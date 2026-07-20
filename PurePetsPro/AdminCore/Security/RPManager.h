//
//  RPManager.h
//  PurePetsPro
//

#import <Foundation/Foundation.h>
#import "PPFirebaseCompat.h"
#import "PPRolePermission.h"

NS_ASSUME_NONNULL_BEGIN

@class UserModel;

@interface RPManager : NSObject

+ (instancetype)shared;

- (id<FIRListenerRegistration> _Nullable)listenPermissionsForUID:(NSString *)uid
                                                       onChange:(void(^)(NSDictionary<NSString *, NSNumber *> *perms,
                                                                         NSError * _Nullable error))block;

- (void)fetchIDTokenClaims:(void(^)(NSDictionary * _Nullable claims,
                                    NSError * _Nullable error))completion;

- (void)listenForRoleChangesOfUser:(NSString *)uid
                        completion:(void(^)(UserModel * _Nullable user,
                                            NSError * _Nullable error))completion;

- (void)stopListening;

@end

NS_ASSUME_NONNULL_END
