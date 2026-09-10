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
        _titleLabel.font = [Styling fontMedium:PPFontSubheadline];
        _titleLabel.textColor = SeconderyTextClr;
        _titleLabel.text = title;
        _titleLabel.userInteractionEnabled = NO;
        PPEnableDynamicType(_titleLabel, UIFontTextStyleSubheadline);
        [self addSubview:_titleLabel];

        _countLabel = [UILabel new];
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _countLabel.font = [Styling fontMedium:PPFontCaption1];
        _countLabel.textColor = AppTertiaryTextClr;
        _countLabel.userInteractionEnabled = NO;
        PPEnableDynamicType(_countLabel, UIFontTextStyleCaption1);
        [self addSubview:_countLabel];

        _underline = [UIView new];
        _underline.translatesAutoresizingMaskIntoConstraints = NO;
        _underline.backgroundColor = AppPrimaryClr;
        _underline.alpha = 0.0;
        _underline.userInteractionEnabled = NO;
        [self addSubview:_underline];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSpaceMDHalf],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_countLabel.firstBaselineAnchor constraintEqualToAnchor:_titleLabel.firstBaselineAnchor],
            [_countLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:PPSpaceMDHalf],
            [_countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],
            [_underline.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:PPSpaceMDHalf],
            [_underline.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_underline.widthAnchor constraintEqualToAnchor:_titleLabel.widthAnchor],
            [_underline.heightAnchor constraintEqualToConstant:1.5],
            // Touch target: the chip keeps its typographic look but is never
            // shorter than 44pt, so the tappable area below the underline is
            // real instead of a ~30pt strip.
            [self.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        ]];

        NSLayoutConstraint *hugUnderline = [_underline.bottomAnchor constraintEqualToAnchor:self.bottomAnchor];
        hugUnderline.priority = UILayoutPriorityDefaultHigh + 1; // yields to the 44pt minimum
        hugUnderline.active = YES;

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityLabel = title;
    }
    return self;
}

- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated {
    _selectedState = selected;
    void (^apply)(void) = ^{
        self.titleLabel.textColor = selected ? (PrimaryTextClr) : SeconderyTextClr;
        self.titleLabel.font = selected ? [Styling fontBold:PPFontSubheadline] : [Styling fontMedium:PPFontSubheadline];
        PPEnableDynamicType(self.titleLabel, UIFontTextStyleSubheadline);
        self.underline.alpha = selected ? 1.0 : 0.0;
    };
    self.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected)
                                       : UIAccessibilityTraitButton;
    if (animated) {
        PPAnimateRespectingMotion(PPAnimDurationNormal, apply, nil);
    } else {
        apply();
    }
}

- (void)setCount:(NSInteger)count {
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)count];
    self.accessibilityValue = self.countLabel.text;
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
@property (nonatomic, strong) UIStackView *filterStack;

@property (nonatomic, strong) UIStackView *metricStack;
@property (nonatomic, strong) UIView *metricCardTotal;
@property (nonatomic, strong) UIView *metricCardActive;
@property (nonatomic, strong) UIView *metricCardDisabled;
@property (nonatomic, strong) UILabel *metricValueTotal;
@property (nonatomic, strong) UILabel *metricValueActive;
@property (nonatomic, strong) UILabel *metricValueDisabled;

@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, strong) UILabel *emptyHeadline;
@property (nonatomic, strong) UIView *emptyRule;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) BOOL isLoadingVets;

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
        PPApplyElevatedShadow(self.heroSurfaceView); // re-resolve the dynamic shadow color
        [self updateAmbientBackgroundForStyle];
    }
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        [self pp_applyFilterRowLayoutForTextSize];
        [self pp_applyHeroTitleLineLimitForTextSize];
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

#pragma mark - Title & Telemetry Bento Hero

- (void)setupTitleHeader {
    BOOL rtl = Language.isRTL;
    NSTextAlignment align = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    _heroSurfaceView = [UIView new];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleCardSurface(_heroSurfaceView, PPCornerHero);
    _heroSurfaceView.backgroundColor = [self pp_surfaceColor];
    _heroSurfaceView.layer.borderColor = [self pp_borderColor].CGColor;
    PPApplyElevatedShadow(_heroSurfaceView);
    [self.view addSubview:_heroSurfaceView];

    UIView *accentBar = [UIView new];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(accentBar, 3.0);
    [_heroSurfaceView addSubview:accentBar];

    _eyebrowLabel = [UILabel new];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.text = [kLang(@"Vet_Section_Title") uppercaseString];
    _eyebrowLabel.font = [Styling fontBold:PPFontCaption1];
    _eyebrowLabel.textColor = AppPrimaryClr;
    _eyebrowLabel.textAlignment = align;
    _eyebrowLabel.numberOfLines = 0;
    PPEnableDynamicType(_eyebrowLabel, UIFontTextStyleCaption1);
    [_heroSurfaceView addSubview:_eyebrowLabel];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = kLang(@"Vet_Manage_Title") ?: ([Language isRTL] ? @"إدارة الكوادر والمراكز البيطرية" : @"Veterinarians Management");
    _titleLabel.font = [Styling fontBold:28];
    _titleLabel.textColor = PrimaryTextClr;
    _titleLabel.numberOfLines = 2;
    _titleLabel.textAlignment = align;
    PPEnableDynamicType(_titleLabel, UIFontTextStyleLargeTitle);
    [_heroSurfaceView addSubview:_titleLabel];

    _metaLabel = [UILabel new];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.text = @"";
    _metaLabel.font = [Styling fontMedium:12.5];
    _metaLabel.textColor = SeconderyTextClr;
    _metaLabel.textAlignment = align;
    _metaLabel.numberOfLines = 0;
    PPEnableDynamicType(_metaLabel, UIFontTextStyleFootnote);
    [_heroSurfaceView addSubview:_metaLabel];

    // Interactive Telemetry Cards
    UILabel *lblTotal = nil;
    self.metricCardTotal = [self metricCardWithTitle:kLang(@"Vet_Filter_All") ?: ([Language isRTL] ? @"إجمالي الأطباء" : @"All Vets")
                                          countLabel:&lblTotal
                                         accentColor:AppPrimaryClr
                                              action:@selector(chipAllTapped)];
    _metricValueTotal = lblTotal;

    UILabel *lblActive = nil;
    self.metricCardActive = [self metricCardWithTitle:kLang(@"Vet_Filter_Active") ?: ([Language isRTL] ? @"معتمد ونشط" : @"Active")
                                           countLabel:&lblActive
                                          accentColor:[UIColor ppSuccess]
                                               action:@selector(chipActiveTapped)];
    _metricValueActive = lblActive;

    UILabel *lblDisabled = nil;
    self.metricCardDisabled = [self metricCardWithTitle:kLang(@"Vet_Filter_Disabled") ?: ([Language isRTL] ? @"غير مفعل" : @"Disabled")
                                             countLabel:&lblDisabled
                                            accentColor:[UIColor ppError]
                                                 action:@selector(chipDisabledTapped)];
    _metricValueDisabled = lblDisabled;

    self.metricStack = [UIStackView new];
    self.metricStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.metricStack.axis = UILayoutConstraintAxisHorizontal;
    self.metricStack.spacing = 10.0;
    self.metricStack.distribution = UIStackViewDistributionFillEqually;
    self.metricStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.metricStack addArrangedSubview:self.metricCardTotal];
    [self.metricStack addArrangedSubview:self.metricCardActive];
    [self.metricStack addArrangedSubview:self.metricCardDisabled];
    [_heroSurfaceView addSubview:self.metricStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    CGFloat cardH = isPad ? 62.0 : 54.0;
    CGFloat hMargin = isPad ? 24.0 : 18.0;

    [NSLayoutConstraint activateConstraints:@[
        [_heroSurfaceView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:PPSpaceSM],
        [_heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:hMargin],
        [_heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-hMargin],

        [accentBar.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:16],
        [accentBar.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20],
        [accentBar.widthAnchor constraintEqualToConstant:64],
        [accentBar.heightAnchor constraintEqualToConstant:5.0],

        [_eyebrowLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:10.0],
        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:20],
        [_eyebrowLabel.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-20],

        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:4.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_eyebrowLabel.trailingAnchor],

        [_metaLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0],
        [_metaLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [self.metricStack.topAnchor constraintEqualToAnchor:_metaLabel.bottomAnchor constant:12.0],
        [self.metricStack.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [self.metricStack.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-18],
        [self.metricStack.heightAnchor constraintEqualToConstant:cardH],
        [self.metricStack.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-16],
    ]];

    [self pp_applyHeroTitleLineLimitForTextSize];
}

- (UIView *)metricCardWithTitle:(NSString *)title countLabel:(UILabel **)outCountLabel accentColor:(UIColor *)accentColor action:(SEL)action {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [accentColor colorWithAlphaComponent:0.07];
    PPApplyContinuousCorners(card, PPCornerButton);
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [accentColor colorWithAlphaComponent:0.22].CGColor;
    card.userInteractionEnabled = YES;

    UILabel *countLabel = [UILabel new];
    countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    countLabel.font = [Styling fontBold:19.0];
    countLabel.textColor = accentColor;
    countLabel.text = @"0";
    countLabel.textAlignment = NSTextAlignmentCenter;
    [card addSubview:countLabel];
    if (outCountLabel) *outCountLabel = countLabel;

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontMedium:11.0];
    titleLabel.textColor = SeconderyTextClr;
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.8;
    [card addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [countLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:6.0],
        [countLabel.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:countLabel.bottomAnchor constant:1.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:4.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-4.0],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-6.0],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:action];
    [card addGestureRecognizer:tap];
    return card;
}

- (void)pp_applyHeroTitleLineLimitForTextSize {
    self.titleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 2;
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
    self.filterStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceXL],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceXL],
    ]];

    [self pp_applyFilterRowLayoutForTextSize];
}

- (void)pp_applyFilterRowLayoutForTextSize {
    if (!self.filterStack) { return; }
    if (PPIsAccessibilityTextSize()) {
        self.filterStack.alignment = UIStackViewAlignmentLeading;
        self.filterStack.axis = UILayoutConstraintAxisVertical;
        self.filterStack.spacing = PPSpaceXS;
    } else {
        self.filterStack.axis = UILayoutConstraintAxisHorizontal;
        self.filterStack.alignment = UIStackViewAlignmentLastBaseline;
        self.filterStack.spacing = 22;
    }
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

    // Update telemetry card visual selection borders
    self.metricCardTotal.layer.borderWidth = (filter == PPVetListFilterAll) ? 2.0 : 1.0;
    self.metricCardActive.layer.borderWidth = (filter == PPVetListFilterActive) ? 2.0 : 1.0;
    self.metricCardDisabled.layer.borderWidth = (filter == PPVetListFilterDisabled) ? 2.0 : 1.0;

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
    PPEnableDynamicTypeForTextField(sv.textField, UIFontTextStyleBody);
    [self.view addSubview:sv];
    self.searchView = sv;

    UIView *hairline = [UIView new];
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    hairline.backgroundColor = PPHairlineColor();
    [self.view addSubview:hairline];

    [NSLayoutConstraint activateConstraints:@[
        // Anchored to the filter stack (not just the first chip) so the row can
        // stack vertically at accessibility text sizes without overlapping.
        [sv.topAnchor constraintEqualToAnchor:self.filterStack.bottomAnchor constant:PPSpaceXS],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        // 44pt minimum touch target, and free to grow with the scaled font.
        [sv.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],

        [hairline.topAnchor constraintEqualToAnchor:sv.bottomAnchor constant:PPSpaceMDHalf],
        [hairline.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceXL],
        [hairline.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceXL],
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
    self.tableView.contentInset = UIEdgeInsetsMake(PPSpaceSM, 0, 96, 0);
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
    headline.font = [Styling fontBold:PPFontTitle2];
    headline.textColor = PrimaryTextClr;
    headline.textAlignment = NSTextAlignmentCenter;
    headline.numberOfLines = 0;
    PPEnableDynamicType(headline, UIFontTextStyleTitle2);
    [_emptyContainer addSubview:headline];
    _emptyHeadline = headline;

    UIView *rule = [UIView new];
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    rule.backgroundColor = AppPrimaryClr;
    [_emptyContainer addSubview:rule];
    _emptyRule = rule;

    // Loading honesty: the first snapshot of the vets listener used to land on
    // the "empty" copy, so a spinner now owns that state until data arrives.
    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.color = AppPrimaryClr;
    _loadingIndicator.hidesWhenStopped = YES;
    [_emptyContainer addSubview:_loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceXXL],
        [_emptyContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceXXL],

        [headline.topAnchor constraintEqualToAnchor:_emptyContainer.topAnchor],
        [headline.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [headline.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],

        [rule.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:18],
        [rule.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [rule.widthAnchor constraintEqualToConstant:42],
        [rule.heightAnchor constraintEqualToConstant:PPSpaceXXS],
        [rule.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor],

        // Occupies the same optical slot; the copy is hidden while it spins.
        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_emptyContainer.centerYAnchor],
    ]];
}

- (void)pp_setVetsLoading:(BOOL)loading {
    _isLoadingVets = loading;
    self.emptyHeadline.hidden = loading;
    self.emptyRule.hidden = loading;
    if (loading) {
        self.emptyContainer.hidden = NO;
        [self.loadingIndicator startAnimating];
    } else {
        [self.loadingIndicator stopAnimating];
    }
}

#pragma mark - Data

- (void)startListening {
    [self pp_setVetsLoading:YES];
    __weak typeof(self) weakSelf = self;
    self.listener = [[PPVetManager sharedManager] observeAllVets:^(NSArray<PPVetModel *> *vets, NSError *error) {
        if (error) { [weakSelf pp_setVetsLoading:NO]; DLog(@"[VetsList] listener error: %@", error.localizedDescription); return; }
        __strong typeof(weakSelf) self = weakSelf;
        [self pp_setVetsLoading:NO];
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

    self.metricValueTotal.text = [NSString stringWithFormat:@"%ld", (long)total];
    self.metricValueActive.text = [NSString stringWithFormat:@"%ld", (long)active];
    self.metricValueDisabled.text = [NSString stringWithFormat:@"%ld", (long)disabled];

    self.metaLabel.text = total == 0
        ? (kLang(@"Vet_Empty_List") ?: ([Language isRTL] ? @"لا توجد ملفات أطباء مسجلة حالياً" : @"No veterinarians registered yet"))
        : [NSString stringWithFormat:@"%ld %@", (long)total, kLang(@"Vet_Section_Title") ?: ([Language isRTL] ? @"طبيب ومركز بيطري" : @"Veterinarians")];
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
    // While a fetch is in flight the placeholder shows the spinner, not the
    // "no vets" copy.
    self.emptyHeadline.hidden = self.isLoadingVets;
    self.emptyRule.hidden     = self.isLoadingVets;

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
    if (PPMotionReduced()) {
        // Reduce Motion: land on the final state, no translate/fade stagger.
        for (UITableViewCell *cell in cells) {
            cell.alpha = 1;
            cell.transform = CGAffineTransformIdentity;
        }
        return;
    }
    for (NSUInteger idx = 0; idx < cells.count; idx++) {
        UITableViewCell *cell = cells[idx];
        cell.alpha = 0;
        cell.transform = CGAffineTransformMakeTranslation(0, 16);
        [UIView animateWithDuration:0.42
                              delay:MIN(0.035 * idx, 0.28) // capped so long lists never crawl in
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

    __weak typeof(self) weakSelf = self;
    cell.onCallTapped = ^(PPVetModel *v) {
        NSString *phone = [v.phone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (phone.length == 0) return;
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tel://" stringByAppendingString:phone]] options:@{} completionHandler:nil];
    };

    cell.onWhatsAppTapped = ^(PPVetModel *v) {
        NSString *wa = [v.whatsapp stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (wa.length == 0) return;
        NSString *clean = [wa stringByReplacingOccurrencesOfString:@"+" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *urlStr = [NSString stringWithFormat:@"https://wa.me/%@", clean];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr] options:@{} completionHandler:nil];
    };

    cell.onToggleStatusTapped = ^(PPVetModel *v) {
        [weakSelf toggleDisabledAtIndexPath:indexPath];
    };

    // The row reads as one button instead of a pile of separate labels; the
    // status word reuses the filter copy already localized on this screen.
    cell.isAccessibilityElement = YES;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    if (vet) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (PPSafeString(vet.title).length > 0) { [parts addObject:PPSafeString(vet.title)]; }
        [parts addObject:vet.isDisabled ? kLang(@"Vet_Filter_Disabled") : kLang(@"Vet_Filter_Active")];
        if (PPSafeString(vet.phone).length > 0) { [parts addObject:PPSafeString(vet.phone)]; }
        cell.accessibilityLabel = [parts componentsJoinedByString:@", "];
    } else {
        cell.accessibilityLabel = nil;
    }
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
    editAction.accessibilityLabel = kLang(@"Vet_Edit_Title"); // icon-only swipe action

    BOOL isDisabled = vet.isDisabled;
    UIContextualAction *toggleAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf toggleDisabledAtIndexPath:indexPath]; handler(YES);
    }];
    toggleAction.backgroundColor = isDisabled ? AppPrimaryClr : [SeconderyTextClr colorWithAlphaComponent:0.55];
    toggleAction.image = [UIImage systemImageNamed:isDisabled ? @"checkmark" : @"nosign"];
    toggleAction.accessibilityLabel = isDisabled ? kLang(@"Vet_Action_Enable") : kLang(@"Vet_Action_Disable");

    UIContextualAction *subAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^handler)(BOOL)) {
        [weakSelf manageSubscriptionAtIndexPath:indexPath]; handler(YES);
    }];
    subAction.backgroundColor = AppPrimaryClr;
    subAction.image = [UIImage systemImageNamed:@"creditcard"];
    subAction.accessibilityLabel = kLang(@"Vet_Subscription");

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
    deleteAction.accessibilityLabel = kLang(@"Delete"); // icon-only swipe action
    if (![self pp_canManageVetWorkspace]) return nil;
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.didPlayEntrance) {
        if (PPMotionReduced()) { cell.alpha = 1; return; }
        cell.alpha = 0;
        PPAnimateRespectingMotion(PPAnimDurationNormal, ^{ cell.alpha = 1; }, nil);
    }
}

#pragma mark - iPad Hardware Key Commands

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        return nil;
    }
    return @[
        [UIKeyCommand keyCommandWithInput:@"n"
                            modifierFlags:UIKeyModifierCommand
                                   action:@selector(addVetTapped)
                     discoverabilityTitle:[Language isRTL] ? @"إضافة طبيب بيطري" : @"Add Veterinarian"],
        [UIKeyCommand keyCommandWithInput:@"r"
                            modifierFlags:UIKeyModifierCommand
                                   action:@selector(onRefresh)
                     discoverabilityTitle:[Language isRTL] ? @"تحديث القائمة" : @"Refresh List"],
        [UIKeyCommand keyCommandWithInput:@"f"
                            modifierFlags:UIKeyModifierCommand
                                   action:@selector(focusSearchField)
                     discoverabilityTitle:[Language isRTL] ? @"بحث في الأطباء" : @"Search Vets"],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                            modifierFlags:0
                                   action:@selector(handleEscapeKey)
                     discoverabilityTitle:[Language isRTL] ? @"رجوع" : @"Back"]
    ];
}

- (void)focusSearchField {
    [self.searchView.textField becomeFirstResponder];
}

- (void)handleEscapeKey {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
