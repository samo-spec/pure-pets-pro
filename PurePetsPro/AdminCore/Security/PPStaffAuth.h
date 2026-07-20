//
//  PPStaffAuth.h
//  PurePetsAdmin
//
//  Staff authorization — reads `staff_users/{uid}` as the single source of truth.
//  Replaces legacy PPRolePermission enum-based auth and triple-subcollection reads.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Staff Roles (string constants matching infra)

typedef NSString * PPStaffRole NS_TYPED_ENUM;

extern PPStaffRole const PPStaffRoleSuperAdmin;
extern PPStaffRole const PPStaffRoleOwner;
extern PPStaffRole const PPStaffRoleOperationsManager;
extern PPStaffRole const PPStaffRoleInventoryManager;
extern PPStaffRole const PPStaffRolePaymentsManager;
extern PPStaffRole const PPStaffRoleSupportAgent;
extern PPStaffRole const PPStaffRoleViewer;

#pragma mark - Staff Status

typedef NSString * PPStaffStatus NS_TYPED_ENUM;

extern PPStaffStatus const PPStaffStatusActive;
extern PPStaffStatus const PPStaffStatusDisabled;

#pragma mark - Firestore Paths

extern NSString * const kStaffUsersCollection;
extern NSString * const kStaffRolesCollection;

#pragma mark - Permission Keys (canonical catalog)

// Dashboard
extern NSString * const kStaffPermDashboardView;

// Staff management
extern NSString * const kStaffPermStaffView;
extern NSString * const kStaffPermStaffManage;

// Users
extern NSString * const kStaffPermUsersFeaturesView;
extern NSString * const kStaffPermUsersFeaturesManage;
extern NSString * const kStaffPermUsersSubscriptionsView;
extern NSString * const kStaffPermUsersSubscriptionsManage;
extern NSString * const kStaffPermUsersRestrictionsView;
extern NSString * const kStaffPermUsersRestrictionsManage;

// Stock
extern NSString * const kStaffPermStockView;
extern NSString * const kStaffPermStockManage;

// Listings
extern NSString * const kStaffPermListingsView;
extern NSString * const kStaffPermListingsModerate;

// Payments
extern NSString * const kStaffPermPaymentsView;
extern NSString * const kStaffPermPaymentsManage;
extern NSString * const kStaffPermRefundsManage;

// POS
extern NSString * const kStaffPermPosView;
extern NSString * const kStaffPermPosManage;

// Branches
extern NSString * const kStaffPermBranchesView;
extern NSString * const kStaffPermBranchesManage;

// Agents
extern NSString * const kStaffPermAgentsView;
extern NSString * const kStaffPermAgentsManage;

// Support
extern NSString * const kStaffPermSupportView;
extern NSString * const kStaffPermSupportManage;

// Services
extern NSString * const kStaffPermServicesView;
extern NSString * const kStaffPermServicesManage;

// Settings
extern NSString * const kStaffPermSettingsView;
extern NSString * const kStaffPermSettingsManage;

// Notifications
extern NSString * const kStaffPermNotificationsView;
extern NSString * const kStaffPermNotificationsSend;

// Accounting
extern NSString * const kStaffPermAccountingView;
extern NSString * const kStaffPermAccountingManage;

// Reports
extern NSString * const kStaffPermReportsView;
extern NSString * const kStaffPermReportsExport;

// Audit
extern NSString * const kStaffPermAuditView;

// Moderation
extern NSString * const kStaffPermModerationView;
extern NSString * const kStaffPermModerationManage;

// Banners
extern NSString * const kStaffPermBannersView;
extern NSString * const kStaffPermBannersManage;

// Categories
extern NSString * const kStaffPermCategoriesView;
extern NSString * const kStaffPermCategoriesManage;

// Veterinarians
extern NSString * const kStaffPermVeterinariansView;
extern NSString * const kStaffPermVeterinariansManage;

#pragma mark - Staff Document Model

@interface PPStaffDoc : NSObject

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) PPStaffRole role;
@property (nonatomic, copy) PPStaffStatus status;
@property (nonatomic, copy) NSArray<NSString *> *permissions;
@property (nonatomic, copy, nullable) NSDictionary *scope;
@property (nonatomic, assign) NSInteger claimsVersion;
@property (nonatomic, copy, nullable) NSString *updatedBy;

- (instancetype)initWithDictionary:(NSDictionary *)dict uid:(NSString *)uid;
- (BOOL)isActive;
- (BOOL)isAdmin;
- (BOOL)hasPermission:(NSString *)perm;
- (BOOL)hasAnyPermission:(NSArray<NSString *> *)perms;

@end

#pragma mark - PPStaffAuth Singleton

@protocol FIRListenerRegistration;

typedef void (^PPStaffDocCompletion)(PPStaffDoc * _Nullable doc, NSError * _Nullable error);
typedef void (^PPStaffListCompletion)(NSArray<PPStaffDoc *> * _Nullable docs, NSError * _Nullable error);

@interface PPStaffAuth : NSObject

+ (instancetype)shared;

/// Fetch a single staff doc by UID.
- (void)fetchStaffDoc:(NSString *)uid completion:(PPStaffDocCompletion)completion;

/// Listen to a single staff doc (real-time updates).
- (id<FIRListenerRegistration>)listenStaffDoc:(NSString *)uid
                                     onChange:(PPStaffDocCompletion)block;

/// Fetch all active staff members.
- (void)fetchAllStaff:(PPStaffListCompletion)completion;

/// Listen to all staff members.
- (id<FIRListenerRegistration>)listenAllStaff:(PPStaffListCompletion)block;

/// Check if current user is staff.
- (void)checkCurrentUserIsStaff:(void(^)(BOOL isStaff, PPStaffDoc * _Nullable doc))completion;

/// Get cached staff doc for current user (nil if not fetched yet).
@property (nonatomic, strong, nullable, readonly) PPStaffDoc *cachedCurrentStaff;

/// Refresh cached staff doc for current user.
- (void)refreshCurrentStaff:(nullable PPStaffDocCompletion)completion;

#pragma mark - Role Mapping (legacy → new)

/// Map legacy UserRole integer to new staff role string.
+ (PPStaffRole)staffRoleFromLegacyRole:(NSInteger)legacyRole;

/// Map new staff role string to legacy UserRole integer (for backward compat).
+ (NSInteger)legacyRoleFromStaffRole:(PPStaffRole)staffRole;

/// Default permissions for a staff role.
+ (NSArray<NSString *> *)defaultPermissionsForStaffRole:(PPStaffRole)role;

/// All admin roles.
+ (BOOL)isAdminRole:(PPStaffRole)role;

/// Localized role label.
+ (NSString *)localizedRoleName:(PPStaffRole)role;

@end

NS_ASSUME_NONNULL_END
