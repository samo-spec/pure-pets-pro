//
//  PPProInAppNotificationPresenter.h
//  PurePetsPro
//
//  In-app notification banner for Pro app (orders, deliveries, alerts).
//  Shows floating banner when app is in foreground for provider/admin notifications.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PPProCompanyDeliveryNotificationTappedNotification;
FOUNDATION_EXPORT NSString * const PPProNotificationPayloadTappedNotification;

@interface PPProInAppNotificationPresenter : NSObject

+ (instancetype)sharedPresenter;

/// Local Pro foreground-notification preferences. System delivery is still controlled by iOS Settings and backend eligibility.
+ (BOOL)notificationPreferencesAllowPayload:(nullable NSDictionary<NSString *, id> *)payload;
+ (BOOL)notificationPreferencesAllowSoundForPayload:(nullable NSDictionary<NSString *, id> *)payload;

/// Plays the bundled Pro notification tone when foreground notification sound is allowed.
- (void)playNotificationSound;

// Show notification for order-related events
- (void)showOrderNotificationWithOrderId:(NSString *)orderId
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle;

// Show notification for delivery-related events
- (void)showDeliveryNotificationWithOrderId:(NSString *)orderId
                                      title:(NSString *)title
                                   subtitle:(NSString *)subtitle;

- (void)showCompanyDeliveryNotificationWithPayload:(NSDictionary<NSString *, id> *)payload
                                              title:(NSString *)title
                                           subtitle:(NSString *)subtitle;

- (void)showNotificationWithPayload:(NSDictionary<NSString *, id> *)payload
                               title:(nullable NSString *)title
                            subtitle:(nullable NSString *)subtitle
                            iconName:(nullable NSString *)iconName
                         accentColor:(nullable UIColor *)accentColor;

// Generic in-app notification
- (void)showNotificationWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                      iconName:(NSString *)iconName
                     accentColor:(UIColor *)accentColor;

- (void)dismissCurrentNotificationAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
