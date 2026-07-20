//
//  PPDeliveryOrderCell.h
//  PurePetsPro
//
//  Modern card-style collection view cell for delivery orders.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPDeliveryOrderModel;

extern NSString * const PPDeliveryOrderCellIdentifier;

@interface PPDeliveryOrderCell : UICollectionViewCell

+ (CGFloat)preferredHeight;
- (void)configureWithOrder:(PPDeliveryOrderModel *)order;

@end

NS_ASSUME_NONNULL_END
