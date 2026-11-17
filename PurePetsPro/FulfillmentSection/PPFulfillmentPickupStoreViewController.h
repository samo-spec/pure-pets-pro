#import <UIKit/UIKit.h>
@class PPFulfillmentModel;

NS_ASSUME_NONNULL_BEGIN

/// Ephemeral review of Infra's authorized pickup projection. Does not dispatch.
@interface PPFulfillmentPickupStoreViewController : UIViewController
- (instancetype)initWithFulfillment:(PPFulfillmentModel *)fulfillment
                        completion:(void (^)(NSString * _Nullable branchID))completion;
@end

NS_ASSUME_NONNULL_END
