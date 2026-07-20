#import <UIKit/UIKit.h>
#import "PPProviderMarketplaceManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPMarketplaceBranchesViewController : UIViewController

- (instancetype)initForSelectionWithCompletion:(void (^)(PPMarketplaceBranch *branch))completion;

@end

NS_ASSUME_NONNULL_END
