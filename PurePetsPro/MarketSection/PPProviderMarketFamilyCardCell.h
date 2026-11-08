#import <UIKit/UIKit.h>

@class PPProviderMarketDisplayGroup, PPProviderMarketItem;

// Shared family presentation. Actions always receive the exact member SKU.
@interface PPProviderMarketFamilyCardCell : UITableViewCell
@property (nonatomic, copy) void (^onExpandTapped)(void);
@property (nonatomic, copy) void (^onStudioTapped)(void);
@property (nonatomic, copy) void (^onMemberSelected)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onMemberStockTapped)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onMemberOfferTapped)(PPProviderMarketItem *item);
- (void)configureWithGroup:(PPProviderMarketDisplayGroup *)group;
- (void)updateExpandedState;
@end
