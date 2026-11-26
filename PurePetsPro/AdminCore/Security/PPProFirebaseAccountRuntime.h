#import <Foundation/Foundation.h>
@class FIRAuth, FIRAuthCredential, FIRPhoneAuthProvider, FIRFirestore, FIRFunctions, FIRStorage, FIRUser;
NS_ASSUME_NONNULL_BEGIN

/// A named Firebase app is one independent authentication and database namespace.
/// The session coordinator must verify Pro access and perform all runtime barriers
/// before installing it. This type never mutates the default Firebase identity.
@interface PPProFirebaseAccountRuntime : NSObject
@property(nonatomic,readonly) NSUUID *slotID;
@property(nonatomic,copy,readonly,nullable) NSString *expectedUID;
@property(nonatomic,copy,readonly,nullable) NSString *currentUID;
@property(nonatomic,readonly) BOOL isAuthorizedSession;
@property(nonatomic,readonly) BOOL isInvalidated;
@property(nonatomic,readonly) BOOL hasMismatchedSignedInUser;
@property(nonatomic,readonly) FIRAuth *auth;
@property(nonatomic,readonly,nullable) FIRFirestore *firestore;
@property(nonatomic,readonly,nullable) FIRFunctions *functions;
@property(nonatomic,readonly,nullable) FIRStorage *storage;
+ (nullable instancetype)openSlot:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID error:(NSError **)error;
+ (nullable instancetype)openRememberedUID:(NSString *)uid error:(NSError **)error;
+ (nullable instancetype)createProvisionalSlotWithError:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
- (FIRPhoneAuthProvider *)phoneProvider;
- (void)authenticateCredential:(FIRAuthCredential *)credential completion:(void (^)(FIRUser * _Nullable user, NSError * _Nullable error))completion;
- (void)validateSessionWithCompletion:(void (^)(FIRUser * _Nullable user, NSError * _Nullable error))completion;
- (void)waitForPendingWritesWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)signOutAndInvalidate:(BOOL)invalidate completion:(void (^ _Nullable)(NSError * _Nullable error))completion;
- (void)teardownSlotAppWithCompletion:(void (^ _Nullable)(BOOL deleted, NSError * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
