//
//  NotificationSettingsViewController.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 24/08/2025.
//

#import "NotificationSettingsViewController.h"
#import "Language.h"
#import "PPButtonHelper.h"
#import "Styling.h"
#import "UIViewController+PPNavBar.h"
#import <UserNotifications/UserNotifications.h>

static NSString * const kPPProNotifMasterPreferenceKey = @"pp_notif_master_enabled";
static NSString * const kPPProNotifSoundPreferenceKey = @"pp_notif_sound_enabled";
static NSString * const kPPProNotifCategoryGeneralKey = @"pp_notif_cat_general";
static NSString * const kPPProNotifCategoryOrdersKey = @"pp_notif_cat_order";
static NSString * const kPPProNotifCategoryDeliveryKey = @"pp_notif_cat_delivery";
static NSString * const kPPProNotifCategoryReviewKey = @"pp_notif_cat_review";
static NSString * const kPPProNotifCategoryWarningKey = @"pp_notif_cat_warning";

@interface NotificationSettingsViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusTitleLabel;
@property (nonatomic, strong) UILabel *statusBodyLabel;
@property (nonatomic, strong) UIButton *statusActionButton;
@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UISwitch *soundSwitch;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UISwitch *> *categorySwitches;
@property (nonatomic, strong) NSMutableArray<UIView *> *categoryRows;
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
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self pp_buildLayout];
    [self pp_prepareEntranceAnimation];
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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor;
        [self pp_updateStatusCardForCurrentAuthorization];
    }
}

#pragma mark - Layout

- (void)pp_buildLayout {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.delegate = self;
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.spacing = 18.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-34.0],
    ]];

    [self.contentStack addArrangedSubview:[self pp_buildHeroSection]];
    [self.contentStack addArrangedSubview:[self pp_buildStatusCard]];
    [self.contentStack addArrangedSubview:[self pp_buildPrimaryControlsCard]];
    [self.contentStack addArrangedSubview:[self pp_buildCategoryCard]];
    [self.contentStack addArrangedSubview:[self pp_buildFootnoteLabel]];
}

- (UIView *)pp_buildHeroSection {
    PPHero *container = [[PPHero alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10] ?: [UIColor.systemBlueColor colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 23.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:iconSurface];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.badge.fill"
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    iconView.isAccessibilityElement = NO;
    [iconSurface addSubview:iconView];

    UILabel *eyebrow = [self pp_labelWithText:kLang(@"NotificationSettings_Eyebrow")
                                         font:[Styling fontBold:11.0]
                                        color:AppPrimaryClr ?: UIColor.systemBlueColor
                                        lines:1];
    eyebrow.text = [eyebrow.text uppercaseString];
    [container addSubview:eyebrow];

    UILabel *title = [self pp_labelWithText:kLang(@"NotificationSettings_HeroTitle")
                                       font:[Styling fontBold:31.0]
                                      color:PrimaryTextClr ?: UIColor.labelColor
                                      lines:2];
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:title.font];
    [container addSubview:title];

    UILabel *subtitle = [self pp_labelWithText:kLang(@"NotificationSettings_HeroSubtitle")
                                          font:[Styling fontMedium:14.0]
                                         color:[SeconderyTextClr colorWithAlphaComponent:0.86] ?: UIColor.secondaryLabelColor
                                         lines:3];
    subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:subtitle.font];
    [container addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:container.topAnchor constant:4.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [iconSurface.widthAnchor constraintEqualToConstant:46.0],
        [iconSurface.heightAnchor constraintEqualToConstant:46.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [eyebrow.topAnchor constraintEqualToAnchor:container.topAnchor constant:6.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:14.0],
        [eyebrow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:7.0],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4.0],
    ]];

    return container;
}

- (UIView *)pp_buildStatusCard {
    PPHero *card = [[PPHero alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusCard = card;

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

    self.statusTitleLabel = [self pp_labelWithText:kLang(@"NotificationSettings_CheckingStatus")
                                              font:[Styling fontBold:16.0]
                                             color:PrimaryTextClr ?: UIColor.labelColor
                                             lines:2];
    self.statusTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:self.statusTitleLabel.font];
    [card addSubview:self.statusTitleLabel];

    self.statusBodyLabel = [self pp_labelWithText:kLang(@"NotificationSettings_CheckingStatusSubtitle")
                                             font:[Styling fontMedium:12.5]
                                            color:[SeconderyTextClr colorWithAlphaComponent:0.84] ?: UIColor.secondaryLabelColor
                                            lines:3];
    self.statusBodyLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:self.statusBodyLabel.font];
    [card addSubview:self.statusBodyLabel];

    self.statusActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.statusActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusActionButton.titleLabel.font = [Styling fontBold:13.0];
    self.statusActionButton.layer.cornerRadius = 17.0;
    self.statusActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusActionButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [self.statusActionButton setTitle:kLang(@"NotificationSettings_OpenIOSSettings") forState:UIControlStateNormal];
    [self.statusActionButton addTarget:self action:@selector(pp_permissionActionTapped) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.statusActionButton style:PPButtonAnimationStyleDefault];
    [card addSubview:self.statusActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:42.0],
        [iconSurface.heightAnchor constraintEqualToConstant:42.0],
        [self.statusIconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:19.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:19.0],

        [self.statusTitleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [self.statusTitleLabel.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:13.0],
        [self.statusTitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],

        [self.statusBodyLabel.topAnchor constraintEqualToAnchor:self.statusTitleLabel.bottomAnchor constant:5.0],
        [self.statusBodyLabel.leadingAnchor constraintEqualToAnchor:self.statusTitleLabel.leadingAnchor],
        [self.statusBodyLabel.trailingAnchor constraintEqualToAnchor:self.statusTitleLabel.trailingAnchor],

        [self.statusActionButton.topAnchor constraintEqualToAnchor:self.statusBodyLabel.bottomAnchor constant:14.0],
        [self.statusActionButton.leadingAnchor constraintEqualToAnchor:self.statusTitleLabel.leadingAnchor],
        [self.statusActionButton.heightAnchor constraintEqualToConstant:38.0],
        [self.statusActionButton.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
    ]];

    [self pp_updateStatusCardForCurrentAuthorization];
    return card;
}

- (UIView *)pp_buildPrimaryControlsCard {
    PPHero *card = [[PPHero alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [self pp_verticalStackWithSpacing:0.0];
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:8.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8.0],
    ]];

    self.masterSwitch = [self pp_addPreferenceRowToStack:stack
                                                   title:kLang(@"NotificationSettings_MasterTitle")
                                                subtitle:kLang(@"NotificationSettings_MasterSubtitle")
                                                iconName:@"bell.and.waves.left.and.right.fill"
                                             accentColor:AppPrimaryClr ?: UIColor.systemBlueColor
                                           preferenceKey:kPPProNotifMasterPreferenceKey
                                            defaultValue:YES
                                               separator:YES];

    self.soundSwitch = [self pp_addPreferenceRowToStack:stack
                                                  title:kLang(@"NotificationSettings_SoundTitle")
                                               subtitle:kLang(@"NotificationSettings_SoundSubtitle")
                                               iconName:@"speaker.wave.2.fill"
                                            accentColor:UIColor.systemOrangeColor
                                          preferenceKey:kPPProNotifSoundPreferenceKey
                                           defaultValue:YES
                                              separator:NO];

    return card;
}

- (UIView *)pp_buildCategoryCard {
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *sectionTitle = [self pp_labelWithText:kLang(@"NotificationSettings_CategoriesTitle")
                                              font:[Styling fontBold:13.0]
                                             color:[PrimaryTextClr colorWithAlphaComponent:0.66] ?: UIColor.secondaryLabelColor
                                             lines:1];
    sectionTitle.text = [sectionTitle.text uppercaseString];
    [wrapper addSubview:sectionTitle];

    PPHero *card = [[PPHero alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapper addSubview:card];

    UIStackView *stack = [self pp_verticalStackWithSpacing:0.0];
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [sectionTitle.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
        [sectionTitle.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:2.0],
        [sectionTitle.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-2.0],

        [card.topAnchor constraintEqualToAnchor:sectionTitle.bottomAnchor constant:10.0],
        [card.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:8.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8.0],
    ]];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryOrdersTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryOrdersSubtitle")
                          iconName:@"shippingbox.fill"
                       accentColor:AppPrimaryClr ?: UIColor.systemBlueColor
                     preferenceKey:kPPProNotifCategoryOrdersKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryDeliveryTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryDeliverySubtitle")
                          iconName:@"truck.box.fill"
                       accentColor:UIColor.systemOrangeColor
                     preferenceKey:kPPProNotifCategoryDeliveryKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryReviewTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryReviewSubtitle")
                          iconName:@"doc.text.magnifyingglass"
                       accentColor:UIColor.systemTealColor
                     preferenceKey:kPPProNotifCategoryReviewKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryWarningTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryWarningSubtitle")
                          iconName:@"shield.lefthalf.filled"
                       accentColor:UIColor.systemRedColor
                     preferenceKey:kPPProNotifCategoryWarningKey
                      defaultValue:YES
                         separator:YES];

    [self pp_addCategoryRowToStack:stack
                             title:kLang(@"NotificationSettings_CategoryGeneralTitle")
                          subtitle:kLang(@"NotificationSettings_CategoryGeneralSubtitle")
                          iconName:@"sparkles"
                       accentColor:UIColor.systemPurpleColor
                     preferenceKey:kPPProNotifCategoryGeneralKey
                      defaultValue:YES
                         separator:NO];

    return wrapper;
}

- (UILabel *)pp_buildFootnoteLabel {
    UILabel *label = [self pp_labelWithText:kLang(@"NotificationSettings_Footnote")
                                       font:[Styling fontMedium:12.0]
                                      color:[SeconderyTextClr colorWithAlphaComponent:0.78] ?: UIColor.secondaryLabelColor
                                      lines:0];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

#pragma mark - Rows

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
                                                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.5 weight:UIImageSymbolWeightSemibold]]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.isAccessibilityElement = NO;
    [iconSurface addSubview:iconView];

    UILabel *titleLabel = [self pp_labelWithText:title
                                            font:[Styling fontBold:15.0]
                                           color:PrimaryTextClr ?: UIColor.labelColor
                                           lines:2];
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:titleLabel.font];
    [row addSubview:titleLabel];

    UILabel *subtitleLabel = [self pp_labelWithText:subtitle
                                               font:[Styling fontMedium:12.0]
                                              color:[SeconderyTextClr colorWithAlphaComponent:0.80] ?: UIColor.secondaryLabelColor
                                              lines:3];
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:subtitleLabel.font];
    [row addSubview:subtitleLabel];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    toggle.accessibilityIdentifier = preferenceKey;
    toggle.accessibilityLabel = title;
    toggle.on = [self pp_boolForPreferenceKey:preferenceKey defaultValue:defaultValue];
    [toggle addTarget:self action:@selector(pp_switchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [iconSurface.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:18.0],
        [iconSurface.topAnchor constraintEqualToAnchor:row.topAnchor constant:18.0],
        [iconSurface.widthAnchor constraintEqualToConstant:36.0],
        [iconSurface.heightAnchor constraintEqualToConstant:36.0],
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
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-14.0],
    ]];

    if (separator) {
        UIView *line = [[UIView alloc] init];
        line.translatesAutoresizingMaskIntoConstraints = NO;
        line.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08] ?: UIColor.separatorColor;
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

#pragma mark - Actions

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

    [PPToast toast:kLang(@"NotificationSettings_SavedToast")
             style:PPToastStyleSuccess
            haptic:NO
          duration:1.3
          position:PPToastPositionBottom
            inView:self.view];
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
    [PPFunc pp_playTapEffect];
    if (self.authorizationStatus == UNAuthorizationStatusNotDetermined) {
        UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
                                                                            completionHandler:^(BOOL granted, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                    [PPToast toast:kLang(@"NotificationSettings_PermissionEnabledToast") style:PPToastStyleSuccess haptic:YES duration:1.6];
                } else if (error) {
                    [PPToast toast:kLang(@"NotificationSettings_PermissionErrorToast") style:PPToastStyleError haptic:YES duration:1.8];
                }
                [self pp_refreshSystemPermissionState];
            });
        }];
        return;
    }

    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (!settingsURL) return;
    [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
}

#pragma mark - Permission State

- (void)pp_refreshSystemPermissionState {
    self.statusTitleLabel.text = kLang(@"NotificationSettings_CheckingStatus");
    self.statusBodyLabel.text = kLang(@"NotificationSettings_CheckingStatusSubtitle");

    if (@available(iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.authorizationStatus = settings.authorizationStatus;
                [self pp_updateStatusCardForCurrentAuthorization];
            });
        }];
        return;
    }

    UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    self.authorizationStatus = settings.types == UIUserNotificationTypeNone ? UNAuthorizationStatusDenied : UNAuthorizationStatusAuthorized;
    [self pp_updateStatusCardForCurrentAuthorization];
}

- (void)pp_updateStatusCardForCurrentAuthorization {
    NSString *title = kLang(@"NotificationSettings_StatusNotDeterminedTitle");
    NSString *body = kLang(@"NotificationSettings_StatusNotDeterminedBody");
    NSString *button = kLang(@"NotificationSettings_AllowNotifications");
    NSString *symbol = @"bell.badge.fill";
    UIColor *accent = UIColor.systemOrangeColor;

    switch (self.authorizationStatus) {
        case UNAuthorizationStatusAuthorized:
            title = kLang(@"NotificationSettings_StatusEnabledTitle");
            body = kLang(@"NotificationSettings_StatusEnabledBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"checkmark.seal.fill";
            accent = UIColor.systemGreenColor;
            break;
        case UNAuthorizationStatusDenied:
            title = kLang(@"NotificationSettings_StatusDeniedTitle");
            body = kLang(@"NotificationSettings_StatusDeniedBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"bell.slash.fill";
            accent = UIColor.systemRedColor;
            break;
        case UNAuthorizationStatusProvisional:
            title = kLang(@"NotificationSettings_StatusQuietTitle");
            body = kLang(@"NotificationSettings_StatusQuietBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"bell.badge.fill";
            accent = UIColor.systemOrangeColor;
            break;
        case UNAuthorizationStatusEphemeral:
            title = kLang(@"NotificationSettings_StatusQuietTitle");
            body = kLang(@"NotificationSettings_StatusQuietBody");
            button = kLang(@"NotificationSettings_OpenIOSSettings");
            symbol = @"bell.badge.fill";
            accent = UIColor.systemOrangeColor;
            break;
        case UNAuthorizationStatusNotDetermined:
        default:
            break;
    }

    self.statusTitleLabel.text = title;
    self.statusBodyLabel.text = body;
    [self.statusActionButton setTitle:button forState:UIControlStateNormal];
    [self.statusActionButton setTitleColor:accent forState:UIControlStateNormal];
    self.statusActionButton.backgroundColor = [accent colorWithAlphaComponent:0.10];
    self.statusIconView.image = [UIImage systemImageNamed:symbol
                                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold]];
    self.statusIconView.tintColor = accent;

    UIView *iconSurface = self.statusIconView.superview;
    iconSurface.backgroundColor = [accent colorWithAlphaComponent:0.10];
    iconSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    iconSurface.layer.borderColor = [accent colorWithAlphaComponent:0.16].CGColor;

    self.statusCard.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title ?: @"", body ?: @""];
}

#pragma mark - Preferences

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
    self.soundSwitch.superview.alpha = masterEnabled ? 1.0 : 0.48;

    [self.categorySwitches enumerateKeysAndObjectsUsingBlock:^(NSString *key, UISwitch *toggle, BOOL *stop) {
        toggle.enabled = masterEnabled;
        [toggle setOn:[self pp_boolForPreferenceKey:key defaultValue:YES] animated:animated];
    }];
    for (UIView *row in self.categoryRows) {
        row.alpha = masterEnabled ? 1.0 : 0.48;
    }
}

#pragma mark - Styling

- (UIView *)pp_surfaceCardWithCornerRadius:(CGFloat)radius {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = radius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    card.layer.borderColor = [self pp_borderColor].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.05 : 0.07;
    card.layer.shadowRadius = 22.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    return card;
}

- (UIColor *)pp_borderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.055];
    }];
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

#pragma mark - Animation

- (void)pp_prepareEntranceAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    for (UIView *view in self.contentStack.arrangedSubviews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    }
}

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in self.contentStack.arrangedSubviews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [self.contentStack.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.42
                              delay:0.035 * idx
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
