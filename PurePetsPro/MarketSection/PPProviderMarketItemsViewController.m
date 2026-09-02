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

// MARK: - Filter & Sort Enums

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

// MARK: - Category-Defining Market Filter & Sort Sheet

@interface PPProviderMarketFilterSheet : UIViewController
@property (nonatomic, assign) PPProviderMarketFilter selectedFilter;
@property (nonatomic, assign) PPProviderMarketSort selectedSort;
@property (nonatomic, copy) NSArray<PPProviderMarketItem *> *items;
@property (nonatomic, copy) void (^onApply)(PPProviderMarketFilter filter, PPProviderMarketSort sort);

@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *applyButton;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterPillButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *sortPillButtons;

- (instancetype)initWithFilter:(PPProviderMarketFilter)filter
                          sort:(PPProviderMarketSort)sort
                         items:(NSArray<PPProviderMarketItem *> *)items;
@end

@implementation PPProviderMarketFilterSheet

- (instancetype)initWithFilter:(PPProviderMarketFilter)filter
                          sort:(PPProviderMarketSort)sort
                         items:(NSArray<PPProviderMarketItem *> *)items {
    self = [super init];
    if (self) {
        _selectedFilter = filter;
        _selectedSort = sort;
        _items = items ?: @[];
        _filterPillButtons = [NSMutableArray array];
        _sortPillButtons = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupSheetUI];
    [self updateButtonsState];
}

- (void)setupSheetUI {
    // 1. Drag Handle
    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:0.35];
    handle.layer.cornerRadius = 2.5;
    [self.view addSubview:handle];

    // 2. Header Bar
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"Market_FilterSheet_Title");
    titleLabel.font = [Styling fontBold:17.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:titleLabel];

    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resetButton setTitle:kLang(@"Market_FilterSheet_Reset") forState:UIControlStateNormal];
    self.resetButton.titleLabel.font = [Styling fontBold:13.5];
    self.resetButton.tintColor = [UIColor ppPrimary];
    [self.resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.resetButton];

    UIView *headerDivider = [[UIView alloc] init];
    headerDivider.translatesAutoresizingMaskIntoConstraints = NO;
    headerDivider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [self.view addSubview:headerDivider];

    // 3. Scroll Content
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:scrollView];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 18.0;
    contentStack.alignment = UIStackViewAlignmentFill;
    [scrollView addSubview:contentStack];

    // Section 1: Stock Status
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Market_FilterSheet_SectionStock")]];
    [contentStack addArrangedSubview:[self buildFilterRowWithDefs:@[
        @{@"filter": @(PPProviderMarketFilterAll), @"title": kLang(@"Market_FilterSheet_All")},
        @{@"filter": @(PPProviderMarketFilterInStock), @"title": kLang(@"Market_FilterSheet_InStockOnly")},
        @{@"filter": @(PPProviderMarketFilterLowStock), @"title": kLang(@"Market_FilterSheet_LowStockOnly")}
    ]]];

    // Section 2: Special Offers
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Market_FilterSheet_SectionOffers")]];
    [contentStack addArrangedSubview:[self buildFilterRowWithDefs:@[
        @{@"filter": @(PPProviderMarketFilterAll), @"title": kLang(@"Market_FilterSheet_All")},
        @{@"filter": @(PPProviderMarketFilterOffers), @"title": kLang(@"Market_FilterSheet_OffersOnly")}
    ]]];

    // Section 3: Visibility
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Market_FilterSheet_SectionVisibility")]];
    [contentStack addArrangedSubview:[self buildFilterRowWithDefs:@[
        @{@"filter": @(PPProviderMarketFilterAll), @"title": kLang(@"Market_FilterSheet_All")},
        @{@"filter": @(PPProviderMarketFilterHidden), @"title": kLang(@"Market_FilterSheet_HiddenOnly")}
    ]]];

    // Section 4: Kind
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Market_FilterSheet_SectionKind")]];
    [contentStack addArrangedSubview:[self buildFilterRowWithDefs:@[
        @{@"filter": @(PPProviderMarketFilterAll), @"title": kLang(@"Market_FilterSheet_All")},
        @{@"filter": @(PPProviderMarketFilterAccessories), @"title": kLang(@"Market_Accessory")},
        @{@"filter": @(PPProviderMarketFilterFood), @"title": kLang(@"Market_Food")}
    ]]];

    // Section 5: Sort
    [contentStack addArrangedSubview:[self buildSectionHeader:kLang(@"Market_FilterSheet_SectionSort")]];
    [contentStack addArrangedSubview:[self buildSortRowWithDefs:@[
        @{@"sort": @(PPProviderMarketSortNewest), @"title": kLang(@"Market_FilterSheet_SortNewest")},
        @{@"sort": @(PPProviderMarketSortPriceLowToHigh), @"title": kLang(@"Market_FilterSheet_SortPriceLow")},
        @{@"sort": @(PPProviderMarketSortPriceHighToLow), @"title": kLang(@"Market_FilterSheet_SortPriceHigh")},
        @{@"sort": @(PPProviderMarketSortStockHighest), @"title": kLang(@"Market_FilterSheet_SortStockHigh")},
        @{@"sort": @(PPProviderMarketSortStockLowest), @"title": kLang(@"Market_FilterSheet_SortStockLow")}
    ]]];

    // 4. Floating Apply CTA
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applyButton.titleLabel.font = [Styling fontBold:16.0];
    self.applyButton.tintColor = UIColor.whiteColor;
    self.applyButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(self.applyButton, 22);
    PPApplyButtonShadow(self.applyButton);
    [self.applyButton addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.applyButton];

    // Layout
    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [handle.widthAnchor constraintEqualToConstant:40],
        [handle.heightAnchor constraintEqualToConstant:5],

        [titleLabel.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],

        [self.resetButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [self.resetButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],

        [headerDivider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [headerDivider.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [headerDivider.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [headerDivider.heightAnchor constraintEqualToConstant:0.8],

        [scrollView.topAnchor constraintEqualToAnchor:headerDivider.bottomAnchor constant:12],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.applyButton.topAnchor constant:-12],

        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

        [self.applyButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.applyButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.applyButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [self.applyButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (UIView *)buildSectionHeader:(NSString *)title {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = title;
    lbl.font = [Styling fontBold:13.5];
    lbl.textColor = [UIColor ppTextSecondary];
    lbl.textAlignment = Language.alignmentForCurrentLanguage;
    return lbl;
}

- (UIView *)buildFilterRowWithDefs:(NSArray<NSDictionary *> *)defs {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:36],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSDictionary *def in defs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:def[@"title"] forState:UIControlStateNormal];
        btn.tag = [def[@"filter"] integerValue];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        PPApplyContinuousCorners(btn, 16);
        [btn addTarget:self action:@selector(filterPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [self.filterPillButtons addObject:btn];
        [stack addArrangedSubview:btn];
    }
    return scroll;
}

- (UIView *)buildSortRowWithDefs:(NSArray<NSDictionary *> *)defs {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    stack.alignment = UIStackViewAlignmentCenter;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:36],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scroll.heightAnchor],
    ]];

    for (NSDictionary *def in defs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:def[@"title"] forState:UIControlStateNormal];
        btn.tag = [def[@"sort"] integerValue];
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        PPApplyContinuousCorners(btn, 16);
        [btn addTarget:self action:@selector(sortPillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn.heightAnchor constraintEqualToConstant:34].active = YES;
        [self.sortPillButtons addObject:btn];
        [stack addArrangedSubview:btn];
    }
    return scroll;
}

- (void)filterPillTapped:(UIButton *)sender {
    self.selectedFilter = sender.tag;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateButtonsState];
}

- (void)sortPillTapped:(UIButton *)sender {
    self.selectedSort = sender.tag;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
    [self updateButtonsState];
}

- (void)resetTapped {
    self.selectedFilter = PPProviderMarketFilterAll;
    self.selectedSort = PPProviderMarketSortNewest;
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeWarning];
    [self updateButtonsState];
}

- (NSInteger)calculatedMatchCount {
    NSInteger count = 0;
    for (PPProviderMarketItem *item in self.items) {
        BOOL match = YES;
        switch (self.selectedFilter) {
            case PPProviderMarketFilterAll: match = YES; break;
            case PPProviderMarketFilterInStock: match = (!item.noStock && item.quantity > 5); break;
            case PPProviderMarketFilterLowStock: match = (item.quantity <= 5 || item.noStock); break;
            case PPProviderMarketFilterOffers: match = item.hasOffer; break;
            case PPProviderMarketFilterHidden: match = (!item.showInAppMarket || item.isArchived); break;
            case PPProviderMarketFilterAccessories: match = (item.accessKindType == 1); break;
            case PPProviderMarketFilterFood: match = (item.accessKindType == 0); break;
        }
        if (match) count++;
    }
    return count;
}

- (void)updateButtonsState {
    for (UIButton *btn in self.filterPillButtons) {
        BOOL isSel = (btn.tag == self.selectedFilter);
        btn.titleLabel.font = isSel ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
        if (isSel) {
            btn.tintColor = UIColor.whiteColor;
            btn.backgroundColor = [UIColor ppPrimary];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.tintColor = [UIColor ppTextPrimary];
            btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
            btn.layer.borderWidth = 0.7;
            btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }

    for (UIButton *btn in self.sortPillButtons) {
        BOOL isSel = (btn.tag == self.selectedSort);
        btn.titleLabel.font = isSel ? [Styling fontBold:13.0] : [Styling fontMedium:12.5];
        if (isSel) {
            btn.tintColor = UIColor.whiteColor;
            btn.backgroundColor = [UIColor ppPrimary];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.tintColor = [UIColor ppTextPrimary];
            btn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.7];
            btn.layer.borderWidth = 0.7;
            btn.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }

    NSInteger matchCount = [self calculatedMatchCount];
    NSString *btnTitle = [NSString stringWithFormat:kLang(@"Market_FilterSheet_ApplyFormat"), (long)matchCount];
    [self.applyButton setTitle:btnTitle forState:UIControlStateNormal];

    BOOL isDefault = (self.selectedFilter == PPProviderMarketFilterAll && self.selectedSort == PPProviderMarketSortNewest);
    self.resetButton.alpha = isDefault ? 0.4 : 1.0;
    self.resetButton.userInteractionEnabled = !isDefault;
}

- (void)applyTapped {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
    if (self.onApply) {
        self.onApply(self.selectedFilter, self.selectedSort);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
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
@property (nonatomic, copy) NSString *searchQuery;
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
    self.searchQuery = @"";
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
    PPProviderMarketFilterSheet *sheet = [[PPProviderMarketFilterSheet alloc] initWithFilter:self.activeFilter sort:self.activeSort items:self.items];
    __weak typeof(self) ws = self;
    sheet.onApply = ^(PPProviderMarketFilter filter, PPProviderMarketSort sort) {
        ws.activeFilter = filter;
        ws.activeSort = sort;
        [ws updateUI];
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

- (void)filterAllTapped {
    self.activeFilter = PPProviderMarketFilterAll;
    [self updateUI];
}

- (void)filterOffersTapped {
    self.activeFilter = PPProviderMarketFilterOffers;
    [self updateUI];
}

- (void)filterLowStockTapped {
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

    self.searchResultsCountLabel.text = [NSString stringWithFormat:@"%ld", (long)self.filteredItems.count];
    self.clearSearchButton.hidden = (self.searchQuery.length == 0);

    // Update Filter Button Visual Active Indicator
    BOOL hasActiveFilter = (self.activeFilter != PPProviderMarketFilterAll || self.activeSort != PPProviderMarketSortNewest);
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
                passesFilter = (item.accessKindType == 0);
                break;
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

            if ([corpus rangeOfString:query].location == NSNotFound) {
                continue;
            }
        }

        [result addObject:item];
    }

    // 3. Sort Pass
    [result sortUsingComparator:^NSComparisonResult(PPProviderMarketItem *a, PPProviderMarketItem *b) {
        switch (self.activeSort) {
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
    return self.filteredItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPProviderMarketItemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderMarketItemCardCell" forIndexPath:indexPath];
    PPProviderMarketItem *item = self.filteredItems[indexPath.row];
    [cell configureWithItem:item];

    __weak typeof(self) ws = self;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPProviderMarketItem *item = self.filteredItems[indexPath.row];
    [self presentDetailInspectorForItem:item];
}

- (void)dealloc {
    [self.listener remove];
}

@end
