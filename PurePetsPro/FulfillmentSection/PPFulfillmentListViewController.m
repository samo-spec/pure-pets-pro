#import "PPFulfillmentListViewController.h"
#import "PPFulfillmentDetailViewController.h"
#import "PPFulfillmentModel.h"
#import "PPFulfillmentManager.h"
#import "PPFulfillmentCell.h"
#import "PPFirebaseCompat.h"
#import "PPProviderCompaniesBottomSearchBar.h"
#import "Lottie.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static const CGFloat PPBottomSearchParkedInset = 16.0;

@interface PPFulfillmentListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *liveBackgroundView;
@property (nonatomic, strong) CAGradientLayer *liveGlowTopLayer;
@property (nonatomic, strong) CAGradientLayer *liveGlowMidLayer;
@property (nonatomic, strong) CAGradientLayer *liveGlowBottomLayer;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) PPHero *headerSurfaceView;
@property (nonatomic, strong) UIView *headerGlyphView;
@property (nonatomic, strong) UIImageView *headerPackageFallbackImageView;
@property (nonatomic, strong) LOTAnimationView *headerPackageAnimationView;
@property (nonatomic, copy) NSArray<UIView *> *headerMotionViews;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *activeValueLabel;
@property (nonatomic, strong) UILabel *netValueLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyContainer;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, assign) NSUInteger listenerGeneration;
@property (nonatomic, copy) NSString *listenerUID;
@property (nonatomic, copy) NSArray<PPFulfillmentModel *> *fulfillments;
@property (nonatomic, copy) NSArray<PPFulfillmentModel *> *filteredFulfillments;
@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, strong) PPProviderCompaniesBottomSearchBar *bottomSearchBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, strong) UIView *bottomSearchFadeView;
@property (nonatomic, strong) CAGradientLayer *bottomSearchFadeLayer;
@property (nonatomic, strong) UIControl *keyboardDismissOverlay;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, assign) BOOL didAnimateHeader;
@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@end

@implementation PPFulfillmentListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.hasLoaded = NO;
    self.fulfillments = @[];
    self.filteredFulfillments = @[];
    self.searchQuery = @"";

    [self buildLiveBackground];
    [self buildHeader];
    [self buildTableView];
    [self buildEmptyState];
    [self buildLoadingState];
    [self buildBottomSearchBar];
    [self startListening];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
    self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Fulfillment_Title") showBack:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runHeaderEntranceIfNeeded];
    [self startLiveBackgroundMotion];
    [self startHeaderAmbientMotion];
    [self updateHeaderPackageAnimationPlayback];
    if (!self.bottomSearchBar.hidden) {
        [self.bottomSearchBar animateInIfNeeded];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopHeaderAmbientMotion];
    [self stopLiveBackgroundMotion];
    [self.headerPackageAnimationView pause];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.liveGlowTopLayer.frame = CGRectMake(-96.0, -90.0, 300.0, 300.0);
    self.liveGlowMidLayer.frame = CGRectMake(CGRectGetWidth(self.liveBackgroundView.bounds) - 230.0, 112.0, 310.0, 310.0);
    self.liveGlowBottomLayer.frame = CGRectMake(30.0, CGRectGetHeight(self.liveBackgroundView.bounds) - 260.0, 280.0, 280.0);
    self.liveGlowTopLayer.cornerRadius = CGRectGetWidth(self.liveGlowTopLayer.bounds) * 0.5;
    self.liveGlowMidLayer.cornerRadius = CGRectGetWidth(self.liveGlowMidLayer.bounds) * 0.5;
    self.liveGlowBottomLayer.cornerRadius = CGRectGetWidth(self.liveGlowBottomLayer.bounds) * 0.5;
    self.bottomSearchFadeLayer.frame = self.bottomSearchFadeView.bounds;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateLiveBackgroundGlowStyle];
    [self updateBottomSearchFadeStyle];
    [self.bottomSearchBar applyCurrentTheme];
}

#pragma mark - View Building

- (void)buildLiveBackground {
    _liveBackgroundView = [[UIView alloc] init];
    _liveBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBackgroundView.userInteractionEnabled = NO;
    _liveBackgroundView.clipsToBounds = YES;
    [self.view insertSubview:_liveBackgroundView atIndex:0];

    _liveGlowTopLayer = [self liveGlowLayerNamed:@"PPProFulfillmentListTopGlow"];
    _liveGlowMidLayer = [self liveGlowLayerNamed:@"PPProFulfillmentListMidGlow"];
    _liveGlowBottomLayer = [self liveGlowLayerNamed:@"PPProFulfillmentListBottomGlow"];
    [_liveBackgroundView.layer addSublayer:_liveGlowTopLayer];
    [_liveBackgroundView.layer addSublayer:_liveGlowMidLayer];
    [_liveBackgroundView.layer addSublayer:_liveGlowBottomLayer];

    [NSLayoutConstraint activateConstraints:@[
        [_liveBackgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_liveBackgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_liveBackgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_liveBackgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self updateLiveBackgroundGlowStyle];
}

- (CAGradientLayer *)liveGlowLayerNamed:(NSString *)name {
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.name = name;
    layer.startPoint = CGPointMake(0.18, 0.16);
    layer.endPoint = CGPointMake(0.90, 0.90);
    layer.locations = @[@0.0, @0.42, @1.0];
    layer.opacity = 1.0;
    layer.masksToBounds = YES;
    if (@available(iOS 12.0, *)) {
        layer.type = kCAGradientLayerRadial;
    }
    return layer;
}

- (void)updateLiveBackgroundGlowStyle {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *champagne = [UIColor ppPremiumAccent];
    UIColor *opal = [UIColor ppQuickActionServices];
    UIColor *rose = [UIColor ppDiscount];
    CGFloat alpha = isDark ? 0.22 : 0.18;

    self.liveGlowTopLayer.colors = @[
        (id)[champagne colorWithAlphaComponent:alpha].CGColor,
        (id)[champagne colorWithAlphaComponent:alpha].CGColor,
        (id)[champagne colorWithAlphaComponent:alpha].CGColor
    ];
    self.liveGlowMidLayer.colors = @[
        (id)[opal colorWithAlphaComponent:alpha * 0.92].CGColor,
        (id)[opal colorWithAlphaComponent:alpha * 0.92].CGColor,
        (id)[opal colorWithAlphaComponent:alpha * 0.92].CGColor
    ];
    self.liveGlowBottomLayer.colors = @[
        (id)[rose colorWithAlphaComponent:alpha * 0.78].CGColor,
        (id)[rose colorWithAlphaComponent:alpha * 0.78].CGColor,
        (id)[rose colorWithAlphaComponent:alpha * 0.78].CGColor
    ];
}

- (void)buildHeader {
     _headerView = [[UIView alloc] init];
     _headerView.translatesAutoresizingMaskIntoConstraints = NO;
     [self.view addSubview:_headerView];

     _headerSurfaceView = [[PPHero alloc] init];
     _headerSurfaceView.accentColor = AppPrimaryClr;
     _headerSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
     [_headerView addSubview:_headerSurfaceView];

    UIView *inkLine = [[UIView alloc] init];
    inkLine.backgroundColor = AppPrimaryClr;
    inkLine.layer.cornerRadius = 2.0;
    inkLine.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerSurfaceView addSubview:inkLine];

    _eyebrowLabel = [self labelWithFont:[Styling fontBold:12] color:AppPrimaryClr lines:1];
    _eyebrowLabel.text = kLang(@"Fulfillment_ListEyebrow");
    [_headerSurfaceView addSubview:_eyebrowLabel];

    _headlineLabel = [self labelWithFont:[Styling fontBold:34] color:PrimaryTextClr lines:2];
    _headlineLabel.text = kLang(@"Fulfillment_ListHeadline");
    _headlineLabel.adjustsFontSizeToFitWidth = YES;
    _headlineLabel.minimumScaleFactor = 0.82;
    [_headerSurfaceView addSubview:_headlineLabel];

    _subtitleLabel = [self labelWithFont:[Styling fontRegular:14] color:SeconderyTextClr lines:2];
    _subtitleLabel.text = kLang(@"Fulfillment_ListSubtitle");
    [_headerSurfaceView addSubview:_subtitleLabel];

    _headerGlyphView = [[UIView alloc] init];
    _headerGlyphView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.11];
    _headerGlyphView.layer.cornerRadius = 22;
    _headerGlyphView.layer.cornerCurve = kCACornerCurveContinuous;
    _headerGlyphView.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerSurfaceView addSubview:_headerGlyphView];

    _headerPackageFallbackImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill"]];
    _headerPackageFallbackImageView.tintColor = AppPrimaryClr;
    _headerPackageFallbackImageView.contentMode = UIViewContentModeScaleAspectFit;
    _headerPackageFallbackImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerGlyphView addSubview:_headerPackageFallbackImageView];

    _headerPackageAnimationView = [[LOTAnimationView alloc] initWithFrame:CGRectZero];
    _headerPackageAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    _headerPackageAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    _headerPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
    _headerPackageAnimationView.animationSpeed = 0.72;
    _headerPackageAnimationView.alpha = 0.0;
    _headerPackageAnimationView.userInteractionEnabled = NO;
    _headerPackageAnimationView.isAccessibilityElement = NO;
    [_headerGlyphView addSubview:_headerPackageAnimationView];

UIStackView *summaryStack = [[UIStackView alloc] init];
      summaryStack.axis = UILayoutConstraintAxisHorizontal;
      summaryStack.spacing = 1;
      summaryStack.distribution = UIStackViewDistributionFillEqually;
      summaryStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
      summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
      [_headerSurfaceView addSubview:summaryStack];

    UIView *activeMetric = [self metricViewWithTitle:kLang(@"Fulfillment_Active") value:@"0"];
    _activeValueLabel = (UILabel *)[activeMetric viewWithTag:771];
    UIView *netMetric = [self metricViewWithTitle:kLang(@"Fulfillment_NetDue") value:@"0 QAR"];
    _netValueLabel = (UILabel *)[netMetric viewWithTag:771];
    [summaryStack addArrangedSubview:activeMetric];
    [summaryStack addArrangedSubview:netMetric];

    [NSLayoutConstraint activateConstraints:@[
        [_headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],

        [_headerSurfaceView.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor],
        [_headerSurfaceView.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor],
        [_headerSurfaceView.topAnchor constraintEqualToAnchor:_headerView.topAnchor],
        [_headerSurfaceView.bottomAnchor constraintEqualToAnchor:_headerView.bottomAnchor],

        [inkLine.leadingAnchor constraintEqualToAnchor:_headerSurfaceView.leadingAnchor constant:18],
        [inkLine.topAnchor constraintEqualToAnchor:_headerSurfaceView.topAnchor constant:18],
        [inkLine.widthAnchor constraintEqualToConstant:42],
        [inkLine.heightAnchor constraintEqualToConstant:4],

        [_headerGlyphView.trailingAnchor constraintEqualToAnchor:_headerSurfaceView.trailingAnchor constant:-18],
        [_headerGlyphView.topAnchor constraintEqualToAnchor:_headerSurfaceView.topAnchor constant:18],
        [_headerGlyphView.widthAnchor constraintEqualToConstant:44],
        [_headerGlyphView.heightAnchor constraintEqualToConstant:44],
        [_headerPackageFallbackImageView.centerXAnchor constraintEqualToAnchor:_headerGlyphView.centerXAnchor],
        [_headerPackageFallbackImageView.centerYAnchor constraintEqualToAnchor:_headerGlyphView.centerYAnchor],
        [_headerPackageFallbackImageView.widthAnchor constraintEqualToConstant:21],
        [_headerPackageFallbackImageView.heightAnchor constraintEqualToConstant:21],
        [_headerPackageAnimationView.centerXAnchor constraintEqualToAnchor:_headerGlyphView.centerXAnchor],
        [_headerPackageAnimationView.centerYAnchor constraintEqualToAnchor:_headerGlyphView.centerYAnchor],
        [_headerPackageAnimationView.widthAnchor constraintEqualToConstant:74],
        [_headerPackageAnimationView.heightAnchor constraintEqualToConstant:74],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_headerSurfaceView.leadingAnchor constant:18],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_headerGlyphView.leadingAnchor constant:-12],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:inkLine.bottomAnchor constant:16],

        [_headlineLabel.leadingAnchor constraintEqualToAnchor:_headerSurfaceView.leadingAnchor constant:18],
        [_headlineLabel.trailingAnchor constraintEqualToAnchor:_headerSurfaceView.trailingAnchor constant:-18],
        [_headlineLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:4],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_headerSurfaceView.leadingAnchor constant:18],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_headerSurfaceView.trailingAnchor constant:-18],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_headlineLabel.bottomAnchor constant:8],

        [summaryStack.leadingAnchor constraintEqualToAnchor:_headerSurfaceView.leadingAnchor constant:14],
        [summaryStack.trailingAnchor constraintEqualToAnchor:_headerSurfaceView.trailingAnchor constant:-14],
        [summaryStack.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:20],
        [summaryStack.bottomAnchor constraintEqualToAnchor:_headerSurfaceView.bottomAnchor constant:-14],
        [summaryStack.heightAnchor constraintEqualToConstant:76],
    ]];

    self.headerMotionViews = @[_headerSurfaceView, inkLine, _eyebrowLabel, _headlineLabel, _subtitleLabel, summaryStack, _headerGlyphView];
    [self prepareHeaderInitialMotionState];
    [self loadHeaderPackageAnimation];
}

- (void)buildTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.contentInset = UIEdgeInsetsMake(14, 0, 126, 0);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(14, 0, 126, 0);
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:[PPFulfillmentCell class] forCellReuseIdentifier:[PPFulfillmentCell reuseIdentifier]];
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(refreshPulled:) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor constant:10],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)buildLoadingState {
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color = AppPrimaryClr;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_spinner];

    [NSLayoutConstraint activateConstraints:@[
        [_spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_spinner.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-24],
    ]];
}

- (void)buildBottomSearchBar {
    self.bottomSearchFadeView = [[UIView alloc] init];
    self.bottomSearchFadeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchFadeView.userInteractionEnabled = NO;
    self.bottomSearchFadeView.hidden = YES;
    [self.view addSubview:self.bottomSearchFadeView];

    self.bottomSearchFadeLayer = [CAGradientLayer layer];
    self.bottomSearchFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.bottomSearchFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    self.bottomSearchFadeLayer.locations = @[@0.0, @0.56, @1.0];
    [self.bottomSearchFadeView.layer addSublayer:self.bottomSearchFadeLayer];

    self.bottomSearchBar = [[PPProviderCompaniesBottomSearchBar alloc] initWithPlaceholder:kLang(@"Fulfillment_BottomSearch_Placeholder")];
    self.bottomSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchBar.hidden = YES;
    __weak typeof(self) weakSelf = self;
    self.bottomSearchBar.textDidChangeHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUIAnimated:NO];
    };
    self.bottomSearchBar.submitHandler = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        self.searchQuery = text ?: @"";
        [self updateUIAnimated:NO];
    };
    [self.view addSubview:self.bottomSearchBar];
    [self installKeyboardDismissOverlay];
    self.bottomSearchBar.keyboardEditingStateHandler = ^(BOOL editing) {
        __strong typeof(weakSelf) self = weakSelf;
        self.keyboardDismissOverlay.hidden = !editing;
        self.bottomSearchFadeView.hidden = editing || self.bottomSearchBar.hidden;
    };

    self.bottomSearchBarBottomConstraint = [self.bottomSearchBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-PPBottomSearchParkedInset];
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomSearchFadeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomSearchFadeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomSearchFadeView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomSearchFadeView.heightAnchor constraintEqualToConstant:136.0],

        [self.bottomSearchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.bottomSearchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        self.bottomSearchBarBottomConstraint,
        [self.bottomSearchBar.heightAnchor constraintEqualToConstant:48.0],
    ]];
    [self.bottomSearchBar installKeyboardAvoidanceInView:self.view bottomConstraint:self.bottomSearchBarBottomConstraint];
    [self updateBottomSearchFadeStyle];
}

- (void)updateBottomSearchFadeStyle {
    UIColor *base = AppBackgroundClr;
    self.bottomSearchFadeLayer.colors = @[
        (id)[base colorWithAlphaComponent:0.0].CGColor,
        (id)[base colorWithAlphaComponent:0.78].CGColor,
        (id)[base colorWithAlphaComponent:1.0].CGColor
    ];
}

- (void)buildEmptyState {
    _emptyContainer = [[UIView alloc] init];
    _emptyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyContainer.hidden = YES;
    _emptyContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:_emptyContainer];

    UIView *iconCircle = [[UIView alloc] init];
    iconCircle.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    iconCircle.layer.cornerRadius = 26;
    iconCircle.layer.cornerCurve = kCACornerCurveContinuous;
    iconCircle.translatesAutoresizingMaskIntoConstraints = NO;
    [_emptyContainer addSubview:iconCircle];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox"]];
    iconView.tintColor = AppPrimaryClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconCircle addSubview:iconView];

    UILabel *titleLabel = [self labelWithFont:[Styling fontBold:20] color:PrimaryTextClr lines:2];
    titleLabel.text = kLang(@"Fulfillment_EmptyTitle");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [_emptyContainer addSubview:titleLabel];
    self.emptyTitleLabel = titleLabel;

    UILabel *subtitleLabel = [self labelWithFont:[Styling fontRegular:14] color:SeconderyTextClr lines:0];
    subtitleLabel.text = kLang(@"Fulfillment_EmptySubtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [_emptyContainer addSubview:subtitleLabel];
    self.emptySubtitleLabel = subtitleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [_emptyContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:38],
        [_emptyContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-38],
        [_emptyContainer.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-20],

        [iconCircle.widthAnchor constraintEqualToConstant:52],
        [iconCircle.heightAnchor constraintEqualToConstant:52],
        [iconCircle.centerXAnchor constraintEqualToAnchor:_emptyContainer.centerXAnchor],
        [iconCircle.topAnchor constraintEqualToAnchor:_emptyContainer.topAnchor],

        [iconView.centerXAnchor constraintEqualToAnchor:iconCircle.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconCircle.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24],
        [iconView.heightAnchor constraintEqualToConstant:24],

        [titleLabel.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:iconCircle.bottomAnchor constant:18],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyContainer.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyContainer.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyContainer.bottomAnchor],
    ]];
}

#pragma mark - UI Helpers

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIView *)metricViewWithTitle:(NSString *)title value:(NSString *)value {
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:20]
                                         color:PrimaryTextClr
                                         lines:1];
    valueLabel.text = value;
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.72;
    valueLabel.tag = 771;
    [view addSubview:valueLabel];

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:12]
                                         color:[SeconderyTextClr colorWithAlphaComponent:0.82]
                                         lines:1];
    titleLabel.text = title;
    [view addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14],
        [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14],
        [valueLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:13],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:14],
        [titleLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14],
        [titleLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:3],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:view.bottomAnchor constant:-12],
    ]];

    return view;
}

- (LOTComposition *)bundledPackageDeliveryComposition {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"PackageDelivery" ofType:@"json"];
    if (path.length == 0) {
        return [LOTComposition animationNamed:@"PackageDelivery"];
    }
    NSData *data = [PPFileHelper safeDataFromFile:path];
    if (data.length == 0) {
        return [LOTComposition animationNamed:@"PackageDelivery"];
    }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) {
        return [LOTComposition animationNamed:@"PackageDelivery"];
    }
    return [LOTComposition animationFromJSON:json];
}

- (void)loadHeaderPackageAnimation {
    LOTComposition *bundledComposition = [self bundledPackageDeliveryComposition];
    if (bundledComposition) {
        [self.headerPackageAnimationView setSceneModel:bundledComposition];
        self.headerPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
        self.headerPackageAnimationView.animationSpeed = 0.78;
        if (UIAccessibilityIsReduceMotionEnabled()) {
            self.headerPackageAnimationView.animationProgress = 0.48;
        }
        [UIView animateWithDuration:0.28
                              delay:0.04
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.headerPackageAnimationView.alpha = 1.0;
            self.headerPackageFallbackImageView.alpha = 0.0;
        } completion:^(__unused BOOL finished) {
            [self updateHeaderPackageAnimationPlayback];
        }];
        return;
    }

    static NSString * const storagePath = @"LottieAnimations/Package delivery.lottie";
    __weak typeof(self) weakSelf = self;
    [Styling fetchLottieJSONFromFirebasePath:storagePath
                                  completion:^(NSDictionary *jsonDict, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                return;
            }
            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                return;
            }
            [self.headerPackageAnimationView setSceneModel:composition];
            self.headerPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
            self.headerPackageAnimationView.animationSpeed = 0.78;
            if (UIAccessibilityIsReduceMotionEnabled()) {
                self.headerPackageAnimationView.animationProgress = 0.52;
            }
            [UIView animateWithDuration:0.28
                                  delay:0.04
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                self.headerPackageAnimationView.alpha = 1.0;
                self.headerPackageFallbackImageView.alpha = 0.0;
            } completion:^(__unused BOOL finished) {
                [self updateHeaderPackageAnimationPlayback];
            }];
        });
    }];
}

- (void)updateHeaderPackageAnimationPlayback {
    if (!self.headerPackageAnimationView.sceneModel || self.view.window == nil) {
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.headerPackageAnimationView.loopAnimation = NO;
        [self.headerPackageAnimationView pause];
        self.headerPackageAnimationView.animationProgress = 0.52;
        return;
    }
    self.headerPackageAnimationView.loopAnimation = YES;
    [self.headerPackageAnimationView play];
}

- (void)runHeaderEntranceIfNeeded {
    if (self.didAnimateHeader) return;
    self.didAnimateHeader = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in self.headerMotionViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [self.headerMotionViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 18);
        [UIView animateWithDuration:0.54
                              delay:0.035 * idx
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.20
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)prepareHeaderInitialMotionState {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    for (UIView *view in self.headerMotionViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 18);
    }
}

- (void)startHeaderAmbientMotion {
   
}

- (void)stopHeaderAmbientMotion {
 }

- (void)startLiveBackgroundMotion {
    if (UIAccessibilityIsReduceMotionEnabled() || !self.liveBackgroundView) {
        self.liveBackgroundView.alpha = 1.0;
        return;
    }
    if ([self.liveGlowTopLayer animationForKey:@"pp.list.live.top"]) {
        return;
    }

    self.liveBackgroundView.alpha = 0.0;
    [UIView animateWithDuration:1.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.liveBackgroundView.alpha = 1.0;
    } completion:nil];

    [self addBreathingAnimationToLayer:self.liveGlowTopLayer key:@"pp.list.live.top" x:24.0 y:20.0 scale:1.07 duration:8.2 delay:0.0];
    [self addBreathingAnimationToLayer:self.liveGlowMidLayer key:@"pp.list.live.mid" x:-22.0 y:18.0 scale:1.06 duration:9.4 delay:0.3];
    [self addBreathingAnimationToLayer:self.liveGlowBottomLayer key:@"pp.list.live.bottom" x:18.0 y:-22.0 scale:1.05 duration:10.6 delay:0.1];
}

- (void)addBreathingAnimationToLayer:(CALayer *)layer
                                 key:(NSString *)key
                                   x:(CGFloat)x
                                   y:(CGFloat)y
                               scale:(CGFloat)scale
                            duration:(CFTimeInterval)duration
                               delay:(CFTimeInterval)delay {
    if (!layer || key.length == 0) return;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    CATransform3D start = CATransform3DIdentity;
    CATransform3D middle = CATransform3DScale(CATransform3DMakeTranslation(x, y, 0.0), scale, scale, 1.0);
    animation.values = @[[NSValue valueWithCATransform3D:start], [NSValue valueWithCATransform3D:middle], [NSValue valueWithCATransform3D:start]];
    animation.keyTimes = @[@0.0, @0.52, @1.0];
    animation.duration = duration;
    animation.beginTime = CACurrentMediaTime() + delay;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ];
    [layer addAnimation:animation forKey:key];
}

- (void)stopLiveBackgroundMotion {
    [self.liveGlowTopLayer removeAnimationForKey:@"pp.list.live.top"];
    [self.liveGlowMidLayer removeAnimationForKey:@"pp.list.live.mid"];
    [self.liveGlowBottomLayer removeAnimationForKey:@"pp.list.live.bottom"];
}

- (NSString *)moneyString:(double)value currency:(NSString *)currency {
    return [NSString stringWithFormat:@"%.0f %@", value, currency.length > 0 ? currency : @"QAR"];
}

#pragma mark - Data

- (void)startListening {
    [self.listener remove];
    self.listener = nil;
    NSUInteger generation = ++self.listenerGeneration;
    NSString *uid = [[FIRAuth auth].currentUser.uid ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.listenerUID = uid;
    if (uid.length == 0) {
        self.fulfillments = @[];
        self.hasLoaded = YES;
        [self updateUIAnimated:NO];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.spinner startAnimating];
    self.listener = [[PPFulfillmentManager sharedManager] observeFulfillmentsForOwnerID:uid onChange:^(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.listenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid] || ![self.listenerUID isEqualToString:uid]) return;
        [self.spinner stopAnimating];
        [self.refreshControl endRefreshing];
        self.hasLoaded = YES;
        if (error) {
            self.fulfillments = self.fulfillments ?: @[];
            [self updateUIAnimated:YES];
            [PPToast toast:kLang(@"Fulfillment_LoadError") style:PPToastStyleError haptic:NO duration:3.0];
            return;
        }
        self.fulfillments = fulfillments ?: @[];
        [self updateUIAnimated:YES];
    }];
}

- (void)refreshPulled:(UIRefreshControl *)refreshControl {
    [self refreshFilteredFulfillments];
    [self.tableView reloadData];
    [self updateSummary];
    [refreshControl endRefreshing];
}

- (void)updateUIAnimated:(BOOL)animated {
    [self refreshFilteredFulfillments];
    [self updateSummary];
    BOOL hasSearch = [self hasActiveSearchQuery];
    BOOL sourceEmpty = self.fulfillments.count == 0;
    BOOL displayEmpty = self.filteredFulfillments.count == 0;
    self.emptyContainer.hidden = !(self.hasLoaded && (sourceEmpty || (hasSearch && displayEmpty)));
    self.tableView.hidden = !self.hasLoaded || sourceEmpty || (hasSearch && displayEmpty);
    self.bottomSearchBar.hidden = !self.hasLoaded || sourceEmpty;
    self.bottomSearchFadeView.hidden = self.bottomSearchBar.hidden || self.bottomSearchBar.isKeyboardEditing;
    [self.bottomSearchBar setResultCount:self.filteredFulfillments.count totalCount:self.fulfillments.count];
    [self updateEmptyStateForSearch:hasSearch sourceEmpty:sourceEmpty displayEmpty:displayEmpty];
    [self.tableView reloadData];

    if (!self.bottomSearchBar.hidden) {
        [self.bottomSearchBar animateInIfNeeded];
    }

    if (animated && !self.tableView.hidden) {
        self.tableView.alpha = 0.0;
        self.tableView.transform = CGAffineTransformMakeTranslation(0, 10);
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.tableView.alpha = 1.0;
            self.tableView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)updateSummary {
    NSInteger active = 0;
    double net = 0;
    NSString *currency = @"QAR";
    for (PPFulfillmentModel *model in [self displayedFulfillments]) {
        if (!model.isTerminal) active += 1;
        net += model.providerNet;
        if (model.currency.length > 0) currency = model.currency;
    }
    self.activeValueLabel.text = [NSString stringWithFormat:@"%ld", (long)active];
    self.netValueLabel.text = [self moneyString:net currency:currency];
}

#pragma mark - Search

- (NSArray<PPFulfillmentModel *> *)displayedFulfillments {
    return self.filteredFulfillments ?: @[];
}

- (BOOL)hasActiveSearchQuery {
    return [self trimmedSearchQuery].length > 0;
}

- (NSString *)trimmedSearchQuery {
    return [self.searchQuery ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)refreshFilteredFulfillments {
    NSArray<PPFulfillmentModel *> *source = self.fulfillments ?: @[];
    NSString *query = [self trimmedSearchQuery];
    if (query.length == 0) {
        self.filteredFulfillments = source;
        return;
    }

    NSMutableArray<PPFulfillmentModel *> *matches = [NSMutableArray array];
    for (PPFulfillmentModel *model in source) {
        NSString *searchText = [self searchTextForFulfillment:model];
        if ([searchText rangeOfString:query options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location != NSNotFound) {
            [matches addObject:model];
        }
    }
    self.filteredFulfillments = matches.copy;
}

- (NSString *)searchTextForFulfillment:(PPFulfillmentModel *)model {
    if (!model) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [self appendSearchObject:model.fulfillmentID toParts:parts];
    [self appendSearchObject:model.parentOrderId toParts:parts];
    [self appendSearchObject:model.parentOrderNumber toParts:parts];
    [self appendSearchObject:model.parentUserId toParts:parts];
    [self appendSearchObject:model.ownerID toParts:parts];
    [self appendSearchObject:model.ownerType toParts:parts];
    [self appendSearchObject:model.fulfillmentMode toParts:parts];
    [self appendSearchObject:model.status toParts:parts];
    [self appendSearchObject:[model statusDisplayName] toParts:parts];
    [self appendSearchObject:model.currency toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%ld", (long)model.itemCount] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", model.subtotal] toParts:parts];
    [self appendSearchObject:[NSString stringWithFormat:@"%.0f", model.providerNet] toParts:parts];
    [self appendSearchObject:model.items toParts:parts];
    [self appendSearchObject:model.events toParts:parts];
    return [parts componentsJoinedByString:@" "];
}

- (void)appendSearchObject:(id)object toParts:(NSMutableArray<NSString *> *)parts {
    if (!object || object == (id)[NSNull null]) return;
    if ([object isKindOfClass:NSString.class]) {
        NSString *value = [(NSString *)object stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) [parts addObject:value];
        return;
    }
    if ([object isKindOfClass:NSNumber.class]) {
        [parts addObject:[(NSNumber *)object stringValue]];
        return;
    }
    if ([object isKindOfClass:NSArray.class]) {
        for (id value in (NSArray *)object) {
            [self appendSearchObject:value toParts:parts];
        }
        return;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        for (id value in [(NSDictionary *)object allValues]) {
            [self appendSearchObject:value toParts:parts];
        }
    }
}

- (void)updateEmptyStateForSearch:(BOOL)hasSearch sourceEmpty:(BOOL)sourceEmpty displayEmpty:(BOOL)displayEmpty {
    if (hasSearch && !sourceEmpty && displayEmpty) {
        self.emptyTitleLabel.text = kLang(@"Fulfillment_SearchEmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Fulfillment_SearchEmptySubtitle");
    } else {
        self.emptyTitleLabel.text = kLang(@"Fulfillment_EmptyTitle");
        self.emptySubtitleLabel.text = kLang(@"Fulfillment_EmptySubtitle");
    }
}
- (void)installKeyboardDismissOverlay {
    self.keyboardDismissOverlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.keyboardDismissOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyboardDismissOverlay.backgroundColor = UIColor.clearColor;
    self.keyboardDismissOverlay.hidden = YES;
    self.keyboardDismissOverlay.accessibilityElementsHidden = YES;
    [self.keyboardDismissOverlay addTarget:self action:@selector(dismissBottomSearchKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:self.keyboardDismissOverlay aboveSubview:self.bottomSearchBar];
    [NSLayoutConstraint activateConstraints:@[
        [self.keyboardDismissOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.keyboardDismissOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keyboardDismissOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.keyboardDismissOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)dismissBottomSearchKeyboard {
    [self.bottomSearchBar dismissKeyboard];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self displayedFulfillments].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPFulfillmentCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPFulfillmentCell reuseIdentifier] forIndexPath:indexPath];
    [cell configureWithModel:[self displayedFulfillments][indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [PPFulfillmentCell preferredHeight];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPFulfillmentModel *model = [self displayedFulfillments][indexPath.row];
    PPFulfillmentDetailViewController *vc = [[PPFulfillmentDetailViewController alloc] initWithModel:model];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    self.listenerGeneration += 1;
    [self.listener remove];
}

@end
