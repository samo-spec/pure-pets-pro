//
//  ChatBubbleView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Copied to PurePetsPro for messaging parity (adapted for Styling system)

#import "ChatBubbleView.h"
#import "PPChatsFunc.h"

@interface ChatBubbleView ()

@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *replyPreviewView;
@property (nonatomic, strong) UIView *replyAccentView;
@property (nonatomic, strong) UILabel *replyTitleLabel;
@property (nonatomic, strong) UILabel *replySubtitleLabel;
@property (nonatomic, strong) UIView *messageContainerView;
@property (nonatomic, strong) UIStackView *messageMetadataStack;
@property (nonatomic, strong) UIImageView *deletedIconView;
@property (nonatomic, strong, readwrite) UILabel *messageLabel;
@property (nonatomic, strong) UIStackView *metadataStack;
@property (nonatomic, strong) UIView *metadataSpacerView;
@property (nonatomic, strong, readwrite) UILabel *timeLabel;
@property (nonatomic, strong, readwrite) UIImageView *statusImageView;
@property (nonatomic, strong) NSLayoutConstraint *maxWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *replyPreviewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *messageLeadingStandardConstraint;
@property (nonatomic, strong) NSLayoutConstraint *messageLeadingDeletedConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *minimumHeightConstraint;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, assign) BOOL replyPreviewVisible;
@property (nonatomic, assign) BOOL contextMenuPresentationActive;
@property (nonatomic, assign) ChatMessageStatus currentStatus;

@end

@implementation ChatBubbleView

- (void)setGroupPosition:(PPChatGroupPosition)groupPosition
{
    if (_groupPosition == groupPosition) return;
    _groupPosition = groupPosition;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    BOOL glow = self.isIncoming && self.groupPosition != PPChatGroupPositionMiddle;
    [PPChatsFunc applyBubbleMask:self isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:glow];
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) [self pp_commonInit];
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) [self pp_commonInit];
    return self;
}

- (void)pp_commonInit
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentType = ChatBubbleContentTypeText;
    self.groupPosition = PPChatGroupPositionSingle;
    self.maxBubbleWidth = UIScreen.mainScreen.bounds.size.width * 0.78;
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self pp_buildHierarchy];
    [self pp_buildConstraints];
    [self pp_applyTypography];
    [self pp_applyLanguageDirection];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory
          isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_applyTypography];
        [self pp_updateMessageMetadataLayout];
    }
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyVisualTheme];
        }
    }
}

#pragma mark - Construction

- (UILabel *)pp_labelWithLines:(NSInteger)lines
{
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = lines;
    label.textAlignment = NSTextAlignmentNatural;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)pp_buildHierarchy
{
    self.replyPreviewView = [UIView new];
    self.replyPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyPreviewView.hidden = YES;
    self.replyPreviewView.clipsToBounds = YES;
    self.replyPreviewView.layer.cornerRadius = 12.0;
    self.replyPreviewView.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        self.replyPreviewView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.replyAccentView = [UIView new];
    self.replyAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.replyAccentView.layer.cornerRadius = 1.5;
    [self.replyPreviewView addSubview:self.replyAccentView];

    self.replyTitleLabel = [self pp_labelWithLines:1];
    self.replyTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.replyPreviewView addSubview:self.replyTitleLabel];

    self.replySubtitleLabel = [self pp_labelWithLines:1];
    self.replySubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.replyPreviewView addSubview:self.replySubtitleLabel];

    self.messageContainerView = [UIView new];
    self.messageContainerView.translatesAutoresizingMaskIntoConstraints = NO;

    self.deletedIconView = [[UIImageView alloc] initWithImage:PPSYSImage(@"arrow.uturn.backward.circle")];
    self.deletedIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.deletedIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.deletedIconView.hidden = YES;
    [self.messageContainerView addSubview:self.deletedIconView];

    self.messageLabel = [self pp_labelWithLines:0];
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisVertical];
    [self.messageContainerView addSubview:self.messageLabel];

    self.metadataSpacerView = [UIView new];
    self.metadataSpacerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.metadataSpacerView setContentHuggingPriority:UILayoutPriorityDefaultLow
                                             forAxis:UILayoutConstraintAxisHorizontal];

    self.timeLabel = [self pp_labelWithLines:1];
    [self.timeLabel setContentHuggingPriority:UILayoutPriorityRequired
                                     forAxis:UILayoutConstraintAxisHorizontal];

    self.statusImageView = [UIImageView new];
    self.statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.statusImageView setContentHuggingPriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];

    self.metadataStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.metadataSpacerView,
        self.timeLabel,
        self.statusImageView,
    ]];
    self.metadataStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.metadataStack.axis = UILayoutConstraintAxisHorizontal;
    self.metadataStack.alignment = UIStackViewAlignmentCenter;
    self.metadataStack.spacing = 4.0;
    [self.metadataStack setContentHuggingPriority:UILayoutPriorityRequired
                                         forAxis:UILayoutConstraintAxisHorizontal];
    [self.metadataStack setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];

    self.messageMetadataStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.messageContainerView,
        self.metadataStack,
    ]];
    self.messageMetadataStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageMetadataStack.axis = UILayoutConstraintAxisVertical;
    self.messageMetadataStack.alignment = UIStackViewAlignmentFill;
    self.messageMetadataStack.spacing = 4.0;

    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.replyPreviewView,
        self.messageMetadataStack,
    ]];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.spacing = 5.0;
    [self addSubview:self.contentStack];
}

- (void)pp_buildConstraints
{
    self.replyPreviewHeightConstraint =
        [self.replyPreviewView.heightAnchor constraintEqualToConstant:0.0];
    self.contentTopConstraint =
        [self.contentStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8.0];
    self.contentLeadingConstraint =
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8.0];
    self.contentTrailingConstraint =
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8.0];
    self.contentBottomConstraint =
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8.0];
    self.minimumHeightConstraint =
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:44.0];
    [NSLayoutConstraint activateConstraints:@[
        self.contentTopConstraint,
        self.contentLeadingConstraint,
        self.contentTrailingConstraint,
        self.contentBottomConstraint,

        self.replyPreviewHeightConstraint,
        [self.replyAccentView.leadingAnchor constraintEqualToAnchor:self.replyPreviewView.leadingAnchor constant:9.0],
        [self.replyAccentView.centerYAnchor constraintEqualToAnchor:self.replyPreviewView.centerYAnchor],
        [self.replyAccentView.widthAnchor constraintEqualToConstant:3.0],
        [self.replyAccentView.heightAnchor constraintEqualToConstant:27.0],
        [self.replyTitleLabel.topAnchor constraintEqualToAnchor:self.replyPreviewView.topAnchor constant:6.0],
        [self.replyTitleLabel.leadingAnchor constraintEqualToAnchor:self.replyAccentView.trailingAnchor constant:8.0],
        [self.replyTitleLabel.trailingAnchor constraintEqualToAnchor:self.replyPreviewView.trailingAnchor constant:-9.0],
        [self.replySubtitleLabel.topAnchor constraintEqualToAnchor:self.replyTitleLabel.bottomAnchor constant:1.0],
        [self.replySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.replyTitleLabel.leadingAnchor],
        [self.replySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.replyTitleLabel.trailingAnchor],

        [self.deletedIconView.leadingAnchor constraintEqualToAnchor:self.messageContainerView.leadingAnchor],
        [self.deletedIconView.centerYAnchor constraintEqualToAnchor:self.messageLabel.centerYAnchor],
        [self.deletedIconView.widthAnchor constraintEqualToConstant:17.0],
        [self.deletedIconView.heightAnchor constraintEqualToConstant:17.0],
        [self.messageLabel.topAnchor constraintEqualToAnchor:self.messageContainerView.topAnchor],
        [self.messageLabel.trailingAnchor constraintEqualToAnchor:self.messageContainerView.trailingAnchor],
        [self.messageLabel.bottomAnchor constraintEqualToAnchor:self.messageContainerView.bottomAnchor],

        [self.statusImageView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusImageView.heightAnchor constraintEqualToConstant:12.0],
        self.minimumHeightConstraint,
    ]];

    self.messageLeadingStandardConstraint =
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.messageContainerView.leadingAnchor];
    self.messageLeadingDeletedConstraint =
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.deletedIconView.trailingAnchor constant:7.0];
    self.messageLeadingStandardConstraint.active = YES;

    self.maxWidthConstraint = [self.widthAnchor constraintLessThanOrEqualToConstant:self.maxBubbleWidth];
    self.maxWidthConstraint.active = YES;
}

#pragma mark - Configuration

- (void)setMessageText:(NSString *)message
                 time:(NSDate *)date
           isIncoming:(BOOL)isIncoming
               status:(ChatMessageStatus)status
{
    self.contentType = ChatBubbleContentTypeText;
    self.isIncoming = isIncoming;
    self.isDeleted = NO;
    self.currentStatus = status;
    self.messageLabel.text = message ?: @"";
    self.timeLabel.text = [self pp_formattedTime:date];
    [self clearReplyPreview];
    [self pp_applyDeletedState:NO];
    [self pp_applyTypography];
    [self pp_applyVisualTheme];

    ChatMessageModel *statusModel = [ChatMessageModel new];
    statusModel.status = status;
    [PPChatsFunc applyStatusForMessage:statusModel
                         toImageView:self.statusImageView
                          isIncoming:isIncoming
                            animated:NO];
    [self pp_updateMessageMetadataLayout];
    [self pp_updateAccessibility];
    [self setNeedsLayout];
}

- (void)setDeleted:(BOOL)deleted animated:(BOOL)animated
{
    if (self.isDeleted == deleted) return;
    self.isDeleted = deleted;
    void (^changes)(void) = ^{
        [self pp_applyDeletedState:deleted];
        [self pp_applyVisualTheme];
        [self pp_updateMessageMetadataLayout];
        [self pp_updateAccessibility];
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView transitionWithView:self
                      duration:0.24
                       options:UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState |
                               UIViewAnimationOptionAllowUserInteraction
                    animations:changes
                    completion:nil];
}

- (void)updateMessageStatus:(ChatMessageModel *)message animated:(BOOL)animated
{
    self.currentStatus = message.status;
    [PPChatsFunc applyStatusForMessage:message
                         toImageView:self.statusImageView
                          isIncoming:self.isIncoming
                            animated:animated];
    [self pp_updateMessageMetadataLayout];
    [self pp_updateAccessibility];
}

- (void)setContextMenuPresentationActive:(BOOL)active
{
    if (_contextMenuPresentationActive == active) return;
    _contextMenuPresentationActive = active;

    if (!active) {
        [self pp_applyVisualTheme];
    }
}

- (void)setReplyPreviewTitle:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                   isIncoming:(BOOL)isIncoming
{
    if (title.length == 0 && subtitle.length == 0) {
        [self clearReplyPreview];
        return;
    }
    self.replyPreviewVisible = YES;
    self.replyPreviewView.hidden = NO;
    self.replyPreviewHeightConstraint.constant = 46.0;
    self.replyTitleLabel.text = title.length > 0 ? title : kLang(@"chat_replying");
    self.replySubtitleLabel.text = subtitle.length > 0 ? subtitle : kLang(@"Message");
    [self pp_updateAccessibility];
}

- (void)clearReplyPreview
{
    self.replyPreviewVisible = NO;
    self.replyPreviewHeightConstraint.constant = 0.0;
    self.replyPreviewView.hidden = YES;
    self.replyTitleLabel.text = nil;
    self.replySubtitleLabel.text = nil;
    [self pp_updateAccessibility];
}

- (void)setMaxBubbleWidth:(CGFloat)maxBubbleWidth
{
    _maxBubbleWidth = MAX(120.0, maxBubbleWidth);
    self.maxWidthConstraint.constant = _maxBubbleWidth;
    [self pp_updateMessageMetadataLayout];
}

- (UIImageView *)getStatusImageView
{
    return self.statusImageView;
}

#pragma mark - Visual System

- (void)pp_applyTypography
{
    UIFontMetrics *bodyMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleBody];
    UIFontMetrics *captionMetrics = [UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2];
    self.messageLabel.font = [bodyMetrics scaledFontForFont:(PPFontRegular(16.0) ?: [UIFont systemFontOfSize:16.0])
                                        maximumPointSize:22.0];
    self.timeLabel.font = [captionMetrics scaledFontForFont:(PPFontRegular(10.5) ?: [UIFont systemFontOfSize:10.5])
                                        maximumPointSize:15.0];
    self.replyTitleLabel.font = [captionMetrics scaledFontForFont:(PPFontBold(11.0) ?: [UIFont boldSystemFontOfSize:11.0])
                                            maximumPointSize:15.0];
    self.replySubtitleLabel.font = [captionMetrics scaledFontForFont:(PPFontMedium(12.0) ?: [UIFont systemFontOfSize:12.0])
                                                 maximumPointSize:16.0];

    if (!self.isDeleted && [self pp_isEmojiOnlyText:self.messageLabel.text]) {
        self.messageLabel.font = [UIFont systemFontOfSize:46.0];
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
    } else {
        self.messageLabel.textAlignment = NSTextAlignmentNatural;
    }
}

- (CGFloat)pp_singleLineTextWidth
{
    NSString *text = self.messageLabel.text ?: @"";
    if (text.length == 0) return 0.0;

    CGSize measured = [text sizeWithAttributes:@{NSFontAttributeName: self.messageLabel.font}];
    return ceil(measured.width);
}

- (CGFloat)pp_singleLineMessageContentWidth
{
    CGFloat width = [self pp_singleLineTextWidth];
    if (self.isDeleted && !self.deletedIconView.hidden) {
        width += 24.0;
    }
    return width;
}

- (CGFloat)pp_metadataWidth
{
    CGFloat width = ceil([self.timeLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width);
    if (!self.statusImageView.hidden && self.statusImageView.image) {
        width += self.metadataStack.spacing + 12.0;
    }
    return width;
}

- (BOOL)pp_shouldInlineMessageMetadata
{
    NSString *text = self.messageLabel.text ?: @"";
    if (text.length == 0 || [self pp_isEmojiOnlyText:text]) return NO;
    if ([text rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound) return NO;

    CGFloat horizontalContentInsets = 22.0;
    CGFloat availableContentWidth = MAX(0.0, self.maxBubbleWidth - horizontalContentInsets);
    CGFloat metadataWidth = [self pp_metadataWidth];
    CGFloat availableTextWidth = availableContentWidth - metadataWidth - 7.0;
    return [self pp_singleLineMessageContentWidth] <= floor(availableTextWidth + 0.5);
}

- (void)pp_updateMessageMetadataLayout
{
    if (!self.messageMetadataStack) return;

    BOOL inlineMetadata = [self pp_shouldInlineMessageMetadata];
    self.messageMetadataStack.axis = inlineMetadata
        ? UILayoutConstraintAxisHorizontal
        : UILayoutConstraintAxisVertical;
    self.messageMetadataStack.alignment = inlineMetadata
        ? UIStackViewAlignmentCenter
        : UIStackViewAlignmentFill;
    self.messageMetadataStack.spacing = inlineMetadata ? 7.0 : 4.0;
    self.metadataSpacerView.hidden = inlineMetadata;
    self.contentTopConstraint.constant = inlineMetadata ? 5.0 : 8.0;
    self.contentBottomConstraint.constant = inlineMetadata ? -5.0 : -7.0;
    self.contentLeadingConstraint.constant = inlineMetadata ? 11.0 : 12.0;
    self.contentTrailingConstraint.constant = inlineMetadata ? -11.0 : -12.0;
    self.minimumHeightConstraint.constant = inlineMetadata ? 36.0 : 44.0;

    UILayoutPriority messageHugging = inlineMetadata
        ? UILayoutPriorityRequired
        : UILayoutPriorityDefaultLow;
    [self.messageContainerView setContentHuggingPriority:messageHugging
                                               forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageContainerView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                forAxis:UILayoutConstraintAxisHorizontal];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)pp_applyVisualTheme
{
    BOOL emojiOnly = !self.isDeleted && [self pp_isEmojiOnlyText:self.messageLabel.text];
    UIColor *foreground = [PPChatsFunc bubblePrimaryContentColorForIncoming:self.isIncoming];
    UIColor *secondary = [PPChatsFunc bubbleSecondaryContentColorForIncoming:self.isIncoming];

    self.backgroundColor = emojiOnly
        ? UIColor.clearColor
        : [PPChatsFunc bubbleSurfaceColorForIncoming:self.isIncoming];
    self.messageLabel.textColor = self.isDeleted
        ? [foreground colorWithAlphaComponent:0.68]
        : foreground;
    self.timeLabel.textColor = secondary;
    self.deletedIconView.tintColor = [foreground colorWithAlphaComponent:0.58];

    self.layer.borderWidth = 0.0;
    self.layer.shadowOpacity = 0.0;
    [self pp_applyReplyTheme];
}

- (void)pp_applyReplyTheme
{
    UIColor *foreground = [PPChatsFunc bubblePrimaryContentColorForIncoming:self.isIncoming];
    self.replyAccentView.backgroundColor =
        [PPChatsFunc bubbleInteractiveAccentColorForIncoming:self.isIncoming];
    self.replyPreviewView.backgroundColor =
        [PPChatsFunc bubbleReplySurfaceColorForIncoming:self.isIncoming];
    self.replyPreviewView.layer.borderColor =
        [PPChatsFunc bubbleStrokeColorForIncoming:self.isIncoming].CGColor;
    self.replyTitleLabel.textColor = foreground;
    self.replySubtitleLabel.textColor = [foreground colorWithAlphaComponent:0.66];
}

- (void)pp_applyDeletedState:(BOOL)deleted
{
    self.deletedIconView.hidden = !deleted;
    self.messageLeadingStandardConstraint.active = !deleted;
    self.messageLeadingDeletedConstraint.active = deleted;
    if (deleted) {
        self.messageLabel.text = kLang(@"chat_message_unsent");
        self.messageLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
        self.statusImageView.hidden = YES;
        [self clearReplyPreview];
    }
    [self pp_applyTypography];
}

- (void)pp_applyLanguageDirection
{
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.replyPreviewView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.messageLabel.textAlignment = NSTextAlignmentNatural;
    self.replyTitleLabel.textAlignment = NSTextAlignmentNatural;
    self.replySubtitleLabel.textAlignment = NSTextAlignmentNatural;
}

#pragma mark - Accessibility And Formatting

- (void)pp_updateAccessibility
{
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.messageLabel.isAccessibilityElement = NO;
    self.timeLabel.isAccessibilityElement = NO;
    self.statusImageView.isAccessibilityElement = NO;
    self.replyPreviewView.isAccessibilityElement = NO;

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:self.isIncoming ? kLang(@"chat_accessibility_incoming") : kLang(@"chat_accessibility_outgoing")];
    if (self.replyPreviewVisible && self.replySubtitleLabel.text.length > 0) {
        [parts addObject:[NSString stringWithFormat:kLang(@"chat_accessibility_reply_format"),
                                                   self.replySubtitleLabel.text]];
    }
    if (self.messageLabel.text.length > 0) [parts addObject:self.messageLabel.text];
    if (self.timeLabel.text.length > 0) [parts addObject:self.timeLabel.text];
    if (!self.isIncoming && !self.isDeleted && self.statusImageView.accessibilityLabel.length > 0) {
        [parts addObject:self.statusImageView.accessibilityLabel];
    }
    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    self.accessibilityHint = self.isDeleted ? nil : kLang(@"chat_message_actions_hint");
}

- (NSString *)pp_formattedTime:(NSDate *)date
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.dateStyle = NSDateFormatterNoStyle;
    });
    formatter.locale = NSLocale.currentLocale;
    return [formatter stringFromDate:date ?: NSDate.date];
}

- (BOOL)isSingleLineMessage
{
    if (self.messageLabel.text.length == 0) return YES;
    CGFloat width = CGRectGetWidth(self.messageLabel.bounds);
    if (width <= 0.0) return YES;
    CGRect rect = [self.messageLabel.text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin |
                                                             NSStringDrawingUsesFontLeading
                                                  attributes:@{NSFontAttributeName: self.messageLabel.font}
                                                     context:nil];
    return ceil(rect.size.height) <= ceil(self.messageLabel.font.lineHeight + 1.0);
}

- (BOOL)pp_isEmojiOnlyText:(NSString *)text
{
    if (text.length == 0) return NO;
    __block BOOL foundEmoji = NO;
    __block BOOL foundOther = NO;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange,
                                         NSRange enclosingRange, BOOL *stop) {
        NSString *trimmed = [substring stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) return;
        __block BOOL scalarLooksEmoji = NO;
        [substring enumerateSubstringsInRange:NSMakeRange(0, substring.length)
                                        options:NSStringEnumerationByComposedCharacterSequences
                                     usingBlock:^(NSString *piece, NSRange pieceRange,
                                                  NSRange enclosingPieceRange, BOOL *pieceStop) {
            unichar value = [piece characterAtIndex:0];
            scalarLooksEmoji = (value >= 0x2100 && value <= 0x27FF) ||
                (value >= 0xD800 && value <= 0xDBFF) || value == 0x00A9 || value == 0x00AE;
            *pieceStop = YES;
        }];
        foundEmoji = foundEmoji || scalarLooksEmoji;
        foundOther = foundOther || !scalarLooksEmoji;
    }];
    return foundEmoji && !foundOther;
}

@end

@implementation ChatMediaBubbleView

- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL glow = self.isIncoming && self.groupPosition != PPChatGroupPositionMiddle;
    [PPChatsFunc applyBubbleMask:self isIncoming:self.isIncoming groupPosition:self.groupPosition showGlow:glow];
}

@end
