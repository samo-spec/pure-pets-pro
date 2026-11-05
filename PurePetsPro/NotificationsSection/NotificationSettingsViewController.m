//
//  NotificationSettingsViewController.m
//  PurePetsPro
//
//  Reinvented from absolute first principles for iPhone & iPad.
//  Category-defining Pro Notification Command Cockpit & Gateway Telemetry.
//

#import "NotificationSettingsViewController.h"
#import "Language.h"
#import "PPButtonHelper.h"
#import "Styling.h"
#import "UIViewController+PPNavBar.h"
#import "PPAlertHelper.h"
#import <UserNotifications/UserNotifications.h>

static NSString * const kPPProNotifMasterPreferenceKey   = @"pp_notif_master_enabled";
static NSString * const kPPProNotifSoundPreferenceKey    = @"pp_notif_sound_enabled";
static NSString * const kPPProNotifCategoryOrdersKey     = @"pp_notif_cat_order";
static NSString * const kPPProNotifCategoryDeliveryKey   = @"pp_notif_cat_delivery";
static NSString * const kPPProNotifCategoryReviewKey     = @"pp_notif_cat_review";
static NSString * const kPPProNotifCategoryWarningKey    = @"pp_notif_cat_warning";
static NSString * const kPPProNotifCategoryGeneralKey    = @"pp_notif_cat_general";

#ifndef PrimaryTextClr
#define PrimaryTextClr (AppPrimaryTextClr ?: UIColor.labelColor)
#endif

#ifndef SeconderyTextClr
#define SeconderyTextClr (AppSecondaryTextClr ?: UIColor.secondaryLabelColor)
#endif

#ifndef PPFontBold
#define PPFontBold(size) ([Styling fontBold:(size)] ?: [UIFont systemFontOfSize:(size) weight:UIFontWeightBold])
#endif

#ifndef PPFontMedium
#define PPFontMedium(size) ([Styling fontMedium:(size)] ?: [UIFont systemFontOfSize:(size) weight:UIFontWeightMedium])
#endif

#ifndef PPFontRegular
#define PPFontRegular(size) ([Styling fontRegular:(size)] ?: [UIFont systemFontOfSize:(size) weight:UIFontWeightRegular])
#endif

@interface NotificationSettingsViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, UIPointerInteractionDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;

// Layout Containers
@property (nonatomic, strong) UIView *canvasContainer;
@property (nonatomic, strong) UIStackView *iphoneStack;
@property (nonatomic, strong) UIView *ipadContainer;
@property (nonatomic, strong) UIStackView *ipadLeadingTower;
@property (nonatomic, strong) UIStackView *ipadTrailingCanvas;

@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *iphoneConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *ipadConstraints;
@property (nonatomic, assign) BOOL isIPadLayoutActive;

// UI Components
@property (nonatomic, strong) UIView *heroSection;
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UIView *statusBeaconDot;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusTitleLabel;
@property (nonatomic, strong) UILabel *statusBodyLabel;
@property (nonatomic, strong) UIButton *statusActionButton;
@property (nonatomic, strong) UIButton *diagnosticTestButton;

@property (nonatomic, strong) UIView *primaryControlsCard;
@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UISwitch *soundSwitch;

@property (nonatomic, strong) UIView *categorySection;
@property (nonatomic, strong) UILabel *categorySummaryPill;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UISwitch *> *categorySwitches;
@property (nonatomic, strong) NSMutableArray<UIView *> *categoryRows;
@property (nonatomic, strong) UILabel *footnoteLabel;

@property (nonatomic, assign) UNAuthorizationStatus authorizationStatus;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;

@end

@implementation NotificationSettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.categorySwitches = [NSMutableDictionary dictionary];
    self.categoryRows = [NSMutableArray array];
    self.authorizationStatus = UNAuthorizationStatusNotDetermined;
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self pp_setupHierarchy];
    [self pp_refreshSystemPermissionState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"NotificationSettings") showBack:YES];
    [self pp_refreshSystemPermissionState];
    [self pp_applySwitchStatesAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateLayoutForCurrentGeometry];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = AppBackgroundClr;
        [self pp_updateStatusCardForCurrentAuthorization];
    }
    if (self.traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass) {
        [self pp_updateLayoutForCurrentGeometry];
    }
}

#pragma mark - Adaptive iPhone & iPad Layout Architecture

- (void)pp_setupHierarchy {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Build Reusable Section Components Once
    self.heroSection = [self pp_buildHeroSection];
    self.statusCard = [self pp_buildStatusCard];
    self.primaryControlsCard = [self pp_buildPrimaryControlsCard];
    self.categorySection = [self pp_buildCategorySection];
    self.footnoteLabel = [self pp_buildFootnoteLabel];

    // 1. iPhone Stack Container
    self.iphoneStack = [[UIStackView alloc] init];
    self.iphoneStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.iphoneStack.axis = UILayoutConstraintAxisVertical;
    self.iphoneStack.alignment = UIStackViewAlignmentFill;
    self.iphoneStack.distribution = UIStackViewDistributionFill;
    self.iphoneStack.spacing = 16.0;
    self.iphoneStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.iphoneStack];

    // 2. iPad Split Container
    self.ipadContainer = [[UIView alloc] init];
    self.ipadContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipadContainer.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.ipadContainer];

    self.ipadLeadingTower = [[UIStackView alloc] init];
    self.ipadLeadingTower.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipadLeadingTower.axis = UILayoutConstraintAxisVertical;
    self.ipadLeadingTower.alignment = UIStackViewAlignmentFill;
    self.ipadLeadingTower.distribution = UIStackViewDistributionFill;
    self.ipadLeadingTower.spacing = 16.0;
    self.ipadLeadingTower.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.ipadContainer addSubview:self.ipadLeadingTower];

    self.ipadTrailingCanvas = [[UIStackView alloc] init];
    self.ipadTrailingCanvas.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipadTrailingCanvas.axis = UILayoutConstraintAxisVertical;
    self.ipadTrailingCanvas.alignment = UIStackViewAlignmentFill;
    self.ipadTrailingCanvas.distribution = UIStackViewDistributionFill;
    self.ipadTrailingCanvas.spacing = 16.0;
    self.ipadTrailingCanvas.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.ipadContainer addSubview:self.ipadTrailingCanvas];

    // Constraints Sets
    self.iphoneConstraints = @[
        [self.iphoneStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16.0],
        [self.iphoneStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18.0],
        [self.iphoneStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18.0],
        [self.iphoneStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-32.0],
    ];

    self.ipadConstraints = @[
        [self.ipadContainer.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:24.0],
        [self.ipadContainer.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:28.0],
        [self.ipadContainer.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-28.0],
        [self.ipadContainer.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-40.0],

        [self.ipadLeadingTower.topAnchor constraintEqualToAnchor:self.ipadContainer.topAnchor],
        [self.ipadLeadingTower.leadingAnchor constraintEqualToAnchor:self.ipadContainer.leadingAnchor],
        [self.ipadLeadingTower.widthAnchor constraintEqualToConstant:370.0],
        [self.ipadLeadingTower.bottomAnchor constraintLessThanOrEqualToAnchor:self.ipadContainer.bottomAnchor],

        [self.ipadTrailingCanvas.topAnchor constraintEqualToAnchor:self.ipadContainer.topAnchor],
        [self.ipadTrailingCanvas.leadingAnchor constraintEqualToAnchor:self.ipadLeadingTower.trailingAnchor constant:24.0],
        [self.ipadTrailingCanvas.trailingAnchor constraintEqualToAnchor:self.ipadContainer.trailingAnchor],
        [self.ipadTrailingCanvas.bottomAnchor constraintEqualToAnchor:self.ipadContainer.bottomAnchor],
    ];

    // Initial Layout Setup
    [self pp_applyLayoutMode:NO];
}

- (void)pp_updateLayoutForCurrentGeometry {
    BOOL shouldBeIPad = (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
                         self.view.bounds.size.width >= 700.0);

    if (shouldBeIPad != self.isIPadLayoutActive) {
        [self pp_applyLayoutMode:shouldBeIPad];
    }
}

- (void)pp_applyLayoutMode:(BOOL)isIPad {
    self.isIPadLayoutActive = isIPad;

    // Cleanly detach views from previous parent
    [self.heroSection removeFromSuperview];
    [self.statusCard removeFromSuperview];
    [self.primaryControlsCard removeFromSuperview];
    [self.categorySection removeFromSuperview];
    [self.footnoteLabel removeFromSuperview];

    if (isIPad) {
        [NSLayoutConstraint deactivateConstraints:self.iphoneConstraints];
        self.iphoneStack.hidden = YES;
        self.ipadContainer.hidden = NO;

        // iPad Leading Tower: Hero, Status Gateway, Master Controls
        [self.ipadLeadingTower addArrangedSubview:self.heroSection];
        [self.ipadLeadingTower addArrangedSubview:self.statusCard];
        [self.ipadLeadingTower addArrangedSubview:self.primaryControlsCard];

        // iPad Trailing Canvas: Channels Matrix + Footnote
        [self.ipadTrailingCanvas addArrangedSubview:self.categorySection];
        [self.ipadTrailingCanvas addArrangedSubview:self.footnoteLabel];

        [NSLayoutConstraint activateConstraints:self.ipadConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:self.ipadConstraints];
        self.ipadContainer.hidden = YES;
        self.iphoneStack.hidden = NO;

        // iPhone Single Vertical Deck
        [self.iphoneStack addArrangedSubview:self.heroSection];
        [self.iphoneStack addArrangedSubview:self.statusCard];
        [self.iphoneStack addArrangedSubview:self.primaryControlsCard];
        [self.iphoneStack addArrangedSubview:self.categorySection];
        [self.iphoneStack addArrangedSubview:self.footnoteLabel];

        [NSLayoutConstraint activateConstraints:self.iphoneConstraints];
    }

    [self.view layoutIfNeeded];
}

#pragma mark - Section Builders

- (UIView *)pp_buildHeroSection {
    UIView *card = [self pp_surfaceCardWithCornerRadius:24.0];
    card.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 23.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.badge.fill"
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    iconView.isAccessibilityElement = NO;
    [iconSurface addSubview:iconView];

    UIView *eyebrowCapsule = [[UIView alloc] init];
    eyebrowCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowCapsule.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
    eyebrowCapsule.layer.cornerRadius = 10.0;
    eyebrowCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:eyebrowCapsule];

    UILabel *eyebrow = [self pp_labelWithText:kLang(@"NotificationSettings_Eyebrow")
                                         font:PPFontBold(10.5)
                                        color:AppPrimaryClr
                                        lines:1];
    eyebrow.text = [eyebrow.text uppercaseString];
    [eyebrowCapsule addSubview:eyebrow];

    UILabel *title = [self pp_labelWithText:kLang(@"NotificationSettings_HeroTitle")
                                       font:PPFontBold(24.0)
                                      color:PrimaryTextClr
                                      lines:2];
    [card addSubview:title];

    UILabel *subtitle = [self pp_labelWithText:kLang(@"NotificationSettings_HeroSubtitle")
                                          font:PPFontRegular(13.5)
                                         color:[SeconderyTextClr colorWithAlphaComponent:0.86]
                                         lines:0];
    [card addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:46.0],
        [iconSurface.heightAnchor constraintEqualToConstant:46.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [eyebrowCapsule.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [eyebrowCapsule.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
        [eyebrowCapsule.heightAnchor constraintEqualToConstant:20.0],

        [eyebrow.leadingAnchor constraintEqualToAnchor:eyebrowCapsule.leadingAnchor constant:8.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:eyebrowCapsule.trailingAnchor constant:-8.0],
        [eyebrow.centerYAnchor constraintEqualToAnchor:eyebrowCapsule.centerYAnchor],

        [title.topAnchor constraintEqualToAnchor:eyebrowCapsule.bottomAnchor constant:6.0],
        [title.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        // Subtitle full-width baseline fix (eliminates "-كم" text clipping bug)
        [subtitle.topAnchor constraintEqualToAnchor:iconSurface.bottomAnchor constant:12.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [subtitle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [subtitle.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    return card;
}

- (UIView *)pp_buildStatusCard {
    UIView *card = [self pp_surfaceCardWithCornerRadius:24.0];
    card.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.layer.cornerRadius = 21.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    self.statusIconView = [[UIImageView alloc] init];
    self.statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIconView.isAccessibilityElement = NO;
    [iconSurface addSubview:self.statusIconView];

    // Live illuminated pulse beacon dot
    self.statusBeaconDot = [[UIView alloc] init];
    self.statusBeaconDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusBeaconDot.layer.cornerRadius = 4.0;
    self.statusBeaconDot.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:self.statusBeaconDot];

    self.statusTitleLabel = [self pp_labelWithText:kLang(@"NotificationSettings_CheckingStatus")
                                              font:PPFontBold(16.0)
                                             color:PrimaryTextClr
                                             lines:2];
    [card addSubview:self.statusTitleLabel];

    self.statusBodyLabel = [self pp_labelWithText:kLang(@"NotificationSettings_CheckingStatusSubtitle")
                                             font:PPFontRegular(13.0)
                                            color:[SeconderyTextClr colorWithAlphaComponent:0.86]
                                            lines:0];
    [card addSubview:self.statusBodyLabel];

    // Action Buttons Row (iOS Settings + Diagnostic Test)
    UIStackView *actionsRow = [[UIStackView alloc] init];
    actionsRow.translatesAutoresizingMaskIntoConstraints = NO;
    actionsRow.axis = UILayoutConstraintAxisHorizontal;
    actionsRow.spacing = 10.0;
    actionsRow.distribution = UIStackViewDistributionFill;
    actionsRow.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [card addSubview:actionsRow];

    self.statusActionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.statusActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusActionButton.titleLabel.font = PPFontBold(13.0);
    self.statusActionButton.layer.cornerRadius = 16.0;
    self.statusActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusActionButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [self.statusActionButton setTitle:kLang(@"NotificationSettings_OpenIOSSettings") forState:UIControlStateNormal];
    [self.statusActionButton addTarget:self action:@selector(pp_permissionActionTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionsRow addArrangedSubview:self.statusActionButton];

    self.diagnosticTestButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.diagnosticTestButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.diagnosticTestButton.titleLabel.font = PPFontMedium(13.0);
    self.diagnosticTestButton.layer.cornerRadius = 16.0;
    self.diagnosticTestButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.diagnosticTestButton.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.80];
    self.diagnosticTestButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.diagnosticTestButton.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.12].CGColor;
    [self.diagnosticTestButton setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    self.diagnosticTestButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
    [self.diagnosticTestButton setTitle:kLang(@"NotificationSettings_SendDiagnosticTest") forState:UIControlStateNormal];
    [self.diagnosticTestButton addTarget:self action:@selector(pp_sendDiagnosticNotification) forControlEvents:UIControlEventTouchUpInside];
    [actionsRow addArrangedSubview:self.diagnosticTestButton];

    if (@available(iOS 13.4, *)) {
        [self.statusActionButton addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
        [self.diagnosticTestButton addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:42.0],
        [iconSurface.heightAnchor constraintEqualToConstant:42.0],

        [self.statusIconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:20.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:20.0],

        [self.statusBeaconDot.centerYAnchor constraintEqualToAnchor:self.statusTitleLabel.centerYAnchor],
        [self.statusBeaconDot.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:12.0],
        [self.statusBeaconDot.widthAnchor constraintEqualToConstant:8.0],
        [self.statusBeaconDot.heightAnchor constraintEqualToConstant:8.0],

        [self.statusTitleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [self.statusTitleLabel.leadingAnchor constraintEqualToAnchor:self.statusBeaconDot.trailingAnchor constant:8.0],
        [self.statusTitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [self.statusBodyLabel.topAnchor constraintEqualToAnchor:self.statusTitleLabel.bottomAnchor constant:6.0],
        [self.statusBodyLabel.leadingAnchor constraintEqualToAnchor:self.statusBeaconDot.leadingAnchor],
        [self.statusBodyLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [actionsRow.topAnchor constraintEqualToAnchor:self.statusBodyLabel.bottomAnchor constant:14.0],
        [actionsRow.leadingAnchor constraintEqualToAnchor:self.statusBeaconDot.leadingAnchor],
        [actionsRow.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18.0],
        [actionsRow.heightAnchor constraintEqualToConstant:36.0],
        [actionsRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];

    [self pp_updateStatusCardForCurrentAuthorization];
    return card;
}

- (UIView *)pp_buildPrimaryControlsCard {
    UIView *card = [self pp_surfaceCardWithCornerRadius:24.0];
    UIStackView *stack = [self pp_verticalStackWithSpacing:0.0];
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:6.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-6.0],
    ]];

    self.masterSwitch = [self pp_addPreferenceRowToStack:stack
                                                   title:kLang(@"NotificationSettings_MasterTitle")
                                                subtitle:kLang(@"NotificationSettings_MasterSubtitle")
                                                iconName:@"bell.and.waves.left.and.right.fill"
                                             accentColor:AppPrimaryClr
                                           preferenceKey:kPPProNotifMasterPreferenceKey
                                            defaultValue:YES
                                               separator:YES];

    self.soundSwitch = [self pp_addPreferenceRowToStack:stack
                                                  title:kLang(@"NotificationSettings_SoundTitle")
                                               subtitle:kLang(@"NotificationSettings_SoundSubtitle")
                                               iconName:@"speaker.wave.2.fill"
                                            accentColor:[UIColor ppWarning]
                                          preferenceKey:kPPProNotifSoundPreferenceKey
                                           defaultValue:YES
                                              separator:NO];

    return card;
}

- (UIView *)pp_buildCategorySection {
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;

    // Section Header with Dynamic Counter Pill
    UIView *headerRow = [[UIView alloc] init];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapper addSubview:headerRow];

    UILabel *sectionTitle = [self pp_labelWithText:kLang(@"NotificationSettings_CategoriesTitle")
                                              font:PPFontBold(13.0)
                                             color:[PrimaryTextClr colorWithAlphaComponent:0.65]
                                             lines:1];
    sectionTitle.text = [sectionTitle.text uppercaseString];
    [headerRow addSubview:sectionTitle];

    self.categorySummaryPill = [self pp_labelWithText:@""
                                                 font:PPFontBold(11.0)
                                                color:AppPrimaryClr
                                                lines:1];
    self.categorySummaryPill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    self.categorySummaryPill.layer.cornerRadius = 8.0;
    self.categorySummaryPill.layer.cornerCurve = kCACornerCurveContinuous;
    self.categorySummaryPill.clipsToBounds = YES;
    self.categorySummaryPill.textAlignment = NSTextAlignmentCenter;
    [headerRow addSubview:self.categorySummaryPill];

    UIView *card = [self pp_surfaceCardWithCornerRadius:24.0];
    [wrapper addSubview:card];

    UIStackView *stack = [self pp_verticalStackWithSpacing:0.0];
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [headerRow.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
        [headerRow.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:4.0],
        [headerRow.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-4.0],
        [headerRow.heightAnchor constraintEqualToConstant:24.0],

        [sectionTitle.leadingAnchor constraintEqualToAnchor:headerRow.leadingAnchor],
        [sectionTitle.centerYAnchor constraintEqualToAnchor:headerRow.centerYAnchor],

        [self.categorySummaryPill.trailingAnchor constraintEqualToAnchor:headerRow.trailingAnchor],
        [self.categorySummaryPill.centerYAnchor constraintEqualToAnchor:headerRow.centerYAnchor],
        [self.categorySummaryPill.heightAnchor constraintEqualToConstant:20.0],

        [card.topAnchor constraintEqualToAnchor:headerRow.bottomAnchor constant:10.0],
        [card.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:6.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-6.0],
    ]];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryOrdersTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryOrdersSubtitle")
                          iconName:@"shippingbox.fill"
                       accentColor:AppPrimaryClr
                     preferenceKey:kPPProNotifCategoryOrdersKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryDeliveryTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryDeliverySubtitle")
                          iconName:@"truck.box.fill"
                       accentColor:[UIColor ppWarning]
                     preferenceKey:kPPProNotifCategoryDeliveryKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryReviewTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryReviewSubtitle")
                          iconName:@"doc.text.magnifyingglass"
                       accentColor:[UIColor ppQuickActionServices]
                     preferenceKey:kPPProNotifCategoryReviewKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryWarningTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryWarningSubtitle")
                          iconName:@"shield.lefthalf.filled"
                       accentColor:[UIColor ppError]
                     preferenceKey:kPPProNotifCategoryWarningKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryGeneralTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryGeneralSubtitle")
                          iconName:@"sparkles"
                       accentColor:[UIColor ppQuickActionAnimals]
                     preferenceKey:kPPProNotifCategoryGeneralKey
                      defaultValue:YES
                         separator:NO];

    return wrapper;
}

- (UILabel *)pp_buildFootnoteLabel {
    UILabel *label = [self pp_labelWithText:kLang(@"NotificationSettings_Footnote")
                                       font:PPFontRegular(12.0)
                                      color:[SeconderyTextClr colorWithAlphaComponent:0.75]
                                      lines:0];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

#pragma mark - Rows Factory

- (UISwitch *)pp_addCategoryRowToStack:(UIStackView *)stack
                                 title:(NSString *)title
                              subtitle:(NSString *)subtitle
                              iconName:(NSString *)iconName
                           accentColor:(UIColor *)accentColor
                         preferenceKey:(NSString *)preferenceKey
                          defaultValue:(BOOL)defaultValue
                             separator:(BOOL)separator {
    UISwitch *toggle = [self pp_addPreferenceRowToStack:stack
                                                  title:title
                                               subtitle:subtitle
                                               iconName:iconName
                                            accentColor:accentColor
                                          preferenceKey:preferenceKey
                                           defaultValue:defaultValue
                                              separator:separator];
    [self.categorySwitches setObject:toggle forKey:preferenceKey];
    UIView *row = toggle.superview;
    if (row) [self.categoryRows addObject:row];
    return toggle;
}

- (UISwitch *)pp_addPreferenceRowToStack:(UIStackView *)stack
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle
                                iconName:(NSString *)iconName
                             accentColor:(UIColor *)accentColor
                           preferenceKey:(NSString *)preferenceKey
                            defaultValue:(BOOL)defaultValue
                               separator:(BOOL)separator {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    row.accessibilityIdentifier = preferenceKey;
    [stack addArrangedSubview:row];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_preferenceRowTapped:)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [row addGestureRecognizer:tap];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 18.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [row addSubview:iconSurface];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.isAccessibilityElement = NO;
    [iconSurface addSubview:iconView];

    UILabel *titleLabel = [self pp_labelWithText:title
                                            font:PPFontBold(15.0)
                                           color:PrimaryTextClr
                                           lines:2];
    [row addSubview:titleLabel];

    UILabel *subtitleLabel = [self pp_labelWithText:subtitle
                                               font:PPFontRegular(12.5)
                                              color:[SeconderyTextClr colorWithAlphaComponent:0.80]
                                              lines:3];
    [row addSubview:subtitleLabel];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = AppPrimaryClr;
    toggle.accessibilityIdentifier = preferenceKey;
    toggle.accessibilityLabel = title;
    toggle.on = [self pp_boolForPreferenceKey:preferenceKey defaultValue:defaultValue];
    [toggle addTarget:self action:@selector(pp_switchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];

    if (@available(iOS 13.4, *)) {
        [toggle addInteraction:[[UIPointerInteraction alloc] initWithDelegate:self]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:74.0],

        [iconSurface.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:18.0],
        [iconSurface.topAnchor constraintEqualToAnchor:row.topAnchor constant:17.0],
        [iconSurface.widthAnchor constraintEqualToConstant:38.0],
        [iconSurface.heightAnchor constraintEqualToConstant:38.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-18.0],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:15.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:13.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-12.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-12.0],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-15.0],
    ]];

    if (separator) {
        UIView *line = [[UIView alloc] init];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        line.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.07];
        [row addSubview:line];
        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
            [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-18.0],
            [line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [line.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        ]];
    }

    return toggle;
}

#pragma mark - Actions & Haptics

- (void)pp_switchChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key.length == 0) return;

    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self pp_applySwitchStatesAnimated:YES];

    if (@available(iOS 10.0, *)) {
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback selectionChanged];
    }
}

- (void)pp_preferenceRowTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) return;
    UIView *row = recognizer.view;
    NSString *key = row.accessibilityIdentifier;
    if (key.length == 0) return;

    UISwitch *toggle = nil;
    if ([key isEqualToString:kPPProNotifMasterPreferenceKey]) {
        toggle = self.masterSwitch;
    } else if ([key isEqualToString:kPPProNotifSoundPreferenceKey]) {
        toggle = self.soundSwitch;
    } else {
        toggle = self.categorySwitches[key];
    }
    if (!toggle.enabled) return;
    [toggle setOn:!toggle.isOn animated:YES];
    [self pp_switchChanged:toggle];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:UISwitch.class] || [view isKindOfClass:UIControl.class]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

- (void)pp_permissionActionTapped {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [impact impactOccurred];
    }

    if (self.authorizationStatus == UNAuthorizationStatusNotDetermined) {
        UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
                                                                             completionHandler:^(BOOL granted, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                    [PPAlertHelper showSuccessIn:self
                                           title:kLang(@"Success")
                                        subtitle:kLang(@"NotificationSettings_PermissionEnabledToast")];
                }
                [self pp_refreshSystemPermissionState];
            });
        }];
        return;
    }

    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (settingsURL && [[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)pp_sendDiagnosticNotification {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [impact impactOccurred];
    }

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Pure Pets Pro";
    content.subtitle = kLang(@"NotificationSettings_DiagnosticPromptTitle") ?: @"Test Alert";
    content.body = kLang(@"NotificationSettings_DiagnosticSentToast") ?: @"Pro notification test successful.";
    content.sound = [UNNotificationSound defaultSound];

    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.5 repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"PPProDiagnosticPulse" content:content trigger:trigger];

    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                [PPAlertHelper showSuccessIn:self
                                       title:kLang(@"Success")
                                    subtitle:kLang(@"NotificationSettings_DiagnosticSentToast")];
            }
        });
    }];
}

#pragma mark - UIPointerInteractionDelegate

- (nullable UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction
                               styleForRegion:(UIPointerRegion *)region API_AVAILABLE(ios(13.4)) {
    if ([interaction.view isKindOfClass:[UIButton class]]) {
        UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:interaction.view];
        return [UIPointerStyle styleWithEffect:[UIPointerHighlightEffect effectWithPreview:preview] shape:nil];
    }
    return nil;
}

#pragma mark - Permission State

- (void)pp_refreshSystemPermissionState {
    self.statusTitleLabel.text = kLang(@"NotificationSettings_CheckingStatus");
    self.statusBodyLabel.text = kLang(@"NotificationSettings_CheckingStatusSubtitle");

    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.authorizationStatus = settings.authorizationStatus;
            [self pp_updateStatusCardForCurrentAuthorization];
        });
    }];
}

- (void)pp_updateStatusCardForCurrentAuthorization {
    NSString *title = kLang(@"NotificationSettings_StatusNotDeterminedTitle");
    NSString *body = kLang(@"NotificationSettings_StatusNotDeterminedBody");
    NSString *button = kLang(@"NotificationSettings_AllowNotifications");
    NSString *symbol = @"bell.badge.fill";
    UIColor *accent = [UIColor ppWarning];

    switch (self.authorizationStatus) {
        case UNAuthorizationStatusAuthorized:
            title = kLang(@"NotificationSettings_StatusEnabledTitle");
            body = kLang(@"NotificationSettings_StatusEnabledBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"checkmark.seal.fill";
            accent = [UIColor ppSuccess];
            break;
        case UNAuthorizationStatusDenied:
            title = kLang(@"NotificationSettings_StatusDeniedTitle");
            body = kLang(@"NotificationSettings_StatusDeniedBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"bell.slash.fill";
            accent = [UIColor ppError];
            break;
        case UNAuthorizationStatusProvisional:
        case UNAuthorizationStatusEphemeral:
            title = kLang(@"NotificationSettings_StatusQuietTitle");
            body = kLang(@"NotificationSettings_StatusQuietBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"bell.badge.fill";
            accent = [UIColor ppWarning];
            break;
        case UNAuthorizationStatusNotDetermined:
        default:
            break;
    }

    self.statusTitleLabel.text = title;
    self.statusBodyLabel.text = body;
    self.statusBeaconDot.backgroundColor = accent;
    [self.statusActionButton setTitle:button forState:UIControlStateNormal];
    [self.statusActionButton setTitleColor:accent forState:UIControlStateNormal];
    self.statusActionButton.backgroundColor = [accent colorWithAlphaComponent:0.12];
    self.statusIconView.image = [UIImage systemImageNamed:symbol
                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold]];
    self.statusIconView.tintColor = accent;

    UIView *iconSurface = self.statusIconView.superview;
    iconSurface.backgroundColor = [accent colorWithAlphaComponent:0.10];
    iconSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    iconSurface.layer.borderColor = [accent colorWithAlphaComponent:0.18].CGColor;

    self.statusCard.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title ?: @"", body ?: @""];
}

#pragma mark - Preferences & States

- (BOOL)pp_boolForPreferenceKey:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (value == nil) return defaultValue;
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)pp_applySwitchStatesAnimated:(BOOL)animated {
    BOOL masterEnabled = [self pp_boolForPreferenceKey:kPPProNotifMasterPreferenceKey defaultValue:YES];
    BOOL soundEnabled = [self pp_boolForPreferenceKey:kPPProNotifSoundPreferenceKey defaultValue:YES];

    [self.masterSwitch setOn:masterEnabled animated:animated];
    [self.soundSwitch setOn:soundEnabled animated:animated];
    self.soundSwitch.enabled = masterEnabled;

    __block NSInteger activeCount = 0;
    [self.categorySwitches enumerateKeysAndObjectsUsingBlock:^(NSString *key, UISwitch *toggle, BOOL *stop) {
        toggle.enabled = masterEnabled;
        BOOL isOn = [self pp_boolForPreferenceKey:key defaultValue:YES];
        [toggle setOn:isOn animated:animated];
        if (isOn) activeCount++;
    }];

    NSString *summaryFormat = kLang(@"NotificationSettings_ActiveChannelsCount") ?: @"%d of %d active";
    self.categorySummaryPill.text = [NSString stringWithFormat:summaryFormat, (int)activeCount, (int)self.categorySwitches.count];

    void (^animations)(void) = ^{
        self.soundSwitch.superview.alpha = masterEnabled ? 1.0 : 0.44;
        for (UIView *row in self.categoryRows) {
            row.alpha = masterEnabled ? 1.0 : 0.44;
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.25 animations:animations];
    } else {
        animations();
    }
}

#pragma mark - Surface Styling

- (UIView *)pp_surfaceCardWithCornerRadius:(CGFloat)radius {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = radius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [PrimaryTextClr colorWithAlphaComponent:0.07].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.04 : 0.06);
    card.layer.shadowRadius = 20.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    return card;
}

- (UIStackView *)pp_verticalStackWithSpacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = spacing;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    return stack;
}

- (UILabel *)pp_labelWithText:(NSString *)text
                         font:(UIFont *)font
                        color:(UIColor *)color
                        lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

#pragma mark - Entrance Animation

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.iphoneStack.alpha = 1.0;
        self.ipadContainer.alpha = 1.0;
        return;
    }

    UIView *activeTarget = self.isIPadLayoutActive ? self.ipadContainer : self.iphoneStack;
    activeTarget.alpha = 0.0;
    activeTarget.transform = CGAffineTransformMakeTranslation(0.0, 12.0);

    [UIView animateWithDuration:0.42
                          delay:0.05
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        activeTarget.alpha = 1.0;
        activeTarget.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
