//
//  PPVetManager.m
//  PurePetsAdmin
//

#import "PPVetManager.h"
#import "PPVetModel.h"
#import "PPFirebaseCompat.h"
#import "PetAccessory.h"
#import "PPProviderMarketplaceManager.h"
#import "PPProviderMarketItem.h"

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

static NSArray<NSDictionary *> *PPVetManagerDictionaryArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    return [value filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id entry, NSDictionary *bindings) {
        return [entry isKindOfClass:NSDictionary.class];
    }]];
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
        _imageURLsArray = @[];
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
    NSMutableArray<NSString *> *imageURLs = [PPVetManagerStringArray(self.imageURLsArray) mutableCopy];
    if (self.imageUrl.length > 0 && ![imageURLs containsObject:self.imageUrl]) [imageURLs insertObject:self.imageUrl atIndex:0];
    NSMutableDictionary *dict = [@{
        @"medicineID": self.medicineID ?: @"",
        @"itemID": self.medicineID ?: @"",
        @"accessKindType": @(PPVetMedicineAccessKindType),
        @"type": @(PPVetMedicineAccessKindType),
        @"providerType": @"pharmacy",
        @"listingType": @"medicine",
        @"name": title,
        @"nameEn": self.titleEn ?: @"",
        @"title": title,
        @"title_lowercase": self.title_lowercase,
        @"searchTitle": self.title_lowercase,
        @"desc": desc,
        @"descEn": self.medicineDescriptionEn ?: @"",
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
        @"isArchived": @(self.isDisabled),
        @"condition": @(1),
    } mutableCopy];
    if (self.createdAt) dict[@"createdAt"] = self.createdAt;
    if (self.updatedAt) dict[@"updatedAt"] = self.updatedAt;
    if (self.imageMeta) dict[@"imageMeta"] = self.imageMeta;
    if (self.revision > 0) dict[@"revision"] = @(self.revision);
    if (self.variantColorDictionary) dict[@"variantAttributes"] = @{@"color": self.variantColorDictionary};

    if (self.productFamilyId.length > 0) dict[@"productFamilyId"] = self.productFamilyId;
    if (self.variantSchemaVersion > 0) dict[@"variantSchemaVersion"] = @(self.variantSchemaVersion);
    dict[@"isVariant"] = @(self.isVariant);
    dict[@"isDefaultVariant"] = @(self.isDefaultVariant);
    if (self.variantSortOrder > 0) dict[@"variantSortOrder"] = @(self.variantSortOrder);
    if (self.selectedOptions.count > 0) dict[@"selectedOptions"] = self.selectedOptions;
    if (self.selectedOptionsSnapshot.count > 0) dict[@"selectedOptionsSnapshot"] = self.selectedOptionsSnapshot;
    if (self.variantCombinationKey.length > 0) dict[@"variantCombinationKey"] = self.variantCombinationKey;
    if (self.variantAxis.length > 0) dict[@"variantAxis"] = self.variantAxis;
    if (self.sku.length > 0) dict[@"sku"] = self.sku;
    if (self.barcode.length > 0) dict[@"barcode"] = self.barcode;
    if (self.wholesalePrice != nil && self.wholesalePrice.doubleValue > 0) dict[@"wholesalePrice"] = self.wholesalePrice;
    if (self.dosageForm.length > 0) dict[@"dosageForm"] = self.dosageForm;
    if (self.strength.length > 0) dict[@"strength"] = self.strength;
    if (self.packSize.length > 0) dict[@"packSize"] = self.packSize;
    if (self.volume.length > 0) dict[@"volume"] = self.volume;
    if (self.batchNumber.length > 0) dict[@"batchNumber"] = self.batchNumber;
    if (self.expiryDate) dict[@"expiryDate"] = self.expiryDate;

    return dict.copy;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)medicineID {
    PPVetMedicineModel *model = [[PPVetMedicineModel alloc] init];
    model.medicineID = medicineID ?: @"";
    NSString *name = PPVetManagerSafeString(dict[@"name"]);
    NSString *nameEn = PPVetManagerSafeString(dict[@"nameEn"]);
    NSString *title = PPVetManagerSafeString(dict[@"title"]);
    model.title = title.length > 0 ? title : (name.length > 0 ? name : nameEn);
    model.titleEn = nameEn;
    NSString *desc = PPVetManagerSafeString(dict[@"desc"]);
    NSString *descEn = PPVetManagerSafeString(dict[@"descEn"]);
    NSString *legacyDescription = PPVetManagerSafeString(dict[@"description"]);
    model.medicineDescription = legacyDescription.length > 0 ? legacyDescription : (desc.length > 0 ? desc : descEn);
    model.medicineDescriptionEn = descEn;
    model.imageURLsArray = PPVetManagerStringArray(dict[@"imageURLsArray"]);
    model.imageMeta = PPVetManagerDictionaryArray(dict[@"imageMeta"]);
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
    model.stockQuantity = [dict[@"quantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"quantity"] integerValue] : ([dict[@"stockQuantity"] respondsToSelector:@selector(integerValue)] ? [dict[@"stockQuantity"] integerValue] : 0);
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

    model.productFamilyId = PPVetManagerSafeString(dict[@"productFamilyId"]);
    model.variantSchemaVersion = [dict[@"variantSchemaVersion"] respondsToSelector:@selector(integerValue)] ? [dict[@"variantSchemaVersion"] integerValue] : 0;
    model.isVariant = PPVetManagerBoolFromValue(dict[@"isVariant"]);
    model.isDefaultVariant = PPVetManagerBoolFromValue(dict[@"isDefaultVariant"]);
    model.variantSortOrder = [dict[@"variantSortOrder"] respondsToSelector:@selector(integerValue)] ? [dict[@"variantSortOrder"] integerValue] : 0;
    model.revision = [dict[@"revision"] respondsToSelector:@selector(integerValue)] ? [dict[@"revision"] integerValue] : 0;
    NSDictionary *attributes = [dict[@"variantAttributes"] isKindOfClass:NSDictionary.class] ? dict[@"variantAttributes"] : @{};
    model.variantColorDictionary = [attributes[@"color"] isKindOfClass:NSDictionary.class] ? attributes[@"color"] : nil;
    if ([dict[@"selectedOptions"] isKindOfClass:[NSDictionary class]]) {
        model.selectedOptions = dict[@"selectedOptions"];
    }
    if ([dict[@"selectedOptionsSnapshot"] isKindOfClass:[NSArray class]]) {
        model.selectedOptionsSnapshot = PPVetManagerDictionaryArray(dict[@"selectedOptionsSnapshot"]);
    }
    model.variantCombinationKey = PPVetManagerSafeString(dict[@"variantCombinationKey"]);
    model.variantAxis = PPVetManagerSafeString(dict[@"variantAxis"]);
    model.sku = PPVetManagerSafeString(dict[@"sku"]);
    model.barcode = PPVetManagerSafeString(dict[@"barcode"]);
    if ([dict[@"wholesalePrice"] respondsToSelector:@selector(doubleValue)]) {
        model.wholesalePrice = dict[@"wholesalePrice"];
    }
    model.dosageForm = PPVetManagerSafeString(dict[@"dosageForm"]);
    model.strength = PPVetManagerSafeString(dict[@"strength"]);
    model.packSize = PPVetManagerSafeString(dict[@"packSize"]);
    model.volume = PPVetManagerSafeString(dict[@"volume"]);
    model.batchNumber = PPVetManagerSafeString(dict[@"batchNumber"]);
    model.expiryDate = PPVetManagerDateFromValue(dict[@"expiryDate"]);

    return model;
}

- (id)copyWithZone:(NSZone *)zone {
    PPVetMedicineModel *copy = [[PPVetMedicineModel allocWithZone:zone] init];
    copy.medicineID = self.medicineID;
    copy.title = self.title;
    copy.titleEn = self.titleEn;
    copy.medicineDescription = self.medicineDescription;
    copy.medicineDescriptionEn = self.medicineDescriptionEn;
    copy.imageUrl = self.imageUrl;
    copy.imageURLsArray = self.imageURLsArray;
    copy.imageMeta = self.imageMeta;
    copy.revision = self.revision;
    copy.variantColorDictionary = self.variantColorDictionary;
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

    copy.productFamilyId = self.productFamilyId;
    copy.variantSchemaVersion = self.variantSchemaVersion;
    copy.isVariant = self.isVariant;
    copy.isDefaultVariant = self.isDefaultVariant;
    copy.variantSortOrder = self.variantSortOrder;
    copy.selectedOptions = [self.selectedOptions copy];
    copy.selectedOptionsSnapshot = [self.selectedOptionsSnapshot copy];
    copy.variantCombinationKey = self.variantCombinationKey;
    copy.variantAxis = self.variantAxis;
    copy.sku = self.sku;
    copy.barcode = self.barcode;
    copy.wholesalePrice = self.wholesalePrice;
    copy.dosageForm = self.dosageForm;
    copy.strength = self.strength;
    copy.packSize = self.packSize;
    copy.volume = self.volume;
    copy.batchNumber = self.batchNumber;
    copy.expiryDate = self.expiryDate;

    return copy;
}

- (PetAccessory *)asPetAccessory {
    PetAccessory *acc = [[PetAccessory alloc] init];
    acc.accessoryID = self.medicineID ?: @"";
    acc.name = self.title ?: @"";
    acc.nameEn = self.titleEn;
    acc.desc = self.medicineDescription ?: @"";
    acc.descEn = self.medicineDescriptionEn;
    acc.imageURLsArray = [self toDictionary][@"imageURLsArray"];
    acc.imageMeta = self.imageMeta;
    acc.revision = self.revision;
    acc.variantColorDictionary = self.variantColorDictionary;
    acc.price = @(self.price);
    acc.quantity = self.stockQuantity;
    acc.noStock = self.stockQuantity <= 0;
    acc.accessKindType = AccessTypePetMedicine;
    acc.ownerID = self.userId ?: (self.vetId ?: @"");
    acc.ownerType = @"partner";
    acc.showInAppMarket = self.isPublished && !self.isDisabled;
    acc.active = self.isPublished && !self.isDisabled;
    acc.createdAt = self.createdAt;

    acc.productFamilyId = self.productFamilyId;
    acc.variantSchemaVersion = self.variantSchemaVersion;
    acc.isVariant = self.isVariant;
    acc.isDefaultVariant = self.isDefaultVariant;
    acc.variantSortOrder = self.variantSortOrder;
    acc.selectedOptions = self.selectedOptions;
    acc.selectedOptionsSnapshot = self.selectedOptionsSnapshot;
    acc.variantCombinationKey = self.variantCombinationKey;
    acc.variantAxis = self.variantAxis;

    acc.sku = self.sku;
    acc.barcode = self.barcode;
    acc.wholesalePrice = self.wholesalePrice;
    [acc normalizeInventoryState];
    return acc;
}

- (void)applyVariantAccessory:(PetAccessory *)accessory {
    if (!accessory || ![accessory.accessoryID isEqualToString:self.medicineID]) return;
    self.productFamilyId = accessory.productFamilyId;
    self.variantSchemaVersion = accessory.variantSchemaVersion;
    self.isVariant = accessory.isVariant;
    self.isDefaultVariant = accessory.isDefaultVariant;
    self.variantSortOrder = accessory.variantSortOrder;
    self.revision = accessory.revision;
    self.variantColorDictionary = accessory.variantColorDictionary;
    self.selectedOptions = accessory.selectedOptions;
    self.selectedOptionsSnapshot = accessory.selectedOptionsSnapshot;
    self.variantCombinationKey = accessory.variantCombinationKey;
    self.variantAxis = accessory.variantAxis;
    self.sku = accessory.sku;
    self.barcode = accessory.barcode;
    self.price = accessory.price.doubleValue;
    self.wholesalePrice = accessory.wholesalePrice;
    self.stockQuantity = accessory.quantity;
    self.imageURLsArray = PPVetManagerStringArray(accessory.imageURLsArray);
    self.imageUrl = self.imageURLsArray.firstObject ?: @"";
    self.imageMeta = accessory.imageMeta;
}

- (NSString *)variantOptionDescription {
    PPProviderMarketItem *item = [PPProviderMarketItem fromDictionary:[self toDictionary] itemID:self.medicineID];
    return item.variantOptionLabel;
}

@end

@interface PPVetManager ()
@property (nonatomic, strong) FIRFirestore *db;
- (NSDictionary *)marketFieldsForMedicine:(PPVetMedicineModel *)medicine;
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
    meta.customMetadata = @{
        @"uploaded_by": [FIRAuth auth].currentUser.uid ?: @"",
        @"entity_type": @"veterinarian",
        @"entity_id": vetID ?: @""
    };

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
    meta.customMetadata = @{
        @"uploaded_by": [FIRAuth auth].currentUser.uid ?: @"",
        @"entity_type": @"medicine",
        @"entity_id": medicineID ?: @""
    };

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

    // The options studio stages a real item. Final Save must update that exact
    // item instead of creating a second medicine detached from its family.
    if (medicine.medicineID.length > 0) {
        [self updateMedicine:medicine image:image completion:completion];
        return;
    }
    NSString *uploadID = NSUUID.UUID.UUIDString;
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
        NSMutableDictionary *fields = [[self marketFieldsForMedicine:medicine] mutableCopy];
        fields[@"accessKindType"] = @4;
        fields[@"showInAppMarket"] = @(medicine.isPublished && !medicine.isDisabled);
        [[PPProviderMarketplaceManager sharedManager] createMarketItem:fields completion:^(BOOL success, NSString *itemID, NSString *message, NSError *error) {
            if (success && itemID.length > 0) {
                medicine.medicineID = itemID;
                medicine.revision = 1;
            }
            if (completion) completion(error ?: (success && itemID.length > 0 ? nil : PPVetError(500, kLang(@"ProInventory_SaveFailed"))));
        }];
    };

    if (image) {
        [self uploadMedicineImage:image medicineID:uploadID completion:saveBlock];
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
        [[PPProviderMarketplaceManager sharedManager] updateMarketItem:medicine.medicineID fields:[self marketFieldsForMedicine:medicine] completion:^(BOOL success, NSString *message, NSError *error) {
            if (success) medicine.revision += 1;
            if (completion) completion(error ?: (success ? nil : PPVetError(500, kLang(@"ProInventory_SaveFailed"))));
        }];
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
    [[PPProviderMarketplaceManager sharedManager] archiveMarketItemWithID:medicine.medicineID completion:^(BOOL success, NSString *message, NSError *error) {
        if (completion) completion(error ?: (success ? nil : PPVetError(500, kLang(@"ProInventory_SaveFailed"))));
    }];
}

- (NSDictionary *)marketFieldsForMedicine:(PPVetMedicineModel *)medicine {
    NSDictionary *model = [medicine toDictionary];
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"name", @"nameEn", @"desc", @"descEn", @"price", @"quantity", @"imageURLsArray", @"barcode", @"sku", @"wholesalePrice", @"dosageForm", @"strength", @"packSize", @"volume", @"batchNumber", @"category", @"animalTypes", @"vetId", @"blurHash", @"isPublished", @"isAvailable"]) {
        if (model[key]) fields[key] = model[key];
    }
    for (NSString *key in @[@"barcode", @"sku", @"dosageForm", @"strength", @"packSize", @"volume", @"batchNumber"]) {
        fields[key] = model[key] ?: @"";
    }
    fields[@"wholesalePrice"] = medicine.wholesalePrice ?: NSNull.null;
    if (medicine.expiryDate) fields[@"expiryDate"] = @(medicine.expiryDate.timeIntervalSince1970);
    if (medicine.medicineID.length > 0) fields[@"expectedRevision"] = @(medicine.revision);
    return fields.copy;
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
