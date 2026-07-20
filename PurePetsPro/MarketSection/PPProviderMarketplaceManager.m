#import "PPProviderMarketplaceManager.h"
#import "PPProviderMarketItem.h"
#import "PPFirebaseCompat.h"

static NSString * const PPMarketplaceErrorRecoverableUnavailableKey = @"PPMarketplaceErrorRecoverableUnavailable";

static NSString *PPMarketplaceMessageFromDetails(id details) {
    if ([details isKindOfClass:NSString.class]) {
        return PPSafeString(details);
    }
    if (![details isKindOfClass:NSDictionary.class]) {
        return @"";
    }
    NSDictionary *dictionary = (NSDictionary *)details;
    NSArray *candidateKeys = @[@"message", @"errorMessage", @"description", NSLocalizedDescriptionKey];
    for (NSString *key in candidateKeys) {
        NSString *value = PPSafeString(dictionary[key]);
        if (value.length > 0) {
            return value;
        }
    }
    id nested = dictionary[@"details"] ?: dictionary[@"error"];
    NSString *nestedMessage = PPMarketplaceMessageFromDetails(nested);
    return nestedMessage ?: @"";
}

static BOOL PPMarketplaceErrorLooksUnavailable(NSError *error, NSString *message) {
    NSString *lowercaseMessage = PPSafeString(message).lowercaseString;
    NSString *lowercaseLocalized = PPSafeString(error.localizedDescription).lowercaseString;
    if ([lowercaseMessage isEqualToString:@"not found"] ||
        [lowercaseMessage isEqualToString:@"not found."] ||
        [lowercaseLocalized isEqualToString:@"not found"] ||
        [lowercaseLocalized isEqualToString:@"not found."] ||
        [lowercaseMessage containsString:@"not_found"] ||
        [lowercaseLocalized containsString:@"not_found"] ||
        [lowercaseMessage containsString:@"not found"] ||
        [lowercaseLocalized containsString:@"not found"] ||
        [lowercaseMessage containsString:@"function"] && [lowercaseMessage containsString:@"not found"] ||
        [lowercaseLocalized containsString:@"function"] && [lowercaseLocalized containsString:@"not found"]) {
        return YES;
    }
    return [lowercaseMessage isEqualToString:@"user not found."] ||
           [lowercaseLocalized isEqualToString:@"user not found."];
}

@implementation PPMarketplaceBranch

+ (instancetype)branchFromDictionary:(NSDictionary *)dictionary {
    PPMarketplaceBranch *branch = [[self alloc] init];
    NSDictionary *name = [dictionary[@"name"] isKindOfClass:NSDictionary.class] ? dictionary[@"name"] : @{};
    branch.branchID = PPSafeString(dictionary[@"id"]);
    branch.code = PPSafeString(dictionary[@"code"]);
    branch.nameAr = PPSafeString(name[@"ar"]);
    branch.nameEn = PPSafeString(name[@"en"]);
    branch.address = PPSafeString(dictionary[@"address"]);
    branch.phone = PPSafeString(dictionary[@"phone"]);
    branch.active = dictionary[@"isActive"] == nil || [dictionary[@"isActive"] boolValue];
    branch.defaultBranch = [dictionary[@"isDefault"] boolValue];
    return branch;
}

- (NSString *)displayName {
    NSString *localized = Language.isRTL ? self.nameAr : self.nameEn;
    NSString *fallback = Language.isRTL ? self.nameEn : self.nameAr;
    if (localized.length > 0) return localized;
    if (fallback.length > 0) return fallback;
    return self.code.length > 0 ? self.code : self.branchID;
}

- (NSDictionary *)pickupAddressPayload {
    return @{
        @"branchId": self.branchID ?: @"",
        @"branchCode": self.code ?: @"",
        @"branchName": @{@"ar": self.nameAr ?: @"", @"en": self.nameEn ?: @""},
        @"displayName": self.address ?: @"",
        @"address": self.address ?: @"",
        @"phone": self.phone ?: @"",
    };
}

@end

@implementation PPProviderMarketplaceManager

+ (instancetype)sharedManager {
    static PPProviderMarketplaceManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[PPProviderMarketplaceManager alloc] initPrivate]; });
    return shared;
}

- (instancetype)initPrivate {
    if (self = [super init]) { }
    return self;
}

- (FIRCollectionReference *)col {
    return [[FIRFirestore firestore] collectionWithPath:@"petAccessories"];
}

- (void)callFunction:(NSString *)name payload:(NSDictionary *)payload completion:(void (^)(BOOL, NSString *, NSError *))completion {
    NSLog(@"[MarketPM] callFunction: %@ payload: %@", name, payload);
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:name];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { NSLog(@"[MarketPM] callFunction %@ error: %@", name, error); NSString *msg = error.localizedDescription; NSDictionary *details = error.userInfo[@"details"]; if ([details isKindOfClass:[NSDictionary class]] && details[@"message"]) msg = details[@"message"]; if (completion) completion(NO, msg, error); return; }
            NSLog(@"[MarketPM] callFunction %@ success", name);
            if (completion) completion(YES, nil, nil);
        });
    }];
}

- (void)callFunctionResult:(NSString *)name
                   payload:(NSDictionary *)payload
                completion:(void (^)(NSDictionary *result, NSError *error))completion {
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:name];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload ?: @{} completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSString *message = error.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic");
                id details = error.userInfo[@"details"];
                NSString *detailsMessage = PPMarketplaceMessageFromDetails(details);
                if (detailsMessage.length > 0) {
                    message = detailsMessage;
                }
                BOOL recoverableUnavailable = [name isEqualToString:@"providerListMarketplaceBranches"] &&
                                               PPMarketplaceErrorLooksUnavailable(error, message);
                if (recoverableUnavailable) {
                    message = kLang(@"MarketplaceBranches_LoadUnavailableSubtitle");
                }
                NSMutableDictionary *userInfo = [@{
                    NSLocalizedDescriptionKey: message,
                    NSUnderlyingErrorKey: error,
                    PPMarketplaceErrorRecoverableUnavailableKey: @(recoverableUnavailable)
                } mutableCopy];
                NSError *normalized = [NSError errorWithDomain:@"PurePetsPro.MarketplaceBranches"
                                                           code:error.code
                                                       userInfo:userInfo.copy];
                if (completion) completion(nil, normalized);
                return;
            }
            NSDictionary *data = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            if (completion) completion(data, nil);
        });
    }];
}
          

- (id<FIRListenerRegistration>)observeMarketItemsForOwnerID:(NSString *)ownerID onChange:(void (^)(NSArray<PPProviderMarketItem *> *, NSError *))onChange {
    NSLog(@"[MarketPM] observeMarketItems start ownerID=%@", ownerID);
    FIRQuery *q = [[self.col queryWhereField:@"ownerID" isEqualTo:ownerID ?: @""] queryLimitedTo:50];
    return [q addSnapshotListener:^(FIRQuerySnapshot *snap, NSError *error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { NSLog(@"[MarketPM] observeMarketItems error: %@", error); onChange(nil, error); return; }
            NSMutableArray *items = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snap.documents) {
                PPProviderMarketItem *item = [PPProviderMarketItem fromDictionary:PPSafeDict(doc.data) itemID:doc.documentID];
                if (item.accessKindType != 1 && item.accessKindType != 2) continue;
                [items addObject:item];
            }
            [items sortUsingComparator:^NSComparisonResult(PPProviderMarketItem *a, PPProviderMarketItem *b) { return [b.updatedAt compare:a.updatedAt]; }];
            NSLog(@"[MarketPM] observeMarketItems loaded %ld items (filtered to kind 1/2)", (long)items.count);
            onChange([items copy], nil);
        });
    }];
}

- (void)createMarketItem:(NSDictionary *)fields completion:(void (^)(BOOL, NSString *, NSString *, NSError *))completion {
    [self callFunction:@"providerCreateMarketItem" payload:fields completion:^(BOOL ok, NSString *msg, NSError *err) {
        if (completion) completion(ok, nil, msg, err);
    }];
}

- (void)updateMarketItem:(NSString *)itemID fields:(NSDictionary *)fields completion:(void (^)(BOOL, NSString *, NSError *))completion {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:fields];
    [p removeObjectForKey:@"accessKindType"];
    p[@"itemID"] = itemID ?: @"";
    [self callFunction:@"providerUpdateMarketItem" payload:p completion:completion];
}

- (void)updateMarketStock:(NSString *)itemID quantity:(NSInteger)quantity completion:(void (^)(BOOL, NSString *, NSError *))completion {
    [self callFunction:@"providerUpdateMarketStock" payload:@{@"itemID": itemID ?: @"", @"quantity": @(quantity)} completion:completion];
}

- (void)updateMarketOffer:(NSString *)itemID discountPercent:(double)dp discountAmount:(double)da hasOffer:(BOOL)ho completion:(void (^)(BOOL, NSString *, NSError *))completion {
    [self callFunction:@"providerUpdateMarketOffer" payload:@{@"itemID": itemID ?: @"", @"discountPercent": @(dp), @"discountAmount": @(da), @"hasOffer": @(ho)} completion:completion];
}

- (void)archiveMarketItemWithID:(NSString *)itemID completion:(void (^)(BOOL, NSString *, NSError *))completion {
    [self callFunction:@"providerArchiveMarketItem" payload:@{@"itemID": itemID ?: @""} completion:completion];
}

- (void)publishMarketItemWithID:(NSString *)itemID completion:(void (^)(BOOL, NSString *, NSError *))completion {
    [self callFunction:@"providerPublishMarketItem" payload:@{@"itemID": itemID ?: @""} completion:completion];
}

- (void)listMarketplaceBranchesWithCompletion:(void (^)(NSArray<PPMarketplaceBranch *> *, NSError *))completion {
    [self callFunctionResult:@"providerListMarketplaceBranches" payload:@{} completion:^(NSDictionary *result, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<PPMarketplaceBranch *> *branches = [NSMutableArray array];
        NSArray *items = [result[@"branches"] isKindOfClass:NSArray.class] ? result[@"branches"] : @[];
        for (NSDictionary *item in items) {
            if ([item isKindOfClass:NSDictionary.class]) {
                [branches addObject:[PPMarketplaceBranch branchFromDictionary:item]];
            }
        }
        if (completion) completion(branches.copy, nil);
    }];
}

- (void)saveMarketplaceBranchWithID:(NSString *)branchID
                             nameAr:(NSString *)nameAr
                             nameEn:(NSString *)nameEn
                            address:(NSString *)address
                              phone:(NSString *)phone
                          isDefault:(BOOL)isDefault
                         completion:(void (^)(BOOL, NSString *, NSError *))completion {
    NSMutableDictionary *payload = [@{
        @"nameAr": nameAr ?: @"",
        @"nameEn": nameEn ?: @"",
        @"address": address ?: @"",
        @"phone": phone ?: @"",
        @"isDefault": @(isDefault),
    } mutableCopy];
    if (branchID.length > 0) payload[@"branchId"] = branchID;
    [self callFunctionResult:@"providerSaveMarketplaceBranch" payload:payload completion:^(NSDictionary *result, NSError *error) {
        if (completion) completion(error == nil, error.localizedDescription, error);
    }];
}

- (void)setMarketplaceBranchID:(NSString *)branchID
                        active:(BOOL)active
                    completion:(void (^)(BOOL, NSString *, NSError *))completion {
    [self callFunctionResult:@"providerSetMarketplaceBranchActive"
                     payload:@{@"branchId": branchID ?: @"", @"isActive": @(active)}
                  completion:^(NSDictionary *result, NSError *error) {
        if (completion) completion(error == nil, error.localizedDescription, error);
    }];
}

@end
