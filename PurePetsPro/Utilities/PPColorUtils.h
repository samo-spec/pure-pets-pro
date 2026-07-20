//
//  PPColorUtils.h
//  PurePetsPro
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPColorUtils : NSObject

+ (UIColor *)pp_selectedCellColorFromPrimary;
+ (UIColor *)pp_selectedCellColorFromPrimaryWithAlpha:(float)cusAlpha;
+ (UIColor *)pp_selectedCellColorFromPrimaryFull;

@end

NS_ASSUME_NONNULL_END
