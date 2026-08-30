//
//  NotificationModel.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// NotificationModel.m
#import "NotificationModel.h"
#import "PPFirebaseCompat.h"
#import "Language.h"

static NSString *PPNotificationModelTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPNotificationModelScalarString(id value)
{
    NSString *stringValue = PPNotificationModelTrimmedString(value);
    if (stringValue.length > 0) return stringValue;

    if ([value isKindOfClass:NSNumber.class]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = 2;
        return [formatter stringFromNumber:(NSNumber *)value] ?: [(NSNumber *)value stringValue];
    }

    return @"";
}

static NSDictionary *PPNotificationModelSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPNotificationModelFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPNotificationModelTrimmedString(source[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPNotificationModelFirstScalarForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPNotificationModelScalarString(source[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPNotificationModelLocalizedValueFromDictionary(NSDictionary *source, NSArray<NSString *> *arKeys, NSArray<NSString *> *enKeys)
{
    NSArray<NSString *> *primaryKeys = Language.isRTL ? arKeys : enKeys;
    NSArray<NSString *> *fallbackKeys = Language.isRTL ? enKeys : arKeys;
    NSString *primary = PPNotificationModelFirstStringForKeys(source, primaryKeys);
    if (primary.length > 0) return primary;
    return PPNotificationModelFirstStringForKeys(source, fallbackKeys);
}

static NSString *PPNotificationModelLocalizedNestedValue(id nestedValue)
{
    NSDictionary *dictionary = PPNotificationModelSafeDictionary(nestedValue);
    if (dictionary.count == 0) return PPNotificationModelTrimmedString(nestedValue);
    return PPNotificationModelLocalizedValueFromDictionary(dictionary,
                                                          @[@"ar", @"arabic", @"titleAr", @"bodyAr", @"valueAr", @"textAr"],
	                                                          @[@"en", @"english", @"titleEn", @"bodyEn", @"valueEn", @"textEn"]);
}

static BOOL PPNotificationModelStringEquals(NSString *lhs, NSString *rhs)
{
    return [PPNotificationModelTrimmedString(lhs) caseInsensitiveCompare:PPNotificationModelTrimmedString(rhs)] == NSOrderedSame;
}

static BOOL PPNotificationModelStringHasPrefix(NSString *value, NSString *prefix)
{
    return [PPNotificationModelTrimmedString(value) rangeOfString:prefix options:NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound;
}

static BOOL PPNotificationModelIsProviderOrderCancellationType(NSString *type)
{
    NSString *normalized = PPNotificationModelTrimmedString(type).lowercaseString;
    return [normalized isEqualToString:@"provider_order_cancelled"] ||
           [normalized isEqualToString:@"provider.order.cancelled"];
}

static NSString *PPNotificationModelOrderReferenceFromTitle(NSString *title)
{
    NSString *safeTitle = PPNotificationModelTrimmedString(title);
    NSString *prefix = @"New Order ";
    if (!PPNotificationModelStringHasPrefix(safeTitle, prefix) || safeTitle.length <= prefix.length) {
        return @"";
    }
    return PPNotificationModelTrimmedString([safeTitle substringFromIndex:prefix.length]);
}

static BOOL PPNotificationModelParseOrderSummaryBody(NSString *body, NSString **itemCount, NSString **amount, NSString **currency)
{
    NSString *safeBody = PPNotificationModelTrimmedString(body);
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

static NSString *PPNotificationModelKnownLocalizedTitle(NSString *rawTitle, NSDictionary *raw, NSDictionary *meta)
{
    NSString *type = [[PPNotificationModelFirstStringForKeys(raw, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]) lowercaseString] copy];
    if (type.length == 0) {
        type = [[PPNotificationModelFirstStringForKeys(meta, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]) lowercaseString] copy];
    }
    NSString *status = [[PPNotificationModelFirstStringForKeys(meta, @[@"status"]) lowercaseString] copy];

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPNotificationModelStringEquals(rawTitle, @"New Delivery Request")) {
        return kLang(@"pp_pro_notification_new_delivery_request_title");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPNotificationModelStringEquals(rawTitle, @"Delivery Request Closed")) {
        return kLang(@"pp_pro_notification_delivery_request_closed_title");
    }

    if (PPNotificationModelIsProviderOrderCancellationType(type)) {
        NSString *orderReference = PPNotificationModelFirstScalarForKeys(meta, @[@"orderNumber", @"parentOrderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
        if (orderReference.length == 0) {
            orderReference = PPNotificationModelFirstScalarForKeys(raw, @[@"orderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
        }
        NSString *format = kLang(@"pp_pro_notification_order_cancelled_title_format");
        return orderReference.length > 0 ? [NSString stringWithFormat:format, orderReference] : kLang(@"pp_pro_notification_order_cancelled_title");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [status isEqualToString:@"new_request"] ||
        PPNotificationModelStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *orderReference = PPNotificationModelFirstScalarForKeys(meta, @[@"orderNumber", @"parentOrderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
        if (orderReference.length == 0) {
            orderReference = PPNotificationModelFirstScalarForKeys(raw, @[@"orderNumber", @"orderReference", @"orderId"]);
        }
        if (orderReference.length == 0) orderReference = PPNotificationModelOrderReferenceFromTitle(rawTitle);
        NSString *format = kLang(@"pp_pro_notification_new_order_title_format");
        return orderReference.length > 0 ? [NSString stringWithFormat:format, orderReference] : kLang(@"pp_pro_notification_new_order_title");
    }

    return @"";
}

static NSString *PPNotificationModelKnownLocalizedBody(NSString *rawBody, NSString *rawTitle, NSDictionary *raw, NSDictionary *meta)
{
    NSString *type = [[PPNotificationModelFirstStringForKeys(raw, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]) lowercaseString] copy];
    if (type.length == 0) {
        type = [[PPNotificationModelFirstStringForKeys(meta, @[@"notificationType", @"type", @"key", @"eventKey", @"route"]) lowercaseString] copy];
    }
    NSString *status = [[PPNotificationModelFirstStringForKeys(meta, @[@"status"]) lowercaseString] copy];

    if ([type isEqualToString:@"drivers_delivery_requested"] ||
        [type isEqualToString:@"delivery_requested"] ||
        PPNotificationModelStringEquals(rawTitle, @"New Delivery Request") ||
        PPNotificationModelStringEquals(rawBody, @"A new order is ready for pickup. Please review the details and accept the delivery request.")) {
        return kLang(@"pp_pro_notification_new_delivery_request_body");
    }

    if ([type isEqualToString:@"drivers_delivery_request_closed"] ||
        [type isEqualToString:@"delivery_request_closed"] ||
        PPNotificationModelStringEquals(rawTitle, @"Delivery Request Closed") ||
        PPNotificationModelStringEquals(rawBody, @"This delivery request is no longer available.")) {
        return kLang(@"pp_pro_notification_delivery_request_closed_body");
    }

    if (PPNotificationModelIsProviderOrderCancellationType(type)) {
        return kLang(@"pp_pro_notification_order_cancelled_body");
    }

    if ([type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [status isEqualToString:@"new_request"] ||
        PPNotificationModelStringHasPrefix(rawTitle, @"New Order ")) {
        NSString *itemCount = PPNotificationModelFirstScalarForKeys(meta, @[@"itemCount", @"itemsCount"]);
        NSString *amount = PPNotificationModelFirstScalarForKeys(meta, @[@"subtotal", @"amount", @"total"]);
        NSString *currency = PPNotificationModelFirstScalarForKeys(meta, @[@"currency"]);
        if (itemCount.length == 0 || amount.length == 0 || currency.length == 0) {
            itemCount = itemCount.length ? itemCount : PPNotificationModelFirstScalarForKeys(raw, @[@"itemCount", @"itemsCount"]);
            amount = amount.length ? amount : PPNotificationModelFirstScalarForKeys(raw, @[@"subtotal", @"amount", @"total"]);
            currency = currency.length ? currency : PPNotificationModelFirstScalarForKeys(raw, @[@"currency"]);
        }
        if (itemCount.length == 0 || amount.length == 0 || currency.length == 0) {
            NSString *parsedCount = nil;
            NSString *parsedAmount = nil;
            NSString *parsedCurrency = nil;
            if (PPNotificationModelParseOrderSummaryBody(rawBody, &parsedCount, &parsedAmount, &parsedCurrency)) {
                if (itemCount.length == 0) itemCount = parsedCount;
                if (amount.length == 0) amount = parsedAmount;
                if (currency.length == 0) currency = parsedCurrency;
            }
        }
        if (itemCount.length > 0 && amount.length > 0 && currency.length > 0) {
            return [NSString stringWithFormat:kLang(@"pp_pro_notification_order_items_total_format"), itemCount, amount, currency];
        }
    }

    return @"";
}

@interface NotificationModel ()
@property (nonatomic, copy) NSDictionary *rawData;
@end

@implementation NotificationModel
+ (instancetype)fromDoc:(FIRDocumentSnapshot *)doc {
    NotificationModel *m = [NotificationModel new];
    m.nid = PPNotificationModelTrimmedString(doc.documentID);
    NSDictionary *d = PPNotificationModelSafeDictionary(doc.data);
    m.rawData = d;
    m.title = PPNotificationModelTrimmedString(d[@"title"]);
    m.body  = PPNotificationModelTrimmedString(d[@"body"]);
    m.targetUserID = PPNotificationModelTrimmedString(d[@"targetUserID"]);
    id rawType = d[@"type"];
    m.type = [rawType isKindOfClass:NSNumber.class] ? [rawType integerValue] : PPNotificationTypeGeneral;
    id rawIsRead = d[@"isRead"];
    m.isRead = [rawIsRead isKindOfClass:NSNumber.class] ? [rawIsRead boolValue] : NO;
    m.meta = PPNotificationModelSafeDictionary(d[@"meta"]);
    m.sourcePath = PPNotificationModelTrimmedString(doc.reference.path);
    id ts = d[@"createdAt"];
    if ([ts isKindOfClass:[FIRTimestamp class]]) m.createdAt = ((FIRTimestamp *)ts).dateValue;
    else m.createdAt = [NSDate date];
    return m;
}

- (NSDictionary *)toDict {
    return @{
        @"title": self.title ?: @"",
        @"body":  self.body ?: @"",
        @"targetUserID": self.targetUserID ?: [NSNull null],
        @"type": @(self.type),
        @"isRead": @(self.isRead),
        @"meta": self.meta ?: @{},
        @"createdAt": [FIRTimestamp timestampWithDate:self.createdAt ?: [NSDate date]]
    };
}

- (NSString *)pp_localizedTitleForCurrentLanguage {
    NSDictionary *meta = PPNotificationModelSafeDictionary(self.meta);
    NSDictionary *raw = PPNotificationModelSafeDictionary(self.rawData);

    NSString *titleKey = PPNotificationModelFirstStringForKeys(meta, @[@"titleLocalizationKey", @"titleKey", @"titleLocKey"]);
    if (titleKey.length == 0) {
        titleKey = PPNotificationModelFirstStringForKeys(raw, @[@"titleLocalizationKey", @"titleKey", @"titleLocKey"]);
    }
    if (titleKey.length > 0) {
        NSString *localizedTitle = kLang(titleKey);
        if ([titleKey isEqualToString:@"pp_pro_notification_order_cancelled_title_format"]) {
            NSString *orderReference = PPNotificationModelFirstScalarForKeys(meta, @[@"orderNumber", @"parentOrderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
            if (orderReference.length == 0) {
                orderReference = PPNotificationModelFirstScalarForKeys(raw, @[@"orderNumber", @"orderReference", @"orderId", @"parentOrderId"]);
            }
            return orderReference.length > 0
                ? [NSString stringWithFormat:localizedTitle, orderReference]
                : kLang(@"pp_pro_notification_order_cancelled_title");
        }
        return localizedTitle;
    }

    NSString *localized = PPNotificationModelLocalizedValueFromDictionary(raw,
                                                                         @[@"titleAr", @"title_ar", @"arTitle", @"titleArabic", @"title_arabic"],
                                                                         @[@"titleEn", @"title_en", @"enTitle", @"titleEnglish", @"title_english"]);
    if (localized.length > 0) return localized;

    localized = PPNotificationModelLocalizedValueFromDictionary(meta,
                                                               @[@"titleAr", @"title_ar", @"arTitle", @"titleArabic", @"title_arabic"],
                                                               @[@"titleEn", @"title_en", @"enTitle", @"titleEnglish", @"title_english"]);
    if (localized.length > 0) return localized;

    NSArray<NSString *> *nestedKeys = @[@"localizedTitle", @"titleLocalized", @"titleI18n", @"title_i18n", @"titleMap"];
    for (NSString *key in nestedKeys) {
        localized = PPNotificationModelLocalizedNestedValue(raw[key]);
        if (localized.length > 0) return localized;
        localized = PPNotificationModelLocalizedNestedValue(meta[key]);
        if (localized.length > 0) return localized;
    }

    localized = PPNotificationModelKnownLocalizedTitle(self.title, raw, meta);
    if (localized.length > 0) return localized;

    return PPNotificationModelTrimmedString(self.title);
}

- (NSString *)pp_localizedBodyForCurrentLanguage {
    NSDictionary *meta = PPNotificationModelSafeDictionary(self.meta);
    NSDictionary *raw = PPNotificationModelSafeDictionary(self.rawData);

    NSString *bodyKey = PPNotificationModelFirstStringForKeys(meta, @[@"bodyLocalizationKey", @"bodyKey", @"bodyLocKey"]);
    if (bodyKey.length == 0) {
        bodyKey = PPNotificationModelFirstStringForKeys(raw, @[@"bodyLocalizationKey", @"bodyKey", @"bodyLocKey"]);
    }
    if (bodyKey.length > 0) {
        NSString *format = kLang(bodyKey);
        NSString *orderReference = PPNotificationModelFirstStringForKeys(meta, @[@"orderReference", @"orderNumber", @"orderId"]);
        if (orderReference.length == 0) {
            orderReference = PPNotificationModelFirstStringForKeys(raw, @[@"orderReference", @"orderNumber", @"orderId"]);
        }
        return orderReference.length > 0 ? [NSString stringWithFormat:format, orderReference] : format;
    }

    NSString *localized = PPNotificationModelLocalizedValueFromDictionary(raw,
                                                                         @[@"bodyAr", @"body_ar", @"arBody", @"bodyArabic", @"body_arabic", @"messageAr", @"message_ar"],
                                                                         @[@"bodyEn", @"body_en", @"enBody", @"bodyEnglish", @"body_english", @"messageEn", @"message_en"]);
    if (localized.length > 0) return localized;

    localized = PPNotificationModelLocalizedValueFromDictionary(meta,
                                                               @[@"bodyAr", @"body_ar", @"arBody", @"bodyArabic", @"body_arabic", @"messageAr", @"message_ar"],
                                                               @[@"bodyEn", @"body_en", @"enBody", @"bodyEnglish", @"body_english", @"messageEn", @"message_en"]);
    if (localized.length > 0) return localized;

    NSArray<NSString *> *nestedKeys = @[@"localizedBody", @"bodyLocalized", @"bodyI18n", @"body_i18n", @"bodyMap"];
    for (NSString *key in nestedKeys) {
        localized = PPNotificationModelLocalizedNestedValue(raw[key]);
        if (localized.length > 0) return localized;
        localized = PPNotificationModelLocalizedNestedValue(meta[key]);
        if (localized.length > 0) return localized;
    }

    localized = PPNotificationModelKnownLocalizedBody(self.body, self.title, raw, meta);
    if (localized.length > 0) return localized;

    return PPNotificationModelTrimmedString(self.body);
}
@end
