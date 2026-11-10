#import "PPFulfillmentModel.h"

@implementation PPFulfillmentModel

+ (instancetype)modelFromDictionary:(NSDictionary *)dict fulfillmentID:(NSString *)fulfillmentID {
    PPFulfillmentModel *m = [[PPFulfillmentModel alloc] init];
    m.fulfillmentID = fulfillmentID;
    m.parentOrderId = PPSafeString(dict[@"parentOrderId"]);
    m.parentUserId = PPSafeString(dict[@"parentUserId"]);
    m.parentOrderNumber = PPSafeString(dict[@"parentOrderNumber"]);
    m.ownerID = PPSafeString(dict[@"ownerID"]);
    m.ownerType = PPSafeString(dict[@"ownerType"]);
    m.fulfillmentMode = PPSafeString(dict[@"fulfillmentMode"]);
    m.status = [self normalizedStatusValue:PPSafeString(dict[@"status"])];

    NSArray *items = PPSafeArray(dict[@"items"]);
    m.itemCount = items.count;
    m.items = items;

    NSDictionary *money = PPSafeDict(dict[@"money"]);
    m.currency = [PPSafeString(money[@"currency"]) uppercaseString];
    m.hasMoneyProjection = [money[@"subtotal"] isKindOfClass:NSNumber.class]
        && [money[@"platformCommission"] isKindOfClass:NSNumber.class]
        && [money[@"providerNet"] isKindOfClass:NSNumber.class]
        && m.currency.length > 0;
    m.subtotal = PPSafeNumber(money[@"subtotal"]).doubleValue;
    m.platformCommission = PPSafeNumber(money[@"platformCommission"]).doubleValue;
    m.providerNet = PPSafeNumber(money[@"providerNet"]).doubleValue;

    id ca = dict[@"createdAt"];
    if ([ca isKindOfClass:[NSDate class]]) m.createdAt = ca;
    else if ([ca respondsToSelector:@selector(dateValue)]) m.createdAt = [ca dateValue];

    id ua = dict[@"updatedAt"];
    if ([ua isKindOfClass:[NSDate class]]) m.updatedAt = ua;
    else if ([ua respondsToSelector:@selector(dateValue)]) m.updatedAt = [ua dateValue];

    m.adminOverrideReason = PPSafeString(dict[@"adminOverrideReason"]);

    id oa = dict[@"adminOverrideAt"];
    if ([oa isKindOfClass:[NSDate class]]) m.adminOverrideAt = oa;
    else if ([oa respondsToSelector:@selector(dateValue)]) m.adminOverrideAt = [oa dateValue];

    m.events = PPSafeArray(dict[@"events"]);

    return m;
}

- (BOOL)isTerminal {
    static NSSet *terminalSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        terminalSet = [NSSet setWithArray:@[@"rejected", @"completed", @"cancelled", @"failed", @"returned"]];
    });
    return [terminalSet containsObject:self.status];
}

+ (NSString *)normalizedStatusValue:(NSString *)status {
    return [[status ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
}

- (NSString *)statusDisplayName {
    return [PPFulfillmentModel displayNameForStatus:self.status];
}

+ (NSString *)displayNameForStatus:(NSString *)status {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"new_request":        @"Fulfillment_Status_NewRequest",
            @"accepted":           @"Fulfillment_Status_Accepted",
            @"rejected":           @"Fulfillment_Status_Rejected",
            @"preparing":          @"Fulfillment_Status_Preparing",
            @"ready_for_pickup":   @"Fulfillment_Status_ReadyForPickup",
            @"delivery_requested": @"Fulfillment_Status_DeliveryRequested",
            @"delivery_assigned":  @"Fulfillment_Status_DeliveryAssigned",
            @"awaiting_handover":  @"Fulfillment_Status_AwaitingHandover",
            @"handed_over":        @"Fulfillment_Status_HandedOver",
            @"in_transit":         @"InTransit",
            @"delivered":          @"Delivered",
            @"payment_pending":    @"Deliv_PaymentPending",
            @"payment_confirmed":  @"Deliv_StatusPaymentConfirmed",
            @"completed":          @"Fulfillment_Status_Completed",
            @"cancelled":          @"Fulfillment_Status_Cancelled",
            @"failed":             @"Fulfillment_Status_Failed",
            @"returned":           @"Fulfillment_Status_Returned",
        };
    });
    NSString *key = map[[self normalizedStatusValue:status]];
    return key.length > 0 ? kLang(key) : kLang(@"Fulfillment_Status_Unknown");
}

- (UIColor *)statusColor {
    NSString *s = self.status;
    if ([s isEqualToString:@"accepted"] || [s isEqualToString:@"completed"] || [s isEqualToString:@"ready_for_pickup"]) return [UIColor ppSuccess];
    if ([s isEqualToString:@"new_request"] || [s isEqualToString:@"preparing"] || [s isEqualToString:@"delivery_requested"] || [s isEqualToString:@"delivery_assigned"] || [s isEqualToString:@"awaiting_handover"]) return [UIColor ppWarning];
    if ([s isEqualToString:@"rejected"] || [s isEqualToString:@"cancelled"] || [s isEqualToString:@"failed"] || [s isEqualToString:@"returned"]) return [UIColor ppError];
    return [UIColor ppTextSecondary];
}

- (NSString *)nextActionForStatus {
    NSString *s = self.status;
    if ([s isEqualToString:@"new_request"])        return kLang(@"Fulfillment_Accept");
    if ([s isEqualToString:@"accepted"])           return kLang(@"Fulfillment_StartPreparing");
    if ([s isEqualToString:@"preparing"])          return kLang(@"Fulfillment_MarkReady");
    if ([s isEqualToString:@"ready_for_pickup"])   return kLang(@"Fulfillment_RequestDelivery");
    if ([s isEqualToString:@"delivery_assigned"])  return kLang(@"Fulfillment_ConfirmHandover");
    return nil;
}

- (NSArray<NSString *> *)availableActions {
    NSString *s = self.status;
    if ([s isEqualToString:@"new_request"])        return @[@"accept", @"reject", @"cancel_request"];
    if ([s isEqualToString:@"accepted"])           return @[@"start_preparing", @"cancel_request"];
    if ([s isEqualToString:@"preparing"])          return @[@"mark_ready", @"cancel_request"];
    if ([s isEqualToString:@"ready_for_pickup"])   return @[@"request_delivery", @"cancel_request"];
    if ([s isEqualToString:@"delivery_requested"]) return @[@"cancel_request"];
    if ([s isEqualToString:@"delivery_assigned"])  return @[@"confirm_handover", @"cancel_request"];
    if ([s isEqualToString:@"awaiting_handover"])  return @[@"cancel_request"];
    return @[];
}

+ (NSString *)targetStatusForAction:(NSString *)action {
    // Infra provider actions; compatibility display aliases never authorize a transition.
    NSDictionary *targets = @{@"accept": @"accepted", @"reject": @"rejected",
        @"start_preparing": @"preparing", @"mark_ready": @"ready_for_pickup",
        @"request_delivery": @"delivery_requested", @"confirm_handover": @"awaiting_handover",
        @"cancel_request": @"cancelled"};
    return targets[action];
}

+ (NSString *)autoGeneratedNoteForAction:(NSString *)action targetStatus:(NSString *)targetStatus {
    NSString *act = [action stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
    NSString *key = [NSString stringWithFormat:@"Fulfillment_AutoNote_%@", act];
    NSString *localized = kLang(key);
    if (localized.length > 0 && ![localized isEqualToString:key]) {
        return localized;
    }
    NSString *effectiveTarget = targetStatus.length > 0 ? targetStatus : [self targetStatusForAction:act];
    NSString *targetDisplayName = effectiveTarget.length > 0 ? [self displayNameForStatus:effectiveTarget] : @"";
    NSString *defaultFormat = kLang(@"Fulfillment_AutoNote_default");
    if (defaultFormat.length > 0 && ![defaultFormat isEqualToString:@"Fulfillment_AutoNote_default"] && targetDisplayName.length > 0) {
        return [NSString stringWithFormat:defaultFormat, targetDisplayName];
    }
    
    // Built-in fallbacks guaranteeing >= 3 characters in Arabic and English
    if (Language.isRTL) {
        if ([act isEqualToString:@"start_preparing"]) return @"تم بدء تجهيز وتحضير الطلب في المتجر";
        if ([act isEqualToString:@"mark_ready"]) return @"تم تجهيز وتغليف الطلب وجاهز للاستلام";
        if ([act isEqualToString:@"request_delivery"]) return @"تم طلب مندوب لتوصيل الشحنة";
        if ([act isEqualToString:@"confirm_handover"]) return @"تم تسليم الطلب بنجاح إلى مندوب التوصيل";
        if ([act isEqualToString:@"accept"]) return @"تم قبول وتأكيد استلام الطلب";
        if ([act isEqualToString:@"reject"]) return @"تم تعذر تجهيز الطلب من قبل المتجر";
        if ([act isEqualToString:@"cancel_request"]) return @"تم إلغاء الطلب من قبل المتجر";
        return targetDisplayName.length > 0 ? [NSString stringWithFormat:@"تحديث حالة الطلب إلى %@", targetDisplayName] : @"تحديث حالة الطلب";
    } else {
        if ([act isEqualToString:@"start_preparing"]) return @"Order preparation started at branch";
        if ([act isEqualToString:@"mark_ready"]) return @"Order prepared and ready for pickup";
        if ([act isEqualToString:@"request_delivery"]) return @"Delivery courier requested for shipment";
        if ([act isEqualToString:@"confirm_handover"]) return @"Order successfully handed over to courier";
        if ([act isEqualToString:@"accept"]) return @"Order accepted and confirmed";
        if ([act isEqualToString:@"reject"]) return @"Order rejected due to fulfillment constraint";
        if ([act isEqualToString:@"cancel_request"]) return @"Order cancelled by store";
        return targetDisplayName.length > 0 ? [NSString stringWithFormat:@"Order status updated to %@", targetDisplayName] : @"Order status updated";
    }
}

- (NSInteger)lifecycleStageIndex {
    NSArray<NSArray<NSString *> *> *groups = @[
        @[@"new_request"], @[@"accepted", @"preparing"],
        @[@"ready_for_pickup", @"delivery_requested"],
        @[@"delivery_assigned", @"awaiting_handover", @"handed_over", @"in_transit"],
        @[@"delivered", @"payment_pending", @"payment_confirmed"], @[@"completed"]];
    for (NSUInteger i = 0; i < groups.count; i++) {
        if ([groups[i] containsObject:self.status]) return (NSInteger)i;
    }
    return NSNotFound;
}

- (BOOL)requiresProviderAction { return self.nextActionForStatus.length > 0; }

- (NSString *)waitingDescription {
    if (self.isTerminal) return kLang(@"ProFulfillment_Closed");
    if ([self.status isEqualToString:@"delivery_requested"]) return kLang(@"ProFulfillment_WaitingDriver");
    if ([self.status isEqualToString:@"awaiting_handover"]) return kLang(@"ProFulfillment_WaitingHandover");
    if ([@[@"handed_over", @"in_transit", @"delivered", @"payment_pending", @"payment_confirmed"] containsObject:self.status]) return kLang(@"ProFulfillment_ExternalProgress");
    return kLang(@"ProFulfillment_NoProviderAction");
}

@end
