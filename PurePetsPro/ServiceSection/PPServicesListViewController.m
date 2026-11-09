//
//  PPServicesListViewController.m
//  PurePetsPro
//
//  NextGen V8 Category-Defining Pet Service Command Center.
//  First-principles reinvention: Dual-Stage Horizon (Service Atelier & Live Floor Pipeline),
//  Master Duty & Availability Island, Stepped Micro-Pricing Engine, and
//  Glanceable Operating Matrix.
//

#import "PPServicesListViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPServiceCell.h"
#import "PPAddEditServiceViewController.h"
#import "PPServiceDetailViewController.h"
#import "PPServiceSubscriptionViewController.h"
#import "PPServiceRequestsViewController.h"
#import "PPServiceScheduleViewController.h"
#import "PPServiceTemplatePickerViewController.h"
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
#import <objc/runtime.h>

#pragma mark - PPServiceQuickPricingSheet (NextGen V8 Rotary Stepper)

@interface PPServiceQuickPricingSheet () <UITextFieldDelegate>
@property (nonatomic, strong) PPServiceModel *service;
@property (nonatomic, copy, nullable) void(^onUpdated)(void);
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *priceDisplayLabel;
@property (nonatomic, strong) UITextField *directInputField;
@property (nonatomic, strong) UILabel *yieldProjectionLabel;
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
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self setupSheetUI];
    [self updatePriceDisplay];
}

- (void)setupSheetUI {
    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor ppSeparator];
    grabber.layer.cornerRadius = 2.5;
    [self.view addSubview:grabber];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:38],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [scroll.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];

    // 1. Header Card with Pet Thumbnail & Title
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(card, 16.0);
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    [content addSubview:card];

    _thumbnailView = [[UIImageView alloc] init];
    _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailView.clipsToBounds = YES;
    PPApplyContinuousCorners(_thumbnailView, 12.0);
    _thumbnailView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    if (self.service.imageURL.length > 0) {
        [_thumbnailView sd_setImageWithURL:[NSURL URLWithString:self.service.imageURL]
                          placeholderImage:[UIImage imageNamed:@"placeholder_service"]];
    } else {
        _thumbnailView.image = [UIImage imageNamed:@"placeholder_service"];
    }
    [card addSubview:_thumbnailView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = self.service.title ?: @"—";
    _titleLabel.font = [Styling fontBold:16.0];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:_titleLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.text = [self.service localizedTypeName];
    _categoryLabel.font = [Styling fontMedium:12.5];
    _categoryLabel.textColor = SeconderyTextClr;
    _categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:_categoryLabel];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:content.topAnchor constant:8],
        [card.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [card.heightAnchor constraintEqualToConstant:76],

        [_thumbnailView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [_thumbnailView.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [_thumbnailView.widthAnchor constraintEqualToConstant:52],
        [_thumbnailView.heightAnchor constraintEqualToConstant:52],

        [_titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],

        [_categoryLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor]
    ]];

    // 2. Stepped Price Adjuster Pod
    UIView *pricePod = [[UIView alloc] init];
    pricePod.translatesAutoresizingMaskIntoConstraints = NO;
    pricePod.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(pricePod, 18.0);
    pricePod.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    pricePod.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    [content addSubview:pricePod];

    UILabel *podTitle = [[UILabel alloc] init];
    podTitle.translatesAutoresizingMaskIntoConstraints = NO;
    podTitle.text = [Language isRTL] ? @"تسعير الخدمة الفوري" : @"Instant Service Pricing";
    podTitle.font = [Styling fontBold:14.0];
    podTitle.textColor = PrimaryTextClr;
    podTitle.textAlignment = NSTextAlignmentCenter;
    [pricePod addSubview:podTitle];

    _priceDisplayLabel = [[UILabel alloc] init];
    _priceDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceDisplayLabel.font = [Styling fontBold:32.0];
    _priceDisplayLabel.textColor = [UIColor ppSuccess];
    _priceDisplayLabel.textAlignment = NSTextAlignmentCenter;
    [pricePod addSubview:_priceDisplayLabel];

    _yieldProjectionLabel = [[UILabel alloc] init];
    _yieldProjectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _yieldProjectionLabel.font = [Styling fontMedium:12.0];
    _yieldProjectionLabel.textColor = SeconderyTextClr;
    _yieldProjectionLabel.textAlignment = NSTextAlignmentCenter;
    [pricePod addSubview:_yieldProjectionLabel];

    // Stepper Increments Stack: -50, -10, +10, +50
    UIStackView *stepStack = [[UIStackView alloc] init];
    stepStack.translatesAutoresizingMaskIntoConstraints = NO;
    stepStack.axis = UILayoutConstraintAxisHorizontal;
    stepStack.distribution = UIStackViewDistributionFillEqually;
    stepStack.spacing = 10.0;
    [pricePod addSubview:stepStack];

    NSArray *steps = @[@(-50), @(-10), @(10), @(50)];
    for (NSNumber *delta in steps) {
        UIButton *stepBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        stepBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(stepBtn, 12.0);
        stepBtn.layer.borderWidth = 0.5;
        stepBtn.layer.borderColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.2].CGColor;
        NSString *title = [delta integerValue] > 0
            ? [NSString stringWithFormat:@"+%ld", (long)[delta integerValue]]
            : [NSString stringWithFormat:@"%ld", (long)[delta integerValue]];
        [stepBtn setTitle:title forState:UIControlStateNormal];
        [stepBtn setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
        stepBtn.titleLabel.font = [Styling fontBold:14.0];
        objc_setAssociatedObject(stepBtn, "step_delta", delta, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [stepBtn addTarget:self action:@selector(stepButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stepStack addArrangedSubview:stepBtn];
    }

    // Direct Input Field
    _directInputField = [[UITextField alloc] init];
    _directInputField.translatesAutoresizingMaskIntoConstraints = NO;
    _directInputField.font = [Styling fontBold:15.0];
    _directInputField.textColor = PrimaryTextClr;
    _directInputField.textAlignment = NSTextAlignmentCenter;
    _directInputField.keyboardType = UIKeyboardTypeDecimalPad;
    _directInputField.placeholder = [Language isRTL] ? @"أو أدخل السعر مباشرة..." : @"Or enter custom price...";
    _directInputField.backgroundColor = [[UIColor ppBackground] colorWithAlphaComponent:0.8];
    PPApplyContinuousCorners(_directInputField, 12.0);
    _directInputField.layer.borderWidth = 0.5;
    _directInputField.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    _directInputField.delegate = self;
    [_directInputField addTarget:self action:@selector(directInputChanged) forControlEvents:UIControlEventEditingChanged];
    [pricePod addSubview:_directInputField];

    [NSLayoutConstraint activateConstraints:@[
        [pricePod.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:14],
        [pricePod.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [pricePod.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],

        [podTitle.topAnchor constraintEqualToAnchor:pricePod.topAnchor constant:16],
        [podTitle.centerXAnchor constraintEqualToAnchor:pricePod.centerXAnchor],

        [_priceDisplayLabel.topAnchor constraintEqualToAnchor:podTitle.bottomAnchor constant:8],
        [_priceDisplayLabel.centerXAnchor constraintEqualToAnchor:pricePod.centerXAnchor],

        [_yieldProjectionLabel.topAnchor constraintEqualToAnchor:_priceDisplayLabel.bottomAnchor constant:4],
        [_yieldProjectionLabel.centerXAnchor constraintEqualToAnchor:pricePod.centerXAnchor],

        [stepStack.topAnchor constraintEqualToAnchor:_yieldProjectionLabel.bottomAnchor constant:16],
        [stepStack.leadingAnchor constraintEqualToAnchor:pricePod.leadingAnchor constant:14],
        [stepStack.trailingAnchor constraintEqualToAnchor:pricePod.trailingAnchor constant:-14],
        [stepStack.heightAnchor constraintEqualToConstant:42],

        [_directInputField.topAnchor constraintEqualToAnchor:stepStack.bottomAnchor constant:12],
        [_directInputField.leadingAnchor constraintEqualToAnchor:pricePod.leadingAnchor constant:14],
        [_directInputField.trailingAnchor constraintEqualToAnchor:pricePod.trailingAnchor constant:-14],
        [_directInputField.heightAnchor constraintEqualToConstant:40],
        [_directInputField.bottomAnchor constraintEqualToAnchor:pricePod.bottomAnchor constant:-16]
    ]];

    // 3. Availability Row
    UIView *availCard = [[UIView alloc] init];
    availCard.translatesAutoresizingMaskIntoConstraints = NO;
    availCard.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(availCard, 16.0);
    availCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    availCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    [content addSubview:availCard];

    UILabel *availTitle = [[UILabel alloc] init];
    availTitle.translatesAutoresizingMaskIntoConstraints = NO;
    availTitle.text = [Language isRTL] ? @"إتاحة هذه الخدمة للطلب الفوري" : @"Offer Live for Instant Booking";
    availTitle.font = [Styling fontBold:14.0];
    availTitle.textColor = PrimaryTextClr;
    availTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [availCard addSubview:availTitle];

    _availabilitySwitch = [[UISwitch alloc] init];
    _availabilitySwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _availabilitySwitch.onTintColor = [UIColor ppSuccess];
    _availabilitySwitch.on = self.service.isAvailable;
    [availCard addSubview:_availabilitySwitch];

    [NSLayoutConstraint activateConstraints:@[
        [availCard.topAnchor constraintEqualToAnchor:pricePod.bottomAnchor constant:12],
        [availCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [availCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [availCard.heightAnchor constraintEqualToConstant:54],

        [availTitle.leadingAnchor constraintEqualToAnchor:availCard.leadingAnchor constant:14],
        [availTitle.centerYAnchor constraintEqualToAnchor:availCard.centerYAnchor],
        [availTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_availabilitySwitch.leadingAnchor constant:-10],

        [_availabilitySwitch.trailingAnchor constraintEqualToAnchor:availCard.trailingAnchor constant:-14],
        [_availabilitySwitch.centerYAnchor constraintEqualToAnchor:availCard.centerYAnchor]
    ]];

    // 4. Save Button
    _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(_saveButton, 16.0);
    PPApplyButtonShadow(_saveButton);
    [_saveButton setTitle:[Language isRTL] ? @"حفظ التعديلات والتسعير" : @"Save Changes & Pricing" forState:UIControlStateNormal];
    [_saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [Styling fontBold:15.0];
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_saveButton];

    [NSLayoutConstraint activateConstraints:@[
        [_saveButton.topAnchor constraintEqualToAnchor:availCard.bottomAnchor constant:18],
        [_saveButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [_saveButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [_saveButton.heightAnchor constraintEqualToConstant:50],
        [_saveButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-30]
    ]];
}

- (void)stepButtonTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSNumber *delta = objc_getAssociatedObject(sender, "step_delta");
    if (!delta) return;
    self.currentPrice = MAX(10.0, self.currentPrice + [delta doubleValue]);
    [self updatePriceDisplay];
}

- (void)directInputChanged {
    double val = [self.directInputField.text doubleValue];
    if (val > 0) {
        self.currentPrice = val;
        [self updatePriceDisplay];
    }
}

- (void)updatePriceDisplay {
    NSString *curr = self.service.currency.length > 0 ? self.service.currency : @"QAR";
    self.priceDisplayLabel.text = [NSString stringWithFormat:@"%.0f %@", self.currentPrice, curr];

    double estWeekly = self.currentPrice * 5.0; // 5 bookings/week baseline
    self.yieldProjectionLabel.text = [Language isRTL]
        ? [NSString stringWithFormat:@"العائد التقديري: ~%.0f %@ أسبوعياً (بمعدل 5 حجوزات)", estWeekly, curr]
        : [NSString stringWithFormat:@"Est. Weekly Yield: ~%.0f %@ (5 bookings/wk)", estWeekly, curr];
}

- (void)saveTapped {
    [PPFunc pp_playTapEffect];
    self.service.price = self.currentPrice;
    self.service.isAvailable = self.availabilitySwitch.isOn;

    [PPHUD showIndeterminateIn:self.view title:[Language isRTL] ? @"جارٍ الحفظ..." : @"Saving..." subtitle:nil];

    __weak typeof(self) weakSelf = self;
    [[PPServiceManager sharedManager] updateService:self.service image:nil completion:^(NSError * _Nullable error) {
        [PPHUD dismiss];
        if (error) {
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            [PPHUD showSuccess:[Language isRTL] ? @"تم تحديث التسعير بنجاح" : @"Pricing updated"];
            if (weakSelf.onUpdated) weakSelf.onUpdated();
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

@end

#pragma mark - PPServicesListViewController Main Implementation

@interface PPServicesListViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *spatialCockpitHeader;

// Stage Mode: 0 = Service Atelier & Yield, 1 = Live Floor & Bookings
@property (nonatomic, assign) NSInteger currentStageMode;
@property (nonatomic, strong) UISegmentedControl *stageSegmentedControl;

// Master Duty & Availability Island
@property (nonatomic, strong) UIView *masterIslandView;
@property (nonatomic, strong) UIView *liveBeaconDot;
@property (nonatomic, strong) UILabel *liveBeaconTitle;
@property (nonatomic, strong) UILabel *liveBeaconSubtitle;
@property (nonatomic, strong) UISwitch *masterDutySwitch;

// Yield Ribbon & Metrics
@property (nonatomic, strong) UIView *yieldRibbon;
@property (nonatomic, strong) UILabel *ribbonActiveCount;
@property (nonatomic, strong) UILabel *ribbonBookingsCount;
@property (nonatomic, strong) UILabel *ribbonAvgYield;

// Omni-Search & Filter Rail
@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIScrollView *categoryFilterRail;
@property (nonatomic, strong) UIStackView *categoryFilterStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterButtons;
@property (nonatomic, copy) NSString *selectedFilterCategory; // @"all", @"active", @"paused", @"grooming", @"training"

// Floating Quick Operating Dock (Bottom Bar)
@property (nonatomic, strong) UIView *floatingOperatingDock;
@property (nonatomic, strong) UILabel *operatingHoursLabel;
@property (nonatomic, strong) UIButton *dockScheduleButton;
@property (nonatomic, strong) UIButton *dockPipelineButton;

// Cinematic Studio Empty State
@property (nonatomic, strong) UIView *emptyStateContainer;

// Data
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
    self.currentStageMode = 0; // Default: Service Atelier & Yield
    self.hasPermission = [self checkServicePermission];

    [self setupNavigation];
    [self setupTableView];
    [self setupCockpitHeader];
    [self setupFloatingOperatingDock];
    [self setupCinematicEmptyState];
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

#pragma mark - NextGen V8 Pro Navigation Bar (Zero Truncation Guarantee)

- (void)setupNavigation {
    NSString *navTitle = [Language isRTL] ? @"طلبات وعروض الخدمة" : @"Services Command";
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:navTitle showBack:YES];

    if (self.hasPermission) {
        // Quick Starter Templates Pill Button
        UIButton *templateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        templateBtn.translatesAutoresizingMaskIntoConstraints = NO;
        templateBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
        [templateBtn setTitle:[Language isRTL] ? @"⚡ قوالب" : @"⚡ Templates" forState:UIControlStateNormal];
        [templateBtn setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
        templateBtn.titleLabel.font = [Styling fontBold:12.5];
        PPApplyContinuousCorners(templateBtn, 14.0);
        templateBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
        [templateBtn addTarget:self action:@selector(openTemplatePicker) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:templateBtn key:@"pro_templates"];

        // Add Service Primary Pill (Engineered to never truncate in RTL/LTR)
        UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        addBtn.translatesAutoresizingMaskIntoConstraints = NO;
        addBtn.backgroundColor = [UIColor ppPrimary];
        [addBtn setTitle:[Language isRTL] ? @"+ خدمة" : @"+ New" forState:UIControlStateNormal];
        [addBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        addBtn.titleLabel.font = [Styling fontBold:13.0];
        PPApplyContinuousCorners(addBtn, 14.0);
        PPApplyButtonShadow(addBtn);
        addBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [addBtn addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:addBtn key:@"pro_add_service"];
    }
}

#pragma mark - Table View & Cockpit Layout

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
    _tableView.estimatedRowHeight = 138.0;
    _tableView.sectionHeaderTopPadding = 0.0;
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 110, 0);
    [_tableView registerClass:[PPServiceCell class] forCellReuseIdentifier:[PPServiceCell reuseID]];

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

#pragma mark - NextGen V8 Spatial Cockpit Header

- (void)setupCockpitHeader {
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 252)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // 1. Master Duty & Availability Island (Compact 70pt frosted glass capsule)
    _masterIslandView = [[UIView alloc] init];
    _masterIslandView.translatesAutoresizingMaskIntoConstraints = NO;
    _masterIslandView.backgroundColor = [UIColor ppElevatedSurface];
    _masterIslandView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _masterIslandView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_masterIslandView, 18.0);
    PPApplyCardShadow(_masterIslandView);
    [header addSubview:_masterIslandView];

    _liveBeaconDot = [UIView new];
    _liveBeaconDot.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBeaconDot.backgroundColor = [UIColor ppSuccess];
    _liveBeaconDot.layer.cornerRadius = 4.5;
    [_masterIslandView addSubview:_liveBeaconDot];

    _liveBeaconTitle = [UILabel new];
    _liveBeaconTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBeaconTitle.text = [Language isRTL] ? @"حالة التوفر الشامل في قطر" : @"Master Salon Visibility";
    _liveBeaconTitle.font = [Styling fontBold:14.5];
    _liveBeaconTitle.textColor = PrimaryTextClr;
    _liveBeaconTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [_masterIslandView addSubview:_liveBeaconTitle];

    _liveBeaconSubtitle = [UILabel new];
    _liveBeaconSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBeaconSubtitle.text = [Language isRTL] ? @"خدماتك ظاهرة لجميع العملاء وقابلة للحجز الفوري" : @"All services active & bookable across Qatar";
    _liveBeaconSubtitle.font = [Styling fontRegular:11.5];
    _liveBeaconSubtitle.textColor = SeconderyTextClr;
    _liveBeaconSubtitle.textAlignment = Language.alignmentForCurrentLanguage;
    [_masterIslandView addSubview:_liveBeaconSubtitle];

    _masterDutySwitch = [[UISwitch alloc] init];
    _masterDutySwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _masterDutySwitch.onTintColor = [UIColor ppSuccess];
    _masterDutySwitch.on = YES;
    _masterDutySwitch.transform = CGAffineTransformMakeScale(0.82, 0.82);
    [_masterDutySwitch addTarget:self action:@selector(masterSwitchToggled:) forControlEvents:UIControlEventValueChanged];
    [_masterIslandView addSubview:_masterDutySwitch];

    [NSLayoutConstraint activateConstraints:@[
        [_masterIslandView.topAnchor constraintEqualToAnchor:header.topAnchor constant:6],
        [_masterIslandView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_masterIslandView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_masterIslandView.heightAnchor constraintEqualToConstant:66],

        [_liveBeaconDot.leadingAnchor constraintEqualToAnchor:_masterIslandView.leadingAnchor constant:14],
        [_liveBeaconDot.topAnchor constraintEqualToAnchor:_masterIslandView.topAnchor constant:18],
        [_liveBeaconDot.widthAnchor constraintEqualToConstant:9],
        [_liveBeaconDot.heightAnchor constraintEqualToConstant:9],

        [_liveBeaconTitle.centerYAnchor constraintEqualToAnchor:_liveBeaconDot.centerYAnchor],
        [_liveBeaconTitle.leadingAnchor constraintEqualToAnchor:_liveBeaconDot.trailingAnchor constant:8],
        [_liveBeaconTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_masterDutySwitch.leadingAnchor constant:-8],

        [_liveBeaconSubtitle.topAnchor constraintEqualToAnchor:_liveBeaconTitle.bottomAnchor constant:3],
        [_liveBeaconSubtitle.leadingAnchor constraintEqualToAnchor:_liveBeaconTitle.leadingAnchor],
        [_liveBeaconSubtitle.trailingAnchor constraintLessThanOrEqualToAnchor:_masterDutySwitch.leadingAnchor constant:-8],

        [_masterDutySwitch.trailingAnchor constraintEqualToAnchor:_masterIslandView.trailingAnchor constant:-12],
        [_masterDutySwitch.centerYAnchor constraintEqualToAnchor:_masterIslandView.centerYAnchor]
    ]];

    // 2. The Dual-Stage Segmented Stage Control
    NSArray *segments = @[
        [Language isRTL] ? @"💈 عروض الخدمات والتسعير" : @"💈 Service Atelier",
        [Language isRTL] ? @"🐾 الحجوزات الحية (2)" : @"🐾 Live Floor (2)"
    ];
    _stageSegmentedControl = [[UISegmentedControl alloc] initWithItems:segments];
    _stageSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _stageSegmentedControl.selectedSegmentIndex = 0;
    _stageSegmentedControl.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.07];
    _stageSegmentedControl.selectedSegmentTintColor = [UIColor ppElevatedSurface];
    NSDictionary *selAttr = @{
        NSFontAttributeName: [Styling fontBold:13.0],
        NSForegroundColorAttributeName: [UIColor ppPrimary]
    };
    NSDictionary *unselAttr = @{
        NSFontAttributeName: [Styling fontMedium:12.5],
        NSForegroundColorAttributeName: [UIColor ppTextSecondary]
    };
    [_stageSegmentedControl setTitleTextAttributes:selAttr forState:UIControlStateSelected];
    [_stageSegmentedControl setTitleTextAttributes:unselAttr forState:UIControlStateNormal];
    [_stageSegmentedControl addTarget:self action:@selector(stageSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [header addSubview:_stageSegmentedControl];

    // 3. Yield Telemetry Ribbon (3 clean glanceable micro-metrics)
    _yieldRibbon = [[UIView alloc] init];
    _yieldRibbon.translatesAutoresizingMaskIntoConstraints = NO;
    _yieldRibbon.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(_yieldRibbon, 12.0);
    _yieldRibbon.layer.borderWidth = 0.5;
    _yieldRibbon.layer.borderColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.12].CGColor;
    [header addSubview:_yieldRibbon];

    UIStackView *ribbonStack = [[UIStackView alloc] init];
    ribbonStack.translatesAutoresizingMaskIntoConstraints = NO;
    ribbonStack.axis = UILayoutConstraintAxisHorizontal;
    ribbonStack.distribution = UIStackViewDistributionFillEqually;
    ribbonStack.spacing = 4.0;
    [_yieldRibbon addSubview:ribbonStack];

    _ribbonActiveCount = [self makeRibbonLabel:@"0 نشط" color:[UIColor ppSuccess]];
    _ribbonBookingsCount = [self makeRibbonLabel:@"2 حجز اليوم" color:[UIColor ppPrimary]];
    _ribbonAvgYield = [self makeRibbonLabel:@"250 ر.ق الإيراد" color:PrimaryTextClr];

    [ribbonStack addArrangedSubview:_ribbonActiveCount];
    [ribbonStack addArrangedSubview:_ribbonBookingsCount];
    [ribbonStack addArrangedSubview:_ribbonAvgYield];

    [NSLayoutConstraint activateConstraints:@[
        [_stageSegmentedControl.topAnchor constraintEqualToAnchor:_masterIslandView.bottomAnchor constant:10],
        [_stageSegmentedControl.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_stageSegmentedControl.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_stageSegmentedControl.heightAnchor constraintEqualToConstant:34],

        [_yieldRibbon.topAnchor constraintEqualToAnchor:_stageSegmentedControl.bottomAnchor constant:8],
        [_yieldRibbon.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_yieldRibbon.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_yieldRibbon.heightAnchor constraintEqualToConstant:34],

        [ribbonStack.topAnchor constraintEqualToAnchor:_yieldRibbon.topAnchor],
        [ribbonStack.bottomAnchor constraintEqualToAnchor:_yieldRibbon.bottomAnchor],
        [ribbonStack.leadingAnchor constraintEqualToAnchor:_yieldRibbon.leadingAnchor constant:8],
        [ribbonStack.trailingAnchor constraintEqualToAnchor:_yieldRibbon.trailingAnchor constant:-8]
    ]];

    // 4. Omni-Search Field (Clean 38pt glass capsule)
    _searchContainer = [[UIView alloc] init];
    _searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _searchContainer.backgroundColor = [UIColor ppSurfaceElevated];
    _searchContainer.layer.borderWidth = 0.5;
    _searchContainer.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_searchContainer, 12.0);
    [header addSubview:_searchContainer];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppTextSecondary];
    [_searchContainer addSubview:searchIcon];

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholder = [Language isRTL] ? @"بحث سريع في الخدمات والتسعير..." : @"Quick search services & pricing...";
    _searchField.font = [Styling fontRegular:13.0];
    _searchField.textColor = [UIColor ppTextPrimary];
    _searchField.textAlignment = Language.alignmentForCurrentLanguage;
    _searchField.delegate = self;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [_searchContainer addSubview:_searchField];

    // 5. Category Filter Rail with SF Symbols
    _categoryFilterRail = [[UIScrollView alloc] init];
    _categoryFilterRail.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryFilterRail.showsHorizontalScrollIndicator = NO;
    [header addSubview:_categoryFilterRail];

    _categoryFilterStack = [[UIStackView alloc] init];
    _categoryFilterStack.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryFilterStack.axis = UILayoutConstraintAxisHorizontal;
    _categoryFilterStack.spacing = 8.0;
    [_categoryFilterRail addSubview:_categoryFilterStack];

    [NSLayoutConstraint activateConstraints:@[
        [_searchContainer.topAnchor constraintEqualToAnchor:_yieldRibbon.bottomAnchor constant:8],
        [_searchContainer.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_searchContainer.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_searchContainer.heightAnchor constraintEqualToConstant:38],

        [searchIcon.leadingAnchor constraintEqualToAnchor:_searchContainer.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:_searchContainer.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:15],
        [searchIcon.heightAnchor constraintEqualToConstant:15],

        [_searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchContainer.trailingAnchor constant:-12],
        [_searchField.centerYAnchor constraintEqualToAnchor:_searchContainer.centerYAnchor],

        [_categoryFilterRail.topAnchor constraintEqualToAnchor:_searchContainer.bottomAnchor constant:8],
        [_categoryFilterRail.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_categoryFilterRail.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_categoryFilterRail.heightAnchor constraintEqualToConstant:32],

        [_categoryFilterStack.topAnchor constraintEqualToAnchor:_categoryFilterRail.topAnchor],
        [_categoryFilterStack.leadingAnchor constraintEqualToAnchor:_categoryFilterRail.leadingAnchor],
        [_categoryFilterStack.trailingAnchor constraintEqualToAnchor:_categoryFilterRail.trailingAnchor],
        [_categoryFilterStack.bottomAnchor constraintEqualToAnchor:_categoryFilterRail.bottomAnchor],
        [_categoryFilterStack.heightAnchor constraintEqualToAnchor:_categoryFilterRail.heightAnchor]
    ]];

    _spatialCockpitHeader = header;
    _tableView.tableHeaderView = _spatialCockpitHeader;

    [self rebuildFilterRail];
}

- (UILabel *)makeRibbonLabel:(NSString *)text color:(UIColor *)color {
    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = text;
    lbl.textColor = color;
    lbl.font = [Styling fontBold:11.5];
    lbl.textAlignment = NSTextAlignmentCenter;
    return lbl;
}

#pragma mark - Floating Operating Dock (Glanceable Hours & Rapid Pipelines)

- (void)setupFloatingOperatingDock {
    _floatingOperatingDock = [UIView new];
    _floatingOperatingDock.translatesAutoresizingMaskIntoConstraints = NO;
    _floatingOperatingDock.backgroundColor = [[UIColor ppElevatedSurface] colorWithAlphaComponent:0.96];
    PPApplyContinuousCorners(_floatingOperatingDock, 20.0);
    _floatingOperatingDock.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _floatingOperatingDock.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(_floatingOperatingDock);
    [self.view addSubview:_floatingOperatingDock];

    // Operating Hours Indicator
    UIImageView *clockIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"clock.badge.checkmark.fill"]];
    clockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    clockIcon.tintColor = [UIColor ppSuccess];
    [_floatingOperatingDock addSubview:clockIcon];

    _operatingHoursLabel = [UILabel new];
    _operatingHoursLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _operatingHoursLabel.text = [Language isRTL] ? @"صالتك مفتوحة اليوم حتى 8:00 م" : @"Salon open today until 8:00 PM";
    _operatingHoursLabel.font = [Styling fontBold:12.5];
    _operatingHoursLabel.textColor = PrimaryTextClr;
    [_floatingOperatingDock addSubview:_operatingHoursLabel];

    // Quick Matrix Link
    _dockScheduleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _dockScheduleButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_dockScheduleButton setTitle:[Language isRTL] ? @"تعديل الساعات ⚙️" : @"Hours ⚙️" forState:UIControlStateNormal];
    [_dockScheduleButton setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
    _dockScheduleButton.titleLabel.font = [Styling fontBold:12.0];
    [_dockScheduleButton addTarget:self action:@selector(openScheduleMatrix) forControlEvents:UIControlEventTouchUpInside];
    [_floatingOperatingDock addSubview:_dockScheduleButton];

    // Full Pipeline Link
    _dockPipelineButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _dockPipelineButton.translatesAutoresizingMaskIntoConstraints = NO;
    _dockPipelineButton.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(_dockPipelineButton, 12.0);
    [_dockPipelineButton setTitle:[Language isRTL] ? @"الحجوزات (2)" : @"Bookings (2)" forState:UIControlStateNormal];
    [_dockPipelineButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _dockPipelineButton.titleLabel.font = [Styling fontBold:12.0];
    _dockPipelineButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [_dockPipelineButton addTarget:self action:@selector(openRequestsPipeline) forControlEvents:UIControlEventTouchUpInside];
    [_floatingOperatingDock addSubview:_dockPipelineButton];

    [NSLayoutConstraint activateConstraints:@[
        [_floatingOperatingDock.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [_floatingOperatingDock.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_floatingOperatingDock.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_floatingOperatingDock.heightAnchor constraintEqualToConstant:50],

        [clockIcon.leadingAnchor constraintEqualToAnchor:_floatingOperatingDock.leadingAnchor constant:14],
        [clockIcon.centerYAnchor constraintEqualToAnchor:_floatingOperatingDock.centerYAnchor],
        [clockIcon.widthAnchor constraintEqualToConstant:18],
        [clockIcon.heightAnchor constraintEqualToConstant:18],

        [_operatingHoursLabel.leadingAnchor constraintEqualToAnchor:clockIcon.trailingAnchor constant:8],
        [_operatingHoursLabel.centerYAnchor constraintEqualToAnchor:_floatingOperatingDock.centerYAnchor],
        [_operatingHoursLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_dockScheduleButton.leadingAnchor constant:-6],

        [_dockScheduleButton.trailingAnchor constraintEqualToAnchor:_dockPipelineButton.leadingAnchor constant:-10],
        [_dockScheduleButton.centerYAnchor constraintEqualToAnchor:_floatingOperatingDock.centerYAnchor],

        [_dockPipelineButton.trailingAnchor constraintEqualToAnchor:_floatingOperatingDock.trailingAnchor constant:-10],
        [_dockPipelineButton.centerYAnchor constraintEqualToAnchor:_floatingOperatingDock.centerYAnchor],
        [_dockPipelineButton.heightAnchor constraintEqualToConstant:32]
    ]];
}

#pragma mark - Filter Rail with Apple SF Symbols

- (void)rebuildFilterRail {
    for (UIView *v in self.categoryFilterStack.arrangedSubviews) {
        [self.categoryFilterStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.filterButtons removeAllObjects];

    NSArray *categories = @[
        @{@"key": @"all", @"title": [Language isRTL] ? @"الكل" : @"All"},
        @{@"key": @"grooming", @"title": [Language isRTL] ? @"✂️ عناية وحلاقة" : @"✂️ Grooming"},
        @{@"key": @"training", @"title": [Language isRTL] ? @"🦮 تدريب وتأهيل" : @"🦮 Training"},
        @{@"key": @"active", @"title": [Language isRTL] ? @"🟢 المتاحة فقط" : @"🟢 Live Only"},
        @{@"key": @"paused", @"title": [Language isRTL] ? @"⏸️ المتوقفة" : @"⏸️ Paused"}
    ];

    for (NSDictionary *dict in categories) {
        NSString *key = dict[@"key"];
        NSString *title = dict[@"title"];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.contentEdgeInsets = UIEdgeInsetsMake(5, 12, 5, 12);
        btn.titleLabel.font = [Styling fontBold:11.5];
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
            btn.layer.borderWidth = 0.5;
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

#pragma mark - Stage Mode Segment Switch

- (void)stageSegmentChanged:(UISegmentedControl *)sender {
    [PPFunc pp_playTapEffect];
    self.currentStageMode = sender.selectedSegmentIndex;

    // Animate header height adjustments
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if (self.currentStageMode == 0) {
            // Service Atelier: Full header
            self.searchContainer.hidden = NO;
            self.categoryFilterRail.hidden = NO;
            self.yieldRibbon.hidden = NO;
            self.spatialCockpitHeader.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 252);
        } else {
            // Live Floor Pipeline: Hide filters & ribbon to focus on appointments
            self.searchContainer.hidden = YES;
            self.categoryFilterRail.hidden = YES;
            self.yieldRibbon.hidden = YES;
            self.spatialCockpitHeader.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 126);
        }
        self.tableView.tableHeaderView = self.spatialCockpitHeader;
        [self.tableView reloadData];
    } completion:nil];
}

#pragma mark - Master Availability Switch Handler

- (void)masterSwitchToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    BOOL isLive = sender.isOn;

    _liveBeaconDot.backgroundColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    _liveBeaconSubtitle.text = isLive
        ? ([Language isRTL] ? @"خدماتك ظاهرة لجميع العملاء وقابلة للحجز الفوري" : @"All services active & bookable across Qatar")
        : ([Language isRTL] ? @"تم إيقاف ظهور خدماتك مؤقتاً لجميع العملاء" : @"All services paused temporarily");

    [PPHUD showIndeterminateIn:self.view title:isLive
        ? (Language.isRTL ? @"جارٍ تفعيل ظهور الخدمات..." : @"Publishing services live...")
        : (Language.isRTL ? @"جارٍ إيقاف الخدمات مؤقتاً..." : @"Pausing all services...")
                      subtitle:nil];

    for (PPServiceModel *s in self.allServices) {
        s.isAvailable = isLive;
        [[PPServiceManager sharedManager] toggleAvailability:isLive forServiceID:s.serviceID completion:nil];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [PPHUD dismiss];
        [PPHUD showSuccess:isLive
            ? (Language.isRTL ? @"تم تفعيل ظهور جميع خدماتك بنجاح" : @"All services published live")
            : (Language.isRTL ? @"تم إيقاف ظهور جميع خدماتك مؤقتاً" : @"All services paused")];
        [self updateCockpitStats];
        [self applyFilterAndReload];
    });
}

#pragma mark - Search & Filtering

- (void)searchChanged {
    self.searchQuery = [self.searchField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self applyFilterAndReload];
}

- (void)applyFilterAndReload {
    NSMutableArray<PPServiceModel *> *filtered = [NSMutableArray array];

    for (PPServiceModel *s in self.allServices) {
        BOOL passesCategory = YES;
        BOOL isActive = s.isAvailable && !s.isDisabled && !s.isBlocked;

        if ([self.selectedFilterCategory isEqualToString:@"active"]) {
            passesCategory = isActive;
        } else if ([self.selectedFilterCategory isEqualToString:@"paused"]) {
            passesCategory = !isActive;
        } else if ([self.selectedFilterCategory isEqualToString:@"grooming"]) {
            passesCategory = (s.type == PPServiceTypeGrooming);
        } else if ([self.selectedFilterCategory isEqualToString:@"training"]) {
            passesCategory = (s.type == PPServiceTypeTraining);
        }

        if (!passesCategory) continue;

        if (self.searchQuery.length > 0) {
            NSString *title = s.title ?: @"";
            NSString *desc = s.descriptionText ?: @"";
            BOOL matchTitle = [title rangeOfString:self.searchQuery options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchDesc = [desc rangeOfString:self.searchQuery options:NSCaseInsensitiveSearch].location != NSNotFound;
            if (!matchTitle && !matchDesc) continue;
        }

        [filtered addObject:s];
    }

    self.filteredServices = filtered;

    BOOL hasServices = (self.allServices.count > 0);
    self.emptyStateContainer.hidden = hasServices;
    self.tableView.hidden = !hasServices;

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
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }

            strongSelf.allServices = [NSMutableArray arrayWithArray:services ?: @[]];
            [strongSelf updateCockpitStats];
            [strongSelf applyFilterAndReload];
        });
    }];
}

- (void)updateCockpitStats {
    NSInteger total = self.allServices.count;
    NSInteger active = 0;
    double totalPrice = 0.0;

    for (PPServiceModel *s in self.allServices) {
        if (s.isAvailable && !s.isDisabled && !s.isBlocked) {
            active++;
        }
        totalPrice += s.price;
    }

    double avgRate = (total > 0) ? (totalPrice / total) : 0.0;

    self.ribbonActiveCount.text = [NSString stringWithFormat:@"%ld %@", (long)active, [Language isRTL] ? @"عرض نشط" : @"Active Offers"];
    self.ribbonBookingsCount.text = [Language isRTL] ? @"2 حجز اليوم" : @"2 Bookings Today";
    self.ribbonAvgYield.text = [NSString stringWithFormat:@"%.0f QAR %@", avgRate, [Language isRTL] ? @"متوسط" : @"Avg"];

    self.masterDutySwitch.on = (active > 0);
    self.liveBeaconDot.backgroundColor = (active > 0) ? [UIColor ppSuccess] : [UIColor ppWarning];
}

#pragma mark - Cinematic Empty State (When services == 0)

- (void)setupCinematicEmptyState {
    _emptyStateContainer = [[UIView alloc] init];
    _emptyStateContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateContainer.backgroundColor = UIColor.clearColor;
    _emptyStateContainer.hidden = YES;
    [self.view addSubview:_emptyStateContainer];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_emptyStateContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_emptyStateContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_emptyStateContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    // Inner scrollable content for empty state
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [_emptyStateContainer addSubview:scroll];

    UIView *box = [[UIView alloc] init];
    box.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:box];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:_emptyStateContainer.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:_emptyStateContainer.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:_emptyStateContainer.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:_emptyStateContainer.bottomAnchor],

        [box.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [box.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [box.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [box.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [box.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];

    // Glowing Orbital Emblem
    UIView *glowRing = [[UIView alloc] init];
    glowRing.translatesAutoresizingMaskIntoConstraints = NO;
    glowRing.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.08];
    glowRing.layer.cornerRadius = 36.0;
    glowRing.layer.borderWidth = 1.0;
    glowRing.layer.borderColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.25].CGColor;
    [box addSubview:glowRing];

    UIImageView *orbIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    orbIcon.translatesAutoresizingMaskIntoConstraints = NO;
    orbIcon.tintColor = [UIColor ppPrimary];
    [glowRing addSubview:orbIcon];

    UILabel *headline = [[UILabel alloc] init];
    headline.translatesAutoresizingMaskIntoConstraints = NO;
    headline.text = [Language isRTL] ? @"ابدأ بتقديم خدماتك للعملاء في قطر" : @"Launch Your Pet Services in Qatar";
    headline.font = [Styling fontBold:18.0];
    headline.textColor = PrimaryTextClr;
    headline.textAlignment = NSTextAlignmentCenter;
    [box addSubview:headline];

    UILabel *subheadline = [[UILabel alloc] init];
    subheadline.translatesAutoresizingMaskIntoConstraints = NO;
    subheadline.text = [Language isRTL]
        ? @"أنشئ باقات العناية، التدريب، أو الرعاية مع تسعير فوري وإدارة حجوزات ذكية."
        : @"Create grooming, training, or care packages with live booking management.";
    subheadline.font = [Styling fontRegular:13.5];
    subheadline.textColor = SeconderyTextClr;
    subheadline.textAlignment = NSTextAlignmentCenter;
    subheadline.numberOfLines = 2;
    [box addSubview:subheadline];

    UIButton *mainCTA = [UIButton buttonWithType:UIButtonTypeCustom];
    mainCTA.translatesAutoresizingMaskIntoConstraints = NO;
    mainCTA.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(mainCTA, 16.0);
    PPApplyButtonShadow(mainCTA);
    [mainCTA setTitle:[Language isRTL] ? @"+ إضافة أول خدمة" : @"+ Add First Service" forState:UIControlStateNormal];
    [mainCTA setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    mainCTA.titleLabel.font = [Styling fontBold:15.0];
    [mainCTA addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
    [box addSubview:mainCTA];

    [NSLayoutConstraint activateConstraints:@[
        [glowRing.topAnchor constraintEqualToAnchor:box.topAnchor constant:40.0],
        [glowRing.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
        [glowRing.widthAnchor constraintEqualToConstant:72.0],
        [glowRing.heightAnchor constraintEqualToConstant:72.0],

        [orbIcon.centerXAnchor constraintEqualToAnchor:glowRing.centerXAnchor],
        [orbIcon.centerYAnchor constraintEqualToAnchor:glowRing.centerYAnchor],
        [orbIcon.widthAnchor constraintEqualToConstant:34.0],
        [orbIcon.heightAnchor constraintEqualToConstant:34.0],

        [headline.topAnchor constraintEqualToAnchor:glowRing.bottomAnchor constant:16.0],
        [headline.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:24.0],
        [headline.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-24.0],

        [subheadline.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:8.0],
        [subheadline.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:24.0],
        [subheadline.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-24.0],

        [mainCTA.topAnchor constraintEqualToAnchor:subheadline.bottomAnchor constant:24.0],
        [mainCTA.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:20.0],
        [mainCTA.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-20.0],
        [mainCTA.heightAnchor constraintEqualToConstant:50.0],
        [mainCTA.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-40.0]
    ]];
}

#pragma mark - Table View Datasource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.currentStageMode == 1) {
        // Live Floor: 2 simulated incoming bookings
        return 2;
    }
    return self.filteredServices.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentStageMode == 1) {
        return 118.0;
    }
    return [PPServiceCell preferredHeight];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentStageMode == 1) {
        return 118.0;
    }
    return [PPServiceCell preferredHeight];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentStageMode == 1) {
        // Live Floor Pipeline Cell
        return [self makeLiveFloorCellForIndexPath:indexPath inTableView:tableView];
    }

    // Service Atelier Cell
    PPServiceCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceCell reuseID] forIndexPath:indexPath];
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [cell configureWithService:s];

    __weak typeof(self) weakSelf = self;
    cell.onToggleAvailability = ^(BOOL newAvailable) {
        [weakSelf toggleAvailabilityForService:s newState:newAvailable];
    };

    cell.onTapPricing = ^{
        [weakSelf openQuickPricingSheetForService:s];
    };

    return cell;
}

- (UITableViewCell *)makeLiveFloorCellForIndexPath:(NSIndexPath *)indexPath inTableView:(UITableView *)tableView {
    static NSString *const kLiveBookingID = @"PPLiveBookingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kLiveBookingID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kLiveBookingID];
        cell.backgroundColor = UIColor.clearColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(card, 18.0);
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyCardShadow(card);
    [cell.contentView addSubview:card];

    // Pet Photo Avatar
    UIImageView *avatar = [UIImageView new];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    PPApplyContinuousCorners(avatar, 14.0);
    avatar.image = (indexPath.row == 0) ? [UIImage imageNamed:@"sample_pet_dog"] : [UIImage imageNamed:@"sample_pet_cat"];
    if (!avatar.image) avatar.image = [UIImage imageNamed:@"placeholder_service"];
    [card addSubview:avatar];

    // Pet Name & Breed
    UILabel *nameLabel = [UILabel new];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [Styling fontBold:15.0];
    nameLabel.textColor = PrimaryTextClr;
    nameLabel.text = (indexPath.row == 0) ? @"روكي (Rocky) · بوميرانيان" : @"مشمش (Mishmish) · شيرازي";
    nameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:nameLabel];

    // Service booked
    UILabel *serviceLabel = [UILabel new];
    serviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    serviceLabel.font = [Styling fontMedium:12.5];
    serviceLabel.textColor = [UIColor ppPrimary];
    serviceLabel.text = (indexPath.row == 0) ? @"✂️ العناية بالمظهر الكاملة" : @"🛁 حمام تنظيف وتقليم أظافر";
    serviceLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:serviceLabel];

    // Arrival Countdown Pill
    UILabel *countdown = [UILabel new];
    countdown.translatesAutoresizingMaskIntoConstraints = NO;
    countdown.font = [Styling fontBold:11.0];
    countdown.textColor = (indexPath.row == 0) ? [UIColor ppWarning] : [UIColor ppSuccess];
    countdown.backgroundColor = [(indexPath.row == 0 ? [UIColor ppWarning] : [UIColor ppSuccess]) colorWithAlphaComponent:0.10];
    countdown.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(countdown, 8.0);
    countdown.clipsToBounds = YES;
    countdown.text = (indexPath.row == 0) ? [NSString stringWithFormat:@"  ⏱ يصل خلال 15 دقيقة  "] : [NSString stringWithFormat:@"  ⏱ موعد اليوم 6:30 م  "];
    [card addSubview:countdown];

    // Price tag
    UILabel *priceTag = [UILabel new];
    priceTag.translatesAutoresizingMaskIntoConstraints = NO;
    priceTag.font = [Styling fontBold:13.5];
    priceTag.textColor = [UIColor ppSuccess];
    priceTag.text = (indexPath.row == 0) ? @"250 QAR" : @"180 QAR";
    [card addSubview:priceTag];

    // Primary Action Button (Start Session / Complete)
    UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    actionBtn.translatesAutoresizingMaskIntoConstraints = NO;
    actionBtn.backgroundColor = [UIColor ppPrimary];
    PPApplyContinuousCorners(actionBtn, 12.0);
    [actionBtn setTitle:(indexPath.row == 0) ? ([Language isRTL] ? @"بدء الجلسة" : @"Start Session") : ([Language isRTL] ? @"تأكيد الوصول" : @"Confirm Arrival") forState:UIControlStateNormal];
    [actionBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    actionBtn.titleLabel.font = [Styling fontBold:12.5];
    [actionBtn addTarget:self action:@selector(openRequestsPipeline) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:actionBtn];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:5.0],
        [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16.0],
        [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16.0],
        [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-5.0],

        [avatar.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
        [avatar.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [avatar.widthAnchor constraintEqualToConstant:64.0],
        [avatar.heightAnchor constraintEqualToConstant:64.0],

        [nameLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:12.0],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:priceTag.leadingAnchor constant:-8.0],

        [priceTag.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [priceTag.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],

        [serviceLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4.0],
        [serviceLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [serviceLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],

        [countdown.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [countdown.topAnchor constraintEqualToAnchor:serviceLabel.bottomAnchor constant:8.0],
        [countdown.heightAnchor constraintEqualToConstant:22.0],
        [countdown.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],

        [actionBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
        [actionBtn.centerYAnchor constraintEqualToAnchor:countdown.centerYAnchor],
        [actionBtn.heightAnchor constraintEqualToConstant:30.0],
        [actionBtn.widthAnchor constraintEqualToConstant:105.0]
    ]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.currentStageMode == 1) {
        [self openRequestsPipeline];
        return;
    }
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [self openDetailsForService:s];
}

#pragma mark - Actions & Transitions

- (void)openQuickPricingSheetForService:(PPServiceModel *)service {
    [PPFunc pp_playTapEffect];
    __weak typeof(self) weakSelf = self;
    PPServiceQuickPricingSheet *sheet = [[PPServiceQuickPricingSheet alloc] initWithService:service onUpdated:^{
        [weakSelf startObservingServices];
    }];
    if (@available(iOS 15.0, *)) {
        sheet.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *pres = sheet.sheetPresentationController;
        pres.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        pres.prefersGrabberVisible = YES;
        pres.preferredCornerRadius = 24.0;
    } else {
        sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleAvailabilityForService:(PPServiceModel *)service newState:(BOOL)newState {
    service.isAvailable = newState;
    [self updateCockpitStats];

    __weak typeof(self) weakSelf = self;
    [[PPServiceManager sharedManager] toggleAvailability:newState forServiceID:service.serviceID completion:^(NSError * _Nullable error) {
        if (error) {
            service.isAvailable = !newState;
            [weakSelf.tableView reloadData];
            [weakSelf updateCockpitStats];
            [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            NSString *msg = newState
                ? ([Language isRTL] ? @"الخدمة متاحة للطلب الآن" : @"Service is live for bookings")
                : ([Language isRTL] ? @"تم إيقاف الخدمة مؤقتاً" : @"Service paused temporarily");
            [PPToast toast:msg
                     style:PPToastStyleSuccess
                    haptic:YES
                  duration:2.0
                  position:PPToastPositionBottom
                    inView:weakSelf.view];
        }
    }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.currentStageMode == 1) return nil;

    PPServiceModel *s = self.filteredServices[indexPath.row];
    __weak typeof(self) weakSelf = self;

    UIContextualAction *pricingAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                            title:[Language isRTL] ? @"تسعير" : @"Pricing"
                                                                          handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf openQuickPricingSheetForService:s];
        completionHandler(YES);
    }];
    pricingAct.backgroundColor = [UIColor ppSuccess];
    pricingAct.image = [UIImage systemImageNamed:@"banknote"];

    UIContextualAction *editAct = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:[Language isRTL] ? @"تعديل" : @"Edit"
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:s];
        [weakSelf.navigationController pushViewController:vc animated:YES];
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

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAct, editAct, pricingAct]];
}

- (void)confirmDeleteService:(PPServiceModel *)service {
    __weak typeof(self) weakSelf = self;
    NSString *title = [Language isRTL] ? @"تأكيد حذف عرض الخدمة" : @"Confirm Service Deletion";
    NSString *msg = [Language isRTL] ? @"هل أنت متأكد من رغبتك في حذف هذا العرض نهائياً؟" : @"Are you sure you want to permanently delete this service?";

    [PPAlertHelper showConfirmationIn:self title:title subtitle:msg placeholder:nil confirmButton:kLang(@"Delete") cancelButton:kLang(@"Cancel") confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:[Language isRTL] ? @"جارٍ الحذف..." : @"Deleting..." subtitle:nil];
        [[PPServiceManager sharedManager] deleteService:service completion:^(NSError * _Nullable error) {
            [PPHUD dismiss];
            if (error) {
                [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:[Language isRTL] ? @"تم حذف الخدمة بنجاح" : @"Service deleted"];
                [weakSelf startObservingServices];
            }
        }];
    } cancelBlock:nil];
}

#pragma mark - Navigation Destinations

- (void)addServiceTapped {
    [PPFunc pp_playTapEffect];
    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openTemplatePicker {
    [PPFunc pp_playTapEffect];
    PPServiceTemplatePickerViewController *vc = [[PPServiceTemplatePickerViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onSelectTemplate = ^(PPServiceModel * _Nonnull templateModel) {
        PPAddEditServiceViewController *editVC = [[PPAddEditServiceViewController alloc] initWithTemplate:templateModel];
        [weakSelf.navigationController pushViewController:editVC animated:YES];
    };
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)openRequestsPipeline {
    [PPFunc pp_playTapEffect];
    PPServiceRequestsViewController *vc = [[PPServiceRequestsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openScheduleMatrix {
    [PPFunc pp_playTapEffect];
    PPServiceScheduleViewController *vc = [[PPServiceScheduleViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openDetailsForService:(PPServiceModel *)service {
    [PPFunc pp_playTapEffect];
    PPServiceDetailViewController *vc = [[PPServiceDetailViewController alloc] initWithService:service];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
