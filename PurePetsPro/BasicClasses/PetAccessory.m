#import "PetAccessory.h"
#import "ArabicNormalizer.h"
#import "MainKindsArrayManager.h"
#import "PPFirebaseCompat.h"
#import "Language.h"
#import <math.h>

@interface PetImageItem (PPAccessoryMetadata)
+ (nullable instancetype)itemWithMediaMetadata:(NSDictionary *)metadata;
@end

@implementation PetImageItem (PPAccessoryMetadata)
+ (nullable instancetype)itemWithMediaMetadata:(NSDictionary *)metadata {
    if (![metadata isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *url = metadata[@"url"];
    if (![url isKindOfClass:NSString.class] || url.length == 0) {
        url = metadata[@"thumbnail_url"];
    }
    if (![url isKindOfClass:NSString.class] || url.length == 0) {
        return nil;
    }
    id widthValue = metadata[@"width"];
    id heightValue = metadata[@"height"];
    CGFloat width = [widthValue respondsToSelector:@selector(doubleValue)] ? [widthValue doubleValue] : 0.0;
    CGFloat height = [heightValue respondsToSelector:@selector(doubleValue)] ? [heightValue doubleValue] : 0.0;
    NSString *blurHash = [metadata[@"blurHash"] isKindOfClass:NSString.class] ? metadata[@"blurHash"] : nil;
    return [[PetImageItem alloc] initWithURL:url width:width height:height blurHash:blurHash];
}
@end

#ifdef DEBUG
BOOL const isPPDebugMode = YES;
#else
BOOL const isPPDebugMode = NO;
#endif

@interface PetAccessory ()
@property (nonatomic, copy) NSString *searchTitle;
@property (nonatomic, assign, readwrite) BOOL hasResolvedSellingPrice;
+ (UIViewController *)pp_topViewController;
+ (UIViewController *)pp_topViewControllerFromRoot:(UIViewController *)rootViewController;
@end

static NSDate *PPDateFromFirestoreValue(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) {
        return [NSDate distantPast];
    }
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        NSTimeInterval t = [(NSNumber *)value doubleValue];
        if (t > 10000000000.0) t /= 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:t];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSTimeInterval t = [(NSString *)value doubleValue];
        if (t > 0) {
            if (t > 10000000000.0) t /= 1000.0;
            return [NSDate dateWithTimeIntervalSince1970:t];
        }
    }
    return [NSDate distantPast];
}

static NSDate * _Nullable PPNullableDateFromFirestoreValue(id value) {
    if (!value || [value isKindOfClass:NSNull.class]) return nil;
    if ([value isKindOfClass:NSDate.class]) return (NSDate *)value;
    if ([value isKindOfClass:FIRTimestamp.class]) return [(FIRTimestamp *)value dateValue];
    return nil;
}

static NSString *PPAccessoryTrimmedString(id value) {
    if ([value isKindOfClass:[NSNull class]] || value == nil) {
        return @"";
    }
    NSString *string = nil;
    if ([value isKindOfClass:[NSString class]]) {
        string = (NSString *)value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        string = [(NSNumber *)value stringValue];
    }
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static NSString *PPAccessoryStringValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSString *value = PPAccessoryTrimmedString(dict[key]);
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

static NSNumber *PPAccessoryNumberValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
    });

    for (NSString *key in keys) {
        id value = dict[key];
        if ([value isKindOfClass:[NSNumber class]] && isfinite([value doubleValue])) {
            return value;
        }
        NSString *string = PPAccessoryTrimmedString(value);
        if (string.length > 0) {
            NSNumber *number = [formatter numberFromString:string];
            if (number && isfinite(number.doubleValue)) {
                return number;
            }
        }
    }
    return nil;
}

static NSInteger PPAccessoryInteger(id value) {
    NSNumber *number = PPAccessoryNumberValueForKeys(@{@"value": value ?: NSNull.null}, @[@"value"]);
    double candidate = number.doubleValue;
    if (!number || fabs(candidate) > 9007199254740991.0 || trunc(candidate) != candidate) return 0;
    return number.integerValue;
}

static BOOL PPAccessoryBool(id value) {
    if ([value isKindOfClass:NSNumber.class]) return isfinite([value doubleValue]) && [value boolValue];
    if ([value isKindOfClass:NSString.class]) return [value boolValue];
    return NO;
}

static NSArray<NSNumber *> *PPAccessoryIntegerArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableOrderedSet<NSNumber *> *numbers = [NSMutableOrderedSet orderedSet];
    for (id candidate in value) {
        NSNumber *number = PPAccessoryNumberValueForKeys(@{@"value": candidate}, @[@"value"]);
        if (number && number.doubleValue >= 0 && number.doubleValue <= 9007199254740991.0 && trunc(number.doubleValue) == number.doubleValue) {
            [numbers addObject:@(number.integerValue)];
        }
    }
    return numbers.array;
}

static NSNumber * _Nullable PPAccessorySellingPriceValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        NSNumber *candidate = PPAccessoryNumberValueForKeys(dict, @[key]);
        if (!candidate) continue;
        double value = candidate.doubleValue;
        if (isfinite(value) && value >= 0.0) {
            return candidate;
        }
    }
    return nil;
}

static NSArray<NSString *> *PPAccessoryStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (id candidate in (NSArray *)value) {
        NSString *string = PPAccessoryTrimmedString(candidate);
        if (string.length > 0) [strings addObject:string];
    }
    return [strings copy];
}

static NSArray<NSDictionary *> *PPAccessoryDictionaryArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSDictionary *> *dictionaries = [NSMutableArray array];
    for (id candidate in (NSArray *)value) {
        if ([candidate isKindOfClass:NSDictionary.class]) {
            [dictionaries addObject:candidate];
        }
    }
    return [dictionaries copy];
}

static NSArray<NSDictionary *> *PPNormalizedImageMeta(NSArray<NSString *> *urls, NSArray<NSDictionary *> *meta) {
    NSMutableArray<NSDictionary *> *normalized = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSInteger i = 0; i < urls.count; i++) {
        NSString *url = [urls[i] isKindOfClass:NSString.class] ? urls[i] : @"";
        NSDictionary *m = (i < meta.count && [meta[i] isKindOfClass:NSDictionary.class]) ? meta[i] : nil;
        id widthValue = m[@"width"];
        id heightValue = m[@"height"];
        CGFloat width = [widthValue respondsToSelector:@selector(doubleValue)] ? [widthValue doubleValue] : 0.0;
        CGFloat height = [heightValue respondsToSelector:@selector(doubleValue)] ? [heightValue doubleValue] : 0.0;
        [normalized addObject:@{
            @"url": url,
            @"width": @(MAX(0.0, width)),
            @"height": @(MAX(0.0, height))
        }];
    }
    return [normalized copy];
}

static NSArray<NSDictionary *> *PPImageItemsPayload(NSArray<NSString *> *urls, NSArray<NSDictionary *> *meta, NSString *blurHash) {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:urls.count];
    for (NSInteger i = 0; i < urls.count; i++) {
        NSString *url = [urls[i] isKindOfClass:NSString.class] ? urls[i] : @"";
        NSDictionary *m = (i < meta.count && [meta[i] isKindOfClass:NSDictionary.class]) ? meta[i] : nil;
        id widthValue = m[@"width"];
        id heightValue = m[@"height"];
        CGFloat width = [widthValue respondsToSelector:@selector(doubleValue)] ? [widthValue doubleValue] : 0.0;
        CGFloat height = [heightValue respondsToSelector:@selector(doubleValue)] ? [heightValue doubleValue] : 0.0;
        NSMutableDictionary *item = [@{
            @"url": url,
            @"width": @(MAX(0.0, width)),
            @"height": @(MAX(0.0, height))
        } mutableCopy];
        if (blurHash.length > 0) {
            item[@"blurHash"] = blurHash;
        }
        [items addObject:[item copy]];
    }
    return [items copy];
}

@implementation PetAccessory

@synthesize price = _price;
@synthesize hasResolvedSellingPrice = _hasResolvedSellingPrice;

- (instancetype)init {
    if (self = [super init]) {
        _name = @"";
        _nameEn = @"";
        _sku = @"";
        _barcode = @"";
        _costPrice = nil;
        _desc = @"";
        _descEn = @"";
        _price = @(0);
        _hasResolvedSellingPrice = NO;
        _ownerID = @"";
        _storeID = @"";
        _storeName = @"";
        _branchID = @"";
        _branchCode = @"";
        _imageURLsArray = @[];
        _relatedAccessories = @[];
        _createdAt = [NSDate date];
        _accessKindType = AccessTypeAccessory;
        _condition = AccessConditionsNew;
        _active = YES;
        _quantity = 0;
        _noStock = YES;
        _revision = 0;
        _searchTitle = @"";
        _productFamilyId = nil;
        _variantSchemaVersion = 0;
        _isVariant = NO;
        _isDefaultVariant = NO;
        _variantSortOrder = 0;
    }
    return self;
}

- (void)setPrice:(NSNumber *)price {
    id candidate = price;
    if ([candidate isKindOfClass:NSNumber.class]) {
        double value = [(NSNumber *)candidate doubleValue];
        if (isfinite(value) && value >= 0.0) {
            _price = [(NSNumber *)candidate copy];
            _hasResolvedSellingPrice = YES;
            return;
        }
    }
    _price = @(0);
    _hasResolvedSellingPrice = NO;
}

- (NSDictionary *)toFirestoreDictionary {
    [self normalizeInventoryState];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // Basic info
    if (self.name) dict[@"name"] = self.name;
    dict[@"searchTitle"] = [ArabicNormalizer normalize:self.name ?: @""];
    if (self.nameEn.length > 0) {
        dict[@"nameEn"] = self.nameEn;
        dict[@"name_en"] = self.nameEn;
    } else {
        dict[@"nameEn"] = [NSNull null];
        dict[@"name_en"] = [NSNull null];
    }
    dict[@"sku"] = (self.sku.length > 0) ? self.sku : [NSNull null];
    dict[@"barcode"] = (self.barcode.length > 0) ? self.barcode : [NSNull null];
    dict[@"costPrice"] = self.costPrice ?: [NSNull null];
    if (self.desc) dict[@"desc"] = self.desc;
    if (self.descEn.length > 0) {
        dict[@"descEn"] = self.descEn;
        dict[@"desc_en"] = self.descEn;
    } else {
        dict[@"descEn"] = [NSNull null];
        dict[@"desc_en"] = [NSNull null];
    }
    if (self.hasResolvedSellingPrice) dict[@"price"] = self.price;

    dict[@"discountPercent"] = self.discountPercent ?: [NSNull null];
    dict[@"discountAmount"] = self.discountAmount ?: [NSNull null];
    if (self.weightText.length > 0) {
        dict[@"weightText"] = self.weightText;
    } else {
        dict[@"weightText"] = [NSNull null];
    }
    if (self.weight) {
        dict[@"weight"] = self.weight;
    } else {
        dict[@"weight"] = [NSNull null];
    }
    if (self.weightUnit.length > 0) {
        dict[@"weightUnit"] = self.weightUnit;
    } else {
        dict[@"weightUnit"] = [NSNull null];
    }
    if (self.size.length > 0) {
        dict[@"size"] = self.size;
    } else {
        dict[@"size"] = [NSNull null];
    }
    if (self.dimensionWidth) {
        dict[@"dimensionWidth"] = self.dimensionWidth;
    } else {
        dict[@"dimensionWidth"] = [NSNull null];
    }
    if (self.dimensionHeight) {
        dict[@"dimensionHeight"] = self.dimensionHeight;
    } else {
        dict[@"dimensionHeight"] = [NSNull null];
    }
    if (self.dimensionUnit.length > 0) {
        dict[@"dimensionUnit"] = self.dimensionUnit;
    } else {
        dict[@"dimensionUnit"] = [NSNull null];
    }

    // Images
    if (self.imageURLsArray) dict[@"imageURLsArray"] = self.imageURLsArray;
    NSArray<NSDictionary *> *normalizedMeta = PPNormalizedImageMeta(self.imageURLsArray ?: @[], self.imageMeta ?: @[]);
    if (normalizedMeta.count > 0) {
        dict[@"imageMeta"] = normalizedMeta;
        dict[@"imageItems"] = PPImageItemsPayload(self.imageURLsArray ?: @[], normalizedMeta, self.blurHash ?: @"");
    } else {
        dict[@"imageMeta"] = self.imageMeta ?: @[];
        dict[@"imageItems"] = @[];
    }
    dict[@"blurHash"] = self.blurHash ?: @"";

    // Categories
    dict[@"petMainCategoryID"] = @(self.petMainCategoryID);
    dict[@"petSubCategoryID"] = @(self.petSubCategoryID);
    if (self.petMainCategoryIDs.count > 0) {
        dict[@"petMainCategoryIDs"] = self.petMainCategoryIDs;
    } else if (self.petMainCategoryID > 0) {
        dict[@"petMainCategoryIDs"] = @[@(self.petMainCategoryID)];
    }
    if (self.petSubCategoryIDs.count > 0) {
        dict[@"petSubCategoryIDs"] = self.petSubCategoryIDs;
    } else if (self.petSubCategoryID > 0) {
        dict[@"petSubCategoryIDs"] = @[@(self.petSubCategoryID)];
    }
    dict[@"isAllCategories"] = @(self.isAllCategories);
    dict[@"isAllSubCategories"] = @(self.isAllSubCategories);
    if (self.AccessoryCategoryID.length > 0) {
        dict[@"AccessoryCategoryID"] = self.AccessoryCategoryID;
    }
    if (self.relatedAccessories) dict[@"relatedAccessories"] = self.relatedAccessories;
    dict[@"cityID"] = @(self.cityID);

    // Metadata
    if (self.ownerID) dict[@"ownerID"] = self.ownerID;
    if (self.ownerType) dict[@"ownerType"] = self.ownerType;
    if (self.source) dict[@"source"] = self.source;
    if (self.branchID.length > 0) dict[@"branchID"] = self.branchID;
    if (self.branchCode.length > 0) dict[@"branchCode"] = self.branchCode;
    if (self.storeID.length > 0) dict[@"storeID"] = self.storeID;
    if (self.storeName.length > 0) dict[@"storeName"] = self.storeName;
    if (self.inventoryMode.length > 0) dict[@"inventoryMode"] = self.inventoryMode;
    if (self.inventoryTrackingPolicy.length > 0) dict[@"inventoryTrackingPolicy"] = self.inventoryTrackingPolicy;
    if (self.shelfLifeDays) dict[@"shelfLifeDays"] = self.shelfLifeDays;
    if (self.guaranteedShelfLifeDays) dict[@"guaranteedShelfLifeDays"] = self.guaranteedShelfLifeDays;
    if (self.expiryCutoffDays) dict[@"expiryCutoffDays"] = self.expiryCutoffDays;
    if (self.standardSellingPrice) dict[@"standardSellingPrice"] = self.standardSellingPrice;
    dict[@"inventorySchemaVersion"] = @(self.inventorySchemaVersion);
    dict[@"accessKindType"] = @(self.accessKindType);
    dict[@"condition"] = @(self.condition);
    dict[@"quantity"] = @(self.quantity);
    dict[@"reservedQuantity"] = @(self.reservedQuantity);
    dict[@"noStock"] = @(self.noStock);
    dict[@"active"] = @(self.active);
    dict[@"isArchived"] = @(self.isArchived);
    dict[@"isNew"] = @(self.isNew);
    dict[@"hasOffer"] = @(self.hasOffer);
    dict[@"showInAppMarket"] = @(self.showInAppMarket);
    dict[@"isBlocked"] = @(self.isBlocked);
    dict[@"isDeleted"] = @(self.isDeleted);
    dict[@"isDisabled"] = @(self.isDisabled);

    if (self.expiryDate) {
        dict[@"expiryDate"] = [FIRTimestamp timestampWithDate:self.expiryDate];
    } else {
        dict[@"expiryDate"] = [NSNull null];
    }

    if (self.hasCommerceConfig) {
        dict[@"hasCommerceConfig"] = @(self.hasCommerceConfig);
    }

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
    if (self.wholesalePrice) dict[@"wholesalePrice"] = self.wholesalePrice;

    dict[@"updatedAt"] = [FIRTimestamp timestampWithDate:[NSDate date]];

    return [dict copy];
}

- (NSNumber *)calculateFinalPrice {
    if (!self.hasResolvedSellingPrice || ![self.price isKindOfClass:NSNumber.class]) return @(0);

    double basePrice = [self.price doubleValue];
    if (!isfinite(basePrice) || basePrice < 0.0) return @(0);
    double finalPrice = basePrice;

    double discountPercent = [self.discountPercent isKindOfClass:NSNumber.class]
        ? self.discountPercent.doubleValue
        : 0.0;
    if (isfinite(discountPercent) && discountPercent > 0.0) {
        double discount = (basePrice * discountPercent) / 100.0;
        finalPrice = basePrice - discount;
    }

    double discountAmount = [self.discountAmount isKindOfClass:NSNumber.class]
        ? self.discountAmount.doubleValue
        : 0.0;
    if (isfinite(discountAmount) && discountAmount > 0.0) {
        finalPrice = finalPrice - discountAmount;
    }
    
    if (finalPrice < 0) finalPrice = 0;
    return @(finalPrice);
}

- (BOOL)belongsToVariantFamily {
    return self.productFamilyId.length > 0 || self.isVariant;
}

- (NSString *)catalogCategoryIdentifier {
    return self.AccessoryCategoryID;
}

- (NSString *)stockStatusText {
    NSInteger qty = [self normalizedQuantity];
    if (qty <= 0) {
        return kLang(@"Out of stock");
    } else if (qty <= 5) {
        return [NSString stringWithFormat:@"%@ %ld %@", kLang(@"Only"), (long)qty, kLang(@"leftInStock")];
    } else {
        return kLang(@"inStock");
    }
}

- (NSInteger)normalizedQuantity {
    return MAX(0, self.quantity);
}

- (void)normalizeInventoryState {
    self.quantity = [self normalizedQuantity];
    self.noStock = (self.quantity <= 0);

    if (self.accessKindType != AccessTypeAccessory &&
        self.accessKindType != AccessTypeFood &&
        self.accessKindType != AccessTypeLivePets &&
        self.accessKindType != AccessTypePetMedicine) {
        self.accessKindType = AccessTypeAccessory;
    }
    if (self.accessKindType == AccessTypeFood) {
        self.condition = AccessConditionsNew;
    } else if (self.condition != AccessConditionsNew && self.condition != AccessConditionsUsed) {
        self.condition = AccessConditionsNew;
    }
}

- (NSArray<PetImageItem *> *)imageItems {
    if (self.imageURLsArray.count == 0) return @[];
    NSMutableArray<PetImageItem *> *items = [NSMutableArray arrayWithCapacity:self.imageURLsArray.count];
    for (NSInteger i = 0; i < self.imageURLsArray.count; i++) {
        NSString *url = self.imageURLsArray[i];
        if (![url isKindOfClass:NSString.class] || url.length == 0) continue;
        NSDictionary *meta = (i < self.imageMeta.count && [self.imageMeta[i] isKindOfClass:NSDictionary.class]) ? self.imageMeta[i] : nil;
        CGFloat width = [meta[@"width"] floatValue];
        CGFloat height = [meta[@"height"] floatValue];
        [items addObject:[[PetImageItem alloc] initWithURL:url width:width height:height blurHash:self.blurHash]];
    }
    return [items copy];
}

- (NSNumber *)finalPrice {
    return [self calculateFinalPrice];
}

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)docID {
    if (self = [super init]) {
        dict = [dict isKindOfClass:NSDictionary.class] ? dict : @{};
        _accessoryID = [docID isKindOfClass:NSString.class] ? docID : @"";
        _name = PPAccessoryStringValueForKeys(dict, (@[@"name", @"title"]));
        _nameEn = PPAccessoryStringValueForKeys(dict, (@[@"nameEn", @"name_en", @"titleEn", @"title_en"]));
        _revision = MAX(0, PPAccessoryInteger(dict[@"revision"]));
        _sku = PPAccessoryStringValueForKeys(dict, (@[@"sku", @"SKU", @"itemSku"]));
        _barcode = PPAccessoryStringValueForKeys(dict, (@[@"barcode", @"barCode", @"bar_code", @"itemBarcode"]));

        NSArray<NSString *> *costKeys = @[
            @"costPrice", @"cost_price", @"cost",
            @"buyPrice", @"buy_price",
            @"purchasePrice", @"purchase_price",
            @"initialCostPrice", @"initial_cost_price",
            @"unitCost", @"unit_cost"
        ];
        NSNumber *foundCost = PPAccessoryNumberValueForKeys(dict, costKeys);
        if (!foundCost) {
            NSDictionary *pricingDict = [dict[@"pricing"] isKindOfClass:NSDictionary.class] ? dict[@"pricing"] : nil;
            if (pricingDict) {
                foundCost = PPAccessoryNumberValueForKeys(pricingDict, @[@"costPrice", @"costPerBaseUnit", @"myCost", @"totalCost", @"cost"]);
            }
        }
        _costPrice = foundCost;
        _desc = PPAccessoryStringValueForKeys(dict, (@[@"desc", @"description"]));
        _descEn = PPAccessoryStringValueForKeys(dict, (@[@"descEn", @"descriptionEn", @"desc_en", @"description_en"]));

        NSNumber *basePrice = PPAccessorySellingPriceValueForKeys(dict, (@[@"price", @"sellPrice"]));
        NSNumber *projectedPrice = PPAccessorySellingPriceValueForKeys(dict, (@[@"finalPrice", @"availableUnitPriceMin"]));
        NSNumber *resolvedPrice = basePrice;
        if (!resolvedPrice || (resolvedPrice.doubleValue <= 0.0 && projectedPrice.doubleValue > 0.0)) {
            resolvedPrice = projectedPrice ?: resolvedPrice;
        }
        [self setPrice:resolvedPrice];
        _discountPercent = PPAccessoryNumberValueForKeys(dict, (@[@"discountPercent"]));
        _discountAmount = PPAccessoryNumberValueForKeys(dict, (@[@"discountAmount"]));
        NSNumber *rawWholesale = PPAccessoryNumberValueForKeys(dict, (@[@"wholesalePrice"]));
        if (rawWholesale != nil && isfinite([rawWholesale doubleValue]) && [rawWholesale doubleValue] > 0.0) {
            _wholesalePrice = rawWholesale;
        } else {
            NSNumber *minorWholesale = PPAccessoryNumberValueForKeys(dict, (@[@"wholesalePriceMinor"]));
            if (minorWholesale != nil && isfinite([minorWholesale doubleValue]) && [minorWholesale doubleValue] > 0.0) {
                _wholesalePrice = @([minorWholesale doubleValue] / 100.0);
            } else {
                _wholesalePrice = nil;
            }
        }
        _hasCommerceConfig = PPAccessoryBool(dict[@"hasCommerceConfig"]);
        _quantityGroups = PPAccessoryDictionaryArray(dict[@"quantityGroups"]);
        _weightText = PPAccessoryStringValueForKeys(dict, (@[@"weightText", @"weightLabel", @"packageWeightText", @"netWeightText", @"itemWeightText"]));
        _weight = PPAccessoryNumberValueForKeys(dict, (@[@"weight", @"packageWeight", @"netWeight", @"itemWeight", @"unitWeight"]));
        _weightUnit = PPAccessoryStringValueForKeys(dict, (@[@"weightUnit", @"unit", @"packageUnit", @"measurementUnit", @"weight_unit"]));
        _size = PPAccessoryStringValueForKeys(dict, (@[@"size", @"itemSize", @"accessorySize"]));
        _dimensionWidth = PPAccessoryNumberValueForKeys(dict, (@[@"dimensionWidth", @"dimensionsWidth", @"width"]));
        _dimensionHeight = PPAccessoryNumberValueForKeys(dict, (@[@"dimensionHeight", @"dimensionsHeight", @"height"]));
        _dimensionUnit = PPAccessoryStringValueForKeys(dict, (@[@"dimensionUnit", @"dimensionsUnit", @"sizeUnit"]));

        _imageURLsArray = PPAccessoryStringArray(dict[@"imageURLsArray"]);
        _imageMeta = PPAccessoryDictionaryArray(dict[@"imageMeta"]);
        NSArray *imageItemsPayload = PPAccessoryDictionaryArray(dict[@"imageItems"]);
        if (_imageURLsArray.count == 0 && imageItemsPayload.count > 0) {
            NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:imageItemsPayload.count];
            for (NSDictionary *item in imageItemsPayload) {
                if (![item isKindOfClass:NSDictionary.class]) continue;
                NSString *url = [item[@"url"] isKindOfClass:NSString.class] ? item[@"url"] : @"";
                if (url.length > 0) [urls addObject:url];
            }
            _imageURLsArray = [urls copy];
        }

        _petMainCategoryID = PPAccessoryInteger(dict[@"petMainCategoryID"]);
        _petSubCategoryID = PPAccessoryInteger(dict[@"petSubCategoryID"]);
        _petMainCategoryIDs = PPAccessoryIntegerArray(dict[@"petMainCategoryIDs"]);
        _petSubCategoryIDs = PPAccessoryIntegerArray(dict[@"petSubCategoryIDs"]);
        _isAllCategories = PPAccessoryBool(dict[@"isAllCategories"]);
        _isAllSubCategories = PPAccessoryBool(dict[@"isAllSubCategories"]);

        if (_petMainCategoryIDs.count == 0 && _petMainCategoryID > 0) {
            _petMainCategoryIDs = @[@(_petMainCategoryID)];
        } else if (_petMainCategoryID <= 0 && _petMainCategoryIDs.count > 0) {
            _petMainCategoryID = [_petMainCategoryIDs.firstObject integerValue];
        }
        if (_petSubCategoryIDs.count == 0 && _petSubCategoryID > 0) {
            _petSubCategoryIDs = @[@(_petSubCategoryID)];
        } else if (_petSubCategoryID <= 0 && _petSubCategoryIDs.count > 0) {
            _petSubCategoryID = [_petSubCategoryIDs.firstObject integerValue];
        }
        _AccessoryCategoryID = PPAccessoryStringValueForKeys(dict, (@[@"AccessoryCategoryID", @"accessoryCategoryID", @"accessoryCategory", @"AccessoryCategory"]));
        _relatedAccessories = PPAccessoryStringArray(dict[@"relatedAccessories"]);
        _cityID = PPAccessoryInteger(dict[@"cityID"]);
        
        id rawCreated = dict[@"createdAt"] ?: dict[@"created_at"] ?: dict[@"timestamp"] ?: dict[@"date"] ?: dict[@"updatedAt"];
        _createdAt = PPDateFromFirestoreValue(rawCreated);
        _expiryDate = PPNullableDateFromFirestoreValue(dict[@"expiryDate"]);

        _ownerID = PPAccessoryStringValueForKeys(dict, (@[@"ownerID"]));
        _branchID = PPAccessoryStringValueForKeys(dict, (@[@"branchID", @"branchId", @"branch_id"]));
        _branchCode = PPAccessoryStringValueForKeys(dict, (@[@"branchCode", @"branch_code"]));
        _storeID = PPAccessoryStringValueForKeys(dict, (@[@"storeID", @"storeId"]));
        _storeName = PPAccessoryStringValueForKeys(dict, (@[@"storeName", @"branchName"]));

        if (_branchID.length == 0 && _storeID.length > 0 && ![_storeID isEqualToString:@"main_store"]) {
            _branchID = _storeID;
        }
        if (_storeID.length == 0 && _branchID.length > 0) {
            _storeID = _branchID;
        }
        _ownerType = [dict[@"ownerType"] isKindOfClass:NSString.class] ? dict[@"ownerType"] : nil;
        _source = [dict[@"source"] isKindOfClass:NSString.class] ? dict[@"source"] : nil;
        _inventoryMode = [dict[@"inventoryMode"] isKindOfClass:NSString.class]
            ? [dict[@"inventoryMode"] uppercaseString]
            : nil;
        _inventoryTrackingPolicy = [dict[@"inventoryTrackingPolicy"] isKindOfClass:NSString.class]
            ? [dict[@"inventoryTrackingPolicy"] lowercaseString]
            : nil;
        _shelfLifeDays = PPAccessoryNumberValueForKeys(dict, (@[@"shelfLifeDays", @"shelf_life_days"]));
        _guaranteedShelfLifeDays = PPAccessoryNumberValueForKeys(dict, (@[@"guaranteedShelfLifeDays", @"guaranteed_shelf_life_days"]));
        _expiryCutoffDays = PPAccessoryNumberValueForKeys(dict, (@[@"expiryCutoffDays", @"expiry_cutoff_days"]));
        _inventorySchemaVersion = PPAccessoryInteger(dict[@"inventorySchemaVersion"]);
        _standardSellingPrice = PPAccessorySellingPriceValueForKeys(dict, (@[@"standardSellingPrice"]));
        _reservedQuantity = MAX(0, PPAccessoryInteger(dict[@"reservedQuantity"]));
        _isArchived = PPAccessoryBool(dict[@"isArchived"]);
        _blurHash = PPAccessoryTrimmedString(dict[@"blurHash"]);

        // Colour-variant identity. Server-owned: parsed for display and editing
        _productFamilyId = PPAccessoryStringValueForKeys(dict, (@[@"productFamilyId"]));
        _variantSchemaVersion = PPAccessoryInteger(dict[@"variantSchemaVersion"]);
        _isVariant = PPAccessoryBool(dict[@"isVariant"]);
        _isDefaultVariant = PPAccessoryBool(dict[@"isDefaultVariant"]);
        _variantSortOrder = MAX(0, PPAccessoryInteger(dict[@"variantSortOrder"]));
        _variantColorDictionary = ({
            NSDictionary *attributes = [dict[@"variantAttributes"] isKindOfClass:NSDictionary.class]
                ? dict[@"variantAttributes"]
                : nil;
            NSDictionary *color = [attributes[@"color"] isKindOfClass:NSDictionary.class]
                ? attributes[@"color"]
                : nil;
            color ? [color copy] : nil;
        });
        _selectedOptions = [dict[@"selectedOptions"] isKindOfClass:NSDictionary.class]
            ? [dict[@"selectedOptions"] copy]
            : nil;
        _selectedOptionsSnapshot = [dict[@"selectedOptionsSnapshot"] isKindOfClass:NSArray.class]
            ? [dict[@"selectedOptionsSnapshot"] copy]
            : nil;
        _variantCombinationKey = PPAccessoryStringValueForKeys(dict, (@[@"variantCombinationKey"]));
        _variantAxis = PPAccessoryStringValueForKeys(dict, (@[@"variantAxis"]));
        
        _accessKindType = ({
            NSInteger rawKind = PPAccessoryInteger(dict[@"accessKindType"]);
            if (rawKind == 0 && dict[@"type"] != nil) {
                rawKind = PPAccessoryInteger(dict[@"type"]);
            }
            AccessKindType parsed;
            switch (rawKind) {
                case AccessTypeFood:        parsed = AccessTypeFood;        break;
                case AccessTypeLivePet:     parsed = AccessTypeLivePet;     break;
                case AccessTypePetMedicine: parsed = AccessTypePetMedicine; break;
                default:                    parsed = AccessTypeAccessory;   break;
            }
            parsed;
        });

        _condition = PPAccessoryInteger(dict[@"condition"]) == AccessConditionsUsed
            ? AccessConditionsUsed
            : AccessConditionsNew;
        _quantity = PPAccessoryInteger(dict[@"quantity"]);
        _noStock = PPAccessoryBool(dict[@"noStock"]);
        _active = dict[@"active"] != nil ? PPAccessoryBool(dict[@"active"]) : YES;
        _isNew = PPAccessoryBool(dict[@"isNew"]);
        _hasOffer = PPAccessoryBool(dict[@"hasOffer"]);
        _showInAppMarket = PPAccessoryBool(dict[@"showInAppMarket"]);
        _isBlocked = PPAccessoryBool(dict[@"isBlocked"]);
        _isDeleted = PPAccessoryBool(dict[@"isDeleted"]);
        _isDisabled = PPAccessoryBool(dict[@"isDisabled"]);

        [self normalizeInventoryState];
    }
    return self;
}

+ (instancetype)deepCopyFrom:(PetAccessory *)source {
    if (!source) return [[PetAccessory alloc] init];
    PetAccessory *copy = [[PetAccessory alloc] init];
    copy.accessoryID = [source.accessoryID copy];
    copy.name = [source.name copy];
    copy.nameEn = [source.nameEn copy];
    copy.revision = source.revision;
    copy.sku = [source.sku copy];
    copy.barcode = [source.barcode copy];
    copy.productFamilyId = [source.productFamilyId copy];
    copy.variantSchemaVersion = source.variantSchemaVersion;
    copy.isVariant = source.isVariant;
    copy.isDefaultVariant = source.isDefaultVariant;
    copy.variantSortOrder = source.variantSortOrder;
    copy.variantColorDictionary = [source.variantColorDictionary copy];
    copy.selectedOptions = [source.selectedOptions copy];
    copy.selectedOptionsSnapshot = [source.selectedOptionsSnapshot copy];
    copy.variantCombinationKey = [source.variantCombinationKey copy];
    copy.variantAxis = [source.variantAxis copy];
    copy.costPrice = [source.costPrice copy];
    if (source.hasResolvedSellingPrice) {
        copy.price = [source.price copy];
    }
    copy.discountPercent = [source.discountPercent copy];
    copy.discountAmount = [source.discountAmount copy];
    copy.wholesalePrice = [source.wholesalePrice copy];
    copy.hasCommerceConfig = source.hasCommerceConfig;
    copy.quantityGroups = [source.quantityGroups copy];
    copy.weightText = [source.weightText copy];
    copy.weight = [source.weight copy];
    copy.weightUnit = [source.weightUnit copy];
    copy.size = [source.size copy];
    copy.dimensionWidth = [source.dimensionWidth copy];
    copy.dimensionHeight = [source.dimensionHeight copy];
    copy.dimensionUnit = [source.dimensionUnit copy];
    copy.desc = [source.desc copy];
    copy.descEn = [source.descEn copy];
    copy.imageURLsArray = [source.imageURLsArray copy];
    copy.imageMeta = [source.imageMeta copy];
    copy.petMainCategoryID = source.petMainCategoryID;
    copy.petSubCategoryID = source.petSubCategoryID;
    copy.petMainCategoryIDs = [source.petMainCategoryIDs copy];
    copy.petSubCategoryIDs = [source.petSubCategoryIDs copy];
    copy.isAllCategories = source.isAllCategories;
    copy.isAllSubCategories = source.isAllSubCategories;
    copy.AccessoryCategoryID = [source.AccessoryCategoryID copy];
    copy.relatedAccessories = [source.relatedAccessories copy];
    copy.cityID = source.cityID;
    copy.createdAt = [source.createdAt copy];
    copy.expiryDate = [source.expiryDate copy];
    copy.ownerID = [source.ownerID copy];
    copy.branchID = [source.branchID copy];
    copy.branchCode = [source.branchCode copy];
    copy.storeID = [source.storeID copy];
    copy.storeName = [source.storeName copy];
    copy.ownerType = [source.ownerType copy];
    copy.source = [source.source copy];
    copy.inventoryMode = [source.inventoryMode copy];
    copy.inventoryTrackingPolicy = [source.inventoryTrackingPolicy copy];
    copy.shelfLifeDays = [source.shelfLifeDays copy];
    copy.guaranteedShelfLifeDays = [source.guaranteedShelfLifeDays copy];
    copy.expiryCutoffDays = [source.expiryCutoffDays copy];
    copy.inventorySchemaVersion = source.inventorySchemaVersion;
    copy.standardSellingPrice = [source.standardSellingPrice copy];
    copy.reservedQuantity = source.reservedQuantity;
    copy.accessKindType = source.accessKindType;
    copy.condition = source.condition;
    copy.quantity = source.quantity;
    copy.noStock = source.noStock;
    copy.active = source.active;
    copy.isArchived = source.isArchived;
    copy.isNew = source.isNew;
    copy.hasOffer = source.hasOffer;
    copy.showInAppMarket = source.showInAppMarket;
    copy.isBlocked = source.isBlocked;
    copy.isDeleted = source.isDeleted;
    copy.isDisabled = source.isDisabled;
    copy.blurHash = [source.blurHash copy];
    return copy;
}

- (BOOL)isLivePet {
    return self.accessKindType == AccessTypeLivePets;
}

- (BOOL)isFood {
    return self.accessKindType == AccessTypeFood;
}

- (BOOL)isPetMedicine {
    return self.accessKindType == AccessTypePetMedicine;
}

#pragma mark - Branch Resolution

- (NSString *)resolvedBranchID {
    if (self.branchID.length > 0) return self.branchID;
    if (self.storeID.length > 0) return self.storeID;
    return @"";
}

- (NSString *)resolvedBranchName {
    if (self.storeName.length > 0) return self.storeName;
    if (self.branchCode.length > 0) return self.branchCode;
    return [Language isRTL] ? @"المتجر الرئيسي" : @"Main Store";
}

- (NSString *)accessoryCategoryName {
    return self.AccessoryCategoryID ?: @"";
}

- (NSString *)category {
    return [self accessoryCategoryName];
}

#pragma mark - Sharing and Helper Presentation

+ (nullable NSURL *)firstImageURLForAccessory:(PetAccessory *)accessory {
    if (!accessory) return nil;
    if (accessory.imageURLsArray.count > 0) {
        for (id candidate in accessory.imageURLsArray) {
            if ([candidate isKindOfClass:NSURL.class]) return (NSURL *)candidate;
            if ([candidate isKindOfClass:NSString.class]) {
                NSString *trimmed = [(NSString *)candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmed.length > 0) {
                    NSURL *url = [NSURL URLWithString:trimmed];
                    if (url) return url;
                }
            }
        }
    }
    return nil;
}

+ (NSString *)typeTextForAccessory:(PetAccessory *)accessory {
    if (!accessory) return @"";
    switch (accessory.accessKindType) {
        case AccessTypeFood: return kLang(@"Market_Food");
        case AccessTypeLivePets: return kLang(@"Live_Pet");
        case AccessTypePetMedicine: return kLang(@"Medicine");
        default: return kLang(@"Market_Accessory");
    }
}

+ (NSString *)conditionTextForAccessory:(PetAccessory *)accessory {
    if (!accessory) return @"";
    return accessory.condition == AccessConditionsUsed ? kLang(@"Used") : kLang(@"New");
}

+ (NSString *)formatCurrency:(NSNumber *)amount {
    if (!amount) return @"0 QAR";
    return [NSString stringWithFormat:@"%.0f QAR", [amount doubleValue]];
}

+ (NSString *)formattedPrice:(NSNumber *)finalPrice
               originalPrice:(NSNumber *)originalPrice
             discountPercent:(NSNumber *)discountPercent {
    return [self formatCurrency:finalPrice];
}

+ (NSString *)shareMessageForAccessory:(PetAccessory *)accessory {
    if (!accessory) return @"";
    return [NSString stringWithFormat:@"%@ - %@", accessory.name ?: @"", [self formatCurrency:accessory.finalPrice]];
}

+ (void)sharePetAccessory:(PetAccessory *)accessory
       fromViewController:(UIViewController *)vc
               sourceView:(nullable UIView *)sourceView {
    if (!accessory || !vc) return;
    NSString *message = [self shareMessageForAccessory:accessory];
    UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:@[message] applicationActivities:nil];
    if (sourceView && [act respondsToSelector:@selector(popoverPresentationController)]) {
        act.popoverPresentationController.sourceView = sourceView;
        act.popoverPresentationController.sourceRect = sourceView.bounds;
    }
    [vc presentViewController:act animated:YES completion:nil];
}

+ (void)sharePetAccessory:(PetAccessory *)accessory fromViewController:(UIViewController *)vc {
    [self sharePetAccessory:accessory fromViewController:vc sourceView:nil];
}

+ (UIViewController *)pp_topViewController {
    return [self pp_topViewControllerFromRoot:[UIApplication sharedApplication].keyWindow.rootViewController];
}

+ (UIViewController *)pp_topViewControllerFromRoot:(UIViewController *)rootViewController {
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)rootViewController;
        return [self pp_topViewControllerFromRoot:nav.visibleViewController];
    }
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)rootViewController;
        return [self pp_topViewControllerFromRoot:tab.selectedViewController];
    }
    if (rootViewController.presentedViewController) {
        return [self pp_topViewControllerFromRoot:rootViewController.presentedViewController];
    }
    return rootViewController;
}

@end
