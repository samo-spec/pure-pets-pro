//
//  PPServiceCell.h
//  PurePetsPro
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

+ (NSString *)reuseID;
+ (CGFloat)preferredHeight;
- (void)configureWithService:(PPServiceModel *)service;

@end

NS_ASSUME_NONNULL_END
