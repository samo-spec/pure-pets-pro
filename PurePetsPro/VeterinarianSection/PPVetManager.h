//
//  PPVetManager.h
//  PurePetsAdmin
//
//  Singleton manager for Firestore "veterinarians" collection.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPVetModel;
@class PPVetMedicineModel;
@protocol FIRListenerRegistration;

typedef void(^PPVetArrayBlock)(NSArray<PPVetModel *> * _Nullable vets, NSError * _Nullable error);
typedef void(^PPVetVoidBlock)(NSError * _Nullable error);
typedef void(^PPVetCountBlock)(NSInteger count);

@class PetAccessory;

@interface PPVetMedicineModel : NSObject <NSCopying>
@property (nonatomic, copy) NSString *medicineID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, readonly) NSString *title_lowercase;
@property (nonatomic, copy) NSString *medicineDescription;
@property (nonatomic, copy) NSString *imageUrl;
@property (nonatomic, copy) NSString *blurHash;
@property (nonatomic, copy) NSString *vetId;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSArray<NSString *> *animalTypes;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) NSInteger stockQuantity;
@property (nonatomic, assign) BOOL isAvailable;
@property (nonatomic, assign) BOOL isPublished;
@property (nonatomic, assign) BOOL isDisabled;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

// Variant & Medical Dimensions
@property (nonatomic, copy, nullable) NSString *productFamilyId;
@property (nonatomic, assign) NSInteger variantSchemaVersion;
@property (nonatomic, assign) BOOL isVariant;
@property (nonatomic, assign) BOOL isDefaultVariant;
@property (nonatomic, assign) NSInteger variantSortOrder;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *selectedOptions;
@property (nonatomic, strong, nullable) NSArray<NSDictionary<NSString *, id> *> *selectedOptionsSnapshot;
@property (nonatomic, copy, nullable) NSString *variantCombinationKey;
@property (nonatomic, copy, nullable) NSString *variantAxis;
@property (nonatomic, copy, nullable) NSString *sku;
@property (nonatomic, copy, nullable) NSString *barcode;
@property (nonatomic, strong, nullable) NSNumber *wholesalePrice;
@property (nonatomic, copy, nullable) NSString *dosageForm;
@property (nonatomic, copy, nullable) NSString *strength;
@property (nonatomic, copy, nullable) NSString *packSize;
@property (nonatomic, copy, nullable) NSString *volume;
@property (nonatomic, copy, nullable) NSString *batchNumber;
@property (nonatomic, strong, nullable) NSDate *expiryDate;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)medicineID;
- (PetAccessory *)asPetAccessory;
@end

@interface PPVetManager : NSObject

+ (instancetype)sharedManager;

// ── READ ──
- (void)fetchAllVetsWithCompletion:(PPVetArrayBlock)completion;
- (id<FIRListenerRegistration>)observeAllVets:(PPVetArrayBlock)onChange;
- (void)fetchVetsForUserID:(NSString *)userID completion:(PPVetArrayBlock)completion;
- (void)fetchVetByID:(NSString *)vetID completion:(void(^)(PPVetModel * _Nullable vet, NSError * _Nullable error))completion;
- (void)fetchMedicinesForVetID:(NSString *)vetID completion:(void(^)(NSArray<PPVetMedicineModel *> * _Nullable medicines, NSError * _Nullable error))completion;
- (void)fetchMedicinesForUserID:(NSString *)userID completion:(void(^)(NSArray<PPVetMedicineModel *> * _Nullable medicines, NSError * _Nullable error))completion;

// ── WRITE ──
- (void)addVet:(PPVetModel *)vet
         image:(UIImage * _Nullable)image
    completion:(PPVetVoidBlock)completion;

- (void)updateVet:(PPVetModel *)vet
            image:(UIImage * _Nullable)image
       completion:(PPVetVoidBlock)completion;

- (void)deleteVet:(PPVetModel *)vet
       completion:(PPVetVoidBlock)completion;

- (void)addMedicine:(PPVetMedicineModel *)medicine
              image:(UIImage * _Nullable)image
         completion:(PPVetVoidBlock)completion;

- (void)updateMedicine:(PPVetMedicineModel *)medicine
                 image:(UIImage * _Nullable)image
            completion:(PPVetVoidBlock)completion;

- (void)deleteMedicine:(PPVetMedicineModel *)medicine
            completion:(PPVetVoidBlock)completion;

// ── Admin toggles ──
- (void)setDisabled:(BOOL)disabled
           forVetID:(NSString *)vetID
         completion:(PPVetVoidBlock)completion;

- (void)updateSubscriptionForVetID:(NSString *)vetID
                              tier:(NSInteger)tier
                            active:(BOOL)active
                         startDate:(NSDate * _Nullable)startDate
                           endDate:(NSDate * _Nullable)endDate
                        completion:(PPVetVoidBlock)completion;

// ── Image ──
- (void)uploadImage:(UIImage *)image
              vetID:(NSString *)vetID
         completion:(void(^)(NSString *imageURL))completion;

// ── Count ──
- (id<FIRListenerRegistration>)listenVetCount:(PPVetCountBlock)block;

@end

NS_ASSUME_NONNULL_END
