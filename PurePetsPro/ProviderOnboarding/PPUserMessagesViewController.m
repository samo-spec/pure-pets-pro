//
//  PPUserMessagesViewController.m
//  PurePetsPro
//

#import "PPUserMessagesViewController.h"
#import "ChatThreadModel.h"
#import "Language.h"
#import "Styling.h"
#import "UserModel.h"
#import "PPChatInputBar.h"
#import "PPToast.h"

@import Firebase;
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseFunctions;
@import FirebaseMessaging;

#import "PPFirebaseCompat.h"
#import "UIImageView+WebCache.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <FirebaseAuth/FirebaseAuth.h>
 
#import <AVFoundation/AVFoundation.h>
#import <math.h>
#import <IQKeyboardManager/IQKeyboardManager.h>

// Keep this lifecycle aligned with Pure Pets iOS ChatMessageStatus.
static const NSInteger PPMessageStatusSending = 0;
static const NSInteger PPMessageStatusSent = 1;
static const NSInteger PPMessageStatusDelivered = 2;
static const NSInteger PPMessageStatusRead = 3;
static const NSInteger PPMessageInitialPageLimit = 50;
static const NSInteger PPMessagePageStep = 50;

static NSString *PPMessageTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSDate *PPMessageDateFromValue(id value)
{
    if ([value isKindOfClass:NSDate.class]) return (NSDate *)value;
    if ([value isKindOfClass:FIRTimestamp.class]) return [(FIRTimestamp *)value dateValue];
    if ([value isKindOfClass:NSNumber.class]) return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
    return nil;
}

static NSInteger PPMessageStatusValue(id status)
{
    if ([status isKindOfClass:NSNumber.class]) return [(NSNumber *)status integerValue];
    NSString *normalized = [PPMessageTrimmedString(status) lowercaseString];
    if ([normalized isEqualToString:@"sending"]) return PPMessageStatusSending;
    if ([normalized isEqualToString:@"sent"]) return PPMessageStatusSent;
    if ([normalized isEqualToString:@"delivered"]) return PPMessageStatusDelivered;
    if ([normalized isEqualToString:@"read"]) return PPMessageStatusRead;
    return PPMessageStatusSent;
}

static UIFont *PPMessageScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static NSString *PPMessageStatusText(id status)
{
    NSInteger value = PPMessageStatusValue(status);
    if (value == PPMessageStatusRead) return kLang(@"ch_provider_message_read");
    if (value == PPMessageStatusDelivered) return kLang(@"ch_provider_message_delivered");
    if (value == PPMessageStatusSending) return kLang(@"ch_provider_message_sending");
    NSString *normalized = [PPMessageTrimmedString(status) lowercaseString];
    if ([normalized isEqualToString:@"failed"]) return kLang(@"ch_provider_message_failed");
    return kLang(@"ch_provider_message_sent");
}

static NSInteger PPMessageTypeValue(id value)
{
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value integerValue];
    NSString *text = [PPMessageTrimmedString(value) lowercaseString];
    if ([text isEqualToString:@"audio"] || [text isEqualToString:@"voice"]) return 2;
    if ([text isEqualToString:@"image"]) return 1;
    if ([text isEqualToString:@"video"]) return 3;
    if ([text isEqualToString:@"file"]) return 4;
    return 0;
}

static BOOL PPMessageIsAudioMessage(NSDictionary *message)
{
    if (PPMessageTypeValue(message[@"type"]) == 2) return YES;
    NSString *mimeType = [PPMessageTrimmedString(message[@"mimeType"] ?: message[@"mime_type"]) lowercaseString];
    if ([mimeType hasPrefix:@"audio/"]) return YES;
    NSString *fileURL = PPMessageTrimmedString(message[@"fileURL"] ?: message[@"file_url"]);
    return fileURL.length > 0 && ([fileURL.lowercaseString containsString:@".m4a"] || [fileURL.lowercaseString containsString:@"audio"]);
}

static NSString *PPMessageFileURLString(NSDictionary *message)
{
    return PPMessageTrimmedString(message[@"fileURL"] ?: message[@"file_url"]);
}

static NSTimeInterval PPMessageMediaDuration(NSDictionary *message)
{
    id value = message[@"mediaDuration"] ?: message[@"media_duration"];
    if ([value respondsToSelector:@selector(doubleValue)]) return [value doubleValue];
    return 0;
}

static NSString *PPMessageDurationText(NSTimeInterval duration)
{
    NSInteger total = MAX(0, (NSInteger)llround(duration));
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

static NSArray<NSNumber *> *PPMessageWaveformSamples(NSDictionary *message)
{
    id waveform = message[@"waveform"];
    if (![waveform isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSNumber *> *clean = [NSMutableArray array];
    for (id value in (NSArray *)waveform) {
        if ([value respondsToSelector:@selector(doubleValue)]) {
            [clean addObject:@(MAX(0.06, MIN(1.0, [value doubleValue])))];
        }
    }
    return clean;
}

static NSString *PPMessageCountText(NSInteger count)
{
    if (count <= 0) return kLang(@"ch_provider_no_messages");
    if (count == 1) return kLang(@"ch_provider_thread_one_message");
    return [NSString stringWithFormat:kLang(@"ch_provider_thread_messages_count_format"), (long)count];
}

static UIColor *PPMessageBackgroundColor(void)
{
    if (@available(iOS 13.0, *)) return [UIColor ppSurface];
    return AppBackgroundClr;
}

static UIColor *PPMessageSurfaceColor(void)
{
    return AppForgroundColr;
}

static UIColor *PPMessageMatteColor(void)
{
    return [UIColor ppBackground];
}

static UIColor *PPMessagePrimaryTextColor(void)
{
    return PrimaryTextClr;
}

static UIColor *PPMessageSecondaryTextColor(void)
{
    return SeconderyTextClr;
}

static NSString *PPMessageInitialForName(NSString *name)
{
    NSString *trimmed = PPMessageTrimmedString(name);
    if (trimmed.length == 0) return @"?";
    NSRange firstCharacterRange = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
    return [[trimmed substringWithRange:firstCharacterRange] uppercaseString];
}

static NSString *PPMessageLocalizedParticipantType(NSString *participantType)
{
    if ([participantType isEqualToString:PPChatParticipantTypeConsole]) {
        return kLang(@"ch_identity_console");
    }
    if ([participantType isEqualToString:PPChatParticipantTypeProvider]) {
        return kLang(@"ch_identity_provider");
    }
    return kLang(@"ch_identity_user");
}

static UIColor *PPMessageParticipantTypeColor(NSString *participantType)
{
    if ([participantType isEqualToString:PPChatParticipantTypeConsole]) {
        return [UIColor ppQuickActionCommunity];
    }
    if ([participantType isEqualToString:PPChatParticipantTypeProvider]) {
        return AppPrimaryClr;
    }
    return PPMessageSecondaryTextColor();
}

@interface PPMessageVoiceWaveformView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *samples;
@property (nonatomic, strong) UIColor *activeColor;
@property (nonatomic, strong) UIColor *inactiveColor;
@end

@implementation PPMessageVoiceWaveformView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _samples = @[];
        _activeColor = AppPrimaryClr;
        _inactiveColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.22];
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.isAccessibilityElement = NO;
    }
    return self;
}

- (void)setSamples:(NSArray<NSNumber *> *)samples
{
    _samples = [samples copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    NSInteger barCount = 24;
    CGFloat spacing = 3.0;
    CGFloat barWidth = MAX(2.0, floor((CGRectGetWidth(rect) - (spacing * (barCount - 1))) / barCount));
    CGFloat maxHeight = MAX(8.0, CGRectGetHeight(rect) * 0.76);
    CGFloat centerY = CGRectGetMidY(rect);
    BOOL isRTL = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    for (NSInteger index = 0; index < barCount; index++) {
        NSInteger sampleIndex = self.samples.count - barCount + index;
        BOOL hasSample = sampleIndex >= 0 && sampleIndex < (NSInteger)self.samples.count;
        CGFloat level = hasSample ? MAX(0.08, MIN(1.0, self.samples[sampleIndex].doubleValue)) : 0.12;
        CGFloat height = MAX(4.0, maxHeight * level);
        NSInteger visualIndex = isRTL ? (barCount - 1 - index) : index;
        CGRect barRect = CGRectMake(visualIndex * (barWidth + spacing), centerY - (height / 2.0), barWidth, height);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:barRect cornerRadius:barWidth / 2.0];
        UIColor *color = hasSample ? self.activeColor : self.inactiveColor;
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextAddPath(ctx, path.CGPath);
        CGContextFillPath(ctx);
    }
}

@end

@interface PPUserMessageCell : UITableViewCell
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIView *statusDotView;
@property (nonatomic, strong) UIView *audioContainerView;
@property (nonatomic, strong) UIButton *audioPlayButton;
@property (nonatomic, strong) PPMessageVoiceWaveformView *audioWaveformView;
@property (nonatomic, strong) UILabel *audioDurationLabel;
@property (nonatomic, strong) NSLayoutConstraint *bubbleLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bubbleMaxWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *timeTopToMessageConstraint;
@property (nonatomic, strong) NSLayoutConstraint *timeTopToAudioConstraint;
@property (nonatomic, copy) NSString *audioMessageID;
@property (nonatomic, copy) NSString *audioFileURL;
@property (nonatomic, copy) void (^audioTapHandler)(NSString *messageID, NSString *fileURL);
- (void)configureWithMessage:(NSDictionary *)message currentUserID:(NSString *)currentUserID senderParticipantType:(NSString *)senderParticipantType formatter:(NSDateFormatter *)formatter playingAudioMessageID:(NSString *)playingAudioMessageID loadingAudioMessageID:(NSString *)loadingAudioMessageID;
@end

@implementation PPUserMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_setup];
    }
    return self;
}

- (void)pp_setup
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.bubbleView = [[UIView alloc] init];
    self.bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleView.layer.cornerRadius = 24.0;
    self.bubbleView.layer.cornerCurve = kCACornerCurveContinuous;
    self.bubbleView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.bubbleView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.bubbleView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.bubbleView.layer.shadowRadius = 18.0;
    self.bubbleView.layer.shadowOpacity = 0.0;
    [self.contentView addSubview:self.bubbleView];

    self.roleLabel = [[UILabel alloc] init];
    self.roleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.roleLabel.font = PPMessageScaledFont([Styling fontBold:10.5], UIFontTextStyleCaption2);
    self.roleLabel.adjustsFontForContentSizeCategory = YES;
    self.roleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.bubbleView addSubview:self.roleLabel];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.font = PPMessageScaledFont([Styling fontMedium:16.0], UIFontTextStyleBody);
    self.messageLabel.adjustsFontForContentSizeCategory = YES;
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.bubbleView addSubview:self.messageLabel];

    self.audioContainerView = [[UIView alloc] init];
    self.audioContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.audioContainerView.hidden = YES;
    self.audioContainerView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.bubbleView addSubview:self.audioContainerView];

    self.audioPlayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.audioPlayButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.audioPlayButton.layer.cornerRadius = 17.0;
    self.audioPlayButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.audioPlayButton.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.16];
    self.audioPlayButton.tintColor = UIColor.whiteColor;
    UIImageSymbolConfiguration *audioIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
    [self.audioPlayButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:audioIconConfig] forState:UIControlStateNormal];
    [self.audioPlayButton addTarget:self action:@selector(pp_audioButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.audioPlayButton.accessibilityLabel = kLang(@"ch_provider_voice_play_accessibility");
    [self.audioContainerView addSubview:self.audioPlayButton];

    self.audioWaveformView = [[PPMessageVoiceWaveformView alloc] init];
    self.audioWaveformView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.audioContainerView addSubview:self.audioWaveformView];

    self.audioDurationLabel = [[UILabel alloc] init];
    self.audioDurationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.audioDurationLabel.font = PPMessageScaledFont([Styling fontBold:12.0], UIFontTextStyleCaption1);
    self.audioDurationLabel.adjustsFontForContentSizeCategory = YES;
    self.audioDurationLabel.textAlignment = NSTextAlignmentNatural;
    [self.audioContainerView addSubview:self.audioDurationLabel];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = PPMessageScaledFont([Styling fontMedium:11.0], UIFontTextStyleCaption2);
    self.timeLabel.adjustsFontForContentSizeCategory = YES;
    self.timeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.bubbleView addSubview:self.timeLabel];

    self.statusDotView = [[UIView alloc] init];
    self.statusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDotView.layer.cornerRadius = 2.0;
    self.statusDotView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.bubbleView addSubview:self.statusDotView];

    self.bubbleLeadingConstraint = [self.bubbleView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:22.0];
    self.bubbleTrailingConstraint = [self.bubbleView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-22.0];
    self.bubbleMaxWidthConstraint = [self.bubbleView.widthAnchor constraintLessThanOrEqualToAnchor:self.contentView.widthAnchor multiplier:0.80];
    self.timeTopToMessageConstraint = [self.timeLabel.topAnchor constraintEqualToAnchor:self.messageLabel.bottomAnchor constant:8.0];
    self.timeTopToAudioConstraint = [self.timeLabel.topAnchor constraintEqualToAnchor:self.audioContainerView.bottomAnchor constant:8.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bubbleView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [self.bubbleView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
        self.bubbleMaxWidthConstraint,

        [self.roleLabel.topAnchor constraintEqualToAnchor:self.bubbleView.topAnchor constant:10.0],
        [self.roleLabel.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:14.0],
        [self.roleLabel.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-14.0],

        [self.messageLabel.topAnchor constraintEqualToAnchor:self.roleLabel.bottomAnchor constant:7.0],
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:14.0],
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-14.0],

        [self.audioContainerView.topAnchor constraintEqualToAnchor:self.roleLabel.bottomAnchor constant:7.0],
        [self.audioContainerView.leadingAnchor constraintEqualToAnchor:self.bubbleView.leadingAnchor constant:12.0],
        [self.audioContainerView.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-12.0],
        [self.audioContainerView.heightAnchor constraintGreaterThanOrEqualToConstant:38.0],

        [self.audioPlayButton.leadingAnchor constraintEqualToAnchor:self.audioContainerView.leadingAnchor],
        [self.audioPlayButton.centerYAnchor constraintEqualToAnchor:self.audioContainerView.centerYAnchor],
        [self.audioPlayButton.widthAnchor constraintEqualToConstant:34.0],
        [self.audioPlayButton.heightAnchor constraintEqualToConstant:34.0],

        [self.audioDurationLabel.trailingAnchor constraintEqualToAnchor:self.audioContainerView.trailingAnchor],
        [self.audioDurationLabel.centerYAnchor constraintEqualToAnchor:self.audioContainerView.centerYAnchor],
        [self.audioDurationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:34.0],

        [self.audioWaveformView.leadingAnchor constraintEqualToAnchor:self.audioPlayButton.trailingAnchor constant:10.0],
        [self.audioWaveformView.trailingAnchor constraintEqualToAnchor:self.audioDurationLabel.leadingAnchor constant:-10.0],
        [self.audioWaveformView.centerYAnchor constraintEqualToAnchor:self.audioContainerView.centerYAnchor],
        [self.audioWaveformView.heightAnchor constraintEqualToConstant:28.0],

        [self.statusDotView.leadingAnchor constraintEqualToAnchor:self.messageLabel.leadingAnchor],
        [self.statusDotView.centerYAnchor constraintEqualToAnchor:self.timeLabel.centerYAnchor],
        [self.statusDotView.widthAnchor constraintEqualToConstant:4.0],
        [self.statusDotView.heightAnchor constraintEqualToConstant:4.0],

        [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.statusDotView.trailingAnchor constant:6.0],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.bubbleView.trailingAnchor constant:-14.0],
        [self.timeLabel.bottomAnchor constraintEqualToAnchor:self.bubbleView.bottomAnchor constant:-10.0],
    ]];
    self.timeTopToMessageConstraint.active = YES;
    self.timeTopToAudioConstraint.active = NO;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.bubbleView.transform = CGAffineTransformIdentity;
    self.messageLabel.hidden = NO;
    self.roleLabel.text = nil;
    self.audioContainerView.hidden = YES;
    self.audioTapHandler = nil;
    self.audioMessageID = @"";
    self.audioFileURL = @"";
    self.audioPlayButton.enabled = YES;
    self.audioPlayButton.alpha = 1.0;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
    [self.audioPlayButton setImage:[UIImage systemImageNamed:@"play.fill" withConfiguration:config] forState:UIControlStateNormal];
}

- (void)configureWithMessage:(NSDictionary *)message currentUserID:(NSString *)currentUserID senderParticipantType:(NSString *)senderParticipantType formatter:(NSDateFormatter *)formatter playingAudioMessageID:(NSString *)playingAudioMessageID loadingAudioMessageID:(NSString *)loadingAudioMessageID
{
    NSString *text = PPMessageTrimmedString(message[@"text"]);
    NSString *senderID = PPMessageTrimmedString(message[@"senderID"]);
    BOOL isOutgoing = senderID.length > 0 && [senderID isEqualToString:currentUserID];
    BOOL isAudio = PPMessageIsAudioMessage(message);
    NSString *messageID = PPMessageTrimmedString(message[@"ID"] ?: message[@"id"]);
    NSString *fileURL = PPMessageFileURLString(message);
    self.audioMessageID = messageID;
    self.audioFileURL = fileURL;
    self.roleLabel.text = PPMessageLocalizedParticipantType(senderParticipantType);

    self.messageLabel.hidden = isAudio;
    self.audioContainerView.hidden = !isAudio;
    self.timeTopToMessageConstraint.active = !isAudio;
    self.timeTopToAudioConstraint.active = isAudio;
    self.messageLabel.text = isAudio ? @"" : text;

    if (isAudio) {
        BOOL isPlaying = messageID.length > 0 && [messageID isEqualToString:playingAudioMessageID];
        BOOL isLoading = messageID.length > 0 && [messageID isEqualToString:loadingAudioMessageID];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightBold];
        NSString *iconName = isLoading ? @"waveform" : (isPlaying ? @"pause.fill" : @"play.fill");
        [self.audioPlayButton setImage:[UIImage systemImageNamed:iconName withConfiguration:config] forState:UIControlStateNormal];
        self.audioPlayButton.enabled = fileURL.length > 0 && !isLoading;
        self.audioPlayButton.alpha = isLoading ? 0.72 : 1.0;
        self.audioDurationLabel.text = PPMessageDurationText(PPMessageMediaDuration(message));
        self.audioWaveformView.samples = PPMessageWaveformSamples(message);
        self.audioPlayButton.accessibilityLabel = isPlaying ? kLang(@"ch_provider_voice_pause_accessibility") : kLang(@"ch_provider_voice_play_accessibility");
    }

    NSDate *date = PPMessageDateFromValue(message[@"timestamp"]);
    NSString *timeText = date ? [formatter stringFromDate:date] : @"";
    NSString *statusText = isOutgoing ? PPMessageStatusText(message[@"status"]) : @"";
    self.timeLabel.text = isOutgoing && statusText.length > 0 ? [NSString stringWithFormat:@"%@  %@", statusText, timeText] : timeText;

    self.bubbleLeadingConstraint.active = !isOutgoing;
    self.bubbleTrailingConstraint.active = isOutgoing;

    UIColor *accent = AppPrimaryClr;
    if (isOutgoing) {
        self.bubbleView.backgroundColor = accent;
        self.bubbleView.layer.borderColor = [accent colorWithAlphaComponent:0.08].CGColor;
        self.bubbleView.layer.shadowOpacity = 0.08;
        self.messageLabel.textColor = UIColor.whiteColor;
        self.timeLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.70];
        self.statusDotView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.62];
        self.audioPlayButton.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.18];
        self.audioPlayButton.tintColor = UIColor.whiteColor;
        self.audioDurationLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.86];
        self.audioWaveformView.activeColor = UIColor.whiteColor;
        self.audioWaveformView.inactiveColor = [UIColor.whiteColor colorWithAlphaComponent:0.24];
        self.roleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.74];
    } else {
        self.bubbleView.backgroundColor = PPMessageSurfaceColor();
        self.bubbleView.layer.borderColor = [accent colorWithAlphaComponent:0.10].CGColor;
        self.bubbleView.layer.shadowOpacity = 0.035;
        self.messageLabel.textColor = PPMessagePrimaryTextColor();
        self.timeLabel.textColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.76];
        self.statusDotView.backgroundColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.35];
        self.audioPlayButton.backgroundColor = [accent colorWithAlphaComponent:0.11];
        self.audioPlayButton.tintColor = accent;
        self.audioDurationLabel.textColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.86];
        self.audioWaveformView.activeColor = accent;
        self.audioWaveformView.inactiveColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.22];
        self.roleLabel.textColor = PPMessageParticipantTypeColor(senderParticipantType);
    }

    if (@available(iOS 11.0, *)) {
        BOOL isRTL = Language.isRTL;
        if (isOutgoing) {
            self.bubbleView.layer.maskedCorners = isRTL ? (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner) : (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner);
        } else {
            self.bubbleView.layer.maskedCorners = isRTL ? (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner) : (kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner);
        }
    }

    if (isAudio) {
        self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@, %@", PPMessageLocalizedParticipantType(senderParticipantType), kLang(@"ch_provider_voice_message"), self.audioDurationLabel.text ?: @"", self.timeLabel.text ?: @""];
    } else {
        self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", PPMessageLocalizedParticipantType(senderParticipantType), text ?: @"", self.timeLabel.text ?: @""];
    }
}

- (void)pp_audioButtonTapped
{
    if (self.audioTapHandler && self.audioMessageID.length > 0 && self.audioFileURL.length > 0) {
        self.audioTapHandler(self.audioMessageID, self.audioFileURL);
    }
}

@end

@interface PPUserMessagesViewController () <UITableViewDataSource, UITableViewDelegate, PPChatInputBarDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) ChatThreadModel *chatThread;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *messages;
@property (nonatomic, strong) id<FIRListenerRegistration> messagesListener;
@property (nonatomic, strong) id<FIRListenerRegistration> threadListener;
@property (nonatomic, strong) PPChatInputBar *chatInputBar;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIView *fixedConversationHeroView;
@property (nonatomic, strong) UIButton *premiumBackButton;
@property (nonatomic, strong) UIView *ambientTopGlowView;
@property (nonatomic, strong) UIView *ambientBottomGlowView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSLayoutConstraint *inputBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *inputRestingBottomConstraint;
@property (nonatomic, assign) BOOL usesKeyboardLayoutGuide;
@property (nonatomic, strong) UIImageView *conversationAvatarImageView;
@property (nonatomic, strong) UILabel *conversationAvatarFallbackLabel;
@property (nonatomic, strong) UILabel *conversationTitleLabel;
@property (nonatomic, strong) UILabel *conversationTypeLabel;
@property (nonatomic, strong) UILabel *conversationSubtitleLabel;
@property (nonatomic, copy) NSString *participantIdentityType;
@property (nonatomic, copy) NSString *currentIdentityType;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, copy) NSString *playingAudioMessageID;
@property (nonatomic, copy) NSString *loadingAudioMessageID;
@property (nonatomic, strong) FIRStorageUploadTask *audioUploadTask;
@property (nonatomic, assign) BOOL didAnimateMessages;
@property (nonatomic, assign) BOOL didPrepareEntranceAnimation;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL ambientMotionRunning;
@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@property (nonatomic, assign) BOOL isSendingMessage;
@property (nonatomic, assign) NSInteger messagePageLimit;
@property (nonatomic, assign) BOOL isExpandingMessagePage;
@property (nonatomic, assign) CGFloat previousContentHeightBeforeExpansion;
@property (nonatomic, assign) CGFloat previousContentOffsetYBeforeExpansion;
@property (nonatomic, strong) NSTimer *typingDebounceTimer;
@property (nonatomic, assign) BOOL didWriteTypingActive;
- (void)pp_prepareEntranceState;
- (NSString *)pp_defaultParticipantIdentityType;
- (void)pp_handlePremiumBackButton;
- (void)pp_loadConversationIdentities;
- (void)pp_updateConversationIdentityUI;
- (NSString *)pp_identityTypeForMessage:(NSDictionary *)message;
@end

@implementation PPUserMessagesViewController

#pragma mark - Lifecycle

- (instancetype)initWithChatThread:(ChatThreadModel *)thread
{
    self = [super init];
    if (!self) return nil;
    _chatThread = thread;
    _messages = [NSMutableArray array];
    _messagePageLimit = PPMessageInitialPageLimit;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterNoStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
    self.participantIdentityType = [self pp_defaultParticipantIdentityType];
    self.currentIdentityType = PPChatParticipantTypeProvider;
    [self pp_configureAppearance];
    [self pp_buildAmbientBackgroundIfNeeded];
    [self pp_configureTableView];
    [self pp_configureInput];
    [self pp_prepareEntranceState];
    [self pp_registerKeyboardNotifications];
    [self pp_loadConversationIdentities];
    [self pp_startObservingMessages];
    [self pp_startObservingThread];
    [self pp_updateEmptyState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
    self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    
 
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_startAmbientMotionIfNeeded];
    [self pp_runEntranceAnimationIfNeeded];
    [self pp_markIncomingMessagesAsRead];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
    [self pp_stopAmbientMotion];
    [self.chatInputBar cancelRecording];
    [self pp_stopAudioPlaybackAndRefresh:NO];
    [self pp_setTypingActive:NO];
    [self.typingDebounceTimer invalidate];
    self.typingDebounceTimer = nil;
    [self.messagesListener remove];
    self.messagesListener = nil;
    [self.threadListener remove];
    self.threadListener = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.audioUploadTask cancel];
    [self.chatInputBar cancelRecording];
    [self pp_stopAudioPlaybackAndRefresh:NO];
    [self pp_setTypingActive:NO];
    [self.typingDebounceTimer invalidate];
    [self.messagesListener remove];
    [self.threadListener remove];
}

#pragma mark - Setup

- (void)pp_configureAppearance
{
    self.view.backgroundColor = PPMessageBackgroundColor();
    self.title = @"";
    self.navigationItem.title = @"";
    self.navigationItem.hidesBackButton = YES;
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)pp_buildAmbientBackgroundIfNeeded
{
    if (self.ambientTopGlowView) return;

    UIColor *accent = AppPrimaryClr;
    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [accent colorWithAlphaComponent:0.08];
    topGlow.layer.cornerRadius = 140.0;
    topGlow.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view insertSubview:topGlow atIndex:0];
    self.ambientTopGlowView = topGlow;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [PPMessagePrimaryTextColor() colorWithAlphaComponent:0.035];
    bottomGlow.layer.cornerRadius = 175.0;
    bottomGlow.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view insertSubview:bottomGlow atIndex:0];
    self.ambientBottomGlowView = bottomGlow;

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:280.0],
        [topGlow.heightAnchor constraintEqualToConstant:280.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-96.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:70.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:350.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:350.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:132.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-124.0],
    ]];
}

- (void)pp_configureTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 74.0;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(10.0, 0.0, 18.0, 0.0);
    [self.tableView registerClass:PPUserMessageCell.class forCellReuseIdentifier:@"PPUserMessageCell"];
    [self.view addSubview:self.tableView];

    self.fixedConversationHeroView = [self pp_makeConversationHeaderView];
    self.fixedConversationHeroView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.fixedConversationHeroView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.font = [Styling fontMedium:15.0];
    self.emptyLabel.textColor = PPMessageSecondaryTextColor();
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.text = kLang(@"ch_provider_no_messages");
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.fixedConversationHeroView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.fixedConversationHeroView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.fixedConversationHeroView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.fixedConversationHeroView.heightAnchor constraintEqualToConstant:132.0],

        [self.tableView.topAnchor constraintEqualToAnchor:self.fixedConversationHeroView.bottomAnchor constant:2.0],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-22.0],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:34.0],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-34.0],
    ]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (![scrollView isEqual:self.tableView]) return;
    CGFloat topThreshold = -scrollView.adjustedContentInset.top + 24.0;
    if (scrollView.contentOffset.y <= topThreshold) {
        [self pp_loadOlderMessagesIfNeeded];
    }
}

- (UIView *)pp_makeConversationHeaderView
{
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, UIScreen.mainScreen.bounds.size.width, 142.0)];
    container.backgroundColor = UIColor.clearColor;

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [PPMessageSurfaceColor() colorWithAlphaComponent:0.74];
    surface.layer.cornerRadius = 28.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = [(AppPrimaryClr) colorWithAlphaComponent:0.14].CGColor;
    surface.layer.shadowColor = UIColor.blackColor.CGColor;
    surface.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    surface.layer.shadowRadius = 26.0;
    surface.layer.shadowOpacity = 0.06;
    [container addSubview:surface];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        blur.layer.cornerRadius = 28.0;
        blur.layer.cornerCurve = kCACornerCurveContinuous;
        [surface addSubview:blur];
        [NSLayoutConstraint activateConstraints:@[
            [blur.topAnchor constraintEqualToAnchor:surface.topAnchor],
            [blur.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
        ]];
    }

    self.premiumBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.premiumBackButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.premiumBackButton.backgroundColor = [PPMessageMatteColor() colorWithAlphaComponent:0.94];
    self.premiumBackButton.tintColor = PPMessagePrimaryTextColor();
    self.premiumBackButton.layer.cornerRadius = 21.0;
    self.premiumBackButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.premiumBackButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.premiumBackButton.layer.borderColor = [PPMessagePrimaryTextColor() colorWithAlphaComponent:0.08].CGColor;
    self.premiumBackButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.premiumBackButton.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.premiumBackButton.layer.shadowRadius = 16.0;
    self.premiumBackButton.layer.shadowOpacity = 0.08;
    UIImageSymbolConfiguration *backConfig = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightBold];
    NSString *backIconName = Language.isRTL ? @"chevron.right" : @"chevron.left";
    [self.premiumBackButton setImage:[UIImage systemImageNamed:backIconName withConfiguration:backConfig] forState:UIControlStateNormal];
    [self.premiumBackButton addTarget:self action:@selector(pp_handlePremiumBackButton) forControlEvents:UIControlEventTouchUpInside];
    self.premiumBackButton.accessibilityLabel = kLang(@"Back");
    [surface addSubview:self.premiumBackButton];

    UIView *avatarSurface = [[UIView alloc] init];
    avatarSurface.translatesAutoresizingMaskIntoConstraints = NO;
    avatarSurface.backgroundColor = [PPMessageMatteColor() colorWithAlphaComponent:0.90];
    avatarSurface.layer.cornerRadius = 29.0;
    avatarSurface.layer.cornerCurve = kCACornerCurveContinuous;
    avatarSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    avatarSurface.layer.borderColor = [(AppPrimaryClr) colorWithAlphaComponent:0.18].CGColor;
    avatarSurface.clipsToBounds = YES;
    [surface addSubview:avatarSurface];

    self.conversationAvatarFallbackLabel = [[UILabel alloc] init];
    self.conversationAvatarFallbackLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationAvatarFallbackLabel.font = [Styling fontBold:20.0];
    self.conversationAvatarFallbackLabel.textColor = AppPrimaryClr;
    self.conversationAvatarFallbackLabel.textAlignment = NSTextAlignmentCenter;
    [avatarSurface addSubview:self.conversationAvatarFallbackLabel];

    self.conversationAvatarImageView = [[UIImageView alloc] init];
    self.conversationAvatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.conversationAvatarImageView.clipsToBounds = YES;
    self.conversationAvatarImageView.isAccessibilityElement = NO;
    [avatarSurface addSubview:self.conversationAvatarImageView];

    self.conversationTypeLabel = [[UILabel alloc] init];
    self.conversationTypeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationTypeLabel.font = [Styling fontBold:10.5];
    self.conversationTypeLabel.textAlignment = NSTextAlignmentCenter;
    self.conversationTypeLabel.layer.cornerRadius = 9.0;
    self.conversationTypeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.conversationTypeLabel.clipsToBounds = YES;
    [surface addSubview:self.conversationTypeLabel];

    self.conversationTitleLabel = [[UILabel alloc] init];
    self.conversationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationTitleLabel.font = [Styling fontBold:23.0];
    self.conversationTitleLabel.textColor = PPMessagePrimaryTextColor();
    self.conversationTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.conversationTitleLabel.numberOfLines = 1;
    [surface addSubview:self.conversationTitleLabel];

    self.conversationSubtitleLabel = [[UILabel alloc] init];
    self.conversationSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.conversationSubtitleLabel.font = [Styling fontMedium:12.5];
    self.conversationSubtitleLabel.textColor = [PPMessageSecondaryTextColor() colorWithAlphaComponent:0.82];
    self.conversationSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.conversationSubtitleLabel.numberOfLines = 1;
    self.conversationSubtitleLabel.text = kLang(@"ch_provider_reply_hint");
    [surface addSubview:self.conversationSubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:container.topAnchor constant:12.0],
        [surface.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [surface.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [surface.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8.0],

        [self.premiumBackButton.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:14.0],
        [self.premiumBackButton.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [self.premiumBackButton.widthAnchor constraintEqualToConstant:42.0],
        [self.premiumBackButton.heightAnchor constraintEqualToConstant:42.0],

        [avatarSurface.leadingAnchor constraintEqualToAnchor:self.premiumBackButton.trailingAnchor constant:12.0],
        [avatarSurface.centerYAnchor constraintEqualToAnchor:surface.centerYAnchor],
        [avatarSurface.widthAnchor constraintEqualToConstant:58.0],
        [avatarSurface.heightAnchor constraintEqualToConstant:58.0],

        [self.conversationAvatarFallbackLabel.centerXAnchor constraintEqualToAnchor:avatarSurface.centerXAnchor],
        [self.conversationAvatarFallbackLabel.centerYAnchor constraintEqualToAnchor:avatarSurface.centerYAnchor],

        [self.conversationAvatarImageView.topAnchor constraintEqualToAnchor:avatarSurface.topAnchor],
        [self.conversationAvatarImageView.leadingAnchor constraintEqualToAnchor:avatarSurface.leadingAnchor],
        [self.conversationAvatarImageView.trailingAnchor constraintEqualToAnchor:avatarSurface.trailingAnchor],
        [self.conversationAvatarImageView.bottomAnchor constraintEqualToAnchor:avatarSurface.bottomAnchor],

        [self.conversationTypeLabel.topAnchor constraintEqualToAnchor:surface.topAnchor constant:18.0],
        [self.conversationTypeLabel.leadingAnchor constraintEqualToAnchor:avatarSurface.trailingAnchor constant:14.0],
        [self.conversationTypeLabel.heightAnchor constraintEqualToConstant:18.0],
        [self.conversationTypeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:56.0],
        [self.conversationTypeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:surface.trailingAnchor constant:-18.0],

        [self.conversationTitleLabel.topAnchor constraintEqualToAnchor:self.conversationTypeLabel.bottomAnchor constant:5.0],
        [self.conversationTitleLabel.leadingAnchor constraintEqualToAnchor:self.conversationTypeLabel.leadingAnchor],
        [self.conversationTitleLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18.0],

        [self.conversationSubtitleLabel.topAnchor constraintEqualToAnchor:self.conversationTitleLabel.bottomAnchor constant:4.0],
        [self.conversationSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.conversationTypeLabel.leadingAnchor],
        [self.conversationSubtitleLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18.0],
    ]];

    [self pp_updateConversationIdentityUI];
    return container;
}

- (void)pp_handlePremiumBackButton
{
    [UIView animateWithDuration:0.08 delay:0.0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.premiumBackButton.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.14 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            self.premiumBackButton.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL innerFinished) {
            if (self.navigationController.viewControllers.count > 1) {
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    }];
}

- (void)pp_configureInput
{
    self.chatInputBar = [[PPChatInputBar alloc] init];
    self.chatInputBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.chatInputBar.delegate = self;
    self.chatInputBar.placeholder = kLang(@"ch_provider_reply");
    self.chatInputBar.minHeight = 64.0;
    self.chatInputBar.maxHeight = 140.0;
    [self.view addSubview:self.chatInputBar];

    NSMutableArray<NSLayoutConstraint *> *constraints = [@[
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.chatInputBar.topAnchor constant:-8.0],
        [self.chatInputBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [self.chatInputBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14.0],
    ] mutableCopy];

    if (@available(iOS 15.0, *)) {
        UIKeyboardLayoutGuide *keyboardGuide = self.view.keyboardLayoutGuide;
        keyboardGuide.followsUndockedKeyboard = YES;
        self.usesKeyboardLayoutGuide = YES;

        self.inputBottomConstraint = [self.chatInputBar.bottomAnchor constraintEqualToAnchor:keyboardGuide.topAnchor constant:-6.0];
        self.inputBottomConstraint.priority = 999;
        self.inputRestingBottomConstraint = [self.chatInputBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0];
        self.inputRestingBottomConstraint.priority = 750;
        [constraints addObject:self.inputBottomConstraint];
        [constraints addObject:self.inputRestingBottomConstraint];
        [constraints addObject:[self.chatInputBar.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0]];
    } else {
        self.inputBottomConstraint = [self.chatInputBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10.0];
        [constraints addObject:self.inputBottomConstraint];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    
    // Set initial content inset to account for input bar
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.bottom = self.chatInputBar.minHeight + 8.0;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

#pragma mark - Conversation Identity

- (NSString *)pp_defaultParticipantIdentityType
{
    NSString *otherUserID = PPMessageTrimmedString(self.chatThread.otherUser.ID);
    NSString *conversationType = [PPMessageTrimmedString(self.chatThread.conversationType) lowercaseString];
    if ([conversationType containsString:@"support"] &&
        otherUserID.length > 0 &&
        [otherUserID isEqualToString:PPMessageTrimmedString(self.chatThread.supportUserID)]) {
        return PPChatParticipantTypeConsole;
    }
    return PPChatParticipantTypeForProfile(nil, self.chatThread.sourcePlatform);
}

- (void)pp_fetchIdentityForUserID:(NSString *)userID
                    sourcePlatform:(NSString *)sourcePlatform
                        completion:(void (^)(UserModel * _Nullable user, NSString *participantType))completion
{
    NSString *safeUserID = PPMessageTrimmedString(userID);
    if (safeUserID.length == 0) {
        if (completion) completion(nil, PPChatParticipantTypeForProfile(nil, sourcePlatform));
        return;
    }

    FIRDocumentReference *profileRef = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:safeUserID];
    [profileRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *profile = (!error && snapshot.exists) ? (snapshot.data ?: @{}) : @{};
            UserModel *user = (!error && snapshot.exists) ? [[UserModel alloc] initWithSnapshot:snapshot] : nil;
            NSString *participantType = PPChatParticipantTypeForProfile(profile, sourcePlatform);
            if (completion) completion(user, participantType);
        });
    }];
}

- (void)pp_loadConversationIdentities
{
    NSString *participantID = PPMessageTrimmedString(self.chatThread.otherUser.ID);
    __weak typeof(self) weakSelf = self;
    [self pp_fetchIdentityForUserID:participantID
                    sourcePlatform:self.chatThread.sourcePlatform
                        completion:^(UserModel *user, NSString *participantType) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (user) {
            UserModel *fallbackUser = strongSelf.chatThread.otherUser;
            if (user.PPBestDisplayName.length == 0) {
                user.UserName = fallbackUser.PPBestDisplayName;
            }
            if (!user.UserImageUrl && fallbackUser.UserImageUrl) {
                user.UserImageUrl = fallbackUser.UserImageUrl;
            }
            strongSelf.chatThread.otherUser = user;
        }
        NSString *defaultType = [strongSelf pp_defaultParticipantIdentityType];
        strongSelf.participantIdentityType = [defaultType isEqualToString:PPChatParticipantTypeConsole]
            ? defaultType
            : (participantType.length > 0 ? participantType : defaultType);
        strongSelf.chatThread.participantType = strongSelf.participantIdentityType;
        [strongSelf pp_updateConversationIdentityUI];
        [strongSelf.tableView reloadData];
    }];

    NSString *currentUserID = [FIRAuth auth].currentUser.uid ?: @"";
    [self pp_fetchIdentityForUserID:currentUserID
                    sourcePlatform:@"pro_ios"
                        completion:^(__unused UserModel *user, NSString *participantType) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.currentIdentityType = participantType.length > 0
            ? participantType
            : PPChatParticipantTypeProvider;
        [strongSelf.tableView reloadData];
    }];
}

- (void)pp_updateConversationIdentityUI
{
    if (!self.conversationTitleLabel) return;

    NSString *name = PPMessageTrimmedString(self.chatThread.otherUser.PPBestDisplayName);
    if (name.length == 0) name = kLang(@"ch_provider_customer_fallback");
    self.conversationTitleLabel.text = name;
    self.conversationAvatarFallbackLabel.text = PPMessageInitialForName(name);
    self.conversationAvatarFallbackLabel.hidden = NO;

    NSString *participantType = self.participantIdentityType.length > 0
        ? self.participantIdentityType
        : [self pp_defaultParticipantIdentityType];
    UIColor *typeColor = PPMessageParticipantTypeColor(participantType);
    self.conversationTypeLabel.text = [NSString stringWithFormat:@"  %@  ", PPMessageLocalizedParticipantType(participantType)];
    self.conversationTypeLabel.textColor = typeColor;
    self.conversationTypeLabel.backgroundColor = [typeColor colorWithAlphaComponent:0.11];

    [self.conversationAvatarImageView sd_cancelCurrentImageLoad];
    self.conversationAvatarImageView.image = nil;
    NSString *photoURL = PPMessageTrimmedString(self.chatThread.otherUser.UserImageUrl.absoluteString);
    if (photoURL.length == 0) photoURL = PPMessageTrimmedString(self.chatThread.supportPhotoURLString);
    if (photoURL.length > 0) {
        NSString *representedUserID = PPMessageTrimmedString(self.chatThread.otherUser.ID);
        __weak typeof(self) weakSelf = self;
        [self.conversationAvatarImageView sd_setImageWithURL:[NSURL URLWithString:photoURL]
                                           placeholderImage:nil
                                                  completed:^(UIImage * _Nullable image,
                                                              NSError * _Nullable error,
                                                              SDImageCacheType cacheType,
                                                              NSURL * _Nullable imageURL) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf ||
                ![PPMessageTrimmedString(strongSelf.chatThread.otherUser.ID) isEqualToString:representedUserID]) {
                return;
            }
            strongSelf.conversationAvatarFallbackLabel.hidden = image != nil;
        }];
    }

    self.conversationTitleLabel.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", name, PPMessageLocalizedParticipantType(participantType)];
}

- (NSString *)pp_identityTypeForMessage:(NSDictionary *)message
{
    NSString *senderID = PPMessageTrimmedString(message[@"senderID"] ?: message[@"senderId"]);
    NSString *employeeID = PPMessageTrimmedString(message[@"employeeID"] ?: message[@"employeeId"]);
    NSString *currentUserID = [FIRAuth auth].currentUser.uid ?: @"";
    if (senderID.length > 0 && [senderID isEqualToString:currentUserID]) {
        return self.currentIdentityType.length > 0 ? self.currentIdentityType : PPChatParticipantTypeProvider;
    }
    if (employeeID.length > 0) {
        return PPChatParticipantTypeConsole;
    }

    NSString *participantID = PPMessageTrimmedString(self.chatThread.otherUser.ID);
    if (senderID.length > 0 && [senderID isEqualToString:participantID]) {
        return self.participantIdentityType.length > 0 ? self.participantIdentityType : [self pp_defaultParticipantIdentityType];
    }
    if (senderID.length > 0 && ![self.chatThread.memberIDs containsObject:senderID]) {
        return PPChatParticipantTypeConsole;
    }
    return self.participantIdentityType.length > 0 ? self.participantIdentityType : [self pp_defaultParticipantIdentityType];
}


#pragma mark - Messaging

- (void)pp_startObservingMessages
{
    if (self.messagesListener || self.chatThread.ID.length == 0) return;

    FIRCollectionReference *messagesRef =
    [[[[FIRFirestore firestore] collectionWithPath:@"Chats"]
      documentWithPath:self.chatThread.ID]
     collectionWithPath:@"Messages"];

    FIRQuery *query = [[messagesRef queryOrderedByField:@"timestamp" descending:YES]
                       queryLimitedTo:self.messagePageLimit];

    __weak typeof(self) weakSelf = self;
    self.messagesListener = [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                strongSelf.isExpandingMessagePage = NO;
                strongSelf.previousContentHeightBeforeExpansion = 0.0;
                strongSelf.previousContentOffsetYBeforeExpansion = 0.0;
                [strongSelf pp_updateEmptyState];
                return;
            }

            CGFloat oldContentHeight = strongSelf.previousContentHeightBeforeExpansion;
            CGFloat oldOffsetY = strongSelf.previousContentOffsetYBeforeExpansion;
            BOOL preserveOffset = strongSelf.isExpandingMessagePage && oldContentHeight > 0.0;

            NSMutableArray<NSDictionary *> *loaded = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents.reverseObjectEnumerator) {
                if (!doc.exists) continue;
                NSMutableDictionary *data = [(doc.data ?: @{}) mutableCopy];
                if (doc.documentID.length > 0 && PPMessageTrimmedString(data[@"ID"]).length == 0) {
                    data[@"ID"] = doc.documentID;
                }
                [loaded addObject:data];
            }
            strongSelf.messages = loaded;
            [strongSelf.tableView reloadData];
            [strongSelf.tableView layoutIfNeeded];
            if (preserveOffset) {
                CGFloat newContentHeight = strongSelf.tableView.contentSize.height;
                CGFloat delta = MAX(0.0, newContentHeight - oldContentHeight);
                CGPoint offset = CGPointMake(0.0, oldOffsetY + delta);
                [strongSelf.tableView setContentOffset:offset animated:NO];
            } else {
                [strongSelf pp_scrollToBottomAnimated:strongSelf.didAnimateMessages];
            }
            strongSelf.isExpandingMessagePage = NO;
            strongSelf.previousContentHeightBeforeExpansion = 0.0;
            strongSelf.previousContentOffsetYBeforeExpansion = 0.0;
            [strongSelf pp_updateEmptyState];
            [strongSelf pp_animateVisibleMessagesIfNeeded];
            [strongSelf pp_markIncomingMessagesAsRead];
        });
    }];
}

- (void)pp_loadOlderMessagesIfNeeded
{
    if (self.isExpandingMessagePage || self.messages.count < self.messagePageLimit) return;
    self.isExpandingMessagePage = YES;
    self.previousContentHeightBeforeExpansion = self.tableView.contentSize.height;
    self.previousContentOffsetYBeforeExpansion = self.tableView.contentOffset.y;
    self.messagePageLimit += PPMessagePageStep;
    [self.messagesListener remove];
    self.messagesListener = nil;
    [self pp_startObservingMessages];
}

- (BOOL)pp_messageIsUnread:(NSDictionary *)message currentUID:(NSString *)currentUID
{
    NSString *receiverID = PPMessageTrimmedString(message[@"receiverID"] ?: message[@"receiverId"]);
    if (![receiverID isEqualToString:currentUID]) return NO;

    return PPMessageStatusValue(message[@"status"]) < PPMessageStatusRead;
}

- (void)pp_markIncomingMessagesAsRead
{
    NSString *currentUID = [FIRAuth auth].currentUser.uid;
    if (!currentUID.length || self.chatThread.ID.length == 0) return;

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"chatMessageCommand"];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:@{
        @"action": @"mark_read",
        @"threadId": self.chatThread.ID
    } completion:nil];
}

- (void)pp_startObservingThread
{
    if (self.threadListener || self.chatThread.ID.length == 0) return;
    FIRDocumentReference *threadRef = [[[FIRFirestore firestore] collectionWithPath:@"Chats"] documentWithPath:self.chatThread.ID];
    __weak typeof(self) weakSelf = self;
    self.threadListener = [threadRef addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        if (error || !snapshot.exists) return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSDictionary *data = snapshot.data ?: @{};
        NSString *otherUID = PPMessageTrimmedString(strongSelf.chatThread.otherUser.ID);
        BOOL isTyping = NO;
        NSDictionary *typingStatus = [data[@"typingStatus"] isKindOfClass:NSDictionary.class] ? data[@"typingStatus"] : nil;
        NSDictionary *typing = [data[@"typing"] isKindOfClass:NSDictionary.class] ? data[@"typing"] : nil;
        if (otherUID.length > 0) {
            isTyping = [typingStatus[otherUID] boolValue] || [typing[otherUID] boolValue];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.conversationSubtitleLabel.text = isTyping ? kLang(@"ch_provider_typing_hint") : kLang(@"ch_provider_reply_hint");
        });
    }];
}

- (void)pp_setTypingActive:(BOOL)isTyping
{
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length == 0 || self.chatThread.ID.length == 0) return;
    if (self.didWriteTypingActive == isTyping) return;
    self.didWriteTypingActive = isTyping;

    NSString *typingStatusPath = [NSString stringWithFormat:@"typingStatus.%@", currentUID];
    NSString *typingPath = [NSString stringWithFormat:@"typing.%@", currentUID];
    FIRDocumentReference *threadRef = [[[FIRFirestore firestore] collectionWithPath:@"Chats"] documentWithPath:self.chatThread.ID];
    [threadRef updateData:@{
        typingStatusPath: @(isTyping),
        typingPath: @(isTyping),
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    }];
}

- (void)pp_typingDebounceDidFire:(NSTimer *)timer
{
    [self pp_setTypingActive:NO];
}

- (NSString *)pp_receiverIDForCurrentSender:(NSString *)senderID
{
    NSString *receiverID = PPMessageTrimmedString(self.chatThread.otherUser.ID);
    if (receiverID.length > 0) return receiverID;

    for (NSString *memberID in self.chatThread.memberIDs) {
        NSString *candidate = PPMessageTrimmedString(memberID);
        if (candidate.length > 0 && ![candidate isEqualToString:senderID]) {
            return candidate;
        }
    }
    return @"";
}

- (void)pp_sendMessage
{
    NSString *conversationType = PPMessageTrimmedString(self.chatThread.conversationType);
    if (self.chatThread.supportThread || [conversationType isEqualToString:@"support"] || [conversationType isEqualToString:@"user_support"]) {
        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
        return;
    }
    NSString *text = PPMessageTrimmedString(self.chatInputBar.textView.text);
    if (text.length == 0) return;

    NSString *senderID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *receiverID = [self pp_receiverIDForCurrentSender:senderID];
    if (senderID.length == 0 || receiverID.length == 0 || self.chatThread.ID.length == 0) return;

    [self pp_setSendInFlight:YES];

    NSString *messageID = [[NSUUID UUID] UUIDString];
    NSDictionary *payload = @{
        @"action": @"send",
        @"threadId": self.chatThread.ID,
        @"messageId": messageID,
        @"receiverID": receiverID,
        @"text": text,
        @"message": @{
            @"text": text,
            @"type": @0,
            @"sourceApp": @"pro_ios",
            @"sourcePlatform": @"ios"
        }
    };

    __weak typeof(self) weakSelf = self;
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"chatMessageCommand"];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        (void)result;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_setSendInFlight:NO];
            if (error) return;
            [strongSelf.chatInputBar clearInput];
        });
    }];
}

- (void)pp_sendVoiceRecordingAtURL:(NSURL *)fileURL duration:(NSTimeInterval)duration waveformSamples:(NSArray<NSNumber *> *)waveformSamples
{
    NSString *conversationType = PPMessageTrimmedString(self.chatThread.conversationType);
    if (self.chatThread.supportThread || [conversationType isEqualToString:@"support"] || [conversationType isEqualToString:@"user_support"]) {
        [PPToast toast:kLang(@"Deliv_CannotChatProvider")];
        return;
    }
    if (fileURL.path.length == 0 || duration <= 0) return;

    NSString *senderID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *receiverID = [self pp_receiverIDForCurrentSender:senderID];
    if (senderID.length == 0 || receiverID.length == 0 || self.chatThread.ID.length == 0) {
        [PPToast toast:kLang(@"ch_provider_voice_send_error")];
        return;
    }

    NSData *audioData = [NSData dataWithContentsOfURL:fileURL];
    if (audioData.length == 0) {
        [PPToast toast:kLang(@"ch_provider_voice_send_error")];
        return;
    }

    [self pp_setSendInFlight:YES];

    NSString *messageID = [[NSUUID UUID] UUIDString];
    NSString *storagePath = [NSString stringWithFormat:@"Chats/%@/audio/%@.m4a", self.chatThread.ID, messageID];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:storagePath];
    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"audio/mp4";
    metadata.customMetadata = @{
        @"uploaded_by": senderID,
        @"thread_id": self.chatThread.ID ?: @"",
        @"message_id": messageID,
        @"media_type": @"audio"
    };
    FIRStorageUploadTask *task = [ref putData:audioData metadata:metadata];
    self.audioUploadTask = task;

    __weak typeof(self) weakSelf = self;
    [task observeStatus:FIRStorageTaskStatusFailure handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.audioUploadTask = nil;
            [strongSelf pp_setSendInFlight:NO];
            [NSFileManager.defaultManager removeItemAtURL:fileURL error:nil];
            [PPToast toast:kLang(@"ch_provider_voice_send_error")];
        });
    }];

    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snapshot) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [ref downloadURLWithCompletion:^(NSURL *downloadURL, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerSelf = weakSelf;
                if (!innerSelf) return;
                if (!downloadURL || error) {
                    innerSelf.audioUploadTask = nil;
                    [innerSelf pp_setSendInFlight:NO];
                    [NSFileManager.defaultManager removeItemAtURL:fileURL error:nil];
                    [PPToast toast:kLang(@"ch_provider_voice_send_error")];
                    return;
                }

                [innerSelf pp_writeVoiceMessageWithID:messageID
                                                  url:downloadURL.absoluteString
                                             senderID:senderID
                                           receiverID:receiverID
                                             duration:duration
                                             fileSize:audioData.length
                                      waveformSamples:waveformSamples ?: @[]
                                         localFileURL:fileURL];
            });
        }];
    }];
}

- (void)pp_writeVoiceMessageWithID:(NSString *)messageID
                                url:(NSString *)urlString
                           senderID:(NSString *)senderID
                         receiverID:(NSString *)receiverID
                           duration:(NSTimeInterval)duration
                           fileSize:(NSUInteger)fileSize
                    waveformSamples:(NSArray<NSNumber *> *)waveformSamples
                       localFileURL:(NSURL *)localFileURL
{
    NSMutableDictionary *messagePayload = [@{
        @"text": kLang(@"ch_provider_voice_message"),
        @"type": @2,
        @"fileURL": urlString ?: @"",
        @"mimeType": @"audio/mp4",
        @"fileSize": @(fileSize),
        @"mediaDuration": @(duration),
        @"sourceApp": @"pro_ios",
        @"sourcePlatform": @"ios"
    } mutableCopy];
    if (waveformSamples.count > 0) messagePayload[@"waveform"] = waveformSamples;
    NSDictionary *payload = @{
        @"action": @"send",
        @"threadId": self.chatThread.ID,
        @"messageId": messageID,
        @"receiverID": receiverID,
        @"text": kLang(@"ch_provider_voice_message"),
        @"message": messagePayload
    };

    __weak typeof(self) weakSelf = self;
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:@"chatMessageCommand"];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        (void)result;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.audioUploadTask = nil;
            [strongSelf pp_setSendInFlight:NO];
            if (error) {
                [PPToast toast:kLang(@"ch_provider_voice_send_error")];
                return;
            }
            [NSFileManager.defaultManager removeItemAtURL:localFileURL error:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"forceReloadThreads" object:nil];
        });
    }];
}

- (void)pp_scrollToBottomAnimated:(BOOL)animated
{
    if (self.messages.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

#pragma mark - State

- (void)pp_updateEmptyState
{
    BOOL isEmpty = self.messages.count == 0;
    self.emptyLabel.hidden = !isEmpty;
    self.tableView.hidden = NO;
}

- (void)pp_setSendInFlight:(BOOL)inFlight
{
    self.isSendingMessage = inFlight;
    [self.chatInputBar setInputEnabled:!inFlight];
    [self.chatInputBar setSending:inFlight];
}

#pragma mark - Keyboard

- (void)pp_registerKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_keyboardWillChange:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)pp_keyboardWillChange:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardInView = [self.view convertRect:keyboardFrame fromView:nil];
    if (!self.usesKeyboardLayoutGuide) {
        CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardInView) - self.view.safeAreaInsets.bottom);
        BOOL isHide = [notification.name isEqualToString:UIKeyboardWillHideNotification];
        self.inputBottomConstraint.constant = isHide ? -10.0 : -(overlap + 10.0);
    }

    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (duration <= 0.0) duration = 0.25;
    UIViewAnimationOptions options = ([userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self.view layoutIfNeeded];
        [self pp_scrollToBottomAnimated:NO];
    } completion:nil];
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    if (self.didPrepareEntranceAnimation || self.didRunEntranceAnimation) return;
    self.didPrepareEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
        self.chatInputBar.alpha = 1.0;
        self.chatInputBar.transform = CGAffineTransformIdentity;
        return;
    }

    self.tableView.tableHeaderView.alpha = 0.0;
    self.tableView.tableHeaderView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 10.0),
                                                                       CGAffineTransformMakeScale(0.99, 0.99));
    self.chatInputBar.alpha = 0.0;
    self.chatInputBar.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
}

- (void)pp_startAmbientMotionIfNeeded
{
    if (self.ambientMotionRunning || UIAccessibilityIsReduceMotionEnabled()) return;
    self.ambientMotionRunning = YES;
    [self.ambientTopGlowView.layer removeAllAnimations];
    [self.ambientBottomGlowView.layer removeAllAnimations];

    [UIView animateWithDuration:6.0
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientTopGlowView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-12.0, 16.0), CGAffineTransformMakeScale(1.06, 1.06));
        self.ambientTopGlowView.alpha = 0.52;
    } completion:nil];

    [UIView animateWithDuration:7.2
                          delay:0.3
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientBottomGlowView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(16.0, -12.0), CGAffineTransformMakeScale(1.05, 1.05));
        self.ambientBottomGlowView.alpha = 0.60;
    } completion:nil];
}

- (void)pp_stopAmbientMotion
{
    self.ambientMotionRunning = NO;
    [self.ambientTopGlowView.layer removeAllAnimations];
    [self.ambientBottomGlowView.layer removeAllAnimations];
    self.ambientTopGlowView.transform = CGAffineTransformIdentity;
    self.ambientBottomGlowView.transform = CGAffineTransformIdentity;
}

- (void)pp_runEntranceAnimationIfNeeded
{
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
        self.chatInputBar.alpha = 1.0;
        self.chatInputBar.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42 delay:0.0 usingSpringWithDamping:0.90 initialSpringVelocity:0.22 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.44 delay:0.06 usingSpringWithDamping:0.86 initialSpringVelocity:0.28 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.chatInputBar.alpha = 1.0;
        self.chatInputBar.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self pp_animateVisibleMessagesIfNeeded];
}

- (void)pp_animateVisibleMessagesIfNeeded
{
    if (self.didAnimateMessages || UIAccessibilityIsReduceMotionEnabled()) return;
    self.didAnimateMessages = YES;
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    [cells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
        cell.contentView.alpha = 0.0;
        cell.contentView.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
        [UIView animateWithDuration:0.38 delay:MIN(idx, 8) * 0.03 usingSpringWithDamping:0.88 initialSpringVelocity:0.24 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            cell.contentView.alpha = 1.0;
            cell.contentView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Audio Playback

- (void)pp_handleAudioTapForMessageID:(NSString *)messageID fileURL:(NSString *)fileURL
{
    if (messageID.length == 0 || fileURL.length == 0) return;

    if ([self.playingAudioMessageID isEqualToString:messageID] && self.audioPlayer.isPlaying) {
        [self pp_stopAudioPlaybackAndRefresh:YES];
        return;
    }

    if ([self.loadingAudioMessageID isEqualToString:messageID]) return;

    NSString *previousID = self.playingAudioMessageID ?: self.loadingAudioMessageID ?: @"";
    [self pp_stopAudioPlaybackAndRefresh:NO];
    self.loadingAudioMessageID = messageID;
    [self pp_reloadAudioRowsForMessageIDs:@[previousID, messageID]];

    NSURL *url = [NSURL URLWithString:fileURL];
    if (!url) {
        self.loadingAudioMessageID = nil;
        [self pp_reloadAudioRowsForMessageIDs:@[messageID]];
        [PPToast toast:kLang(@"ch_provider_voice_play_error")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![strongSelf.loadingAudioMessageID isEqualToString:messageID]) return;
            if (data.length == 0) {
                strongSelf.loadingAudioMessageID = nil;
                [strongSelf pp_reloadAudioRowsForMessageIDs:@[messageID]];
                [PPToast toast:kLang(@"ch_provider_voice_play_error")];
                return;
            }

            NSError *sessionError = nil;
            [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
            [AVAudioSession.sharedInstance setActive:YES error:&sessionError];

            NSError *playerError = nil;
            strongSelf.audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:&playerError];
            strongSelf.audioPlayer.delegate = strongSelf;
            if (!strongSelf.audioPlayer || playerError || ![strongSelf.audioPlayer play]) {
                strongSelf.audioPlayer = nil;
                strongSelf.loadingAudioMessageID = nil;
                [strongSelf pp_reloadAudioRowsForMessageIDs:@[messageID]];
                [PPToast toast:kLang(@"ch_provider_voice_play_error")];
                return;
            }

            strongSelf.playingAudioMessageID = messageID;
            strongSelf.loadingAudioMessageID = nil;
            [strongSelf pp_reloadAudioRowsForMessageIDs:@[previousID, messageID]];
        });
    });
}

- (void)pp_stopAudioPlaybackAndRefresh:(BOOL)refresh
{
    NSString *previousPlaying = self.playingAudioMessageID ?: @"";
    NSString *previousLoading = self.loadingAudioMessageID ?: @"";
    [self.audioPlayer stop];
    self.audioPlayer.delegate = nil;
    self.audioPlayer = nil;
    self.playingAudioMessageID = nil;
    self.loadingAudioMessageID = nil;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    if (refresh) {
        [self pp_reloadAudioRowsForMessageIDs:@[previousPlaying, previousLoading]];
    }
}

- (void)pp_reloadAudioRowsForMessageIDs:(NSArray<NSString *> *)messageIDs
{
    NSMutableSet<NSString *> *ids = [NSMutableSet set];
    for (NSString *messageID in messageIDs) {
        NSString *trimmed = PPMessageTrimmedString(messageID);
        if (trimmed.length > 0) [ids addObject:trimmed];
    }
    if (ids.count == 0) return;

    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    [self.messages enumerateObjectsUsingBlock:^(NSDictionary *message, NSUInteger index, __unused BOOL *stop) {
        NSString *messageID = PPMessageTrimmedString(message[@"ID"] ?: message[@"id"]);
        if ([ids containsObject:messageID]) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
    }];
    if (indexPaths.count == 0) return;

    [UIView performWithoutAnimation:^{
        [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self pp_stopAudioPlaybackAndRefresh:YES];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    [self pp_stopAudioPlaybackAndRefresh:YES];
    [PPToast toast:kLang(@"ch_provider_voice_play_error")];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPUserMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPUserMessageCell" forIndexPath:indexPath];
    NSDictionary *message = self.messages[indexPath.row];
    [cell configureWithMessage:message
                 currentUserID:[FIRAuth auth].currentUser.uid ?: @""
         senderParticipantType:[self pp_identityTypeForMessage:message]
                     formatter:self.dateFormatter
          playingAudioMessageID:self.playingAudioMessageID ?: @""
           loadingAudioMessageID:self.loadingAudioMessageID ?: @""];
    __weak typeof(self) weakSelf = self;
    cell.audioTapHandler = ^(NSString *messageID, NSString *fileURL) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_handleAudioTapForMessageID:messageID fileURL:fileURL];
    };
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self pp_sendMessage];
    return NO;
}

#pragma mark - PPChatInputBarDelegate

- (void)chatInputBar:(UIView *)inputBar didTapSendWithText:(NSString *)text
{
    [self pp_sendMessage];
}

- (void)chatInputBarDidStartRecording:(UIView *)inputBar
{
    [self pp_scrollToBottomAnimated:YES];
}

- (void)chatInputBar:(UIView *)inputBar didFinishRecordingAtURL:(NSURL *)fileURL duration:(NSTimeInterval)duration waveformSamples:(NSArray<NSNumber *> *)waveformSamples
{
    [self pp_sendVoiceRecordingAtURL:fileURL duration:duration waveformSamples:waveformSamples];
}

- (void)chatInputBarDidCancelRecording:(UIView *)inputBar
{
    [PPToast toast:kLang(@"ch_provider_record_cancelled")];
}

- (void)chatInputBarRecordingPermissionDenied:(UIView *)inputBar
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"ch_provider_record_permission_title")
                                                                   message:kLang(@"ch_provider_record_permission_message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chatInputBar:(UIView *)inputBar didFailRecordingWithError:(NSError *)error
{
    [PPToast toast:kLang(@"ch_provider_record_failed")];
}

- (void)chatInputBarDidTapAttachment:(UIView *)inputBar
{
    // The leading input action is voice recording. Keep this fallback for older callers.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"ch_provider_attachment_title") 
                                                                   message:kLang(@"ch_provider_attachment_message") 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chatInputBar:(UIView *)inputBar textDidChange:(NSString *)text
{
    BOOL isTyping = PPMessageTrimmedString(text).length > 0;
    [self.typingDebounceTimer invalidate];
    self.typingDebounceTimer = nil;
    [self pp_setTypingActive:isTyping];
    if (isTyping) {
        self.typingDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                                     target:self
                                                                   selector:@selector(pp_typingDebounceDidFire:)
                                                                   userInfo:nil
                                                                    repeats:NO];
    }
}

- (void)chatInputBar:(UIView *)inputBar heightDidChange:(CGFloat)height
{
    // Height changed callback - adjust table view inset if needed
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.bottom = height + 8.0; // input bar height + spacing
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
    [self pp_scrollToBottomAnimated:YES];
}

@end
