#import "PPFulfillmentDetailViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPMarketplaceBranchesViewController.h"
#import "PPFulfillmentModel.h"
#import "PPFulfillmentManager.h"
#import "PPFirebaseCompat.h"
#import "Lottie.h"

@interface PPFulfillmentDetailViewController ()
@property (nonatomic, strong) PPFulfillmentModel *model;
@property (nonatomic, strong) UIView *liveBackgroundView;
@property (nonatomic, strong) CAGradientLayer *liveGlowTopLayer;
@property (nonatomic, strong) CAGradientLayer *liveGlowMidLayer;
@property (nonatomic, strong) CAGradientLayer *liveGlowBottomLayer;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIView *eventsContainer;
@property (nonatomic, strong) UIView *actionBar;
@property (nonatomic, strong) UIView *moneySurfaceView;
@property (nonatomic, strong) UIVisualEffectView *moneyBlurView;
@property (nonatomic, strong) CAGradientLayer *moneySurfaceLayer;
@property (nonatomic, strong) CAGradientLayer *moneyLiquidBorderLayer;
@property (nonatomic, strong) CAGradientLayer *moneyLiquidHighlightLayer;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *heroGlyphView;
@property (nonatomic, strong) LOTAnimationView *heroPackageAnimationView;
@property (nonatomic, strong) UIImageView *heroPackageFallbackImageView;

@property (nonatomic, copy) NSArray<UIView *> *heroMotionViews;
@property (nonatomic, strong) id<FIRListenerRegistration> eventsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> fulfillmentListener;
@property (nonatomic, assign) NSUInteger fulfillmentListenerGeneration;
@property (nonatomic, assign) NSUInteger eventsListenerGeneration;
@property (nonatomic, copy) NSString *listenerUID;
@property (nonatomic, assign) BOOL hasLiveFulfillmentState;
@property (nonatomic, assign) BOOL didAnimateHero;
- (void)observeFulfillment;
- (void)refreshActionBarFromLiveFulfillment;
- (void)removeActionBar;
- (void)performCanonicalFulfillmentAction:(NSString *)action
                                     note:(NSString *)note
                               completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;
- (BOOL)isFulfillmentV1ParentOrderData:(NSDictionary *)orderData;
- (void)finishSuccessfulFulfillmentAction;
@end

@implementation PPFulfillmentDetailViewController

- (instancetype)initWithModel:(PPFulfillmentModel *)model {
    if (self = [super init]) {
        _model = model;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self buildLiveBackground];
    [self buildScrollView];
    [self buildHeroSection];
    [self buildMoneySection];
    
    [self buildMetaSection];
    [self buildItemsSection];
    [self buildEventsSection];
    [self buildActionBar];
    [self observeFulfillment];
    [self observeEvents];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reduceMotionPreferenceDidChange)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [self runEntranceMotion];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"Fulfillment_DetailTitle") showBack:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runHeroEntranceIfNeeded];
    [self startLiveBackgroundMotion];
    [self startHeroAmbientMotion];
    [self updateHeroPackageAnimationPlayback];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopHeroAmbientMotion];
    [self stopLiveBackgroundMotion];
    [self.heroPackageAnimationView pause];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.liveGlowTopLayer.frame = CGRectMake(-98.0, -90.0, 310.0, 310.0);
    self.liveGlowMidLayer.frame = CGRectMake(CGRectGetWidth(self.liveBackgroundView.bounds) - 238.0, 124.0, 320.0, 320.0);
    self.liveGlowBottomLayer.frame = CGRectMake(24.0, CGRectGetHeight(self.liveBackgroundView.bounds) - 268.0, 288.0, 288.0);
    self.liveGlowTopLayer.cornerRadius = CGRectGetWidth(self.liveGlowTopLayer.bounds) * 0.5;
    self.liveGlowMidLayer.cornerRadius = CGRectGetWidth(self.liveGlowMidLayer.bounds) * 0.5;
    self.liveGlowBottomLayer.cornerRadius = CGRectGetWidth(self.liveGlowBottomLayer.bounds) * 0.5;
    [self layoutMoneyLiquidLayers];

}

#pragma mark - View Building

- (void)buildLiveBackground {
    _liveBackgroundView = [[UIView alloc] init];
    _liveBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    _liveBackgroundView.userInteractionEnabled = NO;
    _liveBackgroundView.clipsToBounds = YES;
    [self.view insertSubview:_liveBackgroundView atIndex:0];

    _liveGlowTopLayer = [self liveGlowLayerNamed:@"PPProFulfillmentDetailTopGlow"];
    _liveGlowMidLayer = [self liveGlowLayerNamed:@"PPProFulfillmentDetailMidGlow"];
    _liveGlowBottomLayer = [self liveGlowLayerNamed:@"PPProFulfillmentDetailBottomGlow"];
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

- (void)buildScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];

    _stack = [[UIStackView alloc] init];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 16;
    _stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_stack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_stack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:22],
        [_stack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-22],
        [_stack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:14],
        [_stack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-28],
        [_stack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-44],
    ]];
}

- (void)buildHeroSection {
    UIView *hero = [[UIView alloc] init];
    hero.translatesAutoresizingMaskIntoConstraints = NO;

    _heroSurfaceView = [[PPHero alloc] init];
    _heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    [hero addSubview:_heroSurfaceView];





    UIView *statusLine = [[UIView alloc] init];
    statusLine.backgroundColor = self.model.statusColor;
    statusLine.layer.cornerRadius = 3;
    statusLine.translatesAutoresizingMaskIntoConstraints = NO;
    [_heroSurfaceView addSubview:statusLine];

    _heroGlyphView = [[UIView alloc] init];
    _heroGlyphView.backgroundColor = [self.model.statusColor colorWithAlphaComponent:0.08];
    _heroGlyphView.layer.cornerRadius = 30;
    _heroGlyphView.layer.cornerCurve = kCACornerCurveContinuous;
    _heroGlyphView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _heroGlyphView.layer.borderColor = [self.model.statusColor colorWithAlphaComponent:0.12].CGColor;
    _heroGlyphView.userInteractionEnabled = NO;
    _heroGlyphView.isAccessibilityElement = NO;
    _heroGlyphView.translatesAutoresizingMaskIntoConstraints = NO;
    [_heroSurfaceView addSubview:_heroGlyphView];

    _heroPackageFallbackImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"shippingbox.fill"]];
    _heroPackageFallbackImageView.tintColor = self.model.statusColor;
    _heroPackageFallbackImageView.contentMode = UIViewContentModeScaleAspectFit;
    _heroPackageFallbackImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_heroGlyphView addSubview:_heroPackageFallbackImageView];

    _heroPackageAnimationView = [[LOTAnimationView alloc] initWithFrame:CGRectZero];
    _heroPackageAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroPackageAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    _heroPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
    _heroPackageAnimationView.animationSpeed = 0.72;
    _heroPackageAnimationView.alpha = 0.0;
    _heroPackageAnimationView.userInteractionEnabled = NO;
    _heroPackageAnimationView.isAccessibilityElement = NO;
    [_heroGlyphView addSubview:_heroPackageAnimationView];

    UILabel *eyebrow = [self labelWithFont:[Styling fontBold:12] color:AppPrimaryClr lines:1];
    eyebrow.text = kLang(@"Fulfillment_DetailEyebrow");
    [_heroSurfaceView addSubview:eyebrow];

    UILabel *title = [self labelWithFont:[Styling fontBold:34] color:PrimaryTextClr lines:2];
    title.text = [self primaryOrderTitle];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.80;
    [_heroSurfaceView addSubview:title];

    UILabel *subtitle = [self labelWithFont:[Styling fontRegular:14] color:SeconderyTextClr lines:2];
    subtitle.text = [NSString stringWithFormat:@"%@ %@  /  %@ %@", kLang(@"Fulfillment_Items"), @(self.model.itemCount), kLang(@"Fulfillment_Reference"), [self shortID:self.model.parentOrderId length:12]];
    [_heroSurfaceView addSubview:subtitle];

    UILabel *status = [self badgeLabelWithText:[self.model statusDisplayName] color:self.model.statusColor];
    [_heroSurfaceView addSubview:status];

    [NSLayoutConstraint activateConstraints:@[
        [_heroSurfaceView.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [_heroSurfaceView.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor],
        [_heroSurfaceView.topAnchor constraintEqualToAnchor:hero.topAnchor],
        [_heroSurfaceView.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor],

        [statusLine.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [statusLine.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:18],
        [statusLine.widthAnchor constraintEqualToConstant:46],
        [statusLine.heightAnchor constraintEqualToConstant:5],

        [_heroGlyphView.trailingAnchor constraintEqualToAnchor:_heroSurfaceView.trailingAnchor constant:-18],
        [_heroGlyphView.topAnchor constraintEqualToAnchor:_heroSurfaceView.topAnchor constant:14],
        [_heroGlyphView.widthAnchor constraintEqualToConstant:108],
        [_heroGlyphView.heightAnchor constraintEqualToConstant:108],
        [_heroPackageFallbackImageView.centerXAnchor constraintEqualToAnchor:_heroGlyphView.centerXAnchor],
        [_heroPackageFallbackImageView.centerYAnchor constraintEqualToAnchor:_heroGlyphView.centerYAnchor],
        [_heroPackageFallbackImageView.widthAnchor constraintEqualToConstant:34],
        [_heroPackageFallbackImageView.heightAnchor constraintEqualToConstant:34],
        [_heroPackageAnimationView.centerXAnchor constraintEqualToAnchor:_heroGlyphView.centerXAnchor],
        [_heroPackageAnimationView.centerYAnchor constraintEqualToAnchor:_heroGlyphView.centerYAnchor],
        [_heroPackageAnimationView.widthAnchor constraintEqualToConstant:132],
        [_heroPackageAnimationView.heightAnchor constraintEqualToConstant:132],

        [eyebrow.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:_heroGlyphView.leadingAnchor constant:-12],
        [eyebrow.topAnchor constraintEqualToAnchor:statusLine.bottomAnchor constant:16],

        [title.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:_heroGlyphView.leadingAnchor constant:-10],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4],

        [subtitle.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:_heroGlyphView.leadingAnchor constant:-10],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],

        [status.leadingAnchor constraintEqualToAnchor:_heroSurfaceView.leadingAnchor constant:18],
        [status.topAnchor constraintGreaterThanOrEqualToAnchor:subtitle.bottomAnchor constant:16],
        [status.topAnchor constraintGreaterThanOrEqualToAnchor:_heroGlyphView.bottomAnchor constant:12],
        [status.bottomAnchor constraintEqualToAnchor:_heroSurfaceView.bottomAnchor constant:-18],
        [status.heightAnchor constraintEqualToConstant:30],
    ]];

    self.heroMotionViews = @[_heroSurfaceView, statusLine, eyebrow, title, subtitle, status, _heroGlyphView];
    [self prepareHeroInitialMotionState];
    [self.stack addArrangedSubview:hero];
    [self loadHeroPackageAnimation];
}

- (void)loadHeroPackageAnimation {
    LOTComposition *bundledComposition = [self bundledPackageDeliveryComposition];
    if (bundledComposition) {
        [self.heroPackageAnimationView setSceneModel:bundledComposition];
        self.heroPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
        self.heroPackageAnimationView.animationSpeed = 0.78;
        if (UIAccessibilityIsReduceMotionEnabled()) {
            self.heroPackageAnimationView.animationProgress = 0.48;
        }
        [UIView animateWithDuration:0.32
                         animations:^{
            self.heroPackageAnimationView.alpha = 1.0;
            self.heroPackageFallbackImageView.alpha = 0.0;
        } completion:^(__unused BOOL finished) {
            [self updateHeroPackageAnimationPlayback];
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

            [self.heroPackageAnimationView setSceneModel:composition];
            self.heroPackageAnimationView.loopAnimation = !UIAccessibilityIsReduceMotionEnabled();
            self.heroPackageAnimationView.animationSpeed = 0.78;
            if (UIAccessibilityIsReduceMotionEnabled()) {
                self.heroPackageAnimationView.animationProgress = 0.52;
            }

            [UIView animateWithDuration:0.32
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                self.heroPackageAnimationView.alpha = 1.0;
                self.heroPackageFallbackImageView.alpha = 0.0;
            } completion:^(__unused BOOL finished) {
                [self updateHeroPackageAnimationPlayback];
            }];
        });
    }];
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

- (void)updateHeroPackageAnimationPlayback {
    if (!self.heroPackageAnimationView.sceneModel || self.view.window == nil) {
        return;
    }
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroPackageAnimationView.loopAnimation = NO;
        [self.heroPackageAnimationView pause];
        self.heroPackageAnimationView.animationProgress = 0.52;
        return;
    }
    self.heroPackageAnimationView.loopAnimation = YES;
    [self.heroPackageAnimationView play];
}

- (void)reduceMotionPreferenceDidChange {
    [self updateHeroPackageAnimationPlayback];
}

- (void)buildMoneySection {
    UIView *surface = [[UIView alloc] init];
    surface.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.92];
    surface.layer.cornerRadius = 30;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.masksToBounds = YES;
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    self.moneySurfaceView = surface;

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        self.moneyBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        self.moneyBlurView.userInteractionEnabled = NO;
        self.moneyBlurView.translatesAutoresizingMaskIntoConstraints = NO;
        [surface addSubview:self.moneyBlurView];
        [NSLayoutConstraint activateConstraints:@[
            [self.moneyBlurView.topAnchor constraintEqualToAnchor:surface.topAnchor],
            [self.moneyBlurView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
            [self.moneyBlurView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
            [self.moneyBlurView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
        ]];
    }

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.name = @"PPProFulfillmentMoneyFill";
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    gradient.colors = @[
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.98].CGColor,
        (id)[AppForgroundColr colorWithAlphaComponent:0.86].CGColor,
        (id)[[UIColor ppMineralBeige] colorWithAlphaComponent:0.82].CGColor
    ];
    gradient.locations = @[@0.0, @0.52, @1.0];
    [surface.layer insertSublayer:gradient atIndex:self.moneyBlurView ? 1 : 0];
    self.moneySurfaceLayer = gradient;

    self.moneyLiquidBorderLayer = [CAGradientLayer layer];
    self.moneyLiquidBorderLayer.name = @"PPProFulfillmentMoneyLiquidBorder";
    self.moneyLiquidBorderLayer.startPoint = CGPointMake(0.0, 0.1);
    self.moneyLiquidBorderLayer.endPoint = CGPointMake(1.0, 0.9);
    self.moneyLiquidBorderLayer.locations = @[@0.0, @0.28, @0.52, @0.78, @1.0];
    [surface.layer addSublayer:self.moneyLiquidBorderLayer];

    self.moneyLiquidHighlightLayer = [CAGradientLayer layer];
    self.moneyLiquidHighlightLayer.name = @"PPProFulfillmentMoneyLiquidHighlight";
    self.moneyLiquidHighlightLayer.startPoint = CGPointMake(0.0, 0.0);
    self.moneyLiquidHighlightLayer.endPoint = CGPointMake(1.0, 1.0);
    self.moneyLiquidHighlightLayer.locations = @[@0.0, @0.48, @1.0];
    self.moneyLiquidHighlightLayer.opacity = 0.36;
    [surface.layer addSublayer:self.moneyLiquidHighlightLayer];

    UIView *accentLine = [[UIView alloc] init];
    accentLine.backgroundColor = [[UIColor ppPremiumAccent] colorWithAlphaComponent:0.86];
    accentLine.layer.cornerRadius = 2.5;
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:accentLine];

    UILabel *titleLabel = [self labelWithFont:[Styling fontBold:12] color:[SeconderyTextClr colorWithAlphaComponent:0.82] lines:1];
    titleLabel.text = kLang(@"Fulfillment_ProviderNet");
    [surface addSubview:titleLabel];

    UILabel *netLabel = [self labelWithFont:[Styling fontBold:36] color:[UIColor ppPremiumAccent] lines:1];
    netLabel.text = [self moneyString:self.model.providerNet];
    netLabel.adjustsFontSizeToFitWidth = YES;
    netLabel.minimumScaleFactor = 0.68;
    [surface addSubview:netLabel];

    UILabel *captionLabel = [self labelWithFont:[Styling fontRegular:12] color:[SeconderyTextClr colorWithAlphaComponent:0.72] lines:2];
    captionLabel.text = [NSString stringWithFormat:@"%@ / %@", kLang(@"Fulfillment_Subtotal"), kLang(@"Fulfillment_PlatformCommission")];
    [surface addSubview:captionLabel];

    UIStackView *bottomRow = [[UIStackView alloc] init];
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.spacing = 10;
    bottomRow.distribution = UIStackViewDistributionFillEqually;
    bottomRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    bottomRow.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:bottomRow];

    [bottomRow addArrangedSubview:[self moneyMiniMetricWithTitle:kLang(@"Fulfillment_Subtotal") value:[self moneyString:self.model.subtotal]]];
    [bottomRow addArrangedSubview:[self moneyMiniMetricWithTitle:kLang(@"Fulfillment_PlatformCommission") value:[self moneyString:self.model.platformCommission]]];

    [NSLayoutConstraint activateConstraints:@[
        [accentLine.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18],
        [accentLine.topAnchor constraintEqualToAnchor:surface.topAnchor constant:18],
        [accentLine.widthAnchor constraintEqualToConstant:44],
        [accentLine.heightAnchor constraintEqualToConstant:5],

        [titleLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:surface.trailingAnchor constant:-18],
        [titleLabel.topAnchor constraintEqualToAnchor:accentLine.bottomAnchor constant:16],

        [netLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18],
        [netLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18],
        [netLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3],

        [captionLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18],
        [captionLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18],
        [captionLabel.topAnchor constraintEqualToAnchor:netLabel.bottomAnchor constant:4],

        [bottomRow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:14],
        [bottomRow.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-14],
        [bottomRow.topAnchor constraintEqualToAnchor:captionLabel.bottomAnchor constant:18],
        [bottomRow.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-14],
        [bottomRow.heightAnchor constraintEqualToConstant:68],
    ]];
    [self layoutMoneyLiquidLayers];
    [self.stack addArrangedSubview:surface];
}

- (void)layoutMoneyLiquidLayers {
    if (!self.moneySurfaceView || CGRectIsEmpty(self.moneySurfaceView.bounds)) return;

    CGRect bounds = self.moneySurfaceView.bounds;
    CGFloat radius = self.moneySurfaceView.layer.cornerRadius;
    self.moneySurfaceLayer.frame = bounds;
    self.moneySurfaceLayer.cornerRadius = radius;
    self.moneyLiquidBorderLayer.frame = bounds;
    self.moneyLiquidHighlightLayer.frame = bounds;
    self.moneyLiquidHighlightLayer.cornerRadius = radius;

    UIColor *gold = [UIColor ppPremiumAccent];
    UIColor *mint = [UIColor ppQuickActionServices];
    self.moneyLiquidBorderLayer.colors = @[
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.10].CGColor,
        (id)[gold colorWithAlphaComponent:0.58].CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.42].CGColor,
        (id)[mint colorWithAlphaComponent:0.28].CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.08].CGColor
    ];
    self.moneyLiquidHighlightLayer.colors = @[
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.00].CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.20].CGColor,
        (id)[UIColor.whiteColor colorWithAlphaComponent:0.00].CGColor
    ];

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.65, 0.65)
                                                    cornerRadius:MAX(0.0, radius - 0.65)];
    CAShapeLayer *borderMask = [CAShapeLayer layer];
    borderMask.frame = bounds;
    borderMask.path = path.CGPath;
    borderMask.fillColor = UIColor.clearColor.CGColor;
    borderMask.strokeColor = UIColor.blackColor.CGColor;
    borderMask.lineWidth = 1.15;
    self.moneyLiquidBorderLayer.mask = borderMask;

    if (!UIAccessibilityIsReduceMotionEnabled() &&
        ![self.moneyLiquidBorderLayer animationForKey:@"pp.money.liquid.flow"]) {
        CABasicAnimation *flow = [CABasicAnimation animationWithKeyPath:@"locations"];
        flow.fromValue = @[@0.0, @0.20, @0.38, @0.62, @1.0];
        flow.toValue = @[@0.0, @0.36, @0.58, @0.82, @1.0];
        flow.duration = 7.4;
        flow.autoreverses = YES;
        flow.repeatCount = HUGE_VALF;
        flow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.moneyLiquidBorderLayer addAnimation:flow forKey:@"pp.money.liquid.flow"];
    }
}

- (void)buildMetaSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:kLang(@"Fulfillment_OrderContext")]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_OrderID") value:self.model.parentOrderId]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_CustomerID") value:[self shortID:self.model.parentUserId length:12]]];
    if (self.model.ownerID.length > 0) {
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_OwnerID") value:[self shortID:self.model.ownerID length:12]]];
    }
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_CreatedAt") value:[self mediumDateString:self.model.createdAt]]];
    [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_UpdatedAt") value:[self mediumDateString:self.model.updatedAt]]];
    if (self.model.adminOverrideReason.length > 0) {
        [content addArrangedSubview:[self detailRowWithTitle:kLang(@"Fulfillment_AdminOverride") value:self.model.adminOverrideReason]];
    }

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildItemsSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"Fulfillment_Items"), (long)self.model.items.count]]];

    if (self.model.items.count == 0) {
        UILabel *empty = [self labelWithFont:[Styling fontRegular:13] color:SeconderyTextClr lines:0];
        empty.text = kLang(@"Fulfillment_NoItems");
        [content addArrangedSubview:empty];
    } else {
        for (NSInteger i = 0; i < self.model.items.count; i++) {
            NSDictionary *item = PPSafeDict(self.model.items[i]);
            [content addArrangedSubview:[self itemRow:item index:i]];
        }
    }

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildEventsSection {
    UIView *section = [self sectionSurface];
    UIStackView *content = [self verticalStackWithSpacing:12];
    [section addSubview:content];

    [content addArrangedSubview:[self sectionTitle:kLang(@"Fulfillment_Events")]];

    _eventsContainer = [[UIView alloc] init];
    _eventsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [content addArrangedSubview:_eventsContainer];

    UILabel *placeholder = [self labelWithFont:[Styling fontRegular:13] color:SeconderyTextClr lines:1];
    placeholder.text = kLang(@"Fulfillment_Loading");
    [_eventsContainer addSubview:placeholder];

    [NSLayoutConstraint activateConstraints:@[
        [_eventsContainer.heightAnchor constraintGreaterThanOrEqualToConstant:22],
        [placeholder.leadingAnchor constraintEqualToAnchor:_eventsContainer.leadingAnchor],
        [placeholder.trailingAnchor constraintEqualToAnchor:_eventsContainer.trailingAnchor],
        [placeholder.topAnchor constraintEqualToAnchor:_eventsContainer.topAnchor],
        [placeholder.bottomAnchor constraintEqualToAnchor:_eventsContainer.bottomAnchor],
    ]];

    [self pinContent:content toSurface:section];
    [self.stack addArrangedSubview:section];
}

- (void)buildActionBar {
    if (!self.hasLiveFulfillmentState) return;
    NSArray<NSString *> *actions = [self.model availableActions];
    if (actions.count == 0 || self.model.isTerminal) return;

    _actionBar = [self sectionSurface];
    _actionBar.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.9];

    UIStackView *btnStack = [[UIStackView alloc] init];
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.spacing = 10;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_actionBar addSubview:btnStack];

    for (NSString *action in actions) {
        UIButton *button = [self buttonForAction:action];
        button.tag = [actions indexOfObject:action];
        [btnStack addArrangedSubview:button];
    }

    [NSLayoutConstraint activateConstraints:@[
        [btnStack.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor constant:12],
        [btnStack.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor constant:-12],
        [btnStack.topAnchor constraintEqualToAnchor:_actionBar.topAnchor constant:12],
        [btnStack.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor constant:-12],
        [_actionBar.heightAnchor constraintGreaterThanOrEqualToConstant:68],
    ]];

    [self.stack addArrangedSubview:_actionBar];
}

- (void)refreshActionBarFromLiveFulfillment {
    [self removeActionBar];
    [self buildActionBar];
}

- (void)removeActionBar {
    if (self.actionBar) {
        [self.stack removeArrangedSubview:self.actionBar];
        [self.actionBar removeFromSuperview];
        self.actionBar = nil;
    }
}

#pragma mark - Component Helpers

- (UIView *)sectionSurface {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
    view.layer.cornerRadius = 24;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.07].CGColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

- (UIStackView *)verticalStackWithSpacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

- (void)pinContent:(UIView *)content toSurface:(UIView *)surface {
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-16],
        [content.topAnchor constraintEqualToAnchor:surface.topAnchor constant:16],
        [content.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-16],
    ]];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *label = [self labelWithFont:[Styling fontBold:15] color:PrimaryTextClr lines:1];
    label.text = text;
    return label;
}

- (UILabel *)badgeLabelWithText:(NSString *)text color:(UIColor *)color {
    UILabel *label = [self labelWithFont:[Styling fontBold:12] color:color lines:1];
    label.text = [NSString stringWithFormat:@"  %@  ", text ?: @"-"];
    label.backgroundColor = [color colorWithAlphaComponent:0.11];
    label.layer.cornerRadius = 14;
    label.layer.cornerCurve = kCACornerCurveContinuous;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (UIView *)metricSurfaceWithTitle:(NSString *)title value:(NSString *)value {
    UIView *surface = [self sectionSurface];
    surface.layer.cornerRadius = 20;

    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:18] color:PrimaryTextClr lines:1];
    valueLabel.text = value;
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.65;
    [surface addSubview:valueLabel];

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:11] color:SeconderyTextClr lines:2];
    titleLabel.text = title;
    [surface addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [valueLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12],
        [valueLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12],
        [valueLabel.topAnchor constraintEqualToAnchor:surface.topAnchor constant:14],

        [titleLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12],
        [titleLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:4],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-12],
    ]];

    return surface;
}

- (UIView *)moneyMiniMetricWithTitle:(NSString *)title value:(NSString *)value {
    UIView *surface = [[UIView alloc] init];
    surface.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
    surface.layer.cornerRadius = 18;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [[UIColor ppPremiumAccent] colorWithAlphaComponent:0.14].CGColor;

    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:15] color:[UIColor ppPremiumAccent] lines:1];
    valueLabel.text = value;
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.68;
    [surface addSubview:valueLabel];

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:11] color:[SeconderyTextClr colorWithAlphaComponent:0.78] lines:1];
    titleLabel.text = title;
    [surface addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [valueLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12],
        [valueLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12],
        [valueLabel.topAnchor constraintEqualToAnchor:surface.topAnchor constant:12],

        [titleLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12],
        [titleLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:3],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-10],
    ]];

    return surface;
}

- (UIView *)detailRowWithTitle:(NSString *)title value:(NSString *)value {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentFirstBaseline;
    row.distribution = UIStackViewDistributionFill;
    row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *titleLabel = [self labelWithFont:[Styling fontMedium:12] color:SeconderyTextClr lines:1];
    titleLabel.text = title;
    [titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:titleLabel];

    UILabel *valueLabel = [self labelWithFont:[Styling fontBold:13] color:PrimaryTextClr lines:0];
    valueLabel.text = value.length > 0 ? value : @"-";
    [row addArrangedSubview:valueLabel];

    return row;
}

- (UIView *)itemRow:(NSDictionary *)item index:(NSInteger)index {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentCenter;
    row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UILabel *ordinal = [self labelWithFont:[Styling fontBold:12] color:AppPrimaryClr lines:1];
    ordinal.text = [NSString stringWithFormat:@"%ld", (long)(index + 1)];
    ordinal.textAlignment = NSTextAlignmentCenter;
    ordinal.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
    ordinal.layer.cornerRadius = 15;
    ordinal.layer.cornerCurve = kCACornerCurveContinuous;
    ordinal.clipsToBounds = YES;
    [ordinal.widthAnchor constraintEqualToConstant:30].active = YES;
    [ordinal.heightAnchor constraintEqualToConstant:30].active = YES;
    [row addArrangedSubview:ordinal];

    UILabel *name = [self labelWithFont:[Styling fontMedium:13] color:PrimaryTextClr lines:2];
    NSString *fallback = [NSString stringWithFormat:@"%@ %ld", kLang(@"Fulfillment_Item"), (long)(index + 1)];
    name.text = PPSafeString(item[@"name"]).length > 0 ? PPSafeString(item[@"name"]) : fallback;
    [row addArrangedSubview:name];

    UILabel *price = [self labelWithFont:[Styling fontBold:12] color:SeconderyTextClr lines:1];
    NSInteger qty = PPSafeNumber(item[@"quantity"]).integerValue;
    if (qty <= 0) qty = PPSafeNumber(item[@"qty"]).integerValue;
    if (qty <= 0) qty = 1;
    double amount = PPSafeNumber(item[@"price"]).doubleValue;
    price.text = [NSString stringWithFormat:@"x%ld / %.0f %@", (long)qty, amount, self.model.currency.length > 0 ? self.model.currency : @"QAR"];
    [price setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:price];

    return row;
}

- (UIButton *)buttonForAction:(NSString *)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [Styling fontBold:13];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    button.layer.cornerRadius = 18;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [button setTitle:[self displayNameForAction:action] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];

    BOOL destructive = [action containsString:@"cancel"] || [action containsString:@"reject"];
    if (destructive) {
        button.backgroundColor = [[UIColor ppError] colorWithAlphaComponent:0.08];
        [button setTitleColor:[UIColor ppError] forState:UIControlStateNormal];
    } else {
        button.backgroundColor = AppPrimaryClr;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }
    return button;
}

#pragma mark - Data Formatting

- (NSString *)primaryOrderTitle {
    NSString *orderNumber = self.model.parentOrderNumber.length > 0 ? self.model.parentOrderNumber : [self shortID:self.model.fulfillmentID length:14];
    return [NSString stringWithFormat:@"%@ %@", kLang(@"Fulfillment_OrderID"), orderNumber.length > 0 ? orderNumber : @"-"];
}

- (NSString *)shortID:(NSString *)value length:(NSUInteger)length {
    if (value.length == 0) return @"-";
    return [value substringToIndex:MIN(length, value.length)];
}

- (NSString *)moneyString:(double)value {
    NSString *currency = self.model.currency.length > 0 ? self.model.currency : @"QAR";
    return [NSString stringWithFormat:@"%.0f %@", value, currency];
}

- (NSString *)mediumDateString:(NSDate *)date {
    if (!date) return @"-";
    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateStyle = NSDateFormatterMediumStyle;
        df.timeStyle = NSDateFormatterShortStyle;
    });
    return [df stringFromDate:date];
}

- (NSString *)eventDateString:(id)value {
    NSDate *date = nil;
    if ([value isKindOfClass:[NSDate class]]) date = value;
    else if ([value respondsToSelector:@selector(dateValue)]) date = [value dateValue];
    if (!date) return @"";

    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"MMM d, HH:mm";
    });
    return [df stringFromDate:date];
}

#pragma mark - Events

- (void)observeFulfillment {
    [self.fulfillmentListener remove];
    self.fulfillmentListener = nil;
    NSUInteger generation = ++self.fulfillmentListenerGeneration;
    NSString *listenerUID = [[FIRAuth auth].currentUser.uid ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *fulfillmentID = [self.model.fulfillmentID copy] ?: @"";
    self.listenerUID = listenerUID;
    self.hasLiveFulfillmentState = NO;
    [self removeActionBar];
    if (listenerUID.length == 0 || fulfillmentID.length == 0) return;

    __weak typeof(self) weakSelf = self;
    self.fulfillmentListener = [[PPFulfillmentManager sharedManager] observeFulfillmentWithID:fulfillmentID stateHandler:^(PPFulfillmentModel * _Nullable fulfillment, NSError * _Nullable error, BOOL fromCache) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.fulfillmentListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:listenerUID] || ![self.listenerUID isEqualToString:listenerUID]) return;
        BOOL ownsFulfillment = [fulfillment.ownerType isEqualToString:@"partner"] && [fulfillment.ownerID isEqualToString:listenerUID];
        if (error || !fulfillment || fromCache || !ownsFulfillment) {
            self.hasLiveFulfillmentState = NO;
            [self removeActionBar];
            return;
        }
        if (![fulfillment.fulfillmentID isEqualToString:fulfillmentID]) return;

        BOOL actionStateChanged = !self.hasLiveFulfillmentState || ![fulfillment.status isEqualToString:self.model.status];
        self.model = fulfillment;
        self.hasLiveFulfillmentState = YES;
        if (actionStateChanged) {
            [self refreshActionBarFromLiveFulfillment];
        }
    }];
}

- (void)observeEvents {
    [self.eventsListener remove];
    self.eventsListener = nil;
    NSUInteger generation = ++self.eventsListenerGeneration;
    NSString *listenerUID = self.listenerUID ?: ([FIRAuth auth].currentUser.uid ?: @"");
    NSString *fulfillmentID = [self.model.fulfillmentID copy] ?: @"";
    if (listenerUID.length == 0 || fulfillmentID.length == 0) return;
    __weak typeof(self) weakSelf = self;
    self.eventsListener = [[PPFulfillmentManager sharedManager] observeEventsForFulfillmentID:fulfillmentID onChange:^(NSArray<NSDictionary *> *events) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.eventsListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:listenerUID] || ![self.listenerUID isEqualToString:listenerUID]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self renderEvents:events ?: @[]];
        });
    }];
}

- (void)renderEvents:(NSArray<NSDictionary *> *)events {
    [[self.eventsContainer subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    UIStackView *stack = [self verticalStackWithSpacing:10];
    [self.eventsContainer addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.eventsContainer.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.eventsContainer.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.eventsContainer.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.eventsContainer.bottomAnchor],
    ]];

    if (events.count == 0) {
        UILabel *empty = [self labelWithFont:[Styling fontRegular:13] color:SeconderyTextClr lines:0];
        empty.text = kLang(@"Fulfillment_NoEvents");
        [stack addArrangedSubview:empty];
        return;
    }

    for (NSDictionary *event in events) {
        [stack addArrangedSubview:[self eventRow:event]];
    }
}

- (UIView *)eventRow:(NSDictionary *)event {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.alignment = UIStackViewAlignmentTop;
    row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *dot = [[UIView alloc] init];
    dot.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.82];
    dot.layer.cornerRadius = 4;
    [dot.widthAnchor constraintEqualToConstant:8].active = YES;
    [dot.heightAnchor constraintEqualToConstant:8].active = YES;
    [row addArrangedSubview:dot];

    UILabel *label = [self labelWithFont:[Styling fontRegular:12] color:SeconderyTextClr lines:0];
    NSString *actionValue = PPSafeString(event[@"action"]);
    NSString *fromValue = PPSafeString(event[@"fromStatus"]);
    NSString *toValue = PPSafeString(event[@"toStatus"]);
    NSString *action = actionValue.length > 0 ? [self displayNameForAction:actionValue] : @"-";
    NSString *from = fromValue.length > 0 ? [self displayNameForStatusValue:fromValue] : @"-";
    NSString *to = toValue.length > 0 ? [self displayNameForStatusValue:toValue] : @"-";
    NSString *date = [self eventDateString:event[@"createdAt"]];
    label.text = [NSString stringWithFormat:@"%@  %@ > %@  %@", action, from, to, date];
    [row addArrangedSubview:label];

    return row;
}

#pragma mark - Actions

- (NSString *)displayNameForAction:(NSString *)action {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"accept":            @"Fulfillment_Accept",
            @"reject":            @"Fulfillment_Reject",
            @"start_preparing":   @"Fulfillment_StartPreparing",
            @"mark_ready":        @"Fulfillment_MarkReady",
            @"request_delivery":  @"Fulfillment_RequestDelivery",
            @"confirm_handover":  @"Fulfillment_ConfirmHandover",
            @"cancel_request":    @"Fulfillment_CancelRequest",
        };
    });
    NSString *key = map[action];
    return key.length > 0 ? kLang(key) : action;
}

- (NSString *)displayNameForStatusValue:(NSString *)status {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"new_request":        @"Fulfillment_Status_NewRequest",
            @"accepted":           @"Fulfillment_Status_Accepted",
            @"rejected":           @"Fulfillment_Status_Rejected",
            @"preparing":          @"Fulfillment_Status_Preparing",
            @"ready_for_pickup":   @"Fulfillment_Status_ReadyForPickup",
            @"delivery_requested": @"Fulfillment_Status_DeliveryRequested",
            @"delivery_assigned":  @"Fulfillment_Status_DeliveryAssigned",
            @"awaiting_handover":  @"Fulfillment_Status_AwaitingHandover",
            @"handed_over":        @"Fulfillment_Status_HandedOver",
            @"in_transit":         @"InTransit",
            @"delivered":          @"Delivered",
            @"payment_pending":    @"Deliv_PaymentPending",
            @"payment_confirmed":  @"Deliv_StatusPaymentConfirmed",
            @"completed":          @"Fulfillment_Status_Completed",
            @"cancelled":          @"Fulfillment_Status_Cancelled",
            @"failed":             @"Fulfillment_Status_Failed",
            @"returned":           @"Fulfillment_Status_Returned",
        };
    });
    NSString *key = map[status];
    return key.length > 0 ? kLang(key) : kLang(@"Fulfillment_Status_Unknown");
}

- (void)actionTapped:(UIButton *)sender {
    if (!self.hasLiveFulfillmentState) return;
    NSArray<NSString *> *actions = [self.model availableActions];
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)actions.count) return;
    [self confirmAction:actions[idx]];
}

- (void)confirmAction:(NSString *)action {
    BOOL destructive = [action containsString:@"cancel"] || [action containsString:@"reject"];
    __weak typeof(self) weakSelf = self;
    if (destructive) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self displayNameForAction:action]
                                                                       message:kLang(@"Fulfillment_ConfirmAction")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = kLang(@"Fulfillment_NoteOptional");
            textField.textAlignment = Language.alignmentForCurrentLanguage;
            textField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        }];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull confirm) {
            NSString *note = alert.textFields.firstObject.text ?: @"";
            [weakSelf executeAction:action note:note];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self executeAction:action note:@""];
    }
}

- (void)executeAction:(NSString *)action note:(NSString *)note {
    if ([action isEqualToString:@"request_delivery"]) {
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Fulfillment_Updating") subtitle:nil];
        __weak typeof(self) weakSelf = self;
        [self fetchParentOrderDataWithCompletion:^(NSDictionary * _Nullable orderData, NSError * _Nullable error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error || orderData.count == 0) {
                [PPHUD dismiss];
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic")];
                return;
            }

            if ([self isFulfillmentV1ParentOrderData:orderData]) {
                [self executeStandardFulfillmentAction:action note:note];
                return;
            }

            [PPHUD dismiss];
            [self presentMarketplaceBranchPickerForAction:action note:note];
        }];
        return;
    }
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Fulfillment_Updating") subtitle:nil];
    [self executeStandardFulfillmentAction:action note:note];
}

- (void)presentMarketplaceBranchPickerForAction:(NSString *)action note:(NSString *)note {
    __weak typeof(self) weakSelf = self;
    PPMarketplaceBranchesViewController *picker =
        [[PPMarketplaceBranchesViewController alloc] initForSelectionWithCompletion:^(PPMarketplaceBranch *branch) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [PPHUD showIndeterminateIn:self.view title:kLang(@"Fulfillment_Updating") subtitle:nil];
        [self executeMarketplaceDeliveryRequestWithAction:action note:note branch:branch];
    }];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:picker];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 16.0, *)) {
        UISheetPresentationControllerDetent *detent =
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"marketplacePickupBranch89"
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return context.maximumDetentValue * 0.89;
        }];
        navigationController.sheetPresentationController.detents = @[detent];
        navigationController.sheetPresentationController.prefersGrabberVisible = YES;
        navigationController.sheetPresentationController.preferredCornerRadius = 30.0;
    } else if (@available(iOS 15.0, *)) {
        navigationController.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        navigationController.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)executeMarketplaceDeliveryRequestWithAction:(NSString *)action
                                               note:(NSString *)note
                                             branch:(PPMarketplaceBranch *)branch {
    __weak typeof(self) weakSelf = self;
    [self fetchParentOrderDataWithCompletion:^(NSDictionary * _Nullable orderData, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || orderData.count == 0) {
            [PPHUD dismiss];
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic")];
            return;
        }

        // Fulfillment V1 owns delivery through providerTransitionFulfillment.
        // The legacy company-delivery callable is fenced by Infra for V1 parents.
        if ([self isFulfillmentV1ParentOrderData:orderData]) {
            [self executeStandardFulfillmentAction:action note:note];
            return;
        }

        NSMutableDictionary *pickupAddress = [[branch pickupAddressPayload] mutableCopy];
        NSMutableDictionary *dropoffAddress = [[self firstAddressPayloadInDictionary:orderData
                                                                                keys:@[@"shippingAddressSnapshot", @"deliveryRequestAddressSnapshot", @"shippingAddress", @"deliveryAddress", @"address"]] mutableCopy];

        NSString *requestNote = note.length > 0
            ? note
            : [self firstStringInDictionary:orderData keys:@[@"deliveryNotes", @"notes", @"note"]];

        [self performCanonicalFulfillmentAction:action note:note completion:^(BOOL transitionSucceeded, NSString *message, NSError *transitionError) {
            __strong typeof(weakSelf) innerSelf = weakSelf;
            if (!innerSelf) return;
            if (!transitionSucceeded) {
                [PPHUD dismiss];
                [PPAlertHelper showErrorIn:innerSelf title:kLang(@"Error") subtitle:message ?: transitionError.localizedDescription];
                return;
            }

            [[PPDeliveryCompanyService shared] createRequestForOrderID:innerSelf.model.parentOrderId
                                                              companyID:nil
                                                  marketplaceProviderID:innerSelf.model.ownerID
                                                              branchID:branch.branchID
                                                          pickupAddress:pickupAddress.copy
                                                         dropoffAddress:dropoffAddress.copy
                                                            deliveryFee:[innerSelf firstNumberInDictionary:orderData keys:@[@"shippingFee", @"deliveryFee", @"shippingCost"]]
                                                          paymentStatus:[innerSelf firstStringInDictionary:orderData keys:@[@"paymentStatus"]]
                                                        paymentProvider:[innerSelf firstStringInDictionary:orderData keys:@[@"paymentProvider"]]
                                                           deliveryNote:requestNote
                                                             completion:^(__unused NSDictionary * _Nullable result, NSError * _Nullable requestError) {
                if (requestError && ![innerSelf shouldIgnoreExistingCompanyRequestError:requestError]) {
                    [PPHUD dismiss];
                    [PPAlertHelper showErrorIn:innerSelf title:kLang(@"Error") subtitle:requestError.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic")];
                    return;
                }
                [innerSelf finishSuccessfulFulfillmentAction];
            }];
        }];
    }];
}

- (BOOL)isFulfillmentV1ParentOrderData:(NSDictionary *)orderData {
    id rawVersion = [orderData isKindOfClass:NSDictionary.class] ? orderData[@"fulfillmentVersion"] : nil;
    return [rawVersion respondsToSelector:@selector(integerValue)] && [rawVersion integerValue] == 1;
}

- (void)fetchParentOrderDataWithCompletion:(void (^)(NSDictionary * _Nullable orderData, NSError * _Nullable error))completion {
    NSString *orderID = self.model.parentOrderId ?: @"";
    if (orderID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.Fulfillment"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Generic")}];
        if (completion) completion(nil, error);
        return;
    }

    FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            if (!snapshot.exists) {
                NSError *notFound = [NSError errorWithDomain:@"PurePetsPro.Fulfillment"
                                                        code:2
                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Generic")}];
                if (completion) completion(nil, notFound);
                return;
            }
            if (completion) completion(PPSafeDict(snapshot.data), nil);
        });
    }];
}

- (NSDictionary *)firstAddressPayloadInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSDictionary *address = [self addressPayloadFromValue:dictionary[key]];
        if (address.count > 0) {
            return address;
        }
    }
    return @{};
}

- (NSDictionary *)addressPayloadFromValue:(id)value {
    if ([value isKindOfClass:NSDictionary.class]) {
        return (NSDictionary *)value;
    }
    NSString *stringValue = [value isKindOfClass:NSString.class] ? [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (stringValue.length > 0) {
        return @{@"displayName": stringValue};
    }
    return @{};
}

- (NSString *)firstStringInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSString *value = PPSafeString(dictionary[key]);
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

- (double)firstNumberInDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value respondsToSelector:@selector(doubleValue)]) {
            return [value doubleValue];
        }
    }
    return 0.0;
}

- (BOOL)shouldIgnoreExistingCompanyRequestError:(NSError *)error {
    NSString *message = [error.localizedDescription lowercaseString];
    return [message containsString:@"already exists"] || [message containsString:@"already-exists"];
}

- (void)executeStandardFulfillmentAction:(NSString *)action note:(NSString *)note {
    __weak typeof(self) weakSelf = self;
    [self performCanonicalFulfillmentAction:action note:note completion:^(BOOL success, NSString *message, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            [PPHUD dismiss];
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:message ?: error.localizedDescription];
            return;
        }
        [self finishSuccessfulFulfillmentAction];
    }];
}

- (void)performCanonicalFulfillmentAction:(NSString *)action
                                     note:(NSString *)note
                               completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    BOOL ownsLiveFulfillment = self.hasLiveFulfillmentState &&
        [self.listenerUID isEqualToString:currentUID] &&
        [self.model.ownerType isEqualToString:@"partner"] &&
        [self.model.ownerID isEqualToString:currentUID];
    if (!ownsLiveFulfillment) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.Fulfillment"
                                             code:409
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryStateChangedReload")}];
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }
    [[PPFulfillmentManager sharedManager] performTransitionAction:action
                                                    fulfillmentID:self.model.fulfillmentID
                                                   expectedStatus:self.model.status
                                                        commandID:nil
                                                             note:note
                                                       completion:^(BOOL success, NSString *message, NSError *error) {
        if (completion) completion(success, message, error);
    }];
}

- (void)finishSuccessfulFulfillmentAction {
    [PPHUD dismiss];
    [PPHUD showSuccess:kLang(@"Fulfillment_ActionSuccess")];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

#pragma mark - Motion

- (void)runEntranceMotion {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    NSArray<UIView *> *sections = self.stack.arrangedSubviews;
    NSUInteger animatedIndex = 0;
    for (NSUInteger idx = 0; idx < sections.count; idx++) {
        if (sections[idx] == self.heroSurfaceView.superview) {
            continue;
        }
        UIView *section = sections[idx];
        section.alpha = 0.0;
        section.transform = CGAffineTransformMakeTranslation(0, 12);
        [UIView animateWithDuration:0.36 delay:0.035 * animatedIndex options:UIViewAnimationOptionCurveEaseOut animations:^{
            section.alpha = 1.0;
            section.transform = CGAffineTransformIdentity;
        } completion:nil];
        animatedIndex += 1;
    }
}

- (void)runHeroEntranceIfNeeded {
    if (self.didAnimateHero) return;
    self.didAnimateHero = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in self.heroMotionViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [self.heroMotionViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 18);
        [UIView animateWithDuration:0.56
                              delay:0.035 * idx
             usingSpringWithDamping:0.91
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)prepareHeroInitialMotionState {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    for (UIView *view in self.heroMotionViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 18);
    }
}

- (void)startHeroAmbientMotion {
    
}

- (void)stopHeroAmbientMotion {
 }

- (void)startLiveBackgroundMotion {
    if (UIAccessibilityIsReduceMotionEnabled() || !self.liveBackgroundView) {
        self.liveBackgroundView.alpha = 1.0;
        return;
    }
    if ([self.liveGlowTopLayer animationForKey:@"pp_detail_live_glow_top"]) {
        return;
    }

    self.liveBackgroundView.alpha = 0.0;
    [UIView animateWithDuration:0.72 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.liveBackgroundView.alpha = 1.0;
    } completion:nil];

    [self addBreathingAnimationToLayer:self.liveGlowTopLayer key:@"pp_detail_live_glow_top" x:-18.0 y:22.0 scale:1.07 duration:8.8 delay:0.0];
    [self addBreathingAnimationToLayer:self.liveGlowMidLayer key:@"pp_detail_live_glow_mid" x:20.0 y:16.0 scale:1.06 duration:10.2 delay:0.4];
    [self addBreathingAnimationToLayer:self.liveGlowBottomLayer key:@"pp_detail_live_glow_bottom" x:-16.0 y:-18.0 scale:1.05 duration:11.0 delay:0.2];
}

- (void)addBreathingAnimationToLayer:(CALayer *)layer
                                  key:(NSString *)key
                                    x:(CGFloat)x
                                    y:(CGFloat)y
                                scale:(CGFloat)scale
                             duration:(CFTimeInterval)duration
                                delay:(CFTimeInterval)delay {
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
    [self.liveGlowTopLayer removeAnimationForKey:@"pp_detail_live_glow_top"];
    [self.liveGlowMidLayer removeAnimationForKey:@"pp_detail_live_glow_mid"];
    [self.liveGlowBottomLayer removeAnimationForKey:@"pp_detail_live_glow_bottom"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.fulfillmentListenerGeneration += 1;
    self.eventsListenerGeneration += 1;
    [self.fulfillmentListener remove];
    [self.eventsListener remove];
}

@end
