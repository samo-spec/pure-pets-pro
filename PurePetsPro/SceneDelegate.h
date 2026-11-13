//
//  SceneDelegate.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import <UIKit/UIKit.h>

@class PPDeliveryCompanyProfile;
@class FIRUser;

typedef NS_ENUM(NSInteger, AppRoot) {
    AppRootSplash,
    AppRootLogin,
    AppRootDashboard,
    AppRootProviderStatus
};

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

/// Preserve an explicit account-management/onboarding intent against older
/// access checks and deferred root transitions. Does not change authorization.
- (void)cancelPendingProAccessRouting;
/// Re-enters the existing authenticated Pro access gate and root owner.
- (void)updateRootForUser:(nullable FIRUser *)user animated:(BOOL)animated;

- (void)reloadRootViewControllerForLanguageChange;
- (void)showDashboardWithDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile animated:(BOOL)animated;
- (void)openNotificationsTabFromNotificationPayload:(nullable NSDictionary *)payload;
/// Shows the dashboard for a server-resolved delivery workspace. When the
/// profile's primary workspace is the driver cockpit (driver-only or
/// restricted) and the account has no provider dashboard of its own, the
/// cockpit opens on top of the dashboard.
- (void)showDeliveryWorkspaceForProfile:(nonnull PPDeliveryCompanyProfile *)profile
                     hasProviderDashboard:(BOOL)hasProviderDashboard
                                 animated:(BOOL)animated;
/// Opens the unified driver cockpit on the dashboard tab, or focuses the one
/// already open. A task identifier is a request to focus; the cockpit
/// re-authorizes it with the backend before showing it.
- (void)openDriverCockpitWithTaskID:(nullable NSString *)taskID
                          authority:(nullable NSString *)authority
                          companyID:(nullable NSString *)companyID
                           animated:(BOOL)animated;
@end
