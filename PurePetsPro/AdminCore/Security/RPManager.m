//
//  RPManager.m
//  PurePetsPro
//

#import "RPManager.h"
#import "PPStaffAuth.h"
#import "UserManager.h"
#import "UserModel.h"

@interface RPManager ()
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> reg;
@end

@implementation RPManager

+ (instancetype)shared
{
    static RPManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [RPManager new];
    });
    return manager;
}

- (id<FIRListenerRegistration>)listenPermissionsForUID:(NSString *)uid
                                              onChange:(void(^)(NSDictionary<NSString *, NSNumber *> *perms,
                                                                NSError * _Nullable error))block
{
    if (uid.length == 0) {
        if (block) {
            block(@{}, [NSError errorWithDomain:@"RPManager"
                                           code:1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        }
        return nil;
    }

    // Helper: load permissions from UsersCol subcollections
    void (^loadUsersColPermissions)(void) = ^{
        UserModel *fallbackUser = [UserManager shared].currentUser;
        if (fallbackUser && [fallbackUser.uid isEqualToString:uid]) {
            [fallbackUser fetchPermissionsWithCompletion:^(NSDictionary<NSString *, NSNumber *> *perms,
                                                          NSError * _Nullable permError) {
                if (block) block(perms ?: @{}, permError);
            }];
        } else {
            UserModel *tempUser = [UserModel new];
            tempUser.uid = uid;
            [tempUser fetchPermissionsWithCompletion:^(NSDictionary<NSString *, NSNumber *> *perms,
                                                      NSError * _Nullable permError) {
                if (block) block(perms ?: @{}, permError);
            }];
        }
    };

    return [[PPStaffAuth shared] listenStaffDoc:uid onChange:^(PPStaffDoc * _Nullable doc, NSError * _Nullable error) {
        if (error) {
            // staff_users read failed (e.g. permission denied) — fall back to UsersCol
            loadUsersColPermissions();
            return;
        }

        if (doc) {
            NSMutableDictionary<NSString *, NSNumber *> *permissionMap = [NSMutableDictionary dictionary];
            for (NSString *permission in doc.permissions) {
                if (permission.length > 0) {
                    permissionMap[permission] = @YES;
                }
            }
            if (block) block(permissionMap.copy, nil);
            return;
        }

        // No staff_users doc — fall back to UsersCol permissions subcollections
        loadUsersColPermissions();
    }];
}

- (void)fetchIDTokenClaims:(void(^)(NSDictionary * _Nullable claims,
                                    NSError * _Nullable error))completion
{
    FIRUser *user = [FIRAuth auth].currentUser;
    if (!user) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"RPManager"
                                                code:2
                                            userInfo:@{NSLocalizedDescriptionKey: @"No current user"}]);
        }
        return;
    }

    [user getIDTokenResultForcingRefresh:YES completion:^(FIRAuthTokenResult * _Nullable tokenResult, NSError * _Nullable error) {
        if (completion) completion(tokenResult.claims, error);
    }];
}

- (void)listenForRoleChangesOfUser:(NSString *)uid
                        completion:(void(^)(UserModel * _Nullable user,
                                            NSError * _Nullable error))completion
{
    if (uid.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"RPManager"
                                                code:3
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing uid"}]);
        }
        return;
    }

    [self.reg remove];
    self.reg = nil;

    FIRDocumentReference *doc = [[[FIRFirestore firestore] collectionWithPath:kPPUsersCol] documentWithPath:uid];
    __weak typeof(self) weakSelf = self;
    self.reg = [doc addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        void (^applyStaffOverlay)(UserModel * _Nullable) = ^(UserModel * _Nullable baseUser) {
            [[PPStaffAuth shared] fetchStaffDoc:uid completion:^(PPStaffDoc * _Nullable staffDoc, NSError * _Nullable staffError) {
                if (staffError) {
                    // staff_users read failed — still load UsersCol permissions for the base user
                    if (baseUser) {
                        [baseUser fetchPermissionsWithCompletion:^(NSDictionary<NSString *, NSNumber *> *perms,
                                                                  NSError * _Nullable permError) {
                            (void)permError;
                            [[UserManager shared] p_cacheUser:baseUser];
                            if (completion) completion(baseUser, nil);
                        }];
                    } else {
                        if (completion) completion(nil, nil);
                    }
                    return;
                }

                UserModel *user = baseUser;
                if (!user && staffDoc) {
                    user = [UserManager shared].currentUser;
                    if (!user || ![user.uid isEqualToString:uid]) {
                        user = [UserModel new];
                        user.uid = uid;
                    }
                }

                if (staffDoc && user) {
                    if (!staffDoc.isActive) {
                        user.isBlocked = YES;
                    } else {
                        UserRole mappedRole = [PPStaffAuth legacyRoleFromStaffRole:staffDoc.role];
                        if (mappedRole != UserRoleUnknown) {
                            user.role = mappedRole;
                            user.isSuperAdmin = [staffDoc.role isEqualToString:PPStaffRoleSuperAdmin];
                            user.isAdmin = user.isSuperAdmin ||
                                           mappedRole == UserRoleAdmin ||
                                           mappedRole == UserRoleSuperAdmin ||
                                           mappedRole == UserRoleOwner;
                            user.isBlocked = NO;
                        }
                    }

                    NSMutableDictionary<NSString *, NSNumber *> *permissionMap =
                        [NSMutableDictionary dictionaryWithDictionary:user.permissions ?: @{}];
                    for (NSString *permission in staffDoc.permissions) {
                        if (permission.length > 0) {
                            permissionMap[permission] = @YES;
                        }
                    }
                    user.permissions = permissionMap;

                    if (user) {
                        [[UserManager shared] p_cacheUser:user];
                    }
                    if (completion) completion(user, nil);
                } else if (user) {
                    // No staff doc — load permissions from UsersCol subcollections
                    [user fetchPermissionsWithCompletion:^(NSDictionary<NSString *, NSNumber *> *perms,
                                                          NSError * _Nullable permError) {
                        (void)permError;
                        [[UserManager shared] p_cacheUser:user];
                        if (completion) completion(user, nil);
                    }];
                } else {
                    if (completion) completion(nil, nil);
                }
            }];
        };

        if (!snapshot.exists) {
            applyStaffOverlay(nil);
            return;
        }

        UserModel *user = [[UserModel alloc] initWithSnapshot:snapshot];
        applyStaffOverlay(user);
    }];
}

- (void)stopListening
{
    [self.reg remove];
    self.reg = nil;
}

@end
