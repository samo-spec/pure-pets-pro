//
//  AdminDashboardViewController.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 21/08/2025.
//


//
//  AdminDashboardViewController.h
//  PurePetsAdmin
//

#import "PPParallax.h"
#import "PPQuickActionsRailView.h"
#import <PhotosUI/PhotosUI.h>

@class PPDeliveryCompanyProfile;

NS_ASSUME_NONNULL_BEGIN

@interface AdminDashboardViewController : XLFormViewController<PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) BOOL didAskForBiometric;
@property (nonatomic, copy) NSString *deliveryCompanyId;
@property (nonatomic, copy) NSString *deliveryCompanyName;
@property (nonatomic, copy) NSString *memberRole;
@property (nonatomic, assign) BOOL isDeliveryCompanyMode;
@property (nonatomic, strong) PPQuickActionsRailView *quickActionsRailView;
@property (nonatomic, assign) PPDashboardQuickActionRailStyle quickActionsRailStyle;
// .h
@property (nonatomic, strong) UIView *headerRoot;        // full-width container (clear)
@property (nonatomic, strong) UIView *headerCard;        // the rounded glass card inside
@property (nonatomic, strong) PPParallax *parallax;

- (instancetype)initWithDeliveryCompanyProfile:(nullable PPDeliveryCompanyProfile *)profile;
- (void)configureDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile;

@end

NS_ASSUME_NONNULL_END
