// NotificationsListViewController.h
#import <UIKit/UIKit.h>
#import "NotificationDetailViewController.h"
NS_ASSUME_NONNULL_BEGIN

@interface NotificationsListViewController : UIViewController

- (void)handleNotificationRoutePayload:(nullable NSDictionary *)payload;

/// Opens the newest unread inbox item once the authenticated live inbox has
/// delivered a snapshot. If no unread item remains, the user stays in the inbox.
- (void)pp_openNewestUnreadNotificationWhenReady;

@end

NS_ASSUME_NONNULL_END
//- (instancetype)initWithUserID:(NSString *)uid; 
