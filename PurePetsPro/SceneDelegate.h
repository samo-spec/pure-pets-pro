//
//  SceneDelegate.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import <UIKit/UIKit.h>

@class PPDeliveryCompanyProfile;

typedef NS_ENUM(NSInteger, AppRoot) {
    AppRootSplash,
    AppRootLogin,
    AppRootDashboard,
    AppRootProviderStatus
};

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow * window;

- (void)reloadRootViewControllerForLanguageChange;
- (void)showDashboardWithDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile animated:(BOOL)animated;
- (void)openNotificationsTabFromNotificationPayload:(nullable NSDictionary *)payload;
@end
