#import <Foundation/Foundation.h>

@class PetAccessory;

NS_ASSUME_NONNULL_BEGIN

@interface PPProviderMarketItem : NSObject

@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *nameEn;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy, nullable) NSString *descEn;
@property (nonatomic, copy) NSArray<NSString *> *imageURLsArray;
@property (nonatomic, assign) double price;
@property (nonatomic, assign) double finalPrice;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) BOOL noStock;
@property (nonatomic, assign) NSInteger accessKindType;
@property (nonatomic, assign) NSInteger petMainCategoryID;
@property (nonatomic, assign) NSInteger petSubCategoryID;
@property (nonatomic, copy, nullable) NSString *petMainCategoryName;
@property (nonatomic, assign) BOOL hasOffer;
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, copy, nullable) NSString *ownerType;
@property (nonatomic, assign) BOOL showInAppMarket;
@property (nonatomic, assign) BOOL isArchived;
@property (nonatomic, copy, nullable) NSDate *createdAt;
@property (nonatomic, copy, nullable) NSDate *updatedAt;
@property (nonatomic, copy, nullable) NSString *productFamilyId;
@property (nonatomic, assign) NSInteger variantSchemaVersion;
@property (nonatomic, assign) BOOL isVariant;
@property (nonatomic, assign) BOOL isDefaultVariant;
@property (nonatomic, assign) NSInteger variantSortOrder;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *variantColorDictionary;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *selectedOptions;
@property (nonatomic, strong, nullable) NSArray<NSDictionary<NSString *, id> *> *selectedOptionsSnapshot;
@property (nonatomic, copy, nullable) NSString *variantCombinationKey;
@property (nonatomic, copy, nullable) NSString *variantAxis;
@property (nonatomic, readonly) BOOL belongsToVariantFamily;

@property (nonatomic, copy, nullable) NSString *sku;
@property (nonatomic, copy, nullable) NSString *barcode;
@property (nonatomic, strong, nullable) NSNumber *costPrice;
@property (nonatomic, strong, nullable) NSNumber *wholesalePrice;
@property (nonatomic, strong, nullable) NSNumber *discountPercent;
@property (nonatomic, strong, nullable) NSNumber *discountAmount;
@property (nonatomic, assign) NSInteger revision;

+ (instancetype)fromDictionary:(NSDictionary<NSString *, id> *)dict itemID:(nullable NSString *)itemID;
- (NSDictionary<NSString *, id> *)toFirestoreDictionary;

@property (nonatomic, readonly, copy) NSString *kindLabel;
@property (nonatomic, readonly, copy) NSString *stockLabel;
@property (nonatomic, readonly, copy) NSString *visibilityLabel;

// Variant option & display helpers
@property (nonatomic, readonly, copy) NSString *pos_variantOptionLabel;
@property (nonatomic, readonly) BOOL pos_hasRealColor;
@property (nonatomic, readonly, copy) NSString *pos_variantColorHex;
@property (nonatomic, readonly, copy) NSString *pos_variantColorName;

// Conversion between PPProviderMarketItem and PetAccessory
- (PetAccessory *)asPetAccessory;
+ (nullable instancetype)fromPetAccessory:(nullable PetAccessory *)accessory;

@end

NS_ASSUME_NONNULL_END

