//
//  PPProCoverImageCell.h
//  PurePetsPro
//
//  UITableViewCell subclass embedding PPImageCollection for cover image editing.
//

#import <UIKit/UIKit.h>
#import "PPImageCollection.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPProCoverImageCell : UITableViewCell <PPImageCollectionDelegate>

@property (nonatomic, strong, readonly) PPImageCollection *imageCollection;
@property (nonatomic, strong, nullable) NSArray<NSString *> *existingImageURLs;
@property (nonatomic, assign) NSInteger maxImages;
@property (nonatomic, assign) BOOL didPreload;
@property (nonatomic, copy, nullable) void (^imagesDidChange)(NSArray<NSString *> *urls);

- (void)preloadExistingImages;

@end

NS_ASSUME_NONNULL_END
