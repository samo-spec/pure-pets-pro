//
//  PPServicesListViewController.m
//  PurePetsPro
//
//  Modern services list — glassmorphism stat cards, pill filter chips,
//  rich empty state with CTA, permission-aware add button, staggered entrance.
//

#import "PPServicesListViewController.h"
#import "PPServiceModel.h"
#import "PPServiceManager.h"
#import "PPServiceCell.h"
#import "PPAddEditServiceViewController.h"
#import "PPServiceDetailViewController.h"
#import "PPFirebaseCompat.h"
#import "PPRolePermission.h"
#import "PurePetsPro-Swift.h"

typedef NS_ENUM(NSInteger, PPServiceListFilter) {
    PPServiceListFilterAll = 0,
    PPServiceListFilterAvailable,
    PPServiceListFilterUnavailable
};

@interface PPServicesListViewController () <UITableViewDataSource, UITableViewDelegate, PPSDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UIView *bgGlowTop;
@property (nonatomic, strong) UIView *bgGlowBottom;

/* Stats header */
@property (nonatomic, strong) PPHero *statsContainer;
@property (nonatomic, strong) UILabel *statTotal;
@property (nonatomic, strong) UILabel *statActive;
@property (nonatomic, strong) UILabel *statDisabled;

/* Pill filter chips */
@property (nonatomic, strong) UIScrollView *pillStrip;
@property (nonatomic, strong) NSArray<UIButton *> *pillButtons;

@property (nonatomic, strong) NSMutableArray<PPServiceModel *> *allServices;
@property (nonatomic, strong) NSMutableArray<PPServiceModel *> *filteredServices;
@property (nonatomic, copy)   NSString *searchQuery;
@property (nonatomic, assign) PPServiceListFilter activeFilter;

@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, assign) BOOL didPlayEntrance;
@property (nonatomic, assign) BOOL hasPermission;
@end

@implementation PPServicesListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;

    self.allServices      = [NSMutableArray array];
    self.filteredServices = [NSMutableArray array];
    self.searchQuery      = @"";
    self.activeFilter     = PPServiceListFilterAll;
    self.hasPermission    = [self checkServicePermission];

    [self setupAmbientBackground];
    [self setupStatsHeader];
    [self setupPillFilters];
    [self setupTableView];
    [self setupEmptyState];
    [self startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.hasPermission) {
        UIButton *plus = [self pp_ButtonWithSystemName:@"plus" action:@selector(addServiceTapped)];
        [self pp_navBarWithOtherButton:plus title:kLang(@"ManageServices")];
    } else {
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"ManageServices") showBack:YES];
    }
}

- (void)dealloc {
    [self.listener remove];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
}

#pragma mark - Ambient Background

- (void)setupAmbientBackground {
    self.bgGlowTop = [[UIView alloc] init];
    self.bgGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowTop.userInteractionEnabled = NO;
    self.bgGlowTop.layer.cornerRadius = 122.0;
    [self.view insertSubview:self.bgGlowTop atIndex:0];

    self.bgGlowBottom = [[UIView alloc] init];
    self.bgGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgGlowBottom.userInteractionEnabled = NO;
    self.bgGlowBottom.layer.cornerRadius = 104.0;
    [self.view insertSubview:self.bgGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgGlowTop.widthAnchor constraintEqualToConstant:244.0],
        [self.bgGlowTop.heightAnchor constraintEqualToConstant:244.0],
        [self.bgGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-84.0],
        [self.bgGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [self.bgGlowBottom.widthAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.heightAnchor constraintEqualToConstant:208.0],
        [self.bgGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:74.0],
        [self.bgGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-74.0],
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

#pragma mark - Permission

- (BOOL)checkServicePermission {
    UserModel *me = [UserManager shared].currentUser;
    if (!me) return NO;
    if (me.canOfferServices) return YES;
    if ([me hasPermissionNamed:kPermManageServices]) return YES;
    if ([me hasPermissionNamed:kPermAdminAll]) return YES;
    if (me.isSuperAdmin || me.isAdmin || me.role == UserRoleSuperAdmin || me.role == UserRoleAdmin) return YES;
    return NO;
}

#pragma mark - Stats Header

- (void)setupStatsHeader {
    _statsContainer = [[PPHero alloc] init];
    _statsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _statsContainer.accentColor = AppPrimaryClr;
    [self.view addSubview:_statsContainer];

    UIView *accent = [UIView new];
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    accent.backgroundColor = AppPrimaryClr;
    accent.layer.cornerRadius = 2.0;
    [_statsContainer addSubview:accent];

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"ManageServices");
    titleLabel.font = [Styling fontBold:24.0];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [_statsContainer addSubview:titleLabel];

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"Serv_Manage_Subtitle");
    subtitleLabel.font = [Styling fontMedium:12.5];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    [_statsContainer addSubview:subtitleLabel];

    UIView *totalCard       = [self buildStatCard:kLang(@"Serv_Stats_Total")       valueLabel:&_statTotal    color:AppPrimaryClr];
    UIView *availableCard   = [self buildStatCard:kLang(@"Serv_Stats_Available")   valueLabel:&_statActive   color:[UIColor ppSuccess]];
    UIView *unavailableCard = [self buildStatCard:kLang(@"Serv_Stats_Unavailable") valueLabel:&_statDisabled color:[UIColor ppWarning]];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        totalCard, availableCard, unavailableCard
    ]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_statsContainer addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_statsContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [_statsContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [_statsContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [_statsContainer.heightAnchor constraintEqualToConstant:154],

        [accent.topAnchor constraintEqualToAnchor:_statsContainer.topAnchor constant:22],
        [accent.leadingAnchor constraintEqualToAnchor:_statsContainer.leadingAnchor constant:22],
        [accent.widthAnchor constraintEqualToConstant:54],
        [accent.heightAnchor constraintEqualToConstant:4],

        [titleLabel.topAnchor constraintEqualToAnchor:accent.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_statsContainer.leadingAnchor constant:22],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_statsContainer.trailingAnchor constant:-22],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:_statsContainer.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:_statsContainer.trailingAnchor constant:-18],
        [stack.bottomAnchor constraintEqualToAnchor:_statsContainer.bottomAnchor constant:-16],
        [stack.heightAnchor constraintEqualToConstant:48],
    ]];
}

- (UIView *)buildStatCard:(NSString *)title valueLabel:(UILabel *__strong *)outLabel color:(UIColor *)accent {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *numLbl = [UILabel new];
    numLbl.translatesAutoresizingMaskIntoConstraints = NO;
    numLbl.text = @"0";
    numLbl.font = [Styling fontBold:18];
    numLbl.textColor = accent;
    numLbl.textAlignment = NSTextAlignmentCenter;
    [card addSubview:numLbl];

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = title;
    titleLbl.font = [Styling fontMedium:10];
    titleLbl.textColor = [accent colorWithAlphaComponent:0.7];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [card addSubview:titleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [numLbl.topAnchor constraintEqualToAnchor:card.topAnchor constant:6],
        [numLbl.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [titleLbl.topAnchor constraintEqualToAnchor:numLbl.bottomAnchor constant:1],
        [titleLbl.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [titleLbl.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-6],
    ]];

    if (outLabel) *outLabel = numLbl;
    return card;
}

- (void)updateStats {
    NSInteger total = self.allServices.count;
    NSInteger available = 0, unavailable = 0;
    for (PPServiceModel *s in self.allServices) {
        if (s.isAvailable && !s.isDisabled && !s.isBlocked) available++;
        else unavailable++;
    }
    self.statTotal.text    = [NSString stringWithFormat:@"%ld", (long)total];
    self.statActive.text   = [NSString stringWithFormat:@"%ld", (long)available];
    self.statDisabled.text = [NSString stringWithFormat:@"%ld", (long)unavailable];
}

#pragma mark - Pill Filters

- (void)setupPillFilters {
    _pillStrip = [UIScrollView new];
    _pillStrip.translatesAutoresizingMaskIntoConstraints = NO;
    _pillStrip.showsHorizontalScrollIndicator = NO;
    _pillStrip.clipsToBounds = NO;
    [self.view addSubview:_pillStrip];

    NSArray *titles = @[kLang(@"Serv_Filter_All"), kLang(@"Serv_Filter_Available"), kLang(@"Serv_Filter_Unavailable")];
    NSArray *icons  = @[@"line.3.horizontal.decrease.circle", @"checkmark.circle", @"pause.circle"];

    UIStackView *pillStack = [UIStackView new];
    pillStack.axis = UILayoutConstraintAxisHorizontal;
    pillStack.spacing = 8;
    pillStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_pillStrip addSubview:pillStack];

    NSMutableArray *btns = [NSMutableArray array];
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.tag = i;

        UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
        UIImage *ico = [UIImage systemImageNamed:icons[i] withConfiguration:symCfg];
        [btn setImage:ico forState:UIControlStateNormal];
        [btn setTitle:[NSString stringWithFormat:@" %@", titles[i]] forState:UIControlStateNormal];
        btn.titleLabel.font = [Styling fontBold:12];
        btn.layer.cornerRadius = 16;
        btn.layer.cornerCurve = kCACornerCurveContinuous;
        btn.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
        [btn addTarget:self action:@selector(pillTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [btn.heightAnchor constraintEqualToConstant:32].active = YES;

        [pillStack addArrangedSubview:btn];
        [btns addObject:btn];
    }
    self.pillButtons = [btns copy];
    [self highlightPillAtIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [_pillStrip.topAnchor constraintEqualToAnchor:_statsContainer.bottomAnchor constant:14],
        [_pillStrip.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_pillStrip.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_pillStrip.heightAnchor constraintEqualToConstant:36],
        [pillStack.topAnchor constraintEqualToAnchor:_pillStrip.topAnchor],
        [pillStack.leadingAnchor constraintEqualToAnchor:_pillStrip.leadingAnchor constant:16],
        [pillStack.trailingAnchor constraintEqualToAnchor:_pillStrip.trailingAnchor constant:-16],
        [pillStack.bottomAnchor constraintEqualToAnchor:_pillStrip.bottomAnchor],
    ]];
}

- (void)highlightPillAtIndex:(NSInteger)idx {
    for (NSInteger i = 0; i < self.pillButtons.count; i++) {
        UIButton *b = self.pillButtons[i];
        BOOL sel = (i == idx);
        b.backgroundColor = sel ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.06];
        b.tintColor = sel ? UIColor.whiteColor : SeconderyTextClr;
        [b setTitleColor:sel ? UIColor.whiteColor : SeconderyTextClr forState:UIControlStateNormal];
    }
}

- (void)pillTapped:(UIButton *)sender {
    [PPFunc pp_playTapEffect];
    self.activeFilter = (PPServiceListFilter)sender.tag;
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:0 animations:^{
        [self highlightPillAtIndex:sender.tag];
    } completion:nil];
    [self applyFilterAndReload];
}

#pragma mark - Table View

- (void)setupTableView {
    CGFloat searchH = 46.0;
    CGFloat pad = 8.0;

    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, searchH + pad * 2)];
    headerContainer.backgroundColor = UIColor.clearColor;

    PPS *sv = [[PPS alloc] initWithFrame:CGRectZero];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.delegate = self;
    sv.cornerRadius = searchH / 2.0;
    sv.blurEnabled = NO;
    sv.shadowEnabled = NO;
    sv.strokeColor = [SeconderyTextClr colorWithAlphaComponent:0.1];
    sv.textField.placeholder = kLang(@"Serv_Search_Placeholder");
    sv.textField.font = [Styling fontMedium:14];
    sv.backgroundColor = AppForgroundColr;
    sv.showsPrimaryButton = NO;
    [headerContainer addSubview:sv];
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:headerContainer.topAnchor constant:pad],
        [sv.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:16],
        [sv.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor constant:-16],
        [sv.heightAnchor constraintEqualToConstant:searchH]
    ]];
    self.searchView = sv;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = [PPServiceCell preferredHeight];
    self.tableView.estimatedRowHeight = [PPServiceCell preferredHeight];
    self.tableView.tableHeaderView = headerContainer;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = AppPrimaryClr;
    [refresh addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    [self.tableView registerClass:[PPServiceCell class] forCellReuseIdentifier:[PPServiceCell reuseID]];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.pillStrip.bottomAnchor constant:6],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Empty State

- (void)setupEmptyState {
    _emptyContainer = [UIView new];
    _emptyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyContainer.hidden = YES;
    [self.view addSubview:_emptyContainer];

    /* Gradient background circle behind icon */
    UIView *circle = [UIView new];
    circle.translatesAutoresizingMaskIntoConstraints = NO;
    circle.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    circle.layer.cornerRadius = 44;
    [_emptyContainer addSubview:circle];

    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [UIImage systemImageNamed:@"sparkles"
                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:32 weight:UIImageSymbolWeightMedium]];
    icon.tintColor = AppPrimaryClr;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [circle addSubview:icon];

    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = kLang(@"Serv_Empty_Title");
    titleLbl.font = [Styling fontBold:18];
    titleLbl.textColor = PrimaryTextClr;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [_emptyContainer addSubview:titleLbl];

    UILabel *subtitleLbl = [UILabel new];
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLbl.text = kLang(@"Serv_Empty_Subtitle");
    subtitleLbl.font = [Styling fontMedium:13];
    subtitleLbl.textColor = SeconderyTextClr;
    subtitleLbl.textAlignment = NSTextAlignmentCenter;
    subtitleLbl.numberOfLines = 0;
    [_emptyContainer addSubview:subtitleLbl];

    // CTA only if user has permission
    UIButton *cta = nil;
    if (self.hasPermission) {
        cta = [UIButton buttonWithType:UIButtonTypeCustom];
        cta.translatesAutoresizingMaskIntoConstraints = NO;
        [cta setTitle:[NSString stringWithFormat:@"  %@", kLang(@"AddService")] forState:UIControlStateNormal];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
        [cta setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:cfg] forState:UIControlStateNormal];
        cta.tintColor = UIColor.whiteColor;
        [cta setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        cta.titleLabel.font = [Styling fontBold:14];
        cta.backgroundColor = AppPrimaryClr;
        cta.layer.cornerRadius = 22;
        cta.layer.cornerCurve = kCACornerCurveContinuous;
        cta.contentEdgeInsets = UIEdgeInsetsMake(0, 24, 0, 24);
        [cta addTarget:self action:@selector(addServiceTapped) forControlEvents:UIControlEventTouchUpInside];
        [_emptyContainer addSubview:cta];
    }

    NSMutableArray *constraints = [@[
        [_emptyContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:20],
        [_emptyContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40],
        [circle.topAnchor constraintEqualToAnchor:_emptyContainer.topAnchor],
        [circle.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [circle.widthAnchor constraintEqualToConstant:88],
        [circle.heightAnchor constraintEqualToConstant:88],
        [icon.centerXAnchor constraintEqualToAnchor:circle.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:circle.centerYAnchor],
        [titleLbl.topAnchor constraintEqualToAnchor:circle.bottomAnchor constant:20],
        [titleLbl.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [subtitleLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:8],
        [subtitleLbl.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [subtitleLbl.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],
    ] mutableCopy];

    if (cta) {
        [constraints addObjectsFromArray:@[
            [cta.topAnchor constraintEqualToAnchor:subtitleLbl.bottomAnchor constant:24],
            [cta.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
            [cta.heightAnchor constraintEqualToConstant:44],
            [cta.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor],
        ]];
    } else {
        [constraints addObject:[subtitleLbl.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - Data

- (void)startListening {
    __weak typeof(self) weakSelf = self;
    NSString *ownerID = [FIRAuth auth].currentUser.uid;
    self.listener = [[PPServiceManager sharedManager] observeServicesForOwnerID:ownerID onChange:^(NSArray<PPServiceModel *> *services, NSError *error) {
        if (error) return;
        __strong typeof(weakSelf) self = weakSelf;
        self.allServices = [services mutableCopy] ?: [NSMutableArray array];
        [self updateStats];
        [self applyFilterAndReload];
    }];
}

- (void)onRefresh {
    // Real-time listener handles data; just restart listener and end the spinner.
    [self.listener remove];
    [self startListening];
    [self.tableView.refreshControl endRefreshing];
}

- (void)applyFilterAndReload {
    NSMutableArray<PPServiceModel *> *result = [NSMutableArray array];
    for (PPServiceModel *s in self.allServices) {
        if (self.activeFilter == PPServiceListFilterAvailable && !s.isLive) continue;
        if (self.activeFilter == PPServiceListFilterUnavailable && s.isAvailable) continue;

        NSString *q = [self.searchQuery lowercaseString];
        if (q.length > 0) {
            if (![[s.title lowercaseString] containsString:q] && ![[s.descriptionText lowercaseString] containsString:q]) continue;
        }
        [result addObject:s];
    }
    self.filteredServices = result;
    [self.tableView reloadData];
    self.emptyContainer.hidden = (self.filteredServices.count > 0);

    if (!self.didPlayEntrance && self.filteredServices.count > 0) {
        self.didPlayEntrance = YES;
        [self playCellEntranceAnimation];
    }
}

- (void)playCellEntranceAnimation {
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    for (NSUInteger idx = 0; idx < cells.count; idx++) {
        UITableViewCell *cell = cells[idx];
        cell.alpha = 0;
        cell.transform = CGAffineTransformMakeTranslation(0, 30);
        [UIView animateWithDuration:0.5 delay:0.05 * idx usingSpringWithDamping:0.82 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
            cell.alpha = 1;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Actions

- (void)addServiceTapped {
    [PPFunc pp_playTapEffect];

    if (![self checkServicePermission]) {
        [PPAlertHelper showConfirmationIn:self
                                  title:kLang(@"Serv_No_Permission")
                               subtitle:kLang(@"Serv_No_Permission_Msg")
                            placeholder:nil
                          confirmButton:kLang(@"OK")
                           cancelButton:nil
                           confirmBlock:nil
                            cancelBlock:nil];
        return;
    }

    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - PPSDelegate

- (void)searchView:(PPS *)view didChangeText:(NSString *)text {
    self.searchQuery = text ?: @"";
    [self applyFilterAndReload];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredServices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPServiceCell reuseID] forIndexPath:indexPath];
    [cell configureWithService:self.filteredServices[indexPath.row]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PPServiceModel *s = self.filteredServices[indexPath.row];
    PPServiceDetailViewController *vc = [[PPServiceDetailViewController alloc] initWithService:s];
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.hasPermission) return nil;

    __weak typeof(self) weakSelf = self;
    PPServiceModel *s = self.filteredServices[indexPath.row];

    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf editService:s];
        handler(YES);
    }];
    editAction.backgroundColor = [UIColor ppInfo];
    editAction.image = [UIImage systemImageNamed:@"pencil.circle.fill"];

    BOOL isAvailable = s.isAvailable;
    UIContextualAction *toggleAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf toggleAvailability:s];
        handler(YES);
    }];
    toggleAction.backgroundColor = isAvailable ? [UIColor ppWarning] : [UIColor ppSuccess];
    toggleAction.image = [UIImage systemImageNamed:isAvailable ? @"pause.circle.fill" : @"checkmark.circle.fill"];

    return [UISwipeActionsConfiguration configurationWithActions:@[toggleAction, editAction]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.hasPermission) return nil;

    __weak typeof(self) weakSelf = self;
    PPServiceModel *s = self.filteredServices[indexPath.row];

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf deleteService:s];
        handler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash.circle.fill"];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma mark - Helper Actions

- (void)editService:(PPServiceModel *)s {
    [PPFunc pp_playTapEffect];
    PPAddEditServiceViewController *vc = [[PPAddEditServiceViewController alloc] initWithService:s];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)toggleAvailability:(PPServiceModel *)s {
    BOOL newState = !s.isAvailable;
    NSString *title = newState ? kLang(@"Serv_Confirm_Available_Title") : kLang(@"Serv_Confirm_Unavailable_Title");
    NSString *msg   = newState ? kLang(@"Serv_Confirm_Available_Msg")   : kLang(@"Serv_Confirm_Unavailable_Msg");

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self title:title subtitle:msg placeholder:nil confirmButton:kLang(@"Confirm") cancelButton:kLang(@"Cancel") confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:kLang(@"Vet_Updating") subtitle:nil];
        [[PPServiceManager sharedManager] toggleAvailability:newState forServiceID:s.serviceID completion:^(NSError *error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:kLang(@"ServiceStatusUpdated")];
            }
        }];
    } cancelBlock:nil];
}

- (void)deleteService:(PPServiceModel *)s {
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self title:kLang(@"Confirm Delete") subtitle:kLang(@"ConfirmDeleteService") placeholder:nil confirmButton:kLang(@"Delete") cancelButton:kLang(@"Cancel") confirmBlock:^{
        [PPHUD showIndeterminateIn:weakSelf.view title:kLang(@"Serv_Deleting") subtitle:nil];
        [[PPServiceManager sharedManager] deleteService:s completion:^(NSError *error) {
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:kLang(@"ServiceDeleted")];
            }
        }];
    } cancelBlock:nil];
}

@end
