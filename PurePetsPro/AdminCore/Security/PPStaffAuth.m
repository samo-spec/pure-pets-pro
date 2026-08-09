//
//  PPStaffAuth.m
//  PurePetsAdmin
//
//  Staff authorization — reads `staff_users/{uid}` as the single source of truth.
//

#import "PPStaffAuth.h"
#import "PPFirebaseCompat.h"

#pragma mark - Staff Role Constants

PPStaffRole const PPStaffRoleSuperAdmin        = @"super_admin";
PPStaffRole const PPStaffRoleOwner             = @"owner";
PPStaffRole const PPStaffRoleOperationsManager = @"operations_manager";
PPStaffRole const PPStaffRoleInventoryManager  = @"inventory_manager";
PPStaffRole const PPStaffRolePaymentsManager   = @"payments_manager";
PPStaffRole const PPStaffRoleSupportAgent      = @"support_agent";
PPStaffRole const PPStaffRoleViewer            = @"viewer";

PPStaffStatus const PPStaffStatusActive   = @"active";
PPStaffStatus const PPStaffStatusDisabled = @"disabled";

NSString * const kStaffUsersCollection = @"staff_users";
NSString * const kStaffRolesCollection = @"staff_roles";

#pragma mark - Permission Key Constants

NSString * const kStaffPermDashboardView  = @"dashboard.view";
NSString * const kStaffPermStaffView      = @"staff.view";
NSString * const kStaffPermStaffManage    = @"staff.manage";

NSString * const kStaffPermUsersFeaturesView          = @"users.features.view";
NSString * const kStaffPermUsersFeaturesManage        = @"users.features.manage";
NSString * const kStaffPermUsersSubscriptionsView     = @"users.subscriptions.view";
NSString * const kStaffPermUsersSubscriptionsManage   = @"users.subscriptions.manage";
NSString * const kStaffPermUsersRestrictionsView      = @"users.restrictions.view";
NSString * const kStaffPermUsersRestrictionsManage    = @"users.restrictions.manage";

NSString * const kStaffPermStockView      = @"stock.view";
NSString * const kStaffPermStockManage    = @"stock.manage";

NSString * const kStaffPermListingsView     = @"listings.view";
NSString * const kStaffPermListingsModerate = @"listings.moderate";

NSString * const kStaffPermPaymentsView   = @"payments.view";
NSString * const kStaffPermPaymentsManage = @"payments.manage";
NSString * const kStaffPermRefundsManage  = @"refunds.manage";

NSString * const kStaffPermPosView   = @"pos.view";
NSString * const kStaffPermPosManage = @"pos.manage";

NSString * const kStaffPermBranchesView   = @"branches.view";
NSString * const kStaffPermBranchesManage = @"branches.manage";

NSString * const kStaffPermAgentsView   = @"agents.view";
NSString * const kStaffPermAgentsManage = @"agents.manage";

NSString * const kStaffPermSupportView   = @"support.view";
NSString * const kStaffPermSupportManage = @"support.manage";

NSString * const kStaffPermServicesView   = @"services.view";
NSString * const kStaffPermServicesManage = @"services.manage";

NSString * const kStaffPermSettingsView   = @"settings.view";
NSString * const kStaffPermSettingsManage = @"settings.manage";

NSString * const kStaffPermNotificationsView = @"notifications.view";
NSString * const kStaffPermNotificationsSend = @"notifications.send";

NSString * const kStaffPermAccountingView   = @"accounting.view";
NSString * const kStaffPermAccountingManage = @"accounting.manage";

NSString * const kStaffPermReportsView   = @"reports.view";
NSString * const kStaffPermReportsExport = @"reports.export";

NSString * const kStaffPermAuditView = @"audit.view";

NSString * const kStaffPermModerationView   = @"moderation.view";
NSString * const kStaffPermModerationManage = @"moderation.manage";

NSString * const kStaffPermBannersView   = @"banners.view";
NSString * const kStaffPermBannersManage = @"banners.manage";

NSString * const kStaffPermCategoriesView   = @"categories.view";
NSString * const kStaffPermCategoriesManage = @"categories.manage";

NSString * const kStaffPermVeterinariansView   = @"veterinarians.view";
NSString * const kStaffPermVeterinariansManage = @"veterinarians.manage";

#pragma mark - PPStaffDoc

@implementation PPStaffDoc

- (instancetype)initWithDictionary:(NSDictionary *)dict uid:(NSString *)uid {
    if ((self = [super init])) {
        _uid = uid ?: @"";
        _role = [dict[@"role"] isKindOfClass:NSString.class] ? dict[@"role"] : PPStaffRoleViewer;
        _status = [dict[@"status"] isKindOfClass:NSString.class] ? dict[@"status"] : PPStaffStatusDisabled;
        _permissions = [dict[@"permissions"] isKindOfClass:NSArray.class] ? dict[@"permissions"] : @[];
        _scope = [dict[@"scope"] isKindOfClass:NSDictionary.class] ? dict[@"scope"] : nil;
        _claimsVersion = [dict[@"claimsVersion"] isKindOfClass:NSNumber.class]
            ? [dict[@"claimsVersion"] integerValue] : 0;
        _updatedBy = [dict[@"updatedBy"] isKindOfClass:NSString.class] ? dict[@"updatedBy"] : nil;
    }
    return self;
}

- (BOOL)isActive {
    return [self.status isEqualToString:PPStaffStatusActive];
}

- (BOOL)isAdmin {
    return [PPStaffAuth isAdminRole:self.role] && self.isActive;
}

- (BOOL)hasPermission:(NSString *)perm {
    if (!perm.length) return NO;
    if (self.isAdmin) return YES;
    return [self.permissions containsObject:perm];
}

- (BOOL)hasAnyPermission:(NSArray<NSString *> *)perms {
    if (self.isAdmin) return YES;
    for (NSString *p in perms) {
        if ([self.permissions containsObject:p]) return YES;
    }
    return NO;
}

@end

#pragma mark - PPStaffAuth

@interface PPStaffAuth ()
@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong, nullable) PPStaffDoc *cachedCurrentStaff;
@end

@implementation PPStaffAuth

+ (instancetype)shared {
    static PPStaffAuth *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [PPStaffAuth new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (FIRDocumentReference *)staffDoc:(NSString *)uid {
    return [[self.db collectionWithPath:kStaffUsersCollection] documentWithPath:uid];
}

- (void)fetchStaffDoc:(NSString *)uid completion:(PPStaffDocCompletion)completion {
    if (!uid.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"PPStaffAuth" code:1
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[self staffDoc:uid] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            if (!error && snap.exists) {
                PPStaffDoc *doc = [[PPStaffDoc alloc] initWithDictionary:snap.data uid:snap.documentID];
                if (completion) completion(doc, nil);
                return;
            }
            
            // Security boundary: staff_users/{uid} is the only authoritative staff
            // record. Never promote accountType/staffProfile from UsersCol after a
            // staff read fails; that user-controlled profile path can otherwise
            // become a privilege-escalation fallback. A missing or failed staff
            // read is therefore fail-closed as "not staff".
            if (completion) completion(nil, error);
        });
    }];
}

- (id<FIRListenerRegistration>)listenStaffDoc:(NSString *)uid onChange:(PPStaffDocCompletion)block {
    if (!uid.length) {
        if (block) block(nil, [NSError errorWithDomain:@"PPStaffAuth" code:2
                                              userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        return nil;
    }
    return [[self staffDoc:uid] addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error) { if (block) block(nil, error); return; }
        if (!snap.exists) { if (block) block(nil, nil); return; }
        PPStaffDoc *doc = [[PPStaffDoc alloc] initWithDictionary:snap.data uid:snap.documentID];
        if (block) block(doc, nil);
    }];
}

- (void)fetchAllStaff:(PPStaffListCompletion)completion {
    FIRQuery *q = [[self.db collectionWithPath:kStaffUsersCollection]
                   queryWhereField:@"status" isEqualTo:PPStaffStatusActive];
    [q getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { if (completion) completion(nil, error); return; }
            NSMutableArray *docs = [NSMutableArray array];
            for (FIRDocumentSnapshot *s in snap.documents) {
                [docs addObject:[[PPStaffDoc alloc] initWithDictionary:s.data uid:s.documentID]];
            }
            if (completion) completion(docs, nil);
        });
    }];
}

- (id<FIRListenerRegistration>)listenAllStaff:(PPStaffListCompletion)block {
    return [[self.db collectionWithPath:kStaffUsersCollection]
            addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (error) { if (block) block(nil, error); return; }
        NSMutableArray *docs = [NSMutableArray array];
        for (FIRDocumentSnapshot *s in snap.documents) {
            [docs addObject:[[PPStaffDoc alloc] initWithDictionary:s.data uid:s.documentID]];
        }
        if (block) block(docs, nil);
    }];
}

- (void)checkCurrentUserIsStaff:(void(^)(BOOL, PPStaffDoc * _Nullable))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid.length) {
        if (completion) completion(NO, nil);
        return;
    }
    [self fetchStaffDoc:uid completion:^(PPStaffDoc * _Nullable doc, NSError * _Nullable error) {
        BOOL isStaff = (doc != nil && doc.isActive);
        if (isStaff) self.cachedCurrentStaff = doc;
        if (completion) completion(isStaff, doc);
    }];
}

- (void)refreshCurrentStaff:(PPStaffDocCompletion)completion {
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid.length) {
        self.cachedCurrentStaff = nil;
        if (completion) completion(nil, nil);
        return;
    }
    [self fetchStaffDoc:uid completion:^(PPStaffDoc * _Nullable doc, NSError * _Nullable error) {
        self.cachedCurrentStaff = doc;
        if (completion) completion(doc, error);
    }];
}

#pragma mark - Legacy Role Mapping

+ (PPStaffRole)staffRoleFromLegacyRole:(NSInteger)legacyRole {
    switch (legacyRole) {
        case 8: return PPStaffRoleSuperAdmin;
        case 5: return PPStaffRoleOwner;         // Admin → owner; keep distinct from super_admin.
        case 2: return PPStaffRoleOwner;
        case 6: return PPStaffRoleInventoryManager;
        case 7: return PPStaffRoleInventoryManager;
        case 4: return PPStaffRoleOperationsManager;
        case 3: return PPStaffRoleSupportAgent;   // Vet → support_agent
        default: return PPStaffRoleViewer;
    }
}

+ (NSInteger)legacyRoleFromStaffRole:(PPStaffRole)staffRole {
    if ([staffRole isEqualToString:PPStaffRoleSuperAdmin])        return 8;
    if ([staffRole isEqualToString:PPStaffRoleOwner])             return 2;
    if ([staffRole isEqualToString:PPStaffRoleOperationsManager]) return 4;
    if ([staffRole isEqualToString:PPStaffRoleInventoryManager])  return 6;
    // The legacy enum has no financial-scope role. Fail closed to the ordinary
    // user value rather than encoding payments_manager as full Admin.
    if ([staffRole isEqualToString:PPStaffRolePaymentsManager])   return 1;
    if ([staffRole isEqualToString:PPStaffRoleSupportAgent])      return 3;
    if ([staffRole isEqualToString:PPStaffRoleViewer])            return 1;
    return 0;
}

+ (BOOL)isAdminRole:(PPStaffRole)role {
    return [role isEqualToString:PPStaffRoleSuperAdmin] ||
           [role isEqualToString:PPStaffRoleOwner];
}

+ (NSArray<NSString *> *)defaultPermissionsForStaffRole:(PPStaffRole)role {
    if ([role isEqualToString:PPStaffRoleSuperAdmin]) {
        return @[
            kStaffPermDashboardView, kStaffPermStaffView, kStaffPermStaffManage,
            kStaffPermUsersFeaturesView, kStaffPermUsersFeaturesManage,
            kStaffPermUsersSubscriptionsView, kStaffPermUsersSubscriptionsManage,
            kStaffPermUsersRestrictionsView, kStaffPermUsersRestrictionsManage,
            kStaffPermStockView, kStaffPermStockManage,
            kStaffPermListingsView, kStaffPermListingsModerate,
            kStaffPermPaymentsView, kStaffPermPaymentsManage, kStaffPermRefundsManage,
            kStaffPermPosView, kStaffPermPosManage,
            kStaffPermBranchesView, kStaffPermBranchesManage,
            kStaffPermAgentsView, kStaffPermAgentsManage,
            kStaffPermSupportView, kStaffPermSupportManage,
            kStaffPermServicesView, kStaffPermServicesManage,
            kStaffPermSettingsView, kStaffPermSettingsManage,
            kStaffPermNotificationsView, kStaffPermNotificationsSend,
            kStaffPermAccountingView, kStaffPermAccountingManage,
            kStaffPermReportsView, kStaffPermReportsExport,
            kStaffPermAuditView,
            kStaffPermModerationView, kStaffPermModerationManage,
            kStaffPermBannersView, kStaffPermBannersManage,
            kStaffPermCategoriesView, kStaffPermCategoriesManage,
            kStaffPermVeterinariansView, kStaffPermVeterinariansManage
        ];
    }
    if ([role isEqualToString:PPStaffRoleOwner]) {
        return @[
            kStaffPermDashboardView, kStaffPermStaffView, kStaffPermStaffManage,
            kStaffPermUsersFeaturesView, kStaffPermUsersFeaturesManage,
            kStaffPermUsersSubscriptionsView, kStaffPermUsersSubscriptionsManage,
            kStaffPermUsersRestrictionsView, kStaffPermUsersRestrictionsManage,
            kStaffPermStockView, kStaffPermStockManage,
            kStaffPermListingsView, kStaffPermListingsModerate,
            kStaffPermPaymentsView, kStaffPermPaymentsManage, kStaffPermRefundsManage,
            kStaffPermPosView, kStaffPermPosManage,
            kStaffPermBranchesView, kStaffPermBranchesManage,
            kStaffPermAgentsView, kStaffPermAgentsManage,
            kStaffPermSupportView, kStaffPermSupportManage,
            kStaffPermServicesView, kStaffPermServicesManage,
            kStaffPermSettingsView, kStaffPermSettingsManage,
            kStaffPermNotificationsView, kStaffPermNotificationsSend,
            kStaffPermAccountingView, kStaffPermAccountingManage,
            kStaffPermReportsView, kStaffPermReportsExport,
            kStaffPermAuditView,
            kStaffPermModerationView, kStaffPermModerationManage,
            kStaffPermBannersView, kStaffPermBannersManage,
            kStaffPermCategoriesView, kStaffPermCategoriesManage,
            kStaffPermVeterinariansView, kStaffPermVeterinariansManage
        ];
    }
    if ([role isEqualToString:PPStaffRoleOperationsManager]) {
        return @[
            kStaffPermDashboardView, kStaffPermStaffView,
            kStaffPermStockView, kStaffPermStockManage,
            kStaffPermListingsView, kStaffPermListingsModerate,
            kStaffPermBranchesView, kStaffPermBranchesManage,
            kStaffPermAgentsView, kStaffPermAgentsManage,
            kStaffPermServicesView, kStaffPermServicesManage,
            kStaffPermSupportView, kStaffPermSupportManage,
            kStaffPermNotificationsView, kStaffPermNotificationsSend,
            kStaffPermModerationView, kStaffPermModerationManage,
            kStaffPermCategoriesView, kStaffPermCategoriesManage,
            kStaffPermReportsView
        ];
    }
    if ([role isEqualToString:PPStaffRoleInventoryManager]) {
        return @[
            kStaffPermDashboardView,
            kStaffPermStockView, kStaffPermStockManage,
            kStaffPermListingsView,
            kStaffPermBranchesView,
            kStaffPermCategoriesView, kStaffPermCategoriesManage,
            kStaffPermReportsView
        ];
    }
    if ([role isEqualToString:PPStaffRolePaymentsManager]) {
        return @[
            kStaffPermDashboardView,
            kStaffPermPaymentsView, kStaffPermPaymentsManage, kStaffPermRefundsManage,
            kStaffPermPosView, kStaffPermPosManage,
            kStaffPermAccountingView, kStaffPermAccountingManage,
            kStaffPermReportsView, kStaffPermReportsExport
        ];
    }
    if ([role isEqualToString:PPStaffRoleSupportAgent]) {
        return @[
            kStaffPermDashboardView,
            kStaffPermSupportView, kStaffPermSupportManage,
            kStaffPermListingsView,
            kStaffPermUsersFeaturesView,
            kStaffPermUsersRestrictionsView, kStaffPermUsersRestrictionsManage,
            kStaffPermModerationView
        ];
    }
    // Viewer
    return @[kStaffPermDashboardView];
}

+ (NSString *)localizedRoleName:(PPStaffRole)role {
    if ([role isEqualToString:PPStaffRoleSuperAdmin])        return kLang(@"StaffRole_SuperAdmin");
    if ([role isEqualToString:PPStaffRoleOwner])             return kLang(@"StaffRole_Owner");
    if ([role isEqualToString:PPStaffRoleOperationsManager]) return kLang(@"StaffRole_OperationsManager");
    if ([role isEqualToString:PPStaffRoleInventoryManager])  return kLang(@"StaffRole_InventoryManager");
    if ([role isEqualToString:PPStaffRolePaymentsManager])   return kLang(@"StaffRole_PaymentsManager");
    if ([role isEqualToString:PPStaffRoleSupportAgent])      return kLang(@"StaffRole_SupportAgent");
    if ([role isEqualToString:PPStaffRoleViewer])            return kLang(@"StaffRole_Viewer");
    return role ?: @"";
}

@end
