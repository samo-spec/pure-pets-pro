//
//  AppManager.m
//  PurePetsAdmin
//






#import "AppManager.h"
@import FirebaseCore;
@import FirebaseAppCheck;
#import "PPFirebaseCompat.h"
#import "PPStaffAuth.h"
#import "PPRolePermission.h"
@import GoogleSignIn;

@interface PPStaffAuth (PPAppManagerCacheAccess)
@property (nonatomic, strong, nullable, readwrite) PPStaffDoc *cachedCurrentStaff;
@end
#import <TargetConditionals.h>

static BOOL PPAppCheckTruthyString(NSString *value) {
    NSString *trimmed = [value isKindOfClass:NSString.class]
        ? [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString]
        : @"";
    if (trimmed.length == 0) {
        return NO;
    }
    return [@[@"1", @"true", @"yes", @"y", @"on"] containsObject:trimmed];
}

static NSString * const PPForceAppCheckDeviceCheckProviderDefaultsKey = @"PPForceAppCheckDeviceCheckProvider";
static NSString * const PPForceAppCheckAppAttestProviderDefaultsKey = @"PPForceAppCheckAppAttestProvider";
static NSString * const PPForceAppCheckDebugProviderDefaultsKey = @"PPForceAppCheckDebugProvider";

typedef void (^PPAppCheckTokenHandler)(FIRAppCheckToken * _Nullable token, NSError * _Nullable error);

static BOOL PPAppCheckErrorLooksLikeAppAttestFailure(NSError *error) {
    if (![error isKindOfClass:NSError.class]) {
        return NO;
    }

    NSMutableArray<NSString *> *messages = [NSMutableArray array];
    NSArray *rawMessages = @[
        error.localizedDescription ?: @"",
        error.localizedFailureReason ?: @"",
        [error.userInfo[NSLocalizedDescriptionKey] isKindOfClass:NSString.class] ? error.userInfo[NSLocalizedDescriptionKey] : @"",
        [error.userInfo[NSLocalizedFailureReasonErrorKey] isKindOfClass:NSString.class] ? error.userInfo[NSLocalizedFailureReasonErrorKey] : @"",
        [error.userInfo[NSDebugDescriptionErrorKey] isKindOfClass:NSString.class] ? error.userInfo[NSDebugDescriptionErrorKey] : @""
    ];
    for (id rawMessage in rawMessages) {
        if ([rawMessage isKindOfClass:NSString.class] && [(NSString *)rawMessage length] > 0) {
            [messages addObject:(NSString *)rawMessage];
        }
    }

    for (NSString *message in messages) {
        NSString *lowercase = message.lowercaseString;
        if ([lowercase containsString:@"exchangeappattestattestation"] ||
            [lowercase containsString:@"app attest"] ||
            [lowercase containsString:@"app attestation failed"] ||
            ([lowercase containsString:@"permission_denied"] &&
             [lowercase containsString:@"firebaseappcheck.googleapis.com"])) {
            return YES;
        }
    }

    NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    if ([underlyingError isKindOfClass:NSError.class] && underlyingError != error) {
        return PPAppCheckErrorLooksLikeAppAttestFailure(underlyingError);
    }

    return NO;
}

static void PPFetchAppCheckTokenFromProvider(id<FIRAppCheckProvider> provider,
                                             BOOL limitedUse,
                                             PPAppCheckTokenHandler handler) {
    if (!provider) {
        if (handler) {
            NSError *providerError =
                [NSError errorWithDomain:@"PurePetsPro.AppCheck"
                                    code:1
                                userInfo:@{NSLocalizedDescriptionKey: @"Missing App Check provider."}];
            handler(nil, providerError);
        }
        return;
    }

    if (limitedUse && [provider respondsToSelector:@selector(getLimitedUseTokenWithCompletion:)]) {
        [provider getLimitedUseTokenWithCompletion:handler];
        return;
    }

    [provider getTokenWithCompletion:handler];
}

static NSString *PPAdminSafeClaimString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            lowercaseString];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *valueString = [(NSString *)[value stringValue] ?: @"" copy];
        return [[valueString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    }
    return @"";
}

static BOOL PPAdminSafeClaimBoolValue(id value)
{
    if ([value isKindOfClass:NSNumber.class] ||
        [value isKindOfClass:NSString.class] ||
        [value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return NO;
}

static BOOL PPUserDocAllowsProAccess(NSDictionary *root)
{
    if (![root isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSString *accountType = [PPAdminSafeClaimString(root[@"accountType"]) lowercaseString];
    NSDictionary *staffProfile = [root[@"staffProfile"] isKindOfClass:NSDictionary.class] ? (NSDictionary *)root[@"staffProfile"] : nil;
    
    NSString *accountStatus =
        [PPAdminSafeClaimString(root[@"accountStatus"]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Unified status check (root or staffProfile)
    NSString *effectiveStatus = accountStatus;
    if (staffProfile && [accountType isEqualToString:@"staff"]) {
        effectiveStatus = [PPAdminSafeClaimString(staffProfile[@"status"]) lowercaseString];
    }
    
    BOOL blocked = PPAdminSafeClaimBoolValue(root[@"isBlocked"]) ||
                   PPAdminSafeClaimBoolValue(root[@"blocked"]) ||
                   [effectiveStatus isEqualToString:@"blocked"] ||
                   [effectiveStatus isEqualToString:@"disabled"];
    
    BOOL deleted = PPAdminSafeClaimBoolValue(root[@"isDeleted"]);
    if (blocked || deleted) {
        return NO;
    }

    // New Infrastructure check
    if ([accountType isEqualToString:@"staff"]) {
        // Active staff members always get access to the Pro app
        return YES;
    }

    // Legacy/Existing checks
    if (PPAdminSafeClaimBoolValue(root[@"isAdmin"]) ||
        PPAdminSafeClaimBoolValue(root[@"isSuperAdmin"]) ||
        PPAdminSafeClaimBoolValue(root[@"isAdminAll"])) {
        return YES;
    }

    UserRole rootRole = PPParseRoleFromUserDoc(root);
    if (PPIsAllowedAdminRole(rootRole)) {
        return YES;
    }

    id features = root[@"features"];
    BOOL canOfferServices = PPAdminSafeClaimBoolValue(root[@"canOfferServices"]);
    BOOL canDelivery = PPAdminSafeClaimBoolValue(root[@"canDelivery"]);
    BOOL canDeliveryCompany = PPAdminSafeClaimBoolValue(root[@"canDeliveryCompany"]);
    BOOL canVet = PPAdminSafeClaimBoolValue(root[@"canVet"]);
    BOOL canPharmacy = PPAdminSafeClaimBoolValue(root[@"canPharmacy"]);
    BOOL canAccessProviderMarketplace = PPAdminSafeClaimBoolValue(root[@"canAccessProviderMarketplace"]);
    if ([features isKindOfClass:NSDictionary.class]) {
        if (!canOfferServices) {
            canOfferServices =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canOfferServices"]) ||
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"service_provider"]);
        }
        if (!canDelivery) {
            canDelivery =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canDelivery"]) ||
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"delivery"]);
        }
        if (!canDeliveryCompany) {
            canDeliveryCompany =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canDeliveryCompany"]);
        }
        if (!canVet) {
            canVet =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canVet"]) ||
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"vet"]);
        }
        if (!canPharmacy) {
            canPharmacy =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canPharmacy"]) ||
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"pharmacy"]);
        }
        if (!canAccessProviderMarketplace) {
            canAccessProviderMarketplace =
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"canAccessProviderMarketplace"]) ||
                PPAdminSafeClaimBoolValue(((NSDictionary *)features)[@"marketplace"]);
        }
    }
    if (!canOfferServices && !canDelivery && !canDeliveryCompany && !canVet && !canPharmacy && !canAccessProviderMarketplace) {
        return NO;
    }

    id subscription = root[@"subscription"];
    if ([subscription isKindOfClass:NSDictionary.class]) {
        NSString *status = PPAdminSafeClaimString(((NSDictionary *)subscription)[@"status"]);
        if ([status isEqualToString:@"blocked"]) {
            return NO;
        }
    }

    return YES;
}

typedef void (^PPUsersColRootCompletion)(NSDictionary * _Nullable root, NSError * _Nullable error);

static void PPQueryUsersColRootMatchingField(FIRFirestore *db,
                                             NSString *field,
                                             NSString *value,
                                             PPUsersColRootCompletion completion)
{
    NSString *safeField = PPSafeString(field);
    NSString *safeValue = PPSafeString(value);
    if (safeField.length == 0 || safeValue.length == 0) {
        if (completion) completion(nil, nil);
        return;
    }

    FIRQuery *query =
        [[[db collectionWithPath:kPPUsersCol]
            queryWhereField:safeField
                 isEqualTo:safeValue]
            queryLimitedTo:1];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        FIRDocumentSnapshot *document = snapshot.documents.firstObject;
        if (!document.exists) {
            if (completion) completion(nil, nil);
            return;
        }

        DLog(@"[ProAccess] Matched UsersCol by %@=%@ (docID=%@)", safeField, safeValue, document.documentID);
        if (completion) completion(document.data ?: @{}, nil);
    }];
}

static void PPFetchUsersColRootForAuthIdentity(FIRFirestore *db,
                                               NSString *uid,
                                               NSString * _Nullable email,
                                               PPUsersColRootCompletion completion)
{
    NSString *safeUID = PPSafeString(uid);
    NSString *safeEmail = PPSafeString(email);
    if (safeUID.length == 0) {
        if (completion) completion(nil, nil);
        return;
    }

    FIRDocumentReference *userRef =
        [[db collectionWithPath:kPPUsersCol] documentWithPath:safeUID];
    [userRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        if (snapshot.exists) {
            if (completion) completion(snapshot.data ?: @{}, nil);
            return;
        }

        PPQueryUsersColRootMatchingField(db, @"uid", safeUID, ^(NSDictionary * _Nullable root, NSError * _Nullable uidError) {
            if (uidError || root) {
                if (completion) completion(root, uidError);
                return;
            }

            PPQueryUsersColRootMatchingField(db, @"ID", safeUID, ^(NSDictionary * _Nullable legacyRoot, NSError * _Nullable legacyError) {
                if (legacyError || legacyRoot || safeEmail.length == 0) {
                    if (completion) completion(legacyRoot, legacyError);
                    return;
                }

                PPQueryUsersColRootMatchingField(db, @"email", safeEmail, ^(NSDictionary * _Nullable emailRoot, NSError * _Nullable emailError) {
                    if (emailError || emailRoot) {
                        if (completion) completion(emailRoot, emailError);
                        return;
                    }

                    PPQueryUsersColRootMatchingField(db, @"UserEmail", safeEmail, completion);
                });
            });
        });
    }];
}

static BOOL PPShouldUseDebugAppCheckProvider(void) {
#if TARGET_OS_SIMULATOR || DEBUG
    return YES;
#else
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    NSString *forceEnv = env[@"PP_FORCE_APPCHECK_DEBUG_PROVIDER"];
    NSString *debugTokenEnv = env[@"FIRAAppCheckDebugToken"];
    BOOL forceFromEnv = PPAppCheckTruthyString(forceEnv);
    BOOL hasDebugTokenEnv = [debugTokenEnv isKindOfClass:NSString.class] && debugTokenEnv.length > 0;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // Check both local flag and a potential global override
    id forceDefaultsValue = [defaults objectForKey:PPForceAppCheckDebugProviderDefaultsKey];
    BOOL forceDefaultsEnabled = NO;
    if ([forceDefaultsValue isKindOfClass:NSNumber.class]) {
        forceDefaultsEnabled = [(NSNumber *)forceDefaultsValue boolValue];
    } else if ([forceDefaultsValue isKindOfClass:NSString.class]) {
        forceDefaultsEnabled = PPAppCheckTruthyString((NSString *)forceDefaultsValue);
    }

    // Also allow forcing via a simple text file in the documents directory (useful for testers)
    static BOOL forceFromDisk = NO;
    static dispatch_once_t onceDisk;
    dispatch_once(&onceDisk, ^{
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"force_appcheck_debug.txt"];
        forceFromDisk = [[NSFileManager defaultManager] fileExistsAtPath:path];
    });

    BOOL explicitDebug = forceFromEnv || hasDebugTokenEnv || forceDefaultsEnabled || forceFromDisk;

#if DEBUG
    return YES;
#else
    return explicitDebug;
#endif
#endif
}

static BOOL PPShouldUseDeviceCheckAppCheckProvider(void) {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    NSString *forceEnv = env[@"PP_FORCE_APPCHECK_DEVICECHECK_PROVIDER"];
    BOOL forceFromEnv = PPAppCheckTruthyString(forceEnv);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id forceDefaultsValue = [defaults objectForKey:PPForceAppCheckDeviceCheckProviderDefaultsKey];
    BOOL forceDefaultsEnabled = NO;
    if ([forceDefaultsValue isKindOfClass:NSNumber.class]) {
        forceDefaultsEnabled = [(NSNumber *)forceDefaultsValue boolValue];
    } else if ([forceDefaultsValue isKindOfClass:NSString.class]) {
        forceDefaultsEnabled = PPAppCheckTruthyString((NSString *)forceDefaultsValue);
    }

    return forceFromEnv || forceDefaultsEnabled;
#endif
}

static BOOL PPShouldUseAppAttestAppCheckProvider(void) {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    NSString *forceEnv = env[@"PP_FORCE_APPCHECK_APPACTEST_PROVIDER"];
    BOOL forceFromEnv = PPAppCheckTruthyString(forceEnv);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id forceDefaultsValue = [defaults objectForKey:PPForceAppCheckAppAttestProviderDefaultsKey];
    BOOL forceDefaultsEnabled = NO;
    if ([forceDefaultsValue isKindOfClass:NSNumber.class]) {
        forceDefaultsEnabled = [(NSNumber *)forceDefaultsValue boolValue];
    } else if ([forceDefaultsValue isKindOfClass:NSString.class]) {
        forceDefaultsEnabled = PPAppCheckTruthyString((NSString *)forceDefaultsValue);
    }

    return forceFromEnv || forceDefaultsEnabled;
#endif
}

@interface PPResilientAppCheckProvider : NSObject <FIRAppCheckProvider>

- (instancetype)initWithAppAttestProvider:(id<FIRAppCheckProvider>)appAttestProvider
                      deviceCheckProvider:(id<FIRAppCheckProvider>)deviceCheckProvider;

@end

@interface PPResilientAppCheckProvider ()

@property (nonatomic, strong, nullable) id<FIRAppCheckProvider> appAttestProvider;
@property (nonatomic, strong, nullable) id<FIRAppCheckProvider> deviceCheckProvider;
@property (atomic, assign) BOOL usingDeviceCheckFallback;

@end

@implementation PPResilientAppCheckProvider

- (instancetype)initWithAppAttestProvider:(id<FIRAppCheckProvider>)appAttestProvider
                      deviceCheckProvider:(id<FIRAppCheckProvider>)deviceCheckProvider {
    self = [super init];
    if (self) {
        _appAttestProvider = appAttestProvider;
        _deviceCheckProvider = deviceCheckProvider;
        _usingDeviceCheckFallback = NO;
    }
    return self;
}

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken * _Nullable, NSError * _Nullable))handler {
    [self pp_getTokenLimitedUse:NO completion:handler];
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken * _Nullable, NSError * _Nullable))handler {
    [self pp_getTokenLimitedUse:YES completion:handler];
}

- (void)pp_getTokenLimitedUse:(BOOL)limitedUse completion:(PPAppCheckTokenHandler)handler {
    id<FIRAppCheckProvider> deviceCheckProvider = self.deviceCheckProvider;
    if (self.usingDeviceCheckFallback || !self.appAttestProvider) {
        PPFetchAppCheckTokenFromProvider(deviceCheckProvider, limitedUse, handler);
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPFetchAppCheckTokenFromProvider(self.appAttestProvider, limitedUse, ^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (handler) {
                handler(token, error);
            }
            return;
        }

        if (!error || !PPAppCheckErrorLooksLikeAppAttestFailure(error)) {
            if (handler) {
                handler(token, error);
            }
            return;
        }

        self.usingDeviceCheckFallback = YES;
        NSLog(@"[AppCheck] App Attest failed for PurePetsPro. Falling back to DeviceCheck for this launch. Error: %@",
              error.localizedDescription ?: @"unknown error");
        PPFetchAppCheckTokenFromProvider(deviceCheckProvider, limitedUse, ^(FIRAppCheckToken * _Nullable fallbackToken, NSError * _Nullable fallbackError) {
            if (fallbackToken || !fallbackError) {
                if (handler) {
                    handler(fallbackToken, nil);
                }
                return;
            }

            if (handler) {
                handler(nil, fallbackError ?: error);
            }
        });
    });
}

@end

@interface PPAppCheckProviderFactory : NSObject <FIRAppCheckProviderFactory>
@end

@implementation PPAppCheckProviderFactory

- (id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
    if (PPShouldUseDebugAppCheckProvider()) {
        NSLog(@"[AppCheck] Using Debug provider for PurePetsPro.");
        return [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    }

    if (PPShouldUseDeviceCheckAppCheckProvider()) {
        NSLog(@"[AppCheck] DeviceCheck provider forced for PurePetsPro.");
        return [[FIRDeviceCheckProvider alloc] initWithApp:app];
    }

    if (PPShouldUseAppAttestAppCheckProvider() && @available(iOS 14.0, *)) {
        NSLog(@"[AppCheck] AppAttest provider forced.");
        id<FIRAppCheckProvider> attestProvider = [[FIRAppAttestProvider alloc] initWithApp:app];
        if (attestProvider) {
            return attestProvider;
        }
        NSLog(@"[AppCheck] AppAttest provider forced but unavailable. Falling back to DeviceCheck.");
    }

    // Best practice fallback sequence for iOS:
    // 1. App Attest (iOS 14+)
    // 2. DeviceCheck

    if (@available(iOS 14.0, *)) {
        id<FIRAppCheckProvider> attestProvider = [[FIRAppAttestProvider alloc] initWithApp:app];
        if (attestProvider) {
            id<FIRAppCheckProvider> deviceCheckProvider = [[FIRDeviceCheckProvider alloc] initWithApp:app];
            if (deviceCheckProvider) {
                NSLog(@"[AppCheck] Using App Attest provider with DeviceCheck fallback.");
                return [[PPResilientAppCheckProvider alloc] initWithAppAttestProvider:attestProvider
                                                                   deviceCheckProvider:deviceCheckProvider];
            }

            NSLog(@"[AppCheck] Using App Attest provider.");
            return attestProvider;
        }
    }

    NSLog(@"[AppCheck] Using DeviceCheck provider (fallback).");
    return [[FIRDeviceCheckProvider alloc] initWithApp:app];
}

@end


@implementation AppManager

- (void)pp_logAndProbeDebugAppCheckIfNeeded {
    if (!PPShouldUseDebugAppCheckProvider()) {
        return;
    }

    FIRApp *defaultApp = [FIRApp defaultApp];
    if (!defaultApp) {
        return;
    }

    FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] initWithApp:defaultApp];
    if (provider) {
        NSLog(@"[AppCheck] Local debug token: '%@'", provider.localDebugToken ?: @"");
        NSLog(@"[AppCheck] Current debug token: '%@'", provider.currentDebugToken ?: @"");
    }

    [[FIRAppCheck appCheck] tokenForcingRefresh:YES completion:^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[AppCheck] Debug token exchange failed for app %@ (%@): %@",
                  defaultApp.options.googleAppID ?: @"unknown-app",
                  defaultApp.options.projectID ?: @"unknown-project",
                  error.localizedDescription ?: @"unknown error");
            return;
        }

        NSLog(@"[AppCheck] Debug token exchange succeeded. Token expiration: %@",
              token.expirationDate ?: [NSNull null]);
    }];
}

- (void)pp_configureGoogleSignInAppCheckForDefaultApp {
    FIRApp *defaultApp = [FIRApp defaultApp];
    if (!defaultApp) {
        return;
    }

    if (PPShouldUseDebugAppCheckProvider()) {
        NSString *apiKey = defaultApp.options.APIKey;
        if (apiKey.length == 0) {
            NSLog(@"[GoogleSignIn][AppCheck] Missing iOS API key; debug provider was not configured.");
            return;
        }

        if (@available(iOS 14.0, *)) {
            [GIDSignIn.sharedInstance configureDebugProviderWithAPIKey:apiKey completion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[GoogleSignIn][AppCheck] Debug provider configuration failed: %@",
                          error.localizedDescription ?: @"unknown error");
                    return;
                }
                NSLog(@"[GoogleSignIn][AppCheck] Debug provider configured for PurePetsPro.");
            }];
        } else {
            NSLog(@"[GoogleSignIn][AppCheck] Debug provider requires iOS 14 or later.");
        }
        return;
    }

    [GIDSignIn.sharedInstance configureWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[GoogleSignIn][AppCheck] Production App Check configuration failed: %@",
                  error.localizedDescription ?: @"unknown error");
            return;
        }
        NSLog(@"[GoogleSignIn][AppCheck] Production App Check configured for PurePetsPro.");
    }];
}

+ (instancetype)shared {
    static AppManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        _appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        DLog(@"Initialized AppManager, version: %@", _appVersion);
    }
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"Singleton"
                                   reason:@"Use +[AppManager shared]"
                                 userInfo:nil];
    return nil;
}

#pragma mark - Firebase

- (void)configureFirebase {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [FIRAppCheck setAppCheckProviderFactory:[[PPAppCheckProviderFactory alloc] init]];
        if (PPShouldUseDebugAppCheckProvider()) {
            NSLog(@"[AppCheck] Debug provider active. If requests are still blocked, register the printed debug token in Firebase Console > App Check > Manage debug tokens.");
        }

        if (![FIRApp defaultApp]) {
            [FIRApp configure];
            DLog(@"Firebase configured ✅");
            [self pp_configureGoogleSignInAppCheckForDefaultApp];
            [self pp_logAndProbeDebugAppCheckIfNeeded];
            
            [FUM startAuthListenerWithChangeBlock:^(FIRUser * _Nullable authUser, UserModel * _Nullable userModel) { }];
            
        } else {
            DLog(@"Firebase already configured, skipping");
            [self pp_configureGoogleSignInAppCheckForDefaultApp];
            [self pp_logAndProbeDebugAppCheckIfNeeded];
        }
    });
}

- (void)checkIfAdmin:(void(^)(BOOL isAdmin))completion {
    FIRUser *user = [FIRAuth auth].currentUser;
    self.currentUser = user;
    
    if (!user) {
        if (completion) completion(NO);
        return;
    }
    
    [user getIDTokenResultForcingRefresh:YES completion:^(FIRAuthTokenResult * _Nullable tokenResult,
                                           NSError * _Nullable error) {
        if (error || !tokenResult) {
            if (completion) completion(NO);
            return;
        }
        
        NSDictionary *claims = tokenResult.claims ?: @{};
        BOOL isAdminFlag = PPAdminSafeClaimBoolValue(claims[@"admin"]) ||
                           PPAdminSafeClaimBoolValue(claims[@"superAdmin"]) ||
                           PPAdminSafeClaimBoolValue(claims[@"isSuperAdmin"]) ||
                           PPAdminSafeClaimBoolValue(claims[@"isAdmin"]) ||
                           PPAdminSafeClaimBoolValue(claims[@"isAdminAll"]);
        BOOL isPrivilegedRole = PPIsAllowedAdminRole(PPParseRoleFromUserDoc(claims));
        if (isAdminFlag || isPrivilegedRole) {
            if (completion) completion(YES);
            return;
        }

        [[PPStaffAuth shared] fetchStaffDoc:user.uid completion:^(PPStaffDoc * _Nullable staffDoc, NSError * _Nullable staffError) {
            if (staffError) {
                NSLog(@"[AdminAccess] staff_users lookup failed: %@", staffError.localizedDescription);
                if (completion) completion(NO);
                return;
            }

            UserRole mappedRole = staffDoc ? [PPStaffAuth legacyRoleFromStaffRole:staffDoc.role] : UserRoleUnknown;
            BOOL allowed = (staffDoc != nil &&
                            staffDoc.isActive &&
                            PPIsAllowedAdminRole(mappedRole));
            if (allowed && staffDoc) {
                [PPStaffAuth shared].cachedCurrentStaff = staffDoc;   // cache for downstream use
            }
            if (completion) completion(allowed);
        }];
    }];
}

- (void)checkIfCurrentUserCanAccessPro:(void(^)(BOOL allowed))completion
{
    NSString *uid = PPSafeString([FIRAuth auth].currentUser.uid);
    [self checkIfUserWithUID:uid canAccessPro:^(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
        (void)userDoc;
        (void)error;
        if (completion) completion(allowed);
    }];
}

- (void)checkIfUserWithUID:(NSString *)uid
              canAccessPro:(void(^)(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error))completion
{
    NSString *safeUID = PPSafeString(uid);
    if (safeUID.length == 0) {
        if (completion) completion(NO, nil, nil);
        return;
    }

    [self checkIfAdmin:^(BOOL isAdmin) {
        if (isAdmin) {
            if (completion) completion(YES, nil, nil);
            return;
        }

        FIRUser *authUser = [FIRAuth auth].currentUser;
        NSString *authEmail =
            [PPSafeString(authUser.uid) isEqualToString:safeUID]
                ? PPSafeString(authUser.email)
                : @"";

        PPFetchUsersColRootForAuthIdentity([FIRFirestore firestore], safeUID, authEmail, ^(NSDictionary * _Nullable root, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(NO, nil, error);
                return;
            }

            if (![root isKindOfClass:NSDictionary.class] || root.count == 0) {
                if (completion) completion(NO, nil, nil);
                return;
            }

            if (completion) completion(PPUserDocAllowsProAccess(root), root, nil);
        });
    }];
}

#pragma mark - MainKinds

- (void)fetchMainKindsWithCompletion:(void(^)(NSArray<MainKindsModel *> * _Nullable kinds, NSError * _Nullable error))completion {
    FIRFirestore *db = [FIRFirestore firestore];
    
    DLog(@"Fetching visible MainKindsCollection from Firestore…");
    FIRQuery *query = [[[db collectionWithPath:@"MainKindsCollection"]
                        queryWhereField:@"is_visible_in_user_app" isEqualTo:@YES]
                       queryOrderedByField:@"sortingKey" descending:NO];
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error) {
        if (error) {
            DLog(@"❌ Error fetching MainKinds: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSMutableArray<MainKindsModel *> *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            MainKindsModel *kind = [[MainKindsModel alloc] initWithSnapshot:doc];
            if (!kind.isVisibleInUserApp) { continue; }
            [result addObject:kind];
            DLog(@"Loaded MainKind: %@ (id=%@)", kind.KindNameEn ?: @"?", doc.documentID);
        }
        
        self.MainKindsArray = result;
        DLog(@"✅ Finished fetching MainKinds. Count = %lu", (unsigned long)result.count);
        
        if (completion) completion(result, nil);
    }];
}

@end
