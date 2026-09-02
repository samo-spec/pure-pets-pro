//
//  PPProPriorityFulfillmentCard.h
//  PurePetsPro
//
//  Created on 31/08/2026.
//

#import <UIKit/UIKit.h>
#import "PPFulfillmentModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPProPriorityFulfillmentCard : UIView

@property (nonatomic, copy, nullable) void (^actionHandler)(void);

@property (nonatomic, strong, readonly) UILabel *eyebrowLabel;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *badgeLabel;
@property (nonatomic, strong, readonly) UIView *badgeView;
@property (nonatomic, strong, readonly) UIButton *actionButton;
@property (nonatomic, strong, readonly) UIView *iconContainerView;
@property (nonatomic, strong, readonly) UIImageView *iconImageView;

- (void)updateWithFulfillmentModel:(nullable PPFulfillmentModel *)model pendingCount:(NSInteger)pendingCount;

@end

NS_ASSUME_NONNULL_END
