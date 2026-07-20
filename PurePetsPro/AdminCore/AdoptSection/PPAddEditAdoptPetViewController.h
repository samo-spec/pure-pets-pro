//
//  PPAddEditAdoptPetViewController.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>
#import "PPAdoptPetModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPAddEditAdoptPetViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) PPAdoptPetModel *pet;

- (instancetype)initWithPet:(nullable PPAdoptPetModel *)pet;

@end

NS_ASSUME_NONNULL_END