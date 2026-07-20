// NotificationsListViewController.h
#import <UIKit/UIKit.h>
#import "NotificationDetailViewController.h"
NS_ASSUME_NONNULL_BEGIN

@interface NotificationsListViewController : UIViewController

- (void)handleNotificationRoutePayload:(nullable NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
//- (instancetype)initWithUserID:(NSString *)uid; 
