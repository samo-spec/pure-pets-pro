//
//  PPServiceModel.m
//  PurePetsPro
//

#import "PPServiceModel.h"
#import "ArabicNormalizer.h"

// Private readwrite redeclaration
@interface PPServiceModel ()
@property (nonatomic, assign) BOOL isDisabled;
@property (nonatomic, assign) BOOL isBlocked;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, copy)   NSString *verificationStatus;
@property (nonatomic, copy)   NSString *subscriptionPlan;
@property (nonatomic, copy)   NSString *subscriptionStatus;
@property (nonatomic, assign) BOOL subscriptionActive;
@property (nonatomic, strong, nullable) NSDate *subscriptionStartDate;
@property (nonatomic, strong, nullable) NSDate *subscriptionEndDate;
@end

@implementation PPServiceModel

#pragma mark - Date Helper

+ (nullable NSDate *)dateFromValue:(id)value {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSDate class]]) return value;
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue];
    return nil;
}

#pragma mark - Localized Helpers

- (NSString *)localizedTypeName {
    switch (self.type) {
        case PPServiceTypeGrooming: return kLang(@"typeGrooming");
        case PPServiceTypeTraining: return kLang(@"typeTraining");
        default: return @"";
    }
}

- (NSString *)localizedVerificationStatus {
    NSString *v = [self.verificationStatus lowercaseString] ?: @"";
    if ([v isEqualToString:@"verified"]) return kLang(@"verifVerified");
    if ([v isEqualToString:@"pending"] || [v isEqualToString:@"pending_review"]) return kLang(@"verifPending");
    if ([v isEqualToString:@"rejected"] || [v isEqualToString:@"blocked"]) return kLang(@"verifRejected");
    return self.verificationStatus ?: kLang(@"verifNotSet");
}

- (NSString *)localizedAvailabilityStatus {
    if (self.isBlocked)  return kLang(@"statusBlocked");
    if (self.isDisabled) return kLang(@"statusDisabled");
    return self.isAvailable ? kLang(@"Serv_Available") : kLang(@"Serv_Unavailable");
}

- (BOOL)isLive {
    return !self.isDeleted && !self.isBlocked && !self.isDisabled && self.isAvailable;
}

#pragma mark - Provider Serialization (writes only provider-controlled fields)

- (NSDictionary *)providerToDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"title"]          = self.title ?: @"";
    d[@"searchTitle"]    = [ArabicNormalizer normalize:self.title ?: @""];
    d[@"description"]    = self.descriptionText ?: @"";
    d[@"price"]          = @(self.price);
    d[@"currency"]       = self.currency ?: @"QAR";
    d[@"category"]       = self.category ?: @"";
    d[@"categoryID"]     = self.categoryID ?: @"";
    d[@"petMainKindID"]  = @(self.petMainKindID);
    d[@"type"]           = @(self.type);
    d[@"imageURL"]       = self.imageURL ?: @"";
    d[@"blurHash"]       = self.blurHash ?: @"";
    d[@"serviceOwnerID"] = self.serviceOwnerID ?: @"";
    d[@"isAvailable"]    = @(self.isAvailable);
    d[@"updatedAt"]      = [NSDate date];
    return [d copy];
}

#pragma mark - Full Serialization (backward compat round-trip)

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [[self providerToDictionary] mutableCopy];

    // Legacy / system fields preserved for Firestore round-trip
    d[@"availableDate"]  = self.availableDate ?: [NSNull null];
    d[@"timestamp"]      = self.timestamp ?: [NSNull null];
    d[@"createdAt"]      = self.createdAt ?: [NSNull null];

    // System status (read-only but preserved on full write)
    d[@"isDisabled"]          = @(self.isDisabled);
    d[@"isBlocked"]           = @(self.isBlocked);
    d[@"isDeleted"]           = @(self.isDeleted);
    d[@"verificationStatus"]  = self.verificationStatus ?: @"";

    // Subscription (read-only but preserved on full write)
    d[@"subscriptionPlan"]      = self.subscriptionPlan ?: @"";
    d[@"subscriptionStatus"]    = self.subscriptionStatus ?: @"";
    d[@"subscriptionActive"]    = @(self.subscriptionActive);
    d[@"subscriptionStartDate"] = self.subscriptionStartDate ?: [NSNull null];
    d[@"subscriptionEndDate"]   = self.subscriptionEndDate ?: [NSNull null];

    // Extra passthrough
    [d addEntriesFromDictionary:self.extraFields ?: @{}];

    return [d copy];
}

#pragma mark - Deserialization

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)serviceID {
    PPServiceModel *m = [[PPServiceModel alloc] init];

    // Identity
    m.serviceID      = serviceID ?: @"";
    m.serviceOwnerID = dict[@"serviceOwnerID"] ?: @"";
    m.title          = dict[@"title"] ?: @"";
    m.searchTitle    = dict[@"searchTitle"] ?: @"";
    m.descriptionText = dict[@"description"] ?: @"";
    m.price          = [dict[@"price"] doubleValue];
    m.currency       = dict[@"currency"] ?: @"QAR";
    m.category       = dict[@"category"] ?: @"";
    m.categoryID     = dict[@"categoryID"] ?: @"";
    m.petMainKindID  = [dict[@"petMainKindID"] integerValue];
    m.type           = [dict[@"type"] integerValue];
    m.imageURL       = dict[@"imageURL"] ?: @"";
    m.blurHash       = dict[@"blurHash"] ?: @"";

    // Availability: prefer explicit isAvailable, fall back to legacy availableDate
    if (dict[@"isAvailable"] != nil) {
        m.isAvailable = [dict[@"isAvailable"] boolValue];
    } else {
        // Legacy: if availableDate exists and is in the future, treat as available
        NSDate *avDate = [self dateFromValue:dict[@"availableDate"]];
        m.isAvailable = (avDate == nil) || ([avDate compare:[NSDate date]] != NSOrderedAscending);
    }

    // System status (read-only)
    m.isDisabled          = [dict[@"isDisabled"] boolValue];
    m.isBlocked           = [dict[@"isBlocked"] boolValue];
    m.isDeleted           = [dict[@"isDeleted"] boolValue];
    m.verificationStatus  = dict[@"verificationStatus"] ?: @"";

    // Subscription (read-only)
    m.subscriptionPlan      = dict[@"subscriptionPlan"] ?: @"free";
    m.subscriptionStatus    = dict[@"subscriptionStatus"] ?: @"";
    m.subscriptionActive    = [dict[@"subscriptionActive"] boolValue];
    m.subscriptionStartDate = [self dateFromValue:dict[@"subscriptionStartDate"]];
    m.subscriptionEndDate   = [self dateFromValue:dict[@"subscriptionEndDate"]];

    // Timestamps
    m.createdAt     = [self dateFromValue:dict[@"createdAt"]];
    m.updatedAt     = [self dateFromValue:dict[@"updatedAt"]];
    m.availableDate = [self dateFromValue:dict[@"availableDate"]];
    m.timestamp     = [self dateFromValue:dict[@"timestamp"]];

    // Extra fields passthrough
    NSSet *knownKeys = [NSSet setWithArray:@[
        @"title", @"searchTitle", @"description", @"price", @"currency",
        @"category", @"categoryID", @"petMainKindID", @"type",
        @"imageURL", @"blurHash", @"serviceOwnerID", @"isAvailable",
        @"availableDate", @"timestamp", @"createdAt", @"updatedAt",
        @"isDisabled", @"isBlocked", @"isDeleted", @"verificationStatus",
        @"subscriptionType", @"subscriptionPlan", @"subscriptionStatus",
        @"subscriptionActive", @"subscriptionStartDate", @"subscriptionEndDate",
        @"serviceFlags", @"archivedAt", @"archivedBy", @"blockedBy", @"disabledBy"
    ]];
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![knownKeys containsObject:key]) extra[key] = obj;
    }];
    m.extraFields = [extra copy];

    return m;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PPServiceModel *c = [[PPServiceModel allocWithZone:zone] init];
    c.serviceID      = self.serviceID;
    c.serviceOwnerID = self.serviceOwnerID;
    c.title          = self.title;
    c.searchTitle    = self.searchTitle;
    c.descriptionText = self.descriptionText;
    c.price          = self.price;
    c.currency       = self.currency;
    c.category       = self.category;
    c.categoryID     = self.categoryID;
    c.petMainKindID  = self.petMainKindID;
    c.type           = self.type;
    c.imageURL       = self.imageURL;
    c.blurHash       = self.blurHash;
    c.isAvailable    = self.isAvailable;
    c.isDisabled     = self.isDisabled;
    c.isBlocked      = self.isBlocked;
    c.isDeleted      = self.isDeleted;
    c.verificationStatus  = self.verificationStatus;
    c.subscriptionPlan    = self.subscriptionPlan;
    c.subscriptionStatus  = self.subscriptionStatus;
    c.subscriptionActive  = self.subscriptionActive;
    c.subscriptionStartDate = self.subscriptionStartDate;
    c.subscriptionEndDate = self.subscriptionEndDate;
    c.createdAt      = self.createdAt;
    c.updatedAt      = self.updatedAt;
    c.availableDate  = self.availableDate;
    c.timestamp      = self.timestamp;
    c.extraFields    = self.extraFields;
    return c;
}

@end
