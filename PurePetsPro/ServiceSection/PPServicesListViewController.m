//
//  PPServicesListViewController.m
//  PurePetsPro
//
//  Created from absolute first principles. Category-defining flagship
//  service command center with Cockpit KPIs, dynamic category rail,
//  omni-search, interactive service cards, and quick pricing sheet.
//

#import "PPServicesListViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPAddEditServiceViewController.h"
#import "PPServiceDetailViewController.h"
#import "PPServiceSubscriptionViewController.h"
#import "PPFirebaseCompat.h"
#import "PPRolePermission.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "UIImageView+WebCache.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "PPFunc.h"
#import "PPAlertHelper.h"

#pragma mark - PPServiceQuickPricingSheet Interface & Implementation

@interface PPServiceQuickPricingSheet () <UITextFieldDelegate>
@property (nonatomic, strong) PPServiceModel *service;
@property (nonatomic, copy, nullable) void(^onUpdated)(void);
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *counterDisplay;
@property (nonatomic, strong) UITextField *directInputField;
@property (nonatomic, strong) UISwitch *availabilitySwitch;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, assign) double currentPrice;
@end

@implementation PPServiceQuickPricingSheet

- (instancetype)initWithService:(PPServiceModel *)service onUpdated:(nullable void(^)(void))onUpdated {
    self = [super init];
    if (self) {
        _service = [service copy];
        _onUpdated = [onUpdated copy];
        _currentPrice = MAX(0.0, _service.price);
        if (@available(iOS 15.0, *)) {
            self.modalPresentationStyle = UIModalPresentationPageSheet;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppSurfaceElevated];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 28.0;
        }
    }
    [self setupUI];
    [self updatePriceDisplay];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    
    // 1. Header Card (Thumbnail + Title + Category)
    UIView *headerCard = [[UIView alloc] init];
    headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    headerCard.backgroundColor = [UIColor ppSurface];
    headerCard.layer.borderWidth = 1.0;
    headerCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(headerCard, PPCornerMedium);
    [content addSubview:headerCard];
    
    _thumbnailView = [[UIImageView alloc] init];
    _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailView.clipsToBounds = YES;
    _thumbnailView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(_thumbnailView, 16.0);
    if (self.service.imageURL.length > 0) {
        [_thumbnailView sd_setImageWithURL:[NSURL URLWithString:self.service.imageURL]
                          placeholderImage:[UIImage systemImageNamed:@"sparkles"]];
    } else {
        _thumbnailView.image = [UIImage systemImageNamed:@"sparkles"];
        _thumbnailView.tintColor = [UIColor ppPrimary];
    }
    [headerCard addSubview:_thumbnailView];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = self.service.title ?: @"";
    _titleLabel.font = [Styling fontBold:16.0];
    _titleLabel.textColor = [UIColor ppTextPrimary];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:_titleLabel];
    
    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.text = self.service.category.length > 0 ? self.service.category : ([Language isRTL] ? @"خدمة مخصصة" : @"Custom Service");
    _categoryLabel.font = [Styling fontMedium:12.5];
    _categoryLabel.textColor = [UIColor ppPrimary];
    _categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:_categoryLabel];
    
    // 2. Big Price Display Chamber
    UIView *priceChamber = [[UIView alloc] init];
    priceChamber.translatesAutoresizingMaskIntoConstraints = NO;
    priceChamber.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(priceChamber, PPCornerCard);
    [content addSubview:priceChamber];
    
    UILabel *chamberTitle = [[UILabel alloc] init];
    chamberTitle.translatesAutoresizingMaskIntoConstraints = NO;
    chamberTitle.text = [Language isRTL] ? @"سعر الخدمة الحالي" : @"Current Service Rate";
    chamberTitle.font = [Styling fontMedium:12.5];
    chamberTitle.textColor = [UIColor ppTextSecondary];
    chamberTitle.textAlignment = NSTextAlignmentCenter;
    [priceChamber addSubview:chamberTitle];
    
    _counterDisplay = [[UILabel alloc] init];
    _counterDisplay.translatesAutoresizingMaskIntoConstraints = NO;
    _counterDisplay.font = [Styling fontBold:38.0];
    _counterDisplay.textColor = [UIColor ppPrimary];
    _counterDisplay.textAlignment = NSTextAlignmentCenter;
    _counterDisplay.text = @"0.00 QAR";
    [priceChamber addSubview:_counterDisplay];
    
    // 3. Quick Stepper Buttons (+10, +25, +50, +100 / -10, -25, -50)
    UIStackView *stepperRow1 = [[UIStackView alloc] init];
    stepperRow1.translatesAutoresizingMaskIntoConstraints = NO;
    stepperRow1.axis = UILayoutConstraintAxisHorizontal;
    stepperRow1.distribution = UIStackViewDistributionFillEqually;
    stepperRow1.spacing = 8;
    [content addSubview:stepperRow1];
    
    NSArray *positives = @[@(10), @(25), @(50), @(100)];
    for (NSNumber *n in positives) {
        UIButton *btn = [self makeDeltaButtonWithTitle:[NSString stringWithFormat:@"+%ld", (long)n.integerValue] delta:n.doubleValue isPositive:YES];
        [stepperRow1 addArrangedSubview:btn];
    }
    
    UIStackView *stepperRow2 = [[UIStackView alloc] init];
    stepperRow2.translatesAutoresizingMaskIntoConstraints = NO;
    stepperRow2.axis = UILayoutConstraintAxisHorizontal;
    stepperRow2.distribution = UIStackViewDistributionFillEqually;
    stepperRow2.spacing = 8;
    [content addSubview:stepperRow2];
    
    NSArray *negatives = @[@(-10), @(-25), @(-50)];
    for (NSNumber *n in negatives) {
        UIButton *btn = [self makeDeltaButtonWithTitle:[NSString stringWithFormat:@"%ld", (long)n.integerValue] delta:n.doubleValue isPositive:NO];
        [stepperRow2 addArrangedSubview:btn];
    }
    
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.titleLabel.font = [Styling fontBold:14.0];
    [resetBtn setTitle:[Language isRTL] ? @"إلغاء السعر" : @"Clear" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
    resetBtn.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(resetBtn, PPCornerMedium);
    [resetBtn addTarget:self action:@selector(zeroTapped) forControlEvents:UIControlEventTouchUpInside];
    [stepperRow2 addArrangedSubview:resetBtn];
    
    // 4. Direct Manual Numeric Input
    _directInputField = [[UITextField alloc] init];
    _directInputField.translatesAutoresizingMaskIntoConstraints = NO;
    _directInputField.backgroundColor = [UIColor ppSurface];
    _directInputField.layer.borderWidth = 1.0;
    _directInputField.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _directInputField.placeholder = [Language isRTL] ? @"أو اكتب السعر مباشرة بالريال القطري..." : @"Or enter exact price in QAR...";
    _directInputField.font = [Styling fontMedium:15.0];
    _directInputField.textColor = [UIColor ppTextPrimary];
    _directInputField.keyboardType = UIKeyboardTypeDecimalPad;
    _directInputField.textAlignment = Language.alignmentForCurrentLanguage;
    PPApplyContinuousCorners(_directInputField, PPCornerMedium);
    _directInputField.delegate = self;
    [_directInputField addTarget:self action:@selector(directInputChanged) forControlEvents:UIControlEventEditingChanged];
    
    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _directInputField.leftView = leftPad;
    _directInputField.leftViewMode = UITextFieldViewModeAlways;
    [content addSubview:_directInputField];
    
    // 5. Customer Availability Switch Row
    UIView *switchRow = [[UIView alloc] init];
    switchRow.translatesAutoresizingMaskIntoConstraints = NO;
    switchRow.backgroundColor = [UIColor ppSurface];
    switchRow.layer.borderWidth = 1.0;
    switchRow.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(switchRow, PPCornerMedium);
    [content addSubview:switchRow];
    
    UILabel *switchTitle = [[UILabel alloc] init];
    switchTitle.translatesAutoresizingMaskIntoConstraints = NO;
    switchTitle.text = [Language isRTL] ? @"متاح للطلب والحجز المباشر" : @"Available for Direct Booking";
    switchTitle.font = [Styling fontBold:14.5];
    switchTitle.textColor = [UIColor ppTextPrimary];
    switchTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [switchRow addSubview:switchTitle];
    
    UILabel *switchSubtitle = [[UILabel alloc] init];
    switchSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    switchSubtitle.text = [Language isRTL] ? @"ظهور الخدمة في قائمة البحث والكتالوج العام" : @"Display service in public search catalog";
    switchSubtitle.font = [Styling fontRegular:12.0];
    switchSubtitle.textColor = [UIColor ppTextSecondary];
    switchSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    [switchRow addSubview:switchSubtitle];
    
    _availabilitySwitch = [[UISwitch alloc] init];
    _availabilitySwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _availabilitySwitch.onTintColor = [UIColor ppPrimary];
    _availabilitySwitch.on = self.service.isAvailable;
    [switchRow addSubview:_availabilitySwitch];
    
    // 6. Save Button
    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.backgroundColor = [UIColor ppPrimary];
    [_saveButton setTitle:[Language isRTL] ? @"حفظ وتحديث الخدمة فورياً" : @"Save & Update Rate" forState:UIControlStateNormal];
    [_saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(_saveButton, PPCornerMedium);
    PPApplyButtonShadow(_saveButton);
    [_saveButton addTarget:self action:@selector(saveRateTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_saveButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
        
        // Header Card
        [headerCard.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [headerCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [headerCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [headerCard.heightAnchor constraintEqualToConstant:76],
        
        [_thumbnailView.leadingAnchor constraintEqualToAnchor:headerCard.leadingAnchor constant:12],
        [_thumbnailView.centerYAnchor constraintEqualToAnchor:headerCard.centerYAnchor],
        [_thumbnailView.widthAnchor constraintEqualToConstant:52],
        [_thumbnailView.heightAnchor constraintEqualToConstant:52],
        
        [_titleLabel.topAnchor constraintEqualToAnchor:headerCard.topAnchor constant:14],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:headerCard.trailingAnchor constant:-12],
        
        [_categoryLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        
        // Price Chamber
        [priceChamber.topAnchor constraintEqualToAnchor:headerCard.bottomAnchor constant:16],
        [priceChamber.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [priceChamber.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [priceChamber.heightAnchor constraintEqualToConstant:98],
        
        [chamberTitle.topAnchor constraintEqualToAnchor:priceChamber.topAnchor constant:14],
        [chamberTitle.centerXAnchor constraintEqualToAnchor:priceChamber.centerXAnchor],
        
        [_counterDisplay.topAnchor constraintEqualToAnchor:chamberTitle.bottomAnchor constant:4],
        [_counterDisplay.centerXAnchor constraintEqualToAnchor:priceChamber.centerXAnchor],
        
        // Stepper rows
        [stepperRow1.topAnchor constraintEqualToAnchor:priceChamber.bottomAnchor constant:16],
        [stepperRow1.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [stepperRow1.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [stepperRow1.heightAnchor constraintEqualToConstant:44],
        
        [stepperRow2.topAnchor constraintEqualToAnchor:stepperRow1.bottomAnchor constant:8],
        [stepperRow2.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [stepperRow2.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [stepperRow2.heightAnchor constraintEqualToConstant:44],
        
        // Direct Input
        [_directInputField.topAnchor constraintEqualToAnchor:stepperRow2.bottomAnchor constant:14],
        [_directInputField.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_directInputField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_directInputField.heightAnchor constraintEqualToConstant:48],
        
        // Switch Row
        [switchRow.topAnchor constraintEqualToAnchor:_directInputField.bottomAnchor constant:14],
        [switchRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [switchRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [switchRow.heightAnchor constraintEqualToConstant:68],
        
        [switchTitle.topAnchor constraintEqualToAnchor:switchRow.topAnchor constant:14],
        [switchTitle.leadingAnchor constraintEqualToAnchor:switchRow.leadingAnchor constant:16],
        [switchTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_availabilitySwitch.leadingAnchor constant:-12],
        
        [switchSubtitle.topAnchor constraintEqualToAnchor:switchTitle.bottomAnchor constant:2],
        [switchSubtitle.leadingAnchor constraintEqualToAnchor:switchTitle.leadingAnchor],
        [switchSubtitle.trailingAnchor constraintEqualToAnchor:switchTitle.trailingAnchor],
        
        [_availabilitySwitch.trailingAnchor constraintEqualToAnchor:switchRow.trailingAnchor constant:-16],
        [_availabilitySwitch.centerYAnchor constraintEqualToAnchor:switchRow.centerYAnchor],
        
        // Save Button
        [_saveButton.topAnchor constraintEqualToAnchor:switchRow.bottomAnchor constant:20],
        [_saveButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_saveButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_saveButton.heightAnchor constraintEqualToConstant:54],
        [_saveButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-32]
    ]];
}

- (UIButton *)makeDeltaButtonWithTitle:(NSString *)title delta:(double)delta isPositive:(BOOL)isPositive {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [Styling fontBold:15.0];
    [btn setTitle:title forState:UIControlStateNormal];
    
    UIColor *color = isPositive ? [UIColor ppPrimary] : [UIColor ppTextSecondary];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.backgroundColor = [color colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(btn, PPCornerMedium);
    
    objc_setAssociatedObject(btn, "price_delta", @(delta), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [btn addTarget:self action:@selector(deltaTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)deltaTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSNumber *deltaNum = objc_getAssociatedObject(sender, "price_delta");
    if (deltaNum) {
        self.currentPrice = MAX(0.0, self.currentPrice + deltaNum.doubleValue);
        [self updatePriceDisplay];
    }
}

- (void)zeroTapped {
    [PPFunc pp_playTapEffect];
    self.currentPrice = 0.0;
    [self updatePriceDisplay];
}

- (void)directInputChanged {
    double parsed = [self.directInputField.text doubleValue];
    self.currentPrice = MAX(0.0, parsed);
    [self updatePriceDisplayWithoutTextField];
}

- (void)updatePriceDisplay {
    [self updatePriceDisplayWithoutTextField];
    if (self.currentPrice > 0) {
        self.directInputField.text = [NSString stringWithFormat:@"%.2f", self.currentPrice];
    } else {
        self.directInputField.text = @"";
    }
}

- (void)updatePriceDisplayWithoutTextField {
    NSString *curr = self.service.currency ?: @"QAR";
    self.counterDisplay.text = [NSString stringWithFormat:@"%.2f %@", self.currentPrice, curr];
}

- (void)saveRateTapped {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    
    [PPHUD showIndeterminateIn:self.view title:[Language isRTL] ? @"جارٍ التحديث..." : @"Updating..." subtitle:nil];
    
    PPServiceModel *updated = [self.service copy];
    updated.price = self.currentPrice;
    updated.isAvailable = self.availabilitySwitch.isOn;
    
    __weak typeof(self) weakSelf = self;
    [[PPServiceManager sharedManager] updateService:updated image:nil completion:^(NSError * _Nullable error) {
        [PPHUD dismiss];
        if (error) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            [PPHUD showSuccess:[Language isRTL] ? @"تم تحديث السعر والتوفر بنجاح" : @"Rate & availability updated!"];
            if (weakSelf.onUpdated) {
                weakSelf.onUpdated();
            }
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

@end

#pragma mark - PPServiceCardCell Interface & Implementation

@interface PPServiceCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardSurface;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryBadge;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;

// Action Buttons
@property (nonatomic, strong) UIButton *availabilityButton;
@property (nonatomic, strong) UIButton *quickPricingButton;
@property (nonatomic, strong) UIButton *detailsButton;

@property (nonatomic, copy, nullable) void(^onToggleAvailability)(PPServiceModel *service);
@property (nonatomic, copy, nullable) void(^onQuickPricing)(PPServiceModel *service);
@property (nonatomic, copy, nullable) void(^onOpenDetails)(PPServiceModel *service);
@property (nonatomic, strong, nullable) PPServiceModel *currentService;
@end

@implementation PPServiceCardCell

+ (NSString *)reuseID {
    return @"PPServiceCardCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    _cardSurface = [[UIView alloc] init];
    _cardSurface.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurface.backgroundColor = [UIColor ppSurfaceElevated];
    _cardSurface.layer.borderWidth = 1.0;
    _cardSurface.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_cardSurface, PPCornerCard);
    PPApplyCardShadow(_cardSurface);
    _cardSurface.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentView addSubview:_cardSurface];

    // Image
    _thumbnailView = [[UIImageView alloc] init];
    _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailView.clipsToBounds = YES;
    _thumbnailView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(_thumbnailView, 18.0);
    [_cardSurface addSubview:_thumbnailView];

    // Category Badge
    _categoryBadge = [[UILabel alloc] init];
    _categoryBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryBadge.font = [Styling fontBold:11.0];
    _categoryBadge.textColor = [UIColor ppPrimary];
    _categoryBadge.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    _categoryBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_categoryBadge, PPCornerPill);
    [_cardSurface addSubview:_categoryBadge];

    // Status Dot & Label
    _statusDot = [[UIView alloc] init];
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    _statusDot.layer.cornerRadius = 4.0;
    _statusDot.layer.masksToBounds = YES;
    [_cardSurface addSubview:_statusDot];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [Styling fontMedium:11.5];
    _statusLabel.textColor = [UIColor ppTextSecondary];
    _statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_statusLabel];

    // Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:16.5];
    _titleLabel.textColor = [UIColor ppTextPrimary];
    _titleLabel.numberOfLines = 1;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_titleLabel];

    // Description Snippet
    _descLabel = [[UILabel alloc] init];
    _descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descLabel.font = [Styling fontRegular:13.0];
    _descLabel.textColor = [UIColor ppTextSecondary];
    _descLabel.numberOfLines = 2;
    _descLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_descLabel];

    // Price
    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [Styling fontBold:16.0];
    _priceLabel.textColor = [UIColor ppPrimary];
    _priceLabel.textAlignment = [Language isRTL] ? NSTextAlignmentLeft : NSTextAlignmentRight;
    [_cardSurface addSubview:_priceLabel];

    // Card Action Pills Row
    UIStackView *actionsRow = [[UIStackView alloc] init];
    actionsRow.translatesAutoresizingMaskIntoConstraints = NO;
    actionsRow.axis = UILayoutConstraintAxisHorizontal;
    actionsRow.spacing = 8;
    actionsRow.distribution = UIStackViewDistributionFillProportionally;
    actionsRow.alignment = UIStackViewAlignmentCenter;
    [_cardSurface addSubview:actionsRow];

    _availabilityButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _availabilityButton.titleLabel.font = [Styling fontBold:12.0];
    _availabilityButton.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
    PPApplyContinuousCorners(_availabilityButton, PPCornerPill);
    [_availabilityButton addTarget:self action:@selector(toggleAvailabilityTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsRow addArrangedSubview:_availabilityButton];

    _quickPricingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _quickPricingButton.titleLabel.font = [Styling fontBold:12.0];
    _quickPricingButton.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
    [_quickPricingButton setTitle:[Language isRTL] ? @"💵 التسعير السريع" : @"💵 Quick Rate" forState:UIControlStateNormal];
    [_quickPricingButton setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
    _quickPricingButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(_quickPricingButton, PPCornerPill);
    [_quickPricingButton addTarget:self action:@selector(quickPricingTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsRow addArrangedSubview:_quickPricingButton];

    _detailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _detailsButton.titleLabel.font = [Styling fontBold:12.0];
    _detailsButton.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
    [_detailsButton setTitle:[Language isRTL] ? @"••• تفاصيل" : @"••• Details" forState:UIControlStateNormal];
    [_detailsButton setTitleColor:[UIColor ppTextSecondary] forState:UIControlStateNormal];
    _detailsButton.backgroundColor = [UIColor ppSurface];
    _detailsButton.layer.borderWidth = 1.0;
    _detailsButton.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_detailsButton, PPCornerPill);
    [_detailsButton addTarget:self action:@selector(detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsRow addArrangedSubview:_detailsButton];

    [NSLayoutConstraint activateConstraints:@[
        [_cardSurface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [_cardSurface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_cardSurface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_cardSurface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],

        // Thumbnail
        [_thumbnailView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:14],
        [_thumbnailView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:14],
        [_thumbnailView.widthAnchor constraintEqualToConstant:86],
        [_thumbnailView.heightAnchor constraintEqualToConstant:86],

        // Top Metadata: Category Badge + Status Dot + Status Label + Price
        [_categoryBadge.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:14],
        [_categoryBadge.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12],
        [_categoryBadge.heightAnchor constraintEqualToConstant:22],

        [_statusDot.centerYAnchor constraintEqualToAnchor:_categoryBadge.centerYAnchor],
        [_statusDot.leadingAnchor constraintEqualToAnchor:_categoryBadge.trailingAnchor constant:8],
        [_statusDot.widthAnchor constraintEqualToConstant:8],
        [_statusDot.heightAnchor constraintEqualToConstant:8],

        [_statusLabel.centerYAnchor constraintEqualToAnchor:_categoryBadge.centerYAnchor],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:5],

        [_priceLabel.centerYAnchor constraintEqualToAnchor:_categoryBadge.centerYAnchor],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        [_priceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_statusLabel.trailingAnchor constant:6],

        // Title
        [_titleLabel.topAnchor constraintEqualToAnchor:_categoryBadge.bottomAnchor constant:6],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],

        // Description
        [_descLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_descLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        // Actions Row
        [actionsRow.topAnchor constraintEqualToAnchor:_thumbnailView.bottomAnchor constant:12],
        [actionsRow.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:14],
        [actionsRow.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        [actionsRow.heightAnchor constraintEqualToConstant:32],
        [actionsRow.bottomAnchor constraintEqualToAnchor:_cardSurface.bottomAnchor constant:-14]
    ]];
}

- (void)configureWithService:(PPServiceModel *)service {
    _currentService = service;

    _titleLabel.text = service.title ?: @"";
    _descLabel.text = service.descriptionText.length > 0 ? service.descriptionText : ([Language isRTL] ? @"لا يوجد وصف مضاف لهذه الخدمة بعد." : @"No description provided for this service.");
    
    NSString *curr = service.currency ?: @"QAR";
    _priceLabel.text = [NSString stringWithFormat:@"%.2f %@", service.price, curr];

    // Image
    if (service.imageURL.length > 0) {
        [_thumbnailView sd_setImageWithURL:[NSURL URLWithString:service.imageURL]
                          placeholderImage:[UIImage systemImageNamed:@"sparkles"]];
    } else {
        _thumbnailView.image = [UIImage systemImageNamed:@"sparkles"];
        _thumbnailView.tintColor = [UIColor ppPrimary];
    }

    // Category
    NSString *cat = service.category.length > 0 ? service.category : ([Language isRTL] ? @"خدمة عامة" : @"Service");
    _categoryBadge.text = [NSString stringWithFormat:@"  %@  ", cat];

    // Availability & Status
    BOOL isActive = service.isAvailable && !service.isDisabled && !service.isBlocked;
    if (isActive) {
        _statusDot.backgroundColor = [UIColor ppSuccess];
        _statusLabel.text = [Language isRTL] ? @"متاح للحجز" : @"Available";
        _statusLabel.textColor = [UIColor ppSuccess];
        
        [_availabilityButton setTitle:[Language isRTL] ? @"🟢 إيقاف مؤقت" : @"🟢 Pause" forState:UIControlStateNormal];
        [_availabilityButton setTitleColor:[UIColor ppWarning] forState:UIControlStateNormal];
        _availabilityButton.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.08];
    } else {
        _statusDot.backgroundColor = [UIColor ppWarning];
        _statusLabel.text = [Language isRTL] ? @"غير متاح" : @"Paused";
        _statusLabel.textColor = [UIColor ppWarning];
        
        [_availabilityButton setTitle:[Language isRTL] ? @"⚪ تفعيل الخدمة" : @"⚪ Activate" forState:UIControlStateNormal];
        [_availabilityButton setTitleColor:[UIColor ppSuccess] forState:UIControlStateNormal];
        _availabilityButton.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
    }
}

- (void)toggleAvailabilityTapped {
    [PPFunc pp_playTapEffect];
    if (self.onToggleAvailability && self.currentService) {
        self.onToggleAvailability(self.currentService);
    }
}

- (void)quickPricingTapped {
    [PPFunc pp_playTapEffect];
    if (self.onQuickPricing && self.currentService) {
        self.onQuickPricing(self.currentService);
    }
}

- (void)detailsTapped {
    [PPFunc pp_playTapEffect];
    if (self.onOpenDetails && self.currentService) {
        self.onOpenDetails(self.currentService);
    }
}

@end

#pragma mark - Main PPServicesListViewController Implementation

@interface PPServicesListViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *cockpitHeaderView;

// Cockpit KPI Badges
@property (nonatomic, strong) UILabel *kpiTotalLabel;
@property (nonatomic, strong) UILabel *kpiActiveLabel;
@property (nonatomic, strong) UILabel *kpiPausedLabel;
@property (nonatomic, strong) UILabel *kpiAvgRateLabel;

// Omni-Search & Filter Rail
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchClearBtn;
@property (nonatomic, strong) UILabel *searchCountLabel;
@property (nonatomic, strong) UIScrollView *categoryFilterRail;
@property (nonatomic, strong) UIStackView *categoryFilterStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterButtons;
@property (nonatomic, copy) NSString *selectedFilterCategory; // @"all", @"active", @"paused", or custom category

// Empty State View
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyImageView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIButton *emptyCTAButton;

// Data & Firestore
@property (nonatomic, strong) NSMutableArray<PPServiceModel *> *allServices;
@property (nonatomic, strong) NSMutableArray<PPServiceModel *> *filteredServices;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> serviceListener;
@property (nonatomic, assign) BOOL hasPermission;
@end

@implementation PPServicesListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.allServices = [NSMutableArray array];
    self.filteredServices = [NSMutableArray array];
    self.filterButtons = [NSMutableArray array];
    self.selectedFilterCategory = @"all";
    self.searchQuery = @"";
    self.hasPermission = [self checkServicePermission];

    [self setupNavigation];
    [self setupTableView];
    [self setupCockpitHeader];
    [self setupEmptyState];
    [self startObservingServices];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigation];
}

- (void)dealloc {
    [self.serviceListener remove];
    self.serviceListener = nil;
}

- (BOOL)checkServicePermission {
    UserModel *me = [UserManager shared].currentUser;
    if (!me) return NO;
    if (me.canOfferServices) return YES;
    if ([me hasPermissionNamed:kPermManageServices]) return YES;
    if ([me hasPermissionNamed:kPermAdminAll]) return YES;
    if (me.isSuperAdmin || me.isAdmin || me.role == UserRoleSuperAdmin || me.role == UserRoleAdmin) return YES;
    return NO;
}

#pragma mark - Top Navigation (PPNavBar)

- (void)setupNavigation {
    NSString *navTitle = kLang(@"ManageServices") ?: ([Language isRTL] ? @"طلبات وعروض الخدمة" : @"Manage Services");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:navTitle showBack:YES];

    if (self.hasPermission) {
        // 1. Add Service Button (Crimson 44x44 circular button)
        UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        addBtn.translatesAutoresizingMaskIntoConstraints = NO;
        addBtn.backgroundColor = [UIColor ppPrimary];
        [addBtn setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
        addBtn.tintColor = UIColor.whiteColor;
        PPApplyContinuousCorners(addBtn, 22.0);
        PPApplyButtonShadow(addBtn);
        [addBtn addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:addBtn key:@"service_add"];

        // 2. Refresh Button
        UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [refreshBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
        refreshBtn.tintColor = [UIColor ppPrimary];
        [refreshBtn addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:refreshBtn key:@"service_refresh"];

        // 3. Subscription Plan Button
        UIButton *subBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        subBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [subBtn setImage:[UIImage systemImageNamed:@"crown.fill"] forState:UIControlStateNormal];
        subBtn.tintColor = [UIColor systemOrangeColor];
        [subBtn addTarget:self action:@selector(openSubscriptionPlan) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:subBtn key:@"service_plan"];
    }
}

- (void)openSubscriptionPlan {
    [PPFunc pp_playTapEffect];
    PPServiceModel *sample = self.allServices.firstObject ?: [[PPServiceModel alloc] init];
    PPServiceSubscriptionViewController *vc = [[PPServiceSubscriptionViewController alloc] initWithService:sample];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Table & Spatial Cockpit Header

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 160.0;
    _tableView.sectionHeaderTopPadding = 0.0;
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 90, 0);
    [_tableView registerClass:[PPServiceCardCell class] forCellReuseIdentifier:[PPServiceCardCell reuseID]];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.tintColor = [UIColor ppPrimary];
    [_refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupCockpitHeader {
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 230)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // 1. Cockpit Metric Strip
    UIView *metricsCard = [[UIView alloc] init];
    metricsCard.translatesAutoresizingMaskIntoConstraints = NO;
    metricsCard.backgroundColor = [UIColor ppSurfaceElevated];
    metricsCard.layer.borderWidth = 1.0;
    metricsCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(metricsCard, PPCornerCard);
    PPApplyCardShadow(metricsCard);
    [header addSubview:metricsCard];

    UIStackView *metricsGrid = [[UIStackView alloc] init];
    metricsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    metricsGrid.axis = UILayoutConstraintAxisHorizontal;
    metricsGrid.distribution = UIStackViewDistributionFillEqually;
    metricsGrid.spacing = 8;
    [metricsCard addSubview:metricsGrid];

    _kpiTotalLabel = [self makeKPILabelWithColor:[UIColor ppTextPrimary]];
    _kpiActiveLabel = [self makeKPILabelWithColor:[UIColor ppSuccess]];
    _kpiPausedLabel = [self makeKPILabelWithColor:[UIColor ppWarning]];
    _kpiAvgRateLabel = [self makeKPILabelWithColor:[UIColor ppPrimary]];

    UIView *tileTotal = [self makeKPITileWithTitle:[Language isRTL] ? @"إجمالي الخدمات" : @"Total Offers"
                                             icon:@"briefcase.fill"
                                            color:[UIColor ppTextPrimary]
                                       valueLabel:_kpiTotalLabel
                                              tag:@"all"];
    UIView *tileActive = [self makeKPITileWithTitle:[Language isRTL] ? @"متاح للحجز" : @"Active"
                                              icon:@"checkmark.seal.fill"
                                             color:[UIColor ppSuccess]
                                        valueLabel:_kpiActiveLabel
                                               tag:@"active"];
    UIView *tilePaused = [self makeKPITileWithTitle:[Language isRTL] ? @"معلق مؤقتاً" : @"Paused"
                                              icon:@"pause.circle.fill"
                                             color:[UIColor ppWarning]
                                        valueLabel:_kpiPausedLabel
                                               tag:@"paused"];
    UIView *tileRate = [self makeKPITileWithTitle:[Language isRTL] ? @"متوسط السعر" : @"Avg Rate"
                                            icon:@"banknote.fill"
                                           color:[UIColor ppPrimary]
                                      valueLabel:_kpiAvgRateLabel
                                             tag:@"all"];

    [metricsGrid addArrangedSubview:tileTotal];
    [metricsGrid addArrangedSubview:tileActive];
    [metricsGrid addArrangedSubview:tilePaused];
    [metricsGrid addArrangedSubview:tileRate];

    // 2. Omni-Search Field
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    searchContainer.backgroundColor = [UIColor ppSurfaceElevated];
    searchContainer.layer.borderWidth = 1.0;
    searchContainer.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(searchContainer, PPCornerMedium);
    PPApplyCardShadow(searchContainer);
    [header addSubview:searchContainer];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppTextTertiary];
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [searchContainer addSubview:searchIcon];

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholder = [Language isRTL] ? @"ابحث في الخدمات، الفئات، أو تفاصيل العرض..." : @"Search services, categories, or details...";
    _searchField.font = [Styling fontMedium:14.5];
    _searchField.textColor = [UIColor ppTextPrimary];
    _searchField.textAlignment = Language.alignmentForCurrentLanguage;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.clearButtonMode = UITextFieldViewModeNever;
    _searchField.delegate = self;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [searchContainer addSubview:_searchField];

    _searchClearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _searchClearBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_searchClearBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    _searchClearBtn.tintColor = [UIColor ppTextTertiary];
    _searchClearBtn.hidden = YES;
    [_searchClearBtn addTarget:self action:@selector(clearSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    [searchContainer addSubview:_searchClearBtn];

    _searchCountLabel = [[UILabel alloc] init];
    _searchCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _searchCountLabel.font = [Styling fontBold:11.0];
    _searchCountLabel.textColor = [UIColor ppPrimary];
    _searchCountLabel.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.10];
    _searchCountLabel.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_searchCountLabel, PPCornerPill);
    _searchCountLabel.hidden = YES;
    [searchContainer addSubview:_searchCountLabel];

    // 3. Category Filter Rail
    _categoryFilterRail = [[UIScrollView alloc] init];
    _categoryFilterRail.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryFilterRail.showsHorizontalScrollIndicator = NO;
    _categoryFilterRail.alwaysBounceHorizontal = YES;
    [header addSubview:_categoryFilterRail];

    _categoryFilterStack = [[UIStackView alloc] init];
    _categoryFilterStack.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryFilterStack.axis = UILayoutConstraintAxisHorizontal;
    _categoryFilterStack.spacing = 8;
    _categoryFilterStack.alignment = UIStackViewAlignmentCenter;
    [_categoryFilterRail addSubview:_categoryFilterStack];

    [NSLayoutConstraint activateConstraints:@[
        // Metrics Card
        [metricsCard.topAnchor constraintEqualToAnchor:header.topAnchor constant:10],
        [metricsCard.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [metricsCard.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [metricsCard.heightAnchor constraintEqualToConstant:84],

        [metricsGrid.topAnchor constraintEqualToAnchor:metricsCard.topAnchor constant:8],
        [metricsGrid.leadingAnchor constraintEqualToAnchor:metricsCard.leadingAnchor constant:8],
        [metricsGrid.trailingAnchor constraintEqualToAnchor:metricsCard.trailingAnchor constant:-8],
        [metricsGrid.bottomAnchor constraintEqualToAnchor:metricsCard.bottomAnchor constant:-8],

        // Search Container
        [searchContainer.topAnchor constraintEqualToAnchor:metricsCard.bottomAnchor constant:12],
        [searchContainer.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [searchContainer.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [searchContainer.heightAnchor constraintEqualToConstant:48],

        [searchIcon.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor constant:14],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:18],
        [searchIcon.heightAnchor constraintEqualToConstant:18],

        [_searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:10],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchClearBtn.leadingAnchor constant:-8],
        [_searchField.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],

        [_searchClearBtn.trailingAnchor constraintEqualToAnchor:_searchCountLabel.leadingAnchor constant:-6],
        [_searchClearBtn.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [_searchClearBtn.widthAnchor constraintEqualToConstant:24],
        [_searchClearBtn.heightAnchor constraintEqualToConstant:24],

        [_searchCountLabel.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor constant:-12],
        [_searchCountLabel.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [_searchCountLabel.heightAnchor constraintEqualToConstant:24],

        // Filter Rail
        [_categoryFilterRail.topAnchor constraintEqualToAnchor:searchContainer.bottomAnchor constant:12],
        [_categoryFilterRail.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_categoryFilterRail.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_categoryFilterRail.heightAnchor constraintEqualToConstant:38],

        [_categoryFilterStack.topAnchor constraintEqualToAnchor:_categoryFilterRail.topAnchor],
        [_categoryFilterStack.leadingAnchor constraintEqualToAnchor:_categoryFilterRail.leadingAnchor],
        [_categoryFilterStack.trailingAnchor constraintEqualToAnchor:_categoryFilterRail.trailingAnchor],
        [_categoryFilterStack.bottomAnchor constraintEqualToAnchor:_categoryFilterRail.bottomAnchor],
        [_categoryFilterStack.heightAnchor constraintEqualToAnchor:_categoryFilterRail.heightAnchor]
    ]];

    _cockpitHeaderView = header;
    _tableView.tableHeaderView = _cockpitHeaderView;

    [self rebuildFilterRail];
}

- (UILabel *)makeKPILabelWithColor:(UIColor *)color {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = [Styling fontBold:16.0];
    lbl.textColor = color;
    lbl.text = @"0";
    lbl.textAlignment = NSTextAlignmentCenter;
    return lbl;
}

- (UIView *)makeKPITileWithTitle:(NSString *)title
                            icon:(NSString *)iconName
                           color:(UIColor *)color
                      valueLabel:(UILabel *)valLabel
                             tag:(NSString *)tagKey {
    UIView *tile = [[UIView alloc] init];
    tile.backgroundColor = [color colorWithAlphaComponent:0.06];
    PPApplyContinuousCorners(tile, PPCornerMedium);
    tile.userInteractionEnabled = YES;
    objc_setAssociatedObject(tile, "kpi_tag", tagKey, OBJC_ASSOCIATION_COPY_NONATOMIC);

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(kpiTileTapped:)];
    [tile addGestureRecognizer:tap];

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = color;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [tile addSubview:icon];

    UILabel *titleL = [[UILabel alloc] init];
    titleL.translatesAutoresizingMaskIntoConstraints = NO;
    titleL.text = title;
    titleL.font = [Styling fontMedium:10.5];
    titleL.textColor = [UIColor ppTextSecondary];
    titleL.textAlignment = NSTextAlignmentCenter;
    [tile addSubview:titleL];

    [tile addSubview:valLabel];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:tile.topAnchor constant:8],
        [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [icon.widthAnchor constraintEqualToConstant:16],
        [icon.heightAnchor constraintEqualToConstant:16],

        [valLabel.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:2],
        [valLabel.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],

        [titleL.topAnchor constraintEqualToAnchor:valLabel.bottomAnchor constant:1],
        [titleL.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [titleL.bottomAnchor constraintLessThanOrEqualToAnchor:tile.bottomAnchor constant:-6]
    ]];
    return tile;
}

- (void)kpiTileTapped:(UITapGestureRecognizer *)gesture {
    [PPFunc pp_playTapEffect];
    NSString *tagKey = objc_getAssociatedObject(gesture.view, "kpi_tag");
    if (tagKey.length > 0) {
        self.selectedFilterCategory = tagKey;
        [self updateFilterButtonsSelection];
        [self applyFilterAndReload];
    }
}

- (void)rebuildFilterRail {
    for (UIView *v in self.categoryFilterStack.arrangedSubviews) {
        [self.categoryFilterStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.filterButtons removeAllObjects];

    NSMutableArray<NSDictionary *> *categories = [NSMutableArray arrayWithArray:@[
        @{@"key": @"all", @"title": [Language isRTL] ? @"الكل" : @"All"},
        @{@"key": @"active", @"title": [Language isRTL] ? @"🟢 متاح" : @"🟢 Active"},
        @{@"key": @"paused", @"title": [Language isRTL] ? @"⏸️ معلق" : @"⏸️ Paused"}
    ]];

    // Extract dynamic categories from services
    NSMutableOrderedSet<NSString *> *dynamicCats = [NSMutableOrderedSet orderedSet];
    for (PPServiceModel *s in self.allServices) {
        if (s.category.length > 0) {
            [dynamicCats addObject:s.category];
        }
    }
    for (NSString *cat in dynamicCats) {
        [categories addObject:@{@"key": cat, @"title": cat}];
    }

    for (NSDictionary *dict in categories) {
        NSString *key = dict[@"key"];
        NSString *title = dict[@"title"];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.contentEdgeInsets = UIEdgeInsetsMake(7, 13, 7, 13);
        btn.titleLabel.font = [Styling fontBold:12.5];
        [btn setTitle:title forState:UIControlStateNormal];
        PPApplyContinuousCorners(btn, PPCornerPill);
        objc_setAssociatedObject(btn, "cat_key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(filterPillTapped:) forControlEvents:UIControlEventTouchUpInside];

        [self.categoryFilterStack addArrangedSubview:btn];
        [self.filterButtons addObject:btn];
    }
    [self updateFilterButtonsSelection];
}

- (void)updateFilterButtonsSelection {
    for (UIButton *btn in self.filterButtons) {
        NSString *key = objc_getAssociatedObject(btn, "cat_key");
        BOOL isSel = [key isEqualToString:self.selectedFilterCategory];
        if (isSel) {
            btn.backgroundColor = [UIColor ppPrimary];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.layer.borderWidth = 0.0;
            PPApplyButtonShadow(btn);
        } else {
            btn.backgroundColor = [UIColor ppSurfaceElevated];
            [btn setTitleColor:[UIColor ppTextSecondary] forState:UIControlStateNormal];
            btn.layer.borderWidth = 1.0;
            btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
            btn.layer.shadowOpacity = 0.0;
        }
    }
}

- (void)filterPillTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSString *key = objc_getAssociatedObject(sender, "cat_key");
    if (key.length > 0) {
        self.selectedFilterCategory = key;
        [self updateFilterButtonsSelection];
        [self applyFilterAndReload];
    }
}

#pragma mark - Empty State

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] init];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    _emptyImageView = [[UIImageView alloc] init];
    _emptyImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyImageView.contentMode = UIViewContentModeScaleAspectFit;
    _emptyImageView.tintColor = [UIColor ppPrimary];
    _emptyImageView.image = [UIImage systemImageNamed:@"sparkles.rectangle.stack.fill"];
    [_emptyStateView addSubview:_emptyImageView];

    _emptyTitleLabel = [[UILabel alloc] init];
    _emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitleLabel.font = [Styling fontBold:18.0];
    _emptyTitleLabel.textColor = [UIColor ppTextPrimary];
    _emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptyTitleLabel.text = [Language isRTL] ? @"لا توجد عروض خدمات حالياً" : @"No Service Offers Yet";
    [_emptyStateView addSubview:_emptyTitleLabel];

    _emptySubtitleLabel = [[UILabel alloc] init];
    _emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitleLabel.font = [Styling fontRegular:14.0];
    _emptySubtitleLabel.textColor = [UIColor ppTextSecondary];
    _emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptySubtitleLabel.numberOfLines = 3;
    _emptySubtitleLabel.text = [Language isRTL]
        ? @"اعرض خدماتك (التدريب، الحلاقة، الرعاية، الاستضافة) لآلاف العملاء في قطر وابدأ باستقبال الحجوزات فوراً."
        : @"Offer your services (grooming, training, boarding, care) to pet owners and start receiving bookings.";
    [_emptyStateView addSubview:_emptySubtitleLabel];

    _emptyCTAButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _emptyCTAButton.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyCTAButton.backgroundColor = [UIColor ppPrimary];
    [_emptyCTAButton setTitle:[Language isRTL] ? @"+ إضافة أول خدمة الآن" : @"+ Add First Service Now" forState:UIControlStateNormal];
    [_emptyCTAButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _emptyCTAButton.titleLabel.font = [Styling fontBold:15.5];
    _emptyCTAButton.contentEdgeInsets = UIEdgeInsetsMake(12, 24, 12, 24);
    PPApplyContinuousCorners(_emptyCTAButton, PPCornerMedium);
    PPApplyButtonShadow(_emptyCTAButton);
    [_emptyCTAButton addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_emptyStateView addSubview:_emptyCTAButton];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:50],
        [_emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [_emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        [_emptyImageView.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [_emptyImageView.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [_emptyImageView.widthAnchor constraintEqualToConstant:68],
        [_emptyImageView.heightAnchor constraintEqualToConstant:68],

        [_emptyTitleLabel.topAnchor constraintEqualToAnchor:_emptyImageView.bottomAnchor constant:16],
        [_emptyTitleLabel.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [_emptyTitleLabel.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [_emptySubtitleLabel.topAnchor constraintEqualToAnchor:_emptyTitleLabel.bottomAnchor constant:8],
        [_emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [_emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [_emptyCTAButton.topAnchor constraintEqualToAnchor:_emptySubtitleLabel.bottomAnchor constant:20],
        [_emptyCTAButton.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [_emptyCTAButton.heightAnchor constraintEqualToConstant:50],
        [_emptyCTAButton.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor]
    ]];
}

#pragma mark - Search & Filtering

- (void)searchChanged {
    self.searchQuery = [self.searchField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.searchClearBtn.hidden = (self.searchQuery.length == 0);
    [self applyFilterAndReload];
}

- (void)clearSearchTapped {
    [PPFunc pp_playTapEffect];
    self.searchField.text = @"";
    [self.searchField resignFirstResponder];
    [self searchChanged];
}

- (void)applyFilterAndReload {
    NSMutableArray<PPServiceModel *> *filtered = [NSMutableArray array];

    for (PPServiceModel *s in self.allServices) {
        // 1. Category / Status Filter
        BOOL passesCategory = YES;
        BOOL isActive = s.isAvailable && !s.isDisabled && !s.isBlocked;
        if ([self.selectedFilterCategory isEqualToString:@"active"]) {
            passesCategory = isActive;
        } else if ([self.selectedFilterCategory isEqualToString:@"paused"]) {
            passesCategory = !isActive;
        } else if (![self.selectedFilterCategory isEqualToString:@"all"]) {
            passesCategory = [s.category isEqualToString:self.selectedFilterCategory];
        }

        if (!passesCategory) continue;

        // 2. Search Query Filter
        if (self.searchQuery.length > 0) {
            NSString *title = s.title ?: @"";
            NSString *desc = s.descriptionText ?: @"";
            NSString *cat = s.category ?: @"";

            BOOL matchTitle = [title rangeOfString:self.searchQuery options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchDesc = [desc rangeOfString:self.searchQuery options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchCat = [cat rangeOfString:self.searchQuery options:NSCaseInsensitiveSearch].location != NSNotFound;

            if (!matchTitle && !matchDesc && !matchCat) {
                continue;
            }
        }

        [filtered addObject:s];
    }

    self.filteredServices = filtered;

    if (self.searchQuery.length > 0) {
        self.searchCountLabel.hidden = NO;
        self.searchCountLabel.text = [NSString stringWithFormat:@" %ld ", (long)filtered.count];
    } else {
        self.searchCountLabel.hidden = YES;
    }

    BOOL isEmpty = (self.filteredServices.count == 0);
    self.emptyStateView.hidden = !isEmpty;
    self.tableView.hidden = (self.allServices.count == 0);

    [self.tableView reloadData];
}

#pragma mark - Data Observation

- (void)onRefresh {
    [self startObservingServices];
}

- (void)startObservingServices {
    NSString *ownerID = [UserManager shared].currentUser.uid;
    if (ownerID.length == 0) {
        [self.refreshControl endRefreshing];
        return;
    }

    [self.serviceListener remove];
    __weak typeof(self) weakSelf = self;

    self.serviceListener = [[PPServiceManager sharedManager] observeServicesForOwnerID:ownerID onChange:^(NSArray<PPServiceModel *> * _Nullable services, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [strongSelf.refreshControl endRefreshing];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }

            strongSelf.allServices = [NSMutableArray arrayWithArray:services ?: @[]];
            [strongSelf updateCockpitStats];
            [strongSelf rebuildFilterRail];
            [strongSelf applyFilterAndReload];
        });
    }];
}

- (void)updateCockpitStats {
    NSInteger total = self.allServices.count;
    NSInteger active = 0;
    NSInteger paused = 0;
    double totalPrice = 0.0;

    for (PPServiceModel *s in self.allServices) {
        if (s.isAvailable && !s.isDisabled && !s.isBlocked) {
            active++;
        } else {
            paused++;
        }
        totalPrice += s.price;
    }

    double avgRate = (total > 0) ? (totalPrice / total) : 0.0;

    self.kpiTotalLabel.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.kpiActiveLabel.text = [NSString stringWithFormat:@"%ld", (long)active];
    self.kpiPausedLabel.text = [NSString stringWithFormat:@"%ld", (long)paused];
    self.kpiAvgRateLabel.text = [NSString stringWithFormat:@"%.0f QAR", avgRate];
}

#pragma mark - User Actions

- (void)addServiceTapped {
    [PPFunc pp_playTapEffect];
    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openQuickPricingForService:(PPServiceModel *)service {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPServiceQuickPricingSheet *sheet = [[PPServiceQuickPricingSheet alloc] initWithService:service onUpdated:^{
        [weakSelf startObservingServices];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openDetailsForService:(PPServiceModel *)service {
    [PPFunc pp_playTapEffect];
    PPServiceDetailViewController *vc = [[PPServiceDetailViewController alloc] initWithService:service];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)toggleAvailabilityForService:(PPServiceModel *)service {
    [PPFunc pp_playTapEffect];
    BOOL newState = !service.isAvailable;
    
    // Optimistic UI update
    service.isAvailable = newState;
    [self.tableView reloadData];
    [self updateCockpitStats];

    __weak typeof(self) weakSelf = self;
    [[PPServiceManager sharedManager] toggleAvailability:newState forServiceID:service.serviceID completion:^(NSError * _Nullable error) {
        if (error) {
            service.isAvailable = !newState;
            [weakSelf.tableView reloadData];
            [weakSelf updateCockpitStats];
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            NSString *msg = newState
                ? ([Language isRTL] ? @"الخدمة متاحة للطلب الآن" : @"Service is now live for bookings")
                : ([Language isRTL] ? @"تم إيقاف الخدمة مؤقتاً" : @"Service paused temporarily");
            [PPHUD showSuccess:msg];
        }
    }];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredServices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceCardCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceCardCell reuseID] forIndexPath:indexPath];
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [cell configureWithService:s];

    __weak typeof(self) weakSelf = self;
    cell.onToggleAvailability = ^(PPServiceModel *service) {
        [weakSelf toggleAvailabilityForService:service];
    };
    cell.onQuickPricing = ^(PPServiceModel *service) {
        [weakSelf openQuickPricingForService:service];
    };
    cell.onOpenDetails = ^(PPServiceModel *service) {
        [weakSelf openDetailsForService:service];
    };

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [self openDetailsForService:s];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceModel *s = self.filteredServices[indexPath.row];
    BOOL newState = !s.isAvailable;
    
    NSString *actionTitle = newState
        ? ([Language isRTL] ? @"تفعيل" : @"Activate")
        : ([Language isRTL] ? @"إيقاف" : @"Pause");
    NSString *icon = newState ? @"checkmark.circle.fill" : @"pause.circle.fill";

    __weak typeof(self) weakSelf = self;
    UIContextualAction *act = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                     title:actionTitle
                                                                   handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf toggleAvailabilityForService:s];
        completionHandler(YES);
    }];
    act.backgroundColor = newState ? [UIColor ppSuccess] : [UIColor ppWarning];
    act.image = [UIImage systemImageNamed:icon];

    return [UISwipeActionsConfiguration configurationWithActions:@[act]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceModel *s = self.filteredServices[indexPath.row];

    __weak typeof(self) weakSelf = self;
    UIContextualAction *editAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:[Language isRTL] ? @"تعديل" : @"Edit"
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf openDetailsForService:s];
        completionHandler(YES);
    }];
    editAct.backgroundColor = [UIColor ppPrimary];
    editAct.image = [UIImage systemImageNamed:@"pencil"];

    UIContextualAction *deleteAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                           title:[Language isRTL] ? @"حذف" : @"Delete"
                                                                         handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf confirmDeleteService:s];
        completionHandler(YES);
    }];
    deleteAct.image = [UIImage systemImageNamed:@"trash.fill"];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAct, editAct]];
}

- (void)confirmDeleteService:(PPServiceModel *)service {
    __weak typeof(self) weakSelf = self;
    NSString *title = [Language isRTL] ? @"تأكيد حذف عرض الخدمة" : @"Confirm Service Deletion";
    NSString *msg = [Language isRTL] ? @"هل أنت متأكد من رغبتك في حذف هذا العرض نهائياً من قائمة خدماتك؟" : @"Are you sure you want to permanently delete this service?";
    
    [PPAlertHelper showConfirmationIn:self title:title subtitle:msg placeholder:nil confirmButton:kLang(@"Delete") cancelButton:kLang(@"Cancel") confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:[Language isRTL] ? @"جارٍ الحذف..." : @"Deleting..." subtitle:nil];
        [[PPServiceManager sharedManager] deleteService:service completion:^(NSError * _Nullable error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:[Language isRTL] ? @"تم حذف الخدمة بنجاح" : @"Service deleted"];
                [weakSelf startObservingServices];
            }
        }];
    } cancelBlock:nil];
}

@end
