#import "PPDeliveryCompanyModels.h"

PPDeliveryCompanyRole const PPDeliveryCompanyRoleOwner = @"owner";
PPDeliveryCompanyRole const PPDeliveryCompanyRoleDispatcher = @"dispatcher";
PPDeliveryCompanyRole const PPDeliveryCompanyRoleDriver = @"driver";
PPDeliveryCompanyRole const PPDeliveryCompanyRoleViewer = @"viewer";

PPDeliveryCompanyStatus const PPDeliveryCompanyStatusOffered = @"offered";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusAccepted = @"accepted_by_company";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusAssigned = @"assigned_to_driver";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusPickedUp = @"picked_up";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusInTransit = @"in_transit";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusDelivered = @"delivered";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusCompleted = @"completed";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusRejected = @"rejected";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusCancelled = @"cancelled";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusFailed = @"failed";
PPDeliveryCompanyStatus const PPDeliveryCompanyStatusExpired = @"expired";

static NSString *PPDCString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    return @"";
}

static NSDictionary *PPDCDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPDCFirstString(NSArray *values) {
    for (id value in values) {
        NSString *stringValue = PPDCString(value);
        if (stringValue.length > 0) {
            return stringValue;
        }
    }
    return @"";
}

static NSString *PPDCFirstStringForKeys(NSDictionary *primary, NSDictionary *secondary, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *primaryValue = PPDCString(primary[key]);
        if (primaryValue.length > 0) {
            return primaryValue;
        }

        NSString *secondaryValue = PPDCString(secondary[key]);
        if (secondaryValue.length > 0) {
            return secondaryValue;
        }
    }
    return @"";
}

NSDate *PPDeliveryCompanyDateFromValue(id value) {
    if (!value || [value isKindOfClass:NSNull.class]) return nil;
    if ([value isKindOfClass:NSDate.class]) return value;
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue];
    if ([value isKindOfClass:NSNumber.class]) {
        NSTimeInterval interval = [value doubleValue];
        if (interval > 1000000000000.0) interval /= 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:interval];
    }
    if ([value isKindOfClass:NSString.class]) {
        static NSISO8601DateFormatter *formatter;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ formatter = [[NSISO8601DateFormatter alloc] init]; });
        return [formatter dateFromString:value];
    }
    return nil;
}

NSString *PPDeliveryCompanyFormattedDate(NSDate *date) {
    if (!date) return kLang(@"DeliveryCompany_NotAvailable");
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    });
    formatter.locale = [NSLocale currentLocale];
    return [formatter stringFromDate:date];
}

NSString *PPDeliveryCompanyRoleDisplayName(NSString *role) {
    NSDictionary *keys = @{
        PPDeliveryCompanyRoleOwner: @"DeliveryCompany_Role_Owner",
        PPDeliveryCompanyRoleDispatcher: @"DeliveryCompany_Role_Dispatcher",
        @"company_dispatcher": @"DeliveryCompany_Role_Dispatcher",
        PPDeliveryCompanyRoleDriver: @"DeliveryCompany_Role_Driver",
        PPDeliveryCompanyRoleViewer: @"DeliveryCompany_Role_Viewer",
        @"customer": @"DeliveryCompany_Role_Customer",
    };
    NSString *key = keys[PPDCString(role).lowercaseString];
    return key.length ? kLang(key) : PPDCString(role);
}

NSString *PPDeliveryCompanyStatusDisplayName(NSString *status) {
    NSDictionary *keys = @{
        PPDeliveryCompanyStatusOffered: @"DeliveryCompany_Status_Offered",
        PPDeliveryCompanyStatusAccepted: @"DeliveryCompany_Status_Accepted",
        PPDeliveryCompanyStatusAssigned: @"DeliveryCompany_Status_Assigned",
        PPDeliveryCompanyStatusPickedUp: @"DeliveryCompany_Status_PickedUp",
        PPDeliveryCompanyStatusInTransit: @"DeliveryCompany_Status_InTransit",
        PPDeliveryCompanyStatusDelivered: @"DeliveryCompany_Status_Delivered",
        PPDeliveryCompanyStatusCompleted: @"DeliveryCompany_Status_Completed",
        PPDeliveryCompanyStatusRejected: @"DeliveryCompany_Status_Rejected",
        PPDeliveryCompanyStatusCancelled: @"DeliveryCompany_Status_Cancelled",
        PPDeliveryCompanyStatusFailed: @"DeliveryCompany_Status_Failed",
        PPDeliveryCompanyStatusExpired: @"DeliveryCompany_Status_Expired",
        @"reassigned": @"DeliveryCompany_Status_Reassigned",
    };
    NSString *normalized = PPDCString(status).lowercaseString;
    NSString *key = keys[normalized];
    return key.length ? kLang(key) : normalized;
}

UIColor *PPDeliveryCompanyStatusColor(NSString *status) {
    NSString *value = PPDCString(status).lowercaseString;
    if ([value isEqualToString:PPDeliveryCompanyStatusCompleted] ||
        [value isEqualToString:PPDeliveryCompanyStatusDelivered]) {
        return [UIColor ppSuccess];
    }
    if ([value isEqualToString:PPDeliveryCompanyStatusAccepted] ||
        [value isEqualToString:PPDeliveryCompanyStatusAssigned]) {
        return [UIColor ppInfo];
    }
    if ([value isEqualToString:PPDeliveryCompanyStatusPickedUp] ||
        [value isEqualToString:PPDeliveryCompanyStatusInTransit]) {
        return [UIColor ppWarning];
    }
    if ([value isEqualToString:PPDeliveryCompanyStatusRejected] ||
        [value isEqualToString:PPDeliveryCompanyStatusCancelled] ||
        [value isEqualToString:PPDeliveryCompanyStatusFailed] ||
        [value isEqualToString:PPDeliveryCompanyStatusExpired]) {
        return [UIColor ppError];
    }
    return [UIColor ppQuickActionAnimals];
}

NSString *PPDeliveryCompanyFilterTitle(PPDeliveryCompanyDashboardFilter filter) {
    switch (filter) {
        case PPDeliveryCompanyDashboardFilterNewRequests: return kLang(@"DeliveryCompany_Tab_New");
        case PPDeliveryCompanyDashboardFilterAccepted: return kLang(@"DeliveryCompany_Tab_Accepted");
        case PPDeliveryCompanyDashboardFilterAssigned: return kLang(@"DeliveryCompany_Tab_Assigned");
        case PPDeliveryCompanyDashboardFilterInProgress: return kLang(@"DeliveryCompany_Tab_InProgress");
        case PPDeliveryCompanyDashboardFilterDelivered: return kLang(@"DeliveryCompany_Tab_Delivered");
        case PPDeliveryCompanyDashboardFilterCompleted: return kLang(@"DeliveryCompany_Tab_Completed");
        case PPDeliveryCompanyDashboardFilterCancelledRejected: return kLang(@"DeliveryCompany_Tab_Closed");
        case PPDeliveryCompanyDashboardFilterMembers: return kLang(@"DeliveryCompany_Tab_Members");
    }
}

static NSString *PPDCAddressSummary(NSDictionary *address) {
    NSDictionary *safe = PPDCDictionary(address);
    for (NSString *key in @[@"formattedAddress", @"formatted", @"fullAddress", @"address", @"summary", @"locationName", @"areaName"]) {
        NSString *candidate = PPDCString(safe[key]);
        if (candidate.length) return candidate;
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in @[@"addressLine1", @"street", @"addressLine2", @"area", @"city"]) {
        NSString *candidate = PPDCString(safe[key]);
        if (candidate.length && ![parts containsObject:candidate]) [parts addObject:candidate];
    }
    return parts.count ? [parts componentsJoinedByString:@"، "] : kLang(@"DeliveryCompany_NotAvailable");
}

@implementation PPDeliveryCompanyProfile

+ (instancetype)modelFromResponse:(NSDictionary *)response {
    NSDictionary *company = PPDCDictionary(response[@"company"]);
    PPDeliveryCompanyProfile *model = [[self alloc] init];
    model.companyID = PPDCString(company[@"id"]);
    model.name = PPDCString(company[@"name"]);
    model.legalName = PPDCString(company[@"legalName"]);
    model.status = PPDCString(company[@"status"]).lowercaseString;
    model.available = company[@"isAvailable"] == nil ? YES : [company[@"isAvailable"] boolValue];
    model.role = PPDCString(response[@"myRole"]).lowercaseString;
    model.createdAt = PPDeliveryCompanyDateFromValue(company[@"createdAt"]);
    model.updatedAt = PPDeliveryCompanyDateFromValue(company[@"updatedAt"]);
    return model;
}

- (BOOL)isOwner { return [self.role isEqualToString:PPDeliveryCompanyRoleOwner]; }
- (BOOL)isDispatcher { return [self.role isEqualToString:PPDeliveryCompanyRoleDispatcher]; }
- (BOOL)isDriver { return [self.role isEqualToString:PPDeliveryCompanyRoleDriver]; }
- (BOOL)isViewer { return [self.role isEqualToString:PPDeliveryCompanyRoleViewer]; }
- (BOOL)canDispatch { return self.isOwner || self.isDispatcher; }
- (BOOL)canViewMembers { return self.role.length > 0 && !self.isDriver; }
- (BOOL)canManageMembers { return self.isOwner; }

@end

@implementation PPDeliveryCompanyEvent

+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary {
    PPDeliveryCompanyEvent *model = [[self alloc] init];
    model.eventID = PPDCString(dictionary[@"id"] ?: dictionary[@"eventId"]);
    model.eventType = PPDCString(dictionary[@"eventType"]);
    model.actorName = PPDCString(dictionary[@"actorName"]);
    model.actorRole = PPDCString(dictionary[@"actorRole"]);
    model.fromStatus = PPDCString(dictionary[@"fromStatus"]);
    model.toStatus = PPDCString(dictionary[@"toStatus"]);
    model.metadata = PPDCDictionary(dictionary[@"metadata"]);
    model.createdAt = PPDeliveryCompanyDateFromValue(dictionary[@"createdAt"]);
    return model;
}

@end

@implementation PPDeliveryCompanyRequest

+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary {
    PPDeliveryCompanyRequest *model = [[self alloc] init];
    model.requestID = PPDCString(dictionary[@"id"] ?: dictionary[@"requestId"]);
    model.orderID = PPDCString(dictionary[@"orderId"]);
    model.orderNumber = PPDCString(dictionary[@"orderNumber"]);
    model.companyID = PPDCString(dictionary[@"targetCompanyId"]);
    model.companyName = PPDCString(dictionary[@"targetCompanyName"]);
    model.status = PPDCString(dictionary[@"status"]).lowercaseString;
    model.pickupAddress = PPDCDictionary(dictionary[@"pickupAddress"]);
    model.dropoffAddress = PPDCDictionary(dictionary[@"dropoffAddress"]);
    model.assignedDriverUID = PPDCString(dictionary[@"assignedDriverUid"]);
    model.assignedDriverName = PPDCString(dictionary[@"assignedDriverName"]);
    model.deliveryFee = [dictionary[@"deliveryFee"] doubleValue];
    model.paymentStatus = PPDCString(dictionary[@"paymentStatus"]);
    model.deliveryNote = PPDCString(dictionary[@"deliveryNote"]);
    model.receiverName = PPDCString(dictionary[@"receiverName"]);
    model.createdAt = PPDeliveryCompanyDateFromValue(dictionary[@"createdAt"]);
    model.updatedAt = PPDeliveryCompanyDateFromValue(dictionary[@"updatedAt"]);
    NSMutableArray *events = [NSMutableArray array];
    for (NSDictionary *event in [dictionary[@"events"] isKindOfClass:NSArray.class] ? dictionary[@"events"] : @[]) {
        if ([event isKindOfClass:NSDictionary.class]) [events addObject:[PPDeliveryCompanyEvent modelFromDictionary:event]];
    }
    model.events = events.copy;
    return model;
}

- (NSString *)bestOrderNumber {
    return self.orderNumber.length ? self.orderNumber : (self.orderID.length ? self.orderID : self.requestID);
}

- (NSString *)pickupSummary { return PPDCAddressSummary(self.pickupAddress); }
- (NSString *)dropoffSummary { return PPDCAddressSummary(self.dropoffAddress); }
- (NSString *)formattedFee {
    return self.deliveryFee > 0.0
        ? [NSString stringWithFormat:kLang(@"DeliveryCompany_Fee_Format"), self.deliveryFee]
        : kLang(@"DeliveryCompany_Fee_Unavailable");
}
- (NSString *)statusDisplayName { return PPDeliveryCompanyStatusDisplayName(self.status); }
- (UIColor *)statusColor { return PPDeliveryCompanyStatusColor(self.status); }

- (BOOL)matchesFilter:(PPDeliveryCompanyDashboardFilter)filter {
    NSString *s = self.status;
    switch (filter) {
        case PPDeliveryCompanyDashboardFilterNewRequests:
            return [s isEqualToString:PPDeliveryCompanyStatusOffered];
        case PPDeliveryCompanyDashboardFilterAccepted:
            return [s isEqualToString:PPDeliveryCompanyStatusAccepted];
        case PPDeliveryCompanyDashboardFilterAssigned:
            return [s isEqualToString:PPDeliveryCompanyStatusAssigned];
        case PPDeliveryCompanyDashboardFilterInProgress:
            return [s isEqualToString:PPDeliveryCompanyStatusPickedUp] || [s isEqualToString:PPDeliveryCompanyStatusInTransit];
        case PPDeliveryCompanyDashboardFilterDelivered:
            return [s isEqualToString:PPDeliveryCompanyStatusDelivered];
        case PPDeliveryCompanyDashboardFilterCompleted:
            return [s isEqualToString:PPDeliveryCompanyStatusCompleted];
        case PPDeliveryCompanyDashboardFilterCancelledRejected:
            return [@[
                PPDeliveryCompanyStatusRejected,
                PPDeliveryCompanyStatusCancelled,
                PPDeliveryCompanyStatusFailed,
                PPDeliveryCompanyStatusExpired
            ] containsObject:s];
        case PPDeliveryCompanyDashboardFilterMembers:
            return NO;
    }
}

- (NSString *)nextDriverStatus {
    if ([self.status isEqualToString:PPDeliveryCompanyStatusAssigned]) return PPDeliveryCompanyStatusPickedUp;
    if ([self.status isEqualToString:PPDeliveryCompanyStatusPickedUp]) return PPDeliveryCompanyStatusInTransit;
    if ([self.status isEqualToString:PPDeliveryCompanyStatusInTransit]) return PPDeliveryCompanyStatusDelivered;
    return nil;
}

@end

@implementation PPDeliveryCompanyMember

+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary {
    PPDeliveryCompanyMember *model = [[self alloc] init];
    NSDictionary *profile = PPDCDictionary(dictionary[@"profile"]);
    model.uid = PPDCFirstString(@[
        PPDCString(dictionary[@"uid"]),
        PPDCString(dictionary[@"userId"]),
        PPDCString(dictionary[@"memberUid"])
    ]);
    model.displayName = PPDCFirstString(@[
        PPDCString(dictionary[@"displayName"]),
        PPDCString(dictionary[@"name"]),
        PPDCString(dictionary[@"fullName"]),
        PPDCString(profile[@"displayName"]),
        PPDCString(profile[@"name"]),
        PPDCString(profile[@"fullName"])
    ]);
    model.phone = PPDCFirstString(@[
        PPDCString(dictionary[@"phone"]),
        PPDCString(dictionary[@"phoneNumber"]),
        PPDCString(profile[@"phone"]),
        PPDCString(profile[@"phoneNumber"])
    ]);
    model.email = PPDCFirstString(@[
        PPDCString(dictionary[@"email"]),
        PPDCString(profile[@"email"])
    ]);
    model.photoURL = PPDCFirstStringForKeys(dictionary,
                                            profile,
                                            @[@"photoURL",
                                              @"photoUrl",
                                              @"UserImageUrl",
                                              @"userImageUrl",
                                              @"avatarURL",
                                              @"profilePhotoURL",
                                              @"profileImageURL"]);
    model.role = PPDCString(dictionary[@"role"]).lowercaseString;
    model.status = PPDCString(dictionary[@"status"]).lowercaseString;
    model.online = [dictionary[@"isOnline"] boolValue];
    model.available = dictionary[@"isAvailable"] == nil ? YES : [dictionary[@"isAvailable"] boolValue];
    model.canReceiveAssignments = [dictionary[@"canReceiveAssignments"] boolValue];
    model.activeDeliveryCount = [dictionary[@"activeDeliveryCount"] integerValue];
    model.lastSeenAt = PPDeliveryCompanyDateFromValue(dictionary[@"lastSeenAt"]);
    if (model.displayName.length == 0) {
        model.displayName = model.uid;
    }
    return model;
}

- (BOOL)isActiveDriver {
    return [self.role isEqualToString:PPDeliveryCompanyRoleDriver] &&
           [self.status isEqualToString:@"active"] &&
           self.canReceiveAssignments &&
           self.available;
}

@end
