#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPProviderSubscriptionManagmetVC : UIViewController

@property (nonatomic, assign) BOOL prefersAutoPresentBecomeProvider;
@property (nonatomic, assign) BOOL suppressAutoDashboardTransition;
/// Nil opens the full inventory. A stable ID opens only that owned agreement.
@property (nonatomic, copy, nullable) NSString *selectedSubscriptionProfileID;

@end

NS_ASSUME_NONNULL_END
