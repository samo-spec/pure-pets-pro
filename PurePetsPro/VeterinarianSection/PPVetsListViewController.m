//
//  PPVetsListViewController.m
//  PurePetsAdmin
//
//  Refactored under frontend-skillv2:
//  cardless, edge-to-edge, one accent, strong typography, restrained motion.
//

#import "PPVetsListViewController.h"
#import "PPVetModel.h"
#import "PPVetManager.h"
#import "PPVetCell.h"
#import "PPAddEditVetViewController.h"
#import "PPVetDetailViewController.h"
#import "PPVetSubscriptionViewController.h"
#import "PPFirebaseCompat.h"

typedef NS_ENUM(NSInteger, PPVetListFilter) {
    PPVetListFilterAll = 0,
    PPVetListFilterActive,
    PPVetListFilterDisabled
};

#pragma mark - Filter Chip (text-led, underline accent)

@interface _PPVetFilterChip : UIControl
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIView  *underline;
@property (nonatomic, assign) BOOL selectedState;
- (instancetype)initWithTitle:(NSString *)title;
- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated;
- (void)setCount:(NSInteger)count;
@end

@implementation _PPVetFilterChip

- (instancetype)initWithTitle:(NSString *)title {
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontMedium:14];
        _titleLabel.textColor = SeconderyTextClr;
        _titleLabel.text = title;
        _titleLabel.userInteractionEnabled = NO;
        [self addSubview:_titleLabel];

        _countLabel = [UILabel new];
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _countLabel.font = [Styling fontMedium:11];
        _countLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.55];
        _countLabel.userInteractionEnabled = NO;
        [self addSubview:_countLabel];

        _underline = [UIView new];
        _underline.translatesAutoresizingMaskIntoConstraints = NO;
        _underline.backgroundColor = AppPrimaryClr;
        _underline.alpha = 0.0;
        _underline.userInteractionEnabled = NO;
        [self addSubview:_underline];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_countLabel.firstBaselineAnchor constraintEqualToAnchor:_titleLabel.firstBaselineAnchor],
            [_countLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:6],
            [_countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],
            [_underline.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
            [_underline.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_underline.widthAnchor constraintEqualToAnchor:_titleLabel.widthAnchor],
            [_underline.heightAnchor constraintEqualToConstant:1.5],
            [_underline.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated {
    _selectedState = selected;
    void (^apply)(void) = ^{
        self.titleLabel.textColor = selected ? (PrimaryTextClr) : SeconderyTextClr;
        self.titleLabel.font = selected ? [Styling fontBold:14] : [Styling fontMedium:14];
        self.underline.alpha = selected ? 1.0 : 0.0;
    };
    if (animated) {
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:apply completion:nil];
    } else {
        apply();
    }
}

- (void)setCount:(NSInteger)count {
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)count];
}

@end

#pragma mark - VC

@interface PPVetsListViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate>

@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIView  *titleRule;
@property (nonatomic, strong) UIView  *heroSurfaceView;
@property (nonatomic, strong) UIView  *bgGlowTop;
@property (nonatomic, strong) UIView  *bgGlowBottom;

@property (nonatomic, strong) _PPVetFilterChip *chipAll;
@property (nonatomic, strong) _PPVetFilterChip *chipActive;
@property (nonatomic, strong) _PPVetFilterChip *chipDisabled;

@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyContainer;

@property (nonatomic, strong) NSMutableArray<PPVetModel *> *allVets;
@property (nonatomic, strong) NSMutableArray<PPVetModel *> *filteredVets;
@property (nonatomic, copy)   NSString *searchQuery;
@property (nonatomic, assign) PPVetListFilter activeFilter;
@property (nonatomic, assign) NSInteger countAll;
@property (nonatomic, assign) NSInteger countActive;
@property (nonatomic, assign) NSInteger countDisabled;

@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation PPVetsListViewController

#pragma mark - User & permissions (unchanged behavior)

- (UserModel *)pp_currentUser {
    return UsrMgr.currentUser;
}

- (NSString *)pp_currentPartnerUID {
    UserModel *user = [self pp_currentUser];
    if (user.uid.length > 0) return user.uid;
    if (user.ID.length > 0) return user.ID;
    return [FIRAuth auth].currentUser.uid ?: @"";
}

- (BOOL)pp_canManageVetWorkspace {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canManageVetPermission;
}

- (BOOL)pp_canCreateVetProfiles {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canPostVetProfilePermission;
}

- (BOOL)pp_canEditVetProfiles {
    UserModel *user = [self pp_currentUser];
    return user.canVetFeature && user.canEditVetInfoPermission;
}

- (BOOL)pp_currentUserOwnsVet:(PPVetModel *)vet {
    NSString *currentUID = [self pp_currentPartnerUID];
    return currentUID.length > 0 && [PPSafeString(vet.userID) isEqualToString:currentUID];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [self pp_canvasColor];

    self.allVets       = [NSMutableArray array];
    self.filteredVets  = [NSMutableArray array];
    self.searchQuery   = @"";
    self.activeFilter  = PPVetListFilterAll;
    self.didPlayEntrance = NO;

    [self setupAmbientBackground];
    [self setupTitleHeader];
    [self setupFilterRow];
    [self setupSearchField];
    [self setupTableView];
    [self setupEmptyState];
    [self startListening];
}

- (UIColor *)pp_canvasColor {
    return [UIColor ppBackground];
}

- (UIColor *)pp_surfaceColor {
    return [UIColor ppElevatedSurface];
}

- (UIColor *)pp_borderColor {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72];
}

- (void)setupAmbientBackground {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 120.0;
    [self.view addSubview:self.bgGlowTop];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 104.0;
    [self.view addSubview:self.bgGlowBottom];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:240.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:240.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-82.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:80.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:70.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-76.0],
    ]];

    [self updateAmbientBackgroundForStyle];
}

- (void)updateAmbientBackgroundForStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.bgGlowTop.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:isDark ? 0.05 : 0.11];
    self.bgGlowTop.layer.shadowColor = AppPrimaryClr.CGColor;
    self.bgGlowTop.layer.shadowOpacity = isDark ? 0.04 : 0.10;
    self.bgGlowTop.layer.shadowRadius = 70.0;
    self.bgGlowBottom.backgroundColor = [[UIColor ppQuickActionServices] colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgGlowBottom.layer.shadowColor = [UIColor ppQuickActionServices].CGColor;
    self.bgGlowBottom.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgGlowBottom.layer.shadowRadius = 68.0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = [self pp_canvasColor];
        self.heroSurfaceView.backgroundColor = [self pp_surfaceColor];
        self.heroSurfaceView.layer.borderColor = [self pp_borderColor].CGColor;
        [self updateAmbientBackgroundForStyle];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self pp_canCreateVetProfiles]) {
        UIButton *plus = [self pp_ButtonWithSystemName:@"plus" action:@selector(addVetTapped)];
        plus.accessibilityLabel = kLang(@"Vet_Add_Title");
        [self pp_navBarWithOtherButton:plus title:kLang(@"Vet_Section_Title")];
    } else {
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Vet_Section_Title") showBack:YES];
    }
}

- (void)dealloc {
    [self.listener remove];
}

#pragma mark - Title (one strong typographic statement, no card)

- (void)setupTitleHeader {
    BOOL rtl = Language.isRTL;
    NSTextAlignment align = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;

    _heroSurfaceView = [UIView new];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.backgroundColor = [self pp_surfaceColor];
    _heroSurfaceView.layer.cornerRadius = 34.0;
    _heroSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _heroSurfaceView.layer.borderColor = [self pp_borderColor].CGColor;
    _heroSurfaceView.layer.shadowColor = AppShadowColor.CGColor;
    _heroSurfaceView.layer.shadowOpacity = 0.08;
    _heroSurfaceView.layer.shadowRadius = 24.0;
    _heroSurfaceView.layer.shadowOffset = CGSizeMake(0, 14.0);
    [self.view addSubview:_heroSurfaceView];

    UIView *accentBar = [UIView new];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    accentBar.layer.cornerRadius = 3.0;
    [_heroSurfaceView addSubview:accentBar];

    _eyebrowLabel = [UILabel new];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.text = [kLang(@"Vet_Section_Title") uppercaseString];
    _eyebrowLabel.font = [Styling fontBold:11];
    _eyebrowLabel.textColor = AppPrimaryClr;
    _eyebrowLabel.textAlignment = align;
    [_heroSurfaceView addSubview:_eyebrowLabel];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = kLang(@"Vet_Manage_Title");
    _titleLabel.font = [Styling fontBold:30];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.numberOfLines = 2;
    _titleLabel.textAlignment = align;
    [_heroSurfaceView addSubview:_titleLabel];

    _metaLabel = [UILabel new];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.text = @"";
    _metaLabel.font = [Styling fontMedium:13];
    _metaLabel.textColor = SeconderyTextClr;
    _metaLabel.textAlignment = align;
    [_heroSurfaceView addSubview:_metaLabel];

    _titleRule = [UIView new];
    _titleRule.translatesAutoresizingMaskIntoConstraints = NO;
    _titleRule.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.10];
    [_heroSurfaceView addSubview:_titleRule];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_heroSurfaceView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [_heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],

        [accentBar.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:18],
        [accentBar.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:22],
        [accentBar.widthAnchor constraintEqualToConstant:70],
        [accentBar.heightAnchor constraintEqualToConstant:6],

        [_eyebrowLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16],
        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:22],
        [_eyebrowLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-22],

        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:6],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_eyebrowLabel.trailingAnchor],

        [_metaLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_metaLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_titleRule.topAnchor constraintEqualToAnchor:_metaLabel.bottomAnchor constant:18],
        [_titleRule.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:22],
        [_titleRule.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-22],
        [_titleRule.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [_titleRule.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-18],
    ]];
}

#pragma mark - Filter row (text + count, accent underline)

- (void)setupFilterRow {
    _chipAll      = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_All")];
    _chipActive   = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_Active")];
    _chipDisabled = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_Disabled")];
    [_chipAll      addTarget:self action:@selector(chipAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipActive   addTarget:self action:@selector(chipActiveTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipDisabled addTarget:self action:@selector(chipDisabledTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipAll setSelectedState:YES animated:NO];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_chipAll, _chipActive, _chipDisabled]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentLastBaseline;
    stack.spacing = 22;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:18],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];
}

- (void)chipAllTapped      { [self setActiveFilter:PPVetListFilterAll]; }
- (void)chipActiveTapped   { [self setActiveFilter:PPVetListFilterActive]; }
- (void)chipDisabledTapped { [self setActiveFilter:PPVetListFilterDisabled]; }

- (void)setActiveFilter:(PPVetListFilter)filter {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    [PPFunc pp_playTapEffect];
    [self.chipAll      setSelectedState:(filter == PPVetListFilterAll)      animated:YES];
    [self.chipActive   setSelectedState:(filter == PPVetListFilterActive)   animated:YES];
    [self.chipDisabled setSelectedState:(filter == PPVetListFilterDisabled) animated:YES];
    [self applyFilterAndReload];
}

#pragma mark - Search (thin, edge-to-edge)

- (void)setupSearchField {
    PPS *sv = [[PPS alloc] initWithFrame:CGRectZero];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.delegate = self;
    sv.cornerRadius = 0;
    sv.blurEnabled = NO;
    sv.shadowEnabled = NO;
    sv.strokeColor = UIColor.clearColor;
    sv.textField.placeholder = kLang(@"Vet_Search_Placeholder");
    sv.backgroundColor = UIColor.clearColor;
    sv.showsPrimaryButton = NO;
    [self.view addSubview:sv];
    self.searchView = sv;

    UIView *hairline = [UIView new];
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    hairline.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.10];
    [self.view addSubview:hairline];

    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.chipAll.bottomAnchor constant:18],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [sv.heightAnchor constraintEqualToConstant:40],

        [hairline.topAnchor constraintEqualToAnchor:sv.bottomAnchor constant:6],
        [hairline.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [hairline.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [hairline.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];
}

#pragma mark - Table

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = [PPVetCell preferredHeight];
    self.tableView.estimatedRowHeight = [PPVetCell preferredHeight];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(8, 0, 96, 0);
    [self.tableView registerClass:[PPVetCell class] forCellReuseIdentifier:[PPVetCell reuseID]];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = AppPrimaryClr;
    [refresh addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchView.bottomAnchor constant:14],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)onRefresh {
    __weak typeof(self) weakSelf = self;
    [[PPVetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<PPVetModel *> *vets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView.refreshControl endRefreshing];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
                return;
            }
            weakSelf.allVets = [vets mutableCopy] ?: [NSMutableArray array];
            [weakSelf refreshCounts];
            [weakSelf applyFilterAndReload];
        });
    }];
}

#pragma mark - Empty state (typographic, no decoration)

- (void)setupEmptyState {
    _emptyContainer = [UIView new];
    _emptyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyContainer.hidden = YES;
    [self.view addSubview:_emptyContainer];

    UILabel *headline = [UILabel new];
    headline.translatesAutoresizingMaskIntoConstraints = NO;
    headline.text = kLang(@"Vet_Empty_List");
    headline.font = [Styling fontBold:22];
    headline.textColor = PrimaryTextClr;
    headline.textAlignment = NSTextAlignmentCenter;
    headline.numberOfLines = 0;
    [_emptyContainer addSubview:headline];

    UIView *rule = [UIView new];
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    rule.backgroundColor = AppPrimaryClr;
    [_emptyContainer addSubview:rule];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [_emptyContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        [headline.topAnchor constraintEqualToAnchor:_emptyContainer.topAnchor],
        [headline.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [headline.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],

        [rule.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:18],
        [rule.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [rule.widthAnchor constraintEqualToConstant:42],
        [rule.heightAnchor constraintEqualToConstant:2],
        [rule.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor],
    ]];
}

#pragma mark - Data

- (void)startListening {
    __weak typeof(self) weakSelf = self;
    self.listener = [[PPVetManager sharedManager] observeAllVets:^(NSArray<PPVetModel *> *vets, NSError *error) {
        if (error) { DLog(@"[VetsList] listener error: %@", error.localizedDescription); return; }
        __strong typeof(weakSelf) self = weakSelf;
        self.allVets = [vets mutableCopy] ?: [NSMutableArray array];
        [self refreshCounts];
        [self applyFilterAndReload];
    }];
}

- (void)refreshCounts {
    NSInteger total = 0, active = 0, disabled = 0;
    for (PPVetModel *v in self.allVets) {
        if (![self pp_currentUserOwnsVet:v]) continue;
        total++;
        if (v.isDisabled) disabled++; else active++;
    }
    self.countAll = total; self.countActive = active; self.countDisabled = disabled;
    [self.chipAll      setCount:total];
    [self.chipActive   setCount:active];
    [self.chipDisabled setCount:disabled];

    self.metaLabel.text = total == 0
        ? kLang(@"Vet_Empty_List")
        : [NSString stringWithFormat:@"%ld %@", (long)total, kLang(@"Vet_Section_Title")];
}

- (void)applyFilterAndReload {
    NSMutableArray<PPVetModel *> *result = [NSMutableArray array];
    for (PPVetModel *vet in self.allVets) {
        if (![self pp_currentUserOwnsVet:vet]) continue;
        if (self.activeFilter == PPVetListFilterActive   &&  vet.isDisabled) continue;
        if (self.activeFilter == PPVetListFilterDisabled && !vet.isDisabled) continue;

        NSString *q = PPSafeString(self.searchQuery).lowercaseString;
        if (q.length > 0) {
            NSString *name  = PPSafeString(vet.title).lowercaseString;
            NSString *desc  = PPSafeString(vet.descriptionText).lowercaseString;
            NSString *phone = PPSafeString(vet.phone).lowercaseString;
            if (![name containsString:q] && ![desc containsString:q] && ![phone containsString:q]) continue;
        }
        [result addObject:vet];
    }

    [result sortUsingComparator:^NSComparisonResult(PPVetModel *a, PPVetModel *b) {
        if (a.isDisabled != b.isDisabled) return a.isDisabled ? NSOrderedDescending : NSOrderedAscending;
        return [a.title localizedCaseInsensitiveCompare:b.title ?: @""];
    }];

    self.filteredVets = result;
    [self.tableView reloadData];
    self.emptyContainer.hidden = (self.filteredVets.count > 0);
    self.tableView.hidden      = (self.filteredVets.count == 0);

    if (!self.didPlayEntrance && self.filteredVets.count > 0) {
        self.didPlayEntrance = YES;
        [self playCellEntranceAnimation];
    }
}

- (PPVetModel *)vetAtIndexPath:(NSIndexPath *)ip {
    if (!ip || ip.row >= (NSInteger)self.filteredVets.count) return nil;
    return self.filteredVets[ip.row];
}

#pragma mark - Motion (one entrance, restrained)

- (void)playCellEntranceAnimation {
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    for (NSUInteger idx = 0; idx < cells.count; idx++) {
        UITableViewCell *cell = cells[idx];
        cell.alpha = 0;
        cell.transform = CGAffineTransformMakeTranslation(0, 16);
        [UIView animateWithDuration:0.42
                              delay:0.035 * idx
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.30
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            cell.alpha = 1;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Actions (unchanged behavior)

- (void)addVetTapped {
    if (![self pp_canCreateVetProfiles]) {
        [PPHUD showError:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
        return;
    }
    [PPFunc pp_playTapEffect];
    PPAddEditVetViewController *vc = [[PPAddEditVetViewController alloc] initWithVet:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)editVetAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    if (!vet || ![self pp_canEditVetProfiles]) return;
    [PPFunc pp_playTapEffect];
    PPAddEditVetViewController *vc = [[PPAddEditVetViewController alloc] initWithVet:vet];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)viewVetAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    if (!vet) return;
    [PPFunc pp_playTapEffect];
    PPVetDetailViewController *vc = [[PPVetDetailViewController alloc] initWithVet:vet];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)toggleDisabledAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    if (!vet || ![self pp_canManageVetWorkspace]) return;

    BOOL newState = !vet.isDisabled;
    NSString *confirmTitle = newState ? kLang(@"Vet_Confirm_Disable_Title") : kLang(@"Vet_Confirm_Enable_Title");
    NSString *confirmMsg   = newState ? kLang(@"Vet_Confirm_Disable_Msg")   : kLang(@"Vet_Confirm_Enable_Msg");
    NSString *confirmBtn   = newState ? kLang(@"Vet_Action_Disable")        : kLang(@"Vet_Action_Enable");

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                              title:confirmTitle
                           subtitle:confirmMsg
                        placeholder:nil
                      confirmButton:confirmBtn
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:kLang(@"Vet_Updating") subtitle:nil];
        [[PPVetManager sharedManager] setDisabled:newState forVetID:vet.vetID completion:^(NSError *error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:kLang(@"Updated") subtitle:newState ? kLang(@"Vet_Disabled_Success") : kLang(@"Vet_Enabled_Success")];
            }
        }];
    } cancelBlock:nil];
}

- (void)deleteVetAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    if (!vet || ![self pp_canManageVetWorkspace]) return;

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                              title:kLang(@"Vet_Confirm_Delete_Title")
                           subtitle:kLang(@"Vet_Confirm_Delete_Msg")
                        placeholder:nil
                      confirmButton:kLang(@"Delete")
                       cancelButton:kLang(@"Cancel")
                       confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:kLang(@"Deleting") subtitle:nil];
        [[PPVetManager sharedManager] deleteVet:vet completion:^(NSError *error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:kLang(@"Deleted") subtitle:kLang(@"Vet_Deleted_Success")];
            }
        }];
    } cancelBlock:nil];
}

- (void)manageSubscriptionAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    if (!vet || ![self pp_canManageVetWorkspace]) return;
    [PPFunc pp_playTapEffect];
    PPVetSubscriptionViewController *vc = [[PPVetSubscriptionViewController alloc] initWithVet:vet];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - PPSDelegate

- (void)searchView:(PPS *)view didChangeText:(NSString *)text {
    self.searchQuery = text ?: @"";
    [self applyFilterAndReload];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredVets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPVetCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPVetCell reuseID] forIndexPath:indexPath];
    PPVetModel *vet = [self vetAtIndexPath:indexPath];
    if (vet) [cell configureWithVet:vet];
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self viewVetAtIndexPath:indexPath];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                       point:(CGPoint)point API_AVAILABLE(ios(13.0)) {

    PPVetModel *vet = [self vetAtIndexPath:indexPath];
    if (!vet) return nil;
    __weak typeof(self) weakSelf = self;

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
        UIAction *viewAction = [UIAction actionWithTitle:kLang(@"Vet_Detail_Title")
                                                   image:[UIImage systemImageNamed:@"eye"]
                                              identifier:nil
                                                 handler:^(UIAction *action) { [weakSelf viewVetAtIndexPath:indexPath]; }];

        UIAction *editAction = [UIAction actionWithTitle:kLang(@"Vet_Edit_Title")
                                                   image:[UIImage systemImageNamed:@"pencil"]
                                              identifier:nil
                                                 handler:^(UIAction *action) { [weakSelf editVetAtIndexPath:indexPath]; }];
        if (![self pp_canEditVetProfiles]) editAction.attributes = UIMenuElementAttributesDisabled;

        BOOL disabled = vet.isDisabled;
        UIAction *toggleAction = [UIAction actionWithTitle:disabled ? kLang(@"Vet_Action_Enable") : kLang(@"Vet_Action_Disable")
                                                     image:[UIImage systemImageNamed:disabled ? @"checkmark.circle" : @"nosign"]
                                                identifier:nil
                                                   handler:^(UIAction *action) { [weakSelf toggleDisabledAtIndexPath:indexPath]; }];
        if (![self pp_canManageVetWorkspace]) toggleAction.attributes = UIMenuElementAttributesDisabled;
        if (!disabled) toggleAction.attributes = UIMenuElementAttributesDestructive;

        UIAction *subAction = [UIAction actionWithTitle:kLang(@"Vet_Subscription")
                                                  image:[UIImage systemImageNamed:@"creditcard.circle"]
                                             identifier:nil
                                                handler:^(UIAction *action) { [weakSelf manageSubscriptionAtIndexPath:indexPath]; }];
        if (![self pp_canManageVetWorkspace]) subAction.attributes = UIMenuElementAttributesDisabled;

        UIAction *callAction = [UIAction actionWithTitle:kLang(@"Vet_Field_Phone")
                                                   image:[UIImage systemImageNamed:@"phone"]
                                              identifier:nil
                                                 handler:^(UIAction *action) {
            NSString *phone = [vet.phone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (phone.length == 0) return;
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tel://" stringByAppendingString:phone]] options:@{} completionHandler:nil];
        }];
        if (vet.phone.length == 0) callAction.attributes = UIMenuElementAttributesDisabled;

        UIAction *deleteAction = [UIAction actionWithTitle:kLang(@"Delete")
                                                     image:[UIImage systemImageNamed:@"trash"]
                                                identifier:nil
                                                   handler:^(UIAction *action) { [weakSelf deleteVetAtIndexPath:indexPath]; }];
        deleteAction.attributes = [self pp_canManageVetWorkspace] ? UIMenuElementAttributesDestructive : UIMenuElementAttributesDisabled;

        UIMenu *primary = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[viewAction, editAction]];
        UIMenu *manage  = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[toggleAction, subAction, callAction]];
        UIMenu *danger  = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[deleteAction]];
        return [UIMenu menuWithTitle:vet.title ?: @"" children:@[primary, manage, danger]];
    }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    PPVetModel *vet = [self vetAtIndexPath:indexPath];

    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf editVetAtIndexPath:indexPath]; handler(YES);
    }];
    editAction.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.85];
    editAction.image = [UIImage systemImageNamed:@"pencil"];

    BOOL isDisabled = vet.isDisabled;
    UIContextualAction *toggleAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf toggleDisabledAtIndexPath:indexPath]; handler(YES);
    }];
    toggleAction.backgroundColor = isDisabled ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.55];
    toggleAction.image = [UIImage systemImageNamed:isDisabled ? @"checkmark" : @"nosign"];

    UIContextualAction *subAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf manageSubscriptionAtIndexPath:indexPath]; handler(YES);
    }];
    subAction.backgroundColor = AppPrimaryClr;
    subAction.image = [UIImage systemImageNamed:@"creditcard"];

    NSMutableArray<UIContextualAction *> *leading = [NSMutableArray array];
    if ([self pp_canManageVetWorkspace]) { [leading addObject:subAction]; [leading addObject:toggleAction]; }
    if ([self pp_canEditVetProfiles])     { [leading addObject:editAction]; }
    if (leading.count == 0) return nil;

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:leading.copy];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf deleteVetAtIndexPath:indexPath]; handler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash"];
    if (![self pp_canManageVetWorkspace]) return nil;
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.didPlayEntrance) {
        cell.alpha = 0;
        [UIView animateWithDuration:0.22 animations:^{ cell.alpha = 1; }];
    }
}

@end
