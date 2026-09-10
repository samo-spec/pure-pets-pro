//
//  PPServicesListViewController.m
//  PurePetsPro
//
//  Category-defining flagship service command center with spatial telemetry island,
//  real-time availability master killswitch, multi-lane domain switcher,
//  live requests pipeline bridge, and studio-grade cinematic empty state.
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
        [grabber.widthAnchor constraintEqualToConstant:40],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [scroll.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:8],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],
    ]];

    // 1. Header Card
    UIView *headerCard = [[UIView alloc] init];
    headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    headerCard.backgroundColor = [UIColor ppSurfaceElevated];
    headerCard.layer.borderWidth = 1.0;
    headerCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(headerCard, PPCornerCard);
    PPApplyCardShadow(headerCard);
    [content addSubview:headerCard];

    _thumbnailView = [[UIImageView alloc] init];
    _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailView.clipsToBounds = YES;
    PPApplyContinuousCorners(_thumbnailView, PPCornerMedium);
    _thumbnailView.backgroundColor = [UIColor ppSurface];
    if (self.service.imageURL.length > 0) {
        [_thumbnailView sd_setImageWithURL:[NSURL URLWithString:self.service.imageURL]];
    } else {
        _thumbnailView.image = [UIImage systemImageNamed:@"sparkles"];
        _thumbnailView.tintColor = [UIColor ppPrimary];
    }
    [headerCard addSubview:_thumbnailView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = self.service.title ?: @"—";
    _titleLabel.font = [Styling fontBold:16.0];
    _titleLabel.textColor = [UIColor ppTextPrimary];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:_titleLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.text = [NSString stringWithFormat:@"%@ · %@", [self.service localizedTypeName], self.service.category ?: @""];
    _categoryLabel.font = [Styling fontRegular:12.5];
    _categoryLabel.textColor = [UIColor ppTextSecondary];
    _categoryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [headerCard addSubview:_categoryLabel];

    // 2. Large Price Display Card
    UIView *priceHeroCard = [[UIView alloc] init];
    priceHeroCard.translatesAutoresizingMaskIntoConstraints = NO;
    priceHeroCard.backgroundColor = [UIColor ppSurface];
    priceHeroCard.layer.borderWidth = 1.0;
    priceHeroCard.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(priceHeroCard, PPCornerCard);
    [content addSubview:priceHeroCard];

    UILabel *badge = [[UILabel alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.text = [Language isRTL] ? @"السعر المعتمد حالياً" : @"Current Rate";
    badge.font = [Styling fontBold:11.0];
    badge.textColor = [UIColor ppPrimary];
    badge.textAlignment = NSTextAlignmentCenter;
    [priceHeroCard addSubview:badge];

    _counterDisplay = [[UILabel alloc] init];
    _counterDisplay.translatesAutoresizingMaskIntoConstraints = NO;
    _counterDisplay.font = [Styling fontBold:38.0];
    _counterDisplay.textColor = [UIColor ppTextPrimary];
    _counterDisplay.textAlignment = NSTextAlignmentCenter;
    [priceHeroCard addSubview:_counterDisplay];

    // 3. Quick Multiplier Chips
    UIStackView *chipsStack = [[UIStackView alloc] init];
    chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipsStack.axis = UILayoutConstraintAxisHorizontal;
    chipsStack.distribution = UIStackViewDistributionFillEqually;
    chipsStack.spacing = 8.0;
    [content addSubview:chipsStack];

    NSArray *deltas = @[
        @{@"title": @"-50", @"val": @(-50.0), @"pos": @NO},
        @{@"title": @"-10", @"val": @(-10.0), @"pos": @NO},
        @{@"title": [Language isRTL] ? @"تصفير" : @"Clear", @"val": @0.0, @"pos": @NO},
        @{@"title": @"+10", @"val": @(10.0), @"pos": @YES},
        @{@"title": @"+50", @"val": @(50.0), @"pos": @YES}
    ];

    for (NSDictionary *dict in deltas) {
        NSString *title = dict[@"title"];
        double val = [dict[@"val"] doubleValue];
        BOOL isPos = [dict[@"pos"] boolValue];

        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        chip.titleLabel.font = [Styling fontBold:13.5];
        [chip setTitle:title forState:UIControlStateNormal];
        UIColor *clr = isPos ? [UIColor ppSuccess] : ([title containsString:@"0"] || [title containsString:@"Clear"] ? [UIColor ppError] : [UIColor ppTextSecondary]);
        [chip setTitleColor:clr forState:UIControlStateNormal];
        chip.backgroundColor = [clr colorWithAlphaComponent:0.08];
        PPApplyContinuousCorners(chip, 10.0);
        objc_setAssociatedObject(chip, "price_delta", @(val), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [chip addTarget:self action:@selector(deltaTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chipsStack addArrangedSubview:chip];
    }

    // 4. Direct Manual Input
    _directInputField = [[UITextField alloc] init];
    _directInputField.translatesAutoresizingMaskIntoConstraints = NO;
    _directInputField.keyboardType = UIKeyboardTypeDecimalPad;
    _directInputField.textAlignment = NSTextAlignmentCenter;
    _directInputField.font = [Styling fontBold:20.0];
    _directInputField.textColor = [UIColor ppPrimary];
    _directInputField.backgroundColor = [UIColor ppSurface];
    _directInputField.layer.borderWidth = 1.0;
    _directInputField.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_directInputField, PPCornerMedium);
    _directInputField.delegate = self;
    [_directInputField addTarget:self action:@selector(directInputChanged) forControlEvents:UIControlEventEditingChanged];
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

    _availabilitySwitch = [[UISwitch alloc] init];
    _availabilitySwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _availabilitySwitch.onTintColor = [UIColor ppSuccess];
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
        [headerCard.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
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

        [_categoryLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [priceHeroCard.topAnchor constraintEqualToAnchor:headerCard.bottomAnchor constant:16],
        [priceHeroCard.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [priceHeroCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [priceHeroCard.heightAnchor constraintEqualToConstant:100],

        [badge.topAnchor constraintEqualToAnchor:priceHeroCard.topAnchor constant:10],
        [badge.centerXAnchor constraintEqualToAnchor:priceHeroCard.centerXAnchor],

        [_counterDisplay.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:2],
        [_counterDisplay.centerXAnchor constraintEqualToAnchor:priceHeroCard.centerXAnchor],

        [chipsStack.topAnchor constraintEqualToAnchor:priceHeroCard.bottomAnchor constant:16],
        [chipsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [chipsStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [chipsStack.heightAnchor constraintEqualToConstant:38],

        [_directInputField.topAnchor constraintEqualToAnchor:chipsStack.bottomAnchor constant:14],
        [_directInputField.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_directInputField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_directInputField.heightAnchor constraintEqualToConstant:46],

        [switchRow.topAnchor constraintEqualToAnchor:_directInputField.bottomAnchor constant:14],
        [switchRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [switchRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [switchRow.heightAnchor constraintEqualToConstant:56],

        [switchTitle.leadingAnchor constraintEqualToAnchor:switchRow.leadingAnchor constant:16],
        [switchTitle.centerYAnchor constraintEqualToAnchor:switchRow.centerYAnchor],
        [switchTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_availabilitySwitch.leadingAnchor constant:-12],

        [_availabilitySwitch.trailingAnchor constraintEqualToAnchor:switchRow.trailingAnchor constant:-16],
        [_availabilitySwitch.centerYAnchor constraintEqualToAnchor:switchRow.centerYAnchor],

        [_saveButton.topAnchor constraintEqualToAnchor:switchRow.bottomAnchor constant:20],
        [_saveButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [_saveButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [_saveButton.heightAnchor constraintEqualToConstant:50],
        [_saveButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-30]
    ]];
}

- (void)deltaTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    NSNumber *deltaNum = objc_getAssociatedObject(sender, "price_delta");
    if (deltaNum) {
        if (deltaNum.doubleValue == 0.0) {
            self.currentPrice = 0.0;
        } else {
            self.currentPrice = MAX(0.0, self.currentPrice + deltaNum.doubleValue);
        }
        [self updatePriceDisplay];
    }
}

- (void)directInputChanged {
    double val = [self.directInputField.text doubleValue];
    self.currentPrice = MAX(0.0, val);
    self.counterDisplay.text = [NSString stringWithFormat:@"%.0f QAR", self.currentPrice];
}

- (void)updatePriceDisplay {
    self.counterDisplay.text = [NSString stringWithFormat:@"%.0f QAR", self.currentPrice];
    self.directInputField.text = [NSString stringWithFormat:@"%.0f", self.currentPrice];
}

- (void)saveRateTapped {
    [PPFunc pp_playTapEffect];
    [PPHUD showIndeterminateIn:self.view title:[Language isRTL] ? @"جارٍ تحديث السعر..." : @"Updating Rate..." subtitle:nil];

    self.service.price = self.currentPrice;
    self.service.isAvailable = self.availabilitySwitch.isOn;

    __weak typeof(self) weakSelf = self;
    [[PPServiceManager sharedManager] updateService:self.service image:nil completion:^(NSError * _Nullable error) {
        [PPHUD dismiss];
        if (error) {
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
        } else {
            [PPHUD showSuccess:[Language isRTL] ? @"تم تحديث السعر بنجاح" : @"Rate updated successfully"];
            if (weakSelf.onUpdated) {
                weakSelf.onUpdated();
            }
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

// Dynamic Ambient Beacon
@property (nonatomic, strong) UIView *liveBeaconDot;
@property (nonatomic, strong) UILabel *liveBeaconLabel;

// Master Availability Switch
@property (nonatomic, strong) UIView *masterCardView;
@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UILabel *masterStatusLabel;

// Cockpit KPI Labels
@property (nonatomic, strong) UILabel *kpiTotalLabel;
@property (nonatomic, strong) UILabel *kpiActiveLabel;
@property (nonatomic, strong) UILabel *kpiRequestsLabel;
@property (nonatomic, strong) UILabel *kpiAvgRateLabel;

// Action Dock
@property (nonatomic, strong) UIButton *actionDockRequestsBtn;
@property (nonatomic, strong) UIButton *actionDockScheduleBtn;

// Omni-Search & Filter Rail
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *searchClearBtn;
@property (nonatomic, strong) UIScrollView *categoryFilterRail;
@property (nonatomic, strong) UIStackView *categoryFilterStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *filterButtons;
@property (nonatomic, copy) NSString *selectedFilterCategory; // @"all", @"active", @"paused", or custom

// Cinematic Studio Empty State
@property (nonatomic, strong) UIView *emptyStateContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *starterTemplateCards;

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
    self.starterTemplateCards = [NSMutableArray array];
    self.selectedFilterCategory = @"all";
    self.searchQuery = @"";
    self.hasPermission = [self checkServicePermission];

    [self setupNavigation];
    [self setupTableView];
    [self setupCockpitHeader];
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

#pragma mark - Pro Navigation Bar

- (void)setupNavigation {
    NSString *navTitle = Language.isRTL ? @"طلبات وعروض الخدمة" : @"Services Command";
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:navTitle showBack:YES];

    if (self.hasPermission) {
        // Quick Starter Templates Action Button
        UIButton *templateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        templateBtn.translatesAutoresizingMaskIntoConstraints = NO;
        templateBtn.backgroundColor = [[UIColor ppPrimary] colorWithAlphaComponent:0.12];
        [templateBtn setTitle:Language.isRTL ? @"⚡ قوالب جاهزة" : @"⚡ Templates" forState:UIControlStateNormal];
        [templateBtn setTitleColor:[UIColor ppPrimary] forState:UIControlStateNormal];
        templateBtn.titleLabel.font = [Styling fontBold:12.5];
        PPApplyContinuousCorners(templateBtn, 14.0);
        templateBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        [templateBtn addTarget:self action:@selector(openTemplatePicker) forControlEvents:UIControlEventTouchUpInside];
        [self pp_navBarAddActionButton:templateBtn key:@"pro_templates"];

        // Add Service Primary Button
        UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        addBtn.translatesAutoresizingMaskIntoConstraints = NO;
        addBtn.backgroundColor = [UIColor ppPrimary];
        [addBtn setTitle:Language.isRTL ? @"+ إضافة خدمة" : @"+ New Service" forState:UIControlStateNormal];
        [addBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        addBtn.titleLabel.font = [Styling fontBold:13.0];
        PPApplyContinuousCorners(addBtn, 16.0);
        PPApplyButtonShadow(addBtn);
        addBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
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
    _tableView.estimatedRowHeight = 140.0;
    _tableView.sectionHeaderTopPadding = 0.0;
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 90, 0);
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

- (void)setupCockpitHeader {
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 305)];
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // 1. Spatial Telemetry & Master Switch Card
    _masterCardView = [[UIView alloc] init];
    _masterCardView.translatesAutoresizingMaskIntoConstraints = NO;
    _masterCardView.backgroundColor = [UIColor ppElevatedSurface];
    _masterCardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _masterCardView.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_masterCardView, PPCornerCard);
    PPApplyCardShadow(_masterCardView);
    [header addSubview:_masterCardView];

    // Live Beacon & Master Title
    _liveBeaconDot = [UIView new];
    _liveBeaconDot.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBeaconDot.backgroundColor = [UIColor ppSuccess];
    _liveBeaconDot.layer.cornerRadius = 5.0;
    [_masterCardView addSubview:_liveBeaconDot];

    _liveBeaconLabel = [UILabel new];
    _liveBeaconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBeaconLabel.text = kLang(@"Serv_Master_Toggle_Title");
    _liveBeaconLabel.font = [Styling fontBold:15.5];
    _liveBeaconLabel.textColor = PrimaryTextClr;
    _liveBeaconLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_masterCardView addSubview:_liveBeaconLabel];

    _masterStatusLabel = [UILabel new];
    _masterStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _masterStatusLabel.text = kLang(@"Serv_Master_Active_State");
    _masterStatusLabel.font = [Styling fontRegular:12.0];
    _masterStatusLabel.textColor = SeconderyTextClr;
    _masterStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_masterCardView addSubview:_masterStatusLabel];

    _masterSwitch = [[UISwitch alloc] init];
    _masterSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    _masterSwitch.onTintColor = [UIColor ppSuccess];
    _masterSwitch.on = YES;
    [_masterSwitch addTarget:self action:@selector(masterSwitchToggled:) forControlEvents:UIControlEventValueChanged];
    [_masterCardView addSubview:_masterSwitch];

    // Divider
    UIView *div = [UIView new];
    div.translatesAutoresizingMaskIntoConstraints = NO;
    div.backgroundColor = [UIColor ppSurfaceBorder];
    [_masterCardView addSubview:div];

    // 3 Spatial KPI Pods
    UIStackView *kpiStack = [[UIStackView alloc] init];
    kpiStack.translatesAutoresizingMaskIntoConstraints = NO;
    kpiStack.axis = UILayoutConstraintAxisHorizontal;
    kpiStack.distribution = UIStackViewDistributionFillEqually;
    kpiStack.spacing = 8.0;
    [_masterCardView addSubview:kpiStack];

    _kpiTotalLabel = [self makeKPILabelWithColor:[UIColor ppPrimary]];
    _kpiActiveLabel = [self makeKPILabelWithColor:[UIColor ppSuccess]];
    _kpiRequestsLabel = [self makeKPILabelWithColor:[UIColor ppWarning]];
    _kpiAvgRateLabel = [self makeKPILabelWithColor:[UIColor ppTextPrimary]];

    UIView *tile1 = [self makeKPITileWithTitle:kLang(@"Serv_Metric_ActiveServices") icon:@"bolt.circle.fill" color:[UIColor ppSuccess] valueLabel:_kpiActiveLabel tag:@"active"];
    UIView *tile2 = [self makeKPITileWithTitle:kLang(@"Serv_Metric_Requests") icon:@"calendar.badge.clock" color:[UIColor ppPrimary] valueLabel:_kpiRequestsLabel tag:@"requests"];
    UIView *tile3 = [self makeKPITileWithTitle:kLang(@"Serv_Metric_Revenue") icon:@"banknote.fill" color:[UIColor ppTextPrimary] valueLabel:_kpiAvgRateLabel tag:@"revenue"];

    [kpiStack addArrangedSubview:tile1];
    [kpiStack addArrangedSubview:tile2];
    [kpiStack addArrangedSubview:tile3];

    // 2. Action Dock (Quick Jump to Live Requests & Schedule)
    UIStackView *actionDock = [UIStackView new];
    actionDock.translatesAutoresizingMaskIntoConstraints = NO;
    actionDock.axis = UILayoutConstraintAxisHorizontal;
    actionDock.distribution = UIStackViewDistributionFillEqually;
    actionDock.spacing = 10.0;
    [header addSubview:actionDock];

    _actionDockRequestsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _actionDockRequestsBtn.backgroundColor = [UIColor ppSurfaceElevated];
    _actionDockRequestsBtn.layer.borderWidth = 1.0;
    _actionDockRequestsBtn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_actionDockRequestsBtn, PPCornerMedium);
    [_actionDockRequestsBtn setTitle:Language.isRTL ? @"📋 طلبات وحجوزات الخدمة (2)" : @"📋 Bookings Pipeline (2)" forState:UIControlStateNormal];
    [_actionDockRequestsBtn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    _actionDockRequestsBtn.titleLabel.font = [Styling fontBold:13.0];
    [_actionDockRequestsBtn addTarget:self action:@selector(openRequestsPipeline) forControlEvents:UIControlEventTouchUpInside];
    [actionDock addArrangedSubview:_actionDockRequestsBtn];

    _actionDockScheduleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _actionDockScheduleBtn.backgroundColor = [UIColor ppSurfaceElevated];
    _actionDockScheduleBtn.layer.borderWidth = 1.0;
    _actionDockScheduleBtn.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(_actionDockScheduleBtn, PPCornerMedium);
    [_actionDockScheduleBtn setTitle:Language.isRTL ? @"⏰ ساعات العمل والتوفر" : @"⏰ Schedule Matrix" forState:UIControlStateNormal];
    [_actionDockScheduleBtn setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    _actionDockScheduleBtn.titleLabel.font = [Styling fontBold:13.0];
    [_actionDockScheduleBtn addTarget:self action:@selector(openScheduleMatrix) forControlEvents:UIControlEventTouchUpInside];
    [actionDock addArrangedSubview:_actionDockScheduleBtn];

    // 3. Omni-Search Field
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    searchContainer.backgroundColor = [UIColor ppSurfaceElevated];
    searchContainer.layer.borderWidth = 1.0;
    searchContainer.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    PPApplyContinuousCorners(searchContainer, PPCornerMedium);
    [header addSubview:searchContainer];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = [UIColor ppTextSecondary];
    [searchContainer addSubview:searchIcon];

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholder = [Language isRTL] ? @"بحث سريع في عروض الخدمات..." : @"Search service offers...";
    _searchField.font = [Styling fontRegular:13.5];
    _searchField.textColor = [UIColor ppTextPrimary];
    _searchField.textAlignment = Language.alignmentForCurrentLanguage;
    _searchField.delegate = self;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [searchContainer addSubview:_searchField];

    // 4. Category Filter Rail
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
        // Master Telemetry Card
        [_masterCardView.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
        [_masterCardView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_masterCardView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_masterCardView.heightAnchor constraintEqualToConstant:140],

        [_liveBeaconDot.leadingAnchor constraintEqualToAnchor:_masterCardView.leadingAnchor constant:14],
        [_liveBeaconDot.topAnchor constraintEqualToAnchor:_masterCardView.topAnchor constant:18],
        [_liveBeaconDot.widthAnchor constraintEqualToConstant:10],
        [_liveBeaconDot.heightAnchor constraintEqualToConstant:10],

        [_liveBeaconLabel.centerYAnchor constraintEqualToAnchor:_liveBeaconDot.centerYAnchor],
        [_liveBeaconLabel.leadingAnchor constraintEqualToAnchor:_liveBeaconDot.trailingAnchor constant:8],
        [_liveBeaconLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_masterSwitch.leadingAnchor constant:-10],

        [_masterStatusLabel.topAnchor constraintEqualToAnchor:_liveBeaconLabel.bottomAnchor constant:3],
        [_masterStatusLabel.leadingAnchor constraintEqualToAnchor:_liveBeaconLabel.leadingAnchor],
        [_masterStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_masterSwitch.leadingAnchor constant:-10],

        [_masterSwitch.trailingAnchor constraintEqualToAnchor:_masterCardView.trailingAnchor constant:-14],
        [_masterSwitch.centerYAnchor constraintEqualToAnchor:_liveBeaconDot.centerYAnchor constant:6],

        [div.topAnchor constraintEqualToAnchor:_masterStatusLabel.bottomAnchor constant:10],
        [div.leadingAnchor constraintEqualToAnchor:_masterCardView.leadingAnchor constant:14],
        [div.trailingAnchor constraintEqualToAnchor:_masterCardView.trailingAnchor constant:-14],
        [div.heightAnchor constraintEqualToConstant:0.5],

        [kpiStack.topAnchor constraintEqualToAnchor:div.bottomAnchor constant:8],
        [kpiStack.leadingAnchor constraintEqualToAnchor:_masterCardView.leadingAnchor constant:10],
        [kpiStack.trailingAnchor constraintEqualToAnchor:_masterCardView.trailingAnchor constant:-10],
        [kpiStack.bottomAnchor constraintEqualToAnchor:_masterCardView.bottomAnchor constant:-8],

        // Action Dock
        [actionDock.topAnchor constraintEqualToAnchor:_masterCardView.bottomAnchor constant:10],
        [actionDock.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [actionDock.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [actionDock.heightAnchor constraintEqualToConstant:38],

        // Search Bar
        [searchContainer.topAnchor constraintEqualToAnchor:actionDock.bottomAnchor constant:10],
        [searchContainer.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [searchContainer.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [searchContainer.heightAnchor constraintEqualToConstant:40],

        [searchIcon.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor constant:12],
        [searchIcon.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:16],
        [searchIcon.heightAnchor constraintEqualToConstant:16],

        [_searchField.leadingAnchor constraintEqualToAnchor:searchIcon.trailingAnchor constant:8],
        [_searchField.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor constant:-12],
        [_searchField.centerYAnchor constraintEqualToAnchor:searchContainer.centerYAnchor],

        // Filter Rail
        [_categoryFilterRail.topAnchor constraintEqualToAnchor:searchContainer.bottomAnchor constant:10],
        [_categoryFilterRail.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [_categoryFilterRail.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [_categoryFilterRail.heightAnchor constraintEqualToConstant:36],

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

- (UILabel *)makeKPILabelWithColor:(UIColor *)color {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.font = [Styling fontBold:15.5];
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

    UILabel *titleL = [[UILabel alloc] init];
    titleL.translatesAutoresizingMaskIntoConstraints = NO;
    titleL.text = title;
    titleL.font = [Styling fontMedium:11.0];
    titleL.textColor = [UIColor ppTextSecondary];
    titleL.textAlignment = NSTextAlignmentCenter;
    [tile addSubview:titleL];

    [tile addSubview:valLabel];

    [NSLayoutConstraint activateConstraints:@[
        [valLabel.topAnchor constraintEqualToAnchor:tile.topAnchor constant:6],
        [valLabel.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],

        [titleL.topAnchor constraintEqualToAnchor:valLabel.bottomAnchor constant:1],
        [titleL.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [titleL.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor constant:-6]
    ]];

    return tile;
}

- (void)kpiTileTapped:(UITapGestureRecognizer *)gesture {
    [PPFunc pp_playTapEffect];
    NSString *tag = objc_getAssociatedObject(gesture.view, "kpi_tag");
    if ([tag isEqualToString:@"requests"]) {
        [self openRequestsPipeline];
    } else if ([tag isEqualToString:@"active"]) {
        self.selectedFilterCategory = @"active";
        [self updateFilterButtonsSelection];
        [self applyFilterAndReload];
    }
}

#pragma mark - Filter Rail

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
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
        btn.titleLabel.font = [Styling fontBold:12.0];
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

#pragma mark - Cinematic Empty State (When count == 0)

- (void)setupCinematicEmptyState {
    _emptyStateContainer = [[UIView alloc] init];
    _emptyStateContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateContainer.hidden = YES;
    [self.view addSubview:_emptyStateContainer];

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [_emptyStateContainer addSubview:scroll];

    UIView *box = [UIView new];
    box.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:box];

    // Glowing Ambient Emblem
    UIView *glowRing = [UIView new];
    glowRing.translatesAutoresizingMaskIntoConstraints = NO;
    glowRing.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    glowRing.layer.cornerRadius = 36.0;
    [box addSubview:glowRing];

    UIImageView *orbIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles.rectangle.stack.fill"]];
    orbIcon.translatesAutoresizingMaskIntoConstraints = NO;
    orbIcon.tintColor = AppPrimaryClr;
    orbIcon.contentMode = UIViewContentModeScaleAspectFit;
    [glowRing addSubview:orbIcon];

    // Inspirational Copy
    UILabel *headline = [UILabel new];
    headline.translatesAutoresizingMaskIntoConstraints = NO;
    headline.text = kLang(@"Serv_Empty_Pro_Headline");
    headline.font = [Styling fontBold:18.5];
    headline.textColor = PrimaryTextClr;
    headline.textAlignment = NSTextAlignmentCenter;
    [box addSubview:headline];

    UILabel *subheadline = [UILabel new];
    subheadline.translatesAutoresizingMaskIntoConstraints = NO;
    subheadline.text = kLang(@"Serv_Empty_Pro_Subheadline");
    subheadline.font = [Styling fontRegular:13.5];
    subheadline.textColor = SeconderyTextClr;
    subheadline.textAlignment = NSTextAlignmentCenter;
    subheadline.numberOfLines = 2;
    [box addSubview:subheadline];

    // 4 Starter Quick-Launch Template Cards in a 2x2 Grid
    UILabel *templatesHeader = [UILabel new];
    templatesHeader.translatesAutoresizingMaskIntoConstraints = NO;
    templatesHeader.text = Language.isRTL ? @"🚀 قوالب جاهزة للإطلاق السريع بلمسة واحدة:" : @"🚀 Instant 1-Tap Starter Templates:";
    templatesHeader.font = [Styling fontBold:13.5];
    templatesHeader.textColor = AppPrimaryClr;
    templatesHeader.textAlignment = Language.alignmentForCurrentLanguage;
    [box addSubview:templatesHeader];

    UIStackView *cardsGrid = [UIStackView new];
    cardsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    cardsGrid.axis = UILayoutConstraintAxisVertical;
    cardsGrid.spacing = 10.0;
    [box addSubview:cardsGrid];

    NSArray *tpls = @[
        @{@"icon": @"scissors", @"title": kLang(@"Serv_Template_Grooming_Title"), @"price": @"150 QAR", @"kind": @1, @"type": @(PPServiceTypeGrooming)},
        @{@"icon": @"figure.walk", @"title": kLang(@"Serv_Template_Training_Title"), @"price": @"250 QAR", @"kind": @1, @"type": @(PPServiceTypeTraining)},
        @{@"icon": @"heart.text.square.fill", @"title": kLang(@"Serv_Template_Bath_Title"), @"price": @"120 QAR", @"kind": @2, @"type": @(PPServiceTypeGrooming)},
        @{@"icon": @"house.fill", @"title": kLang(@"Serv_Template_Boarding_Title"), @"price": @"180 QAR", @"kind": @1, @"type": @(PPServiceTypeGrooming)}
    ];

    for (NSDictionary *t in tpls) {
        UIView *card = [self makeTemplateCardWithData:t];
        [cardsGrid addArrangedSubview:card];
    }

    // Main CTA Button
    UIButton *mainCTA = [UIButton buttonWithType:UIButtonTypeCustom];
    mainCTA.translatesAutoresizingMaskIntoConstraints = NO;
    mainCTA.backgroundColor = [UIColor ppPrimary];
    [mainCTA setTitle:kLang(@"Serv_Action_CreateFirst") forState:UIControlStateNormal];
    [mainCTA setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    mainCTA.titleLabel.font = [Styling fontBold:16.0];
    PPApplyContinuousCorners(mainCTA, PPCornerMedium);
    PPApplyButtonShadow(mainCTA);
    [mainCTA addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
    [box addSubview:mainCTA];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0],
        [_emptyStateContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_emptyStateContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_emptyStateContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [scroll.topAnchor constraintEqualToAnchor:_emptyStateContainer.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:_emptyStateContainer.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:_emptyStateContainer.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:_emptyStateContainer.bottomAnchor],

        [box.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [box.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [box.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [box.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-20.0],
        [box.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],

        [glowRing.topAnchor constraintEqualToAnchor:box.topAnchor constant:16.0],
        [glowRing.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
        [glowRing.widthAnchor constraintEqualToConstant:72.0],
        [glowRing.heightAnchor constraintEqualToConstant:72.0],

        [orbIcon.centerXAnchor constraintEqualToAnchor:glowRing.centerXAnchor],
        [orbIcon.centerYAnchor constraintEqualToAnchor:glowRing.centerYAnchor],
        [orbIcon.widthAnchor constraintEqualToConstant:36.0],
        [orbIcon.heightAnchor constraintEqualToConstant:36.0],

        [headline.topAnchor constraintEqualToAnchor:glowRing.bottomAnchor constant:12.0],
        [headline.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:20.0],
        [headline.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-20.0],

        [subheadline.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:6.0],
        [subheadline.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:20.0],
        [subheadline.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-20.0],

        [templatesHeader.topAnchor constraintEqualToAnchor:subheadline.bottomAnchor constant:20.0],
        [templatesHeader.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:20.0],
        [templatesHeader.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-20.0],

        [cardsGrid.topAnchor constraintEqualToAnchor:templatesHeader.bottomAnchor constant:10.0],
        [cardsGrid.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16.0],
        [cardsGrid.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16.0],

        [mainCTA.topAnchor constraintEqualToAnchor:cardsGrid.bottomAnchor constant:20.0],
        [mainCTA.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16.0],
        [mainCTA.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16.0],
        [mainCTA.heightAnchor constraintEqualToConstant:50.0],
        [mainCTA.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-30.0],
    ]];
}

- (UIView *)makeTemplateCardWithData:(NSDictionary *)data {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor ppElevatedSurface];
    PPApplyContinuousCorners(card, PPCornerMedium);
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [UIColor ppSurfaceBorder].CGColor;
    card.userInteractionEnabled = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:data[@"icon"]
                                                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold]]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    [card addSubview:icon];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = data[@"title"];
    title.font = [Styling fontBold:13.5];
    title.textColor = PrimaryTextClr;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:title];

    UILabel *price = [UILabel new];
    price.translatesAutoresizingMaskIntoConstraints = NO;
    price.text = data[@"price"];
    price.font = [Styling fontBold:12.5];
    price.textColor = [UIColor ppSuccess];
    [card addSubview:price];

    UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"
                                                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold]]];
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.4];
    [card addSubview:arrow];

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintEqualToConstant:56.0],

        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [icon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22.0],
        [icon.heightAnchor constraintEqualToConstant:22.0],

        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10.0],
        [title.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:price.leadingAnchor constant:-8.0],

        [arrow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [arrow.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [arrow.widthAnchor constraintEqualToConstant:8.0],
        [arrow.heightAnchor constraintEqualToConstant:12.0],

        [price.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8.0],
        [price.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(starterTemplateTapped:)];
    objc_setAssociatedObject(tap, "tpl_data", data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [card addGestureRecognizer:tap];

    return card;
}

- (void)starterTemplateTapped:(UITapGestureRecognizer *)gesture {
    [PPFunc pp_playTapEffect];
    NSDictionary *data = objc_getAssociatedObject(gesture, "tpl_data");
    if (!data) return;

    PPServiceModel *model = [[PPServiceModel alloc] init];
    model.title = data[@"title"];
    model.price = [data[@"price"] doubleValue] > 0 ? [data[@"price"] doubleValue] : 150.0;
    model.currency = @"QAR";
    model.type = (PPServiceType)[data[@"type"] integerValue];
    model.petMainKindID = [data[@"kind"] integerValue];
    model.isAvailable = YES;
    model.descriptionText = [NSString stringWithFormat:@"%@ · %@", data[@"title"], Language.isRTL ? @"باقة احترافية شاملة ومجهزة لحيوانك الأليف." : @"Professional complete care package."];

    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithTemplate:model];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Master Availability Switch Handler

- (void)masterSwitchToggled:(UISwitch *)sender {
    [PPFunc pp_playTapEffect];
    BOOL isLive = sender.isOn;

    _liveBeaconDot.backgroundColor = isLive ? [UIColor ppSuccess] : [UIColor ppWarning];
    _masterStatusLabel.text = isLive ? kLang(@"Serv_Master_Active_State") : kLang(@"Serv_Master_Paused_State");

    [PPHUD showIndeterminateIn:self.view title:isLive ? (Language.isRTL ? @"جارٍ تفعيل جميع الخدمات..." : @"Activating All Services...") : (Language.isRTL ? @"جارٍ إيقاف جميع الخدمات..." : @"Pausing All Services...") subtitle:nil];

    // Optimistically update all services
    for (PPServiceModel *s in self.allServices) {
        s.isAvailable = isLive;
        [[PPServiceManager sharedManager] toggleAvailability:isLive forServiceID:s.serviceID completion:nil];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [PPHUD dismiss];
        [PPHUD showSuccess:isLive ? (Language.isRTL ? @"تم تفعيل ظهور جميع خدماتك بنجاح" : @"All services published live") : (Language.isRTL ? @"تم إيقاف ظهور جميع خدماتك مؤقتاً" : @"All services paused")];
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
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
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

    self.kpiTotalLabel.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.kpiActiveLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)active, (long)total];
    self.kpiRequestsLabel.text = @"2 جديدة";
    self.kpiAvgRateLabel.text = [NSString stringWithFormat:@"%.0f QAR", avgRate];

    self.masterSwitch.on = (active > 0);
    self.liveBeaconDot.backgroundColor = (active > 0) ? [UIColor ppSuccess] : [UIColor ppWarning];
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

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredServices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceCell reuseID] forIndexPath:indexPath];
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [cell configureWithService:s];

    __weak typeof(self) weakSelf = self;
    cell.onToggleAvailability = ^(BOOL newAvailable) {
        [weakSelf toggleAvailabilityForService:s newState:newAvailable];
    };

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPServiceModel *s = self.filteredServices[indexPath.row];
    [self openDetailsForService:s];
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
            [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
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
    PPServiceModel *s = self.filteredServices[indexPath.row];

    __weak typeof(self) weakSelf = self;
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

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAct, editAct]];
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
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:[Language isRTL] ? @"تم حذف الخدمة بنجاح" : @"Service deleted"];
                [weakSelf startObservingServices];
            }
        }];
    } cancelBlock:nil];
}

@end
