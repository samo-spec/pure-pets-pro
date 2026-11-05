#import "PPProviderMarketItemsViewController.h"
#import "PPProviderMarketItemEditorViewController.h"
#import "PPProviderMarketItem.h"
#import "PPProviderMarketplaceManager.h"
#import "PPMarketplaceBranchesViewController.h"
#import "PPFirebaseCompat.h"
#import "PPToast.h"
#import "PPHUD.h"
#import "PPAlertHelper.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import "PurePetsPro-Swift.h"

// MARK: - Multi-Dimensional Filter & Sort Criteria

typedef NS_ENUM(NSInteger, PPProviderMarketStockFilter) {
    PPProviderMarketStockFilterAll = 0,
    PPProviderMarketStockFilterInStock,
    PPProviderMarketStockFilterLowStock
};

typedef NS_ENUM(NSInteger, PPProviderMarketOfferFilter) {
    PPProviderMarketOfferFilterAll = 0,
    PPProviderMarketOfferFilterOffersOnly
};

typedef NS_ENUM(NSInteger, PPProviderMarketVisibilityFilter) {
    PPProviderMarketVisibilityFilterAll = 0,
    PPProviderMarketVisibilityFilterHiddenOnly
};

typedef NS_ENUM(NSInteger, PPProviderMarketKindFilter) {
    PPProviderMarketKindFilterAll = 0,
    PPProviderMarketKindFilterAccessories,
    PPProviderMarketKindFilterFood
};

typedef NS_ENUM(NSInteger, PPProviderMarketFilter) {
    PPProviderMarketFilterAll = 0,
    PPProviderMarketFilterInStock,
    PPProviderMarketFilterLowStock,
    PPProviderMarketFilterOffers,
    PPProviderMarketFilterHidden,
    PPProviderMarketFilterAccessories,
    PPProviderMarketFilterFood
};

typedef NS_ENUM(NSInteger, PPProviderMarketSort) {
    PPProviderMarketSortNewest = 0,
    PPProviderMarketSortPriceLowToHigh,
    PPProviderMarketSortPriceHighToLow,
    PPProviderMarketSortStockHighest,
    PPProviderMarketSortStockLowest
};

@interface PPProviderMarketFilterCriteria : NSObject <NSCopying>
@property (nonatomic, assign) PPProviderMarketStockFilter stockFilter;
@property (nonatomic, assign) PPProviderMarketOfferFilter offerFilter;
@property (nonatomic, assign) PPProviderMarketVisibilityFilter visibilityFilter;
@property (nonatomic, assign) PPProviderMarketKindFilter kindFilter;
@property (nonatomic, assign) PPProviderMarketSort sort;

+ (instancetype)criteriaFromLegacyFilter:(PPProviderMarketFilter)filter sort:(PPProviderMarketSort)sort;
- (PPProviderMarketFilter)primaryLegacyFilter;
- (BOOL)isDefault;
- (void)reset;
- (NSInteger)activeFilterCount;
- (BOOL)evaluatesItem:(PPProviderMarketItem *)item;
@end

@implementation PPProviderMarketFilterCriteria

+ (instancetype)criteriaFromLegacyFilter:(PPProviderMarketFilter)filter sort:(PPProviderMarketSort)sort {
    PPProviderMarketFilterCriteria *c = [[self alloc] init];
    c.sort = sort;
    switch (filter) {
        case PPProviderMarketFilterAll: break;
        case PPProviderMarketFilterInStock: c.stockFilter = PPProviderMarketStockFilterInStock; break;
        case PPProviderMarketFilterLowStock: c.stockFilter = PPProviderMarketStockFilterLowStock; break;
        case PPProviderMarketFilterOffers: c.offerFilter = PPProviderMarketOfferFilterOffersOnly; break;
        case PPProviderMarketFilterHidden: c.visibilityFilter = PPProviderMarketVisibilityFilterHiddenOnly; break;
        case PPProviderMarketFilterAccessories: c.kindFilter = PPProviderMarketKindFilterAccessories; break;
        case PPProviderMarketFilterFood: c.kindFilter = PPProviderMarketKindFilterFood; break;
    }
    return c;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    PPProviderMarketFilterCriteria *copy = [[[self class] allocWithZone:zone] init];
    copy.stockFilter = self.stockFilter;
    copy.offerFilter = self.offerFilter;
    copy.visibilityFilter = self.visibilityFilter;
    copy.kindFilter = self.kindFilter;
    copy.sort = self.sort;
    return copy;
}

- (void)reset {
    _stockFilter = PPProviderMarketStockFilterAll;
    _offerFilter = PPProviderMarketOfferFilterAll;
    _visibilityFilter = PPProviderMarketVisibilityFilterAll;
    _kindFilter = PPProviderMarketKindFilterAll;
    _sort = PPProviderMarketSortNewest;
}

- (BOOL)isDefault {
    return (_stockFilter == PPProviderMarketStockFilterAll &&
            _offerFilter == PPProviderMarketOfferFilterAll &&
            _visibilityFilter == PPProviderMarketVisibilityFilterAll &&
            _kindFilter == PPProviderMarketKindFilterAll &&
            _sort == PPProviderMarketSortNewest);
}

- (NSInteger)activeFilterCount {
    NSInteger count = 0;
    if (_stockFilter != PPProviderMarketStockFilterAll) count++;
    if (_offerFilter != PPProviderMarketOfferFilterAll) count++;
    if (_visibilityFilter != PPProviderMarketVisibilityFilterAll) count++;
    if (_kindFilter != PPProviderMarketKindFilterAll) count++;
    if (_sort != PPProviderMarketSortNewest) count++;
    return count;
}

- (PPProviderMarketFilter)primaryLegacyFilter {
    if (_stockFilter == PPProviderMarketStockFilterInStock) return PPProviderMarketFilterInStock;
    if (_stockFilter == PPProviderMarketStockFilterLowStock) return PPProviderMarketFilterLowStock;
    if (_offerFilter == PPProviderMarketOfferFilterOffersOnly) return PPProviderMarketFilterOffers;
    if (_visibilityFilter == PPProviderMarketVisibilityFilterHiddenOnly) return PPProviderMarketFilterHidden;
    if (_kindFilter == PPProviderMarketKindFilterAccessories) return PPProviderMarketFilterAccessories;
    if (_kindFilter == PPProviderMarketKindFilterFood) return PPProviderMarketFilterFood;
    return PPProviderMarketFilterAll;
}

- (BOOL)evaluatesItem:(PPProviderMarketItem *)item {
    if (!item) return NO;
    if (_stockFilter == PPProviderMarketStockFilterInStock) {
        if (item.noStock || item.quantity <= 5) return NO;
    } else if (_stockFilter == PPProviderMarketStockFilterLowStock) {
        if (!item.noStock && item.quantity > 5) return NO;
    }
    if (_offerFilter == PPProviderMarketOfferFilterOffersOnly) {
        if (!item.hasOffer) return NO;
    }
    if (_visibilityFilter == PPProviderMarketVisibilityFilterHiddenOnly) {
        if (item.showInAppMarket && !item.isArchived) return NO;
    }
    if (_kindFilter == PPProviderMarketKindFilterAccessories) {
        if (item.accessKindType != 1) return NO;
    } else if (_kindFilter == PPProviderMarketKindFilterFood) {
        if (item.accessKindType != 2 && item.accessKindType != 0) return NO;
    }
    return YES;
}

@end

// MARK: - Quick Stock Adjustment Sheet Interface & Implementation

@interface PPProviderQuickStockSheet : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) PPProviderMarketItem *item;
@property (nonatomic, copy) void (^onUpdated)(void);
@property (nonatomic, assign) NSInteger currentQuantity;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, strong) UILabel *healthStatusLabel;
@property (nonatomic, strong) UIView *healthStatusBadge;
@property (nonatomic, strong) UITextField *directInputField;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIActivityIndicatorView *saveSpinner;
- (instancetype)initWithItem:(PPProviderMarketItem *)item;
@end

@implementation PPProviderQuickStockSheet

- (instancetype)initWithItem:(PPProviderMarketItem *)item {
    self = [super init];
    if (self) {
        _item = item;
        _currentQuantity = item.quantity;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupUI];
    [self updateDisplay];
}

- (void)setupUI {
    // Sheet Drag Handle
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    // Header Container
    UIView *headerCard = [[UIView alloc] init];
    headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(headerCard, PPCornerMedium);
    [self.view addSubview:headerCard];

    UIImageView *thumb = [[UIImageView alloc] init];
    thumb.translatesAutoresizingMaskIntoConstraints = NO;
    thumb.contentMode = UIViewContentModeScaleAspectFill;
    thumb.clipsToBounds = YES;
    PPApplyContinuousCorners(thumb, PPCornerSmall);
    thumb.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    if (self.item.imageURLsArray.firstObject.length > 0) {
        [thumb setImageURL:[NSURL URLWithString:self.item.imageURLsArray.firstObject]];
    } else {
        thumb.image = [UIImage systemImageNamed:@"shippingbox.fill"];
        thumb.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.3];
    }
    [headerCard addSubview:thumb];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = self.item.name.length ? self.item.name : self.item.nameEn;
    titleLabel.font = [Styling fontBold:16.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    [headerCard addSubview:titleLabel];

    UILabel *sheetTitle = [[UILabel alloc] init];
    sheetTitle.translatesAutoresizingMaskIntoConstraints = NO;
    sheetTitle.text = kLang(@"Market_StockSheet_Title");
    sheetTitle.font = [Styling fontMedium:12.5];
    sheetTitle.textColor = [UIColor ppPrimary];
    sheetTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:sheetTitle];

    // Big Digital Counter Area
    UIView *counterCard = [[UIView alloc] init];
    counterCard.translatesAutoresizingMaskIntoConstraints = NO;
    counterCard.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.8];
    counterCard.layer.borderWidth = 0.8;
    counterCard.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.7].CGColor;
    PPApplyContinuousCorners(counterCard, PPCornerCard);
    [self.view addSubview:counterCard];

    self.quantityLabel = [[UILabel alloc] init];
    self.quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.quantityLabel.font = [UIFont systemFontOfSize:42 weight:UIFontWeightHeavy];
    self.quantityLabel.textColor = [UIColor ppTextPrimary];
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    [counterCard addSubview:self.quantityLabel];

    self.healthStatusBadge = [[UIView alloc] init];
    self.healthStatusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.healthStatusBadge, PPCornerSmall);
    [counterCard addSubview:self.healthStatusBadge];

    self.healthStatusLabel = [[UILabel alloc] init];
    self.healthStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.healthStatusLabel.font = [Styling fontBold:12.0];
    self.healthStatusLabel.textAlignment = NSTextAlignmentCenter;
    [self.healthStatusBadge addSubview:self.healthStatusLabel];

    // Stepper Buttons
    UIButton *minusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minusBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [minusBtn setImage:[UIImage systemImageNamed:@"minus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    minusBtn.tintColor = [UIColor ppTextPrimary];
    minusBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(minusBtn, 24);
    [minusBtn addTarget:self action:@selector(minusTapped) forControlEvents:UIControlEventTouchUpInside];
    [counterCard addSubview:minusBtn];

    UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    plusBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [plusBtn setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    plusBtn.tintColor = UIColor.whiteColor;
    plusBtn.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(plusBtn, 24);
    PPApplyButtonShadow(plusBtn);
    [plusBtn addTarget:self action:@selector(plusTapped) forControlEvents:UIControlEventTouchUpInside];
    [counterCard addSubview:plusBtn];

    // Quick Delta Chips Row
    UIScrollView *deltaScroll = [[UIScrollView alloc] init];
    deltaScroll.translatesAutoresizingMaskIntoConstraints = NO;
    deltaScroll.showsHorizontalScrollIndicator = NO;
    deltaScroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:deltaScroll];

    UIStackView *deltaStack = [[UIStackView alloc] init];
    deltaStack.translatesAutoresizingMaskIntoConstraints = NO;
    deltaStack.axis = UILayoutConstraintAxisHorizontal;
    deltaStack.spacing = 8.0;
    deltaStack.alignment = UIStackViewAlignmentCenter;
    [deltaScroll addSubview:deltaStack];

    NSArray<NSNumber *> *deltas = @[@(-10), @(-5), @(-1), @(1), @(5), @(10), @(25), @(50)];
    for (NSNumber *num in deltas) {
        NSInteger val = num.integerValue;
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        NSString *title = val > 0 ? [NSString stringWithFormat:@"+%ld", (long)val] : [NSString stringWithFormat:@"%ld", (long)val];
        [chip setTitle:title forState:UIControlStateNormal];
        chip.titleLabel.font = [Styling fontBold:13.5];
        chip.tintColor = val > 0 ? [UIColor ppPrimary] : [UIColor ppTextSecondary];
        chip.backgroundColor = val > 0 ? [[UIColor ppPrimary] colorWithAlphaComponent:0.08] : [[UIColor ppTextTertiary] colorWithAlphaComponent:0.12];
        PPApplyContinuousCorners(chip, 14);
        chip.tag = val;
        [chip addTarget:self action:@selector(deltaChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintEqualToConstant:34].active = YES;
        [chip.widthAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
        [deltaStack addArrangedSubview:chip];
    }

    // Direct Input & Preset Buttons Row
    UIStackView *presetStack = [[UIStackView alloc] init];
    presetStack.translatesAutoresizingMaskIntoConstraints = NO;
    presetStack.axis = UILayoutConstraintAxisHorizontal;
    presetStack.spacing = 10.0;
    presetStack.distribution = UIStackViewDistributionFillEqually;
    [self.view addSubview:presetStack];

    UIButton *zeroPreset = [UIButton buttonWithType:UIButtonTypeSystem];
    [zeroPreset setTitle:kLang(@"Market_StockSheet_ResetZero") forState:UIControlStateNormal];
    zeroPreset.titleLabel.font = [Styling fontBold:13.0];
    zeroPreset.tintColor = [UIColor ppError];
    zeroPreset.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.09];
    PPApplyContinuousCorners(zeroPreset, 14);
    [zeroPreset addTarget:self action:@selector(zeroPresetTapped) forControlEvents:UIControlEventTouchUpInside];
    [presetStack addArrangedSubview:zeroPreset];

    UIButton *abundantPreset = [UIButton buttonWithType:UIButtonTypeSystem];
    [abundantPreset setTitle:kLang(@"Market_StockSheet_Abundant") forState:UIControlStateNormal];
    abundantPreset.titleLabel.font = [Styling fontBold:13.0];
    abundantPreset.tintColor = [UIColor ppSuccess];
    abundantPreset.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(abundantPreset, 14);
    [abundantPreset addTarget:self action:@selector(abundantPresetTapped) forControlEvents:UIControlEventTouchUpInside];
    [presetStack addArrangedSubview:abundantPreset];

    // Save Action Button
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setTitle:kLang(@"Market_StockSheet_Save") forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [Styling fontBold:16.0];
    self.saveButton.tintColor = UIColor.whiteColor;
    self.saveButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.saveButton, 22);
    PPApplyButtonShadow(self.saveButton);
    [self.saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.saveButton];

    self.saveSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.saveSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveSpinner.color = UIColor.whiteColor;
    self.saveSpinner.hidesWhenStopped = YES;
    [self.saveButton addSubview:self.saveSpinner];

    // Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [headerCard.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:14],
        [headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerCard.heightAnchor constraintEqualToConstant:64],

        [thumb.leadingAnchor constraintEqualToAnchor:headerCard.leadingAnchor constant:10],
        [thumb.centerYAnchor constraintEqualToAnchor:headerCard.centerYAnchor],
        [thumb.widthAnchor constraintEqualToConstant:44],
        [thumb.heightAnchor constraintEqualToConstant:44],

        [titleLabel.leadingAnchor constraintEqualToAnchor:thumb.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerCard.trailingAnchor constant:-12],
        [titleLabel.topAnchor constraintEqualToAnchor:thumb.topAnchor constant:3],

        [sheetTitle.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [sheetTitle.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [sheetTitle.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],

        [counterCard.topAnchor constraintEqualToAnchor:headerCard.bottomAnchor constant:14],
        [counterCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [counterCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [counterCard.heightAnchor constraintEqualToConstant:120],

        [minusBtn.leadingAnchor constraintEqualToAnchor:counterCard.leadingAnchor constant:16],
        [minusBtn.centerYAnchor constraintEqualToAnchor:counterCard.centerYAnchor],
        [minusBtn.widthAnchor constraintEqualToConstant:48],
        [minusBtn.heightAnchor constraintEqualToConstant:48],

        [plusBtn.trailingAnchor constraintEqualToAnchor:counterCard.trailingAnchor constant:-16],
        [plusBtn.centerYAnchor constraintEqualToAnchor:counterCard.centerYAnchor],
        [plusBtn.widthAnchor constraintEqualToConstant:48],
        [plusBtn.heightAnchor constraintEqualToConstant:48],

        [self.quantityLabel.centerXAnchor constraintEqualToAnchor:counterCard.centerXAnchor],
        [self.quantityLabel.topAnchor constraintEqualToAnchor:counterCard.topAnchor constant:16],

        [self.healthStatusBadge.centerXAnchor constraintEqualToAnchor:counterCard.centerXAnchor],
        [self.healthStatusBadge.topAnchor constraintEqualToAnchor:self.quantityLabel.bottomAnchor constant:4],
        [self.healthStatusBadge.heightAnchor constraintEqualToConstant:24],

        [self.healthStatusLabel.leadingAnchor constraintEqualToAnchor:self.healthStatusBadge.leadingAnchor constant:10],
        [self.healthStatusLabel.trailingAnchor constraintEqualToAnchor:self.healthStatusBadge.trailingAnchor constant:-10],
        [self.healthStatusLabel.centerYAnchor constraintEqualToAnchor:self.healthStatusBadge.centerYAnchor],

        [deltaScroll.topAnchor constraintEqualToAnchor:counterCard.bottomAnchor constant:16],
        [deltaScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [deltaScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [deltaScroll.heightAnchor constraintEqualToConstant:38],

        [deltaStack.leadingAnchor constraintEqualToAnchor:deltaScroll.leadingAnchor],
        [deltaStack.trailingAnchor constraintEqualToAnchor:deltaScroll.trailingAnchor],
        [deltaStack.topAnchor constraintEqualToAnchor:deltaScroll.topAnchor],
        [deltaStack.bottomAnchor constraintEqualToAnchor:deltaScroll.bottomAnchor],
        [deltaStack.heightAnchor constraintEqualToAnchor:deltaScroll.heightAnchor],

        [presetStack.topAnchor constraintEqualToAnchor:deltaScroll.bottomAnchor constant:14],
        [presetStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [presetStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [presetStack.heightAnchor constraintEqualToConstant:38],

        [self.saveButton.topAnchor constraintEqualToAnchor:presetStack.bottomAnchor constant:18],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.saveButton.heightAnchor constraintEqualToConstant:52],

        [self.saveSpinner.centerXAnchor constraintEqualToAnchor:self.saveButton.centerXAnchor],
        [self.saveSpinner.centerYAnchor constraintEqualToAnchor:self.saveButton.centerYAnchor],
    ]];
}

- (void)updateDisplay {
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.currentQuantity];
    UIColor *tint;
    NSString *statusText;

    if (self.currentQuantity == 0) {
        tint = [UIColor ppError];
        statusText = kLang(@"Market_StockSheet_Empty");
    } else if (self.currentQuantity <= 5) {
        tint = [UIColor ppWarning];
        statusText = kLang(@"Market_StockSheet_Critical");
    } else {
        tint = [UIColor ppSuccess];
        statusText = kLang(@"Market_StockSheet_Healthy");
    }

    self.quantityLabel.textColor = tint;
    self.healthStatusLabel.text = statusText;
    self.healthStatusLabel.textColor = tint;
    self.healthStatusBadge.backgroundColor = [tint colorWithAlphaComponent:0.12];
}

- (void)minusTapped {
    if (self.currentQuantity > 0) {
        self.currentQuantity--;
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
        [self updateDisplay];
    }
}

- (void)plusTapped {
    self.currentQuantity++;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateDisplay];
}

- (void)deltaChipTapped:(UIButton *)sender {
    NSInteger delta = sender.tag;
    NSInteger target = self.currentQuantity + delta;
    self.currentQuantity = MAX(0, target);
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    [self updateDisplay];
}

- (void)zeroPresetTapped {
    self.currentQuantity = 0;
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeWarning];
    [self updateDisplay];
}

- (void)abundantPresetTapped {
    self.currentQuantity = 100;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    [self updateDisplay];
}

- (void)saveTapped {
    [self.saveSpinner startAnimating];
    self.saveButton.titleLabel.alpha = 0.0;
    self.saveButton.enabled = NO;

    __weak typeof(self) ws = self;
    [[PPProviderMarketplaceManager sharedManager] updateMarketStock:self.item.itemID quantity:self.currentQuantity completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(ws) self = ws;
        [self.saveSpinner stopAnimating];
        self.saveButton.titleLabel.alpha = 1.0;
        self.saveButton.enabled = YES;

        if (!success) {
            [PPToast toast:(message ?: error.localizedDescription) style:PPToastStyleError haptic:YES duration:3.0];
            return;
        }

        UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [PPToast toast:kLang(@"Market_StockUpdated") style:PPToastStyleSuccess haptic:NO duration:2.0];

        if (self.onUpdated) {
            self.onUpdated();
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

@end

// MARK: - Quick Offer & Promo Engine Sheet

@interface PPProviderQuickOfferSheet : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) PPProviderMarketItem *item;
@property (nonatomic, copy) void (^onUpdated)(void);
@property (nonatomic, assign) BOOL isFixedAmountMode;
@property (nonatomic, assign) double discountPercent;
@property (nonatomic, assign) double discountAmount;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UILabel *basePriceLabel;
@property (nonatomic, strong) UILabel *discountValueLabel;
@property (nonatomic, strong) UILabel *finalPriceLabel;
@property (nonatomic, strong) UILabel *savingsBadgeLabel;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIButton *removeButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
- (instancetype)initWithItem:(PPProviderMarketItem *)item;
@end

@implementation PPProviderQuickOfferSheet

- (instancetype)initWithItem:(PPProviderMarketItem *)item {
    self = [super init];
    if (self) {
        _item = item;
        if (item.hasOffer && item.price > 0 && item.finalPrice < item.price) {
            _discountAmount = item.price - item.finalPrice;
            _discountPercent = (_discountAmount / item.price) * 100.0;
        } else {
            _discountPercent = 15.0; // Sensible default preset
            _discountAmount = (_item.price * 15.0) / 100.0;
        }
        _isFixedAmountMode = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupUI];
    [self updateCalculations];
}

- (void)setupUI {
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    // Header Card
    UIView *headerCard = [[UIView alloc] init];
    headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(headerCard, PPCornerMedium);
    [self.view addSubview:headerCard];

    UIImageView *thumb = [[UIImageView alloc] init];
    thumb.translatesAutoresizingMaskIntoConstraints = NO;
    thumb.contentMode = UIViewContentModeScaleAspectFill;
    thumb.clipsToBounds = YES;
    PPApplyContinuousCorners(thumb, PPCornerSmall);
    thumb.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    if (self.item.imageURLsArray.firstObject.length > 0) {
        [thumb setImageURL:[NSURL URLWithString:self.item.imageURLsArray.firstObject]];
    } else {
        thumb.image = [UIImage systemImageNamed:@"tag.fill"];
        thumb.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.3];
    }
    [headerCard addSubview:thumb];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = self.item.name.length ? self.item.name : self.item.nameEn;
    titleLabel.font = [Styling fontBold:16.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    [headerCard addSubview:titleLabel];

    UILabel *sheetTitle = [[UILabel alloc] init];
    sheetTitle.translatesAutoresizingMaskIntoConstraints = NO;
    sheetTitle.text = kLang(@"Market_OfferSheet_Title");
    sheetTitle.font = [Styling fontMedium:12.5];
    sheetTitle.textColor = [UIColor ppDiscount];
    sheetTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:sheetTitle];

    // Live Telemetry Board Card
    UIView *telemetryCard = [[UIView alloc] init];
    telemetryCard.translatesAutoresizingMaskIntoConstraints = NO;
    telemetryCard.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.8];
    telemetryCard.layer.borderWidth = 0.8;
    telemetryCard.layer.borderColor = [[UIColor ppDiscount] colorWithAlphaComponent:0.35].CGColor;
    PPApplyContinuousCorners(telemetryCard, PPCornerCard);
    [self.view addSubview:telemetryCard];

    UILabel *baseTitle = [[UILabel alloc] init];
    baseTitle.translatesAutoresizingMaskIntoConstraints = NO;
    baseTitle.text = kLang(@"Market_OfferSheet_BasePrice");
    baseTitle.font = [Styling fontMedium:12.0];
    baseTitle.textColor = [UIColor ppTextSecondary];
    baseTitle.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:baseTitle];

    self.basePriceLabel = [[UILabel alloc] init];
    self.basePriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.basePriceLabel.font = [Styling fontBold:16.0];
    self.basePriceLabel.textColor = [UIColor ppTextPrimary];
    self.basePriceLabel.textAlignment = NSTextAlignmentCenter;
    self.basePriceLabel.text = [NSString stringWithFormat:@"%.0f QAR", self.item.price];
    [telemetryCard addSubview:self.basePriceLabel];

    UILabel *discTitle = [[UILabel alloc] init];
    discTitle.translatesAutoresizingMaskIntoConstraints = NO;
    discTitle.text = kLang(@"Market_OfferSheet_DiscountAmt");
    discTitle.font = [Styling fontMedium:12.0];
    discTitle.textColor = [UIColor ppTextSecondary];
    discTitle.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:discTitle];

    self.discountValueLabel = [[UILabel alloc] init];
    self.discountValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.discountValueLabel.font = [Styling fontBold:16.0];
    self.discountValueLabel.textColor = [UIColor ppDiscount];
    self.discountValueLabel.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:self.discountValueLabel];

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [telemetryCard addSubview:divider];

    UILabel *finalTitle = [[UILabel alloc] init];
    finalTitle.translatesAutoresizingMaskIntoConstraints = NO;
    finalTitle.text = kLang(@"Market_OfferSheet_FinalPrice");
    finalTitle.font = [Styling fontMedium:13.0];
    finalTitle.textColor = [UIColor ppTextSecondary];
    finalTitle.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:finalTitle];

    self.finalPriceLabel = [[UILabel alloc] init];
    self.finalPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.finalPriceLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightHeavy];
    self.finalPriceLabel.textColor = [UIColor ppSuccess];
    self.finalPriceLabel.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:self.finalPriceLabel];

    self.savingsBadgeLabel = [[UILabel alloc] init];
    self.savingsBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.savingsBadgeLabel.font = [Styling fontBold:12.0];
    self.savingsBadgeLabel.textColor = [UIColor ppDiscount];
    self.savingsBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [telemetryCard addSubview:self.savingsBadgeLabel];

    // Mode Selector Segment
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"Market_OfferSheet_Percentage"),
        kLang(@"Market_OfferSheet_Fixed")
    ]];
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeControl.selectedSegmentIndex = self.isFixedAmountMode ? 1 : 0;
    [self.modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.modeControl];

    // Preset Chips
    UIScrollView *chipScroll = [[UIScrollView alloc] init];
    chipScroll.translatesAutoresizingMaskIntoConstraints = NO;
    chipScroll.showsHorizontalScrollIndicator = NO;
    chipScroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:chipScroll];

    UIStackView *chipStack = [[UIStackView alloc] init];
    chipStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipStack.axis = UILayoutConstraintAxisHorizontal;
    chipStack.spacing = 8.0;
    chipStack.alignment = UIStackViewAlignmentCenter;
    [chipScroll addSubview:chipStack];

    NSArray<NSNumber *> *presetPcts = @[@(5), @(10), @(15), @(20), @(25), @(30), @(50)];
    for (NSNumber *p in presetPcts) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        [chip setTitle:[NSString stringWithFormat:@"%ld%%", (long)p.integerValue] forState:UIControlStateNormal];
        chip.titleLabel.font = [Styling fontBold:13.5];
        chip.tintColor = [UIColor ppDiscount];
        chip.backgroundColor = [[UIColor ppDiscount] colorWithAlphaComponent:0.09];
        PPApplyContinuousCorners(chip, 14);
        chip.tag = p.integerValue;
        [chip addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.heightAnchor constraintEqualToConstant:34].active = YES;
        [chip.widthAnchor constraintGreaterThanOrEqualToConstant:50].active = YES;
        [chipStack addArrangedSubview:chip];
    }

    // Apply Button
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.applyButton setTitle:kLang(@"Market_OfferSheet_Apply") forState:UIControlStateNormal];
    self.applyButton.titleLabel.font = [Styling fontBold:16.0];
    self.applyButton.tintColor = UIColor.whiteColor;
    self.applyButton.backgroundColor = [UIColor ppDiscount];
    PPApplyContinuousCorners(self.applyButton, 22);
    PPApplyButtonShadow(self.applyButton);
    [self.applyButton addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.applyButton];

    // Remove Button (if active)
    if (self.item.hasOffer) {
        self.removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.removeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.removeButton setTitle:kLang(@"Market_OfferSheet_Remove") forState:UIControlStateNormal];
        self.removeButton.titleLabel.font = [Styling fontBold:13.5];
        self.removeButton.tintColor = [UIColor ppError];
        self.removeButton.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.09];
        PPApplyContinuousCorners(self.removeButton, 18);
        [self.removeButton addTarget:self action:@selector(removeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.removeButton];
    }

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = UIColor.whiteColor;
    self.spinner.hidesWhenStopped = YES;
    [self.applyButton addSubview:self.spinner];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [headerCard.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:14],
        [headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerCard.heightAnchor constraintEqualToConstant:64],

        [thumb.leadingAnchor constraintEqualToAnchor:headerCard.leadingAnchor constant:10],
        [thumb.centerYAnchor constraintEqualToAnchor:headerCard.centerYAnchor],
        [thumb.widthAnchor constraintEqualToConstant:44],
        [thumb.heightAnchor constraintEqualToConstant:44],

        [titleLabel.leadingAnchor constraintEqualToAnchor:thumb.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerCard.trailingAnchor constant:-12],
        [titleLabel.topAnchor constraintEqualToAnchor:thumb.topAnchor constant:3],

        [sheetTitle.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [sheetTitle.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [sheetTitle.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],

        [telemetryCard.topAnchor constraintEqualToAnchor:headerCard.bottomAnchor constant:14],
        [telemetryCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [telemetryCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [telemetryCard.heightAnchor constraintEqualToConstant:140],

        [baseTitle.topAnchor constraintEqualToAnchor:telemetryCard.topAnchor constant:12],
        [baseTitle.leadingAnchor constraintEqualToAnchor:telemetryCard.leadingAnchor constant:16],
        [self.basePriceLabel.topAnchor constraintEqualToAnchor:baseTitle.bottomAnchor constant:2],
        [self.basePriceLabel.centerXAnchor constraintEqualToAnchor:baseTitle.centerXAnchor],

        [discTitle.topAnchor constraintEqualToAnchor:telemetryCard.topAnchor constant:12],
        [discTitle.trailingAnchor constraintEqualToAnchor:telemetryCard.trailingAnchor constant:-16],
        [self.discountValueLabel.topAnchor constraintEqualToAnchor:discTitle.bottomAnchor constant:2],
        [self.discountValueLabel.centerXAnchor constraintEqualToAnchor:discTitle.centerXAnchor],

        [divider.topAnchor constraintEqualToAnchor:self.basePriceLabel.bottomAnchor constant:10],
        [divider.leadingAnchor constraintEqualToAnchor:telemetryCard.leadingAnchor constant:16],
        [divider.trailingAnchor constraintEqualToAnchor:telemetryCard.trailingAnchor constant:-16],
        [divider.heightAnchor constraintEqualToConstant:0.8],

        [finalTitle.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:6],
        [finalTitle.centerXAnchor constraintEqualToAnchor:telemetryCard.centerXAnchor],

        [self.finalPriceLabel.topAnchor constraintEqualToAnchor:finalTitle.bottomAnchor constant:0],
        [self.finalPriceLabel.centerXAnchor constraintEqualToAnchor:telemetryCard.centerXAnchor],

        [self.savingsBadgeLabel.topAnchor constraintEqualToAnchor:self.finalPriceLabel.bottomAnchor constant:2],
        [self.savingsBadgeLabel.centerXAnchor constraintEqualToAnchor:telemetryCard.centerXAnchor],

        [self.modeControl.topAnchor constraintEqualToAnchor:telemetryCard.bottomAnchor constant:14],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.modeControl.heightAnchor constraintEqualToConstant:36],

        [chipScroll.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:12],
        [chipScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [chipScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [chipScroll.heightAnchor constraintEqualToConstant:38],

        [chipStack.leadingAnchor constraintEqualToAnchor:chipScroll.leadingAnchor],
        [chipStack.trailingAnchor constraintEqualToAnchor:chipScroll.trailingAnchor],
        [chipStack.topAnchor constraintEqualToAnchor:chipScroll.topAnchor],
        [chipStack.bottomAnchor constraintEqualToAnchor:chipScroll.bottomAnchor],
        [chipStack.heightAnchor constraintEqualToAnchor:chipScroll.heightAnchor],

        [self.applyButton.topAnchor constraintEqualToAnchor:chipScroll.bottomAnchor constant:16],
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.applyButton.heightAnchor constraintEqualToConstant:50],

        [self.spinner.centerXAnchor constraintEqualToAnchor:self.applyButton.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.applyButton.centerYAnchor],
    ]];

    if (self.removeButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.removeButton.topAnchor constraintEqualToAnchor:self.applyButton.bottomAnchor constant:10],
            [self.removeButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
            [self.removeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
            [self.removeButton.heightAnchor constraintEqualToConstant:40],
        ]];
    }
}

- (void)modeChanged:(UISegmentedControl *)sender {
    self.isFixedAmountMode = (sender.selectedSegmentIndex == 1);
    [self updateCalculations];
}

- (void)presetTapped:(UIButton *)sender {
    double pct = (double)sender.tag;
    self.discountPercent = pct;
    self.discountAmount = (self.item.price * pct) / 100.0;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];
    [self updateCalculations];
}

- (void)updateCalculations {
    double finalP = MAX(0.0, self.item.price - self.discountAmount);
    self.discountValueLabel.text = [NSString stringWithFormat:@"- %.0f QAR (%.0f%%)", self.discountAmount, self.discountPercent];
    self.finalPriceLabel.text = [NSString stringWithFormat:@"%.0f QAR", finalP];

    NSString *amtStr = [NSString stringWithFormat:@"%.0f QAR", self.discountAmount];
    NSString *pctStr = [NSString stringWithFormat:@"%.0f%%", self.discountPercent];
    self.savingsBadgeLabel.text = [NSString stringWithFormat:kLang(@"Market_OfferSheet_SavingsFormat"), amtStr, pctStr];
}

- (void)applyTapped {
    [self.spinner startAnimating];
    self.applyButton.titleLabel.alpha = 0.0;
    self.applyButton.enabled = NO;

    __weak typeof(self) ws = self;
    [[PPProviderMarketplaceManager sharedManager] updateMarketOffer:self.item.itemID discountPercent:self.discountPercent discountAmount:self.discountAmount hasOffer:YES completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(ws) self = ws;
        [self.spinner stopAnimating];
        self.applyButton.titleLabel.alpha = 1.0;
        self.applyButton.enabled = YES;

        if (!success) {
            [PPToast toast:(message ?: error.localizedDescription) style:PPToastStyleError haptic:YES duration:3.0];
            return;
        }

        UINotificationFeedbackGenerator *haptic = [[UINotificationFeedbackGenerator alloc] init];
        [haptic notificationOccurred:UINotificationFeedbackTypeSuccess];
        [PPToast toast:kLang(@"Market_OfferUpdated") style:PPToastStyleSuccess haptic:NO duration:2.0];

        if (self.onUpdated) {
            self.onUpdated();
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)removeTapped {
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingOffer") subtitle:nil];
    __weak typeof(self) ws = self;
    [[PPProviderMarketplaceManager sharedManager] updateMarketOffer:self.item.itemID discountPercent:0 discountAmount:0 hasOffer:NO completion:^(BOOL success, NSString *message, NSError *error) {
        [PPHUD dismiss];
        __strong typeof(ws) self = ws;
        if (!success) {
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:(message ?: error.localizedDescription)];
            return;
        }
        [PPToast toast:kLang(@"Market_OfferRemoved") style:PPToastStyleSuccess haptic:YES duration:2.0];
        if (self.onUpdated) {
            self.onUpdated();
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

@end

// MARK: - Product Quick-Look Inspector Sheet

@interface PPProviderMarketItemDetailSheet : UIViewController
@property (nonatomic, strong) PPProviderMarketItem *item;
@property (nonatomic, copy) void (^onEditRequested)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onStockRequested)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onOfferRequested)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onVisibilityToggled)(PPProviderMarketItem *item);
- (instancetype)initWithItem:(PPProviderMarketItem *)item;
@end

@implementation PPProviderMarketItemDetailSheet

- (instancetype)initWithItem:(PPProviderMarketItem *)item {
    self = [super init];
    if (self) {
        _item = item;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupUI];
}

- (void)setupUI {
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:scrollView];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 16.0;
    contentStack.alignment = UIStackViewAlignmentFill;
    [scrollView addSubview:contentStack];

    // 1. Hero Image
    UIImageView *heroImage = [[UIImageView alloc] init];
    heroImage.translatesAutoresizingMaskIntoConstraints = NO;
    heroImage.contentMode = UIViewContentModeScaleAspectFill;
    heroImage.clipsToBounds = YES;
    PPApplyContinuousCorners(heroImage, PPCornerCard);
    heroImage.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    if (self.item.imageURLsArray.firstObject.length > 0) {
        [heroImage setImageURL:[NSURL URLWithString:self.item.imageURLsArray.firstObject]];
    } else {
        heroImage.image = [UIImage systemImageNamed:@"shippingbox.fill"];
        heroImage.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.3];
    }
    [heroImage.heightAnchor constraintEqualToConstant:190].active = YES;
    [contentStack addArrangedSubview:heroImage];

    // 2. Title & Category Bar
    UIView *metaCard = [[UIView alloc] init];
    metaCard.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(metaCard, PPCornerCard);

    UILabel *catLabel = [[UILabel alloc] init];
    catLabel.translatesAutoresizingMaskIntoConstraints = NO;
    catLabel.text = [NSString stringWithFormat:@"%@  ·  %@", [self.item kindLabel], self.item.petMainCategoryName.length ? self.item.petMainCategoryName : kLang(@"Market_Title")];
    catLabel.font = [Styling fontBold:12.0];
    catLabel.textColor = [UIColor ppPrimary];
    [metaCard addSubview:catLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = self.item.name.length ? self.item.name : self.item.nameEn;
    nameLabel.font = [Styling fontBold:20.0];
    nameLabel.textColor = [UIColor ppTextPrimary];
    nameLabel.numberOfLines = 2;
    nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [metaCard addSubview:nameLabel];

    if (self.item.nameEn.length > 0 && ![self.item.name isEqualToString:self.item.nameEn]) {
        UILabel *enLabel = [[UILabel alloc] init];
        enLabel.translatesAutoresizingMaskIntoConstraints = NO;
        enLabel.text = self.item.nameEn;
        enLabel.font = [Styling fontRegular:13.5];
        enLabel.textColor = [UIColor ppTextSecondary];
        enLabel.numberOfLines = 1;
        enLabel.textAlignment = NSTextAlignmentLeft;
        [metaCard addSubview:enLabel];

        [NSLayoutConstraint activateConstraints:@[
            [catLabel.topAnchor constraintEqualToAnchor:metaCard.topAnchor constant:14],
            [catLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
            [catLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],

            [nameLabel.topAnchor constraintEqualToAnchor:catLabel.bottomAnchor constant:4],
            [nameLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
            [nameLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],

            [enLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:3],
            [enLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
            [enLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],
            [enLabel.bottomAnchor constraintEqualToAnchor:metaCard.bottomAnchor constant:-14]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [catLabel.topAnchor constraintEqualToAnchor:metaCard.topAnchor constant:14],
            [catLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
            [catLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],

            [nameLabel.topAnchor constraintEqualToAnchor:catLabel.bottomAnchor constant:4],
            [nameLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
            [nameLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],
            [nameLabel.bottomAnchor constraintEqualToAnchor:metaCard.bottomAnchor constant:-14]
        ]];
    }
    [contentStack addArrangedSubview:metaCard];

    // 3. 4-Tile Telemetry Grid
    UIView *gridContainer = [[UIView alloc] init];
    gridContainer.translatesAutoresizingMaskIntoConstraints = NO;
    gridContainer.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.8];
    PPApplyContinuousCorners(gridContainer, PPCornerCard);
    gridContainer.layer.borderWidth = 0.8;
    gridContainer.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;

    UIStackView *gridRow1 = [[UIStackView alloc] init];
    gridRow1.translatesAutoresizingMaskIntoConstraints = NO;
    gridRow1.axis = UILayoutConstraintAxisHorizontal;
    gridRow1.distribution = UIStackViewDistributionFillEqually;
    gridRow1.spacing = 10;
    [gridContainer addSubview:gridRow1];

    UIStackView *gridRow2 = [[UIStackView alloc] init];
    gridRow2.translatesAutoresizingMaskIntoConstraints = NO;
    gridRow2.axis = UILayoutConstraintAxisHorizontal;
    gridRow2.distribution = UIStackViewDistributionFillEqually;
    gridRow2.spacing = 10;
    [gridContainer addSubview:gridRow2];

    double finalP = self.item.finalPrice > 0 ? self.item.finalPrice : self.item.price;
    double totalValuation = self.item.quantity * finalP;

    [gridRow1 addArrangedSubview:[self specTileWithTitle:kLang(@"Market_Stock") value:[NSString stringWithFormat:@"%ld", (long)self.item.quantity] color:[UIColor ppPrimary]]];
    [gridRow1 addArrangedSubview:[self specTileWithTitle:kLang(@"Price") value:[NSString stringWithFormat:@"%.0f QAR", finalP] color:[UIColor ppSuccess]]];
    [gridRow2 addArrangedSubview:[self specTileWithTitle:kLang(@"Market_DetailSheet_TotalValuation") value:[NSString stringWithFormat:@"%.0f QAR", totalValuation] color:[UIColor ppDiscount]]];
    [gridRow2 addArrangedSubview:[self specTileWithTitle:kLang(@"Market_DetailSheet_SKU") value:self.item.itemID ?: @"—" color:[UIColor ppTextSecondary]]];

    [NSLayoutConstraint activateConstraints:@[
        [gridRow1.topAnchor constraintEqualToAnchor:gridContainer.topAnchor constant:12],
        [gridRow1.leadingAnchor constraintEqualToAnchor:gridContainer.leadingAnchor constant:12],
        [gridRow1.trailingAnchor constraintEqualToAnchor:gridContainer.trailingAnchor constant:-12],
        [gridRow1.heightAnchor constraintEqualToConstant:54],

        [gridRow2.topAnchor constraintEqualToAnchor:gridRow1.bottomAnchor constant:10],
        [gridRow2.leadingAnchor constraintEqualToAnchor:gridContainer.leadingAnchor constant:12],
        [gridRow2.trailingAnchor constraintEqualToAnchor:gridContainer.trailingAnchor constant:-12],
        [gridRow2.bottomAnchor constraintEqualToAnchor:gridContainer.bottomAnchor constant:-12],
        [gridRow2.heightAnchor constraintEqualToConstant:54],
    ]];
    [contentStack addArrangedSubview:gridContainer];

    // 4. Description Box (if available)
    if (self.item.desc.length > 0 || self.item.descEn.length > 0) {
        UIView *descCard = [[UIView alloc] init];
        descCard.translatesAutoresizingMaskIntoConstraints = NO;
        PPStyleCardSurface(descCard, PPCornerCard);

        UILabel *descTitle = [[UILabel alloc] init];
        descTitle.translatesAutoresizingMaskIntoConstraints = NO;
        descTitle.text = kLang(@"Market_SectionDescription");
        descTitle.font = [Styling fontBold:13.0];
        descTitle.textColor = [UIColor ppTextSecondary];
        [descCard addSubview:descTitle];

        UILabel *descBody = [[UILabel alloc] init];
        descBody.translatesAutoresizingMaskIntoConstraints = NO;
        descBody.text = self.item.desc.length ? self.item.desc : self.item.descEn;
        descBody.font = [Styling fontRegular:14.0];
        descBody.textColor = [UIColor ppTextPrimary];
        descBody.numberOfLines = 0;
        descBody.textAlignment = Language.alignmentForCurrentLanguage;
        [descCard addSubview:descBody];

        [NSLayoutConstraint activateConstraints:@[
            [descTitle.topAnchor constraintEqualToAnchor:descCard.topAnchor constant:14],
            [descTitle.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
            [descTitle.trailingAnchor constraintEqualToAnchor:descCard.trailingAnchor constant:-16],

            [descBody.topAnchor constraintEqualToAnchor:descTitle.bottomAnchor constant:6],
            [descBody.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
            [descBody.trailingAnchor constraintEqualToAnchor:descCard.trailingAnchor constant:-16],
            [descBody.bottomAnchor constraintEqualToAnchor:descCard.bottomAnchor constant:-14]
        ]];
        [contentStack addArrangedSubview:descCard];
    }

    // 5. Actions Box
    UIButton *editFullBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    editFullBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [editFullBtn setTitle:kLang(@"Market_DetailSheet_EditFull") forState:UIControlStateNormal];
    editFullBtn.titleLabel.font = [Styling fontBold:15.5];
    editFullBtn.tintColor = UIColor.whiteColor;
    editFullBtn.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(editFullBtn, 20);
    PPApplyButtonShadow(editFullBtn);
    [editFullBtn addTarget:self action:@selector(editFullTapped) forControlEvents:UIControlEventTouchUpInside];
    [editFullBtn.heightAnchor constraintEqualToConstant:48].active = YES;
    [contentStack addArrangedSubview:editFullBtn];

    UIStackView *subActionRow = [[UIStackView alloc] init];
    subActionRow.translatesAutoresizingMaskIntoConstraints = NO;
    subActionRow.axis = UILayoutConstraintAxisHorizontal;
    subActionRow.spacing = 10;
    subActionRow.distribution = UIStackViewDistributionFillEqually;

    UIButton *stockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [stockBtn setTitle:kLang(@"Market_Action_Stock") forState:UIControlStateNormal];
    stockBtn.titleLabel.font = [Styling fontBold:14.0];
    stockBtn.tintColor = [UIColor ppPrimary];
    stockBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.09];
    PPApplyContinuousCorners(stockBtn, 16);
    [stockBtn addTarget:self action:@selector(stockTapped) forControlEvents:UIControlEventTouchUpInside];
    [stockBtn.heightAnchor constraintEqualToConstant:42].active = YES;
    [subActionRow addArrangedSubview:stockBtn];

    UIButton *offerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [offerBtn setTitle:kLang(@"Market_Action_Offer") forState:UIControlStateNormal];
    offerBtn.titleLabel.font = [Styling fontBold:14.0];
    offerBtn.tintColor = [UIColor ppDiscount];
    offerBtn.backgroundColor = [[UIColor ppDiscount] colorWithAlphaComponent:0.09];
    PPApplyContinuousCorners(offerBtn, 16);
    [offerBtn addTarget:self action:@selector(offerTapped) forControlEvents:UIControlEventTouchUpInside];
    [offerBtn.heightAnchor constraintEqualToConstant:42].active = YES;
    [subActionRow addArrangedSubview:offerBtn];

    [contentStack addArrangedSubview:subActionRow];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [scrollView.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:12],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],

        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-20],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor]
    ]];
}

- (UIView *)specTileWithTitle:(NSString *)title value:(NSString *)value color:(UIColor *)color {
    UIView *tile = [[UIView alloc] init];
    tile.backgroundColor = [[UIColor ppBackground] colorWithAlphaComponent:0.6];
    PPApplyContinuousCorners(tile, PPCornerSmall);

    UILabel *tLabel = [[UILabel alloc] init];
    tLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tLabel.text = title;
    tLabel.font = [Styling fontMedium:11.0];
    tLabel.textColor = [UIColor ppTextSecondary];
    tLabel.textAlignment = NSTextAlignmentCenter;
    [tile addSubview:tLabel];

    UILabel *vLabel = [[UILabel alloc] init];
    vLabel.translatesAutoresizingMaskIntoConstraints = NO;
    vLabel.text = value;
    vLabel.font = [Styling fontBold:14.0];
    vLabel.textColor = color;
    vLabel.textAlignment = NSTextAlignmentCenter;
    [tile addSubview:vLabel];

    [NSLayoutConstraint activateConstraints:@[
        [tLabel.topAnchor constraintEqualToAnchor:tile.topAnchor constant:8],
        [tLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:4],
        [tLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-4],

        [vLabel.topAnchor constraintEqualToAnchor:tLabel.bottomAnchor constant:2],
        [vLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:4],
        [vLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-4],
    ]];
    return tile;
}

- (void)editFullTapped {
    __weak typeof(self) ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (ws.onEditRequested) {
            ws.onEditRequested(ws.item);
        }
    }];
}

- (void)stockTapped {
    __weak typeof(self) ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (ws.onStockRequested) {
            ws.onStockRequested(ws.item);
        }
    }];
}

- (void)offerTapped {
    __weak typeof(self) ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (ws.onOfferRequested) {
            ws.onOfferRequested(ws.item);
        }
    }];
}

@end

// MARK: - Category-Defining Market Filter & Sort Sheet (NextGen V6 Native Cockpit)

@interface PPProviderMarketFilterSheet : UIViewController
@property (nonatomic, strong) PPProviderMarketFilterCriteria *criteria;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *items;
@property (nonatomic, copy) void (^onApplyCriteria)(PPProviderMarketFilterCriteria *criteria);
@property (nonatomic, copy) void (^onApplyLegacy)(PPProviderMarketFilter filter, PPProviderMarketSort sort);

// UI Controls
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *activeBadgeLabel;
@property (nonatomic, strong) UIView *activeBadgePill;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) UIView *actionDockContainer;
@property (nonatomic, strong) UIScrollView *mainScrollView;

// Card Containers
@property (nonatomic, strong) UIView *presetsCard;
@property (nonatomic, strong) UIView *telemetryCard;
@property (nonatomic, strong) UIView *stockCard;
@property (nonatomic, strong) UIView *kindCard;
@property (nonatomic, strong) UIView *offersCard;
@property (nonatomic, strong) UIView *visibilityCard;
@property (nonatomic, strong) UIView *sortCard;
@property (nonatomic, strong) UIView *activeSummaryCard;
@property (nonatomic, strong) UILabel *activeSummaryLabel;

// Buttons Cache
@property (nonatomic, strong) NSMutableArray<UIButton *> *presetButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *stockButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *kindButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *offerButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *visibilityButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *sortButtons;

// iPad Command Controls
@property (nonatomic, strong) UIButton *ipadApplyButton;
@property (nonatomic, strong) UIButton *ipadResetButton;
@property (nonatomic, strong) UIButton *ipadDismissButton;

- (instancetype)initWithCriteria:(PPProviderMarketFilterCriteria *)criteria
                           items:(NSArray<PPProviderMarketItem *> *)items;
- (instancetype)initWithFilter:(PPProviderMarketFilter)filter
                          sort:(PPProviderMarketSort)sort
                         items:(NSArray<PPProviderMarketItem *> *)items;
@end

@implementation PPProviderMarketFilterSheet

- (instancetype)initWithCriteria:(PPProviderMarketFilterCriteria *)criteria
                           items:(NSArray<PPProviderMarketItem *> *)items {
    self = [super init];
    if (self) {
        _criteria = criteria ? [criteria copy] : [[PPProviderMarketFilterCriteria alloc] init];
        _items = items ?: @[];
        _presetButtons = [NSMutableArray array];
        _stockButtons = [NSMutableArray array];
        _kindButtons = [NSMutableArray array];
        _offerButtons = [NSMutableArray array];
        _visibilityButtons = [NSMutableArray array];
        _sortButtons = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithFilter:(PPProviderMarketFilter)filter
                          sort:(PPProviderMarketSort)sort
                         items:(NSArray<PPProviderMarketItem *> *)items {
    PPProviderMarketFilterCriteria *criteria = [PPProviderMarketFilterCriteria criteriaFromLegacyFilter:filter sort:sort];
    return [self initWithCriteria:criteria items:items];
}

- (BOOL)isPadLayout {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    if ([self isPadLayout]) {
        [self setupPadUI];
    } else {
        [self setupPhoneUI];
    }

    [self updateAllButtonsAndTelemetry];
}

#pragma mark - iPhone Handheld Tactical Cockpit

- (void)setupPhoneUI {
    // 1. Drag Handle
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    // 2. Header Bar
    UIView *headerBar = [self buildHeaderBar];
    [self.view addSubview:headerBar];

    // 3. Scroll View
    self.mainScrollView = [[UIScrollView alloc] init];
    self.mainScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainScrollView.showsVerticalScrollIndicator = NO;
    self.mainScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.mainScrollView];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 14.0;
    contentStack.alignment = UIStackViewAlignmentFill;
    [self.mainScrollView addSubview:contentStack];

    // Presets Ribbon
    self.presetsCard = [self buildPresetsRibbon];
    [contentStack addArrangedSubview:self.presetsCard];

    // Telemetry Mini HUD
    self.telemetryCard = [self buildTelemetryHUDCard];
    [contentStack addArrangedSubview:self.telemetryCard];

    // Section 1: Stock Status
    self.stockCard = [self buildStockSectionCard];
    [contentStack addArrangedSubview:self.stockCard];

    // Section 2: Kind / Classification
    self.kindCard = [self buildKindSectionCard];
    [contentStack addArrangedSubview:self.kindCard];

    // Section 3: Promotions & Deals
    self.offersCard = [self buildOffersSectionCard];
    [contentStack addArrangedSubview:self.offersCard];

    // Section 4: Marketplace Visibility
    self.visibilityCard = [self buildVisibilitySectionCard];
    [contentStack addArrangedSubview:self.visibilityCard];

    // Section 5: Sort Matrix
    self.sortCard = [self buildSortSectionCard];
    [contentStack addArrangedSubview:self.sortCard];

    // 4. Pinned Frosted Glass Action Dock
    [self setupPhonePinnedActionDock];

    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10.0],
        [handle.widthAnchor constraintEqualToConstant:40.0],
        [handle.heightAnchor constraintEqualToConstant:5.0],

        [headerBar.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:10.0],
        [headerBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerBar.heightAnchor constraintEqualToConstant:44.0],

        [self.mainScrollView.topAnchor constraintEqualToAnchor:headerBar.bottomAnchor constant:8.0],
        [self.mainScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.mainScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.mainScrollView.bottomAnchor constraintEqualToAnchor:self.actionDockContainer.topAnchor constant:-8.0],

        [contentStack.leadingAnchor constraintEqualToAnchor:self.mainScrollView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:self.mainScrollView.trailingAnchor],
        [contentStack.topAnchor constraintEqualToAnchor:self.mainScrollView.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:self.mainScrollView.bottomAnchor constant:-20.0],
        [contentStack.widthAnchor constraintEqualToAnchor:self.mainScrollView.widthAnchor]
    ]];
}

- (void)setupPhonePinnedActionDock {
    self.actionDockContainer = [[UIView alloc] init];
    self.actionDockContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionDockContainer.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.actionDockContainer];

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5].CGColor;
    blurView.layer.borderWidth = 0.5;
    [self.actionDockContainer addSubview:blurView];

    self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.titleLabel.font = [Styling fontBold:16.0];
    [self.applyButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.applyButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.applyButton, 20.0);
    PPApplyButtonShadow(self.applyButton);

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightBold];
    UIImage *arrowImg = [[UIImage systemImageNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"] imageWithConfiguration:symCfg];
    [self.applyButton setImage:arrowImg forState:UIControlStateNormal];
    self.applyButton.tintColor = UIColor.whiteColor;
    self.applyButton.imageEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 8, 0, -8) : UIEdgeInsetsMake(0, -8, 0, 8);
    [self.applyButton addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.actionDockContainer addSubview:self.applyButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionDockContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.actionDockContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.actionDockContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [blurView.topAnchor constraintEqualToAnchor:self.actionDockContainer.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.actionDockContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.actionDockContainer.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.actionDockContainer.bottomAnchor],

        [self.applyButton.topAnchor constraintEqualToAnchor:self.actionDockContainer.topAnchor constant:10.0],
        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.actionDockContainer.leadingAnchor constant:PPSpaceBase],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:self.actionDockContainer.trailingAnchor constant:-PPSpaceBase],
        [self.applyButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8.0],
        [self.applyButton.heightAnchor constraintEqualToConstant:50.0]
    ]];
}

#pragma mark - iPad Countertop Flight Deck

- (void)setupPadUI {
    // 1. Header Bar
    UIView *headerBar = [self buildHeaderBar];
    [self.view addSubview:headerBar];

    // 2. Dual-Wing Flight Deck Grid
    UIView *leadingWing = [[UIView alloc] init];
    leadingWing.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:leadingWing];

    UIView *trailingWing = [[UIView alloc] init];
    trailingWing.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:trailingWing];

    // Center Divider
    UIView *verticalDivider = [[UIView alloc] init];
    verticalDivider.translatesAutoresizingMaskIntoConstraints = NO;
    verticalDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [self.view addSubview:verticalDivider];

    // --- Leading Wing Elements (Filter Facets) ---
    UIScrollView *leadScroll = [[UIScrollView alloc] init];
    leadScroll.translatesAutoresizingMaskIntoConstraints = NO;
    leadScroll.showsVerticalScrollIndicator = NO;
    [leadingWing addSubview:leadScroll];

    UIStackView *leadStack = [[UIStackView alloc] init];
    leadStack.translatesAutoresizingMaskIntoConstraints = NO;
    leadStack.axis = UILayoutConstraintAxisVertical;
    leadStack.spacing = 14.0;
    leadStack.alignment = UIStackViewAlignmentFill;
    [leadScroll addSubview:leadStack];

    self.presetsCard = [self buildPresetsRibbon];
    [leadStack addArrangedSubview:self.presetsCard];

    self.stockCard = [self buildStockSectionCard];
    [leadStack addArrangedSubview:self.stockCard];

    self.kindCard = [self buildKindSectionCard];
    [leadStack addArrangedSubview:self.kindCard];

    self.offersCard = [self buildOffersSectionCard];
    [leadStack addArrangedSubview:self.offersCard];

    self.visibilityCard = [self buildVisibilitySectionCard];
    [leadStack addArrangedSubview:self.visibilityCard];

    // --- Trailing Wing Elements (Sort, Telemetry & Command Center) ---
    UIScrollView *trailScroll = [[UIScrollView alloc] init];
    trailScroll.translatesAutoresizingMaskIntoConstraints = NO;
    trailScroll.showsVerticalScrollIndicator = NO;
    [trailingWing addSubview:trailScroll];

    UIStackView *trailStack = [[UIStackView alloc] init];
    trailStack.translatesAutoresizingMaskIntoConstraints = NO;
    trailStack.axis = UILayoutConstraintAxisVertical;
    trailStack.spacing = 14.0;
    trailStack.alignment = UIStackViewAlignmentFill;
    [trailScroll addSubview:trailStack];

    self.telemetryCard = [self buildTelemetryHUDCard];
    [trailStack addArrangedSubview:self.telemetryCard];

    self.sortCard = [self buildSortSectionCard];
    [trailStack addArrangedSubview:self.sortCard];

    self.activeSummaryCard = [self buildActiveSummaryCard];
    [trailStack addArrangedSubview:self.activeSummaryCard];

    UIView *commandDeck = [self buildIpadCommandDeck];
    [trailStack addArrangedSubview:commandDeck];

    // iPad Auto Layout
    [NSLayoutConstraint activateConstraints:@[
        [headerBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:14.0],
        [headerBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [headerBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [headerBar.heightAnchor constraintEqualToConstant:44.0],

        [leadingWing.topAnchor constraintEqualToAnchor:headerBar.bottomAnchor constant:14.0],
        [leadingWing.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [leadingWing.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],

        [verticalDivider.topAnchor constraintEqualToAnchor:leadingWing.topAnchor],
        [verticalDivider.bottomAnchor constraintEqualToAnchor:leadingWing.bottomAnchor],
        [verticalDivider.leadingAnchor constraintEqualToAnchor:leadingWing.trailingAnchor constant:16.0],
        [verticalDivider.widthAnchor constraintEqualToConstant:1.0],

        [trailingWing.topAnchor constraintEqualToAnchor:leadingWing.topAnchor],
        [trailingWing.leadingAnchor constraintEqualToAnchor:verticalDivider.trailingAnchor constant:16.0],
        [trailingWing.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24.0],
        [trailingWing.bottomAnchor constraintEqualToAnchor:leadingWing.bottomAnchor],
        [trailingWing.widthAnchor constraintEqualToAnchor:leadingWing.widthAnchor multiplier:0.85],

        // Leading Wing Scroll
        [leadScroll.topAnchor constraintEqualToAnchor:leadingWing.topAnchor],
        [leadScroll.bottomAnchor constraintEqualToAnchor:leadingWing.bottomAnchor],
        [leadScroll.leadingAnchor constraintEqualToAnchor:leadingWing.leadingAnchor],
        [leadScroll.trailingAnchor constraintEqualToAnchor:leadingWing.trailingAnchor],
        [leadStack.topAnchor constraintEqualToAnchor:leadScroll.topAnchor],
        [leadStack.bottomAnchor constraintEqualToAnchor:leadScroll.bottomAnchor constant:-16.0],
        [leadStack.leadingAnchor constraintEqualToAnchor:leadScroll.leadingAnchor],
        [leadStack.trailingAnchor constraintEqualToAnchor:leadScroll.trailingAnchor],
        [leadStack.widthAnchor constraintEqualToAnchor:leadScroll.widthAnchor],

        // Trailing Wing Scroll
        [trailScroll.topAnchor constraintEqualToAnchor:trailingWing.topAnchor],
        [trailScroll.bottomAnchor constraintEqualToAnchor:trailingWing.bottomAnchor],
        [trailScroll.leadingAnchor constraintEqualToAnchor:trailingWing.leadingAnchor],
        [trailScroll.trailingAnchor constraintEqualToAnchor:trailingWing.trailingAnchor],
        [trailStack.topAnchor constraintEqualToAnchor:trailScroll.topAnchor],
        [trailStack.bottomAnchor constraintEqualToAnchor:trailScroll.bottomAnchor constant:-16.0],
        [trailStack.leadingAnchor constraintEqualToAnchor:trailScroll.leadingAnchor],
        [trailStack.trailingAnchor constraintEqualToAnchor:trailScroll.trailingAnchor],
        [trailStack.widthAnchor constraintEqualToAnchor:trailScroll.widthAnchor]
    ]];
}

#pragma mark - Shared Building Blocks

- (UIView *)buildHeaderBar {
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = kLang(@"Market_FilterSheet_Title");
    self.titleLabel.font = [Styling fontBold:17.5];
    self.titleLabel.textColor = [UIColor ppTextPrimary];
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [bar addSubview:self.titleLabel];

    // Active Badge Pill
    self.activeBadgePill = [[UIView alloc] init];
    self.activeBadgePill.translatesAutoresizingMaskIntoConstraints = NO;
    self.activeBadgePill.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(self.activeBadgePill, 8.0);
    self.activeBadgePill.hidden = YES;
    [bar addSubview:self.activeBadgePill];

    self.activeBadgeLabel = [[UILabel alloc] init];
    self.activeBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.activeBadgeLabel.font = [Styling fontBold:11.0];
    self.activeBadgeLabel.textColor = [UIColor ppPrimary];
    self.activeBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.activeBadgePill addSubview:self.activeBadgeLabel];

    // Reset Button
    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resetButton setTitle:kLang(@"Market_FilterSheet_Reset") forState:UIControlStateNormal];
    self.resetButton.titleLabel.font = [Styling fontBold:13.5];
    self.resetButton.tintColor = [UIColor ppPrimary];
    UIImageSymbolConfiguration *rCfg = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightSemibold];
    UIImage *rImg = [[UIImage systemImageNamed:@"arrow.counterclockwise"] imageWithConfiguration:rCfg];
    [self.resetButton setImage:rImg forState:UIControlStateNormal];
    self.resetButton.imageEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 4, 0, -4) : UIEdgeInsetsMake(0, -4, 0, 4);
    [self.resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.4, *)) {
        self.resetButton.pointerInteractionEnabled = YES;
    }
    [bar addSubview:self.resetButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [self.activeBadgePill.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:8.0],
        [self.activeBadgePill.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.activeBadgePill.heightAnchor constraintEqualToConstant:22.0],

        [self.activeBadgeLabel.leadingAnchor constraintEqualToAnchor:self.activeBadgePill.leadingAnchor constant:8.0],
        [self.activeBadgeLabel.trailingAnchor constraintEqualToAnchor:self.activeBadgePill.trailingAnchor constant:-8.0],
        [self.activeBadgeLabel.centerYAnchor constraintEqualToAnchor:self.activeBadgePill.centerYAnchor],

        [self.resetButton.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [self.resetButton.heightAnchor constraintEqualToConstant:32.0]
    ]];

    return bar;
}

- (UIView *)buildPresetsRibbon {
    UIView *container = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_QuickPresets") icon:@"sparkles"];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [container addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    NSArray<NSDictionary *> *presets = @[
        @{@"tag": @(0), @"title": kLang(@"Market_FilterSheet_Preset_All"), @"icon": @"asterisk.circle.fill"},
        @{@"tag": @(1), @"title": kLang(@"Market_FilterSheet_Preset_LowStock"), @"icon": @"exclamationmark.triangle.fill"},
        @{@"tag": @(2), @"title": kLang(@"Market_FilterSheet_Preset_Deals"), @"icon": @"percent"},
        @{@"tag": @(3), @"title": kLang(@"Market_FilterSheet_Preset_Food"), @"icon": @"takeoutbag.and.cup.and.straw.fill"},
        @{@"tag": @(4), @"title": kLang(@"Market_FilterSheet_Preset_Accessories"), @"icon": @"pawprint.fill"},
        @{@"tag": @(5), @"title": kLang(@"Market_FilterSheet_Preset_Hidden"), @"icon": @"eye.slash.fill"}
    ];

    for (NSDictionary *p in presets) {
        UIButton *btn = [self createPillButtonWithTitle:p[@"title"] icon:p[@"icon"] tag:[p[@"tag"] integerValue] selector:@selector(presetTapped:)];
        [self.presetButtons addObject:btn];
        [stack addArrangedSubview:btn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:container.subviews.firstObject.bottomAnchor constant:10.0],
        [scroll.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],
        [scroll.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12.0],
        [scroll.heightAnchor constraintEqualToConstant:36.0],

        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor]
    ]];

    return container;
}

- (UIView *)buildTelemetryHUDCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_CatalogDistribution") icon:@"chart.bar.xaxis"];

    UIStackView *statsGrid = [[UIStackView alloc] init];
    statsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    statsGrid.axis = UILayoutConstraintAxisHorizontal;
    statsGrid.distribution = UIStackViewDistributionFillEqually;
    statsGrid.spacing = 8.0;
    [card addSubview:statsGrid];

    // Compute metrics
    NSInteger total = self.items.count;
    NSInteger inStock = 0;
    NSInteger lowStock = 0;
    NSInteger offers = 0;

    for (PPProviderMarketItem *item in self.items) {
        if (!item.noStock && item.quantity > 5) inStock++;
        if (item.quantity <= 5 || item.noStock) lowStock++;
        if (item.hasOffer) offers++;
    }

    [statsGrid addArrangedSubview:[self buildTelemetryChipWithTitle:kLang(@"Market_FilterSheet_TotalSKUsFormat") count:total color:[UIColor ppTextPrimary]]];
    [statsGrid addArrangedSubview:[self buildTelemetryChipWithTitle:kLang(@"Market_FilterSheet_InStockSummaryFormat") count:inStock color:[UIColor ppSuccess]]];
    [statsGrid addArrangedSubview:[self buildTelemetryChipWithTitle:kLang(@"Market_FilterSheet_LowStockSummaryFormat") count:lowStock color:[UIColor ppWarning]]];
    [statsGrid addArrangedSubview:[self buildTelemetryChipWithTitle:kLang(@"Market_FilterSheet_OffersSummaryFormat") count:offers color:[UIColor ppPrimary]]];

    [NSLayoutConstraint activateConstraints:@[
        [statsGrid.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [statsGrid.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [statsGrid.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [statsGrid.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [statsGrid.heightAnchor constraintEqualToConstant:48.0]
    ]];

    return card;
}

- (UIView *)buildTelemetryChipWithTitle:(NSString *)fmt count:(NSInteger)count color:(UIColor *)color {
    UIView *chip = [[UIView alloc] init];
    chip.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
    chip.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5].CGColor;
    chip.layer.borderWidth = 0.5;
    PPApplyContinuousCorners(chip, 10.0);

    UILabel *numLabel = [[UILabel alloc] init];
    numLabel.translatesAutoresizingMaskIntoConstraints = NO;
    numLabel.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightBold];
    numLabel.textColor = color;
    numLabel.textAlignment = NSTextAlignmentCenter;
    numLabel.text = [NSString stringWithFormat:@"%ld", (long)count];
    [chip addSubview:numLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.font = [Styling fontMedium:10.0];
    subLabel.textColor = [UIColor ppTextSecondary];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.text = [NSString stringWithFormat:fmt, (long)count];
    [chip addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [numLabel.topAnchor constraintEqualToAnchor:chip.topAnchor constant:6.0],
        [numLabel.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [subLabel.topAnchor constraintEqualToAnchor:numLabel.bottomAnchor constant:2.0],
        [subLabel.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [subLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:chip.leadingAnchor constant:4.0],
        [subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chip.trailingAnchor constant:-4.0]
    ]];

    return chip;
}

- (UIView *)buildStockSectionCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_SectionStock") icon:@"cube.box.fill"];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillProportionally;
    stack.alignment = UIStackViewAlignmentCenter;
    [card addSubview:stack];

    NSInteger total = self.items.count;
    NSInteger inStock = [self countForStock:PPProviderMarketStockFilterInStock];
    NSInteger lowStock = [self countForStock:PPProviderMarketStockFilterLowStock];

    UIButton *bAll = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_All"), (long)total] icon:nil tag:PPProviderMarketStockFilterAll selector:@selector(stockPillTapped:)];
    UIButton *bIn = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_InStockOnly"), (long)inStock] icon:@"checkmark.circle.fill" tag:PPProviderMarketStockFilterInStock selector:@selector(stockPillTapped:)];
    UIButton *bLow = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_LowStockOnly"), (long)lowStock] icon:@"exclamationmark.triangle.fill" tag:PPProviderMarketStockFilterLowStock selector:@selector(stockPillTapped:)];

    [self.stockButtons addObjectsFromArray:@[bAll, bIn, bLow]];
    [stack addArrangedSubview:bAll];
    [stack addArrangedSubview:bIn];
    [stack addArrangedSubview:bLow];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    return card;
}

- (UIView *)buildKindSectionCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_SectionKind") icon:@"square.grid.2x2.fill"];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillProportionally;
    stack.alignment = UIStackViewAlignmentCenter;
    [card addSubview:stack];

    NSInteger total = self.items.count;
    NSInteger acc = [self countForKind:PPProviderMarketKindFilterAccessories];
    NSInteger food = [self countForKind:PPProviderMarketKindFilterFood];

    UIButton *bAll = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_All"), (long)total] icon:nil tag:PPProviderMarketKindFilterAll selector:@selector(kindPillTapped:)];
    UIButton *bAcc = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_Accessory"), (long)acc] icon:@"pawprint.fill" tag:PPProviderMarketKindFilterAccessories selector:@selector(kindPillTapped:)];
    UIButton *bFood = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_Food"), (long)food] icon:@"takeoutbag.and.cup.and.straw.fill" tag:PPProviderMarketKindFilterFood selector:@selector(kindPillTapped:)];

    [self.kindButtons addObjectsFromArray:@[bAll, bAcc, bFood]];
    [stack addArrangedSubview:bAll];
    [stack addArrangedSubview:bAcc];
    [stack addArrangedSubview:bFood];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    return card;
}

- (UIView *)buildOffersSectionCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_SectionOffers") icon:@"tag.fill"];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillProportionally;
    stack.alignment = UIStackViewAlignmentCenter;
    [card addSubview:stack];

    NSInteger total = self.items.count;
    NSInteger offers = [self countForOffers:PPProviderMarketOfferFilterOffersOnly];

    UIButton *bAll = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_All"), (long)total] icon:nil tag:PPProviderMarketOfferFilterAll selector:@selector(offerPillTapped:)];
    UIButton *bOffers = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_OffersOnly"), (long)offers] icon:@"percent" tag:PPProviderMarketOfferFilterOffersOnly selector:@selector(offerPillTapped:)];

    [self.offerButtons addObjectsFromArray:@[bAll, bOffers]];
    [stack addArrangedSubview:bAll];
    [stack addArrangedSubview:bOffers];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    return card;
}

- (UIView *)buildVisibilitySectionCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_SectionVisibility") icon:@"eye.fill"];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillProportionally;
    stack.alignment = UIStackViewAlignmentCenter;
    [card addSubview:stack];

    NSInteger total = self.items.count;
    NSInteger hidden = [self countForVisibility:PPProviderMarketVisibilityFilterHiddenOnly];

    UIButton *bAll = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_All"), (long)total] icon:nil tag:PPProviderMarketVisibilityFilterAll selector:@selector(visibilityPillTapped:)];
    UIButton *bHidden = [self createPillButtonWithTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Market_FilterSheet_HiddenOnly"), (long)hidden] icon:@"eye.slash.fill" tag:PPProviderMarketVisibilityFilterHiddenOnly selector:@selector(visibilityPillTapped:)];

    [self.visibilityButtons addObjectsFromArray:@[bAll, bHidden]];
    [stack addArrangedSubview:bAll];
    [stack addArrangedSubview:bHidden];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [stack.heightAnchor constraintEqualToConstant:36.0]
    ]];

    return card;
}

- (UIView *)buildSortSectionCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_FilterSheet_SectionSort") icon:@"arrow.up.arrow.down"];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    NSArray<NSDictionary *> *sortDefs = @[
        @{@"sort": @(PPProviderMarketSortNewest), @"title": kLang(@"Market_FilterSheet_SortNewest"), @"icon": @"clock.fill"},
        @{@"sort": @(PPProviderMarketSortPriceLowToHigh), @"title": kLang(@"Market_FilterSheet_SortPriceLow"), @"icon": @"arrow.down.circle.fill"},
        @{@"sort": @(PPProviderMarketSortPriceHighToLow), @"title": kLang(@"Market_FilterSheet_SortPriceHigh"), @"icon": @"arrow.up.circle.fill"},
        @{@"sort": @(PPProviderMarketSortStockHighest), @"title": kLang(@"Market_FilterSheet_SortStockHigh"), @"icon": @"chart.bar.fill"},
        @{@"sort": @(PPProviderMarketSortStockLowest), @"title": kLang(@"Market_FilterSheet_SortStockLow"), @"icon": @"chart.bar"}
    ];

    for (NSDictionary *def in sortDefs) {
        UIButton *btn = [self createPillButtonWithTitle:def[@"title"] icon:def[@"icon"] tag:[def[@"sort"] integerValue] selector:@selector(sortPillTapped:)];
        [self.sortButtons addObject:btn];
        [stack addArrangedSubview:btn];
    }

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [scroll.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [scroll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [scroll.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
        [scroll.heightAnchor constraintEqualToConstant:36.0],

        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor]
    ]];

    return card;
}

- (UIView *)buildActiveSummaryCard {
    UIView *card = [self makeCardContainerWithTitle:kLang(@"Market_Filter_ActiveIndicator") icon:@"slider.horizontal.3"];

    self.activeSummaryLabel = [[UILabel alloc] init];
    self.activeSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.activeSummaryLabel.font = [Styling fontMedium:12.5];
    self.activeSummaryLabel.textColor = [UIColor ppTextSecondary];
    self.activeSummaryLabel.numberOfLines = 0;
    self.activeSummaryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:self.activeSummaryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.activeSummaryLabel.topAnchor constraintEqualToAnchor:card.subviews.firstObject.bottomAnchor constant:10.0],
        [self.activeSummaryLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [self.activeSummaryLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [self.activeSummaryLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0]
    ]];

    return card;
}

- (UIView *)buildIpadCommandDeck {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    self.ipadApplyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.ipadApplyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipadApplyButton.titleLabel.font = [Styling fontBold:16.0];
    [self.ipadApplyButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.ipadApplyButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.ipadApplyButton, 18.0);
    PPApplyButtonShadow(self.ipadApplyButton);
    [self.ipadApplyButton addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.4, *)) {
        self.ipadApplyButton.pointerInteractionEnabled = YES;
    }
    [container addSubview:self.ipadApplyButton];

    self.ipadResetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.ipadResetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipadResetButton.titleLabel.font = [Styling fontBold:14.0];
    [self.ipadResetButton setTitle:kLang(@"Market_FilterSheet_ResetShortcut") forState:UIControlStateNormal];
    self.ipadResetButton.tintColor = [UIColor ppTextPrimary];
    self.ipadResetButton.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.8];
    self.ipadResetButton.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
    self.ipadResetButton.layer.borderWidth = 1.0;
    PPApplyContinuousCorners(self.ipadResetButton, 16.0);
    [self.ipadResetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.4, *)) {
        self.ipadResetButton.pointerInteractionEnabled = YES;
    }
    [container addSubview:self.ipadResetButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.ipadApplyButton.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.ipadApplyButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.ipadApplyButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.ipadApplyButton.heightAnchor constraintEqualToConstant:50.0],

        [self.ipadResetButton.topAnchor constraintEqualToAnchor:self.ipadApplyButton.bottomAnchor constant:10.0],
        [self.ipadResetButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.ipadResetButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.ipadResetButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [self.ipadResetButton.heightAnchor constraintEqualToConstant:44.0]
    ]];

    return container;
}

#pragma mark - Component Factories

- (UIView *)makeCardContainerWithTitle:(NSString *)title icon:(NSString *)iconName {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppSurfaceElevated];
    card.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.65].CGColor;
    card.layer.borderWidth = 1.0;
    PPApplyContinuousCorners(card, 16.0);
    PPApplyCardShadow(card);

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:header];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [UIColor ppPrimary];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *iCfg = [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
    iconView.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:iCfg];
    [header addSubview:iconView];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title;
    lbl.font = [Styling fontBold:13.5];
    lbl.textColor = [UIColor ppTextSecondary];
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    [header addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:10.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [header.heightAnchor constraintEqualToConstant:20.0],

        [iconView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [lbl.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:6.0],
        [lbl.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [lbl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];

    return card;
}

- (UIButton *)createPillButtonWithTitle:(NSString *)title icon:(nullable NSString *)iconName tag:(NSInteger)tag selector:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.tag = tag;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    PPApplyContinuousCorners(btn, 16.0);
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:34.0].active = YES;

    if (iconName.length > 0) {
        UIImageSymbolConfiguration *sCfg = [UIImageSymbolConfiguration configurationWithPointSize:11.5 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [[UIImage systemImageNamed:iconName] imageWithConfiguration:sCfg];
        [btn setImage:img forState:UIControlStateNormal];
        btn.imageEdgeInsets = Language.isRTL ? UIEdgeInsetsMake(0, 4, 0, -4) : UIEdgeInsetsMake(0, -4, 0, 4);
    }

    if (@available(iOS 13.4, *)) {
        btn.pointerInteractionEnabled = YES;
    }

    return btn;
}

#pragma mark - State Evaluation & Refresh

- (NSInteger)countForStock:(PPProviderMarketStockFilter)stock {
    NSInteger c = 0;
    for (PPProviderMarketItem *it in self.items) {
        if (stock == PPProviderMarketStockFilterAll) c++;
        else if (stock == PPProviderMarketStockFilterInStock && (!it.noStock && it.quantity > 5)) c++;
        else if (stock == PPProviderMarketStockFilterLowStock && (it.quantity <= 5 || it.noStock)) c++;
    }
    return c;
}

- (NSInteger)countForOffers:(PPProviderMarketOfferFilter)offer {
    NSInteger c = 0;
    for (PPProviderMarketItem *it in self.items) {
        if (offer == PPProviderMarketOfferFilterAll) c++;
        else if (offer == PPProviderMarketOfferFilterOffersOnly && it.hasOffer) c++;
    }
    return c;
}

- (NSInteger)countForVisibility:(PPProviderMarketVisibilityFilter)vis {
    NSInteger c = 0;
    for (PPProviderMarketItem *it in self.items) {
        if (vis == PPProviderMarketVisibilityFilterAll) c++;
        else if (vis == PPProviderMarketVisibilityFilterHiddenOnly && (!it.showInAppMarket || it.isArchived)) c++;
    }
    return c;
}

- (NSInteger)countForKind:(PPProviderMarketKindFilter)kind {
    NSInteger c = 0;
    for (PPProviderMarketItem *it in self.items) {
        if (kind == PPProviderMarketKindFilterAll) c++;
        else if (kind == PPProviderMarketKindFilterAccessories && it.accessKindType == 1) c++;
        else if (kind == PPProviderMarketKindFilterFood && it.accessKindType == 0) c++;
    }
    return c;
}

- (NSInteger)calculatedMatchCount {
    NSInteger count = 0;
    for (PPProviderMarketItem *item in self.items) {
        if ([self.criteria evaluatesItem:item]) {
            count++;
        }
    }
    return count;
}

- (void)updateAllButtonsAndTelemetry {
    // 1. Stock Buttons
    for (UIButton *btn in self.stockButtons) {
        [self stylePill:btn isSelected:(btn.tag == self.criteria.stockFilter)];
    }

    // 2. Kind Buttons
    for (UIButton *btn in self.kindButtons) {
        [self stylePill:btn isSelected:(btn.tag == self.criteria.kindFilter)];
    }

    // 3. Offer Buttons
    for (UIButton *btn in self.offerButtons) {
        [self stylePill:btn isSelected:(btn.tag == self.criteria.offerFilter)];
    }

    // 4. Visibility Buttons
    for (UIButton *btn in self.visibilityButtons) {
        [self stylePill:btn isSelected:(btn.tag == self.criteria.visibilityFilter)];
    }

    // 5. Sort Buttons
    for (UIButton *btn in self.sortButtons) {
        [self stylePill:btn isSelected:(btn.tag == self.criteria.sort)];
    }

    // 6. Header Reset & Active Badge
    NSInteger activeCount = [self.criteria activeFilterCount];
    BOOL isDefault = [self.criteria isDefault];

    self.resetButton.alpha = isDefault ? 0.35 : 1.0;
    self.resetButton.userInteractionEnabled = !isDefault;

    if (activeCount > 0) {
        self.activeBadgePill.hidden = NO;
        self.activeBadgeLabel.text = [NSString stringWithFormat:kLang(@"Market_FilterSheet_ActiveFiltersFormat"), (long)activeCount];
    } else {
        self.activeBadgePill.hidden = YES;
    }

    // 7. Dynamic Match Count & Button State
    NSInteger matchCount = [self calculatedMatchCount];
    NSString *btnTitle = (matchCount > 0)
        ? [NSString stringWithFormat:kLang(@"Market_FilterSheet_ApplyFormat"), (long)matchCount]
        : kLang(@"Market_FilterSheet_ZeroMatches");

    if (self.applyButton) {
        [self.applyButton setTitle:btnTitle forState:UIControlStateNormal];
        self.applyButton.alpha = (matchCount > 0) ? 1.0 : 0.6;
        self.applyButton.userInteractionEnabled = (matchCount > 0);
    }

    if (self.ipadApplyButton) {
        NSString *ipadTitle = [NSString stringWithFormat:@"%@  ⌘ ↩", btnTitle];
        [self.ipadApplyButton setTitle:ipadTitle forState:UIControlStateNormal];
        self.ipadApplyButton.alpha = (matchCount > 0) ? 1.0 : 0.6;
        self.ipadApplyButton.userInteractionEnabled = (matchCount > 0);
    }

    // 8. Active Summary Dossier (iPad)
    if (self.activeSummaryLabel) {
        if (isDefault) {
            self.activeSummaryLabel.text = [Language isRTL]
                ? @"كافة فلاتر التصفية غير مفعلة. سيتم عرض جميع المنتجات بترتيب الأحدث."
                : @"All filters inactive. Displaying entire catalog sorted by newest.";
        } else {
            NSMutableArray<NSString *> *summaryParts = [NSMutableArray array];
            if (self.criteria.stockFilter == PPProviderMarketStockFilterInStock) [summaryParts addObject:kLang(@"Market_FilterSheet_InStockOnly")];
            if (self.criteria.stockFilter == PPProviderMarketStockFilterLowStock) [summaryParts addObject:kLang(@"Market_FilterSheet_LowStockOnly")];
            if (self.criteria.kindFilter == PPProviderMarketKindFilterAccessories) [summaryParts addObject:kLang(@"Market_Accessory")];
            if (self.criteria.kindFilter == PPProviderMarketKindFilterFood) [summaryParts addObject:kLang(@"Market_Food")];
            if (self.criteria.offerFilter == PPProviderMarketOfferFilterOffersOnly) [summaryParts addObject:kLang(@"Market_FilterSheet_OffersOnly")];
            if (self.criteria.visibilityFilter == PPProviderMarketVisibilityFilterHiddenOnly) [summaryParts addObject:kLang(@"Market_FilterSheet_HiddenOnly")];
            self.activeSummaryLabel.text = [summaryParts componentsJoinedByString:@" • "];
        }
    }
}

- (void)stylePill:(UIButton *)btn isSelected:(BOOL)isSelected {
    btn.titleLabel.font = isSelected ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
    if (isSelected) {
        btn.tintColor = UIColor.whiteColor;
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor ppPrimary];
        btn.layer.borderWidth = 0.0;
        PPApplyButtonShadow(btn);
    } else {
        btn.tintColor = [UIColor ppTextPrimary];
        [btn setTitleColor:[UIColor ppTextPrimary] forState:UIControlStateNormal];
        btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.75];
        btn.layer.borderWidth = 0.8;
        btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.65].CGColor;
        btn.layer.shadowOpacity = 0.0;
    }
}

#pragma mark - Actions & Interactions

- (void)stockPillTapped:(UIButton *)sender {
    [self playLightHaptic];
    self.criteria.stockFilter = sender.tag;
    [self updateAllButtonsAndTelemetry];
}

- (void)kindPillTapped:(UIButton *)sender {
    [self playLightHaptic];
    self.criteria.kindFilter = sender.tag;
    [self updateAllButtonsAndTelemetry];
}

- (void)offerPillTapped:(UIButton *)sender {
    [self playLightHaptic];
    self.criteria.offerFilter = sender.tag;
    [self updateAllButtonsAndTelemetry];
}

- (void)visibilityPillTapped:(UIButton *)sender {
    [self playLightHaptic];
    self.criteria.visibilityFilter = sender.tag;
    [self updateAllButtonsAndTelemetry];
}

- (void)sortPillTapped:(UIButton *)sender {
    [self playLightHaptic];
    self.criteria.sort = sender.tag;
    [self updateAllButtonsAndTelemetry];
}

- (void)presetTapped:(UIButton *)sender {
    [self playLightHaptic];
    switch (sender.tag) {
        case 0: // All
            [self.criteria reset];
            break;
        case 1: // Low stock
            self.criteria.stockFilter = PPProviderMarketStockFilterLowStock;
            break;
        case 2: // Deals
            self.criteria.offerFilter = PPProviderMarketOfferFilterOffersOnly;
            break;
        case 3: // Food
            self.criteria.kindFilter = PPProviderMarketKindFilterFood;
            break;
        case 4: // Accessories
            self.criteria.kindFilter = PPProviderMarketKindFilterAccessories;
            break;
        case 5: // Hidden
            self.criteria.visibilityFilter = PPProviderMarketVisibilityFilterHiddenOnly;
            break;
    }
    [self updateAllButtonsAndTelemetry];
}

- (void)resetTapped {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeWarning];
    [self.criteria reset];
    [self updateAllButtonsAndTelemetry];
}

- (void)applyTapped {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    if (self.onApplyCriteria) {
        self.onApplyCriteria(self.criteria);
    }
    if (self.onApplyLegacy) {
        self.onApplyLegacy(self.criteria.primaryLegacyFilter, self.criteria.sort);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playLightHaptic {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [gen impactOccurred];
    }
}

#pragma mark - iPad Hardware Key Commands

- (NSArray<UIKeyCommand *> *)keyCommands {
    return @[
        [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:UIKeyModifierCommand action:@selector(applyTapped)],
        [UIKeyCommand keyCommandWithInput:@"r" modifierFlags:UIKeyModifierCommand action:@selector(resetTapped)],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(dismissTapped)]
    ];
}

@end

// MARK: - Category-Defining Product Family Sub-Variant Row

@interface PPProviderVariantSubRowView : UIView
@property (nonatomic, strong) PPProviderMarketItem *member;
@property (nonatomic, copy) void (^onStockTapped)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onOfferTapped)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onRowSelected)(PPProviderMarketItem *item);
@end

@implementation PPProviderVariantSubRowView

- (instancetype)initWithMember:(PPProviderMarketItem *)member {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _member = member;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor ppSurfaceElevated];
        self.layer.cornerRadius = PPCornerSmall;
        self.layer.borderWidth = 0.6;
        self.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = 8.0;
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self addSubview:hStack];

    if (self.member.pos_hasRealColor) {
        UIView *cDot = [[UIView alloc] init];
        cDot.translatesAutoresizingMaskIntoConstraints = NO;
        cDot.backgroundColor = [UIColor colorWithHexString:self.member.pos_variantColorHex];
        cDot.layer.cornerRadius = 6;
        cDot.layer.borderWidth = 1.0;
        cDot.layer.borderColor = [UIColor.blackColor colorWithAlphaComponent:0.15].CGColor;
        [hStack addArrangedSubview:cDot];
        [cDot.widthAnchor constraintEqualToConstant:12].active = YES;
        [cDot.heightAnchor constraintEqualToConstant:12].active = YES;
    }

    UILabel *optLbl = [[UILabel alloc] init];
    optLbl.font = [Styling fontBold:13.0];
    optLbl.textColor = [UIColor ppTextPrimary];
    optLbl.text = self.member.pos_variantOptionLabel.length ? self.member.pos_variantOptionLabel : self.member.pos_smartVariantDescription;
    [hStack addArrangedSubview:optLbl];

    UILabel *qtyBadge = [[UILabel alloc] init];
    qtyBadge.font = [Styling fontBold:11.0];
    qtyBadge.textColor = self.member.quantity > 5 ? [UIColor ppSuccess] : [UIColor ppWarning];
    qtyBadge.text = [NSString stringWithFormat:@"%ld %@", (long)self.member.quantity, Language.isRTL ? @"حبة" : @"pcs"];
    [hStack addArrangedSubview:qtyBadge];

    UIView *spacer = [[UIView alloc] init];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [hStack addArrangedSubview:spacer];

    UILabel *pLbl = [[UILabel alloc] init];
    pLbl.font = [Styling fontBold:13.5];
    pLbl.textColor = [UIColor ppPrimary];
    double finalP = self.member.finalPrice > 0 ? self.member.finalPrice : self.member.price;
    pLbl.text = [NSString stringWithFormat:@"%.0f QAR", finalP];
    [hStack addArrangedSubview:pLbl];

    UIButton *stkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [stkBtn setImage:[UIImage systemImageNamed:@"shippingbox.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    stkBtn.tintColor = [UIColor ppPrimary];
    stkBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(stkBtn, 10);
    [stkBtn addTarget:self action:@selector(stockTapped) forControlEvents:UIControlEventTouchUpInside];
    [hStack addArrangedSubview:stkBtn];
    [stkBtn.widthAnchor constraintEqualToConstant:28].active = YES;
    [stkBtn.heightAnchor constraintEqualToConstant:28].active = YES;

    UIButton *ofrBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [ofrBtn setImage:[UIImage systemImageNamed:@"tag.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    ofrBtn.tintColor = [UIColor ppDiscount];
    ofrBtn.backgroundColor = [[UIColor ppDiscount] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(ofrBtn, 10);
    [ofrBtn addTarget:self action:@selector(offerTapped) forControlEvents:UIControlEventTouchUpInside];
    [hStack addArrangedSubview:ofrBtn];
    [ofrBtn.widthAnchor constraintEqualToConstant:28].active = YES;
    [ofrBtn.heightAnchor constraintEqualToConstant:28].active = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rowTapped)];
    [self addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [hStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
        [hStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
        [hStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
        [hStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:40]
    ]];
}

- (void)stockTapped { if (self.onStockTapped) self.onStockTapped(self.member); }
- (void)offerTapped { if (self.onOfferTapped) self.onOfferTapped(self.member); }
- (void)rowTapped { if (self.onRowSelected) self.onRowSelected(self.member); }

@end

// MARK: - Category-Defining Product Family Card Cell

@interface PPProviderMarketFamilyCardCell : UITableViewCell

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIView *stockBadgeContainer;
@property (nonatomic, strong) UILabel *stockBadgeLabel;
@property (nonatomic, strong) UILabel *kindPill;
@property (nonatomic, strong) UILabel *optionsBadge;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *priceRangeLabel;
@property (nonatomic, strong) UIStackView *swatchesStack;
@property (nonatomic, strong) UIButton *expandButton;
@property (nonatomic, strong) UIButton *studioButton;
@property (nonatomic, strong) UIStackView *subVariantsStack;
@property (nonatomic, strong) PPProviderMarketDisplayGroup *group;

@property (nonatomic, copy) void (^onExpandTapped)(void);
@property (nonatomic, copy) void (^onStudioTapped)(void);
@property (nonatomic, copy) void (^onMemberSelected)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onMemberStockTapped)(PPProviderMarketItem *item);
@property (nonatomic, copy) void (^onMemberOfferTapped)(PPProviderMarketItem *item);

- (void)configureWithGroup:(PPProviderMarketDisplayGroup *)group;
- (void)updateExpandedState;

@end

@implementation PPProviderMarketFamilyCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupCellUI];
    }
    return self;
}

- (void)setupCellUI {
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(self.cardView, PPCornerCard);
    [self.contentView addSubview:self.cardView];

    // 1. Thumbnail (84x84)
    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.thumbnailView, PPCorner16);
    self.thumbnailView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    [self.cardView addSubview:self.thumbnailView];

    // Stock Badge on image
    self.stockBadgeContainer = [[UIView alloc] init];
    self.stockBadgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.stockBadgeContainer, 10);
    [self.cardView addSubview:self.stockBadgeContainer];

    self.stockBadgeLabel = [[UILabel alloc] init];
    self.stockBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockBadgeLabel.font = [Styling fontBold:10.5];
    self.stockBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.stockBadgeContainer addSubview:self.stockBadgeLabel];

    // 2. Kind Pill & Options Badge Header
    self.kindPill = [[UILabel alloc] init];
    self.kindPill.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindPill.font = [Styling fontBold:11.0];
    self.kindPill.textColor = [UIColor ppPrimary];
    self.kindPill.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.09];
    self.kindPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.kindPill, 9);
    self.kindPill.clipsToBounds = YES;
    [self.cardView addSubview:self.kindPill];

    self.optionsBadge = [[UILabel alloc] init];
    self.optionsBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.optionsBadge.font = [Styling fontBold:11.0];
    self.optionsBadge.textColor = [UIColor colorWithRed:0.42 green:0.23 blue:0.71 alpha:1.0];
    self.optionsBadge.backgroundColor = [[UIColor colorWithRed:0.42 green:0.23 blue:0.71 alpha:1.0] colorWithAlphaComponent:0.10];
    self.optionsBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.optionsBadge, 9);
    self.optionsBadge.clipsToBounds = YES;
    [self.cardView addSubview:self.optionsBadge];

    // 3. Name
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [Styling fontBold:16.5];
    self.nameLabel.textColor = [UIColor ppTextPrimary];
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.cardView addSubview:self.nameLabel];

    // 4. Price Range Label
    self.priceRangeLabel = [[UILabel alloc] init];
    self.priceRangeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceRangeLabel.font = [Styling fontBold:17.0];
    self.priceRangeLabel.textColor = [UIColor ppPrimary];
    [self.cardView addSubview:self.priceRangeLabel];

    // 5. Swatches & Pills Stack
    self.swatchesStack = [[UIStackView alloc] init];
    self.swatchesStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.swatchesStack.axis = UILayoutConstraintAxisHorizontal;
    self.swatchesStack.spacing = 6.0;
    self.swatchesStack.alignment = UIStackViewAlignmentCenter;
    self.swatchesStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.cardView addSubview:self.swatchesStack];

    // 6. Action Strip
    UIView *stripDivider = [[UIView alloc] init];
    stripDivider.translatesAutoresizingMaskIntoConstraints = NO;
    stripDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5];
    [self.cardView addSubview:stripDivider];

    UIStackView *actionsStack = [[UIStackView alloc] init];
    actionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    actionsStack.axis = UILayoutConstraintAxisHorizontal;
    actionsStack.spacing = 8.0;
    actionsStack.distribution = UIStackViewDistributionFillProportionally;
    actionsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.cardView addSubview:actionsStack];

    self.expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.expandButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    [self.expandButton setImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:cfg] forState:UIControlStateNormal];
    self.expandButton.titleLabel.font = [Styling fontMedium:12.0];
    self.expandButton.tintColor = [UIColor ppTextPrimary];
    self.expandButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(self.expandButton, 12);
    [self.expandButton addTarget:self action:@selector(expandBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.expandButton];

    self.studioButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.studioButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.studioButton setImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:cfg] forState:UIControlStateNormal];
    [self.studioButton setTitle:[NSString stringWithFormat:@" %@", Language.isRTL ? @"الاستوديو" : @"Studio"] forState:UIControlStateNormal];
    self.studioButton.titleLabel.font = [Styling fontBold:12.0];
    self.studioButton.tintColor = [UIColor ppPrimary];
    self.studioButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(self.studioButton, 12);
    [self.studioButton addTarget:self action:@selector(studioBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.studioButton];

    // 7. Sub-Variants Drawer
    self.subVariantsStack = [[UIStackView alloc] init];
    self.subVariantsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.subVariantsStack.axis = UILayoutConstraintAxisVertical;
    self.subVariantsStack.spacing = 6.0;
    self.subVariantsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.subVariantsStack.hidden = YES;
    [self.cardView addSubview:self.subVariantsStack];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

        // Thumbnail (84x84)
        [self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.thumbnailView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.thumbnailView.widthAnchor constraintEqualToConstant:84],
        [self.thumbnailView.heightAnchor constraintEqualToConstant:84],

        // Stock Badge on image
        [self.stockBadgeContainer.leadingAnchor constraintEqualToAnchor:self.thumbnailView.leadingAnchor constant:4],
        [self.stockBadgeContainer.bottomAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor constant:-4],
        [self.stockBadgeContainer.heightAnchor constraintEqualToConstant:20],

        [self.stockBadgeLabel.leadingAnchor constraintEqualToAnchor:self.stockBadgeContainer.leadingAnchor constant:6],
        [self.stockBadgeLabel.trailingAnchor constraintEqualToAnchor:self.stockBadgeContainer.trailingAnchor constant:-6],
        [self.stockBadgeLabel.centerYAnchor constraintEqualToAnchor:self.stockBadgeContainer.centerYAnchor],

        // Header Row: Kind Pill & Options Badge
        [self.kindPill.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.kindPill.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.kindPill.heightAnchor constraintEqualToConstant:20],
        [self.kindPill.widthAnchor constraintGreaterThanOrEqualToConstant:50],

        [self.optionsBadge.leadingAnchor constraintEqualToAnchor:self.kindPill.trailingAnchor constant:8],
        [self.optionsBadge.centerYAnchor constraintEqualToAnchor:self.kindPill.centerYAnchor],
        [self.optionsBadge.heightAnchor constraintEqualToConstant:20],
        [self.optionsBadge.trailingAnchor constraintLessThanOrEqualToAnchor:self.cardView.trailingAnchor constant:-12],

        // Name
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.kindPill.bottomAnchor constant:6],

        // Price Range
        [self.priceRangeLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.priceRangeLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:6],

        // Swatches
        [self.swatchesStack.leadingAnchor constraintEqualToAnchor:self.priceRangeLabel.trailingAnchor constant:8],
        [self.swatchesStack.centerYAnchor constraintEqualToAnchor:self.priceRangeLabel.centerYAnchor],
        [self.swatchesStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.swatchesStack.heightAnchor constraintEqualToConstant:20],

        // Action Strip
        [stripDivider.topAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor constant:12],
        [stripDivider.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [stripDivider.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [stripDivider.heightAnchor constraintEqualToConstant:0.8],

        [actionsStack.topAnchor constraintEqualToAnchor:stripDivider.bottomAnchor constant:8],
        [actionsStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:10],
        [actionsStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-10],
        [actionsStack.heightAnchor constraintEqualToConstant:34],

        // Sub-variants Stack
        [self.subVariantsStack.topAnchor constraintEqualToAnchor:actionsStack.bottomAnchor constant:8],
        [self.subVariantsStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:10],
        [self.subVariantsStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-10],
        [self.subVariantsStack.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-10]
    ]];
}

- (void)expandBtnTapped {
    if (self.onExpandTapped) self.onExpandTapped();
}

- (void)studioBtnTapped {
    if (self.onStudioTapped) self.onStudioTapped();
}

- (void)configureWithGroup:(PPProviderMarketDisplayGroup *)group {
    if (!group) return;
    self.group = group;

    PPProviderMarketItem *def = group.defaultMember;

    if (def.imageURLsArray.firstObject.length > 0) {
        [self.thumbnailView setImageURL:[NSURL URLWithString:def.imageURLsArray.firstObject]];
    } else {
        self.thumbnailView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
        self.thumbnailView.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.3];
    }

    UIColor *stockColor;
    NSString *stockText;
    if (group.totalStock == 0 || group.hasOutOfStock) {
        stockColor = (group.totalStock == 0) ? [UIColor ppError] : [UIColor ppWarning];
        stockText = (group.totalStock == 0) ? kLang(@"Market_OutOfStock") : [NSString stringWithFormat:kLang(@"Market_Card_InStockBadge"), (long)group.totalStock];
    } else if (group.hasLowStock) {
        stockColor = [UIColor ppWarning];
        stockText = [NSString stringWithFormat:kLang(@"Market_Card_LowStockBadge"), (long)group.totalStock];
    } else {
        stockColor = [UIColor ppSuccess];
        stockText = [NSString stringWithFormat:kLang(@"Market_Card_InStockBadge"), (long)group.totalStock];
    }
    self.stockBadgeLabel.text = stockText;
    self.stockBadgeLabel.textColor = stockColor;
    self.stockBadgeContainer.backgroundColor = [[UIColor ppSurfaceElevated] colorWithAlphaComponent:0.95];
    self.stockBadgeContainer.layer.borderWidth = 0.6;
    self.stockBadgeContainer.layer.borderColor = [stockColor colorWithAlphaComponent:0.5].CGColor;

    self.kindPill.text = [NSString stringWithFormat:@"  %@  ", [def kindLabel]];
    self.optionsBadge.text = [NSString stringWithFormat:@"  %@  ", group.optionsBadgeString];

    BOOL isRTL = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    NSString *disp = isRTL ? (def.name.length ? def.name : def.nameEn) : (def.nameEn.length ? def.nameEn : def.name);
    self.nameLabel.text = disp;

    self.priceRangeLabel.text = group.priceRangeString;

    for (UIView *v in self.swatchesStack.arrangedSubviews) {
        [self.swatchesStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    NSArray<NSString *> *swatches = group.swatchesHexes;
    for (NSInteger i = 0; i < MIN((NSInteger)swatches.count, 4); i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = [UIColor colorWithHexString:swatches[i]];
        dot.layer.cornerRadius = 6;
        dot.layer.borderWidth = 1.0;
        dot.layer.borderColor = [UIColor.blackColor colorWithAlphaComponent:0.15].CGColor;
        [self.swatchesStack addArrangedSubview:dot];
        [dot.widthAnchor constraintEqualToConstant:12].active = YES;
        [dot.heightAnchor constraintEqualToConstant:12].active = YES;
    }
    if (swatches.count > 4) {
        UILabel *moreLbl = [[UILabel alloc] init];
        moreLbl.font = [Styling fontBold:10];
        moreLbl.textColor = [UIColor ppTextSecondary];
        moreLbl.text = [NSString stringWithFormat:@"+%ld", (long)(swatches.count - 4)];
        [self.swatchesStack addArrangedSubview:moreLbl];
    }

    [self updateExpandedState];
}

- (void)updateExpandedState {
    BOOL exp = self.group.isExpanded;
    self.subVariantsStack.hidden = !exp;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    NSString *chevronName = exp ? @"chevron.up" : @"chevron.down";
    [self.expandButton setImage:[UIImage systemImageNamed:chevronName withConfiguration:cfg] forState:UIControlStateNormal];
    NSString *expTitle = [NSString stringWithFormat:Language.isRTL ? @" %@ خيارات (%ld)" : @" %@ Variants (%ld)",
                          exp ? (Language.isRTL ? @"إخفاء" : @"عرض") : (Language.isRTL ? @"عرض" : @"View"),
                          (long)self.group.activeMembers.count];
    [self.expandButton setTitle:expTitle forState:UIControlStateNormal];

    if (exp) {
        [self rebuildSubVariantsDrawer];
    }
}

- (void)rebuildSubVariantsDrawer {
    for (UIView *v in self.subVariantsStack.arrangedSubviews) {
        [self.subVariantsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    for (PPProviderMarketItem *member in self.group.activeMembers) {
        PPProviderVariantSubRowView *row = [[PPProviderVariantSubRowView alloc] initWithMember:member];
        __weak typeof(self) ws = self;
        row.onStockTapped = ^(PPProviderMarketItem *it) {
            if (ws.onMemberStockTapped) ws.onMemberStockTapped(it);
        };
        row.onOfferTapped = ^(PPProviderMarketItem *it) {
            if (ws.onMemberOfferTapped) ws.onMemberOfferTapped(it);
        };
        row.onRowSelected = ^(PPProviderMarketItem *it) {
            if (ws.onMemberSelected) ws.onMemberSelected(it);
        };
        [self.subVariantsStack addArrangedSubview:row];
    }
}

@end

// MARK: - Reimagined Product Card Cell

@interface PPProviderMarketItemCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIView *stockBadgeContainer;
@property (nonatomic, strong) UILabel *stockBadgeLabel;
@property (nonatomic, strong) UILabel *kindPill;
@property (nonatomic, strong) UIView *visibilityDot;
@property (nonatomic, strong) UILabel *visibilityLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIView *discountBadge;
@property (nonatomic, strong) UILabel *discountBadgeLabel;
@property (nonatomic, strong) UIButton *stockActionButton;
@property (nonatomic, strong) UIButton *offerActionButton;
@property (nonatomic, strong) UIButton *visibilityActionButton;
@property (nonatomic, strong) UIButton *moreActionButton;

@property (nonatomic, copy) void (^onStockTapped)(void);
@property (nonatomic, copy) void (^onOfferTapped)(void);
@property (nonatomic, copy) void (^onVisibilityTapped)(void);
@property (nonatomic, copy) void (^onMoreTapped)(void);
@property (nonatomic, copy) void (^onCardTapped)(void);

- (void)configureWithItem:(PPProviderMarketItem *)item;
@end

@implementation PPProviderMarketItemCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupCellUI];
    }
    return self;
}

- (void)setupCellUI {
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(self.cardView, PPCornerCard);
    [self.contentView addSubview:self.cardView];

    // Card Tap Gesture
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cardTapped)];
    [self.cardView addGestureRecognizer:tap];

    // 1. Thumbnail
    self.thumbnailView = [[UIImageView alloc] init];
    self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbnailView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.thumbnailView, PPCorner16);
    self.thumbnailView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    [self.cardView addSubview:self.thumbnailView];

    // Stock Badge on image
    self.stockBadgeContainer = [[UIView alloc] init];
    self.stockBadgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.stockBadgeContainer, 10);
    [self.cardView addSubview:self.stockBadgeContainer];

    self.stockBadgeLabel = [[UILabel alloc] init];
    self.stockBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockBadgeLabel.font = [Styling fontBold:10.5];
    self.stockBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.stockBadgeContainer addSubview:self.stockBadgeLabel];

    // 2. Kind Pill & Visibility Header
    self.kindPill = [[UILabel alloc] init];
    self.kindPill.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindPill.font = [Styling fontBold:11.0];
    self.kindPill.textColor = [UIColor ppPrimary];
    self.kindPill.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.09];
    self.kindPill.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.kindPill, 9);
    self.kindPill.clipsToBounds = YES;
    [self.cardView addSubview:self.kindPill];

    self.visibilityDot = [[UIView alloc] init];
    self.visibilityDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityDot.layer.cornerRadius = 4;
    [self.cardView addSubview:self.visibilityDot];

    self.visibilityLabel = [[UILabel alloc] init];
    self.visibilityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityLabel.font = [Styling fontMedium:11.5];
    [self.cardView addSubview:self.visibilityLabel];

    // 3. Name
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [Styling fontBold:16.5];
    self.nameLabel.textColor = [UIColor ppTextPrimary];
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.cardView addSubview:self.nameLabel];

    // 4. Pricing Row
    self.originalPriceLabel = [[UILabel alloc] init];
    self.originalPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.originalPriceLabel.font = [Styling fontMedium:12.5];
    self.originalPriceLabel.textColor = [UIColor ppTextSecondary];
    [self.cardView addSubview:self.originalPriceLabel];

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.font = [Styling fontBold:17.0];
    self.priceLabel.textColor = [UIColor ppTextPrimary];
    [self.cardView addSubview:self.priceLabel];

    self.discountBadge = [[UIView alloc] init];
    self.discountBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.discountBadge.backgroundColor = [[UIColor ppDiscount] colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(self.discountBadge, 9);
    [self.cardView addSubview:self.discountBadge];

    self.discountBadgeLabel = [[UILabel alloc] init];
    self.discountBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.discountBadgeLabel.font = [Styling fontBold:11.0];
    self.discountBadgeLabel.textColor = [UIColor ppDiscount];
    [self.discountBadge addSubview:self.discountBadgeLabel];

    // 5. Micro-Actions Strip at Bottom
    UIView *stripDivider = [[UIView alloc] init];
    stripDivider.translatesAutoresizingMaskIntoConstraints = NO;
    stripDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5];
    [self.cardView addSubview:stripDivider];

    UIStackView *actionsStack = [[UIStackView alloc] init];
    actionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    actionsStack.axis = UILayoutConstraintAxisHorizontal;
    actionsStack.spacing = 8.0;
    actionsStack.distribution = UIStackViewDistributionFillProportionally;
    [self.cardView addSubview:actionsStack];

    self.stockActionButton = [self makeMicroButtonWithTitle:kLang(@"Market_Action_Stock") icon:@"shippingbox.fill" color:[UIColor ppPrimary]];
    [self.stockActionButton addTarget:self action:@selector(stockBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.stockActionButton];

    self.offerActionButton = [self makeMicroButtonWithTitle:kLang(@"Market_Action_Offer") icon:@"tag.fill" color:[UIColor ppDiscount]];
    [self.offerActionButton addTarget:self action:@selector(offerBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.offerActionButton];

    self.visibilityActionButton = [self makeMicroButtonWithTitle:kLang(@"Market_Action_Visibility") icon:@"eye.fill" color:[UIColor ppTextSecondary]];
    [self.visibilityActionButton addTarget:self action:@selector(visBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.visibilityActionButton];

    self.moreActionButton = [self makeMicroButtonWithTitle:kLang(@"Market_Action_Details") icon:@"ellipsis" color:[UIColor ppTextSecondary]];
    [self.moreActionButton addTarget:self action:@selector(moreBtnTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsStack addArrangedSubview:self.moreActionButton];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

        // Thumbnail (84x84)
        [self.thumbnailView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.thumbnailView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.thumbnailView.widthAnchor constraintEqualToConstant:84],
        [self.thumbnailView.heightAnchor constraintEqualToConstant:84],

        // Stock Badge on image
        [self.stockBadgeContainer.leadingAnchor constraintEqualToAnchor:self.thumbnailView.leadingAnchor constant:4],
        [self.stockBadgeContainer.bottomAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor constant:-4],
        [self.stockBadgeContainer.heightAnchor constraintEqualToConstant:20],

        [self.stockBadgeLabel.leadingAnchor constraintEqualToAnchor:self.stockBadgeContainer.leadingAnchor constant:6],
        [self.stockBadgeLabel.trailingAnchor constraintEqualToAnchor:self.stockBadgeContainer.trailingAnchor constant:-6],
        [self.stockBadgeLabel.centerYAnchor constraintEqualToAnchor:self.stockBadgeContainer.centerYAnchor],

        // Kind Pill & Visibility
        [self.kindPill.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.kindPill.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.kindPill.heightAnchor constraintEqualToConstant:20],
        [self.kindPill.widthAnchor constraintGreaterThanOrEqualToConstant:54],

        [self.visibilityDot.leadingAnchor constraintEqualToAnchor:self.kindPill.trailingAnchor constant:10],
        [self.visibilityDot.centerYAnchor constraintEqualToAnchor:self.kindPill.centerYAnchor],
        [self.visibilityDot.widthAnchor constraintEqualToConstant:8],
        [self.visibilityDot.heightAnchor constraintEqualToConstant:8],

        [self.visibilityLabel.leadingAnchor constraintEqualToAnchor:self.visibilityDot.trailingAnchor constant:5],
        [self.visibilityLabel.centerYAnchor constraintEqualToAnchor:self.visibilityDot.centerYAnchor],
        [self.visibilityLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.cardView.trailingAnchor constant:-12],

        // Name
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.kindPill.bottomAnchor constant:6],

        // Price Row
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.thumbnailView.trailingAnchor constant:12],
        [self.priceLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:6],

        [self.originalPriceLabel.leadingAnchor constraintEqualToAnchor:self.priceLabel.trailingAnchor constant:8],
        [self.originalPriceLabel.centerYAnchor constraintEqualToAnchor:self.priceLabel.centerYAnchor],

        [self.discountBadge.leadingAnchor constraintEqualToAnchor:self.originalPriceLabel.trailingAnchor constant:8],
        [self.discountBadge.centerYAnchor constraintEqualToAnchor:self.priceLabel.centerYAnchor],
        [self.discountBadge.heightAnchor constraintEqualToConstant:20],

        [self.discountBadgeLabel.leadingAnchor constraintEqualToAnchor:self.discountBadge.leadingAnchor constant:6],
        [self.discountBadgeLabel.trailingAnchor constraintEqualToAnchor:self.discountBadge.trailingAnchor constant:-6],
        [self.discountBadgeLabel.centerYAnchor constraintEqualToAnchor:self.discountBadge.centerYAnchor],

        // Divider & Micro-Actions
        [stripDivider.topAnchor constraintEqualToAnchor:self.thumbnailView.bottomAnchor constant:12],
        [stripDivider.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [stripDivider.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-12],
        [stripDivider.heightAnchor constraintEqualToConstant:0.8],

        [actionsStack.topAnchor constraintEqualToAnchor:stripDivider.bottomAnchor constant:8],
        [actionsStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:10],
        [actionsStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-10],
        [actionsStack.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-8],
        [actionsStack.heightAnchor constraintEqualToConstant:32],
    ]];
}

- (UIButton *)makeMicroButtonWithTitle:(NSString *)title icon:(NSString *)icon color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    [btn setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontMedium:11.5];
    btn.tintColor = color;
    btn.backgroundColor = [color colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(btn, 12);
    return btn;
}

- (void)configureWithItem:(PPProviderMarketItem *)item {
    if (!item) return;

    // Thumbnail
    if (item.imageURLsArray.firstObject.length > 0) {
        [self.thumbnailView setImageURL:[NSURL URLWithString:item.imageURLsArray.firstObject]];
    } else {
        self.thumbnailView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
        self.thumbnailView.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.3];
    }

    // Stock Badge
    UIColor *stockColor;
    NSString *stockText;
    if (item.noStock || item.quantity == 0) {
        stockColor = [UIColor ppError];
        stockText = kLang(@"Market_OutOfStock");
    } else if (item.quantity <= 5) {
        stockColor = [UIColor ppWarning];
        stockText = [NSString stringWithFormat:kLang(@"Market_Card_LowStockBadge"), (long)item.quantity];
    } else {
        stockColor = [UIColor ppSuccess];
        stockText = [NSString stringWithFormat:kLang(@"Market_Card_InStockBadge"), (long)item.quantity];
    }
    self.stockBadgeLabel.text = stockText;
    self.stockBadgeLabel.textColor = stockColor;
    self.stockBadgeContainer.backgroundColor = [[UIColor ppSurfaceElevated] colorWithAlphaComponent:0.95];
    self.stockBadgeContainer.layer.borderWidth = 0.6;
    self.stockBadgeContainer.layer.borderColor = [stockColor colorWithAlphaComponent:0.5].CGColor;

    // Kind Badge
    self.kindPill.text = [NSString stringWithFormat:@"  %@  ", [item kindLabel]];

    // Visibility
    BOOL isVisible = item.showInAppMarket && !item.isArchived;
    if (isVisible) {
        self.visibilityDot.backgroundColor = [UIColor ppSuccess];
        self.visibilityLabel.text = kLang(@"Market_DetailSheet_Published");
        self.visibilityLabel.textColor = [UIColor ppSuccess];
    } else {
        self.visibilityDot.backgroundColor = [UIColor ppWarning];
        self.visibilityLabel.text = kLang(@"Market_Hidden");
        self.visibilityLabel.textColor = [UIColor ppWarning];
    }

    // Name
    BOOL isRTL = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    NSString *disp = isRTL ? (item.name.length ? item.name : item.nameEn) : (item.nameEn.length ? item.nameEn : item.name);
    if (item.isVariant && item.pos_smartVariantDescription.length > 0) {
        disp = [NSString stringWithFormat:@"%@ • %@", disp, item.pos_smartVariantDescription];
    }
    self.nameLabel.text = disp;

    // Pricing
    if (item.hasOffer && item.price > 0 && item.finalPrice < item.price) {
        // Strikethrough original
        NSDictionary *attrs = @{
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
            NSForegroundColorAttributeName: [UIColor ppTextTertiary]
        };
        self.originalPriceLabel.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.0f QAR", item.price] attributes:attrs];
        self.originalPriceLabel.hidden = NO;

        self.priceLabel.text = [NSString stringWithFormat:@"%.0f QAR", item.finalPrice];
        self.priceLabel.textColor = [UIColor ppDiscount];

        double savings = item.price - item.finalPrice;
        self.discountBadgeLabel.text = [NSString stringWithFormat:kLang(@"Market_Card_SaveBadge"), [NSString stringWithFormat:@"%.0f", savings]];
        self.discountBadge.hidden = NO;
    } else {
        self.originalPriceLabel.hidden = YES;
        self.discountBadge.hidden = YES;
        self.priceLabel.text = [NSString stringWithFormat:@"%.0f QAR", item.price];
        self.priceLabel.textColor = [UIColor ppTextPrimary];
    }

    // Quick Stock button label
    [self.stockActionButton setTitle:[NSString stringWithFormat:@" 📦 %ld", (long)item.quantity] forState:UIControlStateNormal];
}

- (void)cardTapped {
    if (self.onCardTapped) self.onCardTapped();
}

- (void)stockBtnTapped {
    if (self.onStockTapped) self.onStockTapped();
}

- (void)offerBtnTapped {
    if (self.onOfferTapped) self.onOfferTapped();
}

- (void)visBtnTapped {
    if (self.onVisibilityTapped) self.onVisibilityTapped();
}

- (void)moreBtnTapped {
    if (self.onMoreTapped) self.onMoreTapped();
}

@end

// MARK: - Reimagined PPProviderMarketItemsViewController

@interface PPProviderMarketItemsViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *branchesNavButton;

// Data Listeners & Collections
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *items;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *filteredItems;
@property (nonatomic, copy) NSArray<PPProviderMarketDisplayGroup *> *displayGroups;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) PPProviderMarketFilterCriteria *activeCriteria;
@property (nonatomic, assign) PPProviderMarketFilter activeFilter;
@property (nonatomic, assign) PPProviderMarketSort activeSort;
@property (nonatomic, assign) BOOL hasLoaded;

// Header Telemetry & Filter Controls
@property (nonatomic, strong) UIView *flightDeckHeaderView;
@property (nonatomic, strong) UILabel *totalSKUsBadge;
@property (nonatomic, strong) UILabel *totalValuationBadge;
@property (nonatomic, strong) UILabel *activeOffersBadge;
@property (nonatomic, strong) UILabel *stockAlertBadge;

@property (nonatomic, strong) UITextField *omniSearchField;
@property (nonatomic, strong) UIButton *clearSearchButton;
@property (nonatomic, strong) UILabel *searchResultsCountLabel;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *filterBadgeDot;

@end

@implementation PPProviderMarketItemsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.hasLoaded = NO;
    self.items = @[];
    self.filteredItems = @[];
    self.displayGroups = @[];
    self.searchQuery = @"";
    self.activeCriteria = [[PPProviderMarketFilterCriteria alloc] init];
    self.activeFilter = PPProviderMarketFilterAll;
    self.activeSort = PPProviderMarketSortNewest;

    [self setupNavButtons];
    [self setupTableView];
    [self buildEmptyState];
    [self startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [IQKeyboardManager sharedManager].enable = NO;
    
    // 1. Configure base navigation bar with title and back button
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Market_Title") showBack:YES];
    self.navigationController.navigationBar.tintColor = [UIColor ppPrimary];
    
    // 2. Suppress legacy items so UIKit never lays out conflicting navigation content
    self.navigationItem.rightBarButtonItems = nil;
    self.navigationItem.leftBarButtonItems = nil;
    
    // 3. Attach both action buttons directly to PPNavBar's action stack (left in RTL, right in LTR)
    [self pp_navBarRemoveButtonForKey:@"add"];
    [self pp_navBarRemoveButtonForKey:@"branches"];
    [self pp_navBarAddActionButton:self.addButton key:@"add"];
    [self pp_navBarAddActionButton:self.branchesNavButton key:@"branches"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [IQKeyboardManager sharedManager].enable = YES;
}

- (void)setupNavButtons {
    // 1. Add Button
    self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    [self.addButton setImage:[UIImage systemImageNamed:@"plus" withConfiguration:cfg] forState:UIControlStateNormal];
    self.addButton.tintColor = UIColor.whiteColor;
    self.addButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.addButton, PPTouchTargetMin / 2.0);
    PPApplyButtonShadow(self.addButton);
    [self.addButton.widthAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.addButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.addButton addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];

    // 2. Branches Button
    UIImageSymbolConfiguration *bCfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *bConfig = [UIButtonConfiguration plainButtonConfiguration];
        bConfig.image = [UIImage systemImageNamed:@"building.2.crop.circle.fill" withConfiguration:bCfg];
        bConfig.imagePadding = 6;
        bConfig.contentInsets = NSDirectionalEdgeInsetsMake(0, 12, 0, 14);
        NSMutableAttributedString *titleAttr = [[NSMutableAttributedString alloc] initWithString:kLang(@"Market_Branches_Button") attributes:@{
            NSFontAttributeName: [Styling fontBold:12.5] ?: [UIFont boldSystemFontOfSize:12.5],
            NSForegroundColorAttributeName: [UIColor ppPrimary]
        }];
        bConfig.attributedTitle = [[NSAttributedString alloc] initWithAttributedString:titleAttr];
        bConfig.baseForegroundColor = [UIColor ppPrimary];
        bConfig.background.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.09];
        bConfig.background.cornerRadius = PPTouchTargetMin / 2.0;
        self.branchesNavButton = [UIButton buttonWithConfiguration:bConfig primaryAction:nil];
    } else {
        self.branchesNavButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.branchesNavButton setImage:[UIImage systemImageNamed:@"building.2.crop.circle.fill" withConfiguration:bCfg] forState:UIControlStateNormal];
        [self.branchesNavButton setTitle:[NSString stringWithFormat:@" %@", kLang(@"Market_Branches_Button")] forState:UIControlStateNormal];
        self.branchesNavButton.titleLabel.font = [Styling fontBold:12.5];
        self.branchesNavButton.tintColor = [UIColor ppPrimary];
        self.branchesNavButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.09];
        self.branchesNavButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 14);
        PPApplyContinuousCorners(self.branchesNavButton, PPTouchTargetMin / 2.0);
    }
    self.branchesNavButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.branchesNavButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.branchesNavButton addTarget:self action:@selector(openBranchesTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 168;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[PPProviderMarketItemCardCell class] forCellReuseIdentifier:@"PPProviderMarketItemCardCell"];
    [self.tableView registerClass:[PPProviderMarketFamilyCardCell class] forCellReuseIdentifier:@"PPProviderMarketFamilyCardCell"];

    // Pull to Refresh
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor ppPrimary];
    [self.refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    [self.view addSubview:self.tableView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = [UIColor ppPrimary];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    [self rebuildFlightDeckHeader];
}

// MARK: - Reimagined Telemetry & Filter Flight Deck

- (void)rebuildFlightDeckHeader {
    CGFloat screenW = CGRectGetWidth(self.view.bounds);
    if (screenW <= 0) screenW = UIScreen.mainScreen.bounds.size.width;

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 238)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // 1. Cockpit Title Subtitle Row
    UILabel *cockpitTitle = [[UILabel alloc] init];
    cockpitTitle.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitTitle.text = kLang(@"Market_Title");
    cockpitTitle.font = [Styling fontBold:24.0];
    cockpitTitle.textColor = [UIColor ppTextPrimary];
    cockpitTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [header addSubview:cockpitTitle];

    UILabel *cockpitSubtitle = [[UILabel alloc] init];
    cockpitSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitSubtitle.text = kLang(@"Market_HeaderSubtitle");
    cockpitSubtitle.font = [Styling fontMedium:12.5];
    cockpitSubtitle.textColor = [UIColor ppTextSecondary];
    cockpitSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    cockpitSubtitle.numberOfLines = 1;
    [header addSubview:cockpitSubtitle];

    // 2. 4-Metric Telemetry Cockpit
    UIView *telemetryBox = [[UIView alloc] init];
    telemetryBox.translatesAutoresizingMaskIntoConstraints = NO;
    telemetryBox.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.75];
    PPApplyContinuousCorners(telemetryBox, PPCornerCard);
    telemetryBox.layer.borderWidth = 0.8;
    telemetryBox.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5].CGColor;
    [header addSubview:telemetryBox];

    UIStackView *telemetryStack = [[UIStackView alloc] init];
    telemetryStack.translatesAutoresizingMaskIntoConstraints = NO;
    telemetryStack.axis = UILayoutConstraintAxisHorizontal;
    telemetryStack.distribution = UIStackViewDistributionFillEqually;
    telemetryStack.spacing = 8.0;
    [telemetryBox addSubview:telemetryStack];

    self.totalSKUsBadge = [UILabel new];
    self.totalValuationBadge = [UILabel new];
    self.activeOffersBadge = [UILabel new];
    self.stockAlertBadge = [UILabel new];

    [telemetryStack addArrangedSubview:[self telemetryCardWithTitle:kLang(@"Market_Telemetry_TotalSKUs") label:self.totalSKUsBadge icon:@"shippingbox.fill" color:[UIColor ppPrimary] tapSelector:@selector(filterAllTapped)]];
    [telemetryStack addArrangedSubview:[self telemetryCardWithTitle:kLang(@"Market_Telemetry_Valuation") label:self.totalValuationBadge icon:@"chart.line.uptrend.xyaxis" color:[UIColor ppSuccess] tapSelector:nil]];
    [telemetryStack addArrangedSubview:[self telemetryCardWithTitle:kLang(@"Market_Telemetry_Offers") label:self.activeOffersBadge icon:@"tag.fill" color:[UIColor ppDiscount] tapSelector:@selector(filterOffersTapped)]];
    [telemetryStack addArrangedSubview:[self telemetryCardWithTitle:kLang(@"Market_Telemetry_Alerts") label:self.stockAlertBadge icon:@"exclamationmark.triangle.fill" color:[UIColor ppWarning] tapSelector:@selector(filterLowStockTapped)]];

    // 3. Reimagined Omni-Search & Filter Command Capsule
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    searchContainer.backgroundColor = [UIColor ppSurfaceElevated];
    searchContainer.layer.borderWidth = 0.8;
    searchContainer.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75].CGColor;
    PPApplyContinuousCorners(searchContainer, PPCornerMedium);
    PPApplyCardShadow(searchContainer);
    [header addSubview:searchContainer];

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.07];
    PPApplyContinuousCorners(iconBadge, 14);
    [searchContainer addSubview:iconBadge];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppPrimary];
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:searchIcon];

    self.omniSearchField = [[UITextField alloc] init];
    self.omniSearchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.omniSearchField.placeholder = kLang(@"Market_Search_Placeholder");
    self.omniSearchField.font = [Styling fontMedium:13.5];
    self.omniSearchField.textColor = [UIColor ppTextPrimary];
    self.omniSearchField.textAlignment = Language.alignmentForCurrentLanguage;
    self.omniSearchField.returnKeyType = UIReturnKeySearch;
    self.omniSearchField.delegate = self;
    [self.omniSearchField addTarget:self action:@selector(searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [searchContainer addSubview:self.omniSearchField];

    self.searchResultsCountLabel = [[UILabel alloc] init];
    self.searchResultsCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchResultsCountLabel.font = [Styling fontBold:11.0];
    self.searchResultsCountLabel.textColor = [UIColor ppPrimary];
    self.searchResultsCountLabel.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.10];
    self.searchResultsCountLabel.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.searchResultsCountLabel, 8);
    self.searchResultsCountLabel.clipsToBounds = YES;
    [searchContainer addSubview:self.searchResultsCountLabel];

    self.clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearSearchButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    self.clearSearchButton.tintColor = [UIColor ppTextTertiary];
    self.clearSearchButton.hidden = YES;
    [self.clearSearchButton addTarget:self action:@selector(clearSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [searchContainer addSubview:self.clearSearchButton];

    // Integrated Filter Trigger Button
    self.filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *fCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    [self.filterButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:fCfg] forState:UIControlStateNormal];
    [self.filterButton setTitle:[NSString stringWithFormat:@" %@", kLang(@"Market_Filter_Button")] forState:UIControlStateNormal];
    self.filterButton.titleLabel.font = [Styling fontBold:12.0];
    self.filterButton.tintColor = [UIColor ppTextSecondary];
    self.filterButton.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
    self.filterButton.layer.borderWidth = 0.7;
    self.filterButton.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
    self.filterButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    PPApplyContinuousCorners(self.filterButton, 15);
    [self.filterButton addTarget:self action:@selector(openFilterSheet) forControlEvents:UIControlEventTouchUpInside];
    [searchContainer addSubview:self.filterButton];

    self.filterBadgeDot = [[UIView alloc] init];
    self.filterBadgeDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterBadgeDot.backgroundColor = [UIColor ppPrimary];
    self.filterBadgeDot.layer.cornerRadius = 3.5;
    self.filterBadgeDot.hidden = YES;
    [self.filterButton addSubview:self.filterBadgeDot];

    // Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        [cockpitTitle.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [cockpitTitle.topAnchor constraintEqualToAnchor:header.topAnchor constant:10],

        [cockpitSubtitle.leadingAnchor constraintEqualToAnchor:cockpitTitle.leadingAnchor],
        [cockpitSubtitle.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [cockpitSubtitle.topAnchor constraintEqualToAnchor:cockpitTitle.bottomAnchor constant:2],

        [telemetryBox.topAnchor constraintEqualToAnchor:cockpitSubtitle.bottomAnchor constant:12],
        [telemetryBox.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [telemetryBox.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [telemetryBox.heightAnchor constraintEqualToConstant:78],

        [telemetryStack.topAnchor constraintEqualToAnchor:telemetryBox.topAnchor constant:6],
        [telemetryStack.bottomAnchor constraintEqualToAnchor:telemetryBox.bottomAnchor constant:-6],
        [telemetryStack.leadingAnchor constraintEqualToAnchor:telemetryBox.leadingAnchor constant:8],
        [telemetryStack.trailingAnchor constraintEqualToAnchor:telemetryBox.trailingAnchor constant:-8],

        [searchContainer.topAnchor constraintEqualToAnchor:telemetryBox.bottomAnchor constant:12],
        [searchContainer.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:PPSpaceBase],
        [searchContainer.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-PPSpaceBase],
        [searchContainer.heightAnchor constraintEqualToConstant:46],

        [iconBadge.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor constant:8],
        [iconBadge.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:28],
        [iconBadge.heightAnchor constraintEqualToConstant:28],

        [searchIcon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [searchIcon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:14],
        [searchIcon.heightAnchor constraintEqualToConstant:14],

        [self.omniSearchField.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:8],
        [self.omniSearchField.trailingAnchor constraintEqualToAnchor:self.searchResultsCountLabel.leadingAnchor constant:-6],
        [self.omniSearchField.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],

        [self.searchResultsCountLabel.trailingAnchor constraintEqualToAnchor:self.clearSearchButton.leadingAnchor constant:-4],
        [self.searchResultsCountLabel.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.searchResultsCountLabel.heightAnchor constraintEqualToConstant:20],
        [self.searchResultsCountLabel.widthAnchor constraintGreaterThanOrEqualToConstant:26],

        [self.clearSearchButton.trailingAnchor constraintEqualToAnchor:self.filterButton.leadingAnchor constant:-8],
        [self.clearSearchButton.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.clearSearchButton.widthAnchor constraintEqualToConstant:22],
        [self.clearSearchButton.heightAnchor constraintEqualToConstant:22],

        [self.filterButton.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor constant:-7],
        [self.filterButton.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [self.filterButton.heightAnchor constraintEqualToConstant:32],
        [self.filterButton.widthAnchor constraintGreaterThanOrEqualToConstant:76],

        [self.filterBadgeDot.topAnchor constraintEqualToAnchor:self.filterButton.topAnchor constant:4],
        [self.filterBadgeDot.trailingAnchor constraintEqualToAnchor:self.filterButton.trailingAnchor constant:-4],
        [self.filterBadgeDot.widthAnchor constraintEqualToConstant:7],
        [self.filterBadgeDot.heightAnchor constraintEqualToConstant:7],
    ]];

    self.flightDeckHeaderView = header;
    self.tableView.tableHeaderView = header;
}

- (UIView *)telemetryCardWithTitle:(NSString *)title label:(UILabel *)label icon:(NSString *)icon color:(UIColor *)color tapSelector:(SEL)selector {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [[UIColor ppBackground] colorWithAlphaComponent:0.65];
    PPApplyContinuousCorners(card, PPCornerSmall);

    if (selector) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selector];
        [card addGestureRecognizer:tap];
        card.userInteractionEnabled = YES;
    }

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = color;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:iconView];

    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:14.5];
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"—";
    [card addSubview:label];

    UILabel *tLabel = [[UILabel alloc] init];
    tLabel.translatesAutoresizingMaskIntoConstraints = NO;
    tLabel.text = title;
    tLabel.font = [Styling fontMedium:9.5];
    tLabel.textColor = [UIColor ppTextSecondary];
    tLabel.textAlignment = NSTextAlignmentCenter;
    tLabel.numberOfLines = 1;
    [card addSubview:tLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:6],
        [iconView.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:14],
        [iconView.heightAnchor constraintEqualToConstant:14],

        [label.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:3],
        [label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:2],
        [label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-2],

        [tLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:2],
        [tLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:2],
        [tLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-2],
    ]];

    return card;
}

- (void)openFilterSheet {
    if (!self.activeCriteria) {
        self.activeCriteria = [PPProviderMarketFilterCriteria criteriaFromLegacyFilter:self.activeFilter sort:self.activeSort];
    }
    PPProviderMarketFilterSheet *sheet = [[PPProviderMarketFilterSheet alloc] initWithCriteria:self.activeCriteria items:self.items];
    __weak typeof(self) ws = self;
    sheet.onApplyCriteria = ^(PPProviderMarketFilterCriteria *criteria) {
        ws.activeCriteria = criteria;
        ws.activeFilter = criteria.primaryLegacyFilter;
        ws.activeSort = criteria.sort;
        [ws updateUI];
    };
    sheet.onApplyLegacy = ^(PPProviderMarketFilter filter, PPProviderMarketSort sort) {
        ws.activeFilter = filter;
        ws.activeSort = sort;
        [ws updateUI];
    };

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
        sheet.preferredContentSize = CGSizeMake(680.0, 720.0);
    } else {
        if (@available(iOS 15.0, *)) {
            sheet.modalPresentationStyle = UIModalPresentationPageSheet;
            UISheetPresentationController *pres = sheet.sheetPresentationController;
            pres.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            pres.prefersGrabberVisible = YES;
            pres.preferredCornerRadius = 24.0;
        } else {
            sheet.modalPresentationStyle = UIModalPresentationFormSheet;
        }
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)filterAllTapped {
    [self.activeCriteria reset];
    self.activeFilter = PPProviderMarketFilterAll;
    self.activeSort = PPProviderMarketSortNewest;
    [self updateUI];
}

- (void)filterOffersTapped {
    [self.activeCriteria reset];
    self.activeCriteria.offerFilter = PPProviderMarketOfferFilterOffersOnly;
    self.activeFilter = PPProviderMarketFilterOffers;
    [self updateUI];
}

- (void)filterLowStockTapped {
    [self.activeCriteria reset];
    self.activeCriteria.stockFilter = PPProviderMarketStockFilterLowStock;
    self.activeFilter = PPProviderMarketFilterLowStock;
    [self updateUI];
}

// MARK: - Empty State

- (void)buildEmptyState {
    self.emptyView = [[UIView alloc] init];
    self.emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyView.hidden = YES;
    [self.view addSubview:self.emptyView];

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill"]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.35];
    emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.emptyView addSubview:emptyIcon];

    UILabel *emptyTitle = [[UILabel alloc] init];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.text = kLang(@"Market_EmptyTitle");
    emptyTitle.font = [Styling fontBold:18.0];
    emptyTitle.textColor = [UIColor ppTextPrimary];
    emptyTitle.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:emptyTitle];

    UILabel *emptySub = [[UILabel alloc] init];
    emptySub.translatesAutoresizingMaskIntoConstraints = NO;
    emptySub.text = kLang(@"Market_EmptySubtitle");
    emptySub.font = [Styling fontRegular:13.5];
    emptySub.textColor = [UIColor ppTextSecondary];
    emptySub.textAlignment = NSTextAlignmentCenter;
    emptySub.numberOfLines = 2;
    [self.emptyView addSubview:emptySub];

    UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    createBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [createBtn setTitle:[NSString stringWithFormat:@" +  %@", kLang(@"Market_AddTitle")] forState:UIControlStateNormal];
    createBtn.titleLabel.font = [Styling fontBold:15.0];
    createBtn.tintColor = UIColor.whiteColor;
    createBtn.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(createBtn, 22);
    PPApplyButtonShadow(createBtn);
    [createBtn addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyView addSubview:createBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:60],
        [self.emptyView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceXL],
        [self.emptyView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceXL],

        [emptyIcon.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [emptyIcon.topAnchor constraintEqualToAnchor:self.emptyView.topAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:64],
        [emptyIcon.heightAnchor constraintEqualToConstant:64],

        [emptyTitle.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:14],
        [emptyTitle.leadingAnchor constraintEqualToAnchor:self.emptyView.leadingAnchor],
        [emptyTitle.trailingAnchor constraintEqualToAnchor:self.emptyView.trailingAnchor],

        [emptySub.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:6],
        [emptySub.leadingAnchor constraintEqualToAnchor:self.emptyView.leadingAnchor],
        [emptySub.trailingAnchor constraintEqualToAnchor:self.emptyView.trailingAnchor],

        [createBtn.topAnchor constraintEqualToAnchor:emptySub.bottomAnchor constant:18],
        [createBtn.centerXAnchor constraintEqualToAnchor:self.emptyView.centerXAnchor],
        [createBtn.widthAnchor constraintEqualToConstant:190],
        [createBtn.heightAnchor constraintEqualToConstant:46],
        [createBtn.bottomAnchor constraintEqualToAnchor:self.emptyView.bottomAnchor],
    ]];
}

// MARK: - Data Synchronization

- (void)startListening {
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid) {
        self.hasLoaded = YES;
        [self updateUI];
        return;
    }
    [self.spinner startAnimating];
    __weak typeof(self) ws = self;
    self.listener = [[PPProviderMarketplaceManager sharedManager] observeMarketItemsForOwnerID:uid onChange:^(NSArray<PPProviderMarketItem *> *items, NSError *error) {
        __strong typeof(ws) self = ws;
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        self.hasLoaded = YES;
        if (error) {
            [PPToast toast:kLang(@"Market_LoadError") style:PPToastStyleError haptic:NO duration:3.0];
            return;
        }
        self.items = items ?: @[];
        [self updateUI];
    }];
}

- (void)handleRefresh {
    // Re-trigger listener fetch
    [self startListening];
}

// MARK: - Filtering & Sorting Logic

- (void)updateUI {
    [self applyFilterAndSearch];
    [self updateTelemetryHUD];

    BOOL hasItems = self.filteredItems.count > 0;
    self.emptyView.hidden = hasItems || !self.hasLoaded;
    self.tableView.hidden = !hasItems && self.hasLoaded && self.items.count == 0;

    self.searchResultsCountLabel.text = [NSString stringWithFormat:@"%ld", (long)self.displayGroups.count];
    self.clearSearchButton.hidden = (self.searchQuery.length == 0);

    // Update Filter Button Visual Active Indicator
    BOOL hasActiveFilter = (self.activeCriteria ? ![self.activeCriteria isDefault] : (self.activeFilter != PPProviderMarketFilterAll || self.activeSort != PPProviderMarketSortNewest));
    if (hasActiveFilter) {
        self.filterButton.tintColor = [UIColor ppPrimary];
        self.filterButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.14];
        self.filterButton.layer.borderColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.45].CGColor;
        self.filterBadgeDot.hidden = NO;
    } else {
        self.filterButton.tintColor = [UIColor ppTextSecondary];
        self.filterButton.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
        self.filterButton.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
        self.filterBadgeDot.hidden = YES;
    }

    [self.tableView reloadData];
}

- (void)updateTelemetryHUD {
    // Calculate Telemetry
    NSInteger total = self.items.count;
    double valuation = 0.0;
    NSInteger offers = 0;
    NSInteger alerts = 0;

    for (PPProviderMarketItem *it in self.items) {
        double p = it.finalPrice > 0 ? it.finalPrice : it.price;
        valuation += (it.quantity * p);
        if (it.hasOffer) offers++;
        if (it.quantity <= 5 || it.noStock) alerts++;
    }

    self.totalSKUsBadge.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.totalValuationBadge.text = [NSString stringWithFormat:@"%.0f QAR", valuation];
    self.activeOffersBadge.text = [NSString stringWithFormat:@"%ld", (long)offers];
    self.stockAlertBadge.text = [NSString stringWithFormat:@"%ld", (long)alerts];
}

- (void)applyFilterAndSearch {
    NSMutableArray<PPProviderMarketItem *> *result = [NSMutableArray array];
    NSString *query = [self.searchQuery stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;

    for (PPProviderMarketItem *item in self.items) {
        // 1. Filter Pass
        BOOL passesFilter = YES;
        if (self.activeCriteria) {
            passesFilter = [self.activeCriteria evaluatesItem:item];
        } else {
            switch (self.activeFilter) {
                case PPProviderMarketFilterAll:
                    passesFilter = YES;
                    break;
                case PPProviderMarketFilterInStock:
                    passesFilter = (!item.noStock && item.quantity > 5);
                    break;
                case PPProviderMarketFilterLowStock:
                    passesFilter = (item.quantity <= 5 || item.noStock);
                    break;
                case PPProviderMarketFilterOffers:
                    passesFilter = item.hasOffer;
                    break;
                case PPProviderMarketFilterHidden:
                    passesFilter = (!item.showInAppMarket || item.isArchived);
                    break;
                case PPProviderMarketFilterAccessories:
                    passesFilter = (item.accessKindType == 1);
                    break;
                case PPProviderMarketFilterFood:
                    passesFilter = (item.accessKindType == 2 || item.accessKindType == 0);
                    break;
            }
        }
        if (!passesFilter) continue;

        // 2. Search Pass
        if (query.length > 0) {
            NSMutableString *corpus = [NSMutableString string];
            if (item.name) [corpus appendFormat:@"%@ ", item.name.lowercaseString];
            if (item.nameEn) [corpus appendFormat:@"%@ ", item.nameEn.lowercaseString];
            if (item.desc) [corpus appendFormat:@"%@ ", item.desc.lowercaseString];
            if (item.descEn) [corpus appendFormat:@"%@ ", item.descEn.lowercaseString];
            if (item.itemID) [corpus appendFormat:@"%@ ", item.itemID.lowercaseString];
            if (item.petMainCategoryName) [corpus appendFormat:@"%@ ", item.petMainCategoryName.lowercaseString];
            if (item.sku) [corpus appendFormat:@"%@ ", item.sku.lowercaseString];
            if (item.barcode) [corpus appendFormat:@"%@ ", item.barcode.lowercaseString];
            if (item.pos_smartVariantDescription) [corpus appendFormat:@"%@ ", item.pos_smartVariantDescription.lowercaseString];
            if (item.pos_variantOptionLabel) [corpus appendFormat:@"%@ ",
                                              item.pos_variantOptionLabel.lowercaseString];

            if ([corpus rangeOfString:query].location == NSNotFound) {
                continue;
            }
        }

        [result addObject:item];
    }

    // 3. Sort Pass
    PPProviderMarketSort currentSort = self.activeCriteria ? self.activeCriteria.sort : self.activeSort;
    [result sortUsingComparator:^NSComparisonResult(PPProviderMarketItem *a, PPProviderMarketItem *b) {
        switch (currentSort) {
            case PPProviderMarketSortNewest:
                return [b.createdAt compare:a.createdAt ?: [NSDate distantPast]];
            case PPProviderMarketSortPriceLowToHigh: {
                double pa = a.finalPrice > 0 ? a.finalPrice : a.price;
                double pb = b.finalPrice > 0 ? b.finalPrice : b.price;
                return pa < pb ? NSOrderedAscending : (pa > pb ? NSOrderedDescending : NSOrderedSame);
            }
            case PPProviderMarketSortPriceHighToLow: {
                double pa = a.finalPrice > 0 ? a.finalPrice : a.price;
                double pb = b.finalPrice > 0 ? b.finalPrice : b.price;
                return pa > pb ? NSOrderedAscending : (pa < pb ? NSOrderedDescending : NSOrderedSame);
            }
            case PPProviderMarketSortStockHighest:
                return a.quantity > b.quantity ? NSOrderedAscending : (a.quantity < b.quantity ? NSOrderedDescending : NSOrderedSame);
            case PPProviderMarketSortStockLowest:
                return a.quantity < b.quantity ? NSOrderedAscending : (a.quantity > b.quantity ? NSOrderedDescending : NSOrderedSame);
        }
    }];

    self.filteredItems = result.copy;
    self.displayGroups = [PPProviderMarketDisplayGroup groupedItems:result];
}

// MARK: - Search Actions

- (void)searchTextChanged:(UITextField *)sender {
    self.searchQuery = sender.text ?: @"";
    [self updateUI];
}

- (void)clearSearchTapped {
    self.omniSearchField.text = @"";
    self.searchQuery = @"";
    [self updateUI];
    [self.omniSearchField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// MARK: - Navigation Actions

- (void)onBack {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController || self.navigationController.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)addTapped {
    PPProviderMarketItemEditorViewController *vc = [[PPProviderMarketItemEditorViewController alloc] initForCreate];
    __weak typeof(self) ws = self;
    vc.onSave = ^{ [ws updateUI]; };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openBranchesTapped {
    PPMarketplaceBranchesViewController *vc = [[PPMarketplaceBranchesViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openEditorForItem:(PPProviderMarketItem *)item {
    if (!item) return;
    PPProviderMarketItemEditorViewController *vc = [[PPProviderMarketItemEditorViewController alloc] initWithItem:item];
    __weak typeof(self) ws = self;
    vc.onSave = ^{ [ws updateUI]; };
    [self.navigationController pushViewController:vc animated:YES];
}

// MARK: - Studio Quick Sheets Presentation

- (void)presentQuickStockSheetForItem:(PPProviderMarketItem *)item {
    PPProviderQuickStockSheet *sheet = [[PPProviderQuickStockSheet alloc] initWithItem:item];
    __weak typeof(self) ws = self;
    sheet.onUpdated = ^{ [ws updateUI]; };

    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[
            [UISheetPresentationControllerDetent mediumDetent]
        ];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentQuickOfferSheetForItem:(PPProviderMarketItem *)item {
    PPProviderQuickOfferSheet *sheet = [[PPProviderQuickOfferSheet alloc] initWithItem:item];
    __weak typeof(self) ws = self;
    sheet.onUpdated = ^{ [ws updateUI]; };

    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentDetailInspectorForItem:(PPProviderMarketItem *)item {
    PPProviderMarketItemDetailSheet *sheet = [[PPProviderMarketItemDetailSheet alloc] initWithItem:item];
    __weak typeof(self) ws = self;
    sheet.onEditRequested = ^(PPProviderMarketItem *it) {
        [ws openEditorForItem:it];
    };
    sheet.onStockRequested = ^(PPProviderMarketItem *it) {
        [ws presentQuickStockSheetForItem:it];
    };
    sheet.onOfferRequested = ^(PPProviderMarketItem *it) {
        [ws presentQuickOfferSheetForItem:it];
    };

    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleVisibilityForItem:(PPProviderMarketItem *)item {
    BOOL isVisible = item.showInAppMarket && !item.isArchived;
    if (isVisible) {
        __weak typeof(self) ws = self;
        [PPAlertHelper showConfirmationIn:self title:kLang(@"Market_HideFromMarket") subtitle:kLang(@"Market_HideConfirm") placeholder:nil
                           confirmButton:kLang(@"Confirm") cancelButton:kLang(@"Cancel") confirmBlock:^{
            [PPHUD showIndeterminateIn:ws.view title:kLang(@"Market_UpdatingVisibility") subtitle:nil];
            [[PPProviderMarketplaceManager sharedManager] archiveMarketItemWithID:item.itemID completion:^(BOOL ok, NSString *msg, NSError *err) {
                [PPHUD dismiss];
                if (!ok) { [PPAlertHelper showErrorIn:ws title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
                [PPHUD showSuccess:kLang(@"Market_ItemHidden")];
                [ws updateUI];
            }];
        } cancelBlock:nil];
    } else {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Market_UpdatingVisibility") subtitle:nil];
        __weak typeof(self) ws = self;
        [[PPProviderMarketplaceManager sharedManager] publishMarketItemWithID:item.itemID completion:^(BOOL ok, NSString *msg, NSError *err) {
            [PPHUD dismiss];
            if (!ok) { [PPAlertHelper showErrorIn:ws title:kLang(@"Error") subtitle:msg ?: err.localizedDescription]; return; }
            [PPHUD showSuccess:kLang(@"Market_ItemShown")];
            [ws updateUI];
        }];
    }
}

// MARK: - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.displayGroups.count) {
        return [[UITableViewCell alloc] init];
    }
    PPProviderMarketDisplayGroup *group = self.displayGroups[indexPath.row];
    __weak typeof(self) ws = self;

    if (group.isFamily) {
        PPProviderMarketFamilyCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderMarketFamilyCardCell" forIndexPath:indexPath];
        [cell configureWithGroup:group];
        cell.onExpandTapped = ^{
            group.isExpanded = !group.isExpanded;
            [tableView beginUpdates];
            [cell updateExpandedState];
            [tableView endUpdates];
        };
        cell.onStudioTapped = ^{
            [ws openVariantStudioForItem:group.defaultMember];
        };
        cell.onMemberSelected = ^(PPProviderMarketItem *item) {
            [ws presentDetailInspectorForItem:item];
        };
        cell.onMemberStockTapped = ^(PPProviderMarketItem *item) {
            [ws presentQuickStockSheetForItem:item];
        };
        cell.onMemberOfferTapped = ^(PPProviderMarketItem *item) {
            [ws presentQuickOfferSheetForItem:item];
        };
        return cell;
    } else {
        PPProviderMarketItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderMarketItemCardCell" forIndexPath:indexPath];
        PPProviderMarketItem *item = group.singleItem ?: group.defaultMember;
        [cell configureWithItem:item];

        cell.onCardTapped = ^{
            [ws presentDetailInspectorForItem:item];
        };
        cell.onStockTapped = ^{
            [ws presentQuickStockSheetForItem:item];
        };
        cell.onOfferTapped = ^{
            [ws presentQuickOfferSheetForItem:item];
        };
        cell.onVisibilityTapped = ^{
            [ws toggleVisibilityForItem:item];
        };
        cell.onMoreTapped = ^{
            [ws presentDetailInspectorForItem:item];
        };

        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.displayGroups.count) return;
    PPProviderMarketDisplayGroup *group = self.displayGroups[indexPath.row];
    if (group.isFamily) {
        group.isExpanded = !group.isExpanded;
        PPProviderMarketFamilyCardCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell && [cell isKindOfClass:[PPProviderMarketFamilyCardCell class]]) {
            [tableView beginUpdates];
            [cell updateExpandedState];
            [tableView endUpdates];
        }
    } else {
        PPProviderMarketItem *item = group.singleItem ?: group.defaultMember;
        [self presentDetailInspectorForItem:item];
    }
}

- (void)openVariantStudioForItem:(PPProviderMarketItem *)item {
    if (!item) return;
    PPAccessoryVariantStudioHostController *host = [[PPAccessoryVariantStudioHostController alloc] initWithMarketItem:item];
    __weak typeof(self) ws = self;
    host.onSaved = ^(PetAccessory *acc) {
        [ws updateUI];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:host];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dealloc {
    [self.listener remove];
}

@end
