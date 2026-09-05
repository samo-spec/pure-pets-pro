//
//  PPServiceTemplatePickerViewController.h
//  PurePetsPro
//
//  Curated professional starter templates for pet grooming, training, care, and boarding.
//  Enables service providers to launch high-converting offers in 5 seconds.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceModel;

@interface PPServiceTemplatePickerViewController : UIViewController

@property (nonatomic, copy, nullable) void(^onSelectTemplate)(PPServiceModel *templateModel);

@end

NS_ASSUME_NONNULL_END
