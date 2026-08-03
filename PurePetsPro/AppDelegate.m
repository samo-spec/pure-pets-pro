//
//  AppDelegate.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import "AppDelegate.h"
#import "SceneDelegate.h"
#import "PPFirebaseCompat.h"
#import "PPProInAppNotificationPresenter.h"
#import <sys/utsname.h>
@import FirebaseMessaging;
@import GoogleSignIn;
// AppDelegate.m
#if DEBUG
#import <Foundation/Foundation.h>
#endif
#import "FirebaseInstallations/FIRInstallations.h"
static NSString * const kPPProNotificationV2AppID = @"pro_ios";
static NSString * const kPPProNotificationV2BindingDefaultsKey = @"PPNotificationV2ProBindingV1";

static NSString *PPAdminRouteTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL PPAdminIsCompanyDeliveryPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? payload : @{};
    NSString *type = [PPAdminRouteTrimmedString(safePayload[@"type"]) lowercaseString];
    NSString *notificationType = [PPAdminRouteTrimmedString(safePayload[@"notificationType"]) lowercaseString];
    NSString *route = [PPAdminRouteTrimmedString(safePayload[@"route"]) lowercaseString];
    return [type hasPrefix:@"company_delivery"] ||
           [notificationType hasPrefix:@"company_delivery"] ||
           [route isEqualToString:@"fleet_partner"];
}

static BOOL PPAdminPayloadTargetsOtherApp(NSDictionary *payload)
{
    NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? payload : @{};
    NSString *targetApp = [PPAdminRouteTrimmedString(safePayload[@"targetApp"] ?: safePayload[@"targetAppId"] ?: safePayload[@"appId"]) lowercaseString];
    return targetApp.length > 0 && ![targetApp isEqualToString:@"pro_ios"];
}

static NSString *PPAdminNotificationEnvironment(void)
{
#if DEBUG
    return @"sandbox";
#else
    return @"production";
#endif
}

static NSString *PPAdminCurrentDeviceModel(void)
{
    struct utsname systemInfo;
    if (uname(&systemInfo) != 0) {
        return PPAdminRouteTrimmedString(UIDevice.currentDevice.model);
    }
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] ?: @"";
}

@interface AppDelegate ()
@property (nonatomic, assign) FIRAuthStateDidChangeListenerHandle authStateHandle;
@property (nonatomic, copy) NSString *apnsTokenHexString;
@property (nonatomic, assign) BOOL notificationV2RegistrationInFlight;
@property (nonatomic, copy) NSString *notificationV2PendingReason;
@property (nonatomic, assign) BOOL notificationV2LogoutBarrierActive;
@property (nonatomic, assign) NSUInteger notificationV2LifecycleEpoch;
@property (nonatomic, strong) NSMutableArray *notificationV2LogoutBarrierWaiters;

- (void)pp_finishNotificationV2RegistrationCycle;
- (void)pp_releaseNotificationV2LogoutBarrierWaiters;
- (BOOL)pp_notificationV2RegistrationIsCurrentForUID:(NSString *)uid epoch:(NSUInteger)epoch;
- (void)pp_compensateStaleNotificationV2Registration:(NSDictionary *)response
                                                  uid:(NSString *)uid
                                       installationId:(NSString *)installationId
                                           environment:(NSString *)environment
                                            completion:(dispatch_block_t)completion;
@end

@implementation AppDelegate

static SceneDelegate *PPProActiveSceneDelegate(void)
{
    NSSet<UIScene *> *connectedScenes = UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        if (scene.activationState == UISceneActivationStateForegroundActive ||
            scene.activationState == UISceneActivationStateForegroundInactive) {
            id delegate = scene.delegate;
            if ([delegate isKindOfClass:SceneDelegate.class]) {
                return (SceneDelegate *)delegate;
            }
        }
    }
    for (UIScene *scene in connectedScenes) {
        id delegate = scene.delegate;
        if ([delegate isKindOfClass:SceneDelegate.class]) {
            return (SceneDelegate *)delegate;
        }
    }
    return nil;
}

extern BOOL PP_TouchDotsEnabled;

- (void)pp_storeFCMToken:(NSString *)token {
    NSString *safeToken = PPAdminRouteTrimmedString(token);
    if (safeToken.length == 0) {
        return;
    }

    self.fcmToken = safeToken;
    PPNotifications.deviceToken = safeToken;
}

- (void)pp_resolveCurrentFCMTokenWithCompletion:(void (^)(NSString * _Nullable token))completion {
    NSString *resolvedToken = PPAdminRouteTrimmedString(self.fcmToken);
    if (resolvedToken.length == 0) {
        resolvedToken = PPAdminRouteTrimmedString([FIRMessaging messaging].FCMToken);
    }
    if (resolvedToken.length > 0) {
        if (completion) completion(resolvedToken);
        return;
    }

    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *safeToken = PPAdminRouteTrimmedString(token);
            if (safeToken.length > 0) {
                [self pp_storeFCMToken:safeToken];
            } else if (error) {
                NSLog(@"[FIRMessaging] Unable to resolve current FCM token: %@", error.localizedDescription);
            }
            if (completion) completion(safeToken.length > 0 ? safeToken : nil);
        });
    }];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // PPImageCollectionRow auto-registers via +load — no manual registration needed.

    // Configure Firebase as early as possible for Messaging/Auth consumers.
    [AppMgr configureFirebase];
    
    // In AppDelegate.m - application:didFinishLaunchingWithOptions:
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
    
 
    [self setupAppAppearance];          // keep your existing method
    NSString *lang = [Language currentLanguageCode];
    [Language userSelectedLanguage:lang];

    
    [[NSUserDefaults standardUserDefaults] setObject:@[lang] forKey:@"AppleLanguages"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"AppleLanguages  lang %@" ,lang);
    // --- Push Notifications ---
    // Set Firebase Messaging delegate
    [FIRMessaging messaging].delegate = self;
    
    // Start token sync observer
    [self pp_registerForAdminTokenSync];
    
    // Request permissions and register for remote notifications
    [self registerForRemoteNotifications];

    // ✅ iOS 12 fallback (no SceneDelegate)
        if (@available(iOS 13.0, *)) {
            // handled by SceneDelegate
        } else {
            self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            AdminLoginViewController *rootVC = [AdminLoginViewController new];
            PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:rootVC];
            self.window.rootViewController = nav;
            [self.window makeKeyAndVisible];
        }
    
    
    return YES;
}


#pragma mark - UISceneSession lifecycle (iOS 13+)

- (UISceneConfiguration *)application:(UIApplication *)application
  configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                               options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)) {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                                 sessionRole:connectingSceneSession.role];
    config.delegateClass = [SceneDelegate class];
    return config;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    (void)application;
    (void)options;
    return [GIDSignIn.sharedInstance handleURL:url];
}

// ===============================  NOTIFICATIONS ===========================================================//



#pragma mark - Remote Notifications Registration

- (void)registerForRemoteNotifications {
    if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or later
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error requesting notification authorization: %@", error);
            }
        }];
    } else {
        // iOS 9 or earlier
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

#pragma mark - APNs Token Methods

// This method is called when APNs has assigned the device a unique token
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Convert device token to string
    const char *data = [deviceToken bytes];
    NSMutableString *tokenString = [NSMutableString string];
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [tokenString appendFormat:@"%02.2hhX", data[i]];
    }

    self.apnsTokenHexString = [tokenString copy];
    NSLog(@"[NotificationsV2] APNs token updated. reason=apns_registration hasToken=%@", self.apnsTokenHexString.length > 0 ? @"yes" : @"no");
    
    // Forward the token to Firebase Messaging
    [FIRMessaging messaging].APNSToken = deviceToken;
    [self pp_attemptNotificationV2RegistrationForReason:@"apns_registration"];
}

// This method is called if APNs registration fails
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"[FIRMessaging] Failed to register for remote notifications: %@", error);
}

#pragma mark - FIRMessagingDelegate Methods

// This method is called whenever FCM receives a new registration token
- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    (void)messaging;
    NSString *safeToken = PPAdminRouteTrimmedString(fcmToken);
    if (safeToken.length == 0) {
        return;
    }
    NSLog(@"[NotificationsV2] FCM token updated. reason=fcm_refresh hasToken=yes");
    [self pp_storeFCMToken:safeToken];
    
    // Send token to your server if needed
    [self sendTokenToServer:safeToken];

    [self pp_attemptNotificationV2RegistrationForReason:@"fcm_refresh"];
    
    // Post notification that token has been updated
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FCMTokenUpdated" object:safeToken];
}

#pragma mark - Handle Token

- (void)pp_registerForAdminTokenSync {
    __weak typeof(self) weakSelf = self;
    
    // 1. Resolve current token and sync if user is already logged in
    [self pp_resolveCurrentFCMTokenWithCompletion:^(NSString * _Nullable token) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || token.length == 0) return;
        NSString *currentUID = [FIRAuth auth].currentUser.uid;
        if (currentUID.length > 0) {
            [strongSelf pp_syncAdminPushToken:token preferredUID:currentUID];
            [strongSelf pp_attemptNotificationV2RegistrationForReason:@"launch_sync"];
        }
    }];

    // 2. Listen for auth changes to sync token for the new user session
    self.authStateHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth * _Nonnull auth, FIRUser * _Nullable user) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !user.uid.length) return;
        
        [strongSelf pp_resolveCurrentFCMTokenWithCompletion:^(NSString * _Nullable token) {
            if (token.length > 0) {
                [strongSelf pp_syncAdminPushToken:token preferredUID:user.uid];
            }
        }];
        [strongSelf pp_attemptNotificationV2RegistrationForReason:@"auth_change"];
    }];
}

- (void)pp_syncAdminPushToken:(NSString *)token preferredUID:(NSString *)preferredUID {
    NSString *safeToken = PPAdminRouteTrimmedString(token);
    NSString *uid = PPAdminRouteTrimmedString(preferredUID);
    if (safeToken.length == 0 || uid.length == 0) return;

    // Always update the local model if it exists. Also perform the direct
    // merge below so notification routing is not dependent on model sync shape.
    if (UsrMgr.currentUser && [UsrMgr.currentUser.uid isEqualToString:uid]) {
        UsrMgr.currentUser.PPProTokenID = safeToken;
         [UsrMgr.currentUser SYNC:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[FIRMessaging] Failed syncing token via model: %@", error.localizedDescription);
            } else {
                NSLog(@"[FIRMessaging] Token synced via model for %@", uid);
            }
        }];
    }

    // Direct Firestore update covers launch/early login and backstops model sync.
    NSLog(@"[FIRMessaging] Performing direct Firestore token sync for %@", uid);
    NSDictionary *update = @{
        @"PPProTokenID": safeToken,
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };
    
    [[[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid]
        setData:update merge:YES completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FIRMessaging] Direct Firestore sync failed: %@", error.localizedDescription);
        } else {
            NSLog(@"[FIRMessaging] Direct Firestore sync success for %@", uid);
        }
    }];
}

- (void)sendTokenToServer:(NSString *)token {
    // Implement your server communication here
    NSLog(@"[FIRMessaging] Sending token to server via legacy sync.");
    [self pp_storeFCMToken:token];
    
    NSString *currentUID = [FIRAuth auth].currentUser.uid;
    [self pp_syncAdminPushToken:token preferredUID:currentUID];
}

- (void)pp_beginNotificationV2LogoutBarrierWithCompletion:(dispatch_block_t)completion
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_beginNotificationV2LogoutBarrierWithCompletion:completion];
        });
        return;
    }

    if (!self.notificationV2LogoutBarrierActive) {
        self.notificationV2LogoutBarrierActive = YES;
        self.notificationV2LifecycleEpoch += 1;
        self.notificationV2PendingReason = nil;
        NSLog(@"PPLAB NotificationsV2 logout barrier raised | appId=%@ epoch=%lu inFlight=%@",
              kPPProNotificationV2AppID,
              (unsigned long)self.notificationV2LifecycleEpoch,
              self.notificationV2RegistrationInFlight ? @"yes" : @"no");

    }

    if (completion) {
        if (!self.notificationV2LogoutBarrierWaiters) {
            self.notificationV2LogoutBarrierWaiters = [NSMutableArray array];
        }
        [self.notificationV2LogoutBarrierWaiters addObject:[completion copy]];
    }

    NSUInteger barrierEpoch = self.notificationV2LifecycleEpoch;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.notificationV2LogoutBarrierActive ||
            strongSelf.notificationV2LifecycleEpoch != barrierEpoch ||
            strongSelf.notificationV2LogoutBarrierWaiters.count == 0) {
            return;
        }
        NSLog(@"PPLAB NotificationsV2 logout barrier timeout | appId=%@ epoch=%lu inFlight=%@ continuing=yes",
              kPPProNotificationV2AppID,
              (unsigned long)barrierEpoch,
              strongSelf.notificationV2RegistrationInFlight ? @"yes" : @"no");
        [strongSelf pp_releaseNotificationV2LogoutBarrierWaiters];
    });

    if (!self.notificationV2RegistrationInFlight) {
        [self pp_releaseNotificationV2LogoutBarrierWaiters];
    }
}

- (void)pp_releaseNotificationV2LogoutBarrierWaiters
{
    NSArray *waiters = [self.notificationV2LogoutBarrierWaiters copy] ?: @[];
    [self.notificationV2LogoutBarrierWaiters removeAllObjects];
    for (id waiterObject in waiters) {
        dispatch_block_t waiter = (dispatch_block_t)waiterObject;
        waiter();
    }
}

- (void)pp_endNotificationV2LogoutBarrier
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_endNotificationV2LogoutBarrier];
        });
        return;
    }

    self.notificationV2LogoutBarrierActive = NO;
    self.notificationV2PendingReason = nil;
    [self.notificationV2LogoutBarrierWaiters removeAllObjects];
    NSLog(@"PPLAB NotificationsV2 logout barrier lowered | appId=%@ epoch=%lu",
          kPPProNotificationV2AppID,
          (unsigned long)self.notificationV2LifecycleEpoch);
}

- (void)pp_abortNotificationV2LogoutBarrierAndRefreshForReason:(NSString *)reason
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_abortNotificationV2LogoutBarrierAndRefreshForReason:reason];
        });
        return;
    }

    [self pp_endNotificationV2LogoutBarrier];
    NSString *safeReason = PPAdminRouteTrimmedString(reason);
    [self pp_attemptNotificationV2RegistrationForReason:safeReason.length > 0 ? safeReason : @"logout_aborted"];
}

- (BOOL)pp_notificationV2RegistrationIsCurrentForUID:(NSString *)uid epoch:(NSUInteger)epoch
{
    NSString *activeUID = PPAdminRouteTrimmedString([FIRAuth auth].currentUser.uid);
    return !self.notificationV2LogoutBarrierActive &&
        epoch == self.notificationV2LifecycleEpoch &&
        [activeUID isEqualToString:PPAdminRouteTrimmedString(uid)];
}

- (void)pp_compensateStaleNotificationV2Registration:(NSDictionary *)response
                                                  uid:(NSString *)uid
                                       installationId:(NSString *)installationId
                                           environment:(NSString *)environment
                                            completion:(dispatch_block_t)completion
{
    dispatch_block_t finish = completion ?: ^{};
    BOOL ok = [response[@"ok"] respondsToSelector:@selector(boolValue)] && [response[@"ok"] boolValue];
    NSString *bindingGeneration = PPAdminRouteTrimmedString(response[@"bindingGeneration"]);
    NSString *fcmTokenHash = PPAdminRouteTrimmedString(response[@"fcmTokenHash"]);
    NSString *activeUID = PPAdminRouteTrimmedString([FIRAuth auth].currentUser.uid);
    if (!ok || ![activeUID isEqualToString:PPAdminRouteTrimmedString(uid)] ||
        PPAdminRouteTrimmedString(installationId).length == 0 ||
        bindingGeneration.length == 0 || fcmTokenHash.length == 0) {
        NSLog(@"PPLAB NotificationsV2 stale registration discarded | appId=%@ compensated=no hasAuth=%@ hasBinding=%@",
              kPPProNotificationV2AppID,
              [activeUID isEqualToString:PPAdminRouteTrimmedString(uid)] ? @"yes" : @"no",
              bindingGeneration.length > 0 && fcmTokenHash.length > 0 ? @"yes" : @"no");
        finish();
        return;
    }

    NSDictionary *payload = @{
        @"installationId": PPAdminRouteTrimmedString(installationId),
        @"reason": @"logout",
        @"appId": kPPProNotificationV2AppID,
        @"environment": PPAdminRouteTrimmedString(environment).length > 0 ? PPAdminRouteTrimmedString(environment) : PPAdminNotificationEnvironment(),
        @"bindingGeneration": bindingGeneration,
        @"expectedFcmTokenHash": fcmTokenHash
    };
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"deactivateNotificationDeviceV2"];
    callable.timeoutInterval = 10.0;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *deactivateResponse = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            BOOL deactivateOK = [deactivateResponse[@"ok"] respondsToSelector:@selector(boolValue)] && [deactivateResponse[@"ok"] boolValue];
            NSLog(@"PPLAB NotificationsV2 stale registration compensated | appId=%@ ok=%@ error=%@",
                  kPPProNotificationV2AppID,
                  deactivateOK ? @"yes" : @"no",
                  error.localizedDescription ?: @"none");
            finish();
        });
    }];
}

- (void)pp_attemptNotificationV2RegistrationForReason:(NSString *)reason {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_attemptNotificationV2RegistrationForReason:reason];
        });
        return;
    }

    NSString *safeReason = PPAdminRouteTrimmedString(reason);
    if (self.notificationV2LogoutBarrierActive) {
        NSLog(@"PPLAB NotificationsV2 registration blocked | reason=%@ appId=%@ logoutBarrier=yes epoch=%lu",
              safeReason.length > 0 ? safeReason : @"unknown",
              kPPProNotificationV2AppID,
              (unsigned long)self.notificationV2LifecycleEpoch);
        return;
    }

    NSString *uid = PPAdminRouteTrimmedString([FIRAuth auth].currentUser.uid);
    if (uid.length == 0) {
        NSLog(@"PPLAB NotificationsV2 registration skipped | reason=%@ appId=%@ hasUID=no",
              safeReason.length > 0 ? safeReason : @"unknown",
              kPPProNotificationV2AppID);
        return;
    }

    if (self.notificationV2RegistrationInFlight) {
        self.notificationV2PendingReason = safeReason.length > 0 ? safeReason : @"coalesced";
        NSLog(@"PPLAB NotificationsV2 registration coalesced | reason=%@ appId=%@",
              self.notificationV2PendingReason,
              kPPProNotificationV2AppID);
        return;
    }
    NSUInteger registrationEpoch = self.notificationV2LifecycleEpoch;
    self.notificationV2RegistrationInFlight = YES;

    __weak typeof(self) weakSelf = self;
    [self pp_resolveCurrentFCMTokenWithCompletion:^(NSString * _Nullable token) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (![strongSelf pp_notificationV2RegistrationIsCurrentForUID:uid epoch:registrationEpoch]) {
            NSLog(@"PPLAB NotificationsV2 registration cancelled | reason=%@ appId=%@ staleEpoch=yes",
                  safeReason.length > 0 ? safeReason : @"unknown",
                  kPPProNotificationV2AppID);
            [strongSelf pp_finishNotificationV2RegistrationCycle];
            return;
        }

        NSString *safeToken = PPAdminRouteTrimmedString(token);
        if (safeToken.length == 0) {
            NSLog(@"PPLAB NotificationsV2 registration skipped | reason=%@ appId=%@ hasUID=yes hasFCM=no",
                  safeReason.length > 0 ? safeReason : @"unknown",
                  kPPProNotificationV2AppID);
            [strongSelf pp_finishNotificationV2RegistrationCycle];
            return;
        }

        [PPFIRInstallation installationIDWithCompletion:^(NSString * _Nullable installationId, NSError * _Nullable installationError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;

                if (![strongSelf pp_notificationV2RegistrationIsCurrentForUID:uid epoch:registrationEpoch]) {
                    NSLog(@"PPLAB NotificationsV2 registration cancelled | reason=%@ appId=%@ auth_changed_or_stale=yes",
                          safeReason.length > 0 ? safeReason : @"unknown",
                          kPPProNotificationV2AppID);
                    [strongSelf pp_finishNotificationV2RegistrationCycle];
                    return;
                }

                NSString *safeInstallationId = PPAdminRouteTrimmedString(installationId);
                if (safeInstallationId.length == 0) {
                    NSLog(@"PPLAB NotificationsV2 registration skipped | reason=%@ appId=%@ hasUID=yes hasFCM=yes hasInstallation=no error=%@",
                          safeReason.length > 0 ? safeReason : @"unknown",
                          kPPProNotificationV2AppID,
                          installationError.localizedDescription ?: @"unknown");
                    [strongSelf pp_finishNotificationV2RegistrationCycle];
                    return;
                }

                NSString *bundleId = PPAdminRouteTrimmedString(NSBundle.mainBundle.bundleIdentifier);
                NSString *locale = PPAdminRouteTrimmedString([Language currentLanguageCode]);
                NSString *timezone = PPAdminRouteTrimmedString(NSTimeZone.localTimeZone.name);
                NSString *appVersion = PPAdminRouteTrimmedString(AppMgr.appVersion);
                NSString *osVersion = PPAdminRouteTrimmedString(UIDevice.currentDevice.systemVersion);
                NSString *deviceModel = PPAdminCurrentDeviceModel();
                NSString *apnsTokenHex = PPAdminRouteTrimmedString(strongSelf.apnsTokenHexString);
                NSArray<NSString *> *notificationScopes = @[@"provider.orders", @"provider.chat", @"provider.account", @"provider.settlements"];
                NSArray<NSString *> *providerIds = @[uid];
                NSDictionary *capabilities = @{
                    @"customer": @NO,
                    @"provider": @YES,
                    @"staff": @NO
                };

                NSMutableDictionary *payload = [@{
                    @"installationId": safeInstallationId,
                    @"platform": @"ios",
                    @"appId": @"pro_ios",
                    @"bundleId": bundleId,
                    @"environment": PPAdminNotificationEnvironment(),
                    @"fcmToken": safeToken,
                    @"notificationScopes": notificationScopes,
                    @"providerIds": providerIds,
                    @"capabilities": capabilities,
                    @"locale": locale,
                    @"timezone": timezone,
                    @"appVersion": appVersion,
                    @"osVersion": osVersion,
                    @"deviceModel": deviceModel
                } mutableCopy];

                if (apnsTokenHex.length > 0) {
                    payload[@"apnsTokenHash"] = apnsTokenHex;
                }

                FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"registerNotificationDeviceV2"];
                callable.timeoutInterval = 30.0;

                NSLog(@"PPLAB NotificationsV2 registration start | reason=%@ hasUID=yes appId=pro_ios scopes=%lu providerIds=%lu hasAPNS=%@",
                      safeReason.length > 0 ? safeReason : @"unknown",
                      (unsigned long)notificationScopes.count,
                      (unsigned long)providerIds.count,
                      apnsTokenHex.length > 0 ? @"yes" : @"no");

                [callable callWithObject:[payload copy] completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) return;

                        if (error) {
                            NSLog(@"PPLAB NotificationsV2 registration failed | reason=%@ appId=pro_ios scopes=%lu error=%@",
                                  safeReason.length > 0 ? safeReason : @"unknown",
                                  (unsigned long)notificationScopes.count,
                                  error.localizedDescription ?: @"unknown");
                            [strongSelf pp_finishNotificationV2RegistrationCycle];
                            return;
                        }

                        NSDictionary *response = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
                        if (![strongSelf pp_notificationV2RegistrationIsCurrentForUID:uid epoch:registrationEpoch]) {
                            NSLog(@"PPLAB NotificationsV2 registration ignored | reason=%@ appId=%@ auth_changed_or_stale=yes",
                                  safeReason.length > 0 ? safeReason : @"unknown",
                                  kPPProNotificationV2AppID);
                            [strongSelf pp_compensateStaleNotificationV2Registration:response
                                                                               uid:uid
                                                                    installationId:safeInstallationId
                                                                        environment:PPAdminNotificationEnvironment()
                                                                         completion:^{
                                [strongSelf pp_finishNotificationV2RegistrationCycle];
                            }];
                            return;
                        }

                        BOOL ok = [response[@"ok"] respondsToSelector:@selector(boolValue)] ? [response[@"ok"] boolValue] : NO;
                        NSArray *scopes = [response[@"scopes"] isKindOfClass:NSArray.class] ? response[@"scopes"] : notificationScopes;
                        if (ok) {
                            NSString *bindingGeneration = PPAdminRouteTrimmedString(response[@"bindingGeneration"]);
                            NSString *fcmTokenHash = PPAdminRouteTrimmedString(response[@"fcmTokenHash"]);
                            NSString *environment = PPAdminRouteTrimmedString(response[@"environment"]);
                            if (environment.length == 0) environment = PPAdminNotificationEnvironment();
                            if (bindingGeneration.length > 0 && fcmTokenHash.length > 0) {
                                NSDictionary *binding = @{
                                    @"uid": uid,
                                    @"installationId": safeInstallationId,
                                    @"appId": kPPProNotificationV2AppID,
                                    @"environment": environment,
                                    @"bindingGeneration": bindingGeneration,
                                    @"fcmTokenHash": fcmTokenHash
                                };
                                [NSUserDefaults.standardUserDefaults setObject:binding forKey:kPPProNotificationV2BindingDefaultsKey];
                            }
                        }
                        NSLog(@"PPLAB NotificationsV2 registration finish | reason=%@ ok=%@ appId=%@ scopes=%lu isActive=%@",
                              safeReason.length > 0 ? safeReason : @"unknown",
                              ok ? @"yes" : @"no",
                              PPAdminRouteTrimmedString(response[@"appId"]).length > 0 ? PPAdminRouteTrimmedString(response[@"appId"]) : @"pro_ios",
                              (unsigned long)scopes.count,
                              [response[@"isActive"] respondsToSelector:@selector(boolValue)] && [response[@"isActive"] boolValue] ? @"yes" : @"no");
                        [strongSelf pp_finishNotificationV2RegistrationCycle];
                    });
                }];
            });
        }];
    }];
}

- (void)pp_finishNotificationV2RegistrationCycle
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_finishNotificationV2RegistrationCycle];
        });
        return;
    }

    self.notificationV2RegistrationInFlight = NO;
    if (self.notificationV2LogoutBarrierActive) {
        self.notificationV2PendingReason = nil;
        [self pp_releaseNotificationV2LogoutBarrierWaiters];
        return;
    }

    NSString *pendingReason = PPAdminRouteTrimmedString(self.notificationV2PendingReason);
    self.notificationV2PendingReason = nil;
    if (pendingReason.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_attemptNotificationV2RegistrationForReason:pendingReason];
        });
    }
}

#pragma mark - Get Current Token

// Method to get current FCM token
- (NSString *)getCurrentFCMToken {
    return self.fcmToken ?: @"";
}

// Method to check if token is available
- (BOOL)isFCMTokenAvailable {
    return self.fcmToken != nil && self.fcmToken.length > 0;
}

- (BOOL)pp_showProInAppNotificationWithPayload:(NSDictionary *)payload
                                         title:(NSString *)title
                                          body:(NSString *)body {
    NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? payload : @{};
    NSString *type = [PPAdminRouteTrimmedString(safePayload[@"type"]) lowercaseString];
    NSString *notificationType = [PPAdminRouteTrimmedString(safePayload[@"notificationType"]) lowercaseString];
    NSString *effectiveType = type.length > 0 ? type : notificationType;
    NSString *orderId = PPAdminRouteTrimmedString(safePayload[@"orderId"]);
    NSString *effectiveTitle = title.length > 0 ? title : PPAdminRouteTrimmedString(safePayload[@"title"]);
    NSString *effectiveBody = body.length > 0 ? body : PPAdminRouteTrimmedString(safePayload[@"body"]);
    NSString *subtitle = effectiveBody.length > 0 ? effectiveBody : kLang(@"New notification");

    if (![PPProInAppNotificationPresenter notificationPreferencesAllowPayload:safePayload]) {
        NSLog(@"[Push] Pro foreground notification suppressed by local notification settings. type=%@", effectiveType);
        return YES;
    }

    if (PPAdminIsCompanyDeliveryPayload(safePayload)) {
        [[PPProInAppNotificationPresenter sharedPresenter] showCompanyDeliveryNotificationWithPayload:safePayload
                                                                                                title:effectiveTitle
                                                                                             subtitle:subtitle];
        return YES;
    }
    if ([effectiveType hasPrefix:@"order"]) {
        [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:safePayload
                                                                                 title:effectiveTitle
                                                                              subtitle:subtitle
                                                                              iconName:@"shippingbox.fill"
                                                                           accentColor:AppPrimaryClr];
        return YES;
    }
    if ([effectiveType isEqualToString:@"provider_new_fulfillment"]) {
        [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:safePayload
                                                                                 title:effectiveTitle
                                                                              subtitle:effectiveBody
                                                                              iconName:@"shippingbox.fill"
                                                                           accentColor:AppPrimaryClr];
        return YES;
    }
    if ([effectiveType hasPrefix:@"delivery"] || [effectiveType hasPrefix:@"request"] || [effectiveType hasPrefix:@"drivers_delivery_requested"] || [effectiveType hasPrefix:@"customer_delivery_requested"]) {
        [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:safePayload
                                                                                 title:effectiveTitle
                                                                              subtitle:effectiveBody
                                                                              iconName:@"bicycle"
                                                                           accentColor:UIColor.systemOrangeColor];
        return YES;
    }
    if (effectiveType.length > 0 || effectiveTitle.length > 0 || effectiveBody.length > 0) {
        [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:safePayload
                                                                                 title:effectiveTitle
                                                                              subtitle:effectiveBody
                                                                              iconName:@"bell.badge.fill"
                                                                           accentColor:AppPrimaryClr];
        return YES;
    }
    return NO;
}

- (void)pp_showProInAppNotificationAfterActivationWithPayload:(NSDictionary *)payload
                                                        title:(NSString *)title
                                                         body:(NSString *)body
                                                      attempt:(NSInteger)attempt {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            [self pp_showProInAppNotificationWithPayload:payload title:title body:body];
            return;
        }
        if (attempt >= 8) {
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pp_showProInAppNotificationAfterActivationWithPayload:payload title:title body:body attempt:attempt + 1];
        });
    });
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
         willPresentNotification:(UNNotification *)notification
           withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    (void)center;
    UNNotificationContent *content = notification.request.content;
    NSDictionary *payload = [content.userInfo isKindOfClass:NSDictionary.class] ? content.userInfo : @{};
    if (PPAdminPayloadTargetsOtherApp(payload)) {
        completionHandler(UNNotificationPresentationOptionNone);
        return;
    }
    
    NSString *title = PPAdminRouteTrimmedString(content.title);
    NSString *body = PPAdminRouteTrimmedString(content.body);
    BOOL didShowLocalNotification = [self pp_showProInAppNotificationWithPayload:payload title:title body:body];

    if (didShowLocalNotification) {
        if ([PPProInAppNotificationPresenter notificationPreferencesAllowSoundForPayload:payload]) {
            [[PPProInAppNotificationPresenter sharedPresenter] playNotificationSound];
        }
        completionHandler(UNNotificationPresentationOptionNone);
        return;
    }

    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionList |
                          UNNotificationPresentationOptionSound);
        return;
    }
    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler {
    (void)center;
    NSDictionary *payload = [response.notification.request.content.userInfo isKindOfClass:NSDictionary.class]
        ? response.notification.request.content.userInfo
        : @{};
    if (PPAdminPayloadTargetsOtherApp(payload)) {
        if (completionHandler) completionHandler();
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        SceneDelegate *sceneDelegate = PPProActiveSceneDelegate();
        if (sceneDelegate) {
            [sceneDelegate openNotificationsTabFromNotificationPayload:payload];
        } else {
            NSLog(@"[NotificationRoute] No active SceneDelegate available for notification response.");
        }
        if (completionHandler) {
            completionHandler();
        }
    });
}

#pragma mark - Remote Notification (Data-Only Handling)

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (PPAdminPayloadTargetsOtherApp(userInfo)) {
        if (completionHandler) {
            completionHandler(UIBackgroundFetchResultNoData);
        }
        return;
    }
    NSString *type = [userInfo[@"type"] isKindOfClass:NSString.class] ? userInfo[@"type"] : @"";
    NSString *notificationType = [userInfo[@"notificationType"] isKindOfClass:NSString.class] ? userInfo[@"notificationType"] : @"";
    NSString *effectiveType = type.length > 0 ? type : notificationType;
    NSString *orderId = [[userInfo[@"orderId"] isKindOfClass:NSString.class] ? userInfo[@"orderId"] : @""
                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *title = [userInfo[@"title"] isKindOfClass:NSString.class] ? userInfo[@"title"] : kLang(@"pp_pro_notification_new_delivery_request_title");
    NSString *body = [userInfo[@"body"] isKindOfClass:NSString.class] ? userInfo[@"body"] : kLang(@"pp_pro_notification_new_delivery_request_body");
    
    NSLog(@"[Push] didReceiveRemoteNotification | type=%@ notificationType=%@ effectiveType=%@ orderId=%@ title=%@ body=%@",
          type, notificationType, effectiveType, orderId, title, body);
    
    if (application.applicationState == UIApplicationStateActive) {
        BOOL didShowLocalNotification = NO;
        BOOL allowsProForegroundAlert = [PPProInAppNotificationPresenter notificationPreferencesAllowPayload:userInfo];
        if (!allowsProForegroundAlert) {
            didShowLocalNotification = YES;
            NSLog(@"[Push] Pro data notification suppressed by local notification settings. type=%@", effectiveType);
        } else if (PPAdminIsCompanyDeliveryPayload(userInfo)) {
            [[PPProInAppNotificationPresenter sharedPresenter] showCompanyDeliveryNotificationWithPayload:userInfo
                                                                                                    title:title
                                                                                                 subtitle:body];
            didShowLocalNotification = YES;
            NSLog(@"[Push] Showing in-app company delivery notification banner");
        } else if ([effectiveType hasPrefix:@"delivery"] || [effectiveType hasPrefix:@"request"] || [effectiveType hasPrefix:@"drivers_delivery_requested"] || [effectiveType hasPrefix:@"customer_delivery_requested"]) {
            [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:userInfo
                                                                                     title:title
                                                                                  subtitle:body
                                                                                  iconName:@"bicycle"
                                                                               accentColor:UIColor.systemOrangeColor];
            didShowLocalNotification = YES;
            NSLog(@"[Push] Showing in-app delivery notification banner");
        } else if ([effectiveType isEqualToString:@"provider_new_fulfillment"]) {
            [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:userInfo
                                                                                     title:title
                                                                                  subtitle:body
                                                                                  iconName:@"shippingbox.fill"
                                                                               accentColor:AppPrimaryClr];
            didShowLocalNotification = YES;
            NSLog(@"[Push] Showing in-app fulfillment notification banner");
        } else if ([effectiveType hasPrefix:@"order"]) {
            [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:userInfo
                                                                                     title:title
                                                                                  subtitle:body
                                                                                  iconName:@"shippingbox.fill"
                                                                               accentColor:AppPrimaryClr];
            didShowLocalNotification = YES;
            NSLog(@"[Push] Showing in-app order notification banner");
        } else if (type.length > 0 || notificationType.length > 0) {
            [[PPProInAppNotificationPresenter sharedPresenter] showNotificationWithPayload:userInfo
                                                                                     title:title
                                                                                  subtitle:body
                                                                                  iconName:@"bell.badge.fill"
                                                                               accentColor:AppPrimaryClr];
            didShowLocalNotification = YES;
            NSLog(@"[Push] Showing generic in-app notification banner");
        }
    }

    if ((PPAdminIsCompanyDeliveryPayload(userInfo) || [effectiveType hasPrefix:@"delivery"] || [effectiveType hasPrefix:@"request"] || [effectiveType hasPrefix:@"drivers_delivery_requested"] || [effectiveType hasPrefix:@"customer_delivery_requested"] || [effectiveType isEqualToString:@"provider_new_fulfillment"] || [effectiveType hasPrefix:@"order"] || type.length > 0 || notificationType.length > 0) &&
        [PPProInAppNotificationPresenter notificationPreferencesAllowSoundForPayload:userInfo]) {
        [[PPProInAppNotificationPresenter sharedPresenter] playNotificationSound];
    }
    
    if (completionHandler) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}





// =======================================================================================================================================================================/

- (void)setupAppAppearance {
    NSLog(@"[AppDelegate] setupAppAppearance called");
    
    // Theme preference defaults to PPProThemePreferenceSystem via PPProCurrentThemePreference fallback

    NSLog(@"[AppDelegate] [Language languageVal] %ld",[Language languageVal]);
    //if(!Language.languageVal)
    //    [Language userSelectedLanguage:LanguageCode[1]];

}


#pragma mark - UISceneSession lifecycle



- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
