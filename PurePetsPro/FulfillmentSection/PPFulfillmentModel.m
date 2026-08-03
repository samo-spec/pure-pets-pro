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
    m.status = [PPSafeString(dict[@"status"]) lowercaseString];
    m.currency = PPSafeString(dict[@"money"][@"currency"]) ?: @"QAR";

    NSArray *items = PPSafeArray(dict[@"items"]);
    m.itemCount = items.count;
    m.items = items;

    NSDictionary *money = PPSafeDict(dict[@"money"]);
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

- (NSString *)statusDisplayName {
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
            @"completed":          @"Fulfillment_Status_Completed",
            @"cancelled":          @"Fulfillment_Status_Cancelled",
            @"failed":             @"Fulfillment_Status_Failed",
            @"returned":           @"Fulfillment_Status_Returned",
        };
    });
    NSString *key = map[self.status];
    return key.length > 0 ? kLang(key) : kLang(@"Fulfillment_Status_Unknown");
}

- (UIColor *)statusColor {
    NSString *s = self.status;
    if ([s isEqualToString:@"accepted"] || [s isEqualToString:@"completed"] || [s isEqualToString:@"ready_for_pickup"]) return UIColor.systemGreenColor;
    if ([s isEqualToString:@"new_request"] || [s isEqualToString:@"preparing"] || [s isEqualToString:@"delivery_requested"] || [s isEqualToString:@"delivery_assigned"] || [s isEqualToString:@"awaiting_handover"]) return UIColor.systemOrangeColor;
    if ([s isEqualToString:@"rejected"] || [s isEqualToString:@"cancelled"] || [s isEqualToString:@"failed"] || [s isEqualToString:@"returned"]) return UIColor.systemRedColor;
    return UIColor.systemGrayColor;
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
    if ([s isEqualToString:@"awaiting_handover"])  return @[@"confirm_handover", @"cancel_request"];
    return @[];
}

@end
