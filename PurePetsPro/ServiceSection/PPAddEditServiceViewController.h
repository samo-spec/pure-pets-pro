//
//  PPAddEditServiceViewController.h
//  PurePetsPro
//
//  Category-defining service creation studio with live customer preview,
//  bespoke photography studio, species chips, pricing engine, and floating dock.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;

@interface PPAddEditServiceViewController : UIViewController

@property (nonatomic, strong, nullable) PPServiceModel *serviceToEdit;

- (instancetype)initWithService:(PPServiceModel * _Nullable)service;
- (instancetype)initWithTemplate:(PPServiceModel * _Nullable)templateModel;

@end

NS_ASSUME_NONNULL_END

