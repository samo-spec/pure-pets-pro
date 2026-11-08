#import "PPProviderMarketItem.h"
#import "PetAccessory.h"

// Firestore arrays can contain legacy nulls. Filter before bridging to Swift's
// [String], where an unchecked element otherwise traps while opening the studio.
static NSArray<NSString *> *PPMarketImageURLs(id value) {
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    for (id candidate in PPSafeArray(value)) {
        if (![candidate isKindOfClass:NSString.class]) continue;
        NSString *url = [candidate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (url.length > 0 && ![urls containsObject:url]) [urls addObject:url];
    }
    return urls.copy;
}

@implementation PPProviderMarketItem

+ (instancetype)fromDictionary:(NSDictionary *)dict itemID:(NSString *)itemID {
    PPProviderMarketItem *item = [[PPProviderMarketItem alloc] init];
    item.itemID = itemID;
    item.name = PPSafeString(dict[@"name"]);
    item.nameEn = PPSafeString(dict[@"nameEn"]);
    item.desc = PPSafeString(dict[@"desc"]);
    item.descEn = PPSafeString(dict[@"descEn"]);
    item.imageURLsArray = PPMarketImageURLs(dict[@"imageURLsArray"]);
    item.price = PPSafeNumber(dict[@"price"]).doubleValue;
    item.finalPrice = PPSafeNumber(dict[@"finalPrice"]).doubleValue;
    item.quantity = PPSafeNumber(dict[@"quantity"]).integerValue;
    item.noStock = [dict[@"noStock"] boolValue];
    item.accessKindType = PPSafeNumber(dict[@"accessKindType"]).integerValue;
    item.petMainCategoryID = PPSafeNumber(dict[@"petMainCategoryID"]).integerValue;
    item.petSubCategoryID = PPSafeNumber(dict[@"petSubCategoryID"]).integerValue;
    item.petMainCategoryName = PPSafeString(dict[@"petMainCategoryName"]);
    item.hasOffer = [dict[@"hasOffer"] boolValue];
    item.ownerID = PPSafeString(dict[@"ownerID"]);
    item.ownerType = PPSafeString(dict[@"ownerType"]);
    item.showInAppMarket = [dict[@"showInAppMarket"] boolValue];
    item.isArchived = [dict[@"isArchived"] boolValue];

    id ca = dict[@"createdAt"];
    if ([ca isKindOfClass:[NSDate class]]) item.createdAt = ca;
    else if ([ca respondsToSelector:@selector(dateValue)]) item.createdAt = [ca dateValue];

    id ua = dict[@"updatedAt"];
    if ([ua isKindOfClass:[NSDate class]]) item.updatedAt = ua;
    else if ([ua respondsToSelector:@selector(dateValue)]) item.updatedAt = [ua dateValue];

    // Variant identity
    item.productFamilyId = PPSafeString(dict[@"productFamilyId"]);
    if (item.productFamilyId.length == 0) {
        item.productFamilyId = PPSafeString(dict[@"colorFamilyId"]);
    }
    item.variantSchemaVersion = PPSafeNumber(dict[@"variantSchemaVersion"]).integerValue;
    item.isVariant = [dict[@"isVariant"] boolValue];
    item.isDefaultVariant = [dict[@"isDefaultVariant"] boolValue];
    item.variantSortOrder = PPSafeNumber(dict[@"variantSortOrder"]).integerValue;

    NSDictionary *variantAttrs = [dict[@"variantAttributes"] isKindOfClass:[NSDictionary class]] ? dict[@"variantAttributes"] : nil;
    if ([variantAttrs[@"color"] isKindOfClass:[NSDictionary class]]) {
        item.variantColorDictionary = [variantAttrs[@"color"] copy];
    } else if ([dict[@"color"] isKindOfClass:[NSDictionary class]]) {
        item.variantColorDictionary = [dict[@"color"] copy];
    }

    if ([dict[@"selectedOptions"] isKindOfClass:[NSDictionary class]]) {
        item.selectedOptions = [dict[@"selectedOptions"] copy];
    }
    if ([dict[@"selectedOptionsSnapshot"] isKindOfClass:[NSArray class]]) {
        item.selectedOptionsSnapshot = [dict[@"selectedOptionsSnapshot"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id candidate, NSDictionary *bindings) {
            return [candidate isKindOfClass:NSDictionary.class];
        }]];
    }
    item.variantCombinationKey = PPSafeString(dict[@"variantCombinationKey"]);
    item.variantAxis = PPSafeString(dict[@"variantAxis"]);

    item.sku = PPSafeString(dict[@"sku"]);
    item.barcode = PPSafeString(dict[@"barcode"]);
    if (dict[@"costPrice"]) item.costPrice = PPSafeNumber(dict[@"costPrice"]);
    if (dict[@"wholesalePrice"]) item.wholesalePrice = PPSafeNumber(dict[@"wholesalePrice"]);
    if (dict[@"discountPercent"]) item.discountPercent = PPSafeNumber(dict[@"discountPercent"]);
    if (dict[@"discountAmount"]) item.discountAmount = PPSafeNumber(dict[@"discountAmount"]);
    item.revision = PPSafeNumber(dict[@"revision"]).integerValue;

    return item;
}

- (NSDictionary *)toFirestoreDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"name"] = self.name ?: @"";
    dict[@"nameEn"] = self.nameEn ?: @"";
    dict[@"desc"] = self.desc ?: @"";
    dict[@"descEn"] = self.descEn ?: @"";
    dict[@"price"] = @(self.price);
    dict[@"finalPrice"] = @(self.finalPrice > 0 ? self.finalPrice : self.price);
    dict[@"quantity"] = @(self.quantity);
    dict[@"noStock"] = @(self.noStock || self.quantity <= 0);
    dict[@"accessKindType"] = @(self.accessKindType);
    dict[@"petMainCategoryID"] = @(self.petMainCategoryID);
    dict[@"petSubCategoryID"] = @(self.petSubCategoryID);
    dict[@"petMainCategoryName"] = self.petMainCategoryName ?: @"";
    dict[@"hasOffer"] = @(self.hasOffer);
    dict[@"showInAppMarket"] = @(self.showInAppMarket);
    dict[@"isArchived"] = @(self.isArchived);

    if (self.imageURLsArray) dict[@"imageURLsArray"] = self.imageURLsArray;
    if (self.ownerID) dict[@"ownerID"] = self.ownerID;
    if (self.ownerType) dict[@"ownerType"] = self.ownerType;

    if (self.productFamilyId.length > 0) dict[@"productFamilyId"] = self.productFamilyId;
    if (self.variantSchemaVersion > 0) dict[@"variantSchemaVersion"] = @(self.variantSchemaVersion);
    dict[@"isVariant"] = @(self.isVariant);
    dict[@"isDefaultVariant"] = @(self.isDefaultVariant);
    dict[@"variantSortOrder"] = @(self.variantSortOrder);
    if (self.variantColorDictionary) {
        dict[@"variantAttributes"] = @{@"color": self.variantColorDictionary};
    }
    if (self.selectedOptions) dict[@"selectedOptions"] = self.selectedOptions;
    if (self.selectedOptionsSnapshot) dict[@"selectedOptionsSnapshot"] = self.selectedOptionsSnapshot;
    if (self.variantCombinationKey.length > 0) dict[@"variantCombinationKey"] = self.variantCombinationKey;
    if (self.variantAxis.length > 0) dict[@"variantAxis"] = self.variantAxis;

    if (self.sku.length > 0) dict[@"sku"] = self.sku;
    if (self.barcode.length > 0) dict[@"barcode"] = self.barcode;
    if (self.costPrice) dict[@"costPrice"] = self.costPrice;
    if (self.wholesalePrice) dict[@"wholesalePrice"] = self.wholesalePrice;
    if (self.discountPercent) dict[@"discountPercent"] = self.discountPercent;
    if (self.discountAmount) dict[@"discountAmount"] = self.discountAmount;
    if (self.revision > 0) dict[@"revision"] = @(self.revision);

    return [dict copy];
}

- (NSString *)kindLabel {
    if (self.accessKindType == 3) return kLang(@"ProInventory_LivePets");
    if (self.accessKindType == 4) return kLang(@"ProInventory_Medicines");
    return self.accessKindType == 2 ? kLang(@"Market_Food") : kLang(@"Market_Accessory");
}

- (NSString *)stockLabel {
    if (self.noStock || self.quantity <= 0) return kLang(@"Market_OutOfStock");
    return [NSString stringWithFormat:@"%@ %ld", kLang(@"Market_InStock"), (long)self.quantity];
}

- (NSString *)visibilityLabel {
    if (self.isArchived || !self.showInAppMarket) return kLang(@"Market_Hidden");
    return @"";
}

- (BOOL)belongsToVariantFamily {
    return self.productFamilyId.length > 0;
}

- (NSString *)pos_variantColorHex {
    if ([self.variantColorDictionary[@"hex"] isKindOfClass:[NSString class]]) {
        return self.variantColorDictionary[@"hex"];
    }
    return @"";
}

- (NSString *)pos_variantColorName {
    if (!self.variantColorDictionary) return @"";
    BOOL isAr = [Language isRTL];
    NSString *name = PPSafeString(isAr ? self.variantColorDictionary[@"nameAr"] : self.variantColorDictionary[@"nameEn"]);
    if (!name || name.length == 0) {
        name = PPSafeString(self.variantColorDictionary[@"nameAr"]);
        if (name.length == 0) name = PPSafeString(self.variantColorDictionary[@"nameEn"]);
    }
    return name ?: @"";
}

- (BOOL)pos_hasRealColor {
    if (!self.variantColorDictionary) return NO;
    NSString *hex = [self pos_variantColorHex].uppercaseString;
    NSString *nameAr = PPSafeString(self.variantColorDictionary[@"nameAr"]).lowercaseString;
    NSString *nameEn = PPSafeString(self.variantColorDictionary[@"nameEn"]).lowercaseString;
    NSString *cid = PPSafeString(self.variantColorDictionary[@"id"]).lowercaseString;

    if (cid.length == 0 || [cid isEqualToString:@"standard"] || [cid isEqualToString:@"default"] || [cid isEqualToString:@"neutral"]) {
        return NO;
    }

    NSArray *sizeWords = @[@"صغير", @"متوسط", @"كبير", @"xs", @"s", @"m", @"l", @"xl", @"2xl", @"3xl", @"small", @"medium", @"large"];
    for (NSString *w in sizeWords) {
        if ([nameAr containsString:w] || [nameEn containsString:w]) return NO;
    }

    NSArray *colorWords = @[@"أبيض", @"ابيض", @"اسود", @"أسود", @"احمر", @"أحمر", @"ازرق", @"أزرق", @"اخضر", @"أخضر", @"اصفر", @"أصفر", @"بني", @"وردي", @"برتقالي", @"بنفسجي", @"رمادي", @"كحلي", @"بيج", @"ذهبي", @"فضي", @"white", @"black", @"red", @"blue", @"green", @"yellow", @"brown", @"pink", @"orange", @"purple", @"gray", @"grey", @"navy", @"beige", @"gold", @"silver"];
    for (NSString *cw in colorWords) {
        if ([nameAr containsString:cw] || [nameEn containsString:cw] || [cid containsString:cw]) return YES;
    }

    if ([hex isEqualToString:@"#CCCCCC"] || [hex isEqualToString:@"#7F7F7F"] || [hex isEqualToString:@"#8E8E93"] || [hex isEqualToString:@"#FFFFFF"]) {
        return NO;
    }
    return hex.length > 0;
}

- (NSString *)pos_variantOptionLabel {
    BOOL isAr = [Language isRTL];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if (self.selectedOptionsSnapshot.count > 0) {
        for (NSDictionary *opt in self.selectedOptionsSnapshot) {
            if (![opt isKindOfClass:NSDictionary.class]) continue;
            NSString *val = @"";
            if ([opt[@"valueName"] isKindOfClass:[NSDictionary class]]) {
                val = isAr ? opt[@"valueName"][@"ar"] : opt[@"valueName"][@"en"];
                if (val.length == 0) val = opt[@"valueName"][@"ar"] ?: opt[@"valueName"][@"en"] ?: @"";
            } else if ([opt[@"valueName"] isKindOfClass:[NSString class]]) {
                val = opt[@"valueName"];
            }
            if (val.length == 0 && [opt[@"valueId"] isKindOfClass:[NSString class]]) {
                val = opt[@"valueId"];
            }
            if (val.length > 0) [parts addObject:val];
        }
        if (parts.count > 0) return [parts componentsJoinedByString:@" • "];
    }

    if ([self pos_hasRealColor]) {
        NSString *cn = [self pos_variantColorName];
        if (cn.length > 0) [parts addObject:cn];
    }

    if (self.selectedOptions.count > 0) {
        for (id k in self.selectedOptions) {
            id v = self.selectedOptions[k];
            if (v) [parts addObject:[NSString stringWithFormat:@"%@", v]];
        }
        if (parts.count > 0) return [parts componentsJoinedByString:@" • "];
    }

    if (self.variantCombinationKey.length > 0) {
        NSArray *combParts = [self.variantCombinationKey componentsSeparatedByString:@"|"];
        for (NSString *cp in combParts) {
            NSArray *kv = [cp componentsSeparatedByString:@"="];
            if (kv.count == 2) [parts addObject:kv[1]];
        }
        if (parts.count > 0) return [parts componentsJoinedByString:@" • "];
    }

    if (parts.count > 0) return [parts componentsJoinedByString:@" • "];
    if (self.isDefaultVariant) return isAr ? @"الافتراضي" : @"Default";
    return @"";
}

- (NSString *)variantOptionLabel {
    return [self pos_variantOptionLabel];
}

- (PetAccessory *)asPetAccessory {
    PetAccessory *acc = [[PetAccessory alloc] init];
    acc.accessoryID = self.itemID ?: @"";
    acc.name = self.name ?: @"";
    acc.nameEn = self.nameEn;
    acc.desc = self.desc ?: @"";
    acc.descEn = self.descEn;
    acc.imageURLsArray = PPMarketImageURLs(self.imageURLsArray);
    acc.price = @(self.price);
    acc.quantity = self.quantity;
    acc.noStock = self.noStock || self.quantity <= 0;
    acc.accessKindType = (AccessKindType)self.accessKindType;
    acc.petMainCategoryID = self.petMainCategoryID;
    acc.petSubCategoryID = self.petSubCategoryID;
    acc.hasOffer = self.hasOffer;
    acc.ownerID = self.ownerID ?: @"";
    acc.ownerType = self.ownerType;
    acc.showInAppMarket = self.showInAppMarket;
    acc.isArchived = self.isArchived;
    acc.createdAt = self.createdAt;

    acc.productFamilyId = self.productFamilyId;
    acc.variantSchemaVersion = self.variantSchemaVersion;
    acc.isVariant = self.isVariant;
    acc.isDefaultVariant = self.isDefaultVariant;
    acc.variantSortOrder = self.variantSortOrder;
    acc.variantColorDictionary = self.variantColorDictionary;
    acc.selectedOptions = self.selectedOptions;
    acc.selectedOptionsSnapshot = self.selectedOptionsSnapshot;
    acc.variantCombinationKey = self.variantCombinationKey;
    acc.variantAxis = self.variantAxis;

    acc.sku = self.sku;
    acc.barcode = self.barcode;
    acc.costPrice = self.costPrice;
    acc.wholesalePrice = self.wholesalePrice;
    acc.discountPercent = self.discountPercent;
    acc.discountAmount = self.discountAmount;
    acc.revision = self.revision;

    [acc normalizeInventoryState];
    return acc;
}

+ (instancetype)fromPetAccessory:(PetAccessory *)accessory {
    if (!accessory) return nil;
    PPProviderMarketItem *item = [[PPProviderMarketItem alloc] init];
    item.itemID = accessory.accessoryID ?: @"";
    item.name = accessory.name ?: @"";
    item.nameEn = accessory.nameEn;
    item.desc = accessory.desc ?: @"";
    item.descEn = accessory.descEn;
    item.imageURLsArray = accessory.imageURLsArray ?: @[];
    item.price = accessory.price.doubleValue;
    item.finalPrice = accessory.finalPrice.doubleValue;
    item.quantity = accessory.quantity;
    item.noStock = accessory.noStock;
    item.accessKindType = accessory.accessKindType;
    item.petMainCategoryID = accessory.petMainCategoryID;
    item.petSubCategoryID = accessory.petSubCategoryID;
    item.petMainCategoryName = accessory.petMainCategoryIDs.firstObject ? @"" : @"";
    item.hasOffer = accessory.hasOffer;
    item.ownerID = accessory.ownerID ?: @"";
    item.ownerType = accessory.ownerType;
    item.showInAppMarket = accessory.showInAppMarket;
    item.isArchived = accessory.isArchived;
    item.createdAt = accessory.createdAt;

    item.productFamilyId = accessory.productFamilyId;
    item.variantSchemaVersion = accessory.variantSchemaVersion;
    item.isVariant = accessory.isVariant;
    item.isDefaultVariant = accessory.isDefaultVariant;
    item.variantSortOrder = accessory.variantSortOrder;
    item.variantColorDictionary = accessory.variantColorDictionary;
    item.selectedOptions = accessory.selectedOptions;
    item.selectedOptionsSnapshot = accessory.selectedOptionsSnapshot;
    item.variantCombinationKey = accessory.variantCombinationKey;
    item.variantAxis = accessory.variantAxis;

    item.sku = accessory.sku;
    item.barcode = accessory.barcode;
    item.costPrice = accessory.costPrice;
    item.wholesalePrice = accessory.wholesalePrice;
    item.discountPercent = accessory.discountPercent;
    item.discountAmount = accessory.discountAmount;
    item.revision = accessory.revision;

    return item;
}

@end

