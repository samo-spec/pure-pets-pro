//
//  NotificationDetailViewController.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// NotificationDetailViewController.m
#import "NotificationDetailViewController.h"
#import "NotificationManager+Targets.h"
#import "NotificationManager.h"
#import "Styling.h"
#import "Language.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryManager.h"
#import "PPFirebaseCompat.h"

static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";
static NSString *PPNotificationDetailTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSDictionary *PPNotificationDetailSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPNotificationDetailLocalizedString(id value)
{
    NSString *scalar = PPNotificationDetailTrimmedString(value);
    if (scalar.length) return scalar;

    NSDictionary *dictionary = PPNotificationDetailSafeDictionary(value);
    if (dictionary.count == 0) return @"";

    NSArray<NSString *> *primaryKeys = Language.isRTL
        ? @[@"ar", @"arabic", @"titleAr", @"nameAr", @"valueAr", @"textAr"]
        : @[@"en", @"english", @"titleEn", @"nameEn", @"valueEn", @"textEn"];
    NSArray<NSString *> *fallbackKeys = Language.isRTL
        ? @[@"en", @"english", @"titleEn", @"nameEn", @"valueEn", @"textEn"]
        : @[@"ar", @"arabic", @"titleAr", @"nameAr", @"valueAr", @"textAr"];

    for (NSString *key in primaryKeys) {
        NSString *localized = PPNotificationDetailTrimmedString(dictionary[key]);
        if (localized.length) return localized;
    }
    for (NSString *key in fallbackKeys) {
        NSString *localized = PPNotificationDetailTrimmedString(dictionary[key]);
        if (localized.length) return localized;
    }
    return @"";
}

static NSString *PPNotificationDetailFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPNotificationDetailLocalizedString(source[key]);
        if (value.length) return value;
    }
    return @"";
}

static NSString *PPNotificationDetailNestedStringForKeys(NSDictionary *source, NSArray<NSString *> *containerKeys, NSArray<NSString *> *valueKeys)
{
    for (NSString *containerKey in containerKeys) {
        NSDictionary *nested = PPNotificationDetailSafeDictionary(source[containerKey]);
        NSString *value = PPNotificationDetailFirstStringForKeys(nested, valueKeys);
        if (value.length) return value;
    }
    return @"";
}

static NSString *PPNotificationDetailNormalizedStatus(NSString *value)
{
    NSString *clean = [PPNotificationDetailTrimmedString(value) lowercaseString];
    clean = [clean stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    return clean;
}

@interface NotificationDetailViewController ()
@property (nonatomic, strong) NotificationModel *model;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *requestSummaryCardView;
@property (nonatomic, strong) UILabel *summaryOrderValueLabel;
@property (nonatomic, strong) UILabel *summaryPickupValueLabel;
@property (nonatomic, strong) UILabel *summaryDestinationTitleLabel;
@property (nonatomic, strong) UILabel *summaryDestinationValueLabel;
@property (nonatomic, strong) UILabel *summaryStatusLabel;
@property (nonatomic, strong) UILabel *summaryPrivacyLabel;
@property (nonatomic, strong, nullable) PPDeliveryOrderModel *summaryOrder;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> summaryOrderListener;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *topBackgroundGlowView;
@property (nonatomic, strong) UIView *bottomBackgroundGlowView;
@property (nonatomic, strong) UIView *ctaContainerView;
@property (nonatomic, strong) UIButton *ctaButton;
@property (nonatomic, copy, nullable) NSDictionary *routePayload;
@property (nonatomic, assign) BOOL initiallyUnread;
@property (nonatomic, assign) BOOL didPlayEntrance;
@end

@implementation NotificationDetailViewController

- (instancetype)initWithModel:(NotificationModel *)model userID:(NSString *)uid {
    if (self = [super init]) {
        _model = model;
        _uid = [uid copy] ?: @"";
        _initiallyUnread = !model.isRead;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_navBarWithOtherButton:nil title:kLang(@"Notification")];
    self.routePayload = [NotificationManager routingPayloadForNotificationModel:self.model];

    [self pp_setupBackgroundGlows];
    [self pp_buildInterface];

    if (self.initiallyUnread) {
        self.model.isRead = YES;
        [[NotificationManager shared] markRead:self.model forUser:self.uid completion:nil];
    }
    [self pp_applyModel];
    [self pp_startOrderSummaryListenerIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_prepareEntranceStateIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_playEntranceIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_updateBackgroundGlowStyle];
        }
    }
}

- (void)dealloc {
    [self.summaryOrderListener remove];
    self.summaryOrderListener = nil;
}

- (UIView *)pp_backgroundGlowView {
    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.userInteractionEnabled = NO;
    glow.layer.cornerRadius = 122.0;
    glow.layer.cornerCurve = kCACornerCurveContinuous;
    glow.layer.shadowOffset = CGSizeZero;
    return glow;
}

- (void)pp_setupBackgroundGlows {
    self.topBackgroundGlowView = [self pp_backgroundGlowView];
    self.bottomBackgroundGlowView = [self pp_backgroundGlowView];
    [self.view addSubview:self.topBackgroundGlowView];
    [self.view addSubview:self.bottomBackgroundGlowView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topBackgroundGlowView.widthAnchor constraintEqualToConstant:244.0],
        [self.topBackgroundGlowView.heightAnchor constraintEqualToConstant:244.0],
        [self.topBackgroundGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-112.0],
        [self.topBackgroundGlowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-78.0],

        [self.bottomBackgroundGlowView.widthAnchor constraintEqualToConstant:278.0],
        [self.bottomBackgroundGlowView.heightAnchor constraintEqualToConstant:278.0],
        [self.bottomBackgroundGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:124.0],
        [self.bottomBackgroundGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:88.0],
    ]];

    [self pp_updateBackgroundGlowStyle];
}

- (void)pp_updateBackgroundGlowStyle {
    UIColor *accent = AppPrimaryClr;
    UIColor *support = SeconderyTextClr;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    self.topBackgroundGlowView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.052 : 0.078];
    self.topBackgroundGlowView.layer.shadowColor = accent.CGColor;
    self.topBackgroundGlowView.layer.shadowOpacity = isDark ? 0.30 : 0.16;
    self.topBackgroundGlowView.layer.shadowRadius = isDark ? 58.0 : 48.0;

    self.bottomBackgroundGlowView.backgroundColor = [support colorWithAlphaComponent:isDark ? 0.045 : 0.060];
    self.bottomBackgroundGlowView.layer.shadowColor = support.CGColor;
    self.bottomBackgroundGlowView.layer.shadowOpacity = isDark ? 0.22 : 0.12;
    self.bottomBackgroundGlowView.layer.shadowRadius = isDark ? 56.0 : 46.0;

}

- (void)pp_buildInterface {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:contentView];

    self.heroSurfaceView = [[PPHero alloc] init];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.heroSurfaceView];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.layer.cornerRadius = 28.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroSurfaceView addSubview:iconShell];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bell.badge.fill"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [Styling fontBold:11];
    self.statusLabel.textColor = AppPrimaryClr;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    UIView *statusPill = [[UIView alloc] init];
    statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    statusPill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    statusPill.layer.cornerRadius = 15.0;
    statusPill.layer.cornerCurve = kCACornerCurveContinuous;
    [statusPill addSubview:self.statusLabel];
    [self.heroSurfaceView addSubview:statusPill];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [Styling fontBold:27];
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [Styling fontMedium:12];
    self.timeLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.78];
    self.timeLabel.numberOfLines = 1;
    self.timeLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.bodyLabel = [[UILabel alloc] init];
    self.bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bodyLabel.font = [Styling fontMedium:16];
    self.bodyLabel.textColor = [PrimaryTextClr colorWithAlphaComponent:0.92];
    self.bodyLabel.numberOfLines = 0;
    self.bodyLabel.textAlignment = [Language alignmentForCurrentLanguage];

    UIStackView *copyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.timeLabel,
        self.bodyLabel
    ]];
    copyStack.translatesAutoresizingMaskIntoConstraints = NO;
    copyStack.axis = UILayoutConstraintAxisVertical;
    copyStack.alignment = UIStackViewAlignmentFill;
    copyStack.spacing = 14.0;
    copyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.heroSurfaceView addSubview:copyStack];

    self.requestSummaryCardView = [self pp_buildRequestSummaryCardIfNeeded];
    if (self.requestSummaryCardView) {
        [contentView addSubview:self.requestSummaryCardView];
    }

    self.ctaContainerView = [self pp_buildRouteCTAIfNeeded];
    if (self.ctaContainerView) {
        [self.view addSubview:self.ctaContainerView];
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18.0],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],

        [iconShell.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:24.0],
        [iconShell.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-24.0],
        [iconShell.widthAnchor constraintEqualToConstant:56.0],
        [iconShell.heightAnchor constraintEqualToConstant:56.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [statusPill.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:58.0],
        [statusPill.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [statusPill.heightAnchor constraintEqualToConstant:30.0],
        [statusPill.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:statusPill.leadingAnchor constant:14.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:statusPill.trailingAnchor constant:-14.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:statusPill.centerYAnchor],

        [copyStack.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:24.0],
        [copyStack.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:24.0],
        [copyStack.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-24.0],
        [copyStack.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-26.0],
    ]];

    if (self.ctaContainerView) {
        [constraints addObjectsFromArray:@[
            [self.scrollView.bottomAnchor constraintEqualToAnchor:self.ctaContainerView.topAnchor],
            [self.ctaContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.ctaContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.ctaContainerView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        ]];
        self.scrollView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 18.0, 0.0);
        self.scrollView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, 122.0, 0.0);
    } else {
        [constraints addObject:[self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]];
    }

    if (self.requestSummaryCardView) {
        [constraints addObjectsFromArray:@[
            [self.requestSummaryCardView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:16.0],
            [self.requestSummaryCardView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
            [self.requestSummaryCardView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
            [self.requestSummaryCardView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0],
        ]];
    } else {
        [constraints addObject:[self.heroSurfaceView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
    [self pp_prepareEntranceStateIfNeeded];
}

- (UIView *)pp_buildRouteCTAIfNeeded
{
    if (![NotificationManager payloadHasDirectTarget:self.routePayload]) {
        return nil;
    }

    UIColor *accentColor = AppPrimaryClr;
    UIColor *primaryTextColor = PrimaryTextClr;
    UIColor *secondaryTextColor = SeconderyTextClr;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *dockShadowView = [[UIView alloc] init];
    dockShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    dockShadowView.userInteractionEnabled = NO;
    dockShadowView.backgroundColor = UIColor.clearColor;
    dockShadowView.layer.shadowColor = UIColor.blackColor.CGColor;
    dockShadowView.layer.shadowOpacity = isDark ? 0.34 : 0.13;
    dockShadowView.layer.shadowRadius = 28.0;
    dockShadowView.layer.shadowOffset = CGSizeMake(0.0, -10.0);
    [container addSubview:dockShadowView];

    UIView *dockSurfaceView = [[UIView alloc] init];
    dockSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    dockSurfaceView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.075 alpha:0.88]
            : [UIColor colorWithWhite:1.0 alpha:0.84];
    }];
    dockSurfaceView.layer.cornerRadius = 30.0;
    dockSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    dockSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    dockSurfaceView.layer.borderColor = [secondaryTextColor colorWithAlphaComponent:isDark ? 0.16 : 0.10].CGColor;
    dockSurfaceView.clipsToBounds = YES;
    [dockShadowView addSubview:dockSurfaceView];

    if (@available(iOS 13.0, *)) {
        UIBlurEffectStyle blurStyle = isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight;
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        [dockSurfaceView insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:dockSurfaceView.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:dockSurfaceView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:dockSurfaceView.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:dockSurfaceView.bottomAnchor],
        ]];
    }

    UIView *surfaceHighlightView = [[UIView alloc] init];
    surfaceHighlightView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceHighlightView.userInteractionEnabled = NO;
    surfaceHighlightView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.07 : 0.54];
    surfaceHighlightView.layer.cornerRadius = 1.0;
    surfaceHighlightView.layer.cornerCurve = kCACornerCurveContinuous;
    [dockSurfaceView addSubview:surfaceHighlightView];

    UIView *actionHaloView = [[UIView alloc] init];
    actionHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    actionHaloView.userInteractionEnabled = NO;
    actionHaloView.backgroundColor = [accentColor colorWithAlphaComponent:isDark ? 0.20 : 0.13];
    actionHaloView.layer.cornerRadius = 24.0;
    actionHaloView.layer.cornerCurve = kCACornerCurveContinuous;
    actionHaloView.layer.shadowColor = accentColor.CGColor;
    actionHaloView.layer.shadowOpacity = isDark ? 0.24 : 0.15;
    actionHaloView.layer.shadowRadius = 20.0;
    actionHaloView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [dockSurfaceView addSubview:actionHaloView];

    self.ctaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.ctaButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.ctaButton.backgroundColor = accentColor;
    self.ctaButton.layer.cornerRadius = 24.0;
    self.ctaButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.ctaButton.layer.shadowColor = accentColor.CGColor;
    self.ctaButton.layer.shadowOpacity = isDark ? 0.30 : 0.19;
    self.ctaButton.layer.shadowRadius = 16.0;
    self.ctaButton.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    self.ctaButton.titleLabel.font = [Styling fontBold:16];
    self.ctaButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.ctaButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.ctaButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 22.0, 0.0, 22.0);
    self.ctaButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.ctaButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.ctaButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.ctaButton setTitleColor:[UIColor.whiteColor colorWithAlphaComponent:0.68] forState:UIControlStateDisabled];
    [self.ctaButton setTitle:[NotificationManager callToActionTitleForPayload:self.routePayload] forState:UIControlStateNormal];

    UIImageSymbolConfiguration *iconConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                    weight:UIImageSymbolWeightBold];
    UIImage *arrowIcon = [[UIImage systemImageNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"] imageWithConfiguration:iconConfiguration];
    [self.ctaButton setImage:arrowIcon forState:UIControlStateNormal];
    self.ctaButton.tintColor = UIColor.whiteColor;
    self.ctaButton.imageEdgeInsets = Language.isRTL
        ? UIEdgeInsetsMake(0.0, 9.0, 0.0, -9.0)
        : UIEdgeInsetsMake(0.0, -9.0, 0.0, 9.0);

    UIView *buttonInnerHighlightView = [[UIView alloc] init];
    buttonInnerHighlightView.translatesAutoresizingMaskIntoConstraints = NO;
    buttonInnerHighlightView.userInteractionEnabled = NO;
    buttonInnerHighlightView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.09 : 0.18];
    buttonInnerHighlightView.layer.cornerRadius = 1.0;
    buttonInnerHighlightView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.ctaButton addSubview:buttonInnerHighlightView];

    UILabel *confidenceLabel = [[UILabel alloc] init];
    confidenceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    confidenceLabel.font = [Styling fontMedium:11];
    confidenceLabel.textColor = [secondaryTextColor colorWithAlphaComponent:isDark ? 0.74 : 0.68];
    confidenceLabel.textAlignment = NSTextAlignmentCenter;
    confidenceLabel.numberOfLines = 1;
    confidenceLabel.adjustsFontSizeToFitWidth = YES;
    confidenceLabel.minimumScaleFactor = 0.82;
    confidenceLabel.text = kLang(@"Notification_RequestSummarySubtitle");
    confidenceLabel.accessibilityElementsHidden = YES;
    [dockSurfaceView addSubview:confidenceLabel];

    [self.ctaButton addTarget:self action:@selector(pp_routeCTAButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.ctaButton addTarget:self action:@selector(pp_routeCTAButtonTouchCancel:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [self.ctaButton addTarget:self action:@selector(pp_routeCTAButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.ctaButton];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintEqualToConstant:122.0],

        [dockShadowView.topAnchor constraintEqualToAnchor:container.topAnchor constant:10.0],
        [dockShadowView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12.0],
        [dockShadowView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12.0],
        [dockShadowView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8.0],

        [dockSurfaceView.topAnchor constraintEqualToAnchor:dockShadowView.topAnchor],
        [dockSurfaceView.leadingAnchor constraintEqualToAnchor:dockShadowView.leadingAnchor],
        [dockSurfaceView.trailingAnchor constraintEqualToAnchor:dockShadowView.trailingAnchor],
        [dockSurfaceView.bottomAnchor constraintEqualToAnchor:dockShadowView.bottomAnchor],

        [surfaceHighlightView.topAnchor constraintEqualToAnchor:dockSurfaceView.topAnchor constant:8.0],
        [surfaceHighlightView.leadingAnchor constraintEqualToAnchor:dockSurfaceView.leadingAnchor constant:28.0],
        [surfaceHighlightView.trailingAnchor constraintEqualToAnchor:dockSurfaceView.trailingAnchor constant:-28.0],
        [surfaceHighlightView.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [actionHaloView.topAnchor constraintEqualToAnchor:dockSurfaceView.topAnchor constant:18.0],
        [actionHaloView.leadingAnchor constraintEqualToAnchor:dockSurfaceView.leadingAnchor constant:18.0],
        [actionHaloView.trailingAnchor constraintEqualToAnchor:dockSurfaceView.trailingAnchor constant:-18.0],
        [actionHaloView.heightAnchor constraintEqualToConstant:58.0],

        [self.ctaButton.topAnchor constraintEqualToAnchor:dockSurfaceView.topAnchor constant:16.0],
        [self.ctaButton.leadingAnchor constraintEqualToAnchor:dockSurfaceView.leadingAnchor constant:16.0],
        [self.ctaButton.trailingAnchor constraintEqualToAnchor:dockSurfaceView.trailingAnchor constant:-16.0],
        [self.ctaButton.heightAnchor constraintEqualToConstant:58.0],

        [buttonInnerHighlightView.topAnchor constraintEqualToAnchor:self.ctaButton.topAnchor constant:8.0],
        [buttonInnerHighlightView.leadingAnchor constraintEqualToAnchor:self.ctaButton.leadingAnchor constant:26.0],
        [buttonInnerHighlightView.trailingAnchor constraintEqualToAnchor:self.ctaButton.trailingAnchor constant:-26.0],
        [buttonInnerHighlightView.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [confidenceLabel.topAnchor constraintEqualToAnchor:self.ctaButton.bottomAnchor constant:10.0],
        [confidenceLabel.leadingAnchor constraintEqualToAnchor:dockSurfaceView.leadingAnchor constant:24.0],
        [confidenceLabel.trailingAnchor constraintEqualToAnchor:dockSurfaceView.trailingAnchor constant:-24.0],
        [confidenceLabel.bottomAnchor constraintLessThanOrEqualToAnchor:dockSurfaceView.bottomAnchor constant:-12.0],
    ]];

    return container;
}

- (void)pp_routeCTAButtonTouchDown:(UIButton *)button
{
    if (!button.enabled || UIAccessibilityIsReduceMotionEnabled()) return;

    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.982, 0.982);
        button.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.22 : 0.14;
        button.layer.shadowRadius = 10.0;
        button.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    } completion:nil];
}

- (void)pp_routeCTAButtonTouchCancel:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.16
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.30 : 0.19;
        button.layer.shadowRadius = 16.0;
        button.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    } completion:nil];
}

#pragma mark - Request Summary

- (BOOL)pp_isDeliveryRequestNotification {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *type = PPNotificationDetailNormalizedStatus(PPNotificationDetailFirstStringForKeys(meta, @[
        @"notificationType",
        @"type",
        @"key",
        @"eventKey",
        @"route"
    ]));
    if (type.length == 0) {
        type = PPNotificationDetailNormalizedStatus(PPNotificationDetailNestedStringForKeys(meta,
                                                                                           @[@"order", @"orderData", @"payload"],
                                                                                           @[@"notificationType", @"type", @"key", @"eventKey", @"route"]));
    }

    if ([type hasPrefix:@"drivers_delivery_"] ||
        [type isEqualToString:@"delivery_requested"] ||
        [type isEqualToString:@"delivery_request_closed"]) {
        return YES;
    }

    NSString *title = PPNotificationDetailTrimmedString(self.model.title);
    return [title caseInsensitiveCompare:@"New Delivery Request"] == NSOrderedSame ||
           [title caseInsensitiveCompare:@"Delivery Request Closed"] == NSOrderedSame;
}

- (NSString *)pp_fulfillmentIdentifier {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *fulfillmentID = PPNotificationDetailFirstStringForKeys(meta, @[
        @"fulfillmentId",
        @"fulfillmentID"
    ]);
    if (fulfillmentID.length) return fulfillmentID;

    return PPNotificationDetailNestedStringForKeys(meta,
                                                   @[@"order", @"orderData", @"payload"],
                                                   @[@"fulfillmentId", @"fulfillmentID"]);
}

- (BOOL)pp_isFulfillmentOrderNotification {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *type = PPNotificationDetailNormalizedStatus(PPNotificationDetailFirstStringForKeys(meta, @[
        @"notificationType",
        @"type",
        @"key",
        @"eventKey",
        @"route"
    ]));
    if (type.length == 0) {
        type = PPNotificationDetailNormalizedStatus(PPNotificationDetailNestedStringForKeys(meta,
                                                                                           @[@"order", @"orderData", @"payload"],
                                                                                           @[@"notificationType", @"type", @"key", @"eventKey", @"route"]));
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [type isEqualToString:@"provider_order_cancelled"] ||
        [type isEqualToString:@"provider.order.cancelled"]) {
        return YES;
    }

    NSString *status = PPNotificationDetailNormalizedStatus(PPNotificationDetailFirstStringForKeys(meta, @[@"status"]));
    if ([self pp_fulfillmentIdentifier].length > 0 && [status isEqualToString:@"new_request"]) {
        return YES;
    }

    NSString *title = PPNotificationDetailTrimmedString(self.model.title);
    return [title rangeOfString:@"New Order " options:NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound;
}

- (BOOL)pp_shouldShowRequestSummary {
    return [self pp_isDeliveryRequestNotification] || [self pp_isFulfillmentOrderNotification];
}

- (NSString *)pp_orderIdentifier {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSString *orderID = PPNotificationDetailFirstStringForKeys(meta, @[
        @"orderId",
        @"orderID",
        @"parentOrderId",
        @"parentOrderID"
    ]);
    if (orderID.length) return orderID;

    return PPNotificationDetailNestedStringForKeys(meta,
                                                   @[@"order", @"orderData", @"payload"],
                                                   @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
}

- (NSDictionary *)pp_orderSummarySeedData {
    NSDictionary *meta = PPNotificationDetailSafeDictionary(self.model.meta);
    NSMutableDictionary *seed = [NSMutableDictionary dictionary];

    for (NSString *containerKey in @[@"order", @"orderData", @"payload"]) {
        NSDictionary *nested = PPNotificationDetailSafeDictionary(meta[containerKey]);
        if (nested.count) [seed addEntriesFromDictionary:nested];
    }
    [seed addEntriesFromDictionary:meta];

    NSString *orderID = [self pp_orderIdentifier];
    if (orderID.length) seed[@"orderId"] = orderID;

    NSString *orderNumber = PPNotificationDetailFirstStringForKeys(seed, @[@"orderNumber", @"parentOrderNumber", @"orderReference"]);
    if (orderNumber.length) seed[@"orderNumber"] = orderNumber;

    NSString *deliveryStatus = PPNotificationDetailFirstStringForKeys(seed, @[@"deliveryStatus", @"status"]);
    if (deliveryStatus.length == 0) seed[@"deliveryStatus"] = PPDeliveryStatusRequested;

    return [seed copy];
}

- (UIFont *)pp_scaledFontWithTextStyle:(UIFontTextStyle)textStyle baseFont:(UIFont *)baseFont {
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:textStyle];
    return [metrics scaledFontForFont:baseFont maximumPointSize:34.0];
}

- (UILabel *)pp_summaryLabelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = [Language alignmentForCurrentLanguage];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UIView *)pp_summaryRowWithIcon:(NSString *)iconName
                       iconColor:(UIColor *)iconColor
                            title:(NSString *)title
                            value:(NSString *)value
                       titleLabel:(UILabel * __strong *)titleLabel
                       valueLabel:(UILabel * __strong *)valueLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [iconColor colorWithAlphaComponent:0.10];
    iconShell.layer.cornerRadius = 18.0;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    [row addSubview:iconShell];

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                                  weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:iconName] imageWithConfiguration:configuration]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = iconColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.isAccessibilityElement = NO;
    [iconShell addSubview:iconView];

    UILabel *rowTitleLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleCaption1
                                                                                  baseFont:[Styling fontBold:11]]
                                                     color:[SeconderyTextClr colorWithAlphaComponent:0.82]
                                                     lines:1];
    rowTitleLabel.text = title;

    UILabel *rowValueLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleBody
                                                                                  baseFont:[Styling fontMedium:15]]
                                                     color:PrimaryTextClr
                                                     lines:0];
    rowValueLabel.text = value;

    UIStackView *copyStack = [[UIStackView alloc] initWithArrangedSubviews:@[rowTitleLabel, rowValueLabel]];
    copyStack.translatesAutoresizingMaskIntoConstraints = NO;
    copyStack.axis = UILayoutConstraintAxisVertical;
    copyStack.alignment = UIStackViewAlignmentFill;
    copyStack.spacing = 3.0;
    copyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [row addSubview:copyStack];

    [NSLayoutConstraint activateConstraints:@[
        [iconShell.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [iconShell.topAnchor constraintEqualToAnchor:row.topAnchor constant:2.0],
        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:17.0],
        [iconView.heightAnchor constraintEqualToConstant:17.0],

        [copyStack.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:12.0],
        [copyStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [copyStack.topAnchor constraintEqualToAnchor:row.topAnchor],
        [copyStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [copyStack.heightAnchor constraintGreaterThanOrEqualToConstant:42.0],
    ]];

    if (titleLabel) *titleLabel = rowTitleLabel;
    if (valueLabel) *valueLabel = rowValueLabel;
    return row;
}

- (UIView *)pp_buildRequestSummaryCardIfNeeded {
    if (![self pp_shouldShowRequestSummary]) return nil;

    PPHero *card = [[PPHero alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    card.shouldGroupAccessibilityChildren = YES;

    UIView *headerIconShell = [[UIView alloc] init];
    headerIconShell.translatesAutoresizingMaskIntoConstraints = NO;
    headerIconShell.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    headerIconShell.layer.cornerRadius = 22.0;
    headerIconShell.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageSymbolConfiguration *headerIconConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                                          weight:UIImageSymbolWeightSemibold];
    UIImageView *headerIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"shippingbox.fill"] imageWithConfiguration:headerIconConfiguration]];
    headerIcon.translatesAutoresizingMaskIntoConstraints = NO;
    headerIcon.tintColor = AppPrimaryClr;
    headerIcon.contentMode = UIViewContentModeScaleAspectFit;
    headerIcon.isAccessibilityElement = NO;
    [headerIconShell addSubview:headerIcon];

    UILabel *headingLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleHeadline
                                                                                 baseFont:[Styling fontBold:19]]
                                                    color:PrimaryTextClr
                                                    lines:0];
    headingLabel.text = kLang(@"Notification_RequestSummaryTitle");

    UILabel *supportLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleSubheadline
                                                                                 baseFont:[Styling fontRegular:13]]
                                                    color:[SeconderyTextClr colorWithAlphaComponent:0.84]
                                                    lines:0];
    supportLabel.text = kLang(@"Notification_RequestSummarySubtitle");

    UIStackView *headingStack = [[UIStackView alloc] initWithArrangedSubviews:@[headingLabel, supportLabel]];
    headingStack.axis = UILayoutConstraintAxisVertical;
    headingStack.alignment = UIStackViewAlignmentFill;
    headingStack.spacing = 4.0;
    headingStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.summaryStatusLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleCaption1
                                                                                   baseFont:[Styling fontBold:11]]
                                                      color:AppPrimaryClr
                                                      lines:2];
    self.summaryStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.summaryStatusLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    self.summaryStatusLabel.layer.cornerRadius = 14.0;
    self.summaryStatusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.summaryStatusLabel.clipsToBounds = YES;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerIconShell,
        headingStack,
        self.summaryStatusLabel
    ]];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 12.0;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:header];

    [headerIconShell.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [headerIconShell.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [self.summaryStatusLabel.widthAnchor constraintEqualToConstant:112.0].active = YES;
    [self.summaryStatusLabel.heightAnchor constraintGreaterThanOrEqualToConstant:32.0].active = YES;
    [self.summaryStatusLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    [card addSubview:divider];

    UILabel *orderValueLabel = nil;
    UIView *orderRow = [self pp_summaryRowWithIcon:@"number"
                                        iconColor:AppPrimaryClr
                                             title:kLang(@"Notification_RequestSummaryOrder")
                                             value:kLang(@"Notification_RequestSummaryLoading")
                                        titleLabel:NULL
                                        valueLabel:&orderValueLabel];
    self.summaryOrderValueLabel = orderValueLabel;

    UILabel *pickupValueLabel = nil;
    UIView *pickupRow = [self pp_summaryRowWithIcon:@"shippingbox.fill"
                                         iconColor:[UIColor ppQuickActionCommunity]
                                              title:kLang(@"Deliv_PackagePickupLocation")
                                              value:kLang(@"Notification_RequestSummaryLoading")
                                         titleLabel:NULL
                                         valueLabel:&pickupValueLabel];
    self.summaryPickupValueLabel = pickupValueLabel;

    UILabel *destinationTitleLabel = nil;
    UILabel *destinationValueLabel = nil;
    UIView *destinationRow = [self pp_summaryRowWithIcon:@"location.fill"
                                              iconColor:[UIColor ppWarning]
                                                   title:kLang(@"Deliv_DeliveryArea")
                                                   value:kLang(@"Notification_RequestSummaryLoading")
                                              titleLabel:&destinationTitleLabel
                                              valueLabel:&destinationValueLabel];
    self.summaryDestinationTitleLabel = destinationTitleLabel;
    self.summaryDestinationValueLabel = destinationValueLabel;

    UIStackView *detailsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        orderRow,
        pickupRow,
        destinationRow
    ]];
    detailsStack.translatesAutoresizingMaskIntoConstraints = NO;
    detailsStack.axis = UILayoutConstraintAxisVertical;
    detailsStack.alignment = UIStackViewAlignmentFill;
    detailsStack.spacing = 14.0;
    detailsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:detailsStack];

    UIView *privacyDivider = [[UIView alloc] init];
    privacyDivider.translatesAutoresizingMaskIntoConstraints = NO;
    privacyDivider.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    [card addSubview:privacyDivider];

    UIImageView *privacyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    privacyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    privacyIcon.tintColor = [SeconderyTextClr colorWithAlphaComponent:0.74];
    privacyIcon.contentMode = UIViewContentModeScaleAspectFit;
    privacyIcon.isAccessibilityElement = NO;

    self.summaryPrivacyLabel = [self pp_summaryLabelWithFont:[self pp_scaledFontWithTextStyle:UIFontTextStyleFootnote
                                                                                    baseFont:[Styling fontMedium:12]]
                                                       color:[SeconderyTextClr colorWithAlphaComponent:0.82]
                                                       lines:0];
    self.summaryPrivacyLabel.text = kLang(@"Deliv_ExactLocationAfterAccepting");

    UIStackView *privacyRow = [[UIStackView alloc] initWithArrangedSubviews:@[privacyIcon, self.summaryPrivacyLabel]];
    privacyRow.translatesAutoresizingMaskIntoConstraints = NO;
    privacyRow.axis = UILayoutConstraintAxisHorizontal;
    privacyRow.alignment = UIStackViewAlignmentTop;
    privacyRow.spacing = 9.0;
    privacyRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [privacyIcon.widthAnchor constraintEqualToConstant:17.0].active = YES;
    [privacyIcon.heightAnchor constraintEqualToConstant:17.0].active = YES;
    [card addSubview:privacyRow];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:40.0],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],

        [headerIcon.centerXAnchor constraintEqualToAnchor:headerIconShell.centerXAnchor],
        [headerIcon.centerYAnchor constraintEqualToAnchor:headerIconShell.centerYAnchor],
        [headerIcon.widthAnchor constraintEqualToConstant:20.0],
        [headerIcon.heightAnchor constraintEqualToConstant:20.0],

        [divider.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18.0],
        [divider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [divider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
        [divider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [detailsStack.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:18.0],
        [detailsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [detailsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],

        [privacyDivider.topAnchor constraintEqualToAnchor:detailsStack.bottomAnchor constant:18.0],
        [privacyDivider.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [privacyDivider.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
        [privacyDivider.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [privacyRow.topAnchor constraintEqualToAnchor:privacyDivider.bottomAnchor constant:14.0],
        [privacyRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22.0],
        [privacyRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22.0],
        [privacyRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20.0],
    ]];

    NSDictionary *seedData = [self pp_orderSummarySeedData];
    self.summaryOrder = [PPDeliveryOrderModel fromDictionary:seedData withID:[self pp_orderIdentifier]];
    [self pp_applySummaryOrder:self.summaryOrder loading:YES unavailable:NO];
    return card;
}

- (void)pp_applySummaryOrder:(PPDeliveryOrderModel *)order loading:(BOOL)loading unavailable:(BOOL)unavailable {
    if (!self.requestSummaryCardView && !self.summaryOrderValueLabel) return;

    NSString *loadingText = kLang(@"Notification_RequestSummaryLoading");
    NSString *unavailableText = kLang(@"Notification_RequestSummaryUnavailable");
    NSString *orderReference = [order bestOrderNumber];
    if (orderReference.length == 0) orderReference = [self pp_orderIdentifier];
    self.summaryOrderValueLabel.text = orderReference.length ? orderReference : (unavailable ? unavailableText : loadingText);

    BOOL hasPickup = order.pickupAddress.length ||
                     order.branchName.length ||
                     order.branchID.length ||
                     order.marketplaceProviderName.length ||
                     order.marketplaceProviderID.length;
    NSString *pickup = hasPickup ? [order pp_pickupLocationSummary] : @"";

    // If pickup contains an ID (not a name or address), try to get provider name from cache
    if (pickup.length > 0 &&
        order.marketplaceProviderID.length > 0 &&
        ![order.marketplaceProviderID isEqualToString:@"platform"] &&
        ![order.marketplaceProviderID isEqualToString:PPDeliveryOfficialSupportUserID]) {
        NSString *providerName = [[PPDeliveryManager shared] providerDisplayNameForID:order.marketplaceProviderID];
        if ([pickup isEqualToString:order.marketplaceProviderID] &&
            providerName.length > 0 &&
            ![providerName isEqualToString:order.marketplaceProviderID]) {
            pickup = providerName;
        }
    }

    self.summaryPickupValueLabel.text = pickup.length ? pickup : (unavailable ? unavailableText : loadingText);

    NSString *exactLocation = [order pp_exactDeliveryLocationText];
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    BOOL assignedToCurrentUser = currentUID.length > 0 &&
                                 order.deliveryUserId.length > 0 &&
                                 [order.deliveryUserId isEqualToString:currentUID];
    BOOL exactLocationVisible = [order pp_canRevealExactDeliveryLocation] &&
                                assignedToCurrentUser &&
                                exactLocation.length > 0;
    self.summaryDestinationTitleLabel.text = exactLocationVisible
        ? kLang(@"Deliv_ExactCustomerLocation")
        : kLang(@"Deliv_DeliveryArea");

    NSString *destination = exactLocationVisible ? exactLocation : [order pp_deliveryAreaSummary];
    BOOL hasUsefulDestination = exactLocationVisible
        ? destination.length > 0
        : order.deliveryAreaName.length > 0;
    if (!hasUsefulDestination && loading) destination = loadingText;
    if (!destination.length || (!hasUsefulDestination && unavailable)) destination = unavailableText;
    self.summaryDestinationValueLabel.text = destination;

    NSString *status = [order displayStatus];
    if ([self pp_isFulfillmentOrderNotification] &&
        [PPNotificationDetailNormalizedStatus(order.rawStatus) isEqualToString:@"new_request"]) {
        status = kLang(@"Fulfillment_Status_NewRequest");
    }
    self.summaryStatusLabel.text = status.length ? status : kLang(@"Deliv_StatusRequested");
    self.summaryPrivacyLabel.text = exactLocationVisible
        ? kLang(@"Notification_RequestSummaryExactAvailable")
        : kLang(@"Deliv_ExactLocationAfterAccepting");
}

- (void)pp_startOrderSummaryListenerIfNeeded {
    NSString *orderID = [self pp_orderIdentifier];
    NSString *fulfillmentID = [self pp_fulfillmentIdentifier];
    BOOL shouldLoadFulfillment = [self pp_isFulfillmentOrderNotification] && fulfillmentID.length > 0;
    NSString *documentID = shouldLoadFulfillment ? fulfillmentID : orderID;
    if (!self.requestSummaryCardView || documentID.length == 0 || self.summaryOrderListener) return;

    NSString *collectionPath = shouldLoadFulfillment ? @"FulfillmentOrders" : @"Orders";
    FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:collectionPath] documentWithPath:documentID];
    __weak typeof(self) weakSelf = self;
    self.summaryOrderListener = [reference addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !snapshot.exists || !snapshot.data) {
                [strongSelf pp_applySummaryOrder:strongSelf.summaryOrder loading:NO unavailable:YES];
                return;
            }

            NSMutableDictionary *summaryData = [snapshot.data mutableCopy];
            NSString *parentOrderID = PPNotificationDetailFirstStringForKeys(summaryData, @[@"parentOrderId", @"parentOrderID"]);
            NSString *parentOrderNumber = PPNotificationDetailFirstStringForKeys(summaryData, @[@"parentOrderNumber"]);
            if (PPNotificationDetailFirstStringForKeys(summaryData, @[@"orderId", @"orderID"]).length == 0 && parentOrderID.length) {
                summaryData[@"orderId"] = parentOrderID;
            }
            if (PPNotificationDetailFirstStringForKeys(summaryData, @[@"orderNumber", @"displayOrderNumber"]).length == 0 && parentOrderNumber.length) {
                summaryData[@"orderNumber"] = parentOrderNumber;
            }

            NSString *modelOrderID = parentOrderID.length ? parentOrderID : snapshot.documentID;
            strongSelf.summaryOrder = [PPDeliveryOrderModel fromDictionary:summaryData withID:modelOrderID];
            [strongSelf pp_applySummaryOrder:strongSelf.summaryOrder loading:NO unavailable:NO];
        });
    }];
}

- (void)pp_applyModel {
    self.titleLabel.text = [self.model pp_localizedTitleForCurrentLanguage];
    self.bodyLabel.text = [self.model pp_localizedBodyForCurrentLanguage];
    self.statusLabel.text = self.model.isRead ? kLang(@"Read") : kLang(@"Unread");

    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    self.timeLabel.text = [fmt stringFromDate:self.model.createdAt ?: [NSDate date]];
}

- (void)pp_routeCTAButtonTapped
{
    if (!self.ctaButton || self.ctaButton.isEnabled == NO) {
        return;
    }

    NSDictionary *payload = self.routePayload;
    if (![NotificationManager payloadHasDirectTarget:payload]) {
        return;
    }

    NSString *stableTitle = [self.ctaButton titleForState:UIControlStateNormal] ?: [NotificationManager callToActionTitleForPayload:payload];
    UIImage *stableImage = [self.ctaButton imageForState:UIControlStateNormal];

    self.ctaButton.enabled = NO;
    self.ctaButton.alpha = 0.96;
    [self.ctaButton setTitle:kLang(@"Loading") ?: stableTitle forState:UIControlStateNormal];
    [self.ctaButton setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.14
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.24
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.ctaButton.transform = CGAffineTransformIdentity;
            self.ctaButton.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.24 : 0.15;
            self.ctaButton.layer.shadowRadius = 11.0;
            self.ctaButton.layer.shadowOffset = CGSizeMake(0.0, 6.0);
        } completion:nil];
    } else {
        self.ctaButton.transform = CGAffineTransformIdentity;
    }

    [NotificationManager routePayload:payload
             fromNavigationController:self.navigationController
                            presenter:self
                           completion:^(BOOL handled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handled) {
                [self.ctaButton setTitle:kLang(@"Done") ?: stableTitle forState:UIControlStateNormal];
                [self.ctaButton setImage:[UIImage systemImageNamed:@"checkmark"] forState:UIControlStateNormal];
                if (@available(iOS 10.0, *)) {
                    UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
                    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                }
            } else {
                [self.ctaButton setTitle:stableTitle forState:UIControlStateNormal];
                [self.ctaButton setImage:stableImage forState:UIControlStateNormal];
                [PPHUD showError:kLang(@"Notification_RequestSummaryUnavailable") ?: @"Request details unavailable"];
            }

            self.ctaButton.enabled = YES;
            self.ctaButton.alpha = 1.0;
            [self pp_routeCTAButtonTouchCancel:self.ctaButton];

            if (handled) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (!self.ctaButton) return;
                    [self.ctaButton setTitle:stableTitle forState:UIControlStateNormal];
                    [self.ctaButton setImage:stableImage forState:UIControlStateNormal];
                });
            }
        });
    }];
}

- (void)pp_prepareEntranceStateIfNeeded {
    if (self.didPlayEntrance) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.requestSummaryCardView.alpha = 1.0;
        self.requestSummaryCardView.transform = CGAffineTransformIdentity;
        self.ctaContainerView.alpha = 1.0;
        self.ctaContainerView.transform = CGAffineTransformIdentity;
        return;
    }

    self.heroSurfaceView.alpha = 0.0;
    self.heroSurfaceView.transform = CGAffineTransformMakeTranslation(0, 14.0);
    self.requestSummaryCardView.alpha = 0.0;
    self.requestSummaryCardView.transform = CGAffineTransformMakeTranslation(0, 12.0);
    self.ctaContainerView.alpha = 0.0;
    self.ctaContainerView.transform = CGAffineTransformMakeTranslation(0, 16.0);
}

- (void)pp_playEntranceIfNeeded {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
        self.requestSummaryCardView.alpha = 1.0;
        self.requestSummaryCardView.transform = CGAffineTransformIdentity;
        self.ctaContainerView.alpha = 1.0;
        self.ctaContainerView.transform = CGAffineTransformIdentity;
        return;
    }

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.48
                          delay:0.0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.heroSurfaceView.alpha = 1.0;
        self.heroSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (self.requestSummaryCardView) {
        [UIView animateWithDuration:0.50
                              delay:0.09
             usingSpringWithDamping:0.94
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.requestSummaryCardView.alpha = 1.0;
            self.requestSummaryCardView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    if (self.ctaContainerView) {
        [UIView animateWithDuration:0.44
                              delay:0.14
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.ctaContainerView.alpha = 1.0;
            self.ctaContainerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}
@end
