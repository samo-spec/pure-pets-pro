#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "YYKit.h"
#import "PPFirebaseCompat.h"
#import "PPProviderApplicationStatusViewController.h"
#import "PPDeliveryCompanyDetailViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPAlertHelper.h"
#import "NotificationManager+Targets.h"
#import "NotificationsListViewController.h"
#import "PPProInAppNotificationPresenter.h"
#import "PPStaffAuth.h"
#import "PPProRememberedAccountStore.h"
#import "PPProSessionFence.h"
#import "AppManager.h"
#import "AdminDashboardViewController.h"
#import "PurePetsPro-Swift.h"
#import "PPFunc.h"
#import <QuartzCore/QuartzCore.h>
@import GoogleSignIn;

extern NSString * const UserManagerAuthStateDidChangeNotification;

/// Login-in-progress flag — prevents SceneDelegate from re-routing while the
/// login controller's multi-step sign-in pipeline is active.
static BOOL _pp_adminLoginInProgress = NO;

BOOL PPAdminLoginInProgress(void) { return _pp_adminLoginInProgress; }
void PPAdminSetLoginInProgress(BOOL inProgress) { _pp_adminLoginInProgress = inProgress; }

@interface SceneDelegate ()
@property (nonatomic) AppRoot currentRoot;
@property (nonatomic) FIRAuthStateDidChangeListenerHandle authHandle;
@property (nonatomic) BOOL awaitingModel;
@property (nonatomic) BOOL pp_requiresForegroundUnlock;
@property (nonatomic) BOOL pp_isUnlockPromptRunning;
@property (nonatomic) BOOL pp_didAutoPromptForCurrentLockCycle;
@property (nonatomic) BOOL pp_requiresManualUnlockRetry;
@property (nonatomic) CFTimeInterval pp_lastUnlockPromptAt;
@property (nonatomic, strong, nullable) UIView *ppLockOverlay;
@property (nonatomic, strong, nullable) UIButton *ppUnlockButton;
@property (nonatomic) BOOL pp_skipNextDidBecomeActiveAutoPrompt;
@property (nonatomic) BOOL pp_autoPresentProviderStatusOnNextRoot;
@property (nonatomic, strong) NSDate *pp_splashAppearDate;
@property (nonatomic, copy, nullable) NSDictionary *pp_pendingCompanyDeliveryPayload;
@property (nonatomic, copy, nullable) NSDictionary *pp_pendingNotificationRoutePayload;
@property (nonatomic, strong, nullable) NSUUID *pp_pendingNotificationEpoch;
@property (nonatomic, strong, nullable) NSUUID *pp_pendingCompanyDeliveryEpoch;
@property (nonatomic, strong, nullable) NSUUID *pp_companyResolutionID;
@property (nonatomic, copy, nullable) NSString *pp_lastNotificationRouteSignature;
@property (nonatomic) CFTimeInterval pp_lastNotificationRouteAt;
@property (nonatomic) BOOL pp_isResolvingCompanyDeliveryNotification;
@property (nonatomic) NSUInteger pp_proAccessRoutingGeneration;
@property (nonatomic) NSUInteger pp_rootTransitionGeneration;
@property (nonatomic, copy, nullable) NSString *pp_currentRootOwnershipKey;
@property (nonatomic, strong, nullable) UIView *pp_transitionPrivacyCurtain;
@property (nonatomic, strong, nullable) UILabel *pp_transitionCurtainStatusLabel;
@property (nonatomic, copy, nullable) NSString *pp_pendingReauthUID;
@property (nonatomic, assign) BOOL pp_pendingAddAccountMode;
@property (nonatomic, assign) BOOL pp_coldRestoreAttempted;
- (void)setRoot:(AppRoot)target animated:(BOOL)animated completion:(void (^ _Nullable)(void))completion;
- (void)pp_installRoot:(AppRoot)target animated:(BOOL)animated generation:(NSUInteger)generation completion:(void (^ _Nullable)(void))completion;
- (void)pp_routeAfterDeliveryCompanyPreflightForUID:(NSString *)uid
                                            userDoc:(NSDictionary *)userDoc
                                  hasProviderAccess:(BOOL)hasProviderAccess
                                       fallbackRoot:(AppRoot)fallbackRoot
                             autoPresentOnboarding:(BOOL)autoPresentOnboarding
                                            animated:(BOOL)animated;
- (void)pp_handleNotificationPayloadTap:(NSNotification *)notification;
- (void)pp_consumePendingNotificationRouteIfPossible;
- (UINavigationController * _Nullable)pp_notificationsNavigationController;
- (NotificationsListViewController *)pp_openNotificationsScreenAndReturnController;
- (void)pp_handleCompanyDeliveryNotification:(NSNotification *)notification;
- (void)pp_routePendingCompanyDeliveryNotificationIfPossible;
- (void)pp_presentPendingCompanyDeliveryWithProfile:(PPDeliveryCompanyProfile *)profile;
- (void)pp_applyNavigationAppearance;
@end

static NSTimeInterval const kPPSplashMinDisplayTime = 0.0;

static BOOL PPSceneUserDocIsBlocked(NSDictionary *root) {
     return [AppManager isProAccountBlocked:root];
}

static BOOL PPSceneUserHasPartnerApplicationInReview(UserModel *user) {
     if (![user isKindOfClass:UserModel.class]) {
          return NO;
     }
     NSString *status = [PPSafeString(user.partnerApplicationStatus).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
     return [status isEqualToString:@"pending"] ||
            [status isEqualToString:@"under_review"];
}

static BOOL PPSceneUserDocHasPartnerApplicationInReview(NSDictionary *root) {
     if (![root isKindOfClass:NSDictionary.class]) {
          return NO;
     }
     NSDictionary *onboarding = [root[@"onboarding"] isKindOfClass:NSDictionary.class] ? root[@"onboarding"] : @{};
     NSDictionary *partnerRoot = onboarding.count > 0 ? onboarding : root;
     NSString *status = [PPSafeString(partnerRoot[@"partnerApplicationStatus"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
     return [status isEqualToString:@"pending"] ||
            [status isEqualToString:@"under_review"];
}

static NSString *PPSceneNotificationRouteSignature(NSDictionary *payload)
{
     NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? payload : @{};
     NSMutableArray<NSString *> *parts = [NSMutableArray array];
     for (NSString *key in @[@"requestId", @"orderId", @"threadId", @"threadID", @"notificationId", @"nid", @"type", @"notificationType", @"route", @"title", @"body"]) {
          NSString *value = PPSafeString(safePayload[key]);
          if (value.length > 0) {
               [parts addObject:[NSString stringWithFormat:@"%@=%@", key, value.lowercaseString]];
          }
     }
     return parts.count > 0 ? [parts componentsJoinedByString:@"|"] : @"";
}

static NSString *PPSceneTrimmed(id value)
{
     return [PPSafeString(value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/// Driver pushes carry the task identity and the backend authority that owns
/// it. Workforce drivers receive route "driver_task" (FULFILLMENT_V1 or
/// COMPANY_DELIVERY_REQUEST); partner-company drivers receive route
/// "fleet_partner" with PARTNER_COMPANY_REQUEST. Company and dispatcher pushes
/// carry no authority and keep their existing destinations. Returns nil when
/// the payload is not a well-formed driver task.
static NSDictionary<NSString *, NSString *> *PPSceneDriverTaskRoute(NSDictionary *payload)
{
     NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? payload : @{};
     NSString *route = PPSceneTrimmed(safePayload[@"route"]).lowercaseString;
     NSString *authority = PPSceneTrimmed(safePayload[@"authority"]).uppercaseString;
     BOOL officialTask = [route isEqualToString:@"driver_task"] &&
          ([authority isEqualToString:@"FULFILLMENT_V1"] || [authority isEqualToString:@"COMPANY_DELIVERY_REQUEST"]);
     BOOL partnerTask = [route isEqualToString:@"fleet_partner"] && [authority isEqualToString:@"PARTNER_COMPANY_REQUEST"];
     if (!officialTask && !partnerTask) {
          return nil;
     }
     NSString *taskID = PPSceneTrimmed(safePayload[@"taskId"]);
     if (taskID.length == 0) taskID = PPSceneTrimmed(safePayload[@"requestId"]);
     if (taskID.length == 0 || taskID.length > 256 || [taskID containsString:@"/"]) {
          return nil;
     }
     NSString *companyID = PPSceneTrimmed(safePayload[@"carrierId"]);
     if (companyID.length == 0) companyID = PPSceneTrimmed(safePayload[@"companyId"]);
     if (companyID.length > 128 || [companyID containsString:@"/"]) companyID = @"";
     return @{ @"taskId": taskID, @"authority": authority, @"companyId": companyID };
}

static void PPProApplyThemeToWindow(UIWindow *window) {
     if (@available(iOS 13.0, *)) {
          NSString *pref = [[NSUserDefaults standardUserDefaults] stringForKey:@"themePreference"] ?: PPProThemePreferenceSystem;
          if ([pref isEqualToString:PPProThemePreferenceLight]) {
               window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
          } else if ([pref isEqualToString:PPProThemePreferenceDark]) {
               window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
          } else {
               window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
          }
     }
}

@implementation SceneDelegate

- (NSUUID *)pp_captureNotificationEpoch {
     FIRUser *user = [PPProSessionCoordinator.shared currentUser];
     return [[PPProSessionFence shared] captureForUID:user.uid ?: @"" activeUID:user.uid identity:user];
}

- (BOOL)pp_notificationEpochIsCurrent:(NSUUID *)epoch {
     FIRUser *user = [PPProSessionCoordinator.shared currentUser];
     return [[PPProSessionFence shared] accepts:epoch requestedUID:user.uid ?: @"" activeUID:user.uid identity:user];
}

- (void)pp_discardStaleNotificationRoutes {
     if (![self pp_notificationEpochIsCurrent:self.pp_pendingNotificationEpoch]) {
          self.pp_pendingNotificationRoutePayload = nil;
          self.pp_pendingNotificationEpoch = nil;
          self.pp_lastNotificationRouteSignature = nil;
          self.pp_lastNotificationRouteAt = 0;
     }
     if (![self pp_notificationEpochIsCurrent:self.pp_pendingCompanyDeliveryEpoch]) {
          self.pp_pendingCompanyDeliveryPayload = nil;
          self.pp_pendingCompanyDeliveryEpoch = nil;
          self.pp_companyResolutionID = nil;
          self.pp_isResolvingCompanyDeliveryNotification = NO;
     }
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
#if DEBUG
     if ([NSProcessInfo.processInfo.arguments containsObject:@"-PPProIdentityPortalUITest"]) {
          if (![scene isKindOfClass:UIWindowScene.class]) return;
          self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
          self.currentRoot = AppRootLogin;
          self.window.rootViewController = [[PPNavigationController alloc] initWithRootViewController:[AdminLoginViewController new]];
          PPProApplyThemeToWindow(self.window);
          [self.window makeKeyAndVisible];
          return;
     }
#endif
     
     
     [self setRoot:AppRootSplash animated:NO];
     self.pp_splashAppearDate = [NSDate date];
     static dispatch_once_t onceToken;
     dispatch_once(&onceToken, ^{
          // AppManager installs App Check provider factory before Firebase configure.
          [AppMgr configureFirebase];
     });
     
     // --- Core config ---
    

     // --- UI / Appearance ---
     [Styling setupFormAppearance];      // ✅ move from SceneDelegate
     [self pp_applyNavigationAppearance];
     
     if (![scene isKindOfClass:[UIWindowScene class]]) return;

     
    /*
     // Always start with splash
     //[self setRoot:AppRootSplash animated:NO];
     UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
     [appearance configureWithTransparentBackground];
     appearance.shadowColor = UIColor.clearColor;
     appearance.backgroundColor = UIColor.clearColor;
     
     [UINavigationBar appearance].standardAppearance = appearance;
     [UINavigationBar appearance].scrollEdgeAppearance = appearance;
     [UINavigationBar appearance].compactAppearance = appearance;
     [UINavigationBar appearance].tintColor = UIColor.clearColor;

     */
     
     UIWindowScene *windowScene = (UIWindowScene *)scene;
     if (!self.window) {
          self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
     }
     PPProApplyThemeToWindow(self.window);

     __weak typeof(self) weakSelf = self;
     [[PPProSessionCoordinator shared] performColdStartRecoveryCheckWithCompletion:^(BOOL recoveryRequired,
                                                                                     BOOL cleared,
                                                                                     __unused NSError * _Nullable recoveryError) {
          dispatch_async(dispatch_get_main_queue(), ^{
               __strong typeof(weakSelf) strongSelf = weakSelf;
               if (!strongSelf) return;
               if (recoveryRequired && !cleared) {
                    [strongSelf pp_hideTransitionPrivacyCurtain];
                    [strongSelf pp_applyAdminRoutingForAuthUser:nil animated:NO];
                    return;
               }
               if ([PPProRememberedAccountStore rolloutEnabled] && !strongSelf.pp_coldRestoreAttempted) {
                    strongSelf.pp_coldRestoreAttempted = YES;
                    [strongSelf pp_showTransitionPrivacyCurtainWithStatusKey:@"restore"];
                    [PPProSessionCoordinator.shared restoreLastActiveSessionOnColdLaunchWithCompletion:^(BOOL restored,
                                                                                                           BOOL requiresReauth,
                                                                                                           NSString * _Nullable uid,
                                                                                                           __unused NSError * _Nullable restoreErr) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                              __strong typeof(weakSelf) innerSelf = weakSelf;
                              if (!innerSelf) return;
                              [innerSelf pp_hideTransitionPrivacyCurtain];
                              if (restored) {
                                   [innerSelf pp_applyAdminRoutingForAuthUser:[PPProSessionCoordinator.shared currentUser] animated:YES];
                              } else {
                                   if (requiresReauth && uid.length > 0) {
                                        innerSelf.pp_pendingReauthUID = uid;
                                   }
                                   [innerSelf pp_applyAdminRoutingForAuthUser:nil animated:NO];
                              }
                         });
                    }];
               }
          });
     }];
     [[FUManager shared] startAuthListenerWithChangeBlock:^(FIRUser * _Nullable authUser,
                                                            UserModel * _Nullable userModel) {
          (void)userModel;
          dispatch_async(dispatch_get_main_queue(), ^{
               [weakSelf pp_applyAdminRoutingForAuthUser:authUser animated:YES];
          });
     }];
     
     
     
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(handleAuthChange)
                                                  name:UserManagerAuthStateDidChangeNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(handleAuthChange)
                                                  name:PPProSessionDidChangeActiveRuntimeNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleTransitionRecoveryRequired)
                                                  name:PPProSessionTransitionRecoveryRequiredNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleTransitionWillBegin:)
                                                  name:PPProSessionTransitionWillBeginNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleTransitionPhaseDidChange:)
                                                  name:PPProSessionTransitionPhaseDidChangeNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleSessionDidSuspend:)
                                                  name:PPProSessionDidSuspendNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleSessionDidCommitOrRollback:)
                                                  name:PPProSessionDidCommitNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleSessionDidCommitOrRollback:)
                                                  name:PPProSessionTransitionDidRollbackNotification
                                                object:nil];
     
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(handleAuthChange)
                                                  name:LanguageDidChangeNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleNotificationPayloadTap:)
                                                  name:PPProNotificationPayloadTappedNotification
                                                object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(pp_handleCompanyDeliveryNotification:)
                                                  name:PPProCompanyDeliveryNotificationTappedNotification
                                                object:nil];
     NSDictionary *notificationPayload = connectionOptions.notificationResponse.notification.request.content.userInfo;
     if ([notificationPayload isKindOfClass:NSDictionary.class] &&
         [AppDelegate pp_isNotificationPayloadRoutable:notificationPayload]) {
          self.pp_pendingNotificationRoutePayload = [notificationPayload copy];
          self.pp_pendingNotificationEpoch = [self pp_captureNotificationEpoch];
     }
     self.pp_requiresForegroundUnlock = NO;
     self.pp_didAutoPromptForCurrentLockCycle = NO;
     self.pp_requiresManualUnlockRetry = NO;
     self.pp_skipNextDidBecomeActiveAutoPrompt = NO;
     self.pp_lastUnlockPromptAt = 0;
     [self handleAuthChange]; // set initial root
     
     
     
     
     
     //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadRootViewControllerForLanguageChange) name:LanguageDidChangeNotification object:nil];
}

- (void)pp_startFlowForAuthUser:(FIRUser * _Nullable)authUser userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
     (void)userModel;
     [self pp_applyAdminRoutingForAuthUser:authUser animated:animated];
}

- (void)pp_applyAdminRoutingForAuthUser:(FIRUser * _Nullable)authUser animated:(BOOL)animated {
     if ([PPProSessionCoordinator.shared requiresTransitionRecovery]) {
          ++self.pp_proAccessRoutingGeneration;
          self.awaitingModel = NO;
          self.pp_requiresForegroundUnlock = NO;
          self.pp_didAutoPromptForCurrentLockCycle = NO;
          self.pp_requiresManualUnlockRetry = NO;
          [self pp_hideLockOverlay];
          [self pp_discardStaleNotificationRoutes];
          [self setRoot:AppRootLogin animated:animated];
          return;
     }
     if ([PPProSessionCoordinator.shared currentUser] != authUser) return;
     [self pp_discardStaleNotificationRoutes];
     // ── Guard: don't interfere while the login controller's pipeline is active ──
     if (PPAdminLoginInProgress()) {
          NSLog(@"[SceneDelegate] ⏸ skipping routing — login in progress");
          return;
     }

     if (!authUser) {
          ++self.pp_proAccessRoutingGeneration;
          self.awaitingModel = NO;
          self.pp_requiresForegroundUnlock = NO;
          self.pp_didAutoPromptForCurrentLockCycle = NO;
          self.pp_requiresManualUnlockRetry = NO;
          [self pp_hideLockOverlay];
          [self setRoot:AppRootLogin animated:animated];
          return;
     }

     __weak typeof(self) weakSelf = self;
     NSUInteger routingGeneration = ++self.pp_proAccessRoutingGeneration;
     [AppMgr checkIfUserWithUID:authUser.uid canAccessPro:^(BOOL isAllowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf || routingGeneration != weakSelf.pp_proAccessRoutingGeneration ||
                    ![[PPProSessionCoordinator.shared currentUser].uid isEqualToString:authUser.uid]) {
                     return;
                }
                // Re-check: login controller may have started between the async gap
                if (PPAdminLoginInProgress()) {
                     NSLog(@"[SceneDelegate] ⏸ skipping post-access-check routing — login in progress");
                     return;
                }
                if (error) {
                     NSLog(@"[SceneDelegate] access check error: %@", error.localizedDescription);
                     weakSelf.pp_requiresForegroundUnlock = NO;
                     weakSelf.pp_didAutoPromptForCurrentLockCycle = NO;
                     weakSelf.pp_requiresManualUnlockRetry = NO;
                     [weakSelf pp_hideLockOverlay];
                     [weakSelf setRoot:AppRootLogin animated:animated];
                     return;
                }

                if (!isAllowed) {
                     weakSelf.pp_requiresForegroundUnlock = NO;
                     weakSelf.pp_didAutoPromptForCurrentLockCycle = NO;
                     weakSelf.pp_requiresManualUnlockRetry = NO;
                     [weakSelf pp_hideLockOverlay];

                     if (PPSceneUserDocIsBlocked(userDoc ?: @{})) {
                          [UserManager.shared forceSecuritySignOutWithCompletion:nil];
                          [weakSelf setRoot:AppRootLogin animated:animated];
                          return;
                     }

                     [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:authUser.uid
                                                                    userDoc:userDoc ?: @{}
                                                          hasProviderAccess:NO
                                                               fallbackRoot:AppRootProviderStatus
                                                    autoPresentOnboarding:!PPSceneUserDocHasPartnerApplicationInReview(userDoc ?: @{})
                                                                   animated:animated];
                     return;
                }

                [weakSelf startFlowForAuthUser:authUser userModel:nil animated:animated];
                if (weakSelf.pp_requiresForegroundUnlock) {
                     [weakSelf pp_showLockOverlayIfNeeded];
               }
          });
     }];
 }

- (void)pp_routeAfterDeliveryCompanyPreflightForUID:(NSString *)uid
                                             userDoc:(NSDictionary *)userDoc
                                   hasProviderAccess:(BOOL)hasProviderAccess
                                        fallbackRoot:(AppRoot)fallbackRoot
                             autoPresentOnboarding:(BOOL)autoPresentOnboarding
                                            animated:(BOOL)animated {
     if (!uid.length || PPSceneUserDocIsBlocked(userDoc ?: @{})) {
          self.pp_autoPresentProviderStatusOnNextRoot = autoPresentOnboarding;
          [self setRoot:fallbackRoot animated:animated];
          return;
     }

     NSUInteger routingGeneration = ++self.pp_proAccessRoutingGeneration;
     __weak typeof(self) weakSelf = self;
     [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles,
                                                                                  NSError * _Nullable error) {
          __strong typeof(weakSelf) self = weakSelf;
          if (!self || routingGeneration != self.pp_proAccessRoutingGeneration || PPAdminLoginInProgress()) {
               return;
          }

          NSString *activeUID = [PPProSessionCoordinator.shared activeUID] ?: @"";
          if (![activeUID isEqualToString:uid]) {
               return;
          }

          BOOL requiresSelection = NO;
          PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyService.shared preferredProfileFromProfiles:profiles ?: @[]
                                                                                         requiresSelection:&requiresSelection];
          if (profile.companyID.length > 0) {
               NSLog(@"[SceneDelegate] delivery company membership granted uid=%@ company=%@ role=%@ selection=%@",
                     uid, profile.companyID, profile.role, requiresSelection ? @"required" : @"resolved");
               // A usable workspace becomes the dashboard company (several are
               // ordered by preferredProfileFromProfiles:); a restricted
               // membership is never remembered.
               if (!profile.isRestrictedWorkspace) {
                    [PPDeliveryCompanyService.shared storeVerifiedProfile:profile];
               }
               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               [self showDeliveryWorkspaceForProfile:profile
                                 hasProviderDashboard:(fallbackRoot == AppRootDashboard)
                                             animated:animated];
               return;
          }

          if (error) {
               // A provider grant does not depend on the optional fleet lookup.
               // No driver capability is added without a resolved membership.
               if (hasProviderAccess) {
                    self.pp_autoPresentProviderStatusOnNextRoot = NO;
                    [self setRoot:fallbackRoot animated:animated];
                    return;
               }
               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               [self setRoot:AppRootLogin animated:animated completion:^{
               __strong typeof(weakSelf) self = weakSelf;
               if (!self || self.currentRoot != AppRootLogin || PPAdminLoginInProgress() ||
                   ![PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) return;
               [PPAlertHelper showThreeActionConfirmationIn:self.window.rootViewController
                                           title:kLang(@"ProAccess_CheckFailedTitle")
                                        subtitle:kLang(@"ProAccess_CheckFailedBody")
                                   primaryButton:kLang(@"TryAgain")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:kLang(@"ProAccess_BecomePartner")
                                  secondaryStyle:UIAlertActionStyleDefault
                                  tertiaryButton:kLang(@"ProAccess_UseAnotherAccount")
                                   tertiaryStyle:UIAlertActionStyleDefault
                                    primaryBlock:^{
                    if (![PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) return;
                    [weakSelf pp_applyAdminRoutingForAuthUser:PPProSessionCoordinator.shared.currentUser animated:YES];
               } secondaryBlock:^{
                    if (!weakSelf || ![PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) return;
                    [weakSelf cancelPendingProAccessRouting];
                    weakSelf.pp_autoPresentProviderStatusOnNextRoot = YES;
                    [weakSelf setRoot:AppRootProviderStatus animated:YES];
               } tertiaryBlock:^{
                    if ([PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) [UserManager.shared forceSecuritySignOutWithCompletion:nil];
               }];
               }];
               return;
          }
          if (!hasProviderAccess && fallbackRoot == AppRootProviderStatus && autoPresentOnboarding) {
               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               [self setRoot:AppRootLogin animated:animated completion:^{
               __strong typeof(weakSelf) self = weakSelf;
               if (!self || self.currentRoot != AppRootLogin || PPAdminLoginInProgress() ||
                   ![PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) return;
               [PPAlertHelper showInfoIn:self.window.rootViewController title:kLang(@"ProAccess_NotEnabledTitle")
                                subtitle:kLang(@"ProAccess_NotEnabledBody")
                           primaryButton:kLang(@"ProAccess_BecomePartner")
                         secondaryButton:kLang(@"ProAccess_UseAnotherAccount")
                            primaryBlock:^{
                    if (!weakSelf || ![PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) return;
                    [weakSelf cancelPendingProAccessRouting];
                    weakSelf.pp_autoPresentProviderStatusOnNextRoot = YES;
                    [weakSelf setRoot:AppRootProviderStatus animated:YES];
               } secondaryBlock:^{
                    if ([PPProSessionCoordinator.shared.currentUser.uid isEqualToString:uid]) [UserManager.shared forceSecuritySignOutWithCompletion:nil];
               }];
               }];
               return;
          }
          self.pp_autoPresentProviderStatusOnNextRoot = autoPresentOnboarding;
          [self setRoot:fallbackRoot animated:animated];
     }];
}

- (void)pp_rememberAuthorizedIdentity {
     if (![PPProRememberedAccountStore rolloutEnabled]) return;
     FIRUser *user = [PPProSessionCoordinator.shared currentUser];
     if (!user.uid.length) return;
     NSString *method = nil;
     for (id<FIRUserInfo> info in user.providerData) {
          if ([@[@"phone", @"apple.com", @"google.com"] containsObject:info.providerID]) {
               method = info.providerID;
               if ([method isEqualToString:@"phone"] && user.phoneNumber.length) break;
          }
     }
     if (!method) return;
     NSString *label = [PPProRememberedAccountStore maskedLabelForPhone:user.phoneNumber email:user.email];
     [PPProRememberedAccountStore rememberUID:user.uid
                                  maskedLabel:label
                                       method:method
                                       slotID:PPProSessionCoordinator.shared.activeSlot.slotID
                                        error:nil];
}

- (NSString *)pp_rootOwnershipKeyForTarget:(AppRoot)target companyProfile:(nullable PPDeliveryCompanyProfile *)profile {
     NSString *uid = [PPProSessionCoordinator.shared activeUID] ?: @"";
     NSUInteger generation = PPProSessionCoordinator.shared.sessionGeneration;
     BOOL recovery = PPProSessionCoordinator.shared.requiresTransitionRecovery;
     NSString *companyID = profile.companyID ?: @"";
     NSString *role = profile.role ?: @"";
     return [NSString stringWithFormat:@"%ld|%@|%lu|%d|%@|%@",
             (long)target, uid, (unsigned long)generation, recovery ? 1 : 0, companyID, role];
}

- (void)showDashboardWithDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile animated:(BOOL)animated {
     if (!profile.companyID.length) {
          [self setRoot:AppRootProviderStatus animated:animated];
          return;
     }

     [self cancelPendingProAccessRouting];
     [self pp_rememberAuthorizedIdentity];
     NSString *ownershipKey = [self pp_rootOwnershipKeyForTarget:AppRootDashboard companyProfile:profile];
     if (self.currentRoot == AppRootDashboard &&
         [self.pp_currentRootOwnershipKey isEqualToString:ownershipKey] &&
         self.window.rootViewController) {
          return;
     }
     self.pp_currentRootOwnershipKey = ownershipKey;
     self.currentRoot = AppRootDashboard;
     // Official root UITabBarController (replaces single UINavigationController)
     PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
     // Force view load so tabs exist before injecting profile
     [tabBar loadViewIfNeeded];
     if ([tabBar.viewControllers.firstObject isKindOfClass:UINavigationController.class]) {
          UINavigationController *dashNav = (UINavigationController *)tabBar.viewControllers.firstObject;
          if ([dashNav.viewControllers.firstObject isKindOfClass:AdminDashboardViewController.class]) {
               AdminDashboardViewController *dashboard = (AdminDashboardViewController *)dashNav.viewControllers.firstObject;
               [dashboard configureDeliveryCompanyProfile:profile];
          }
     }
     UIViewController *oldRoot = self.window.rootViewController;
     if (oldRoot.presentedViewController) {
          [oldRoot.presentedViewController dismissViewControllerAnimated:NO completion:nil];
     }
     self.window.rootViewController = tabBar;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
     [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];

     if (animated && oldRoot) {
          [UIView transitionWithView:self.window
                            duration:0.25
                             options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                          animations:nil
                          completion:nil];
     }
     [self pp_consumePendingNotificationRouteIfPossible];
     [self pp_presentPendingCompanyDeliveryWithProfile:profile];
}

- (void)showDeliveryWorkspaceForProfile:(PPDeliveryCompanyProfile *)profile
                     hasProviderDashboard:(BOOL)hasProviderDashboard
                                 animated:(BOOL)animated {
     // A tapped notification decides the first screen; a driver task route
     // opens the cockpit itself.
     BOOL hasPendingRoute = self.pp_pendingNotificationRoutePayload.count > 0 ||
                            self.pp_pendingCompanyDeliveryPayload.count > 0;
     [self showDashboardWithDeliveryCompanyProfile:profile animated:animated];
     if (hasPendingRoute || hasProviderDashboard || !profile.prefersDriverCockpit ||
         self.currentRoot != AppRootDashboard) {
          return;
     }
     // A driver-only or restricted account has no other work in Pro, so it
     // lands in its cockpit.
     [self openDriverCockpitWithTaskID:nil authority:nil companyID:nil animated:NO];
}

- (void)openDriverCockpitWithTaskID:(NSString *)taskID
                          authority:(NSString *)authority
                          companyID:(NSString *)companyID
                           animated:(BOOL)animated {
     UIViewController *root = self.window.rootViewController;
     UITabBarController *tabBar = [root isKindOfClass:UITabBarController.class] ? (UITabBarController *)root : nil;
     NSArray<UIViewController *> *tabs = tabBar ? tabBar.viewControllers : (root ? @[root] : @[]);
     UINavigationController *navigationController = nil;
     PPDriverCockpitHostController *existing = nil;
     // One cockpit per scene: reuse an open one on any tab before pushing.
     for (UIViewController *candidate in tabs) {
          if (![candidate isKindOfClass:UINavigationController.class]) continue;
          for (UIViewController *child in ((UINavigationController *)candidate).viewControllers) {
               if ([child isKindOfClass:PPDriverCockpitHostController.class]) {
                    navigationController = (UINavigationController *)candidate;
                    existing = (PPDriverCockpitHostController *)child;
                    break;
               }
          }
          if (existing) break;
     }
     if (!navigationController) {
          for (UIViewController *candidate in tabs) {
               if ([candidate isKindOfClass:UINavigationController.class] &&
                   [((UINavigationController *)candidate).viewControllers.firstObject isKindOfClass:AdminDashboardViewController.class]) {
                    navigationController = (UINavigationController *)candidate;
                    break;
               }
          }
     }
     if (!navigationController) {
          NSLog(@"[DriverCockpit] Dashboard navigation is not available; cockpit not opened.");
          return;
     }

     NSString *safeTaskID = PPSceneTrimmed(taskID);
     NSString *safeAuthority = PPSceneTrimmed(authority);
     NSString *safeCompanyID = PPSceneTrimmed(companyID);
     NSUUID *cockpitEpoch = [self pp_captureNotificationEpoch];
     void (^showCockpit)(void) = ^{
          if (![self pp_notificationEpochIsCurrent:cockpitEpoch]) return;
          if (tabBar && tabBar.selectedViewController != navigationController) {
               tabBar.selectedViewController = navigationController;
          }
          if (existing) {
               if (navigationController.topViewController != existing) {
                    [navigationController popToViewController:existing animated:animated];
               }
               if (safeTaskID.length > 0) {
                    [existing focusWithTaskID:safeTaskID authority:safeAuthority companyID:safeCompanyID];
               }
               return;
          }
          PPDriverCockpitHostController *cockpit = safeTaskID.length > 0
               ? [[PPDriverCockpitHostController alloc] initWithFocusTaskID:safeTaskID authority:safeAuthority companyID:safeCompanyID]
               : [[PPDriverCockpitHostController alloc] init];
          [navigationController pushViewController:cockpit animated:animated];
     };

     UIViewController *presenter = tabBar ?: navigationController;
     UIViewController *presented = presenter.presentedViewController;
     if (presented && !presented.isBeingDismissed) {
          [presenter dismissViewControllerAnimated:animated completion:showCockpit];
     } else {
          showCockpit();
     }
}

- (void)pp_handleCompanyDeliveryNotification:(NSNotification *)notification {
     [self pp_discardStaleNotificationRoutes];
     NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:
                                     [notification.userInfo isKindOfClass:NSDictionary.class] ? notification.userInfo : @{}];
     NSString *requestID = PPSafeString(notification.object);
     if (requestID.length > 0 && PPSafeString(payload[@"requestId"]).length == 0) {
          payload[@"requestId"] = requestID;
     }
     if (![AppDelegate pp_isNotificationPayloadRoutable:payload]) return;
     // A driver's own task opens the driver cockpit, never the dispatcher's
     // request detail. Inbox rows and banners reach this handler too.
     NSDictionary<NSString *, NSString *> *driverRoute = PPSceneDriverTaskRoute(payload);
     if (driverRoute) {
          if (self.currentRoot != AppRootDashboard) {
               self.pp_pendingNotificationRoutePayload = payload.copy;
               self.pp_pendingNotificationEpoch = [self pp_captureNotificationEpoch];
               return;
          }
          [self openDriverCockpitWithTaskID:driverRoute[@"taskId"]
                                  authority:driverRoute[@"authority"]
                                  companyID:driverRoute[@"companyId"]
                                   animated:YES];
          return;
     }
     if (PPSafeString(payload[@"requestId"]).length == 0) {
          return;
     }
     self.pp_pendingCompanyDeliveryPayload = payload.copy;
     self.pp_pendingCompanyDeliveryEpoch = [self pp_captureNotificationEpoch];
     [self pp_routePendingCompanyDeliveryNotificationIfPossible];
}

- (void)pp_routePendingCompanyDeliveryNotificationIfPossible {
     [self pp_discardStaleNotificationRoutes];
     NSDictionary *payload = self.pp_pendingCompanyDeliveryPayload;
     NSString *requestID = PPSafeString(payload[@"requestId"]);
     NSString *uid = [PPProSessionCoordinator.shared activeUID] ?: @"";
     if (requestID.length == 0 || uid.length == 0 || self.pp_isResolvingCompanyDeliveryNotification) {
          return;
     }

     self.pp_isResolvingCompanyDeliveryNotification = YES;
     NSUUID *epoch = self.pp_pendingCompanyDeliveryEpoch;
     NSUUID *resolutionID = [NSUUID UUID];
     self.pp_companyResolutionID = resolutionID;
     __weak typeof(self) weakSelf = self;
     [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error) {
          __strong typeof(weakSelf) self = weakSelf;
          if (!self || ![self.pp_companyResolutionID isEqual:resolutionID]) return;
          self.pp_isResolvingCompanyDeliveryNotification = NO;
          self.pp_companyResolutionID = nil;
          if (![self pp_notificationEpochIsCurrent:epoch]) { [self pp_discardStaleNotificationRoutes]; return; }
          if (![self.pp_pendingCompanyDeliveryPayload isEqual:payload]) {
               [self pp_routePendingCompanyDeliveryNotificationIfPossible];
               return;
          }

          if (error || profiles.count == 0) {
               NSLog(@"[CompanyDeliveryPush] Unable to resolve active company membership: %@",
                     error.localizedDescription ?: @"no active membership");
               return;
          }

          NSString *companyID = PPSafeString(payload[@"companyId"]);
          PPDeliveryCompanyProfile *profile = nil;
          for (PPDeliveryCompanyProfile *candidate in profiles) {
               if (companyID.length == 0 || [candidate.companyID isEqualToString:companyID]) {
                    profile = candidate;
                    break;
               }
          }
          if (!profile) {
               NSLog(@"[CompanyDeliveryPush] Notification company is not available to the signed-in user.");
               return;
          }

          [PPDeliveryCompanyService.shared storeVerifiedProfile:profile];
          UINavigationController *navigationController = nil;
          AdminDashboardViewController *dashboard = nil;
          if ([self.window.rootViewController isKindOfClass:UINavigationController.class]) {
               navigationController = (UINavigationController *)self.window.rootViewController;
               if ([navigationController.viewControllers.firstObject isKindOfClass:AdminDashboardViewController.class]) {
                    dashboard = (AdminDashboardViewController *)navigationController.viewControllers.firstObject;
               }
          } else if ([self.window.rootViewController isKindOfClass:UITabBarController.class]) {
               UITabBarController *tabBar = (UITabBarController *)self.window.rootViewController;
               for (UIViewController *vc in tabBar.viewControllers) {
                    if ([vc isKindOfClass:UINavigationController.class]) {
                         UINavigationController *nav = (UINavigationController *)vc;
                         if ([nav.viewControllers.firstObject isKindOfClass:AdminDashboardViewController.class]) {
                              navigationController = nav;
                              dashboard = (AdminDashboardViewController *)nav.viewControllers.firstObject;
                              break;
                         }
                    }
               }
          }
          if (self.currentRoot != AppRootDashboard || !dashboard) {
               [self showDashboardWithDeliveryCompanyProfile:profile animated:YES];
               return;
          }
          [dashboard configureDeliveryCompanyProfile:profile];
          [self pp_presentPendingCompanyDeliveryWithProfile:profile];
     }];
}

- (void)pp_presentPendingCompanyDeliveryWithProfile:(PPDeliveryCompanyProfile *)profile {
     [self pp_discardStaleNotificationRoutes];
     NSDictionary *payload = self.pp_pendingCompanyDeliveryPayload;
     NSString *requestID = PPSafeString(payload[@"requestId"]);
     NSString *companyID = PPSafeString(payload[@"companyId"]);
     if (requestID.length == 0 ||
         profile.companyID.length == 0 ||
         (companyID.length > 0 && ![companyID isEqualToString:profile.companyID])) {
          return;
     }

     UINavigationController *navigationController = nil;
     if ([self.window.rootViewController isKindOfClass:UINavigationController.class]) {
          navigationController = (UINavigationController *)self.window.rootViewController;
     } else if ([self.window.rootViewController isKindOfClass:UITabBarController.class]) {
          UITabBarController *tabBar = (UITabBarController *)self.window.rootViewController;
          // Prefer the dashboard tab for company delivery detail
          for (UIViewController *vc in tabBar.viewControllers) {
               if ([vc isKindOfClass:UINavigationController.class]) {
                    UINavigationController *nav = (UINavigationController *)vc;
                    if ([nav.viewControllers.firstObject isKindOfClass:AdminDashboardViewController.class]) {
                         navigationController = nav;
                         // Ensure dashboard tab is selected before pushing
                         tabBar.selectedViewController = nav;
                         break;
                    }
               }
          }
          if (!navigationController && [tabBar.selectedViewController isKindOfClass:UINavigationController.class]) {
               navigationController = (UINavigationController *)tabBar.selectedViewController;
          }
     }
     if (!navigationController) {
          return;
     }

     self.pp_pendingCompanyDeliveryPayload = nil;
     PPDeliveryCompanyDetailViewController *detail =
          [[PPDeliveryCompanyDetailViewController alloc] initWithRequestID:requestID profile:profile];
     [navigationController pushViewController:detail animated:YES];
}

- (void)pp_handleNotificationPayloadTap:(NSNotification *)notification
{
     NSDictionary *payload = [notification.userInfo isKindOfClass:NSDictionary.class] ? notification.userInfo : @{};
     [self openNotificationsTabFromNotificationPayload:payload];
}

- (void)openNotificationsTabFromNotificationPayload:(NSDictionary *)payload
{
     NSDictionary *safePayload = [payload isKindOfClass:NSDictionary.class] ? [payload copy] : nil;
     if (![AppDelegate pp_isNotificationPayloadRoutable:safePayload]) return;
     NSString *signature = PPSceneNotificationRouteSignature(safePayload);
     CFTimeInterval now = CACurrentMediaTime();
     if (signature.length > 0 &&
         [self.pp_lastNotificationRouteSignature isEqualToString:signature] &&
         (now - self.pp_lastNotificationRouteAt) < 1.5) {
          NSLog(@"[NotificationRoute] Ignoring duplicate notification route for signature=%@", signature);
          return;
     }
     self.pp_lastNotificationRouteSignature = signature;
     self.pp_lastNotificationRouteAt = now;
     if (safePayload.count == 0) {
          NSLog(@"[NotificationRoute] Invalid or empty notification payload received. Skipping direct notification route.");
     }

     self.pp_pendingNotificationRoutePayload = safePayload;
     self.pp_pendingNotificationEpoch = [self pp_captureNotificationEpoch];
     [self pp_consumePendingNotificationRouteIfPossible];
}

- (void)pp_consumePendingNotificationRouteIfPossible
{
     [self pp_discardStaleNotificationRoutes];
     if (self.pp_pendingNotificationRoutePayload.count == 0) {
          return;
     }

     if (self.currentRoot != AppRootDashboard || !self.window.rootViewController) {
          NSLog(@"[NotificationRoute] Dashboard root is not ready yet. Deferring notification route.");
          return;
     }

     NSDictionary<NSString *, NSString *> *driverRoute = PPSceneDriverTaskRoute(self.pp_pendingNotificationRoutePayload);
     if (driverRoute) {
          // Opened before the notifications tab is selected so the driver goes
          // straight to the task without a tab flicker.
          self.pp_pendingNotificationRoutePayload = nil;
          [self openDriverCockpitWithTaskID:driverRoute[@"taskId"]
                                  authority:driverRoute[@"authority"]
                                  companyID:driverRoute[@"companyId"]
                                   animated:YES];
          return;
     }

     UINavigationController *navigationController = [self pp_notificationsNavigationController];
     if (!navigationController) {
          NSLog(@"[NotificationRoute] Missing root tab bar and navigation controller. Deferring notification route.");
          return;
     }

     NSDictionary *payload = self.pp_pendingNotificationRoutePayload;
     NSUUID *epoch = self.pp_pendingNotificationEpoch;
     self.pp_pendingNotificationRoutePayload = nil;
     self.pp_pendingNotificationEpoch = nil;
     __weak typeof(self) weakSelf = self;
     [NotificationManager routePayload:payload
              fromNavigationController:navigationController
                             presenter:navigationController.topViewController ?: navigationController
                            completion:^(BOOL handled) {
          if (handled) {
               return;
          }
          __strong typeof(weakSelf) self = weakSelf;
          if (!self || ![self pp_notificationEpochIsCurrent:epoch]) return;
          NotificationsListViewController *notificationsController = [self pp_openNotificationsScreenAndReturnController];
          [notificationsController handleNotificationRoutePayload:payload];
     }];
}

- (UINavigationController *)pp_notificationsNavigationController
{
     UIViewController *root = self.window.rootViewController;
     if ([root isKindOfClass:UITabBarController.class]) {
          UITabBarController *tabBarController = (UITabBarController *)root;
          // Prefer the Notifications tab specifically when using official root tab bar
          for (UIViewController *vc in tabBarController.viewControllers) {
               if ([vc isKindOfClass:UINavigationController.class]) {
                    UINavigationController *nav = (UINavigationController *)vc;
                    for (UIViewController *child in nav.viewControllers) {
                         if ([child isKindOfClass:NotificationsListViewController.class]) {
                              // Ensure that tab is selected for visible routing
                              if (tabBarController.selectedViewController != nav) {
                                   tabBarController.selectedViewController = nav;
                              }
                              return nav;
                         }
                    }
                    // Fallback: check if nav's root is NotificationsListViewController
                    if ([nav.viewControllers.firstObject isKindOfClass:NotificationsListViewController.class]) {
                         if (tabBarController.selectedViewController != nav) {
                              tabBarController.selectedViewController = nav;
                         }
                         return nav;
                    }
               }
          }
          // Fallback to selected controller (legacy behavior)
          UIViewController *selectedController = tabBarController.selectedViewController;
          if ([selectedController isKindOfClass:UINavigationController.class]) {
               return (UINavigationController *)selectedController;
          }
          if ([selectedController.navigationController isKindOfClass:UINavigationController.class]) {
               return selectedController.navigationController;
          }
     }

     if ([root isKindOfClass:UINavigationController.class]) {
          NSLog(@"[NotificationRoute] Root tab bar not available. Using navigation stack fallback for Notifications.");
          return (UINavigationController *)root;
     }

     if ([root.navigationController isKindOfClass:UINavigationController.class]) {
          NSLog(@"[NotificationRoute] Root tab bar not available. Using navigation stack fallback for Notifications.");
          return root.navigationController;
     }

     return nil;
}

- (NotificationsListViewController *)pp_openNotificationsScreenAndReturnController
{
     UINavigationController *navigationController = [self pp_notificationsNavigationController];
     if (!navigationController) {
          return [NotificationsListViewController new];
     }

     NSEnumerator<UIViewController *> *reverseEnumerator = navigationController.viewControllers.reverseObjectEnumerator;
     for (UIViewController *controller in reverseEnumerator) {
          if ([controller isKindOfClass:NotificationsListViewController.class]) {
               [navigationController popToViewController:controller animated:NO];
               return (NotificationsListViewController *)controller;
          }
     }

     NotificationsListViewController *notificationsController = [[NotificationsListViewController alloc] init];
     [navigationController pushViewController:notificationsController animated:YES];
     return notificationsController;
}

- (void)pp_setRoot:(AppRoot)target userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
     NSString *ownershipKey = [self pp_rootOwnershipKeyForTarget:target companyProfile:nil];
     if (target == self.currentRoot &&
         [self.pp_currentRootOwnershipKey isEqualToString:ownershipKey] &&
         self.window.rootViewController) return;

     // If transitioning away from splash, respect minimum display time
     if (self.currentRoot == AppRootSplash && target != AppRootSplash && self.pp_splashAppearDate) {
          NSTimeInterval elapsed = -[self.pp_splashAppearDate timeIntervalSinceNow];
          NSTimeInterval remaining = kPPSplashMinDisplayTime - elapsed;
          if (remaining > 0.05) {
               __weak typeof(self) weakSelf = self;
               AppRoot capturedTarget = target;
               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                              dispatch_get_main_queue(), ^{
                    weakSelf.currentRoot = AppRootSplash;
                    [weakSelf pp_setRoot:capturedTarget userModel:userModel animated:animated];
               });
               return;
          }
     }

     self.pp_currentRootOwnershipKey = ownershipKey;
     self.currentRoot = target;
     
     if (target == AppRootDashboard) {
          PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
          UIViewController *old = self.window.rootViewController;
          if (old.presentedViewController) {
               [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
          }
          self.window.rootViewController = tabBar;
          PPProApplyThemeToWindow(self.window);
          [self.window makeKeyAndVisible];
          [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];
          [self pp_consumePendingNotificationRouteIfPossible];
          return;
     }
     UIViewController *root;
     switch (target) {
          case AppRootSplash:    root = [SplashViewController new]; break;
          case AppRootLogin: {
               AdminLoginViewController *loginVC = [AdminLoginViewController new];
               loginVC.initialSelectedRememberedUID = self.pp_pendingReauthUID;
               loginVC.isAddAccountFlow = self.pp_pendingAddAccountMode;
               self.pp_pendingReauthUID = nil;
               self.pp_pendingAddAccountMode = NO;
               root = loginVC;
               break;
          }
          case AppRootDashboard: root = [[AdminDashboardViewController alloc] init]; break;
          case AppRootProviderStatus: {
               PPProviderApplicationStatusViewController *statusController = [[PPProviderApplicationStatusViewController alloc] init];
               statusController.prefersAutoPresentBecomeProvider = self.pp_autoPresentProviderStatusOnNextRoot;

               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               root = statusController;
               break;
          }
          default: root = [SplashViewController new]; break;
     }
     
     PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:root];
     UIViewController *old = self.window.rootViewController;
     if (old.presentedViewController) {
          [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
     }
     self.window.rootViewController = nav;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
     [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];
     [self pp_consumePendingNotificationRouteIfPossible];
     
     return;
     
}


- (void)pp_setRootDashboardWithUser:(UserModel *)model animated:(BOOL)animated {
     (void)model;
     NSString *ownershipKey = [self pp_rootOwnershipKeyForTarget:AppRootDashboard companyProfile:nil];
     self.pp_currentRootOwnershipKey = ownershipKey;
     self.currentRoot = AppRootDashboard;
     PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
     
     UIViewController *old = self.window.rootViewController;
     if (old.presentedViewController) {
          [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
     }
     self.window.rootViewController = tabBar;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
     [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];
     if (animated && old) {
          [UIView transitionWithView:self.window duration:0.25
                             options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
                          animations:nil completion:nil];
     }
}


#pragma mark - Flow

- (void)startFlowForAuthUser:(FIRUser * _Nullable)user userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
     if (!user) {
          self.awaitingModel = NO;
          [self setRoot:AppRootLogin animated:animated];
          return;
     }
     
     // We’re signed in → fetch the UserModel first
     self.awaitingModel = YES;
     [self setRoot:AppRootSplash animated:animated]; // keep splash while loading
     
     NSString *authUID = user.uid;
     NSUInteger routingGeneration = ++self.pp_proAccessRoutingGeneration;
     __weak typeof(self) weakSelf = self;
     [UserManager.shared loadUserByUIDOrID:authUID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
          if (!weakSelf || routingGeneration != weakSelf.pp_proAccessRoutingGeneration ||
              ![[PPProSessionCoordinator.shared currentUser].uid isEqualToString:authUID]) return;
          weakSelf.awaitingModel = NO;
          
          UserModel *effectiveUser = user;
          if (!effectiveUser) {
               FIRUser *au = [PPProSessionCoordinator.shared currentUser];
               if (au) {
                    effectiveUser = [[FUManager shared] userModelFromAuth:au doc:nil];
               }
          }
          if (effectiveUser) {
               UserManager.shared.currentUser = effectiveUser;
               BOOL shouldShowProviderStatus = PPSceneUserHasPartnerApplicationInReview(effectiveUser);
               [AppMgr checkIfUserWithUID:authUID canAccessPro:^(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                         if (!weakSelf || routingGeneration != weakSelf.pp_proAccessRoutingGeneration ||
                             ![[PPProSessionCoordinator.shared currentUser].uid isEqualToString:authUID]) return;
                         if (error) {
                              [weakSelf setRoot:AppRootLogin animated:YES];
                              return;
                         }
                         if (!allowed) {
                              if (PPSceneUserDocIsBlocked(userDoc ?: @{})) {
                                   [UserManager.shared forceSecuritySignOutWithCompletion:nil];
                                   [weakSelf setRoot:AppRootLogin animated:YES];
                                   return;
                              }
                              [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:authUID
                                                                             userDoc:userDoc ?: @{}
                                                                   hasProviderAccess:NO
                                                                        fallbackRoot:AppRootProviderStatus
                                                             autoPresentOnboarding:!(shouldShowProviderStatus || PPSceneUserDocHasPartnerApplicationInReview(userDoc ?: @{}))
                                                                            animated:YES];
                         } else {
                              [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:authUID
                                                                             userDoc:userDoc ?: @{}
                                                                   hasProviderAccess:YES
                                                                        fallbackRoot:(shouldShowProviderStatus ? AppRootProviderStatus : AppRootDashboard)
                                                             autoPresentOnboarding:NO
                                                                            animated:YES];
                         }
                    });
               }];
          } else {
               [weakSelf setRoot:AppRootLogin animated:YES];
          }
     }];
}

#pragma mark - Root switching

- (void)setRoot:(AppRoot)target animated:(BOOL)animated {
     [self setRoot:target animated:animated completion:nil];
}

- (void)setRoot:(AppRoot)target animated:(BOOL)animated completion:(void (^ _Nullable)(void))completion {
     NSUInteger generation = ++self.pp_rootTransitionGeneration;
     [self pp_installRoot:target animated:animated generation:generation completion:completion];
}

- (void)cancelPendingProAccessRouting {
     self.pp_proAccessRoutingGeneration += 1;
     self.pp_rootTransitionGeneration += 1;
}

- (void)pp_installRoot:(AppRoot)target animated:(BOOL)animated generation:(NSUInteger)generation completion:(void (^ _Nullable)(void))completion {
     if (generation != self.pp_rootTransitionGeneration) return;
     NSString *ownershipKey = [self pp_rootOwnershipKeyForTarget:target companyProfile:nil];
     if (target == self.currentRoot &&
         [self.pp_currentRootOwnershipKey isEqualToString:ownershipKey] &&
         self.window.rootViewController) {
          if (completion) completion();
          return;
     }

     // If transitioning away from splash, respect minimum display time
     if (self.currentRoot == AppRootSplash && target != AppRootSplash && self.pp_splashAppearDate) {
          NSTimeInterval elapsed = -[self.pp_splashAppearDate timeIntervalSinceNow];
          NSTimeInterval remaining = kPPSplashMinDisplayTime - elapsed;
          if (remaining > 0.05) {
               __weak typeof(self) weakSelf = self;
               AppRoot capturedTarget = target;
               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                              dispatch_get_main_queue(), ^{
                    [weakSelf pp_installRoot:capturedTarget animated:animated generation:generation completion:completion];
               });
               return;
          }
     }

     self.pp_currentRootOwnershipKey = ownershipKey;
     self.currentRoot = target;
     
     if (target == AppRootDashboard) {
          [self pp_rememberAuthorizedIdentity];
          PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
          UIViewController *old = self.window.rootViewController;
          if (old.presentedViewController) {
               [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
          }
          self.window.rootViewController = tabBar;
          PPProApplyThemeToWindow(self.window);
          [self.window makeKeyAndVisible];
          [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];
          if (animated && old) {
               [UIView transitionWithView:self.window
                                 duration:0.25
                                  options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
                               animations:nil
                               completion:^(__unused BOOL finished) {
                    if (generation == self.pp_rootTransitionGeneration && completion) completion();
               }];
          } else if (completion) {
               completion();
          }
          return;
     }
     UIViewController *root;
     switch (target) {
          case AppRootSplash:    root = [SplashViewController new]; break;
          case AppRootLogin: {
               AdminLoginViewController *loginVC = [AdminLoginViewController new];
               loginVC.initialSelectedRememberedUID = self.pp_pendingReauthUID;
               loginVC.isAddAccountFlow = self.pp_pendingAddAccountMode;
               self.pp_pendingReauthUID = nil;
               self.pp_pendingAddAccountMode = NO;
               root = loginVC;
               break;
          }
          case AppRootDashboard: root = [[AdminDashboardViewController alloc] init]; break;
          case AppRootProviderStatus: {
               PPProviderApplicationStatusViewController *statusController = [[PPProviderApplicationStatusViewController alloc] init];
               statusController.prefersAutoPresentBecomeProvider = self.pp_autoPresentProviderStatusOnNextRoot;

               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               root = statusController;
               break;
          }
          default:               root = [SplashViewController new]; break;
     }
     PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:root];
     
     UIViewController *old = self.window.rootViewController;
     if (old.presentedViewController) {
          [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
     }
     self.window.rootViewController = nav;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
     [self pp_bringTransitionPrivacyCurtainToFrontIfVisible];
     
     if (animated && old) {
          [UIView transitionWithView:self.window
                            duration:0.25
                             options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
                          animations:nil
                          completion:^(__unused BOOL finished) {
               if (generation == self.pp_rootTransitionGeneration && completion) completion();
          }];
     } else if (completion) {
          completion();
     }
}

#pragma mark - Language rebuild

- (void)pp_applyNavigationAppearance {
     UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
     UIColor *titleColor = PrimaryTextClr;
     UIImage *backImage = [UIImage systemImageNamed:(Language.isRTL ? @"chevron.forward" : @"chevron.backward")];

     UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
     [appearance configureWithTransparentBackground];
     appearance.backgroundColor = UIColor.clearColor;
     appearance.shadowColor = UIColor.clearColor;
     appearance.titleTextAttributes = @{
          NSForegroundColorAttributeName: titleColor,
          NSFontAttributeName: [Styling fontBold:22]
     };
     appearance.largeTitleTextAttributes = @{
          NSForegroundColorAttributeName: titleColor,
          NSFontAttributeName: [Styling fontBold:30]
     };
     if (backImage) {
          [appearance setBackIndicatorImage:backImage transitionMaskImage:backImage];
     }

     UIBarButtonItemAppearance *backButtonAppearance = [[UIBarButtonItemAppearance alloc] init];
     backButtonAppearance.normal.titleTextAttributes = @{
          NSForegroundColorAttributeName: UIColor.clearColor
     };
     backButtonAppearance.highlighted.titleTextAttributes = backButtonAppearance.normal.titleTextAttributes;
     backButtonAppearance.disabled.titleTextAttributes = backButtonAppearance.normal.titleTextAttributes;
     appearance.backButtonAppearance = backButtonAppearance;

     UINavigationBar *navigationBar = [UINavigationBar appearance];
     navigationBar.semanticContentAttribute = attr;
     navigationBar.tintColor = titleColor;
     navigationBar.standardAppearance = appearance;
     navigationBar.scrollEdgeAppearance = appearance;
     navigationBar.compactAppearance = appearance;
     navigationBar.prefersLargeTitles = NO;
}

- (void)rebuildForLanguage {
     // Apply semantic direction + nav appearance, then rebuild current target.
     UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
     [UIView appearance].semanticContentAttribute = attr;
     [UINavigationBar appearance].semanticContentAttribute = attr;
     self.window.semanticContentAttribute = attr;
     [self pp_applyNavigationAppearance];
     
     // If we are waiting on model, keep splash; else rebuild the same target
     AppRoot target = self.awaitingModel ? AppRootSplash : self.currentRoot;
     [self setRoot:target animated:YES];
}

#pragma mark - Language

- (void)reloadRootViewControllerForLanguageChange {
     [self pp_applyNavigationAppearance];
     if ([self.window.rootViewController isKindOfClass:NSClassFromString(@"PPProRootTabBarController")]) {
          PPProRootTabBarController *tabBar = (PPProRootTabBarController *)self.window.rootViewController;
          [tabBar refreshForLanguageChange];
          return;
     }
     
     [self updateRootForUser:[PPProSessionCoordinator.shared currentUser] animated:YES];
}


- (void)handleAuthStateChange {
     [self pp_applyAdminRoutingForAuthUser:[PPProSessionCoordinator.shared currentUser] animated:YES];
}

- (void)pp_clearAllYYCacheNamed:(NSString *)name {
     [PPFunc pp_clearAllYYCacheNamed:name];
}



- (void)handleAuthChange {
     if (self.currentRoot == AppRootLogin &&
         [PPProSessionCoordinator.shared activeTransitionTicket] &&
         ![PPProSessionCoordinator.shared currentUser] &&
         ![PPProSessionCoordinator.shared requiresTransitionRecovery]) {
          return;
     }
     [self pp_applyAdminRoutingForAuthUser:[PPProSessionCoordinator.shared currentUser] animated:YES];
}

- (void)pp_handleTransitionRecoveryRequired {
     dispatch_async(dispatch_get_main_queue(), ^{
          [self pp_hideTransitionPrivacyCurtain];
          [self pp_applyAdminRoutingForAuthUser:nil animated:YES];
     });
}

#pragma mark - Transition Privacy Curtain & Workspace Switching

- (NSString *)pp_localizedTransitionStatusTextForKey:(nullable NSString *)statusKey {
     NSString *key = @"ProIdentityTransition_Default";
     if ([statusKey isEqualToString:@"preflight"]) key = @"ProIdentityTransition_Preflight";
     else if ([statusKey isEqualToString:@"drain"]) key = @"ProIdentityTransition_Drain";
     else if ([statusKey isEqualToString:@"freeze"]) key = @"ProIdentityTransition_Freeze";
     else if ([statusKey isEqualToString:@"detach_notifications"]) key = @"ProIdentityTransition_Notifications";
     else if ([statusKey isEqualToString:@"suspended"]) key = @"ProIdentityTransition_Suspended";
     else if ([statusKey isEqualToString:@"authenticating"]) key = @"ProIdentityTransition_Authenticating";
     else if ([statusKey isEqualToString:@"installed"]) key = @"ProIdentityTransition_Installed";
     else if ([statusKey isEqualToString:@"restore"]) key = @"ProIdentityTransition_Restore";
     else if ([statusKey isEqualToString:@"add_account"]) key = @"ProIdentityTransition_AddAccount";
     else if ([statusKey isEqualToString:@"sign_out_all"]) key = @"ProIdentityTransition_SignOutAll";
     NSString *resolved = kLang(key);
     return (resolved.length > 0 && ![resolved isEqualToString:key]) ? resolved : kLang(@"Please wait");
}

- (void)pp_showTransitionPrivacyCurtainWithStatusKey:(nullable NSString *)statusKey {
     if (!self.window) return;
     if (!self.pp_transitionPrivacyCurtain) {
          UIView *curtain = [[UIView alloc] initWithFrame:self.window.bounds];
          curtain.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
          curtain.userInteractionEnabled = YES;
          curtain.accessibilityViewIsModal = YES;
          curtain.accessibilityIdentifier = @"pro.transition.privacyCurtain";
          curtain.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

          if (UIAccessibilityIsReduceTransparencyEnabled()) {
               curtain.backgroundColor = [UIColor ppBackground];
          } else {
               curtain.backgroundColor = UIColor.clearColor;
               UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
               blur.frame = curtain.bounds;
               blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
               [curtain addSubview:blur];
          }

          UIView *badge = [[UIView alloc] init];
          badge.translatesAutoresizingMaskIntoConstraints = NO;
          badge.backgroundColor = [UIColor ppSurface];
          badge.layer.cornerRadius = 22.0;
          if (@available(iOS 13.0, *)) {
               badge.layer.cornerCurve = kCACornerCurveContinuous;
          }
          badge.layer.borderWidth = 1.0;
          badge.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
          badge.layer.shadowColor = [UIColor ppShadow].CGColor;
          badge.layer.shadowOpacity = 0.14;
          badge.layer.shadowRadius = 20.0;
          badge.layer.shadowOffset = CGSizeMake(0.0, 10.0);

          UIImageView *shield = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.shield.fill"]];
          shield.translatesAutoresizingMaskIntoConstraints = NO;
          shield.tintColor = [UIColor ppPrimary];
          shield.contentMode = UIViewContentModeScaleAspectFit;

          UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
          spinner.translatesAutoresizingMaskIntoConstraints = NO;
          spinner.color = [UIColor ppPrimary];
          [spinner startAnimating];

          UILabel *label = [[UILabel alloc] init];
          label.translatesAutoresizingMaskIntoConstraints = NO;
          label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
          label.adjustsFontForContentSizeCategory = YES;
          label.textColor = [UIColor ppTextPrimary];
          label.textAlignment = NSTextAlignmentCenter;
          label.numberOfLines = 0;

          UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[shield, label, spinner]];
          stack.translatesAutoresizingMaskIntoConstraints = NO;
          stack.axis = UILayoutConstraintAxisVertical;
          stack.alignment = UIStackViewAlignmentCenter;
          stack.spacing = 12.0;
          [badge addSubview:stack];
          [curtain addSubview:badge];

          [NSLayoutConstraint activateConstraints:@[
               [shield.widthAnchor constraintEqualToConstant:34.0],
               [shield.heightAnchor constraintEqualToConstant:34.0],
               [badge.centerXAnchor constraintEqualToAnchor:curtain.centerXAnchor],
               [badge.centerYAnchor constraintEqualToAnchor:curtain.centerYAnchor],
               [badge.leadingAnchor constraintGreaterThanOrEqualToAnchor:curtain.safeAreaLayoutGuide.leadingAnchor constant:24.0],
               [badge.trailingAnchor constraintLessThanOrEqualToAnchor:curtain.safeAreaLayoutGuide.trailingAnchor constant:-24.0],
               [badge.widthAnchor constraintLessThanOrEqualToConstant:360.0],
               [stack.topAnchor constraintEqualToAnchor:badge.topAnchor constant:22.0],
               [stack.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-22.0],
               [stack.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:22.0],
               [stack.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-22.0],
          ]];

          self.pp_transitionPrivacyCurtain = curtain;
          self.pp_transitionCurtainStatusLabel = label;
          curtain.alpha = 0.0;
          [self.window addSubview:curtain];
          if (UIAccessibilityIsReduceMotionEnabled()) {
               curtain.alpha = 1.0;
          } else {
               [UIView animateWithDuration:0.16 animations:^{
                    curtain.alpha = 1.0;
               }];
          }
     }
     self.pp_transitionCurtainStatusLabel.text = [self pp_localizedTransitionStatusTextForKey:statusKey];
     self.pp_transitionPrivacyCurtain.accessibilityLabel = self.pp_transitionCurtainStatusLabel.text;
     [self.window bringSubviewToFront:self.pp_transitionPrivacyCurtain];
}

- (void)pp_bringTransitionPrivacyCurtainToFrontIfVisible {
     if (self.pp_transitionPrivacyCurtain && self.pp_transitionPrivacyCurtain.superview == self.window) {
          [self.window bringSubviewToFront:self.pp_transitionPrivacyCurtain];
     }
}

- (void)pp_hideTransitionPrivacyCurtain {
     UIView *curtain = self.pp_transitionPrivacyCurtain;
     if (!curtain) return;
     self.pp_transitionPrivacyCurtain = nil;
     self.pp_transitionCurtainStatusLabel = nil;
     if (UIAccessibilityIsReduceMotionEnabled()) {
          [curtain removeFromSuperview];
     } else {
          [UIView animateWithDuration:0.18 animations:^{
               curtain.alpha = 0.0;
          } completion:^(__unused BOOL finished) {
               [curtain removeFromSuperview];
          }];
     }
}

- (void)pp_handleTransitionWillBegin:(NSNotification *)note {
     dispatch_async(dispatch_get_main_queue(), ^{
          NSString *statusKey = [note.userInfo[@"statusKey"] isKindOfClass:NSString.class] ? note.userInfo[@"statusKey"] : @"preflight";
          [self pp_showTransitionPrivacyCurtainWithStatusKey:statusKey];
     });
}

- (void)pp_handleTransitionPhaseDidChange:(NSNotification *)note {
     dispatch_async(dispatch_get_main_queue(), ^{
          NSString *statusKey = [note.userInfo[@"statusKey"] isKindOfClass:NSString.class] ? note.userInfo[@"statusKey"] : nil;
          if (self.pp_transitionPrivacyCurtain) {
               [self pp_showTransitionPrivacyCurtainWithStatusKey:statusKey];
          }
     });
}

- (void)pp_handleSessionDidSuspend:(__unused NSNotification *)note {
     dispatch_async(dispatch_get_main_queue(), ^{
          self.pp_currentRootOwnershipKey = nil;
          self.pp_pendingNotificationRoutePayload = nil;
          self.pp_pendingNotificationEpoch = nil;
          self.pp_pendingCompanyDeliveryPayload = nil;
          self.pp_pendingCompanyDeliveryEpoch = nil;
          self.pp_companyResolutionID = nil;
          self.pp_isResolvingCompanyDeliveryNotification = NO;
          self.pp_proAccessRoutingGeneration += 1;
          UIViewController *root = self.window.rootViewController;
          if (root.presentedViewController && !root.presentedViewController.isBeingDismissed) {
               [root.presentedViewController dismissViewControllerAnimated:NO completion:nil];
          }
          [self pp_showTransitionPrivacyCurtainWithStatusKey:@"suspended"];
     });
}

- (void)pp_handleSessionDidCommitOrRollback:(__unused NSNotification *)note {
     dispatch_async(dispatch_get_main_queue(), ^{
          [self pp_hideTransitionPrivacyCurtain];
     });
}

- (void)beginAddAccountTransitionAnimated:(BOOL)animated {
     NSString *activeUID = [PPProSessionCoordinator.shared activeUID];
     [self pp_showTransitionPrivacyCurtainWithStatusKey:@"add_account"];
     __weak typeof(self) weakSelf = self;
     [PPProSessionCoordinator.shared beginProvisionalAddAccountFromUID:activeUID
                                                            completion:^(BOOL allowed,
                                                                         __unused NSUUID * _Nullable ticket,
                                                                         __unused id<PPProSessionSlotHandle> _Nullable provisionalSlot,
                                                                         NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
               __strong typeof(weakSelf) strongSelf = weakSelf;
               if (!strongSelf) return;
               [strongSelf pp_hideTransitionPrivacyCurtain];
               if (!allowed) {
                    UIViewController *presenter = [strongSelf pp_topViewController];
                    if (presenter) {
                         [PPAlertHelper showErrorIn:presenter
                                              title:kLang(@"Error")
                                           subtitle:error.localizedDescription ?: kLang(@"StatusLoginFailed")];
                    }
                    return;
               }
               strongSelf.pp_pendingAddAccountMode = YES;
               strongSelf.pp_pendingReauthUID = nil;
               strongSelf.pp_currentRootOwnershipKey = nil;
               [strongSelf setRoot:AppRootLogin animated:animated];
          });
     }];
}

- (void)switchToRememberedAccountUID:(NSString *)uid animated:(BOOL)animated {
     NSString *safeUID = PPSceneTrimmed(uid);
     if (!safeUID.length) return;
     NSString *activeUID = [PPProSessionCoordinator.shared activeUID];
     [self pp_showTransitionPrivacyCurtainWithStatusKey:@"preflight"];
     __weak typeof(self) weakSelf = self;
     [PPProSessionCoordinator.shared fastSwitchToRememberedUID:safeUID
                                                        fromUID:activeUID
                                                     completion:^(BOOL switched,
                                                                  BOOL requiresReauth,
                                                                  __unused NSUUID * _Nullable ticket,
                                                                  __unused id<PPProSessionSlotHandle> _Nullable stagedSlot,
                                                                  NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
               __strong typeof(weakSelf) strongSelf = weakSelf;
               if (!strongSelf) return;
               [strongSelf pp_hideTransitionPrivacyCurtain];
               if (switched) {
                    strongSelf.pp_currentRootOwnershipKey = nil;
                    [strongSelf pp_applyAdminRoutingForAuthUser:[PPProSessionCoordinator.shared currentUser] animated:animated];
                    return;
               }
               if (requiresReauth) {
                    strongSelf.pp_pendingReauthUID = safeUID;
                    strongSelf.pp_pendingAddAccountMode = NO;
                    strongSelf.pp_currentRootOwnershipKey = nil;
                    [strongSelf setRoot:AppRootLogin animated:animated];
                    return;
               }
               UIViewController *presenter = [strongSelf pp_topViewController];
               if (presenter) {
                    [PPAlertHelper showErrorIn:presenter
                                         title:kLang(@"Error")
                                      subtitle:error.localizedDescription ?: kLang(@"StatusLoginFailed")];
               }
          });
     }];
}

- (void)signOutAllAccountsAnimated:(BOOL)animated {
     [self pp_showTransitionPrivacyCurtainWithStatusKey:@"sign_out_all"];
     __weak typeof(self) weakSelf = self;
     [PPProSessionCoordinator.shared signOutAllAccountsWithReason:@"sign_out_all"
                                                       completion:^(BOOL signedOutAll, NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
               __strong typeof(weakSelf) strongSelf = weakSelf;
               if (!strongSelf) return;
               [strongSelf pp_hideTransitionPrivacyCurtain];
               if (!signedOutAll) {
                    UIViewController *presenter = [strongSelf pp_topViewController];
                    if (presenter) {
                         [PPAlertHelper showErrorIn:presenter
                                              title:kLang(@"Error")
                                           subtitle:error.localizedDescription ?: kLang(@"StatusLoginFailed")];
                    }
                    return;
               }
               strongSelf.pp_pendingReauthUID = nil;
               strongSelf.pp_pendingAddAccountMode = NO;
               strongSelf.pp_currentRootOwnershipKey = nil;
               [strongSelf setRoot:AppRootLogin animated:animated];
          });
     }];
}

#pragma mark - Public: called by [Language userSelectedLanguage:]
- (void)sceneDidBecomeActive:(UIScene *)scene {
     (void)scene;
     self.pp_requiresForegroundUnlock = NO;
     self.pp_didAutoPromptForCurrentLockCycle = NO;
     self.pp_requiresManualUnlockRetry = NO;
     self.pp_skipNextDidBecomeActiveAutoPrompt = NO;
     self.pp_isUnlockPromptRunning = NO;
     [self pp_hideLockOverlay];
     [self pp_consumePendingNotificationRouteIfPossible];
}

- (void)sceneWillResignActive:(UIScene *)scene {
     (void)scene;
}

/// Handle Google Sign-In OAuth callback URL
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts API_AVAILABLE(ios(13.0)) {
     (void)scene;
     for (UIOpenURLContext *ctx in URLContexts) {
          if ([GIDSignIn.sharedInstance handleURL:ctx.URL]) { return; }
          if ([PPProSessionCoordinator.shared canHandleAuthURL:ctx.URL]) { return; }
     }
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
     (void)scene;
}

#pragma mark - Root swapping

- (void)updateRootForUser:(FIRUser *_Nullable)user animated:(BOOL)animated {
     [self pp_applyAdminRoutingForAuthUser:user animated:animated];
}

#pragma mark - Foreground Lock

- (UIViewController *)pp_topViewController {
     UIViewController *top = self.window.rootViewController;
     while (top.presentedViewController) {
          top = top.presentedViewController;
     }
     return top;
}

- (BOOL)pp_shouldProtectCurrentSession {
     return NO;
}

- (void)pp_showLockOverlayIfNeeded {
     [self pp_hideLockOverlay];
}

- (void)pp_hideLockOverlay {
     [self.ppLockOverlay removeFromSuperview];
     self.ppLockOverlay = nil;
     self.ppUnlockButton = nil;
}

- (void)pp_unlockButtonTapped {
     [self pp_hideLockOverlay];
}

- (void)pp_promptForegroundUnlockIfNeededForced:(BOOL)forced {
     (void)forced;
     self.pp_requiresForegroundUnlock = NO;
     self.pp_didAutoPromptForCurrentLockCycle = NO;
     self.pp_requiresManualUnlockRetry = NO;
     self.pp_skipNextDidBecomeActiveAutoPrompt = NO;
     self.pp_isUnlockPromptRunning = NO;
     [self pp_hideLockOverlay];
}

- (void)pp_armForegroundLockIfNeeded {
     self.pp_requiresForegroundUnlock = NO;
     self.pp_didAutoPromptForCurrentLockCycle = NO;
     self.pp_requiresManualUnlockRetry = NO;
     self.pp_skipNextDidBecomeActiveAutoPrompt = NO;
     self.pp_isUnlockPromptRunning = NO;
     [self pp_hideLockOverlay];
}

- (void)dealloc
{
     [[NSNotificationCenter defaultCenter] removeObserver:self];
}



@end



/*
 
 
 @import FirebaseAuth;
 @import FirebaseFirestore;
 
 
 
 @interface SceneDelegate ()
 @property (nonatomic) AppRoot currentRoot;
 @property (nonatomic) FIRAuthStateDidChangeListenerHandle authHandle;
 @property (nonatomic) BOOL awaitingModel;
 @end
 
 @implementation SceneDelegate
 
 - (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
 if (![scene isKindOfClass:[UIWindowScene class]]) return;
 UIWindowScene *ws = (UIWindowScene *)scene;
 self.window = [[UIWindow alloc] initWithWindowScene:ws];
 self.window.frame = ws.coordinateSpace.bounds;
 
 // 1) Always start on Splash
 [self pp_setRoot:AppRootSplash userModel:nil animated:NO];
 
 // 2) Attach auth listener
 __weak typeof(self) weakSelf = self;
 self.authHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser * _Nullable user) {
 FIRUser * _Nullable userAuth = user;
 [UsrMgr fetchAdminWithUID:user.uid cachePolicy:PPUserCachePolicyServerOnly completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
 [weakSelf pp_startFlowForAuthUser:userAuth userModel:user animated:YES];
 
 // 3) Kick initial evaluation
 [self pp_startFlowForAuthUser:[FIRAuth auth].currentUser userModel:user animated:NO];
 
 [self.window makeKeyAndVisible];
 
 
 }];
 
 }];
 
 
 
 [[NSNotificationCenter defaultCenter] addObserver:self
 selector:@selector(reloadRootViewControllerForLanguageChange)
 name:LanguageDidChangeNotification
 object:nil];
 }
 
 - (void)pp_startFlowForAuthUser:(FIRUser * _Nullable)authUser userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
 if (!authUser) { return; }
 
 // keep Splash while fetching model
 [self pp_setRoot:AppRootSplash userModel:userModel animated:animated];
 
 __weak typeof(self) weakSelf = self;
 [UserManager.shared loadUserByUIDOrID:authUser.uid completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
 
 if (user) {
 [weakSelf pp_setRootDashboardWithUser:user animated:YES];
 } else {
 [weakSelf pp_setRoot:AppRootLogin userModel:user animated:YES];
 }
 }];
 }
 
 - (void)pp_setRoot:(AppRoot)target userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
 static AppRoot current = -1;
 if (target == current && self.window.rootViewController) return;
 current = target;
 
 UIViewController *root = nil;
 switch (target) {
 case AppRootSplash:    root = [SplashViewController new]; break;
 case AppRootLogin:     root = [AdminLoginViewController new]; break;
 case AppRootDashboard: root = [UIViewController new]; break;
 }
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
 
 UIViewController *old = self.window.rootViewController;
 self.window.rootViewController = nav;
 if (animated && old) {
 [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
 [UIView transitionWithView:self.window duration:0.45
 options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
 animations:nil completion:nil];
 }
 }
 
 - (void)pp_setRootDashboardWithUser:(UserModel *)model animated:(BOOL)animated {
 AdminDashboardViewController *dash = [[AdminDashboardViewController alloc] init];
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dash];
 
 UIViewController *old = self.window.rootViewController;
 self.window.rootViewController = nav;
 if (animated && old) {
 [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
 [UIView transitionWithView:self.window duration:0.25
 options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
 animations:nil completion:nil];
 }
 }
 
 
 #pragma mark - Flow
 
 - (void)startFlowForAuthUser:(FIRUser * _Nullable)user userModel:(UserModel * _Nullable)userModel animated:(BOOL)animated {
 if (!user) {
 self.awaitingModel = NO;
 [self setRoot:AppRootLogin animated:animated];
 return;
 }
 
 // We’re signed in → fetch the UserModel first
 self.awaitingModel = YES;
 [self setRoot:AppRootSplash animated:animated]; // keep splash while loading
 
 __weak typeof(self) weakSelf = self;
 [UserManager.shared loadUserByUIDOrID:user.uid completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
 
 weakSelf.awaitingModel = NO;
 
 if (user) {
 // Optional: set currentUser if you haven’t already inside the fetch
 UserManager.shared.currentUser = user;
 [weakSelf setRoot:AppRootDashboard animated:YES];
 } else {
 // If user doc missing or error, send to Login
 [weakSelf setRoot:AppRootLogin animated:YES];
 }
 }];
 }
 
 #pragma mark - Root switching
 
 - (void)setRoot:(AppRoot)target animated:(BOOL)animated {
 if (target == self.currentRoot && self.window.rootViewController) return;
 self.currentRoot = target;
 
 UIViewController *root;
 switch (target) {
 case AppRootSplash:    root = [SplashViewController new]; break;
 case AppRootLogin:     root = [AdminLoginViewController new]; break;
 case AppRootDashboard: root = [[AdminDashboardViewController alloc]init]; break;
 default:               root = [SplashViewController new]; break;
 }
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
 
 UIViewController *old = self.window.rootViewController;
 self.window.rootViewController = nav;
 
 if (animated && old) {
 [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
 [UIView transitionWithView:self.window
 duration:0.25
 options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
 animations:nil
 completion:nil];
 }
 }
 
 #pragma mark - Language rebuild
 
 - (void)rebuildForLanguage {
 // Apply semantic direction + nav appearance, then rebuild current target.
 UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
 [UIView appearance].semanticContentAttribute = attr;
 [UINavigationBar appearance].semanticContentAttribute = attr;
 self.window.semanticContentAttribute = attr;
 [self pp_applyNavigationAppearance];
 
 // If we are waiting on model, keep splash; else rebuild the same target
 AppRoot target = self.awaitingModel ? AppRootSplash : self.currentRoot;
 [self setRoot:target animated:YES];
 }
 
 - (void)pp_applyNavigationAppearance {
 UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
 UIColor *titleColor = PrimaryTextClr;
 UIImage *backImage = [UIImage systemImageNamed:(Language.isRTL ? @"chevron.forward" : @"chevron.backward")];

 UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
 [appearance configureWithTransparentBackground];
 appearance.backgroundColor = UIColor.clearColor;
 appearance.shadowColor = UIColor.clearColor;
 appearance.titleTextAttributes = @{
     NSForegroundColorAttributeName: titleColor,
     NSFontAttributeName: [Styling fontBold:22]
 };
 appearance.largeTitleTextAttributes = @{
     NSForegroundColorAttributeName: titleColor,
     NSFontAttributeName: [Styling fontBold:30]
 };
 if (backImage) {
     [appearance setBackIndicatorImage:backImage transitionMaskImage:backImage];
 }

 UIBarButtonItemAppearance *backButtonAppearance = [[UIBarButtonItemAppearance alloc] init];
 backButtonAppearance.normal.titleTextAttributes = @{
     NSForegroundColorAttributeName: UIColor.clearColor
 };
 backButtonAppearance.highlighted.titleTextAttributes = backButtonAppearance.normal.titleTextAttributes;
 backButtonAppearance.disabled.titleTextAttributes = backButtonAppearance.normal.titleTextAttributes;
 appearance.backButtonAppearance = backButtonAppearance;

 [UINavigationBar appearance].semanticContentAttribute = attr;
 [UINavigationBar appearance].tintColor = titleColor;
 [UINavigationBar appearance].standardAppearance = appearance;
 [UINavigationBar appearance].scrollEdgeAppearance = appearance;
 [UINavigationBar appearance].compactAppearance = appearance;
 [UINavigationBar appearance].prefersLargeTitles = NO;
 }
 
 #pragma mark - Language
 
 - (void)reloadRootViewControllerForLanguageChange {
 UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
 [UIView appearance].semanticContentAttribute = attr;
 [UINavigationBar appearance].semanticContentAttribute = attr;
 self.window.semanticContentAttribute = attr;
 
 [self pp_applyNavigationAppearance];
 [self updateRootForUser:[FIRAuth auth].currentUser animated:YES];
 }
 
 
 - (void)handleAuthStateChange {
 BOOL loggedIn = ([FIRAuth auth].currentUser != nil);
 AppRoot desired = loggedIn ? AppRootDashboard : AppRootLogin;
 if (desired == self.currentRoot) return; // already on right root
 
 if(loggedIn)
 {
 self.currentRoot = AppRootDashboard;
 
 AdminDashboardViewController *dash = [[AdminDashboardViewController alloc] init];
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dash];
 self.window.rootViewController = nav;
 [self.window makeKeyAndVisible];
 
 }
 else
 {
 self.currentRoot = AppRootDashboard;
 AdminLoginViewController *rootVC = [AdminLoginViewController new];
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
 self.window.rootViewController = nav;
 [self.window makeKeyAndVisible];
 
 }
 
 }
 
 
 - (void)pp_clearAllYYCacheNamed:(NSString *)name {
 YYCache *cache = [YYCache cacheWithName:name];
 [cache removeAllObjectsWithBlock:^{
 dispatch_async(dispatch_get_main_queue(), ^{
 [PPToast toast:kLang(@"Cache cleared") style:PPToastStyleSuccess haptic:YES duration:2.0];
 });
 }];
 }
 
 
 
 - (void)handleAuthChange {
 BOOL loggedIn = ([FIRAuth auth].currentUser != nil);
 if(loggedIn)
 {
 UIViewController *root =[[AdminDashboardViewController alloc] init];
 self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
 [self.window makeKeyAndVisible];
 }
 else
 {
 UIViewController *root = [[AdminLoginViewController alloc]init];
 self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
 [self.window makeKeyAndVisible];
 }
 }
 
 #pragma mark - Public: called by [Language userSelectedLanguage:]
 - (void)sceneDidBecomeActive:(UIScene *)scene {
 
 }
 
 
 
 
 - (void)sceneWillResignActive:(UIScene *)scene {
 // Called when the scene will move from an active state to an inactive state.
 // This may occur due to temporary interruptions (ex. an incoming phone call).
 }
 
 
 - (void)sceneWillEnterForeground:(UIScene *)scene {
 // Called as the scene transitions from the background to the foreground.
 // Use this method to undo the changes made on entering the background.
 }
 
 
 - (void)sceneDidEnterBackground:(UIScene *)scene {
 [[AppLockManager shared] didEnterBackground];
 }
 
 #pragma mark - Root swapping
 
 - (void)updateRootForUser:(FIRUser *_Nullable)user animated:(BOOL)animated {
 BOOL loggedIn = (user != nil);
 
 //if (desired == self.currentRoot) return; // already on right root
 
 if(loggedIn)
 {
 self.currentRoot = AppRootDashboard;
 
 AdminDashboardViewController *dash = [[AdminDashboardViewController alloc] init];
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dash];
 self.window.rootViewController = nav;
 [self.window makeKeyAndVisible];
 
 }
 else
 {
 self.currentRoot = AppRootDashboard;
 AdminLoginViewController *rootVC = [AdminLoginViewController new];
 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
 self.window.rootViewController = nav;
 [self.window makeKeyAndVisible];
 
 }
 }
 
 
 
 @end
 
 
 */
