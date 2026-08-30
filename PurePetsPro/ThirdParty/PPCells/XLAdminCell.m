//
//  XLAdminCell.m
//  PurePetsAdmin
//
//  Modern trending cell — multi-layer gradient, accent glow, glass icon chip,
//  shine overlay, spring tap feedback. Matches Pure Pets iOS PPHomeActionCell.

#import "XLAdminCell.h"
#import "PPPaddingLabel.h"

static const CGFloat PPCellCorner      = 22.0;
static const CGFloat PPCellIconSize    = 42.0;
static const CGFloat PPCellIconCorner  = 14.0;
static const CGFloat PPCellChevronSize = 28.0;
static const CGFloat PPCellChevronCorner = 14.0;
static const CGFloat PPCellHPad        = 14.0;
static const CGFloat PPCellVPad        = 2.0;
static const CGFloat PPCellHMargin     = 10.0;

@interface XLAdminCell ()
@property (nonatomic, strong) UIView              *surfaceView;
@property (nonatomic, strong) CAGradientLayer     *surfaceGradient;
@property (nonatomic, strong) CAGradientLayer     *shineLayer;
@property (nonatomic, strong) UIView              *accentGlowView;
@property (nonatomic, strong) UIView              *iconSurfaceView;
@property (nonatomic, strong) UIImageView         *iconView;
@property (nonatomic, strong) UILabel             *eyebrowLabel;
@property (nonatomic, strong) UILabel             *titleLabel;
@property (nonatomic, strong) UILabel             *subtitleLabel;
@property (nonatomic, strong) UIStackView         *textStack;
@property (nonatomic, strong) UIView              *chevronPill;
@property (nonatomic, strong) UIImageView         *chevronView;
@property (nonatomic, strong) PPPaddingLabel      *badgeLabel;
@property (nonatomic, strong) NSLayoutConstraint *textStackTrailingConstraint;
@end

@implementation XLAdminCell

#pragma mark - Configure

- (void)configure {
    [super configure];

    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds   = NO;
    self.layer.masksToBounds   = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds   = NO;
    self.contentView.layer.masksToBounds   = NO;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    if (self.surfaceView) return;

    UIColor *accent  = AppPrimaryClr;
    UIColor *accentDarker = AppPrimaryClrDarker;
    UIColor *surface = [UIColor ppElevatedSurface];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    // ── Surface card ──
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = surface;
    self.surfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.surfaceView.layer.cornerRadius  = PPCellCorner;
    self.surfaceView.layer.cornerCurve   = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth   = 1.0 / UIScreen.mainScreen.scale;
    self.surfaceView.layer.borderColor   = [accent colorWithAlphaComponent:isDark ? 0.12 : 0.08].CGColor;
    self.surfaceView.layer.shadowColor   = UIColor.clearColor.CGColor;
    self.surfaceView.layer.shadowOpacity = isDark ? 0.0 : 0.00;
    self.surfaceView.layer.shadowRadius  = 0.0;
    self.surfaceView.layer.shadowOffset  = CGSizeMake(0, 0);
    self.surfaceView.clipsToBounds       = NO;
    self.surfaceView.userInteractionEnabled = NO;
    [self.contentView addSubview:self.surfaceView];

    // ── Gradient overlay (clipped inner) ──
    UIView *gradientHost = [[UIView alloc] init];
    gradientHost.translatesAutoresizingMaskIntoConstraints = NO;
    gradientHost.clipsToBounds     = YES;
    gradientHost.layer.cornerRadius = PPCellCorner;
    gradientHost.layer.cornerCurve  = kCACornerCurveContinuous;
    gradientHost.userInteractionEnabled = NO;
    [self.surfaceView addSubview:gradientHost];

    self.surfaceGradient = [CAGradientLayer layer];
    self.surfaceGradient.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradient.endPoint   = CGPointMake(1.0, 1.0);
    self.surfaceGradient.cornerRadius = PPCellCorner;
    [gradientHost.layer addSublayer:self.surfaceGradient];

    // Shine highlight (top-down)
    self.shineLayer = [CAGradientLayer layer];
    self.shineLayer.startPoint = CGPointMake(0.5, 0.0);
    self.shineLayer.endPoint   = CGPointMake(0.5, 1.0);
    self.shineLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:isDark ? 0.04 : 0.14].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];
    self.shineLayer.locations = @[@0.0, @0.5];
    [gradientHost.layer addSublayer:self.shineLayer];

    // ── Accent glow (leading edge, subtle) ──
    self.accentGlowView = [[UIView alloc] init];
    self.accentGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentGlowView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.10 : 0.18];
    self.accentGlowView.layer.cornerRadius = 22.0;
    self.accentGlowView.userInteractionEnabled = NO;
    [gradientHost addSubview:self.accentGlowView];

    // ── Icon chip (glass effect) ──
    self.iconSurfaceView = [[UIView alloc] init];
    self.iconSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconSurfaceView.backgroundColor = [accent colorWithAlphaComponent:isDark ? 0.14 : 0.10];
    self.iconSurfaceView.layer.cornerRadius  = PPCellIconCorner;
    self.iconSurfaceView.layer.cornerCurve   = kCACornerCurveContinuous;
    self.iconSurfaceView.layer.borderWidth   = 1.0 / UIScreen.mainScreen.scale;
    self.iconSurfaceView.layer.borderColor   = [accent colorWithAlphaComponent:0.12].CGColor;
    [self.surfaceView addSubview:self.iconSurfaceView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = accent;
    [self.iconSurfaceView addSubview:self.iconView];

    // ── Text stack ──
    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = [Styling fontBold:10];
    self.eyebrowLabel.textColor = accent;
    self.eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.eyebrowLabel.numberOfLines = 1;
    self.eyebrowLabel.hidden = YES;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [Styling fontBold:16];
    self.titleLabel.textColor = PrimaryTextClr;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 2;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [Styling fontMedium:12];
    self.subtitleLabel.textColor = SeconderyTextClr;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.numberOfLines = 2;

    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.eyebrowLabel, self.titleLabel, self.subtitleLabel]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis      = UILayoutConstraintAxisVertical;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.spacing   = 4.0;
    self.textStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.surfaceView addSubview:self.textStack];

    // ── Chevron pill ──
    self.chevronPill = [[UIView alloc] init];
    self.chevronPill.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronPill.backgroundColor = [accentDarker colorWithAlphaComponent:isDark ? 0.18 : 0.12];
    self.chevronPill.layer.cornerRadius = PPCellChevronCorner;
    self.chevronPill.layer.cornerCurve  = kCACornerCurveContinuous;
    [self.surfaceView addSubview:self.chevronPill];

    BOOL isRTL = Language.languageVal == 1;
    UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    UIImage *chevImg = [UIImage systemImageNamed:isRTL ? @"chevron.left" : @"chevron.right" withConfiguration:chevCfg];
    self.chevronView = [[UIImageView alloc] initWithImage:chevImg];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.tintColor = accentDarker;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.chevronPill addSubview:self.chevronView];

    // ── Badge Label ──
    self.badgeLabel = [[PPPaddingLabel alloc] init];
    self.badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.badgeLabel.font = [Styling fontBold:11.0];
    self.badgeLabel.textColor = UIColor.whiteColor;
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.backgroundColor = [UIColor ppError];
    self.badgeLabel.textInsets = UIEdgeInsetsMake(3.0, 6.5, 3.0, 6.5);
    self.badgeLabel.layer.cornerRadius = 9.5;
    self.badgeLabel.clipsToBounds = YES;
    self.badgeLabel.hidden = YES;
    [self.surfaceView addSubview:self.badgeLabel];

    // ── Constraints ──
    [NSLayoutConstraint activateConstraints:@[
        // Surface
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPCellVPad],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPCellVPad],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPCellHMargin],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPCellHMargin],

        // Gradient host fills surface
        [gradientHost.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [gradientHost.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [gradientHost.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [gradientHost.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],

        // Accent glow — positioned leading, oversized
        [self.accentGlowView.widthAnchor constraintEqualToConstant:44.0],
        [self.accentGlowView.heightAnchor constraintEqualToConstant:90.0],
        [self.accentGlowView.leadingAnchor constraintEqualToAnchor:gradientHost.leadingAnchor constant:-8.0],
        [self.accentGlowView.centerYAnchor constraintEqualToAnchor:gradientHost.centerYAnchor],

        // Icon chip
        [self.iconSurfaceView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPCellHPad],
        [self.iconSurfaceView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconSurfaceView.widthAnchor constraintEqualToConstant:PPCellIconSize],
        [self.iconSurfaceView.heightAnchor constraintEqualToConstant:PPCellIconSize],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconSurfaceView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconSurfaceView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:22.0],
        [self.iconView.heightAnchor constraintEqualToConstant:22.0],

        // Text stack (leading and centerY)
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.iconSurfaceView.trailingAnchor constant:14.0],
        [self.textStack.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],

        // Badge Label
        [self.badgeLabel.trailingAnchor constraintEqualToAnchor:self.chevronPill.leadingAnchor constant:-8.0],
        [self.badgeLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],

        // Chevron pill
        [self.chevronPill.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPCellHPad],
        [self.chevronPill.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronPill.widthAnchor constraintEqualToConstant:PPCellChevronSize],
        [self.chevronPill.heightAnchor constraintEqualToConstant:PPCellChevronSize],

        [self.chevronView.centerXAnchor constraintEqualToAnchor:self.chevronPill.centerXAnchor],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.chevronPill.centerYAnchor],
    ]];

    // Active trailing limit by default
    self.textStackTrailingConstraint = [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronPill.leadingAnchor constant:-10.0];
    self.textStackTrailingConstraint.active = YES;

    [self pp_applyGradientTheme];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.surfaceView.bounds;
    self.surfaceGradient.frame = b;
    self.shineLayer.frame      = b;
}

#pragma mark - Theme

- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:prev]) {
        [self pp_applyGradientTheme];
    }
}

- (void)pp_applyGradientTheme {
    UIColor *accent  = AppPrimaryClr;
    UIColor *surface = AppForgroundColr;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL supportCard = [self pp_isSupportDeskCard];

    // Surface gradient: surface → surface+accentTint
    UIColor *gradEnd = supportCard
        ? [UIColor colorWithWhite:isDark ? 1.0 : 0.0 alpha:isDark ? 0.035 : 0.018]
        : (isDark
        ? [accent colorWithAlphaComponent:0.06]
           : [accent colorWithAlphaComponent:0.04]);

    self.surfaceGradient.colors = @[
        (id)surface.CGColor,
        (id)[self pp_blendColor:surface with:gradEnd].CGColor,
    ];

    // Shine
    self.shineLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:isDark ? 0.04 : 0.14].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
    ];

    // Border
    self.surfaceView.layer.borderColor = [accent colorWithAlphaComponent:supportCard ? (isDark ? 0.22 : 0.16) : (isDark ? 0.12 : 0.08)].CGColor;
    self.surfaceView.layer.shadowOpacity = supportCard ? (isDark ? 0.0 : 0.06) : (isDark ? 0.0 : 0.00);
    self.surfaceView.layer.shadowRadius = supportCard ? 20.0 : 0.0;
    self.surfaceView.layer.shadowOffset = supportCard ? CGSizeMake(0.0, 10.0) : CGSizeMake(0.0, 0.0);

    // Glow
    self.accentGlowView.backgroundColor = [accent colorWithAlphaComponent:supportCard ? (isDark ? 0.08 : 0.11) : (isDark ? 0.10 : 0.18)];

    // Icon chip
    self.iconSurfaceView.backgroundColor = supportCard
        ? [(PrimaryTextClr) colorWithAlphaComponent:isDark ? 0.14 : 0.07]
        : [accent colorWithAlphaComponent:isDark ? 0.14 : 0.10];
    self.iconSurfaceView.layer.borderColor = [accent colorWithAlphaComponent:supportCard ? 0.18 : 0.12].CGColor;

    // Chevron
    UIColor *accentDarker = AppPrimaryClrDarker;
    self.chevronPill.backgroundColor = [accentDarker colorWithAlphaComponent:supportCard ? (isDark ? 0.16 : 0.10) : (isDark ? 0.18 : 0.12)];
    self.chevronView.tintColor = supportCard ? accent : accentDarker;
    self.eyebrowLabel.textColor = accent;
}

- (UIColor *)pp_blendColor:(UIColor *)base with:(UIColor *)overlay {
    CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
    [base getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [overlay getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    return [UIColor colorWithRed:r1 * (1 - a2) + r2 * a2
                           green:g1 * (1 - a2) + g2 * a2
                            blue:b1 * (1 - a2) + b2 * a2
                           alpha:1.0];
}

#pragma mark - Update

- (void)update {
    [super update];
    NSDictionary *value = self.rowDescriptor.value;
    self.iconView.image    = value[@"icon"];
    self.titleLabel.text   = value[@"title"];
    self.subtitleLabel.text = value[@"subtitle"];
    self.subtitleLabel.hidden = (self.subtitleLabel.text.length == 0);
    BOOL supportCard = [self pp_isSupportDeskCard];
    NSString *eyebrow = [value[@"eyebrow"] isKindOfClass:NSString.class] ? value[@"eyebrow"] : @"";
    self.eyebrowLabel.text = eyebrow.uppercaseString;
    self.eyebrowLabel.hidden = !supportCard || eyebrow.length == 0;
    self.textStack.spacing = supportCard ? 3.0 : 4.0;
    self.titleLabel.font = supportCard ? [Styling fontBold:18] : [Styling fontBold:16];
    self.subtitleLabel.font = supportCard ? [Styling fontMedium:12.5] : [Styling fontMedium:12];
    self.titleLabel.textColor = PrimaryTextClr;
    self.subtitleLabel.textColor = supportCard
        ? [(SeconderyTextClr) colorWithAlphaComponent:0.82]
        : (SeconderyTextClr);
    self.iconSurfaceView.layer.cornerRadius = supportCard ? 18.0 : PPCellIconCorner;
    self.surfaceView.layer.cornerRadius = supportCard ? 26.0 : PPCellCorner;
    self.surfaceGradient.cornerRadius = supportCard ? 26.0 : PPCellCorner;

    // Dynamic Badge Update
    NSString *badgeText = nil;
    if (value[@"badgeText"]) {
        badgeText = [NSString stringWithFormat:@"%@", value[@"badgeText"]];
    } else if (value[@"badgeCount"]) {
        badgeText = [NSString stringWithFormat:@"%@", value[@"badgeCount"]];
    }

    if (badgeText.length > 0 && ![badgeText isEqualToString:@"0"]) {
        self.badgeLabel.text = badgeText;
        self.badgeLabel.hidden = NO;
        self.textStackTrailingConstraint.active = NO;
        self.textStackTrailingConstraint = [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.badgeLabel.leadingAnchor constant:-8.0];
        self.textStackTrailingConstraint.active = YES;
    } else {
        self.badgeLabel.text = nil;
        self.badgeLabel.hidden = YES;
        self.textStackTrailingConstraint.active = NO;
        self.textStackTrailingConstraint = [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronPill.leadingAnchor constant:-10.0];
        self.textStackTrailingConstraint.active = YES;
    }

    [self pp_applyGradientTheme];
}

- (BOOL)pp_isSupportDeskCard {
    NSDictionary *value = self.rowDescriptor.value;
    NSString *style = [value[@"style"] isKindOfClass:NSString.class] ? value[@"style"] : @"";
    return [style isEqualToString:@"supportChat"];
}

#pragma mark - Interaction (Spring Tap Feedback)

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_applyInteraction:highlighted || self.selected animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_applyInteraction:selected || self.highlighted animated:animated];
}

- (void)pp_applyInteraction:(BOOL)pressed animated:(BOOL)animated {
    CGFloat scale = pressed ? 0.975 : 1.0;
    UIColor *accent = AppPrimaryClr;
    BOOL supportCard = [self pp_isSupportDeskCard];
    UIColor *idleIconSurface = supportCard
        ? [(PrimaryTextClr) colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.14 : 0.07]
        : [accent colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.14 : 0.10];

    void (^changes)(void) = ^{
        self.surfaceView.transform = CGAffineTransformMakeScale(scale, scale);
        self.surfaceView.layer.shadowOpacity = pressed ? 0.0 : (supportCard && self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark ? 0.06 : 0.0);
        self.iconSurfaceView.backgroundColor = pressed
            ? [accent colorWithAlphaComponent:0.22]
            : idleIconSurface;
    };

    if (animated) {
        [UIView animateWithDuration:pressed ? 0.12 : 0.4
                              delay:0
             usingSpringWithDamping:pressed ? 1.0 : 0.75
              initialSpringVelocity:pressed ? 0 : 0.8
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller {
    if (self.rowDescriptor.action.formBlock) {
        self.rowDescriptor.action.formBlock(self.rowDescriptor);
    }
}

@end
