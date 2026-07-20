//
//  PPDeliveryDashboardViewController.m
//  PurePetsPro
//
//  Premium minimal delivery dashboard with a stronger hero composition,
//  quieter chrome, and refined filtering/search surfaces.
//

#import "PPDeliveryDashboardViewController.h"
#import "PPDeliveryManager.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryOrderCell.h"
#import "PPDeliveryOrderDetailViewController.h"

static CGFloat const kStatCardHeight       = 110.0;
static CGFloat const kPillHeight           = 38.0;
static CGFloat const kChromeInset          = 16.0;
static CGFloat const kDeliveryHeroHeight   = 480.0;
static CGFloat const kDeliveryHeroCollapsedHeight = 196.0;
static CGFloat const kSearchShellHeight    = 56.0;
static CGFloat const kHeroSurfaceRadius    = 42.0;
static NSString * const PPDeliveryHeroIntroSeenDefaultsKey = @"PPDeliveryHeroIntroSeenDefaultsKey";

static inline CGFloat PPDeliveryLerp(CGFloat from, CGFloat to, CGFloat progress) {
    return from + ((to - from) * progress);
}

#pragma mark - Filter Pill Data

@interface _PPDeliveryPill : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, assign) PPDeliveryFilter filter;
@end
@implementation _PPDeliveryPill
@end

#pragma mark - Stat Card

@interface _PPStatCard : UIView
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *titleLabel;
- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title color:(UIColor *)color;
- (void)updateCount:(NSInteger)count;
@end

@implementation _PPStatCard

- (instancetype)initWithIcon:(NSString *)iconName title:(NSString *)title color:(UIColor *)color {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.backgroundColor = AppForgroundColr;
        self.layer.shadowColor = AppShadowColor.CGColor;
        self.layer.shadowOpacity = 0.06;
        self.layer.shadowOffset = CGSizeMake(0, 10);
        self.layer.shadowRadius = 18.0;

        UIView *surfaceView = [[UIView alloc] init];
        surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        surfaceView.backgroundColor = AppForgroundColr;
        surfaceView.clipsToBounds = YES;
        surfaceView.layer.cornerRadius = 24.0;
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        surfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        [self addSubview:surfaceView];

        UIView *toneHalo = [[UIView alloc] init];
        toneHalo.translatesAutoresizingMaskIntoConstraints = NO;
        toneHalo.backgroundColor = [color colorWithAlphaComponent:0.11];
        toneHalo.layer.cornerRadius = 42.0;
        [surfaceView addSubview:toneHalo];

        UIView *iconWrap = [[UIView alloc] init];
        iconWrap.translatesAutoresizingMaskIntoConstraints = NO;
        iconWrap.backgroundColor = [color colorWithAlphaComponent:0.10];
        iconWrap.layer.cornerRadius = 16.0;
        iconWrap.layer.cornerCurve = kCACornerCurveContinuous;
        [surfaceView addSubview:iconWrap];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = color;
        UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
        iconView.image = [[UIImage systemImageNamed:iconName] imageWithConfiguration:iconConfig];
        [iconWrap addSubview:iconView];

        UIView *accentDot = [[UIView alloc] init];
        accentDot.translatesAutoresizingMaskIntoConstraints = NO;
        accentDot.backgroundColor = color;
        accentDot.layer.cornerRadius = 3.0;
        [surfaceView addSubview:accentDot];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = PPFontMedium(11);
        _titleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.88];
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _titleLabel.text = title;
        _titleLabel.numberOfLines = 2;
        [surfaceView addSubview:_titleLabel];

        _countLabel = [[UILabel alloc] init];
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _countLabel.font = PPFontBold(28);
        _countLabel.textColor = PrimaryTextClr;
        _countLabel.textAlignment = Language.alignmentForCurrentLanguage;
        _countLabel.text = @"0";
        [surfaceView addSubview:_countLabel];

        [NSLayoutConstraint activateConstraints:@[
            [surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [toneHalo.widthAnchor constraintEqualToConstant:84.0],
            [toneHalo.heightAnchor constraintEqualToConstant:84.0],
            [toneHalo.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:-28.0],
            [toneHalo.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:18.0],

            [iconWrap.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:14.0],
            [iconWrap.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:14.0],
            [iconWrap.widthAnchor constraintEqualToConstant:32.0],
            [iconWrap.heightAnchor constraintEqualToConstant:32.0],

            [iconView.centerXAnchor constraintEqualToAnchor:iconWrap.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:14.0],
            [iconView.heightAnchor constraintEqualToConstant:14.0],

            [accentDot.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:18.0],
            [accentDot.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-16.0],
            [accentDot.widthAnchor constraintEqualToConstant:6.0],
            [accentDot.heightAnchor constraintEqualToConstant:6.0],

            [_titleLabel.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:iconWrap.trailingAnchor constant:10.0],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:accentDot.leadingAnchor constant:-10.0],

            [_countLabel.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:14.0],
            [_countLabel.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-14.0],
            [_countLabel.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-12.0],
            [_countLabel.topAnchor constraintGreaterThanOrEqualToAnchor:_titleLabel.bottomAnchor constant:10.0],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:24.0];
    self.layer.shadowPath = shadowPath.CGPath;
}

- (void)updateCount:(NSInteger)count {
    NSString *nextValue = [NSString stringWithFormat:@"%ld", (long)count];
    if ([self.countLabel.text isEqualToString:nextValue]) {
        return;
    }

    [UIView transitionWithView:self.countLabel
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:^{
        self.countLabel.text = nextValue;
    } completion:nil];
}

@end

#pragma mark - Dashboard ViewController

@interface PPDeliveryDashboardViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UISearchBarDelegate>

// Hero + stats
@property (nonatomic, strong) PPHero *heroSurfaceView;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *heroBadgeRow;
@property (nonatomic, strong) UIView *heroStageView;
@property (nonatomic, strong) UIView *heroDividerView;
@property (nonatomic, strong) UIButton *heroSummaryToggleButton;
@property (nonatomic, strong) UILabel *heroFocusLabel;
@property (nonatomic, strong) UILabel *heroResultsLabel;
@property (nonatomic, strong) _PPStatCard *totalCard;
@property (nonatomic, strong) _PPStatCard *readyCard;
@property (nonatomic, strong) _PPStatCard *transitCard;
@property (nonatomic, strong) _PPStatCard *deliveredCard;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *statCardHeightConstraints;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *statsGridBottomConstraint;
@property (nonatomic, strong) UIStackView *statsGrid;

// Filters
@property (nonatomic, strong) UIScrollView *pillScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *pillButtons;
@property (nonatomic, strong) NSArray<_PPDeliveryPill *> *pills;

// Search + collection
@property (nonatomic, strong) UIView *searchShellView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

// Empty state
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIView *emptyHaloView;
@property (nonatomic, strong) UILabel *emptyFilterLabel;

// Data
@property (nonatomic, assign) PPDeliveryFilter currentFilter;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *filteredOrders;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didAnimateChrome;
@property (nonatomic, assign) BOOL heroExpanded;
@property (nonatomic, assign) BOOL shouldPlayHeroIntro;

@end

@implementation PPDeliveryDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    BOOL hasSeenHeroIntro = [[NSUserDefaults standardUserDefaults] boolForKey:PPDeliveryHeroIntroSeenDefaultsKey];
    self.view.backgroundColor = AppBackgroundClr;
    self.currentFilter = PPDeliveryFilterReady;
    self.filteredOrders = @[];
    self.didAnimateEntrance = NO;
    self.didAnimateChrome = NO;
    self.heroExpanded = !hasSeenHeroIntro;
    self.shouldPlayHeroIntro = !hasSeenHeroIntro;

    [self setupBackgroundAtmosphere];
    [self buildPillData];
    [self setupStatsHeader];
    [self setupPillFilters];
    [self setupSearchBar];
    [self setupCollectionView];
    [self setupEmptyState];
    [self updateToggleButtonAppearance];
    [self applyHeroExpansionStateAnimated:NO];
    [self primeChromeForEntranceAnimation];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ordersDidChange:)
                                                 name:PPDeliveryOrdersDidChangeNotification
                                               object:nil];
}

- (void)onBack {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self animateChromeIfNeeded];
    [self scrollPillsToLeadingEdgeIfNeeded];

    if (self.shouldPlayHeroIntro) {
        self.shouldPlayHeroIntro = NO;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PPDeliveryHeroIntroSeenDefaultsKey];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.view.window == nil || !strongSelf.heroExpanded) {
                return;
            }

            strongSelf.heroExpanded = NO;
            [strongSelf updateToggleButtonAppearance];
            [strongSelf applyHeroExpansionStateAnimated:YES];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"DeliveryManagement") showBack:YES];
    [[PPDeliveryManager shared] startListeningForDeliveryOrders];
    [self reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [[PPDeliveryManager shared] stopListening];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIBezierPath *searchPath = [UIBezierPath bezierPathWithRoundedRect:self.searchShellView.bounds
                                                           cornerRadius:(kSearchShellHeight / 2.0)];
    self.searchShellView.layer.shadowPath = searchPath.CGPath;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup: Background

- (void)setupBackgroundAtmosphere {
    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    topGlow.layer.cornerRadius = 130.0;
    [self.view addSubview:topGlow];
    [self.view sendSubviewToBack:topGlow];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:260.0],
        [topGlow.heightAnchor constraintEqualToConstant:260.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-110.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:72.0],
    ]];
}

#pragma mark - Pill Data

- (void)buildPillData {
    NSMutableArray *arr = [NSMutableArray array];

    _PPDeliveryPill *p0 = [_PPDeliveryPill new];
    p0.title = kLang(@"Deliv_FilterReady");
    p0.iconName = @"shippingbox";
    p0.filter = PPDeliveryFilterReady;
    [arr addObject:p0];

    _PPDeliveryPill *p1 = [_PPDeliveryPill new];
    p1.title = kLang(@"Deliv_FilterPendingPickup");
    p1.iconName = @"shippingbox.circle";
    p1.filter = PPDeliveryFilterPendingPickup;
    [arr addObject:p1];

    _PPDeliveryPill *p2 = [_PPDeliveryPill new];
    p2.title = kLang(@"Deliv_FilterInTransit");
    p2.iconName = @"truck.box";
    p2.filter = PPDeliveryFilterInTransit;
    [arr addObject:p2];

    _PPDeliveryPill *p3 = [_PPDeliveryPill new];
    p3.title = kLang(@"Deliv_FilterDelivered");
    p3.iconName = @"checkmark.circle";
    p3.filter = PPDeliveryFilterDelivered;
    [arr addObject:p3];

    _PPDeliveryPill *p4 = [_PPDeliveryPill new];
    p4.title = kLang(@"Deliv_FilterCancelled");
    p4.iconName = @"xmark.circle";
    p4.filter = PPDeliveryFilterCancelled;
    [arr addObject:p4];

    _PPDeliveryPill *p5 = [_PPDeliveryPill new];
    p5.title = kLang(@"Deliv_FilterAll");
    p5.iconName = @"list.bullet";
    p5.filter = PPDeliveryFilterAll;
    [arr addObject:p5];

    self.pills = [arr copy];
}

- (NSString *)pp_titleForFilter:(PPDeliveryFilter)filter {
    for (_PPDeliveryPill *pill in self.pills) {
        if (pill.filter == filter) {
            return pill.title ?: @"";
        }
    }
    return @"";
}

#pragma mark - Setup: Hero

- (UIView *)buildHeroBadgeWithBackgroundColor:(UIColor *)backgroundColor
                                    textColor:(UIColor *)textColor
                                   labelStore:(UILabel * __strong *)labelStore {
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = backgroundColor;
    badge.layer.cornerRadius = 18.0;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    badge.layer.borderColor = [textColor colorWithAlphaComponent:0.12].CGColor;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = PPFontBold(12);
    label.textColor = textColor;
    label.textAlignment = NSTextAlignmentCenter;
    [badge addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:badge.topAnchor constant:9.0],
        [label.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-9.0],
        [label.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:14.0],
        [label.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-14.0],
    ]];

    if (labelStore) {
        *labelStore = label;
    }
    return badge;
}

- (UIButton *)buildHeroSummaryToggleButton {
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    config.baseForegroundColor = PrimaryTextClr;
    config.contentInsets = NSDirectionalEdgeInsetsMake(9.0, 20.0, 9.0, 20.0);
    config.imagePadding = 8.0;
    config.imagePlacement = NSDirectionalRectEdgeTrailing;
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
        NSMutableDictionary<NSAttributedStringKey, id> *updated = [incoming mutableCopy] ?: [NSMutableDictionary dictionary];
        updated[NSFontAttributeName] = PPFontBold(12);
        return updated;
    };
    config.title = kLang(@"Deliv_OrderSummary");

    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.layer.cornerRadius = 18.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    button.layer.shadowColor = AppShadowColor.CGColor;
    button.layer.shadowOpacity = 0.04;
    button.layer.shadowOffset = CGSizeMake(0, 8);
    button.layer.shadowRadius = 16.0;
    button.accessibilityLabel = kLang(@"Deliv_OrderSummary");
    [button addTarget:self action:@selector(toggleHeroSummaryCards) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupStatsHeader {
    _heroSurfaceView = [[PPHero alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSurfaceView.accentColor = AppPrimaryClr;
    [self.view addSubview:_heroSurfaceView];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = PPFontBold(12);
    eyebrowLabel.textColor = [AppPrimaryClr colorWithAlphaComponent:0.88];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrowLabel.text = kLang(@"Deliv_LiveBoard");
    [_heroSurfaceView addSubview:eyebrowLabel];

    _heroTitleLabel = [[UILabel alloc] init];
    _heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _heroTitleLabel.font = PPFontBold(30);
    _heroTitleLabel.textColor = PrimaryTextClr;
    _heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _heroTitleLabel.numberOfLines = 2;
    _heroTitleLabel.text = kLang(@"DeliveryManagement");
    [_heroSurfaceView addSubview:_heroTitleLabel];

    _heroSubtitleLabel = [[UILabel alloc] init];
    _heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _heroSubtitleLabel.font = PPFontMedium(14);
    _heroSubtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.88];
    _heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _heroSubtitleLabel.numberOfLines = 0;
    _heroSubtitleLabel.text = kLang(@"DeliveryManagementSubtitle");
    [_heroSurfaceView addSubview:_heroSubtitleLabel];

    UIView *heroStageView = [[UIView alloc] init];
    heroStageView.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.06];
    heroStageView.layer.cornerRadius = 56.0;
    heroStageView.layer.cornerCurve = kCACornerCurveContinuous;
    [_heroSurfaceView addSubview:heroStageView];
    _heroStageView = heroStageView;

    UIView *heroStageCore = [[UIView alloc] init];
    heroStageCore.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageCore.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    heroStageCore.layer.cornerRadius = 30.0;
    heroStageCore.layer.cornerCurve = kCACornerCurveContinuous;
    [_heroStageView addSubview:heroStageCore];

    UIImageView *heroStageIcon = [[UIImageView alloc] init];
    heroStageIcon.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageIcon.contentMode = UIViewContentModeScaleAspectFit;
    heroStageIcon.tintColor = AppPrimaryClr;
    UIImageSymbolConfiguration *stageIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:26.0 weight:UIImageSymbolWeightSemibold];
    heroStageIcon.image = [[UIImage systemImageNamed:@"truck.box.fill"] imageWithConfiguration:stageIconConfig];
    [heroStageCore addSubview:heroStageIcon];

    UIView *heroStageDot = [[UIView alloc] init];
    heroStageDot.translatesAutoresizingMaskIntoConstraints = NO;
    heroStageDot.backgroundColor = UIColor.systemGreenColor;
    heroStageDot.layer.cornerRadius = 5.0;
    [_heroStageView addSubview:heroStageDot];

    UIView *focusBadge = [self buildHeroBadgeWithBackgroundColor:[AppPrimaryClr colorWithAlphaComponent:0.11]
                                                       textColor:AppPrimaryClr
                                                      labelStore:&_heroFocusLabel];
    UIView *resultsBadge = [self buildHeroBadgeWithBackgroundColor:[SeconderyTextClr colorWithAlphaComponent:0.08]
                                                         textColor:PrimaryTextClr
                                                        labelStore:&_heroResultsLabel];

    self.heroSummaryToggleButton = [self buildHeroSummaryToggleButton];

    UIStackView *badgeRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        resultsBadge,
        focusBadge,
        self.heroSummaryToggleButton
    ]];
    badgeRow.translatesAutoresizingMaskIntoConstraints = NO;
    badgeRow.axis = UILayoutConstraintAxisHorizontal;
    badgeRow.alignment = UIStackViewAlignmentCenter;
    badgeRow.spacing = 8.0;
    badgeRow.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [_heroSurfaceView addSubview:badgeRow];
    [_heroSurfaceView bringSubviewToFront:badgeRow];
    self.heroBadgeRow = badgeRow;

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    divider.layer.cornerRadius = 0.5;
    [_heroSurfaceView addSubview:divider];
    self.heroDividerView = divider;

    _totalCard = [[_PPStatCard alloc] initWithIcon:@"cube.box.fill"
                                             title:kLang(@"Deliv_TotalOrders")
                                             color:AppPrimaryClr];
    _readyCard = [[_PPStatCard alloc] initWithIcon:@"shippingbox.fill"
                                             title:kLang(@"Deliv_ReadyCount")
                                             color:UIColor.systemOrangeColor];
    _transitCard = [[_PPStatCard alloc] initWithIcon:@"truck.box.fill"
                                               title:kLang(@"Deliv_InTransitCount")
                                               color:UIColor.systemIndigoColor];
    _deliveredCard = [[_PPStatCard alloc] initWithIcon:@"checkmark.circle.fill"
                                                 title:kLang(@"Deliv_DeliveredCount")
                                                 color:UIColor.systemGreenColor];

    UIStackView *topStatsRow = [[UIStackView alloc] initWithArrangedSubviews:@[_totalCard, _readyCard]];
    topStatsRow.translatesAutoresizingMaskIntoConstraints = NO;
    topStatsRow.axis = UILayoutConstraintAxisHorizontal;
    topStatsRow.alignment = UIStackViewAlignmentFill;
    topStatsRow.distribution = UIStackViewDistributionFillEqually;
    topStatsRow.spacing = 10.0;
    topStatsRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *bottomStatsRow = [[UIStackView alloc] initWithArrangedSubviews:@[_transitCard, _deliveredCard]];
    bottomStatsRow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomStatsRow.axis = UILayoutConstraintAxisHorizontal;
    bottomStatsRow.alignment = UIStackViewAlignmentFill;
    bottomStatsRow.distribution = UIStackViewDistributionFillEqually;
    bottomStatsRow.spacing = 10.0;
    bottomStatsRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *statsGrid = [[UIStackView alloc] initWithArrangedSubviews:@[
        topStatsRow,
        bottomStatsRow
    ]];
    statsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    statsGrid.axis = UILayoutConstraintAxisVertical;
    statsGrid.alignment = UIStackViewAlignmentFill;
    statsGrid.distribution = UIStackViewDistributionFillEqually;
    statsGrid.spacing = 10.0;
    [_heroSurfaceView addSubview:statsGrid];
    self.statsGrid = statsGrid;

    NSMutableArray<NSLayoutConstraint *> *cardHeightConstraints = [NSMutableArray array];
    for (_PPStatCard *card in @[_totalCard, _readyCard, _transitCard, _deliveredCard]) {
        NSLayoutConstraint *heightConstraint = [card.heightAnchor constraintEqualToConstant:kStatCardHeight];
        heightConstraint.active = YES;
        [cardHeightConstraints addObject:heightConstraint];
    }
    self.statCardHeightConstraints = cardHeightConstraints.copy;

    self.heroTopConstraint = [_heroSurfaceView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10.0];
    self.heroHeightConstraint = [_heroSurfaceView.heightAnchor constraintEqualToConstant:(self.heroExpanded ? kDeliveryHeroHeight : kDeliveryHeroCollapsedHeight)];

    [NSLayoutConstraint activateConstraints:@[
        self.heroTopConstraint,
        [_heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kChromeInset],
        [_heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kChromeInset],
        self.heroHeightConstraint,

        [eyebrowLabel.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:22.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:_heroStageView.leadingAnchor constant:-12.0],

        [_heroStageView.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:20.0],
        [_heroStageView.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20.0],
        [_heroStageView.widthAnchor constraintEqualToConstant:112.0],
        [_heroStageView.heightAnchor constraintEqualToConstant:112.0],

        [heroStageCore.centerXAnchor constraintEqualToAnchor:_heroStageView.centerXAnchor],
        [heroStageCore.centerYAnchor constraintEqualToAnchor:_heroStageView.centerYAnchor],
        [heroStageCore.widthAnchor constraintEqualToConstant:60.0],
        [heroStageCore.heightAnchor constraintEqualToConstant:60.0],

        [heroStageIcon.centerXAnchor constraintEqualToAnchor:heroStageCore.centerXAnchor],
        [heroStageIcon.centerYAnchor constraintEqualToAnchor:heroStageCore.centerYAnchor],
        [heroStageIcon.widthAnchor constraintEqualToConstant:32.0],
        [heroStageIcon.heightAnchor constraintEqualToConstant:32.0],

        [heroStageDot.topAnchor constraintEqualToAnchor:_heroStageView.topAnchor constant:18.0],
        [heroStageDot.trailingAnchor constraintEqualToAnchor:_heroStageView.trailingAnchor constant:-18.0],
        [heroStageDot.widthAnchor constraintEqualToConstant:10.0],
        [heroStageDot.heightAnchor constraintEqualToConstant:10.0],

        [_heroTitleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:14.0],
        [_heroTitleLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [_heroTitleLabel.trailingAnchor constraintEqualToAnchor:_heroStageView.leadingAnchor constant:-12.0],

        [_heroSubtitleLabel.topAnchor constraintEqualToAnchor:_heroTitleLabel.bottomAnchor constant:6.0],
        [_heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [_heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20.0],

        [badgeRow.topAnchor constraintEqualToAnchor:_heroSubtitleLabel.bottomAnchor constant:14.0],
        [badgeRow.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [badgeRow.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20.0],

        [divider.topAnchor constraintEqualToAnchor:badgeRow.bottomAnchor constant:18.0],
        [divider.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [divider.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20.0],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [statsGrid.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:16.0],
        [statsGrid.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20.0],
        [statsGrid.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20.0],
    ]];

    self.statsGridBottomConstraint = [statsGrid.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-20.0];
    self.statsGridBottomConstraint.active = self.heroExpanded;
}

#pragma mark - Setup: Filters

- (void)setupPillFilters {
    _pillScrollView = [[UIScrollView alloc] init];
    _pillScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _pillScrollView.showsHorizontalScrollIndicator = NO;
    _pillScrollView.clipsToBounds = NO;
    _pillScrollView.alwaysBounceHorizontal = YES;
    _pillScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:_pillScrollView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8.0;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_pillScrollView addSubview:stack];

    _pillButtons = [NSMutableArray array];

    for (NSInteger i = 0; i < self.pills.count; i++) {
        _PPDeliveryPill *pill = self.pills[i];

        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 16.0, 10.0, 16.0);
        config.imagePadding = 8.0;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightMedium];
        config.image = [UIImage systemImageNamed:pill.iconName];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:pill.title attributes:@{
            NSFontAttributeName: PPFontBold(12)
        }];

        UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = i;
        button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        button.layer.cornerRadius = kPillHeight / 2.0;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        button.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
        button.layer.shadowColor = AppShadowColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 8);
        button.layer.shadowRadius = 16.0;
        [button.heightAnchor constraintEqualToConstant:kPillHeight].active = YES;
        [button addTarget:self action:@selector(pillTapped:) forControlEvents:UIControlEventTouchUpInside];

        [stack addArrangedSubview:button];
        [_pillButtons addObject:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [_pillScrollView.topAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:14.0],
        [_pillScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_pillScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_pillScrollView.heightAnchor constraintEqualToConstant:kPillHeight + 6.0],

        [stack.topAnchor constraintEqualToAnchor:_pillScrollView.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:_pillScrollView.leadingAnchor constant:kChromeInset],
        [stack.trailingAnchor constraintEqualToAnchor:_pillScrollView.trailingAnchor constant:-kChromeInset],
        [stack.bottomAnchor constraintEqualToAnchor:_pillScrollView.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:_pillScrollView.heightAnchor],
    ]];

    [self updatePillSelectionAnimated:NO];
}

- (void)scrollPillsToLeadingEdgeIfNeeded {
    if (!Language.isRTL) return;
    [self.pillScrollView layoutIfNeeded];
    CGFloat maxOffsetX = self.pillScrollView.contentSize.width - self.pillScrollView.bounds.size.width;
    if (maxOffsetX > 0) {
        [self.pillScrollView setContentOffset:CGPointMake(maxOffsetX, 0) animated:NO];
    }
}

- (void)updatePillSelectionAnimated:(BOOL)animated {
    void (^applyStyles)(void) = ^{
        for (NSInteger i = 0; i < self.pillButtons.count; i++) {
            UIButton *button = self.pillButtons[i];
            BOOL isSelected = (self.pills[i].filter == self.currentFilter);
            UIButtonConfiguration *config = button.configuration;

            if (isSelected) {
                config.baseBackgroundColor = AppForgroundColr;
                config.baseForegroundColor = AppPrimaryClr;
                button.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.12].CGColor;
                button.layer.shadowOpacity = 0.06;
                button.transform = CGAffineTransformIdentity;
            } else {
                config.baseBackgroundColor = AppBackgroundClr;
                config.baseForegroundColor = [SeconderyTextClr colorWithAlphaComponent:0.92];
                button.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.06].CGColor;
                button.layer.shadowOpacity = 0.0;
                button.transform = CGAffineTransformMakeScale(0.985, 0.985);
            }

            button.configuration = config;
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.28
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:applyStyles
                         completion:nil];
    } else {
        applyStyles();
    }
}

- (void)pillTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.pills.count) {
        return;
    }

    self.currentFilter = self.pills[index].filter;
    [PPFunc pp_playSelectionEffect];
    [self updatePillSelectionAnimated:YES];
    [self reloadData];
}

#pragma mark - Setup: Search

- (void)setupSearchBar {
    _searchShellView = [[UIView alloc] init];
    _searchShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchShellView.backgroundColor = AppForgroundColr;
    _searchShellView.layer.cornerRadius = kSearchShellHeight / 2.0;
    _searchShellView.layer.cornerCurve = kCACornerCurveContinuous;
    _searchShellView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _searchShellView.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.08].CGColor;
    _searchShellView.layer.shadowColor = AppShadowColor.CGColor;
    _searchShellView.layer.shadowOpacity = 0.05;
    _searchShellView.layer.shadowOffset = CGSizeMake(0, 10);
    _searchShellView.layer.shadowRadius = 18.0;
    [self.view addSubview:_searchShellView];

    UIView *searchGlow = [[UIView alloc] init];
    searchGlow.translatesAutoresizingMaskIntoConstraints = NO;
    searchGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.07];
    searchGlow.layer.cornerRadius = 28.0;
    [_searchShellView addSubview:searchGlow];

    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = kLang(@"Deliv_SearchOrders");
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.delegate = self;
    _searchBar.backgroundColor = UIColor.clearColor;
    _searchBar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _searchBar.backgroundImage = [UIImage new];
    [_searchShellView addSubview:_searchBar];

    UITextField *searchField = [_searchBar valueForKey:@"searchField"];
    if (searchField) {
        searchField.font = PPFontRegular(14);
        searchField.textAlignment = Language.alignmentForCurrentLanguage;
        searchField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        searchField.backgroundColor = UIColor.clearColor;
        searchField.layer.cornerRadius = 0.0;
        searchField.layer.borderWidth = 0.0;
        searchField.borderStyle = UITextBorderStyleNone;
        searchField.clearButtonMode = UITextFieldViewModeWhileEditing;

        if ([searchField.leftView isKindOfClass:[UIImageView class]]) {
            UIImageView *iconView = (UIImageView *)searchField.leftView;
            iconView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.80];
        }
    }

    [NSLayoutConstraint activateConstraints:@[
        [_searchShellView.topAnchor constraintEqualToAnchor:_pillScrollView.bottomAnchor constant:14.0],
        [_searchShellView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kChromeInset],
        [_searchShellView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kChromeInset],
        [_searchShellView.heightAnchor constraintEqualToConstant:kSearchShellHeight],

        [searchGlow.widthAnchor constraintEqualToConstant:120.0],
        [searchGlow.heightAnchor constraintEqualToConstant:120.0],
        [searchGlow.centerYAnchor constraintEqualToAnchor:_searchShellView.centerYAnchor],
        [searchGlow.trailingAnchor constraintEqualToAnchor:_searchShellView.trailingAnchor constant:46.0],

        [_searchBar.topAnchor constraintEqualToAnchor:_searchShellView.topAnchor constant:2.0],
        [_searchBar.leadingAnchor constraintEqualToAnchor:_searchShellView.leadingAnchor constant:2.0],
        [_searchBar.trailingAnchor constraintEqualToAnchor:_searchShellView.trailingAnchor constant:-2.0],
        [_searchBar.bottomAnchor constraintEqualToAnchor:_searchShellView.bottomAnchor constant:-2.0],
    ]];
}

#pragma mark - Setup: Collection View

- (void)setupCollectionView {
    UICollectionViewCompositionalLayout *layout = [self createLayout];
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = AppClearClr;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _collectionView.alwaysBounceVertical = YES;
    [_collectionView registerClass:[PPDeliveryOrderCell class]
        forCellWithReuseIdentifier:PPDeliveryOrderCellIdentifier];
    [self.view addSubview:_collectionView];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.tintColor = AppPrimaryClr;
    [_refreshControl addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    _collectionView.refreshControl = _refreshControl;

    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.topAnchor constraintEqualToAnchor:_searchShellView.bottomAnchor constant:10.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (UICollectionViewCompositionalLayout *)createLayout {
    UICollectionLayoutListConfiguration *config = [[UICollectionLayoutListConfiguration alloc]
        initWithAppearance:UICollectionLayoutListAppearancePlain];
    config.backgroundColor = AppClearClr;
    config.showsSeparators = NO;

    return [UICollectionViewCompositionalLayout layoutWithListConfiguration:config];
}

#pragma mark - Setup: Empty State

- (void)setupEmptyState {
    _emptyStateView = [[UIView alloc] init];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.alpha = 0.0;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    _emptyHaloView = [[UIView alloc] init];
    _emptyHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyHaloView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    _emptyHaloView.layer.cornerRadius = 58.0;
    [_emptyStateView addSubview:_emptyHaloView];

    UIView *emptyIconCore = [[UIView alloc] init];
    emptyIconCore.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIconCore.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.14];
    emptyIconCore.layer.cornerRadius = 34.0;
    emptyIconCore.layer.cornerCurve = kCACornerCurveContinuous;
    [_emptyHaloView addSubview:emptyIconCore];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightLight];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"shippingbox.fill"] imageWithConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = AppPrimaryClr;
    [emptyIconCore addSubview:iconView];

    UIView *filterBadge = [self buildHeroBadgeWithBackgroundColor:[AppPrimaryClr colorWithAlphaComponent:0.10]
                                                        textColor:AppPrimaryClr
                                                       labelStore:&_emptyFilterLabel];
    [_emptyStateView addSubview:filterBadge];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPFontBold(19);
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = kLang(@"Deliv_EmptyTitle");
    [_emptyStateView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPFontMedium(13);
    subtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.88];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"Deliv_EmptySubtitle");
    [_emptyStateView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor constant:8.0],
        [_emptyStateView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.collectionView.leadingAnchor constant:42.0],
        [_emptyStateView.trailingAnchor constraintLessThanOrEqualToAnchor:self.collectionView.trailingAnchor constant:-42.0],
        [_emptyStateView.widthAnchor constraintLessThanOrEqualToConstant:320.0],

        [_emptyHaloView.topAnchor constraintEqualToAnchor:_emptyStateView.topAnchor],
        [_emptyHaloView.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [_emptyHaloView.widthAnchor constraintEqualToConstant:116.0],
        [_emptyHaloView.heightAnchor constraintEqualToConstant:116.0],

        [emptyIconCore.centerXAnchor constraintEqualToAnchor:_emptyHaloView.centerXAnchor],
        [emptyIconCore.centerYAnchor constraintEqualToAnchor:_emptyHaloView.centerYAnchor],
        [emptyIconCore.widthAnchor constraintEqualToConstant:68.0],
        [emptyIconCore.heightAnchor constraintEqualToConstant:68.0],

        [iconView.centerXAnchor constraintEqualToAnchor:emptyIconCore.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:emptyIconCore.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:34.0],
        [iconView.heightAnchor constraintEqualToConstant:34.0],

        [filterBadge.topAnchor constraintEqualToAnchor:_emptyHaloView.bottomAnchor constant:18.0],
        [filterBadge.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:filterBadge.bottomAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyStateView.bottomAnchor],
    ]];
}

#pragma mark - Data

- (void)reloadData {
    NSString *searchText = self.searchBar.text;
    self.filteredOrders = [[PPDeliveryManager shared] ordersForFilter:self.currentFilter
                                                          searchText:searchText];
    [self.collectionView reloadData];

    BOOL shouldShowEmpty = (self.filteredOrders.count == 0);
    self.emptyFilterLabel.text = [self pp_titleForFilter:self.currentFilter];

    if (shouldShowEmpty) {
        if (self.emptyStateView.hidden) {
            self.emptyStateView.hidden = NO;
            self.emptyStateView.alpha = 0.0;
            self.emptyStateView.transform = CGAffineTransformMakeTranslation(0, 12.0);
            [UIView animateWithDuration:0.28
                             animations:^{
                self.emptyStateView.alpha = 1.0;
                self.emptyStateView.transform = CGAffineTransformIdentity;
            }];
        }

        if (![self.emptyHaloView.layer animationForKey:@"breathe"]) {
            CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            breathe.fromValue = @1.0;
            breathe.toValue = @1.05;
            breathe.duration = 2.2;
            breathe.autoreverses = YES;
            breathe.repeatCount = HUGE_VALF;
            breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.emptyHaloView.layer addAnimation:breathe forKey:@"breathe"];
        }
    } else {
        [self.emptyHaloView.layer removeAnimationForKey:@"breathe"];
        self.emptyStateView.hidden = YES;
        self.emptyStateView.alpha = 0.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
    }

    [self updateStats];
    [self applyHeroExpansionStateAnimated:NO];

    if (!self.didAnimateEntrance && self.filteredOrders.count > 0) {
        self.didAnimateEntrance = YES;
        [self animateEntranceOnce];
    }
}

- (void)updateStats {
    NSArray *all = [[PPDeliveryManager shared] ordersForFilter:PPDeliveryFilterAll searchText:nil];
    NSArray *ready = [[PPDeliveryManager shared] ordersForFilter:PPDeliveryFilterReady searchText:nil];
    NSArray *transit = [[PPDeliveryManager shared] ordersForFilter:PPDeliveryFilterInTransit searchText:nil];
    NSArray *delivered = [[PPDeliveryManager shared] ordersForFilter:PPDeliveryFilterDelivered searchText:nil];

    [self.totalCard updateCount:(NSInteger)all.count];
    [self.readyCard updateCount:(NSInteger)ready.count];
    [self.transitCard updateCount:(NSInteger)transit.count];
    [self.deliveredCard updateCount:(NSInteger)delivered.count];

    self.heroFocusLabel.text = [self pp_titleForFilter:self.currentFilter];
    self.heroResultsLabel.text = [NSString stringWithFormat:kLang(@"Deliv_VisibleOrdersCount"), (long)self.filteredOrders.count];
}

- (void)ordersDidChange:(NSNotification *)note {
    [self.refreshControl endRefreshing];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadData) object:nil];
    [self performSelector:@selector(reloadData) withObject:nil afterDelay:0.15];
}

- (void)handleRefresh {
    [[PPDeliveryManager shared] startListeningForDeliveryOrders];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
}

#pragma mark - Motion

- (void)primeChromeForEntranceAnimation {
    NSArray<UIView *> *animatedViews = @[
        self.heroSurfaceView,
        self.pillScrollView,
        self.searchShellView
    ];

    for (UIView *view in animatedViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 20.0);
    }

    self.heroStageView.transform = CGAffineTransformMakeScale(0.92, 0.92);
}

- (CGFloat)heroCollapseProgressForCurrentState {
    if (!self.heroExpanded) {
        return 1.0;
    }

    if (self.filteredOrders.count <= 10) {
        return 0.0;
    }

    CGFloat offset = MAX(0.0, self.collectionView.contentOffset.y);
    return MIN(1.0, offset / 160.0);
}

- (void)applyHeroExpansionProgress:(CGFloat)collapseProgress animated:(BOOL)animated {
    CGFloat normalizedProgress = MIN(MAX(collapseProgress, 0.0), 1.0);
    BOOL shouldShowSummaryCards = (normalizedProgress < 0.999);

    if (shouldShowSummaryCards) {
        self.heroDividerView.hidden = NO;
        self.statsGrid.hidden = NO;
    }

    self.statsGridBottomConstraint.active = shouldShowSummaryCards;

    CGFloat targetHeroHeight = PPDeliveryLerp(kDeliveryHeroHeight, kDeliveryHeroCollapsedHeight, normalizedProgress);
    CGFloat targetCardHeight = PPDeliveryLerp(kStatCardHeight, 0.0, normalizedProgress);
    CGFloat targetDividerAlpha = PPDeliveryLerp(1.0, 0.0, normalizedProgress);
    CGFloat targetStatsAlpha = PPDeliveryLerp(1.0, 0.0, normalizedProgress);
    CGFloat targetStatsSpacing = PPDeliveryLerp(10.0, 0.0, normalizedProgress);
    CGAffineTransform targetStatsTransform = CGAffineTransformMakeTranslation(0, -14.0 * normalizedProgress);

    void (^updates)(void) = ^{
        self.heroHeightConstraint.constant = targetHeroHeight;
        self.statsGrid.spacing = targetStatsSpacing;
        for (NSLayoutConstraint *constraint in self.statCardHeightConstraints) {
            constraint.constant = targetCardHeight;
        }
        self.heroDividerView.alpha = targetDividerAlpha;
        self.statsGrid.alpha = targetStatsAlpha;
        self.statsGrid.transform = targetStatsTransform;
        [self.view layoutIfNeeded];
    };

    void (^completion)(void) = ^{
        self.heroDividerView.hidden = !shouldShowSummaryCards;
        self.statsGrid.hidden = !shouldShowSummaryCards;
    };

    if (animated) {
        [UIView animateWithDuration:0.42
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:^(__unused BOOL finished) {
            completion();
        }];
    } else {
        updates();
        completion();
    }
}

- (void)updateToggleButtonAppearance {
    UIButtonConfiguration *config = self.heroSummaryToggleButton.configuration;
    config.baseBackgroundColor = self.heroExpanded ? [AppPrimaryClr colorWithAlphaComponent:0.12] : [SeconderyTextClr colorWithAlphaComponent:0.08];
    config.baseForegroundColor = self.heroExpanded ? AppPrimaryClr : PrimaryTextClr;
    config.image = [UIImage systemImageNamed:(self.heroExpanded ? @"chevron.up" : @"chevron.down")];
    self.heroSummaryToggleButton.configuration = config;
    self.heroSummaryToggleButton.layer.borderColor = (self.heroExpanded ? [AppPrimaryClr colorWithAlphaComponent:0.16] : [SeconderyTextClr colorWithAlphaComponent:0.08]).CGColor;
}

- (void)applyHeroExpansionStateAnimated:(BOOL)animated {
    [self applyHeroExpansionProgress:[self heroCollapseProgressForCurrentState] animated:animated];
}

- (void)toggleHeroSummaryCards {
    self.heroExpanded = !self.heroExpanded;
    [PPFunc pp_playSelectionEffect];
    [self updateToggleButtonAppearance];
    [self applyHeroExpansionStateAnimated:YES];
}

- (void)animateChromeIfNeeded {
    if (self.didAnimateChrome) {
        return;
    }

    self.didAnimateChrome = YES;

    NSArray<UIView *> *animatedViews = @[
        self.heroSurfaceView,
        self.pillScrollView,
        self.searchShellView
    ];

    for (UIView *view in animatedViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 20.0);
    }

    self.heroStageView.transform = CGAffineTransformMakeScale(0.92, 0.92);

    [UIView animateWithDuration:0.58
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.32
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.heroStageView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.50
                          delay:0.08
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.pillScrollView.alpha = 1.0;
        self.pillScrollView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.50
                          delay:0.14
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.26
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.searchShellView.alpha = 1.0;
        self.searchShellView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)animateEntranceOnce {
    NSArray<NSIndexPath *> *visible = [self.collectionView indexPathsForVisibleItems];
    NSArray<NSIndexPath *> *sorted = [visible sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
        return [@(a.item) compare:@(b.item)];
    }];

    for (NSInteger i = 0; i < sorted.count; i++) {
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:sorted[i]];
        if (!cell) {
            continue;
        }

        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0, 26.0);

        [UIView animateWithDuration:0.46
                              delay:0.045 * i
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filteredOrders.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPDeliveryOrderCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPDeliveryOrderCellIdentifier
                                                                          forIndexPath:indexPath];
    if (indexPath.item < self.filteredOrders.count) {
        [cell configureWithOrder:self.filteredOrders[indexPath.item]];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.collectionView) {
        return;
    }

    CGFloat offset = MAX(0.0, scrollView.contentOffset.y);
    CGFloat summaryCollapseProgress = [self heroCollapseProgressForCurrentState];
    CGFloat chromeProgress = self.heroExpanded ? MAX(summaryCollapseProgress, MIN(1.0, offset / 220.0)) : 1.0;

    [self applyHeroExpansionProgress:summaryCollapseProgress animated:NO];

    self.heroTitleLabel.transform = CGAffineTransformMakeTranslation(0, -4.0 * chromeProgress);
    self.heroSubtitleLabel.alpha = MAX(0.74, 1.0 - (0.18 * chromeProgress));
    self.heroBadgeRow.alpha = MAX(0.82, 1.0 - (0.12 * chromeProgress));
    self.heroStageView.transform = CGAffineTransformMakeTranslation(0, -5.0 * chromeProgress);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    if (indexPath.item >= self.filteredOrders.count) {
        return;
    }

    [PPFunc pp_playTapEffect];
    PPDeliveryOrderModel *order = self.filteredOrders[indexPath.item];
    PPDeliveryOrderDetailViewController *detail = [[PPDeliveryOrderDetailViewController alloc] initWithOrder:order];
    [self.navigationController pushViewController:detail animated:YES];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(collectionView.bounds.size.width, [PPDeliveryOrderCell preferredHeight]);
}

@end
