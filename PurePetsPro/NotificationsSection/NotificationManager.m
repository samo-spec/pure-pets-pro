//
//  NotificationManager.m
//  PurePetsPro
//
//  Created by Mohammed Ahmed on 24/08/2025.
//

#import "NotificationManager.h"
#import "PPNotificationsManager.h"
#import "PPStaffAuth.h"

#import "PPFirebaseCompat.h"
@import FirebaseFunctions;

@interface PPCombinedNotificationListener : NSObject <FIRListenerRegistration>
@property (nonatomic, strong) NSMutableArray<id<FIRListenerRegistration>> *registrations;
@property (nonatomic, assign, getter=isRemoved) BOOL removed;
- (instancetype)initWithRegistrations:(NSArray<id<FIRListenerRegistration>> *)registrations;
- (BOOL)addRegistration:(id<FIRListenerRegistration>)registration;
@end

@implementation PPCombinedNotificationListener

- (instancetype)initWithRegistrations:(NSArray<id<FIRListenerRegistration>> *)registrations {
    self = [super init];
    if (self) {
        _registrations = [NSMutableArray arrayWithArray:registrations ?: @[]];
    }
    return self;
}

- (BOOL)addRegistration:(id<FIRListenerRegistration>)registration {
    if (!registration) return NO;
    @synchronized (self) {
        if (self.isRemoved) {
            [registration remove];
            return NO;
        }
        [self.registrations addObject:registration];
        return YES;
    }
}

- (void)remove {
    NSArray<id<FIRListenerRegistration>> *registrations = nil;
    @synchronized (self) {
        if (self.isRemoved) return;
        self.removed = YES;
        registrations = self.registrations.copy;
        [self.registrations removeAllObjects];
    }
    for (id<FIRListenerRegistration> registration in registrations) {
        [registration remove];
    }
}

@end

@interface NotificationManager ()
@property (nonatomic, strong) NSHashTable<PPCombinedNotificationListener *> *activeInboxListeners;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NotificationModel *> *> *cachedUserInboxItems;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NotificationModel *> *> *cachedStaffInboxItems;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *confirmedStaffInboxApplicability;
+ (NSError *)pp_notificationErrorWithMessage:(NSString *)message;
+ (NSError *)pp_cacheOnlyNotificationErrorForSource:(NSString *)source;
- (id<FIRListenerRegistration> _Nullable)pp_observeInboxForUser:(NSString *)uid
                                           waitsForInitialPair:(BOOL)waitsForInitialPair
                                                  stateHandler:(PPInboxObserverStateHandler)handler;
@end

@implementation NotificationManager

+ (instancetype)shared {
    static NotificationManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [NotificationManager new];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _activeInboxListeners = [NSHashTable weakObjectsHashTable];
        _cachedUserInboxItems = [NSMutableDictionary dictionary];
        _cachedStaffInboxItems = [NSMutableDictionary dictionary];
        _confirmedStaffInboxApplicability = [NSMutableDictionary dictionary];
    }
    return self;
}

- (FIRCollectionReference *)adminCollection {
    return [[[[FIRFirestore firestore] collectionWithPath:@"admin"]
             documentWithPath:@"notifications"]
            collectionWithPath:@"items"];
}

- (FIRCollectionReference *)staffInboxForUser:(NSString *)uid {
    NSString *safeUID = [uid isKindOfClass:NSString.class]
      ? [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
      : @"";
    if (safeUID.length == 0) return nil;
    return [[[[FIRFirestore firestore] collectionWithPath:@"staff_users"]
             documentWithPath:safeUID]
            collectionWithPath:@"inbox"];
}

- (FIRCollectionReference *)inboxForUser:(NSString *)uid {
    FIRCollectionReference *ref = [UsrMgrCls inboxRefForUID:uid];
    if (ref) return ref;
    return [UsrMgrCls inboxRefForCurrentUser];
}

- (NSArray<NotificationModel *> *)mergedNotificationsWithUserItems:(NSArray<NotificationModel *> *)userItems
                                                        staffItems:(NSArray<NotificationModel *> *)staffItems {
    NSMutableDictionary<NSString *, NotificationModel *> *byKey = [NSMutableDictionary dictionary];
    for (NotificationModel *item in userItems ?: @[]) {
        if (![item isKindOfClass:NotificationModel.class]) continue;
        NSString *key = [NSString stringWithFormat:@"%@::%@", item.sourcePath ?: @"UsersCol", item.nid ?: @""];
        byKey[key] = item;
    }
    for (NotificationModel *item in staffItems ?: @[]) {
        if (![item isKindOfClass:NotificationModel.class]) continue;
        NSString *key = [NSString stringWithFormat:@"%@::%@", item.sourcePath ?: @"staff_users", item.nid ?: @""];
        byKey[key] = item;
    }

    NSArray<NotificationModel *> *merged = byKey.allValues;
    return [merged sortedArrayUsingComparator:^NSComparisonResult(NotificationModel * _Nonnull lhs, NotificationModel * _Nonnull rhs) {
        NSDate *leftDate = lhs.createdAt ?: [NSDate distantPast];
        NSDate *rightDate = rhs.createdAt ?: [NSDate distantPast];
        return [rightDate compare:leftDate];
    }];
}

#pragma mark - Reads

- (id<FIRListenerRegistration>)observeInboxForUser:(NSString *)uid
                                           handler:(void (^)(NSArray<NotificationModel *> *))handler {
    return [self pp_observeInboxForUser:uid waitsForInitialPair:NO stateHandler:^(NSArray<NotificationModel *> *items, __unused NSError *error) {
        if (handler) handler(items);
    }];
}

- (id<FIRListenerRegistration>)observeInboxForUser:(NSString *)uid
                                       stateHandler:(PPInboxObserverStateHandler)handler {
    return [self pp_observeInboxForUser:uid waitsForInitialPair:YES stateHandler:handler];
}

- (id<FIRListenerRegistration>)pp_observeInboxForUser:(NSString *)uid
                                  waitsForInitialPair:(BOOL)waitsForInitialPair
                                         stateHandler:(PPInboxObserverStateHandler)handler {
    NSString *safeUID = [uid isKindOfClass:NSString.class]
        ? [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (safeUID.length == 0) {
        safeUID = [FIRAuth auth].currentUser.uid ?: @"";
    }
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length == 0 || ![safeUID isEqualToString:authUID]) {
        if (handler) {
            handler(@[], [self.class pp_notificationErrorWithMessage:@"The requested inbox does not belong to the current session."]);
        }
        return nil;
    }
    FIRCollectionReference *userRef = [self inboxForUser:safeUID];
    if (!userRef) {
        if (handler) {
            handler(@[], [self.class pp_notificationErrorWithMessage:@"User inbox reference not found."]);
        }
        return nil;
    }

    PPCombinedNotificationListener *combined = [[PPCombinedNotificationListener alloc] initWithRegistrations:@[]];
    // Seed a replacement listener with its last confirmed source values. Retry
    // can then surface a healthy side without erasing the failed side, while the
    // source path remains available for deterministic merge/deduplication.
    __block NSArray<NotificationModel *> *userItems = self.cachedUserInboxItems[safeUID] ?: @[];
    __block NSArray<NotificationModel *> *staffItems = @[];
    __block FIRCollectionReference *staffRef = nil;
    __block id<FIRListenerRegistration> staffInboxRegistration = nil;
    __block NSError *userError = nil;
    __block NSError *staffApplicabilityError = nil;
    __block NSError *staffError = nil;
    __block BOOL userDidRespond = NO;
    __block BOOL staffApplicabilityDidResolve = NO;
    __block BOOL staffDidRespond = YES;
    __weak typeof(self) weakSelf = self;
    __weak PPCombinedNotificationListener *weakCombined = combined;
    BOOL (^authIsCurrent)(void) = ^BOOL(void) {
        return [([FIRAuth auth].currentUser.uid ?: @"") isEqualToString:safeUID];
    };
    void (^emitMerged)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        __strong PPCombinedNotificationListener *strongCombined = weakCombined;
        if (!self || !strongCombined || strongCombined.isRemoved || !handler) return;
        if (!authIsCurrent()) {
            [strongCombined remove];
            return;
        }
        if (waitsForInitialPair &&
            (!userDidRespond || !staffApplicabilityDidResolve || (staffRef && !staffDidRespond))) {
            return;
        }
        // Every configured source is operationally meaningful. A partial
        // failure therefore remains visible as degraded while confirmed items
        // from the healthy/cached source continue to render.
        NSError *aggregateError = userError ?: staffApplicabilityError ?: staffError;
        handler([self mergedNotificationsWithUserItems:userItems staffItems:staffItems], aggregateError);
    };

    id<FIRListenerRegistration> userRegistration =
    [[userRef queryOrderedByField:@"createdAt" descending:YES]
     addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        __strong PPCombinedNotificationListener *strongCombined = weakCombined;
        if (!strongCombined || strongCombined.isRemoved) return;
        if (!authIsCurrent()) {
            [strongCombined remove];
            return;
        }
        userDidRespond = YES;
        if (error || !snap) {
            userError = error ?: [NotificationManager pp_notificationErrorWithMessage:@"User inbox snapshot unavailable."];
            emitMerged();
            return;
        }

        NSMutableArray<NotificationModel *> *items = [NSMutableArray arrayWithCapacity:snap.documents.count];
        for (FIRDocumentSnapshot *doc in snap.documents) {
            [items addObject:[NotificationModel fromDoc:doc]];
        }
        NSArray<NotificationModel *> *incomingItems = items.copy;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        BOOL fromCache = snap.metadata.isFromCache;
        NSArray<NotificationModel *> *confirmedItems = strongSelf.cachedUserInboxItems[safeUID];
        if (!fromCache) {
            userItems = incomingItems;
            strongSelf.cachedUserInboxItems[safeUID] = incomingItems;
        } else if (!confirmedItems) {
            userItems = incomingItems;
        }
        userError = fromCache ? [NotificationManager pp_cacheOnlyNotificationErrorForSource:@"UsersCol/inbox"] : nil;
        emitMerged();
    }];
    if (![combined addRegistration:userRegistration]) {
        userDidRespond = YES;
        userError = [self.class pp_notificationErrorWithMessage:@"Unable to observe the user inbox."];
    }

    void (^startStaffInboxObservation)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong PPCombinedNotificationListener *strongCombined = weakCombined;
        if (!strongSelf || !strongCombined || strongCombined.isRemoved || staffInboxRegistration) return;
        if (!authIsCurrent()) {
            [strongCombined remove];
            return;
        }

        staffRef = [strongSelf staffInboxForUser:safeUID];
        if (!staffRef) {
            staffDidRespond = YES;
            staffError = [NotificationManager pp_notificationErrorWithMessage:@"Staff inbox reference not found."];
            emitMerged();
            return;
        }

        staffItems = strongSelf.cachedStaffInboxItems[safeUID] ?: @[];
        staffDidRespond = NO;
        staffError = nil;
        staffInboxRegistration =
        [[staffRef queryOrderedByField:@"createdAt" descending:YES]
         addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
            __strong PPCombinedNotificationListener *callbackCombined = weakCombined;
            if (!callbackCombined || callbackCombined.isRemoved) return;
            if (!authIsCurrent()) {
                [callbackCombined remove];
                return;
            }
            staffDidRespond = YES;
            if (error || !snap) {
                staffError = error ?: [NotificationManager pp_notificationErrorWithMessage:@"Staff inbox snapshot unavailable."];
                emitMerged();
                return;
            }

            NSMutableArray<NotificationModel *> *items = [NSMutableArray arrayWithCapacity:snap.documents.count];
            for (FIRDocumentSnapshot *doc in snap.documents) {
                [items addObject:[NotificationModel fromDoc:doc]];
            }
            NSArray<NotificationModel *> *incomingItems = items.copy;
            __strong typeof(weakSelf) callbackSelf = weakSelf;
            BOOL fromCache = snap.metadata.isFromCache;
            NSArray<NotificationModel *> *confirmedItems = callbackSelf.cachedStaffInboxItems[safeUID];
            if (!fromCache) {
                staffItems = incomingItems;
                callbackSelf.cachedStaffInboxItems[safeUID] = incomingItems;
            } else if (!confirmedItems) {
                staffItems = incomingItems;
            }
            staffError = fromCache ? [NotificationManager pp_cacheOnlyNotificationErrorForSource:@"staff_users/inbox"] : nil;
            emitMerged();
        }];
        if (![strongCombined addRegistration:staffInboxRegistration]) {
            staffInboxRegistration = nil;
            staffDidRespond = YES;
            staffError = [NotificationManager pp_notificationErrorWithMessage:@"Unable to observe the staff inbox."];
            emitMerged();
        }
    };

    FIRDocumentReference *staffDocument = [[[FIRFirestore firestore] collectionWithPath:kStaffUsersCollection]
                                             documentWithPath:safeUID];
    id<FIRListenerRegistration> staffApplicabilityRegistration =
    [staffDocument addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong PPCombinedNotificationListener *strongCombined = weakCombined;
        if (!strongSelf || !strongCombined || strongCombined.isRemoved) return;
        if (!authIsCurrent()) {
            [strongCombined remove];
            return;
        }

        staffApplicabilityDidResolve = YES;
        if (error || !snap) {
            staffApplicabilityError = error ?: [NotificationManager pp_notificationErrorWithMessage:@"Staff inbox applicability unavailable."];
            emitMerged();
            return;
        }

        PPStaffDoc *staffDoc = snap.exists
            ? [[PPStaffDoc alloc] initWithDictionary:(snap.data ?: @{}) uid:safeUID]
            : nil;
        BOOL fromCache = snap.metadata.isFromCache;
        NSNumber *confirmedApplicability = strongSelf.confirmedStaffInboxApplicability[safeUID];
        BOOL shouldObserveStaffInbox = (fromCache && confirmedApplicability)
            ? confirmedApplicability.boolValue
            : staffDoc.isActive;
        if (!fromCache) {
            strongSelf.confirmedStaffInboxApplicability[safeUID] = @(shouldObserveStaffInbox);
        }
        staffApplicabilityError = fromCache
            ? [NotificationManager pp_cacheOnlyNotificationErrorForSource:@"staff_users"]
            : nil;

        if (shouldObserveStaffInbox) {
            startStaffInboxObservation();
        } else if (!fromCache || !confirmedApplicability) {
            [staffInboxRegistration remove];
            staffInboxRegistration = nil;
            staffRef = nil;
            staffDidRespond = YES;
            staffError = nil;
            staffItems = @[];
            if (!fromCache) {
                [strongSelf.cachedStaffInboxItems removeObjectForKey:safeUID];
            }
        }
        emitMerged();
    }];
    if (![combined addRegistration:staffApplicabilityRegistration]) {
        staffApplicabilityDidResolve = YES;
        staffApplicabilityError = [self.class pp_notificationErrorWithMessage:@"Unable to resolve staff inbox applicability."];
    }

    [self.activeInboxListeners addObject:combined];
    if (!userRegistration || !staffApplicabilityRegistration) {
        emitMerged();
    }
    return combined;
}

- (void)stopListening {
    NSArray<PPCombinedNotificationListener *> *listeners = self.activeInboxListeners.allObjects.copy;
    [self.activeInboxListeners removeAllObjects];
    [self.cachedUserInboxItems removeAllObjects];
    [self.cachedStaffInboxItems removeAllObjects];
    [self.confirmedStaffInboxApplicability removeAllObjects];
    for (PPCombinedNotificationListener *listener in listeners) {
        [listener remove];
    }
}

- (void)fetchInboxPageForUser:(NSString *)uid
                        limit:(NSInteger)limit
                   startAfter:(FIRDocumentSnapshot *)startAfter
                   completion:(PPNotifPage)completion {
    NSString *safeUID = [uid isKindOfClass:NSString.class]
        ? [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (safeUID.length == 0) safeUID = authUID;
    if (authUID.length == 0 || ![safeUID isEqualToString:authUID]) {
        if (completion) {
            completion(@[], nil, [self.class pp_notificationErrorWithMessage:@"The requested inbox does not belong to the current session."]);
        }
        return;
    }

    FIRCollectionReference *userRef = [self inboxForUser:safeUID];
    if (!userRef) {
        if (completion) completion(@[], nil, [self.class pp_notificationErrorWithMessage:@"User inbox reference not found."]);
        return;
    }

    NSInteger safeLimit = MAX(limit, 1);
    __weak typeof(self) weakSelf = self;
    void (^fetchResolvedSources)(FIRCollectionReference * _Nullable, NSError * _Nullable) =
    ^(FIRCollectionReference *staffRef, NSError *applicabilityError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_group_t group = dispatch_group_create();
        __block NSArray<NotificationModel *> *userItems = @[];
        __block NSArray<NotificationModel *> *staffItems = @[];
        __block NSError *lastError = applicabilityError;

        void (^fetchBlock)(FIRCollectionReference *, BOOL) = ^(FIRCollectionReference *ref, BOOL isStaff) {
            if (!ref) return;
            dispatch_group_enter(group);
            FIRQuery *query = [[ref queryOrderedByField:@"createdAt" descending:YES] queryLimitedTo:safeLimit];
            if (startAfter) query = [query queryStartingAfterDocument:startAfter];
            [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
                if (error || !snapshot) {
                    lastError = lastError ?: error ?: [NotificationManager pp_notificationErrorWithMessage:@"Inbox page unavailable."];
                    dispatch_group_leave(group);
                    return;
                }

                NSMutableArray<NotificationModel *> *items = [NSMutableArray arrayWithCapacity:snapshot.documents.count];
                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    [items addObject:[NotificationModel fromDoc:doc]];
                }
                if (isStaff) {
                    staffItems = items.copy;
                } else {
                    userItems = items.copy;
                }
                if (snapshot.metadata.isFromCache) {
                    lastError = lastError ?: [NotificationManager pp_cacheOnlyNotificationErrorForSource:(isStaff ? @"staff_users/inbox" : @"UsersCol/inbox")];
                }
                dispatch_group_leave(group);
            }];
        };

        fetchBlock(userRef, NO);
        fetchBlock(staffRef, YES);

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSArray<NotificationModel *> *merged = [strongSelf mergedNotificationsWithUserItems:userItems staffItems:staffItems];
            NSArray<NotificationModel *> *page = (merged.count > safeLimit)
                ? [merged subarrayWithRange:NSMakeRange(0, safeLimit)]
                : merged;
            if (completion) completion(page, nil, lastError);
        });
    };

    FIRDocumentReference *staffDocument = [[[FIRFirestore firestore] collectionWithPath:kStaffUsersCollection]
                                             documentWithPath:safeUID];
    [staffDocument getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error || !snapshot) {
            NSError *resolvedError = error ?: [NotificationManager pp_notificationErrorWithMessage:@"Staff inbox applicability unavailable."];
            fetchResolvedSources(nil, resolvedError);
            return;
        }

        PPStaffDoc *staffDoc = snapshot.exists
            ? [[PPStaffDoc alloc] initWithDictionary:(snapshot.data ?: @{}) uid:safeUID]
            : nil;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        BOOL fromCache = snapshot.metadata.isFromCache;
        NSNumber *confirmedApplicability = strongSelf.confirmedStaffInboxApplicability[safeUID];
        BOOL shouldFetchStaffInbox = (fromCache && confirmedApplicability)
            ? confirmedApplicability.boolValue
            : staffDoc.isActive;
        if (!fromCache) {
            strongSelf.confirmedStaffInboxApplicability[safeUID] = @(shouldFetchStaffInbox);
            if (!shouldFetchStaffInbox) {
                [strongSelf.cachedStaffInboxItems removeObjectForKey:safeUID];
            }
        }
        FIRCollectionReference *staffRef = shouldFetchStaffInbox ? [strongSelf staffInboxForUser:safeUID] : nil;
        NSError *availabilityError = fromCache
            ? [NotificationManager pp_cacheOnlyNotificationErrorForSource:@"staff_users"]
            : nil;
        fetchResolvedSources(staffRef, availabilityError);
    }];
}

#pragma mark - Writes

- (void)markRead:(NotificationModel *)model
         forUser:(NSString *_Nullable)uid
      completion:(void (^)(NSError * _Nullable))completion {
    if (![model isKindOfClass:NotificationModel.class]) {
        if (completion) completion([self.class pp_notificationErrorWithMessage:@"Notification id is required."]);
        return;
    }
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *requestedUID = [uid isKindOfClass:NSString.class]
        ? [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    NSString *notificationID = [model.nid isKindOfClass:NSString.class]
        ? [model.nid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (authUID.length == 0 ||
        (requestedUID.length > 0 && ![requestedUID isEqualToString:authUID]) ||
        notificationID.length == 0 ||
        [notificationID containsString:@"/"]) {
        if (completion) completion([self.class pp_notificationErrorWithMessage:@"Notification id is required."]);
        return;
    }

    NSString *sourcePath = [model.sourcePath stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *pathComponents = [sourcePath componentsSeparatedByString:@"/"];
    NSString *callableName = nil;
    BOOL exactOwnedPath = pathComponents.count == 4 &&
        [pathComponents[1] isEqualToString:authUID] &&
        [pathComponents[2] isEqualToString:@"inbox"] &&
        [pathComponents[3] isEqualToString:notificationID];
    if (exactOwnedPath && [pathComponents[0] isEqualToString:@"UsersCol"]) {
        callableName = @"userNotificationInboxReadAck";
    } else if (exactOwnedPath && [pathComponents[0] isEqualToString:@"staff_users"]) {
        callableName = @"staffNotificationInboxReadAck";
    }
    if (callableName.length == 0) {
        if (completion) completion([self.class pp_notificationErrorWithMessage:@"Notification source is not authorized for acknowledgement."]);
        return;
    }

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:callableName];
    [callable callWithObject:@{@"notificationId": notificationID} completion:^(__unused FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:authUID]) return;
            if (completion) completion(error);
        });
    }];
}

- (void)sendToUser:(NSString *)uid
             model:(NotificationModel *)model
        completion:(void (^)(NSError * _Nullable))completion {
    FIRCollectionReference *ref = [self inboxForUser:uid];
    if (!ref) {
        if (completion) completion([self.class pp_notificationErrorWithMessage:@"Unable to resolve inbox for user."]);
        return;
    }

    NSMutableDictionary *payload = model.toDict.mutableCopy;
    payload[@"isRead"] = @NO;
    [[ref documentWithAutoID] setData:payload completion:completion];
}

- (void)sendBroadcast:(NotificationModel *)model completion:(void (^)(NSError * _Nullable))completion {
    [[[self adminCollection] documentWithAutoID] setData:model.toDict completion:completion];
}

#pragma mark - Cloud function wrappers

+ (void)sendToUserWithUID:(NSString *)uid
                    title:(NSString *)title
                     body:(NSString *)body
                     data:(NSDictionary *)data
               completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToUser:uid title:title body:body data:data completion:completion];
}

+ (void)sendToUserWithToken:(NSString *)token
                      title:(NSString *)title
                       body:(NSString *)body
                       data:(NSDictionary *)data
                 completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToToken:token title:title body:body data:data completion:completion];
}

+ (void)sendToUsersWithUIDs:(NSArray<NSString *> *)uids
                      title:(NSString *)title
                       body:(NSString *)body
                       data:(NSDictionary *)data
                 completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToUsers:uids title:title body:body data:data completion:completion];
}

+ (void)sendToAllUsersWithTitle:(NSString *)title
                           body:(NSString *)body
                           data:(NSDictionary *)data
                     completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToAllUsersWithTitle:title body:body data:data completion:completion];
}

+ (void)sendToAdminsWithTitle:(NSString *)title
                         body:(NSString *)body
                         data:(NSDictionary *)data
                   completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToAdminsWithTitle:title body:body data:data completion:completion];
}

+ (void)sendToAllWithTitle:(NSString *)title
                      body:(NSString *)body
                      data:(NSDictionary *)data
                completion:(void (^)(NSDictionary *, NSError *))completion {
    [PPNotificationsManager sendToAllWithTitle:title body:body data:data completion:completion];
}

+ (NSError *)pp_notificationErrorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:@"NotificationManager"
                               code:404
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Notification operation failed."}];
}

+ (NSError *)pp_cacheOnlyNotificationErrorForSource:(NSString *)source {
    return [NSError errorWithDomain:@"PurePetsPro.NotificationAvailability"
                               code:2
                           userInfo:@{
        NSLocalizedDescriptionKey: @"Notification data is available from the local cache only.",
        @"source": source ?: @"inbox"
    }];
}

@end
