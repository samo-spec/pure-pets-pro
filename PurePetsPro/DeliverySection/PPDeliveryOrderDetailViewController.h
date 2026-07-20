//
//  PPDeliveryOrderDetailViewController.h
//  PurePetsPro
//
//  Order detail with timeline, contact actions, and status update buttons.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPDeliveryOrderModel;

@interface PPDeliveryOrderDetailViewController : UIViewController

- (instancetype)initWithOrder:(PPDeliveryOrderModel *)order;
- (UIView *)infoRowWithIcon:(NSString *)iconName iconColor:(UIColor *)iconColor text:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor;

@end

NS_ASSUME_NONNULL_END
