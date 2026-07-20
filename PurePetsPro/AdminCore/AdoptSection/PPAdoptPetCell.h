//
//  PPAdoptPetCell.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>
#import "PPAdoptPetModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPAdoptPetCell : UITableViewCell

@property (nonatomic, strong) UILabel *petTitle;
@property (nonatomic, strong) UILabel *petDescription;
@property (nonatomic, strong) UILabel *adopterInfoLabel;

- (void)configureWithAdoptPet:(PPAdoptPetModel *)pet;

@end

NS_ASSUME_NONNULL_END