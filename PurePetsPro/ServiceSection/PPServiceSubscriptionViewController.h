//
//  PPServiceSubscriptionViewController.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;

@interface PPServiceSubscriptionViewController : UIViewController
- (instancetype)initWithService:(PPServiceModel *)service;
@end

NS_ASSUME_NONNULL_END
