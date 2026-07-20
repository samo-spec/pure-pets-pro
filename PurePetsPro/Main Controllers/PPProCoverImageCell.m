//
//  PPProCoverImageCell.m
//  PurePetsPro
//
//  UITableViewCell subclass embedding PPImageCollection for cover image editing.
//

#import "PPProCoverImageCell.h"

@interface PPProCoverImageCell ()
@end

@implementation PPProCoverImageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        _imageCollection = [[PPImageCollection alloc] initWithFrame:CGRectZero];
        _imageCollection.translatesAutoresizingMaskIntoConstraints = NO;
        _imageCollection.delegate = self;
        _imageCollection.maxImageCount = 6;
        _imageCollection.allowsEditing = YES;
        _imageCollection.allowsReordering = YES;
        _imageCollection.useArabic = [kLang(@"lang") isEqualToString:@"ar"];
        _imageCollection.layer.cornerRadius = 16.0;
        _imageCollection.layer.cornerCurve = kCACornerCurveContinuous;
        _imageCollection.layer.masksToBounds = YES;
        _imageCollection.backgroundColor = [AppForgroundColr colorWithAlphaComponent:1];
        [self.contentView addSubview:_imageCollection];

        [NSLayoutConstraint activateConstraints:@[
            [_imageCollection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
            [_imageCollection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_imageCollection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_imageCollection.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],
            [_imageCollection.heightAnchor constraintGreaterThanOrEqualToConstant:110.0],
        ]];
    }
    return self;
}

- (void)setMaxImages:(NSInteger)maxImages {
    _maxImages = MAX(1, maxImages);
    _imageCollection.maxImageCount = _maxImages;
}

- (void)preloadExistingImages {
    if (_didPreload || _existingImageURLs.count == 0) return;
    __weak typeof(self) weakSelf = self;
    [_imageCollection preloadImagesFromURLs:_existingImageURLs completion:^{
        weakSelf.didPreload = YES;
    }];
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    if (self.didPreload && self.imagesDidChange) {
        self.imagesDidChange(@[]);
    }
}

- (void)imageCollection:(PPImageCollection *)collection didSelectImage:(UIImage *)selectedImage AtIndex:(NSInteger)index {
    // Handled internally by PPImageCollection (viewer presentation).
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    // Handled internally by PPImageCollection (picker presentation).
}

@end
