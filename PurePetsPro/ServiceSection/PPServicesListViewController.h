//
//  PPServicesListViewController.h
//  PurePetsPro
//
//  Created from absolute first principles. Category-defining flagship
//  service command center with Cockpit KPIs, dynamic category rail,
//  omni-search, interactive service cards, and quick pricing sheet.
//

#import <UIKit/UIKit.h>
#import "PPServiceModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPServicesListViewController : UIViewController
@end

@interface PPServiceQuickPricingSheet : UIViewController
- (instancetype)initWithService:(PPServiceModel *)service onUpdated:(nullable void(^)(void))onUpdated;
@end

NS_ASSUME_NONNULL_END
