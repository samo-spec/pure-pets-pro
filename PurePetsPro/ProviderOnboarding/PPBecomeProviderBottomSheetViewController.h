#import <UIKit/UIKit.h>
#import "PPProviderApplicationManager.h"

NS_ASSUME_NONNULL_BEGIN

@class PPBecomeProviderBottomSheetViewController;

@protocol PPBecomeProviderBottomSheetViewControllerDelegate <NSObject>
- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller;
@end

@interface PPBecomeProviderBottomSheetViewController : UIViewController

@property (nonatomic, weak, nullable) id<PPBecomeProviderBottomSheetViewControllerDelegate> delegate;

- (instancetype)initWithState:(PPProviderOnboardingState *)state
          eligibleProviderTypes:(NSArray<NSNumber *> *)eligibleProviderTypes
            preferredProviderType:(PPProviderType)preferredProviderType;

@end

NS_ASSUME_NONNULL_END
