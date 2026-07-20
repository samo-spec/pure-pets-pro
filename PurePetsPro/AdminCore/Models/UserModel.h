//
//  UserModel.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 21/08/2025.
//  Refactored for best practices
//
#import <Foundation/Foundation.h>
#import "XLForm.h"
#import "PPRolePermission.h"

@class FIRDocumentSnapshot;
@class FIRUser;
@protocol FIRListenerRegistration;

@class PPAddressModel;
@class UserPaymentInstrument;

NS_ASSUME_NONNULL_BEGIN

// ===== Login Source =====
typedef NS_ENUM(NSInteger, UserLoginSource) {
    UserLoginSourceUnknown = 0,
    UserLoginSourcePPUsers = 1,   // From main PurePets app
    UserLoginSourcePPAdmin = 2    // From PurePets Admin app
};

// ===== Online Status =====
typedef NS_ENUM(NSInteger, OnlineStatus) {
    OnlineStatusOffline = 0,
    OnlineStatusOnline
};

@interface UserModel : NSObject <XLFormOptionObject, NSSecureCoding>
@property (nonatomic, strong, nullable) UserPaymentInstrument *SelectedInstrument;
#pragma mark - Core Profile
@property (nonatomic, assign) OnlineStatus onlineStatus;
@property (nonatomic, strong, nullable) NSDate *lastSeen;

#pragma mark - Identity
@property (nonatomic, copy) NSString *ID;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *UserEmail;
@property (nonatomic, copy) NSString *UserName;

#pragma mark - From Server
// Compatibility aliases are kept for older call sites; they are mirrored to canonical fields internally.
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *photoURL;
@property (nonatomic, copy, nullable) NSString *FirstName;
@property (nonatomic, copy, nullable) NSString *LastName;
@property (nonatomic, copy, nullable) NSString *MobileNo;
@property (nonatomic, copy, nullable) NSString *UserAbout;
@property (nonatomic, copy, nullable) NSString *UserImageName;
@property (nonatomic, strong, nullable) NSURL *UserImageUrl;

#pragma mark - Presence Convenience
@property (nonatomic, assign) BOOL isOnline; // -> onlineStatus

#pragma mark - Status & Meta
@property (nonatomic, strong, nullable) NSDate *loginDate;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@property (nonatomic, assign) NSInteger CountryID;
@property (nonatomic, copy) NSString *PPUserTokenID;
@property (nonatomic, copy) NSString *PPAdminTokenID;
@property (nonatomic, copy) NSString *PPProTokenID;

#pragma mark - Roles
@property (nonatomic, assign) UserRole role;
@property (nonatomic, assign) BOOL isAdmin;
@property (nonatomic, assign) BOOL isSuperAdmin;
@property (nonatomic, assign) BOOL isBlocked;

#pragma mark - Permissions
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *permissions;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> permissionsListener;

#pragma mark - Convenience Flags
@property (nonatomic, readonly) BOOL canPostAds;
@property (nonatomic, readonly) BOOL canSellNew;
@property (nonatomic, readonly) BOOL canSellUsed;
@property (nonatomic, readonly) BOOL canAdoption;
@property (nonatomic, readonly) BOOL canManageStore;
@property (nonatomic, readonly) BOOL canModeration;
@property (nonatomic, readonly) BOOL isAdminAll;

@property (nonatomic, readonly) BOOL isStoreManager;
@property (nonatomic, readonly) BOOL isFoodManager;
@property (nonatomic, readonly) BOOL isModerator;
@property (nonatomic, readonly) BOOL isOwner;
@property (nonatomic, readonly) BOOL isVet;

#pragma mark - Service Provider
@property (nonatomic, assign) BOOL canOfferServices;
@property (nonatomic, assign) BOOL canDelivery;

#pragma mark - Partner Access Model
@property (nonatomic, assign) BOOL canOfferServicesFeature;
@property (nonatomic, assign) BOOL canDeliveryFeature;
@property (nonatomic, assign) BOOL canDeliveryCompanyFeature;
@property (nonatomic, assign) BOOL canVetFeature;
@property (nonatomic, assign) BOOL canPharmacyFeature;
@property (nonatomic, assign) BOOL canAccessProviderMarketplaceFeature;
@property (nonatomic, assign) BOOL partnerOnboardingVisible;
@property (nonatomic, copy) NSString *partnerApplicationStatus;
@property (nonatomic, copy, nullable) NSString *selectedPartnerType;
@property (nonatomic, assign) BOOL canAccessPartnerAppPermission;
@property (nonatomic, assign) BOOL canManageDeliveryPermission;
@property (nonatomic, assign) BOOL canManageServiceProviderPermission;
@property (nonatomic, assign) BOOL canManageVetPermission;
@property (nonatomic, assign) BOOL canPostVetProfilePermission;
@property (nonatomic, assign) BOOL canEditVetInfoPermission;
@property (nonatomic, assign) BOOL canManagePetMedicinesPermission;

#pragma mark - Verification / Plan
@property (nonatomic, assign, getter=isVerified) BOOL verified;
@property (nonatomic, copy, nullable) NSString *plan;

#pragma mark - Login Source
@property (nonatomic, assign) UserLoginSource loginSource;
@property (nonatomic, copy, nullable) NSString *authPassword; // session-only
@property (nonatomic, readonly) BOOL hasAuthCredentials;

#pragma mark - Addresses
@property (nonatomic, strong) NSMutableArray<PPAddressModel *> *Addresses;

#pragma mark - Initializers
- (instancetype)initWithDict:(NSDictionary *)dict;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;

#pragma mark - Firestore Sync
- (NSDictionary *)toDictionary;
- (void)SYNC:(void(^)(NSError * _Nullable error))completion;

#pragma mark - Permissions API
- (void)fetchPermissionsWithCompletion:(void (^_Nullable)(NSDictionary<NSString *, NSNumber *> *perms,
                                                         NSError * _Nullable error))completion;
- (void)startListeningPermissionsWithChange:(void (^)(NSDictionary<NSString *, NSNumber *> *perms))changeBlock;
- (void)stopListeningPermissions;
- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                completion:(void (^)(NSError * _Nullable error))completion;
- (BOOL)hasPermissionNamed:(NSString *)permName;
- (BOOL)hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames;

#pragma mark - Cache Helpers
+ (nullable instancetype)loadSavedUserWithUID:(NSString *)uid;
- (void)saveToDisk;
+ (void)clearCachedUserWithUID:(NSString *)uid;
- (void)clearSensitiveAuthCache;

#pragma mark - Builders
+ (instancetype)fromAuthUser:(FIRUser *)auth
                     rootDoc:(nullable NSDictionary *)root
                 permissions:(nullable NSDictionary<NSString *, NSNumber *> *)perms
                      claims:(nullable NSDictionary *)claims;
+ (void)loadCurrentUserModelWithCompletion:(void(^)(UserModel *_Nullable u,
                                                    NSError *_Nullable err))completion;
 
#pragma mark - Display Helpers
- (NSString *)PPBestDisplayName;
 
@end
/**************************************************************************************************************************************************************************************/
NS_ASSUME_NONNULL_END
