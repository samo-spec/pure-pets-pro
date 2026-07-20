#import <UIKit/UIKit.h>

@class PPFulfillmentModel;

@interface PPFulfillmentCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)preferredHeight;

- (void)configureWithModel:(PPFulfillmentModel *)model;

@end
