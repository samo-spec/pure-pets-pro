//
//  PPAdoptPetManager.m
//  PurePetsPro
//

#import "PPAdoptPetManager.h"
#import "PPFirebaseCompat.h"

@implementation PPAdoptPetManager

+ (instancetype)sharedManager {
    static PPAdoptPetManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (NSString *)adoptPetsCollection {
    return @"adopt_pets";
}

- (void)fetchAdoptPetsStatus:(NSString *)status completion:(void(^)(NSArray<PPAdoptPetModel *> *, NSError *))completion {
    FIRCollectionReference *col = [FIRFirestore.firestore collectionWithPath:self.adoptPetsCollection];
    FIRQuery *query = col;
    if (status.length) {
        query = [query queryWhereField:@"status" isEqualTo:status];
    }
    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) { if (completion) completion(@[], error); return; }
        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data ?: @{};
            PPAdoptPetModel *model = [[PPAdoptPetModel alloc] initWithDictionary:data];
            model.petID = doc.documentID;
            [result addObject:model];
        }
        [result sortUsingComparator:^NSComparisonResult(PPAdoptPetModel *left, PPAdoptPetModel *right) {
            return [(right.createdAt ?: NSDate.distantPast) compare:(left.createdAt ?: NSDate.distantPast)];
        }];
        if (completion) completion(result.copy, nil);
    }];
}

- (void)createAdoptRequest:(PPAdoptPetModel *)pet completion:(void(^)(BOOL, NSError *))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.AdoptPets"
                                             code:FIRFirestoreErrorCodeUnauthenticated
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"Please login first")}];
        if (completion) completion(NO, error);
        return;
    }

    NSString *trimmedTitle = [pet.title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedTitle.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.AdoptPets"
                                             code:FIRFirestoreErrorCodeInvalidArgument
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"AdoptPro_Validation_TitleRequired")}];
        if (completion) completion(NO, error);
        return;
    }

    if (pet.ownerID.length == 0) {
        pet.ownerID = uid;
    }
    NSDate *now = NSDate.date;
    if (!pet.createdAt) {
        pet.createdAt = now;
    }
    pet.updatedAt = now;

    FIRCollectionReference *col = [FIRFirestore.firestore collectionWithPath:self.adoptPetsCollection];
    FIRDocumentReference *doc = pet.petID.length > 0 ? [col documentWithPath:pet.petID] : [col documentWithAutoID];
    pet.petID = doc.documentID;
    [doc setData:[pet toDictionary] merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error == nil, error);
    }];
}

- (void)updateAdoptStatus:(NSString *)petID status:(NSString *)status completion:(void(^)(BOOL, NSError *))completion {
    if (petID.length == 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"PurePetsPro.AdoptPets"
                                                           code:FIRFirestoreErrorCodeInvalidArgument
                                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"AdoptPro_Error_MissingListing")}]);
        return;
    }
    NSString *normalized = status.length > 0 ? status : @"available";
    BOOL adopted = [normalized isEqualToString:@"adopted"];
    BOOL hidden = [normalized isEqualToString:@"hidden"];
    FIRDocumentReference *doc = [[FIRFirestore.firestore collectionWithPath:self.adoptPetsCollection] documentWithPath:petID];
    [doc setData:@{
        @"status": normalized,
        @"isAdopted": @(adopted),
        @"visibility": @(hidden ? 1 : 0),
        @"updatedAt": [FIRTimestamp timestampWithDate:NSDate.date]
    } merge:YES completion:^(NSError * _Nullable error) {
        if (completion) completion(error == nil, error);
    }];
}

- (void)deleteAdoptRequest:(NSString *)petID completion:(void(^)(BOOL, NSError *))completion {
    if (petID.length == 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"PurePetsPro.AdoptPets"
                                                           code:FIRFirestoreErrorCodeInvalidArgument
                                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"AdoptPro_Error_MissingListing")}]);
        return;
    }
    FIRDocumentReference *doc = [[FIRFirestore.firestore collectionWithPath:self.adoptPetsCollection] documentWithPath:petID];
    [doc deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error == nil, error);
    }];
}

- (id<FIRListenerRegistration>)observeAllAdoptPets:(void(^)(NSArray<PPAdoptPetModel *> * _Nullable pets, NSError * _Nullable error))onChange {
    FIRCollectionReference *col = [FIRFirestore.firestore collectionWithPath:self.adoptPetsCollection];
    return [col addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { onChange(nil, error); return; }
            NSMutableArray *result = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                NSDictionary *data = doc.data ?: @{};
                PPAdoptPetModel *model = [[PPAdoptPetModel alloc] initWithDictionary:data];
                model.petID = doc.documentID;
                [result addObject:model];
            }
            [result sortUsingComparator:^NSComparisonResult(PPAdoptPetModel *left, PPAdoptPetModel *right) {
                return [(right.createdAt ?: NSDate.distantPast) compare:(left.createdAt ?: NSDate.distantPast)];
            }];
            onChange(result.copy, nil);
        });
    }];
}

@end
