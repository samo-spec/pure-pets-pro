//
//  PPPharmacyMedicinesViewController.m
//  Pure Pets Pro
//
//  Created from absolute first principles. Flagship medical pharmacy hub
//  with spatial cockpit KPI summary, omni-search, category filter rail,
//  interactive quick stock sheet, detailed medicine inspector, and
//  high-performance fluid table view.
//

#import "PPPharmacyMedicinesViewController.h"
#import "PPPharmacyMedicineEditorViewController.h"
#import "PPVetManager.h"
#import "PPFirebaseCompat.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "UIImageView+WebCache.h"
#import "PPHUD.h"
#import "PPAlertHelper.h"
#import "PPFunc.h"
#import "UserModel.h"
#import "UserManager.h"
#import "AppManager.h"
#import <objc/runtime.h>

#pragma mark - Filter Rail Enums

typedef NS_ENUM(NSInteger, PPPharmacyFilterLens) {
    PPPharmacyFilterLensAll = 0,
    PPPharmacyFilterLensLowStock,
    PPPharmacyFilterLensAvailable,
    PPPharmacyFilterLensUnavailable,
    PPPharmacyFilterLensCategory
};

#pragma mark - 1. Quick Stock Adjustment Sheet (PPPharmacyQuickStockSheet)

@interface PPPharmacyQuickStockSheet () <UITextFieldDelegate>
@property (nonatomic, strong) PPVetMedicineModel *medicine;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, assign) NSInteger currentQuantity;

@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UIView *statusBadgeView;
@property (nonatomic, strong) UITextField *directInputField;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation PPPharmacyQuickStockSheet

- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine onUpdated:(nullable void(^)(void))onUpdated {
    self = [super init];
    if (self) {
        _medicine = medicine;
        _onUpdated = [onUpdated copy];
        _currentQuantity = MAX(0, medicine.stockQuantity);
        self.modalPresentationStyle = UIModalPresentationPageSheet;
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
            sheet.preferredCornerRadius = 24.0;
        }
    }
    
    [self setupUI];
    [self updateCounterDisplay];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.alwaysBounceVertical = YES;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:scroll];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];
    
    // Header Info Card
    UIView *headerCard = [[UIView alloc] init];
    headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    headerCard.backgroundColor = [UIColor ppSurface];
    headerCard.layer.borderWidth = 1.0;
    headerCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(headerCard, PPCornerCard);
    [contentView addSubview:headerCard];
    
    UIImageView *thumb = [[UIImageView alloc] init];
    thumb.translatesAutoresizingMaskIntoConstraints = NO;
    thumb.contentMode = UIViewContentModeScaleAspectFill;
    thumb.clipsToBounds = YES;
    PPApplyContinuousCorners(thumb, PPCornerSmall);
    thumb.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    if (self.medicine.imageUrl.length > 0) {
        [thumb sd_setImageWithURL:[NSURL URLWithString:self.medicine.imageUrl]
                 placeholderImage:[UIImage systemImageNamed:@"pills.fill"]];
    } else {
        thumb.image = [UIImage systemImageNamed:@"pills.fill"];
        thumb.tintColor = [UIColor ppPrimary];
    }
    [headerCard addSubview:thumb];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = self.medicine.title.length ? self.medicine.title : @"—";
    titleLabel.font = [Styling fontBold:17.0];
    titleLabel.textColor = [UIColor ppTextPrimary];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 1;
    [headerCard addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"Pharmacy_Section_Pricing_Hint");
    subtitleLabel.font = [Styling fontMedium:12.5];
    subtitleLabel.textColor = [UIColor ppPrimary];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:subtitleLabel];
    
    // Big Digital Counter Area
    UIView *counterBox = [[UIView alloc] init];
    counterBox.translatesAutoresizingMaskIntoConstraints = NO;
    counterBox.backgroundColor = [UIColor ppSurface];
    counterBox.layer.borderWidth = 1.0;
    counterBox.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(counterBox, PPCornerCard);
    [contentView addSubview:counterBox];
    
    self.counterLabel = [[UILabel alloc] init];
    self.counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.counterLabel.font = [UIFont systemFontOfSize:44 weight:UIFontWeightHeavy];
    self.counterLabel.textColor = [UIColor ppTextPrimary];
    self.counterLabel.textAlignment = NSTextAlignmentCenter;
    [counterBox addSubview:self.counterLabel];
    
    UILabel *unitLabel = [[UILabel alloc] init];
    unitLabel.translatesAutoresizingMaskIntoConstraints = NO;
    unitLabel.text = kLang(@"Pharmacy_Field_Quantity");
    unitLabel.font = [Styling fontMedium:13.0];
    unitLabel.textColor = [UIColor ppTextSecondary];
    unitLabel.textAlignment = NSTextAlignmentCenter;
    [counterBox addSubview:unitLabel];
    
    self.statusBadgeView = [[UIView alloc] init];
    self.statusBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.statusBadgeView, PPCornerPill);
    [counterBox addSubview:self.statusBadgeView];
    
    self.statusBadgeLabel = [[UILabel alloc] init];
    self.statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBadgeLabel.font = [Styling fontBold:11.5];
    self.statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.statusBadgeView addSubview:self.statusBadgeLabel];
    
    // Stepper Container
    UIStackView *steppersStack = [[UIStackView alloc] init];
    steppersStack.translatesAutoresizingMaskIntoConstraints = NO;
    steppersStack.axis = UILayoutConstraintAxisVertical;
    steppersStack.spacing = 10;
    steppersStack.distribution = UIStackViewDistributionFillEqually;
    [contentView addSubview:steppersStack];
    
    // Row 1: Increments
    UIStackView *incRow = [[UIStackView alloc] init];
    incRow.axis = UILayoutConstraintAxisHorizontal;
    incRow.spacing = 8;
    incRow.distribution = UIStackViewDistributionFillEqually;
    [incRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"+1" delta:1 isAdd:YES]];
    [incRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"+5" delta:5 isAdd:YES]];
    [incRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"+10" delta:10 isAdd:YES]];
    [incRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"+50" delta:50 isAdd:YES]];
    [steppersStack addArrangedSubview:incRow];
    
    // Row 2: Decrements & Zero
    UIStackView *decRow = [[UIStackView alloc] init];
    decRow.axis = UILayoutConstraintAxisHorizontal;
    decRow.spacing = 8;
    decRow.distribution = UIStackViewDistributionFillEqually;
    [decRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"-1" delta:-1 isAdd:NO]];
    [decRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"-5" delta:-5 isAdd:NO]];
    [decRow addArrangedSubview:[self makeDeltaButtonWithTitle:@"-10" delta:-10 isAdd:NO]];
    [decRow addArrangedSubview:[self makeZeroButton]];
    [steppersStack addArrangedSubview:decRow];
    
    // Direct Numeric Input Box
    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = [UIColor ppSurface];
    inputContainer.layer.borderWidth = 1.0;
    inputContainer.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(inputContainer, PPCornerMedium);
    [contentView addSubview:inputContainer];
    
    self.directInputField = [[UITextField alloc] init];
    self.directInputField.translatesAutoresizingMaskIntoConstraints = NO;
    self.directInputField.keyboardType = UIKeyboardTypeNumberPad;
    self.directInputField.textAlignment = NSTextAlignmentCenter;
    self.directInputField.font = [Styling fontBold:18.0];
    self.directInputField.textColor = [UIColor ppTextPrimary];
    self.directInputField.placeholder = kLang(@"Pharmacy_Field_Quantity");
    self.directInputField.delegate = self;
    [self.directInputField addTarget:self action:@selector(directInputChanged) forControlEvents:UIControlEventEditingChanged];
    [inputContainer addSubview:self.directInputField];
    
    // Confirm Button
    self.confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.confirmButton.backgroundColor = [UIColor ppPrimary];
    [self.confirmButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    [self.confirmButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.confirmButton.titleLabel.font = [Styling fontBold:17.0];
    PPApplyContinuousCorners(self.confirmButton, PPCornerMedium);
    PPApplyButtonShadow(self.confirmButton);
    [self.confirmButton addTarget:self action:@selector(saveStockTapped) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.confirmButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = UIColor.whiteColor;
    self.spinner.hidesWhenStopped = YES;
    [self.confirmButton addSubview:self.spinner];
    
    [NSLayoutConstraint activateConstraints:@[
        [headerCard.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
        [headerCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [headerCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [headerCard.heightAnchor constraintEqualToConstant:68],
        
        [thumb.leadingAnchor constraintEqualToAnchor:headerCard.leadingAnchor constant:12],
        [thumb.centerYAnchor constraintEqualToAnchor:headerCard.centerYAnchor],
        [thumb.widthAnchor constraintEqualToConstant:48],
        [thumb.heightAnchor constraintEqualToConstant:48],
        
        [titleLabel.topAnchor constraintEqualToAnchor:headerCard.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:thumb.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerCard.trailingAnchor constant:-12],
        
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        
        [counterBox.topAnchor constraintEqualToAnchor:headerCard.bottomAnchor constant:16],
        [counterBox.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [counterBox.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [counterBox.heightAnchor constraintEqualToConstant:140],
        
        [self.counterLabel.topAnchor constraintEqualToAnchor:counterBox.topAnchor constant:14],
        [self.counterLabel.centerXAnchor constraintEqualToAnchor:counterBox.centerXAnchor],
        
        [unitLabel.topAnchor constraintEqualToAnchor:self.counterLabel.bottomAnchor constant:2],
        [unitLabel.centerXAnchor constraintEqualToAnchor:counterBox.centerXAnchor],
        
        [self.statusBadgeView.bottomAnchor constraintEqualToAnchor:counterBox.bottomAnchor constant:-12],
        [self.statusBadgeView.centerXAnchor constraintEqualToAnchor:counterBox.centerXAnchor],
        [self.statusBadgeView.heightAnchor constraintEqualToConstant:24],
        
        [self.statusBadgeLabel.leadingAnchor constraintEqualToAnchor:self.statusBadgeView.leadingAnchor constant:12],
        [self.statusBadgeLabel.trailingAnchor constraintEqualToAnchor:self.statusBadgeView.trailingAnchor constant:-12],
        [self.statusBadgeLabel.centerYAnchor constraintEqualToAnchor:self.statusBadgeView.centerYAnchor],
        
        [steppersStack.topAnchor constraintEqualToAnchor:counterBox.bottomAnchor constant:16],
        [steppersStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [steppersStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [steppersStack.heightAnchor constraintEqualToConstant:96],
        
        [inputContainer.topAnchor constraintEqualToAnchor:steppersStack.bottomAnchor constant:14],
        [inputContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [inputContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [inputContainer.heightAnchor constraintEqualToConstant:50],
        
        [self.directInputField.topAnchor constraintEqualToAnchor:inputContainer.topAnchor],
        [self.directInputField.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:12],
        [self.directInputField.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-12],
        [self.directInputField.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor],
        
        [self.confirmButton.topAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:20],
        [self.confirmButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [self.confirmButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [self.confirmButton.heightAnchor constraintEqualToConstant:54],
        [self.confirmButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-30],
        
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.confirmButton.centerYAnchor],
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.confirmButton.trailingAnchor constant:-20]
    ]];
}

- (UIButton *)makeDeltaButtonWithTitle:(NSString *)title delta:(NSInteger)delta isAdd:(BOOL)isAdd {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontBold:15.0];
    [btn setTitleColor:isAdd ? [UIColor ppPrimary] : [UIColor ppTextPrimary] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor ppSurface];
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = isAdd ? [[UIColor ppPrimary] colorWithAlphaComponent:0.25].CGColor : [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(btn, PPCornerSmall);
    btn.tag = delta;
    [btn addTarget:self action:@selector(deltaTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UIButton *)makeZeroButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"0" forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontBold:15.0];
    [btn setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
    btn.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.08];
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [[UIColor ppError] colorWithAlphaComponent:0.25].CGColor;
    PPApplyContinuousCorners(btn, PPCornerSmall);
    [btn addTarget:self action:@selector(zeroTapped) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)deltaTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.currentQuantity = MAX(0, self.currentQuantity + sender.tag);
    [self updateCounterDisplay];
}

- (void)zeroTapped {
    [PPFunc pp_playTapEffect];
    self.currentQuantity = 0;
    [self updateCounterDisplay];
}

- (void)directInputChanged {
    NSInteger val = [self.directInputField.text integerValue];
    self.currentQuantity = MAX(0, val);
    [self updateCounterDisplayOnly];
}

- (void)updateCounterDisplay {
    [self updateCounterDisplayOnly];
    self.directInputField.text = [NSString stringWithFormat:@"%ld", (long)self.currentQuantity];
}

- (void)updateCounterDisplayOnly {
    self.counterLabel.text = [NSString stringWithFormat:@"%ld", (long)self.currentQuantity];
    
    if (self.currentQuantity == 0) {
        self.statusBadgeView.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.12];
        self.statusBadgeLabel.textColor = [UIColor ppError];
        self.statusBadgeLabel.text = [Language isRTL] ? @"نفد المخزون" : @"Out of Stock";
    } else if (self.currentQuantity <= 5) {
        self.statusBadgeView.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.15];
        self.statusBadgeLabel.textColor = [UIColor ppWarning];
        self.statusBadgeLabel.text = [Language isRTL] ? @"مخزون منخفض" : @"Low Stock";
    } else {
        self.statusBadgeView.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        self.statusBadgeLabel.textColor = [UIColor ppSuccess];
        self.statusBadgeLabel.text = [Language isRTL] ? @"متوفر ومناسب" : @"In Stock";
    }
}

- (void)saveStockTapped {
    [PPFunc pp_playTapEffect];
    [self.view endEditing:YES];
    
    self.confirmButton.enabled = NO;
    [self.spinner startAnimating];
    
    self.medicine.stockQuantity = self.currentQuantity;
    self.medicine.isAvailable = (self.currentQuantity > 0 && self.medicine.isPublished && !self.medicine.isDisabled);
    
    __weak typeof(self) weakSelf = self;
    [[PPVetManager sharedManager] updateMedicine:self.medicine image:nil completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.confirmButton.enabled = YES;
            [self.spinner stopAnimating];
            
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            
            [PPHUD showSuccess:kLang(@"Updated") subtitle:nil];
            if (self.onUpdated) {
                self.onUpdated();
            }
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end

#pragma mark - 2. Medicine Detail & Inspection Screen (PPPharmacyMedicineDetailViewController)

@interface PPPharmacyMedicineDetailViewController ()
@property (nonatomic, strong) PPVetMedicineModel *medicine;
@property (nonatomic, copy, nullable) void (^onUpdated)(void);
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryPillLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *stockValueLabel;
@property (nonatomic, strong) UIProgressView *stockProgressView;
@property (nonatomic, strong) UILabel *stockStatusLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIStackView *animalTagsStack;
@property (nonatomic, strong) UILabel *visibilityStatusLabel;
@property (nonatomic, strong) UIView *visibilityDot;
@end

@implementation PPPharmacyMedicineDetailViewController

- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine onUpdated:(nullable void(^)(void))onUpdated {
    self = [super init];
    if (self) {
        _medicine = medicine;
        _onUpdated = [onUpdated copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:[Language isRTL] ? @"تفاصيل المستحضر" : @"Medicine Details"
                    showBack:YES];
    
    [self setupContent];
    [self reloadMedicineData];
}

- (void)setupContent {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor]
    ]];
    
    // Hero Image Container Card
    UIView *heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = [UIColor ppSurfaceElevated];
    heroCard.layer.borderWidth = 1.0;
    heroCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(heroCard, PPCornerHero);
    PPApplyCardShadow(heroCard);
    [contentView addSubview:heroCard];
    
    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.heroImageView, PPCornerCard);
    self.heroImageView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    [heroCard addSubview:self.heroImageView];
    
    // Metadata Header Card
    UIView *metaCard = [[UIView alloc] init];
    metaCard.translatesAutoresizingMaskIntoConstraints = NO;
    metaCard.backgroundColor = [UIColor ppSurfaceElevated];
    metaCard.layer.borderWidth = 1.0;
    metaCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(metaCard, PPCornerCard);
    PPApplyCardShadow(metaCard);
    [contentView addSubview:metaCard];
    
    UIView *catPill = [[UIView alloc] init];
    catPill.translatesAutoresizingMaskIntoConstraints = NO;
    catPill.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.1];
    PPApplyContinuousCorners(catPill, PPCornerPill);
    [metaCard addSubview:catPill];
    
    self.categoryPillLabel = [[UILabel alloc] init];
    self.categoryPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryPillLabel.font = [Styling fontBold:12.0];
    self.categoryPillLabel.textColor = [UIColor ppPrimary];
    [catPill addSubview:self.categoryPillLabel];
    
    self.visibilityDot = [[UIView alloc] init];
    self.visibilityDot.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.visibilityDot, 4);
    [metaCard addSubview:self.visibilityDot];
    
    self.visibilityStatusLabel = [[UILabel alloc] init];
    self.visibilityStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.visibilityStatusLabel.font = [Styling fontMedium:12.5];
    self.visibilityStatusLabel.textColor = [UIColor ppTextSecondary];
    [metaCard addSubview:self.visibilityStatusLabel];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [Styling fontBold:22.0];
    self.titleLabel.textColor = [UIColor ppTextPrimary];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [metaCard addSubview:self.titleLabel];
    
    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightHeavy];
    self.priceLabel.textColor = [UIColor ppPrimary];
    self.priceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [metaCard addSubview:self.priceLabel];
    
    // Stock & Inventory Card
    UIView *stockCard = [[UIView alloc] init];
    stockCard.translatesAutoresizingMaskIntoConstraints = NO;
    stockCard.backgroundColor = [UIColor ppSurfaceElevated];
    stockCard.layer.borderWidth = 1.0;
    stockCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(stockCard, PPCornerCard);
    PPApplyCardShadow(stockCard);
    [contentView addSubview:stockCard];
    
    UILabel *stockHeader = [[UILabel alloc] init];
    stockHeader.translatesAutoresizingMaskIntoConstraints = NO;
    stockHeader.text = [Language isRTL] ? @"إدارة مخزون الصيدلية" : @"Pharmacy Stock Control";
    stockHeader.font = [Styling fontBold:15.0];
    stockHeader.textColor = [UIColor ppTextPrimary];
    stockHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [stockCard addSubview:stockHeader];
    
    self.stockValueLabel = [[UILabel alloc] init];
    self.stockValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockValueLabel.font = [Styling fontBold:18.0];
    self.stockValueLabel.textColor = [UIColor ppTextPrimary];
    self.stockValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [stockCard addSubview:self.stockValueLabel];
    
    self.stockProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.stockProgressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockProgressView.layer.cornerRadius = 4;
    self.stockProgressView.clipsToBounds = YES;
    self.stockProgressView.trackTintColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.6];
    [stockCard addSubview:self.stockProgressView];
    
    self.stockStatusLabel = [[UILabel alloc] init];
    self.stockStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockStatusLabel.font = [Styling fontMedium:12.0];
    self.stockStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [stockCard addSubview:self.stockStatusLabel];
    
    UIButton *quickStockBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    quickStockBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [quickStockBtn setTitle:[Language isRTL] ? @"تعديل فوري للمخزون" : @"Quick Stock Adjust" forState:UIControlStateNormal];
    [quickStockBtn setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
    quickStockBtn.titleLabel.font = [Styling fontBold:14.0];
    quickStockBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(quickStockBtn, PPCornerSmall);
    [quickStockBtn addTarget:self action:@selector(openQuickStock) forControlEvents:UIControlEventTouchUpInside];
    [stockCard addSubview:quickStockBtn];
    
    // Description Card
    UIView *descCard = [[UIView alloc] init];
    descCard.translatesAutoresizingMaskIntoConstraints = NO;
    descCard.backgroundColor = [UIColor ppSurfaceElevated];
    descCard.layer.borderWidth = 1.0;
    descCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(descCard, PPCornerCard);
    PPApplyCardShadow(descCard);
    [contentView addSubview:descCard];
    
    UILabel *descHeader = [[UILabel alloc] init];
    descHeader.translatesAutoresizingMaskIntoConstraints = NO;
    descHeader.text = kLang(@"Pharmacy_Field_Description");
    descHeader.font = [Styling fontBold:15.0];
    descHeader.textColor = [UIColor ppTextPrimary];
    descHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [descCard addSubview:descHeader];
    
    self.descLabel = [[UILabel alloc] init];
    self.descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descLabel.font = [Styling fontRegular:14.5];
    self.descLabel.textColor = [UIColor ppTextSecondary];
    self.descLabel.numberOfLines = 0;
    self.descLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [descCard addSubview:self.descLabel];
    
    // Animals Target Row Card
    UIView *animalsCard = [[UIView alloc] init];
    animalsCard.translatesAutoresizingMaskIntoConstraints = NO;
    animalsCard.backgroundColor = [UIColor ppSurfaceElevated];
    animalsCard.layer.borderWidth = 1.0;
    animalsCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(animalsCard, PPCornerCard);
    PPApplyCardShadow(animalsCard);
    [contentView addSubview:animalsCard];
    
    UILabel *animalsHeader = [[UILabel alloc] init];
    animalsHeader.translatesAutoresizingMaskIntoConstraints = NO;
    animalsHeader.text = kLang(@"Pharmacy_Field_AnimalTypes");
    animalsHeader.font = [Styling fontBold:15.0];
    animalsHeader.textColor = [UIColor ppTextPrimary];
    animalsHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [animalsCard addSubview:animalsHeader];
    
    self.animalTagsStack = [[UIStackView alloc] init];
    self.animalTagsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.animalTagsStack.axis = UILayoutConstraintAxisHorizontal;
    self.animalTagsStack.spacing = 8;
    self.animalTagsStack.alignment = UIStackViewAlignmentCenter;
    [animalsCard addSubview:self.animalTagsStack];
    
    // Bottom Action Buttons
    UIButton *editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    editBtn.translatesAutoresizingMaskIntoConstraints = NO;
    editBtn.backgroundColor = [UIColor ppPrimary];
    [editBtn setTitle:kLang(@"Edit") forState:UIControlStateNormal];
    [editBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    editBtn.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(editBtn, PPCornerMedium);
    PPApplyButtonShadow(editBtn);
    [editBtn addTarget:self action:@selector(openFullEditor) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:editBtn];
    
    UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    deleteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    deleteBtn.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.08];
    [deleteBtn setTitle:kLang(@"Delete") forState:UIControlStateNormal];
    [deleteBtn setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
    deleteBtn.titleLabel.font = [Styling fontBold:16.0];
    deleteBtn.layer.borderWidth = 1.0;
    deleteBtn.layer.borderColor = [[UIColor ppError] colorWithAlphaComponent:0.25].CGColor;
    PPApplyContinuousCorners(deleteBtn, PPCornerMedium);
    [deleteBtn addTarget:self action:@selector(confirmDelete) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:deleteBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [heroCard.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16],
        [heroCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [heroCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [heroCard.heightAnchor constraintEqualToConstant:220],
        
        [self.heroImageView.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:12],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:12],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-12],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-12],
        
        [metaCard.topAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:14],
        [metaCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [metaCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        [catPill.topAnchor constraintEqualToAnchor:metaCard.topAnchor constant:16],
        [catPill.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
        [catPill.heightAnchor constraintEqualToConstant:26],
        
        [self.categoryPillLabel.leadingAnchor constraintEqualToAnchor:catPill.leadingAnchor constant:12],
        [self.categoryPillLabel.trailingAnchor constraintEqualToAnchor:catPill.trailingAnchor constant:-12],
        [self.categoryPillLabel.centerYAnchor constraintEqualToAnchor:catPill.centerYAnchor],
        
        [self.visibilityDot.centerYAnchor constraintEqualToAnchor:catPill.centerYAnchor],
        [self.visibilityDot.leadingAnchor constraintEqualToAnchor:catPill.trailingAnchor constant:14],
        [self.visibilityDot.widthAnchor constraintEqualToConstant:8],
        [self.visibilityDot.heightAnchor constraintEqualToConstant:8],
        
        [self.visibilityStatusLabel.centerYAnchor constraintEqualToAnchor:self.visibilityDot.centerYAnchor],
        [self.visibilityStatusLabel.leadingAnchor constraintEqualToAnchor:self.visibilityDot.trailingAnchor constant:6],
        [self.visibilityStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:metaCard.trailingAnchor constant:-16],
        
        [self.titleLabel.topAnchor constraintEqualToAnchor:catPill.bottomAnchor constant:12],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],
        
        [self.priceLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:metaCard.leadingAnchor constant:16],
        [self.priceLabel.trailingAnchor constraintEqualToAnchor:metaCard.trailingAnchor constant:-16],
        [self.priceLabel.bottomAnchor constraintEqualToAnchor:metaCard.bottomAnchor constant:-16],
        
        [stockCard.topAnchor constraintEqualToAnchor:metaCard.bottomAnchor constant:14],
        [stockCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [stockCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        [stockHeader.topAnchor constraintEqualToAnchor:stockCard.topAnchor constant:16],
        [stockHeader.leadingAnchor constraintEqualToAnchor:stockCard.leadingAnchor constant:16],
        [stockHeader.trailingAnchor constraintEqualToAnchor:stockCard.trailingAnchor constant:-16],
        
        [self.stockValueLabel.topAnchor constraintEqualToAnchor:stockHeader.bottomAnchor constant:10],
        [self.stockValueLabel.leadingAnchor constraintEqualToAnchor:stockCard.leadingAnchor constant:16],
        [self.stockValueLabel.trailingAnchor constraintEqualToAnchor:stockCard.trailingAnchor constant:-16],
        
        [self.stockProgressView.topAnchor constraintEqualToAnchor:self.stockValueLabel.bottomAnchor constant:10],
        [self.stockProgressView.leadingAnchor constraintEqualToAnchor:stockCard.leadingAnchor constant:16],
        [self.stockProgressView.trailingAnchor constraintEqualToAnchor:stockCard.trailingAnchor constant:-16],
        [self.stockProgressView.heightAnchor constraintEqualToConstant:8],
        
        [self.stockStatusLabel.topAnchor constraintEqualToAnchor:self.stockProgressView.bottomAnchor constant:8],
        [self.stockStatusLabel.leadingAnchor constraintEqualToAnchor:stockCard.leadingAnchor constant:16],
        [self.stockStatusLabel.trailingAnchor constraintEqualToAnchor:stockCard.trailingAnchor constant:-16],
        
        [quickStockBtn.topAnchor constraintEqualToAnchor:self.stockStatusLabel.bottomAnchor constant:14],
        [quickStockBtn.leadingAnchor constraintEqualToAnchor:stockCard.leadingAnchor constant:16],
        [quickStockBtn.trailingAnchor constraintEqualToAnchor:stockCard.trailingAnchor constant:-16],
        [quickStockBtn.heightAnchor constraintEqualToConstant:42],
        [quickStockBtn.bottomAnchor constraintEqualToAnchor:stockCard.bottomAnchor constant:-16],
        
        [descCard.topAnchor constraintEqualToAnchor:stockCard.bottomAnchor constant:14],
        [descCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [descCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        [descHeader.topAnchor constraintEqualToAnchor:descCard.topAnchor constant:16],
        [descHeader.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
        [descHeader.trailingAnchor constraintEqualToAnchor:descCard.trailingAnchor constant:-16],
        
        [self.descLabel.topAnchor constraintEqualToAnchor:descHeader.bottomAnchor constant:8],
        [self.descLabel.leadingAnchor constraintEqualToAnchor:descCard.leadingAnchor constant:16],
        [self.descLabel.trailingAnchor constraintEqualToAnchor:descCard.trailingAnchor constant:-16],
        [self.descLabel.bottomAnchor constraintEqualToAnchor:descCard.bottomAnchor constant:-16],
        
        [animalsCard.topAnchor constraintEqualToAnchor:descCard.bottomAnchor constant:14],
        [animalsCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [animalsCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        
        [animalsHeader.topAnchor constraintEqualToAnchor:animalsCard.topAnchor constant:16],
        [animalsHeader.leadingAnchor constraintEqualToAnchor:animalsCard.leadingAnchor constant:16],
        [animalsHeader.trailingAnchor constraintEqualToAnchor:animalsCard.trailingAnchor constant:-16],
        
        [self.animalTagsStack.topAnchor constraintEqualToAnchor:animalsHeader.bottomAnchor constant:12],
        [self.animalTagsStack.leadingAnchor constraintEqualToAnchor:animalsCard.leadingAnchor constant:16],
        [self.animalTagsStack.trailingAnchor constraintLessThanOrEqualToAnchor:animalsCard.trailingAnchor constant:-16],
        [self.animalTagsStack.bottomAnchor constraintEqualToAnchor:animalsCard.bottomAnchor constant:-16],
        
        [editBtn.topAnchor constraintEqualToAnchor:animalsCard.bottomAnchor constant:24],
        [editBtn.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [editBtn.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [editBtn.heightAnchor constraintEqualToConstant:54],
        
        [deleteBtn.topAnchor constraintEqualToAnchor:editBtn.bottomAnchor constant:12],
        [deleteBtn.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
        [deleteBtn.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
        [deleteBtn.heightAnchor constraintEqualToConstant:50],
        [deleteBtn.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-40]
    ]];
}

- (void)reloadMedicineData {
    if (self.medicine.imageUrl.length > 0) {
        [self.heroImageView sd_setImageWithURL:[NSURL URLWithString:self.medicine.imageUrl]
                              placeholderImage:[UIImage systemImageNamed:@"pills.fill"]];
    } else {
        self.heroImageView.image = [UIImage systemImageNamed:@"pills.fill"];
        self.heroImageView.tintColor = [UIColor ppPrimary];
    }
    
    self.titleLabel.text = self.medicine.title.length ? self.medicine.title : @"—";
    self.categoryPillLabel.text = self.medicine.category.length ? self.medicine.category : kLang(@"Pharmacy_Category_Other");
    self.priceLabel.text = [NSString stringWithFormat:@"%.2f %@", self.medicine.price, self.medicine.currency ?: @"QAR"];
    
    BOOL isAvailable = self.medicine.isAvailable && (self.medicine.stockQuantity > 0) && self.medicine.isPublished && !self.medicine.isDisabled;
    self.visibilityDot.backgroundColor = isAvailable ? [UIColor ppSuccess] : [UIColor ppError];
    self.visibilityStatusLabel.text = isAvailable ? ([Language isRTL] ? @"متاح للطلب في الصيدلية" : @"Available in Pharmacy") : ([Language isRTL] ? @"غير متاح للعملاء حالياً" : @"Currently Unavailable");
    
    self.stockValueLabel.text = [NSString stringWithFormat:@"%ld %@", (long)MAX(0, self.medicine.stockQuantity), kLang(@"Pharmacy_Field_Quantity")];
    float progress = (float)self.medicine.stockQuantity / 50.0f;
    self.stockProgressView.progress = MIN(1.0, MAX(0.0, progress));
    if (self.medicine.stockQuantity == 0) {
        self.stockProgressView.progressTintColor = [UIColor ppError];
        self.stockStatusLabel.textColor = [UIColor ppError];
        self.stockStatusLabel.text = [Language isRTL] ? @"تنبيه: نفد المخزون بالكامل، لن يظهر المستحضر للطلب." : @"Alert: Out of stock.";
    } else if (self.medicine.stockQuantity <= 5) {
        self.stockProgressView.progressTintColor = [UIColor ppWarning];
        self.stockStatusLabel.textColor = [UIColor ppWarning];
        self.stockStatusLabel.text = [Language isRTL] ? @"تحذير: المخزون أوشك على النفاد (أقل من ٥ وحدات)." : @"Warning: Low stock level.";
    } else {
        self.stockProgressView.progressTintColor = [UIColor ppSuccess];
        self.stockStatusLabel.textColor = [UIColor ppSuccess];
        self.stockStatusLabel.text = [Language isRTL] ? @"حالة المخزون ممتازة ومستقرة." : @"Inventory level healthy.";
    }
    
    self.descLabel.text = self.medicine.medicineDescription.length ? self.medicine.medicineDescription : ([Language isRTL] ? @"لا يوجد وصف طبي مضاف لهذا المستحضر." : @"No medical description provided.");
    
    for (UIView *sub in self.animalTagsStack.arrangedSubviews) {
        [self.animalTagsStack removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }
    NSArray *animals = self.medicine.animalTypes.count ? self.medicine.animalTypes : @[[Language isRTL] ? @"جميع الحيوانات" : @"All Animals"];
    for (NSString *animal in animals) {
        UIView *tag = [[UIView alloc] init];
        tag.backgroundColor = [UIColor ppSurface];
        tag.layer.borderWidth = 1.0;
        tag.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        PPApplyContinuousCorners(tag, PPCornerPill);
        
        UILabel *lbl = [[UILabel alloc] init];
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        lbl.text = animal;
        lbl.font = [Styling fontMedium:12.0];
        lbl.textColor = [UIColor ppTextSecondary];
        [tag addSubview:lbl];
        
        [NSLayoutConstraint activateConstraints:@[
            [lbl.topAnchor constraintEqualToAnchor:tag.topAnchor constant:4],
            [lbl.bottomAnchor constraintEqualToAnchor:tag.bottomAnchor constant:-4],
            [lbl.leadingAnchor constraintEqualToAnchor:tag.leadingAnchor constant:10],
            [lbl.trailingAnchor constraintEqualToAnchor:tag.trailingAnchor constant:-10]
        ]];
        [self.animalTagsStack addArrangedSubview:tag];
    }
}

- (void)openQuickStock {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPPharmacyQuickStockSheet *sheet = [[PPPharmacyQuickStockSheet alloc] initWithMedicine:self.medicine onUpdated:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self reloadMedicineData];
        if (self.onUpdated) self.onUpdated();
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openFullEditor {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPPharmacyMedicineEditorViewController *editor = [[PPPharmacyMedicineEditorViewController alloc] initWithMedicine:self.medicine completion:^(PPVetMedicineModel *editedMedicine, UIImage * _Nullable image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
        [[PPVetManager sharedManager] updateMedicine:editedMedicine image:image completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                if (error) {
                    [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                    return;
                }
                [PPHUD showSuccess:kLang(@"Updated") subtitle:nil];
                self.medicine = editedMedicine;
                [self reloadMedicineData];
                if (self.onUpdated) self.onUpdated();
                [self.navigationController popViewControllerAnimated:YES];
            });
        }];
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)confirmDelete {
    [PPFunc pp_playTapEffect];
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"Pharmacy_Delete_Confirm_Title")
                             subtitle:kLang(@"Pharmacy_Delete_Confirm_Msg")
                          placeholder:nil
                        confirmButton:kLang(@"Delete")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Deleting") subtitle:nil];
        [[PPVetManager sharedManager] deleteMedicine:self.medicine completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                if (error) {
                    [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                    return;
                }
                [PPHUD showSuccess:kLang(@"Deleted") subtitle:nil];
                if (self.onUpdated) self.onUpdated();
                [self.navigationController popViewControllerAnimated:YES];
            });
        }];
    } cancelBlock:nil];
}

@end

#pragma mark - 3. Medicine Card Table Cell (PPPharmacyMedicineCardCell)

@interface PPPharmacyMedicineCardCell : UITableViewCell
@property (nonatomic, strong) UIView *cardSurface;
@property (nonatomic, strong) UIImageView *medicineImageView;
@property (nonatomic, strong) UIView *inImageBadge;
@property (nonatomic, strong) UILabel *inImageBadgeLabel;
@property (nonatomic, strong) UIView *categoryPill;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *animalsSnippetLabel;

@property (nonatomic, strong) UIButton *stockPillButton;
@property (nonatomic, strong) UIButton *visibilityPillButton;
@property (nonatomic, strong) UIButton *detailsPillButton;

@property (nonatomic, strong) PPVetMedicineModel *medicine;
@property (nonatomic, copy, nullable) void (^onQuickStockTapped)(void);
@property (nonatomic, copy, nullable) void (^onVisibilityToggled)(void);
@property (nonatomic, copy, nullable) void (^onDetailsTapped)(void);
@end

@implementation PPPharmacyMedicineCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self setupCard];
    }
    return self;
}

- (void)setupCard {
    _cardSurface = [[UIView alloc] init];
    _cardSurface.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurface.backgroundColor = [UIColor ppSurfaceElevated];
    _cardSurface.layer.borderWidth = 1.0;
    _cardSurface.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_cardSurface, PPCornerCard);
    PPApplyCardShadow(_cardSurface);
    [self.contentView addSubview:_cardSurface];
    
    // Thumbnail Image
    _medicineImageView = [[UIImageView alloc] init];
    _medicineImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _medicineImageView.contentMode = UIViewContentModeScaleAspectFill;
    _medicineImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_medicineImageView, PPCornerSmall);
    _medicineImageView.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.06];
    [_cardSurface addSubview:_medicineImageView];
    
    // In-Image Stock Badge
    _inImageBadge = [[UIView alloc] init];
    _inImageBadge.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_inImageBadge, 6);
    [_cardSurface addSubview:_inImageBadge];
    
    _inImageBadgeLabel = [[UILabel alloc] init];
    _inImageBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _inImageBadgeLabel.font = [Styling fontBold:10.0];
    _inImageBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [_inImageBadge addSubview:_inImageBadgeLabel];
    
    // Category Capsule
    _categoryPill = [[UIView alloc] init];
    _categoryPill.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryPill.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(_categoryPill, PPCornerPill);
    [_cardSurface addSubview:_categoryPill];
    
    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [Styling fontBold:11.0];
    _categoryLabel.textColor = [UIColor ppPrimary];
    [_categoryPill addSubview:_categoryLabel];
    
    // Live Glowing Status Dot
    _statusDot = [[UIView alloc] init];
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(_statusDot, 4);
    [_cardSurface addSubview:_statusDot];
    
    // Title Label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [Styling fontBold:16.5];
    _titleLabel.textColor = [UIColor ppTextPrimary];
    _titleLabel.numberOfLines = 2;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_titleLabel];
    
    // Target Animals Snippet
    _animalsSnippetLabel = [[UILabel alloc] init];
    _animalsSnippetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _animalsSnippetLabel.font = [Styling fontMedium:12.0];
    _animalsSnippetLabel.textColor = [UIColor ppTextTertiary];
    _animalsSnippetLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_animalsSnippetLabel];
    
    // Price Label
    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    _priceLabel.textColor = [UIColor ppPrimary];
    _priceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_cardSurface addSubview:_priceLabel];
    
    // Divider
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5];
    [_cardSurface addSubview:divider];
    
    // Interactive Quick Actions Row
    _stockPillButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _stockPillButton.translatesAutoresizingMaskIntoConstraints = NO;
    _stockPillButton.backgroundColor = [UIColor ppSurface];
    _stockPillButton.layer.borderWidth = 0.8;
    _stockPillButton.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _stockPillButton.titleLabel.font = [Styling fontBold:12.0];
    [_stockPillButton setTitleColor:[UIColor ppTextPrimary] forState:UIControlStateNormal];
    PPApplyContinuousCorners(_stockPillButton, PPCornerSmall);
    [_stockPillButton addTarget:self action:@selector(stockTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardSurface addSubview:_stockPillButton];
    
    _visibilityPillButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _visibilityPillButton.translatesAutoresizingMaskIntoConstraints = NO;
    _visibilityPillButton.backgroundColor = [UIColor ppSurface];
    _visibilityPillButton.layer.borderWidth = 0.8;
    _visibilityPillButton.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _visibilityPillButton.titleLabel.font = [Styling fontBold:12.0];
    PPApplyContinuousCorners(_visibilityPillButton, PPCornerSmall);
    [_visibilityPillButton addTarget:self action:@selector(visibilityTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardSurface addSubview:_visibilityPillButton];
    
    _detailsPillButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _detailsPillButton.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsPillButton.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    _detailsPillButton.titleLabel.font = [Styling fontBold:12.0];
    [_detailsPillButton setTitle:[Language isRTL] ? @"تفاصيل" : @"Details" forState:UIControlStateNormal];
    [_detailsPillButton setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
    PPApplyContinuousCorners(_detailsPillButton, PPCornerSmall);
    [_detailsPillButton addTarget:self action:@selector(detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardSurface addSubview:_detailsPillButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_cardSurface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [_cardSurface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_cardSurface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_cardSurface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        
        [_medicineImageView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:14],
        [_medicineImageView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:14],
        [_medicineImageView.widthAnchor constraintEqualToConstant:90],
        [_medicineImageView.heightAnchor constraintEqualToConstant:90],
        
        [_inImageBadge.bottomAnchor constraintEqualToAnchor:_medicineImageView.bottomAnchor constant:-4],
        [_inImageBadge.leadingAnchor constraintEqualToAnchor:_medicineImageView.leadingAnchor constant:4],
        [_inImageBadge.trailingAnchor constraintEqualToAnchor:_medicineImageView.trailingAnchor constant:-4],
        [_inImageBadge.heightAnchor constraintEqualToConstant:20],
        
        [_inImageBadgeLabel.topAnchor constraintEqualToAnchor:_inImageBadge.topAnchor],
        [_inImageBadgeLabel.bottomAnchor constraintEqualToAnchor:_inImageBadge.bottomAnchor],
        [_inImageBadgeLabel.leadingAnchor constraintEqualToAnchor:_inImageBadge.leadingAnchor constant:2],
        [_inImageBadgeLabel.trailingAnchor constraintEqualToAnchor:_inImageBadge.trailingAnchor constant:-2],
        
        [_categoryPill.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:14],
        [_categoryPill.leadingAnchor constraintEqualToAnchor:_medicineImageView.trailingAnchor constant:12],
        [_categoryPill.heightAnchor constraintEqualToConstant:22],
        
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_categoryPill.leadingAnchor constant:8],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_categoryPill.trailingAnchor constant:-8],
        [_categoryLabel.centerYAnchor constraintEqualToAnchor:_categoryPill.centerYAnchor],
        
        [_statusDot.centerYAnchor constraintEqualToAnchor:_categoryPill.centerYAnchor],
        [_statusDot.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        [_statusDot.widthAnchor constraintEqualToConstant:8],
        [_statusDot.heightAnchor constraintEqualToConstant:8],
        
        [_titleLabel.topAnchor constraintEqualToAnchor:_categoryPill.bottomAnchor constant:6],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_categoryPill.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        
        [_animalsSnippetLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_animalsSnippetLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_animalsSnippetLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        
        [_priceLabel.topAnchor constraintEqualToAnchor:_animalsSnippetLabel.bottomAnchor constant:6],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        
        [divider.topAnchor constraintEqualToAnchor:_medicineImageView.bottomAnchor constant:14],
        [divider.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:14],
        [divider.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        [divider.heightAnchor constraintEqualToConstant:0.8],
        
        [_stockPillButton.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:10],
        [_stockPillButton.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:14],
        [_stockPillButton.heightAnchor constraintEqualToConstant:36],
        [_stockPillButton.bottomAnchor constraintEqualToAnchor:_cardSurface.bottomAnchor constant:-12],
        
        [_visibilityPillButton.centerYAnchor constraintEqualToAnchor:_stockPillButton.centerYAnchor],
        [_visibilityPillButton.leadingAnchor constraintEqualToAnchor:_stockPillButton.trailingAnchor constant:8],
        [_visibilityPillButton.heightAnchor constraintEqualToConstant:36],
        [_visibilityPillButton.widthAnchor constraintEqualToAnchor:_stockPillButton.widthAnchor],
        
        [_detailsPillButton.centerYAnchor constraintEqualToAnchor:_stockPillButton.centerYAnchor],
        [_detailsPillButton.leadingAnchor constraintEqualToAnchor:_visibilityPillButton.trailingAnchor constant:8],
        [_detailsPillButton.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-14],
        [_detailsPillButton.heightAnchor constraintEqualToConstant:36],
        [_detailsPillButton.widthAnchor constraintEqualToAnchor:_stockPillButton.widthAnchor]
    ]];
}

- (void)configureWithMedicine:(PPVetMedicineModel *)medicine {
    _medicine = medicine;
    
    _titleLabel.text = medicine.title.length ? medicine.title : @"—";
    _categoryLabel.text = medicine.category.length ? medicine.category : kLang(@"Pharmacy_Category_Other");
    _priceLabel.text = [NSString stringWithFormat:@"%.2f %@", medicine.price, medicine.currency ?: @"QAR"];
    
    if (medicine.imageUrl.length > 0) {
        [_medicineImageView sd_setImageWithURL:[NSURL URLWithString:medicine.imageUrl]
                              placeholderImage:[UIImage systemImageNamed:@"pills.fill"]];
    } else {
        _medicineImageView.image = [UIImage systemImageNamed:@"pills.fill"];
        _medicineImageView.tintColor = [UIColor ppPrimary];
    }
    
    // In-Image Stock Badge
    if (medicine.stockQuantity == 0) {
        _inImageBadge.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.88];
        _inImageBadgeLabel.textColor = UIColor.whiteColor;
        _inImageBadgeLabel.text = [Language isRTL] ? @"نفد" : @"0 Stock";
    } else if (medicine.stockQuantity <= 5) {
        _inImageBadge.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.92];
        _inImageBadgeLabel.textColor = UIColor.blackColor;
        _inImageBadgeLabel.text = [NSString stringWithFormat:@"%@: %ld", [Language isRTL] ? @"حرج" : @"Low", (long)medicine.stockQuantity];
    } else {
        _inImageBadge.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.88];
        _inImageBadgeLabel.textColor = UIColor.whiteColor;
        _inImageBadgeLabel.text = [NSString stringWithFormat:@"%@: %ld", [Language isRTL] ? @"متوفر" : @"In Stock", (long)medicine.stockQuantity];
    }
    
    // Status Dot
    BOOL isLive = medicine.isAvailable && (medicine.stockQuantity > 0) && medicine.isPublished && !medicine.isDisabled;
    _statusDot.backgroundColor = isLive ? [UIColor ppSuccess] : [UIColor ppError];
    
    // Animals snippet
    if (medicine.animalTypes.count > 0) {
        _animalsSnippetLabel.text = [NSString stringWithFormat:@"🐾 %@", [medicine.animalTypes componentsJoinedByString:@" · "]];
        _animalsSnippetLabel.hidden = NO;
    } else {
        _animalsSnippetLabel.hidden = YES;
    }
    
    // Action Buttons
    NSString *stockTitle = [NSString stringWithFormat:@"📦 %ld %@", (long)MAX(0, medicine.stockQuantity), [Language isRTL] ? @"وحدة" : @"pcs"];
    [_stockPillButton setTitle:stockTitle forState:UIControlStateNormal];
    
    if (isLive) {
        [_visibilityPillButton setTitle:[Language isRTL] ? @"👁️ متاح" : @"👁️ Active" forState:UIControlStateNormal];
        [_visibilityPillButton setTitleColor:[UIColor ppSuccess] forState:UIControlStateNormal];
        _visibilityPillButton.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.08];
        _visibilityPillButton.layer.borderColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.25].CGColor;
    } else {
        [_visibilityPillButton setTitle:[Language isRTL] ? @"🙈 مخفي" : @"🙈 Hidden" forState:UIControlStateNormal];
        [_visibilityPillButton setTitleColor:[UIColor ppTextTertiary] forState:UIControlStateNormal];
        _visibilityPillButton.backgroundColor = [UIColor ppSurface];
        _visibilityPillButton.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    }
    
    _cardSurface.alpha = medicine.isDisabled ? 0.6 : 1.0;
}

- (void)stockTapped {
    if (self.onQuickStockTapped) self.onQuickStockTapped();
}

- (void)visibilityTapped {
    if (self.onVisibilityToggled) self.onVisibilityToggled();
}

- (void)detailsTapped {
    if (self.onDetailsTapped) self.onDetailsTapped();
}

@end

#pragma mark - 4. Main Reimagined Pharmacy Hub (PPPharmacyMedicinesViewController)

@interface PPPharmacyMedicinesViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPVetMedicineModel *> *allMedicines;
@property (nonatomic, strong) NSArray<PPVetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, assign) PPPharmacyFilterLens currentLens;
@property (nonatomic, copy, nullable) NSString *selectedCategoryName;

// Cockpit Metric Labels
@property (nonatomic, strong) UILabel *totalCountLabel;
@property (nonatomic, strong) UILabel *valuationLabel;
@property (nonatomic, strong) UILabel *availableCountLabel;
@property (nonatomic, strong) UILabel *lowStockCountLabel;

// Header Controls
@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UILabel *searchResultBadge;
@property (nonatomic, strong) UIButton *clearSearchButton;
@property (nonatomic, strong) UIScrollView *filterScrollView;
@property (nonatomic, strong) UIStackView *filterStackView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterButtons;

// State Views
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation PPPharmacyMedicinesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    self.allMedicines = @[];
    self.filteredMedicines = @[];
    self.currentLens = PPPharmacyFilterLensAll;
    self.filterButtons = [NSMutableArray array];
    
    [self setupNavigation];
    [self setupTableView];
    [self setupTableHeader];
    [self setupEmptyState];
    
    [self pp_reloadMedicines];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigation];
}

- (void)setupNavigation {
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:kLang(@"Pharmacy_Section_Title")
                    showBack:YES];
    
    // Add Button in Top Bar (Red Circle 44x44)
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addBtn.translatesAutoresizingMaskIntoConstraints = NO;
    addBtn.backgroundColor = [UIColor ppPrimary];
    [addBtn setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    addBtn.tintColor = UIColor.whiteColor;
    PPApplyContinuousCorners(addBtn, 22.0);
    PPApplyButtonShadow(addBtn);
    [addBtn addTarget:self action:@selector(addMedicineTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [NSLayoutConstraint activateConstraints:@[
        [addBtn.widthAnchor constraintEqualToConstant:44.0],
        [addBtn.heightAnchor constraintEqualToConstant:44.0]
    ]];
    [self pp_navBarAddActionButton:addBtn key:@"pharma_add"];
    
    // Refresh Button in Top Bar
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
    refreshBtn.backgroundColor = [[UIColor ppSurface] colorWithAlphaComponent:0.8];
    refreshBtn.layer.borderWidth = 1.0;
    refreshBtn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    [refreshBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    refreshBtn.tintColor = [UIColor ppTextPrimary];
    PPApplyContinuousCorners(refreshBtn, 22.0);
    [refreshBtn addTarget:self action:@selector(pp_reloadMedicines) forControlEvents:UIControlEventTouchUpInside];
    
    [NSLayoutConstraint activateConstraints:@[
        [refreshBtn.widthAnchor constraintEqualToConstant:44.0],
        [refreshBtn.heightAnchor constraintEqualToConstant:44.0]
    ]];
    [self pp_navBarAddActionButton:refreshBtn key:@"pharma_refresh"];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.estimatedRowHeight = 200;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _tableView.contentInset = UIEdgeInsetsMake(8, 0, 100, 0);
    [_tableView registerClass:[PPPharmacyMedicineCardCell class] forCellReuseIdentifier:@"PharmaCardCell"];
    [self.view addSubview:_tableView];
    
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = [UIColor ppPrimary];
    [refresh addTarget:self action:@selector(pp_reloadMedicines) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _spinner.center = self.view.center;
    _spinner.color = [UIColor ppPrimary];
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];
}

- (void)setupTableHeader {
    _tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 360)];
    _tableHeaderView.backgroundColor = UIColor.clearColor;
    
    // 1. Cockpit Card
    UIView *cockpitCard = [[UIView alloc] init];
    cockpitCard.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitCard.backgroundColor = [UIColor ppSurfaceElevated];
    cockpitCard.layer.borderWidth = 1.0;
    cockpitCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(cockpitCard, PPCornerCard);
    PPApplyCardShadow(cockpitCard);
    [_tableHeaderView addSubview:cockpitCard];
    
    UILabel *cockpitTitle = [[UILabel alloc] init];
    cockpitTitle.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitTitle.text = kLang(@"Pharmacy_Section_Title");
    cockpitTitle.font = [Styling fontBold:20.0];
    cockpitTitle.textColor = [UIColor ppTextPrimary];
    cockpitTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [cockpitCard addSubview:cockpitTitle];
    
    UILabel *cockpitSubtitle = [[UILabel alloc] init];
    cockpitSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    cockpitSubtitle.text = kLang(@"Pharmacy_Manage_Subtitle");
    cockpitSubtitle.font = [Styling fontMedium:12.5];
    cockpitSubtitle.textColor = [UIColor ppTextSecondary];
    cockpitSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    [cockpitCard addSubview:cockpitSubtitle];
    
    // 4 KPI Tiles Grid (2 Rows x 2 Cols)
    UIStackView *gridStack = [[UIStackView alloc] init];
    gridStack.translatesAutoresizingMaskIntoConstraints = NO;
    gridStack.axis = UILayoutConstraintAxisVertical;
    gridStack.spacing = 8;
    gridStack.distribution = UIStackViewDistributionFillEqually;
    [cockpitCard addSubview:gridStack];
    
    UIStackView *row1 = [[UIStackView alloc] init];
    row1.axis = UILayoutConstraintAxisHorizontal;
    row1.spacing = 8;
    row1.distribution = UIStackViewDistributionFillEqually;
    
    self.totalCountLabel = [[UILabel alloc] init];
    UIView *tile1 = [self makeKpiTileWithTitle:[Language isRTL] ? @"إجمالي الأدوية" : @"Total Medicines"
                                     valueLabel:self.totalCountLabel
                                       iconName:@"pills.fill"
                                     tintColor:[UIColor ppPrimary]];
    [row1 addArrangedSubview:tile1];
    
    self.valuationLabel = [[UILabel alloc] init];
    UIView *tile2 = [self makeKpiTileWithTitle:[Language isRTL] ? @"قيمة الصيدلية" : @"Total Value"
                                     valueLabel:self.valuationLabel
                                       iconName:@"chart.line.uptrend.xyaxis"
                                     tintColor:[UIColor ppSuccess]];
    [row1 addArrangedSubview:tile2];
    [gridStack addArrangedSubview:row1];
    
    UIStackView *row2 = [[UIStackView alloc] init];
    row2.axis = UILayoutConstraintAxisHorizontal;
    row2.spacing = 8;
    row2.distribution = UIStackViewDistributionFillEqually;
    
    self.availableCountLabel = [[UILabel alloc] init];
    UIView *tile3 = [self makeKpiTileWithTitle:[Language isRTL] ? @"متاح للطلب" : @"In Stock"
                                     valueLabel:self.availableCountLabel
                                       iconName:@"checkmark.seal.fill"
                                     tintColor:[UIColor ppAccent]];
    [row2 addArrangedSubview:tile3];
    
    self.lowStockCountLabel = [[UILabel alloc] init];
    UIView *tile4 = [self makeKpiTileWithTitle:[Language isRTL] ? @"تنبيه النواقص" : @"Low Stock"
                                     valueLabel:self.lowStockCountLabel
                                       iconName:@"exclamationmark.triangle.fill"
                                     tintColor:[UIColor ppWarning]];
    [row2 addArrangedSubview:tile4];
    [gridStack addArrangedSubview:row2];
    
    // 2. Omni-Search Bar
    UIView *searchBarBox = [[UIView alloc] init];
    searchBarBox.translatesAutoresizingMaskIntoConstraints = NO;
    searchBarBox.backgroundColor = [UIColor ppSurface];
    searchBarBox.layer.borderWidth = 1.0;
    searchBarBox.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(searchBarBox, PPCornerMedium);
    [_tableHeaderView addSubview:searchBarBox];
    
    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppTextTertiary];
    [searchBarBox addSubview:searchIcon];
    
    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholder = kLang(@"Pharmacy_Search_Placeholder");
    _searchField.font = [Styling fontMedium:14.5];
    _searchField.textColor = [UIColor ppTextPrimary];
    _searchField.textAlignment = Language.alignmentForCurrentLanguage;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.delegate = self;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [searchBarBox addSubview:_searchField];
    
    _clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_clearSearchButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    _clearSearchButton.tintColor = [UIColor ppTextTertiary];
    _clearSearchButton.hidden = YES;
    [_clearSearchButton addTarget:self action:@selector(clearSearch) forControlEvents:UIControlEventTouchUpInside];
    [searchBarBox addSubview:_clearSearchButton];
    
    _searchResultBadge = [[UILabel alloc] init];
    _searchResultBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _searchResultBadge.font = [Styling fontBold:11.5];
    _searchResultBadge.textColor = [UIColor ppPrimary];
    _searchResultBadge.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.1];
    _searchResultBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(_searchResultBadge, PPCornerPill);
    [searchBarBox addSubview:_searchResultBadge];
    
    // 3. Filter Rail
    _filterScrollView = [[UIScrollView alloc] init];
    _filterScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterScrollView.showsHorizontalScrollIndicator = NO;
    _filterScrollView.alwaysBounceHorizontal = YES;
    [_tableHeaderView addSubview:_filterScrollView];
    
    _filterStackView = [[UIStackView alloc] init];
    _filterStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterStackView.axis = UILayoutConstraintAxisHorizontal;
    _filterStackView.spacing = 8;
    _filterStackView.alignment = UIStackViewAlignmentCenter;
    [_filterScrollView addSubview:_filterStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [cockpitCard.topAnchor constraintEqualToAnchor:_tableHeaderView.topAnchor constant:12],
        [cockpitCard.leadingAnchor constraintEqualToAnchor:_tableHeaderView.leadingAnchor constant:16],
        [cockpitCard.trailingAnchor constraintEqualToAnchor:_tableHeaderView.trailingAnchor constant:-16],
        [cockpitCard.heightAnchor constraintEqualToConstant:200],
        
        [cockpitTitle.topAnchor constraintEqualToAnchor:cockpitCard.topAnchor constant:14],
        [cockpitTitle.leadingAnchor constraintEqualToAnchor:cockpitCard.leadingAnchor constant:16],
        [cockpitTitle.trailingAnchor constraintEqualToAnchor:cockpitCard.trailingAnchor constant:-16],
        
        [cockpitSubtitle.topAnchor constraintEqualToAnchor:cockpitTitle.bottomAnchor constant:3],
        [cockpitSubtitle.leadingAnchor constraintEqualToAnchor:cockpitCard.leadingAnchor constant:16],
        [cockpitSubtitle.trailingAnchor constraintEqualToAnchor:cockpitCard.trailingAnchor constant:-16],
        
        [gridStack.topAnchor constraintEqualToAnchor:cockpitSubtitle.bottomAnchor constant:12],
        [gridStack.leadingAnchor constraintEqualToAnchor:cockpitCard.leadingAnchor constant:12],
        [gridStack.trailingAnchor constraintEqualToAnchor:cockpitCard.trailingAnchor constant:-12],
        [gridStack.bottomAnchor constraintEqualToAnchor:cockpitCard.bottomAnchor constant:-12],
        
        [searchBarBox.topAnchor constraintEqualToAnchor:cockpitCard.bottomAnchor constant:12],
        [searchBarBox.leadingAnchor constraintEqualToAnchor:_tableHeaderView.leadingAnchor constant:16],
        [searchBarBox.trailingAnchor constraintEqualToAnchor:_tableHeaderView.trailingAnchor constant:-16],
        [searchBarBox.heightAnchor constraintEqualToConstant:48],
        
        [searchIcon.leadingAnchor constraintEqualToAnchor:searchBarBox.leadingAnchor constant:14],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchBarBox.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:20],
        [searchIcon.heightAnchor constraintEqualToConstant:20],
        
        [_searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:10],
        [_searchField.trailingAnchor constraintEqualToAnchor:_clearSearchButton.leadingAnchor constant:-8],
        [_searchField.topAnchor constraintEqualToAnchor:searchBarBox.topAnchor],
        [_searchField.bottomAnchor constraintEqualToAnchor:searchBarBox.bottomAnchor],
        
        [_clearSearchButton.trailingAnchor constraintEqualToAnchor:_searchResultBadge.leadingAnchor constant:-6],
        [_clearSearchButton.centerYAnchor constraintEqualToAnchor:searchBarBox.centerYAnchor],
        [_clearSearchButton.widthAnchor constraintEqualToConstant:24],
        [_clearSearchButton.heightAnchor constraintEqualToConstant:24],
        
        [_searchResultBadge.trailingAnchor constraintEqualToAnchor:searchBarBox.trailingAnchor constant:-12],
        [_searchResultBadge.centerYAnchor constraintEqualToAnchor:searchBarBox.centerYAnchor],
        [_searchResultBadge.heightAnchor constraintEqualToConstant:24],
        [_searchResultBadge.widthAnchor constraintGreaterThanOrEqualToConstant:40],
        
        [_filterScrollView.topAnchor constraintEqualToAnchor:searchBarBox.bottomAnchor constant:10],
        [_filterScrollView.leadingAnchor constraintEqualToAnchor:_tableHeaderView.leadingAnchor],
        [_filterScrollView.trailingAnchor constraintEqualToAnchor:_tableHeaderView.trailingAnchor],
        [_filterScrollView.heightAnchor constraintEqualToConstant:44],
        
        [_filterStackView.topAnchor constraintEqualToAnchor:_filterScrollView.topAnchor],
        [_filterStackView.leadingAnchor constraintEqualToAnchor:_filterScrollView.leadingAnchor constant:16],
        [_filterStackView.trailingAnchor constraintEqualToAnchor:_filterScrollView.trailingAnchor constant:-16],
        [_filterStackView.bottomAnchor constraintEqualToAnchor:_filterScrollView.bottomAnchor],
        [_filterStackView.heightAnchor constraintEqualToAnchor:_filterScrollView.heightAnchor]
    ]];
    
    _tableView.tableHeaderView = _tableHeaderView;
}

- (UIView *)makeKpiTileWithTitle:(NSString *)title
                      valueLabel:(UILabel *)valueLabel
                        iconName:(NSString *)iconName
                       tintColor:(UIColor *)tintColor {
    UIView *tile = [[UIView alloc] init];
    tile.backgroundColor = [UIColor ppSurface];
    tile.layer.borderWidth = 0.8;
    tile.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(tile, PPCornerSmall);
    
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = tintColor;
    [tile addSubview:icon];
    
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = title;
    titleLbl.font = [Styling fontMedium:11.5];
    titleLbl.textColor = [UIColor ppTextSecondary];
    titleLbl.textAlignment = Language.alignmentForCurrentLanguage;
    [tile addSubview:titleLbl];
    
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = @"0";
    valueLabel.font = [Styling fontBold:16.0];
    valueLabel.textColor = [UIColor ppTextPrimary];
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [tile addSubview:valueLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:10],
        [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        
        [valueLabel.topAnchor constraintEqualToAnchor:tile.topAnchor constant:8],
        [valueLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:8],
        [valueLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-8],
        
        [titleLbl.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:1],
        [titleLbl.leadingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor],
        [titleLbl.trailingAnchor constraintEqualToAnchor:valueLabel.trailingAnchor]
    ]];
    return tile;
}

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] init];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];
    
    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"cross.case.fill"]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.25];
    emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    [_emptyStateView addSubview:emptyIcon];
    
    UILabel *emptyTitle = [[UILabel alloc] init];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.text = kLang(@"Pharmacy_Empty_Title");
    emptyTitle.font = [Styling fontBold:18.0];
    emptyTitle.textColor = [UIColor ppTextPrimary];
    emptyTitle.textAlignment = NSTextAlignmentCenter;
    [_emptyStateView addSubview:emptyTitle];
    
    UILabel *emptySub = [[UILabel alloc] init];
    emptySub.translatesAutoresizingMaskIntoConstraints = NO;
    emptySub.text = kLang(@"Pharmacy_Empty_List");
    emptySub.font = [Styling fontRegular:14.0];
    emptySub.textColor = [UIColor ppTextSecondary];
    emptySub.textAlignment = NSTextAlignmentCenter;
    emptySub.numberOfLines = 0;
    [_emptyStateView addSubview:emptySub];
    
    UIButton *addFirstBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addFirstBtn.translatesAutoresizingMaskIntoConstraints = NO;
    addFirstBtn.backgroundColor = [UIColor ppPrimary];
    [addFirstBtn setTitle:kLang(@"Pharmacy_Add_Title") forState:UIControlStateNormal];
    [addFirstBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    addFirstBtn.titleLabel.font = [Styling fontBold:15.0];
    PPApplyContinuousCorners(addFirstBtn, PPCornerMedium);
    PPApplyButtonShadow(addFirstBtn);
    [addFirstBtn addTarget:self action:@selector(addMedicineTapped) forControlEvents:UIControlEventTouchUpInside];
    [_emptyStateView addSubview:addFirstBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:80],
        [_emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [_emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
        
        [emptyIcon.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:64],
        [emptyIcon.heightAnchor constraintEqualToConstant:64],
        
        [emptyTitle.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:14],
        [emptyTitle.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [emptyTitle.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        
        [emptySub.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:6],
        [emptySub.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [emptySub.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        
        [addFirstBtn.topAnchor constraintEqualToAnchor:emptySub.bottomAnchor constant:18],
        [addFirstBtn.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [addFirstBtn.widthAnchor constraintEqualToConstant:160],
        [addFirstBtn.heightAnchor constraintEqualToConstant:46],
        [addFirstBtn.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor]
    ]];
}

#pragma mark - Data Loading & Filtering

- (NSString *)pp_currentPartnerUID {
    UserModel *user = UsrMgr.currentUser;
    if (user.uid.length > 0) return user.uid;
    if (user.ID.length > 0) return user.ID;
    return [FIRAuth auth].currentUser.uid ?: @"";
}

- (void)pp_reloadMedicines {
    NSString *uid = [self pp_currentPartnerUID];
    if (uid.length == 0) return;
    
    if (self.allMedicines.count == 0) {
        [self.spinner startAnimating];
    }
    
    __weak typeof(self) weakSelf = self;
    [[PPVetManager sharedManager] fetchMedicinesForUserID:uid completion:^(NSArray<PPVetMedicineModel *> * _Nullable medicines, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.tableView.refreshControl endRefreshing];
            [self.spinner stopAnimating];
            
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            
            self.allMedicines = [medicines sortedArrayUsingComparator:^NSComparisonResult(PPVetMedicineModel *a, PPVetMedicineModel *b) {
                return [PPSafeString(a.title) localizedCaseInsensitiveCompare:PPSafeString(b.title)];
            }];
            
            [self updateCockpitMetrics];
            [self rebuildFilterRail];
            [self applyFilter];
        });
    }];
}

- (void)updateCockpitMetrics {
    NSInteger total = self.allMedicines.count;
    double totalValuation = 0;
    NSInteger availableCount = 0;
    NSInteger lowStockCount = 0;
    
    for (PPVetMedicineModel *m in self.allMedicines) {
        totalValuation += (m.price * MAX(0, m.stockQuantity));
        if (m.isAvailable && m.stockQuantity > 0 && m.isPublished && !m.isDisabled) {
            availableCount++;
        }
        if (m.stockQuantity <= 5) {
            lowStockCount++;
        }
    }
    
    self.totalCountLabel.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.valuationLabel.text = [NSString stringWithFormat:@"%.0f %@", totalValuation, @"QAR"];
    self.availableCountLabel.text = [NSString stringWithFormat:@"%ld", (long)availableCount];
    self.lowStockCountLabel.text = [NSString stringWithFormat:@"%ld", (long)lowStockCount];
}

- (void)rebuildFilterRail {
    for (UIView *sub in self.filterStackView.arrangedSubviews) {
        [self.filterStackView removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }
    [self.filterButtons removeAllObjects];
    
    // Default system filters
    NSArray *defaultFilters = @[
        @{@"id": @(PPPharmacyFilterLensAll), @"title": [Language isRTL] ? @"الكل" : @"All"},
        @{@"id": @(PPPharmacyFilterLensLowStock), @"title": [Language isRTL] ? @"تنبيه النواقص" : @"Low Stock"},
        @{@"id": @(PPPharmacyFilterLensAvailable), @"title": [Language isRTL] ? @"متاح للطلب" : @"Available"},
        @{@"id": @(PPPharmacyFilterLensUnavailable), @"title": [Language isRTL] ? @"غير متاح" : @"Hidden"}
    ];
    
    for (NSDictionary *d in defaultFilters) {
        PPPharmacyFilterLens lens = [d[@"id"] integerValue];
        UIButton *btn = [self makeFilterChipWithTitle:d[@"title"] isSelected:(self.currentLens == lens && self.selectedCategoryName == nil)];
        btn.tag = lens;
        [btn addTarget:self action:@selector(filterChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.filterButtons addObject:btn];
        [self.filterStackView addArrangedSubview:btn];
    }
    
    // Dynamic Categories
    NSMutableSet<NSString *> *categorySet = [NSMutableSet set];
    for (PPVetMedicineModel *m in self.allMedicines) {
        if (m.category.length > 0) {
            [categorySet addObject:m.category];
        }
    }
    NSArray<NSString *> *sortedCategories = [categorySet.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *cat in sortedCategories) {
        BOOL isSelected = (self.currentLens == PPPharmacyFilterLensCategory && [self.selectedCategoryName isEqualToString:cat]);
        UIButton *btn = [self makeFilterChipWithTitle:cat isSelected:isSelected];
        btn.tag = PPPharmacyFilterLensCategory;
        objc_setAssociatedObject(btn, "CategoryNameKey", cat, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(categoryChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.filterButtons addObject:btn];
        [self.filterStackView addArrangedSubview:btn];
    }
}

- (UIButton *)makeFilterChipWithTitle:(NSString *)title isSelected:(BOOL)isSelected {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    btn.titleLabel.font = [Styling fontBold:13.0];
    [btn setTitle:title forState:UIControlStateNormal];
    PPApplyContinuousCorners(btn, PPCornerPill);
    
    if (isSelected) {
        btn.backgroundColor = [UIColor ppPrimary];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.layer.borderWidth = 0;
        PPApplyButtonShadow(btn);
    } else {
        btn.backgroundColor = [UIColor ppSurface];
        [btn setTitleColor:[UIColor ppTextSecondary] forState:UIControlStateNormal];
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
        btn.layer.shadowOpacity = 0;
    }
    return btn;
}

- (void)filterChipTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.currentLens = sender.tag;
    self.selectedCategoryName = nil;
    [self rebuildFilterRail];
    [self applyFilter];
}

- (void)categoryChipTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.currentLens = PPPharmacyFilterLensCategory;
    self.selectedCategoryName = objc_getAssociatedObject(sender, "CategoryNameKey");
    [self rebuildFilterRail];
    [self applyFilter];
}

- (void)applyFilter {
    NSString *query = [[PPSafeString(self.searchQuery) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(PPVetMedicineModel *med, NSDictionary *b) {
        // Lens filter
        if (self.currentLens == PPPharmacyFilterLensLowStock && med.stockQuantity > 5) {
            return NO;
        }
        if (self.currentLens == PPPharmacyFilterLensAvailable && !(med.isAvailable && med.stockQuantity > 0 && med.isPublished && !med.isDisabled)) {
            return NO;
        }
        if (self.currentLens == PPPharmacyFilterLensUnavailable && (med.isAvailable && med.stockQuantity > 0 && med.isPublished && !med.isDisabled)) {
            return NO;
        }
        if (self.currentLens == PPPharmacyFilterLensCategory && self.selectedCategoryName.length > 0) {
            if (![med.category isEqualToString:self.selectedCategoryName]) return NO;
        }
        
        // Search query filter
        if (query.length > 0) {
            NSString *haystack = [NSString stringWithFormat:@"%@ %@ %@", med.title, med.medicineDescription, med.category].lowercaseString;
            if (![haystack containsString:query]) return NO;
        }
        return YES;
    }];
    
    self.filteredMedicines = [self.allMedicines filteredArrayUsingPredicate:pred];
    self.searchResultBadge.text = [NSString stringWithFormat:@"%ld", (long)self.filteredMedicines.count];
    self.emptyStateView.hidden = (self.filteredMedicines.count > 0);
    
    [self.tableView reloadData];
}

- (void)searchChanged {
    self.searchQuery = self.searchField.text;
    self.clearSearchButton.hidden = (self.searchField.text.length == 0);
    [self applyFilter];
}

- (void)clearSearch {
    [PPFunc pp_playTapEffect];
    self.searchField.text = @"";
    [self searchChanged];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredMedicines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPPharmacyMedicineCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PharmaCardCell" forIndexPath:indexPath];
    PPVetMedicineModel *medicine = self.filteredMedicines[indexPath.row];
    [cell configureWithMedicine:medicine];
    
    __weak typeof(self) weakSelf = self;
    cell.onQuickStockTapped = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openQuickStockForMedicine:medicine];
    };
    
    cell.onVisibilityToggled = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self toggleVisibilityForMedicine:medicine];
    };
    
    cell.onDetailsTapped = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self openDetailForMedicine:medicine];
    };
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [PPFunc pp_playTapEffect];
    PPVetMedicineModel *medicine = self.filteredMedicines[indexPath.row];
    [self openDetailForMedicine:medicine];
}

#pragma mark - Navigation & Actions

- (void)addMedicineTapped {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPPharmacyMedicineEditorViewController *editor = [[PPPharmacyMedicineEditorViewController alloc] initWithMedicine:nil completion:^(PPVetMedicineModel *newMedicine, UIImage * _Nullable image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Please wait") subtitle:nil];
        [[PPVetManager sharedManager] addMedicine:newMedicine image:image completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                if (error) {
                    [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                    return;
                }
                [PPHUD showSuccess:kLang(@"Updated") subtitle:kLang(@"Pharmacy_Added_Success")];
                [self.navigationController popViewControllerAnimated:YES];
                [self pp_reloadMedicines];
            });
        }];
    }];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)openDetailForMedicine:(PPVetMedicineModel *)medicine {
    __weak typeof(self) weakSelf = self;
    PPPharmacyMedicineDetailViewController *detail = [[PPPharmacyMedicineDetailViewController alloc] initWithMedicine:medicine onUpdated:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_reloadMedicines];
    }];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)openQuickStockForMedicine:(PPVetMedicineModel *)medicine {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPPharmacyQuickStockSheet *sheet = [[PPPharmacyQuickStockSheet alloc] initWithMedicine:medicine onUpdated:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_reloadMedicines];
    }];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleVisibilityForMedicine:(PPVetMedicineModel *)medicine {
    [PPFunc pp_playTapEffect];
    
    // Toggle state optimistically
    medicine.isAvailable = !medicine.isAvailable;
    medicine.isPublished = medicine.isAvailable;
    [self.tableView reloadData];
    
    __weak typeof(self) weakSelf = self;
    [[PPVetManager sharedManager] updateMedicine:medicine image:nil completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error) {
                // Revert on error
                medicine.isAvailable = !medicine.isAvailable;
                medicine.isPublished = medicine.isAvailable;
                [self.tableView reloadData];
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            [self updateCockpitMetrics];
        });
    }];
}

@end
