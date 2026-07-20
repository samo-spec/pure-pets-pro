//
//  PPAdoptPetsListViewController.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>
#import "PPAdoptPetModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPAdoptPetsListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSMutableArray<PPAdoptPetModel *> *adoptPets;

@end

NS_ASSUME_NONNULL_END