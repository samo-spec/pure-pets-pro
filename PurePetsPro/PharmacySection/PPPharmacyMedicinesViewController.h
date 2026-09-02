#import <UIKit/UIKit.h>
#import "PPVetManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPPharmacyMedicinesViewController : UIViewController
@end

@interface PPPharmacyQuickStockSheet : UIViewController
- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine onUpdated:(nullable void(^)(void))onUpdated;
@end

@interface PPPharmacyMedicineDetailViewController : UIViewController
- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine onUpdated:(nullable void(^)(void))onUpdated;
@end

NS_ASSUME_NONNULL_END
