#import <Foundation/Foundation.h>

@interface PPProviderMarketItem : NSObject

@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *nameEn;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *descEn;
@property (nonatomic, copy) NSArray<NSString *> *imageURLsArray;
@property (nonatomic, assign) double price;
@property (nonatomic, assign) double finalPrice;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) BOOL noStock;
@property (nonatomic, assign) NSInteger accessKindType;
@property (nonatomic, assign) NSInteger petMainCategoryID;
@property (nonatomic, assign) NSInteger petSubCategoryID;
@property (nonatomic, copy) NSString *petMainCategoryName;
@property (nonatomic, assign) BOOL hasOffer;
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, copy) NSString *ownerType;
@property (nonatomic, assign) BOOL showInAppMarket;
@property (nonatomic, assign) BOOL isArchived;
@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, copy) NSDate *updatedAt;

+ (instancetype)fromDictionary:(NSDictionary *)dict itemID:(NSString *)itemID;

- (NSString *)kindLabel;
- (NSString *)stockLabel;
- (NSString *)visibilityLabel;

@end
