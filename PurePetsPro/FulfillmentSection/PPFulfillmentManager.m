#import "PPFulfillmentManager.h"
#import "PPFulfillmentModel.h"
#import "PPFirebaseCompat.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const kColFulfillmentOrders = @"FulfillmentOrders";

static NSString *PPFulfillmentTrimmedString(NSString *value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
}

static NSError *PPFulfillmentManagerError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"PPFulfillmentManager"
                               code:code
                           userInfo:message.length > 0 ? @{NSLocalizedDescriptionKey: message} : nil];
}

static NSString *PPProviderFulfillmentCommandID(NSString *uid,
                                                NSString *fulfillmentID,
                                                NSString *expectedStatus,
                                                NSString *action,
                                                NSString *note) {
    NSString *basis = [@[ @"pure-pets-pro-provider-transition-v1",
                           PPFulfillmentTrimmedString(uid),
                           PPFulfillmentTrimmedString(fulfillmentID),
                           PPFulfillmentTrimmedString(expectedStatus).lowercaseString,
                           PPFulfillmentTrimmedString(action).lowercaseString,
                           PPFulfillmentTrimmedString(note) ] componentsJoinedByString:@"\0"];
    NSData *data = [basis dataUsingEncoding:NSUTF8StringEncoding] ?: NSData.data;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return [@"pro-provider-v1-" stringByAppendingString:hex];
}

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
    return [self observeFulfillmentsForOwnerID:ownerID stateHandler:^(NSArray<PPFulfillmentModel *> *fulfillments,
                                                                      NSError *error,
                                                                      __unused BOOL fromCache) {
        if (onChange) onChange(fulfillments, error);
    }];
}

- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                stateHandler:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments,
                                                                         NSError *error,
                                                                         BOOL fromCache))stateHandler {
    NSString *uid = PPFulfillmentTrimmedString(ownerID);
    NSString *authenticatedUID = PPFulfillmentTrimmedString([FIRAuth auth].currentUser.uid);
    if (uid.length == 0 || ![authenticatedUID isEqualToString:uid]) {
        if (stateHandler) stateHandler(nil, PPFulfillmentManagerError(401, kLang(@"DeliveryOrderUnavailable")), NO);
        return nil;
    }
    FIRQuery *q = [[[self collection]
        queryWhereField:@"ownerID" isEqualTo:uid]
        queryLimitedTo:50];

    return [q addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot *snap, NSError *error) {
        if (!stateHandler) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
            if (error || !snap) {
                NSError *resolvedError = error ?: [NSError errorWithDomain:@"PPFulfillmentManager"
                                                                       code:503
                                                                   userInfo:nil];
                stateHandler(nil, resolvedError, NO);
                return;
            }
            NSMutableArray<PPFulfillmentModel *> *models = [NSMutableArray array];
            for (FIRDocumentSnapshot *doc in snap.documents) {
                NSDictionary *data = PPSafeDict(doc.data);
                [models addObject:[PPFulfillmentModel modelFromDictionary:data fulfillmentID:doc.documentID]];
            }
            [models sortUsingComparator:^NSComparisonResult(PPFulfillmentModel *a, PPFulfillmentModel *b) {
                return [b.createdAt compare:a.createdAt];
            }];
            stateHandler([models copy], nil, snap.metadata.isFromCache);
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

- (id<FIRListenerRegistration>)observeFulfillmentWithID:(NSString *)fulfillmentID
                                                onChange:(void (^)(PPFulfillmentModel * _Nullable fulfillment,
                                                                     NSError * _Nullable error))onChange {
    return [self observeFulfillmentWithID:fulfillmentID
                             stateHandler:^(PPFulfillmentModel * _Nullable fulfillment,
                                            NSError * _Nullable error,
                                            __unused BOOL fromCache) {
        if (onChange) onChange(fulfillment, error);
    }];
}

- (id<FIRListenerRegistration>)observeFulfillmentWithID:(NSString *)fulfillmentID
                                            stateHandler:(void (^)(PPFulfillmentModel * _Nullable fulfillment,
                                                                     NSError * _Nullable error,
                                                                     BOOL fromCache))stateHandler {
    NSString *resolvedFulfillmentID = [fulfillmentID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *listenerUID = PPFulfillmentTrimmedString([FIRAuth auth].currentUser.uid);
    if (resolvedFulfillmentID.length == 0) {
        if (stateHandler) stateHandler(nil, PPFulfillmentManagerError(400, nil), NO);
        return nil;
    }
    if (listenerUID.length == 0) {
        if (stateHandler) stateHandler(nil, PPFulfillmentManagerError(401, kLang(@"DeliveryOrderUnavailable")), NO);
        return nil;
    }

    return [[self documentForID:resolvedFulfillmentID] addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:listenerUID]) return;
            if (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
                if (stateHandler) stateHandler(nil, error ?: PPFulfillmentManagerError(404, kLang(@"DeliveryOrderUnavailable")), NO);
                return;
            }
            PPFulfillmentModel *model = [PPFulfillmentModel modelFromDictionary:snapshot.data fulfillmentID:snapshot.documentID];
            if (stateHandler) stateHandler(model, nil, snapshot.metadata.isFromCache);
        });
    }];
}

- (void)fetchFulfillmentWithID:(NSString *)fulfillmentID
                     completion:(void (^)(PPFulfillmentModel * _Nullable fulfillment, NSError * _Nullable error))completion {
    NSString *resolvedFulfillmentID = [fulfillmentID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *requestUID = PPFulfillmentTrimmedString([FIRAuth auth].currentUser.uid);
    if (resolvedFulfillmentID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"PPFulfillmentManager" code:400 userInfo:nil]);
        }
        return;
    }
    if (requestUID.length == 0) {
        if (completion) completion(nil, PPFulfillmentManagerError(401, kLang(@"DeliveryOrderUnavailable")));
        return;
    }

    [[self documentForID:resolvedFulfillmentID] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:requestUID]) return;
            if (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
                if (completion) completion(nil, error);
                return;
            }
            PPFulfillmentModel *model = [PPFulfillmentModel modelFromDictionary:snapshot.data fulfillmentID:snapshot.documentID];
            if (completion) completion(model, nil);
        });
    }];
}

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                           note:(NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    [self fetchFulfillmentWithID:fulfillmentID completion:^(PPFulfillmentModel * _Nullable fulfillment, NSError * _Nullable error) {
        if (error || !fulfillment) {
            if (completion) completion(NO, error.localizedDescription, error);
            return;
        }
        [self performTransitionAction:action
                        fulfillmentID:fulfillment.fulfillmentID
                       expectedStatus:fulfillment.status
                            commandID:nil
                                 note:note
                           completion:completion];
    }];
}

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                 expectedStatus:(NSString *)expectedStatus
                      commandID:(NSString *)commandID
                           note:(NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    NSString *requestUID = PPFulfillmentTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *resolvedFulfillmentID = PPFulfillmentTrimmedString(fulfillmentID);
    NSString *resolvedAction = PPFulfillmentTrimmedString(action).lowercaseString;
    NSString *resolvedExpectedStatus = PPFulfillmentTrimmedString(expectedStatus).lowercaseString;
    NSString *resolvedNote = PPFulfillmentTrimmedString(note);
    if (requestUID.length == 0 || resolvedFulfillmentID.length == 0 || resolvedAction.length == 0 || resolvedExpectedStatus.length == 0) {
        NSError *validationError = PPFulfillmentManagerError(422, kLang(@"DeliveryStateChangedReload"));
        if (completion) completion(NO, validationError.localizedDescription, validationError);
        return;
    }
    NSString *resolvedCommandID = PPFulfillmentTrimmedString(commandID);
    if (resolvedCommandID.length == 0) {
        resolvedCommandID = PPProviderFulfillmentCommandID(requestUID,
                                                          resolvedFulfillmentID,
                                                          resolvedExpectedStatus,
                                                          resolvedAction,
                                                          resolvedNote);
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"providerTransitionFulfillment"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"fulfillmentID"] = resolvedFulfillmentID;
    payload[@"action"] = resolvedAction;
    payload[@"expectedStatus"] = resolvedExpectedStatus;
    payload[@"commandId"] = resolvedCommandID;
    if (resolvedNote.length > 0) payload[@"note"] = resolvedNote;

    NSLog(@"PPLAB Pro provider fulfillment command submit fulfillmentID=%@ action=%@ expectedStatus=%@ commandId=%@",
          resolvedFulfillmentID, resolvedAction, resolvedExpectedStatus, resolvedCommandID);

    [callable callWithObject:[payload copy] completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:requestUID]) return;
            if (error) {
                NSString *msg = error.localizedDescription;
                NSDictionary *details = error.userInfo[@"details"];
                if ([details isKindOfClass:[NSDictionary class]] && details[@"message"]) {
                    msg = details[@"message"];
                }
                if (completion) completion(NO, msg, error);
                return;
            }
            NSLog(@"PPLAB Pro provider fulfillment command accepted fulfillmentID=%@ action=%@ commandId=%@",
                  resolvedFulfillmentID, resolvedAction, resolvedCommandID);
            if (completion) completion(YES, nil, nil);
        });
    }];
}

@end
