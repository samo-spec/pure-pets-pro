//
//  AppManager.m
//  PurePetsAdmin
//






#import "AppManager.h"
#import <math.h>
@import FirebaseCore;
@import FirebaseAppCheck;
#import "PPFirebaseCompat.h"
#import "PPStaffAuth.h"
#import "PPRolePermission.h"
#import <CoreFoundation/CoreFoundation.h>
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

static BOOL PPProStrictTrue(id value) {
    return [value isKindOfClass:NSNumber.class] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() &&
           [value boolValue];
}

static BOOL PPProAccountIsBlocked(NSDictionary *root) {
    if (![root isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in @[@"isBlocked", @"blocked", @"banned", @"deactivated", @"isDeleted",
                            @"deleted", @"isSuspended", @"suspended", @"isDisabled", @"disabled"]) {
        if (PPProStrictTrue(root[key])) return YES;
    }
    for (NSString *key in @[@"status", @"accountStatus"]) {
        if ([@[@"blocked", @"deleted", @"suspended", @"disabled"] containsObject:PPAdminSafeClaimString(root[key])]) {
            return YES;
        }
    }
    return NO;
}

// Match Infra's providerSubscriptionValueActive, including legacy absent status.
static BOOL PPProSubscriptionIsActive(id value) {
    if (!value) return YES;
    id status = value;
    if ([value isKindOfClass:NSDictionary.class]) {
        id schemaVersion = value[@"schemaVersion"];
        if (schemaVersion && (![schemaVersion isKindOfClass:NSNumber.class] || [schemaVersion doubleValue] != 1)) return NO;
        if (schemaVersion && value[@"expiresAt"] && value[@"expiresAt"] != NSNull.null) {
            id rawDate = value[@"expiresAt"];
            if ([rawDate isKindOfClass:NSNumber.class] && !isfinite([rawDate doubleValue])) return NO;
            NSDate *end = [rawDate isKindOfClass:NSNumber.class] ? [NSDate dateWithTimeIntervalSince1970:[rawDate doubleValue] / 1000.0]
                : ([rawDate respondsToSelector:@selector(dateValue)] ? [rawDate dateValue] : nil);
            if (!end || end.timeIntervalSinceNow <= 0) return NO;
        }
        status = value[@"status"];
        if (!status) return !schemaVersion;
    }
    return [status isKindOfClass:NSString.class] &&
           [@[@"active", @"approved", @"trial"] containsObject:status];
}

static BOOL PPUserDocAllowsProAccess(NSDictionary *root) {
    if (![root isKindOfClass:NSDictionary.class] || PPProAccountIsBlocked(root)) return NO;
    for (NSString *key in @[@"status", @"accountStatus"]) {
        id status = root[key];
        if (status && (![status isKindOfClass:NSString.class] ||
                       ![@[@"active", @"approved"] containsObject:status])) return NO;
    }

    NSDictionary *features = [root[@"features"] isKindOfClass:NSDictionary.class] ? root[@"features"] : @{};
    NSDictionary *subscriptions = [root[@"subscriptions"] isKindOfClass:NSDictionary.class] ? root[@"subscriptions"] : @{};
    if (!PPProSubscriptionIsActive(root[@"subscription"]) ||
        !PPProSubscriptionIsActive(subscriptions[@"pro"])) return NO;

    // Canonical feature, legacy feature, legacy nested alias, Infra provider type.
    // Staff membership and admin claims deliberately do not grant provider access.
    NSArray<NSArray<NSString *> *> *providerFeatures = @[
        @[@"serviceProvider", @"canOfferServices", @"service_provider", @"service"],
        @[@"production", @"canAccessProviderMarketplace", @"marketplace", @"marketplace"],
        @[@"veterinarians", @"canVet", @"vet", @"vet"],
        @[@"pharmacy", @"canPharmacy", @"pharmacy", @"pharmacy"],
        @[@"delivery", @"canDelivery", @"delivery", @"delivery_subscription"],
        @[@"delivery", @"canDeliveryCompany", @"canDeliveryCompany", @"delivery_company"]
    ];
    for (NSArray<NSString *> *feature in providerFeatures) {
        BOOL hasFeatureProjection = features[feature[0]] != nil || features[feature[1]] != nil || features[feature[2]] != nil;
        BOOL enabled = PPProStrictTrue(features[feature[0]]) || PPProStrictTrue(features[feature[1]]) ||
                       PPProStrictTrue(features[feature[2]]);
        // Retain old server-issued root flags only when no newer projection exists.
        if (!hasFeatureProjection) enabled = PPProStrictTrue(root[feature[1]]);
        if (enabled && PPProSubscriptionIsActive(subscriptions[feature[0]]) &&
            PPProSubscriptionIsActive(subscriptions[feature[3]])) return YES;
    }
    return NO;
}

typedef void (^PPUsersColRootCompletion)(NSDictionary * _Nullable root, NSError * _Nullable error);

static void PPFetchUsersColRootForAuthIdentity(FIRFirestore *db,
                                               NSString *uid,
                                               PPUsersColRootCompletion completion)
{
    NSString *safeUID = PPSafeString(uid);
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

        // Owner identity is the Firebase Auth UID. Missing profiles enter the
        // existing onboarding flow; collection queries are staff-only in Infra.
        if (completion) completion(snapshot.exists ? (snapshot.data ?: @{}) : nil, nil);
    }];
}

static BOOL PPShouldUseDebugAppCheckProvider(void) {
#if TARGET_OS_SIMULATOR
    return YES;
#elif DEBUG
    // In Debug builds (e.g. running from Xcode on connected physical device),
    // default to Debug provider unless explicitly forced to production App Attest.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSDictionary<NSString *, NSString *> *env = processInfo.environment ?: @{};
    if (PPAppCheckTruthyString(env[@"PP_FORCE_APPCHECK_APPACTEST_PROVIDER"])) {
        return NO;
    }
    return YES;
#else
    // Release builds always attest the real app, regardless of local defaults.
    return NO;
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
        DLog(@"[AppCheck] App Attest failed for PurePetsPro. Falling back to DeviceCheck for this launch. Error: %@",
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
        DLog(@"[AppCheck] Using Debug provider for PurePetsPro.");
        return [[FIRAppCheckDebugProvider alloc] initWithApp:app];
    }

    if (PPShouldUseDeviceCheckAppCheckProvider()) {
        DLog(@"[AppCheck] DeviceCheck provider forced for PurePetsPro.");
        return [[FIRDeviceCheckProvider alloc] initWithApp:app];
    }

    if (PPShouldUseAppAttestAppCheckProvider() && @available(iOS 14.0, *)) {
        DLog(@"[AppCheck] AppAttest provider forced.");
        id<FIRAppCheckProvider> attestProvider = [[FIRAppAttestProvider alloc] initWithApp:app];
        if (attestProvider) {
            return attestProvider;
        }
        DLog(@"[AppCheck] AppAttest provider forced but unavailable. Falling back to DeviceCheck.");
    }

    // Best practice fallback sequence for iOS:
    // 1. App Attest (iOS 14+)
    // 2. DeviceCheck

    if (@available(iOS 14.0, *)) {
        id<FIRAppCheckProvider> attestProvider = [[FIRAppAttestProvider alloc] initWithApp:app];
        if (attestProvider) {
            id<FIRAppCheckProvider> deviceCheckProvider = [[FIRDeviceCheckProvider alloc] initWithApp:app];
            if (deviceCheckProvider) {
                DLog(@"[AppCheck] Using App Attest provider with DeviceCheck fallback.");
                return [[PPResilientAppCheckProvider alloc] initWithAppAttestProvider:attestProvider
                                                                   deviceCheckProvider:deviceCheckProvider];
            }

            DLog(@"[AppCheck] Using App Attest provider.");
            return attestProvider;
        }
    }

    DLog(@"[AppCheck] Using DeviceCheck provider (fallback).");
    return [[FIRDeviceCheckProvider alloc] initWithApp:app];
}

@end


@interface AppManager ()
@property (nonatomic, assign) BOOL googleSignInAppCheckReady;
@property (nonatomic, assign) BOOL googleSignInAppCheckConfiguring;
@property (nonatomic, assign) NSUInteger googleSignInAppCheckGeneration;
@property (nonatomic, strong) NSMutableArray *googleSignInAppCheckCompletions;
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
    (void)provider;

    [[FIRAppCheck appCheck] tokenForcingRefresh:YES completion:^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
        if (error) {
            DLog(@"[AppCheck] Debug token exchange failed for app %@ (%@): %@",
                  defaultApp.options.googleAppID ?: @"unknown-app",
                  defaultApp.options.projectID ?: @"unknown-project",
                  error.localizedDescription ?: @"unknown error");
            return;
        }

        DLog(@"[AppCheck] Debug token exchange succeeded. Token expiration: %@",
              token.expirationDate ?: [NSNull null]);
    }];
}

- (void)prepareGoogleSignInWithCompletion:(void (^)(NSError * _Nullable))callback {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self prepareGoogleSignInWithCompletion:callback]; });
        return;
    }
    if (self.googleSignInAppCheckReady) {
        if (callback) callback(nil);
        return;
    }
    if (!self.googleSignInAppCheckCompletions) self.googleSignInAppCheckCompletions = [NSMutableArray array];
    if (callback) [self.googleSignInAppCheckCompletions addObject:[callback copy]];
    if (self.googleSignInAppCheckConfiguring) return;
    self.googleSignInAppCheckConfiguring = YES;
    NSUInteger generation = ++self.googleSignInAppCheckGeneration;

    void (^completion)(NSError *) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.googleSignInAppCheckGeneration != generation || !self.googleSignInAppCheckConfiguring) return;
            self.googleSignInAppCheckConfiguring = NO;
            self.googleSignInAppCheckReady = error == nil;
            NSArray *callbacks = self.googleSignInAppCheckCompletions.copy;
            [self.googleSignInAppCheckCompletions removeAllObjects];
            if (error) DLog(@"[GoogleSignIn][AppCheck] Configuration failed (%@/%ld).", error.domain, (long)error.code);
            for (void (^pending)(NSError *) in callbacks) pending(error);
        });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.googleSignInAppCheckGeneration == generation && self.googleSignInAppCheckConfiguring) {
            completion([NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]);
        }
    });
    FIRApp *defaultApp = [FIRApp defaultApp];
    if (!defaultApp) {
        completion([NSError errorWithDomain:@"PurePetsPro.GoogleAppCheck" code:1 userInfo:nil]);
        return;
    }
#if DEBUG || TARGET_OS_SIMULATOR
    if (PPShouldUseDebugAppCheckProvider()) {
        if (@available(iOS 14.0, *)) {
            // Google Identity has its own App Check client. Firebase's provider
            // factory alone does not configure it. The SDK owns the debug token.
            NSString *apiKey = defaultApp.options.APIKey;
            if (apiKey.length == 0) {
                completion([NSError errorWithDomain:@"PurePetsPro.GoogleAppCheck" code:2 userInfo:nil]);
                return;
            }
            [GIDSignIn.sharedInstance configureDebugProviderWithAPIKey:apiKey completion:completion];
            return;
        }
    }
#endif
    [GIDSignIn.sharedInstance configureWithCompletion:completion];
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
            DLog(@"[AppCheck] Debug provider active. Register the debug token in Firebase Console > App Check > Manage debug tokens.");
        }

        if (![FIRApp defaultApp]) {
            [FIRApp configure];
            DLog(@"Firebase configured ✅");
            [self prepareGoogleSignInWithCompletion:nil];
            [self pp_logAndProbeDebugAppCheckIfNeeded];
            
            [FUM startAuthListenerWithChangeBlock:^(FIRUser * _Nullable authUser, UserModel * _Nullable userModel) { }];
            
        } else {
            DLog(@"Firebase already configured, skipping");
            [self prepareGoogleSignInWithCompletion:nil];
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
                DLog(@"[AdminAccess] staff_users lookup failed: %@", staffError.localizedDescription);
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
    if (safeUID.length == 0 || ![[FIRAuth auth].currentUser.uid isEqualToString:safeUID]) {
        if (completion) completion(NO, nil, nil);
        return;
    }

    PPFetchUsersColRootForAuthIdentity([FIRFirestore firestore], safeUID, ^(NSDictionary * _Nullable root, NSError * _Nullable error) {
        if (![[FIRAuth auth].currentUser.uid isEqualToString:safeUID]) {
            if (completion) completion(NO, nil, nil);
            return;
        }
        if (error) {
            if (completion) completion(NO, nil, error);
            return;
        }
        if (completion) completion(PPUserDocAllowsProAccess(root), root, nil);
    });
}

+ (BOOL)isProAccountBlocked:(NSDictionary *)userDoc {
    return PPProAccountIsBlocked(userDoc);
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
