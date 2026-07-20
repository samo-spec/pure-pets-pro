#import <UIKit/UIKit.h>

@class PPDeliveryCompanyProfile;

NS_ASSUME_NONNULL_BEGIN

@interface PPDeliveryCompanyDetailViewController : UIViewController
- (instancetype)initWithRequestID:(NSString *)requestID profile:(PPDeliveryCompanyProfile *)profile;
@end

NS_ASSUME_NONNULL_END
