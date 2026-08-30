//
//  PPDeliveryManager.m
//  PurePetsPro
//

#import "PPDeliveryManager.h"
#import "PPFirebaseCompat.h"
#import "PPStaffAuth.h"
#import "UserManager.h"
#import "UserModel.h"
#import <CommonCrypto/CommonDigest.h>

NSString * const PPDeliveryOrdersDidChangeNotification = @"PPDeliveryOrdersDidChangeNotification";
static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

static NSString *PPDeliveryV1CommandID(NSString *actorUID,
                                       NSString *orderID,
                                       NSArray<NSString *> *fulfillmentIDs,
                                       NSString *action,
                                       NSString *note) {
    NSArray *envelope = @[@"pp_delivery_v1",
                          actorUID ?: @"",
                          orderID ?: @"",
                          fulfillmentIDs ?: @[],
                          action ?: @"",
                          note ?: @""];
    NSData *data = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:nil] ?: [NSData data];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return [@"pro-v1-" stringByAppendingString:hex];
}

static NSSet<NSString *> *PPDeliveryV1SourceStatusesForAction(NSString *action) {
    NSDictionary<NSString *, NSSet<NSString *> *> *map = @{
        @"order_accept_delivery": [NSSet setWithObject:@"delivery_requested"],
        @"order_mark_shipped": [NSSet setWithObject:@"awaiting_handover"],
        @"order_mark_in_transit": [NSSet setWithObject:@"handed_over"],
        @"order_mark_delivered": [NSSet setWithArray:@[@"handed_over", @"in_transit"]],
        @"order_collect_payment": [NSSet setWithObject:@"payment_pending"],
        @"order_mark_completed": [NSSet setWithArray:@[@"delivered", @"payment_confirmed"]],
        @"order_cancel_delivery": [NSSet setWithArray:@[@"delivery_assigned", @"awaiting_handover"]],
    };
    return map[action ?: @""] ?: [NSSet set];
}

static NSArray<NSString *> *PPDeliveryAllStatuses(void) {
    return @[
        PPDeliveryStatusReadyToShip,
        PPDeliveryStatusRequested,
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ];
}

static NSArray<NSString *> *PPAssignedDeliveryStatuses(void) {
    return @[
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted,
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ];
}

static NSArray<NSString *> *PPAssignedFulfillmentActiveStatuses(void) {
    return @[
        @"delivery_assigned",
        @"awaiting_handover",
        @"handed_over",
        @"in_transit",
        @"delivered",
        @"payment_pending",
        @"payment_confirmed",
    ];
}

static NSString *PPParentDeliveryStatusForFulfillmentStatus(NSString *status) {
    NSString *normalized = [[status ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    NSDictionary<NSString *, NSString *> *map = @{
        @"delivery_assigned": PPDeliveryStatusAssigned,
        @"awaiting_handover": PPDeliveryStatusAwaitingHandover,
        @"handed_over": PPDeliveryStatusPickedUp,
        @"in_transit": PPDeliveryStatusInTransit,
        @"delivered": PPDeliveryStatusDelivered,
        @"payment_pending": PPDeliveryStatusPaymentPending,
        @"payment_confirmed": PPDeliveryStatusPaymentConfirmed,
    };
    return map[normalized] ?: @"";
}

static NSSet<NSString *> *PPReadyStatuses(void) {
    return [NSSet setWithArray:@[PPDeliveryStatusReadyToShip, PPDeliveryStatusRequested]];
}

static NSSet<NSString *> *PPPendingPickupStatuses(void) {
    return [NSSet setWithArray:@[
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp
    ]];
}

static NSSet<NSString *> *PPInTransitStatuses(void) {
    return [NSSet setWithArray:@[PPDeliveryStatusInTransit]];
}

static NSSet<NSString *> *PPDeliveredStatuses(void) {
    return [NSSet setWithArray:@[
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed,
        PPDeliveryStatusCompleted
    ]];
}

static NSSet<NSString *> *PPCancelledStatuses(void) {
    return [NSSet setWithArray:@[
        PPDeliveryStatusCancelled,
        PPDeliveryStatusFailed,
        PPDeliveryStatusReturnedToStore
    ]];
}

@interface PPDeliveryManager ()
@property (nonatomic, strong, readwrite) NSArray<PPDeliveryOrderModel *> *allOrders;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> primaryListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> secondaryListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> tertiaryListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> legacyAssignedListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> branchesListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> staffListener;
@property (nonatomic, copy, nullable) PPStaffRole lastStaffAuthorizationRole;
@property (nonatomic, assign) BOOL lastStaffAuthorizationIsActive;
@property (nonatomic, assign) BOOL hasStaffAuthorizationState;
@property (nonatomic, assign) NSUInteger staffListenerGeneration;
@property (nonatomic, assign) NSUInteger orderListenerGeneration;
@property (nonatomic, assign) NSUInteger assignedHydrationGeneration;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *primaryOrders;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *secondaryOrders;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *legacyAssignedOrders;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *deliveryUserAssignedChildren;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *driverAliasAssignedChildren;
@property (nonatomic, assign) BOOL deliveryUserAssignedSourceServerReady;
@property (nonatomic, assign) BOOL driverAliasAssignedSourceServerReady;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *branchNameCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *providerNameCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UserModel *> *providerUserCache;
- (void)startOrderListenersForStaff:(PPStaffDoc * _Nullable)staff uid:(NSString *)uid;
- (void)stopOrderListeners;
- (void)updateOrderListenersForStaff:(PPStaffDoc * _Nullable)staff uid:(NSString *)uid;
- (void)postOrdersChangeWithError:(NSError * _Nullable)error;
- (void)pp_applyAssignedFulfillmentDocuments:(NSArray<FIRDocumentSnapshot *> *)documents
                              assignmentField:(NSString *)assignmentField
                                          uid:(NSString *)uid
                                   generation:(NSUInteger)generation;
- (void)pp_refreshAssignedOrdersForUID:(NSString *)uid generation:(NSUInteger)generation;
- (void)pp_submitV1DeliveryAction:(NSString *)action
                          orderID:(NSString *)orderID
                             note:(NSString *)note
                   fulfillmentIDs:(NSArray<NSString *> *)fulfillmentIDs
                       completion:(PPDeliveryActionBlock)completion;
- (void)pp_reloadAfterV1ConflictForOrderID:(NSString *)orderID action:(NSString *)action;
@end

@implementation PPDeliveryManager

#pragma mark - Singleton

+ (instancetype)shared {
    static PPDeliveryManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPDeliveryManager alloc] init];
    });
    return instance;
}

#pragma mark - Provider Name Cache

- (NSString *)providerDisplayNameForID:(NSString *)providerID {
    if (providerID.length == 0) return providerID;

    // Check cache first
    NSString *cachedName = self.providerNameCache[providerID];
    if (cachedName.length > 0) {
        return cachedName;
    }

    // Check if we have the UserModel cached
    UserModel *cachedUser = self.providerUserCache[providerID];
    if (cachedUser && cachedUser.PPBestDisplayName.length > 0) {
        self.providerNameCache[providerID] = cachedUser.PPBestDisplayName;
        return cachedUser.PPBestDisplayName;
    }

    // Return the ID as fallback
    return providerID;
}

- (void)cacheProviderUser:(UserModel *)user forID:(NSString *)providerID {
    if (providerID.length == 0 || !user) return;
    self.providerUserCache[providerID] = user;
    if (user.PPBestDisplayName.length > 0) {
        self.providerNameCache[providerID] = user.PPBestDisplayName;
    }
}

- (void)prefetchProviderNamesForIDs:(NSArray<NSString *> *)providerIDs {
    if (providerIDs.count == 0) return;

    // Remove IDs that are already cached
    NSMutableArray<NSString *> *idsToFetch = [NSMutableArray array];
    for (NSString *providerID in providerIDs) {
        if (providerID.length == 0) continue;
        if (self.providerNameCache[providerID] == nil && self.providerUserCache[providerID] == nil) {
            [idsToFetch addObject:providerID];
        }
    }

    if (idsToFetch.count == 0) return;

    // Fetch users for the remaining IDs
    for (NSString *providerID in idsToFetch) {
        [[UserManager shared] lookupUserByUIDOrID:providerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            if (user && !error) {
                [self cacheProviderUser:user forID:providerID];
                // Notify that orders may need refresh
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryOrdersDidChangeNotification object:self];
                });
            }
        }];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _allOrders = @[];
        _primaryOrders = @[];
        _secondaryOrders = @[];
        _legacyAssignedOrders = @[];
        _deliveryUserAssignedChildren = @{};
        _driverAliasAssignedChildren = @{};
        _deliveryUserAssignedSourceServerReady = NO;
        _driverAliasAssignedSourceServerReady = NO;
        _branchNameCache = [NSMutableDictionary dictionary];
        _providerNameCache = [NSMutableDictionary dictionary];
        _providerUserCache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Firestore Listener

- (void)startListeningForDeliveryOrders {
    [self stopListening];
    [self startBranchesListener];

    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid.length) {
        DLog(@"[PPDeliveryManager] ❌ No authenticated user — cannot listen for orders.");
        [self postOrdersChangeWithError:[NSError errorWithDomain:@"PPDeliveryManager"
                                                             code:401
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Authentication is required to load delivery orders."}]];
        return;
    }

    [self.staffListener remove];
    self.staffListener = nil;
    NSUInteger listenerGeneration = ++self.staffListenerGeneration;
    __weak typeof(self) weakSelf = self;
    self.staffListener = [[PPStaffAuth shared] listenStaffDoc:uid onChange:^(PPStaffDoc * _Nullable staff, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (listenerGeneration != strongSelf.staffListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        if (error) {
            DLog(@"[PPDeliveryManager] Staff authorization listener error: %@", error.localizedDescription);
            [strongSelf updateOrderListenersForStaff:nil uid:uid];
            return;
        }
        [strongSelf updateOrderListenersForStaff:staff uid:uid];
    }];
}

- (void)stopListening {
    self.staffListenerGeneration += 1;
    [self stopOrderListeners];
    [self.branchesListener remove];
    [self.staffListener remove];
    self.primaryListener = nil;
    self.secondaryListener = nil;
    self.branchesListener = nil;
    self.staffListener = nil;
    self.lastStaffAuthorizationRole = nil;
    self.lastStaffAuthorizationIsActive = NO;
    self.hasStaffAuthorizationState = NO;
    self.allOrders = @[];
    [self postOrdersChangeWithError:nil];
}

- (void)stopOrderListeners {
    self.orderListenerGeneration += 1;
    self.assignedHydrationGeneration += 1;
    [self.primaryListener remove];
    [self.secondaryListener remove];
    [self.tertiaryListener remove];
    [self.legacyAssignedListener remove];
    self.primaryListener = nil;
    self.secondaryListener = nil;
    self.tertiaryListener = nil;
    self.legacyAssignedListener = nil;
    self.primaryOrders = @[];
    self.secondaryOrders = @[];
    self.legacyAssignedOrders = @[];
    self.deliveryUserAssignedChildren = @{};
    self.driverAliasAssignedChildren = @{};
    self.deliveryUserAssignedSourceServerReady = NO;
    self.driverAliasAssignedSourceServerReady = NO;
}

- (void)updateOrderListenersForStaff:(PPStaffDoc *)staff uid:(NSString *)uid {
    NSString *role = staff.role ?: @"";
    BOOL isActive = staff.isActive;
    BOOL authorizationChanged = !self.hasStaffAuthorizationState ||
        self.lastStaffAuthorizationIsActive != isActive ||
        ![self.lastStaffAuthorizationRole isEqualToString:role];
    if (!authorizationChanged) return;

    self.hasStaffAuthorizationState = YES;
    self.lastStaffAuthorizationRole = [role copy];
    self.lastStaffAuthorizationIsActive = isActive;
    [self stopOrderListeners];
    [self startOrderListenersForStaff:staff uid:uid];
}

- (void)startOrderListenersForStaff:(PPStaffDoc *)staff uid:(NSString *)uid {
    if (uid.length == 0) return;

    FIRCollectionReference *ordersRef = [[FIRFirestore firestore] collectionWithPath:@"Orders"];
    BOOL canSeeAllDeliveryOrders = staff.isActive &&
        ([PPStaffAuth isAdminRole:staff.role] || [staff.role isEqualToString:PPStaffRoleOperationsManager]);

    NSUInteger listenerGeneration = ++self.orderListenerGeneration;
    __weak typeof(self) weakSelf = self;
    void (^applyParentDocuments)(NSArray<FIRDocumentSnapshot *> *, BOOL) = ^(NSArray<FIRDocumentSnapshot *> *documents,
                                                                              BOOL serverConfirmed) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;

        NSMutableArray<PPDeliveryOrderModel *> *orders = [NSMutableArray arrayWithCapacity:documents.count];
        NSMutableSet<NSString *> *providerIDs = [NSMutableSet set];
        for (FIRDocumentSnapshot *doc in documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;
            PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:data withID:doc.documentID];
            if (order.fulfillmentVersion == 1 && !serverConfirmed) {
                // Cached parent projections remain useful for display, but a
                // courier cannot accept a V1 child set until the server has
                // confirmed the exact request projection for this auth epoch.
                order.deliveryRequestFulfillmentOrderIDs = @[];
            }
            [orders addObject:order];
            if (order.marketplaceProviderID.length > 0 &&
                ![order.marketplaceProviderID isEqualToString:@"platform"] &&
                ![order.marketplaceProviderID isEqualToString:PPDeliveryOfficialSupportUserID]) {
                [providerIDs addObject:order.marketplaceProviderID];
            }
        }

        strongSelf.primaryOrders = [orders copy];
        [strongSelf prefetchProviderNamesForIDs:providerIDs.allObjects];
        [strongSelf mergeAndPublishOrders];
    };

    if (canSeeAllDeliveryOrders) {
        // Infra policy grants broad operational visibility to admin/owner and
        // operations_manager. payments_manager is financial-only and must not
        // select this branch merely because it has payments.view/manage.
        FIRQuery *query = [[ordersRef queryWhereField:@"deliveryStatus" in:PPDeliveryAllStatuses()] queryOrderedByField:@"createdAt" descending:YES];
        self.primaryListener = [query addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
            if (error) {
                DLog(@"[PPDeliveryManager] ❌ All-order delivery listener error: %@", error.localizedDescription);
                [strongSelf postOrdersChangeWithError:error];
                return;
            }
            applyParentDocuments(snapshot.documents ?: @[], !snapshot.metadata.isFromCache);
        }];
        return;
    }

    FIRQuery *openQuery = [[ordersRef queryWhereField:@"deliveryStatus" isEqualTo:PPDeliveryStatusRequested] queryOrderedByField:@"createdAt" descending:YES];
    FIRCollectionReference *fulfillmentsRef = [[FIRFirestore firestore] collectionWithPath:@"FulfillmentOrders"];
    NSArray<NSString *> *activeStatuses = PPAssignedFulfillmentActiveStatuses();
    FIRQuery *(^assignedQueryForField)(NSString *) = ^FIRQuery *(NSString *field) {
        FIRQuery *query = [[fulfillmentsRef queryWhereField:field isEqualTo:uid]
                           queryWhereField:@"status" in:activeStatuses];
        query = [query queryOrderedByField:@"updatedAt" descending:YES];
        return [query queryOrderedByFieldPath:FIRFieldPath.documentID descending:YES];
    };

    self.primaryListener = [openQuery addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        if (error) {
            DLog(@"[PPDeliveryManager] ❌ Open delivery listener error: %@", error.localizedDescription);
            [strongSelf postOrdersChangeWithError:error];
            return;
        }
        applyParentDocuments(snapshot.documents ?: @[], !snapshot.metadata.isFromCache);
    }];

    self.secondaryListener = [assignedQueryForField(@"deliveryUserId") addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        if (error) {
            DLog(@"[PPDeliveryManager] ❌ Canonical deliveryUserId child listener error: %@", error.localizedDescription);
            strongSelf.deliveryUserAssignedSourceServerReady = NO;
            strongSelf.deliveryUserAssignedChildren = @{};
            [strongSelf pp_refreshAssignedOrdersForUID:uid generation:listenerGeneration];
            [strongSelf postOrdersChangeWithError:error];
            return;
        }
        if (snapshot.metadata.isFromCache) {
            strongSelf.deliveryUserAssignedSourceServerReady = NO;
            strongSelf.deliveryUserAssignedChildren = @{};
            [strongSelf pp_refreshAssignedOrdersForUID:uid generation:listenerGeneration];
            return;
        }
        strongSelf.deliveryUserAssignedSourceServerReady = YES;
        [strongSelf pp_applyAssignedFulfillmentDocuments:snapshot.documents ?: @[]
                                         assignmentField:@"deliveryUserId"
                                                     uid:uid
                                              generation:listenerGeneration];
    }];

    self.tertiaryListener = [assignedQueryForField(@"deliveryAssignedDriverUid") addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        if (error) {
            DLog(@"[PPDeliveryManager] ❌ Canonical deliveryAssignedDriverUid child listener error: %@", error.localizedDescription);
            strongSelf.driverAliasAssignedSourceServerReady = NO;
            strongSelf.driverAliasAssignedChildren = @{};
            [strongSelf pp_refreshAssignedOrdersForUID:uid generation:listenerGeneration];
            [strongSelf postOrdersChangeWithError:error];
            return;
        }
        if (snapshot.metadata.isFromCache) {
            strongSelf.driverAliasAssignedSourceServerReady = NO;
            strongSelf.driverAliasAssignedChildren = @{};
            [strongSelf pp_refreshAssignedOrdersForUID:uid generation:listenerGeneration];
            return;
        }
        strongSelf.driverAliasAssignedSourceServerReady = YES;
        [strongSelf pp_applyAssignedFulfillmentDocuments:snapshot.documents ?: @[]
                                         assignmentField:@"deliveryAssignedDriverUid"
                                                     uid:uid
                                              generation:listenerGeneration];
    }];

    // Compatibility only: legacy (fulfillmentVersion 0/missing) assignments
    // remain parent-owned. Fulfillment V1 documents returned by this legacy
    // index are deliberately discarded and never drive an action.
    FIRQuery *legacyAssignedQuery = [[[ordersRef queryWhereField:@"deliveryUserId" isEqualTo:uid]
                                      queryWhereField:@"deliveryStatus" in:PPAssignedDeliveryStatuses()]
                                     queryOrderedByField:@"createdAt" descending:YES];
    self.legacyAssignedListener = [legacyAssignedQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || listenerGeneration != strongSelf.orderListenerGeneration) return;
        if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) return;
        if (error) {
            strongSelf.legacyAssignedOrders = @[];
            [strongSelf mergeAndPublishOrders];
            [strongSelf postOrdersChangeWithError:error];
            return;
        }
        NSMutableArray<PPDeliveryOrderModel *> *legacyOrders = [NSMutableArray array];
        for (FIRDocumentSnapshot *document in snapshot.documents ?: @[]) {
            PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:document.data ?: @{}
                                                                          withID:document.documentID];
            if (order.fulfillmentVersion == 1 || ![order.deliveryUserId isEqualToString:uid]) continue;
            [legacyOrders addObject:order];
        }
        strongSelf.legacyAssignedOrders = legacyOrders.copy;
        [strongSelf mergeAndPublishOrders];
    }];
}

- (void)pp_applyAssignedFulfillmentDocuments:(NSArray<FIRDocumentSnapshot *> *)documents
                              assignmentField:(NSString *)assignmentField
                                          uid:(NSString *)uid
                                   generation:(NSUInteger)generation {
    if (generation != self.orderListenerGeneration ||
        ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) {
        return;
    }

    NSSet<NSString *> *activeStatuses = [NSSet setWithArray:PPAssignedFulfillmentActiveStatuses()];
    NSMutableDictionary<NSString *, NSDictionary *> *accepted = [NSMutableDictionary dictionary];
    for (FIRDocumentSnapshot *document in documents) {
        NSDictionary *data = [document.data isKindOfClass:NSDictionary.class] ? document.data : nil;
        if (!data || document.documentID.length == 0) continue;
        NSString *deliveryUserID = [data[@"deliveryUserId"] isKindOfClass:NSString.class]
            ? [data[@"deliveryUserId"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        NSString *driverAliasUID = [data[@"deliveryAssignedDriverUid"] isKindOfClass:NSString.class]
            ? [data[@"deliveryAssignedDriverUid"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        // Match backend ownership exactly: the canonical field wins whenever
        // present; the alias is consulted only for legacy child documents.
        NSString *assignedUID = deliveryUserID.length > 0 ? deliveryUserID : driverAliasUID;
        NSString *parentOrderID = [data[@"parentOrderId"] isKindOfClass:NSString.class]
            ? [data[@"parentOrderId"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        NSString *status = [data[@"status"] isKindOfClass:NSString.class]
            ? [data[@"status"] lowercaseString]
            : @"";
        BOOL aliasFallbackDocument = [assignmentField isEqualToString:@"deliveryAssignedDriverUid"] &&
            deliveryUserID.length == 0;
        BOOL canonicalDocument = [assignmentField isEqualToString:@"deliveryUserId"];
        if (![assignedUID isEqualToString:uid] ||
            (!canonicalDocument && !aliasFallbackDocument) ||
            parentOrderID.length == 0 ||
            ![activeStatuses containsObject:status]) {
            continue;
        }
        NSMutableDictionary *child = [data mutableCopy];
        child[@"_fulfillmentDocumentID"] = document.documentID;
        accepted[document.documentID] = child.copy;
    }

    if ([assignmentField isEqualToString:@"deliveryUserId"]) {
        self.deliveryUserAssignedChildren = accepted.copy;
    } else if ([assignmentField isEqualToString:@"deliveryAssignedDriverUid"]) {
        self.driverAliasAssignedChildren = accepted.copy;
    } else {
        return;
    }
    [self pp_refreshAssignedOrdersForUID:uid generation:generation];
}

- (void)pp_refreshAssignedOrdersForUID:(NSString *)uid generation:(NSUInteger)generation {
    if (generation != self.orderListenerGeneration ||
        ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) {
        return;
    }

    if (!self.deliveryUserAssignedSourceServerReady ||
        !self.driverAliasAssignedSourceServerReady) {
        self.assignedHydrationGeneration += 1;
        self.secondaryOrders = @[];
        [self mergeAndPublishOrders];
        return;
    }

    NSMutableDictionary<NSString *, NSDictionary *> *childrenByID = [NSMutableDictionary dictionary];
    [childrenByID addEntriesFromDictionary:self.deliveryUserAssignedChildren ?: @{}];
    [childrenByID addEntriesFromDictionary:self.driverAliasAssignedChildren ?: @{}];

    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSString *> *> *statusesByParent = [NSMutableDictionary dictionary];
    [childrenByID enumerateKeysAndObjectsUsingBlock:^(NSString *fulfillmentID, NSDictionary *data, BOOL *stop) {
        (void)stop;
        NSString *parentOrderID = [data[@"parentOrderId"] isKindOfClass:NSString.class]
            ? [data[@"parentOrderId"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            : @"";
        NSString *status = [data[@"status"] isKindOfClass:NSString.class]
            ? [data[@"status"] lowercaseString]
            : @"";
        if (parentOrderID.length == 0 || status.length == 0) return;
        NSMutableDictionary<NSString *, NSString *> *parentStatuses = statusesByParent[parentOrderID];
        if (!parentStatuses) {
            parentStatuses = [NSMutableDictionary dictionary];
            statusesByParent[parentOrderID] = parentStatuses;
        }
        parentStatuses[fulfillmentID] = status;
    }];

    NSUInteger hydrationGeneration = ++self.assignedHydrationGeneration;
    if (statusesByParent.count == 0) {
        self.secondaryOrders = @[];
        [self mergeAndPublishOrders];
        return;
    }

    dispatch_group_t hydrationGroup = dispatch_group_create();
    NSMutableArray<PPDeliveryOrderModel *> *hydratedOrders = [NSMutableArray arrayWithCapacity:statusesByParent.count];
    __block NSError *firstError = nil;
    FIRCollectionReference *ordersRef = [[FIRFirestore firestore] collectionWithPath:@"Orders"];
    [statusesByParent enumerateKeysAndObjectsUsingBlock:^(NSString *parentOrderID, NSMutableDictionary<NSString *, NSString *> *statuses, BOOL *stop) {
        (void)stop;
        dispatch_group_enter(hydrationGroup);
        [[ordersRef documentWithPath:parentOrderID] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (generation == self.orderListenerGeneration &&
                hydrationGeneration == self.assignedHydrationGeneration &&
                [[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) {
                if (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
                    @synchronized (hydratedOrders) {
                        if (!firstError) {
                            firstError = error ?: [NSError errorWithDomain:@"PPDeliveryManager"
                                                                      code:404
                                                                  userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryOrderUnavailable")}];
                        }
                    }
                } else {
                    PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:snapshot.data withID:snapshot.documentID];
                    if (order.fulfillmentVersion == 1) {
                        NSArray<NSString *> *selectedIDs = [statuses.allKeys sortedArrayUsingSelector:@selector(compare:)];
                        order.fulfillmentOrderIDs = selectedIDs;
                        order.assignedFulfillmentStatusesByID = statuses.copy;
                        order.deliveryUserId = uid;

                        NSMutableSet<NSString *> *mappedParentStatuses = [NSMutableSet set];
                        for (NSString *childStatus in statuses.allValues) {
                            NSString *mapped = PPParentDeliveryStatusForFulfillmentStatus(childStatus);
                            if (mapped.length > 0) [mappedParentStatuses addObject:mapped];
                        }
                        if (mappedParentStatuses.count == 1) {
                            order.deliveryStatus = mappedParentStatuses.anyObject;
                        }
                        @synchronized (hydratedOrders) {
                            [hydratedOrders addObject:order];
                        }
                    }
                }
            }
            dispatch_group_leave(hydrationGroup);
        }];
    }];

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(hydrationGroup, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf ||
            generation != strongSelf.orderListenerGeneration ||
            hydrationGeneration != strongSelf.assignedHydrationGeneration ||
            ![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:uid]) {
            return;
        }
        strongSelf.secondaryOrders = hydratedOrders.copy;
        NSMutableSet<NSString *> *providerIDs = [NSMutableSet set];
        for (PPDeliveryOrderModel *order in hydratedOrders) {
            if (order.marketplaceProviderID.length > 0 &&
                ![order.marketplaceProviderID isEqualToString:@"platform"] &&
                ![order.marketplaceProviderID isEqualToString:PPDeliveryOfficialSupportUserID]) {
                [providerIDs addObject:order.marketplaceProviderID];
            }
        }
        [strongSelf prefetchProviderNamesForIDs:providerIDs.allObjects];
        DLog(@"[PPLAB][PPDeliveryManager] assigned-child hydration uid=%@ childCount=%lu parentCount=%lu generation=%lu",
             uid,
             (unsigned long)childrenByID.count,
             (unsigned long)hydratedOrders.count,
             (unsigned long)generation);
        [strongSelf mergeAndPublishOrders];
        if (firstError) [strongSelf postOrdersChangeWithError:firstError];
    });
}

- (void)postOrdersChangeWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = error ? @{ @"error": error } : nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryOrdersDidChangeNotification
                                                              object:self
                                                            userInfo:userInfo];
    });
}

- (void)mergeAndPublishOrders {
    NSMutableDictionary<NSString *, PPDeliveryOrderModel *> *merged = [NSMutableDictionary dictionary];
    for (PPDeliveryOrderModel *order in self.primaryOrders) {
        if (order.orderId.length) merged[order.orderId] = [order copy];
    }
    for (PPDeliveryOrderModel *order in self.secondaryOrders) {
        if (order.orderId.length) merged[order.orderId] = [order copy];
    }
    for (PPDeliveryOrderModel *order in self.legacyAssignedOrders) {
        if (order.orderId.length && !merged[order.orderId]) merged[order.orderId] = [order copy];
    }

    // Enrich orders with cached branch names
    for (PPDeliveryOrderModel *order in merged.allValues) {
        if (order.branchName.length == 0 && order.branchID.length > 0) {
            NSString *cached = self.branchNameCache[order.branchID];
            if (cached.length) {
                order.branchName = [cached copy];
            }
        }
    }

    NSArray<PPDeliveryOrderModel *> *sorted = [[merged allValues] sortedArrayUsingComparator:^NSComparisonResult(PPDeliveryOrderModel *obj1, PPDeliveryOrderModel *obj2) {
        NSDate *lhs = obj1.createdAt ?: [NSDate distantPast];
        NSDate *rhs = obj2.createdAt ?: [NSDate distantPast];
        return [rhs compare:lhs];
    }];

    self.allOrders = sorted;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryOrdersDidChangeNotification object:self userInfo:nil];
    });
}

#pragma mark - Branch Name Cache

- (void)startBranchesListener {
    if (self.branchesListener) return;

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *branchesRef = [db collectionWithPath:@"branches"];

    __weak typeof(self) weakSelf = self;
    self.branchesListener = [branchesRef addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || error || !snapshot) return;

        BOOL changed = NO;
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;

            NSString *docID = doc.documentID;
            NSString *resolvedName = nil;

            id nameVal = data[@"name"];
            if ([nameVal isKindOfClass:[NSDictionary class]]) {
                NSDictionary *nameDict = (NSDictionary *)nameVal;
                NSString *ar = nameDict[@"ar"] ?: @"";
                NSString *en = nameDict[@"en"] ?: @"";
                resolvedName = Language.isRTL ? (ar.length ? ar : en) : (en.length ? en : ar);
            } else if ([nameVal isKindOfClass:[NSString class]]) {
                resolvedName = (NSString *)nameVal;
            }

            if (resolvedName.length > 0 && ![strongSelf.branchNameCache[docID] isEqualToString:resolvedName]) {
                strongSelf.branchNameCache[docID] = resolvedName;
                changed = YES;
            }
        }

        if (changed && (strongSelf.primaryOrders.count > 0 || strongSelf.secondaryOrders.count > 0)) {
            [strongSelf mergeAndPublishOrders];
        }
    }];
}

#pragma mark - Filtering

- (NSArray<PPDeliveryOrderModel *> *)ordersForFilter:(PPDeliveryFilter)filter {
    return [self ordersForFilter:filter searchText:nil];
}

- (NSArray<PPDeliveryOrderModel *> *)ordersForFilter:(PPDeliveryFilter)filter searchText:(NSString *)searchText {
    NSArray<PPDeliveryOrderModel *> *source = self.allOrders;

    // Filter by segment
    if (filter != PPDeliveryFilterAll) {
        NSSet *statusSet;
        switch (filter) {
            case PPDeliveryFilterReady:          statusSet = PPReadyStatuses(); break;
            case PPDeliveryFilterPendingPickup:  statusSet = PPPendingPickupStatuses(); break;
            case PPDeliveryFilterInTransit:      statusSet = PPInTransitStatuses(); break;
            case PPDeliveryFilterDelivered:       statusSet = PPDeliveredStatuses(); break;
            case PPDeliveryFilterCancelled:      statusSet = PPCancelledStatuses(); break;
            default: statusSet = nil; break;
        }
        if (statusSet) {
            source = [source filteredArrayUsingPredicate:
                [NSPredicate predicateWithBlock:^BOOL(PPDeliveryOrderModel *order, NSDictionary *bindings) {
                    return [statusSet containsObject:[order.deliveryStatus lowercaseString]];
                }]
            ];
        }
    }

    // Search filter
    if (searchText.length > 0) {
        NSString *lower = [searchText lowercaseString];
        source = [source filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(PPDeliveryOrderModel *order, NSDictionary *bindings) {
                return [[order.customerName lowercaseString] containsString:lower] ||
                       [[[order bestOrderNumber] lowercaseString] containsString:lower] ||
                       [[order.deliveryAddress lowercaseString] containsString:lower] ||
                       [[order.customerPhone lowercaseString] containsString:lower];
            }]
        ];
    }

    return source;
}

#pragma mark - Target Revalidation

- (void)fetchDeliveryOrderWithID:(NSString *)orderID completion:(PPDeliveryOrderBlock)completion {
    NSString *resolvedOrderID = [orderID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (resolvedOrderID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"PPDeliveryManager" code:400 userInfo:nil]);
        }
        return;
    }
    if (authUID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"PPDeliveryManager" code:401 userInfo:nil]);
        }
        return;
    }

    FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:resolvedOrderID];
    [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:authUID]) return;
            if (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
                if (completion) completion(nil, error);
                return;
            }
            PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:snapshot.data withID:snapshot.documentID];
            PPDeliveryOrderModel *cached = [self currentDeliveryOrderWithID:order.orderId];
            if (order.fulfillmentVersion == 1 && cached.assignedFulfillmentStatusesByID.count > 0) {
                order.fulfillmentOrderIDs = cached.fulfillmentOrderIDs.copy;
                order.assignedFulfillmentStatusesByID = cached.assignedFulfillmentStatusesByID.copy;
                order.deliveryUserId = cached.deliveryUserId;
            }
            if (completion) completion(order, nil);
        });
    }];
}

#pragma mark - Cloud Function Actions

- (PPDeliveryOrderModel *)pp_deliveryOrderForOrderID:(NSString *)orderID {
    NSString *resolvedOrderID = [orderID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (resolvedOrderID.length == 0) return nil;
    for (PPDeliveryOrderModel *order in self.allOrders) {
        if ([order.orderId isEqualToString:resolvedOrderID]) return order;
    }
    return nil;
}

- (PPDeliveryOrderModel *)currentDeliveryOrderWithID:(NSString *)orderID {
    return [[self pp_deliveryOrderForOrderID:orderID] copy];
}

- (void)pp_performV1DeliveryAction:(NSString *)action
                           orderID:(NSString *)orderID
                              note:(NSString *)note
                    fulfillmentIDs:(NSArray<NSString *> *)fulfillmentIDs
                        completion:(PPDeliveryActionBlock)completion {
    NSMutableArray<NSString *> *resolvedIDs = [NSMutableArray array];
    BOOL invalidSelection = NO;
    for (id value in fulfillmentIDs ?: @[]) {
        if (![value isKindOfClass:NSString.class]) {
            invalidSelection = YES;
            continue;
        }
        NSString *fulfillmentID = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (fulfillmentID.length == 0 ||
            [fulfillmentID containsString:@"/"] ||
            [resolvedIDs containsObject:fulfillmentID]) {
            invalidSelection = YES;
            continue;
        }
        [resolvedIDs addObject:fulfillmentID];
    }

    if (invalidSelection || resolvedIDs.count == 0 || resolvedIDs.count != fulfillmentIDs.count) {
        NSError *error = [NSError errorWithDomain:@"PPDeliveryManager"
                                             code:409
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryStateChangedReload")}];
        DLog(@"[PPDeliveryManager] Pro delivery v1 rejected orderId=%@ action=%@ reason=invalidExactSelection", orderID, action);
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }
    [resolvedIDs sortUsingSelector:@selector(compare:)];

    NSSet<NSString *> *sourceStatuses = PPDeliveryV1SourceStatusesForAction(action);
    NSString *actorUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (sourceStatuses.count == 0 || actorUID.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PPDeliveryManager"
                                             code:403
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryOrderUnavailable")}];
        if (completion) completion(NO, error.localizedDescription, error);
        return;
    }

    FIRFirestore *firestore = [FIRFirestore firestore];
    if ([action isEqualToString:@"order_accept_delivery"]) {
        FIRDocumentReference *parentReference = [[firestore collectionWithPath:@"Orders"] documentWithPath:orderID ?: @""];
        [parentReference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:actorUID]) return;
                if (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class]) {
                    NSError *resolvedError = error ?: [NSError errorWithDomain:@"PPDeliveryManager"
                                                                          code:404
                                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryOrderUnavailable")}];
                    if (completion) completion(NO, resolvedError.localizedDescription, resolvedError);
                    return;
                }

                NSDictionary *parentData = snapshot.data;
                NSArray *requestIDs = [parentData[@"deliveryRequestFulfillmentOrderIDs"] isKindOfClass:NSArray.class]
                    ? parentData[@"deliveryRequestFulfillmentOrderIDs"]
                    : @[];
                NSMutableArray<NSString *> *projectedIDs = [NSMutableArray arrayWithCapacity:requestIDs.count];
                BOOL invalidProjection = NO;
                for (id value in requestIDs) {
                    if (![value isKindOfClass:NSString.class]) {
                        invalidProjection = YES;
                        continue;
                    }
                    NSString *candidate = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    if (candidate.length == 0 ||
                        [candidate containsString:@"/"] ||
                        [projectedIDs containsObject:candidate]) {
                        invalidProjection = YES;
                        continue;
                    }
                    [projectedIDs addObject:candidate];
                }
                [projectedIDs sortUsingSelector:@selector(compare:)];

                NSString *parentDeliveryStatus = [parentData[@"deliveryStatus"] isKindOfClass:NSString.class]
                    ? [parentData[@"deliveryStatus"] lowercaseString]
                    : @"";
                BOOL exactProjection = !invalidProjection &&
                    projectedIDs.count > 0 &&
                    [projectedIDs isEqualToArray:resolvedIDs] &&
                    [parentData[@"fulfillmentVersion"] integerValue] == 1 &&
                    [parentDeliveryStatus isEqualToString:PPDeliveryStatusRequested];
                if (!exactProjection) {
                    NSError *projectionError = [NSError errorWithDomain:@"PPDeliveryManager"
                                                                    code:409
                                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryStateChangedReload")}];
                    [self pp_reloadAfterV1ConflictForOrderID:orderID action:action];
                    if (completion) completion(NO, projectionError.localizedDescription, projectionError);
                    return;
                }
                [self pp_submitV1DeliveryAction:action
                                        orderID:orderID
                                           note:note
                                 fulfillmentIDs:resolvedIDs.copy
                                     completion:completion];
            });
        }];
        return;
    }

    dispatch_group_t selectionGroup = dispatch_group_create();
    NSMutableArray<NSString *> *eligibleIDs = [NSMutableArray array];
    __block NSError *selectionError = nil;

    for (NSString *fulfillmentID in resolvedIDs) {
        dispatch_group_enter(selectionGroup);
        FIRDocumentReference *reference = [[firestore collectionWithPath:@"FulfillmentOrders"] documentWithPath:fulfillmentID];
        [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            @synchronized (eligibleIDs) {
                if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:actorUID]) {
                    selectionError = [NSError errorWithDomain:@"PPDeliveryManager"
                                                         code:401
                                                     userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryOrderUnavailable")}];
                } else if (!selectionError && (error || !snapshot.exists || ![snapshot.data isKindOfClass:NSDictionary.class])) {
                    selectionError = error ?: [NSError errorWithDomain:@"PPDeliveryManager"
                                                                   code:404
                                                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryOrderUnavailable")}];
                } else if (!selectionError) {
                    NSDictionary *data = snapshot.data;
                    NSString *status = [data[@"status"] isKindOfClass:NSString.class]
                        ? [data[@"status"] lowercaseString]
                        : @"";
                    NSString *deliveryUserID = [data[@"deliveryUserId"] isKindOfClass:NSString.class]
                        ? [data[@"deliveryUserId"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                        : @"";
                    NSString *assignedDriverUID = [data[@"deliveryAssignedDriverUid"] isKindOfClass:NSString.class]
                        ? [data[@"deliveryAssignedDriverUid"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                        : @"";
                    NSString *parentOrderID = [data[@"parentOrderId"] isKindOfClass:NSString.class]
                        ? [data[@"parentOrderId"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                        : @"";
                    NSString *canonicalAssignedUID = deliveryUserID.length > 0
                        ? deliveryUserID
                        : assignedDriverUID;
                    BOOL actorOwnsChild = [canonicalAssignedUID isEqualToString:actorUID];
                    BOOL exactParent = [parentOrderID isEqualToString:orderID ?: @""];
                    if ([sourceStatuses containsObject:status] && actorOwnsChild && exactParent) {
                        [eligibleIDs addObject:fulfillmentID];
                    } else {
                        selectionError = [NSError errorWithDomain:@"PPDeliveryManager"
                                                             code:409
                                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryStateChangedReload")}];
                    }
                }
            }
            dispatch_group_leave(selectionGroup);
        }];
    }

    dispatch_group_notify(selectionGroup, dispatch_get_main_queue(), ^{
        if (selectionError || eligibleIDs.count != resolvedIDs.count) {
            NSError *error = selectionError ?: [NSError errorWithDomain:@"PPDeliveryManager"
                                                                    code:409
                                                                userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryStateChangedReload")}];
            DLog(@"[PPLAB][PPDeliveryManager] Pro delivery v1 conflict orderId=%@ action=%@ selected=%lu eligible=%lu",
                 orderID,
                 action,
                 (unsigned long)resolvedIDs.count,
                 (unsigned long)eligibleIDs.count);
            [self pp_reloadAfterV1ConflictForOrderID:orderID action:action];
            if (completion) completion(NO, error.localizedDescription, error);
            return;
        }

        [self pp_submitV1DeliveryAction:action
                                orderID:orderID
                                   note:note
                         fulfillmentIDs:eligibleIDs.copy
                             completion:completion];
    });
}

- (void)pp_submitV1DeliveryAction:(NSString *)action
                          orderID:(NSString *)orderID
                             note:(NSString *)note
                   fulfillmentIDs:(NSArray<NSString *> *)fulfillmentIDs
                       completion:(PPDeliveryActionBlock)completion {
    NSArray<NSString *> *sortedIDs = [fulfillmentIDs sortedArrayUsingSelector:@selector(compare:)];
    NSString *actorUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *commandID = PPDeliveryV1CommandID(actorUID, orderID, sortedIDs, action, note);
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"deliveryTransitionFulfillment"];
    callable.timeoutInterval = 30;
    NSDictionary *payload = @{
        @"parentOrderID": orderID ?: @"",
        @"fulfillmentIDs": sortedIDs,
        @"action": action ?: @"",
        @"note": note ?: @"",
        @"commandId": commandID,
    };

    DLog(@"[PPLAB][PPDeliveryManager] Pro delivery v1 submit orderId=%@ action=%@ childCount=%lu commandId=%@",
         orderID,
         action,
         (unsigned long)sortedIDs.count,
         commandID);

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        (void)result;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid ?: @"" isEqualToString:actorUID]) return;
            if (error) {
                DLog(@"[PPDeliveryManager] Pro delivery v1 failed orderId=%@ action=%@ fulfillmentCount=%lu code=%ld", orderID, action, (unsigned long)sortedIDs.count, (long)error.code);
                NSString *message = error.localizedDescription;
                NSDictionary *details = error.userInfo[@"details"];
                if ([details isKindOfClass:NSDictionary.class] && [details[@"message"] isKindOfClass:NSString.class]) {
                    message = details[@"message"];
                }
                [self pp_reloadAfterV1ConflictForOrderID:orderID action:action];
                if (completion) completion(NO, message, error);
                return;
            }
            DLog(@"[PPDeliveryManager] Pro delivery v1 accepted orderId=%@ action=%@ fulfillmentCount=%lu", orderID, action, (unsigned long)sortedIDs.count);
            if (completion) completion(YES, kLang(@"DeliverySuccess"), nil);
        });
    }];
}

- (void)pp_reloadAfterV1ConflictForOrderID:(NSString *)orderID action:(NSString *)action {
    DLog(@"[PPLAB][PPDeliveryManager] Reloading canonical delivery listeners orderId=%@ action=%@", orderID, action);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startListeningForDeliveryOrders];
    });
}

- (void)performDeliveryAction:(NSString *)action orderId:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    PPDeliveryOrderModel *order = [self pp_deliveryOrderForOrderID:orderId];
    if (order.fulfillmentVersion == 1) {
        NSArray<NSString *> *selectedIDs = [action isEqualToString:@"order_accept_delivery"]
            ? order.deliveryRequestFulfillmentOrderIDs
            : order.fulfillmentOrderIDs;
        DLog(@"[PPDeliveryManager] Pro delivery route=v1-child orderId=%@ action=%@ fulfillmentCount=%lu", orderId, action, (unsigned long)selectedIDs.count);
        [self pp_performV1DeliveryAction:action
                                orderID:orderId
                                   note:(note.length > 0) ? note : kLang(@"DeliveryDefaultActionNote")
                         fulfillmentIDs:selectedIDs
                             completion:completion];
        return;
    }

    DLog(@"[PPDeliveryManager] Pro delivery route=legacy-parent orderId=%@ action=%@", orderId, action);
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"deliveryTransitionOrderStatus"];
    callable.timeoutInterval = 30;

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"action"]  = action;
    data[@"orderId"] = orderId ?: @"";
    data[@"note"]    = (note.length > 0) ? note : kLang(@"DeliveryDefaultActionNote");

    [callable callWithObject:[data copy] completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
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

            NSString *successMsg = nil;
            if ([result.data isKindOfClass:[NSDictionary class]]) {
                successMsg = result.data[@"message"];
            }
            if (completion) completion(YES, successMsg ?: kLang(@"DeliverySuccess"), nil);
        });
    }];
}

- (void)markOrderShipped:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_mark_shipped" orderId:orderId note:note completion:completion];
}

- (void)markOrderInTransit:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_mark_in_transit" orderId:orderId note:note completion:completion];
}

- (void)markOrderDelivered:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_mark_delivered" orderId:orderId note:note completion:completion];
}

- (void)collectCashPayment:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_collect_payment" orderId:orderId note:note completion:completion];
}

- (void)markOrderCompleted:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_mark_completed" orderId:orderId note:note completion:completion];
}

- (void)cancelOrder:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_cancel_delivery" orderId:orderId note:note completion:completion];
}

- (void)acceptDeliveryOrder:(NSString *)orderId completion:(PPDeliveryActionBlock)completion {
    [self performDeliveryAction:@"order_accept_delivery" orderId:orderId note:kLang(@"DeliveryDefaultActionNote") completion:completion];
}

@end
