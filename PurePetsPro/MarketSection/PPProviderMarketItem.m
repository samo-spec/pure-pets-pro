#import "PPProviderMarketItem.h"

@implementation PPProviderMarketItem

+ (instancetype)fromDictionary:(NSDictionary *)dict itemID:(NSString *)itemID {
    PPProviderMarketItem *item = [[PPProviderMarketItem alloc] init];
    item.itemID = itemID;
    item.name = PPSafeString(dict[@"name"]);
    item.nameEn = PPSafeString(dict[@"nameEn"]);
    item.desc = PPSafeString(dict[@"desc"]);
    item.descEn = PPSafeString(dict[@"descEn"]);
    item.imageURLsArray = PPSafeArray(dict[@"imageURLsArray"]);
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

    return item;
}

- (NSString *)kindLabel {
    return self.accessKindType == 2 ? kLang(@"Market_Food") : kLang(@"Market_Accessory");
}

- (NSString *)stockLabel {
    if (self.noStock) return kLang(@"Market_OutOfStock");
    return [NSString stringWithFormat:@"%@ %ld", kLang(@"Market_InStock"), (long)self.quantity];
}

- (NSString *)visibilityLabel {
    if (self.isArchived || !self.showInAppMarket) return kLang(@"Market_Hidden");
    return @"";
}

@end
