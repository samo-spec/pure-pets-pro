//
//  PPDeliveryOrderModel.m
//  PurePetsPro
//

#import "PPDeliveryOrderModel.h"
#import "Language.h"

#pragma mark - Date Helper

static NSDate * _Nullable PPDateFromFirestoreValue(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSDate class]]) return value;
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue]; // FIRTimestamp
    if ([value isKindOfClass:[NSNumber class]]) {
        NSTimeInterval ts = [value doubleValue];
        if (ts > 1e12) ts /= 1000.0; // ms → sec
        return [NSDate dateWithTimeIntervalSince1970:ts];
    }
    return nil;
}

static NSString * _Nonnull PPOrderModelSafeString(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id val = dict[key];
        if ([val isKindOfClass:[NSString class]]) {
            NSString *trimmed = [(NSString *)val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 0) return trimmed;
        }
    }
    return @"";
}

static NSString * _Nullable PPOrderModelOptionalString(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return trimmed.length ? trimmed : nil;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    return nil;
}

static NSDictionary * _Nonnull PPOrderModelSafeDictionary(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? (NSDictionary *)value : @{};
}

static NSString * _Nonnull PPOrderModelFirstString(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *value = PPOrderModelOptionalString(dict[key]);
        if (value.length) return value;
    }
    return @"";
}

static void PPOrderModelAppendUniquePart(NSMutableArray<NSString *> *parts, NSString *part) {
    NSString *clean = PPOrderModelOptionalString(part);
    if (clean.length == 0) return;
    for (NSString *existing in parts) {
        if ([existing caseInsensitiveCompare:clean] == NSOrderedSame) return;
    }
    [parts addObject:clean];
}

static NSString * _Nonnull PPOrderModelExactAddressFromSnapshot(NSDictionary *snapshot) {
    NSString *formatted = PPOrderModelFirstString(snapshot, @[@"formattedAddress", @"formatted", @"fullAddress", @"address"]);
    if (formatted.length) return formatted;

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    PPOrderModelAppendUniquePart(parts, PPOrderModelFirstString(snapshot, @[@"addressLine1", @"street", @"address1"]));
    PPOrderModelAppendUniquePart(parts, PPOrderModelFirstString(snapshot, @[@"addressLine2", @"address2"]));
    PPOrderModelAppendUniquePart(parts, PPOrderModelFirstString(snapshot, @[@"locatioName", @"locationName", @"area"]));
    PPOrderModelAppendUniquePart(parts, PPOrderModelFirstString(snapshot, @[@"city"]));
    PPOrderModelAppendUniquePart(parts, PPOrderModelFirstString(snapshot, @[@"postalCode", @"zipCode", @"postal_code"]));
    return parts.count ? [parts componentsJoinedByString:@", "] : @"";
}

static NSString * _Nonnull PPOrderModelAreaNameFromSnapshot(NSDictionary *snapshot) {
    return PPOrderModelFirstString(snapshot, @[
        @"deliveryAreaName",
        @"deliveryArea",
        @"areaName",
        @"locatioName",
        @"locationName",
        @"area",
        @"city"
    ]);
}

static NSString * _Nullable PPOrderModelSafeOptionalString(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *value = PPOrderModelOptionalString(dict[key]);
        if (value.length) return value;
    }
    return nil;
}

static double PPOrderModelSafeDouble(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id val = dict[key];
        if (val && ![val isKindOfClass:[NSNull class]]) return [val doubleValue];
    }
    return 0.0;
}

static NSString * _Nonnull PPNormalizedDeliveryStatus(NSString *value) {
    NSString *clean = [[value ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    clean = [clean stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    return clean;
}

static BOOL PPStatusContainsToken(NSString *status, NSString *token) {
    if (status.length == 0 || token.length == 0) return NO;
    NSString *wrappedStatus = [NSString stringWithFormat:@"_%@_", PPNormalizedDeliveryStatus(status)];
    NSString *wrappedToken = [NSString stringWithFormat:@"_%@_", PPNormalizedDeliveryStatus(token)];
    return [wrappedStatus containsString:wrappedToken];
}

static BOOL PPStatusHasAny(NSString *status, NSArray<NSString *> *tokens) {
    for (NSString *token in tokens) {
        if (PPStatusContainsToken(status, token)) return YES;
    }
    return NO;
}

#pragma mark - PPDeliveryOrderItem

@implementation PPDeliveryOrderItem

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    PPDeliveryOrderItem *item = [[PPDeliveryOrderItem alloc] init];
    item.itemID   = PPOrderModelSafeString(dict, @[@"itemID", @"itemId", @"id", @"productId", @"accessoryId"]);
    item.name     = dict[@"name"] ?: dict[@"title"] ?: dict[@"productName"] ?: @"";
    item.imageURL = dict[@"imageURL"] ?: dict[@"image"] ?: dict[@"imageUrl"] ?: @"";
    item.quantity = [dict[@"quantity"] integerValue] ?: 1;
    item.price    = [dict[@"price"] doubleValue];
    item.variant  = dict[@"variant"] ?: dict[@"size"] ?: nil;
    item.ownerID  = PPOrderModelSafeOptionalString(dict, @[@"ownerID", @"ownerId", @"providerId"]);
    item.ownerType = PPOrderModelSafeOptionalString(dict, @[@"ownerType"]);
    return item;
}

@end

#pragma mark - PPDeliveryOrderModel

@implementation PPDeliveryOrderModel

#pragma mark - Serialization

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)docID {
    PPDeliveryOrderModel *m = [[PPDeliveryOrderModel alloc] init];
    NSDictionary *shippingSnapshot = PPOrderModelSafeDictionary(dict[@"shippingAddressSnapshot"]);
    if (shippingSnapshot.count == 0) {
        shippingSnapshot = PPOrderModelSafeDictionary(dict[@"deliveryRequestAddressSnapshot"]);
    }
    if (shippingSnapshot.count == 0) {
        shippingSnapshot = PPOrderModelSafeDictionary(dict[@"shippingAddress"]);
    }

    // Identity
    m.orderId            = docID ?: dict[@"orderId"] ?: @"";
    m.orderNumber        = PPOrderModelSafeString(dict, @[@"orderNumber", @"order_number"]);
    m.displayOrderNumber = PPOrderModelSafeString(dict, @[@"displayOrderNumber", @"orderNumber", @"order_number"]);
    m.userId             = PPOrderModelSafeString(dict, @[@"userId", @"uid", @"buyerId"]);
    m.fulfillmentVersion = [dict[@"fulfillmentVersion"] respondsToSelector:@selector(integerValue)]
        ? [dict[@"fulfillmentVersion"] integerValue]
        : 0;
    NSArray *rawFulfillmentIDs = [dict[@"fulfillmentOrderIDs"] isKindOfClass:NSArray.class]
        ? dict[@"fulfillmentOrderIDs"]
        : @[];
    NSMutableArray<NSString *> *fulfillmentIDs = [NSMutableArray arrayWithCapacity:rawFulfillmentIDs.count];
    for (id rawFulfillmentID in rawFulfillmentIDs) {
        if (![rawFulfillmentID isKindOfClass:NSString.class]) continue;
        NSString *fulfillmentID = [(NSString *)rawFulfillmentID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (fulfillmentID.length > 0) [fulfillmentIDs addObject:fulfillmentID];
    }
    m.fulfillmentOrderIDs = fulfillmentIDs.copy;

    // Customer
    m.customerName  = PPOrderModelSafeString(dict, @[@"customerName", @"userName", @"buyerName", @"name"]);
    m.customerPhone = PPOrderModelSafeString(dict, @[@"customerPhone", @"phone", @"buyerPhone"]);
    m.deliveryAddress = PPOrderModelSafeString(dict, @[@"deliveryAddress", @"shippingAddress", @"address"]);
    m.pickupAddress = PPOrderModelSafeString(dict, @[@"pickupAddress", @"pickup_address", @"storeAddress", @"branchAddress"]);
    m.deliveryAreaName = PPOrderModelSafeString(dict, @[@"deliveryAreaName", @"deliveryArea", @"areaName", @"customerAreaName", @"destinationAreaName"]);
    m.deliveryLocationPoint = PPOrderModelSafeString(dict, @[@"deliveryLocationPoint", @"deliveryLocationPoints", @"locationPoints", @"customerLocationPoint"]);

    if (m.customerName.length == 0) {
        m.customerName = PPOrderModelFirstString(shippingSnapshot, @[@"fullName", @"displayName", @"name", @"UserName"]);
    }
    if (m.customerPhone.length == 0) {
        m.customerPhone = PPOrderModelFirstString(shippingSnapshot, @[@"phoneNumber", @"MobileNo", @"phone", @"customerPhone"]);
    }
    if (m.deliveryAreaName.length == 0) {
        m.deliveryAreaName = PPOrderModelAreaNameFromSnapshot(shippingSnapshot);
    }
    if (m.deliveryLocationPoint.length == 0) {
        m.deliveryLocationPoint = PPOrderModelFirstString(shippingSnapshot, @[@"locationPoints", @"locationPoint", @"coordinates", @"coordinate"]);
    }

    // If address is a nested dict, extract formatted
    for (NSString *addrKey in @[@"deliveryAddress", @"shippingAddress", @"address"]) {
        id addrVal = dict[addrKey];
        if ([addrVal isKindOfClass:[NSDictionary class]]) {
            NSString *formatted = PPOrderModelExactAddressFromSnapshot((NSDictionary *)addrVal);
            if (formatted.length) {
                m.deliveryAddress = formatted;
                break;
            }
        }
    }

    if (m.pickupAddress.length == 0) {
        for (NSString *addrKey in @[@"pickupAddress", @"pickup_address", @"storeAddress", @"branchAddress"]) {
            id addrVal = dict[addrKey];
            if ([addrVal isKindOfClass:[NSDictionary class]]) {
                NSString *formatted = PPOrderModelExactAddressFromSnapshot((NSDictionary *)addrVal);
                if (formatted.length) {
                    m.pickupAddress = formatted;
                    break;
                }
            }
        }
    }

    if (m.deliveryAddress.length == 0 && shippingSnapshot.count > 0) {
        m.deliveryAddress = PPOrderModelExactAddressFromSnapshot(shippingSnapshot);
    }

    // Items
    NSArray *rawItems = dict[@"items"] ?: dict[@"orderItems"] ?: @[];
    NSMutableArray<PPDeliveryOrderItem *> *parsedItems = [NSMutableArray arrayWithCapacity:rawItems.count];
    for (NSDictionary *itemDict in rawItems) {
        if ([itemDict isKindOfClass:[NSDictionary class]]) {
            [parsedItems addObject:[PPDeliveryOrderItem fromDictionary:itemDict]];
        }
    }
    m.items = [parsedItems copy];

    NSMutableArray<NSString *> *marketplaceItemIDs = [NSMutableArray array];
    NSMutableSet<NSString *> *providerIDs = [NSMutableSet set];
    NSString *ownerType = nil;
    for (PPDeliveryOrderItem *item in parsedItems) {
        if (item.itemID.length && item.ownerID.length) {
            [marketplaceItemIDs addObject:item.itemID];
        }
        if (item.ownerID.length) {
            [providerIDs addObject:item.ownerID];
        }
        if (item.ownerType.length && ownerType == nil) {
            ownerType = item.ownerType;
        }
    }
    m.marketplaceItemIDs = [marketplaceItemIDs copy];
    m.marketplaceProviderID = providerIDs.count == 1 ? [providerIDs.allObjects.firstObject copy] : nil;
    m.marketplaceOwnerType = ownerType;

    // Parse marketplace provider info from order document
    m.marketplaceProviderName = PPOrderModelSafeOptionalString(dict, @[@"marketplaceProviderName", @"providerName", @"deliveryRequestProviderName"]);
    m.marketplaceProviderPhone = PPOrderModelSafeOptionalString(dict, @[@"marketplaceProviderPhone", @"providerPhone", @"deliveryRequestProviderPhone"]);
    m.marketplaceProviderPhotoURLString = PPOrderModelSafeOptionalString(dict, @[@"marketplaceProviderPhotoURL", @"providerPhotoURL", @"deliveryRequestProviderPhotoURL", @"marketplaceProviderPhotoURLString"]);

    // Financials
    m.totalAmount    = PPOrderModelSafeDouble(dict, @[@"totalAmount", @"amount", @"total", @"grandTotal"]);
    m.currencyCode   = PPOrderModelSafeString(dict, @[@"currencyCode", @"currency"]);
    if (m.currencyCode.length == 0) m.currencyCode = @"QAR";
    m.paymentMethodId = PPOrderModelSafeString(dict, @[@"paymentMethodId", @"paymentType"]);

    // Nested paymentMethod
    if (m.paymentMethodId.length == 0) {
        NSDictionary *pm = dict[@"paymentMethod"];
        if ([pm isKindOfClass:[NSDictionary class]]) {
            m.paymentMethodId = pm[@"methodId"] ?: pm[@"type"] ?: @"";
        }
    }
    m.paymentStatus = PPOrderModelSafeString(dict, @[@"paymentStatus", @"payment_status"]);

    // Status
    m.rawStatus = PPOrderModelSafeString(dict, @[@"status", @"rawStatus", @"orderStatus"]);
    m.deliveryStatus = PPOrderModelSafeString(dict, @[@"deliveryStatus"]);
    m.notes     = PPOrderModelSafeString(dict, @[@"notes", @"deliveryNotes", @"note"]);
    m.latestDeliveryEventType = PPOrderModelSafeString(dict, @[@"latestDeliveryEventType"]);

    // Delivery assignment
    m.deliveryUserId   = PPOrderModelSafeString(dict, @[@"deliveryUserId", @"deliveryUid"]);
    m.deliveryUserName = PPOrderModelSafeString(dict, @[@"deliveryUserName", @"deliveryAgentName"]);
    m.deliveryUserPhone = PPOrderModelSafeString(dict, @[@"deliveryUserPhone", @"deliveryPhone"]);
    m.branchID = PPOrderModelSafeString(dict, @[@"BranchID", @"branchId", @"branch_id"]);
    
    // Parse branch name
    id rawBranchName = dict[@"branchName"];
    if ([rawBranchName isKindOfClass:[NSDictionary class]]) {
        NSDictionary *bn = (NSDictionary *)rawBranchName;
        NSString *ar = bn[@"ar"] ?: @"";
        NSString *en = bn[@"en"] ?: @"";
        m.branchName = Language.isRTL ? (ar.length ? ar : en) : (en.length ? en : ar);
    } else if ([rawBranchName isKindOfClass:[NSString class]]) {
        m.branchName = (NSString *)rawBranchName;
    }
    
    if (m.branchName.length == 0) {
        m.branchName = PPOrderModelSafeString(dict, @[@"storeName", @"shopName", @"branch_name"]);
    }

    // Timestamps
    m.createdAt          = PPDateFromFirestoreValue(dict[@"createdAt"] ?: dict[@"created_at"] ?: dict[@"timestamp"]);
    m.processedAt        = PPDateFromFirestoreValue(dict[@"processedAt"] ?: dict[@"processed_at"]);
    m.readyAt            = PPDateFromFirestoreValue(dict[@"readyAt"] ?: dict[@"ready_at"]);
    m.readyToShipAt      = PPDateFromFirestoreValue(dict[@"readyToShipAt"]);
    m.deliveryRequestedAt = PPDateFromFirestoreValue(dict[@"deliveryRequestedAt"]);
    m.deliveryAcceptedAt = PPDateFromFirestoreValue(dict[@"deliveryAcceptedAt"]);
    m.pickedUpAt         = PPDateFromFirestoreValue(dict[@"pickedUpAt"]);
    m.inTransitAt        = PPDateFromFirestoreValue(dict[@"inTransitAt"]);
    m.shippedAt          = PPDateFromFirestoreValue(dict[@"shippedAt"] ?: dict[@"shipped_at"]);
    m.deliveredAt        = PPDateFromFirestoreValue(dict[@"deliveredAt"] ?: dict[@"delivered_at"]);
    m.paymentPendingAt   = PPDateFromFirestoreValue(dict[@"paymentPendingAt"]);
    m.paymentConfirmedAt = PPDateFromFirestoreValue(dict[@"paymentConfirmedAt"]);
    m.completedAt        = PPDateFromFirestoreValue(dict[@"completedAt"]);
    m.paymentCollectedAt = PPDateFromFirestoreValue(dict[@"paymentCollectedAt"] ?: dict[@"payment_collected_at"]);
    m.cancelledAt        = PPDateFromFirestoreValue(dict[@"deliveryCancelledAt"] ?: dict[@"cancelledAt"] ?: dict[@"cancelled_at"]);
    m.deliveryFailedAt   = PPDateFromFirestoreValue(dict[@"deliveryFailedAt"]);
    m.returnedToStoreAt  = PPDateFromFirestoreValue(dict[@"returnedToStoreAt"]);
    m.latestDeliveryEventAt = PPDateFromFirestoreValue(dict[@"latestDeliveryEventAt"]);

    if (m.deliveryStatus.length == 0) {
        NSString *raw = [m.rawStatus lowercaseString];
        if (PPStatusHasAny(raw, @[@"cancelled", @"canceled"])) {
            m.deliveryStatus = PPDeliveryStatusCancelled;
        } else if (PPStatusHasAny(raw, @[@"returned_to_store"])) {
            m.deliveryStatus = PPDeliveryStatusReturnedToStore;
        } else if (PPStatusHasAny(raw, @[@"failed"])) {
            m.deliveryStatus = PPDeliveryStatusFailed;
        } else if (PPStatusHasAny(raw, @[@"completed", @"fulfilled"])) {
            m.deliveryStatus = PPDeliveryStatusCompleted;
        } else if (PPStatusHasAny(raw, @[@"delivered"])) {
            BOOL requiresCashConfirmation = [m isCashOrder] &&
                                            (m.paymentCollectedAt == nil &&
                                             ![[m.paymentStatus lowercaseString] isEqualToString:@"paid"]);
            m.deliveryStatus = requiresCashConfirmation ? PPDeliveryStatusPaymentPending : PPDeliveryStatusDelivered;
        } else if (PPStatusHasAny(raw, @[@"shipped", @"shipping", @"in_transit", @"out_for_delivery"])) {
            m.deliveryStatus = m.inTransitAt ? PPDeliveryStatusInTransit : PPDeliveryStatusPickedUp;
        } else if ([raw isEqualToString:@"ready"]) {
            m.deliveryStatus = m.deliveryUserId.length ? PPDeliveryStatusAwaitingHandover : PPDeliveryStatusRequested;
        } else if (PPStatusHasAny(raw, @[@"processing", @"preparing", @"packed", @"confirmed", @"paid"])) {
            m.deliveryStatus = PPDeliveryStatusReadyToShip;
        }
    }

    return m;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"orderId"]            = self.orderId ?: @"";
    d[@"orderNumber"]        = self.orderNumber ?: @"";
    d[@"displayOrderNumber"] = self.displayOrderNumber ?: @"";
    d[@"userId"]             = self.userId ?: @"";
    d[@"fulfillmentVersion"] = @(self.fulfillmentVersion);
    d[@"fulfillmentOrderIDs"] = self.fulfillmentOrderIDs ?: @[];
    d[@"customerName"]       = self.customerName ?: @"";
    d[@"customerPhone"]      = self.customerPhone ?: @"";
    d[@"deliveryAddress"]    = self.deliveryAddress ?: @"";
    d[@"pickupAddress"]      = self.pickupAddress ?: @"";
    d[@"deliveryAreaName"]   = self.deliveryAreaName ?: @"";
    d[@"deliveryLocationPoint"] = self.deliveryLocationPoint ?: @"";
    d[@"marketplaceProviderID"] = self.marketplaceProviderID ?: @"";
    d[@"marketplaceOwnerType"] = self.marketplaceOwnerType ?: @"";
    d[@"totalAmount"]        = @(self.totalAmount);
    d[@"currencyCode"]       = self.currencyCode ?: @"QAR";
    d[@"paymentMethodId"]    = self.paymentMethodId ?: @"";
    d[@"paymentStatus"]      = self.paymentStatus ?: @"";
    d[@"status"]             = self.rawStatus ?: @"";
    d[@"deliveryStatus"]     = self.deliveryStatus ?: @"";
    d[@"notes"]              = self.notes ?: @"";
    return [d copy];
}

#pragma mark - Status Helpers

- (BOOL)isCashOrder {
    NSString *lower = [self.paymentMethodId lowercaseString];
    return [lower isEqualToString:@"cash"] || [lower isEqualToString:@"cod"] || [lower isEqualToString:@"cash_on_delivery"];
}

- (BOOL)isReady {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    return [delivery isEqualToString:PPDeliveryStatusRequested] ||
           [delivery isEqualToString:PPDeliveryStatusReadyToShip];
}

- (BOOL)canAcceptDelivery {
    return [[self.deliveryStatus lowercaseString] isEqualToString:PPDeliveryStatusRequested] &&
           self.deliveryUserId.length == 0;
}

- (BOOL)canConfirmPackageHandover {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    return [delivery isEqualToString:PPDeliveryStatusAssigned] ||
           [delivery isEqualToString:PPDeliveryStatusAwaitingHandover];
}

- (BOOL)canMarkShipped {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    if (self.fulfillmentVersion == 1) {
        return [delivery isEqualToString:PPDeliveryStatusAwaitingHandover];
    }
    return [self canConfirmPackageHandover];
}

- (BOOL)canMarkInTransit {
    return [[self.deliveryStatus lowercaseString] isEqualToString:PPDeliveryStatusPickedUp];
}

- (BOOL)canMarkDelivered {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    return [delivery isEqualToString:PPDeliveryStatusPickedUp] ||
           [delivery isEqualToString:PPDeliveryStatusInTransit];
}

- (BOOL)canCollectCashPayment {
    if (![self isCashOrder]) return NO;
    NSSet *validStatus  = [NSSet setWithArray:@[PPDeliveryStatusDelivered, PPDeliveryStatusPaymentPending]];
    NSSet *validPayment = [NSSet setWithArray:@[@"pending_collection", @"pending"]];
    return [validStatus containsObject:[self.deliveryStatus lowercaseString]] &&
           [validPayment containsObject:[self.paymentStatus lowercaseString]];
}

- (BOOL)canMarkCompleted {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    if ([delivery isEqualToString:PPDeliveryStatusPaymentConfirmed]) {
        return YES;
    }
    if ([delivery isEqualToString:PPDeliveryStatusDelivered]) {
        return ![self isCashOrder] || self.paymentCollectedAt != nil || [[self.paymentStatus lowercaseString] isEqualToString:@"paid"];
    }
    return NO;
}

- (BOOL)canCancel {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    return [delivery isEqualToString:PPDeliveryStatusRequested] ||
           [delivery isEqualToString:PPDeliveryStatusAssigned] ||
           [delivery isEqualToString:PPDeliveryStatusAwaitingHandover];
}

- (BOOL)isTerminal {
    NSSet *terminal = [NSSet setWithArray:@[
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]];
    return [terminal containsObject:[self.deliveryStatus lowercaseString]];
}

#pragma mark - Display Helpers

- (BOOL)pp_canRevealExactDeliveryLocation {
    return self.deliveryUserId.length > 0 || self.deliveryAcceptedAt != nil;
}

- (BOOL)pp_canRevealCustomerPhoneForDeliveryUserID:(NSString *)deliveryUserID {
    if (deliveryUserID.length == 0 ||
        self.deliveryUserId.length == 0 ||
        ![self.deliveryUserId isEqualToString:deliveryUserID]) {
        return NO;
    }

    // Current acceptance writes deliveryAcceptedAt. The status fallback keeps
    // already-accepted legacy orders usable without exposing pre-accept data.
    if (self.deliveryAcceptedAt != nil) return YES;

    static NSSet<NSString *> *acceptedDeliveryStatuses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        acceptedDeliveryStatuses = [NSSet setWithArray:@[
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
        ]];
    });
    return [acceptedDeliveryStatuses containsObject:self.deliveryStatus.lowercaseString ?: @""];
}

- (NSString *)pp_pickupLocationSummary {
    if (self.pickupAddress.length) return self.pickupAddress;
    if (self.branchName.length) return self.branchName;
    if (self.branchID.length) return self.branchID;
    if (self.marketplaceProviderName.length) return self.marketplaceProviderName;
    if (self.marketplaceProviderID.length &&
        ![self.marketplaceProviderID isEqualToString:@"platform"]) {
        return self.marketplaceProviderID;
    }
    return kLang(@"Deliv_BranchPendingAssignment") ?: @"";
}

- (NSString *)pp_deliveryAreaSummary {
    if (self.deliveryAreaName.length) return self.deliveryAreaName;
    return kLang(@"Deliv_DeliveryAreaPending") ?: @"";
}

- (NSString *)pp_exactDeliveryLocationText {
    if (self.deliveryAddress.length) return self.deliveryAddress;
    return self.deliveryLocationPoint ?: @"";
}

- (NSString *)pp_visibleCustomerLocationSummary {
    if ([self pp_canRevealExactDeliveryLocation]) {
        NSString *exact = [self pp_exactDeliveryLocationText];
        if (exact.length) return exact;
    }
    NSString *area = [self pp_deliveryAreaSummary];
    return area.length ? area : (kLang(@"Deliv_AddressHidden") ?: @"");
}

- (NSString *)displayStatus {
    NSString *delivery = [self.deliveryStatus lowercaseString];
    if ([delivery isEqualToString:PPDeliveryStatusReadyToShip])      return kLang(@"Deliv_StatusPreparing");
    if ([delivery isEqualToString:PPDeliveryStatusRequested])        return kLang(@"Deliv_StatusRequested");
    if ([delivery isEqualToString:PPDeliveryStatusAssigned])         return kLang(@"Deliv_StatusAssigned");
    if ([delivery isEqualToString:PPDeliveryStatusAwaitingHandover]) return kLang(@"Deliv_StatusAwaitingHandover");
    if ([delivery isEqualToString:PPDeliveryStatusPickedUp])         return kLang(@"Deliv_StatusPickedUp");
    if ([delivery isEqualToString:PPDeliveryStatusInTransit])        return kLang(@"Deliv_StatusInTransit");
    if ([delivery isEqualToString:PPDeliveryStatusDelivered])        return kLang(@"Deliv_StatusDelivered");
    if ([delivery isEqualToString:PPDeliveryStatusPaymentPending])   return kLang(@"Deliv_StatusPaymentPending");
    if ([delivery isEqualToString:PPDeliveryStatusPaymentConfirmed]) return kLang(@"Deliv_StatusPaymentConfirmed");
    if ([delivery isEqualToString:PPDeliveryStatusCompleted])        return kLang(@"Deliv_StatusCompleted");
    if ([delivery isEqualToString:PPDeliveryStatusCancelled])        return kLang(@"Deliv_StatusCancelled");
    if ([delivery isEqualToString:PPDeliveryStatusFailed])           return kLang(@"Deliv_StatusFailed");
    if ([delivery isEqualToString:PPDeliveryStatusReturnedToStore])  return kLang(@"Deliv_StatusReturned");
    return self.rawStatus ?: @"";
}

- (NSString *)formattedTotal {
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterCurrencyStyle;
    fmt.currencyCode = self.currencyCode ?: @"QAR";
    fmt.maximumFractionDigits = 2;
    return [fmt stringFromNumber:@(self.totalAmount)] ?: [NSString stringWithFormat:@"%.2f %@", self.totalAmount, self.currencyCode];
}

- (NSString *)bestOrderNumber {
    if (self.displayOrderNumber.length) return self.displayOrderNumber;
    if (self.orderNumber.length) return self.orderNumber;
    // Fallback: last 8 chars of orderId
    if (self.orderId.length > 8) return [self.orderId substringFromIndex:self.orderId.length - 8];
    return self.orderId;
}

@end
