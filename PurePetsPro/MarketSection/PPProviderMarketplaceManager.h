#import <Foundation/Foundation.h>

@class PPProviderMarketItem;
@protocol FIRListenerRegistration;
@class UIImage;

@interface PPMarketplaceBranch : NSObject
@property (nonatomic, copy) NSString *branchID;
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *nameAr;
@property (nonatomic, copy) NSString *nameEn;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, copy, nullable) NSString *locationPoints;
@property (nonatomic, assign) BOOL hasCoordinates;
@property (nonatomic, copy, nullable) NSString *stockMode;
@property (nonatomic, copy, nullable) NSString *operatingHours;
@property (nonatomic, copy, nullable) NSString *crNumber;
@property (nonatomic, copy, nullable) NSString *taxNumber;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL defaultBranch;
+ (instancetype)branchFromDictionary:(NSDictionary *)dictionary;
- (NSString *)displayName;
- (NSDictionary *)pickupAddressPayload;
@end

@interface PPProviderMarketplaceManager : NSObject

+ (instancetype)sharedManager;

- (id<FIRListenerRegistration>)observeMarketItemsForOwnerID:(NSString *)ownerID
                                                   onChange:(void (^)(NSArray<PPProviderMarketItem *> *items, NSError *error))onChange;

- (void)createMarketItem:(NSDictionary *)fields
              completion:(void (^)(BOOL success, NSString *itemID, NSString *message, NSError *error))completion;

- (void)updateMarketItem:(NSString *)itemID
                  fields:(NSDictionary *)fields
              completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)updateMarketStock:(NSString *)itemID
                quantity:(NSInteger)quantity
              completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)updateMarketOffer:(NSString *)itemID
         discountPercent:(double)discountPercent
          discountAmount:(double)discountAmount
                hasOffer:(BOOL)hasOffer
              completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)archiveMarketItemWithID:(NSString *)itemID
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)publishMarketItemWithID:(NSString *)itemID
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)listMarketplaceBranchesWithCompletion:(void (^)(NSArray<PPMarketplaceBranch *> *branches, NSError *error))completion;
- (void)saveMarketplaceBranchWithID:(NSString * _Nullable)branchID
                             nameAr:(NSString *)nameAr
                             nameEn:(NSString *)nameEn
                            address:(NSString *)address
                              phone:(NSString *)phone
                          isDefault:(BOOL)isDefault
                         completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;
- (void)saveMarketplaceBranchWithID:(NSString * _Nullable)branchID
                             nameAr:(NSString *)nameAr
                             nameEn:(NSString *)nameEn
                            address:(NSString *)address
                              phone:(NSString *)phone
                           latitude:(double)latitude
                          longitude:(double)longitude
                     locationPoints:(NSString * _Nullable)locationPoints
                          stockMode:(NSString * _Nullable)stockMode
                     operatingHours:(NSString * _Nullable)operatingHours
                           crNumber:(NSString * _Nullable)crNumber
                          taxNumber:(NSString * _Nullable)taxNumber
                          isDefault:(BOOL)isDefault
                         completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;
- (void)setMarketplaceBranchID:(NSString *)branchID
                        active:(BOOL)active
                    completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

@end
