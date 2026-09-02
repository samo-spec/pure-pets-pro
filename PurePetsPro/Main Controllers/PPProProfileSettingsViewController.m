#import "PPProProfileSettingsViewController.h"

#import "NotificationSettingsViewController.h"
#import "PPDeliveryCompanyDashboardViewController.h"
#import "PPDeliveryCompanySetupViewController.h"
#import "PPDeliveryDashboardViewController.h"
#import "PPFirebaseCompat.h"
#import "PPMarketplaceBranchesViewController.h"
#import "PPPharmacyMedicinesViewController.h"
#import "PPProviderApplicationManager.h"
#import "PPProviderProfileEditorViewController.h"
#import "PPServicesListViewController.h"
#import "PPVetsListViewController.h"

static NSString *PPProCurrentThemePreference(void) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"themePreference"];
    return saved ?: PPProThemePreferenceSystem;
}

static void PPProApplyThemePreference(NSString *preference) {
    NSString *resolved = preference ?: PPProThemePreferenceSystem;
    [[NSUserDefaults standardUserDefaults] setObject:resolved forKey:@"themePreference"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if ([resolved isEqualToString:PPProThemePreferenceLight]) style = UIUserInterfaceStyleLight;
    if ([resolved isEqualToString:PPProThemePreferenceDark]) style = UIUserInterfaceStyleDark;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            window.overrideUserInterfaceStyle = style;
        }
    }
}

typedef NS_ENUM(NSInteger, PPProProfileSettingsAction) {
    PPProProfileSettingsActionNotifications = 0,
    PPProProfileSettingsActionAppearance = 1,
    PPProProfileSettingsActionLanguage = 2,
    PPProProfileSettingsActionLogout = 3,
};

@interface PPProProfileSettingsSheetViewController : UIViewController

- (instancetype)initWithActions:(NSArray<NSDictionary *> *)actions
                       selection:(void(^)(PPProProfileSettingsAction action))selection;

@end

@implementation PPProProfileSettingsSheetViewController {
    NSArray<NSDictionary *> *_actions;
    void (^_selection)(PPProProfileSettingsAction action);
    UIView *_dimmingView;
    UIView *_sheetView;
    UIStackView *_stackView;
    BOOL _didPrepareEntrance;
    BOOL _didRunEntrance;
}

- (instancetype)initWithActions:(NSArray<NSDictionary *> *)actions
                      selection:(void(^)(PPProProfileSettingsAction action))selection {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _actions = actions.copy ?: @[];
        _selection = [selection copy];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    _dimmingView = [[UIView alloc] init];
    _dimmingView.translatesAutoresizingMaskIntoConstraints = NO;
    _dimmingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.32];
    _dimmingView.alpha = 0.0;
    [self.view addSubview:_dimmingView];

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    dismissButton.backgroundColor = UIColor.clearColor;
    dismissButton.accessibilityLabel = kLang(@"Cancel");
    [dismissButton addTarget:self action:@selector(pp_dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];

    _sheetView = [[UIView alloc] init];
    _sheetView.translatesAutoresizingMaskIntoConstraints = NO;
    _sheetView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.12 alpha:0.98]
            : [UIColor colorWithWhite:1.0 alpha:0.98];
    }];
    PPApplyContinuousCorners(_sheetView, PPCornerHero);
    // Bottom sheet keeps its upward shadow direction; color/opacity/radius now come from tokens.
    _sheetView.layer.shadowColor = AppShadowColor.CGColor;
    _sheetView.layer.shadowOpacity = PPShadowElevatedOpacity;
    _sheetView.layer.shadowRadius = PPShadowElevatedRadius;
    _sheetView.layer.shadowOffset = CGSizeMake(0.0, -PPSpaceSM);
    [self.view addSubview:_sheetView];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        PPApplyContinuousCorners(blurView, PPCornerHero);
        blurView.clipsToBounds = YES;
        [_sheetView addSubview:blurView];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:_sheetView.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:_sheetView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:_sheetView.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:_sheetView.bottomAnchor],
        ]];
    }

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [[UIColor ppTextPrimary] colorWithAlphaComponent:0.12];
    grabber.layer.cornerRadius = 2.5;
    [_sheetView addSubview:grabber];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"ProfileSettings_SheetTitle");
    titleLabel.font = [Styling fontBold:PPFontTitle3];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(titleLabel, UIFontTextStyleTitle3);
    [_sheetView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"ProfileSettings_SheetSubtitle");
    subtitleLabel.font = [Styling fontMedium:PPFontFootnote];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicType(subtitleLabel, UIFontTextStyleFootnote);
    [_sheetView addSubview:subtitleLabel];

    _stackView = [[UIStackView alloc] init];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = 10.0;
    [_sheetView addSubview:_stackView];

    for (NSDictionary *item in _actions) {
        UIButton *button = [self pp_makeActionButton:item];
        [_stackView addArrangedSubview:button];
    }

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [UIColor colorWithWhite:0.0 alpha:0.035];
    }];
    PPApplyContinuousCorners(cancelButton, PPCornerMedium);
    cancelButton.titleLabel.font = [Styling fontBold:PPFontCallout];
    PPEnableDynamicType(cancelButton.titleLabel, UIFontTextStyleCallout);
    [cancelButton setTitle:kLang(@"Cancel") forState:UIControlStateNormal];
    [cancelButton setTitleColor:PrimaryTextClr forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(pp_dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [_sheetView addSubview:cancelButton];

    [NSLayoutConstraint activateConstraints:@[
        [_dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [dismissButton.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dismissButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dismissButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dismissButton.bottomAnchor constraintEqualToAnchor:_sheetView.topAnchor],

        [_sheetView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [_sheetView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [_sheetView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0],

        [grabber.topAnchor constraintEqualToAnchor:_sheetView.topAnchor constant:10.0],
        [grabber.centerXAnchor constraintEqualToAnchor:_sheetView.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:42.0],
        [grabber.heightAnchor constraintEqualToConstant:5.0],

        [titleLabel.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_sheetView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_sheetView.trailingAnchor constant:-18.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [_stackView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [_stackView.leadingAnchor constraintEqualToAnchor:_sheetView.leadingAnchor constant:16.0],
        [_stackView.trailingAnchor constraintEqualToAnchor:_sheetView.trailingAnchor constant:-16.0],

        [cancelButton.topAnchor constraintEqualToAnchor:_stackView.bottomAnchor constant:14.0],
        [cancelButton.leadingAnchor constraintEqualToAnchor:_stackView.leadingAnchor],
        [cancelButton.trailingAnchor constraintEqualToAnchor:_stackView.trailingAnchor],
        [cancelButton.heightAnchor constraintGreaterThanOrEqualToConstant:54.0],
        [cancelButton.bottomAnchor constraintEqualToAnchor:_sheetView.bottomAnchor constant:-16.0],
    ]];

    [self pp_prepareEntranceState];
}

- (UIButton *)pp_makeActionButton:(NSDictionary *)item {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = [item[@"action"] integerValue];
    button.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.05]
            : [UIColor colorWithWhite:0.0 alpha:0.028];
    }];
    PPApplyContinuousCorners(button, PPCornerCard);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    // Grows instead of clipping when the user raises the text size.
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:74.0].active = YES;
    [button addTarget:self action:@selector(pp_actionTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(iconPlate, PPCornerMedium, 0.10);
    iconPlate.userInteractionEnabled = NO;
    [button addSubview:iconPlate];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item[@"icon"]
                                                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [item[@"destructive"] boolValue] ? [UIColor ppError] : AppPrimaryClr;
    iconView.userInteractionEnabled = NO;
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = item[@"title"];
    titleLabel.font = [Styling fontBold:PPFontCallout];
    titleLabel.textColor = [item[@"destructive"] boolValue] ? [UIColor ppError] : PrimaryTextClr;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.userInteractionEnabled = NO;
    PPEnableDynamicType(titleLabel, UIFontTextStyleCallout);
    [button addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = item[@"subtitle"];
    subtitleLabel.font = [Styling fontMedium:PPFontFootnote];
    subtitleLabel.textColor = SeconderyTextClr;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.userInteractionEnabled = NO;
    PPEnableDynamicType(subtitleLabel, UIFontTextStyleFootnote);
    [button addSubview:subtitleLabel];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"
                                                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = AppTertiaryTextClr;
    chevron.userInteractionEnabled = NO;
    [button addSubview:chevron];

    // The row is drawn from plain subviews, so VoiceOver needs one composed element.
    NSMutableArray<NSString *> *spokenParts = [NSMutableArray array];
    if (titleLabel.text.length) [spokenParts addObject:titleLabel.text];
    if (subtitleLabel.text.length) [spokenParts addObject:subtitleLabel.text];
    button.isAccessibilityElement = YES;
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.accessibilityLabel = [spokenParts componentsJoinedByString:@", "];

    [NSLayoutConstraint activateConstraints:@[
        [iconPlate.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:14.0],
        [iconPlate.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:36.0],
        [iconPlate.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:button.topAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-10.0],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:button.bottomAnchor constant:-14.0],

        [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16.0],
        [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
    ]];

    return button;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)pp_prepareEntranceState {
    if (_didRunEntrance || _didPrepareEntrance) return;
    _didPrepareEntrance = YES;
    // Reduce Motion: skip staging so there is no entrance left to animate.
    if (PPMotionReduced()) return;
    _sheetView.transform = CGAffineTransformMakeTranslation(0.0, 28.0);
    _sheetView.alpha = 0.0;
}

- (void)pp_runEntranceIfNeeded {
    if (_didRunEntrance) return;
    _didRunEntrance = YES;
    if (PPMotionReduced()) {
        _dimmingView.alpha = 1.0;
        _sheetView.alpha = 1.0;
        _sheetView.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self->_dimmingView.alpha = 1.0;
    } completion:nil];
    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_sheetView.alpha = 1.0;
        self->_sheetView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_actionTapped:(UIButton *)sender {
    PPProProfileSettingsAction action = (PPProProfileSettingsAction)sender.tag;
    [self dismissViewControllerAnimated:YES completion:^{
        if (self->_selection) {
            self->_selection(action);
        }
    }];
}

- (void)pp_dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface PPProProfileSettingsViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) PPHero *heroCard;
@property (nonatomic, strong) UIImageView *heroAvatarView;
@property (nonatomic, strong) UILabel *heroNameLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UILabel *heroMetaLabel;
@property (nonatomic, strong) UILabel *heroRolePillLabel;

@property (nonatomic, strong) UIView *accountSectionCard;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UILabel *saveFootnoteLabel;

@property (nonatomic, strong) UIView *providerSectionCard;
@property (nonatomic, strong) UIImageView *providerCoverImageView;
@property (nonatomic, strong) UIView *providerCoverFallbackView;
@property (nonatomic, strong) UIActivityIndicatorView *providerLoadingIndicator;
@property (nonatomic, strong) UIImageView *providerLogoView;
@property (nonatomic, strong) UILabel *providerStatusPillLabel;
@property (nonatomic, strong) UILabel *providerPreviewTitleLabel;
@property (nonatomic, strong) UILabel *providerPreviewSubtitleLabel;
@property (nonatomic, strong) UILabel *providerNameValueLabel;
@property (nonatomic, strong) UILabel *providerEmailValueLabel;
@property (nonatomic, strong) UILabel *providerPhoneValueLabel;
@property (nonatomic, strong) UILabel *providerCoverValueLabel;
@property (nonatomic, strong) UILabel *providerPlanCaptionLabel;
@property (nonatomic, strong) UIButton *providerCTAButton;
@property (nonatomic, strong) UIView *settingsSectionCard;

@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) id<FIRListenerRegistration> providerStateListener;
@property (nonatomic, strong) PPProviderOnboardingState *providerState;
@property (nonatomic, strong) NSError *providerStateError;
@property (nonatomic, strong) NSMutableArray<NSString *> *coverImageURLs;

@property (nonatomic, copy) NSString *editedName;
@property (nonatomic, copy) NSString *editedEmail;
@property (nonatomic, copy) NSString *editedPhone;
@property (nonatomic, assign) BOOL hasEdits;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;

@end

@implementation PPProProfileSettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = pp_canvasColor();
    self.coverImageURLs = [NSMutableArray array];
    [self pp_syncEditedFieldsFromUser];
    [self pp_buildScrollSurface];
    [self pp_buildNavigation];
    [self pp_loadCoverImageURLs];
    [self pp_startProviderStateObservation];
    [self pp_refreshAllContent];
    [self pp_prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_buildNavigation];
    [self pp_syncEditedFieldsFromUser];
    [self pp_refreshAllContent];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = pp_canvasColor();
        [self pp_applyStaticColors];
        [self pp_refreshProviderPreview];
    }
}

- (void)dealloc {
    [self.providerStateListener remove];
    self.providerStateListener = nil;
}

#pragma mark - Build

- (void)pp_buildNavigation {
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.saveButton, PPCorner16);
    // Dynamic Type intentionally skipped: this pill lives inside the fixed-height
    // navigation bar chrome, so a scaled title would clip rather than reflow.
    self.saveButton.titleLabel.font = [Styling fontBold:13];
    [self.saveButton setTitle:kLang(@"Save") forState:UIControlStateNormal];
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.saveButton.tintColor = UIColor.whiteColor;
    self.saveButton.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    [self.saveButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin].active = YES;
    [self.saveButton addTarget:self action:@selector(pp_saveProfile) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.saveButton style:PPButtonAnimationStyleDefault];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:self.saveButton title:kLang(@"ProfileSettings") showBack:YES];
    [self pp_refreshSaveButtonState];
}

- (void)pp_buildScrollSurface {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18.0;
    [self.contentView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-32.0],
    ]];

    [self.contentStack addArrangedSubview:[self pp_buildHeroCard]];
    [self.contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProfileSettings_PersonalSectionTitle")
                                                                      subtitle:kLang(@"ProfileSettings_PersonalSectionSubtitle")]];
    [self.contentStack addArrangedSubview:[self pp_buildAccountSection]];
    [self.contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProfileSettings_ProviderPreviewTitle")
                                                                      subtitle:kLang(@"ProfileSettings_ProviderPreviewSubtitle")]];
    [self.contentStack addArrangedSubview:[self pp_buildProviderPreviewSection]];
    [self.contentStack addArrangedSubview:[self pp_buildSectionHeaderWithTitle:kLang(@"ProfileSettings_SettingsSectionTitle")
                                                                      subtitle:kLang(@"ProfileSettings_SettingsSectionSubtitle")]];
    [self.contentStack addArrangedSubview:[self pp_buildSettingsSection]];

    [self pp_applySectionCardStyling];
}

- (UIView *)pp_buildHeroCard {
    self.heroCard = [[PPHero alloc] init];
    self.heroCard.translatesAutoresizingMaskIntoConstraints = NO;
     self.heroCard.accentColor = AppPrimaryClr;

    UILabel *eyebrow = [self pp_label:kLang(@"ProfileSettings_Eyebrow")
                                 font:[Styling fontBold:PPFontCaption1]
                                color:AppPrimaryClr
                                lines:1
                            textStyle:UIFontTextStyleCaption1];
    [self.heroCard addSubview:eyebrow];

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(avatarHalo, 44.0, 0.10);
    [self.heroCard addSubview:avatarHalo];

    self.heroAvatarView = [[UIImageView alloc] init];
    self.heroAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroAvatarView.clipsToBounds = YES;
    self.heroAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    PPApplyContinuousCorners(self.heroAvatarView, 36.0);
    self.heroAvatarView.backgroundColor = AppPrimaryClrWithAlpha(0.08);
    [avatarHalo addSubview:self.heroAvatarView];

    self.heroNameLabel = [self pp_label:@""
                                   font:[Styling fontBold:28]
                                  color:PrimaryTextClr
                                  lines:2
                              textStyle:UIFontTextStyleTitle1];
    [self.heroCard addSubview:self.heroNameLabel];

    self.heroSubtitleLabel = [self pp_label:@""
                                       font:[Styling fontMedium:13]
                                      color:SeconderyTextClr
                                      lines:2
                                  textStyle:UIFontTextStyleFootnote];
    [self.heroCard addSubview:self.heroSubtitleLabel];

    // Dynamic Type intentionally skipped on the role pill: it is a fixed-height
    // badge whose padding comes from literal spaces in the text, so a scaled
    // font would clip horizontally instead of reflowing.
    self.heroRolePillLabel = [self pp_label:@""
                                       font:[Styling fontBold:PPFontCaption1]
                                      color:AppPrimaryClr
                                      lines:1];
    self.heroRolePillLabel.textAlignment = NSTextAlignmentCenter;
    self.heroRolePillLabel.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    PPApplyContinuousCorners(self.heroRolePillLabel, PPCornerSmall);
    self.heroRolePillLabel.clipsToBounds = YES;
    [self.heroCard addSubview:self.heroRolePillLabel];

    self.heroMetaLabel = [self pp_label:@""
                                   font:[Styling fontMedium:PPFontFootnote]
                                  color:SeconderyTextClr
                                  lines:2
                              textStyle:UIFontTextStyleFootnote];
    [self.heroCard addSubview:self.heroMetaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCard.heightAnchor constraintGreaterThanOrEqualToConstant:180.0],

        [eyebrow.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:22.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:avatarHalo.leadingAnchor constant:-14.0],

        [avatarHalo.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-20.0],
        [avatarHalo.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:22.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:88.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:88.0],

        [self.heroAvatarView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [self.heroAvatarView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [self.heroAvatarView.widthAnchor constraintEqualToConstant:72.0],
        [self.heroAvatarView.heightAnchor constraintEqualToConstant:72.0],

        [self.heroNameLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:10.0],
        [self.heroNameLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.heroNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:avatarHalo.leadingAnchor constant:-14.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroNameLabel.bottomAnchor constant:8.0],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-22.0],

        [self.heroRolePillLabel.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:14.0],
        [self.heroRolePillLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.heroRolePillLabel.heightAnchor constraintEqualToConstant:25.0],
        [self.heroRolePillLabel.widthAnchor constraintGreaterThanOrEqualToConstant:94.0],

        [self.heroMetaLabel.topAnchor constraintEqualToAnchor:self.heroRolePillLabel.bottomAnchor constant:12.0],
        [self.heroMetaLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.heroMetaLabel.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-22.0],
        [self.heroMetaLabel.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-22.0],
    ]];

    return self.heroCard;
}

- (UIView *)pp_buildSectionHeaderWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [self pp_label:title font:[Styling fontBold:PPFontHeadline] color:PrimaryTextClr lines:2
                               textStyle:UIFontTextStyleHeadline];
    UILabel *subtitleLabel = [self pp_label:subtitle font:[Styling fontMedium:PPFontFootnote] color:SeconderyTextClr lines:2
                                  textStyle:UIFontTextStyleFootnote];
    [container addSubview:titleLabel];
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:48.0],
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:2.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-2.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    return container;
}

- (UIView *)pp_buildAccountSection {
    self.accountSectionCard = [[UIView alloc] init];
    self.accountSectionCard.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [self.accountSectionCard addSubview:stack];

    [stack addArrangedSubview:[self pp_makeEditableFieldShellWithIcon:@"person.fill"
                                                                title:kLang(@"ProfileDisplayName")
                                                          assignField:&_nameField
                                                                  tag:0
                                                             keyboard:UIKeyboardTypeDefault
                                               autocapitalizationType:UITextAutocapitalizationTypeWords]];
    [stack addArrangedSubview:[self pp_makeEditableFieldShellWithIcon:@"envelope.fill"
                                                                title:kLang(@"ProfileEmail")
                                                          assignField:&_emailField
                                                                  tag:1
                                                             keyboard:UIKeyboardTypeEmailAddress
                                               autocapitalizationType:UITextAutocapitalizationTypeNone]];
    [stack addArrangedSubview:[self pp_makeEditableFieldShellWithIcon:@"phone.fill"
                                                                title:kLang(@"ProfilePhone")
                                                          assignField:&_phoneField
                                                                  tag:2
                                                             keyboard:UIKeyboardTypePhonePad
                                               autocapitalizationType:UITextAutocapitalizationTypeNone]];

    self.saveFootnoteLabel = [self pp_label:kLang(@"ProfileSettings_SaveHint")
                                       font:[Styling fontMedium:PPFontCaption1]
                                      color:SeconderyTextClr
                                      lines:2
                                  textStyle:UIFontTextStyleCaption1];
    [stack addArrangedSubview:self.saveFootnoteLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.accountSectionCard.heightAnchor constraintGreaterThanOrEqualToConstant:292.0],
        [stack.topAnchor constraintEqualToAnchor:self.accountSectionCard.topAnchor constant:18.0],
        [stack.leadingAnchor constraintEqualToAnchor:self.accountSectionCard.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.accountSectionCard.trailingAnchor constant:-18.0],
        [stack.bottomAnchor constraintEqualToAnchor:self.accountSectionCard.bottomAnchor constant:-18.0],
    ]];

    return self.accountSectionCard;
}

- (UIView *)pp_makeEditableFieldShellWithIcon:(NSString *)icon
                                        title:(NSString *)title
                                  assignField:(UITextField * __strong *)fieldPtr
                                          tag:(NSInteger)tag
                                     keyboard:(UIKeyboardType)keyboard
                       autocapitalizationType:(UITextAutocapitalizationType)capitalization {
    UIView *shell = [[UIView alloc] init];
    shell.translatesAutoresizingMaskIntoConstraints = NO;
    shell.backgroundColor = [self pp_innerSurfaceColor];
    PPApplyContinuousCorners(shell, PPCornerCard);

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(iconPlate, PPCornerMedium, 0.10);
    [shell addSubview:iconPlate];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self pp_label:title font:[Styling fontBold:13] color:SeconderyTextClr lines:1
                               textStyle:UIFontTextStyleFootnote];
    [shell addSubview:titleLabel];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.font = [Styling fontMedium:17];
    field.textColor = PrimaryTextClr;
    field.textAlignment = Language.alignmentForCurrentLanguage;
    PPEnableDynamicTypeForTextField(field, UIFontTextStyleHeadline);
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = capitalization;
    field.keyboardType = keyboard;
    field.tag = tag;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.returnKeyType = tag == 2 ? UIReturnKeyDone : UIReturnKeyNext;
    field.delegate = self;
    [field addTarget:self action:@selector(pp_fieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [shell addSubview:field];
    if (fieldPtr) {
        *fieldPtr = field;
    }

    [NSLayoutConstraint activateConstraints:@[
        [shell.heightAnchor constraintGreaterThanOrEqualToConstant:86.0],

        [iconPlate.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],
        [iconPlate.centerYAnchor constraintEqualToAnchor:shell.centerYAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:36.0],
        [iconPlate.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:shell.topAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-16.0],

        [field.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [field.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [field.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [field.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-16.0],
    ]];

    return shell;
}

- (UIView *)pp_buildProviderPreviewSection {
    self.providerSectionCard = [[UIView alloc] init];
    self.providerSectionCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerSectionCard.clipsToBounds = YES;

    UIView *coverContainer = [[UIView alloc] init];
    coverContainer.translatesAutoresizingMaskIntoConstraints = NO;
    coverContainer.clipsToBounds = YES;
    PPApplyContinuousCorners(coverContainer, PPCornerCard);
    [self.providerSectionCard addSubview:coverContainer];

    self.providerCoverImageView = [[UIImageView alloc] init];
    self.providerCoverImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerCoverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.providerCoverImageView.clipsToBounds = YES;
    [coverContainer addSubview:self.providerCoverImageView];

    self.providerCoverFallbackView = [[UIView alloc] init];
    self.providerCoverFallbackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerCoverFallbackView.backgroundColor = AppPrimaryClrWithAlpha(0.08);
    [coverContainer addSubview:self.providerCoverFallbackView];

    // Honest loading: the placeholder plate spins until the provider state resolves.
    self.providerLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.providerLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerLoadingIndicator.color = AppPrimaryClr;
    self.providerLoadingIndicator.hidesWhenStopped = YES;
    [self.providerCoverFallbackView addSubview:self.providerLoadingIndicator];

    UIView *coverShade = [[UIView alloc] init];
    coverShade.translatesAutoresizingMaskIntoConstraints = NO;
    coverShade.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.18];
    [coverContainer addSubview:coverShade];

    UIView *logoHalo = [[UIView alloc] init];
    logoHalo.translatesAutoresizingMaskIntoConstraints = NO;
    logoHalo.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
    PPApplyContinuousCorners(logoHalo, 34.0);
    [coverContainer addSubview:logoHalo];

    self.providerLogoView = [[UIImageView alloc] init];
    self.providerLogoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerLogoView.clipsToBounds = YES;
    self.providerLogoView.contentMode = UIViewContentModeScaleAspectFill;
    PPApplyContinuousCorners(self.providerLogoView, 28.0);
    self.providerLogoView.backgroundColor = AppPrimaryClrWithAlpha(0.12);
    [logoHalo addSubview:self.providerLogoView];

    // Dynamic Type intentionally skipped on the status pill: fixed-height badge
    // over the cover art, padded by literal spaces, so scaling would clip it.
    self.providerStatusPillLabel = [self pp_label:@""
                                             font:[Styling fontBold:PPFontCaption1]
                                            color:UIColor.whiteColor
                                            lines:1];
    self.providerStatusPillLabel.textAlignment = NSTextAlignmentCenter;
    self.providerStatusPillLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
    PPApplyContinuousCorners(self.providerStatusPillLabel, PPCornerSmall);
    self.providerStatusPillLabel.clipsToBounds = YES;
    [coverContainer addSubview:self.providerStatusPillLabel];

    self.providerPreviewTitleLabel = [self pp_label:kLang(@"ProfileSettings_ProviderPreviewShownInUsersApp")
                                               font:[Styling fontBold:17]
                                              color:PrimaryTextClr
                                              lines:2
                                          textStyle:UIFontTextStyleHeadline];
    [self.providerSectionCard addSubview:self.providerPreviewTitleLabel];

    self.providerPreviewSubtitleLabel = [self pp_label:@""
                                                  font:[Styling fontMedium:PPFontFootnote]
                                                 color:SeconderyTextClr
                                                 lines:3
                                             textStyle:UIFontTextStyleFootnote];
    [self.providerSectionCard addSubview:self.providerPreviewSubtitleLabel];

    UIStackView *rowsStack = [[UIStackView alloc] init];
    rowsStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowsStack.axis = UILayoutConstraintAxisVertical;
    rowsStack.spacing = 10.0;
    [self.providerSectionCard addSubview:rowsStack];

    [rowsStack addArrangedSubview:[self pp_makeKeyValueRowWithTitle:kLang(@"ProfileDisplayName") valueLabel:&_providerNameValueLabel]];
    [rowsStack addArrangedSubview:[self pp_makeKeyValueRowWithTitle:kLang(@"ProfileEmail") valueLabel:&_providerEmailValueLabel]];
    [rowsStack addArrangedSubview:[self pp_makeKeyValueRowWithTitle:kLang(@"ProfilePhone") valueLabel:&_providerPhoneValueLabel]];
    [rowsStack addArrangedSubview:[self pp_makeKeyValueRowWithTitle:kLang(@"ProfileSettings_ProviderPreviewCoverTitle") valueLabel:&_providerCoverValueLabel]];

    self.providerPlanCaptionLabel = [self pp_label:@""
                                              font:[Styling fontMedium:PPFontFootnote]
                                             color:SeconderyTextClr
                                             lines:3
                                         textStyle:UIFontTextStyleFootnote];
    [self.providerSectionCard addSubview:self.providerPlanCaptionLabel];

    self.providerCTAButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.providerCTAButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerCTAButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.providerCTAButton, PPCornerMedium);
    self.providerCTAButton.titleLabel.font = [Styling fontBold:PPFontCallout];
    PPEnableDynamicType(self.providerCTAButton.titleLabel, UIFontTextStyleCallout);
    [self.providerCTAButton setTitle:kLang(@"ProfileSettings_EditProviderProfile") forState:UIControlStateNormal];
    [self.providerCTAButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.providerCTAButton setImage:[UIImage systemImageNamed:@"arrow.up.forward.app.fill"
                                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]
                             forState:UIControlStateNormal];
    self.providerCTAButton.tintColor = UIColor.whiteColor;
    self.providerCTAButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.providerCTAButton.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
    [self.providerCTAButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG].active = YES;
    [self.providerCTAButton addTarget:self action:@selector(pp_openProviderProfileEditor) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.providerCTAButton style:PPButtonAnimationStyleDefault];
    [self.providerSectionCard addSubview:self.providerCTAButton];

    [NSLayoutConstraint activateConstraints:@[
        [coverContainer.topAnchor constraintEqualToAnchor:self.providerSectionCard.topAnchor constant:18.0],
        [coverContainer.leadingAnchor constraintEqualToAnchor:self.providerSectionCard.leadingAnchor constant:18.0],
        [coverContainer.trailingAnchor constraintEqualToAnchor:self.providerSectionCard.trailingAnchor constant:-18.0],
        [coverContainer.heightAnchor constraintEqualToConstant:188.0],

        [self.providerCoverImageView.topAnchor constraintEqualToAnchor:coverContainer.topAnchor],
        [self.providerCoverImageView.leadingAnchor constraintEqualToAnchor:coverContainer.leadingAnchor],
        [self.providerCoverImageView.trailingAnchor constraintEqualToAnchor:coverContainer.trailingAnchor],
        [self.providerCoverImageView.bottomAnchor constraintEqualToAnchor:coverContainer.bottomAnchor],

        [self.providerCoverFallbackView.topAnchor constraintEqualToAnchor:coverContainer.topAnchor],
        [self.providerCoverFallbackView.leadingAnchor constraintEqualToAnchor:coverContainer.leadingAnchor],
        [self.providerCoverFallbackView.trailingAnchor constraintEqualToAnchor:coverContainer.trailingAnchor],
        [self.providerCoverFallbackView.bottomAnchor constraintEqualToAnchor:coverContainer.bottomAnchor],

        [self.providerLoadingIndicator.centerXAnchor constraintEqualToAnchor:self.providerCoverFallbackView.centerXAnchor],
        [self.providerLoadingIndicator.centerYAnchor constraintEqualToAnchor:self.providerCoverFallbackView.centerYAnchor],

        [coverShade.topAnchor constraintEqualToAnchor:coverContainer.topAnchor],
        [coverShade.leadingAnchor constraintEqualToAnchor:coverContainer.leadingAnchor],
        [coverShade.trailingAnchor constraintEqualToAnchor:coverContainer.trailingAnchor],
        [coverShade.bottomAnchor constraintEqualToAnchor:coverContainer.bottomAnchor],

        [logoHalo.leadingAnchor constraintEqualToAnchor:coverContainer.leadingAnchor constant:16.0],
        [logoHalo.bottomAnchor constraintEqualToAnchor:coverContainer.bottomAnchor constant:-16.0],
        [logoHalo.widthAnchor constraintEqualToConstant:68.0],
        [logoHalo.heightAnchor constraintEqualToConstant:68.0],

        [self.providerLogoView.centerXAnchor constraintEqualToAnchor:logoHalo.centerXAnchor],
        [self.providerLogoView.centerYAnchor constraintEqualToAnchor:logoHalo.centerYAnchor],
        [self.providerLogoView.widthAnchor constraintEqualToConstant:56.0],
        [self.providerLogoView.heightAnchor constraintEqualToConstant:56.0],

        [self.providerStatusPillLabel.topAnchor constraintEqualToAnchor:coverContainer.topAnchor constant:14.0],
        [self.providerStatusPillLabel.trailingAnchor constraintEqualToAnchor:coverContainer.trailingAnchor constant:-14.0],
        [self.providerStatusPillLabel.heightAnchor constraintEqualToConstant:25.0],
        [self.providerStatusPillLabel.widthAnchor constraintGreaterThanOrEqualToConstant:84.0],

        [self.providerPreviewTitleLabel.topAnchor constraintEqualToAnchor:coverContainer.bottomAnchor constant:16.0],
        [self.providerPreviewTitleLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionCard.leadingAnchor constant:18.0],
        [self.providerPreviewTitleLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionCard.trailingAnchor constant:-18.0],

        [self.providerPreviewSubtitleLabel.topAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.bottomAnchor constant:6.0],
        [self.providerPreviewSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.leadingAnchor],
        [self.providerPreviewSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.trailingAnchor],

        [rowsStack.topAnchor constraintEqualToAnchor:self.providerPreviewSubtitleLabel.bottomAnchor constant:16.0],
        [rowsStack.leadingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.leadingAnchor],
        [rowsStack.trailingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.trailingAnchor],

        [self.providerPlanCaptionLabel.topAnchor constraintEqualToAnchor:rowsStack.bottomAnchor constant:14.0],
        [self.providerPlanCaptionLabel.leadingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.leadingAnchor],
        [self.providerPlanCaptionLabel.trailingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.trailingAnchor],

        [self.providerCTAButton.topAnchor constraintEqualToAnchor:self.providerPlanCaptionLabel.bottomAnchor constant:16.0],
        [self.providerCTAButton.leadingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.leadingAnchor],
        [self.providerCTAButton.trailingAnchor constraintEqualToAnchor:self.providerPreviewTitleLabel.trailingAnchor],
        [self.providerCTAButton.bottomAnchor constraintEqualToAnchor:self.providerSectionCard.bottomAnchor constant:-18.0],
    ]];

    return self.providerSectionCard;
}

- (UIView *)pp_buildSettingsSection {
    self.settingsSectionCard = [[UIView alloc] init];
    self.settingsSectionCard.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *rowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    rowButton.translatesAutoresizingMaskIntoConstraints = NO;
    rowButton.backgroundColor = [self pp_innerSurfaceColor];
    PPApplyContinuousCorners(rowButton, PPCornerCard);
    rowButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    rowButton.contentEdgeInsets = UIEdgeInsetsZero;
    // Grows instead of clipping when the user raises the text size.
    [rowButton.heightAnchor constraintGreaterThanOrEqualToConstant:82.0].active = YES;
    [rowButton addTarget:self action:@selector(pp_showMoreActions) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:rowButton style:PPButtonAnimationStyleDefault];
    [self.settingsSectionCard addSubview:rowButton];

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    PPStyleAccentPlate(iconPlate, 20.0, 0.10);
    iconPlate.userInteractionEnabled = NO;
    [rowButton addSubview:iconPlate];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"
                                                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    iconView.userInteractionEnabled = NO;
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [self pp_label:kLang(@"ProfileSettings_SettingsRowTitle")
                                    font:[Styling fontBold:PPFontCallout]
                                   color:PrimaryTextClr
                                   lines:2
                               textStyle:UIFontTextStyleCallout];
    titleLabel.userInteractionEnabled = NO;
    [rowButton addSubview:titleLabel];

    UILabel *subtitleLabel = [self pp_label:kLang(@"ProfileSettings_SettingsRowSubtitle")
                                       font:[Styling fontMedium:PPFontFootnote]
                                      color:SeconderyTextClr
                                      lines:2
                                  textStyle:UIFontTextStyleFootnote];
    subtitleLabel.userInteractionEnabled = NO;
    [rowButton addSubview:subtitleLabel];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"
                                                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = AppTertiaryTextClr;
    chevron.userInteractionEnabled = NO;
    [rowButton addSubview:chevron];

    // The row is drawn from plain subviews, so VoiceOver needs one composed element.
    NSMutableArray<NSString *> *spokenParts = [NSMutableArray array];
    if (titleLabel.text.length) [spokenParts addObject:titleLabel.text];
    if (subtitleLabel.text.length) [spokenParts addObject:subtitleLabel.text];
    rowButton.isAccessibilityElement = YES;
    rowButton.accessibilityTraits = UIAccessibilityTraitButton;
    rowButton.accessibilityLabel = [spokenParts componentsJoinedByString:@", "];

    [NSLayoutConstraint activateConstraints:@[
        [self.settingsSectionCard.heightAnchor constraintGreaterThanOrEqualToConstant:118.0],
        [rowButton.topAnchor constraintEqualToAnchor:self.settingsSectionCard.topAnchor constant:18.0],
        [rowButton.leadingAnchor constraintEqualToAnchor:self.settingsSectionCard.leadingAnchor constant:18.0],
        [rowButton.trailingAnchor constraintEqualToAnchor:self.settingsSectionCard.trailingAnchor constant:-18.0],
        [rowButton.bottomAnchor constraintEqualToAnchor:self.settingsSectionCard.bottomAnchor constant:-18.0],

        [iconPlate.leadingAnchor constraintEqualToAnchor:rowButton.leadingAnchor constant:14.0],
        [iconPlate.centerYAnchor constraintEqualToAnchor:rowButton.centerYAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:40.0],
        [iconPlate.heightAnchor constraintEqualToConstant:40.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:rowButton.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-12.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-12.0],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:rowButton.bottomAnchor constant:-16.0],

        [chevron.trailingAnchor constraintEqualToAnchor:rowButton.trailingAnchor constant:-16.0],
        [chevron.centerYAnchor constraintEqualToAnchor:rowButton.centerYAnchor],
    ]];

    return self.settingsSectionCard;
}

- (UIView *)pp_makeKeyValueRowWithTitle:(NSString *)title valueLabel:(UILabel * __strong *)valueLabelPtr {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [self pp_innerSurfaceColor];
    PPApplyContinuousCorners(row, PPCornerMedium);

    UILabel *titleLabel = [self pp_label:title font:[Styling fontBold:PPFontFootnote] color:SeconderyTextClr lines:1
                               textStyle:UIFontTextStyleFootnote];
    UILabel *valueLabel = [self pp_label:@""
                                    font:[Styling fontMedium:PPFontSubheadline]
                                   color:PrimaryTextClr
                                   lines:2
                               textStyle:UIFontTextStyleSubheadline];
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [row addSubview:titleLabel];
    [row addSubview:valueLabel];

    // Title + value read as one element; the value is refreshed with the content.
    row.isAccessibilityElement = YES;
    row.accessibilityLabel = title;

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14.0],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12.0],
    ]];

    if (valueLabelPtr) {
        *valueLabelPtr = valueLabel;
    }
    return row;
}

#pragma mark - Data

- (void)pp_syncEditedFieldsFromUser {
    UserModel *user = UsrMgr.currentUser;
    NSString *name = [self pp_displayNameForUser:user];
    self.editedName = name;
    self.editedEmail = user.UserEmail.length ? user.UserEmail : (user.email.length ? user.email : @"");
    self.editedPhone = user.MobileNo.length ? user.MobileNo : @"";
}

- (void)pp_startProviderStateObservation {
    [self.providerStateListener remove];
    __weak typeof(self) weakSelf = self;
    self.providerStateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.providerState = state;
        strongSelf.providerStateError = error;
        [strongSelf pp_refreshProviderPreview];
    }];
}

- (void)pp_loadCoverImageURLs {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) return;
    FIRDocumentReference *doc = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    __weak typeof(self) weakSelf = self;
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error || !snap.exists) return;
        NSArray *urls = [snap[@"coverImageUrls"] isKindOfClass:NSArray.class] ? snap[@"coverImageUrls"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.coverImageURLs removeAllObjects];
            for (id item in urls) {
                if ([item isKindOfClass:NSString.class] && ((NSString *)item).length > 0) {
                    [strongSelf.coverImageURLs addObject:item];
                }
            }
            [strongSelf pp_refreshProviderPreview];
        });
    }];
}

- (void)pp_refreshAllContent {
    [self pp_refreshHero];
    [self pp_refreshEditableFields];
    [self pp_refreshProviderPreview];
    [self pp_checkHasEdits];
}

- (void)pp_refreshHero {
    UserModel *user = UsrMgr.currentUser;
    NSString *displayName = [self pp_displayNameForUser:user];
    NSString *roleName = [PPRolePermission localizedRoleName:user.role];
    NSString *email = user.UserEmail.length ? user.UserEmail : user.email;
    NSMutableArray<NSString *> *metaParts = [NSMutableArray array];
    if (email.length) [metaParts addObject:email];
    if (user.MobileNo.length) [metaParts addObject:user.MobileNo];

    self.heroNameLabel.text = displayName.length ? displayName : kLang(@"ProfileSettings_NoContact");
    self.heroSubtitleLabel.text = kLang(@"ProfileSettings_HeroSubtitle");
    self.heroRolePillLabel.text = [NSString stringWithFormat:@"  %@  ", roleName.length ? roleName : @"—"];
    self.heroMetaLabel.text = metaParts.count ? [metaParts componentsJoinedByString:@"  •  "] : kLang(@"ProfileSettings_NoContact");

    NSString *avatarURL = [self pp_avatarURLStringForUser:user];
    if (avatarURL.length > 0) {
        [self.heroAvatarView setImageFromUrl:avatarURL placeholderImage:@"Profile5" completion:nil];
    } else {
        self.heroAvatarView.image = [UIImage imageNamed:@"Profile5"];
    }
}

- (void)pp_refreshEditableFields {
    self.nameField.text = self.editedName ?: @"";
    self.emailField.text = self.editedEmail ?: @"";
    self.phoneField.text = self.editedPhone ?: @"";
}

- (void)pp_refreshProviderPreview {
    UserModel *user = UsrMgr.currentUser;
    NSString *displayName = [self pp_displayNameForUser:user];
    NSString *email = self.editedEmail.length ? self.editedEmail : (user.UserEmail.length ? user.UserEmail : user.email);
    NSString *phone = self.editedPhone.length ? self.editedPhone : user.MobileNo;
    NSString *avatarURL = [self pp_avatarURLStringForUser:user];
    NSString *coverURL = self.coverImageURLs.firstObject ?: @"";
    NSString *workspace = [self pp_primaryProviderWorkspaceTitle];
    NSString *status = [self pp_providerStatusTitle];
    NSString *planSummary = [self pp_providerPlanSummary];

    self.providerNameValueLabel.text = displayName.length ? displayName : @"—";
    self.providerEmailValueLabel.text = email.length ? email : @"—";
    self.providerPhoneValueLabel.text = phone.length ? phone : @"—";
    self.providerCoverValueLabel.text = [NSString stringWithFormat:kLang(@"ProfileSettings_ProviderPreviewCoverCountFormat"), (unsigned long)self.coverImageURLs.count];
    [self pp_syncRowAccessibilityValueForLabel:self.providerNameValueLabel];
    [self pp_syncRowAccessibilityValueForLabel:self.providerEmailValueLabel];
    [self pp_syncRowAccessibilityValueForLabel:self.providerPhoneValueLabel];
    [self pp_syncRowAccessibilityValueForLabel:self.providerCoverValueLabel];
    self.providerStatusPillLabel.text = status;
    self.providerPreviewSubtitleLabel.text = workspace.length
        ? [NSString stringWithFormat:kLang(@"ProfileSettings_ProviderPreviewWorkspaceFormat"), workspace]
        : kLang(@"ProfileSettings_ProviderPreviewEmpty");
    self.providerPlanCaptionLabel.text = planSummary;
    self.providerCTAButton.enabled = YES;
    self.providerCTAButton.alpha = 1.0;

    if (avatarURL.length > 0) {
        [self.providerLogoView setImageFromUrl:avatarURL placeholderImage:@"Profile5" completion:nil];
    } else {
        self.providerLogoView.image = [UIImage imageNamed:@"Profile5"];
    }

    if (coverURL.length > 0) {
        self.providerCoverImageView.hidden = NO;
        self.providerCoverFallbackView.hidden = YES;
        [self.providerCoverImageView setImageFromUrl:coverURL placeholderImage:@"Profile5" completion:nil];
    } else {
        self.providerCoverImageView.hidden = YES;
        self.providerCoverFallbackView.hidden = NO;
        self.providerCoverImageView.image = nil;
    }

    // The placeholder plate keeps spinning until the provider state observation
    // has produced either a state or an error.  This is the system loading
    // control (not decorative motion), so it is not suppressed by Reduce Motion.
    BOOL providerStateResolved = (self.providerState != nil) || (self.providerStateError != nil);
    if (providerStateResolved || self.providerCoverFallbackView.hidden) {
        [self.providerLoadingIndicator stopAnimating];
    } else {
        [self.providerLoadingIndicator startAnimating];
    }
}

#pragma mark - Editing

- (void)pp_fieldDidChange:(UITextField *)sender {
    NSString *text = [sender.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (sender == self.nameField) {
        self.editedName = text;
    } else if (sender == self.emailField) {
        self.editedEmail = text;
    } else if (sender == self.phoneField) {
        self.editedPhone = text;
    }
    [self pp_checkHasEdits];
    [self pp_refreshProviderPreview];
}

- (void)pp_checkHasEdits {
    UserModel *user = UsrMgr.currentUser;
    NSString *origName = [self pp_displayNameForUser:user];
    NSString *origEmail = user.UserEmail.length ? user.UserEmail : (user.email.length ? user.email : @"");
    NSString *origPhone = user.MobileNo.length ? user.MobileNo : @"";

    self.hasEdits =
        ![PPSafeString(self.editedName) isEqualToString:PPSafeString(origName)] ||
        ![PPSafeString(self.editedEmail) isEqualToString:PPSafeString(origEmail)] ||
        ![PPSafeString(self.editedPhone) isEqualToString:PPSafeString(origPhone)];
    [self pp_refreshSaveButtonState];
}

- (void)pp_refreshSaveButtonState {
    BOOL enabled = self.hasEdits;
    self.saveButton.enabled = enabled;
    self.saveButton.alpha = enabled ? 1.0 : 0.58;
    self.saveButton.backgroundColor = enabled ? AppPrimaryClr : [[AppPrimaryClr colorWithAlphaComponent:0.42] copy];
    self.saveFootnoteLabel.textColor = enabled ? SeconderyTextClr : [UIColor ppTextTertiary];
}

- (void)pp_saveProfile {
    UserModel *user = UsrMgr.currentUser;
    if (!user) return;

    NSString *name = [PPSafeString(self.editedName) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *email = [PPSafeString(self.editedEmail) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *phone = [PPSafeString(self.editedPhone) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (name.length == 0) {
        [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:kLang(@"ProfileSettings_NameRequired")];
        return;
    }

    [self.view endEditing:YES];
    [PPHUD showIndeterminateIn:self.view title:kLang(@"Saving") subtitle:nil];

    NSString *currentName = [self pp_displayNameForUser:user];
    NSString *currentEmail = user.UserEmail.length ? user.UserEmail : (user.email.length ? user.email : @"");
    NSString *currentPhone = user.MobileNo.length ? user.MobileNo : @"";

    BOOL nameChanged = ![name isEqualToString:currentName];
    BOOL emailChanged = ![email isEqualToString:currentEmail];
    BOOL phoneChanged = ![phone isEqualToString:currentPhone];

    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;

    if (nameChanged) {
        dispatch_group_enter(group);
        user.displayName = name;
        [UsrMgr p_cacheUser:user];
        [user SYNC:^(NSError *error) {
            if (error && !firstError) firstError = error;
            dispatch_group_leave(group);
        }];
    }

    if (emailChanged && email.length > 0) {
        dispatch_group_enter(group);
        [FUM updateEmail:email completion:^(NSError *error) {
            if (!error) {
                user.UserEmail = email;
                user.email = email;
                [UsrMgr p_cacheUser:user];
            } else if (!firstError) {
                firstError = error;
            }
            dispatch_group_leave(group);
        }];
    }

    if (phoneChanged) {
        dispatch_group_enter(group);
        user.MobileNo = phone;
        [UsrMgr p_cacheUser:user];
        [user SYNC:^(NSError *error) {
            if (error && !firstError) firstError = error;
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [PPHUD dismiss];
        if (firstError) {
            [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:firstError.localizedDescription];
            return;
        }
        [self pp_syncEditedFieldsFromUser];
        [self pp_refreshAllContent];
        [PPToast toast:kLang(@"ProfileUpdated") style:PPToastStyleSuccess haptic:YES duration:1.8];
    });
}

#pragma mark - Provider CTA

- (void)pp_openProviderProfileEditor {
    [PPFunc pp_playTapEffect];
    PPProviderProfileEditorViewController *controller = [[PPProviderProfileEditorViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - More Actions

- (void)pp_showMoreActions {
    [PPFunc pp_playTapEffect];
    NSMutableArray<NSDictionary *> *actions = [NSMutableArray array];
    [actions addObject:@{
        @"action": @(PPProProfileSettingsActionNotifications),
        @"icon": @"bell.badge.fill",
        @"title": kLang(@"NotificationSettings"),
        @"subtitle": kLang(@"NotificationSettingsSubtitle"),
        @"destructive": @NO
    }];
    [actions addObject:@{
        @"action": @(PPProProfileSettingsActionAppearance),
        @"icon": @"circle.lefthalf.filled",
        @"title": kLang(@"AppearanceSettings"),
        @"subtitle": kLang(@"AppearanceSettingsSubtitle"),
        @"destructive": @NO
    }];
    NSString *languageCode = [Language currentLanguageCode] ?: @"en";
    NSString *languageTitle = [languageCode isEqualToString:@"ar"]
        ? (kLang(@"ProfileSettings_LanguageArabic") ?: @"العربية")
        : (kLang(@"ProfileSettings_LanguageEnglish") ?: @"English");
    [actions addObject:@{
        @"action": @(PPProProfileSettingsActionLanguage),
        @"icon": @"globe",
        @"title": kLang(@"ProfileSettings_LanguageTitle"),
        @"subtitle": [NSString stringWithFormat:kLang(@"ProfileSettings_LanguageSubtitleFormat"), languageTitle],
        @"destructive": @NO
    }];
    [actions addObject:@{
        @"action": @(PPProProfileSettingsActionLogout),
        @"icon": @"power.circle.fill",
        @"title": kLang(@"LogOut"),
        @"subtitle": kLang(@"ProfileSettings_LogoutSubtitle"),
        @"destructive": @YES
    }];

    __weak typeof(self) weakSelf = self;
    PPProProfileSettingsSheetViewController *sheet =
    [[PPProProfileSettingsSheetViewController alloc] initWithActions:actions.copy
                                                           selection:^(PPProProfileSettingsAction action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        switch (action) {
            case PPProProfileSettingsActionNotifications:
                [self.navigationController pushViewController:[[NotificationSettingsViewController alloc] init] animated:YES];
                break;
            case PPProProfileSettingsActionAppearance:
                [self pp_showThemePicker];
                break;
            case PPProProfileSettingsActionLanguage:
                [self pp_showLanguagePicker];
                break;
            case PPProProfileSettingsActionLogout:
                [self pp_logoutAction];
                break;
        }
    }];
    [self presentViewController:sheet animated:NO completion:nil];
}

- (void)pp_showThemePicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"AppearanceSettings")
                                                                   message:kLang(@"AppearanceSettingsSubtitle")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *themes = @[
        @{@"key": PPProThemePreferenceSystem, @"title": kLang(@"ThemeSystem")},
        @{@"key": PPProThemePreferenceLight, @"title": kLang(@"ThemeLight")},
        @{@"key": PPProThemePreferenceDark, @"title": kLang(@"ThemeDark")},
    ];

    __weak typeof(self) weakSelf = self;
    for (NSDictionary *theme in themes) {
        NSString *title = [theme[@"key"] isEqualToString:PPProCurrentThemePreference()]
            ? [NSString stringWithFormat:@"✓ %@", theme[@"title"]]
            : theme[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            PPProApplyThemePreference(theme[@"key"]);
            [PPToast toast:kLang(@"ThemeUpdated") style:PPToastStyleSuccess haptic:YES duration:1.5];
            [weakSelf pp_refreshAllContent];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 40.0, 1.0, 1.0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_showLanguagePicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"Confirm_LanguageChange_Title")
                                                                   message:kLang(@"ProfileSettings_LanguageSheetSubtitle")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *currentLanguage = [Language currentLanguageCode] ?: @"en";
    NSArray<NSDictionary *> *languages = @[
        @{@"code": @"en", @"title": kLang(@"ProfileSettings_LanguageEnglish")},
        @{@"code": @"ar", @"title": kLang(@"ProfileSettings_LanguageArabic")}
    ];

    __weak typeof(self) weakSelf = self;
    for (NSDictionary *language in languages) {
        NSString *code = language[@"code"];
        NSString *title = [code isEqualToString:currentLanguage]
            ? [NSString stringWithFormat:@"✓ %@", language[@"title"]]
            : language[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [weakSelf pp_applyLanguageCode:code];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 40.0, 1.0, 1.0);
        popover.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pp_applyLanguageCode:(NSString *)code {
    NSString *target = code.length ? code : @"en";
    NSString *current = [Language currentLanguageCode] ?: @"en";
    if ([target isEqualToString:current]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    UIImage *warnIcon = [UIImage systemImageNamed:@"globe.central.south.asia.fill"];
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"Confirm_LanguageChange_Title")
                             subtitle:kLang(@"Confirm_LanguageChange_Msg")
                          placeholder:nil
                        confirmButton:kLang(@"Confirm")
                         cancelButton:kLang(@"Cancel")
                                 icon:warnIcon
                         confirmBlock:^{
        [Language userSelectedLanguage:target];
        [PPAlertHelper showSuccessIn:weakSelf
                               title:kLang(@"Success")
                            subtitle:kLang(@"Language changed successfully")];
    }
                          cancelBlock:nil];
}

- (void)pp_logoutAction {
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"LogOut")
                             subtitle:kLang(@"LogOutConfirmation")
                          placeholder:nil
                        confirmButton:kLang(@"LogOut")
                         cancelButton:kLang(@"Cancel")
                         confirmBlock:^{
        [UsrMgr signOut];
    } cancelBlock:nil];
}

#pragma mark - Helpers

- (void)pp_applyStaticColors {
    // Re-runs the card styling so token fills *and* the resolved border CGColor
    // follow light/dark appearance changes.
    [self pp_applySectionCardStyling];
}

- (void)pp_applySectionCardStyling {
    // Canonical Pro card surface: token fill + hairline border + card shadow.
    PPStyleCardSurface(self.accountSectionCard, PPCornerHero);
    PPStyleCardSurface(self.settingsSectionCard, PPCornerHero);
    // The provider card clips its cover art, so a drop shadow would be clipped
    // away: fill + hairline border + continuous corners only.
    self.providerSectionCard.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(self.providerSectionCard, PPCornerHero);
    self.providerSectionCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.providerSectionCard.layer.borderColor = [self pp_borderColor].CGColor;
}

- (UIColor *)pp_surfaceColor {
    return [UIColor ppElevatedSurface];
}

- (UIColor *)pp_innerSurfaceColor {
    return [UIColor ppSurface];
}

- (UIColor *)pp_borderColor {
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.72];
}

- (UILabel *)pp_label:(NSString *)text font:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

/// Same label, but the brand font is wrapped in the matching text style so it
/// actually scales with the user's text-size preference.  Only used where the
/// label's container can grow.
- (UILabel *)pp_label:(NSString *)text
                 font:(UIFont *)font
                color:(UIColor *)color
                lines:(NSInteger)lines
            textStyle:(UIFontTextStyle)textStyle {
    UILabel *label = [self pp_label:text font:font color:color lines:lines];
    PPEnableDynamicType(label, textStyle);
    return label;
}

- (void)pp_syncRowAccessibilityValueForLabel:(UILabel *)valueLabel {
    valueLabel.superview.accessibilityValue = valueLabel.text;
}

- (NSString *)pp_displayNameForUser:(UserModel *)user {
    NSString *displayName = PPSafeString(user.displayName);
    if (displayName.length == 0) displayName = PPSafeString([user PPBestDisplayName]);
    if (displayName.length == 0) displayName = PPSafeString(user.UserName);
    return displayName;
}

- (NSString *)pp_avatarURLStringForUser:(UserModel *)user {
    if ([user.UserImageUrl isKindOfClass:NSURL.class]) {
        return user.UserImageUrl.absoluteString ?: @"";
    }
    if ([user.UserImageUrl isKindOfClass:NSString.class]) {
        return (NSString *)user.UserImageUrl ?: @"";
    }
    return PPSafeString(user.photoURL);
}

- (BOOL)pp_canManageMarketplace {
    return UsrMgr.currentUser.canAccessProviderMarketplaceFeature;
}

- (BOOL)pp_canManagePharmacy {
    UserModel *user = UsrMgr.currentUser;
    return user.canPharmacyFeature && user.canManagePetMedicinesPermission;
}

- (BOOL)pp_canManageServices {
    UserModel *user = UsrMgr.currentUser;
    return (user.canOfferServices || user.canOfferServicesFeature) && user.canManageServiceProviderPermission;
}

- (BOOL)pp_canManageVets {
    UserModel *user = UsrMgr.currentUser;
    return user.canVetFeature && (user.canEditVetInfoPermission || user.canManageVetPermission || user.canPostVetProfilePermission);
}

- (BOOL)pp_canManageDelivery {
    if (!PPProviderTypeIsEnabledInProApp(PPProviderTypeDeliverySubscription)) {
        return NO;
    }
    UserModel *user = UsrMgr.currentUser;
    return (user.canDelivery || user.canDeliveryFeature) && user.canManageDeliveryPermission;
}

- (BOOL)pp_canManageDeliveryCompany {
    UserModel *user = UsrMgr.currentUser;
    return user.canDeliveryCompanyFeature || self.providerState.canDeliveryCompany;
}

- (NSString *)pp_primaryProviderWorkspaceTitle {
    if ([self pp_canManageMarketplace]) return kLang(@"Market_Title");
    if ([self pp_canManagePharmacy]) return kLang(@"Pharmacy_Manage_Title");
    if ([self pp_canManageServices]) return kLang(@"ManageServices");
    if ([self pp_canManageVets]) return kLang(@"Vet_Manage_Title");
    if ([self pp_canManageDeliveryCompany]) return kLang(@"DeliveryCompany_Title");
    if ([self pp_canManageDelivery]) return kLang(@"DeliveryManagement");
    if (self.providerState.partnerOnboardingVisible || self.providerState.hasAnyLifecycleRecord) return kLang(@"ProviderSubscriptionCardTitle");
    return @"";
}

- (NSString *)pp_providerStatusTitle {
    if (self.providerStateError) return kLang(@"ProviderHeroErrorBadge");
    if (self.providerState.isBlocked) return kLang(@"ProviderHeroBlockedBadge");

    NSArray<NSNumber *> *types = @[
        @(PPProviderTypeMarketplace),
        @(PPProviderTypeDeliveryCompany),
        @(PPProviderTypeVet),
        @(PPProviderTypePharmacy),
        @(PPProviderTypeDeliverySubscription),
        @(PPProviderTypeService)
    ];
    for (NSNumber *typeValue in types) {
        PPProviderType type = typeValue.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) {
            continue;
        }
        if ([self.providerState isActiveForType:type]) {
            return kLang(@"ProviderStatusActive");
        }
        PPProviderApplication *application = [self.providerState applicationForType:type];
        NSString *status = [[PPSafeString(application.status) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([status isEqualToString:@"pending"] || [status isEqualToString:@"under_review"]) {
            return kLang(@"ProviderStatusUnderReview");
        }
    }
    if ([self pp_primaryProviderWorkspaceTitle].length > 0) {
        return kLang(@"ProfileSettings_ProviderPreviewStatusReady");
    }
    return kLang(@"ProfileSettings_ProviderPreviewStatusUnavailable");
}

- (NSString *)pp_providerPlanSummary {
    if (self.providerStateError) {
        return self.providerStateError.localizedDescription.length ? self.providerStateError.localizedDescription : kLang(@"ProviderStateErrorSubtitle");
    }
    if (self.providerState.isBlocked) {
        return kLang(@"ProviderSubscriptionCardBlockedSubtitle");
    }

    NSArray<NSNumber *> *types = @[
        @(PPProviderTypeMarketplace),
        @(PPProviderTypeDeliveryCompany),
        @(PPProviderTypeVet),
        @(PPProviderTypePharmacy),
        @(PPProviderTypeDeliverySubscription),
        @(PPProviderTypeService)
    ];
    for (NSNumber *typeValue in types) {
        PPProviderType type = typeValue.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) {
            continue;
        }
        PPProviderProfile *profile = [self.providerState profileForType:type];
        if ([self.providerState isActiveForType:type] || [PPSafeString(profile.status).lowercaseString isEqualToString:@"active"]) {
            NSString *planName = profile.localizedPlanName.length ? profile.localizedPlanName : kLang(@"ProviderSubscriptionCardActivePlanFallback");
            return [NSString stringWithFormat:kLang(@"ProfileSettings_ProviderPreviewPlanFormat"), planName];
        }

        PPProviderApplication *application = [self.providerState applicationForType:type];
        NSString *applicationStatus = [[PPSafeString(application.status) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([applicationStatus isEqualToString:@"pending"] || [applicationStatus isEqualToString:@"under_review"]) {
            return kLang(@"ProviderSubscriptionCardReviewSubtitle");
        }
    }

    if ([self pp_primaryProviderWorkspaceTitle].length > 0) {
        return kLang(@"ProfileSettings_ProviderPreviewWorkspaceHint");
    }
    return kLang(@"ProfileSettings_ProviderPreviewEmpty");
}

#pragma mark - Entrance

- (void)pp_prepareEntranceState {
    if (self.didPrepareEntrance || self.didRunEntrance) return;
    self.didPrepareEntrance = YES;
    // Reduce Motion: nothing is staged, so there is no entrance left to animate.
    if (PPMotionReduced()) return;
    self.heroCard.alpha = 0.0;
    self.heroCard.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.accountSectionCard.alpha = 0.0;
    self.accountSectionCard.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.providerSectionCard.alpha = 0.0;
    self.providerSectionCard.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)pp_runEntranceIfNeeded {
    if (self.didRunEntrance) return;
    self.didRunEntrance = YES;
    if (PPMotionReduced()) {
        self.heroCard.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
        self.accountSectionCard.alpha = 1.0;
        self.accountSectionCard.transform = CGAffineTransformIdentity;
        self.providerSectionCard.alpha = 1.0;
        self.providerSectionCard.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroCard.alpha = 1.0;
        self.heroCard.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.06
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.accountSectionCard.alpha = 1.0;
        self.accountSectionCard.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42
                          delay:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.providerSectionCard.alpha = 1.0;
        self.providerSectionCard.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.nameField) {
        [self.emailField becomeFirstResponder];
    } else if (textField == self.emailField) {
        [self.phoneField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [self.view endEditing:YES];
}

@end
