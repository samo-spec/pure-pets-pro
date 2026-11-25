//
//  PPServiceRequestsViewController.h
//  PurePetsPro
//
//  Category-defining NextGen V10 Live Service Bookings & Over-Follow Pipeline.
//  Real-time tracking of pet owner reservations across stages:
//  New -> Scheduled -> In-Progress -> Completed.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPServiceBookingItem;

@interface PPServiceRequestsViewController : UIViewController

/// Optional filter to a specific service ID or initial stage index (0 = New, 1 = Scheduled, 2 = In-Progress, 3 = Completed)
@property (nonatomic, copy, nullable) NSString *initialServiceID;
@property (nonatomic, assign) NSInteger initialStageIndex;

@end

NS_ASSUME_NONNULL_END
