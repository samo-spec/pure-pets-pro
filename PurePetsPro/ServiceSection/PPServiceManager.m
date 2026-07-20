//
//  PPServiceManager.m
//  PurePetsPro
//
//  Provider-scoped service operations against "serviceOffers" Firestore collection.
//

#import "PPServiceManager.h"
#import "PPServiceModel.h"
#import "PPFirebaseCompat.h"

static NSString * const kColServices = @"serviceOffers";

static NSError *PPServiceError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"pp.service.manager"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Service operation failed"}];
}

@interface PPServiceManager ()
@property (nonatomic, strong) FIRFirestore *db;
@end

@implementation PPServiceManager

+ (instancetype)sharedManager {
    static PPServiceManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPServiceManager alloc] init];
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
    return [self.db collectionWithPath:kColServices];
}

#pragma mark - Mapping

- (PPServiceModel *)_mapDoc:(FIRDocumentSnapshot *)doc {
    return [PPServiceModel fromDictionary:doc.data ?: @{} withID:doc.documentID];
}

- (NSArray<PPServiceModel *> *)_mapDocs:(NSArray<FIRDocumentSnapshot *> *)docs {
    NSMutableArray<PPServiceModel *> *arr = [NSMutableArray arrayWithCapacity:docs.count];
    for (FIRDocumentSnapshot *doc in docs) {
        [arr addObject:[self _mapDoc:doc]];
    }
    return arr;
}

#pragma mark - READ (Provider-Scoped)

- (id<FIRListenerRegistration>)observeServicesForOwnerID:(NSString *)ownerID onChange:(PPServiceArrayBlock)onChange {
    FIRQuery *q = [[self col] queryWhereField:@"serviceOwnerID" isEqualTo:ownerID ?: @""];
    return [q addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            onChange(error ? nil : [self _mapDocs:snap.documents], error);
        });
    }];
}

- (void)fetchServiceByID:(NSString *)serviceID completion:(void (^)(PPServiceModel * _Nullable, NSError * _Nullable))completion {
    if (serviceID.length == 0) {
        if (completion) completion(nil, PPServiceError(400, @"Service ID is required."));
        return;
    }
    [[[self col] documentWithPath:serviceID] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        if (error) { completion(nil, error); return; }
        if (!snap.exists) { completion(nil, PPServiceError(404, @"Service not found.")); return; }
        completion([self _mapDoc:snap], nil);
    }];
}

#pragma mark - WRITE (Provider-Owned Only)

- (void)addService:(PPServiceModel *)service image:(UIImage *)image completion:(PPServiceVoidBlock)completion {
    if (!service) {
        if (completion) completion(PPServiceError(400, @"Service model is required."));
        return;
    }

    NSString *docID = [[NSUUID UUID] UUIDString];
    service.serviceID = docID;

    if (!service.createdAt) {
        service.createdAt = [NSDate date];
    }

    // Build the provider fields dict + creation-time extras
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];
    data[@"createdAt"]          = service.createdAt;
    data[@"timestamp"]          = service.createdAt;
    data[@"isDeleted"]          = @NO;
    data[@"verificationStatus"] = @"pending";

    void (^saveBlock)(NSString *) = ^(NSString *logoURL) {
        if (logoURL.length) data[@"imageURL"] = logoURL;
        [[[self col] documentWithPath:docID] setData:data completion:completion];
    };

    if (image) {
        [self uploadImage:image serviceID:docID completion:saveBlock];
    } else {
        saveBlock(@"");
    }
}

- (void)updateService:(PPServiceModel *)service image:(UIImage *)image completion:(PPServiceVoidBlock)completion {
    if (!service || service.serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Valid service model with ID is required."));
        return;
    }

    // Only write provider-controlled fields (never overwrites admin/subscription fields)
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];

    void (^updateBlock)(NSString *) = ^(NSString *logoURL) {
        if (logoURL.length) data[@"imageURL"] = logoURL;
        [[[self col] documentWithPath:service.serviceID] updateData:data completion:completion];
    };

    if (image) {
        [self uploadImage:image serviceID:service.serviceID completion:updateBlock];
    } else {
        updateBlock(@"");
    }
}

- (void)toggleAvailability:(BOOL)available forServiceID:(NSString *)serviceID completion:(PPServiceVoidBlock)completion {
    if (serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Service ID is missing."));
        return;
    }
    [[[self col] documentWithPath:serviceID]
     updateData:@{
        @"isAvailable": @(available),
        @"updatedAt": [FIRTimestamp timestamp]
    }
     completion:completion];
}

- (void)deleteService:(PPServiceModel *)service completion:(PPServiceVoidBlock)completion {
    if (!service || service.serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Service ID is required for deletion."));
        return;
    }
    [[[self col] documentWithPath:service.serviceID] updateData:@{
        @"isDeleted": @YES,
        @"archivedAt": [NSDate date],
        @"archivedBy": [FIRAuth auth].currentUser.uid ?: @"",
        @"updatedAt": [FIRTimestamp timestamp]
    } completion:completion];
}

#pragma mark - Image Upload

- (void)uploadImage:(UIImage *)image serviceID:(NSString *)serviceID completion:(void (^)(NSString *))completion {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.85);
    if (!imageData) {
        if (completion) completion(@"");
        return;
    }
    NSString *path = [NSString stringWithFormat:@"services/%@.jpg", serviceID];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];

    // Explicit JPEG contentType for Storage security rules
    FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
    meta.contentType = @"image/jpeg";

    [ref putData:imageData metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            DLog(@"[PPServiceManager] image upload error: %@", error.localizedDescription);
            if (completion) completion(@"");
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (completion) completion(URL.absoluteString ?: @"");
        }];
    }];
}

@end
