//
//  PPServiceCell.h
//  PurePetsPro
//
//  NextGen V8 Studio-Grade Pet Service Atelier Card.
//  Continuous spatial curvature, species vector emblem, micro-stepper tap zone,
//  and tactile inline availability switch.
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
@property (nonatomic, copy, nullable) void(^onTapPricing)(void);

+ (NSString *)reuseID;
+ (CGFloat)preferredHeight;
- (void)configureWithService:(PPServiceModel *)service;

@end

NS_ASSUME_NONNULL_END
