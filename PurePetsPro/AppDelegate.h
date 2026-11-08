//
//  AppDelegate.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <FirebaseMessaging/FirebaseMessaging.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, FIRMessagingDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) NSString *fcmToken;

+ (BOOL)pp_isNotificationPayloadRoutable:(NSDictionary *)payload;

/// YES when the payload is addressed to the account `uid`. Notifications V2
/// stamps `targetUid` on every push and inbox items carry `targetUserID`.
/// With `requiresRecipient`, a payload that names no account is treated as
/// belonging to nobody.
+ (BOOL)pp_notificationPayload:(NSDictionary *)payload
              isAddressedToUID:(NSString *)uid
             requiresRecipient:(BOOL)requiresRecipient;

@end
