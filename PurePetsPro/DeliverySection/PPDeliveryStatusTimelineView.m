//
//  PPDeliveryStatusTimelineView.m
//  PurePetsPro
//
//  Premium minimal delivery timeline with a refined progress header,
//  quieter milestone rows, and stronger current-state emphasis.
//

#import "PPDeliveryStatusTimelineView.h"
#import "PPDeliveryOrderModel.h"

static CGFloat const kTimelineHeaderRadius       = 26.0;
static CGFloat const kTimelineTrackHeight        = 8.0;
static CGFloat const kTimelineMarkerSize         = 26.0;
static CGFloat const kTimelineMarkerColumnWidth  = 34.0;
static CGFloat const kTimelineStepSpacing        = 14.0;

static BOOL PPTimelineStatusInSet(NSString *status, NSArray<NSString *> *values) {
    for (NSString *candidate in values) {
        if ([status isEqualToString:[candidate lowercaseString]]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Step Model

@interface PPTimelineStep : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, strong) UIColor *activeColor;
@property (nonatomic, assign) BOOL completed;
@property (nonatomic, assign) BOOL current;
@end

@implementation PPTimelineStep
@end

#pragma mark - Step Row

@interface _PPTimelineStepRowView : UIView
@property (nonatomic, strong) UIStackView *layoutStack;
@property (nonatomic, strong) UIView *markerColumnView;
@property (nonatomic, strong) UIView *lineAboveView;
@property (nonatomic, strong) UIView *lineBelowView;
@property (nonatomic, strong) UIView *markerHaloView;
@property (nonatomic, strong) UIView *markerShellView;
@property (nonatomic, strong) UIView *markerCoreView;
@property (nonatomic, strong) UIImageView *markerGlyphView;
@property (nonatomic, strong) UIStackView *cpStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, assign) BOOL showsSubtitle;
- (void)configureWithStep:(PPTimelineStep *)step isFirst:(BOOL)isFirst isLast:(BOOL)isLast;
@end

@implementation _PPTimelineStepRowView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        _layoutStack = [[UIStackView alloc] init];
        _layoutStack.translatesAutoresizingMaskIntoConstraints = NO;
        _layoutStack.axis = UILayoutConstraintAxisHorizontal;
        _layoutStack.alignment = UIStackViewAlignmentFill;
        _layoutStack.spacing = 12.0;
        _layoutStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self addSubview:_layoutStack];

        _markerColumnView = [[UIView alloc] init];
        _markerColumnView.translatesAutoresizingMaskIntoConstraints = NO;
        _markerColumnView.backgroundColor = UIColor.clearColor;
        [_layoutStack addArrangedSubview:_markerColumnView];

        _cpStack = [[UIStackView alloc] init];
        _cpStack.translatesAutoresizingMaskIntoConstraints = NO;
        _cpStack.axis = UILayoutConstraintAxisVertical;
        _cpStack.alignment = UIStackViewAlignmentFill;
        _cpStack.spacing = 4.0;
        _cpStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [_layoutStack addArrangedSubview:_cpStack];

        _lineAboveView = [[UIView alloc] init];
        _lineAboveView.translatesAutoresizingMaskIntoConstraints = NO;
        _lineAboveView.layer.cornerRadius = 1.25;
        _lineAboveView.layer.cornerCurve = kCACornerCurveContinuous;
        [_markerColumnView addSubview:_lineAboveView];

        _lineBelowView = [[UIView alloc] init];
        _lineBelowView.translatesAutoresizingMaskIntoConstraints = NO;
        _lineBelowView.layer.cornerRadius = 1.25;
        _lineBelowView.layer.cornerCurve = kCACornerCurveContinuous;
        [_markerColumnView addSubview:_lineBelowView];

        _markerHaloView = [[UIView alloc] init];
        _markerHaloView.translatesAutoresizingMaskIntoConstraints = NO;
        _markerHaloView.backgroundColor = UIColor.clearColor;
        _markerHaloView.layer.borderWidth = 1.5;
        _markerHaloView.hidden = YES;
        [_markerColumnView addSubview:_markerHaloView];

        _markerShellView = [[UIView alloc] init];
        _markerShellView.translatesAutoresizingMaskIntoConstraints = NO;
        _markerShellView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _markerShellView.layer.cornerCurve = kCACornerCurveContinuous;
        [_markerColumnView addSubview:_markerShellView];

        _markerCoreView = [[UIView alloc] init];
        _markerCoreView.translatesAutoresizingMaskIntoConstraints = NO;
        _markerCoreView.layer.cornerCurve = kCACornerCurveContinuous;
        [_markerShellView addSubview:_markerCoreView];

        _markerGlyphView = [[UIImageView alloc] init];
        _markerGlyphView.translatesAutoresizingMaskIntoConstraints = NO;
        _markerGlyphView.contentMode = UIViewContentModeScaleAspectFit;
        _markerGlyphView.hidden = YES;
        [_markerShellView addSubview:_markerGlyphView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = PPFontMedium(14);
        _titleLabel.textColor = PrimaryTextClr;
        _titleLabel.numberOfLines = 2;
        _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cpStack addArrangedSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = PPFontRegular(11);
        _subtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.72];
        _subtitleLabel.numberOfLines = 2;
        _subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        [_cpStack addArrangedSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_layoutStack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_layoutStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_layoutStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_layoutStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_markerColumnView.widthAnchor constraintEqualToConstant:kTimelineMarkerColumnWidth],

            [_lineAboveView.centerXAnchor constraintEqualToAnchor:_markerColumnView.centerXAnchor],
            [_lineAboveView.topAnchor constraintEqualToAnchor:_markerColumnView.topAnchor],
            [_lineAboveView.widthAnchor constraintEqualToConstant:2.5],
            [_lineAboveView.bottomAnchor constraintEqualToAnchor:_markerShellView.topAnchor constant:-6.0],

            [_lineBelowView.centerXAnchor constraintEqualToAnchor:_markerColumnView.centerXAnchor],
            [_lineBelowView.topAnchor constraintEqualToAnchor:_markerShellView.bottomAnchor constant:6.0],
            [_lineBelowView.widthAnchor constraintEqualToConstant:2.5],
            [_lineBelowView.bottomAnchor constraintEqualToAnchor:_markerColumnView.bottomAnchor],

            [_markerHaloView.centerXAnchor constraintEqualToAnchor:_markerColumnView.centerXAnchor],
            [_markerHaloView.centerYAnchor constraintEqualToAnchor:_markerShellView.centerYAnchor],
            [_markerHaloView.widthAnchor constraintEqualToConstant:kTimelineMarkerSize + 12.0],
            [_markerHaloView.heightAnchor constraintEqualToConstant:kTimelineMarkerSize + 12.0],

            [_markerShellView.centerXAnchor constraintEqualToAnchor:_markerColumnView.centerXAnchor],
            [_markerShellView.topAnchor constraintEqualToAnchor:_markerColumnView.topAnchor constant:2.0],
            [_markerShellView.widthAnchor constraintEqualToConstant:kTimelineMarkerSize],
            [_markerShellView.heightAnchor constraintEqualToConstant:kTimelineMarkerSize],

            [_markerCoreView.centerXAnchor constraintEqualToAnchor:_markerShellView.centerXAnchor],
            [_markerCoreView.centerYAnchor constraintEqualToAnchor:_markerShellView.centerYAnchor],
            [_markerCoreView.widthAnchor constraintEqualToConstant:10.0],
            [_markerCoreView.heightAnchor constraintEqualToConstant:10.0],

            [_markerGlyphView.centerXAnchor constraintEqualToAnchor:_markerShellView.centerXAnchor],
            [_markerGlyphView.centerYAnchor constraintEqualToAnchor:_markerShellView.centerYAnchor],
            [_markerGlyphView.widthAnchor constraintEqualToConstant:13.0],
            [_markerGlyphView.heightAnchor constraintEqualToConstant:13.0],
        ]];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, self.showsSubtitle ? 58.0 : 42.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.markerHaloView.layer.cornerRadius = self.markerHaloView.bounds.size.width / 2.0;
    self.markerShellView.layer.cornerRadius = self.markerShellView.bounds.size.width / 2.0;
    self.markerCoreView.layer.cornerRadius = self.markerCoreView.bounds.size.width / 2.0;
}

- (void)configureWithStep:(PPTimelineStep *)step isFirst:(BOOL)isFirst isLast:(BOOL)isLast {
    UIColor *activeColor = step.activeColor ?: AppPrimaryClr;
    UIColor *inactiveColor = [SeconderyTextClr colorWithAlphaComponent:0.12];
    UIColor *mutedTextColor = [SeconderyTextClr colorWithAlphaComponent:0.68];

    self.lineAboveView.hidden = isFirst;
    self.lineBelowView.hidden = isLast;
    self.lineAboveView.backgroundColor = (step.completed || step.current) ? [activeColor colorWithAlphaComponent:0.34] : inactiveColor;
    self.lineBelowView.backgroundColor = step.completed ? [activeColor colorWithAlphaComponent:0.34] : inactiveColor;

    self.titleLabel.text = step.title;
    self.titleLabel.font = step.current ? PPFontBold(15) : (step.completed ? PPFontMedium(14) : PPFontRegular(14));
    self.titleLabel.textColor = (step.completed || step.current) ? PrimaryTextClr : mutedTextColor;

    self.subtitleLabel.text = step.subtitle ?: @"";
    self.subtitleLabel.hidden = (step.subtitle.length == 0);
    self.showsSubtitle = !self.subtitleLabel.hidden;

    self.markerHaloView.hidden = !step.current;
    [self.markerHaloView.layer removeAnimationForKey:@"pp.timeline.row.pulse"];

    UIImageSymbolConfiguration *glyphConfig = [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightBold];

    if (step.completed) {
        self.markerShellView.backgroundColor = activeColor;
        self.markerShellView.layer.borderColor = [activeColor colorWithAlphaComponent:0.14].CGColor;
        self.markerCoreView.hidden = YES;
        self.markerGlyphView.hidden = NO;
        self.markerGlyphView.tintColor = UIColor.whiteColor;
        self.markerGlyphView.image = [[UIImage systemImageNamed:@"checkmark"] imageWithConfiguration:glyphConfig];
    } else if (step.current) {
        self.markerShellView.backgroundColor = [activeColor colorWithAlphaComponent:0.12];
        self.markerShellView.layer.borderColor = [activeColor colorWithAlphaComponent:0.18].CGColor;
        self.markerCoreView.hidden = NO;
        self.markerCoreView.backgroundColor = activeColor;
        self.markerGlyphView.hidden = YES;
        self.markerHaloView.layer.borderColor = [activeColor colorWithAlphaComponent:0.34].CGColor;

        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.fromValue = @1.0;
        pulse.toValue = @1.16;

        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @0.75;
        fade.toValue = @0.0;

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[pulse, fade];
        group.duration = 1.45;
        group.repeatCount = HUGE_VALF;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [self.markerHaloView.layer addAnimation:group forKey:@"pp.timeline.row.pulse"];
    } else {
        self.markerShellView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.04];
        self.markerShellView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.10].CGColor;
        self.markerCoreView.hidden = NO;
        self.markerCoreView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.22];
        self.markerGlyphView.hidden = YES;
    }

    [self invalidateIntrinsicContentSize];
}

@end

#pragma mark - PPDeliveryStatusTimelineView

@interface PPDeliveryStatusTimelineView ()
@property (nonatomic, strong) NSArray<PPTimelineStep *> *steps;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *summarySurfaceView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *summarySubtitleLabel;
@property (nonatomic, strong) UILabel *progressRatioLabel;
@property (nonatomic, strong) UIView *progressTrackView;
@property (nonatomic, strong) UIView *progressGlowView;
@property (nonatomic, strong) CAGradientLayer *progressFillLayer;
@property (nonatomic, strong) UIStackView *stepsStack;
@property (nonatomic, assign) CGFloat progressValue;
@property (nonatomic, strong) UIColor *progressTintColor;
@end

@implementation PPDeliveryStatusTimelineView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = AppClearClr;
        self.opaque = NO;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.spacing = 18.0;
    self.contentStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self addSubview:self.contentStack];

    self.summarySurfaceView = [[UIView alloc] init];
    self.summarySurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.summarySurfaceView.backgroundColor = AppForgroundColr;
    self.summarySurfaceView.layer.cornerRadius = kTimelineHeaderRadius;
    self.summarySurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.summarySurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.summarySurfaceView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    self.summarySurfaceView.clipsToBounds = YES;
    [self.contentStack addArrangedSubview:self.summarySurfaceView];

    UIView *summaryGlow = [[UIView alloc] init];
    summaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    summaryGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    summaryGlow.layer.cornerRadius = 84.0;
    summaryGlow.layer.cornerCurve = kCACornerCurveContinuous;
    summaryGlow.userInteractionEnabled = NO;
    [self.summarySurfaceView addSubview:summaryGlow];

    UIView *summaryHighlight = [[UIView alloc] init];
    summaryHighlight.translatesAutoresizingMaskIntoConstraints = NO;
    summaryHighlight.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    summaryHighlight.layer.cornerRadius = 54.0;
    summaryHighlight.layer.cornerCurve = kCACornerCurveContinuous;
    summaryHighlight.userInteractionEnabled = NO;
    [self.summarySurfaceView addSubview:summaryHighlight];

    UIView *summaryAccentBar = [[UIView alloc] init];
    summaryAccentBar.translatesAutoresizingMaskIntoConstraints = NO;
    summaryAccentBar.backgroundColor = AppPrimaryClr;
    summaryAccentBar.layer.cornerRadius = 2.0;
    summaryAccentBar.layer.cornerCurve = kCACornerCurveContinuous;
    [self.summarySurfaceView addSubview:summaryAccentBar];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = PPFontBold(17);
    self.statusLabel.textColor = PrimaryTextClr;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.summarySubtitleLabel = [[UILabel alloc] init];
    self.summarySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.summarySubtitleLabel.font = PPFontRegular(12);
    self.summarySubtitleLabel.textColor = [SeconderyTextClr colorWithAlphaComponent:0.74];
    self.summarySubtitleLabel.numberOfLines = 2;
    self.summarySubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIStackView *headlineStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.statusLabel,
        self.summarySubtitleLabel
    ]];
    headlineStack.translatesAutoresizingMaskIntoConstraints = NO;
    headlineStack.axis = UILayoutConstraintAxisVertical;
    headlineStack.alignment = UIStackViewAlignmentFill;
    headlineStack.spacing = 4.0;
    headlineStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.summarySurfaceView addSubview:headlineStack];

    UIView *ratioShellView = [[UIView alloc] init];
    ratioShellView.translatesAutoresizingMaskIntoConstraints = NO;
    ratioShellView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    ratioShellView.layer.cornerRadius = 16.0;
    ratioShellView.layer.cornerCurve = kCACornerCurveContinuous;
    ratioShellView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    ratioShellView.layer.borderColor = [SeconderyTextClr colorWithAlphaComponent:0.08].CGColor;
    [self.summarySurfaceView addSubview:ratioShellView];

    self.progressRatioLabel = [[UILabel alloc] init];
    self.progressRatioLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressRatioLabel.font = PPFontBold(12);
    self.progressRatioLabel.textColor = AppPrimaryClr;
    self.progressRatioLabel.textAlignment = NSTextAlignmentCenter;
    self.progressRatioLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [ratioShellView addSubview:self.progressRatioLabel];

    self.progressTrackView = [[UIView alloc] init];
    self.progressTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressTrackView.backgroundColor = [SeconderyTextClr colorWithAlphaComponent:0.08];
    self.progressTrackView.layer.cornerRadius = kTimelineTrackHeight / 2.0;
    self.progressTrackView.layer.cornerCurve = kCACornerCurveContinuous;
    self.progressTrackView.clipsToBounds = YES;
    [self.summarySurfaceView addSubview:self.progressTrackView];

    self.progressFillLayer = [CAGradientLayer layer];
    self.progressFillLayer.startPoint = CGPointMake(0.0, 0.5);
    self.progressFillLayer.endPoint = CGPointMake(1.0, 0.5);
    self.progressFillLayer.cornerRadius = kTimelineTrackHeight / 2.0;
    [self.progressTrackView.layer addSublayer:self.progressFillLayer];

    self.progressGlowView = [[UIView alloc] init];
    self.progressGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressGlowView.backgroundColor = AppPrimaryClr;
    self.progressGlowView.layer.cornerRadius = 4.0;
    self.progressGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    self.progressGlowView.layer.shadowColor = AppPrimaryClr.CGColor;
    self.progressGlowView.layer.shadowOpacity = 0.20;
    self.progressGlowView.layer.shadowRadius = 8.0;
    self.progressGlowView.layer.shadowOffset = CGSizeZero;
    self.progressGlowView.userInteractionEnabled = NO;
    [self.progressTrackView addSubview:self.progressGlowView];

    self.stepsStack = [[UIStackView alloc] init];
    self.stepsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.stepsStack.axis = UILayoutConstraintAxisVertical;
    self.stepsStack.alignment = UIStackViewAlignmentFill;
    self.stepsStack.spacing = kTimelineStepSpacing;
    self.stepsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.contentStack addArrangedSubview:self.stepsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.summarySurfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [summaryGlow.widthAnchor constraintEqualToConstant:168.0],
        [summaryGlow.heightAnchor constraintEqualToConstant:168.0],
        [summaryGlow.topAnchor constraintEqualToAnchor:self.summarySurfaceView.topAnchor constant:-92.0],
        [summaryGlow.trailingAnchor constraintEqualToAnchor:self.summarySurfaceView.trailingAnchor constant:70.0],

        [summaryHighlight.widthAnchor constraintEqualToConstant:108.0],
        [summaryHighlight.heightAnchor constraintEqualToConstant:108.0],
        [summaryHighlight.leadingAnchor constraintEqualToAnchor:self.summarySurfaceView.leadingAnchor constant:-44.0],
        [summaryHighlight.bottomAnchor constraintEqualToAnchor:self.summarySurfaceView.bottomAnchor constant:48.0],

        [summaryAccentBar.topAnchor constraintEqualToAnchor:self.summarySurfaceView.topAnchor constant:18.0],
        [summaryAccentBar.leadingAnchor constraintEqualToAnchor:self.summarySurfaceView.leadingAnchor constant:18.0],
        [summaryAccentBar.widthAnchor constraintEqualToConstant:58.0],
        [summaryAccentBar.heightAnchor constraintEqualToConstant:4.0],

        [headlineStack.topAnchor constraintEqualToAnchor:self.summarySurfaceView.topAnchor constant:24.0],
        [headlineStack.leadingAnchor constraintEqualToAnchor:self.summarySurfaceView.leadingAnchor constant:18.0],
        [headlineStack.trailingAnchor constraintLessThanOrEqualToAnchor:ratioShellView.leadingAnchor constant:-12.0],

        [ratioShellView.centerYAnchor constraintEqualToAnchor:headlineStack.centerYAnchor],
        [ratioShellView.trailingAnchor constraintEqualToAnchor:self.summarySurfaceView.trailingAnchor constant:-18.0],
        [ratioShellView.widthAnchor constraintGreaterThanOrEqualToConstant:54.0],

        [self.progressRatioLabel.topAnchor constraintEqualToAnchor:ratioShellView.topAnchor constant:8.0],
        [self.progressRatioLabel.leadingAnchor constraintEqualToAnchor:ratioShellView.leadingAnchor constant:12.0],
        [self.progressRatioLabel.trailingAnchor constraintEqualToAnchor:ratioShellView.trailingAnchor constant:-12.0],
        [self.progressRatioLabel.bottomAnchor constraintEqualToAnchor:ratioShellView.bottomAnchor constant:-8.0],

        [self.progressTrackView.topAnchor constraintGreaterThanOrEqualToAnchor:headlineStack.bottomAnchor constant:16.0],
        [self.progressTrackView.leadingAnchor constraintEqualToAnchor:self.summarySurfaceView.leadingAnchor constant:18.0],
        [self.progressTrackView.trailingAnchor constraintEqualToAnchor:self.summarySurfaceView.trailingAnchor constant:-18.0],
        [self.progressTrackView.bottomAnchor constraintEqualToAnchor:self.summarySurfaceView.bottomAnchor constant:-18.0],
        [self.progressTrackView.heightAnchor constraintEqualToConstant:kTimelineTrackHeight],

        [self.progressGlowView.centerYAnchor constraintEqualToAnchor:self.progressTrackView.centerYAnchor],
        [self.progressGlowView.widthAnchor constraintEqualToConstant:8.0],
        [self.progressGlowView.heightAnchor constraintEqualToConstant:8.0],
    ]];
}

#pragma mark - Configuration

- (void)configureWithOrder:(PPDeliveryOrderModel *)order {
    NSString *delivery = [order.deliveryStatus ?: @"" lowercaseString];
    NSString *rawStatus = [order.rawStatus ?: @"" lowercaseString];
    BOOL isCash = [order isCashOrder];

    NSMutableArray<PPTimelineStep *> *steps = [NSMutableArray array];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;

    PPTimelineStep *placed = [PPTimelineStep new];
    placed.title = kLang(@"Deliv_StatusOrderPlaced");
    placed.activeColor = [UIColor ppWarning];
    if (order.createdAt) {
        placed.subtitle = [dateFormatter stringFromDate:order.createdAt];
    }
    [steps addObject:placed];

    PPTimelineStep *preparing = [PPTimelineStep new];
    preparing.title = kLang(@"Deliv_StatusPreparing");
    preparing.activeColor = [UIColor ppWarning];
    if (order.processedAt) {
        preparing.subtitle = [dateFormatter stringFromDate:order.processedAt];
    }
    [steps addObject:preparing];

    PPTimelineStep *requested = [PPTimelineStep new];
    requested.title = kLang(@"Deliv_StatusRequested");
    requested.activeColor = [UIColor ppWarning];
    if (order.deliveryRequestedAt) {
        requested.subtitle = [dateFormatter stringFromDate:order.deliveryRequestedAt];
    }
    [steps addObject:requested];

    PPTimelineStep *handover = [PPTimelineStep new];
    handover.title = kLang(@"Deliv_StatusAwaitingHandover");
    handover.activeColor = [UIColor ppInfo];
    if (order.deliveryAcceptedAt) {
        handover.subtitle = [dateFormatter stringFromDate:order.deliveryAcceptedAt];
    }
    [steps addObject:handover];

    PPTimelineStep *transit = [PPTimelineStep new];
    transit.title = kLang(@"Deliv_StatusInTransit");
    transit.activeColor = [UIColor ppQuickActionCommunity];
    NSDate *transitDate = order.inTransitAt ?: order.pickedUpAt ?: order.shippedAt;
    if (transitDate) {
        transit.subtitle = [dateFormatter stringFromDate:transitDate];
    }
    [steps addObject:transit];

    PPTimelineStep *delivered = [PPTimelineStep new];
    delivered.title = kLang(@"Deliv_StatusDelivered");
    delivered.activeColor = [UIColor ppSuccess];
    if (order.deliveredAt) {
        delivered.subtitle = [dateFormatter stringFromDate:order.deliveredAt];
    }
    [steps addObject:delivered];

    PPTimelineStep *cashStep = nil;
    if (isCash) {
        cashStep = [PPTimelineStep new];
        cashStep.title = kLang(@"Deliv_StatusPaymentConfirmed");
        cashStep.activeColor = [UIColor ppQuickActionServices];
        NSDate *paymentDate = order.paymentCollectedAt ?: order.paymentConfirmedAt;
        if (paymentDate) {
            cashStep.subtitle = [dateFormatter stringFromDate:paymentDate];
        }
        [steps addObject:cashStep];
    }

    PPTimelineStep *completed = [PPTimelineStep new];
    completed.title = kLang(@"Deliv_StatusCompleted");
    completed.activeColor = [UIColor ppSuccess];
    if (order.completedAt) {
        completed.subtitle = [dateFormatter stringFromDate:order.completedAt];
    }
    [steps addObject:completed];

    NSInteger currentIndex = NSNotFound;
    if (delivery.length == 0 && [rawStatus isEqualToString:PPOrderRawStatusPending]) {
        currentIndex = 0;
    } else if ([delivery isEqualToString:PPDeliveryStatusReadyToShip]) {
        currentIndex = 1;
    } else if ([delivery isEqualToString:PPDeliveryStatusRequested]) {
        currentIndex = 2;
    } else if (PPTimelineStatusInSet(delivery, @[PPDeliveryStatusAssigned, PPDeliveryStatusAwaitingHandover])) {
        currentIndex = 3;
    } else if (PPTimelineStatusInSet(delivery, @[PPDeliveryStatusPickedUp, PPDeliveryStatusInTransit])) {
        currentIndex = 4;
    } else if (PPTimelineStatusInSet(delivery, @[PPDeliveryStatusDelivered, PPDeliveryStatusPaymentPending])) {
        currentIndex = 5;
    } else if ([delivery isEqualToString:PPDeliveryStatusPaymentConfirmed]) {
        currentIndex = isCash ? 6 : 5;
    } else if ([delivery isEqualToString:PPDeliveryStatusCompleted]) {
        currentIndex = isCash ? 7 : 6;
    }

    NSMutableArray<NSNumber *> *reachedFlags = [NSMutableArray array];
    [reachedFlags addObject:@(order.createdAt != nil || rawStatus.length > 0 || delivery.length > 0)];
    [reachedFlags addObject:@(order.processedAt != nil || PPTimelineStatusInSet(delivery, @[
        PPDeliveryStatusReadyToShip,
        PPDeliveryStatusRequested,
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]))];
    [reachedFlags addObject:@(order.deliveryRequestedAt != nil || PPTimelineStatusInSet(delivery, @[
        PPDeliveryStatusRequested,
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]))];
    [reachedFlags addObject:@(order.deliveryAcceptedAt != nil || PPTimelineStatusInSet(delivery, @[
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]))];
    [reachedFlags addObject:@(transitDate != nil || PPTimelineStatusInSet(delivery, @[
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]))];
    [reachedFlags addObject:@(order.deliveredAt != nil || PPTimelineStatusInSet(delivery, @[
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted
    ]))];
    if (isCash) {
        [reachedFlags addObject:@((order.paymentCollectedAt != nil || order.paymentConfirmedAt != nil) || PPTimelineStatusInSet(delivery, @[
            PPDeliveryStatusPaymentConfirmed,
            PPDeliveryStatusCompleted
        ]))];
    }
    [reachedFlags addObject:@(order.completedAt != nil || [delivery isEqualToString:PPDeliveryStatusCompleted])];

    if (currentIndex != NSNotFound) {
        for (NSInteger idx = 0; idx <= currentIndex && idx < reachedFlags.count; idx++) {
            reachedFlags[idx] = @YES;
        }
    }

    for (NSInteger idx = 0; idx < steps.count; idx++) {
        PPTimelineStep *step = steps[idx];
        BOOL isCurrent = (currentIndex != NSNotFound && idx == currentIndex);
        BOOL isReached = idx < reachedFlags.count ? reachedFlags[idx].boolValue : NO;
        step.current = isCurrent;
        step.completed = isReached && !isCurrent;
    }

    self.steps = steps.copy;

    NSInteger reachedCount = 0;
    for (PPTimelineStep *step in self.steps) {
        if (step.completed || step.current) {
            reachedCount += 1;
        }
    }
    if (self.steps.count > 0) {
        reachedCount = MAX(reachedCount, 1);
    }

    PPTimelineStep *emphasisStep = nil;
    if (currentIndex != NSNotFound && currentIndex < self.steps.count) {
        emphasisStep = self.steps[currentIndex];
    } else {
        for (NSInteger idx = self.steps.count - 1; idx >= 0; idx--) {
            PPTimelineStep *candidate = self.steps[idx];
            if (candidate.completed) {
                emphasisStep = candidate;
                break;
            }
        }
    }

    self.progressTintColor = emphasisStep.activeColor ?: AppPrimaryClr;
    self.progressValue = self.steps.count > 0 ? ((CGFloat)reachedCount / (CGFloat)self.steps.count) : 0.0;

    self.statusLabel.text = order.displayStatus.length ? [order displayStatus] : (emphasisStep.title ?: @"");
    self.summarySubtitleLabel.text = emphasisStep.subtitle ?: @"";
    self.summarySubtitleLabel.hidden = (self.summarySubtitleLabel.text.length == 0);
    self.progressRatioLabel.text = self.steps.count > 0 ? [NSString stringWithFormat:@"%ld/%ld", (long)reachedCount, (long)self.steps.count] : @"";
    self.progressRatioLabel.textColor = self.progressTintColor;

    [self rebuildStepRows];
    [self updateProgressAppearance];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)rebuildStepRows {
    for (UIView *arranged in self.stepsStack.arrangedSubviews) {
        [self.stepsStack removeArrangedSubview:arranged];
        [arranged removeFromSuperview];
    }

    for (NSInteger idx = 0; idx < self.steps.count; idx++) {
        PPTimelineStep *step = self.steps[idx];
        _PPTimelineStepRowView *rowView = [[_PPTimelineStepRowView alloc] init];
        [rowView configureWithStep:step isFirst:(idx == 0) isLast:(idx == self.steps.count - 1)];
        [self.stepsStack addArrangedSubview:rowView];
    }
}

- (void)updateProgressAppearance {
    UIColor *tintColor = self.progressTintColor ?: AppPrimaryClr;
    self.summarySurfaceView.layer.borderColor = [tintColor colorWithAlphaComponent:0.10].CGColor;
    self.progressFillLayer.colors = @[
        (__bridge id)[[tintColor colorWithAlphaComponent:0.72] CGColor],
        (__bridge id)[tintColor CGColor]
    ];
    self.progressGlowView.backgroundColor = tintColor;
    self.progressGlowView.layer.shadowColor = tintColor.CGColor;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    CGFloat headerHeight = self.summarySubtitleLabel.hidden ? 96.0 : 110.0;
    CGFloat totalHeight = headerHeight;

    for (NSInteger idx = 0; idx < self.steps.count; idx++) {
        PPTimelineStep *step = self.steps[idx];
        totalHeight += (step.subtitle.length > 0) ? 58.0 : 42.0;
        if (idx < self.steps.count - 1) {
            totalHeight += kTimelineStepSpacing;
        }
    }

    if (self.steps.count > 0) {
        totalHeight += 18.0;
    }

    return CGSizeMake(UIViewNoIntrinsicMetric, MAX(totalHeight, 44.0));
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat trackWidth = self.progressTrackView.bounds.size.width;
    CGFloat trackHeight = self.progressTrackView.bounds.size.height;
    CGFloat progressWidth = MAX(trackHeight, floor(trackWidth * MIN(MAX(self.progressValue, 0.0), 1.0)));
    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat fillOriginX = isRTL ? (trackWidth - progressWidth) : 0.0;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.progressFillLayer.frame = CGRectMake(fillOriginX, 0.0, progressWidth, trackHeight);
    self.progressFillLayer.cornerRadius = trackHeight / 2.0;
    [CATransaction commit];

    CGFloat glowCenterX = isRTL ? fillOriginX : CGRectGetMaxX(self.progressFillLayer.frame);
    self.progressGlowView.hidden = (progressWidth <= trackHeight + 1.0);
    self.progressGlowView.center = CGPointMake(glowCenterX, CGRectGetMidY(self.progressTrackView.bounds));
}

@end
