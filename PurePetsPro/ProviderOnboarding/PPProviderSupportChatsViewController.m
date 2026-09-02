//
//  PPProviderSupportChatsViewController.m
//  PurePetsPro
//

#import "PPProviderSupportChatsViewController.h"
#import "ChatThreadModel.h"
#import "PPUserMessagesViewController.h"
#import "Language.h"
#import "Styling.h"
#import "UserModel.h"
#import "UIImageView+WebCache.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <FirebaseAuth/FirebaseAuth.h>

static NSString * const kPPProviderSupportChatsTitle = @"ch_provider_support_chats_title";
static NSString * const kPPProviderSupportChatsSubtitle = @"ch_provider_support_chats_subtitle";
static NSString * const kPPProviderSupportChatsEmpty = @"ch_provider_support_empty";
static NSString * const kPPProviderSupportChatsError = @"ch_provider_support_error";
static NSString * const kPPConversationTypeProviderChat = @"provider_chat";

// The table header is content-driven but never collapses below its design height.
static const CGFloat kPPProviderSupportHeaderMinHeight = 214.0;

static NSString *PPChatTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static UIColor *PPChatBackgroundColor(void)
{
    if (@available(iOS 13.0, *)) return [UIColor ppSurface];
    return AppBackgroundClr;
}

static UIColor *PPChatSurfaceColor(void)
{
    return AppForgroundColr;
}

static UIColor *PPChatMatteColor(void)
{
    return [UIColor ppBackground];
}

static UIColor *PPChatPrimaryTextColor(void)
{
    return PrimaryTextClr;
}

static UIColor *PPChatSecondaryTextColor(void)
{
    return SeconderyTextClr;
}

static NSString *PPChatInitialForName(NSString *name)
{
    NSString *trimmed = PPChatTrimmedString(name);
    if (trimmed.length == 0) return @"?";
    NSRange firstCharacterRange = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
    return [[trimmed substringWithRange:firstCharacterRange] uppercaseString];
}

static NSString *PPChatLocalizedParticipantType(NSString *participantType)
{
    if ([participantType isEqualToString:PPChatParticipantTypeConsole]) {
        return kLang(@"ch_identity_console");
    }
    if ([participantType isEqualToString:PPChatParticipantTypeProvider]) {
        return kLang(@"ch_identity_provider");
    }
    return kLang(@"ch_identity_user");
}

static UIColor *PPChatParticipantTypeColor(NSString *participantType)
{
    if ([participantType isEqualToString:PPChatParticipantTypeConsole]) {
        return [UIColor ppQuickActionCommunity];
    }
    if ([participantType isEqualToString:PPChatParticipantTypeProvider]) {
        return AppPrimaryClr;
    }
    return PPChatSecondaryTextColor();
}

static BOOL PPChatMessageIsUnread(NSDictionary *payload)
{
    id status = payload[@"status"];
    if ([status isKindOfClass:[NSNumber class]]) {
        return [status integerValue] < 3;
    }
    if ([status isKindOfClass:[NSString class]]) {
        NSString *normalized = [[PPChatTrimmedString(status) lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (normalized.length == 0) return NO;
        return ![normalized isEqualToString:@"read"];
    }

    id isRead = payload[@"isRead"];
    if ([isRead isKindOfClass:[NSNumber class]]) {
        return ![(NSNumber *)isRead boolValue];
    }
    if ([isRead isKindOfClass:[NSString class]]) {
        NSString *normalized = [[PPChatTrimmedString(isRead) lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (normalized.length == 0) return NO;
        return !([normalized isEqualToString:@"true"] ||
                 [normalized isEqualToString:@"yes"] ||
                 [normalized isEqualToString:@"1"] ||
                 [normalized isEqualToString:@"read"]);
    }
    return NO;
}

static NSString *PPChatThreadIDFromMessage(FIRDocumentSnapshot *doc, NSDictionary *payload)
{
    NSString *threadID = doc.reference.parent.parent.documentID ?: @"";
    if (threadID.length > 0) return threadID;
    threadID = PPChatTrimmedString(payload[@"threadID"]);
    if (threadID.length > 0) return threadID;
    threadID = PPChatTrimmedString(payload[@"threadId"]);
    if (threadID.length > 0) return threadID;
    threadID = PPChatTrimmedString(payload[@"chatID"]);
    if (threadID.length > 0) return threadID;
    return PPChatTrimmedString(payload[@"chatId"]);
}

@interface PPProviderSupportChatCell : UITableViewCell
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, copy) NSString *representedParticipantID;
@property (nonatomic, assign) BOOL ppHasUnread;
- (void)configureWithThread:(ChatThreadModel *)thread unreadCount:(NSInteger)unreadCount dateFormatter:(NSDateFormatter *)formatter;
- (void)pp_applyBorderTint;
@end

@implementation PPProviderSupportChatCell

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

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    // Token card surface: elevated fill + hairline border + continuous corners + card shadow.
    // The resting/unread border tint is re-applied by -pp_applyBorderTint.
    PPStyleCardSurface(self.surfaceView, PPCornerCard);
    [self.contentView addSubview:self.surfaceView];

    self.avatarView = [[UIView alloc] init];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.backgroundColor = [PPChatMatteColor() colorWithAlphaComponent:0.86];
    // 25pt keeps the fixed 50x50 plate a true circle, so it stays off the radius token scale.
    PPApplyContinuousCorners(self.avatarView, 25.0);
    self.avatarView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.avatarView.layer.borderColor = AppPrimaryClrWithAlpha(0.16).CGColor;
    self.avatarView.clipsToBounds = YES;
    [self.surfaceView addSubview:self.avatarView];

    self.avatarImageView = [[UIImageView alloc] init];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.isAccessibilityElement = NO;
    [self.avatarView addSubview:self.avatarImageView];

    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarLabel.font = [Styling fontBold:PPFontHeadline];
    self.avatarLabel.textColor = AppPrimaryClr;
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    // No Dynamic Type: the initial sits inside a hard 50x50 circular plate.
    [self.avatarView addSubview:self.avatarLabel];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [Styling fontBold:PPFontTitle3];
    self.titleLabel.textColor = PPChatPrimaryTextColor();
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.numberOfLines = 1;
    PPEnableDynamicType(self.titleLabel, UIFontTextStyleTitle3);
    [self.surfaceView addSubview:self.titleLabel];

    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeLabel.font = [Styling fontBold:10.5];
    self.typeLabel.textAlignment = NSTextAlignmentCenter;
    // No Dynamic Type: fixed 18pt pill with no vertical inset to give back.
    PPApplyContinuousCorners(self.typeLabel, 9.0);
    self.typeLabel.clipsToBounds = YES;
    [self.surfaceView addSubview:self.typeLabel];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.font = [Styling fontMedium:13.5];
    self.messageLabel.textColor = PPChatSecondaryTextColor();
    self.messageLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.messageLabel.numberOfLines = 2;
    PPEnableDynamicType(self.messageLabel, UIFontTextStyleFootnote);
    [self.surfaceView addSubview:self.messageLabel];

    self.dateLabel = [[UILabel alloc] init];
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dateLabel.font = [Styling fontMedium:11.5];
    self.dateLabel.textColor = [PPChatSecondaryTextColor() colorWithAlphaComponent:0.72];
    self.dateLabel.textAlignment = Language.alignmentForCurrentLanguage;
    // No Dynamic Type: capped at 86pt in the same line as the title, so scaling
    // would either truncate the timestamp or starve the name beside it.
    [self.surfaceView addSubview:self.dateLabel];

    self.badgeLabel = [[UILabel alloc] init];
    self.badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.badgeLabel.font = [Styling fontBold:PPFontCaption1];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.textColor = UIColor.whiteColor;
    self.badgeLabel.backgroundColor = AppPrimaryClr;
    // No Dynamic Type: fixed 24x24 circular unread badge.
    PPApplyContinuousCorners(self.badgeLabel, 12.0);
    self.badgeLabel.clipsToBounds = YES;
    [self.surfaceView addSubview:self.badgeLabel];

    BOOL isRTL = Language.languageVal == 1;
    UIImageSymbolConfiguration *chevronConfig = [UIImageSymbolConfiguration configurationWithPointSize:PPFontFootnote weight:UIImageSymbolWeightSemibold];
    self.chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:isRTL ? @"chevron.left" : @"chevron.right" withConfiguration:chevronConfig]];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.tintColor = [PPChatSecondaryTextColor() colorWithAlphaComponent:0.55];
    self.chevronView.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.chevronView];

    // The row reads as a single VoiceOver button; the composed label is built in
    // -configureWithThread: from the already-localized row values.
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self pp_applyBorderTint];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceMDHalf],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceLG],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceLG],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceMDHalf],
        [self.surfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:108.0],

        [self.avatarView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSpaceBase],
        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:50.0],
        [self.avatarView.heightAnchor constraintEqualToConstant:50.0],

        [self.avatarImageView.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [self.avatarImageView.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [self.avatarImageView.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [self.avatarImageView.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],

        [self.avatarLabel.centerXAnchor constraintEqualToAnchor:self.avatarView.centerXAnchor],
        [self.avatarLabel.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],

        [self.dateLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceBase],
        [self.dateLabel.trailingAnchor constraintEqualToAnchor:self.chevronView.leadingAnchor constant:-10.0],
        [self.dateLabel.widthAnchor constraintLessThanOrEqualToConstant:86.0],

        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceBase],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:0.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:0.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceBase],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:14.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.dateLabel.leadingAnchor constant:-10.0],

        [self.typeLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:5.0],
        [self.typeLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.typeLabel.heightAnchor constraintEqualToConstant:18.0],
        [self.typeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:54.0],
        [self.typeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.dateLabel.leadingAnchor constant:-10.0],

        [self.messageLabel.topAnchor constraintEqualToAnchor:self.typeLabel.bottomAnchor constant:5.0],
        [self.messageLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.messageLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.badgeLabel.leadingAnchor constant:-10.0],
        [self.messageLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-14.0],

        [self.badgeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.badgeLabel.trailingAnchor constraintEqualToAnchor:self.dateLabel.trailingAnchor],
        [self.badgeLabel.centerYAnchor constraintEqualToAnchor:self.messageLabel.centerYAnchor],
        [self.badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [self.badgeLabel.heightAnchor constraintEqualToConstant:24.0],
    ]];
}

// Border tints are CGColor snapshots, so they are re-applied whenever the unread
// state or the light/dark appearance changes.
- (void)pp_applyBorderTint
{
    UIColor *tint = self.ppHasUnread
        ? AppPrimaryClrWithAlpha(0.26)
        : [PPChatSecondaryTextColor() colorWithAlphaComponent:0.10];
    self.surfaceView.layer.borderColor = tint.CGColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self pp_applyBorderTint];
        self.avatarView.layer.borderColor = AppPrimaryClrWithAlpha(0.16).CGColor;
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.representedParticipantID = @"";
    [self.avatarImageView sd_cancelCurrentImageLoad];
    self.avatarImageView.image = nil;
    self.avatarLabel.hidden = NO;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.contentView.alpha = 1.0;
}

- (void)configureWithThread:(ChatThreadModel *)thread unreadCount:(NSInteger)unreadCount dateFormatter:(NSDateFormatter *)formatter
{
    NSString *name = PPChatTrimmedString(thread.otherUser.PPBestDisplayName);
    if (name.length == 0) name = kLang(@"ch_provider_customer_fallback");

    NSString *message = PPChatTrimmedString(thread.lastMessage);
    if (message.length == 0) message = kLang(@"ch_provider_no_messages");

    self.titleLabel.text = name;
    self.messageLabel.text = message;
    NSString *participantID = PPChatTrimmedString(thread.otherUser.ID);
    self.representedParticipantID = participantID;
    self.avatarLabel.text = PPChatInitialForName(name);
    self.avatarLabel.hidden = NO;
    self.avatarImageView.image = nil;
    [self.avatarImageView sd_cancelCurrentImageLoad];

    NSString *photoURL = PPChatTrimmedString(thread.otherUser.UserImageUrl.absoluteString);
    if (photoURL.length == 0) photoURL = PPChatTrimmedString(thread.supportPhotoURLString);
    if (photoURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:photoURL]
                               placeholderImage:nil
                                      completed:^(UIImage * _Nullable image,
                                                  NSError * _Nullable error,
                                                  SDImageCacheType cacheType,
                                                  NSURL * _Nullable imageURL) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || ![strongSelf.representedParticipantID isEqualToString:participantID]) return;
            strongSelf.avatarLabel.hidden = image != nil;
        }];
    }

    NSString *participantType = thread.participantType.length > 0
        ? thread.participantType
        : PPChatParticipantTypeForProfile(nil, thread.sourcePlatform);
    UIColor *typeColor = PPChatParticipantTypeColor(participantType);
    self.typeLabel.text = [NSString stringWithFormat:@"  %@  ", PPChatLocalizedParticipantType(participantType)];
    self.typeLabel.textColor = typeColor;
    self.typeLabel.backgroundColor = [typeColor colorWithAlphaComponent:0.11];
    self.dateLabel.text = thread.timestamp ? [formatter stringFromDate:thread.timestamp] : @"";

    BOOL unread = unreadCount > 0;
    self.badgeLabel.hidden = !unread;
    self.badgeLabel.text = unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unreadCount];
    self.titleLabel.textColor = unread ? (AppPrimaryClr) : PPChatPrimaryTextColor();
    self.ppHasUnread = unread;
    [self pp_applyBorderTint];
    // Let the name wrap instead of truncating once the user is on an accessibility text size.
    self.titleLabel.numberOfLines = PPIsAccessibilityTextSize() ? 2 : 1;
    NSMutableArray<NSString *> *voiceOverParts = [NSMutableArray arrayWithObjects:name,
                                                  PPChatLocalizedParticipantType(participantType),
                                                  message, nil];
    if (self.dateLabel.text.length > 0) [voiceOverParts addObject:self.dateLabel.text];
    if (unread && self.badgeLabel.text.length > 0) [voiceOverParts addObject:self.badgeLabel.text];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel = [voiceOverParts componentsJoinedByString:@", "];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    CGFloat scale = highlighted ? PPTapCardScaleDown : 1.0;
    void (^changes)(void) = ^{
        self.surfaceView.transform = CGAffineTransformMakeScale(scale, scale);
    };
    if (animated && !PPMotionReduced()) {
        [UIView animateWithDuration:highlighted ? PPAnimDurationFast : PPAnimDurationNormal
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

@end

@interface PPProviderSupportChatsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyIconView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) UIStackView *emptyContentStack;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicatorView;
@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, weak) UIView *headerSurfaceView;
@property (nonatomic, strong) UILabel *headerActiveValueLabel;
@property (nonatomic, strong) UILabel *headerUnreadValueLabel;
@property (nonatomic, strong) UILabel *headerLatestValueLabel;
@property (nonatomic, strong) UILabel *headerStatusLabel;
@property (nonatomic, strong) UIView *ambientTopGlowView;
@property (nonatomic, strong) UIView *ambientBottomGlowView;
@property (nonatomic, strong) NSArray<ChatThreadModel *> *supportThreads;
@property (nonatomic, strong) id<FIRListenerRegistration> threadsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> messagesListener;
@property (nonatomic, strong) id<FIRListenerRegistration> legacyMessagesListener;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *unreadCountsByThreadID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *primaryUnreadCountsByThreadID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *legacyUnreadCountsByThreadID;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasError;
@property (nonatomic, assign) BOOL requiresAuth;
@property (nonatomic, assign) BOOL didAnimateRows;
@property (nonatomic, assign) BOOL didPrepareEntranceAnimation;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL ambientMotionRunning;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadingParticipantIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *resolvedParticipantIDs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UserModel *> *participantUsersByID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *participantTypesByID;
- (void)pp_prepareEntranceState;
- (void)pp_mergeUnreadCountsAndRefresh;
- (void)pp_registerAccessibilityObservers;
- (void)pp_updateTableHeaderHeight;
@end

@implementation PPProviderSupportChatsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.supportThreads = @[];
    self.unreadCountsByThreadID = [NSMutableDictionary dictionary];
    self.primaryUnreadCountsByThreadID = [NSMutableDictionary dictionary];
    self.legacyUnreadCountsByThreadID = [NSMutableDictionary dictionary];
    self.isLoading = YES;
    self.hasError = NO;
    self.loadingParticipantIDs = [NSMutableSet set];
    self.resolvedParticipantIDs = [NSMutableSet set];
    self.participantUsersByID = [NSMutableDictionary dictionary];
    self.participantTypesByID = [NSMutableDictionary dictionary];
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterNoStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
   
    [self pp_buildAmbientBackgroundIfNeeded];
    [self pp_configureTableView];
    [self pp_configureEmptyState];
    [self pp_updateEmptyState];
    [self pp_prepareEntranceState];
    [self pp_registerAccessibilityObservers];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self pp_startObservingChats];
    [self pp_startObservingUnreadMessages];
    [self pp_configureAppearance];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self pp_startAmbientMotionIfNeeded];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self pp_stopAmbientMotion];
    [self pp_stopObservingChats];
    [self pp_stopObservingUnreadMessages];
}

#pragma mark - Setup

- (void)pp_configureAppearance
{
    self.view.backgroundColor = PPChatBackgroundColor();
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                       button:nil
                        title:kLang(kPPProviderSupportChatsTitle)
                     showBack:YES];
}

- (void)pp_buildAmbientBackgroundIfNeeded
{
    if (self.ambientTopGlowView) return;

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.accessibilityElementsHidden = YES;
    topGlow.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    // 150/180pt radii keep the 300/360pt decorative plates perfectly circular.
    PPApplyContinuousCorners(topGlow, 150.0);
    [self.view insertSubview:topGlow atIndex:0];
    self.ambientTopGlowView = topGlow;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.accessibilityElementsHidden = YES;
    bottomGlow.backgroundColor = [PPChatPrimaryTextColor() colorWithAlphaComponent:0.035];
    PPApplyContinuousCorners(bottomGlow, 180.0);
    [self.view insertSubview:bottomGlow atIndex:0];
    self.ambientBottomGlowView = bottomGlow;

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:300.0],
        [topGlow.heightAnchor constraintEqualToConstant:300.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-96.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:82.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:360.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:360.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:130.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-120.0],
    ]];

    topGlow.alpha = 0.72;
    bottomGlow.alpha = 0.86;
}

- (void)pp_configureTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 92.0;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.contentInset = UIEdgeInsetsMake(PPSpaceMD, 0.0, PPSpaceXXL, 0.0);
    [self.tableView registerClass:PPProviderSupportChatCell.class forCellReuseIdentifier:@"PPProviderSupportChatCell"];
    [self.view addSubview:self.tableView];

    UIView *header = [self pp_makeHeaderView];
    self.tableHeaderView = header;
    self.tableView.tableHeaderView = header;
    [self pp_updateTableHeaderHeight];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

// The header used to be pinned to a hard 214pt frame, which clipped its copy at
// large text sizes.  It now measures its own content and keeps 214pt as a floor,
// so the default-size layout is byte-for-byte what it was before.
- (void)pp_updateTableHeaderHeight
{
    UIView *header = self.tableHeaderView;
    if (!header) return;

    CGFloat width = self.view.bounds.size.width > 0.0 ? self.view.bounds.size.width : UIScreen.mainScreen.bounds.size.width;
    CGSize fitting = [header systemLayoutSizeFittingSize:CGSizeMake(width, 0.0)
                          withHorizontalFittingPriority:UILayoutPriorityRequired
                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = MAX(kPPProviderSupportHeaderMinHeight, ceil(fitting.height));
    if (fabs(header.frame.size.height - height) < 0.5 && fabs(header.frame.size.width - width) < 0.5) return;

    CGAffineTransform restoreTransform = header.transform;
    header.transform = CGAffineTransformIdentity;
    header.frame = CGRectMake(0.0, 0.0, width, height);
    header.transform = restoreTransform;
    // Re-assigning is what commits the new height to the table.
    self.tableView.tableHeaderView = header;
}

- (UIView *)pp_makeHeaderView
{
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, kPPProviderSupportHeaderMinHeight)];
    container.backgroundColor = UIColor.clearColor;

    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [PPChatSurfaceColor() colorWithAlphaComponent:0.70];
    // Translucent hero plate: keeps its own alpha fill so the material below stays
    // visible, so only the radius/border/shadow come from the token scale.
    PPApplyContinuousCorners(surface, PPCornerHero);
    surface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surface.layer.borderColor = AppPrimaryClrWithAlpha(0.16).CGColor;
    surface.layer.shadowColor = AppShadowColor.CGColor;
    surface.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    surface.layer.shadowRadius = 34.0;
    surface.layer.shadowOpacity = 0.07;
    surface.clipsToBounds = NO;
    [container addSubview:surface];
    self.headerSurfaceView = surface;

    UIView *materialHost = [[UIView alloc] init];
    materialHost.translatesAutoresizingMaskIntoConstraints = NO;
    materialHost.clipsToBounds = YES;
    PPApplyContinuousCorners(materialHost, PPCornerHero);
    materialHost.userInteractionEnabled = NO;
    materialHost.accessibilityElementsHidden = YES;
    [surface addSubview:materialHost];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.userInteractionEnabled = NO;
        [materialHost addSubview:blur];
        [NSLayoutConstraint activateConstraints:@[
            [blur.topAnchor constraintEqualToAnchor:materialHost.topAnchor],
            [blur.leadingAnchor constraintEqualToAnchor:materialHost.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:materialHost.trailingAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:materialHost.bottomAnchor],
        ]];
    }

    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [Styling fontBold:PPFontCaption1];
    eyebrow.textColor = AppPrimaryClr;
    eyebrow.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrow.text = kLang(@"ch_provider_support_eyebrow");
    eyebrow.numberOfLines = 2;
    PPEnableDynamicType(eyebrow, UIFontTextStyleCaption1);
    [surface addSubview:eyebrow];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [Styling fontBold:32.0];
    title.textColor = PPChatPrimaryTextColor();
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.numberOfLines = 0;
    title.text = kLang(kPPProviderSupportChatsTitle);
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    PPEnableDynamicType(title, UIFontTextStyleLargeTitle);
    [surface addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.font = [Styling fontMedium:13.5];
    subtitle.textColor = [PPChatSecondaryTextColor() colorWithAlphaComponent:0.86];
    subtitle.textAlignment = Language.alignmentForCurrentLanguage;
    subtitle.numberOfLines = 0;
    subtitle.text = kLang(@"ch_provider_support_premium_subtitle");
    if (subtitle.text.length == 0 || [subtitle.text isEqualToString:@"ch_provider_support_premium_subtitle"]) {
        subtitle.text = kLang(kPPProviderSupportChatsSubtitle);
    }
    PPEnableDynamicType(subtitle, UIFontTextStyleFootnote);
    [surface addSubview:subtitle];

    UIView *mark = [[UIView alloc] init];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.backgroundColor = [PPChatMatteColor() colorWithAlphaComponent:0.84];
    // 26pt squircle on a fixed 64x64 glyph plate — kept off the token scale on purpose.
    PPApplyContinuousCorners(mark, 26.0);
    PPApplyCardShadow(mark);
    mark.isAccessibilityElement = NO;
    [surface addSubview:mark];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"message.badge.fill" withConfiguration:config] ?: [UIImage systemImageNamed:@"message.fill" withConfiguration:config]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr;
    icon.isAccessibilityElement = NO;
    [mark addSubview:icon];

    [NSLayoutConstraint activateConstraints:@[
        [surface.topAnchor constraintEqualToAnchor:container.topAnchor constant:18.0],
        [surface.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [surface.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [surface.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-18.0],

        [materialHost.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [materialHost.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [materialHost.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [materialHost.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],

        [eyebrow.topAnchor constraintEqualToAnchor:surface.topAnchor constant:PPSpaceXL],
        [eyebrow.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:22.0],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:mark.leadingAnchor constant:-PPSpaceBase],

        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:PPSpaceSM],
        [title.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:mark.leadingAnchor constant:-18.0],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],

        [mark.topAnchor constraintEqualToAnchor:surface.topAnchor constant:PPSpaceXL],
        [mark.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-22.0],
        [mark.widthAnchor constraintEqualToConstant:64.0],
        [mark.heightAnchor constraintEqualToConstant:64.0],

        // Bottom pins let the header measure its own content instead of trusting a
        // hard-coded height, which is what makes the scaled copy safe.
        [surface.bottomAnchor constraintGreaterThanOrEqualToAnchor:subtitle.bottomAnchor constant:PPSpaceXL],
        [surface.bottomAnchor constraintGreaterThanOrEqualToAnchor:mark.bottomAnchor constant:PPSpaceXL],

        [icon.centerXAnchor constraintEqualToAnchor:mark.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:mark.centerYAnchor],
    ]];

    return container;
}

- (void)pp_configureEmptyState
{
    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.backgroundColor = PPChatMatteColor();
    // Recessed matte placeholder: it keeps its own fill rather than the elevated
    // card surface, so only the radius comes from the token scale.
    PPApplyContinuousCorners(self.emptyStateView, PPCornerCard);
    self.emptyStateView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.emptyStateView.layer.borderColor = [PPChatSecondaryTextColor() colorWithAlphaComponent:0.08].CGColor;
    [self.view addSubview:self.emptyStateView];

    // Loading honesty: the placeholder now shows a real spinner while the chats
    // listener is still warming up, driven by the existing isLoading flag.
    self.loadingIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicatorView.hidesWhenStopped = YES;
    self.loadingIndicatorView.color = AppPrimaryClr;
    self.loadingIndicatorView.isAccessibilityElement = NO;

    self.emptyTitleLabel = [[UILabel alloc] init];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = [Styling fontBold:17.0];
    self.emptyTitleLabel.textColor = PPChatPrimaryTextColor();
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.numberOfLines = 0;
    PPEnableDynamicType(self.emptyTitleLabel, UIFontTextStyleHeadline);

    self.emptySubtitleLabel = [[UILabel alloc] init];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = [Styling fontMedium:13.0];
    self.emptySubtitleLabel.textColor = PPChatSecondaryTextColor();
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 0;
    PPEnableDynamicType(self.emptySubtitleLabel, UIFontTextStyleFootnote);

    // A stack keeps the card content growable and lets the stopped spinner
    // collapse instead of leaving a hole above the title.
    self.emptyContentStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.loadingIndicatorView,
                                                                            self.emptyTitleLabel,
                                                                            self.emptySubtitleLabel]];
    self.emptyContentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyContentStack.axis = UILayoutConstraintAxisVertical;
    self.emptyContentStack.alignment = UIStackViewAlignmentFill;
    self.emptyContentStack.spacing = PPSpaceSM;
    self.emptyContentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.emptyContentStack setCustomSpacing:PPSpaceMD afterView:self.loadingIndicatorView];
    [self.emptyStateView addSubview:self.emptyContentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:26.0],
        [self.emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-26.0],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:46.0],

        [self.emptyContentStack.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor constant:PPSpaceXL],
        [self.emptyContentStack.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:22.0],
        [self.emptyContentStack.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-22.0],
        [self.emptyContentStack.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor constant:-PPSpaceXL],
    ]];
}

#pragma mark - Query Scope

- (void)pp_startObservingChats
{
    if (self.threadsListener) return;
    NSString *providerUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (providerUID.length == 0) {
        self.supportThreads = @[];
        self.isLoading = NO;
        [self pp_updateEmptyState];
        return;
    }

    FIRQuery *query =
    [[[[[[FIRFirestore firestore] collectionWithPath:@"Chats"]
        queryWhereField:@"members" arrayContains:providerUID]
       queryWhereField:@"conversationType" isEqualTo:kPPConversationTypeProviderChat]
      queryWhereField:@"supportUserId" isEqualTo:providerUID]
     queryOrderedByField:@"timestamp" descending:YES];

    __weak typeof(self) weakSelf = self;
    self.threadsListener = [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.isLoading = NO;
            if (error) {
                strongSelf.hasError = YES;
                strongSelf.supportThreads = @[];
                [strongSelf.tableView reloadData];
                [strongSelf pp_updateEmptyState];
                return;
            }

            strongSelf.hasError = NO;
            NSMutableArray<ChatThreadModel *> *threads = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                if (!doc.exists) continue;
                ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:doc.data];
                thread.ID = doc.documentID;
                [threads addObject:thread];
            }
            strongSelf.supportThreads = threads.copy;
            [strongSelf pp_hydrateParticipantProfilesForThreads:strongSelf.supportThreads];
            [strongSelf.tableView reloadData];
            [strongSelf pp_updateEmptyState];
            [strongSelf pp_updateHeaderSummary];
            [strongSelf pp_animateVisibleRowsIfNeeded];
        });
    }];
}

- (void)pp_hydrateParticipantProfilesForThreads:(NSArray<ChatThreadModel *> *)threads
{
    for (ChatThreadModel *thread in threads) {
        NSString *participantID = PPChatTrimmedString(thread.otherUser.ID);
        if (participantID.length == 0) {
            continue;
        }

        if ([self.resolvedParticipantIDs containsObject:participantID]) {
            UserModel *cachedUser = self.participantUsersByID[participantID];
            NSString *cachedType = self.participantTypesByID[participantID];
            if (cachedUser) thread.otherUser = cachedUser;
            if (cachedType.length > 0) thread.participantType = cachedType;
            continue;
        }
        if ([self.loadingParticipantIDs containsObject:participantID]) continue;

        [self.loadingParticipantIDs addObject:participantID];
        FIRDocumentReference *profileRef = [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:participantID];
        __weak typeof(self) weakSelf = self;
        [profileRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;

                [strongSelf.loadingParticipantIDs removeObject:participantID];
                [strongSelf.resolvedParticipantIDs addObject:participantID];
                if (error || !snapshot.exists) {
                    strongSelf.participantTypesByID[participantID] = PPChatParticipantTypeForProfile(nil, thread.sourcePlatform);
                    return;
                }

                NSDictionary *profile = snapshot.data ?: @{};
                UserModel *resolvedUser = [[UserModel alloc] initWithSnapshot:snapshot];
                NSString *resolvedType = PPChatParticipantTypeForProfile(profile, thread.sourcePlatform);
                strongSelf.participantUsersByID[participantID] = resolvedUser;
                strongSelf.participantTypesByID[participantID] = resolvedType;
                for (ChatThreadModel *candidate in strongSelf.supportThreads) {
                    if (![PPChatTrimmedString(candidate.otherUser.ID) isEqualToString:participantID]) continue;

                    UserModel *fallbackUser = candidate.otherUser;
                    if (resolvedUser.PPBestDisplayName.length == 0) {
                        resolvedUser.UserName = fallbackUser.PPBestDisplayName;
                    }
                    if (!resolvedUser.UserImageUrl && fallbackUser.UserImageUrl) {
                        resolvedUser.UserImageUrl = fallbackUser.UserImageUrl;
                    }
                    candidate.otherUser = resolvedUser;
                    candidate.participantType = resolvedType;
                }
                [strongSelf.tableView reloadData];
            });
        }];
    }
}

- (void)pp_stopObservingChats
{
    [self.threadsListener remove];
    self.threadsListener = nil;
}

- (void)pp_startObservingUnreadMessages
{
    if (self.messagesListener) return;
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length == 0) return;

    // Use the composite collection-group index (receiverID + status)
    // that matches the consumer iOS app's ChManager global unread listener.
    // status < 3 means Sending(0), Sent(1), or Delivered(2) — all unread.
    FIRQuery *query =
    [[[[FIRFirestore firestore]
       collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:currentUID]
     queryWhereField:@"status" isLessThan:@(3)];

    __weak typeof(self) weakSelf = self;
    self.messagesListener = [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
            if (!error && snapshot) {
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    if (!doc.exists) continue;
                    NSDictionary *data = doc.data ?: @{};

                    NSString *threadID = PPChatThreadIDFromMessage(doc, data);
                    if (threadID.length == 0) continue;
                    NSInteger current = [counts[threadID] integerValue];
                    counts[threadID] = @(current + 1);
                }
            }
            strongSelf.unreadCountsByThreadID = counts;
            [strongSelf.tableView reloadData];
            [strongSelf pp_updateHeaderSummary];
        });
    }];
}

- (void)pp_mergeUnreadCountsAndRefresh
{
    // Kept for interface compatibility — now a simple passthrough.
    [self.tableView reloadData];
    [self pp_updateHeaderSummary];
}

- (void)pp_stopObservingUnreadMessages
{
    [self.messagesListener remove];
    self.messagesListener = nil;
    [self.legacyMessagesListener remove];
    self.legacyMessagesListener = nil;
    self.unreadCountsByThreadID = [NSMutableDictionary dictionary];
    self.primaryUnreadCountsByThreadID = [NSMutableDictionary dictionary];
    self.legacyUnreadCountsByThreadID = [NSMutableDictionary dictionary];
}

#pragma mark - Empty State

- (void)pp_updateEmptyState
{
    BOOL showEmpty = self.supportThreads.count == 0;
    self.emptyStateView.hidden = !showEmpty;
    self.tableView.hidden = showEmpty && !self.isLoading;

    if (self.hasError) {
        self.emptyTitleLabel.text = kLang(kPPProviderSupportChatsError);
        self.emptySubtitleLabel.text = kLang(@"ch_provider_support_error_subtitle");
    } else if (self.isLoading) {
        self.emptyTitleLabel.text = kLang(@"ch_provider_support_loading");
        self.emptySubtitleLabel.text = kLang(@"ch_provider_support_loading_subtitle");
    } else {
        self.emptyTitleLabel.text = kLang(kPPProviderSupportChatsEmpty);
        self.emptySubtitleLabel.text = kLang(@"ch_provider_support_empty_subtitle");
    }

    // Reduce Motion users are never given a perpetual spinner — the already
    // localized loading copy above carries the same state for them.
    BOOL shouldSpin = showEmpty && self.isLoading && !self.hasError && !PPMotionReduced();
    if (shouldSpin) {
        [self.loadingIndicatorView startAnimating];
    } else {
        [self.loadingIndicatorView stopAnimating];
    }
}

#pragma mark - Motion

- (void)pp_registerAccessibilityObservers
{
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(pp_reduceMotionStatusDidChange)
                                               name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                             object:nil];
}

// Reduce Motion can be switched on while this screen is already on screen, so the
// perpetual ambient drift has to be torn down immediately when that happens.
- (void)pp_reduceMotionStatusDidChange
{
    if (PPMotionReduced()) {
        [self pp_stopAmbientMotion];
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
        self.emptyStateView.alpha = 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
    } else if (self.viewIfLoaded.window) {
        [self pp_startAmbientMotionIfNeeded];
    }
    [self pp_updateEmptyState];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        // Scaled header copy needs a re-measure, and the rows re-lay out at the new size.
        [self pp_updateTableHeaderHeight];
        [self.tableView reloadData];
    }
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        // CGColor snapshots do not follow light/dark switches on their own.
        self.emptyStateView.layer.borderColor = [PPChatSecondaryTextColor() colorWithAlphaComponent:0.08].CGColor;
        self.headerSurfaceView.layer.borderColor = AppPrimaryClrWithAlpha(0.16).CGColor;
    }
}

- (void)pp_prepareEntranceState
{
    if (self.didPrepareEntranceAnimation || self.didRunEntranceAnimation) return;
    self.didPrepareEntranceAnimation = YES;

    if (PPMotionReduced()) {
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
        self.emptyStateView.alpha = 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
        return;
    }

    self.tableView.tableHeaderView.alpha = 0.0;
    self.tableView.tableHeaderView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                                                       CGAffineTransformMakeScale(0.99, 0.99));
    self.emptyStateView.alpha = 0.0;
    self.emptyStateView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
}

- (void)pp_startAmbientMotionIfNeeded
{
    // Never start perpetual/repeating motion under Reduce Motion.
    if (self.ambientMotionRunning || PPMotionReduced()) return;
    self.ambientMotionRunning = YES;
    [self.ambientTopGlowView.layer removeAllAnimations];
    [self.ambientBottomGlowView.layer removeAllAnimations];

    [UIView animateWithDuration:6.4
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientTopGlowView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-14.0, 18.0), CGAffineTransformMakeScale(1.07, 1.07));
        self.ambientTopGlowView.alpha = 0.50;
    } completion:nil];

    [UIView animateWithDuration:7.8
                          delay:0.25
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.ambientBottomGlowView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(14.0, -14.0), CGAffineTransformMakeScale(1.05, 1.05));
        self.ambientBottomGlowView.alpha = 0.58;
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

- (void)pp_updateHeaderSummary
{
    NSInteger unreadThreads = 0;
    NSDate *latestDate = nil;
    for (ChatThreadModel *thread in self.supportThreads) {
        NSInteger count = [self.unreadCountsByThreadID[thread.ID] integerValue];
        if (count > 0) {
            unreadThreads += 1;
        }
        NSDate *candidate = thread.timestamp ?: thread.lastMessageAt;
        if (candidate && (!latestDate || [candidate compare:latestDate] == NSOrderedDescending)) {
            latestDate = candidate;
        }
    }

    self.headerActiveValueLabel.text = self.isLoading ? @"--" : [NSString stringWithFormat:@"%ld", (long)self.supportThreads.count];
    self.headerUnreadValueLabel.text = self.isLoading ? @"--" : [NSString stringWithFormat:@"%ld", (long)unreadThreads];
    self.headerLatestValueLabel.text = latestDate ? [self.dateFormatter stringFromDate:latestDate] : @"--";
    if (self.hasError) {
        self.headerStatusLabel.text = kLang(@"ch_provider_support_offline");
        self.headerStatusLabel.textColor = [UIColor ppWarning];
        self.headerStatusLabel.backgroundColor = [[UIColor ppWarning] colorWithAlphaComponent:0.12];
    } else if (self.isLoading) {
        self.headerStatusLabel.text = kLang(@"ch_provider_support_syncing");
        self.headerStatusLabel.textColor = AppPrimaryClr;
        self.headerStatusLabel.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    } else {
        self.headerStatusLabel.text = kLang(@"ch_provider_support_live");
        self.headerStatusLabel.textColor = AppPrimaryClr;
        self.headerStatusLabel.backgroundColor = AppPrimaryClrWithAlpha(0.10);
    }
}

- (void)pp_retryLoadingChats
{
    [self pp_stopObservingChats];
    self.isLoading = YES;
    self.hasError = NO;
    self.requiresAuth = NO;
    self.supportThreads = @[];
    [self.tableView reloadData];
    [self pp_updateEmptyState];
    [self pp_startObservingChats];
}

- (void)pp_runEntranceAnimationIfNeeded
{
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;
    if (PPMotionReduced()) {
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
        self.emptyStateView.alpha = 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.52 delay:0.0 usingSpringWithDamping:0.88 initialSpringVelocity:0.32 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.tableView.tableHeaderView.alpha = 1.0;
        self.tableView.tableHeaderView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.42 delay:0.08 usingSpringWithDamping:0.90 initialSpringVelocity:0.22 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.emptyStateView.alpha = 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self pp_animateVisibleRowsIfNeeded];
}

- (void)pp_animateVisibleRowsIfNeeded
{
    if (self.didAnimateRows || PPMotionReduced()) return;
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    if (cells.count == 0) return;
    self.didAnimateRows = YES;
    [cells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
        cell.contentView.alpha = 0.0;
        cell.contentView.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        // Stagger is clamped at 6 steps (6 x 0.035 = 0.21s) so the last visible row
        // never waits noticeably longer than the first.
        NSTimeInterval staggerDelay = MIN(idx, 6) * 0.035;
        [UIView animateWithDuration:0.42 delay:staggerDelay usingSpringWithDamping:0.88 initialSpringVelocity:0.28 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            cell.contentView.alpha = 1.0;
            cell.contentView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.supportThreads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPProviderSupportChatCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProviderSupportChatCell" forIndexPath:indexPath];
    ChatThreadModel *thread = self.supportThreads[indexPath.row];
    NSInteger unreadCount = [self.unreadCountsByThreadID[thread.ID] integerValue];
    [cell configureWithThread:thread unreadCount:unreadCount dateFormatter:self.dateFormatter];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ChatThreadModel *thread = self.supportThreads[indexPath.row];
    PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
    messagesVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:messagesVC animated:YES];
}

@end
