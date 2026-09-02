#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "PPFirebaseCompat.h"
#import "PPProviderApplicationStatusViewController.h"
#import "PPDeliveryCompanyDetailViewController.h"
#import "PPDeliveryCompanyService.h"
#import "NotificationManager+Targets.h"
#import "NotificationsListViewController.h"
#import "PPProInAppNotificationPresenter.h"
#import "PPStaffAuth.h"
#import "AppManager.h"
#import "AdminDashboardViewController.h"
#import "PurePetsPro-Swift.h"
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
@property (nonatomic, copy, nullable) NSString *pp_lastNotificationRouteSignature;
@property (nonatomic) CFTimeInterval pp_lastNotificationRouteAt;
@property (nonatomic) BOOL pp_isResolvingCompanyDeliveryNotification;
- (void)pp_routeAfterDeliveryCompanyPreflightForUID:(NSString *)uid
                                            userDoc:(NSDictionary *)userDoc
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
@end

static NSTimeInterval const kPPSplashMinDisplayTime = 2.2;

static BOOL PPSceneRootBoolValue(id value) {
     if ([value respondsToSelector:@selector(boolValue)]) {
          return [value boolValue];
     }
     return NO;
}

static BOOL PPSceneUserDocIsBlocked(NSDictionary *root) {
     if (![root isKindOfClass:NSDictionary.class]) {
          return NO;
     }
     NSString *accountStatus = [PPSafeString(root[@"accountStatus"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
     return PPSceneRootBoolValue(root[@"isBlocked"]) ||
            PPSceneRootBoolValue(root[@"blocked"]) ||
            PPSceneRootBoolValue(root[@"isDeleted"]) ||
            [accountStatus isEqualToString:@"blocked"] ||
            [accountStatus isEqualToString:@"disabled"];
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

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
     
     
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
     // ── Guard: don't interfere while the login controller's pipeline is active ──
     if (PPAdminLoginInProgress()) {
          NSLog(@"[SceneDelegate] ⏸ skipping routing — login in progress");
          return;
     }

     if (!authUser) {
          self.pp_requiresForegroundUnlock = NO;
          self.pp_didAutoPromptForCurrentLockCycle = NO;
          self.pp_requiresManualUnlockRetry = NO;
          [self pp_hideLockOverlay];
          [self setRoot:AppRootLogin animated:animated];
          return;
     }

     __weak typeof(self) weakSelf = self;
     [AppMgr checkIfUserWithUID:authUser.uid canAccessPro:^(BOOL isAllowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf) {
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
                          [UserManager.shared signOut];
                          [weakSelf setRoot:AppRootLogin animated:animated];
                          return;
                     }

                     [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:authUser.uid
                                                                    userDoc:userDoc ?: @{}
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
                                        fallbackRoot:(AppRoot)fallbackRoot
                             autoPresentOnboarding:(BOOL)autoPresentOnboarding
                                            animated:(BOOL)animated {
     if (!uid.length || PPSceneUserDocIsBlocked(userDoc ?: @{})) {
          self.pp_autoPresentProviderStatusOnNextRoot = autoPresentOnboarding;
          [self setRoot:fallbackRoot animated:animated];
          return;
     }

     __weak typeof(self) weakSelf = self;
     [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles,
                                                                                  NSError * _Nullable error) {
          __strong typeof(weakSelf) self = weakSelf;
          if (!self || PPAdminLoginInProgress()) {
               return;
          }

          NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
          if (![activeUID isEqualToString:uid]) {
               return;
          }

          PPDeliveryCompanyProfile *profile = profiles.firstObject;
          if (profile.companyID.length > 0) {
               NSLog(@"[SceneDelegate] delivery company membership granted uid=%@ company=%@ role=%@",
                     uid, profile.companyID, profile.role);
               [PPDeliveryCompanyService.shared storeVerifiedProfile:profile];
               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               [self showDashboardWithDeliveryCompanyProfile:profile animated:animated];
               return;
          }

          if (error) {
               NSLog(@"[SceneDelegate] delivery company membership preflight failed; continuing onboarding: %@",
                     error.localizedDescription);
          }
          self.pp_autoPresentProviderStatusOnNextRoot = autoPresentOnboarding;
          [self setRoot:fallbackRoot animated:animated];
     }];
}

- (void)showDashboardWithDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile animated:(BOOL)animated {
     if (!profile.companyID.length) {
          [self setRoot:AppRootProviderStatus animated:animated];
          return;
     }

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
     self.window.rootViewController = tabBar;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];

     if (animated && oldRoot) {
          [oldRoot.presentedViewController dismissViewControllerAnimated:NO completion:nil];
          [UIView transitionWithView:self.window
                            duration:0.25
                             options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                          animations:nil
                          completion:nil];
     }
     [self pp_consumePendingNotificationRouteIfPossible];
     [self pp_presentPendingCompanyDeliveryWithProfile:profile];
}

- (void)pp_handleCompanyDeliveryNotification:(NSNotification *)notification {
     NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:
                                     [notification.userInfo isKindOfClass:NSDictionary.class] ? notification.userInfo : @{}];
     NSString *requestID = PPSafeString(notification.object);
     if (requestID.length > 0 && PPSafeString(payload[@"requestId"]).length == 0) {
          payload[@"requestId"] = requestID;
     }
     if (PPSafeString(payload[@"requestId"]).length == 0) {
          return;
     }
     self.pp_pendingCompanyDeliveryPayload = payload.copy;
     [self pp_routePendingCompanyDeliveryNotificationIfPossible];
}

- (void)pp_routePendingCompanyDeliveryNotificationIfPossible {
     NSDictionary *payload = self.pp_pendingCompanyDeliveryPayload;
     NSString *requestID = PPSafeString(payload[@"requestId"]);
     NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
     if (requestID.length == 0 || uid.length == 0 || self.pp_isResolvingCompanyDeliveryNotification) {
          return;
     }

     self.pp_isResolvingCompanyDeliveryNotification = YES;
     __weak typeof(self) weakSelf = self;
     [PPDeliveryCompanyService.shared discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error) {
          __strong typeof(weakSelf) self = weakSelf;
          if (!self) return;
          self.pp_isResolvingCompanyDeliveryNotification = NO;

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
     [self pp_consumePendingNotificationRouteIfPossible];
}

- (void)pp_consumePendingNotificationRouteIfPossible
{
     if (self.pp_pendingNotificationRoutePayload.count == 0) {
          return;
     }

     if (self.currentRoot != AppRootDashboard || !self.window.rootViewController) {
          NSLog(@"[NotificationRoute] Dashboard root is not ready yet. Deferring notification route.");
          return;
     }

     UINavigationController *navigationController = [self pp_notificationsNavigationController];
     if (!navigationController) {
          NSLog(@"[NotificationRoute] Missing root tab bar and navigation controller. Deferring notification route.");
          return;
     }

     NSDictionary *payload = self.pp_pendingNotificationRoutePayload;
     self.pp_pendingNotificationRoutePayload = nil;
     __weak typeof(self) weakSelf = self;
     [NotificationManager routePayload:payload
              fromNavigationController:navigationController
                             presenter:navigationController.topViewController ?: navigationController
                            completion:^(BOOL handled) {
          if (handled) {
               return;
          }
          __strong typeof(weakSelf) self = weakSelf;
          if (!self) return;
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
     if (target == self.currentRoot && self.window.rootViewController) return;

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

     self.currentRoot = target;
     
     if (target == AppRootDashboard) {
          PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
          self.window.rootViewController = tabBar;
          PPProApplyThemeToWindow(self.window);
          [self.window makeKeyAndVisible];
          [self pp_consumePendingNotificationRouteIfPossible];
          return;
     }
     UIViewController *root;
     switch (target) {
          case AppRootSplash:    root = [SplashViewController new]; break;
          case AppRootLogin:     root = [AdminLoginViewController new]; break;
          case AppRootDashboard: root = [[AdminDashboardViewController alloc] init]; break;
          case AppRootProviderStatus: {
               PPProviderApplicationStatusViewController *statusController = [[PPProviderApplicationStatusViewController alloc] init];
               statusController.prefersAutoPresentBecomeProvider = NO;

               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               root = statusController;
               break;
          }
          default: root = [SplashViewController new]; break;
     }
     
     PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:root];
     self.window.rootViewController = nav;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
     [self pp_consumePendingNotificationRouteIfPossible];
     
     return;
     
}


- (void)pp_setRootDashboardWithUser:(UserModel *)model animated:(BOOL)animated {
     PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
     
     UIViewController *old = self.window.rootViewController;
     self.window.rootViewController = tabBar;
     PPProApplyThemeToWindow(self.window);
     [self.window makeKeyAndVisible];
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
          
          UserModel *effectiveUser = user;
          if (!effectiveUser) {
               FIRUser *au = [FIRAuth auth].currentUser;
               if (au) {
                    effectiveUser = [[FUManager shared] userModelFromAuth:au doc:nil];
               }
          }
          if (effectiveUser) {
               UserManager.shared.currentUser = effectiveUser;
               BOOL shouldShowProviderStatus = PPSceneUserHasPartnerApplicationInReview(effectiveUser);
               [AppMgr checkIfUserWithUID:effectiveUser.ID canAccessPro:^(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                         if (!allowed) {
                              BOOL blocked = [userDoc[@"isBlocked"] boolValue] || [userDoc[@"blocked"] boolValue] || [userDoc[@"isDeleted"] boolValue];
                              if (blocked) {
                                   [UserManager.shared signOut];
                                   [weakSelf setRoot:AppRootLogin animated:YES];
                                   return;
                              }
                              [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:effectiveUser.ID
                                                                             userDoc:userDoc ?: @{}
                                                                        fallbackRoot:AppRootProviderStatus
                                                             autoPresentOnboarding:!(shouldShowProviderStatus || PPSceneUserDocHasPartnerApplicationInReview(userDoc ?: @{}))
                                                                            animated:YES];
                         } else {
                              [weakSelf pp_routeAfterDeliveryCompanyPreflightForUID:effectiveUser.ID
                                                                             userDoc:userDoc ?: @{}
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
     if (target == self.currentRoot && self.window.rootViewController) return;

     // If transitioning away from splash, respect minimum display time
     if (self.currentRoot == AppRootSplash && target != AppRootSplash && self.pp_splashAppearDate) {
          NSTimeInterval elapsed = -[self.pp_splashAppearDate timeIntervalSinceNow];
          NSTimeInterval remaining = kPPSplashMinDisplayTime - elapsed;
          if (remaining > 0.05) {
               __weak typeof(self) weakSelf = self;
               AppRoot capturedTarget = target;
               dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                              dispatch_get_main_queue(), ^{
                    // Reset currentRoot so the guard at the top doesn't skip
                    weakSelf.currentRoot = AppRootSplash;
                    [weakSelf setRoot:capturedTarget animated:animated];
               });
               return;
          }
     }

     self.currentRoot = target;
     
     if (target == AppRootDashboard) {
          PPProRootTabBarController *tabBar = [[PPProRootTabBarController alloc] init];
          UIViewController *old = self.window.rootViewController;
          self.window.rootViewController = tabBar;
          PPProApplyThemeToWindow(self.window);
          [self.window makeKeyAndVisible];
          if (animated && old) {
               [old.presentedViewController dismissViewControllerAnimated:NO completion:nil];
               [UIView transitionWithView:self.window
                                 duration:0.25
                                  options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowAnimatedContent
                               animations:nil
                               completion:nil];
          }
          return;
     }
     UIViewController *root;
     switch (target) {
          case AppRootSplash:    root = [SplashViewController new]; break;
          case AppRootLogin:     root = [AdminLoginViewController new]; break;
          case AppRootDashboard: root = [[AdminDashboardViewController alloc] init]; break;
          case AppRootProviderStatus: {
               PPProviderApplicationStatusViewController *statusController = [[PPProviderApplicationStatusViewController alloc] init];
               statusController.prefersAutoPresentBecomeProvider = NO;

               self.pp_autoPresentProviderStatusOnNextRoot = NO;
               root = statusController;
               break;
          }
          default:               root = [SplashViewController new]; break;
     }
     PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:root];
     
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
     //UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
     //[UIView appearance].semanticContentAttribute = attr;
     //[UINavigationBar appearance].semanticContentAttribute = attr;
     //self.window.semanticContentAttribute = attr;
     //[self pp_applyNavigationAppearance];
     
     // If we are waiting on model, keep splash; else rebuild the same target
     AppRoot target = self.awaitingModel ? AppRootSplash : self.currentRoot;
     [self setRoot:target animated:YES];
}

#pragma mark - Language

- (void)reloadRootViewControllerForLanguageChange {
     if ([self.window.rootViewController isKindOfClass:NSClassFromString(@"PPProRootTabBarController")]) {
          PPProRootTabBarController *tabBar = (PPProRootTabBarController *)self.window.rootViewController;
          [tabBar refreshForLanguageChange];
          return;
     }
     //UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
     //[UIView appearance].semanticContentAttribute = attr;
     //[UINavigationBar appearance].semanticContentAttribute = attr;
     //self.window.semanticContentAttribute = attr;
     
     // [self pp_applyNavigationAppearance];
     [self updateRootForUser:[FIRAuth auth].currentUser animated:YES];
}


- (void)handleAuthStateChange {
     [self pp_applyAdminRoutingForAuthUser:[FIRAuth auth].currentUser animated:YES];
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
     [self pp_applyAdminRoutingForAuthUser:[FIRAuth auth].currentUser animated:YES];
     
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
