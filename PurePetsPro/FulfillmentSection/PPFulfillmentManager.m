#import "PPFulfillmentManager.h"
#import "PPFulfillmentModel.h"
#import "PPFirebaseCompat.h"

static NSString * const kColFulfillmentOrders = @"FulfillmentOrders";

@interface PPFulfillmentManager ()
@property (nonatomic, strong) FIRFirestore *db;
@end

@implementation PPFulfillmentManager

+ (instancetype)sharedManager {
    static PPFulfillmentManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[PPFulfillmentManager alloc] initPrivate]; });
    return shared;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (FIRCollectionReference *)collection {
    return [self.db collectionWithPath:kColFulfillmentOrders];
}

- (FIRDocumentReference *)documentForID:(NSString *)fulfillmentID {
    return [[self collection] documentWithPath:fulfillmentID ?: @""];
}

- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                    onChange:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error))onChange {
    NSString *uid = ownerID ?: @"";
    FIRQuery *q = [[[[self collection]
        queryWhereField:@"ownerID" isEqualTo:uid]
        queryWhereField:@"ownerType" isEqualTo:@"partner"]
        queryLimitedTo:50];

    return [q addSnapshotListener:^(FIRQuerySnapshot *snap, NSError *error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { onChange(nil, error); return; }
            NSMutableArray<PPFulfillmentModel *> *models = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snap.documents) {
                NSDictionary *data = PPSafeDict(doc.data);
                [models addObject:[PPFulfillmentModel modelFromDictionary:data fulfillmentID:doc.documentID]];
            }
            [models sortUsingComparator:^NSComparisonResult(PPFulfillmentModel *a, PPFulfillmentModel *b) {
                return [b.createdAt compare:a.createdAt];
            }];
            onChange([models copy], nil);
        });
    }];
}

- (id<FIRListenerRegistration>)observeEventsForFulfillmentID:(NSString *)fulfillmentID
                                                    onChange:(void (^)(NSArray<NSDictionary *> *events))onChange {
    if (!onChange) return nil;
    FIRDocumentReference *docRef = [self documentForID:fulfillmentID];
    FIRQuery *q = [[[docRef collectionWithPath:@"events"] queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:50];
    return [q addSnapshotListener:^(FIRQuerySnapshot *snap, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { onChange(@[]); return; }
            NSMutableArray<NSDictionary *> *events = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snap.documents) {
                NSMutableDictionary *entry = [PPSafeDict(doc.data) mutableCopy];
                entry[@"eventId"] = doc.documentID;
                [events addObject:[entry copy]];
            }
            onChange([events copy]);
        });
    }];
}

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                           note:(NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"providerTransitionFulfillment"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"fulfillmentID"] = fulfillmentID ?: @"";
    payload[@"action"] = action ?: @"";
    if (note.length > 0) payload[@"note"] = note;

    [callable callWithObject:[payload copy] completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSString *msg = error.localizedDescription;
                NSDictionary *details = error.userInfo[@"details"];
                if ([details isKindOfClass:[NSDictionary class]] && details[@"message"]) {
                    msg = details[@"message"];
                }
                if (completion) completion(NO, msg, error);
                return;
            }
            if (completion) completion(YES, nil, nil);
        });
    }];
}

@end
