//
//  PPServiceCell.h
//  PurePetsPro
//
//  Category-defining service card with spatial continuous curvature,
//  multi-tag pet species pills, inline availability switch, and live price badge.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;

@interface PPServiceCell : UITableViewCell

@property (nonatomic, strong, readonly) UIImageView *serviceImageView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *priceLabel;
@property (nonatomic, strong, readonly) UILabel *statusBadge;
@property (nonatomic, strong, readonly) UIView *cardView;
@property (nonatomic, strong, readonly) UISwitch *inlineSwitch;
@property (nonatomic, copy, nullable) void(^onToggleAvailability)(BOOL newAvailable);

+ (NSString *)reuseID;
+ (CGFloat)preferredHeight;
- (void)configureWithService:(PPServiceModel *)service;

@end

NS_ASSUME_NONNULL_END
