#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPVetMedicineModel;

typedef void(^PPPharmacyMedicineEditorCompletion)(PPVetMedicineModel *medicine, UIImage * _Nullable image);

@interface PPPharmacyMedicineEditorViewController : UIViewController

- (instancetype)initWithMedicine:(nullable PPVetMedicineModel *)medicine
                      completion:(PPPharmacyMedicineEditorCompletion)completion;

@end

NS_ASSUME_NONNULL_END
