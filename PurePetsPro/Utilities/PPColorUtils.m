//
//  PPColorUtils.m
//  PurePetsPro
//

#import "PPColorUtils.h"

@implementation PPColorUtils

+ (UIColor *)pp_selectedCellColorFromPrimary
{
    return [self pp_selectedCellColorFromPrimaryWithAlpha:0.1f];
}

+ (UIColor *)pp_selectedCellColorFromPrimaryWithAlpha:(float)cusAlpha
{
    UIColor *primary = AppPrimaryClr ?: [UIColor systemBlueColor];
    return [primary colorWithAlphaComponent:MAX(0.0f, MIN(1.0f, cusAlpha))];
}

+ (UIColor *)pp_selectedCellColorFromPrimaryFull
{
    return AppPrimaryClr ?: [UIColor systemBlueColor];
}

@end
