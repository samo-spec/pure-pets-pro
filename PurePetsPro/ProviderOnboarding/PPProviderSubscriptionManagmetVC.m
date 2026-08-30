#import "PPProviderSubscriptionManagmetVC.h"
#import "PPBecomeProviderBottomSheetViewController.h"
#import "PPProviderApplicationManager.h"
#import "AdminDashboardViewController.h"
#import "Language.h"
#import "PPButtonHelper.h"
#import "PPFirebaseCompat.h"
#import "PPPaddingLabel.h"
#import "Styling.h"
#import "Lottie.h"
#import "UserManager.h"

static NSString * const kPPProviderStatusPendingValue = @"pending";
static NSString * const kPPProviderStatusUnderReviewValue = @"under_review";
static NSString * const kPPProviderStatusRejectedValue = @"rejected";
static NSString * const kPPProviderStatusArchivedValue = @"archived";
static NSString * const kPPProviderProfileStatusActiveValue = @"active";

static UIColor *PPProviderStatusAccentColor(void) {
    return AppPrimaryClr;
}

static UIColor *PPProviderStatusBackgroundColor(void) {
    return [UIColor ppElevatedSurface];
}

static UIColor *PPProviderStatusSurfaceColor(void) {
    return [UIColor ppSurface];
}

static UIColor *PPProviderStatusPrimaryTextColor(void) {
    return [UIColor ppTextPrimary];
}

static UIColor *PPProviderStatusSecondaryTextColor(void) {
    return [UIColor ppTextSecondary];
}

@interface PPProviderSubscriptionManagmetVC () <PPBecomeProviderBottomSheetViewControllerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) PPPaddingLabel *statusPillLabel;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *heroStageIconView;
@property (nonatomic, strong) LOTAnimationView *heroStageWaitingAnimationView;

@property (nonatomic, strong) UIView *heroStageView;
@property (nonatomic, strong) UIView *heroStageCoreView;
@property (nonatomic, strong) UIView *identityCard;
@property (nonatomic, strong) UIView *applicationEntryCard;
@property (nonatomic, strong) UILabel *providerCardsSectionLabel;
@property (nonatomic, strong) UIStackView *statusCardsStack;
@property (nonatomic, strong) UIButton *applicationsActionButton;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) UIView *footerBar;
@property (nonatomic, strong) NSLayoutConstraint *footerBarHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *secondaryButtonTopToPrimaryConstraint;
@property (nonatomic, strong) NSLayoutConstraint *secondaryButtonTopToFooterConstraint;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> stateListener;
@property (nonatomic, strong, nullable) PPProviderOnboardingState *state;
@property (nonatomic, strong, nullable) NSError *lastError;
@property (nonatomic, strong) UIView *backgroundGlowTop;
@property (nonatomic, strong) UIView *backgroundGlowBottom;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL didAutoPresentBecomeProvider;
@property (nonatomic, assign) BOOL didTransitionToDashboard;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL isClosing;
@end

@implementation PPProviderSubscriptionManagmetVC

- (BOOL)pp_hasReviewLifecycleInState:(PPProviderOnboardingState *)state {
    if (!state) {
        return NO;
    }
    NSString *partnerStatus = [PPSafeString(state.partnerApplicationStatus).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([partnerStatus isEqualToString:kPPProviderStatusPendingValue] ||
        [partnerStatus isEqualToString:kPPProviderStatusUnderReviewValue]) {
        return YES;
    }

    for (PPProviderApplication *application in state.applications) {
        if (!PPProviderTypeIsEnabledInProApp(application.providerType)) {
            continue;
        }
        NSString *status = [PPSafeString(application.status).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([status isEqualToString:kPPProviderStatusPendingValue] ||
            [status isEqualToString:kPPProviderStatusUnderReviewValue]) {
            return YES;
        }
    }
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPProviderStatusBackgroundColor();
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.isLoading = YES;
    [self pp_buildLayout];
    [self pp_applyLoadingState];
    [self pp_startObservingState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_forceProviderStatusNavigationControls];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_forceProviderStatusNavigationControls];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)pp_forceProviderStatusNavigationControls {
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = @"";

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"ProviderStatusNavTitle") showBack:NO];
    [self pp_navBarRemoveButtonForKey:@"close"];
    [self pp_navBarSetLeftIcon:@"xmark" key:@"close" target:self action:@selector(pp_closeTapped) tap:^{}];
}

- (void)pp_stopObservingState {
    [self.stateListener remove];
    self.stateListener = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
}

- (void)dealloc {
    [self pp_stopObservingState];
}

#pragma mark - Layout

- (void)pp_buildLayout {
    [self pp_buildAmbientBackground];

    self.footerBar = [[UIView alloc] init];
    self.footerBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerBar.backgroundColor = [PPProviderStatusBackgroundColor() colorWithAlphaComponent:0.96];
    self.footerBar.clipsToBounds = YES;
    [self.view addSubview:self.footerBar];

    UIView *footerHairline = [[UIView alloc] init];
    footerHairline.translatesAutoresizingMaskIntoConstraints = NO;
    footerHairline.backgroundColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.10];
    [self.footerBar addSubview:footerHairline];

    self.primaryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryButton.layer.cornerRadius = 24.0;
    self.primaryButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.primaryButton.titleLabel.font = [Styling fontBold:16.0];
    self.primaryButton.contentEdgeInsets = UIEdgeInsetsMake(17.0, 18.0, 17.0, 18.0);
    self.primaryButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.primaryButton addTarget:self action:@selector(primaryButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.primaryButton.heightAnchor constraintEqualToConstant:56.0].active = YES;
    [PPButtonHelper attachTapAnimationToButton:self.primaryButton style:PPButtonAnimationStyleDefault];
    [self.footerBar addSubview:self.primaryButton];

    self.secondaryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.secondaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.secondaryButton.layer.cornerRadius = 21.0;
    self.secondaryButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.secondaryButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.secondaryButton.titleLabel.font = [Styling fontBold:14.0];
    self.secondaryButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    self.secondaryButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.secondaryButton addTarget:self action:@selector(secondaryButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.secondaryButton.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [PPButtonHelper attachTapAnimationToButton:self.secondaryButton style:PPButtonAnimationStylePulse];
    [self.footerBar addSubview:self.secondaryButton];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 20.0;
    contentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [scrollView addSubview:contentStack];
    self.contentStack = contentStack;

    self.footerBarHeightConstraint = [self.footerBar.heightAnchor constraintEqualToConstant:132.0];
    self.secondaryButtonTopToPrimaryConstraint = [self.secondaryButton.topAnchor constraintEqualToAnchor:self.primaryButton.bottomAnchor constant:10.0];
    self.secondaryButtonTopToFooterConstraint = [self.secondaryButton.topAnchor constraintEqualToAnchor:self.footerBar.topAnchor constant:14.0];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.footerBar.topAnchor],

        [contentStack.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:24.0],
        [contentStack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:20.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-20.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-30.0],
        [contentStack.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-40.0],

        [self.footerBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.footerBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.footerBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        self.footerBarHeightConstraint,

        [footerHairline.topAnchor constraintEqualToAnchor:self.footerBar.topAnchor],
        [footerHairline.leadingAnchor constraintEqualToAnchor:self.footerBar.leadingAnchor constant:20.0],
        [footerHairline.trailingAnchor constraintEqualToAnchor:self.footerBar.trailingAnchor constant:-20.0],
        [footerHairline.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [self.primaryButton.topAnchor constraintEqualToAnchor:self.footerBar.topAnchor constant:14.0],
        [self.primaryButton.leadingAnchor constraintEqualToAnchor:self.footerBar.leadingAnchor constant:20.0],
        [self.primaryButton.trailingAnchor constraintEqualToAnchor:self.footerBar.trailingAnchor constant:-20.0],

        [self.secondaryButton.leadingAnchor constraintEqualToAnchor:self.footerBar.leadingAnchor constant:20.0],
        [self.secondaryButton.trailingAnchor constraintEqualToAnchor:self.footerBar.trailingAnchor constant:-20.0],
    ]];

    [contentStack addArrangedSubview:[self pp_buildHeroSection]];
    [contentStack addArrangedSubview:self.identityCard];
    self.applicationEntryCard = [self pp_buildApplicationEntrySurface];
    [contentStack addArrangedSubview:self.applicationEntryCard];

    self.providerCardsSectionLabel = [self pp_sectionLabelWithText:kLang(@"ProviderApplicationsSectionTitle")];
    [contentStack addArrangedSubview:self.providerCardsSectionLabel];

    self.statusCardsStack = [[UIStackView alloc] init];
    self.statusCardsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusCardsStack.axis = UILayoutConstraintAxisVertical;
    self.statusCardsStack.spacing = 12.0;
    self.statusCardsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentStack addArrangedSubview:self.statusCardsStack];

    self.applicationsActionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.applicationsActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.applicationsActionButton.layer.cornerRadius = 22.0;
    self.applicationsActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.applicationsActionButton.titleLabel.font = [Styling fontBold:16.0];
    self.applicationsActionButton.contentEdgeInsets = UIEdgeInsetsMake(16.0, 18.0, 16.0, 18.0);
    self.applicationsActionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.applicationsActionButton.hidden = YES;
    [self.applicationsActionButton addTarget:self action:@selector(primaryButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.applicationsActionButton style:PPButtonAnimationStyleDefault];
    [contentStack addArrangedSubview:self.applicationsActionButton];

    self.footerLabel = [[UILabel alloc] init];
    self.footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerLabel.font = [Styling fontMedium:13.0];
    self.footerLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
    self.footerLabel.numberOfLines = 0;
    self.footerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.footerLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentStack addArrangedSubview:self.footerLabel];

    [self pp_applySecondaryButtonStyle];
}

- (UIView *)pp_buildHeroSection {
    UIColor *accentColor = PPProviderStatusAccentColor();

    PPHero *heroSurface = [[PPHero alloc] init];
    heroSurface.translatesAutoresizingMaskIntoConstraints = NO;



    self.statusPillLabel = [[PPPaddingLabel alloc] init];
    self.statusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusPillLabel.font = [Styling fontBold:12.0];
    self.statusPillLabel.textInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    self.statusPillLabel.layer.cornerRadius = 17.0;
    self.statusPillLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusPillLabel.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.statusPillLabel.clipsToBounds = YES;
    [heroSurface addSubview:self.statusPillLabel];

    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = [Styling fontBold:11.0];
    self.eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    self.eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [heroSurface addSubview:self.eyebrowLabel];

    self.headlineLabel = [[UILabel alloc] init];
    self.headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headlineLabel.font = [Styling fontBold:30.0];
    self.headlineLabel.textColor = PPProviderStatusPrimaryTextColor();
    self.headlineLabel.numberOfLines = 2;
    self.headlineLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [heroSurface addSubview:self.headlineLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [Styling fontRegular:14.0];
    self.subtitleLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [heroSurface addSubview:self.subtitleLabel];

    self.heroStageView = [[PPHero alloc] init];
    self.heroStageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStageView.layer.cornerRadius = 32.0;
    [heroSurface addSubview:self.heroStageView];

    self.heroStageCoreView = [[UIView alloc] init];
    self.heroStageCoreView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStageCoreView.backgroundColor = [accentColor colorWithAlphaComponent:0.18];
    self.heroStageCoreView.layer.cornerRadius = 20.0;
    self.heroStageCoreView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroStageView addSubview:self.heroStageCoreView];

    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:21.0
                                                                                                weight:UIImageSymbolWeightSemibold];
    self.heroStageIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:symbolConfig]];
    self.heroStageIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStageIconView.tintColor = accentColor;
    [self.heroStageCoreView addSubview:self.heroStageIconView];

    self.heroStageWaitingAnimationView = [LOTAnimationView animationNamed:@"BePartner"];
    self.heroStageWaitingAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStageWaitingAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroStageWaitingAnimationView.loopAnimation = YES;
    self.heroStageWaitingAnimationView.animationSpeed = 0.5f;
    self.heroStageWaitingAnimationView.alpha = 0;
    self.heroStageWaitingAnimationView.userInteractionEnabled = NO;
    [self.heroStageCoreView addSubview:self.heroStageWaitingAnimationView];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroStageWaitingAnimationView.centerXAnchor constraintEqualToAnchor:self.heroStageCoreView.centerXAnchor],
        [self.heroStageWaitingAnimationView.centerYAnchor constraintEqualToAnchor:self.heroStageCoreView.centerYAnchor],
        [self.heroStageWaitingAnimationView.widthAnchor constraintEqualToAnchor:self.heroStageCoreView.widthAnchor multiplier:2.8],
        [self.heroStageWaitingAnimationView.heightAnchor constraintEqualToAnchor:self.heroStageCoreView.heightAnchor multiplier:2.8],
        [heroSurface.heightAnchor constraintGreaterThanOrEqualToConstant:250.0],



        [self.heroStageView.topAnchor constraintEqualToAnchor:heroSurface.topAnchor constant:22.0],
        [self.heroStageView.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-22.0],
        [self.heroStageView.widthAnchor constraintEqualToConstant:82.0],
        [self.heroStageView.heightAnchor constraintEqualToConstant:82.0],

        [self.heroStageCoreView.centerXAnchor constraintEqualToAnchor:self.heroStageView.centerXAnchor],
        [self.heroStageCoreView.centerYAnchor constraintEqualToAnchor:self.heroStageView.centerYAnchor],
        [self.heroStageCoreView.widthAnchor constraintEqualToConstant:40.0],
        [self.heroStageCoreView.heightAnchor constraintEqualToConstant:40.0],

        [self.heroStageIconView.centerXAnchor constraintEqualToAnchor:self.heroStageCoreView.centerXAnchor],
        [self.heroStageIconView.centerYAnchor constraintEqualToAnchor:self.heroStageCoreView.centerYAnchor],

        [self.statusPillLabel.topAnchor constraintEqualToAnchor:heroSurface.topAnchor constant:22.0],
        [self.statusPillLabel.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:22.0],
        [self.statusPillLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_heroStageView.leadingAnchor constant:-16.0],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.statusPillLabel.bottomAnchor constant:18.0],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:22.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_heroStageView.leadingAnchor constant:-16.0],

        [self.headlineLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:8.0],
        [self.headlineLabel.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:22.0],
        [self.headlineLabel.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-22.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.headlineLabel.bottomAnchor constant:10.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:heroSurface.leadingAnchor constant:22.0],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:heroSurface.trailingAnchor constant:-22.0],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:heroSurface.bottomAnchor constant:-22.0],
    ]];

    self.identityCard = [self pp_buildIdentitySurface];
    return heroSurface;
}

- (UIView *)pp_buildIdentitySurface {
    UIColor *accentColor = PPProviderStatusAccentColor();

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPProviderStatusSurfaceColor();
    surface.layer.cornerRadius = 30.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [accentColor colorWithAlphaComponent:0.08].CGColor;
    return surface;
}

- (UIView *)pp_buildApplicationEntrySurface {
    UIColor *accentColor = PPProviderStatusAccentColor();

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPProviderStatusSurfaceColor();
    surface.layer.cornerRadius = 32.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [accentColor colorWithAlphaComponent:0.08].CGColor;
    return surface;
}

- (UILabel *)pp_sectionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:12.0];
    label.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.text = text;
    return label;
}

- (void)pp_buildAmbientBackground {
    UIColor *accentColor = PPProviderStatusAccentColor();

    self.backgroundGlowTop = [[UIView alloc] init];
    self.backgroundGlowTop.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundGlowTop.backgroundColor = [accentColor colorWithAlphaComponent:0.06];
    self.backgroundGlowTop.layer.cornerRadius = 140.0;
    self.backgroundGlowTop.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view insertSubview:self.backgroundGlowTop atIndex:0];

    self.backgroundGlowBottom = [[UIView alloc] init];
    self.backgroundGlowBottom.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundGlowBottom.backgroundColor = [accentColor colorWithAlphaComponent:0.04];
    self.backgroundGlowBottom.layer.cornerRadius = 160.0;
    self.backgroundGlowBottom.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view insertSubview:self.backgroundGlowBottom atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundGlowTop.widthAnchor constraintEqualToConstant:280.0],
        [self.backgroundGlowTop.heightAnchor constraintEqualToConstant:280.0],
        [self.backgroundGlowTop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-80.0],
        [self.backgroundGlowTop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:60.0],

        [self.backgroundGlowBottom.widthAnchor constraintEqualToConstant:320.0],
        [self.backgroundGlowBottom.heightAnchor constraintEqualToConstant:320.0],
        [self.backgroundGlowBottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:100.0],
        [self.backgroundGlowBottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-80.0],
    ]];
}

#pragma mark - Data

- (void)pp_startObservingState {
    [self pp_stopObservingState];

    __weak typeof(self) weakSelf = self;
    self.stateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isLoading = NO;
        self.lastError = error;
        self.state = state;

        BOOL hasReviewLifecycle = (!error && state && [self pp_hasReviewLifecycleInState:state]);
        
        if (!error &&
            state &&
            !self.suppressAutoDashboardTransition &&
            (state.canOfferServices ||
             state.canDeliveryCompany ||
             state.canVet ||
             state.canPharmacy ||
             state.canAccessProviderMarketplace) &&
            !hasReviewLifecycle) {
            [self pp_transitionToDashboardIfNeeded];
            return;
        }

        [self pp_renderCurrentState];
    }];
}

- (void)pp_applyLoadingState {
    [self pp_applyHeroBadgeText:kLang(@"ProviderHeroLoadingBadge")
                    accentColor:PPProviderStatusAccentColor()
                     symbolName:@"hourglass.circle.fill"
          showsWaitingAnimation:NO];
    self.eyebrowLabel.text = kLang(@"ProviderStatusEyebrow");
    self.headlineLabel.text = kLang(@"ProviderStateLoadingTitle");
    self.subtitleLabel.text = kLang(@"ProviderStateLoadingSubtitle");
    self.footerLabel.text = @"";
    self.footerLabel.hidden = YES;
    self.primaryButton.hidden = YES;
    self.secondaryButton.hidden = YES;
    self.applicationsActionButton.hidden = YES;
    [self pp_updateFooterBarVisibilityAnimated:NO];
    [self pp_renderIdentityCardWithEntries:@[]];
    [self pp_renderApplicationEntryCardWithAccentColor:PPProviderStatusAccentColor()
                                               eyebrow:kLang(@"ProviderStartCardEyebrow")
                                                 title:kLang(@"ProviderStateLoadingTitle")
                                              subtitle:kLang(@"ProviderStateLoadingSubtitle")
                                           buttonTitle:nil
                                              footnote:nil
                                            symbolName:@"sparkles"
                                     providerTypeTitles:@[]];
    [self pp_renderProviderCards:@[]];
}

- (void)pp_renderCurrentState {
    if (self.isLoading) {
        [self pp_applyLoadingState];
        return;
    }

    if (self.lastError) {
        UIColor *accentColor = [UIColor ppError];
        [self pp_applyHeroBadgeText:kLang(@"ProviderHeroErrorBadge")
                        accentColor:accentColor
                         symbolName:@"wifi.exclamationmark"
              showsWaitingAnimation:NO];
        self.eyebrowLabel.text = kLang(@"ProviderStatusEyebrow");
        self.headlineLabel.text = kLang(@"ProviderStateErrorTitle");
        self.subtitleLabel.text = self.lastError.localizedDescription ?: kLang(@"ProviderStateErrorSubtitle");
        self.footerLabel.text = @"";
        self.footerLabel.hidden = YES;

        self.primaryButton.hidden = YES;
        self.secondaryButton.hidden = YES;
        [self pp_updateFooterBarVisibilityAnimated:YES];

        [self pp_renderIdentityCardWithEntries:@[]];
        [self pp_renderApplicationEntryCardWithAccentColor:accentColor
                                                   eyebrow:kLang(@"ProviderStartCardEyebrow")
                                                     title:kLang(@"ProviderStateErrorTitle")
                                                  subtitle:self.lastError.localizedDescription ?: kLang(@"ProviderStateErrorSubtitle")
                                               buttonTitle:kLang(@"ProviderRetryButton")
                                                  footnote:kLang(@"ProviderStateRetryHint")
                                                symbolName:@"arrow.clockwise"
                                         providerTypeTitles:@[]];
        [self pp_renderProviderCards:@[]];
        return;
    }

    PPProviderOnboardingState *state = self.state ?: [[PPProviderOnboardingState alloc] init];
    NSArray<NSNumber *> *eligibleTypes = state.eligibleProviderTypes;
    NSArray<NSString *> *eligibleTypeTitles = [self pp_providerTypeTitlesForEligibleTypes:eligibleTypes];
    BOOL hasPending = [self pp_hasApplicationStatus:kPPProviderStatusPendingValue];
    BOOL hasUnderReview = [self pp_hasApplicationStatus:kPPProviderStatusUnderReviewValue];
    BOOL hasRejected = [self pp_hasApplicationStatus:kPPProviderStatusRejectedValue];
    BOOL hasArchived = [self pp_hasApplicationStatus:kPPProviderStatusArchivedValue];

    UIColor *heroAccentColor = PPProviderStatusAccentColor();
    NSString *heroBadgeText = kLang(@"ProviderHeroReadyBadge");
    NSString *heroSymbolName = @"sparkles";
    NSString *entryCardTitle = kLang(@"ProviderStartCardReadyTitle");
    NSString *entryCardSubtitle = kLang(@"ProviderStartCardReadySubtitle");
    NSString *entryCardButtonTitle = eligibleTypes.count > 0 ? [self pp_primaryCTAForEligibleTypes:eligibleTypes] : nil;
    NSString *entryCardFootnote = eligibleTypes.count > 0 ? kLang(@"ProviderStateEligibleFootnote") : kLang(@"ProviderStateCompleteFootnote");
    NSString *entryCardSymbolName = @"arrow.up.right";
    self.eyebrowLabel.text = kLang(@"ProviderStatusEyebrow");

    if (state.isBlocked) {
        heroAccentColor = [UIColor ppError];
        heroBadgeText = kLang(@"ProviderHeroBlockedBadge");
        heroSymbolName = @"hand.raised.fill";
        self.headlineLabel.text = kLang(@"ProviderStateBlockedTitle");
        self.subtitleLabel.text = kLang(@"ProviderStateBlockedSubtitle");
        entryCardTitle = kLang(@"ProviderStartCardBlockedTitle");
        entryCardSubtitle = kLang(@"ProviderStartCardBlockedSubtitle");
        entryCardButtonTitle = nil;
        entryCardFootnote = kLang(@"ProviderStateBlockedFootnote");
        entryCardSymbolName = @"hand.raised.fill";
    } else if (hasArchived) {
        heroAccentColor = [UIColor ppTextSecondary];
        heroBadgeText = kLang(@"ProviderStatusArchived");
        heroSymbolName = @"archivebox.fill";
        self.headlineLabel.text = kLang(@"ProviderStatusArchived");
        self.subtitleLabel.text = kLang(@"ProviderStateRejectedSubtitle");
        entryCardTitle = kLang(@"ProviderStatusArchived");
        entryCardSubtitle = kLang(@"ProviderStateRejectedSubtitle");
        entryCardButtonTitle = eligibleTypes.count > 0 ? [self pp_primaryCTAForEligibleTypes:eligibleTypes] : nil;
        entryCardFootnote = kLang(@"ProviderStateRejectedFootnote");
        entryCardSymbolName = @"archivebox.fill";
    } else if (hasUnderReview || hasPending) {
        heroAccentColor = [UIColor ppWarning];
        heroBadgeText = kLang(@"ProviderHeroReviewBadge");
        heroSymbolName = @"clock.badge.checkmark.fill";
        self.headlineLabel.text = kLang(@"ProviderStateReviewTitle");
        self.subtitleLabel.text = kLang(@"ProviderStateReviewSubtitle");
        entryCardTitle = kLang(@"ProviderStartCardReviewTitle");
        entryCardSubtitle = eligibleTypes.count > 0 ? kLang(@"ProviderStartCardReviewMultiSubtitle") : kLang(@"ProviderStartCardReviewSubtitle");
        entryCardButtonTitle = eligibleTypes.count > 0 ? [self pp_primaryCTAForEligibleTypes:eligibleTypes] : nil;
        entryCardFootnote = eligibleTypes.count > 0 ? kLang(@"ProviderStateEligibleFootnote") : kLang(@"ProviderStateNoActionFootnote");
        entryCardSymbolName = @"clock.badge.checkmark.fill";
    } else if (hasRejected) {
        heroAccentColor = [UIColor ppError];
        heroBadgeText = kLang(@"ProviderHeroRejectedBadge");
        heroSymbolName = @"arrow.triangle.2.circlepath.circle.fill";
        self.headlineLabel.text = kLang(@"ProviderStateRejectedTitle");
        self.subtitleLabel.text = kLang(@"ProviderStateRejectedSubtitle");
        entryCardTitle = kLang(@"ProviderStartCardRejectedTitle");
        entryCardSubtitle = kLang(@"ProviderStartCardRejectedSubtitle");
        entryCardButtonTitle = eligibleTypes.count > 0 ? [self pp_primaryCTAForEligibleTypes:eligibleTypes] : nil;
        entryCardFootnote = kLang(@"ProviderStateRejectedFootnote");
        entryCardSymbolName = @"arrow.triangle.2.circlepath.circle.fill";
    } else {
        heroAccentColor = PPProviderStatusAccentColor();
        heroBadgeText = kLang(@"ProviderHeroReadyBadge");
        heroSymbolName = @"sparkles";
        self.headlineLabel.text = kLang(@"ProviderStateReadyTitle");
        self.subtitleLabel.text = kLang(@"ProviderStateReadySubtitle");
        if (eligibleTypes.count == 0) {
            entryCardTitle = kLang(@"ProviderStartCardCompleteTitle");
            entryCardSubtitle = kLang(@"ProviderStartCardCompleteSubtitle");
            entryCardButtonTitle = nil;
            entryCardFootnote = kLang(@"ProviderStateCompleteFootnote");
            entryCardSymbolName = @"checkmark.seal.fill";
        }
    }

    [self pp_applyHeroBadgeText:heroBadgeText
                    accentColor:heroAccentColor
                     symbolName:heroSymbolName
          showsWaitingAnimation:(hasUnderReview || hasPending)];

    NSMutableArray<NSDictionary<NSString *, NSString *> *> *identityEntries = [NSMutableArray array];
    if (state.displayName.length > 0) {
        [identityEntries addObject:@{
            @"title": kLang(@"ProviderIdentityName"),
            @"value": state.displayName
        }];
    }
    if (state.email.length > 0) {
        [identityEntries addObject:@{
            @"title": kLang(@"ProviderIdentityEmail"),
            @"value": state.email
        }];
    }
    if (state.phone.length > 0) {
        [identityEntries addObject:@{
            @"title": kLang(@"ProviderIdentityPhone"),
            @"value": state.phone
        }];
    }
    [self pp_renderIdentityCardWithEntries:identityEntries.copy];

    NSArray<UIView *> *providerCards = [self pp_providerActivityCardsForState:state];
    BOOL showsBottomApplicationAction = (providerCards.count > 0 &&
                                         eligibleTypes.count > 0 &&
                                         !state.isBlocked);
    if (showsBottomApplicationAction) {
        entryCardButtonTitle = nil;
    }

    [self pp_renderApplicationEntryCardWithAccentColor:heroAccentColor
                                               eyebrow:kLang(@"ProviderStartCardEyebrow")
                                                 title:entryCardTitle
                                              subtitle:entryCardSubtitle
                                           buttonTitle:entryCardButtonTitle
                                              footnote:entryCardFootnote
                                            symbolName:entryCardSymbolName
                                     providerTypeTitles:(state.isBlocked ? @[] : eligibleTypeTitles)];

    [self pp_renderProviderCards:providerCards];
    [self pp_configureApplicationsActionButtonWithTitle:((providerCards.count > 0 &&
                                                          eligibleTypes.count > 0 &&
                                                          !state.isBlocked) ? [self pp_primaryCTAForEligibleTypes:eligibleTypes] : nil)
                                            accentColor:heroAccentColor];

    self.primaryButton.hidden = YES;
    self.secondaryButton.hidden = YES;
    self.footerLabel.text = @"";
    self.footerLabel.hidden = YES;

    [self pp_updateFooterBarVisibilityAnimated:YES];

    BOOL hasReviewLifecycle = [self pp_hasReviewLifecycleInState:state];
    if (self.prefersAutoPresentBecomeProvider &&
        !self.didAutoPresentBecomeProvider &&
        !hasReviewLifecycle &&
        !state.hasAnyLifecycleRecord &&
        eligibleTypes.count > 0) {
        self.didAutoPresentBecomeProvider = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self primaryButtonTapped];
        });
    }
}

- (BOOL)pp_hasApplicationStatus:(NSString *)status {
    for (PPProviderApplication *application in self.state.applications) {
        if (!PPProviderTypeIsEnabledInProApp(application.providerType)) {
            continue;
        }
        NSString *applicationStatus = application.status.lowercaseString ?: @"";
        if ([applicationStatus isEqualToString:status]) {
            return YES;
        }
    }
    return NO;
}

- (void)pp_applyHeroBadgeText:(NSString *)badgeText
                  accentColor:(UIColor *)accentColor
                   symbolName:(NSString *)symbolName
        showsWaitingAnimation:(BOOL)showsWaitingAnimation {
    self.statusPillLabel.text = badgeText;
    self.statusPillLabel.textColor = accentColor;
    self.statusPillLabel.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    self.statusPillLabel.layer.borderColor = [accentColor colorWithAlphaComponent:0.14].CGColor;
    self.eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];

    self.heroStageView.backgroundColor = [accentColor colorWithAlphaComponent:0.08];
    self.heroStageView.layer.borderColor = [accentColor colorWithAlphaComponent:0.14].CGColor;
    self.heroStageCoreView.backgroundColor = [accentColor colorWithAlphaComponent:0.08];

    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:21.0
                                                                                                weight:UIImageSymbolWeightSemibold];
    self.heroStageIconView.image = [UIImage systemImageNamed:symbolName withConfiguration:symbolConfig];
    self.heroStageIconView.tintColor = accentColor;
    [self pp_setHeroWaitingAnimationVisible:showsWaitingAnimation];
}

- (NSString *)pp_primaryCTAForEligibleTypes:(NSArray<NSNumber *> *)eligibleTypes {
    if (eligibleTypes.count == 1) {
        return [NSString stringWithFormat:kLang(@"ProviderApplySingleTypeButtonFormat"),
                                          [PPProviderApplicationManager localizedTitleForProviderType:eligibleTypes.firstObject.integerValue]];
    }
    return kLang(@"ProviderApplyGenericButton");
}

- (NSArray<NSString *> *)pp_providerTypeTitlesForEligibleTypes:(NSArray<NSNumber *> *)eligibleTypes {
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSNumber *typeValue in eligibleTypes) {
        NSString *title = [PPProviderApplicationManager localizedTitleForProviderType:typeValue.integerValue];
        if (title.length > 0) {
            [titles addObject:title];
        }
    }
    return titles.copy;
}

- (NSArray<UIView *> *)pp_providerActivityCardsForState:(PPProviderOnboardingState *)state {
    NSMutableArray<UIView *> *cards = [NSMutableArray array];
    NSMutableSet<NSString *> *applicationTypes = [NSMutableSet set];
    for (PPProviderApplication *application in state.applications) {
        if (application.providerType == PPProviderTypeUnspecified) {
            continue;
        }
        if (!PPProviderTypeIsEnabledInProApp(application.providerType)) {
            continue;
        }
        [cards addObject:[self pp_cardForApplication:application]];
        [applicationTypes addObject:PPProviderTypeIdentifier(application.providerType)];
    }
    for (NSNumber *typeValue in @[@(PPProviderTypeVet), @(PPProviderTypePharmacy), @(PPProviderTypeDeliverySubscription), @(PPProviderTypeDeliveryCompany), @(PPProviderTypeService), @(PPProviderTypeMarketplace)]) {
        PPProviderType type = typeValue.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) {
            continue;
        }
        BOOL isActive = [state isActiveForType:type];
        if (isActive && ![applicationTypes containsObject:PPProviderTypeIdentifier(type)]) {
            [cards addObject:[self pp_cardForType:type]];
        }
    }
    return cards.copy;
}

- (void)pp_renderApplicationEntryCardWithAccentColor:(UIColor *)accentColor
                                             eyebrow:(NSString *)eyebrow
                                               title:(NSString *)title
                                            subtitle:(NSString *)subtitle
                                         buttonTitle:(NSString * _Nullable)buttonTitle
                                            footnote:(NSString * _Nullable)footnote
                                          symbolName:(NSString *)symbolName
                                   providerTypeTitles:(NSArray<NSString *> *)providerTypeTitles {
    for (UIView *subview in self.applicationEntryCard.subviews.copy) {
        [subview removeFromSuperview];
    }

    self.applicationEntryCard.layer.borderColor = [accentColor colorWithAlphaComponent:0.10].CGColor;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.applicationEntryCard addSubview:iconSurface];

    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                                weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName
                                                                         withConfiguration:symbolConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    [iconSurface addSubview:iconView];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [Styling fontBold:11.0];
    eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrowLabel.text = eyebrow;
    [self.applicationEntryCard addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:23.0];
    titleLabel.textColor = PPProviderStatusPrimaryTextColor();
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    [self.applicationEntryCard addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:14.0];
    subtitleLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.94];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.text = subtitle;
    [self.applicationEntryCard addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:self.applicationEntryCard.topAnchor constant:20.0],
        [iconSurface.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],
        [iconSurface.widthAnchor constraintEqualToConstant:48.0],
        [iconSurface.heightAnchor constraintEqualToConstant:48.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:self.applicationEntryCard.topAnchor constant:20.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:iconSurface.leadingAnchor constant:-14.0],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],
    ]];

    UIView *previousView = subtitleLabel;

    if (providerTypeTitles.count > 0) {
        UILabel *typeLabel = [[UILabel alloc] init];
        typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        typeLabel.font = [Styling fontMedium:11.0];
        typeLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.82];
        typeLabel.textAlignment = Language.alignmentForCurrentLanguage;
        typeLabel.text = kLang(@"ProviderStartCardAvailableTypes");
        [self.applicationEntryCard addSubview:typeLabel];

        UIStackView *pillsStack = [[UIStackView alloc] init];
        pillsStack.translatesAutoresizingMaskIntoConstraints = NO;
        pillsStack.axis = UILayoutConstraintAxisVertical;
        pillsStack.alignment = UIStackViewAlignmentLeading;
        pillsStack.spacing = 8.0;
        pillsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self.applicationEntryCard addSubview:pillsStack];

        for (NSString *typeTitle in providerTypeTitles) {
            PPPaddingLabel *pillLabel = [[PPPaddingLabel alloc] init];
            pillLabel.font = [Styling fontBold:11.0];
            pillLabel.textInsets = UIEdgeInsetsMake(8, 12, 8, 12);
            pillLabel.textColor = accentColor;
            pillLabel.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
            pillLabel.layer.cornerRadius = 14.0;
            pillLabel.layer.cornerCurve = kCACornerCurveContinuous;
            pillLabel.clipsToBounds = YES;
            pillLabel.text = typeTitle;
            [pillsStack addArrangedSubview:pillLabel];
        }

        [NSLayoutConstraint activateConstraints:@[
            [typeLabel.topAnchor constraintEqualToAnchor:previousView.bottomAnchor constant:16.0],
            [typeLabel.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
            [typeLabel.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],

            [pillsStack.topAnchor constraintEqualToAnchor:typeLabel.bottomAnchor constant:10.0],
            [pillsStack.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
            [pillsStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],
        ]];
        previousView = pillsStack;
    }

    if (buttonTitle.length > 0) {
        UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        actionButton.backgroundColor = accentColor;
        actionButton.layer.cornerRadius = 22.0;
        actionButton.layer.cornerCurve = kCACornerCurveContinuous;
        actionButton.titleLabel.font = [Styling fontBold:16.0];
        actionButton.contentEdgeInsets = UIEdgeInsetsMake(16.0, 18.0, 16.0, 18.0);
        actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [actionButton setTitle:buttonTitle forState:UIControlStateNormal];
        [actionButton addTarget:self action:@selector(primaryButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [PPButtonHelper attachTapAnimationToButton:actionButton style:PPButtonAnimationStyleDefault];
        [self.applicationEntryCard addSubview:actionButton];

        [NSLayoutConstraint activateConstraints:@[
            [actionButton.topAnchor constraintEqualToAnchor:previousView.bottomAnchor constant:18.0],
            [actionButton.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
            [actionButton.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],
            [actionButton.heightAnchor constraintEqualToConstant:54.0],
        ]];
        previousView = actionButton;
    }

    if (footnote.length > 0) {
        UILabel *footnoteLabel = [[UILabel alloc] init];
        footnoteLabel.translatesAutoresizingMaskIntoConstraints = NO;
        footnoteLabel.font = [Styling fontMedium:12.0];
        footnoteLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.88];
        footnoteLabel.numberOfLines = 0;
        footnoteLabel.textAlignment = Language.alignmentForCurrentLanguage;
        footnoteLabel.text = footnote;
        [self.applicationEntryCard addSubview:footnoteLabel];

        [NSLayoutConstraint activateConstraints:@[
            [footnoteLabel.topAnchor constraintEqualToAnchor:previousView.bottomAnchor constant:12.0],
            [footnoteLabel.leadingAnchor constraintEqualToAnchor:self.applicationEntryCard.leadingAnchor constant:20.0],
            [footnoteLabel.trailingAnchor constraintEqualToAnchor:self.applicationEntryCard.trailingAnchor constant:-20.0],
            [footnoteLabel.bottomAnchor constraintEqualToAnchor:self.applicationEntryCard.bottomAnchor constant:-20.0],
        ]];
    } else {
        [previousView.bottomAnchor constraintEqualToAnchor:self.applicationEntryCard.bottomAnchor constant:-20.0].active = YES;
    }
}

#pragma mark - Identity

- (void)pp_renderIdentityCardWithEntries:(NSArray<NSDictionary<NSString *, NSString *> *> *)entries {
    for (UIView *subview in self.identityCard.subviews.copy) {
        [subview removeFromSuperview];
    }

    UIColor *accentColor = PPProviderStatusAccentColor();
    self.identityCard.layer.borderColor = [accentColor colorWithAlphaComponent:0.10].CGColor;

    PPPaddingLabel *badgeLabel = [[PPPaddingLabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [Styling fontBold:11.0];
    badgeLabel.textInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    badgeLabel.textColor = accentColor;
    badgeLabel.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    badgeLabel.layer.cornerRadius = 14.0;
    badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    badgeLabel.clipsToBounds = YES;
    badgeLabel.text = kLang(@"ProviderIdentitySignedInBadge");
    [self.identityCard addSubview:badgeLabel];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 22.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.identityCard addSubview:iconSurface];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                              weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.seal.fill"
                                                                         withConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    [iconSurface addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:23.0];
    titleLabel.textColor = PPProviderStatusPrimaryTextColor();
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 0;
    titleLabel.text = kLang(@"ProviderIdentitySignedInTitle");
    [self.identityCard addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [Styling fontRegular:14.0];
    subtitleLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"ProviderIdentitySignedInSubtitle");
    [self.identityCard addSubview:subtitleLabel];

    UILabel *detailsLabel = [[UILabel alloc] init];
    detailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailsLabel.font = [Styling fontBold:12.0];
    detailsLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    detailsLabel.textAlignment = Language.alignmentForCurrentLanguage;
    detailsLabel.text = kLang(@"ProviderIdentityCardTitle");
    [self.identityCard addSubview:detailsLabel];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.identityCard addSubview:stack];

    if (entries.count == 0) {
        UILabel *placeholderLabel = [[UILabel alloc] init];
        placeholderLabel.font = [Styling fontRegular:14.0];
        placeholderLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
        placeholderLabel.numberOfLines = 0;
        placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
        placeholderLabel.text = kLang(@"ProviderIdentityLoading");
        [stack addArrangedSubview:placeholderLabel];
    } else {
        [entries enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
            (void)stop;

            UIView *row = [[UIView alloc] init];
            row.translatesAutoresizingMaskIntoConstraints = NO;

            UILabel *keyLabel = [[UILabel alloc] init];
            keyLabel.translatesAutoresizingMaskIntoConstraints = NO;
            keyLabel.font = [Styling fontMedium:11.0];
            keyLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.84];
            keyLabel.textAlignment = Language.alignmentForCurrentLanguage;
            keyLabel.text = entry[@"title"] ?: @"";
            [row addSubview:keyLabel];

            UILabel *valueLabel = [[UILabel alloc] init];
            valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            valueLabel.font = [Styling fontBold:15.0];
            valueLabel.textColor = PPProviderStatusPrimaryTextColor();
            valueLabel.numberOfLines = 0;
            valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
            valueLabel.text = entry[@"value"] ?: @"";
            [row addSubview:valueLabel];

            [NSLayoutConstraint activateConstraints:@[
                [keyLabel.topAnchor constraintEqualToAnchor:row.topAnchor],
                [keyLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [keyLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],

                [valueLabel.topAnchor constraintEqualToAnchor:keyLabel.bottomAnchor constant:4.0],
                [valueLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [valueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
                [valueLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            ]];

            [stack addArrangedSubview:row];

            if (idx + 1 < entries.count) {
                UIView *separator = [[UIView alloc] init];
                separator.translatesAutoresizingMaskIntoConstraints = NO;
                separator.backgroundColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.08];
                [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale].active = YES;
                [stack addArrangedSubview:separator];
            }
        }];
    }

    [NSLayoutConstraint activateConstraints:@[
        [badgeLabel.topAnchor constraintEqualToAnchor:self.identityCard.topAnchor constant:20.0],
        [badgeLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:20.0],
        [badgeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:iconSurface.leadingAnchor constant:-12.0],

        [iconSurface.topAnchor constraintEqualToAnchor:self.identityCard.topAnchor constant:20.0],
        [iconSurface.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-20.0],
        [iconSurface.widthAnchor constraintEqualToConstant:44.0],
        [iconSurface.heightAnchor constraintEqualToConstant:44.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:badgeLabel.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:20.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:20.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-20.0],

        [detailsLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:16.0],
        [detailsLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:20.0],
        [detailsLabel.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-20.0],

        [stack.topAnchor constraintEqualToAnchor:detailsLabel.bottomAnchor constant:12.0],
        [stack.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:20.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-20.0],
        [stack.bottomAnchor constraintEqualToAnchor:self.identityCard.bottomAnchor constant:-20.0],
    ]];
}

#pragma mark - Provider Cards

- (void)pp_renderProviderCards:(NSArray<UIView *> *)cards {
    for (UIView *view in self.statusCardsStack.arrangedSubviews.copy) {
        [self.statusCardsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    self.providerCardsSectionLabel.hidden = (cards.count == 0);
    self.statusCardsStack.hidden = (cards.count == 0);

    for (UIView *card in cards) {
        [self.statusCardsStack addArrangedSubview:card];
    }
}

- (void)pp_configureApplicationsActionButtonWithTitle:(NSString * _Nullable)title
                                          accentColor:(UIColor *)accentColor {
    BOOL shouldShow = title.length > 0;
    self.applicationsActionButton.hidden = !shouldShow;
    if (!shouldShow) {
        return;
    }

    self.applicationsActionButton.backgroundColor = accentColor;
    [self.applicationsActionButton setTitle:title forState:UIControlStateNormal];
    [self.applicationsActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}

- (UIView *)pp_cardForApplication:(PPProviderApplication *)application {
    return [self pp_cardForType:application.providerType
                    application:application
                        profile:nil
                       isActive:NO];
}

- (UIView *)pp_cardForType:(PPProviderType)type {
    return [self pp_cardForType:type
                    application:[self.state applicationForType:type]
                        profile:[self.state profileForType:type]
                       isActive:[self.state isActiveForType:type]];
}

- (UIView *)pp_cardForType:(PPProviderType)type
               application:(PPProviderApplication *)application
                   profile:(PPProviderProfile *)profile
                  isActive:(BOOL)isActive {

    NSString *statusValue = isActive ? kPPProviderProfileStatusActiveValue : (application.status.length > 0 ? application.status : @"not_applied");
    NSString *statusText = [PPProviderApplicationManager localizedStatusTitle:statusValue];
    UIColor *accentColor = PPProviderStatusAccentColor();
    if ([statusValue isEqualToString:kPPProviderStatusRejectedValue]) {
        accentColor = [UIColor ppError];
    } else if ([statusValue isEqualToString:kPPProviderStatusArchivedValue]) {
        accentColor = [UIColor ppTextSecondary];
    } else if ([statusValue isEqualToString:kPPProviderStatusPendingValue] || [statusValue isEqualToString:kPPProviderStatusUnderReviewValue]) {
        accentColor = [UIColor ppWarning];
    } else if ([statusValue isEqualToString:kPPProviderProfileStatusActiveValue]) {
        accentColor = [UIColor ppSuccess];
    }

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = PPProviderStatusSurfaceColor();
    card.layer.cornerRadius = 28.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [accentColor colorWithAlphaComponent:0.10].CGColor;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 22.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                              weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[PPProviderApplicationManager symbolNameForProviderType:type]
                                                                         withConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    [iconSurface addSubview:iconView];

    PPPaddingLabel *statusLabel = [[PPPaddingLabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = [Styling fontBold:11.0];
    statusLabel.textInsets = UIEdgeInsetsMake(7, 12, 7, 12);
    statusLabel.textColor = accentColor;
    statusLabel.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    statusLabel.layer.cornerRadius = 14.0;
    statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    statusLabel.clipsToBounds = YES;
    statusLabel.text = statusText;
    [card addSubview:statusLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [Styling fontBold:18.0];
    titleLabel.textColor = PPProviderStatusPrimaryTextColor();
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.numberOfLines = 2;
    titleLabel.text = [PPProviderApplicationManager localizedTitleForProviderType:type];
    [card addSubview:titleLabel];

    NSString *planName = isActive ? profile.localizedPlanName : application.localizedPlanName;
    UILabel *summaryLabel = [[UILabel alloc] init];
    summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    summaryLabel.font = [Styling fontMedium:13.0];
    summaryLabel.textColor = planName.length > 0 ? accentColor : [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.94];
    summaryLabel.textAlignment = Language.alignmentForCurrentLanguage;
    summaryLabel.numberOfLines = 0;
    summaryLabel.text = planName.length > 0 ? [NSString stringWithFormat:@"%@ · %@", kLang(@"ProviderCardPlanLabel"), planName] : [PPProviderApplicationManager localizedSubtitleForProviderType:type];
    [card addSubview:summaryLabel];

    UILabel *notesLabel = [[UILabel alloc] init];
    notesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    notesLabel.font = [Styling fontRegular:13.0];
    notesLabel.textColor = [PPProviderStatusSecondaryTextColor() colorWithAlphaComponent:0.92];
    notesLabel.numberOfLines = 0;
    notesLabel.textAlignment = Language.alignmentForCurrentLanguage;
    notesLabel.hidden = (application.reviewNotes.length == 0);
    notesLabel.text = application.reviewNotes.length > 0 ? [NSString stringWithFormat:@"%@ · %@", kLang(@"ProviderCardNotesLabel"), application.reviewNotes] : @"";
    [card addSubview:notesLabel];

    NSLayoutConstraint *notesBottomConstraint = [notesLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0];
    notesBottomConstraint.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *notesHeightConstraint = [notesLabel.heightAnchor constraintEqualToConstant:0.0];
    notesHeightConstraint.active = (application.reviewNotes.length == 0);

    NSLayoutConstraint *summaryBottomConstraint = [summaryLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0];
    summaryBottomConstraint.priority = UILayoutPriorityDefaultLow;

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:44.0],
        [iconSurface.heightAnchor constraintEqualToConstant:44.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [statusLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [statusLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:statusLabel.leadingAnchor constant:-12.0],

        [summaryLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [summaryLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [summaryLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [notesLabel.topAnchor constraintEqualToAnchor:summaryLabel.bottomAnchor constant:(application.reviewNotes.length > 0 ? 8.0 : 0.0)],
        [notesLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [notesLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        notesBottomConstraint,
        summaryBottomConstraint,
    ]];

    return card;
}

#pragma mark - Buttons

- (void)pp_applyPrimaryButtonStyleWithAccentColor:(UIColor *)accentColor {
    self.primaryButton.backgroundColor = accentColor;
    [self.primaryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}

- (void)pp_applySecondaryButtonStyle {
    UIColor *accentColor = PPProviderStatusAccentColor();
    self.secondaryButton.backgroundColor = [accentColor colorWithAlphaComponent:0.08];
    self.secondaryButton.layer.borderColor = [accentColor colorWithAlphaComponent:0.10].CGColor;
    [self.secondaryButton setTitleColor:accentColor forState:UIControlStateNormal];
}

- (void)pp_updateFooterBarVisibilityAnimated:(BOOL)animated {
    BOOL hasPrimary = !self.primaryButton.hidden;
    BOOL hasSecondary = !self.secondaryButton.hidden;
    CGFloat targetHeight = 0.0;
    if (hasPrimary || hasSecondary) {
        if (hasPrimary && hasSecondary) {
            targetHeight = 132.0;
        } else if (hasPrimary) {
            targetHeight = 86.0;
        } else {
            targetHeight = 70.0;
        }
    }

    self.secondaryButtonTopToPrimaryConstraint.active = hasPrimary;
    self.secondaryButtonTopToFooterConstraint.active = !hasPrimary;

    void (^updates)(void) = ^{
        self.footerBar.alpha = targetHeight > 0.0 ? 1.0 : 0.0;
        self.footerBarHeightConstraint.constant = targetHeight;
        [self.view layoutIfNeeded];
    };

    if (animated && self.view.window) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.24 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:updates completion:nil];
    } else {
        updates();
    }
}

- (void)pp_closeTapped {
    if (self.isClosing) {
        return;
    }
    self.isClosing = YES;
    [self pp_stopObservingState];

    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UIViewController *rootController = self.view.window.rootViewController;
    if (rootController.presentedViewController) {
        [rootController dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    // Fallback: if this controller is the root of the window, sign out so the user can log in to another account or exit
    [[UserManager shared] signOut];
    self.isClosing = NO;
}

- (void)primaryButtonTapped {
    if (self.lastError) {
        self.isLoading = YES;
        self.lastError = nil;
        [self pp_applyLoadingState];
        [self pp_startObservingState];
        return;
    }

    NSArray<NSNumber *> *eligibleTypes = self.state.eligibleProviderTypes;
    if (eligibleTypes.count == 0) {
        return;
    }

    PPProviderType preferredType = eligibleTypes.firstObject.integerValue;
    PPBecomeProviderBottomSheetViewController *controller = [[PPBecomeProviderBottomSheetViewController alloc] initWithState:self.state
                                                                                                           eligibleProviderTypes:eligibleTypes
                                                                                                           preferredProviderType:preferredType];
    controller.delegate = self;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    nav.view.backgroundColor = PPProviderStatusBackgroundColor();

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)secondaryButtonTapped {
    [self pp_startObservingState];
}

- (void)becomeProviderBottomSheetDidSubmitApplication:(PPBecomeProviderBottomSheetViewController *)controller {
    (void)controller;
    self.prefersAutoPresentBecomeProvider = NO;
}

#pragma mark - Navigation

- (void)pp_transitionToDashboardIfNeeded {
    if (self.didTransitionToDashboard) {
        return;
    }
    self.didTransitionToDashboard = YES;
    [self pp_stopObservingState];
    [PPToast toast:kLang(@"ProviderActivatedToast") style:PPToastStyleSuccess haptic:YES duration:2.0];
    AdminDashboardViewController *dashboard = [[AdminDashboardViewController alloc] init];
    [self.navigationController setViewControllers:@[dashboard] animated:YES];
}

#pragma mark - Animation

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didRunEntranceAnimation) {
        return;
    }
    self.didRunEntranceAnimation = YES;

    NSArray<UIView *> *targets = [self pp_entranceAnimationTargets];
    CGFloat offset = 18.0;
    for (UIView *view in targets) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, offset);
        offset += 8.0;
    }

    [targets enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:0.5
                              delay:0.04 * idx
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (NSArray<UIView *> *)pp_entranceAnimationTargets {
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (UIView *view in self.contentStack.arrangedSubviews) {
        [views addObject:view];
    }
    [views addObject:self.footerBar];
    return views.copy;
}

- (void)pp_setHeroWaitingAnimationVisible:(BOOL)visible {
    if (!visible) {
        [self.heroStageWaitingAnimationView pause];
        self.heroStageWaitingAnimationView.alpha = 0;
        self.heroStageIconView.hidden = NO;
        return;
    }

    self.heroStageIconView.hidden = YES;
    self.heroStageWaitingAnimationView.alpha = 1;
    self.heroStageWaitingAnimationView.animationSpeed = 0.5f;
    self.heroStageWaitingAnimationView.loopAnimation = YES;
    [self.heroStageWaitingAnimationView play];
}

@end
