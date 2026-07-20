//
//  PPDeliveryManager.m
//  PurePetsPro
//

#import "PPDeliveryManager.h"
#import "PPFirebaseCompat.h"
#import "PPStaffAuth.h"
#import "UserManager.h"
#import "UserModel.h"

NSString * const PPDeliveryOrdersDidChangeNotification = @"PPDeliveryOrdersDidChangeNotification";
static NSString * const PPDeliveryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

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
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> branchesListener;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *primaryOrders;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *secondaryOrders;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *branchNameCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *providerNameCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UserModel *> *providerUserCache;
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

    FIRFirestore *db = [FIRFirestore firestore];
    FIRCollectionReference *ordersRef = [db collectionWithPath:@"Orders"];

    PPStaffDoc *staff = [PPStaffAuth shared].cachedCurrentStaff;
    BOOL hasPaymentAccess = [staff hasAnyPermission:@[kStaffPermPaymentsView, kStaffPermPaymentsManage]];

    __weak typeof(self) weakSelf = self;
    void (^applyDocuments)(NSArray<FIRDocumentSnapshot *> *, BOOL) = ^(NSArray<FIRDocumentSnapshot *> *documents, BOOL primary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSMutableArray<PPDeliveryOrderModel *> *orders = [NSMutableArray arrayWithCapacity:documents.count];
        NSMutableSet<NSString *> *providerIDs = [NSMutableSet set];
        for (FIRDocumentSnapshot *doc in documents) {
            NSDictionary *data = doc.data;
            if (!data) continue;
            PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:data withID:doc.documentID];
            [orders addObject:order];

            // Collect marketplace provider IDs for pre-fetching
            if (order.marketplaceProviderID.length > 0 &&
                ![order.marketplaceProviderID isEqualToString:@"platform"] &&
                ![order.marketplaceProviderID isEqualToString:PPDeliveryOfficialSupportUserID]) {
                [providerIDs addObject:order.marketplaceProviderID];
            }
        }

        if (primary) {
            strongSelf.primaryOrders = [orders copy];
        } else {
            strongSelf.secondaryOrders = [orders copy];
        }

        // Pre-fetch provider names for unique provider IDs
        [strongSelf prefetchProviderNamesForIDs:providerIDs.allObjects];

        [strongSelf mergeAndPublishOrders];
    };

    if (hasPaymentAccess) {
        FIRQuery *query = [[ordersRef queryWhereField:@"deliveryStatus" in:PPDeliveryAllStatuses()] queryOrderedByField:@"createdAt" descending:YES];
        self.primaryListener = [query addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                NSLog(@"[PPDeliveryManager] ❌ Admin delivery listener error: %@", error.localizedDescription);
                return;
            }
            applyDocuments(snapshot.documents ?: @[], YES);
        }];
        return;
    }

    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid.length) {
        NSLog(@"[PPDeliveryManager] ❌ No authenticated user — cannot listen for orders.");
        return;
    }

    FIRQuery *openQuery = [[ordersRef queryWhereField:@"deliveryStatus" isEqualTo:PPDeliveryStatusRequested] queryOrderedByField:@"createdAt" descending:YES];
    FIRQuery *assignedQuery = [[[ordersRef queryWhereField:@"deliveryUserId" isEqualTo:uid]
                                queryWhereField:@"deliveryStatus" in:PPAssignedDeliveryStatuses()]
                               queryOrderedByField:@"createdAt" descending:YES];

    self.primaryListener = [openQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPDeliveryManager] ❌ Open delivery listener error: %@", error.localizedDescription);
            return;
        }
        applyDocuments(snapshot.documents ?: @[], YES);
    }];

    self.secondaryListener = [assignedQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PPDeliveryManager] ❌ Assigned delivery listener error: %@", error.localizedDescription);
            return;
        }
        applyDocuments(snapshot.documents ?: @[], NO);
    }];
}

- (void)stopListening {
    [self.primaryListener remove];
    [self.secondaryListener remove];
    [self.branchesListener remove];
    self.primaryListener = nil;
    self.secondaryListener = nil;
    self.branchesListener = nil;
    self.primaryOrders = @[];
    self.secondaryOrders = @[];
    self.allOrders = @[];
}

- (void)mergeAndPublishOrders {
    NSMutableDictionary<NSString *, PPDeliveryOrderModel *> *merged = [NSMutableDictionary dictionary];
    for (PPDeliveryOrderModel *order in self.primaryOrders) {
        if (order.orderId.length) merged[order.orderId] = order;
    }
    for (PPDeliveryOrderModel *order in self.secondaryOrders) {
        if (order.orderId.length) merged[order.orderId] = order;
    }

    // Enrich orders with cached branch names
    for (PPDeliveryOrderModel *order in merged.allValues) {
        if (order.branchName.length == 0 && order.branchID.length > 0) {
            NSString *cached = self.branchNameCache[order.branchID];
            if (cached.length) {
                order.branchName = cached;
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
        [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryOrdersDidChangeNotification object:self];
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

#pragma mark - Cloud Function Actions

- (void)performDeliveryAction:(NSString *)action orderId:(NSString *)orderId note:(NSString *)note completion:(PPDeliveryActionBlock)completion {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"deliveryTransitionOrderStatus"];
    callable.timeoutInterval = 30;

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"action"]  = action;
    data[@"orderId"] = orderId ?: @"";
    data[@"note"]    = (note.length > 0) ? note : @"Action performed from Pro app";

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
    [self performDeliveryAction:@"order_accept_delivery" orderId:orderId note:@"Delivery accepted from Pro app" completion:completion];
}

@end
