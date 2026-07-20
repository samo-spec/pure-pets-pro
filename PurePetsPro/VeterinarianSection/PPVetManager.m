//
//  PPVetManager.m
//  PurePetsAdmin
//

#import "PPVetManager.h"
#import "PPVetModel.h"
#import "PPFirebaseCompat.h"

static NSString * const kColVets = @"veterinarians";
static NSString * const kColPetAccessories = @"petAccessories";
static NSInteger const PPVetMedicineAccessKindType = 4;

static NSString *PPVetManagerSafeString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    }
    return @"";
}

static NSArray<NSString *> *PPVetManagerStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id entry in (NSArray *)value) {
        NSString *safeEntry = PPVetManagerSafeString(entry);
        if (safeEntry.length > 0) {
            [items addObject:safeEntry];
        }
    }
    return items.copy;
}

static NSDate * _Nullable PPVetManagerDateFromValue(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    return nil;
}

static BOOL PPVetManagerBoolFromValue(id value) {
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized = [[(NSString *)value lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return [normalized isEqualToString:@"true"] || [normalized isEqualToString:@"yes"] || [normalized isEqualToString:@"1"];
    }
    return NO;
}

static NSString *PPVetManagerFirstImageURL(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return PPVetManagerSafeString(value);
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            NSString *url = PPVetManagerFirstImageURL(entry);
            if (url.length > 0) {
                return url;
            }
        }
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        return PPVetManagerFirstImageURL(((NSDictionary *)value)[@"url"]);
    }
    return @"";
}

static BOOL PPVetManagerIsMedicineDocument(NSDictionary *dict) {
    NSInteger accessKindType = [dict[@"accessKindType"] respondsToSelector:@selector(integerValue)] ? [dict[@"accessKindType"] integerValue] : 0;
    NSInteger legacyType = [dict[@"type"] respondsToSelector:@selector(integerValue)] ? [dict[@"type"] integerValue] : 0;
    return accessKindType == PPVetMedicineAccessKindType || legacyType == PPVetMedicineAccessKindType;
}

static NSString *PPVetManagerOwnerIdentifierForDocument(NSDictionary *dict) {
    for (NSString *key in @[@"ownerID", @"ownerId", @"userId", @"userID", @"providerId", @"providerID"]) {
        NSString *candidate = PPVetManagerSafeString(dict[key]);
        if (candidate.length > 0) {
            return candidate;
        }
    }
    return @"";
}

static NSError *PPVetError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"pp.vet.manager"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Vet operation failed"}];
}

@implementation PPVetMedicineModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _medicineID = @"";
        _title = @"";
        _medicineDescription = @"";
        _imageUrl = @"";
        _blurHash = @"";
        _vetId = @"";
        _userId = @"";
        _animalTypes = @[];
        _category = @"";
        _currency = @"QAR";
        _isAvailable = YES;
        _isPublished = YES;
    }
    return self;
}

- (NSString *)title_lowercase {
    return self.title.lowercaseString ?: @"";
}

- (NSDictionary *)toDictionary {
    NSString *title = self.title ?: @"";
    NSString *desc = self.medicineDescription ?: @"";
    NSString *ownerID = self.userId ?: @"";
    NSInteger quantity = MAX(0, self.stockQuantity);
    BOOL active = self.isPublished && !self.isDisabled;
    BOOL visibleInUserApp = active && self.isAvailable && quantity > 0;
    NSMutableArray<NSString *> *imageURLs = [NSMutableArray array];
    if (self.imageUrl.length > 0) {
        [imageURLs addObject:self.imageUrl];
    }
    NSMutableDictionary *dict = [@{
        @"medicineID": self.medicineID ?: @"",
        @"itemID": self.medicineID ?: @"",
        @"accessKindType": @(PPVetMedicineAccessKindType),
        @"type": @(PPVetMedicineAccessKindType),
        @"providerType": @"pharmacy",
        @"listingType": @"medicine",
        @"name": title,
        @"nameEn": title,
        @"title": title,
        @"title_lowercase": self.title_lowercase,
        @"searchTitle": self.title_lowercase,
        @"desc": desc,
        @"descEn": desc,
        @"description": desc,
        @"imageUrl": self.imageUrl ?: @"",
        @"imageURLsArray": imageURLs.copy,
        @"blurHash": self.blurHash ?: @"",
        @"vetId": self.vetId ?: @"",
        @"userId": ownerID,
        @"userID": ownerID,
        @"ownerID": ownerID,
        @"ownerId": ownerID,
        @"providerId": ownerID,
        @"providerID": ownerID,
        @"animalTypes": self.animalTypes ?: @[],
        @"category": self.category ?: @"",
        @"price": @(self.price),
        @"finalPrice": @(self.price),
        @"currency": self.currency.length > 0 ? self.currency : @"QAR",
        @"stockQuantity": @(quantity),
        @"quantity": @(quantity),
        @"noStock": @(quantity <= 0),
        @"isAvailable": @(visibleInUserApp),
        @"showInAppMarket": @(active),
        @"active": @(active),
        @"isPublished": @(self.isPublished),
        @"isDisabled": @(self.isDisabled),
        @"condition": @(1),
    } mutableCopy];
    if (self.createdAt) dict[@"createdAt"] = self.createdAt;
    if (self.updatedAt) dict[@"updatedAt"] = self.updatedAt;
    return dict.copy;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)medicineID {
    PPVetMedicineModel *model = [[PPVetMedicineModel alloc] init];
    model.medicineID = medicineID ?: @"";
    NSString *name = PPVetManagerSafeString(dict[@"name"]);
    NSString *nameEn = PPVetManagerSafeString(dict[@"nameEn"]);
    NSString *title = PPVetManagerSafeString(dict[@"title"]);
    model.title = title.length > 0 ? title : (name.length > 0 ? name : nameEn);
    NSString *desc = PPVetManagerSafeString(dict[@"desc"]);
    NSString *descEn = PPVetManagerSafeString(dict[@"descEn"]);
    NSString *legacyDescription = PPVetManagerSafeString(dict[@"description"]);
    model.medicineDescription = legacyDescription.length > 0 ? legacyDescription : (desc.length > 0 ? desc : descEn);
    NSString *imageUrl = PPVetManagerFirstImageURL(dict[@"imageUrl"]);
    if (imageUrl.length == 0) {
        imageUrl = PPVetManagerFirstImageURL(dict[@"imageURLsArray"]);
    }
    model.imageUrl = imageUrl;
    model.blurHash = PPVetManagerSafeString(dict[@"blurHash"]);
    model.vetId = PPVetManagerSafeString(dict[@"vetId"]);
    NSString *ownerID = PPVetManagerOwnerIdentifierForDocument(dict);
    NSString *userId = PPVetManagerSafeString(dict[@"userId"]);
    model.userId = userId.length > 0 ? userId : ownerID;
    model.animalTypes = PPVetManagerStringArray(dict[@"animalTypes"]);
    model.category = PPVetManagerSafeString(dict[@"category"]);
    model.price = [dict[@"price"] respondsToSelector:@selector(doubleValue)] ? [dict[@"price"] doubleValue] : ([dict[@"finalPrice"] respondsToSelector:@selector(doubleValue)] ? [dict[@"finalPrice"] doubleValue] : 0.0);
    model.currency = PPVetManagerSafeString(dict[@"currency"]).length > 0 ? PPVetManagerSafeString(dict[@"currency"]) : @"QAR";
    model.stockQuantity = [dict[@"stockQuantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"stockQuantity"] integerValue] : ([dict[@"quantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"quantity"] integerValue] : 0);
    BOOL noStock = PPVetManagerBoolFromValue(dict[@"noStock"]);
    model.isAvailable = dict[@"isAvailable"] == nil ? (model.stockQuantity > 0 && !noStock) : [dict[@"isAvailable"] boolValue];
    BOOL blocked = PPVetManagerBoolFromValue(dict[@"isBlocked"]);
    BOOL deleted = PPVetManagerBoolFromValue(dict[@"isDeleted"]);
    BOOL archived = PPVetManagerBoolFromValue(dict[@"isArchived"]);
    BOOL active = dict[@"active"] == nil ? YES : PPVetManagerBoolFromValue(dict[@"active"]);
    model.isPublished = dict[@"isPublished"] == nil ? (active && !(blocked || deleted || archived)) : [dict[@"isPublished"] boolValue];
    model.isDisabled = [dict[@"isDisabled"] boolValue] || blocked || deleted || archived;
    model.createdAt = PPVetManagerDateFromValue(dict[@"createdAt"]);
    model.updatedAt = PPVetManagerDateFromValue(dict[@"updatedAt"]);
    return model;
}

- (id)copyWithZone:(NSZone *)zone {
    PPVetMedicineModel *copy = [[PPVetMedicineModel allocWithZone:zone] init];
    copy.medicineID = self.medicineID;
    copy.title = self.title;
    copy.medicineDescription = self.medicineDescription;
    copy.imageUrl = self.imageUrl;
    copy.blurHash = self.blurHash;
    copy.vetId = self.vetId;
    copy.userId = self.userId;
    copy.animalTypes = self.animalTypes;
    copy.category = self.category;
    copy.price = self.price;
    copy.currency = self.currency;
    copy.stockQuantity = self.stockQuantity;
    copy.isAvailable = self.isAvailable;
    copy.isPublished = self.isPublished;
    copy.isDisabled = self.isDisabled;
    copy.createdAt = self.createdAt;
    copy.updatedAt = self.updatedAt;
    return copy;
}

@end

@interface PPVetManager ()
@property (nonatomic, strong) FIRFirestore *db;
@end

@implementation PPVetManager

+ (instancetype)sharedManager {
    static PPVetManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPVetManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (FIRCollectionReference *)col {
    return [self.db collectionWithPath:kColVets];
}

- (FIRCollectionReference *)medicineCol {
    return [self.db collectionWithPath:kColPetAccessories];
}

#pragma mark - Mapping

- (PPVetModel *)_mapDoc:(FIRDocumentSnapshot *)doc {
    return [PPVetModel fromDictionary:doc.data ?: @{} withID:doc.documentID];
}

- (NSArray<PPVetModel *> *)_mapDocs:(NSArray<FIRDocumentSnapshot *> *)docs {
    NSMutableArray<PPVetModel *> *arr = [NSMutableArray arrayWithCapacity:docs.count];
    for (FIRDocumentSnapshot *doc in docs) {
        [arr addObject:[self _mapDoc:doc]];
    }
    return arr;
}

#pragma mark - READ

- (void)fetchAllVetsWithCompletion:(PPVetArrayBlock)completion {
    [[self col] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        completion(error ? nil : [self _mapDocs:snap.documents], error);
    }];
}

- (id<FIRListenerRegistration>)observeAllVets:(PPVetArrayBlock)onChange {
    return [[self col] addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            onChange(error ? nil : [self _mapDocs:snap.documents], error);
        });
    }];
}

- (void)fetchVetsForUserID:(NSString *)userID completion:(PPVetArrayBlock)completion {
    NSString *safeUserID = userID ?: @"";
    if (safeUserID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    [[[self col] queryWhereField:@"userId" isEqualTo:safeUserID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (snap.documents.count > 0) {
            if (completion) completion([self _mapDocs:snap.documents], nil);
            return;
        }
        [[[self col] queryWhereField:@"userID" isEqualTo:safeUserID]
         getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable legacySnap, NSError * _Nullable legacyError) {
            if (!completion) return;
            completion(legacyError ? nil : [self _mapDocs:legacySnap.documents], legacyError);
        }];
    }];
}

- (void)fetchVetByID:(NSString *)vetID completion:(void (^)(PPVetModel * _Nullable, NSError * _Nullable))completion {
    if (vetID.length == 0) {
        if (completion) completion(nil, PPVetError(400, @"Vet ID is required."));
        return;
    }
    [[[self col] documentWithPath:vetID] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        if (error) { completion(nil, error); return; }
        if (!snap.exists) { completion(nil, PPVetError(404, @"Vet not found.")); return; }
        completion([self _mapDoc:snap], nil);
    }];
}

#pragma mark - WRITE

- (void)addVet:(PPVetModel *)vet image:(UIImage *)image completion:(PPVetVoidBlock)completion {
    if (!vet) {
        if (completion) completion(PPVetError(400, @"Vet model is required."));
        return;
    }

    NSString *docID = [[NSUUID UUID] UUIDString];
    vet.vetID = docID;

    if (!vet.createdAt) {
        vet.createdAt = [NSDate date];
    }
    vet.updatedAt = [NSDate date];
    vet.readyToContact = vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
    if (vet.verificationStatus.length == 0) {
        vet.verificationStatus = @"pending";
    }
    if (!vet.canEditProfile) {
        vet.canEditProfile = YES;
    }
    if (!vet.canPostServices) {
        vet.canPostServices = YES;
    }

    if (vet.userID.length == 0) {
        vet.userID = [FIRAuth auth].currentUser.uid ?: @"";
    }

    void (^saveBlock)(NSString *) = ^(NSString *logoURL) {
        vet.logoURL = logoURL.length ? logoURL : vet.logoURL;
        [[[self col] documentWithPath:docID] setData:[vet toDictionary] completion:completion];
    };

    if (image) {
        [self uploadImage:image vetID:docID completion:saveBlock];
    } else {
        saveBlock(@"");
    }
}

- (void)updateVet:(PPVetModel *)vet image:(UIImage *)image completion:(PPVetVoidBlock)completion {
    if (!vet || vet.vetID.length == 0) {
        if (completion) completion(PPVetError(400, @"Valid vet model with ID is required."));
        return;
    }

    vet.updatedAt = [NSDate date];
    vet.readyToContact = vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
    if (vet.verificationStatus.length == 0) {
        vet.verificationStatus = @"pending";
    }

    void (^updateBlock)(NSString *) = ^(NSString *logoURL) {
        vet.logoURL = logoURL.length ? logoURL : vet.logoURL;
        [[[self col] documentWithPath:vet.vetID] setData:[vet toDictionary] merge:YES completion:completion];
    };

    if (image) {
        [self uploadImage:image vetID:vet.vetID completion:updateBlock];
    } else {
        updateBlock(@"");
    }
}

- (void)deleteVet:(PPVetModel *)vet completion:(PPVetVoidBlock)completion {
    if (!vet || vet.vetID.length == 0) {
        if (completion) completion(PPVetError(400, @"Vet ID is required for deletion."));
        return;
    }
    [[[self col] documentWithPath:vet.vetID] deleteDocumentWithCompletion:completion];
}

#pragma mark - Admin Toggles

- (void)setDisabled:(BOOL)disabled forVetID:(NSString *)vetID completion:(PPVetVoidBlock)completion {
    if (vetID.length == 0) {
        if (completion) completion(PPVetError(400, @"Vet ID is missing."));
        return;
    }
    [[[self col] documentWithPath:vetID]
     updateData:@{
        @"isDisabled": @(disabled),
        @"updatedAt": [FIRTimestamp timestamp]
    }
     completion:completion];
}

- (void)updateSubscriptionForVetID:(NSString *)vetID
                              tier:(NSInteger)tier
                            active:(BOOL)active
                         startDate:(NSDate *)startDate
                           endDate:(NSDate *)endDate
                        completion:(PPVetVoidBlock)completion {
    if (vetID.length == 0) {
        if (completion) completion(PPVetError(400, @"Vet ID is missing."));
        return;
    }
    NSMutableDictionary *data = [@{
        @"subscriptionTier":   @(tier),
        @"subscriptionActive": @(active),
        @"updatedAt":          [FIRTimestamp timestamp]
    } mutableCopy];

    if (startDate) {
        data[@"subscriptionStartDate"] = startDate;
    }
    if (endDate) {
        data[@"subscriptionEndDate"] = endDate;
    }

    [[[self col] documentWithPath:vetID] updateData:data completion:completion];
}

#pragma mark - Image Upload

- (void)uploadImage:(UIImage *)image vetID:(NSString *)vetID completion:(void (^)(NSString *))completion {
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        if (completion) completion(@"");
        return;
    }
    NSString *path = [NSString stringWithFormat:@"vets/%@.png", vetID];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
    FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
    meta.contentType = @"image/png";

    [ref putData:imageData metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            DLog(@"[PPVetManager] image upload error: %@", error.localizedDescription);
            if (completion) completion(@"");
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (completion) completion(URL.absoluteString ?: @"");
        }];
    }];
}

- (void)uploadMedicineImage:(UIImage *)image medicineID:(NSString *)medicineID completion:(void (^)(NSString *))completion {
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        if (completion) completion(@"");
        return;
    }
    NSString *path = [NSString stringWithFormat:@"petAccessories/%@.png", medicineID ?: @""];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];
    FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
    meta.contentType = @"image/png";

    [ref putData:imageData metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            DLog(@"[PPVetManager] medicine image upload error: %@", error.localizedDescription);
            if (completion) completion(@"");
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (completion) completion(URL.absoluteString ?: @"");
        }];
    }];
}

- (void)fetchMedicinesForVetID:(NSString *)vetID completion:(void (^)(NSArray<PPVetMedicineModel *> * _Nullable, NSError * _Nullable))completion {
    NSString *safeVetID = vetID ?: @"";
    if (safeVetID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    [[[self medicineCol] queryWhereField:@"accessKindType" isEqualTo:@(PPVetMedicineAccessKindType)]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        if (error) {
            completion(nil, error);
            return;
        }
        NSMutableArray<PPVetMedicineModel *> *items = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snap.documents) {
            NSDictionary *data = doc.data ?: @{};
            if (!PPVetManagerIsMedicineDocument(data)) {
                continue;
            }
            NSString *docVetID = PPVetManagerSafeString(data[@"vetId"]);
            if (![docVetID isEqualToString:safeVetID]) {
                continue;
            }
            [items addObject:[PPVetMedicineModel fromDictionary:doc.data ?: @{} withID:doc.documentID]];
        }
        completion(items.copy, nil);
    }];
}

- (void)fetchMedicinesForUserID:(NSString *)userID completion:(void (^)(NSArray<PPVetMedicineModel *> * _Nullable, NSError * _Nullable))completion {
    NSString *safeUserID = userID ?: @"";
    if (safeUserID.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    [[[self medicineCol] queryWhereField:@"accessKindType" isEqualTo:@(PPVetMedicineAccessKindType)]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        if (error) {
            completion(nil, error);
            return;
        }
        NSMutableArray<PPVetMedicineModel *> *items = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snap.documents) {
            NSDictionary *data = doc.data ?: @{};
            if (!PPVetManagerIsMedicineDocument(data)) {
                continue;
            }
            NSString *ownerID = PPVetManagerOwnerIdentifierForDocument(data);
            NSString *userId = PPVetManagerSafeString(data[@"userId"]);
            if (!([ownerID isEqualToString:safeUserID] || [userId isEqualToString:safeUserID])) {
                continue;
            }
            [items addObject:[PPVetMedicineModel fromDictionary:data withID:doc.documentID]];
        }
        completion(items.copy, nil);
    }];
}

- (void)addMedicine:(PPVetMedicineModel *)medicine image:(UIImage *)image completion:(PPVetVoidBlock)completion {
    if (!medicine) {
        if (completion) completion(PPVetError(400, @"Medicine model is required."));
        return;
    }

    NSString *docID = [[NSUUID UUID] UUIDString];
    medicine.medicineID = docID;
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length == 0) {
        if (completion) completion(PPVetError(401, @"Sign in before adding medicine."));
        return;
    }
    medicine.userId = currentUID;
    if (!medicine.vetId.length) {
        medicine.vetId = currentUID;
    }
    medicine.isAvailable = medicine.isAvailable && medicine.isPublished && !medicine.isDisabled && medicine.stockQuantity > 0;
    medicine.updatedAt = [NSDate date];
    if (!medicine.createdAt) {
        medicine.createdAt = medicine.updatedAt;
    }

    void (^saveBlock)(NSString *) = ^(NSString *imageURL) {
        if (imageURL.length > 0) {
            medicine.imageUrl = imageURL;
        }
        [[[self medicineCol] documentWithPath:docID] setData:[medicine toDictionary] completion:completion];
    };

    if (image) {
        [self uploadMedicineImage:image medicineID:docID completion:saveBlock];
    } else {
        saveBlock(@"");
    }
}

- (void)updateMedicine:(PPVetMedicineModel *)medicine image:(UIImage *)image completion:(PPVetVoidBlock)completion {
    if (!medicine || medicine.medicineID.length == 0) {
        if (completion) completion(PPVetError(400, @"Valid medicine model with ID is required."));
        return;
    }
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length == 0) {
        if (completion) completion(PPVetError(401, @"Sign in before updating medicine."));
        return;
    }
    if (!medicine.userId.length) {
        medicine.userId = currentUID;
    }
    if (!medicine.vetId.length) {
        medicine.vetId = currentUID;
    }
    medicine.isAvailable = medicine.isAvailable && medicine.isPublished && !medicine.isDisabled && medicine.stockQuantity > 0;
    medicine.updatedAt = [NSDate date];

    void (^updateBlock)(NSString *) = ^(NSString *imageURL) {
        if (imageURL.length > 0) {
            medicine.imageUrl = imageURL;
        }
        NSMutableDictionary *payload = [[medicine toDictionary] mutableCopy];
        payload[@"requiresPrescription"] = [FIRFieldValue fieldValueForDelete];
        [[[self medicineCol] documentWithPath:medicine.medicineID] setData:payload merge:YES completion:completion];
    };

    if (image) {
        [self uploadMedicineImage:image medicineID:medicine.medicineID completion:updateBlock];
    } else {
        updateBlock(@"");
    }
}

- (void)deleteMedicine:(PPVetMedicineModel *)medicine completion:(PPVetVoidBlock)completion {
    if (!medicine || medicine.medicineID.length == 0) {
        if (completion) completion(PPVetError(400, @"Medicine ID is required for deletion."));
        return;
    }
    [[[self medicineCol] documentWithPath:medicine.medicineID] deleteDocumentWithCompletion:completion];
}

#pragma mark - Count

- (id<FIRListenerRegistration>)listenVetCount:(PPVetCountBlock)block {
    return [[self col] addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!block) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            block(error ? 0 : (NSInteger)snap.documents.count);
        });
    }];
}

@end
