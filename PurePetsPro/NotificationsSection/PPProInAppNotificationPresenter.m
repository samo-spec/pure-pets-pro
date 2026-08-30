//
//  PPProInAppNotificationPresenter.m
//  PurePetsPro
//
//  In-app notification banner for Pro app (orders, deliveries, alerts).
//

#import "PPProInAppNotificationPresenter.h"
#import "PPAlertHelper.h"
#import "Language.h"
#import "SceneDelegate.h"
#import <UserNotifications/UserNotifications.h>
@import AVFoundation;

NSString * const PPProCompanyDeliveryNotificationTappedNotification = @"PPProCompanyDeliveryNotificationTappedNotification";
NSString * const PPProNotificationPayloadTappedNotification = @"PPProNotificationPayloadTappedNotification";

static CGFloat const kPPProNoticeHorizontalInset = 12.0;
static CGFloat const kPPProNoticeTopInset = 8.0;
static CGFloat const kPPProNoticeMinHeight = 92.0;
static CGFloat const kPPProNoticeMaxWidth = 560.0;
static CGFloat const kPPProNoticeIconWellSize = 48.0;
static CGFloat const kPPProNoticeIconSize = 20.0;
static CGFloat const kPPProNoticeChevronWellSize = 32.0;
static CGFloat const kPPProNoticeCornerRadius = 28.0;
static NSTimeInterval const kPPProNoticeVisibleDuration = 5.6;
static NSTimeInterval const kPPProNoticeSoundThrottle = 0.45;
static NSString * const kPPProNoticeSoundResource = @"new-notification";
static NSString * const kPPProNoticeSoundExtension = @"mp3";
static NSString * const kPPProNotifMasterPreferenceKey = @"pp_notif_master_enabled";
static NSString * const kPPProNotifSoundPreferenceKey = @"pp_notif_sound_enabled";
static NSString * const kPPProNotifCategoryGeneralKey = @"pp_notif_cat_general";
static NSString * const kPPProNotifCategoryOrdersKey = @"pp_notif_cat_order";
static NSString * const kPPProNotifCategoryDeliveryKey = @"pp_notif_cat_delivery";
static NSString * const kPPProNotifCategoryReviewKey = @"pp_notif_cat_review";
static NSString * const kPPProNotifCategoryWarningKey = @"pp_notif_cat_warning";

static NSString *PPProNoticeTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *PPProNoticeLocalizedValue(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    if (value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

static BOOL PPProNoticeBoolPreference(NSString *key, BOOL defaultValue)
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (value == nil) {
        return defaultValue;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static SceneDelegate *PPProNoticeActiveSceneDelegate(void)
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        if (scene.activationState == UISceneActivationStateForegroundActive ||
            scene.activationState == UISceneActivationStateForegroundInactive) {
            id delegate = scene.delegate;
            if ([delegate isKindOfClass:SceneDelegate.class]) {
                return (SceneDelegate *)delegate;
            }
        }
    }

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        id delegate = scene.delegate;
        if ([delegate isKindOfClass:SceneDelegate.class]) {
            return (SceneDelegate *)delegate;
        }
    }
    return nil;
}

static NSString *PPProNoticeCategoryPreferenceKeyForPayload(NSDictionary<NSString *, id> *payload)
{
    if (![payload isKindOfClass:NSDictionary.class]) {
        return kPPProNotifCategoryGeneralKey;
    }

    NSString *type = PPProNoticeTrimmedString(payload[@"type"]).lowercaseString;
    NSString *notificationType = PPProNoticeTrimmedString(payload[@"notificationType"]).lowercaseString;
    NSString *route = PPProNoticeTrimmedString(payload[@"route"]).lowercaseString;
    NSString *eventKey = PPProNoticeTrimmedString(payload[@"eventKey"]).lowercaseString;
    NSString *key = PPProNoticeTrimmedString(payload[@"key"]).lowercaseString;
    NSString *effectiveType = type.length > 0 ? type : notificationType;
    if (effectiveType.length == 0) {
        effectiveType = eventKey.length > 0 ? eventKey : key;
    }

    if ([route isEqualToString:@"fleet_partner"] ||
        [effectiveType hasPrefix:@"company_delivery"] ||
        [effectiveType hasPrefix:@"delivery"] ||
        [effectiveType hasPrefix:@"request"] ||
        [effectiveType hasPrefix:@"drivers_delivery_requested"] ||
        [effectiveType hasPrefix:@"customer_delivery_requested"]) {
        return kPPProNotifCategoryDeliveryKey;
    }

    if ([route isEqualToString:@"fulfillment_order"] ||
        [effectiveType hasPrefix:@"order"] ||
        [effectiveType isEqualToString:@"provider_order_cancelled"] ||
        [effectiveType isEqualToString:@"provider.order.cancelled"] ||
        [effectiveType isEqualToString:@"provider_new_fulfillment"] ||
        [effectiveType containsString:@"fulfillment"]) {
        return kPPProNotifCategoryOrdersKey;
    }

    if ([effectiveType containsString:@"review"] ||
        [effectiveType containsString:@"listing"] ||
        [effectiveType containsString:@"ad_"] ||
        [effectiveType containsString:@"pet_ad"]) {
        return kPPProNotifCategoryReviewKey;
    }

    if ([effectiveType containsString:@"warning"] ||
        [effectiveType containsString:@"security"] ||
        [effectiveType containsString:@"suspend"] ||
        [effectiveType containsString:@"blocked"] ||
        [effectiveType containsString:@"account"]) {
        return kPPProNotifCategoryWarningKey;
    }

    return kPPProNotifCategoryGeneralKey;
}

#pragma mark - Passthrough Window

@interface PPProNoticePassthroughWindow : UIWindow
@property (nonatomic, weak) UIView *touchTarget;
@end

@implementation PPProNoticePassthroughWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.touchTarget || self.hidden || self.alpha <= 0.01) {
        return NO;
    }
    CGPoint converted = [self convertPoint:point toView:self.touchTarget];
    return [self.touchTarget pointInside:converted withEvent:event];
}

@end

#pragma mark - Root View Controller

@interface PPProNoticeRootViewController : UIViewController
@end

@implementation PPProNoticeRootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.userInteractionEnabled = YES;
}

- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

@end


#pragma mark - Banner View

@interface PPProNoticeBannerView : UIControl
@property (nonatomic, strong) UIView *ambientGlowView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *contentGroupView;
@property (nonatomic, strong) UIView *iconWellView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *chevronWellView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *topSheenView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) CAGradientLayer *surfaceWashLayer;
@property (nonatomic, strong) CAGradientLayer *accentBloomLayer;
@property (nonatomic, strong) CAGradientLayer *railLightLayer;
@property (nonatomic, strong) CAShapeLayer *progressTrackLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, strong) UIColor *accentColor;
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName accentColor:(UIColor *)accentColor;
- (void)prepareContentEntrance;
- (void)animateContentEntranceWithDelay:(NSTimeInterval)delay;
- (void)setContentEntranceFinalState;
- (void)startLiveEffectsWithDuration:(NSTimeInterval)duration;
- (void)stopLiveEffects;
@end

@implementation PPProNoticeBannerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_setupUI];
        [self pp_applyTheme];
    }
    return self;
}

- (void)pp_setupUI
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.clipsToBounds = NO;
    self.backgroundColor = UIColor.clearColor;

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.backgroundColor = UIColor.clearColor;
    ambientGlow.layer.cornerRadius = kPPProNoticeCornerRadius + 4.0;
    if (@available(iOS 13.0, *)) {
        ambientGlow.layer.cornerCurve = kCACornerCurveContinuous;
    }
    ambientGlow.layer.shadowColor = UIColor.blackColor.CGColor;
    ambientGlow.layer.shadowOpacity = 0.16;
    ambientGlow.layer.shadowRadius = 28.0;
    ambientGlow.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    self.ambientGlowView = ambientGlow;
    [self addSubview:ambientGlow];

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.clipsToBounds = YES;
    surface.userInteractionEnabled = NO;
    surface.layer.cornerRadius = kPPProNoticeCornerRadius;
    if (@available(iOS 13.0, *)) {
        surface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.surfaceView = surface;
    [self addSubview:surface];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.userInteractionEnabled = NO;
        self.blurView = blur;
        [surface addSubview:blur];
    }

    UIView *tint = [[UIView alloc] init];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.userInteractionEnabled = NO;
    self.tintView = tint;
    [surface addSubview:tint];

    CAGradientLayer *surfaceWash = [CAGradientLayer layer];
    surfaceWash.startPoint = CGPointMake(0.0, 0.0);
    surfaceWash.endPoint = CGPointMake(1.0, 1.0);
    surfaceWash.locations = @[@0.0, @0.48, @1.0];
    self.surfaceWashLayer = surfaceWash;
    [tint.layer addSublayer:surfaceWash];

    CAGradientLayer *accentBloom = [CAGradientLayer layer];
    accentBloom.startPoint = CGPointMake(0.0, 0.5);
    accentBloom.endPoint = CGPointMake(1.0, 0.5);
    accentBloom.locations = @[@0.0, @0.34, @1.0];
    self.accentBloomLayer = accentBloom;
    [tint.layer addSublayer:accentBloom];

    UIView *topSheen = [[UIView alloc] init];
    topSheen.translatesAutoresizingMaskIntoConstraints = NO;
    topSheen.userInteractionEnabled = NO;
    topSheen.layer.cornerRadius = 1.0;
    if (@available(iOS 13.0, *)) {
        topSheen.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.topSheenView = topSheen;
    [surface addSubview:topSheen];

    UIView *accentRail = [[UIView alloc] init];
    accentRail.translatesAutoresizingMaskIntoConstraints = NO;
    accentRail.userInteractionEnabled = NO;
    accentRail.layer.cornerRadius = 1.5;
    if (@available(iOS 13.0, *)) {
        accentRail.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.accentRailView = accentRail;
    [surface addSubview:accentRail];

    CAGradientLayer *railLight = [CAGradientLayer layer];
    railLight.startPoint = CGPointMake(0.5, 0.0);
    railLight.endPoint = CGPointMake(0.5, 1.0);
    railLight.locations = @[@0.0, @0.5, @1.0];
    railLight.opacity = 0.0;
    railLight.hidden = YES;
    self.railLightLayer = railLight;
    [accentRail.layer addSublayer:railLight];

    UIView *contentGroup = [[UIView alloc] init];
    contentGroup.translatesAutoresizingMaskIntoConstraints = NO;
    contentGroup.userInteractionEnabled = NO;
    contentGroup.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentGroupView = contentGroup;
    [surface addSubview:contentGroup];

    UIView *iconWell = [[UIView alloc] init];
    iconWell.translatesAutoresizingMaskIntoConstraints = NO;
    iconWell.userInteractionEnabled = NO;
    iconWell.layer.cornerRadius = 17.0;
    if (@available(iOS 13.0, *)) {
        iconWell.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.iconWellView = iconWell;
    [contentGroup addSubview:iconWell];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.userInteractionEnabled = NO;
    icon.isAccessibilityElement = NO;
    self.iconView = icon;
    [iconWell addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:[Styling fontBold:16.5]];
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 2;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    title.textAlignment = [Language alignmentForCurrentLanguage];
    title.isAccessibilityElement = NO;
    [title setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    self.titleLabel = title;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[Styling fontMedium:13.0]];
    subtitle.adjustsFontForContentSizeCategory = YES;
    subtitle.numberOfLines = 2;
    subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
    subtitle.textAlignment = [Language alignmentForCurrentLanguage];
    subtitle.isAccessibilityElement = NO;
    [subtitle setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    self.subtitleLabel = subtitle;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentFill;
    textStack.distribution = UIStackViewDistributionFill;
    textStack.spacing = 3.0;
    textStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    textStack.userInteractionEnabled = NO;
    self.textStack = textStack;
    [contentGroup addSubview:textStack];

    UIView *chevronWell = [[UIView alloc] init];
    chevronWell.translatesAutoresizingMaskIntoConstraints = NO;
    chevronWell.userInteractionEnabled = NO;
    chevronWell.layer.cornerRadius = kPPProNoticeChevronWellSize / 2.0;
    if (@available(iOS 13.0, *)) {
        chevronWell.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.chevronWellView = chevronWell;
    [contentGroup addSubview:chevronWell];

    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.userInteractionEnabled = NO;
    chevron.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12.5 weight:UIImageSymbolWeightBold];
        chevron.image = [UIImage systemImageNamed:@"chevron.forward" withConfiguration:cfg];
    }
    self.chevronView = chevron;
    [chevronWell addSubview:chevron];

    CAShapeLayer *progressTrack = [CAShapeLayer layer];
    progressTrack.fillColor = UIColor.clearColor.CGColor;
    progressTrack.lineCap = kCALineCapRound;
    progressTrack.lineWidth = 2.0;
    progressTrack.opacity = 1.0;
    self.progressTrackLayer = progressTrack;
    [surface.layer addSublayer:progressTrack];

    CAShapeLayer *progress = [CAShapeLayer layer];
    progress.fillColor = UIColor.clearColor.CGColor;
    progress.lineCap = kCALineCapRound;
    progress.lineWidth = 2.0;
    progress.opacity = 0.84;
    self.progressLayer = progress;
    [surface.layer addSublayer:progress];

    [NSLayoutConstraint activateConstraints:@[
        [ambientGlow.topAnchor constraintEqualToAnchor:self.topAnchor constant:1.0],
        [ambientGlow.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:2.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-2.0],
        [ambientGlow.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-1.0],

        [surface.topAnchor constraintEqualToAnchor:self.topAnchor],
        [surface.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [surface.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [surface.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    if (self.blurView) {
        [NSLayoutConstraint activateConstraints:@[
            [self.blurView.topAnchor constraintEqualToAnchor:surface.topAnchor],
            [self.blurView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
            [self.blurView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
            [self.blurView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [tint.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [tint.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [tint.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [tint.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        [topSheen.topAnchor constraintEqualToAnchor:surface.topAnchor constant:8.0],
        [topSheen.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:28.0],
        [topSheen.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-28.0],
        [topSheen.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [accentRail.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:9.0],
        [accentRail.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [accentRail.widthAnchor constraintEqualToConstant:3.0],
        [accentRail.heightAnchor constraintEqualToConstant:38.0],

        [contentGroup.topAnchor constraintGreaterThanOrEqualToAnchor:surface.topAnchor constant:14.0],
        [contentGroup.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18.0],
        [contentGroup.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-14.0],
        [contentGroup.bottomAnchor constraintLessThanOrEqualToAnchor:surface.bottomAnchor constant:-15.0],
        [contentGroup.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],

        [iconWell.leadingAnchor constraintEqualToAnchor:contentGroup.leadingAnchor],
        [iconWell.centerYAnchor constraintEqualToAnchor:contentGroup.centerYAnchor],
        [iconWell.widthAnchor constraintEqualToConstant:kPPProNoticeIconWellSize],
        [iconWell.heightAnchor constraintEqualToConstant:kPPProNoticeIconWellSize],

        [icon.centerXAnchor constraintEqualToAnchor:iconWell.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:iconWell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:kPPProNoticeIconSize],
        [icon.heightAnchor constraintEqualToConstant:kPPProNoticeIconSize],

        [chevronWell.trailingAnchor constraintEqualToAnchor:contentGroup.trailingAnchor],
        [chevronWell.centerYAnchor constraintEqualToAnchor:contentGroup.centerYAnchor],
        [chevronWell.widthAnchor constraintEqualToConstant:kPPProNoticeChevronWellSize],
        [chevronWell.heightAnchor constraintEqualToConstant:kPPProNoticeChevronWellSize],

        [chevron.centerXAnchor constraintEqualToAnchor:chevronWell.centerXAnchor],
        [chevron.centerYAnchor constraintEqualToAnchor:chevronWell.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:11.0],
        [chevron.heightAnchor constraintEqualToConstant:14.0],

        [textStack.leadingAnchor constraintEqualToAnchor:iconWell.trailingAnchor constant:13.0],
        [textStack.trailingAnchor constraintEqualToAnchor:chevronWell.leadingAnchor constant:-12.0],
        [textStack.topAnchor constraintGreaterThanOrEqualToAnchor:contentGroup.topAnchor],
        [textStack.bottomAnchor constraintLessThanOrEqualToAnchor:contentGroup.bottomAnchor],
        [textStack.centerYAnchor constraintEqualToAnchor:contentGroup.centerYAnchor],
    ]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_applyTheme];

    CGFloat height = self.surfaceView.bounds.size.height;
    CGFloat width = self.surfaceView.bounds.size.width;
    self.surfaceWashLayer.frame = self.tintView.bounds;
    self.accentBloomLayer.frame = CGRectMake(0.0, 0.0, width, height);
    self.railLightLayer.frame = self.accentRailView.bounds;

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:kPPProNoticeCornerRadius];
    self.ambientGlowView.layer.shadowPath = shadowPath.CGPath;

    CGFloat progressWidth = MAX(1.0, width - 42.0);
    CGRect progressFrame = CGRectMake(21.0, height - 5.0, progressWidth, 2.0);
    self.progressTrackLayer.frame = progressFrame;
    self.progressLayer.frame = progressFrame;

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0.0, 1.0)];
    [path addLineToPoint:CGPointMake(progressWidth, 1.0)];
    self.progressTrackLayer.path = path.CGPath;
    self.progressLayer.path = path.CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyTheme];
}

- (void)pp_applyTheme
{
    UIColor *accent = self.accentColor ?: AppPrimaryClr;
    UIColor *resolvedAccent = [accent resolvedColorWithTraitCollection:self.traitCollection];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();

    if (self.blurView) {
        if (reduceTransparency) {
            self.blurView.effect = nil;
        } else if (@available(iOS 13.0, *)) {
            self.blurView.effect = [UIBlurEffect effectWithStyle:isDark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight];
        }
    }

    self.tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        if (UIAccessibilityIsReduceTransparencyEnabled()) {
            return dark ? [UIColor colorWithWhite:0.055 alpha:0.99] : [UIColor colorWithWhite:1.0 alpha:0.99];
        }
        return dark ? [UIColor colorWithWhite:0.035 alpha:0.74] : [UIColor colorWithWhite:1.0 alpha:0.70];
    }];

    self.titleLabel.textColor = [UIColor ppTextPrimary];
    self.subtitleLabel.textColor = [[UIColor ppTextSecondary] colorWithAlphaComponent:isDark ? 0.86 : 0.82];
    self.iconView.tintColor = resolvedAccent;
    self.chevronView.tintColor = [[UIColor ppTextTertiary] colorWithAlphaComponent:isDark ? 0.84 : 0.72];

    self.surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.surfaceView.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark ? [UIColor colorWithWhite:1.0 alpha:0.145] : [UIColor colorWithWhite:0.0 alpha:0.070];
    }].CGColor;

    self.iconWellView.backgroundColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.16 : 0.105];
    self.iconWellView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.iconWellView.layer.borderColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.22 : 0.16].CGColor;

    self.chevronWellView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark ? [UIColor colorWithWhite:1.0 alpha:0.070] : [UIColor colorWithWhite:0.0 alpha:0.040];
    }];
    self.chevronWellView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.chevronWellView.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark ? [UIColor colorWithWhite:1.0 alpha:0.075] : [UIColor colorWithWhite:0.0 alpha:0.035];
    }].CGColor;

    self.accentRailView.backgroundColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.48 : 0.42];
    self.topSheenView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.080 : 0.520];
    self.ambientGlowView.layer.shadowOpacity = isDark ? 0.30 : 0.14;
    self.ambientGlowView.layer.shadowRadius = isDark ? 30.0 : 28.0;
    self.ambientGlowView.layer.shadowOffset = CGSizeMake(0.0, isDark ? 16.0 : 14.0);

    CGFloat washWhiteAlpha = isDark ? 0.060 : 0.620;
    CGFloat accentAlpha = isDark ? 0.105 : 0.055;
    self.surfaceWashLayer.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:washWhiteAlpha].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:accentAlpha].CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
    ];

    self.accentBloomLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:isDark ? 0.115 : 0.080].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:isDark ? 0.040 : 0.026].CGColor,
        (__bridge id)[UIColor.clearColor CGColor],
    ];

    self.railLightLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.50 : 0.64].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.0].CGColor,
    ];

    self.progressTrackLayer.strokeColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        BOOL dark = trait.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark ? [UIColor colorWithWhite:1.0 alpha:0.070] : [UIColor colorWithWhite:0.0 alpha:0.050];
    }].CGColor;
    self.progressLayer.strokeColor = [resolvedAccent colorWithAlphaComponent:isDark ? 0.76 : 0.68].CGColor;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName accentColor:(UIColor *)accentColor
{
    self.iconName = iconName;
    self.accentColor = accentColor ?: AppPrimaryClr;

    NSString *trimmedTitle = PPProNoticeTrimmedString(title);
    NSString *trimmedSubtitle = PPProNoticeTrimmedString(subtitle);
    self.titleLabel.text = trimmedTitle;
    self.subtitleLabel.text = trimmedSubtitle;
    self.subtitleLabel.hidden = trimmedSubtitle.length == 0;
    self.textStack.spacing = trimmedSubtitle.length == 0 ? 0.0 : 3.0;
    self.accessibilityLabel = trimmedSubtitle.length ? [NSString stringWithFormat:@"%@. %@", trimmedTitle ?: @"", trimmedSubtitle] : (trimmedTitle ?: @"");
    self.accessibilityHint = PPProNoticeLocalizedValue(@"pp_pro_notification_accessibility_hint", @"");
    self.accessibilityIdentifier = @"pp.pro.in_app_notification";

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [UIImage systemImageNamed:iconName ?: @"bell.badge.fill" withConfiguration:config];
    } else {
        self.iconView.image = [UIImage imageNamed:iconName ?: @"bell.badge.fill"];
    }

    [self pp_applyTheme];
    [self setNeedsLayout];
}

- (void)prepareContentEntrance
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self setContentEntranceFinalState];
        return;
    }

    self.surfaceView.alpha = 0.0;
    self.surfaceView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -6.0), CGAffineTransformMakeScale(0.990, 0.990));
    self.ambientGlowView.alpha = 0.0;
    self.iconWellView.alpha = 0.0;
    self.iconWellView.transform = CGAffineTransformMakeScale(0.84, 0.84);
    self.textStack.alpha = 0.0;
    self.textStack.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    self.chevronWellView.alpha = 0.0;
    self.chevronWellView.transform = CGAffineTransformMakeTranslation(Language.isRTL ? -5.0 : 5.0, 0.0);
    self.accentRailView.alpha = 0.0;
    self.accentRailView.transform = CGAffineTransformMakeScale(1.0, 0.52);
    self.progressTrackLayer.opacity = 0.0;
    self.progressLayer.opacity = 0.0;
}

- (void)animateContentEntranceWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self setContentEntranceFinalState];
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.surfaceView.alpha = 1.0;
        self.surfaceView.transform = CGAffineTransformIdentity;
        self.ambientGlowView.alpha = 1.0;
    } completion:nil];

    [UIView animateWithDuration:0.36
                          delay:delay + 0.035
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.34
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.iconWellView.alpha = 1.0;
        self.iconWellView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.32
                          delay:delay + 0.070
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.textStack.alpha = 1.0;
        self.textStack.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.30
                          delay:delay + 0.105
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.chevronWellView.alpha = 1.0;
        self.chevronWellView.transform = CGAffineTransformIdentity;
        self.accentRailView.alpha = 1.0;
        self.accentRailView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.24
                          delay:delay + 0.150
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.progressTrackLayer.opacity = 1.0;
        self.progressLayer.opacity = 0.84;
    } completion:nil];
}

- (void)setContentEntranceFinalState
{
    self.surfaceView.alpha = 1.0;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.ambientGlowView.alpha = 1.0;
    self.iconWellView.alpha = 1.0;
    self.iconWellView.transform = CGAffineTransformIdentity;
    self.textStack.alpha = 1.0;
    self.textStack.transform = CGAffineTransformIdentity;
    self.chevronWellView.alpha = 1.0;
    self.chevronWellView.transform = CGAffineTransformIdentity;
    self.accentRailView.alpha = 1.0;
    self.accentRailView.transform = CGAffineTransformIdentity;
    self.progressTrackLayer.opacity = 1.0;
    self.progressLayer.opacity = 0.84;
}

- (void)startLiveEffectsWithDuration:(NSTimeInterval)duration
{
    [self stopLiveEffects];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.railLightLayer.hidden = NO;
    self.railLightLayer.opacity = 0.0;
    CABasicAnimation *railPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    railPulse.fromValue = @0.0;
    railPulse.toValue = @0.78;
    railPulse.duration = 1.35;
    railPulse.autoreverses = YES;
    railPulse.repeatCount = HUGE_VALF;
    railPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.railLightLayer addAnimation:railPulse forKey:@"pp.pro.notice.rail.pulse"];

    self.progressLayer.strokeStart = 0.0;
    self.progressLayer.strokeEnd = 1.0;

    NSString *keyPath = Language.isRTL ? @"strokeStart" : @"strokeEnd";
    CABasicAnimation *progress = [CABasicAnimation animationWithKeyPath:keyPath];
    progress.fromValue = Language.isRTL ? @0.0 : @1.0;
    progress.toValue = Language.isRTL ? @1.0 : @0.0;
    progress.duration = duration;
    progress.removedOnCompletion = NO;
    progress.fillMode = kCAFillModeForwards;
    progress.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];
    [self.progressLayer addAnimation:progress forKey:@"pp.pro.notice.progress"];
}

- (void)stopLiveEffects
{
    [self.railLightLayer removeAnimationForKey:@"pp.pro.notice.rail.pulse"];
    [self.progressLayer removeAnimationForKey:@"pp.pro.notice.progress"];
    self.railLightLayer.hidden = YES;
    self.railLightLayer.opacity = 0.0;
    self.progressLayer.strokeStart = 0.0;
    self.progressLayer.strokeEnd = 1.0;
}

@end

#pragma mark - Presenter Implementation

@interface PPProInAppNotificationPresenter ()
@property (nonatomic, strong) PPProNoticePassthroughWindow *overlayWindow;
@property (nonatomic, strong) PPProNoticeBannerView *bannerView;
@property (nonatomic, copy) dispatch_block_t dismissWork;
@property (nonatomic, copy) NSDictionary<NSString *, id> *currentPayload;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong) AVAudioPlayer *notificationSoundPlayer;
@property (nonatomic, assign) CFTimeInterval lastSoundPlaybackTime;
@property (nonatomic, assign) NSUInteger soundRequestGeneration;
- (void)pp_announceBannerForAccessibility;
@end

@implementation PPProInAppNotificationPresenter

+ (instancetype)sharedPresenter
{
    static PPProInAppNotificationPresenter *presenter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        presenter = [[PPProInAppNotificationPresenter alloc] init];
    });
    return presenter;
}

+ (BOOL)notificationPreferencesAllowPayload:(NSDictionary<NSString *, id> *)payload
{
    if (!PPProNoticeBoolPreference(kPPProNotifMasterPreferenceKey, YES)) {
        return NO;
    }
    NSString *categoryKey = PPProNoticeCategoryPreferenceKeyForPayload(payload);
    return PPProNoticeBoolPreference(categoryKey, YES);
}

+ (BOOL)notificationPreferencesAllowSoundForPayload:(NSDictionary<NSString *, id> *)payload
{
    if (![self notificationPreferencesAllowPayload:payload]) {
        return NO;
    }
    return PPProNoticeBoolPreference(kPPProNotifSoundPreferenceKey, YES);
}

- (void)playNotificationSound
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!PPProNoticeBoolPreference(kPPProNotifMasterPreferenceKey, YES) ||
            !PPProNoticeBoolPreference(kPPProNotifSoundPreferenceKey, YES)) {
            return;
        }
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            [self pp_playSoundWithCategory:AVAudioSessionCategoryAmbient];
        } else {
            [self pp_playSoundWithCategory:AVAudioSessionCategoryPlayback];
        }
    });
}

- (void)pp_playSoundWithCategory:(AVAudioSessionCategory)category
{
    NSUInteger generation = ++self.soundRequestGeneration;
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.soundRequestGeneration ||
                settings.soundSetting == UNNotificationSettingDisabled) {
                return;
            }

            CFTimeInterval now = CACurrentMediaTime();
            if (now - self.lastSoundPlaybackTime < kPPProNoticeSoundThrottle) return;

            NSURL *soundURL = [NSBundle.mainBundle URLForResource:kPPProNoticeSoundResource
                                                    withExtension:kPPProNoticeSoundExtension];
            if (!soundURL) {
                NSLog(@"[Notifications] Pro in-app sound resource unavailable.");
                return;
            }

            NSError *sessionError = nil;
            [AVAudioSession.sharedInstance setCategory:category
                                                   mode:AVAudioSessionModeDefault
                                                options:AVAudioSessionCategoryOptionMixWithOthers
                                                  error:&sessionError];

            NSError *playerError = nil;
            AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&playerError];
            if (!player || playerError || sessionError) {
                NSLog(@"[Notifications] Pro in-app sound could not be prepared.");
                return;
            }

            player.volume = 0.88;
            [player prepareToPlay];
            self.notificationSoundPlayer = player;
            self.lastSoundPlaybackTime = now;
            [player play];
        });
    }];
}

- (void)showOrderNotificationWithOrderId:(NSString *)orderId title:(NSString *)title subtitle:(NSString *)subtitle
{
    NSDictionary *payload = @{
        @"type": @"order",
        @"orderId": orderId ?: @"",
        @"title": title ?: @"",
        @"message": subtitle ?: @""
    };
    [self pp_showNotification:payload
                        title:title
                     subtitle:subtitle
                     iconName:@"shippingbox.fill"
                  accentColor:AppPrimaryClr];
}

- (void)showDeliveryNotificationWithOrderId:(NSString *)orderId title:(NSString *)title subtitle:(NSString *)subtitle
{
    NSDictionary *payload = @{
        @"type": @"delivery",
        @"orderId": orderId ?: @"",
        @"title": title ?: @"",
        @"message": subtitle ?: @""
    };
    [self pp_showNotification:payload
                        title:title
                     subtitle:subtitle
                     iconName:@"bicycle"
                  accentColor:[UIColor ppWarning]];
}

- (void)showCompanyDeliveryNotificationWithPayload:(NSDictionary<NSString *,id> *)payload
                                              title:(NSString *)title
                                           subtitle:(NSString *)subtitle
{
    NSMutableDictionary<NSString *, id> *resolvedPayload = [NSMutableDictionary dictionaryWithDictionary:payload ?: @{}];
    resolvedPayload[@"type"] = @"company_delivery_request";
    resolvedPayload[@"route"] = @"fleet_partner";
    resolvedPayload[@"title"] = title ?: @"";
    resolvedPayload[@"message"] = subtitle ?: @"";
    [self pp_showNotification:resolvedPayload.copy
                        title:title
                     subtitle:subtitle
                     iconName:@"truck.box.fill"
                  accentColor:AppPrimaryClr];
}

- (void)showNotificationWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName accentColor:(UIColor *)accentColor
{
    NSDictionary *payload = @{
        @"type": @"generic",
        @"title": title ?: @"",
        @"message": subtitle ?: @""
    };
    [self pp_showNotification:payload title:title subtitle:subtitle iconName:iconName accentColor:accentColor];
}

- (void)showNotificationWithPayload:(NSDictionary<NSString *,id> *)payload
                               title:(NSString *)title
                            subtitle:(NSString *)subtitle
                            iconName:(NSString *)iconName
                         accentColor:(UIColor *)accentColor
{
    NSMutableDictionary<NSString *, id> *resolvedPayload = [NSMutableDictionary dictionaryWithDictionary:payload ?: @{}];
    if (title.length > 0) {
        resolvedPayload[@"title"] = title;
    }
    if (subtitle.length > 0) {
        resolvedPayload[@"message"] = subtitle;
        if (!resolvedPayload[@"body"]) {
            resolvedPayload[@"body"] = subtitle;
        }
    }
    [self pp_showNotification:resolvedPayload.copy
                        title:title
                     subtitle:subtitle
                     iconName:iconName
                  accentColor:accentColor];
}

- (void)pp_showNotification:(NSDictionary *)payload
{
    [self pp_showNotification:payload title:payload[@"title"] ?: @"Notification"
                     subtitle:payload[@"message"] ?: @""
                     iconName:@"bell.badge.fill"
                  accentColor:AppPrimaryClr];
}

- (void)pp_showNotification:(NSDictionary *)payload title:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName accentColor:(UIColor *)accentColor
{
    if (title.length == 0 && subtitle.length == 0) {
        return;
    }
    if (![PPProInAppNotificationPresenter notificationPreferencesAllowPayload:payload]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            return;
        }

        self.currentPayload = payload.copy;
        [self pp_prepareOverlayIfNeeded];
        [self.bannerView configureWithTitle:title subtitle:subtitle iconName:iconName accentColor:accentColor];
        [self pp_cancelDismissWork];
        [self pp_showBanner];
        [self pp_scheduleDismiss];
    });
}

- (void)dismissCurrentNotificationAnimated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_cancelDismissWork];
        [self pp_hideBannerAnimated:animated completion:nil];
    });
}

#pragma mark - Overlay

- (void)pp_prepareOverlayIfNeeded
{
    if (self.overlayWindow && self.bannerView.superview) {
        UIWindowScene *scene = self.overlayWindow.windowScene;
        if (!scene || scene.activationState == UISceneActivationStateForegroundActive) {
            self.overlayWindow.hidden = NO;
            return;
        }
        self.overlayWindow.hidden = YES;
        self.overlayWindow = nil;
        self.bannerView = nil;
    }
    
    PPProNoticePassthroughWindow *window = nil;
    UIWindowScene *activeScene = [self pp_activeWindowScene];
    if (activeScene) {
        window = [[PPProNoticePassthroughWindow alloc] initWithWindowScene:activeScene];
    } else {
        window = [[PPProNoticePassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    window.windowLevel = UIWindowLevelStatusBar + 4.0;
    window.backgroundColor = UIColor.clearColor;
    window.hidden = YES;
    window.userInteractionEnabled = YES;
    
    PPProNoticeRootViewController *root = [[PPProNoticeRootViewController alloc] init];
    window.rootViewController = root;
    
    PPProNoticeBannerView *banner = [[PPProNoticeBannerView alloc] initWithFrame:CGRectZero];
    banner.hidden = YES;
    banner.alpha = 0.0;
    [banner addTarget:self action:@selector(pp_bannerTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [banner addTarget:self action:@selector(pp_bannerTouchCancel:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [banner addTarget:self action:@selector(pp_bannerTapped:) forControlEvents:UIControlEventTouchUpInside];
    UISwipeGestureRecognizer *dismissSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(pp_bannerSwiped:)];
    dismissSwipe.direction = UISwipeGestureRecognizerDirectionUp;
    [banner addGestureRecognizer:dismissSwipe];
    [root.view addSubview:banner];
    
    UILayoutGuide *safe = root.view.safeAreaLayoutGuide;
    NSLayoutConstraint *widthLimit = [banner.widthAnchor constraintLessThanOrEqualToConstant:kPPProNoticeMaxWidth];
    widthLimit.priority = UILayoutPriorityRequired;
    
    [NSLayoutConstraint activateConstraints:@[
        [banner.topAnchor constraintEqualToAnchor:safe.topAnchor constant:kPPProNoticeTopInset],
        [banner.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.view.leadingAnchor constant:kPPProNoticeHorizontalInset],
        [banner.trailingAnchor constraintLessThanOrEqualToAnchor:root.view.trailingAnchor constant:-kPPProNoticeHorizontalInset],
        [banner.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
        widthLimit,
        [banner.heightAnchor constraintGreaterThanOrEqualToConstant:kPPProNoticeMinHeight],
    ]];
    
    window.touchTarget = banner;
    self.overlayWindow = window;
    self.bannerView = banner;
}

- (UIWindowScene *)pp_activeWindowScene
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

#pragma mark - Motion

- (void)pp_showBanner
{
    [self.overlayWindow.rootViewController.view layoutIfNeeded];
    [self.bannerView.layer removeAllAnimations];
    [self.bannerView stopLiveEffects];

    if (self.isVisible) {
        self.overlayWindow.hidden = NO;
        self.bannerView.hidden = NO;
        [self pp_refreshVisibleBannerMotion];
        [self.bannerView startLiveEffectsWithDuration:kPPProNoticeVisibleDuration];
        return;
    }

    self.isVisible = YES;
    [self.bannerView prepareContentEntrance];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [self.bannerView setContentEntranceFinalState];
        self.overlayWindow.hidden = NO;
        self.bannerView.hidden = NO;
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.bannerView.alpha = 1.0;
        } completion:^(__unused BOOL finished) {
            [self pp_announceBannerForAccessibility];
        }];
        return;
    }

    self.bannerView.alpha = 0.0;
    self.bannerView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -24.0),
                                                         CGAffineTransformMakeScale(0.972, 0.972));
    self.overlayWindow.hidden = NO;
    self.bannerView.hidden = NO;

    [UIView animateWithDuration:0.48
                          delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.62
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [self pp_announceBannerForAccessibility];
    }];

    [self.bannerView animateContentEntranceWithDelay:0.055];
    [self.bannerView startLiveEffectsWithDuration:kPPProNoticeVisibleDuration];
}

- (void)pp_refreshVisibleBannerMotion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [self.bannerView setContentEntranceFinalState];
        [self pp_announceBannerForAccessibility];
        return;
    }

    [self.bannerView prepareContentEntrance];
    self.bannerView.transform = CGAffineTransformMakeScale(0.988, 0.988);
    [UIView animateWithDuration:0.22
                          delay:0.0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.bannerView.alpha = 1.0;
        self.bannerView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [self pp_announceBannerForAccessibility];
    }];
    [self.bannerView animateContentEntranceWithDelay:0.025];
}

- (void)pp_announceBannerForAccessibility
{
    if (UIAccessibilityIsVoiceOverRunning() && self.bannerView.accessibilityLabel.length > 0) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.bannerView.accessibilityLabel);
    }
}

- (void)pp_hideBannerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    if (!self.isVisible && self.bannerView.hidden) {
        if (completion) completion();
        return;
    }
    
    self.isVisible = NO;
    [self.bannerView stopLiveEffects];
    
    void (^finish)(void) = ^{
        self.bannerView.hidden = YES;
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformIdentity;
        [self.bannerView setContentEntranceFinalState];
        self.overlayWindow.hidden = YES;
        self.currentPayload = nil;
        if (completion) completion();
    };
    
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        finish();
        return;
    }
    
    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.bannerView.alpha = 0.0;
        self.bannerView.transform = CGAffineTransformMakeTranslation(0, -24.0);
    } completion:^(__unused BOOL finished) {
        finish();
    }];
}

- (void)pp_scheduleDismiss
{
    __weak typeof(self) weakSelf = self;
    dispatch_block_t work = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_hideBannerAnimated:YES completion:nil];
    });
    self.dismissWork = work;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPProNoticeVisibleDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   work);
}

- (void)pp_cancelDismissWork
{
    if (self.dismissWork) {
        dispatch_block_cancel(self.dismissWork);
        self.dismissWork = nil;
    }
}

#pragma mark - Touch

- (void)pp_bannerSwiped:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized) {
        [self dismissCurrentNotificationAnimated:YES];
    }
}

- (void)pp_bannerTouchDown:(UIControl *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 1.0), CGAffineTransformMakeScale(0.986, 0.986));
        if ([sender isKindOfClass:PPProNoticeBannerView.class]) {
            PPProNoticeBannerView *banner = (PPProNoticeBannerView *)sender;
            banner.surfaceView.alpha = 0.94;
            banner.ambientGlowView.alpha = 0.78;
        }
    } completion:nil];
}

- (void)pp_bannerTouchCancel:(UIControl *)sender
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        if ([sender isKindOfClass:PPProNoticeBannerView.class]) {
            PPProNoticeBannerView *banner = (PPProNoticeBannerView *)sender;
            banner.surfaceView.alpha = 1.0;
            banner.ambientGlowView.alpha = 1.0;
        }
    } completion:nil];
}

- (void)pp_bannerTapped:(UIControl *)sender
{
    (void)sender;
    if (@available(iOS 10.0, *)) {
        UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
        [feedback selectionChanged];
    }
    NSDictionary<NSString *, id> *payload = self.currentPayload.copy;
    if (payload.count == 0) {
        [self dismissCurrentNotificationAnimated:YES];
        return;
    }
    
    [self pp_cancelDismissWork];
    [self pp_hideBannerAnimated:YES completion:^{
        SceneDelegate *sceneDelegate = PPProNoticeActiveSceneDelegate();
        if (sceneDelegate) {
            [sceneDelegate openNotificationsTabFromNotificationPayload:payload];
            return;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:PPProNotificationPayloadTappedNotification
                                                            object:nil
                                                          userInfo:payload];
    }];
}

@end
