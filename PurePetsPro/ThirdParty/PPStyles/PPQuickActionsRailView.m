//
//  PPQuickActionsRailView.m
//  PurePetsPro
//
//  Premium horizontal quick actions scroll rail for Pro dashboard.
//  Apple-level business control center design.
//

#import "PPQuickActionsRailView.h"
#import "PPButtonHelper.h"
#import "PPFunc+Haptics.h"
#import "Language.h"
#import "Styling.h"

static const CGFloat PPQuickActionRailItemWidth = 148.0;
static const CGFloat PPQuickActionRailItemHeight = 102.0;
static const CGFloat PPQuickActionRailCornerRadius = 28.0;
static const CGFloat PPQuickActionRailInnerPadding = 14.0;
static const CGFloat PPQuickActionRailSpacing = 12.0;
static const CGFloat PPQuickActionSectionCornerRadius = 28.0;
static const CGFloat PPQuickActionSectionInset = 16.0;
static const CGFloat PPQuickActionRailCardShadowInset = 4.0;

@interface PPQuickActionRailCell : UICollectionViewCell
- (void)configureWithItem:(PPDashboardQuickActionRailItem *)item style:(PPDashboardQuickActionRailStyle)style tintColor:(UIColor *)tintColor;
@end

@interface PPDashboardQuickActionRailItem ()
@end

@implementation PPDashboardQuickActionRailItem
+ (instancetype)itemWithTitleKey:(NSString *)titleKey
                       subtitleKey:(nullable NSString *)subtitleKey
                          iconName:(NSString *)iconName
                        badgeText:(nullable NSString *)badgeText
                           enabled:(BOOL)isEnabled
                      chevron:(BOOL)showsChevron
                         handler:(nullable void (^)(void))handler {
    PPDashboardQuickActionRailItem *item = [[PPDashboardQuickActionRailItem alloc] init];
    item.titleKey = titleKey;
    item.subtitleKey = subtitleKey;
    item.iconName = iconName;
    item.badgeText = badgeText;
    item.isEnabled = isEnabled;
    item.showsChevron = showsChevron;
    item.handler = handler;
    return item;
}
@end

@interface PPQuickActionsRailView ()<UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UIView *sectionCardView;
 @property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *trailingButton;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation PPQuickActionsRailView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_setupUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self pp_setupUI];
    }
    return self;
}

- (void)pp_setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.sectionCardView = [[UIView alloc] init];
    self.sectionCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sectionCardView.backgroundColor = UIColor.clearColor;
    self.sectionCardView.layer.cornerRadius = 0;
    self.sectionCardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.sectionCardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.sectionCardView.layer.shadowOpacity = 0.00;
    self.sectionCardView.layer.shadowRadius = 0.0;
    self.sectionCardView.layer.shadowOffset = CGSizeMake(0, 0.0);
    self.sectionCardView.clipsToBounds = NO;
    [self addSubview:self.sectionCardView];


    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [Styling fontBold:19.0];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 1;
    [self.sectionCardView addSubview:self.titleLabel];

    self.trailingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.trailingButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.trailingButton.layer.cornerRadius = 15.0;
    self.trailingButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.trailingButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.trailingButton.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.08].CGColor;
    self.trailingButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
    self.trailingButton.contentEdgeInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    self.trailingButton.titleLabel.font = [Styling fontMedium:12.0];
    [self.trailingButton setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    [self.trailingButton addTarget:self action:@selector(pp_didTapTrailingButton) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.trailingButton style:PPButtonAnimationStyleDefault];
    [self.sectionCardView addSubview:self.trailingButton];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = PPQuickActionRailSpacing;
    layout.minimumLineSpacing = PPQuickActionRailSpacing;
    layout.itemSize = CGSizeMake(PPQuickActionRailItemWidth, PPQuickActionRailItemHeight);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.clipsToBounds = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[PPQuickActionRailCell class] forCellWithReuseIdentifier:@"PPQuickActionRailCell"];
    [self.sectionCardView addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.sectionCardView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.sectionCardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.sectionCardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.sectionCardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],


        [self.titleLabel.topAnchor constraintEqualToAnchor:self.sectionCardView.topAnchor constant:PPQuickActionSectionInset],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.sectionCardView.leadingAnchor constant:PPQuickActionSectionInset],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingButton.leadingAnchor constant:-10.0],

        [self.trailingButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.trailingButton.trailingAnchor constraintEqualToAnchor:self.sectionCardView.trailingAnchor constant:-PPQuickActionSectionInset],
        [self.trailingButton.heightAnchor constraintEqualToConstant:30.0],

        [self.collectionView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:14.0],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.sectionCardView.leadingAnchor constant:0],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.sectionCardView.trailingAnchor constant:-0],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.sectionCardView.bottomAnchor constant:-PPQuickActionSectionInset],
        [self.collectionView.heightAnchor constraintEqualToConstant:PPQuickActionRailItemHeight],
    ]];

     [self pp_refreshSectionCopy];
}



- (void)setActions:(NSArray<PPDashboardQuickActionRailItem *> *)actions {
    _actions = [actions copy];
    [self.collectionView reloadData];
    [self pp_scrollToEndForRTLIfNeeded];
}

- (void)setTitleKey:(NSString *)titleKey {
    _titleKey = [titleKey copy];
    [self pp_refreshSectionCopy];
}

- (void)setSubtitleKey:(NSString *)subtitleKey {
    _subtitleKey = [subtitleKey copy];
    [self pp_refreshSectionCopy];
}

- (void)setTrailingTitleKey:(NSString *)trailingTitleKey {
    _trailingTitleKey = [trailingTitleKey copy];
    [self pp_refreshSectionCopy];
}

- (void)setTrailingHandler:(void (^)(void))trailingHandler {
    _trailingHandler = [trailingHandler copy];
    [self pp_refreshSectionCopy];
}

- (void)reloadActions {
    [self.collectionView reloadData];
    [self pp_scrollToEndForRTLIfNeeded];
}

- (void)pp_scrollToEndForRTLIfNeeded {
    if (!Language.isRTL) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        CGSize contentSize = self.collectionView.contentSize;
        CGSize boundsSize = self.collectionView.bounds.size;
        if (contentSize.width > 0 && boundsSize.width > 0 && contentSize.width > boundsSize.width) {
            CGFloat offsetX = contentSize.width - boundsSize.width;
            [self.collectionView setContentOffset:CGPointMake(offsetX, 0) animated:NO];
        }
    });
}

- (void)animateEntrance {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;
    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeTranslation(0, 16.0);

    [UIView animateWithDuration:0.6
                          delay:0.0
         usingSpringWithDamping:0.86
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pp_animateCellsEntrance];
    });
}

- (void)pp_refreshSectionCopy {
    self.titleLabel.text = self.titleKey.length ? kLang(self.titleKey) : @"";

    NSString *buttonTitle = self.trailingTitleKey.length ? kLang(self.trailingTitleKey) : @"";
    BOOL showsTrailing = buttonTitle.length > 0 && self.trailingHandler != nil;
    self.trailingButton.hidden = !showsTrailing;
    [self.trailingButton setTitle:buttonTitle forState:UIControlStateNormal];
}

- (void)pp_didTapTrailingButton {
    [PPFunc pp_playTapEffect];
    if (self.trailingHandler) {
        self.trailingHandler();
    }
}

- (void)pp_animateCellsEntrance {
    NSArray<UICollectionViewCell *> *cells = self.collectionView.visibleCells;
    [cells enumerateObjectsUsingBlock:^(UICollectionViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeScale(0.92, 0.92);
        [UIView animateWithDuration:0.45
                              delay:0.03 * idx
           usingSpringWithDamping:0.88
                initialSpringVelocity:0.3
                              options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.actions.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPQuickActionRailCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPQuickActionRailCell" forIndexPath:indexPath];
    PPDashboardQuickActionRailItem *item = self.actions[indexPath.item];
    [cell configureWithItem:item style:self.style tintColor:self.tintColorForIcons];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PPDashboardQuickActionRailItem *item = self.actions[indexPath.item];
    if (!item.isEnabled) return;

    PPQuickActionRailCell *cell = (PPQuickActionRailCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.1 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.18
                             delay:0
              usingSpringWithDamping:0.5
               initialSpringVelocity:3.0
                             options:UIViewAnimationOptionCurveEaseOut
                          animations:^{
            cell.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL completed) {
            if (item.handler) {
                item.handler();
            }
        }];
    }];
}

@end



@interface PPQuickActionRailCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *iconContainer;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIColor *currentActionColor;
@end

@implementation PPQuickActionRailCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_setupCell];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self pp_setupCell];
    }
    return self;
}

- (void)pp_setupCell {
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.cardView.layer.cornerRadius = PPQuickActionRailCornerRadius;
    self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.cardView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.06].CGColor;
    self.cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.cardView.layer.shadowOpacity = 0.10;
    self.cardView.layer.shadowRadius = 14.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 7.0);
    self.cardView.isAccessibilityElement = YES;
    [self.contentView addSubview:self.cardView];

    self.iconContainer = [[UIView alloc] init];
    self.iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconContainer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.04];
    self.iconContainer.layer.cornerRadius = 18.0;
    self.iconContainer.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconContainer.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.iconContainer.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.03].CGColor;
    [self.cardView addSubview:self.iconContainer];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconContainer addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:13.5];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.cardView addSubview:self.titleLabel];

    self.badgeLabel = [[UILabel alloc] init];
    self.badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.badgeLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:11.0];
    self.badgeLabel.textColor = UIColor.labelColor;
    self.badgeLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.18]
            : [UIColor colorWithWhite:0.0 alpha:0.08];
    }];
    self.badgeLabel.layer.cornerRadius = 9.0;
    self.badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.clipsToBounds = YES;
    self.badgeLabel.hidden = YES;
    [self.cardView addSubview:self.badgeLabel];

    self.chevronView = [[UIImageView alloc] init];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.tintColor = [UIColor secondaryLabelColor];
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
    [self.cardView addSubview:self.chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPQuickActionRailCardShadowInset],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPQuickActionRailCardShadowInset],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPQuickActionRailCardShadowInset],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-(PPQuickActionRailCardShadowInset + 2.0)],

        [self.iconContainer.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:PPQuickActionRailInnerPadding],
        [self.iconContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPQuickActionRailInnerPadding],
        [self.iconContainer.widthAnchor constraintEqualToConstant:36.0],
        [self.iconContainer.heightAnchor constraintEqualToConstant:36.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainer.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainer.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:20.0],
        [self.iconView.heightAnchor constraintEqualToConstant:20.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconContainer.bottomAnchor constant:11.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPQuickActionRailInnerPadding],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-8.0],
        [self.titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-PPQuickActionRailInnerPadding],

        [self.badgeLabel.centerYAnchor constraintEqualToAnchor:self.iconContainer.centerYAnchor],
        [self.badgeLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPQuickActionRailInnerPadding],
        [self.badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:18.0],
        [self.badgeLabel.heightAnchor constraintEqualToConstant:18.0],

        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPQuickActionRailInnerPadding],
        [self.chevronView.widthAnchor constraintEqualToConstant:10.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:14.0],
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            UIColor *fallbackColor = [self pp_ultraPremiumColorWithLightRed:0.000 green:0.445 blue:0.392
                                                                     darkRed:0.410 green:0.875 blue:0.800];
            [self pp_applySolidItemBackgroundWithActionColor:self.currentActionColor ?: fallbackColor];
        }
    } else {
        UIColor *fallbackColor = [self pp_ultraPremiumColorWithLightRed:0.000 green:0.445 blue:0.392
                                                                 darkRed:0.410 green:0.875 blue:0.800];
        [self pp_applySolidItemBackgroundWithActionColor:self.currentActionColor ?: fallbackColor];
    }
}

- (void)configureWithItem:(PPDashboardQuickActionRailItem *)item style:(PPDashboardQuickActionRailStyle)style tintColor:(UIColor *)tintColor {
    [self configureWithItem:item style:style tintColor:tintColor atIndex:0];
}

- (void)configureWithItem:(PPDashboardQuickActionRailItem *)item style:(PPDashboardQuickActionRailStyle)style tintColor:(UIColor *)tintColor atIndex:(NSUInteger)index {
#pragma unused(index)
    self.titleLabel.text = item.titleKey.length ? NSLocalizedString(item.titleKey, nil) : @"";

    UIImage *icon = [UIImage systemImageNamed:item.iconName];
    UIColor *actionColor = [self pp_premiumActionColorForItem:item style:style fallbackColor:tintColor];

    self.currentActionColor = actionColor;
    [self pp_applySolidItemBackgroundWithActionColor:actionColor];
    self.iconContainer.backgroundColor = [actionColor colorWithAlphaComponent:0.13];
    self.iconContainer.layer.borderColor = [actionColor colorWithAlphaComponent:0.12].CGColor;
    self.iconView.tintColor = actionColor;
    self.iconView.image = icon;
    self.cardView.layer.borderColor = [actionColor colorWithAlphaComponent:0.16].CGColor;
    self.cardView.layer.shadowColor = [actionColor colorWithAlphaComponent:0.22].CGColor;
    self.chevronView.tintColor = [actionColor colorWithAlphaComponent:0.74];

    self.badgeLabel.text = item.badgeText;
    self.badgeLabel.hidden = item.badgeText.length == 0;

    // Apply premium badge styling with action color for Sam iOS UI Artist APEX
    if (item.badgeText.length > 0 && actionColor) {
        self.badgeLabel.textColor = UIColor.whiteColor;
        self.badgeLabel.backgroundColor = actionColor;
        self.badgeLabel.layer.borderWidth = 0.0;
    } else {
        self.badgeLabel.textColor = UIColor.labelColor;
        self.badgeLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.18]
                : [UIColor colorWithWhite:0.0 alpha:0.08];
        }];
        self.badgeLabel.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        self.badgeLabel.layer.borderColor = [actionColor colorWithAlphaComponent:0.12].CGColor;
    }

    self.chevronView.hidden = !item.showsChevron;

    self.cardView.alpha = item.isEnabled ? 1.0 : 0.4;
    self.userInteractionEnabled = item.isEnabled;

    self.accessibilityLabel = item.titleKey.length ? NSLocalizedString(item.titleKey, nil) : @"";
    self.accessibilityHint = @"";
    self.isAccessibilityElement = item.isEnabled;
}

- (void)pp_applySolidItemBackgroundWithActionColor:(UIColor *)actionColor {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *baseColor = isDark
        ? [UIColor colorWithRed:0.090 green:0.096 blue:0.112 alpha:1.0]
        : [UIColor colorWithRed:0.988 green:0.982 blue:0.966 alpha:1.0];
    self.cardView.backgroundColor = [self pp_colorByBlendingBaseColor:baseColor
                                                            withColor:actionColor
                                                               amount:(isDark ? 0.22 : 0.11)];
}

- (UIColor *)pp_colorByBlendingBaseColor:(UIColor *)baseColor withColor:(UIColor *)overlayColor amount:(CGFloat)amount {
    UIColor *resolvedBase = baseColor;
    UIColor *resolvedOverlay = overlayColor;
    if (@available(iOS 13.0, *)) {
        resolvedBase = [baseColor resolvedColorWithTraitCollection:self.traitCollection];
        resolvedOverlay = [overlayColor resolvedColorWithTraitCollection:self.traitCollection];
    }

    CGFloat baseRed = 0.0, baseGreen = 0.0, baseBlue = 0.0, baseAlpha = 1.0;
    CGFloat overlayRed = 0.0, overlayGreen = 0.0, overlayBlue = 0.0, overlayAlpha = 1.0;
    if (![resolvedBase getRed:&baseRed green:&baseGreen blue:&baseBlue alpha:&baseAlpha] ||
        ![resolvedOverlay getRed:&overlayRed green:&overlayGreen blue:&overlayBlue alpha:&overlayAlpha]) {
        return [overlayColor colorWithAlphaComponent:amount];
    }

    CGFloat clampedAmount = MIN(MAX(amount, 0.0), 1.0);
    return [UIColor colorWithRed:(baseRed * (1.0 - clampedAmount)) + (overlayRed * clampedAmount)
                           green:(baseGreen * (1.0 - clampedAmount)) + (overlayGreen * clampedAmount)
                            blue:(baseBlue * (1.0 - clampedAmount)) + (overlayBlue * clampedAmount)
                           alpha:1.0];
}

- (UIColor *)pp_premiumActionColorForItem:(PPDashboardQuickActionRailItem *)item
                                    style:(PPDashboardQuickActionRailStyle)style
                            fallbackColor:(UIColor *)fallbackColor {
    NSString *signature = [NSString stringWithFormat:@"%@ %@", item.titleKey ?: @"", item.iconName ?: @""].lowercaseString;
    if ([signature containsString:@"fulfillment"] || [signature containsString:@"shippingbox"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.225 green:0.208 blue:0.510
                                              darkRed:0.690 green:0.655 blue:1.000];
    }
    if ([signature containsString:@"market"] || [signature containsString:@"bag"] || [signature containsString:@"branch"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.000 green:0.445 blue:0.392
                                              darkRed:0.410 green:0.875 blue:0.800];
    }
    if ([signature containsString:@"delivery"] || [signature containsString:@"truck"] || [signature containsString:@"location"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.050 green:0.275 blue:0.560
                                              darkRed:0.455 green:0.735 blue:1.000];
    }
    if ([signature containsString:@"pharmacy"] || [signature containsString:@"pill"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.085 green:0.520 blue:0.355
                                              darkRed:0.455 green:0.900 blue:0.635];
    }
    if ([signature containsString:@"vet"] || [signature containsString:@"cross"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.610 green:0.095 blue:0.170
                                              darkRed:1.000 green:0.515 blue:0.555];
    }
    if ([signature containsString:@"adopt"] || [signature containsString:@"heart"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.665 green:0.165 blue:0.390
                                              darkRed:1.000 green:0.565 blue:0.730];
    }
    if ([signature containsString:@"notification"] || [signature containsString:@"bell"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.695 green:0.355 blue:0.060
                                              darkRed:1.000 green:0.685 blue:0.310];
    }
    if ([signature containsString:@"support"] || [signature containsString:@"message"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.435 green:0.200 blue:0.565
                                              darkRed:0.795 green:0.610 blue:0.980];
    }
    if ([signature containsString:@"profile"] || [signature containsString:@"person"] || [signature containsString:@"pencil"] || [signature containsString:@"building"]) {
        return [self pp_ultraPremiumColorWithLightRed:0.455 green:0.335 blue:0.240
                                              darkRed:0.835 green:0.695 blue:0.560];
    }
    UIColor *styleFallback = style == PPDashboardQuickActionRailStyleDeliveryMember
        ? [self pp_ultraPremiumColorWithLightRed:0.050 green:0.275 blue:0.560
                                         darkRed:0.455 green:0.735 blue:1.000]
        : [self pp_ultraPremiumColorWithLightRed:0.000 green:0.445 blue:0.392
                                         darkRed:0.410 green:0.875 blue:0.800];
    return styleFallback;
}

- (UIColor *)pp_ultraPremiumColorWithLightRed:(CGFloat)lightRed
                                        green:(CGFloat)lightGreen
                                         blue:(CGFloat)lightBlue
                                      darkRed:(CGFloat)darkRed
                                        green:(CGFloat)darkGreen
                                         blue:(CGFloat)darkBlue {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL isDark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return [UIColor colorWithRed:(isDark ? darkRed : lightRed)
                                   green:(isDark ? darkGreen : lightGreen)
                                    blue:(isDark ? darkBlue : lightBlue)
                                   alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:lightRed green:lightGreen blue:lightBlue alpha:1.0];
}

@end
