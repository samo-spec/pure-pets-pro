//
//  PPVetModel.m
//  PurePetsAdmin
//

#import "PPVetModel.h"

static NSString *PPVetSafeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    }
    return @"";
}

static NSArray<NSString *> *PPVetStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id entry in (NSArray *)value) {
        NSString *safeEntry = PPVetSafeString(entry);
        if (safeEntry.length > 0) {
            [items addObject:safeEntry];
        }
    }
    return items.copy;
}

static NSString *PPVetNormalizedTypeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [PPVetSafeString(value).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([normalized isEqualToString:@"clinic"] || [normalized isEqualToString:@"company"] || [normalized isEqualToString:@"1"]) {
            return @"clinic";
        }
        if ([normalized isEqualToString:@"doctor"] || [normalized isEqualToString:@"personal"] || [normalized isEqualToString:@"0"]) {
            return @"doctor";
        }
    }
    if ([value respondsToSelector:@selector(integerValue)] && [value integerValue] == PPVetTypeCompany) {
        return @"clinic";
    }
    return @"doctor";
}

@implementation PPVetModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _vetID = @"";
        _userID = @"";
        _logoURL = @"";
        _title = @"";
        _descriptionText = @"";
        _phone = @"";
        _whatsapp = @"";
        _blurHash = @"";
        _animalTypes = @[];
        _verificationStatus = @"pending";
    }
    return self;
}

#pragma mark - Derived

- (NSString *)name_lowercase {
    return self.title.lowercaseString ?: @"";
}

- (NSString *)normalizedTypeValue {
    return self.type == PPVetTypeCompany ? @"clinic" : @"doctor";
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSString *safeTitle = self.title ?: @"";
    NSString *descriptionText = self.descriptionText ?: @"";
    NSMutableDictionary *dict = [@{
        @"type":            [self normalizedTypeValue],
        @"userId":          self.userID ?: @"",
        @"petMainKindID":   @(self.petMainKindID),
        @"logoUrl":         self.logoURL ?: @"",
        @"title":           safeTitle,
        @"name_lowercase":  safeTitle.lowercaseString,
        @"description":     descriptionText,
        @"descriptionText": descriptionText,
        @"phone":           self.phone ?: @"",
        @"whatsapp":        self.whatsapp ?: @"",
        @"blurHash":        self.blurHash ?: @"",
        @"availableDate":   self.availableDate ?: [NSNull null],
        @"vetCost":         @(self.vetCost),
        @"animalTypes":     self.animalTypes ?: @[],
        @"readyToContact":  @(self.readyToContact || self.phone.length > 0 || self.whatsapp.length > 0),
        @"isDisabled":      @(self.isDisabled),
        @"verificationStatus": PPVetSafeString(self.verificationStatus).length > 0 ? self.verificationStatus : @"pending",
        @"subscriptionTier":      @(self.subscriptionTier),
        @"subscriptionActive":    @(self.subscriptionActive),
        @"subscriptionStartDate": self.subscriptionStartDate ?: [NSNull null],
        @"subscriptionEndDate":   self.subscriptionEndDate   ?: [NSNull null],
        @"canEditProfile":  @(self.canEditProfile),
        @"canPostServices": @(self.canPostServices),
        @"canPostMedicines": @(self.canPostMedicines),
    } mutableCopy];

    if (self.createdAt) {
        dict[@"createdAt"] = self.createdAt;
    }
    dict[@"updatedAt"] = self.updatedAt ?: [NSDate date];

    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)vetID {
    PPVetModel *m = [[PPVetModel alloc] init];
    m.vetID           = vetID ?: @"";
    m.type            = [PPVetNormalizedTypeString(dict[@"type"]) isEqualToString:@"clinic"] ? PPVetTypeCompany : PPVetTypePersonal;
    m.userID          = PPVetSafeString(dict[@"userId"]).length > 0 ? PPVetSafeString(dict[@"userId"]) : PPVetSafeString(dict[@"userID"]);
    m.petMainKindID   = [dict[@"petMainKindID"] integerValue];
    m.logoURL         = PPVetSafeString(dict[@"logoUrl"]).length > 0 ? PPVetSafeString(dict[@"logoUrl"]) : PPVetSafeString(dict[@"logoURL"]);
    m.title           = PPVetSafeString(dict[@"title"]);
    m.descriptionText = PPVetSafeString(dict[@"description"]).length > 0 ? PPVetSafeString(dict[@"description"]) : PPVetSafeString(dict[@"descriptionText"]);
    m.phone           = PPVetSafeString(dict[@"phone"]);
    m.whatsapp        = PPVetSafeString(dict[@"whatsapp"]);
    m.blurHash        = PPVetSafeString(dict[@"blurHash"]);
    m.vetCost         = [dict[@"vetCost"] doubleValue];
    m.animalTypes     = PPVetStringArray(dict[@"animalTypes"]);
    m.readyToContact  = [dict[@"readyToContact"] boolValue] || m.phone.length > 0 || m.whatsapp.length > 0;

    // Dates — handle both FIRTimestamp and NSDate
    m.availableDate         = [self dateFromValue:dict[@"availableDate"]];
    m.createdAt             = [self dateFromValue:dict[@"createdAt"]];
    m.updatedAt             = [self dateFromValue:dict[@"updatedAt"]];
    m.subscriptionStartDate = [self dateFromValue:dict[@"subscriptionStartDate"]];
    m.subscriptionEndDate   = [self dateFromValue:dict[@"subscriptionEndDate"]];

    // Admin
    m.isDisabled        = [dict[@"isDisabled"] boolValue];
    m.verificationStatus = PPVetSafeString(dict[@"verificationStatus"]).length > 0 ? PPVetSafeString(dict[@"verificationStatus"]) : @"pending";
    m.subscriptionTier  = [dict[@"subscriptionTier"] integerValue];
    m.subscriptionActive = [dict[@"subscriptionActive"] boolValue];
    m.canEditProfile = [dict[@"canEditProfile"] boolValue];
    m.canPostServices = [dict[@"canPostServices"] boolValue];
    m.canPostMedicines = [dict[@"canPostMedicines"] boolValue];

    return m;
}

#pragma mark - Helpers

+ (nullable NSDate *)dateFromValue:(id)value {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSDate class]]) return value;
    // FIRTimestamp
    if ([value respondsToSelector:@selector(dateValue)]) return [value dateValue];
    return nil;
}

- (NSString *)localizedTypeName {
    switch (self.type) {
        case PPVetTypePersonal: return kLang(@"Vet_Type_Personal");
        case PPVetTypeCompany:  return kLang(@"Vet_Type_Company");
        default:                return @"";
    }
}

- (NSString *)localizedSubscriptionTierName {
    switch (self.subscriptionTier) {
        case PPVetSubscriptionFree:    return kLang(@"Vet_Sub_Free");
        case PPVetSubscriptionBasic:   return kLang(@"Vet_Sub_Basic");
        case PPVetSubscriptionPremium: return kLang(@"Vet_Sub_Premium");
        default:                       return @"";
    }
}

- (BOOL)isSubscriptionExpired {
    if (!self.subscriptionEndDate) return NO;
    return [self.subscriptionEndDate compare:[NSDate date]] == NSOrderedAscending;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PPVetModel *copy = [[PPVetModel allocWithZone:zone] init];
    copy.vetID           = self.vetID;
    copy.type            = self.type;
    copy.userID          = self.userID;
    copy.petMainKindID   = self.petMainKindID;
    copy.logoURL         = self.logoURL;
    copy.title           = self.title;
    copy.descriptionText = self.descriptionText;
    copy.phone           = self.phone;
    copy.whatsapp        = self.whatsapp;
    copy.blurHash        = self.blurHash;
    copy.availableDate   = self.availableDate;
    copy.vetCost         = self.vetCost;
    copy.animalTypes     = self.animalTypes;
    copy.readyToContact  = self.readyToContact;
    copy.isDisabled      = self.isDisabled;
    copy.verificationStatus = self.verificationStatus;
    copy.subscriptionTier    = self.subscriptionTier;
    copy.subscriptionStartDate = self.subscriptionStartDate;
    copy.subscriptionEndDate   = self.subscriptionEndDate;
    copy.subscriptionActive    = self.subscriptionActive;
    copy.canEditProfile  = self.canEditProfile;
    copy.canPostServices = self.canPostServices;
    copy.canPostMedicines = self.canPostMedicines;
    copy.createdAt       = self.createdAt;
    copy.updatedAt       = self.updatedAt;
    return copy;
}

@end
