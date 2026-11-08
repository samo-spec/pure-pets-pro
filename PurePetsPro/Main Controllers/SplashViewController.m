//
//  SplashViewController.m
//  PurePetsPro
//
//  NextGen V7 — Precision Ignition Splash
//  Reinvented from first principles to embody Pro identity:
//  architectural carrier, orbital readiness ring, phase-responsive
//  atmosphere, purposeful causal motion. Every animation communicates
//  system state — nothing decorative.
//
//  Preserved contracts: PPSplashLoadingPhase enum, kLang() keys,
//  SceneDelegate integration ([SplashViewController new]), design tokens,
//  RTL/LTR, Reduce Motion, dark mode, increased contrast, lifecycle.
//

#import "SplashViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "PPDesignTokens.h"
#import "Styling.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"

typedef NS_ENUM(NSInteger, PPSplashLoadingPhase) {
    PPSplashLoadingPhaseBootstrapping = 0,
    PPSplashLoadingPhasePreparingContent,
    PPSplashLoadingPhaseReady
};

#pragma mark - Color Helpers

static UIColor *PPSplashBlendColor(UIColor *c1, UIColor *c2, CGFloat factor) {
    if (!c1) return c2 ?: UIColor.clearColor;
    if (!c2) return c1;
    CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 0;
    CGFloat r2 = 0, g2 = 0, b2 = 0, a2 = 0;
    if (![c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1]) return c1;
    if (![c2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) return c1;
    CGFloat f = MIN(MAX(factor, 0.0), 1.0);
    return [UIColor colorWithRed:r1 + (r2 - r1) * f
                           green:g1 + (g2 - g1) * f
                            blue:b1 + (b2 - b1) * f
                           alpha:a1 + (a2 - a1) * f];
}

#pragma mark - Carrier Geometry Constants

/// Adaptive squircle carrier dimensions
static const CGFloat PPCarrierSideRegular   = 132.0;
static const CGFloat PPCarrierSideCompact   = 118.0;
static const CGFloat PPCarrierSideAccessibility = 104.0;

/// Continuous corner radius for the Apple squircle
static const CGFloat PPCarrierCornerRadius  = 30.0;

/// Logo optical size inside carrier
static const CGFloat PPLogoSideRegular      = 78.0;
static const CGFloat PPLogoSideCompact      = 68.0;

/// Orbital readiness ring
static const CGFloat PPRingGap              = 14.0;   // carrier edge → ring
static const CGFloat PPRingTrackWidth       = 2.0;
static const CGFloat PPRingProgressWidth    = 3.0;
static const CGFloat PPRingHighContrastTrackWidth    = 3.0;
static const CGFloat PPRingHighContrastProgressWidth = 4.5;
static const CGFloat PPRingSegmentGapAngle  = 0.10;   // ~5.7° gap between segments

/// Phase count
static const NSInteger PPSplashPhaseCount   = 3;

#pragma mark - PPProCarrierView

/// Central brand carrier: precision squircle + logo + orbital readiness ring.
/// Three arc segments indicate bootstrap → content → ready phases.
@interface PPProCarrierView : UIView

@property (nonatomic, strong) CAGradientLayer *haloLayer;
@property (nonatomic, strong) UIView *plateView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *ringTrackLayers;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *ringProgressLayers;

@property (nonatomic, assign) NSInteger activePhaseCount;
@property (nonatomic, assign, getter=isReady) BOOL ready;
@property (nonatomic, assign) BOOL didPlayEntrance;

- (void)setActivePhaseCount:(NSInteger)count animated:(BOOL)animated;
- (void)setReady:(BOOL)ready animated:(BOOL)animated;
- (void)playEntrance;
- (void)resumeAmbientMotionIfAllowed;
- (void)stopMotion;
- (void)settleForSnapshot;
- (void)pp_applyTheme;

@end

@implementation PPProCarrierView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self pp_commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self pp_commonInit];
    return self;
}

- (void)pp_commonInit {
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;

    // 1. Radial halo — brand presence behind carrier
    CAGradientLayer *haloLayer = [CAGradientLayer layer];
    if (@available(iOS 12.0, *)) {
        haloLayer.type = kCAGradientLayerRadial;
    }
    haloLayer.startPoint = CGPointMake(0.5, 0.5);
    haloLayer.endPoint   = CGPointMake(1.0, 1.0);
    haloLayer.locations   = @[@0.0, @0.42, @1.0];
    haloLayer.opacity     = 0.0f;
    [self.layer addSublayer:haloLayer];
    self.haloLayer = haloLayer;

    // 2. Carrier plate — precision squircle container
    //    masksToBounds is NO so the shadow renders; cornerRadius still
    //    rounds the layer's own background and border without clipping.
    UIView *plateView = [[UIView alloc] init];
    plateView.backgroundColor = UIColor.clearColor;
    plateView.layer.cornerRadius = PPCarrierCornerRadius;
    if (@available(iOS 13.0, *)) {
        plateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    plateView.layer.masksToBounds = NO;
    plateView.layer.borderWidth = 0.5;
    plateView.userInteractionEnabled = NO;
    plateView.accessibilityElementsHidden = YES;
    plateView.alpha = 0.0;
    [self addSubview:plateView];
    self.plateView = plateView;

    // 3. Brand mark — AD_LOGO
    UIImage *brandImage = [[UIImage imageNamed:@"AD_LOGO"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!brandImage) {
        brandImage = [[UIImage imageNamed:@"ProV8"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:brandImage];
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    logoImageView.userInteractionEnabled = NO;
    logoImageView.accessibilityElementsHidden = YES;
    logoImageView.accessibilityIgnoresInvertColors = YES;
    logoImageView.alpha = 0.0;
    [self addSubview:logoImageView];
    self.logoImageView = logoImageView;

    // 4. Orbital readiness ring — 3 arc segments (track + progress each)
    NSMutableArray<CAShapeLayer *> *tracks = [NSMutableArray arrayWithCapacity:PPSplashPhaseCount];
    NSMutableArray<CAShapeLayer *> *progresses = [NSMutableArray arrayWithCapacity:PPSplashPhaseCount];

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        CAShapeLayer *track = [CAShapeLayer layer];
        track.fillColor   = UIColor.clearColor.CGColor;
        track.lineCap     = kCALineCapRound;
        track.opacity     = 0.0f;
        [self.layer addSublayer:track];
        [tracks addObject:track];

        CAShapeLayer *progress = [CAShapeLayer layer];
        progress.fillColor   = UIColor.clearColor.CGColor;
        progress.lineCap     = kCALineCapRound;
        progress.strokeEnd   = 0.0;
        progress.opacity     = 0.0f;
        [self.layer addSublayer:progress];
        [progresses addObject:progress];
    }
    self.ringTrackLayers    = tracks.copy;
    self.ringProgressLayers = progresses.copy;

    _activePhaseCount = 0;
    [self setActivePhaseCount:1 animated:NO];
    [self pp_applyTheme];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat viewW = CGRectGetWidth(self.bounds);
    CGFloat viewH = CGRectGetHeight(self.bounds);
    if (viewW < 1.0 || viewH < 1.0) return;

    CGFloat side   = MIN(viewW, viewH);
    CGPoint center = CGPointMake(viewW * 0.5, viewH * 0.5);

    // Halo fills the full view
    self.haloLayer.frame = self.bounds;
    self.haloLayer.cornerRadius = side * 0.5;

    // Derive carrier plate size from view bounds (set by constraints)
    // View total = carrierSide + 2*(ringGap + maxStrokeWidth)
    CGFloat maxStroke   = MAX(PPRingProgressWidth, PPRingHighContrastProgressWidth);
    CGFloat carrierSide = side - 2.0 * (PPRingGap + maxStroke);
    carrierSide = MAX(carrierSide, 60.0);

    CGRect plateFrame = CGRectMake(center.x - carrierSide * 0.5,
                                   center.y - carrierSide * 0.5,
                                   carrierSide, carrierSide);
    self.plateView.frame = plateFrame;
    CGFloat scaledCorner = PPCarrierCornerRadius * (carrierSide / PPCarrierSideRegular);
    self.plateView.layer.cornerRadius = scaledCorner;

    // Shadow path — must be set here where bounds are valid
    self.plateView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.plateView.bounds
                                                                cornerRadius:scaledCorner].CGPath;

    // Logo — centered inside carrier
    CGFloat logoSide = (carrierSide >= PPCarrierSideRegular) ? PPLogoSideRegular : PPLogoSideCompact;
    self.logoImageView.frame = CGRectMake(center.x - logoSide * 0.5,
                                          center.y - logoSide * 0.5,
                                          logoSide, logoSide);

    // Ring geometry — 3 arc segments around carrier
    BOOL wasAnimating = [self.haloLayer animationForKey:@"pp.halo.breathe"] != nil;
    CGFloat ringRadius   = carrierSide * 0.5 + PPRingGap;
    CGFloat segmentAngle = (2.0 * M_PI - PPSplashPhaseCount * PPRingSegmentGapAngle) / (CGFloat)PPSplashPhaseCount;

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        CGFloat startAngle = -M_PI_2 + (CGFloat)i * (segmentAngle + PPRingSegmentGapAngle);
        CGFloat endAngle   = startAngle + segmentAngle;

        UIBezierPath *arcPath = [UIBezierPath bezierPathWithArcCenter:center
                                                               radius:ringRadius
                                                           startAngle:startAngle
                                                             endAngle:endAngle
                                                            clockwise:YES];

        CAShapeLayer *track = self.ringTrackLayers[i];
        track.frame = self.bounds;
        track.path  = arcPath.CGPath;

        CAShapeLayer *progress = self.ringProgressLayers[i];
        progress.frame = self.bounds;
        progress.path  = arcPath.CGPath;
    }

    if (wasAnimating) {
        [self resumeAmbientMotionIfAllowed];
    }
}

#pragma mark - Phase progression

- (void)setActivePhaseCount:(NSInteger)count animated:(BOOL)animated {
    NSInteger clamped = MIN(MAX(count, 1), PPSplashPhaseCount);
    NSInteger previous = _activePhaseCount;
    _activePhaseCount = clamped;

    BOOL shouldAnimate = animated && self.didPlayEntrance && !UIAccessibilityIsReduceMotionEnabled();

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        CAShapeLayer *progress = self.ringProgressLayers[i];
        CGFloat target = (i < clamped) ? 1.0 : 0.0;
        CGFloat fromValue = progress.presentationLayer
            ? ((CAShapeLayer *)progress.presentationLayer).strokeEnd
            : progress.strokeEnd;
        progress.strokeEnd = target;
        progress.opacity   = 1.0f;

        if (shouldAnimate && target > fromValue && i >= previous) {
            CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            draw.fromValue = @(fromValue);
            draw.toValue   = @(target);
            draw.duration  = 0.28;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
            [progress addAnimation:draw forKey:@"pp.ring.draw"];
        }
    }

    [CATransaction commit];
    [self pp_applyTheme];
}

- (void)setReady:(BOOL)ready animated:(BOOL)animated {
    BOOL didBecomeReady = !_ready && ready;
    _ready = ready;
    [self pp_applyTheme];

    if (!didBecomeReady) return;

    // Intensify halo on ready
    CALayer *presentation = self.haloLayer.presentationLayer;
    CGFloat currentOpacity = presentation ? presentation.opacity : self.haloLayer.opacity;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.haloLayer.opacity = 0.68f;
    [CATransaction commit];

    if (!animated || UIAccessibilityIsReduceMotionEnabled() || currentOpacity >= 0.66f) return;

    CABasicAnimation *intensify = [CABasicAnimation animationWithKeyPath:@"opacity"];
    intensify.fromValue = @(currentOpacity);
    intensify.toValue   = @0.68;
    intensify.duration  = 0.24;
    intensify.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.haloLayer addAnimation:intensify forKey:@"pp.halo.intensify"];

    // Gold gleam: flash ring segments to premium accent and back
    UIColor *goldColor = [UIColor ppPremiumAccent];
    UIColor *brandColor = [UIColor ppPrimary];

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        CAShapeLayer *progress = self.ringProgressLayers[i];

        CAKeyframeAnimation *gleam = [CAKeyframeAnimation animationWithKeyPath:@"strokeColor"];
        gleam.values = @[
            (id)progress.strokeColor,
            (id)goldColor.CGColor,
            (id)goldColor.CGColor,
            (id)brandColor.CGColor
        ];
        gleam.keyTimes = @[@0.0, @0.25, @0.55, @1.0];
        gleam.duration = 0.72;
        gleam.beginTime = CACurrentMediaTime() + 0.12 + (CFTimeInterval)i * 0.04;
        gleam.fillMode = kCAFillModeBackwards;
        gleam.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [progress addAnimation:gleam forKey:@"pp.ring.gleam"];
    }
}

#pragma mark - Entrance

- (void)playEntrance {
    if (self.didPlayEntrance) return;
    self.didPlayEntrance = YES;
    [self layoutIfNeeded];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.haloLayer.opacity = self.isReady ? 0.68f : 0.48f;
        self.plateView.alpha   = 1.0;
        self.plateView.transform = CGAffineTransformIdentity;
        self.logoImageView.alpha = 1.0;
        self.logoImageView.transform = CGAffineTransformIdentity;
        for (CAShapeLayer *t in self.ringTrackLayers)    t.opacity = 1.0f;
        for (CAShapeLayer *p in self.ringProgressLayers) p.opacity = 1.0f;
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();

    // Halo fade-in
    self.haloLayer.opacity = self.isReady ? 0.68f : 0.48f;
    CABasicAnimation *haloFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloFade.fromValue = @0.0;
    haloFade.toValue   = @(self.haloLayer.opacity);
    haloFade.duration  = 0.26;
    haloFade.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.haloLayer addAnimation:haloFade forKey:@"pp.halo.entrance"];

    // Carrier plate — scale from 0.88 + fade
    self.plateView.alpha = 1.0;
    self.plateView.transform = CGAffineTransformIdentity;

    CABasicAnimation *plateScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    plateScale.fromValue = @0.88;
    plateScale.toValue   = @1.0;
    plateScale.duration  = 0.42;
    plateScale.beginTime = now + 0.02;
    plateScale.fillMode  = kCAFillModeBackwards;
    plateScale.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.plateView.layer addAnimation:plateScale forKey:@"pp.plate.scale"];

    CABasicAnimation *plateFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    plateFade.fromValue = @0.0;
    plateFade.toValue   = @1.0;
    plateFade.duration  = 0.22;
    plateFade.beginTime = now + 0.02;
    plateFade.fillMode  = kCAFillModeBackwards;
    plateFade.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.plateView.layer addAnimation:plateFade forKey:@"pp.plate.fade"];

    // Logo — slight scale from 0.90 + fade, staggered
    self.logoImageView.alpha = 1.0;
    self.logoImageView.transform = CGAffineTransformIdentity;

    CABasicAnimation *logoScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    logoScale.fromValue = @0.90;
    logoScale.toValue   = @1.0;
    logoScale.duration  = 0.38;
    logoScale.beginTime = now + 0.06;
    logoScale.fillMode  = kCAFillModeBackwards;
    logoScale.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.logoImageView.layer addAnimation:logoScale forKey:@"pp.logo.scale"];

    CABasicAnimation *logoFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    logoFade.fromValue = @0.0;
    logoFade.toValue   = @1.0;
    logoFade.duration  = 0.20;
    logoFade.beginTime = now + 0.06;
    logoFade.fillMode  = kCAFillModeBackwards;
    logoFade.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
    [self.logoImageView.layer addAnimation:logoFade forKey:@"pp.logo.fade"];

    // Ring tracks fade in, staggered
    [self.ringTrackLayers enumerateObjectsUsingBlock:^(CAShapeLayer *track, NSUInteger idx, BOOL *stop) {
        track.opacity = 1.0f;
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @0.0;
        fade.toValue   = @1.0;
        fade.beginTime = now + 0.08 + (CFTimeInterval)idx * 0.025;
        fade.duration  = 0.18;
        fade.fillMode  = kCAFillModeBackwards;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [track addAnimation:fade forKey:@"pp.track.entrance"];

        // First segment draws on entrance
        CAShapeLayer *progress = self.ringProgressLayers[idx];
        progress.opacity = 1.0f;
        if ((NSInteger)idx < self.activePhaseCount) {
            CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            draw.fromValue = @0.0;
            draw.toValue   = @(progress.strokeEnd);
            draw.beginTime = now + 0.10 + (CFTimeInterval)idx * 0.03;
            draw.duration  = 0.28;
            draw.fillMode  = kCAFillModeBackwards;
            draw.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.23 :1.0 :0.32 :1.0];
            [progress addAnimation:draw forKey:@"pp.ring.entrance.draw"];
        }
    }];

    [self resumeAmbientMotionIfAllowed];
}

#pragma mark - Ambient Motion

- (void)resumeAmbientMotionIfAllowed {
    if (!self.didPlayEntrance || UIAccessibilityIsReduceMotionEnabled() || !self.window ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    if (processInfo.isLowPowerModeEnabled) return;
    if (@available(iOS 11.0, *)) {
        if (processInfo.thermalState >= NSProcessInfoThermalStateSerious) return;
    }

    // Subtle halo pulse — barely perceptible "alive" signal
    if (![self.haloLayer animationForKey:@"pp.halo.breathe"]) {
        CGFloat baseOpacity = self.isReady ? 0.68f : 0.48f;
        CAKeyframeAnimation *haloBreathe = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        haloBreathe.values   = @[@(baseOpacity), @(baseOpacity + 0.08), @(baseOpacity)];
        haloBreathe.keyTimes = @[@0.0, @0.5, @1.0];
        haloBreathe.duration = 3.6;
        haloBreathe.repeatCount = HUGE_VALF;
        haloBreathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        haloBreathe.removedOnCompletion = NO;
        [self.haloLayer addAnimation:haloBreathe forKey:@"pp.halo.breathe"];
    }

    // Carrier plate micro-scale pulse — 0.5% scale oscillation
    if (![self.plateView.layer animationForKey:@"pp.plate.breathe"]) {
        CAKeyframeAnimation *plateBreathe = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        plateBreathe.values   = @[@1.0, @1.006, @1.0];
        plateBreathe.keyTimes = @[@0.0, @0.5, @1.0];
        plateBreathe.duration = 3.2;
        plateBreathe.repeatCount = HUGE_VALF;
        plateBreathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        plateBreathe.removedOnCompletion = NO;
        [self.plateView.layer addAnimation:plateBreathe forKey:@"pp.plate.breathe"];
    }
}

- (void)stopMotion {
    [self.haloLayer removeAllAnimations];
    [self.plateView.layer removeAllAnimations];
    [self.logoImageView.layer removeAllAnimations];
    for (CAShapeLayer *t in self.ringTrackLayers)    [t removeAllAnimations];
    for (CAShapeLayer *p in self.ringProgressLayers) [p removeAllAnimations];
}

- (void)settleForSnapshot {
    [self stopMotion];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.haloLayer.opacity = self.isReady ? 0.68f : 0.48f;
    self.plateView.alpha   = 1.0;
    self.plateView.transform = CGAffineTransformIdentity;
    self.logoImageView.alpha = 1.0;
    self.logoImageView.transform = CGAffineTransformIdentity;

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        self.ringTrackLayers[i].opacity = 1.0f;
        CAShapeLayer *progress = self.ringProgressLayers[i];
        progress.opacity   = 1.0f;
        progress.strokeEnd = (i < self.activePhaseCount) ? 1.0 : 0.0;
    }
    [CATransaction commit];
}

#pragma mark - Theme

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (!previousTraitCollection ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection] ||
        self.traitCollection.accessibilityContrast != previousTraitCollection.accessibilityContrast) {
        [self pp_applyTheme];
    }
}

- (void)pp_applyTheme {
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    BOOL highContrast = (self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh);

    UIColor *brandColor     = [UIColor ppPrimary];
    UIColor *accentText     = [UIColor ppAccentText];
    UIColor *premiumColor   = [UIColor ppPremiumAccent];
    UIColor *surfaceColor   = [UIColor ppSurface];
    UIColor *borderColor    = [UIColor ppSurfaceBorder];
    UIColor *secondaryText  = [UIColor ppTextSecondary];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    // Halo gradient — brand-tinted radial glow
    UIColor *haloColor = isDark ? (accentText ?: brandColor) : brandColor;
    CGFloat centerAlpha = highContrast ? (isDark ? 0.24 : 0.14) : (isDark ? 0.16 : 0.09);
    self.haloLayer.colors = @[
        (id)[haloColor colorWithAlphaComponent:centerAlpha].CGColor,
        (id)[haloColor colorWithAlphaComponent:centerAlpha * 0.3].CGColor,
        (id)UIColor.clearColor.CGColor
    ];

    // Carrier plate surface + border
    self.plateView.backgroundColor  = surfaceColor;
    self.plateView.layer.borderColor = borderColor.CGColor;

    // Plate shadow — depth cue
    self.plateView.layer.masksToBounds = NO;
    self.plateView.layer.shadowColor   = [UIColor ppShadow].CGColor;
    self.plateView.layer.shadowOffset  = CGSizeMake(0, isDark ? 2.0 : 1.5);
    self.plateView.layer.shadowRadius  = isDark ? 10.0 : 7.0;
    self.plateView.layer.shadowOpacity = isDark ? (highContrast ? 0.32 : 0.22) : (highContrast ? 0.10 : 0.06);
    self.plateView.layer.shadowPath    = [UIBezierPath bezierPathWithRoundedRect:self.plateView.bounds
                                                                   cornerRadius:self.plateView.layer.cornerRadius].CGPath;
    // Re-enable clipping for content while keeping shadow visible
    // (shadow is drawn by the layer itself; content clips via sublayer masking)

    // Ring track — dim architectural guide
    UIColor *trackColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:highContrast ? 0.28 : 0.12]
        : [secondaryText colorWithAlphaComponent:highContrast ? 0.70 : 0.22];

    CGFloat trackW    = highContrast ? PPRingHighContrastTrackWidth : PPRingTrackWidth;
    CGFloat progressW = highContrast ? PPRingHighContrastProgressWidth : PPRingProgressWidth;

    UIColor *ringBrandColor = isDark ? (accentText ?: brandColor) : brandColor;

    for (NSInteger i = 0; i < PPSplashPhaseCount; i++) {
        self.ringTrackLayers[i].strokeColor = trackColor.CGColor;
        self.ringTrackLayers[i].lineWidth   = trackW;

        // Final segment uses premium gold when ready
        UIColor *segColor = (i == PPSplashPhaseCount - 1 && self.isReady)
            ? premiumColor : ringBrandColor;
        self.ringProgressLayers[i].strokeColor = segColor.CGColor;
        self.ringProgressLayers[i].lineWidth   = progressW;
    }

    [CATransaction commit];
}

@end

#pragma mark - PPProAtmosphereView

/// Full-bleed gradient background that shifts color temperature with loading phases.
@interface PPProAtmosphereView : UIView
@property (nonatomic, strong) CAGradientLayer *mistLayer;
@end

@implementation PPProAtmosphereView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.mistLayer = [CAGradientLayer layer];
        if (@available(iOS 12.0, *)) {
            self.mistLayer.type = kCAGradientLayerRadial;
        }
        self.mistLayer.startPoint = CGPointMake(0.5, 0.40);
        self.mistLayer.endPoint   = CGPointMake(1.25, 1.25);
        self.mistLayer.locations  = @[@0.0, @0.50, @1.0];
        [self.layer addSublayer:self.mistLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.mistLayer.frame = self.bounds;
}

- (void)updateWithMistColor:(UIColor *)mist surfaceColor:(UIColor *)surface {
    self.backgroundColor = surface;
    self.mistLayer.colors = @[
        (id)[mist colorWithAlphaComponent:0.36].CGColor,
        (id)[mist colorWithAlphaComponent:0.10].CGColor,
        (id)UIColor.clearColor.CGColor
    ];
}

@end

#pragma mark - SplashViewController

@interface SplashViewController ()

@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL viewIsVisible;
@property (nonatomic, assign) CGSize lastLayoutSize;
@property (nonatomic, assign) PPSplashLoadingPhase currentLoadingPhase;
@property (nonatomic, copy, nullable) NSString *currentLoadingDetail;

// Subviews
@property (nonatomic, strong) PPProAtmosphereView *atmosphereView;
@property (nonatomic, strong) PPProCarrierView *carrierView;
@property (nonatomic, strong) NSLayoutConstraint *carrierWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *carrierHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *carrierCenterYConstraint;

@property (nonatomic, strong) UIStackView *identityStackView;
@property (nonatomic, strong) UILabel *brandLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *identityBottomConstraint;

@property (nonatomic, strong) UIView *statusGroupView;
@property (nonatomic, strong) UIStackView *statusTextStackView;
@property (nonatomic, strong) UILabel *loadingTitleLabel;
@property (nonatomic, strong) UILabel *loadingStatusLabel;
@property (nonatomic, strong) NSLayoutConstraint *statusTopConstraint;

@property (nonatomic, strong) UILabel *footerLabel;

// Animators
@property (nonatomic, strong, nullable) id<UIViewAnimating> contentEntranceAnimator;
@property (nonatomic, strong, nullable) id<UIViewAnimating> statusEntranceAnimator;
@property (nonatomic, strong, nullable) id<UIViewAnimating> statusTextAnimator;

@end

@implementation SplashViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self pp_buildInterface];
    [self pp_applyTheme];
    [self pp_applyCopy];
    [self pp_updateLoadingPhase:PPSplashLoadingPhaseBootstrapping detail:self.currentLoadingDetail];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionStatusDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_processEnvironmentDidChange:)
                                                 name:NSProcessInfoPowerStateDidChangeNotification
                                               object:nil];
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pp_processEnvironmentDidChange:)
                                                     name:NSProcessInfoThermalStateDidChangeNotification
                                                   object:nil];
    }

    [PPHUD dismiss];

    // Simulated progression while SceneDelegate handles auth & workspace bootstrap
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.currentLoadingPhase >= PPSplashLoadingPhasePreparingContent) return;
        [self pp_updateLoadingPhase:PPSplashLoadingPhasePreparingContent detail:kLang(@"splash_loading_categories")];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.currentLoadingPhase >= PPSplashLoadingPhaseReady) return;
        [self pp_updateLoadingPhase:PPSplashLoadingPhaseReady detail:kLang(@"splash_loading_ready")];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.viewIsVisible = YES;
    [self pp_beginEntranceAnimationsIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.viewIsVisible = NO;
    [self.carrierView stopMotion];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL colorChanged = !previousTraitCollection ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection];
    BOOL contrastChanged = previousTraitCollection &&
        self.traitCollection.accessibilityContrast != previousTraitCollection.accessibilityContrast;
    if (colorChanged || contrastChanged) {
        [self pp_applyTheme];
    }
    if (!previousTraitCollection ||
        ![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_applyAdaptiveLayout];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!CGSizeEqualToSize(self.lastLayoutSize, self.view.bounds.size)) {
        self.lastLayoutSize = self.view.bounds.size;
        [self pp_applyAdaptiveLayout];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification {
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        if (self.viewIsVisible) {
            [self.carrierView resumeAmbientMotionIfAllowed];
        }
        return;
    }

    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    self.contentEntranceAnimator = nil;
    self.statusEntranceAnimator  = nil;
    self.statusTextAnimator      = nil;

    [self.carrierView settleForSnapshot];
    self.atmosphereView.alpha  = 1.0;
    self.brandLabel.alpha      = 1.0;
    self.subtitleLabel.alpha   = 1.0;
    self.statusGroupView.alpha = 1.0;
    self.loadingTitleLabel.alpha  = 1.0;
    self.loadingStatusLabel.alpha = 1.0;
    self.footerLabel.alpha = 1.0;
}

- (void)pp_applicationDidEnterBackground:(NSNotification *)notification {
    if (!self.viewIsVisible) return;
    [self.carrierView settleForSnapshot];
    [self.contentEntranceAnimator stopAnimation:YES];
    [self.statusEntranceAnimator stopAnimation:YES];
    [self.statusTextAnimator stopAnimation:YES];
    self.contentEntranceAnimator = nil;
    self.statusEntranceAnimator  = nil;
    self.statusTextAnimator      = nil;
}

- (void)pp_applicationDidBecomeActive:(NSNotification *)notification {
    if (!self.viewIsVisible) return;
    [self.carrierView settleForSnapshot];
    [self.carrierView resumeAmbientMotionIfAllowed];
}

- (void)pp_processEnvironmentDidChange:(NSNotification *)notification {
    if (!self.viewIsVisible) return;
    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    BOOL thermalPressure = NO;
    if (@available(iOS 11.0, *)) {
        thermalPressure = processInfo.thermalState >= NSProcessInfoThermalStateSerious;
    }
    if (processInfo.isLowPowerModeEnabled || thermalPressure) {
        [self.carrierView settleForSnapshot];
    } else {
        [self.carrierView resumeAmbientMotionIfAllowed];
    }
}

#pragma mark - Build Interface

- (void)pp_buildInterface {
    for (UIView *legacy in self.view.subviews.copy) {
        [legacy removeFromSuperview];
    }

    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.view.clipsToBounds = YES;

    // Atmosphere — full-bleed gradient background
    PPProAtmosphereView *atmosphereView = [[PPProAtmosphereView alloc] initWithFrame:self.view.bounds];
    atmosphereView.translatesAutoresizingMaskIntoConstraints = NO;
    atmosphereView.alpha = 0.0;
    [self.view addSubview:atmosphereView];
    self.atmosphereView = atmosphereView;

    // Carrier — center brand mark + orbital ring
    PPProCarrierView *carrierView = [[PPProCarrierView alloc] init];
    carrierView.translatesAutoresizingMaskIntoConstraints = NO;
    carrierView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:carrierView];
    self.carrierView = carrierView;

    self.carrierWidthConstraint  = [carrierView.widthAnchor constraintEqualToConstant:PPCarrierSideRegular + PPRingGap * 2 + PPRingProgressWidth * 2];
    self.carrierHeightConstraint = [carrierView.heightAnchor constraintEqualToConstant:PPCarrierSideRegular + PPRingGap * 2 + PPRingProgressWidth * 2];
    self.carrierWidthConstraint.active  = YES;
    self.carrierHeightConstraint.active = YES;

    // Identity stack — brand name + subtitle above carrier
    UIStackView *identityStack = [[UIStackView alloc] init];
    identityStack.translatesAutoresizingMaskIntoConstraints = NO;
    identityStack.axis         = UILayoutConstraintAxisVertical;
    identityStack.alignment    = UIStackViewAlignmentFill;
    identityStack.distribution = UIStackViewDistributionFill;
    identityStack.spacing      = PPSpaceXS;
    identityStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:identityStack];
    self.identityStackView = identityStack;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.numberOfLines = 2;
    brandLabel.font = [Styling fontBold:26.0];
    brandLabel.adjustsFontForContentSizeCategory = YES;
    brandLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    brandLabel.alpha = 0.0;
    [identityStack addArrangedSubview:brandLabel];
    self.brandLabel = brandLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment   = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines   = 0;
    subtitleLabel.font            = [Styling fontMedium:14.0];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.lineBreakMode   = NSLineBreakByWordWrapping;
    subtitleLabel.alpha           = 0.0;
    [identityStack addArrangedSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    // Status group — loading phase title + detail below carrier
    UIView *statusGroupView = [[UIView alloc] init];
    statusGroupView.translatesAutoresizingMaskIntoConstraints = NO;
    statusGroupView.backgroundColor = UIColor.clearColor;
    statusGroupView.isAccessibilityElement = YES;
    statusGroupView.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    statusGroupView.alpha = 0.0;
    [self.view addSubview:statusGroupView];
    self.statusGroupView = statusGroupView;

    UIStackView *statusTextStack = [[UIStackView alloc] init];
    statusTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusTextStack.axis         = UILayoutConstraintAxisVertical;
    statusTextStack.alignment    = UIStackViewAlignmentFill;
    statusTextStack.distribution = UIStackViewDistributionFill;
    statusTextStack.spacing      = PPSpaceXS;
    statusTextStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [statusGroupView addSubview:statusTextStack];
    self.statusTextStackView = statusTextStack;

    UILabel *loadingTitleLabel = [[UILabel alloc] init];
    loadingTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    loadingTitleLabel.font     = [Styling fontBold:16.0];
    loadingTitleLabel.adjustsFontForContentSizeCategory = YES;
    loadingTitleLabel.textAlignment = NSTextAlignmentCenter;
    loadingTitleLabel.numberOfLines = 0;
    loadingTitleLabel.isAccessibilityElement = NO;
    [statusTextStack addArrangedSubview:loadingTitleLabel];
    self.loadingTitleLabel = loadingTitleLabel;

    UILabel *loadingStatusLabel = [[UILabel alloc] init];
    loadingStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    loadingStatusLabel.font     = [Styling fontMedium:13.5];
    loadingStatusLabel.adjustsFontForContentSizeCategory = YES;
    loadingStatusLabel.textAlignment = NSTextAlignmentCenter;
    loadingStatusLabel.numberOfLines = 0;
    loadingStatusLabel.isAccessibilityElement = NO;
    [statusTextStack addArrangedSubview:loadingStatusLabel];
    self.loadingStatusLabel = loadingStatusLabel;

    // Footer
    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 2;
    footerLabel.font          = [Styling fontMedium:11.5];
    footerLabel.adjustsFontForContentSizeCategory = YES;
    footerLabel.alpha = 0.0;
    footerLabel.accessibilityElementsHidden = YES;
    [self.view addSubview:footerLabel];
    self.footerLabel = footerLabel;

    // Layout constraints
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;

    NSLayoutConstraint *identityFluidWidth = [identityStack.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-64.0];
    identityFluidWidth.priority = UILayoutPriorityRequired - 1;
    NSLayoutConstraint *identityMaxWidth = [identityStack.widthAnchor constraintLessThanOrEqualToConstant:360.0];

    self.identityBottomConstraint = [identityStack.bottomAnchor constraintEqualToAnchor:carrierView.topAnchor constant:-PPSpaceLG];
    self.identityBottomConstraint.priority = UILayoutPriorityRequired - 1;

    self.carrierCenterYConstraint = [carrierView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30.0];
    self.carrierCenterYConstraint.priority = UILayoutPriorityDefaultHigh;

    self.statusTopConstraint = [statusGroupView.topAnchor constraintEqualToAnchor:carrierView.bottomAnchor constant:PPSpaceMD];
    self.statusTopConstraint.priority = UILayoutPriorityRequired - 1;

    NSLayoutConstraint *statusFluidWidth = [statusGroupView.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-72.0];
    statusFluidWidth.priority = UILayoutPriorityRequired - 1;
    NSLayoutConstraint *statusMaxWidth = [statusGroupView.widthAnchor constraintLessThanOrEqualToConstant:360.0];

    [NSLayoutConstraint activateConstraints:@[
        // Atmosphere — full bleed
        [atmosphereView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [atmosphereView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [atmosphereView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [atmosphereView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Identity — centered above carrier
        [identityStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [identityStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:PPSpaceXL],
        [identityStack.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-PPSpaceXL],
        identityFluidWidth,
        identityMaxWidth,
        [identityStack.topAnchor constraintGreaterThanOrEqualToAnchor:safeArea.topAnchor constant:PPSpaceBase],
        self.identityBottomConstraint,

        // Carrier — centered
        [carrierView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        self.carrierCenterYConstraint,

        // Status — centered below carrier
        [statusGroupView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [statusGroupView.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:PPSpaceXL],
        [statusGroupView.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-PPSpaceXL],
        self.statusTopConstraint,
        [statusGroupView.bottomAnchor constraintLessThanOrEqualToAnchor:footerLabel.topAnchor constant:-PPSpaceLG],
        statusFluidWidth,
        statusMaxWidth,

        [statusTextStack.leadingAnchor constraintEqualToAnchor:statusGroupView.leadingAnchor],
        [statusTextStack.trailingAnchor constraintEqualToAnchor:statusGroupView.trailingAnchor],
        [statusTextStack.topAnchor constraintEqualToAnchor:statusGroupView.topAnchor],
        [statusTextStack.bottomAnchor constraintEqualToAnchor:statusGroupView.bottomAnchor],

        // Footer — bottom safe area
        [footerLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:PPSpaceXL],
        [footerLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-PPSpaceXL],
        [footerLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-PPSpaceMD],
    ]];

    self.view.accessibilityElements = @[brandLabel, subtitleLabel, statusGroupView];
    [self pp_applyAdaptiveLayout];
}

#pragma mark - Theme & Styling

- (void)pp_applyTheme {
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    UIColor *canvasColor       = [UIColor ppBackground];
    UIColor *titleColor        = [UIColor ppTextPrimary];
    UIColor *secondaryColor    = [UIColor ppTextSecondary];
    UIColor *primaryColor      = [UIColor ppPrimary];
    UIColor *elevatedSurface   = [UIColor ppElevatedSurface];
    UIColor *softRose          = [UIColor ppSoftRose];

    // Atmosphere mist — warm brand-tinted radial
    UIColor *mistColor = isDark
        ? PPSplashBlendColor(primaryColor, softRose, 0.24)
        : PPSplashBlendColor(softRose, primaryColor, 0.16);

    self.view.backgroundColor = canvasColor;
    [self.atmosphereView updateWithMistColor:mistColor surfaceColor:elevatedSurface];
    [self.carrierView pp_applyTheme];

    self.brandLabel.textColor         = titleColor;
    self.subtitleLabel.textColor      = secondaryColor;
    self.loadingTitleLabel.textColor  = titleColor;
    self.loadingStatusLabel.textColor = secondaryColor;
    self.footerLabel.textColor        = [secondaryColor colorWithAlphaComponent:isDark ? 0.62 : 0.78];
}

- (void)pp_applyCopy {
    NSInteger currentYear = [[NSCalendar currentCalendar] component:NSCalendarUnitYear fromDate:[NSDate date]];

    NSString *appName = kLang(@"AppName");
    if (!appName.length) {
        appName = Language.isRTL ? @"بيور بتس برو" : @"Pure Pets Pro";
    }
    self.brandLabel.text     = appName;
    self.subtitleLabel.text  = kLang(@"splash_product_promise");
    self.loadingTitleLabel.text = kLang(@"splash_loading_title");
    self.footerLabel.text    = [NSString localizedStringWithFormat:kLang(@"splash_footer_format"), (long)currentYear];
    self.currentLoadingDetail = kLang(@"splash_loading_boot");
}

- (void)pp_applyAdaptiveLayout {
    BOOL accessibilitySizes = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
    BOOL compactHeight = (viewHeight > 0.0 && viewHeight < 720.0);

    // Carrier dimensions — adapt to available space
    CGFloat carrierSide = compactHeight ? PPCarrierSideCompact : PPCarrierSideRegular;
    if (accessibilitySizes && compactHeight) {
        carrierSide = PPCarrierSideAccessibility;
    }
    CGFloat totalSide = carrierSide + PPRingGap * 2 + PPRingProgressWidth * 2;
    self.carrierWidthConstraint.constant  = totalSide;
    self.carrierHeightConstraint.constant = totalSide;

    self.identityBottomConstraint.constant = compactHeight ? -PPSpaceSM : -PPSpaceLG;
    self.statusTopConstraint.constant      = compactHeight ? PPSpaceXS : PPSpaceMD;

    self.brandLabel.numberOfLines     = 2;
    self.footerLabel.numberOfLines    = accessibilitySizes ? 2 : 1;
    self.identityStackView.spacing    = accessibilitySizes ? PPSpaceXXS : PPSpaceXS;
    self.statusTextStackView.spacing  = accessibilitySizes ? PPSpaceXXS : PPSpaceXS;
}

#pragma mark - Entrance Choreography

- (void)pp_beginEntranceAnimationsIfNeeded {
    if (self.didAnimateEntrance) return;
    self.didAnimateEntrance = YES;

    [self.carrierView playEntrance];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.atmosphereView.alpha    = 1.0;
        self.brandLabel.alpha        = 1.0;
        self.subtitleLabel.alpha     = 1.0;
        self.statusGroupView.alpha   = 1.0;
        self.footerLabel.alpha       = 1.0;
        return;
    }

    __weak typeof(self) weakSelf = self;
    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1.0)
                                                                              controlPoint2:CGPointMake(0.32, 1.0)];

    // Identity + atmosphere entrance
    UIViewPropertyAnimator *contentAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.26 timingParameters:timing];
    [contentAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.atmosphereView.alpha = 1.0;
        self.brandLabel.alpha     = 1.0;
        self.subtitleLabel.alpha  = 1.0;
    }];
    self.contentEntranceAnimator = contentAnimator;
    [contentAnimator startAnimationAfterDelay:0.02];

    // Status + footer entrance — slightly staggered
    UIViewPropertyAnimator *statusAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.22 timingParameters:timing];
    [statusAnimator addAnimations:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.statusGroupView.alpha = 1.0;
        self.footerLabel.alpha     = 1.0;
    }];
    self.statusEntranceAnimator = statusAnimator;
    [statusAnimator startAnimationAfterDelay:0.06];
}

#pragma mark - Phase Progression

- (void)pp_updateLoadingPhase:(PPSplashLoadingPhase)phase detail:(NSString *)detail {
    PPSplashLoadingPhase previousPhase = self.currentLoadingPhase;
    self.currentLoadingPhase  = phase;
    self.currentLoadingDetail = detail ?: self.currentLoadingDetail;

    BOOL isReady = (phase == PPSplashLoadingPhaseReady);
    NSString *titleKey = isReady ? @"splash_ready_title" : @"splash_loading_title";
    NSString *title      = kLang(titleKey) ?: @"";
    NSString *safeDetail = self.currentLoadingDetail ?: @"";

    [self.statusTextAnimator stopAnimation:YES];
    self.statusTextAnimator = nil;
    self.loadingTitleLabel.text  = title;
    self.loadingStatusLabel.text = safeDetail;

    if (self.view.window && !UIAccessibilityIsReduceMotionEnabled()) {
        self.loadingTitleLabel.alpha  = 0.82;
        self.loadingStatusLabel.alpha = 0.78;

        __weak typeof(self) weakSelf = self;
        UICubicTimingParameters *timing = [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1.0)
                                                                                  controlPoint2:CGPointMake(0.32, 1.0)];
        UIViewPropertyAnimator *textAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.22 timingParameters:timing];
        [textAnimator addAnimations:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.loadingTitleLabel.alpha  = 1.0;
            self.loadingStatusLabel.alpha = 1.0;
        }];
        self.statusTextAnimator = textAnimator;
        [textAnimator startAnimation];
    } else {
        self.loadingTitleLabel.alpha  = 1.0;
        self.loadingStatusLabel.alpha = 1.0;
    }

    NSInteger activePhases = MIN(MAX((NSInteger)phase + 1, 1), PPSplashPhaseCount);
    BOOL shouldAnimate = (self.view.window != nil && self.didAnimateEntrance);
    [self.carrierView setActivePhaseCount:activePhases animated:shouldAnimate];
    [self.carrierView setReady:isReady animated:shouldAnimate && previousPhase != phase];
    [self pp_applyTheme];

    self.statusGroupView.accessibilityLabel = [NSString localizedStringWithFormat:kLang(@"splash_loading_accessibility_format"), title, safeDetail];
}

@end
