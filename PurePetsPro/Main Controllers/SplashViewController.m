//
//  SplashViewController.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 29/08/2025.
//

#import "SplashViewController.h"

@interface SplashViewController ()
// — Logo plate —
@property (nonatomic, strong) UIView              *logoPlate;
@property (nonatomic, strong) UIVisualEffectView  *logoBlurView;
@property (nonatomic, strong) UIImageView         *logoImageView;
@property (nonatomic, strong) UIImageView         *bgImageView;
// — Title + subtitle —
@property (nonatomic, strong) UILabel             *titleLabel;
@property (nonatomic, strong) UIView              *subtitleClipView;
@property (nonatomic, strong) UILabel             *subtitleLabel;

// — Loading card —
@property (nonatomic, strong) UIView              *loadingCard;
@property (nonatomic, strong) UIVisualEffectView  *loadingBlurView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel             *loadingLabel;

// — Background circles —
@property (nonatomic, strong) UIView              *bgCircle1;
@property (nonatomic, strong) UIView              *bgCircle2;
@property (nonatomic, strong) UIView              *bgCircle3;

@property (nonatomic, assign) BOOL                animationsStarted;
@end

@implementation SplashViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.animationsStarted = NO;
    [self pp_buildInterface];
    [self pp_applyTheme];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.animationsStarted) {
        self.animationsStarted = YES;
        [self pp_startAnimations];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyTheme];
    }
}

#pragma mark - Build Interface

- (void)pp_buildInterface {
    self.view.clipsToBounds = YES;

    self.bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bglunch"]];
    self.bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:self.bgImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bgImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.bgImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bgImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bgImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
    
    
    // ── Background circles (behind everything) ──
    CGFloat sizes[] = {220, 160, 130};
    UIView *circles[3];
    for (int i = 0; i < 3; i++) {
        UIView *c = [[UIView alloc] init];
        c.translatesAutoresizingMaskIntoConstraints = NO;
        c.alpha = 0;
        c.layer.cornerRadius = sizes[i] / 2.0;
        [self.view addSubview:c];
        [NSLayoutConstraint activateConstraints:@[
            [c.widthAnchor constraintEqualToConstant:sizes[i]],
            [c.heightAnchor constraintEqualToConstant:sizes[i]],
        ]];
        circles[i] = c;
    }
    self.bgCircle1 = circles[0];
    self.bgCircle2 = circles[1];
    self.bgCircle3 = circles[2];

    // Circle positions — scattered around
    [NSLayoutConstraint activateConstraints:@[
        [self.bgCircle1.centerXAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:60],
        [self.bgCircle1.centerYAnchor constraintEqualToAnchor:self.view.topAnchor constant:180],
        [self.bgCircle2.centerXAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.bgCircle2.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:80],
        [self.bgCircle3.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-30],
        [self.bgCircle3.centerYAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-140],
    ]];

    // ── Logo plate (glass container) ──
    self.logoPlate = [[UIView alloc] init];
    self.logoPlate.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoPlate.layer.cornerRadius = 32;
    self.logoPlate.layer.cornerCurve = kCACornerCurveContinuous;
    self.logoPlate.clipsToBounds = YES;
    [self.view addSubview:self.logoPlate];

    // Blur backing
    UIBlurEffect *plateBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.logoBlurView = [[UIVisualEffectView alloc] initWithEffect:plateBlur];
    self.logoBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.logoPlate addSubview:self.logoBlurView];
    [NSLayoutConstraint activateConstraints:@[
        [self.logoBlurView.topAnchor constraintEqualToAnchor:self.logoPlate.topAnchor],
        [self.logoBlurView.leadingAnchor constraintEqualToAnchor:self.logoPlate.leadingAnchor],
        [self.logoBlurView.trailingAnchor constraintEqualToAnchor:self.logoPlate.trailingAnchor],
        [self.logoBlurView.bottomAnchor constraintEqualToAnchor:self.logoPlate.bottomAnchor],
    ]];

    // Logo image
    self.logoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AD_LOGO"]];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.logoPlate addSubview:self.logoImageView];

    CGFloat logoSize = 80;
    [NSLayoutConstraint activateConstraints:@[
        [self.logoPlate.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoPlate.widthAnchor constraintEqualToConstant:logoSize + 40],
        [self.logoPlate.heightAnchor constraintEqualToConstant:logoSize + 40],
        [self.logoImageView.centerXAnchor constraintEqualToAnchor:self.logoPlate.centerXAnchor],
        [self.logoImageView.centerYAnchor constraintEqualToAnchor:self.logoPlate.centerYAnchor],
        [self.logoImageView.widthAnchor constraintEqualToConstant:logoSize],
        [self.logoImageView.heightAnchor constraintEqualToConstant:logoSize],
    ]];

    // ── Title ──
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"Pure Pets";
    self.titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.logoPlate.bottomAnchor constant:16],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
    ]];

    // Logo plate vertical center offset upward
    NSLayoutConstraint *plateY = [self.logoPlate.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-60];
    plateY.active = YES;

    // ── Subtitle clip view (masks text scrolling behind title) ──
    self.subtitleClipView = [[UIView alloc] init];
    self.subtitleClipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleClipView.clipsToBounds = YES;
    [self.view addSubview:self.subtitleClipView];

    [NSLayoutConstraint activateConstraints:@[
        [self.subtitleClipView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.subtitleClipView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.subtitleClipView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.subtitleClipView.heightAnchor constraintEqualToConstant:36],
    ]];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.text = @"Professional Management";
    self.subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.alpha = 0.7;
    [self.subtitleClipView addSubview:self.subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.subtitleLabel.centerXAnchor constraintEqualToAnchor:self.subtitleClipView.centerXAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.subtitleClipView.topAnchor constant:36],
        [self.subtitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.subtitleClipView.leadingAnchor],
    ]];

    // ── Loading card (glass container) ──
    self.loadingCard = [[UIView alloc] init];
    self.loadingCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingCard.layer.cornerRadius = 20;
    self.loadingCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.loadingCard.clipsToBounds = YES;
    [self.view addSubview:self.loadingCard];

    // Blur backing
    UIBlurEffect *cardBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.loadingBlurView = [[UIVisualEffectView alloc] initWithEffect:cardBlur];
    self.loadingBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loadingCard addSubview:self.loadingBlurView];
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingBlurView.topAnchor constraintEqualToAnchor:self.loadingCard.topAnchor],
        [self.loadingBlurView.leadingAnchor constraintEqualToAnchor:self.loadingCard.leadingAnchor],
        [self.loadingBlurView.trailingAnchor constraintEqualToAnchor:self.loadingCard.trailingAnchor],
        [self.loadingBlurView.bottomAnchor constraintEqualToAnchor:self.loadingCard.bottomAnchor],
    ]];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loadingCard addSubview:self.spinner];
    [self.spinner startAnimating];

    // Loading text
    self.loadingLabel = [[UILabel alloc] init];
    self.loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingLabel.text = @"Loading…";
    self.loadingLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.loadingLabel.alpha = 0.6;
    [self.loadingCard addSubview:self.loadingLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingCard.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingCard.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-40],
        [self.loadingCard.widthAnchor constraintGreaterThanOrEqualToConstant:140],
        [self.loadingCard.heightAnchor constraintEqualToConstant:44],
        [self.spinner.leadingAnchor constraintEqualToAnchor:self.loadingCard.leadingAnchor constant:16],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.loadingCard.centerYAnchor],
        [self.loadingLabel.leadingAnchor constraintEqualToAnchor:self.spinner.trailingAnchor constant:8],
        [self.loadingLabel.centerYAnchor constraintEqualToAnchor:self.loadingCard.centerYAnchor],
        [self.loadingLabel.trailingAnchor constraintEqualToAnchor:self.loadingCard.trailingAnchor constant:-16],
    ]];
}

#pragma mark - Theme

- (void)pp_applyTheme {
    UIColor *bg = AppBackgroundClr;
    UIColor *secColor = [UIColor colorNamed:@"AppSecColor"];
    UIColor *primary = AppPrimaryClr;
    UIColor *textClr = PrimaryTextClr;

    self.view.backgroundColor = bg;

    // Circles — AppSecColor with low alpha
    UIColor *circleFill = secColor ? [secColor colorWithAlphaComponent:0.12]
                                   : [primary colorWithAlphaComponent:0.10];
    self.bgCircle1.backgroundColor = circleFill;
    self.bgCircle2.backgroundColor = secColor ? [secColor colorWithAlphaComponent:0.08]
                                               : [primary colorWithAlphaComponent:0.07];
    self.bgCircle3.backgroundColor = circleFill;

    // Logo plate — glass tint
    UIColor *glassTint = secColor ? [secColor colorWithAlphaComponent:0.06]
                                  : [primary colorWithAlphaComponent:0.05];
    self.logoPlate.backgroundColor = glassTint;
    self.logoPlate.layer.borderWidth = 0.5;
    self.logoPlate.layer.borderColor = [textClr colorWithAlphaComponent:0.08].CGColor;

    // Title + subtitle
    self.titleLabel.textColor = textClr;
    self.subtitleLabel.textColor = [textClr colorWithAlphaComponent:0.5];

    // Loading card — glass tint
    self.loadingCard.backgroundColor = glassTint;
    self.loadingCard.layer.borderWidth = 0.5;
    self.loadingCard.layer.borderColor = [textClr colorWithAlphaComponent:0.08].CGColor;
    self.spinner.color = secColor ?: primary;
    self.loadingLabel.textColor = [textClr colorWithAlphaComponent:0.6];
}

#pragma mark - Animations

- (void)pp_startAnimations {
    // ── 1. Circles fade in staggered ──
    NSArray<UIView *> *circles = @[self.bgCircle1, self.bgCircle2, self.bgCircle3];
    for (NSUInteger i = 0; i < circles.count; i++) {
        UIView *c = circles[i];
        c.transform = CGAffineTransformMakeScale(0.6, 0.6);
        [UIView animateWithDuration:1.2
                              delay:0.3 * i
             usingSpringWithDamping:0.7
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            c.alpha = 1.0;
            c.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    // ── 2. Circle breathing / drift (infinite) ──
    [self pp_animateCircleDrift:self.bgCircle1 dx:12 dy:-8  dur:6.0];
    [self pp_animateCircleDrift:self.bgCircle2 dx:-10 dy:14 dur:7.5];
    [self pp_animateCircleDrift:self.bgCircle3 dx:8  dy:10  dur:8.0];

    [self pp_animateCircleScale:self.bgCircle1 dur:5.0];
    [self pp_animateCircleScale:self.bgCircle2 dur:6.5];
    [self pp_animateCircleScale:self.bgCircle3 dur:7.0];

    // ── 3. Logo pulse ──
    [UIView animateWithDuration:2.0
                          delay:0
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.logoImageView.transform = CGAffineTransformMakeScale(1.04, 1.04);
    } completion:nil];

    // ── 4. Subtitle scroll up (starts below clip → goes above = behind title) ──
    [self pp_animateSubtitleScroll];
}

- (void)pp_animateCircleDrift:(UIView *)circle dx:(CGFloat)dx dy:(CGFloat)dy dur:(NSTimeInterval)dur {
    [UIView animateWithDuration:dur
                          delay:0
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        circle.transform = CGAffineTransformMakeTranslation(dx, dy);
    } completion:nil];
}

- (void)pp_animateCircleScale:(UIView *)circle dur:(NSTimeInterval)dur {
    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @1.0;
    scale.toValue = @1.12;
    scale.duration = dur;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [circle.layer addAnimation:scale forKey:@"breathe"];
}

- (void)pp_animateSubtitleScroll {
    // Reset to below the clip
    self.subtitleLabel.transform = CGAffineTransformMakeTranslation(0, 36);
    self.subtitleLabel.alpha = 0;

    // Phase 1: fade in + scroll to center
    [UIView animateWithDuration:1.5
                          delay:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.subtitleLabel.transform = CGAffineTransformMakeTranslation(0, -2);
        self.subtitleLabel.alpha = 0.7;
    } completion:^(BOOL finished) {
        if (!finished) return;
        // Phase 2: hold 2s then scroll up behind title
        [UIView animateWithDuration:2.0
                              delay:2.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.subtitleLabel.transform = CGAffineTransformMakeTranslation(0, -44);
            self.subtitleLabel.alpha = 0;
        } completion:^(BOOL f2) {
            if (f2) [self pp_animateSubtitleScroll]; // loop
        }];
    }];
}

@end
