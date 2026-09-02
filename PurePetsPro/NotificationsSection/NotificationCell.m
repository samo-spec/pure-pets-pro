//
//  NotificationCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// NotificationCell.m
#import "NotificationCell.h"
#import "NotificationManager+Targets.h"
#import "Styling.h"
#import "Language.h"

/// Per-category presentation.
///
/// The cell previously hardcoded `bell.badge.fill` and `AppPrimaryClr` for every
/// row, so a chat message, a cancelled order, a delivery request and an account
/// update were pixel-identical — the only variation in the entire list was read
/// vs unread. Meanwhile `NotificationManager+Targets` already computes a
/// five-way taxonomy (`PPProNotificationTargetKind`) in order to route the tap.
/// This reuses that same classification for presentation, so the icon a row
/// shows and the screen its tap opens can never disagree.
static NSString *PPNotificationSymbolForKind(PPProNotificationTargetKind kind)
{
    switch (kind) {
        case PPProNotificationTargetKindFulfillment:     return @"bag.fill";
        case PPProNotificationTargetKindDeliveryOrder:   return @"shippingbox.fill";
        case PPProNotificationTargetKindCompanyDelivery: return @"truck.box.fill";
        case PPProNotificationTargetKindChat:            return @"bubble.left.and.bubble.right.fill";
        case PPProNotificationTargetKindUnknown:
        default:                                         return @"bell.badge.fill";
    }
}

/// Accent per category, resolved only through existing `PPDesignTokens` colours so
/// the row introduces no new palette.
static UIColor *PPNotificationAccentForKind(PPProNotificationTargetKind kind)
{
    switch (kind) {
        case PPProNotificationTargetKindFulfillment:     return [UIColor ppQuickActionShopping];
        case PPProNotificationTargetKindDeliveryOrder:   return [UIColor ppQuickActionAnimals];
        case PPProNotificationTargetKindCompanyDelivery: return [UIColor ppInfo];
        case PPProNotificationTargetKindChat:            return [UIColor ppQuickActionServices];
        case PPProNotificationTargetKindUnknown:
        default:                                         return AppPrimaryClr;
    }
}

/// Whether the localized body is really just the server's untranslated English
/// string being passed through.
///
/// `-pp_localizedBodyForCurrentLanguage` walks explicit loc keys, `bodyAr`-style
/// side-by-side fields, nested `{ar,en}` maps and finally a heuristic matcher;
/// when all of those miss it returns `self.body` verbatim
/// (`NotificationModel.m`). For a plain new-order document the server writes only
/// an English `body` and no numeric metadata, so the heuristic yields nothing and
/// an Arabic UI renders "A new order #PP-… has been placed." — a sentence that
/// also just repeats the order reference already in the title.
///
/// When that is the case the body is suppressed in favour of the destination
/// affordance, which is genuinely new information. The durable fix is server-side
/// (`bodyLocalizationKey` or `bodyAr` from Infra); this only stops the client
/// presenting untranslated duplicate copy as if it were content.
static BOOL PPNotificationBodyIsUntranslatedPassthrough(NotificationModel *model, NSString *localizedBody)
{
    if (!Language.isRTL) { return NO; }              // English UI: the English body is correct.
    if (localizedBody.length == 0) { return YES; }
    NSString *raw = model.body ?: @"";
    if (![localizedBody isEqualToString:raw]) { return NO; }  // A real localization won.
    // Passthrough confirmed. Only treat it as noise if it carries Latin letters,
    // so a legitimately Arabic server body is never hidden.
    NSCharacterSet *latin = [NSCharacterSet characterSetWithRange:NSMakeRange('A', 26)];
    NSCharacterSet *latinLower = [NSCharacterSet characterSetWithRange:NSMakeRange('a', 26)];
    return [localizedBody rangeOfCharacterFromSet:latin].location != NSNotFound
        || [localizedBody rangeOfCharacterFromSet:latinLower].location != NSNotFound;
}


/// Dynamic Type bridge. `Styling fontBold:`/`fontMedium:` return fixed-size
/// fonts, so every label on this screen was previously frozen at its design
/// size. Scaling through UIFontMetrics keeps the brand face while letting the
/// user's text-size preference apply.
static UIFont *PPNotificationScaledFont(UIFont *base, UIFontTextStyle style)
{
    if (!base) { return nil; }
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:base];
}

/// One formatter for the whole screen instead of an allocation per `configure:`
/// on the scroll path, and explicitly locked to the in-app language so an
/// English-locale device does not render Latin dates inside Arabic UI.
static NSDateFormatter *PPNotificationTimestampFormatter(void)
{
    static NSDateFormatter *formatter = nil;
    static NSString *cachedLanguageCode = nil;
    NSString *languageCode = [Language currentLanguageCode] ?: @"en";

    if (!formatter || ![cachedLanguageCode isEqualToString:languageCode]) {
        formatter = [NSDateFormatter new];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.locale = [NSLocale localeWithLocaleIdentifier:languageCode];
        cachedLanguageCode = languageCode;
    }
    return formatter;
}

@implementation NotificationCell {
    UIView *_surfaceView;
    UIView *_rankEdgeView;
    UIView *_iconShellView;
    UIImageView *_iconView;
    UILabel *_title;
    UILabel *_body;
    UILabel *_destination;
    UILabel *_time;
    UIView *_metaRow;
    UIView *_statusPillView;
    UILabel *_statusLabel;
    UIImageView *_chevronView;
    NSLayoutConstraint *_copyStackTrailingToPill;
    NSLayoutConstraint *_copyStackTrailingToChevron;
}

+ (NSString *)reuseId { return @"NotificationCell"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.preservesSuperviewLayoutMargins = NO;
        self.layoutMargins = UIEdgeInsetsZero;
        self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        // The row is one decision, so VoiceOver reads it as one element.
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _surfaceView = [UIView new];
        _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
        _surfaceView.backgroundColor = AppForgroundColr;
        PPApplyContinuousCorners(_surfaceView, PPCornerCard);
        _surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        _surfaceView.layer.borderColor = PPHairlineColor().CGColor;
        PPApplyCardShadow(_surfaceView);
        [self.contentView addSubview:_surfaceView];

        // Rank edge — the same "rank is felt, not read" encoding the Pulse queue
        // uses. Replaces the decorative unread dot that duplicated the status
        // pill; the pill still carries the localized word.
        _rankEdgeView = [UIView new];
        _rankEdgeView.translatesAutoresizingMaskIntoConstraints = NO;
        _rankEdgeView.backgroundColor = AppPrimaryClr;
        PPApplyContinuousCorners(_rankEdgeView, 1.5);
        [_surfaceView addSubview:_rankEdgeView];

        _iconShellView = [UIView new];
        _iconShellView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconShellView.backgroundColor = AppPrimaryClrWithAlpha(0.10);
        PPApplyContinuousCorners(_iconShellView, PPCorner16);
        [_surfaceView addSubview:_iconShellView];

        _iconView = [UIImageView new];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = AppPrimaryClr;
        _iconView.image = [UIImage systemImageNamed:@"bell.badge.fill"];
        [_iconShellView addSubview:_iconView];

        _title = [UILabel new];
        _title.translatesAutoresizingMaskIntoConstraints = NO;
        _title.font = PPNotificationScaledFont([Styling fontBold:PPFontHeadline], UIFontTextStyleHeadline);
        _title.adjustsFontForContentSizeCategory = YES;
        _title.textColor = PrimaryTextClr;
        _title.numberOfLines = 2;
        _title.textAlignment = [Language alignmentForCurrentLanguage];

        _body = [UILabel new];
        _body.translatesAutoresizingMaskIntoConstraints = NO;
        _body.font = PPNotificationScaledFont([Styling fontMedium:13], UIFontTextStyleSubheadline);
        _body.adjustsFontForContentSizeCategory = YES;
        _body.textColor = SeconderyTextClr;
        _body.numberOfLines = 2;
        _body.textAlignment = [Language alignmentForCurrentLanguage];

        _destination = [UILabel new];
        _destination.translatesAutoresizingMaskIntoConstraints = NO;
        _destination.font = PPNotificationScaledFont([Styling fontBold:PPFontCaption1], UIFontTextStyleCaption1);
        _destination.adjustsFontForContentSizeCategory = YES;
        _destination.numberOfLines = 1;
        _destination.textAlignment = [Language alignmentForCurrentLanguage];
        [_destination setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh + 1
                                                      forAxis:UILayoutConstraintAxisHorizontal];

        _time = [UILabel new];
        _time.translatesAutoresizingMaskIntoConstraints = NO;
        _time.font = PPNotificationScaledFont([Styling fontMedium:PPFontCaption1], UIFontTextStyleCaption1);
        _time.adjustsFontForContentSizeCategory = YES;
        _time.textColor = AppTertiaryTextClr;
        _time.textAlignment = [Language alignmentForCurrentLanguage];
        _time.numberOfLines = 1;

        // Destination + timestamp share one line: where this row goes, and when it
        // arrived. The destination title is the same localized CTA the router uses
        // (`+callToActionTitleForPayload:`), so the row states its own outcome.
        UIStackView *metaStack = [[UIStackView alloc] initWithArrangedSubviews:@[_destination, _time]];
        metaStack.translatesAutoresizingMaskIntoConstraints = NO;
        metaStack.axis = UILayoutConstraintAxisHorizontal;
        metaStack.alignment = UIStackViewAlignmentFirstBaseline;
        metaStack.spacing = PPSpaceSM;
        metaStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        _metaRow = metaStack;

        _statusPillView = [UIView new];
        _statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
        PPApplyContinuousCorners(_statusPillView, PPCornerSmall);
        [_surfaceView addSubview:_statusPillView];

        _statusLabel = [UILabel new];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = PPNotificationScaledFont([Styling fontBold:PPFontCaption2], UIFontTextStyleCaption2);
        _statusLabel.adjustsFontForContentSizeCategory = YES;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 1;
        [_statusPillView addSubview:_statusLabel];

        _chevronView = [UIImageView new];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
        _chevronView.tintColor = AppTertiaryTextClr;
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [_surfaceView addSubview:_chevronView];

        UIStackView *copyStack = [[UIStackView alloc] initWithArrangedSubviews:@[_title, _body, _metaRow]];
        copyStack.translatesAutoresizingMaskIntoConstraints = NO;
        copyStack.axis = UILayoutConstraintAxisVertical;
        copyStack.alignment = UIStackViewAlignmentFill;
        copyStack.spacing = PPSpaceXS;
        copyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [_surfaceView addSubview:copyStack];

        _copyStackTrailingToPill = [copyStack.trailingAnchor constraintLessThanOrEqualToAnchor:_statusPillView.leadingAnchor constant:-PPSpaceSM];
        _copyStackTrailingToChevron = [copyStack.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-PPSpaceSM];
        // One of the two is always active; default to the wider (pill-present)
        // form so the stack is never unconstrained before the first configure:.
        _copyStackTrailingToPill.active = YES;

        [NSLayoutConstraint activateConstraints:@[
            [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceMDHalf],
            [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
            [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
            [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceMDHalf],

            [_rankEdgeView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor],
            [_rankEdgeView.widthAnchor constraintEqualToConstant:3.0],
            [_rankEdgeView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:PPSpaceBase],
            [_rankEdgeView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-PPSpaceBase],

            [_iconShellView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:PPSpaceBase],
            [_iconShellView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:PPSpaceBase],
            [_iconShellView.widthAnchor constraintEqualToConstant:PPTouchTargetMin],
            [_iconShellView.heightAnchor constraintEqualToConstant:PPTouchTargetMin],

            [_iconView.centerXAnchor constraintEqualToAnchor:_iconShellView.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:_iconShellView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:19.0],
            [_iconView.heightAnchor constraintEqualToConstant:19.0],

            [copyStack.leadingAnchor constraintEqualToAnchor:_iconShellView.trailingAnchor constant:PPSpaceMD],
            [copyStack.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:PPSpaceBase],
            [copyStack.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-PPSpaceBase],

            [_statusPillView.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-PPSpaceSM],
            [_statusPillView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
            // Grows with the text instead of clipping it at accessibility sizes.
            [_statusPillView.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
            [_statusPillView.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],

            [_statusLabel.leadingAnchor constraintEqualToAnchor:_statusPillView.leadingAnchor constant:PPSpaceSM],
            [_statusLabel.trailingAnchor constraintEqualToAnchor:_statusPillView.trailingAnchor constant:-PPSpaceSM],
            [_statusLabel.topAnchor constraintEqualToAnchor:_statusPillView.topAnchor constant:PPSpaceXS],
            [_statusLabel.bottomAnchor constraintEqualToAnchor:_statusPillView.bottomAnchor constant:-PPSpaceXS],

            [_chevronView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-PPSpaceBase],
            [_chevronView.centerYAnchor constraintEqualToAnchor:_surfaceView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:10.0],
            [_chevronView.heightAnchor constraintEqualToConstant:16.0],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _title.text = nil;
    _body.text = nil;
    _destination.text = nil;
    _time.text = nil;
    _statusLabel.text = nil;
    _rankEdgeView.alpha = 0.0;
    _body.hidden = NO;
    _destination.hidden = NO;
    self.accessibilityLabel = nil;
}

- (void)configure:(NotificationModel *)m {
    BOOL unread = !m.isRead;
    BOOL isAccessibilitySize = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);

    // One classification for both the icon and the destination label, taken from
    // the same routing taxonomy that will decide where the tap actually goes.
    NSDictionary *payload = [NotificationManager routingPayloadForNotificationModel:m];
    PPProNotificationTargetKind kind = [NotificationManager targetKindForPayload:payload];
    BOOL hasDirectTarget = [NotificationManager payloadHasDirectTarget:payload];
    NSString *kindSymbol = PPNotificationSymbolForKind(kind);
    UIColor *accent = PPNotificationAccentForKind(kind) ?: AppPrimaryClr;

    NSString *localizedTitle = [m pp_localizedTitleForCurrentLanguage] ?: @"";
    NSString *localizedBody = [m pp_localizedBodyForCurrentLanguage] ?: @"";
    BOOL suppressBody = PPNotificationBodyIsUntranslatedPassthrough(m, localizedBody);

    _title.text = localizedTitle;
    _title.font = PPNotificationScaledFont([Styling fontBold:PPFontHeadline], UIFontTextStyleHeadline);
    _title.numberOfLines = isAccessibilitySize ? 4 : 2;

    _body.text = suppressBody ? @"" : localizedBody;
    _body.hidden = suppressBody || localizedBody.length == 0;
    _body.numberOfLines = isAccessibilitySize ? 6 : 2;

    // The destination is real information the row never carried: which screen
    // this opens. Shown only when the router actually has a concrete target, so
    // it never promises a destination that does not exist.
    NSString *destinationTitle = hasDirectTarget ? [NotificationManager callToActionTitleForPayload:payload] : @"";
    _destination.text = destinationTitle;
    _destination.hidden = destinationTitle.length == 0;
    _destination.textColor = accent;

    NSDate *d = m.createdAt ?: [NSDate date];
    _time.text = [PPNotificationTimestampFormatter() stringFromDate:d];

    // At accessibility sizes the destination and the timestamp stop competing for
    // one line and stack instead.
    ((UIStackView *)_metaRow).axis = isAccessibilitySize
        ? UILayoutConstraintAxisVertical
        : UILayoutConstraintAxisHorizontal;
    ((UIStackView *)_metaRow).alignment = isAccessibilitySize
        ? UIStackViewAlignmentLeading
        : UIStackViewAlignmentFirstBaseline;

    // Unread is signalled by the rank edge, the accent title and the explicit
    // word. A "Read" pill on every historical row was pure noise — read rows now
    // drop the pill and give the width back to the title, and the copy stack
    // re-targets its trailing constraint accordingly.
    _statusPillView.hidden = !unread;
    _copyStackTrailingToPill.active = unread;
    _copyStackTrailingToChevron.active = !unread;
    _statusLabel.text = unread ? kLang(@"Unread") : @"";

    _iconView.image = [UIImage systemImageNamed:kindSymbol];
    _rankEdgeView.backgroundColor = accent;
    _rankEdgeView.alpha = unread ? 1.0 : 0.0;
    _title.textColor = unread ? accent : PrimaryTextClr;
    _surfaceView.backgroundColor = AppForgroundColr;
    _surfaceView.layer.borderColor = (unread
                                      ? [accent colorWithAlphaComponent:0.22]
                                      : PPHairlineColor()).CGColor;
    _surfaceView.layer.shadowOpacity = unread ? PPShadowCardOpacity : PPShadowSubtleOpacity;
    _iconShellView.backgroundColor = [accent colorWithAlphaComponent:unread ? 0.14 : 0.08];
    _iconView.tintColor = unread ? accent : [accent colorWithAlphaComponent:0.62];
    _statusPillView.backgroundColor = [accent colorWithAlphaComponent:0.11];
    _statusLabel.textColor = accent;
    _chevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
    _chevronView.tintColor = AppTertiaryTextClr;

    // Composed from already-localized values only — no new copy. The read/unread
    // word is always spoken even though the pill is now visual-only for unread,
    // so the state never depends on seeing a colour.
    NSMutableArray<NSString *> *spoken = [NSMutableArray array];
    [spoken addObject:unread ? kLang(@"Unread") : kLang(@"Read")];
    if (localizedTitle.length > 0) { [spoken addObject:localizedTitle]; }
    if (!suppressBody && localizedBody.length > 0) { [spoken addObject:localizedBody]; }
    if (_time.text.length > 0) { [spoken addObject:_time.text]; }
    self.accessibilityLabel = [spoken componentsJoinedByString:Language.isRTL ? @"، " : @", "];
    self.accessibilityHint = destinationTitle.length > 0
        ? destinationTitle
        : kLang(@"pp_pro_notification_accessibility_hint");
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_setPressed:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_setPressed:selected animated:animated];
}

- (void)pp_setPressed:(BOOL)pressed animated:(BOOL)animated {
    void (^changes)(void) = ^{
        self->_surfaceView.transform = pressed
            ? CGAffineTransformMakeScale(PPTapCardScaleDown, PPTapCardScaleDown)
            : CGAffineTransformIdentity;
        self->_surfaceView.alpha = pressed ? 0.86 : 1.0;
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:PPAnimDurationFast delay:0 options:UIViewAnimationOptionCurveEaseOut animations:changes completion:nil];
    } else {
        changes();
    }
}
@end
