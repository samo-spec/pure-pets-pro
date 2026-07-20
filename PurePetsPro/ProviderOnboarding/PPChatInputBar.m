//
//  PPChatInputBar.m
//  PurePetsPro
//
//  ChatGPT-style floating input bar with auto-growing UITextView
//

#import "PPChatInputBar.h"
#import "Language.h"
#import "Styling.h"
#import "PrefixHeader.pch"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

static inline UIColor *PPChatInputBarBackgroundColor(void)
{
    if (@available(iOS 13.0, *)) return UIColor.systemBackgroundColor;
    return AppBackgroundClr ?: UIColor.whiteColor;
}

static inline UIColor *PPChatInputBarSurfaceColor(void)
{
    return AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
}

static inline UIColor *PPChatInputBarMatteColor(void)
{
    if (@available(iOS 13.0, *)) return UIColor.secondarySystemGroupedBackgroundColor;
    return [UIColor colorWithWhite:0.96 alpha:1.0];
}

static inline UIColor *PPChatInputBarPrimaryTextColor(void)
{
    return PrimaryTextClr ?: UIColor.labelColor;
}

static inline UIColor *PPChatInputBarSecondaryTextColor(void)
{
    return SeconderyTextClr ?: UIColor.secondaryLabelColor;
}

static inline CGFloat PPChatInputBarMinimumFittingHeight(void)
{
    return 70.0;
}

static inline NSString *PPChatInputBarDurationText(NSTimeInterval duration)
{
    NSInteger total = MAX(0, (NSInteger)llround(duration));
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

static inline CGFloat PPChatInputBarNormalizedPower(float averagePower)
{
    if (averagePower < -55.0f) return 0.08;
    CGFloat level = (averagePower + 55.0f) / 55.0f;
    return MAX(0.08, MIN(1.0, pow(level, 0.58)));
}

@interface PPChatRecordingWaveformView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *samples;
@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, strong) UIColor *idleColor;
- (void)appendSample:(CGFloat)sample;
- (void)resetSamples;
@end

@implementation PPChatRecordingWaveformView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _samples = @[];
        _barColor = AppPrimaryClr ?: UIColor.systemTealColor;
        _idleColor = [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.22];
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.isAccessibilityElement = NO;
    }
    return self;
}

- (void)appendSample:(CGFloat)sample
{
    NSMutableArray<NSNumber *> *next = [self.samples mutableCopy] ?: [NSMutableArray array];
    [next addObject:@(MAX(0.08, MIN(1.0, sample)))];
    if (next.count > 28) {
        [next removeObjectsInRange:NSMakeRange(0, next.count - 28)];
    }
    self.samples = next;
    [self setNeedsDisplay];
}

- (void)resetSamples
{
    self.samples = @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    NSInteger barCount = 28;
    CGFloat spacing = 3.0;
    CGFloat barWidth = MAX(2.0, floor((CGRectGetWidth(rect) - (spacing * (barCount - 1))) / barCount));
    CGFloat centerY = CGRectGetMidY(rect);
    CGFloat maxHeight = MAX(10.0, CGRectGetHeight(rect) * 0.76);
    BOOL isRTL = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    for (NSInteger index = 0; index < barCount; index++) {
        NSInteger sampleIndex = self.samples.count - barCount + index;
        BOOL hasSample = sampleIndex >= 0 && sampleIndex < (NSInteger)self.samples.count;
        CGFloat level = hasSample ? MAX(0.08, MIN(1.0, self.samples[sampleIndex].doubleValue)) : 0.12;
        CGFloat height = MAX(4.0, maxHeight * level);
        CGFloat visualIndex = isRTL ? (barCount - 1 - index) : index;
        CGRect barRect = CGRectMake(visualIndex * (barWidth + spacing), centerY - (height / 2.0), barWidth, height);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:barRect cornerRadius:barWidth / 2.0];
        UIColor *color = hasSample ? self.barColor : self.idleColor;
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextAddPath(ctx, path.CGPath);
        CGContextFillPath(ctx);
    }
}

@end

@interface PPChatInputBar () <AVAudioRecorderDelegate>
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *sendHaloView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *attachmentButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIActivityIndicatorView *sendActivityIndicator;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *recordingTimerLabel;
@property (nonatomic, strong) UILabel *recordingHintLabel;
@property (nonatomic, strong) UIView *recordingDotView;
@property (nonatomic, strong) PPChatRecordingWaveformView *recordingWaveformView;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, assign) CGFloat currentHeight;
@property (nonatomic, assign) BOOL isUpdatingHeight;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, assign) BOOL recordingActive;
@property (nonatomic, assign) BOOL inputEnabled;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) NSURL *recordingURL;
@property (nonatomic, strong) NSDate *recordingStartDate;
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *recordingSamples;
- (void)pp_hideKeyboardAssistantItems;
@end

@implementation PPChatInputBar

@synthesize textView = _textView;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

- (void)pp_commonInit
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.minHeight = PPChatInputBarMinimumFittingHeight();
    self.maxHeight = 140.0;
    self.currentHeight = self.minHeight;
    _inputEnabled = YES;
    self.recordingSamples = [NSMutableArray array];

    [self pp_setupSurfaceView];
    [self pp_setupTextView];
    [self pp_setupAttachmentButton];
    [self pp_setupSendButton];
    [self pp_setupPlaceholderLabel];
    [self pp_setupRecordingViews];
    [self pp_setupConstraints];
    [self pp_setupKeyboardNotifications];
}

- (void)pp_setupSurfaceView
{
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [PPChatInputBarSurfaceColor() colorWithAlphaComponent:0.78];
    self.surfaceView.layer.cornerRadius = 26.0;
    self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.surfaceView.layer.borderColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.14].CGColor;
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.surfaceView.layer.shadowRadius = 24.0;
    self.surfaceView.layer.shadowOpacity = 0.065;
    [self addSubview:self.surfaceView];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        blur.layer.cornerRadius = 26.0;
        blur.layer.cornerCurve = kCACornerCurveContinuous;
        [self.surfaceView insertSubview:blur atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blur.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
            [blur.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        ]];
    }
}

- (void)pp_setupTextView
{
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.delegate = self;
    self.textView.font = [Styling fontMedium:15.0];
    self.textView.textColor = PPChatInputBarPrimaryTextColor();
    self.textView.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    self.textView.backgroundColor = UIColor.clearColor;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.textView.textContainerInset = UIEdgeInsetsMake(10.0, 4.0, 10.0, 4.0);
    self.textView.textContainer.lineFragmentPadding = 0.0;
    self.textView.showsHorizontalScrollIndicator = NO;
    self.textView.showsVerticalScrollIndicator = NO;
    self.textView.scrollEnabled = YES;
    self.textView.scrollsToTop = NO;
    self.textView.returnKeyType = UIReturnKeySend;
    self.textView.enablesReturnKeyAutomatically = YES;
    [self pp_hideKeyboardAssistantItems];
    [self.surfaceView addSubview:self.textView];
}

- (void)pp_setupAttachmentButton
{
    self.attachmentButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.attachmentButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.attachmentButton.tintColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightMedium];
    UIImage *recordIcon = [[UIImage systemImageNamed:@"mic.fill"] imageByApplyingSymbolConfiguration:config];
    [self.attachmentButton setImage:recordIcon forState:UIControlStateNormal];
    [self.attachmentButton addTarget:self action:@selector(pp_attachmentButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.attachmentButton.accessibilityLabel = kLang(@"ch_provider_record_accessibility");
    [self.surfaceView addSubview:self.attachmentButton];
}

- (void)pp_setupSendButton
{
    self.sendHaloView = [[UIView alloc] init];
    self.sendHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendHaloView.backgroundColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.10];
    self.sendHaloView.layer.cornerRadius = 21.0;
    self.sendHaloView.layer.cornerCurve = kCACornerCurveContinuous;
    self.sendHaloView.alpha = 0.0;
    [self.surfaceView addSubview:self.sendHaloView];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendButton.tintColor = [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.70];
    self.sendButton.backgroundColor = [PPChatInputBarMatteColor() colorWithAlphaComponent:0.92];
    self.sendButton.layer.cornerRadius = 18.0;
    self.sendButton.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightBold];
    UIImage *sendIcon = [[UIImage systemImageNamed:@"paperplane.fill"] imageByApplyingSymbolConfiguration:config];
    [self.sendButton setImage:sendIcon forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(pp_sendButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.enabled = NO;
    self.sendButton.alpha = 0.45;
    self.sendButton.accessibilityLabel = kLang(@"ch_provider_send_accessibility");
    [self.surfaceView addSubview:self.sendButton];

    UIActivityIndicatorViewStyle indicatorStyle;
    if (@available(iOS 13.0, *)) {
        indicatorStyle = UIActivityIndicatorViewStyleMedium;
    } else {
        indicatorStyle = UIActivityIndicatorViewStyleWhite;
    }
    self.sendActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle];
    self.sendActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.sendActivityIndicator.color = UIColor.whiteColor;
    self.sendActivityIndicator.hidesWhenStopped = YES;
    [self.sendButton addSubview:self.sendActivityIndicator];
}

- (void)pp_setupPlaceholderLabel
{
    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.font = [Styling fontMedium:15.0];
    self.placeholderLabel.textColor = [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.64];
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.placeholderLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.placeholderLabel.text = kLang(@"ch_provider_reply");
    [self.surfaceView addSubview:self.placeholderLabel];
}

- (void)pp_setupRecordingViews
{
    self.recordingDotView = [[UIView alloc] init];
    self.recordingDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingDotView.backgroundColor = UIColor.systemRedColor;
    self.recordingDotView.layer.cornerRadius = 4.0;
    self.recordingDotView.alpha = 0.0;
    self.recordingDotView.hidden = YES;
    [self.surfaceView addSubview:self.recordingDotView];

    self.recordingTimerLabel = [[UILabel alloc] init];
    self.recordingTimerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingTimerLabel.font = [Styling fontBold:13.0];
    self.recordingTimerLabel.textColor = PPChatInputBarPrimaryTextColor();
    self.recordingTimerLabel.textAlignment = NSTextAlignmentNatural;
    self.recordingTimerLabel.text = @"0:00";
    self.recordingTimerLabel.alpha = 0.0;
    self.recordingTimerLabel.hidden = YES;
    [self.surfaceView addSubview:self.recordingTimerLabel];

    self.recordingWaveformView = [[PPChatRecordingWaveformView alloc] init];
    self.recordingWaveformView.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingWaveformView.alpha = 0.0;
    self.recordingWaveformView.hidden = YES;
    self.recordingWaveformView.barColor = AppPrimaryClr ?: UIColor.systemTealColor;
    self.recordingWaveformView.idleColor = [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.18];
    [self.surfaceView addSubview:self.recordingWaveformView];

    self.recordingHintLabel = [[UILabel alloc] init];
    self.recordingHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingHintLabel.font = [Styling fontMedium:11.5];
    self.recordingHintLabel.textColor = [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.76];
    self.recordingHintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.recordingHintLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.recordingHintLabel.text = kLang(@"ch_provider_recording_hint");
    self.recordingHintLabel.alpha = 0.0;
    self.recordingHintLabel.hidden = YES;
    [self.surfaceView addSubview:self.recordingHintLabel];
}

- (void)pp_setupConstraints
{
    self.heightConstraint = [self.heightAnchor constraintEqualToConstant:self.minHeight];
    self.heightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:8.0],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8.0],
        [self.surfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:54.0],

        [self.attachmentButton.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:12.0],
        [self.attachmentButton.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.attachmentButton.widthAnchor constraintEqualToConstant:36.0],
        [self.attachmentButton.heightAnchor constraintEqualToConstant:36.0],

        [self.sendHaloView.centerXAnchor constraintEqualToAnchor:self.sendButton.centerXAnchor],
        [self.sendHaloView.centerYAnchor constraintEqualToAnchor:self.sendButton.centerYAnchor],
        [self.sendHaloView.widthAnchor constraintEqualToConstant:42.0],
        [self.sendHaloView.heightAnchor constraintEqualToConstant:42.0],

        [self.sendButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-8.0],
        [self.sendButton.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.sendButton.widthAnchor constraintEqualToConstant:36.0],
        [self.sendButton.heightAnchor constraintEqualToConstant:36.0],

        [self.sendActivityIndicator.centerXAnchor constraintEqualToAnchor:self.sendButton.centerXAnchor],
        [self.sendActivityIndicator.centerYAnchor constraintEqualToAnchor:self.sendButton.centerYAnchor],

        [self.textView.leadingAnchor constraintEqualToAnchor:self.attachmentButton.trailingAnchor constant:8.0],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.sendButton.leadingAnchor constant:-8.0],
        [self.textView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:8.0],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-8.0],

        [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.textView.leadingAnchor constant:12.0],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
        [self.placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.textView.trailingAnchor constant:-8.0],

        [self.recordingDotView.leadingAnchor constraintEqualToAnchor:self.attachmentButton.trailingAnchor constant:10.0],
        [self.recordingDotView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor constant:-7.0],
        [self.recordingDotView.widthAnchor constraintEqualToConstant:8.0],
        [self.recordingDotView.heightAnchor constraintEqualToConstant:8.0],

        [self.recordingTimerLabel.leadingAnchor constraintEqualToAnchor:self.recordingDotView.trailingAnchor constant:8.0],
        [self.recordingTimerLabel.centerYAnchor constraintEqualToAnchor:self.recordingDotView.centerYAnchor],
        [self.recordingTimerLabel.widthAnchor constraintGreaterThanOrEqualToConstant:42.0],

        [self.recordingWaveformView.leadingAnchor constraintEqualToAnchor:self.recordingTimerLabel.trailingAnchor constant:10.0],
        [self.recordingWaveformView.trailingAnchor constraintEqualToAnchor:self.sendButton.leadingAnchor constant:-10.0],
        [self.recordingWaveformView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.recordingWaveformView.heightAnchor constraintEqualToConstant:26.0],

        [self.recordingHintLabel.topAnchor constraintEqualToAnchor:self.recordingTimerLabel.bottomAnchor constant:1.0],
        [self.recordingHintLabel.leadingAnchor constraintEqualToAnchor:self.recordingTimerLabel.leadingAnchor],
        [self.recordingHintLabel.trailingAnchor constraintEqualToAnchor:self.recordingWaveformView.trailingAnchor],
    ]];

    self.textViewHeightConstraint = [self.textView.heightAnchor constraintGreaterThanOrEqualToConstant:self.minHeight - 16.0];
    self.textViewHeightConstraint.active = YES;
}

- (void)pp_setupKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_audioSessionInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self pp_cancelRecordingNotifyDelegate:NO];
}

#pragma mark - Public Methods

- (BOOL)isRecording
{
    return self.recordingActive;
}

- (void)setIsRecording:(BOOL)isRecording
{
    [self setRecording:isRecording];
}

- (void)clearInput
{
    self.textView.text = @"";
    [self pp_updatePlaceholderVisibility];
    [self pp_updateSendButtonState];
    [self pp_adjustHeight];
}

- (void)setInputEnabled:(BOOL)enabled
{
    _inputEnabled = enabled;
    self.textView.editable = enabled && !self.recordingActive;
    self.textView.selectable = enabled && !self.recordingActive;
    self.attachmentButton.enabled = enabled || self.recordingActive;
    self.sendButton.enabled = self.recordingActive || self.sending || (enabled && self.textView.text.length > 0);
    self.attachmentButton.alpha = (enabled || self.recordingActive) ? 1.0 : 0.35;
    [self pp_updateSendButtonState];
}

- (void)setMinHeight:(CGFloat)minHeight
{
    CGFloat fittingMinHeight = MAX(minHeight, PPChatInputBarMinimumFittingHeight());
    _minHeight = fittingMinHeight;
    if (self.heightConstraint) {
        self.currentHeight = MAX(self.currentHeight, fittingMinHeight);
        self.heightConstraint.constant = MAX(self.heightConstraint.constant, fittingMinHeight);
    }
    if (self.textViewHeightConstraint) {
        self.textViewHeightConstraint.constant = MAX(0.0, fittingMinHeight - 16.0);
    }
    if (self.maxHeight < fittingMinHeight) {
        _maxHeight = fittingMinHeight;
    }
    if (self.textView) {
        [self pp_adjustHeight];
    }
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _maxHeight = MAX(maxHeight, self.minHeight);
    if (self.textView) {
        [self pp_adjustHeight];
    }
}

- (void)setSending:(BOOL)sending
{
    _sending = sending;
    [self pp_updateSendButtonState];
}

- (void)setRecording:(BOOL)recording
{
    if (recording) {
        [self pp_startRecordingFlow];
    } else {
        [self pp_cancelRecordingNotifyDelegate:NO];
    }
}

- (void)cancelRecording
{
    [self pp_cancelRecordingNotifyDelegate:NO];
}

- (void)setPlaceholder:(NSString *)placeholder
{
    _placeholder = placeholder;
    self.placeholderLabel.text = placeholder.length > 0 ? placeholder : kLang(@"ch_provider_reply");
}

#pragma mark - Private Methods

- (void)pp_updatePlaceholderVisibility
{
    BOOL showPlaceholder = self.textView.text.length == 0 && !self.recordingActive;
    self.placeholderLabel.hidden = !showPlaceholder;
}

- (void)pp_updateSendButtonState
{
    BOOL hasText = [self.textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
    BOOL enabled = (hasText && self.inputEnabled && !self.sending) || self.recordingActive;
    self.sendButton.enabled = enabled || self.sending;

    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *recordAccent = UIColor.systemRedColor;
    UIImageSymbolConfiguration *sendConfig = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightBold];
    UIImageSymbolConfiguration *micConfig = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightMedium];
    UIImage *sendIcon = [[UIImage systemImageNamed:@"paperplane.fill"] imageByApplyingSymbolConfiguration:sendConfig];
    UIImage *leadingIcon = [[UIImage systemImageNamed:self.recordingActive ? @"xmark" : @"mic.fill"] imageByApplyingSymbolConfiguration:micConfig];
    [self.sendButton setImage:sendIcon forState:UIControlStateNormal];
    [self.attachmentButton setImage:leadingIcon forState:UIControlStateNormal];
    self.sendButton.accessibilityLabel = self.recordingActive ? kLang(@"ch_provider_record_finish_accessibility") : kLang(@"ch_provider_send_accessibility");
    self.attachmentButton.accessibilityLabel = self.recordingActive ? kLang(@"ch_provider_record_cancel_accessibility") : kLang(@"ch_provider_record_accessibility");

    void (^updates)(void) = ^{
        self.sendButton.alpha = (enabled || self.sending) ? 1.0 : 0.45;
        self.sendButton.backgroundColor = self.recordingActive ? recordAccent : ((enabled || self.sending) ? accent : [PPChatInputBarMatteColor() colorWithAlphaComponent:0.92]);
        self.sendButton.tintColor = (enabled || self.sending) ? UIColor.whiteColor : [PPChatInputBarSecondaryTextColor() colorWithAlphaComponent:0.70];
        self.sendButton.transform = (enabled || self.sending) ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.92, 0.92);
        self.sendHaloView.backgroundColor = [(self.recordingActive ? recordAccent : accent) colorWithAlphaComponent:self.recordingActive ? 0.16 : 0.10];
        self.sendHaloView.alpha = enabled ? 1.0 : 0.0;
        self.sendButton.imageView.alpha = self.sending ? 0.0 : 1.0;
        self.attachmentButton.tintColor = self.recordingActive ? recordAccent : accent;
    };

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:updates completion:nil];
    } else {
        updates();
    }

    if (self.sending) {
        [self.sendActivityIndicator startAnimating];
    } else {
        [self.sendActivityIndicator stopAnimating];
    }
}

- (void)pp_adjustHeight
{
    if (self.isUpdatingHeight) return;
    self.isUpdatingHeight = YES;

    CGFloat minHeight = self.minHeight;
    CGFloat maxHeight = self.maxHeight;

    CGFloat availableWidth = self.textView.bounds.size.width;
    if (availableWidth <= 0) {
        availableWidth = self.bounds.size.width - 80.0;
    }

    CGSize fittingSize = [self.textView sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)];
    CGFloat requiredHeight = fittingSize.height + 16.0;
    CGFloat newHeight = self.recordingActive ? minHeight : MAX(minHeight, MIN(requiredHeight, maxHeight));

    if (fabs(newHeight - self.currentHeight) > 0.5) {
        self.currentHeight = newHeight;
        self.heightConstraint.constant = newHeight;

        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
            [self layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.isUpdatingHeight = NO;
            if ([self.delegate respondsToSelector:@selector(chatInputBar:heightDidChange:)]) {
                [self.delegate chatInputBar:self heightDidChange:newHeight];
            }
        }];
    } else {
        self.isUpdatingHeight = NO;
    }
}

- (NSURL *)pp_newRecordingURL
{
    NSString *fileName = [NSString stringWithFormat:@"pp_pro_voice_%@.m4a", NSUUID.UUID.UUIDString];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
}

- (NSDictionary *)pp_audioRecorderSettings
{
    return @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };
}

- (void)pp_startRecordingFlow
{
    if (self.recordingActive || self.sending || !self.inputEnabled) return;

    AVAudioSession *session = AVAudioSession.sharedInstance;
    AVAudioSessionRecordPermission permission = session.recordPermission;
    if (permission == AVAudioSessionRecordPermissionDenied) {
        if ([self.delegate respondsToSelector:@selector(chatInputBarRecordingPermissionDenied:)]) {
            [self.delegate chatInputBarRecordingPermissionDenied:self];
        } else {
            [PPToast toast:kLang(@"ch_provider_record_permission_message")];
        }
        return;
    }

    if (permission == AVAudioSessionRecordPermissionUndetermined) {
        __weak typeof(self) weakSelf = self;
        [session requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                if (granted) {
                    [strongSelf pp_beginRecording];
                } else if ([strongSelf.delegate respondsToSelector:@selector(chatInputBarRecordingPermissionDenied:)]) {
                    [strongSelf.delegate chatInputBarRecordingPermissionDenied:strongSelf];
                } else {
                    [PPToast toast:kLang(@"ch_provider_record_permission_message")];
                }
            });
        }];
        return;
    }

    [self pp_beginRecording];
}

- (void)pp_beginRecording
{
    [self.textView resignFirstResponder];

    AVAudioSession *session = AVAudioSession.sharedInstance;
    NSError *sessionError = nil;
    BOOL didSetCategory = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                   withOptions:(AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth)
                                         error:&sessionError];
    BOOL didActivate = didSetCategory && [session setActive:YES error:&sessionError];
    if (!didActivate || sessionError) {
        [self pp_failRecordingWithError:sessionError];
        return;
    }

    self.recordingURL = [self pp_newRecordingURL];
    self.recordingStartDate = NSDate.date;
    self.recordingSamples = [NSMutableArray array];
    [self.recordingWaveformView resetSamples];

    NSError *recorderError = nil;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.recordingURL settings:[self pp_audioRecorderSettings] error:&recorderError];
    if (!self.audioRecorder || recorderError) {
        [self pp_failRecordingWithError:recorderError];
        return;
    }

    self.audioRecorder.delegate = self;
    self.audioRecorder.meteringEnabled = YES;
    [self.audioRecorder prepareToRecord];
    if (![self.audioRecorder record]) {
        [self pp_failRecordingWithError:nil];
        return;
    }

    self.recordingActive = YES;
    [self pp_setRecordingUIActive:YES animated:YES];
    [self pp_startRecordingTimer];
    [self pp_adjustHeight];
    [self pp_fireImpact:UIImpactFeedbackStyleMedium];

    if ([self.delegate respondsToSelector:@selector(chatInputBarDidStartRecording:)]) {
        [self.delegate chatInputBarDidStartRecording:self];
    }
}

- (void)pp_startRecordingTimer
{
    [self pp_stopRecordingTimer];
    self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.12 target:self selector:@selector(pp_tickRecording) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.recordingTimer forMode:NSRunLoopCommonModes];
    [self pp_tickRecording];
}

- (void)pp_stopRecordingTimer
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
}

- (void)pp_tickRecording
{
    if (!self.recordingActive || !self.audioRecorder) return;

    [self.audioRecorder updateMeters];
    NSTimeInterval duration = [NSDate.date timeIntervalSinceDate:self.recordingStartDate ?: NSDate.date];
    self.recordingTimerLabel.text = PPChatInputBarDurationText(duration);
    CGFloat sample = PPChatInputBarNormalizedPower([self.audioRecorder averagePowerForChannel:0]);
    [self.recordingSamples addObject:@(sample)];
    if (self.recordingSamples.count > 40) {
        [self.recordingSamples removeObjectsInRange:NSMakeRange(0, self.recordingSamples.count - 40)];
    }
    [self.recordingWaveformView appendSample:sample];
}

- (void)pp_finishRecording
{
    if (!self.recordingActive || !self.audioRecorder) return;

    NSTimeInterval duration = [NSDate.date timeIntervalSinceDate:self.recordingStartDate ?: NSDate.date];
    NSURL *fileURL = self.recordingURL;
    NSArray<NSNumber *> *samples = [self.recordingSamples copy] ?: @[];

    [self pp_stopRecordingTimer];
    [self.audioRecorder stop];
    self.audioRecorder = nil;
    self.recordingActive = NO;
    [self pp_setAudioSessionInactive];

    if (duration < 0.55 || fileURL.path.length == 0) {
        [self pp_deleteRecordingAtURL:fileURL];
        [self pp_resetRecordingStateAnimated:YES];
        [PPToast toast:kLang(@"ch_provider_record_too_short")];
        [self pp_fireImpact:UIImpactFeedbackStyleLight];
        return;
    }

    [self pp_resetRecordingStateAnimated:YES];
    [self pp_fireNotificationSuccess];

    if ([self.delegate respondsToSelector:@selector(chatInputBar:didFinishRecordingAtURL:duration:waveformSamples:)]) {
        [self.delegate chatInputBar:self didFinishRecordingAtURL:fileURL duration:duration waveformSamples:samples];
    }
}

- (void)pp_cancelRecordingNotifyDelegate:(BOOL)notifyDelegate
{
    if (!self.recordingActive && !self.audioRecorder && !self.recordingURL) return;

    NSURL *fileURL = self.recordingURL;
    [self pp_stopRecordingTimer];
    if (self.audioRecorder.isRecording) {
        [self.audioRecorder stop];
    }
    self.audioRecorder = nil;
    self.recordingActive = NO;
    [self pp_setAudioSessionInactive];
    [self pp_deleteRecordingAtURL:fileURL];
    [self pp_resetRecordingStateAnimated:YES];
    [self pp_fireImpact:UIImpactFeedbackStyleLight];

    if (notifyDelegate && [self.delegate respondsToSelector:@selector(chatInputBarDidCancelRecording:)]) {
        [self.delegate chatInputBarDidCancelRecording:self];
    }
}

- (void)pp_failRecordingWithError:(NSError *)error
{
    [self pp_stopRecordingTimer];
    self.recordingActive = NO;
    self.audioRecorder = nil;
    [self pp_setAudioSessionInactive];
    [self pp_deleteRecordingAtURL:self.recordingURL];
    [self pp_resetRecordingStateAnimated:YES];

    if ([self.delegate respondsToSelector:@selector(chatInputBar:didFailRecordingWithError:)]) {
        NSError *safeError = error ?: [NSError errorWithDomain:@"PPChatInputBarRecording" code:-1 userInfo:@{NSLocalizedDescriptionKey: kLang(@"ch_provider_record_failed")}];
        [self.delegate chatInputBar:self didFailRecordingWithError:safeError];
    } else {
        [PPToast toast:kLang(@"ch_provider_record_failed")];
    }
}

- (void)pp_setAudioSessionInactive
{
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)pp_deleteRecordingAtURL:(NSURL *)url
{
    if (url.path.length == 0) return;
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
}

- (void)pp_resetRecordingStateAnimated:(BOOL)animated
{
    self.recordingURL = nil;
    self.recordingStartDate = nil;
    self.recordingSamples = [NSMutableArray array];
    [self.recordingWaveformView resetSamples];
    self.recordingTimerLabel.text = @"0:00";
    [self pp_setRecordingUIActive:NO animated:animated];
    [self pp_adjustHeight];
}

- (void)pp_setRecordingUIActive:(BOOL)active animated:(BOOL)animated
{
    self.textView.editable = self.inputEnabled && !active;
    self.textView.selectable = self.inputEnabled && !active;
    self.recordingDotView.hidden = NO;
    self.recordingTimerLabel.hidden = NO;
    self.recordingWaveformView.hidden = NO;
    self.recordingHintLabel.hidden = NO;
    self.placeholderLabel.hidden = active || self.textView.text.length > 0;

    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *recordColor = UIColor.systemRedColor;
    void (^updates)(void) = ^{
        self.textView.alpha = active ? 0.0 : 1.0;
        self.placeholderLabel.alpha = active ? 0.0 : 1.0;
        self.recordingDotView.alpha = active ? 1.0 : 0.0;
        self.recordingTimerLabel.alpha = active ? 1.0 : 0.0;
        self.recordingWaveformView.alpha = active ? 1.0 : 0.0;
        self.recordingHintLabel.alpha = active ? 1.0 : 0.0;
        self.surfaceView.layer.borderColor = [(active ? recordColor : accent) colorWithAlphaComponent:active ? 0.28 : 0.14].CGColor;
        self.surfaceView.transform = active ? CGAffineTransformMakeScale(1.012, 1.012) : CGAffineTransformIdentity;
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        if (!active) {
            self.recordingDotView.hidden = YES;
            self.recordingTimerLabel.hidden = YES;
            self.recordingWaveformView.hidden = YES;
            self.recordingHintLabel.hidden = YES;
            [self pp_updatePlaceholderVisibility];
        }
    };

    [self pp_updateSendButtonState];
    [self pp_updateRecordingPulseActive:active];
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.24 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:updates completion:completion];
    } else {
        updates();
        completion(YES);
    }
}

- (void)pp_updateRecordingPulseActive:(BOOL)active
{
    [self.recordingDotView.layer removeAnimationForKey:@"pp_recording_pulse"];
    if (!active || UIAccessibilityIsReduceMotionEnabled()) {
        self.recordingDotView.alpha = active ? 1.0 : 0.0;
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @1.0;
    pulse.toValue = @0.36;
    pulse.duration = 0.74;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.recordingDotView.layer addAnimation:pulse forKey:@"pp_recording_pulse"];
}

- (void)pp_fireImpact:(UIImpactFeedbackStyle)style
{
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator impactOccurred];
    }
}

- (void)pp_fireNotificationSuccess
{
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
}

#pragma mark - Actions

- (void)pp_attachmentButtonTapped
{
    [self pp_performTapResponseOnView:self.attachmentButton];
    if (self.recordingActive) {
        [self pp_cancelRecordingNotifyDelegate:YES];
        return;
    }
    [self pp_startRecordingFlow];
}

- (void)pp_sendButtonTapped
{
    if (self.recordingActive) {
        [self pp_performTapResponseOnView:self.sendButton];
        [self pp_finishRecording];
        return;
    }

    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0 || self.sending) return;
    [self pp_performTapResponseOnView:self.sendButton];

    if ([self.delegate respondsToSelector:@selector(chatInputBar:didTapSendWithText:)]) {
        [self.delegate chatInputBar:self didTapSendWithText:text];
    }
}

- (void)pp_performTapResponseOnView:(UIView *)view
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.08 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        view.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.16 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Keyboard Notifications

- (void)pp_keyboardWillShow:(NSNotification *)notification
{
    // Keyboard handling is managed by the parent view controller.
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    // Keyboard handling is managed by the parent view controller.
}

- (void)pp_audioSessionInterrupted:(NSNotification *)notification
{
    NSNumber *typeValue = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    if (typeValue.integerValue == AVAudioSessionInterruptionTypeBegan) {
        [self pp_cancelRecordingNotifyDelegate:YES];
    }
}

- (void)pp_applicationWillResignActive:(NSNotification *)notification
{
    [self pp_cancelRecordingNotifyDelegate:YES];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    [self pp_updatePlaceholderVisibility];
    [self pp_updateSendButtonState];
    [self pp_adjustHeight];

    if ([self.delegate respondsToSelector:@selector(chatInputBar:textDidChange:)]) {
        [self.delegate chatInputBar:self textDidChange:textView.text];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        if (textView.text.length > 0) {
            [self pp_sendButtonTapped];
        }
        return NO;
    }
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self pp_hideKeyboardAssistantItems];
    [self pp_updatePlaceholderVisibility];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    [self pp_hideKeyboardAssistantItems];
    return self.inputEnabled && !self.recordingActive;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self pp_hideKeyboardAssistantItems];
}

- (void)pp_hideKeyboardAssistantItems
{
    if (@available(iOS 9.0, *)) {
        UITextInputAssistantItem *assistantItem = self.textView.inputAssistantItem;
        assistantItem.leadingBarButtonGroups = @[];
        assistantItem.trailingBarButtonGroups = @[];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self pp_updatePlaceholderVisibility];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    [self pp_failRecordingWithError:error];
}

@end
