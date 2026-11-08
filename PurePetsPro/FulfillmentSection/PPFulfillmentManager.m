#import "PPFulfillmentManager.h"
#import "PPFulfillmentModel.h"
#import "PPFirebaseCompat.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const kColFulfillmentOrders = @"FulfillmentOrders";
NSString * const PPFulfillmentOfficialOwnerUID = @"PUIDPOFFICILAL20262214";

// Infra FULFILLMENT_STATUS. The platform lane names every status so it is
// served by the deployed (ownerID, ownerType, status, createdAt) index.
static NSArray<NSString *> *PPFulfillmentCanonicalStatuses(void) {
    return @[@"new_request", @"accepted", @"rejected", @"preparing", @"ready_for_pickup",
             @"delivery_requested", @"delivery_assigned", @"awaiting_handover", @"handed_over",
             @"in_transit", @"delivered", @"payment_pending", @"payment_confirmed", @"completed",
             @"cancelled", @"failed", @"returned"];
}

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

// Separate namespace so an official command never collides with a provider one.
static NSString *PPOfficialFulfillmentCommandID(NSString *uid,
                                                NSString *fulfillmentID,
                                                NSString *expectedStatus,
                                                NSString *action,
                                                NSString *note) {
    NSString *providerID = PPProviderFulfillmentCommandID([@"official\0" stringByAppendingString:PPFulfillmentTrimmedString(uid)],
                                                          fulfillmentID, expectedStatus, action, note);
    return [@"pro-official-v1-" stringByAppendingString:[providerID substringFromIndex:@"pro-provider-v1-".length]];
}

// One owner for account/profile watches and all bounded child query pages.
// Direct legacy notifications/detail reads remain supported by document Rules;
// missing providerProfileID fields cannot be safely discovered by this query.
@interface PPProviderFulfillmentQueue : NSObject <FIRListenerRegistration>
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, copy) void (^handler)(NSArray<PPFulfillmentModel *> *, NSError *, BOOL);
@property (nonatomic, strong) id<FIRListenerRegistration> accountListener;
@property (nonatomic, strong) id<FIRListenerRegistration> profilesListener;
@property (nonatomic, strong) id authHandle;
@property (nonatomic, strong) NSDictionary *account;
@property (nonatomic, strong) NSArray<FIRDocumentSnapshot *> *profiles;
@property (nonatomic, strong) NSMutableArray<id<FIRListenerRegistration>> *children;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FIRQuerySnapshot *> *snapshots;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSError *> *errors;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) NSInteger limit;
@property (nonatomic) BOOL removed;
@property (nonatomic) BOOL authorityFromCache;
@property (nonatomic) BOOL accountFromCache;
@property (nonatomic) BOOL profilesFromCache;
- (void)start;
- (void)loadMore;
- (BOOL)hasMore;
@end

@implementation PPProviderFulfillmentQueue
- (BOOL)sessionCurrent {
    return !self.removed && [[FIRAuth auth].currentUser.uid isEqualToString:self.uid] &&
        ![FIRAuth auth].currentUser.isAnonymous;
}
- (void)clearQueries {
    self.generation += 1;
    for (id<FIRListenerRegistration> child in self.children) [child remove];
    self.children = [NSMutableArray array];
    self.snapshots = [NSMutableDictionary dictionary];
    self.errors = [NSMutableDictionary dictionary];
}
- (void)remove {
    if (self.removed) return;
    self.removed = YES;
    [self clearQueries];
    [self.accountListener remove]; self.accountListener = nil;
    [self.profilesListener remove]; self.profilesListener = nil;
    if (self.authHandle) [[FIRAuth auth] removeAuthStateDidChangeListener:self.authHandle];
    self.authHandle = nil;
    self.handler = nil;
}
- (void)fail:(NSError *)error {
    [self clearQueries];
    if (self.handler) self.handler(@[], error ?: PPFulfillmentManagerError(403, kLang(@"Fulfillment_LoadError")), NO);
}
- (BOOL)subscriptionActive:(id)value {
    if (!value) return YES; // Infra compatibility for approved profiles without subscriptions.
    NSString *status = [value isKindOfClass:NSString.class] ? value :
        ([value isKindOfClass:NSDictionary.class] ? value[@"status"] : nil);
    return ([value isKindOfClass:NSDictionary.class] && !status) ||
        [@[@"active", @"approved", @"trial"] containsObject:status ?: @""];
}
- (BOOL)allowsProviderType:(NSString *)type {
    NSDictionary *features = PPSafeDict(self.account[@"features"]);
    NSDictionary *keys = @{@"marketplace": @[@"production", @"canAccessProviderMarketplace"],
        @"production": @[@"production"], @"pharmacy": @[@"pharmacy", @"canPharmacy"],
        @"service": @[@"serviceProvider", @"canOfferServices"], @"vet": @[@"veterinarians", @"canVet"],
        @"delivery_company": @[@"delivery", @"canDeliveryCompany"]};
    NSArray *featureKeys = keys[type];
    BOOL enabled = NO;
    for (NSString *key in featureKeys) if ([features[key] isEqual:@YES]) enabled = YES;
    NSDictionary *subscriptions = PPSafeDict(self.account[@"subscriptions"]);
    return enabled && [self subscriptionActive:self.account[@"subscription"]] &&
        [self subscriptionActive:subscriptions[@"pro"]] &&
        [self subscriptionActive:subscriptions[type]] &&
        [self subscriptionActive:subscriptions[featureKeys.firstObject]];
}
- (void)rebuild {
    if (![self sessionCurrent] || !self.account || !self.profiles) return;
    [self clearQueries];
    NSDictionary *restrictions = PPSafeDict(self.account[@"restrictions"]);
    NSString *status = PPSafeString(self.account[@"status"]);
    NSString *accountStatus = PPSafeString(self.account[@"accountStatus"]);
    BOOL active = [PPSafeString(self.account[@"accountType"]) isEqualToString:@"user"] &&
        [@[@"active", @"approved"] containsObject:status] &&
        (accountStatus.length == 0 || [@[@"active", @"approved"] containsObject:accountStatus]) &&
        ![restrictions[@"purchaseBlocked"] isEqual:@YES] && ![restrictions[@"withdrawalBlocked"] isEqual:@YES] &&
        ![self.account[@"isBlocked"] isEqual:@YES] && ![self.account[@"blocked"] isEqual:@YES];
    for (NSString *flag in @[@"banned", @"deactivated", @"isDeleted", @"deleted", @"isSuspended", @"suspended", @"isDisabled", @"disabled"]) {
        if ([self.account[flag] isEqual:@YES]) active = NO;
    }
    // The official account is a staff identity, so it never passes the partner
    // account gate above. It owns every platform fulfillment; Firestore Rules
    // authorize that lane from its staff_users record.
    BOOL officialLane = [self.uid isEqualToString:PPFulfillmentOfficialOwnerUID];
    if (!active && !officialLane) { [self fail:nil]; return; }
    // Drop previously authorized rows while fresh authority queries settle.
    if (self.handler) self.handler(@[], nil, YES);
    self.authorityFromCache = self.accountFromCache || self.profilesFromCache;
    NSUInteger generation = self.generation;
    __weak typeof(self) weakSelf = self;
    void (^listen)(NSString *, FIRQuery *) = ^(NSString *key, FIRQuery *query) {
        id<FIRListenerRegistration> child = [query addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot *snapshot, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![self sessionCurrent] || generation != self.generation) return;
            if (error || !snapshot) {
                [self.snapshots removeObjectForKey:key];
                self.errors[key] = error ?: PPFulfillmentManagerError(503, kLang(@"Fulfillment_LoadError"));
            } else {
                self.snapshots[key] = snapshot;
                [self.errors removeObjectForKey:key];
            }
            [self emit];
        }];
        [self.children addObject:child];
    };
    if (officialLane) {
        FIRQuery *platform = [[[[[[self.db collectionWithPath:kColFulfillmentOrders]
            queryWhereField:@"ownerID" isEqualTo:self.uid]
            queryWhereField:@"ownerType" isEqualTo:@"platform"]
            queryWhereField:@"status" in:PPFulfillmentCanonicalStatuses()]
            queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:self.limit];
        listen(@"official-platform", platform);
    }
    for (FIRDocumentSnapshot *profile in (active ? self.profiles : @[])) {
        NSDictionary *data = profile.data;
        NSString *type = PPSafeString(data[@"providerType"]);
        NSDictionary *plan = PPSafeDict(data[@"planSnapshot"]);
        if (![PPSafeString(data[@"userId"]) isEqualToString:self.uid] ||
            ![PPSafeString(data[@"status"]) isEqualToString:@"active"] ||
            PPFulfillmentTrimmedString(data[@"planId"]).length == 0 ||
            (plan[@"providerType"] && ![plan[@"providerType"] isEqual:type]) || ![self allowsProviderType:type]) continue;
        FIRQuery *query = [[[[[[[self.db collectionWithPath:kColFulfillmentOrders]
            queryWhereField:@"ownerID" isEqualTo:self.uid]
            queryWhereField:@"ownerType" isEqualTo:@"partner"]
            queryWhereField:@"providerType" isEqualTo:type]
            queryWhereField:@"providerProfileID" isEqualTo:profile.documentID]
            queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:self.limit];
        listen(profile.documentID, query);
    }
    if (self.children.count == 0 && self.handler) self.handler(@[], nil, self.authorityFromCache);
}
- (void)emit {
    if (![self sessionCurrent] || !self.handler) return;
    if (self.snapshots.count + self.errors.count < self.children.count) return;
    NSMutableDictionary<NSString *, PPFulfillmentModel *> *models = [NSMutableDictionary dictionary];
    BOOL fromCache = self.authorityFromCache;
    for (FIRQuerySnapshot *snapshot in self.snapshots.allValues) {
        fromCache = fromCache || snapshot.metadata.isFromCache;
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            models[document.documentID] = [PPFulfillmentModel modelFromDictionary:document.data fulfillmentID:document.documentID];
        }
    }
    NSArray *ordered = [models.allValues sortedArrayUsingComparator:^NSComparisonResult(PPFulfillmentModel *a, PPFulfillmentModel *b) {
        NSComparisonResult date = [(b.createdAt ?: NSDate.distantPast) compare:(a.createdAt ?: NSDate.distantPast)];
        return date == NSOrderedSame ? [b.fulfillmentID compare:a.fulfillmentID] : date;
    }];
    self.handler(ordered, self.errors.allValues.firstObject, fromCache);
}
- (BOOL)hasMore {
    if (self.errors.count || self.snapshots.count < self.children.count) return NO;
    for (FIRQuerySnapshot *snapshot in self.snapshots.allValues) if (snapshot.documents.count >= self.limit) return YES;
    return NO;
}
- (void)loadMore {
    if (![self hasMore] || ![self sessionCurrent]) return;
    self.limit += 50;
    [self rebuild];
}
- (void)start {
    self.limit = 50;
    [self clearQueries];
    __weak typeof(self) weakSelf = self;
    self.authHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.removed || [self sessionCurrent]) return;
        if (self.handler) self.handler(@[], PPFulfillmentManagerError(401, kLang(@"Fulfillment_LoadError")), NO);
        [self remove];
    }];
    self.accountListener = [[[self.db collectionWithPath:@"UsersCol"] documentWithPath:self.uid]
        addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![self sessionCurrent]) return;
            if (error || !snapshot.exists) { self.account = nil; [self fail:error]; return; }
            self.account = snapshot.data;
            self.accountFromCache = snapshot.metadata.isFromCache;
            [self rebuild];
        }];
    FIRQuery *profiles = [[[[self.db collectionWithPath:@"providerProfiles"]
        queryWhereField:@"userId" isEqualTo:self.uid] queryWhereField:@"status" isEqualTo:@"active"]
        queryWhereField:@"providerType" in:@[@"marketplace", @"production", @"pharmacy", @"service", @"vet", @"delivery_company"]];
    self.profilesListener = [profiles addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self sessionCurrent]) return;
        if (error || !snapshot) { self.profiles = nil; [self fail:error]; return; }
        self.profiles = snapshot.documents;
        self.profilesFromCache = snapshot.metadata.isFromCache;
        [self rebuild];
    }];
}
- (void)dealloc { [self remove]; }
@end

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
    PPProviderFulfillmentQueue *queue = [PPProviderFulfillmentQueue new];
    queue.uid = uid;
    queue.db = self.db;
    queue.handler = stateHandler;
    [queue start];
    return queue;
}

- (BOOL)canLoadMoreFulfillmentsForListener:(id<FIRListenerRegistration>)listener {
    return [listener isKindOfClass:PPProviderFulfillmentQueue.class] && [(PPProviderFulfillmentQueue *)listener hasMore];
}

- (void)loadMoreFulfillmentsForListener:(id<FIRListenerRegistration>)listener {
    if ([listener isKindOfClass:PPProviderFulfillmentQueue.class]) [(PPProviderFulfillmentQueue *)listener loadMore];
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
    [self pp_performTransitionWithCallable:@"providerTransitionFulfillment"
                                    action:action
                             fulfillmentID:fulfillmentID
                            expectedStatus:expectedStatus
                                 commandID:commandID
                                      note:note
                                completion:completion];
}

- (void)performOfficialPlatformTransitionAction:(NSString *)action
                                  fulfillmentID:(NSString *)fulfillmentID
                                 expectedStatus:(NSString *)expectedStatus
                                           note:(NSString *)note
                                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion {
    NSString *requestUID = PPFulfillmentTrimmedString([FIRAuth auth].currentUser.uid);
    NSString *resolvedNote = PPFulfillmentTrimmedString(note);
    if (![requestUID isEqualToString:PPFulfillmentOfficialOwnerUID]) {
        NSError *error = PPFulfillmentManagerError(403, kLang(@"DeliveryStateChangedReload"));
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }
    if (resolvedNote.length < 3) {
        NSError *error = PPFulfillmentManagerError(422, kLang(@"Fulfillment_StaffNoteTooShort"));
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }
    NSString *commandID = PPOfficialFulfillmentCommandID(requestUID,
                                                        PPFulfillmentTrimmedString(fulfillmentID),
                                                        PPFulfillmentTrimmedString(expectedStatus).lowercaseString,
                                                        PPFulfillmentTrimmedString(action).lowercaseString,
                                                        resolvedNote);
    [self pp_performTransitionWithCallable:@"staffTransitionOfficialFulfillment"
                                    action:action
                             fulfillmentID:fulfillmentID
                            expectedStatus:expectedStatus
                                 commandID:commandID
                                      note:resolvedNote
                                completion:completion];
}

+ (BOOL)isOfficialPlatformFulfillment:(PPFulfillmentModel *)fulfillment forUID:(NSString *)uid {
    NSString *accountUID = PPFulfillmentTrimmedString(uid);
    return [accountUID isEqualToString:PPFulfillmentOfficialOwnerUID] &&
        [PPFulfillmentTrimmedString(fulfillment.ownerType).lowercaseString isEqualToString:@"platform"] &&
        [PPFulfillmentTrimmedString(fulfillment.ownerID) isEqualToString:accountUID];
}

- (void)pp_performTransitionWithCallable:(NSString *)callableName
                                  action:(NSString *)action
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
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:callableName];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"fulfillmentID"] = resolvedFulfillmentID;
    payload[@"action"] = resolvedAction;
    payload[@"expectedStatus"] = resolvedExpectedStatus;
    payload[@"commandId"] = resolvedCommandID;
    if (resolvedNote.length > 0) payload[@"note"] = resolvedNote;

    NSLog(@"PPLAB Pro fulfillment command submit callable=%@ fulfillmentID=%@ action=%@ expectedStatus=%@ commandId=%@",
          callableName, resolvedFulfillmentID, resolvedAction, resolvedExpectedStatus, resolvedCommandID);

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
