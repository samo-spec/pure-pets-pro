//
//  PPQuickActionsView.m
//  PurePetsAdmin
//

#import "PPQuickActionsView.h"

#pragma mark - PPQuickActionItem

@implementation PPQuickActionItem

+ (instancetype)itemWithTitleKey:(NSString *)titleKey
                     subtitleKey:(NSString *)subtitleKey
                        iconName:(NSString *)iconName
                           width:(CGFloat)width
                        handler:(void (^ _Nullable)(void))handler {
    PPQuickActionItem *item = [[PPQuickActionItem alloc] init];
    item.titleKey = titleKey;
    item.subtitleKey = subtitleKey;
    item.iconName = iconName;
    item.buttonWidth = width;
    item.handler = handler;
    return item;
}

+ (instancetype)itemWithTitleKey:(NSString *)titleKey
                        iconName:(NSString *)iconName
                           width:(CGFloat)width
                        handler:(void (^ _Nullable)(void))handler {
    return [self itemWithTitleKey:titleKey
                      subtitleKey:nil
                         iconName:iconName
                            width:width
                         handler:handler];
}

@end

#pragma mark - PPQuickActionsView

@interface PPQuickActionsView ()
@property (nonatomic, strong) UIStackView *stack;
- (UIView *)pp_breathingDotWithAccentColor:(UIColor *)accentColor coreView:(UIView * _Nullable * _Nullable)coreView badgeText:(NSString * _Nullable)badgeText;
- (void)pp_startBreathingDotMotionForContainer:(UIView *)container core:(UIView *)core;
@end

@implementation PPQuickActionsView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _buttonHeight = 58.0;
        _cornerRadius = 24.0;
        _backgroundColorForButton = AppForgroundColr;
        _tintColorForIcon = AppPrimaryClr;

        self.stack = [UIStackView new];
        self.stack.axis = UILayoutConstraintAxisHorizontal;
        self.stack.alignment = UIStackViewAlignmentFill;
        self.stack.distribution = UIStackViewDistributionFillEqually;
        self.stack.spacing = 12.0;
        self.stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.stack];

        [NSLayoutConstraint activateConstraints:@[
            [self.stack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)setActions:(NSArray<PPQuickActionItem *> *)actions {
    for (UIView *view in self.stack.arrangedSubviews) {
        [self.stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    if (actions.count == 0) {
        return;
    }

    if (actions.count == 3) {
        [self.stack addArrangedSubview:[self buildButtonFor:actions.firstObject featured:NO]];
        [self.stack addArrangedSubview:[self buildButtonFor:actions[1] featured:NO]];
        [self.stack addArrangedSubview:[self buildButtonFor:actions[2] featured:NO]];
       /*
        UIStackView *secondaryRow = [UIStackView new];
        secondaryRow.axis = UILayoutConstraintAxisHorizontal;
        secondaryRow.alignment = UIStackViewAlignmentFill;
        secondaryRow.distribution = UIStackViewDistributionFillEqually;
        secondaryRow.spacing = 10.0;
        secondaryRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        secondaryRow.translatesAutoresizingMaskIntoConstraints = NO;

        [secondaryRow addArrangedSubview:[self buildButtonFor:actions[1] featured:NO]];
        [secondaryRow addArrangedSubview:[self buildButtonFor:actions[2] featured:NO]];
        [self.stack addArrangedSubview:secondaryRow];
        */
        return;
    }

    if (actions.count == 2) {
        [self.stack addArrangedSubview:[self buildButtonFor:actions.firstObject featured:YES]];
        [self.stack addArrangedSubview:[self buildButtonFor:actions.lastObject featured:NO]];
        return;
    }

    NSMutableArray<PPQuickActionItem *> *mutableActions = actions.mutableCopy;
    while (mutableActions.count > 0) {
        NSRange rowRange = NSMakeRange(0, MIN(2, mutableActions.count));
        NSArray<PPQuickActionItem *> *rowItems = [mutableActions subarrayWithRange:rowRange];
        [mutableActions removeObjectsInRange:rowRange];

        UIStackView *rowStack = [UIStackView new];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.alignment = UIStackViewAlignmentFill;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = 10.0;
        rowStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        rowStack.translatesAutoresizingMaskIntoConstraints = NO;

        for (PPQuickActionItem *item in rowItems) {
            [rowStack addArrangedSubview:[self buildButtonFor:item featured:NO]];
        }

        if (rowItems.count == 1) {
            UIView *spacer = [[UIView alloc] init];
            spacer.backgroundColor = UIColor.clearColor;
            [rowStack addArrangedSubview:spacer];
        }

        [self.stack addArrangedSubview:rowStack];
    }
}

#pragma mark - Helpers

- (UIView *)buildButtonFor:(PPQuickActionItem *)item featured:(BOOL)featured {
    UIColor *accentColor = self.tintColorForIcon ?: [UIColor ppQuickActionServices];
    UIColor *surfaceColor = self.backgroundColorForButton ?: [UIColor ppElevatedSurface];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *neutralAccentSurface = [accentColor colorWithAlphaComponent:isDark ? 0.16 : 0.10];
    CGFloat resolvedHeight = featured ? MAX(self.buttonHeight, 92.0) : self.buttonHeight;
    CGFloat resolvedCornerRadius = MIN(MAX(self.cornerRadius, 20.0), 26.0);
    CGFloat iconShellSize = featured ? 34.0 : 34.0;
    CGFloat iconPointSize = featured ? 19.0 : 18.0;
    CGFloat titleFontSize = featured ? 15.5 : 14.5;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = PPIOS26() ? [AppForgroundColr colorWithAlphaComponent:0.82] : surfaceColor;
    button.layer.cornerRadius = resolvedCornerRadius;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [accentColor colorWithAlphaComponent:isDark ? 0.18 : 0.10].CGColor;
    button.layer.shadowColor = [accentColor colorWithAlphaComponent:isDark ? 0.45 : 0.28].CGColor;
    button.layer.shadowOpacity = featured ? 0.13 : 0.10;
    button.layer.shadowRadius = featured ? 18.0 : 14.0;
    button.layer.shadowOffset = CGSizeMake(0, featured ? 10.0 : 8.0);
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [button.heightAnchor constraintEqualToConstant:resolvedHeight].active = YES;

    UIView *accentWashView = [[UIView alloc] init];
    accentWashView.translatesAutoresizingMaskIntoConstraints = NO;
    accentWashView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:isDark ? 0.035 : 0.025];
    accentWashView.layer.cornerRadius = resolvedCornerRadius - 2.0;
    accentWashView.layer.cornerCurve = kCACornerCurveContinuous;
    accentWashView.userInteractionEnabled = NO;
    [button addSubview:accentWashView];

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = neutralAccentSurface;
    iconShell.layer.cornerRadius = (iconShellSize / 2.0) - 4;
    iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    iconShell.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    iconShell.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.04].CGColor;
    iconShell.userInteractionEnabled = NO;
    [button addSubview:iconShell];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:iconPointSize weight:UIImageSymbolWeightSemibold];
    UIImage *icon = [[UIImage systemImageNamed:item.iconName withConfiguration:config] ?: [UIImage imageNamed:item.iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;
    [iconShell addSubview:iconView];

    UIView *breathingDotCore = nil;
    UIView *breathingDot = nil;
    UILabel *badgeLabel = nil;

    if (item.badgeText.length > 0) {
        breathingDot = [self pp_breathingDotWithAccentColor:[UIColor ppError] coreView:&breathingDotCore badgeText:item.badgeText];
        [button addSubview:breathingDot];
    } else if (item.showsBreathingDot) {
        breathingDot = [self pp_breathingDotWithAccentColor:[UIColor ppSuccess] coreView:&breathingDotCore badgeText:nil];
        [button addSubview:breathingDot];
    }

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(item.titleKey);
    titleLabel.font = [Styling fontBold:titleFontSize];
    titleLabel.textColor = PrimaryTextClr;
    titleLabel.numberOfLines = 1;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    titleLabel.userInteractionEnabled = NO;
    [button addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentWashView.topAnchor constraintEqualToAnchor:button.topAnchor constant:1.0],
        [accentWashView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:1.0],
        [accentWashView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-1.0],
        [accentWashView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-1.0],

        [iconShell.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [iconShell.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:12.0],
        [iconShell.widthAnchor constraintEqualToConstant:iconShellSize],
        [iconShell.heightAnchor constraintEqualToConstant:iconShellSize],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:featured ? 21.0 : 19.0],
        [iconView.heightAnchor constraintEqualToConstant:featured ? 21.0 : 19.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-10.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [titleLabel.topAnchor constraintGreaterThanOrEqualToAnchor:button.topAnchor constant:10.0],
        [titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:button.bottomAnchor constant:-10.0],
    ]];

    if (breathingDot && breathingDotCore) {
        [NSLayoutConstraint activateConstraints:@[
            [breathingDot.centerXAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:-2.0],
            [breathingDot.centerYAnchor constraintEqualToAnchor:iconShell.topAnchor constant:2.0],
        ]];

        if (item.badgeText.length > 0) {
            [NSLayoutConstraint activateConstraints:@[
                [breathingDotCore.widthAnchor constraintGreaterThanOrEqualToConstant:22.0],
                [breathingDotCore.heightAnchor constraintEqualToConstant:22.0],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [breathingDot.widthAnchor constraintEqualToConstant:16.0],
                [breathingDot.heightAnchor constraintEqualToConstant:16.0],

                [breathingDotCore.widthAnchor constraintEqualToConstant:7.0],
                [breathingDotCore.heightAnchor constraintEqualToConstant:7.0],
            ]];
        }
        [self pp_startBreathingDotMotionForContainer:breathingDot core:breathingDotCore];
    }

    if (badgeLabel) {
        [NSLayoutConstraint activateConstraints:@[
            [badgeLabel.centerXAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:-2.0],
            [badgeLabel.centerYAnchor constraintEqualToAnchor:iconShell.topAnchor constant:2.0],
            [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:20.0],
            [badgeLabel.heightAnchor constraintEqualToConstant:20.0],
        ]];
    }

    [PPButtonHelper attachTapAnimationToButton:button style:PPButtonAnimationStyleDefault];
    button.accessibilityLabel = kLang(item.titleKey);
    if (item.handler) {
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            item.handler();
        }] forControlEvents:UIControlEventTouchUpInside];
    }

    return button;
}

- (UIView *)pp_breathingDotWithAccentColor:(UIColor *)accentColor coreView:(UIView * _Nullable * _Nullable)coreView badgeText:(NSString * _Nullable)badgeText {
    UIColor *signalColor = accentColor ?: AppPrimaryClr;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.userInteractionEnabled = NO;
    container.backgroundColor = UIColor.clearColor;
    container.layer.shadowColor = signalColor.CGColor;
    container.layer.shadowOpacity = isDark ? 0.24 : 0.14;
    container.layer.shadowRadius = 8.0;
    container.layer.shadowOffset = CGSizeZero;

    UIView *halo = [[UIView alloc] init];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.userInteractionEnabled = NO;
    halo.backgroundColor = [signalColor colorWithAlphaComponent:isDark ? 0.18 : 0.12];
    halo.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    halo.layer.borderColor = [signalColor colorWithAlphaComponent:isDark ? 0.26 : 0.18].CGColor;
    halo.tag = 6101;
    [container addSubview:halo];

    UIView *core = [[UIView alloc] init];
    core.translatesAutoresizingMaskIntoConstraints = NO;
    core.userInteractionEnabled = NO;
    core.backgroundColor = signalColor;
    core.layer.shadowColor = signalColor.CGColor;
    core.layer.shadowOpacity = isDark ? 0.34 : 0.22;
    core.layer.shadowRadius = 5.5;
    core.layer.shadowOffset = CGSizeZero;
    [container addSubview:core];

    UIView *innerSheen = [[UIView alloc] init];
    innerSheen.translatesAutoresizingMaskIntoConstraints = NO;
    innerSheen.userInteractionEnabled = NO;
    innerSheen.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:isDark ? 0.18 : 0.36];
    innerSheen.layer.cornerRadius = 2.0;
    innerSheen.layer.cornerCurve = kCACornerCurveContinuous;
    innerSheen.tag = 6102;
    [container addSubview:innerSheen];



    if (badgeText.length > 0) {
        core.layer.cornerRadius = 11.0;
        core.layer.cornerCurve = kCACornerCurveContinuous;

        halo.layer.cornerRadius = 16.0;
        halo.layer.cornerCurve = kCACornerCurveContinuous;

        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = badgeText;
        label.textColor = UIColor.whiteColor;
        label.font = [Styling fontBold:11.0];
        label.textAlignment = NSTextAlignmentCenter;
        label.userInteractionEnabled = NO;
        [core addSubview:label];

        [NSLayoutConstraint activateConstraints:@[
            [label.topAnchor constraintEqualToAnchor:core.topAnchor],
            [label.bottomAnchor constraintEqualToAnchor:core.bottomAnchor],
            [label.leadingAnchor constraintEqualToAnchor:core.leadingAnchor constant:6.0],
            [label.trailingAnchor constraintEqualToAnchor:core.trailingAnchor constant:-6.0],

            [halo.topAnchor constraintEqualToAnchor:core.topAnchor constant:-5.0],
            [halo.bottomAnchor constraintEqualToAnchor:core.bottomAnchor constant:5.0],
            [halo.leadingAnchor constraintEqualToAnchor:core.leadingAnchor constant:-5.0],
            [halo.trailingAnchor constraintEqualToAnchor:core.trailingAnchor constant:5.0],

            [container.topAnchor constraintEqualToAnchor:halo.topAnchor],
            [container.bottomAnchor constraintEqualToAnchor:halo.bottomAnchor],
            [container.leadingAnchor constraintEqualToAnchor:halo.leadingAnchor],
            [container.trailingAnchor constraintEqualToAnchor:halo.trailingAnchor],

            [innerSheen.widthAnchor constraintEqualToConstant:4.0],
            [innerSheen.heightAnchor constraintEqualToConstant:4.0],
            [innerSheen.leadingAnchor constraintEqualToAnchor:core.leadingAnchor constant:4.0],
            [innerSheen.topAnchor constraintEqualToAnchor:core.topAnchor constant:4.0],
        ]];
    } else {
        core.layer.cornerRadius = 3.25;
        core.layer.cornerCurve = kCACornerCurveContinuous;

        halo.layer.cornerRadius = 8.0;
        halo.layer.cornerCurve = kCACornerCurveContinuous;

        [NSLayoutConstraint activateConstraints:@[
            [halo.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [halo.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [halo.widthAnchor constraintEqualToConstant:16.0],
            [halo.heightAnchor constraintEqualToConstant:16.0],

            [container.topAnchor constraintEqualToAnchor:halo.topAnchor],
            [container.bottomAnchor constraintEqualToAnchor:halo.bottomAnchor],
            [container.leadingAnchor constraintEqualToAnchor:halo.leadingAnchor],
            [container.trailingAnchor constraintEqualToAnchor:halo.trailingAnchor],

            [innerSheen.widthAnchor constraintEqualToConstant:4.0],
            [innerSheen.heightAnchor constraintEqualToConstant:4.0],
            [innerSheen.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:5.0],
            [innerSheen.topAnchor constraintEqualToAnchor:container.topAnchor constant:5.0],
        ]];
    }

    if (coreView) {
        *coreView = core;
    }
    return container;
}

- (void)pp_startBreathingDotMotionForContainer:(UIView *)container core:(UIView *)core {
    UIView *halo = [container viewWithTag:6101] ?: container;
    UIView *innerSheen = [container viewWithTag:6102];

    [container.layer removeAnimationForKey:@"pp.quickAction.signal.container.depth"];
    [halo.layer removeAnimationForKey:@"pp.quickAction.signal.halo.scale"];
    [halo.layer removeAnimationForKey:@"pp.quickAction.signal.halo.opacity"];
    [core.layer removeAnimationForKey:@"pp.quickAction.signal.core.scale"];
    [core.layer removeAnimationForKey:@"pp.quickAction.signal.core.opacity"];
    [innerSheen.layer removeAnimationForKey:@"pp.quickAction.signal.sheen.opacity"];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        container.alpha = 1.0;
        halo.alpha = 0.72;
        core.alpha = 1.0;
        innerSheen.alpha = 0.86;
        container.transform = CGAffineTransformIdentity;
        halo.transform = CGAffineTransformIdentity;
        core.transform = CGAffineTransformIdentity;
        return;
    }

    CAMediaTimingFunction *premiumTiming = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :0.2 :1.0];

    CABasicAnimation *haloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    haloScale.fromValue = @0.84;
    haloScale.toValue = @1.18;
    haloScale.duration = 1.9;
    haloScale.autoreverses = YES;
    haloScale.repeatCount = HUGE_VALF;
    haloScale.timingFunction = premiumTiming;

    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @0.78;
    haloOpacity.toValue = @0.24;
    haloOpacity.duration = 1.9;
    haloOpacity.autoreverses = YES;
    haloOpacity.repeatCount = HUGE_VALF;
    haloOpacity.timingFunction = premiumTiming;

    CABasicAnimation *coreScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    coreScale.fromValue = @0.96;
    coreScale.toValue = @1.06;
    coreScale.duration = 1.9;
    coreScale.autoreverses = YES;
    coreScale.repeatCount = HUGE_VALF;
    coreScale.timingFunction = premiumTiming;
    coreScale.beginTime = CACurrentMediaTime() + 0.10;

    CABasicAnimation *coreOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    coreOpacity.fromValue = @0.86;
    coreOpacity.toValue = @1.0;
    coreOpacity.duration = 1.9;
    coreOpacity.autoreverses = YES;
    coreOpacity.repeatCount = HUGE_VALF;
    coreOpacity.timingFunction = premiumTiming;
    coreOpacity.beginTime = coreScale.beginTime;

    CABasicAnimation *depthPulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    depthPulse.fromValue = @0.10;
    depthPulse.toValue = @0.24;
    depthPulse.duration = 1.9;
    depthPulse.autoreverses = YES;
    depthPulse.repeatCount = HUGE_VALF;
    depthPulse.timingFunction = premiumTiming;

    CABasicAnimation *sheenOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    sheenOpacity.fromValue = @0.22;
    sheenOpacity.toValue = @0.82;
    sheenOpacity.duration = 1.9;
    sheenOpacity.autoreverses = YES;
    sheenOpacity.repeatCount = HUGE_VALF;
    sheenOpacity.timingFunction = premiumTiming;
    sheenOpacity.beginTime = CACurrentMediaTime() + 0.16;

    [container.layer addAnimation:depthPulse forKey:@"pp.quickAction.signal.container.depth"];
    [halo.layer addAnimation:haloScale forKey:@"pp.quickAction.signal.halo.scale"];
    [halo.layer addAnimation:haloOpacity forKey:@"pp.quickAction.signal.halo.opacity"];
    [core.layer addAnimation:coreScale forKey:@"pp.quickAction.signal.core.scale"];
    [core.layer addAnimation:coreOpacity forKey:@"pp.quickAction.signal.core.opacity"];
    [innerSheen.layer addAnimation:sheenOpacity forKey:@"pp.quickAction.signal.sheen.opacity"];
}

@end
