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

#pragma mark - Filter Chip (tactile pill with count badge)

@interface _PPVetFilterChip : UIControl
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIView  *countBadge;
@property (nonatomic, assign) BOOL selectedState;
- (instancetype)initWithTitle:(NSString *)title;
- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated;
- (void)setCount:(NSInteger)count;
@end

@implementation _PPVetFilterChip {
    UIStackView *_contentStack;
    NSLayoutConstraint *_badgeWidthConstraint;
}

- (instancetype)initWithTitle:(NSString *)title {
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 13.0;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
        }
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75].CGColor;
        self.backgroundColor = [UIColor ppElevatedSurface];

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontMedium:13.0];
        _titleLabel.textColor = SeconderyTextClr;
        _titleLabel.text = title;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.userInteractionEnabled = NO;
        PPEnableDynamicType(_titleLabel, UIFontTextStyleSubheadline);

        _countBadge = [UIView new];
        _countBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _countBadge.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.10];
        _countBadge.layer.cornerRadius = 10.0;
        _countBadge.clipsToBounds = YES;
        _countBadge.userInteractionEnabled = NO;

        _countLabel = [UILabel new];
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _countLabel.font = [Styling fontBold:11.5];
        _countLabel.textColor = SeconderyTextClr;
        _countLabel.textAlignment = NSTextAlignmentCenter;
        _countLabel.text = @"0";
        _countLabel.userInteractionEnabled = NO;
        PPEnableDynamicType(_countLabel, UIFontTextStyleCaption1);
        [_countBadge addSubview:_countLabel];

        _contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _countBadge]];
        _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        _contentStack.axis = UILayoutConstraintAxisHorizontal;
        _contentStack.alignment = UIStackViewAlignmentCenter;
        _contentStack.spacing = 6.0;
        _contentStack.userInteractionEnabled = NO;
        _contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        [self addSubview:_contentStack];

        _badgeWidthConstraint = [_countBadge.widthAnchor constraintGreaterThanOrEqualToConstant:20.0];

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:42.0],

            [_contentStack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_contentStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_contentStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:6.0],
            [_contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-6.0],

            [_countBadge.heightAnchor constraintEqualToConstant:20.0],
            _badgeWidthConstraint,

            [_countLabel.leadingAnchor constraintEqualToAnchor:_countBadge.leadingAnchor constant:6.0],
            [_countLabel.trailingAnchor constraintEqualToAnchor:_countBadge.trailingAnchor constant:-6.0],
            [_countLabel.centerYAnchor constraintEqualToAnchor:_countBadge.centerYAnchor],
        ]];

        if (@available(iOS 13.4, *)) {
            [self addInteraction:[[UIPointerInteraction alloc] initWithDelegate:nil]];
        }

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityLabel = title;
    }
    return self;
}

- (void)setSelectedState:(BOOL)selected animated:(BOOL)animated {
    _selectedState = selected;
    void (^apply)(void) = ^{
        if (selected) {
            self.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
            self.layer.borderColor = AppPrimaryClr.CGColor;
            self.layer.borderWidth = 1.5;
            self.titleLabel.textColor = AppPrimaryClr;
            self.titleLabel.font = [Styling fontBold:13.0];
            self.countBadge.backgroundColor = AppPrimaryClr;
            self.countLabel.textColor = UIColor.whiteColor;
        } else {
            self.backgroundColor = [UIColor ppElevatedSurface];
            self.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75].CGColor;
            self.layer.borderWidth = 1.0;
            self.titleLabel.textColor = SeconderyTextClr;
            self.titleLabel.font = [Styling fontMedium:13.0];
            self.countBadge.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.10];
            self.countLabel.textColor = SeconderyTextClr;
        }
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

// Spatial Containers (Adaptive iPhone vs iPad)
@property (nonatomic, strong) UIView *masterContainer;
@property (nonatomic, strong) UIView *inspectorContainer;
@property (nonatomic, strong) NSLayoutConstraint *masterTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *masterWidthConstraint;
@property (nonatomic, strong) PPVetModel *selectedVet;

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

@property (nonatomic, strong) PPS *searchView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, strong) UILabel *emptyHeadline;
@property (nonatomic, strong) UIView *emptyRule;
@property (nonatomic, strong) UIButton *emptyRetryButton;
@property (nonatomic, strong) NSLayoutConstraint *emptyNormalBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *emptyRetryBottomConstraint;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) BOOL isLoadingVets;

// iPad Live Clinical Inspector subviews
@property (nonatomic, strong) UIView *inspectorEmptyState;
@property (nonatomic, strong) UIStackView *inspectorDetailStack;
@property (nonatomic, strong) UIImageView *inspectorAvatar;
@property (nonatomic, strong) UILabel *inspectorNameLabel;
@property (nonatomic, strong) UILabel *inspectorTypeBadge;
@property (nonatomic, strong) UILabel *inspectorFeeBadge;
@property (nonatomic, strong) UILabel *inspectorBioLabel;
@property (nonatomic, strong) UILabel *inspectorDateLabel;
@property (nonatomic, strong) UILabel *inspectorStatusBadge;
@property (nonatomic, strong) UIButton *inspectorCallBtn;
@property (nonatomic, strong) UIButton *inspectorWABtn;
@property (nonatomic, strong) UIButton *inspectorEditBtn;
@property (nonatomic, strong) UIButton *inspectorSubBtn;
@property (nonatomic, strong) UIButton *inspectorToggleBtn;
@property (nonatomic, strong) UIButton *inspectorDeleteBtn;

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

    [self setupSpatialContainers];
    [self setupTitleHeader];
    [self setupFilterRow];
    [self setupSearchField];
    [self setupTableView];
    [self setupEmptyState];
    [self setupInspectorPane];
    [self startListening];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateLayoutForCurrentBounds];
}

- (void)updateLayoutForCurrentBounds {
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isRegularWidth = isPad && (self.view.bounds.size.width >= 720.0);

    if (isRegularWidth) {
        self.masterTrailingConstraint.active = NO;
        self.masterWidthConstraint.active = YES;
        self.inspectorContainer.hidden = NO;
        if (!self.selectedVet && self.filteredVets.count > 0) {
            self.selectedVet = self.filteredVets.firstObject;
            [self updateInspectorWithVet:self.selectedVet];
            [self.tableView reloadData];
        }
    } else {
        self.masterWidthConstraint.active = NO;
        self.masterTrailingConstraint.active = YES;
        self.inspectorContainer.hidden = YES;
    }
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

- (void)setupSpatialContainers {
    self.masterContainer = [UIView new];
    self.masterContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.masterContainer];

    self.inspectorContainer = [UIView new];
    self.inspectorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorContainer.hidden = YES;
    [self.view addSubview:self.inspectorContainer];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    self.masterTrailingConstraint = [self.masterContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor];
    self.masterWidthConstraint = [self.masterContainer.widthAnchor constraintEqualToConstant:410.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.masterContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.masterContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.masterContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        self.masterTrailingConstraint,

        [self.inspectorContainer.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8.0],
        [self.inspectorContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20.0],
        [self.inspectorContainer.leadingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor constant:16.0],
        [self.inspectorContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
    ]];
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
        self.inspectorContainer.backgroundColor = [self pp_surfaceColor];
        self.inspectorContainer.layer.borderColor = [self pp_borderColor].CGColor;
        PPApplyElevatedShadow(self.inspectorContainer);
        [self updateAmbientBackgroundForStyle];
    }
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        [self pp_applyFilterRowLayoutForTextSize];
        [self pp_applyHeroTitleLineLimitForTextSize];
        [self.tableView reloadData];
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

#pragma mark - NextGen V9: clinical roster introduction

- (void)setupTitleHeader {
    BOOL rtl = Language.isRTL;
    NSTextAlignment align = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    CGFloat margin = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 20.0 : 16.0;

    self.heroSurfaceView = [UIView new];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.heroSurfaceView, 18.0);
    self.heroSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.heroSurfaceView.layer.borderColor = [self pp_borderColor].CGColor;
    self.heroSurfaceView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.04].CGColor;
    self.heroSurfaceView.layer.shadowOffset = CGSizeMake(0, 3);
    self.heroSurfaceView.layer.shadowRadius = 8.0;
    self.heroSurfaceView.layer.shadowOpacity = 1.0;
    [self.masterContainer addSubview:self.heroSurfaceView];

    // Clinical identity pill
    UIView *badgeContainer = [UIView new];
    badgeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    badgeContainer.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    PPApplyContinuousCorners(badgeContainer, 8.0);
    badgeContainer.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:badgeContainer];

    UIImageSymbolConfiguration *badgeSymConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.5 weight:UIImageSymbolWeightBold];
    UIImageView *badgeIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"stethoscope" withConfiguration:badgeSymConfig]];
    badgeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    badgeIcon.tintColor = AppPrimaryClr;
    badgeIcon.contentMode = UIViewContentModeScaleAspectFit;
    [badgeContainer addSubview:badgeIcon];

    self.eyebrowLabel = [UILabel new];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.text = [Language isRTL] ? @"العيادة البيطرية" : @"Veterinary Clinic";
    self.eyebrowLabel.font = [Styling fontBold:11.5];
    self.eyebrowLabel.textColor = AppPrimaryClr;
    self.eyebrowLabel.textAlignment = align;
    PPEnableDynamicType(self.eyebrowLabel, UIFontTextStyleCaption1);
    [badgeContainer addSubview:self.eyebrowLabel];

    // Live Duty Indicator (Green Beacon)
    UIView *liveDutyView = [UIView new];
    liveDutyView.translatesAutoresizingMaskIntoConstraints = NO;
    liveDutyView.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(liveDutyView, 8.0);
    liveDutyView.clipsToBounds = YES;
    [self.heroSurfaceView addSubview:liveDutyView];

    UIView *liveDot = [UIView new];
    liveDot.translatesAutoresizingMaskIntoConstraints = NO;
    liveDot.backgroundColor = [UIColor ppSuccess];
    liveDot.layer.cornerRadius = 3.5;
    liveDot.clipsToBounds = YES;
    [liveDutyView addSubview:liveDot];

    UILabel *liveDutyLabel = [UILabel new];
    liveDutyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    liveDutyLabel.text = [Language isRTL] ? @"الخدمة نشطة" : @"Duty Active";
    liveDutyLabel.font = [Styling fontBold:11.0];
    liveDutyLabel.textColor = [UIColor ppSuccess];
    [liveDutyView addSubview:liveDutyLabel];

    // Title: "الفريق البيطري"
    self.titleLabel = [UILabel new];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = kLang(@"Vet_Roster_Title");
    self.titleLabel.font = [Styling fontBold:22.0];
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.textAlignment = align;
    self.titleLabel.numberOfLines = 2;
    PPEnableDynamicType(self.titleLabel, UIFontTextStyleTitle2);
    [self.heroSurfaceView addSubview:self.titleLabel];

    // Meta summary: "الإجمالي 3 · النشط 3"
    self.metaLabel = [UILabel new];
    self.metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaLabel.textColor = SeconderyTextClr;
    self.metaLabel.font = [Styling fontMedium:12.5];
    self.metaLabel.textAlignment = align;
    self.metaLabel.numberOfLines = 0;
    self.metaLabel.text = kLang(@"Vet_Roster_Empty_Summary");
    PPEnableDynamicType(self.metaLabel, UIFontTextStyleFootnote);
    [self.heroSurfaceView addSubview:self.metaLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.masterContainer.leadingAnchor constant:margin],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor constant:-margin],

        // Badge Container (leading)
        [badgeContainer.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:12.0],
        [badgeContainer.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:14.0],
        [badgeContainer.heightAnchor constraintEqualToConstant:24.0],

        [badgeIcon.leadingAnchor constraintEqualToAnchor:badgeContainer.leadingAnchor constant:8.0],
        [badgeIcon.centerYAnchor constraintEqualToAnchor:badgeContainer.centerYAnchor],
        [badgeIcon.widthAnchor constraintEqualToConstant:14.0],
        [badgeIcon.heightAnchor constraintEqualToConstant:14.0],

        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:badgeIcon.trailingAnchor constant:5.0],
        [self.eyebrowLabel.trailingAnchor constraintEqualToAnchor:badgeContainer.trailingAnchor constant:-8.0],
        [self.eyebrowLabel.centerYAnchor constraintEqualToAnchor:badgeContainer.centerYAnchor],

        // Live Duty Beacon (trailing)
        [liveDutyView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:12.0],
        [liveDutyView.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-14.0],
        [liveDutyView.heightAnchor constraintEqualToConstant:24.0],

        [liveDot.leadingAnchor constraintEqualToAnchor:liveDutyView.leadingAnchor constant:8.0],
        [liveDot.centerYAnchor constraintEqualToAnchor:liveDutyView.centerYAnchor],
        [liveDot.widthAnchor constraintEqualToConstant:7.0],
        [liveDot.heightAnchor constraintEqualToConstant:7.0],

        [liveDutyLabel.leadingAnchor constraintEqualToAnchor:liveDot.trailingAnchor constant:5.0],
        [liveDutyLabel.trailingAnchor constraintEqualToAnchor:liveDutyView.trailingAnchor constant:-8.0],
        [liveDutyLabel.centerYAnchor constraintEqualToAnchor:liveDutyView.centerYAnchor],

        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:badgeContainer.bottomAnchor constant:10.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:14.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-14.0],

        // Meta summary
        [self.metaLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:14.0],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-14.0],
        [self.metaLabel.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-12.0],
    ]];
    [self pp_applyHeroTitleLineLimitForTextSize];
}

- (void)pp_applyHeroTitleLineLimitForTextSize {
    self.titleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 0 : 2;
}

#pragma mark - Filter row (tactile pills with count badges)

- (void)setupFilterRow {
    _chipAll      = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_All") ?: ([Language isRTL] ? @"الكل" : @"All")];
    _chipActive   = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_Active") ?: ([Language isRTL] ? @"نشط" : @"Active")];
    _chipDisabled = [[_PPVetFilterChip alloc] initWithTitle:kLang(@"Vet_Filter_Disabled") ?: ([Language isRTL] ? @"معطل" : @"Disabled")];
    [_chipAll      addTarget:self action:@selector(chipAllTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipActive   addTarget:self action:@selector(chipActiveTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipDisabled addTarget:self action:@selector(chipDisabledTapped) forControlEvents:UIControlEventTouchUpInside];
    [_chipAll setSelectedState:YES animated:NO];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_chipAll, _chipActive, _chipDisabled]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8.0;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.masterContainer addSubview:stack];
    self.filterStack = stack;

    CGFloat hMargin = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 20.0 : 16.0;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:12.0],
        [stack.leadingAnchor constraintEqualToAnchor:self.masterContainer.leadingAnchor constant:hMargin],
        [stack.trailingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor constant:-hMargin],
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
        self.filterStack.alignment = UIStackViewAlignmentCenter;
        self.filterStack.spacing = 10.0;
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

    [self applyFilterAndReload];
}

#pragma mark - Search Capsule

- (void)setupSearchField {
    PPS *sv = [[PPS alloc] initWithFrame:CGRectZero];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.delegate = self;
    sv.cornerRadius = 14.0;
    sv.blurEnabled = NO;
    sv.shadowEnabled = NO;
    sv.strokeColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.75];
    sv.textField.placeholder = kLang(@"Vet_Search_Placeholder") ?: ([Language isRTL] ? @"ابحث باسم الطبيب، التخصص، أو الهاتف..." : @"Search by name, specialty, or phone...");
    sv.textField.font = [Styling fontRegular:13.5];
    sv.backgroundColor = [UIColor ppElevatedSurface];
    sv.showsPrimaryButton = NO;
    sv.contentInsets = UIEdgeInsetsMake(6, 14, 6, 14);

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightMedium];
    UIImageView *magIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:symConfig]];
    magIcon.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.8];
    magIcon.contentMode = UIViewContentModeCenter;
    magIcon.frame = CGRectMake(0, 0, 26, 20);
    sv.textField.leftView = magIcon;
    sv.textField.leftViewMode = UITextFieldViewModeAlways;

    PPEnableDynamicTypeForTextField(sv.textField, UIFontTextStyleBody);
    [self.masterContainer addSubview:sv];
    self.searchView = sv;

    CGFloat hMargin = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 20.0 : 16.0;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.filterStack.bottomAnchor constant:10.0],
        [sv.leadingAnchor constraintEqualToAnchor:self.masterContainer.leadingAnchor constant:hMargin],
        [sv.trailingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor constant:-hMargin],
        [sv.heightAnchor constraintEqualToConstant:46.0],
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
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = [PPVetCell preferredHeight];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0, 96.0, 0);
    [self.tableView registerClass:[PPVetCell class] forCellReuseIdentifier:[PPVetCell reuseID]];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = AppPrimaryClr;
    [refresh addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    [self.masterContainer addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchView.bottomAnchor constant:10.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.masterContainer.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.masterContainer.bottomAnchor],
    ]];
}

#pragma mark - iPad Live Clinical Inspector Studio

- (void)setupInspectorPane {
    self.inspectorContainer.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.inspectorContainer, PPCornerHero);
    PPApplyElevatedShadow(self.inspectorContainer);
    self.inspectorContainer.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.inspectorContainer.layer.borderColor = [self pp_borderColor].CGColor;
    self.inspectorContainer.clipsToBounds = YES;

    // 1. Standby / Empty Placeholder
    self.inspectorEmptyState = [UIView new];
    self.inspectorEmptyState.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inspectorContainer addSubview:self.inspectorEmptyState];

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"stethoscope.circle.fill"]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.4];
    [self.inspectorEmptyState addSubview:emptyIcon];

    UILabel *emptyTitle = [UILabel new];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.font = [Styling fontBold:20.0];
    emptyTitle.textColor = PrimaryTextClr;
    emptyTitle.textAlignment = NSTextAlignmentCenter;
    emptyTitle.text = [Language isRTL] ? @"معاينة الملف البيطري" : @"Veterinarian Inspector";
    [self.inspectorEmptyState addSubview:emptyTitle];

    UILabel *emptySub = [UILabel new];
    emptySub.translatesAutoresizingMaskIntoConstraints = NO;
    emptySub.font = [Styling fontRegular:13.5];
    emptySub.textColor = SeconderyTextClr;
    emptySub.textAlignment = NSTextAlignmentCenter;
    emptySub.numberOfLines = 2;
    emptySub.text = [Language isRTL]
        ? @"اختر طبيباً بيطرياً من القائمة لمعاينة تفاصيل الاعتماد، والتواصل المباشر، وإدارة الاشتراك."
        : @"Select a veterinarian from the list to inspect clinical credentials, contacts, and subscriptions.";
    [self.inspectorEmptyState addSubview:emptySub];

    [NSLayoutConstraint activateConstraints:@[
        [self.inspectorEmptyState.centerXAnchor constraintEqualToAnchor:self.inspectorContainer.centerXAnchor],
        [self.inspectorEmptyState.centerYAnchor constraintEqualToAnchor:self.inspectorContainer.centerYAnchor],
        [self.inspectorEmptyState.leadingAnchor constraintEqualToAnchor:self.inspectorContainer.leadingAnchor constant:32.0],
        [self.inspectorEmptyState.trailingAnchor constraintEqualToAnchor:self.inspectorContainer.trailingAnchor constant:-32.0],

        [emptyIcon.centerXAnchor constraintEqualToAnchor:self.inspectorEmptyState.centerXAnchor],
        [emptyIcon.topAnchor constraintEqualToAnchor:self.inspectorEmptyState.topAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:72.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:72.0],

        [emptyTitle.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:16.0],
        [emptyTitle.leadingAnchor constraintEqualToAnchor:self.inspectorEmptyState.leadingAnchor],
        [emptyTitle.trailingAnchor constraintEqualToAnchor:self.inspectorEmptyState.trailingAnchor],

        [emptySub.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:6.0],
        [emptySub.leadingAnchor constraintEqualToAnchor:self.inspectorEmptyState.leadingAnchor],
        [emptySub.trailingAnchor constraintEqualToAnchor:self.inspectorEmptyState.trailingAnchor],
        [emptySub.bottomAnchor constraintEqualToAnchor:self.inspectorEmptyState.bottomAnchor],
    ]];

    // 2. Active Detail Scroll View
    UIScrollView *inspectorScroll = [UIScrollView new];
    inspectorScroll.translatesAutoresizingMaskIntoConstraints = NO;
    inspectorScroll.showsVerticalScrollIndicator = NO;
    [self.inspectorContainer addSubview:inspectorScroll];

    self.inspectorDetailStack = [UIStackView new];
    self.inspectorDetailStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorDetailStack.axis = UILayoutConstraintAxisVertical;
    self.inspectorDetailStack.spacing = 16.0;
    self.inspectorDetailStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [inspectorScroll addSubview:self.inspectorDetailStack];

    [NSLayoutConstraint activateConstraints:@[
        [inspectorScroll.topAnchor constraintEqualToAnchor:self.inspectorContainer.topAnchor constant:20.0],
        [inspectorScroll.leadingAnchor constraintEqualToAnchor:self.inspectorContainer.leadingAnchor constant:22.0],
        [inspectorScroll.trailingAnchor constraintEqualToAnchor:self.inspectorContainer.trailingAnchor constant:-22.0],
        [inspectorScroll.bottomAnchor constraintEqualToAnchor:self.inspectorContainer.bottomAnchor constant:-20.0],

        [self.inspectorDetailStack.topAnchor constraintEqualToAnchor:inspectorScroll.contentLayoutGuide.topAnchor],
        [self.inspectorDetailStack.leadingAnchor constraintEqualToAnchor:inspectorScroll.contentLayoutGuide.leadingAnchor],
        [self.inspectorDetailStack.trailingAnchor constraintEqualToAnchor:inspectorScroll.contentLayoutGuide.trailingAnchor],
        [self.inspectorDetailStack.bottomAnchor constraintEqualToAnchor:inspectorScroll.contentLayoutGuide.bottomAnchor],
        [self.inspectorDetailStack.widthAnchor constraintEqualToAnchor:inspectorScroll.frameLayoutGuide.widthAnchor],
    ]];

    [self buildInspectorCardViews];
    inspectorScroll.hidden = YES;
}

- (void)buildInspectorCardViews {
    // ── Header Card (Avatar + Title + Type + Fee) ──
    UIView *topCard = [UIView new];
    topCard.translatesAutoresizingMaskIntoConstraints = NO;
    topCard.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(topCard, PPCornerCard);
    topCard.layer.borderWidth = 1.0;
    topCard.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5].CGColor;

    self.inspectorAvatar = [UIImageView new];
    self.inspectorAvatar.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorAvatar.contentMode = UIViewContentModeScaleAspectFill;
    self.inspectorAvatar.clipsToBounds = YES;
    self.inspectorAvatar.layer.cornerRadius = 22.0;
    self.inspectorAvatar.layer.cornerCurve = kCACornerCurveContinuous;
    self.inspectorAvatar.layer.borderWidth = 2.5;
    self.inspectorAvatar.layer.borderColor = AppPrimaryClr.CGColor;
    self.inspectorAvatar.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    [topCard addSubview:self.inspectorAvatar];

    self.inspectorNameLabel = [UILabel new];
    self.inspectorNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorNameLabel.font = [Styling fontBold:20.0];
    self.inspectorNameLabel.textColor = PrimaryTextClr;
    self.inspectorNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.inspectorNameLabel.numberOfLines = 2;
    [topCard addSubview:self.inspectorNameLabel];

    self.inspectorTypeBadge = [UILabel new];
    self.inspectorTypeBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorTypeBadge.font = [Styling fontBold:12.0];
    self.inspectorTypeBadge.textColor = AppPrimaryClr;
    self.inspectorTypeBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    PPApplyContinuousCorners(self.inspectorTypeBadge, PPCornerPill);
    [topCard addSubview:self.inspectorTypeBadge];

    self.inspectorFeeBadge = [UILabel new];
    self.inspectorFeeBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorFeeBadge.font = [Styling fontBold:12.5];
    PPApplyContinuousCorners(self.inspectorFeeBadge, PPCornerPill);
    [topCard addSubview:self.inspectorFeeBadge];

    self.inspectorStatusBadge = [UILabel new];
    self.inspectorStatusBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorStatusBadge.font = [Styling fontBold:11.5];
    self.inspectorStatusBadge.textAlignment = NSTextAlignmentCenter;
    PPApplyContinuousCorners(self.inspectorStatusBadge, PPCornerPill);
    [topCard addSubview:self.inspectorStatusBadge];

    [NSLayoutConstraint activateConstraints:@[
        [self.inspectorAvatar.topAnchor constraintEqualToAnchor:topCard.topAnchor constant:18.0],
        [self.inspectorAvatar.leadingAnchor constraintEqualToAnchor:topCard.leadingAnchor constant:18.0],
        [self.inspectorAvatar.widthAnchor constraintEqualToConstant:72.0],
        [self.inspectorAvatar.heightAnchor constraintEqualToConstant:72.0],

        [self.inspectorNameLabel.topAnchor constraintEqualToAnchor:topCard.topAnchor constant:18.0],
        [self.inspectorNameLabel.leadingAnchor constraintEqualToAnchor:self.inspectorAvatar.trailingAnchor constant:14.0],
        [self.inspectorNameLabel.trailingAnchor constraintEqualToAnchor:topCard.trailingAnchor constant:-18.0],

        [self.inspectorTypeBadge.topAnchor constraintEqualToAnchor:self.inspectorNameLabel.bottomAnchor constant:6.0],
        [self.inspectorTypeBadge.leadingAnchor constraintEqualToAnchor:self.inspectorNameLabel.leadingAnchor],
        [self.inspectorTypeBadge.heightAnchor constraintEqualToConstant:24.0],

        [self.inspectorFeeBadge.leadingAnchor constraintEqualToAnchor:self.inspectorTypeBadge.trailingAnchor constant:8.0],
        [self.inspectorFeeBadge.centerYAnchor constraintEqualToAnchor:self.inspectorTypeBadge.centerYAnchor],
        [self.inspectorFeeBadge.heightAnchor constraintEqualToConstant:24.0],

        [self.inspectorStatusBadge.topAnchor constraintEqualToAnchor:self.inspectorTypeBadge.bottomAnchor constant:8.0],
        [self.inspectorStatusBadge.leadingAnchor constraintEqualToAnchor:self.inspectorNameLabel.leadingAnchor],
        [self.inspectorStatusBadge.heightAnchor constraintEqualToConstant:24.0],
        [self.inspectorStatusBadge.bottomAnchor constraintEqualToAnchor:topCard.bottomAnchor constant:-18.0],
    ]];
    [self.inspectorDetailStack addArrangedSubview:topCard];

    // ── Communications Quick Dock ──
    UIStackView *commStack = [UIStackView new];
    commStack.translatesAutoresizingMaskIntoConstraints = NO;
    commStack.axis = UILayoutConstraintAxisHorizontal;
    commStack.spacing = 10.0;
    commStack.distribution = UIStackViewDistributionFillEqually;
    commStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    self.inspectorCallBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.inspectorCallBtn.backgroundColor = [[UIColor ppInfo] colorWithAlphaComponent:0.12];
    self.inspectorCallBtn.tintColor = [UIColor ppInfo];
    PPApplyContinuousCorners(self.inspectorCallBtn, PPCornerPill);
    [self.inspectorCallBtn setImage:[UIImage systemImageNamed:@"phone.fill" withConfiguration:symCfg] forState:UIControlStateNormal];
    self.inspectorCallBtn.accessibilityLabel = kLang(@"Vet_Action_Call");
    [self.inspectorCallBtn setTitle:[Language isRTL] ? @" اتصال فوري" : @" Direct Call" forState:UIControlStateNormal];
    self.inspectorCallBtn.titleLabel.font = [Styling fontBold:13.0];
    [self.inspectorCallBtn addTarget:self action:@selector(inspectorCallTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inspectorCallBtn.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [commStack addArrangedSubview:self.inspectorCallBtn];

    UIColor *waGreen = [UIColor colorWithRed:37.0/255.0 green:211.0/255.0 blue:102.0/255.0 alpha:1.0];
    self.inspectorWABtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.inspectorWABtn.backgroundColor = [waGreen colorWithAlphaComponent:0.14];
    self.inspectorWABtn.tintColor = waGreen;
    PPApplyContinuousCorners(self.inspectorWABtn, PPCornerPill);
    [self.inspectorWABtn setImage:[UIImage systemImageNamed:@"message.circle.fill" withConfiguration:symCfg] forState:UIControlStateNormal];
    self.inspectorWABtn.accessibilityLabel = kLang(@"Vet_Action_WhatsApp");
    [self.inspectorWABtn setTitle:[Language isRTL] ? @" واتساب الطبيب" : @" WhatsApp Chat" forState:UIControlStateNormal];
    self.inspectorWABtn.titleLabel.font = [Styling fontBold:13.0];
    [self.inspectorWABtn addTarget:self action:@selector(inspectorWATapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inspectorWABtn.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [commStack addArrangedSubview:self.inspectorWABtn];

    [self.inspectorDetailStack addArrangedSubview:commStack];

    // ── Clinical Bio & Specialty Section ──
    UIView *bioCard = [UIView new];
    bioCard.translatesAutoresizingMaskIntoConstraints = NO;
    bioCard.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
    PPApplyContinuousCorners(bioCard, PPCornerCard);
    bioCard.layer.borderWidth = 1.0;
    bioCard.layer.borderColor = [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.5].CGColor;

    UILabel *bioTitle = [UILabel new];
    bioTitle.translatesAutoresizingMaskIntoConstraints = NO;
    bioTitle.font = [Styling fontBold:14.0];
    bioTitle.textColor = PrimaryTextClr;
    bioTitle.text = [Language isRTL] ? @"النبذة الطبية والخبرات" : @"Clinical Bio & Specialties";
    bioTitle.textAlignment = Language.alignmentForCurrentLanguage;
    [bioCard addSubview:bioTitle];

    self.inspectorBioLabel = [UILabel new];
    self.inspectorBioLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorBioLabel.font = [Styling fontRegular:13.5];
    self.inspectorBioLabel.textColor = SeconderyTextClr;
    self.inspectorBioLabel.numberOfLines = 0;
    self.inspectorBioLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [bioCard addSubview:self.inspectorBioLabel];

    self.inspectorDateLabel = [UILabel new];
    self.inspectorDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.inspectorDateLabel.font = [Styling fontMedium:12.5];
    self.inspectorDateLabel.textColor = [self pp_borderColor];
    self.inspectorDateLabel.textColor = SeconderyTextClr;
    self.inspectorDateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [bioCard addSubview:self.inspectorDateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [bioTitle.topAnchor constraintEqualToAnchor:bioCard.topAnchor constant:16.0],
        [bioTitle.leadingAnchor constraintEqualToAnchor:bioCard.leadingAnchor constant:16.0],
        [bioTitle.trailingAnchor constraintEqualToAnchor:bioCard.trailingAnchor constant:-16.0],

        [self.inspectorBioLabel.topAnchor constraintEqualToAnchor:bioTitle.bottomAnchor constant:8.0],
        [self.inspectorBioLabel.leadingAnchor constraintEqualToAnchor:bioTitle.leadingAnchor],
        [self.inspectorBioLabel.trailingAnchor constraintEqualToAnchor:bioTitle.trailingAnchor],

        [self.inspectorDateLabel.topAnchor constraintEqualToAnchor:self.inspectorBioLabel.bottomAnchor constant:12.0],
        [self.inspectorDateLabel.leadingAnchor constraintEqualToAnchor:bioTitle.leadingAnchor],
        [self.inspectorDateLabel.trailingAnchor constraintEqualToAnchor:bioTitle.trailingAnchor],
        [self.inspectorDateLabel.bottomAnchor constraintEqualToAnchor:bioCard.bottomAnchor constant:-16.0],
    ]];
    [self.inspectorDetailStack addArrangedSubview:bioCard];

    // ── Management Actions ──
    self.inspectorEditBtn = [self actionButtonWithTitle:kLang(@"Vet_Edit_Title") ?: ([Language isRTL] ? @"تعديل الملف الطبي" : @"Edit Doctor Profile")
                                                 system:@"pencil"
                                                  color:AppPrimaryClr
                                                 action:@selector(inspectorEditTapped)];
    self.inspectorSubBtn  = [self actionButtonWithTitle:kLang(@"Vet_Subscription") ?: ([Language isRTL] ? @"إدارة الاشتراك" : @"Manage Subscription")
                                                 system:@"creditcard.circle"
                                                  color:AppPrimaryClr
                                                 action:@selector(inspectorSubTapped)];
    self.inspectorToggleBtn = [self actionButtonWithTitle:kLang(@"Vet_Action_Disable") ?: ([Language isRTL] ? @"تعطيل / تفعيل الملف" : @"Toggle Status")
                                                   system:@"arrow.triangle.2.circlepath"
                                                    color:SeconderyTextClr
                                                   action:@selector(inspectorToggleTapped)];
    self.inspectorDeleteBtn = [self actionButtonWithTitle:kLang(@"Delete") ?: ([Language isRTL] ? @"حذف الطبيب" : @"Delete Profile")
                                                   system:@"trash"
                                                    color:[UIColor ppError]
                                                   action:@selector(inspectorDeleteTapped)];

    [self.inspectorDetailStack addArrangedSubview:self.inspectorEditBtn];
    [self.inspectorDetailStack addArrangedSubview:self.inspectorSubBtn];
    [self.inspectorDetailStack addArrangedSubview:self.inspectorToggleBtn];
    [self.inspectorDetailStack addArrangedSubview:self.inspectorDeleteBtn];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title system:(NSString *)systemName color:(UIColor *)color action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [color colorWithAlphaComponent:0.08];
    btn.tintColor = color;
    PPApplyContinuousCorners(btn, PPCornerButton);
    UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    [btn setImage:[UIImage systemImageNamed:systemName withConfiguration:symCfg] forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    btn.titleLabel.font = [Styling fontBold:14.0];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:46.0].active = YES;
    if (@available(iOS 13.4, *)) {
        [btn addInteraction:[[UIPointerInteraction alloc] initWithDelegate:nil]];
    }
    return btn;
}

- (void)updateInspectorWithVet:(PPVetModel *)vet {
    if (!vet) {
        self.inspectorEmptyState.hidden = NO;
        self.inspectorDetailStack.superview.hidden = YES;
        return;
    }
    self.inspectorEmptyState.hidden = YES;
    self.inspectorDetailStack.superview.hidden = NO;

    self.inspectorNameLabel.text = vet.title.length ? vet.title : ([Language isRTL] ? @"طبيب بيطري معتمد" : @"Licensed Veterinarian");
    if (vet.logoURL.length > 0) {
        [self.inspectorAvatar setImageFromUrl:vet.logoURL placeholderImage:@"veterinary" Blr:YES Shimmering:YES completion:nil];
    } else {
        self.inspectorAvatar.image = [UIImage systemImageNamed:@"stethoscope.circle.fill"];
        self.inspectorAvatar.tintColor = AppPrimaryClr;
    }

    NSString *typeName = [vet localizedTypeName];
    self.inspectorTypeBadge.text = typeName.length ? [NSString stringWithFormat:@"  %@  ", typeName] : ([Language isRTL] ? @"  طبيب شخصي معتمد  " : @"  Specialist  ");

    if (vet.vetCost > 0) {
        self.inspectorFeeBadge.text = [NSString stringWithFormat:@"  %.0f %@  ", vet.vetCost, [Language isRTL] ? @"ر.ق" : @"QAR"];
        self.inspectorFeeBadge.textColor = AppPrimaryClr;
        self.inspectorFeeBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    } else {
        self.inspectorFeeBadge.text = [Language isRTL] ? @"  استشارة مجانية  " : @"  Free Consult  ";
        self.inspectorFeeBadge.textColor = [UIColor ppSuccess];
        self.inspectorFeeBadge.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
    }

    self.inspectorBioLabel.text = vet.descriptionText.length ? vet.descriptionText : ([Language isRTL] ? @"متوفر للاستشارات والفحوصات الطبية المعتمدة للحيوانات الأليفة" : @"Available for veterinary consultations & pet care");

    BOOL disabled = vet.isDisabled;
    if (disabled) {
        self.inspectorStatusBadge.text = [Language isRTL] ? @"  ● معطل  " : @"  ● Disabled  ";
        self.inspectorStatusBadge.textColor = [UIColor ppError];
        self.inspectorStatusBadge.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.10];
        [self.inspectorToggleBtn setTitle:[NSString stringWithFormat:@"  %@", kLang(@"Vet_Action_Enable") ?: ([Language isRTL] ? @"تفعيل الملف الطبي" : @"Enable Doctor Profile")] forState:UIControlStateNormal];
        [self.inspectorToggleBtn setTitleColor:[UIColor ppSuccess] forState:UIControlStateNormal];
        self.inspectorToggleBtn.tintColor = [UIColor ppSuccess];
    } else {
        self.inspectorStatusBadge.text = [Language isRTL] ? @"  ● نشط ومعتمد  " : @"  ● Active & Verified  ";
        self.inspectorStatusBadge.textColor = [UIColor ppSuccess];
        self.inspectorStatusBadge.backgroundColor = [[UIColor ppSuccess] colorWithAlphaComponent:0.12];
        [self.inspectorToggleBtn setTitle:[NSString stringWithFormat:@"  %@", kLang(@"Vet_Action_Disable") ?: ([Language isRTL] ? @"تعطيل الملف الطبي" : @"Disable Doctor Profile")] forState:UIControlStateNormal];
        [self.inspectorToggleBtn setTitleColor:SeconderyTextClr forState:UIControlStateNormal];
        self.inspectorToggleBtn.tintColor = SeconderyTextClr;
    }

    self.inspectorCallBtn.hidden = (vet.phone.length == 0);
    self.inspectorWABtn.hidden = (vet.whatsapp.length == 0);

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    NSString *dateStr = vet.availableDate ? [df stringFromDate:vet.availableDate] : ([Language isRTL] ? @"متاح الآن" : @"Available Now");
    self.inspectorDateLabel.text = [NSString stringWithFormat:@"%@: %@", [Language isRTL] ? @"📅 موعد التوفر" : @"📅 Availability", dateStr];
}

#pragma mark - Inspector Actions

- (void)inspectorCallTapped {
    if (!self.selectedVet.phone.length) return;
    [PPFunc pp_playTapEffect];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tel://" stringByAppendingString:self.selectedVet.phone]] options:@{} completionHandler:nil];
}

- (void)inspectorWATapped {
    if (!self.selectedVet.whatsapp.length) return;
    [PPFunc pp_playTapEffect];
    NSString *clean = [self.selectedVet.whatsapp stringByReplacingOccurrencesOfString:@"+" withString:@""];
    clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *urlStr = [NSString stringWithFormat:@"https://wa.me/%@", clean];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr] options:@{} completionHandler:nil];
}

- (void)inspectorEditTapped {
    if (self.selectedVet) [self editVet:self.selectedVet];
}

- (void)inspectorSubTapped {
    if (self.selectedVet) [self manageSubscriptionForVet:self.selectedVet];
}

- (void)inspectorToggleTapped {
    if (self.selectedVet) [self toggleDisabledForVet:self.selectedVet];
}

- (void)inspectorDeleteTapped {
    if (self.selectedVet) [self deleteVetForVet:self.selectedVet];
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
    [self.masterContainer addSubview:_emptyContainer];

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

    UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
    retry.translatesAutoresizingMaskIntoConstraints = NO;
    retry.hidden = YES;
    [retry setTitle:kLang(@"Vet_Roster_Retry") forState:UIControlStateNormal];
    retry.titleLabel.font = [Styling fontBold:14.0];
    retry.tintColor = AppPrimaryClr;
    retry.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(retry, 14.0);
    retry.accessibilityLabel = kLang(@"Vet_Roster_Retry");
    [retry addTarget:self action:@selector(retryVetLoadTapped) forControlEvents:UIControlEventTouchUpInside];
    [_emptyContainer addSubview:retry];
    self.emptyRetryButton = retry;
    self.emptyNormalBottomConstraint = [rule.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor];
    self.emptyRetryBottomConstraint = [retry.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor];
    self.emptyRetryBottomConstraint.active = NO;

    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingIndicator.color = AppPrimaryClr;
    _loadingIndicator.hidesWhenStopped = YES;
    [_emptyContainer addSubview:_loadingIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyContainer.centerXAnchor constraintEqualToAnchor:self.masterContainer.centerXAnchor],
        [_emptyContainer.centerYAnchor constraintEqualToAnchor:self.masterContainer.centerYAnchor],
        [_emptyContainer.leadingAnchor constraintEqualToAnchor:self.masterContainer.leadingAnchor constant:PPSpaceXXL],
        [_emptyContainer.trailingAnchor constraintEqualToAnchor:self.masterContainer.trailingAnchor constant:-PPSpaceXXL],

        [headline.topAnchor constraintEqualToAnchor:_emptyContainer.topAnchor],
        [headline.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [headline.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],

        [rule.topAnchor constraintEqualToAnchor:headline.bottomAnchor constant:18],
        [rule.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [rule.widthAnchor constraintEqualToConstant:42],
        [rule.heightAnchor constraintEqualToConstant:PPSpaceXXS],
        self.emptyNormalBottomConstraint,

        [retry.topAnchor constraintEqualToAnchor:rule.bottomAnchor constant:14.0],
        [retry.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [retry.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [retry.widthAnchor constraintGreaterThanOrEqualToConstant:136.0],

        [_loadingIndicator.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [_loadingIndicator.centerYAnchor constraintEqualToAnchor:_emptyContainer.centerYAnchor],
    ]];
}

- (void)retryVetLoadTapped {
    [self.listener remove];
    self.listener = nil;
    self.emptyRetryButton.hidden = YES;
    self.emptyRetryBottomConstraint.active = NO;
    self.emptyNormalBottomConstraint.active = YES;
    [self startListening];
}

- (void)pp_setVetsLoading:(BOOL)loading {
    _isLoadingVets = loading;
    self.emptyHeadline.hidden = loading;
    self.emptyRule.hidden = loading;
    if (loading) {
        self.emptyRetryButton.hidden = YES;
        self.emptyRetryBottomConstraint.active = NO;
        self.emptyNormalBottomConstraint.active = YES;
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
        if (error) {
            [weakSelf pp_setVetsLoading:NO];
            weakSelf.emptyHeadline.text = kLang(@"Vet_Roster_Load_Error");
            weakSelf.emptyNormalBottomConstraint.active = NO;
            weakSelf.emptyRetryBottomConstraint.active = YES;
            weakSelf.emptyRetryButton.hidden = NO;
            weakSelf.emptyContainer.hidden = NO;
            weakSelf.tableView.hidden = YES;
            DLog(@"[VetsList] listener error: %@", error.localizedDescription);
            return;
        }
        weakSelf.emptyHeadline.text = kLang(@"Vet_Empty_List");
        weakSelf.emptyRetryButton.hidden = YES;
        weakSelf.emptyRetryBottomConstraint.active = NO;
        weakSelf.emptyNormalBottomConstraint.active = YES;
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

    self.metaLabel.text = total == 0 ? kLang(@"Vet_Roster_Empty_Summary")
        : [NSString stringWithFormat:kLang(@"Vet_Roster_Summary_Format"), (long)total, (long)active];
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
    self.emptyHeadline.hidden = self.isLoadingVets;
    self.emptyRule.hidden     = self.isLoadingVets;

    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isRegularWidth = isPad && (self.view.bounds.size.width >= 720.0);
    if (isRegularWidth) {
        if (self.selectedVet) {
            PPVetModel *match = nil;
            for (PPVetModel *v in self.filteredVets) {
                if ([v.vetID isEqualToString:self.selectedVet.vetID]) { match = v; break; }
            }
            self.selectedVet = match ?: self.filteredVets.firstObject;
        } else {
            self.selectedVet = self.filteredVets.firstObject;
        }
        [self updateInspectorWithVet:self.selectedVet];
    }

    if (!self.didPlayEntrance && self.filteredVets.count > 0) {
        self.didPlayEntrance = YES;
        [self playCellEntranceAnimation];
    }
}

- (PPVetModel *)vetAtIndexPath:(NSIndexPath *)ip {
    if (!ip || ip.row >= (NSInteger)self.filteredVets.count) return nil;
    return self.filteredVets[ip.row];
}

#pragma mark - Motion (one quiet transition, no scroll-time replay)

- (void)playCellEntranceAnimation {
    // A roster should be ready to act on immediately. Animate only the first
    // arrival, not every cell reuse or scroll, and honor Reduce Motion.
    if (PPMotionReduced() || UIAccessibilityIsReduceMotionEnabled()) return;
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        cell.alpha = 0.0;
        PPAnimateRespectingMotion(PPAnimDurationNormal, ^{
            cell.alpha = 1.0;
        }, nil);
    }
}

#pragma mark - Actions

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
    [self editVet:vet];
}

- (void)editVet:(PPVetModel *)vet {
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
    [self toggleDisabledForVet:vet];
}

- (void)toggleDisabledForVet:(PPVetModel *)vet {
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
                vet.isDisabled = newState;
                if ([weakSelf.selectedVet.vetID isEqualToString:vet.vetID]) {
                    [weakSelf updateInspectorWithVet:vet];
                }
                [weakSelf.tableView reloadData];
            }
        }];
    } cancelBlock:nil];
}

- (void)deleteVetAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    [self deleteVetForVet:vet];
}

- (void)deleteVetForVet:(PPVetModel *)vet {
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
                if ([weakSelf.selectedVet.vetID isEqualToString:vet.vetID]) {
                    weakSelf.selectedVet = nil;
                    [weakSelf updateInspectorWithVet:nil];
                }
            }
        }];
    } cancelBlock:nil];
}

- (void)manageSubscriptionAtIndexPath:(NSIndexPath *)ip {
    PPVetModel *vet = [self vetAtIndexPath:ip];
    [self manageSubscriptionForVet:vet];
}

- (void)manageSubscriptionForVet:(PPVetModel *)vet {
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
    cell.canManageStatus = [self pp_canManageVetWorkspace];
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;

    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isRegular = isPad && (self.view.bounds.size.width >= 720.0);
    if (isRegular && vet && self.selectedVet) {
        [cell setSplitSelected:[vet.vetID isEqualToString:self.selectedVet.vetID] animated:NO];
    } else {
        [cell setSplitSelected:NO animated:NO];
    }

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
        [weakSelf toggleDisabledForVet:v];
    };
    cell.onOpenTapped = ^(PPVetModel *v) {
        if (isRegular) {
            weakSelf.selectedVet = v;
            [weakSelf updateInspectorWithVet:v];
            [weakSelf.tableView reloadData];
        } else {
            PPVetDetailViewController *detail = [[PPVetDetailViewController alloc] initWithVet:v];
            [weakSelf.navigationController pushViewController:detail animated:YES];
        }
    };

    cell.isAccessibilityElement = NO;
    cell.accessibilityTraits = UIAccessibilityTraitNone;
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
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    BOOL isRegular = isPad && (self.view.bounds.size.width >= 720.0);

    PPVetModel *vet = [self vetAtIndexPath:indexPath];
    if (!vet) return;

    if (isRegular) {
        [PPFunc pp_playTapEffect];
        self.selectedVet = vet;
        [self updateInspectorWithVet:vet];
        [self.tableView reloadData];
    } else {
        [self viewVetAtIndexPath:indexPath];
    }
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
    editAction.accessibilityLabel = kLang(@"Vet_Edit_Title");

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
    deleteAction.accessibilityLabel = kLang(@"Delete");
    if (![self pp_canManageVetWorkspace]) return nil;
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Cells remain immediately readable while scrolling or refreshing.
    cell.alpha = 1.0;
    cell.transform = CGAffineTransformIdentity;
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
        [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow
                            modifierFlags:0
                                   action:@selector(selectPreviousVet)
                     discoverabilityTitle:[Language isRTL] ? @"الطبيب السابق" : @"Previous Vet"],
        [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow
                            modifierFlags:0
                                   action:@selector(selectNextVet)
                     discoverabilityTitle:[Language isRTL] ? @"الطبيب التالي" : @"Next Vet"],
        [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                            modifierFlags:0
                                   action:@selector(handleEscapeKey)
                     discoverabilityTitle:[Language isRTL] ? @"رجوع" : @"Back"]
    ];
}

- (void)selectPreviousVet {
    if (self.filteredVets.count == 0) return;
    NSInteger currentIdx = [self.filteredVets indexOfObject:self.selectedVet];
    if (currentIdx == NSNotFound || currentIdx <= 0) return;
    self.selectedVet = self.filteredVets[currentIdx - 1];
    [self updateInspectorWithVet:self.selectedVet];
    [self.tableView reloadData];
    NSIndexPath *ip = [NSIndexPath indexPathForRow:currentIdx - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)selectNextVet {
    if (self.filteredVets.count == 0) return;
    NSInteger currentIdx = [self.filteredVets indexOfObject:self.selectedVet];
    if (currentIdx == NSNotFound) {
        self.selectedVet = self.filteredVets.firstObject;
    } else if (currentIdx + 1 < (NSInteger)self.filteredVets.count) {
        self.selectedVet = self.filteredVets[currentIdx + 1];
    } else {
        return;
    }
    [self updateInspectorWithVet:self.selectedVet];
    [self.tableView reloadData];
    NSInteger newIdx = [self.filteredVets indexOfObject:self.selectedVet];
    NSIndexPath *ip = [NSIndexPath indexPathForRow:newIdx inSection:0];
    [self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)focusSearchField {
    [self.searchView.textField becomeFirstResponder];
}

- (void)handleEscapeKey {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
