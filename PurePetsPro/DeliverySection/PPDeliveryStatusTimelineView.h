//
//  PPDeliveryStatusTimelineView.h
//  PurePetsPro
//
//  Visual timeline showing order progression through delivery steps.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPDeliveryOrderModel;

@interface PPDeliveryStatusTimelineView : UIView

/// Update the timeline for the given order.
- (void)configureWithOrder:(PPDeliveryOrderModel *)order;

@end

NS_ASSUME_NONNULL_END
