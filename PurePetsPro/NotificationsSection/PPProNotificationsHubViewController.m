//
//  PPProNotificationsHubViewController.m
//  PurePetsPro
//
//  Premium notifications hub for provider/admin alerts.
//  Shows local notifications for new orders, delivery requests, and system alerts.
//

#import "PPProNotificationsHubViewController.h"
#import "PPNotificationsManager.h"
#import "NotificationModel.h"
#import "NotificationManager.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPToast.h"
#import "ChatThreadModel.h"
#import "PPUserMessagesViewController.h"
#import "PPProInAppNotificationPresenter.h"
#import "Language.h"
#import <UserNotifications/UserNotifications.h>

static CGFloat const kPPProHubTopBarHeight = 46.0;
static CGFloat const kPPProHubActionButtonSize = 44.0;

static NSString *PPProHubTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSDictionary *PPProHubSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPProHubFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPProHubTrimmedString(source[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPProHubLocalizedValueFromDictionary(NSDictionary *source, NSArray<NSString *> *arKeys, NSArray<NSString *> *enKeys)
{
    NSArray<NSString *> *primaryKeys = Language.isRTL ? arKeys : enKeys;
    NSArray<NSString *> *fallbackKeys = Language.isRTL ? enKeys : arKeys;
    NSString *primary = PPProHubFirstStringForKeys(source, primaryKeys);
    if (primary.length > 0) return primary;
    return PPProHubFirstStringForKeys(source, fallbackKeys);
}

static NSString *PPProHubLocalizedNestedValue(id nestedValue)
{
    NSDictionary *dictionary = PPProHubSafeDictionary(nestedValue);
    if (dictionary.count == 0) return PPProHubTrimmedString(nestedValue);
    return PPProHubLocalizedValueFromDictionary(dictionary,
                                               @[@"ar", @"arabic", @"titleAr", @"bodyAr", @"valueAr", @"textAr"],
                                               @[@"en", @"english", @"titleEn", @"bodyEn", @"valueEn", @"textEn"]);
}

static BOOL PPProHubStringEquals(NSString *lhs, NSString *rhs)
{
    return [PPProHubTrimmedString(lhs) caseInsensitiveCompare:PPProHubTrimmedString(rhs)] == NSOrderedSame;
}

static BOOL PPProHubStringHasPrefix(NSString *value, NSString *prefix)
{
    return [PPProHubTrimmedString(value) rangeOfString:prefix options:NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound;
}

static NSString *PPProHubOrderReferenceFromTitle(NSString *title)
{
    NSString *safeTitle = PPProHubTrimmedString(title);
    NSString *prefix = @"New Order ";
    if (!PPProHubStringHasPrefix(safeTitle, prefix) || safeTitle.length <= prefix.length) {
        return @"";
    }
    return PPProHubTrimmedString([safeTitle substringFromIndex:prefix.length]);
}

static BOOL PPProHubParseOrderSummaryBody(NSString *body, NSString **itemCount, NSString **amount, NSString **currency)
{
    NSString *safeBody = PPProHubTrimmedString(body);
    if (safeBody.length == 0) return NO;

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(\\d+)\\s+item\\(s\\)\\s*•\\s*([0-9]+(?:\\.[0-9]+)?)\\s*([A-Za-z]+)\\s*$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    if (error) return NO;

    NSTextCheckingResult *match = [regex firstMatchInString:safeBody options:0 range:NSMakeRange(0, safeBody.length)];
    if (!match || match.numberOfRanges < 4) return NO;

    if (itemCount) *itemCount = [safeBody substringWithRange:[match rangeAtIndex:1]];
    if (amount) *amount = [safeBody substringWithRange:[match rangeAtIndex:2]];
    if (currency) *currency = [safeBody substringWithRange:[match rangeAtIndex:3]];
    return YES;
}

static NSString *PPProHubLocalizedNotificationTitle(NSString *rawTitle, NSDictionary *payload)
{
    NSDictionary *safePayload = PPProHubSafeDictionary(payload);
    NSString *type = [[PPProHubFirstStringForKeys(safePayload, @[@"notificationType", @"type", @"key", @"eventKey"]) lowercaseString] copy];

    NSString *titleKey = PPProHubFirstStringForKeys(safePayload, @[@"titleLocalizationKey", @"titleKey", @"titleLocKey"]);
    if (titleKey.length > 0) return kLang(titleKey);

    NSString *localized = PPProHubLocalizedValueFromDictionary(safePayload,
                                                              @[@"titleAr", @"title_ar", @"arTitle", @"titleArabic", @"title_arabic"],
                                                              @[@"titleEn", @"title_en", @"enTitle", @"titleEnglish", @"title_english"]);
    if (localized.length > 0) return localized;

    for (NSString *key in @[@"localizedTitle", @"titleLocalized", @"titleI18n", @"title_i18n", @"titleMap"]) {
        localized = PPProHubLocalizedNestedValue(safePayload[key]);
        if (localized.length > 0) return localized;
    }

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPProHubStringEquals(rawTitle, @"New Delivery Request")) {
        return kLang(@"pp_pro_notification_new_delivery_request_title");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPProHubStringEquals(rawTitle, @"Delivery Request Closed")) {
        return kLang(@"pp_pro_notification_delivery_request_closed_title");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        PPProHubStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *orderReference = PPProHubFirstStringForKeys(safePayload, @[@"orderNumber", @"orderReference", @"orderId"]);
        if (orderReference.length == 0) orderReference = PPProHubOrderReferenceFromTitle(rawTitle);
        NSString *format = kLang(@"pp_pro_notification_new_order_title_format");
        return orderReference.length > 0 ? [NSString stringWithFormat:format, orderReference] : kLang(@"pp_pro_notification_new_order_title");
    }

    return PPProHubTrimmedString(rawTitle);
}

static NSString *PPProHubLocalizedNotificationBody(NSString *rawBody, NSString *rawTitle, NSDictionary *payload)
{
    NSDictionary *safePayload = PPProHubSafeDictionary(payload);
    NSString *type = [[PPProHubFirstStringForKeys(safePayload, @[@"notificationType", @"type", @"key", @"eventKey"]) lowercaseString] copy];

    NSString *bodyKey = PPProHubFirstStringForKeys(safePayload, @[@"bodyLocalizationKey", @"bodyKey", @"bodyLocKey"]);
    if (bodyKey.length > 0) return kLang(bodyKey);

    NSString *localized = PPProHubLocalizedValueFromDictionary(safePayload,
                                                              @[@"bodyAr", @"body_ar", @"arBody", @"bodyArabic", @"body_arabic", @"messageAr", @"message_ar"],
                                                              @[@"bodyEn", @"body_en", @"enBody", @"bodyEnglish", @"body_english", @"messageEn", @"message_en"]);
    if (localized.length > 0) return localized;

    for (NSString *key in @[@"localizedBody", @"bodyLocalized", @"bodyI18n", @"body_i18n", @"bodyMap"]) {
        localized = PPProHubLocalizedNestedValue(safePayload[key]);
        if (localized.length > 0) return localized;
    }

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPProHubStringEquals(rawTitle, @"New Delivery Request") ||
        PPProHubStringEquals(rawBody, @"A new order is ready for pickup. Please review the details and accept the delivery request.")) {
        return kLang(@"pp_pro_notification_new_delivery_request_body");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPProHubStringEquals(rawTitle, @"Delivery Request Closed") ||
        PPProHubStringEquals(rawBody, @"This delivery request is no longer available.")) {
        return kLang(@"pp_pro_notification_delivery_request_closed_body");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        PPProHubStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *itemCount = PPProHubFirstStringForKeys(safePayload, @[@"itemCount", @"itemsCount"]);
        NSString *amount = PPProHubFirstStringForKeys(safePayload, @[@"subtotal", @"amount", @"total"]);
        NSString *currency = PPProHubFirstStringForKeys(safePayload, @[@"currency"]);
        if (itemCount.length == 0 || amount.length == 0 || currency.length == 0) {
            NSString *parsedCount = nil;
            NSString *parsedAmount = nil;
            NSString *parsedCurrency = nil;
            if (PPProHubParseOrderSummaryBody(rawBody, &parsedCount, &parsedAmount, &parsedCurrency)) {
                if (itemCount.length == 0) itemCount = parsedCount;
                if (amount.length == 0) amount = parsedAmount;
                if (currency.length == 0) currency = parsedCurrency;
            }
        }
        if (itemCount.length > 0 && amount.length > 0 && currency.length > 0) {
            return [NSString stringWithFormat:kLang(@"pp_pro_notification_order_items_total_format"), itemCount, amount, currency];
        }
    }

    return PPProHubTrimmedString(rawBody);
}

static NSString *PPProHubInboxCategoryTitle(NSDictionary *payload)
{
    NSString *type = [[PPProHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPProHubTrimmedString(payload[@"conversationId"] ?: payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPProHubTrimmedString(payload[@"orderId"]);

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return kLang(@"notifications_inbox_category_chat") ?: @"Chats";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        return kLang(@"notifications_inbox_category_orders") ?: @"Orders";
    }
    if ([type isEqualToString:@"delivery"] || [type hasPrefix:@"delivery"]) {
        return kLang(@"notifications_inbox_category_delivery") ?: @"Delivery";
    }
    return kLang(@"notifications_inbox_category_updates") ?: @"Updates";
}

static UIColor *PPProHubInboxAccentColor(NSDictionary *payload)
{
    NSString *type = [[PPProHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *status = [[PPProHubTrimmedString(payload[@"status"]) lowercaseString] copy];

    if ([type isEqualToString:@"chat"]) {
        return AppPrimaryClr ?: UIColor.systemPurpleColor;
    }
    if ([status containsString:@"deliver"] || [status containsString:@"paid"]) {
        return UIColor.systemGreenColor;
    }
    if ([status containsString:@"ship"]) {
        return UIColor.systemBlueColor;
    }
    if ([status containsString:@"fail"] || [status containsString:@"cancel"]) {
        return UIColor.systemRedColor;
    }
    if ([type isEqualToString:@"delivery"] || [status containsString:@"ready"]) {
        return UIColor.systemOrangeColor;
    }
    return UIColor.systemPurpleColor;
}

static NSString *PPProHubInboxSymbolName(NSDictionary *payload)
{
    NSString *type = [[PPProHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *threadID = PPProHubTrimmedString(payload[@"conversationId"] ?: payload[@"threadID"] ?: payload[@"threadId"]);
    NSString *orderID = PPProHubTrimmedString(payload[@"orderId"]);
    NSString *status = [[PPProHubTrimmedString(payload[@"status"]) lowercaseString] copy];

    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        return @"ellipsis.message.fill";
    }
    if (orderID.length > 0 || [type hasPrefix:@"order"]) {
        if ([status containsString:@"deliver"]) return @"checkmark.seal.fill";
        if ([status containsString:@"ship"]) return @"shippingbox.fill";
        if ([status containsString:@"fail"] || [status containsString:@"cancel"]) return @"xmark.octagon.fill";
        return @"bag.fill.badge.plus";
    }
    if ([type isEqualToString:@"delivery"]) {
        return @"truck.box.fill";
    }
    return @"bell.badge.fill";
}

#pragma mark - Inbox Item Model

@interface PPProHubNotificationItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *categoryTitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, copy) NSDictionary *payload;
@end

@implementation PPProHubNotificationItem
@end

#pragma mark - Inbox Cell

@interface PPProHubInboxCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
- (void)configureWithItem:(PPProHubNotificationItem *)item formatter:(NSDateFormatter *)formatter;
@end

@implementation PPProHubInboxCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:1.0];
    _cardView.layer.cornerRadius = 22.0;
    _cardView.layer.masksToBounds = NO;
    _cardView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.16].CGColor;
    _cardView.layer.shadowOpacity = 0.10;
    _cardView.layer.shadowRadius = 14.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_cardView];

    _iconContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconContainerView.layer.cornerRadius = 20.0;
    _iconContainerView.layer.masksToBounds = YES;
    [_cardView addSubview:_iconContainerView];

    _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconContainerView addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = PPFontBold(16.0);
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.numberOfLines = 2;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = PPFontMedium(13.0);
    _subtitleLabel.textColor = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = PPFontMedium(12.0);
    _metaLabel.textColor = UIColor.tertiaryLabelColor;
    _metaLabel.numberOfLines = 1;
    [_cardView addSubview:_metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:16.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:14.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.metaLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:8.0],
        [self.metaLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metaLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.metaLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.cardView.bottomAnchor constant:-16.0],
    ]];

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                                              cornerRadius:self.cardView.layer.cornerRadius].CGPath;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.metaLabel.text = @"";
    self.iconView.image = nil;
}

- (void)configureWithItem:(PPProHubNotificationItem *)item formatter:(NSDateFormatter *)formatter
{
    self.titleLabel.text = item.title ?: @"";
    self.subtitleLabel.text = item.subtitle ?: @"";
    NSString *dateText = @"";
    if ([item.timestamp isKindOfClass:NSDate.class]) {
        dateText = [formatter stringFromDate:item.timestamp] ?: @"";
    }
    if (dateText.length > 0 && item.categoryTitle.length > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%@ • %@", item.categoryTitle, dateText];
    } else {
        self.metaLabel.text = item.categoryTitle.length > 0 ? item.categoryTitle : dateText;
    }

    UIColor *accent = item.accentColor ?: AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.iconContainerView.backgroundColor = [accent colorWithAlphaComponent:0.14];
    self.iconView.tintColor = accent;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [UIImage systemImageNamed:item.symbolName ?: @"bell.fill" withConfiguration:config];
    } else {
        self.iconView.image = [UIImage imageNamed:item.symbolName ?: @"bell.fill"];
    }
}

@end

#pragma mark - Notifications Inbox

@interface PPProHubNotificationsInboxVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) NSArray<PPProHubNotificationItem *> *items;
@property (nonatomic, strong) NSArray<PPProHubNotificationItem *> *inboxItems;
@property (nonatomic, strong) NSArray<PPProHubNotificationItem *> *deliveredItems;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> inboxListener;
- (void)reloadNotifications;
@end

@implementation PPProHubNotificationsInboxVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.items = @[];
    self.inboxItems = @[];
    self.deliveredItems = @[];

    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.locale = [NSLocale currentLocale];
    [self.dateFormatter setLocalizedDateFormatFromTemplate:@"EEE d MMM h:mm a"];

    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) style = UITableViewStyleInsetGrouped;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.rowHeight = 100.0;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 32.0, 0.0);
    if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0.0;
    [self.tableView registerClass:PPProHubInboxCell.class forCellReuseIdentifier:@"PPProHubInboxCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIView *emptyView = [[UIView alloc] initWithFrame:CGRectZero];
    emptyView.backgroundColor = UIColor.clearColor;

    UIImageView *emptyIconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    emptyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIconView.tintColor = UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:42.0 weight:UIImageSymbolWeightRegular];
        emptyIconView.image = [UIImage systemImageNamed:@"bell.slash.fill" withConfiguration:config];
    }
    [emptyView addSubview:emptyIconView];

    self.emptyTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyTitleLabel.font = PPFontBold(20.0);
    self.emptyTitleLabel.textColor = UIColor.labelColor;
    self.emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyTitleLabel.text = kLang(@"notifications_inbox_empty_title") ?: @"No notifications yet";
    [emptyView addSubview:self.emptyTitleLabel];

    self.emptySubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySubtitleLabel.font = PPFontMedium(14.0);
    self.emptySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptySubtitleLabel.numberOfLines = 0;
    self.emptySubtitleLabel.text = kLang(@"notifications_inbox_empty_subtitle") ?: @"Order updates and alerts will show up here.";
    [emptyView addSubview:self.emptySubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyIconView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [emptyIconView.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-38.0],

        [self.emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIconView.bottomAnchor constant:16.0],
        [self.emptyTitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:28.0],
        [self.emptyTitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-28.0],

        [self.emptySubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyTitleLabel.bottomAnchor constant:8.0],
        [self.emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor constant:34.0],
        [self.emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor constant:-34.0],
    ]];
    self.tableView.backgroundView = emptyView;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleRefreshNotification:)
                                                 name:@"PPProNotificationReceived"
                                               object:nil];

    [self reloadNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.inboxListener remove];
}

- (void)pp_handleRefreshNotification:(NSNotification *)notification
{
    (void)notification;
    [self reloadNotifications];
}

- (void)reloadNotifications
{
    [self pp_startInboxListenerIfNeeded];

    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        NSMutableArray<PPProHubNotificationItem *> *items = [NSMutableArray array];
        for (UNNotification *notification in notifications ?: @[]) {
            UNNotificationContent *content = notification.request.content;
            NSDictionary *payload = [content.userInfo isKindOfClass:NSDictionary.class] ? content.userInfo : @{};

            NSString *rawTitle = PPProHubTrimmedString(content.title);
            if (rawTitle.length == 0) rawTitle = PPProHubInboxCategoryTitle(payload);

            NSString *rawSubtitle = PPProHubTrimmedString(content.body);
            if (rawSubtitle.length == 0) rawSubtitle = PPProHubTrimmedString(payload[@"message"] ?: payload[@"status"]);

            NSString *title = PPProHubLocalizedNotificationTitle(rawTitle, payload);
            if (title.length == 0) title = PPProHubInboxCategoryTitle(payload);

            NSString *subtitle = PPProHubLocalizedNotificationBody(rawSubtitle, rawTitle, payload);
            if (subtitle.length == 0) subtitle = rawSubtitle;

            PPProHubNotificationItem *item = [PPProHubNotificationItem new];
            item.identifier = PPProHubTrimmedString(notification.request.identifier);
            item.title = title;
            item.subtitle = subtitle;
            item.categoryTitle = PPProHubInboxCategoryTitle(payload);
            item.symbolName = PPProHubInboxSymbolName(payload);
            item.accentColor = PPProHubInboxAccentColor(payload);
            item.timestamp = notification.date;
            item.payload = payload;
            [items addObject:item];
        }

        [items sortUsingComparator:^NSComparisonResult(PPProHubNotificationItem *a, PPProHubNotificationItem *b) {
            NSDate *first = a.timestamp ?: [NSDate distantPast];
            NSDate *second = b.timestamp ?: [NSDate distantPast];
            return [second compare:first];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.deliveredItems = items.copy;
            [strongSelf pp_applyMergedNotificationItems];
        });
    }];
}

- (NSString *)pp_currentUID
{
    NSString *uid = PPProHubTrimmedString(UsrMgr.currentUser.uid);
    if (uid.length == 0) {
        uid = PPProHubTrimmedString([FIRAuth auth].currentUser.uid);
    }
    return uid ?: @"";
}

- (void)pp_startInboxListenerIfNeeded
{
    NSString *resolvedUID = [self pp_currentUID];
    if ([self.uid isEqualToString:resolvedUID] && self.inboxListener) {
        return;
    }

    [self.inboxListener remove];
    self.inboxListener = nil;
    self.uid = resolvedUID ?: @"";
    self.inboxItems = @[];

    if (self.uid.length == 0) {
        [self pp_applyMergedNotificationItems];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.inboxListener = [[NotificationManager shared] observeInboxForUser:self.uid handler:^(NSArray<NotificationModel *> *items) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSMutableArray<PPProHubNotificationItem *> *mappedItems = [NSMutableArray arrayWithCapacity:items.count];
            for (NotificationModel *model in items ?: @[]) {
                PPProHubNotificationItem *item = [strongSelf pp_itemFromNotificationModel:model];
                if (item) {
                    [mappedItems addObject:item];
                }
            }
            strongSelf.inboxItems = mappedItems.copy;
            [strongSelf pp_applyMergedNotificationItems];
        });
    }];
}

- (PPProHubNotificationItem *)pp_itemFromNotificationModel:(NotificationModel *)model
{
    if (![model isKindOfClass:NotificationModel.class]) {
        return nil;
    }

    NSDictionary *meta = PPProHubSafeDictionary(model.meta);
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:meta];
    NSString *notificationId = PPProHubFirstStringForKeys(meta, @[@"notificationId", @"id"]);
    if (notificationId.length == 0) {
        notificationId = PPProHubTrimmedString(model.nid);
    }
    if (notificationId.length > 0) {
        payload[@"notificationId"] = notificationId;
    }

    NSString *orderID = PPProHubFirstStringForKeys(meta, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    NSString *orderNumber = PPProHubFirstStringForKeys(meta, @[@"orderNumber", @"parentOrderNumber", @"orderReference"]);
    NSString *status = PPProHubFirstStringForKeys(meta, @[@"status", @"paymentStatus", @"deliveryStatus"]);
    NSString *notificationType = PPProHubFirstStringForKeys(meta, @[@"notificationType", @"type", @"eventKey", @"notificationEvent", @"route"]);
    NSString *fulfillmentID = PPProHubFirstStringForKeys(meta, @[@"fulfillmentId", @"fulfillmentID"]);

    if (notificationType.length == 0 && fulfillmentID.length > 0) {
        notificationType = @"provider_new_fulfillment";
    }
    if (notificationType.length == 0 && orderID.length > 0) {
        notificationType = @"order";
    }

    if (orderID.length > 0) payload[@"orderId"] = orderID;
    if (orderNumber.length > 0) payload[@"orderNumber"] = orderNumber;
    if (status.length > 0) payload[@"status"] = status;
    if (notificationType.length > 0) {
        payload[@"type"] = notificationType;
        payload[@"notificationType"] = notificationType;
    }
    if (fulfillmentID.length > 0) payload[@"fulfillmentId"] = fulfillmentID;

    NSString *title = [model pp_localizedTitleForCurrentLanguage];
    if (title.length == 0) title = PPProHubTrimmedString(model.title);
    NSString *subtitle = [model pp_localizedBodyForCurrentLanguage];
    if (subtitle.length == 0) subtitle = PPProHubTrimmedString(model.body);
    if (title.length > 0) payload[@"title"] = title;
    if (subtitle.length > 0) payload[@"body"] = subtitle;

    PPProHubNotificationItem *item = [PPProHubNotificationItem new];
    item.identifier = notificationId.length > 0 ? notificationId : PPProHubTrimmedString(model.nid);
    item.title = title.length > 0 ? title : PPProHubInboxCategoryTitle(payload);
    item.subtitle = subtitle ?: @"";
    item.categoryTitle = PPProHubInboxCategoryTitle(payload);
    item.symbolName = PPProHubInboxSymbolName(payload);
    item.accentColor = PPProHubInboxAccentColor(payload);
    item.timestamp = model.createdAt ?: [NSDate date];
    item.payload = payload.copy;
    return item;
}

- (NSString *)pp_dedupeKeyForItem:(PPProHubNotificationItem *)item
{
    NSDictionary *payload = PPProHubSafeDictionary(item.payload);
    NSString *notificationId = PPProHubFirstStringForKeys(payload, @[@"notificationId", @"id"]);
    if (notificationId.length > 0) {
        return [NSString stringWithFormat:@"notification:%@", notificationId];
    }

    NSString *orderID = PPProHubFirstStringForKeys(payload, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    NSString *type = PPProHubFirstStringForKeys(payload, @[@"notificationType", @"type", @"eventKey", @"route"]);
    if (orderID.length > 0 && type.length > 0) {
        return [NSString stringWithFormat:@"order:%@:%@", orderID, type];
    }

    NSString *identifier = PPProHubTrimmedString(item.identifier);
    if (identifier.length > 0) {
        return [NSString stringWithFormat:@"local:%@", identifier];
    }

    return [NSString stringWithFormat:@"generated:%p", item];
}

- (void)pp_applyMergedNotificationItems
{
    NSMutableDictionary<NSString *, PPProHubNotificationItem *> *itemsByKey = [NSMutableDictionary dictionary];

    for (PPProHubNotificationItem *item in self.deliveredItems ?: @[]) {
        NSString *key = [self pp_dedupeKeyForItem:item];
        if (key.length > 0) {
            itemsByKey[key] = item;
        }
    }

    for (PPProHubNotificationItem *item in self.inboxItems ?: @[]) {
        NSString *key = [self pp_dedupeKeyForItem:item];
        if (key.length > 0) {
            itemsByKey[key] = item;
        }
    }

    NSArray<PPProHubNotificationItem *> *merged = [itemsByKey.allValues sortedArrayUsingComparator:^NSComparisonResult(PPProHubNotificationItem *a, PPProHubNotificationItem *b) {
        NSDate *first = a.timestamp ?: [NSDate distantPast];
        NSDate *second = b.timestamp ?: [NSDate distantPast];
        return [second compare:first];
    }];

    self.items = merged ?: @[];
    [self.tableView reloadData];
    self.tableView.backgroundView.hidden = (self.items.count > 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPProHubInboxCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProHubInboxCell" forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.items.count) {
        [cell configureWithItem:self.items[indexPath.row] formatter:self.dateFormatter];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;

    PPProHubNotificationItem *item = self.items[indexPath.row];
    NSDictionary *payload = item.payload ?: @{};
    NSString *orderID = PPProHubTrimmedString(payload[@"orderId"]);
    NSString *type = [[PPProHubTrimmedString(payload[@"type"]) lowercaseString] copy];
    NSString *route = [[PPProHubTrimmedString(payload[@"route"]) lowercaseString] copy];
    NSString *requestID = PPProHubTrimmedString(payload[@"requestId"]);

    if (requestID.length > 0 &&
        ([type hasPrefix:@"company_delivery"] || [route isEqualToString:@"fleet_partner"])) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PPProCompanyDeliveryNotificationTappedNotification
                                                            object:requestID
                                                          userInfo:payload];
        return;
    }

    if (orderID.length > 0 || [type hasPrefix:@"order"] || [type isEqualToString:@"delivery"]) {
        [self pp_navigateToOrder:payload];
        return;
    }

    NSString *threadID = PPProHubTrimmedString(payload[@"conversationId"] ?: payload[@"threadID"] ?: payload[@"threadId"]);
    if (threadID.length > 0 || [type isEqualToString:@"chat"]) {
        [self pp_navigateToChat:payload];
        return;
    }

    [PPToast toast:kLang(@"notifications_inbox_empty_subtitle") ?: @"Notifications"
             style:PPToastStyleInfo
            haptic:NO
          duration:1.6
          position:PPToastPositionBottom
            inView:self.view];
}

- (void)pp_navigateToChat:(NSDictionary *)payload
{
    NSString *threadID = PPProHubTrimmedString(payload[@"conversationId"] ?: payload[@"threadID"] ?: payload[@"threadId"]);
    if (threadID.length == 0) {
        [PPToast toast:kLang(@"notifications_inbox_empty_subtitle") ?: @"Notifications"
                 style:PPToastStyleInfo
                haptic:NO
              duration:1.6
              position:PPToastPositionBottom
                inView:self.view];
        return;
    }

    FIRDocumentReference *threadRef = [[[FIRFirestore firestore] collectionWithPath:@"Chats"] documentWithPath:threadID];
    __weak typeof(self) weakSelf = self;
    [threadRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"notifications_inbox_empty_subtitle") ?: @"Notifications unavailable"];
                return;
            }

            ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
            thread.ID = snapshot.documentID;
            PPUserMessagesViewController *messagesVC = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
            messagesVC.hidesBottomBarWhenPushed = YES;
            [strongSelf.navigationController pushViewController:messagesVC animated:YES];
        });
    }];
}

- (void)pp_navigateToOrder:(NSDictionary *)payload
{
    NSString *orderID = PPProHubTrimmedString(payload[@"orderId"]);
    if (orderID.length == 0) {
        [PPToast toast:kLang(@"order_support_unavailable_no_order") ?: @"Order data unavailable"
                 style:PPToastStyleInfo
                haptic:NO
              duration:1.8
              position:PPToastPositionBottom
                inView:self.view];
        return;
    }

    FIRDocumentReference *orderRef = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    __weak typeof(self) weakSelf = self;
    [orderRef getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !snapshot.exists) {
                [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order unavailable"];
                return;
            }

            // Navigate based on type: delivery vs regular order
            NSString *type = [[PPProHubTrimmedString(payload[@"type"]) lowercaseString] copy];
            if ([type isEqualToString:@"delivery"]) {
                // Delivery detail would go here
                [PPToast toast:kLang(@"DeliveryManagement") ?: @"Delivery"
                         style:PPToastStyleInfo
                        haptic:NO
                      duration:1.6
                      position:PPToastPositionBottom
                        inView:strongSelf.view];
            } else {
                // Regular order detail
                [PPToast toast:kLang(@"ChangeOrderStatus") ?: @"Order"
                         style:PPToastStyleInfo
                        haptic:NO
                      duration:1.6
                      position:PPToastPositionBottom
                        inView:strongSelf.view];
            }
        });
    }];
}

@end

#pragma mark - Hub View Controller

@interface PPProNotificationsHubViewController ()
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundMidGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) UIView *topChromeContainerView;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UIViewController *activeChild;
@property (nonatomic, strong) PPProHubNotificationsInboxVC *notificationsVC;
@property (nonatomic, assign) NSInteger selectedIndex;
@end

@implementation PPProNotificationsHubViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = AppPageColr;
    self.selectedIndex = 0;

    [self pp_setupBackdrop];
    [self pp_setupContentContainer];
    [self pp_showNotifications];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"NotificationsTitle") showBack:YES];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat topSize = MIN(360.0, MAX(248.0, width * 0.74));
    CGFloat midSize = MIN(300.0, MAX(210.0, width * 0.58));
    CGFloat bottomSize = MIN(340.0, MAX(220.0, width * 0.66));

    self.backgroundTopGlowView.frame = CGRectMake(width - (topSize * 0.62), - (topSize * 0.72), topSize, topSize);
    self.backgroundMidGlowView.frame = CGRectMake(-(midSize * 0.44), MAX(112.0, height * 0.28), midSize, midSize);
    self.backgroundBottomGlowView.frame = CGRectMake(width - (bottomSize * 0.56), height - (bottomSize * 0.62), bottomSize, bottomSize);

    for (UIView *glowView in @[self.backgroundTopGlowView, self.backgroundMidGlowView, self.backgroundBottomGlowView]) {
        CGFloat radius = CGRectGetWidth(glowView.bounds) * 0.5;
        glowView.layer.cornerRadius = radius;
        glowView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:glowView.bounds].CGPath;
    }

    self.contentContainerView.frame = self.view.bounds;
    self.activeChild.view.frame = self.contentContainerView.bounds;
}

- (void)pp_setupBackdrop
{
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    [self.view insertSubview:self.backgroundTopGlowView atIndex:0];

    self.backgroundMidGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundMidGlowView.userInteractionEnabled = NO;
    [self.view insertSubview:self.backgroundMidGlowView atIndex:0];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    [self.view insertSubview:self.backgroundBottomGlowView atIndex:0];

    [self pp_updateGlowAppearance];
}

- (void)pp_updateGlowAppearance
{
    BOOL isDark = NO;
    if (@available(iOS 12.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    UIColor *primaryColor = AppPrimaryClr ?: UIColor.systemPurpleColor;
    UIColor *secondaryColor = AppSecondaryClr;
    if (!secondaryColor) secondaryColor = [primaryColor colorWithAlphaComponent:1.0];
    UIColor *bottomFadeColor = isDark ? UIColor.blackColor : [UIColor colorWithRed:0.98 green:0.66 blue:0.46 alpha:1.0];

    [self pp_applyGlowView:self.backgroundTopGlowView
                     color:AppSurfColor
              surfaceAlpha:isDark ? 0.13 : 0.075
            shadowOpacity:isDark ? 0.16f : 0.10f
             shadowRadius:isDark ? 82.0 : 74.0];

    [self pp_applyGlowView:self.backgroundMidGlowView
                     color:secondaryColor
              surfaceAlpha:isDark ? 0.10 : 0.055
            shadowOpacity:isDark ? 0.12f : 0.075f
             shadowRadius:isDark ? 72.0 : 64.0];

    [self pp_applyGlowView:self.backgroundBottomGlowView
                     color:bottomFadeColor
              surfaceAlpha:isDark ? 0.030 : 0.050
            shadowOpacity:isDark ? 0.08f : 0.045f
             shadowRadius:isDark ? 62.0 : 54.0];
}

- (void)pp_applyGlowView:(UIView *)glowView
                   color:(UIColor *)color
            surfaceAlpha:(CGFloat)surfaceAlpha
          shadowOpacity:(CGFloat)shadowOpacity
           shadowRadius:(CGFloat)shadowRadius
{
    if (!glowView || !color) return;

    glowView.alpha = 1.0;
    glowView.backgroundColor = [color colorWithAlphaComponent:surfaceAlpha];
    glowView.layer.shadowColor = AppClearClr.CGColor;
    glowView.layer.shadowOpacity = 0;
    glowView.layer.shadowRadius = 0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self pp_updateGlowAppearance];
            self.view.backgroundColor = AppPageColr;
        }
    }
}

- (void)pp_setupContentContainer
{
    self.contentContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentContainerView.backgroundColor = UIColor.clearColor;
    self.contentContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentContainerView];
}

- (void)pp_showNotifications
{
    self.notificationsVC = [PPProHubNotificationsInboxVC new];
    [self addChildViewController:self.notificationsVC];
    self.notificationsVC.view.frame = self.contentContainerView.bounds;
    self.notificationsVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentContainerView addSubview:self.notificationsVC.view];
    [self.notificationsVC didMoveToParentViewController:self];
    self.activeChild = self.notificationsVC;
}

@end
