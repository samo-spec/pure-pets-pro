//
//  PPProPriorityNotificationCard.h
//  PurePetsPro
//
//  Created on 31/08/2026.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPProPriorityNotificationCard : UIView

@property (nonatomic, copy, nullable) void (^actionHandler)(void);

@property (nonatomic, strong, readonly) UILabel *eyebrowLabel;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *badgeLabel;
@property (nonatomic, strong, readonly) UIView *badgeView;
@property (nonatomic, strong, readonly) UIButton *actionButton;
@property (nonatomic, strong, readonly) UIView *iconContainerView;
@property (nonatomic, strong, readonly) UIImageView *iconImageView;

- (void)updateUnreadCount:(NSInteger)unreadCount;
- (void)setBadgeCountString:(nullable NSString *)badgeString;

@end

NS_ASSUME_NONNULL_END
