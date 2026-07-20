//
//  PPAddEditServiceViewController.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;

@interface PPAddEditServiceViewController : XLFormViewController
@property (nonatomic, strong, nullable) PPServiceModel *serviceToEdit;
- (instancetype)initWithService:(PPServiceModel * _Nullable)service;
@end

NS_ASSUME_NONNULL_END

