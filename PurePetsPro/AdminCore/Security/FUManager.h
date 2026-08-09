//
//  FUUserDoc.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 02/09/2025.
//


//  FUManager.h
//  Auth + Profile + UserDoc + Users list (no roles/permissions here)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class FIRAuthCredential;
@class FIRDocumentChange;
@class FIRDocumentReference;
@class FIRFirestore;
@class FIRFunctions;
@class FIRQuery;
@class FIRSnapshotMetadata;
@class FIRStorage;
@class FIRUser;
@protocol FIRListenerRegistration;

NS_ASSUME_NONNULL_BEGIN

@class UserModel; // your app's model

// Callbacks
typedef void (^FUErrorBlock)(NSError * _Nullable error);
typedef void (^FUUserBlock)(FIRUser * _Nullable user, NSError * _Nullable error);
typedef void (^FUURLBlock)(NSURL * _Nullable url, NSError * _Nullable error);
typedef void (^FUAnyBlock)(id _Nullable obj, NSError * _Nullable error);

// Users list completions
typedef void (^FUUsersCompletion)(NSArray<UserModel *> * _Nullable users,
                                  FIRSnapshotMetadata * _Nullable metadata,
                                  NSError * _Nullable error);

typedef void (^FUUsersDiffCompletion)(NSArray<UserModel *> * _Nullable users,
                                      NSArray<FIRDocumentChange *> * _Nullable changes,
                                      FIRSnapshotMetadata * _Nullable metadata,
                                      NSError * _Nullable error);

/// Simple wrapper for a subset of UsersCol/<uid> fields we keep handy
@interface FUUserDoc : NSObject
@property (nonatomic, copy, nullable) NSString *uid;
@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, strong, nullable) NSURL *photoURL;
@property (nonatomic, strong, nullable) NSDictionary *raw;
@end


typedef void (^FUProgressBlock)(double fraction); // 0..1



@interface FUManager : NSObject

- (void)updatePhotoImage:(UIImage *)image
         maxDimension_px:(NSUInteger)maxDim
                maxBytes:(NSUInteger)maxBytes
                progress:(FUProgressBlock _Nullable)progress
              completion:(FUURLBlock)completion;


+ (instancetype)shared;

#pragma mark - Photo URL helpers

/// Upload a PNG avatar (e.g., from HXPhotoPicker), store at
/// avatars/{uid}/{timestamp}.png, then update Auth.photoURL + UsersCol/{uid}.UserImageUrl.
/// Returns the final download URL.
- (void)uploadAvatarPNGData:(NSData *)pngData
                 completion:(FUURLBlock)completion;

/// Set the avatar *directly* from an existing URL (no upload).
/// Writes to Auth.photoURL and UsersCol/{uid}.UserImageUrl (and 'photoURL' mirror).
- (void)updatePhotoURL:(NSURL *)url
            completion:(FUErrorBlock)completion;

/// Convenience if you have a string URL
- (void)updatePhotoURLString:(NSString *)urlString
                  completion:(FUErrorBlock)completion;

/// Fetch the current user’s avatar URL. Prefers Auth.photoURL; falls back to Firestore UserImageUrl.
- (void)fetchCurrentUserPhotoURL:(FUURLBlock)completion;

/// Fetch another user’s avatar URL from Firestore.
- (void)fetchPhotoURLForUID:(NSString *)uid
                 completion:(FUURLBlock)completion;

/// Remove current user’s avatar.
/// If deleteFromStorage==YES and a 'UserImagePath' is present on the doc, it will be deleted (best effort).
- (void)removeCurrentUserPhotoWithDeleteFromStorage:(BOOL)deleteFromStorage
                                         completion:(FUErrorBlock)completion;


#pragma mark - Core Services & State

@property (nonatomic, strong) FIRFirestore *db;
@property (nonatomic, strong) FIRStorage *storage;
@property (nonatomic, strong) FIRFunctions *functions;
@property (nonatomic, strong, readwrite, nullable) FUUserDoc *currentUserDoc;
@property (nonatomic, strong, readonly, nullable) FIRUser *currentUser;

#pragma mark - Private helpers (intentionally public to keep exact signatures for linker)

- (NSError *)p_err:(NSString *)msg code:(NSInteger)code;
- (void)p_finishUser:(FIRUser * _Nullable)user
               error:(NSError * _Nullable)error
          completion:(FUUserBlock)completion;

- (void)p_applyDisplayName:(NSString * _Nullable)displayName
                  photoURL:(NSURL * _Nullable)photoURL
                    toUser:(FIRUser *)user
                completion:(FUErrorBlock)completion;

- (void)p_createOrMergeUserDocFor:(FIRUser *)user
                            extra:(NSDictionary * _Nullable)extra
                       completion:(FUErrorBlock)completion;

- (void)p_uploadProfileImage:(UIImage *)image
                      forUID:(NSString *)uid
                      maxDim:(NSUInteger)maxDim
                    maxBytes:(NSUInteger)maxBytes
                  completion:(FUURLBlock)completion;

- (NSArray<NSString *> *)p_providerIDsForUser:(FIRUser *)user;
- (UIImage *)p_scaleImage:(UIImage *)image maxDimension:(NSUInteger)maxDim;
- (NSData *)p_pngDataForImage:(UIImage *)image targetMaxBytes:(NSUInteger)maxBytes;
- (void)p_linkCredential:(FIRAuthCredential *)cred
              completion:(FUUserBlock)completion;

#pragma mark - Auth lifecycle

- (void)createUserWithEmail:(NSString *)email
                   password:(NSString *)password
                displayName:(nullable NSString *)displayName
                      photo:(nullable UIImage *)photo
                   metadata:(nullable NSDictionary *)metadata
                 completion:(FUUserBlock)completion;

- (void)signInWithEmail:(NSString *)email
               password:(NSString *)password
             completion:(FUUserBlock)completion;

- (BOOL)signOut:(NSError * _Nullable * _Nullable)error;
- (void)deleteCurrentUserWithCompletion:(FUErrorBlock)completion;

#pragma mark - Reauth / reload

- (void)reauthenticateWithEmail:(NSString *)email
                       password:(NSString *)password
                     completion:(FUErrorBlock)completion;

- (void)reauthenticateWithCredential:(FIRAuthCredential *)credential
                          completion:(FUErrorBlock)completion;

- (void)reloadCurrentUser:(FUErrorBlock)completion;

#pragma mark - Profile updates (Auth + Firestore + Storage)

- (void)updateDisplayName:(NSString *)displayName completion:(FUErrorBlock)completion;
- (void)updateEmail:(NSString *)email completion:(FUErrorBlock)completion;
- (void)updatePassword:(NSString *)newPassword completion:(FUErrorBlock)completion;

- (void)updatePhotoImage:(UIImage *)image
         maxDimension_px:(NSUInteger)maxDim
               maxBytes:(NSUInteger)maxBytes
              completion:(FUURLBlock)completion;

#pragma mark - Firestore user doc APIs

- (void)ensureUserDocumentExistsForCurrentUserWithExtra:(nullable NSDictionary *)extra
                                             completion:(FUErrorBlock)completion;

- (void)updateUserDocumentFields:(NSDictionary *)fields completion:(FUErrorBlock)completion;

- (nullable FIRDocumentReference *)userDocumentRefForUID:(NSString *)uid;

- (id<FIRListenerRegistration>)listenToCurrentUserDoc:(void(^)(FUUserDoc * _Nullable doc,
                                                                NSError * _Nullable error))block;

- (void)unlinkProvider:(NSString *)providerID completion:(FUUserBlock)completion;

#pragma mark - Apple nonce helpers (optional)

+ (NSString *)randomNonceString:(NSUInteger)length;
+ (NSString *)sha256:(NSString *)input;

#pragma mark - Combined modeler

- (UserModel * _Nullable)userModelFromAuth:(FIRUser * _Nullable)auth
                                       doc:(FUUserDoc * _Nullable)doc;

- (id<FIRListenerRegistration>)listenCombinedUser:(void(^)(UserModel * _Nullable u,
                                                           NSError * _Nullable err))block;

#pragma mark - Users listing (ordered by UserName + uid)

- (id<FIRListenerRegistration>)listenAllUsersOrderedBy:(NSString * _Nullable)orderField
                                             ascending:(BOOL)ascending
                                  includeMetadataChanges:(BOOL)includeMetadata
                                                 queue:(dispatch_queue_t _Nullable)callbackQueue
                                            completion:(FUUsersCompletion)completion;

- (id<FIRListenerRegistration>)listenAllUsersWithDiffsOrderedBy:(NSString * _Nullable)orderField
                                                       ascending:(BOOL)ascending
                                            includeMetadataChanges:(BOOL)includeMetadata
                                                           queue:(dispatch_queue_t _Nullable)callbackQueue
                                                        completion:(FUUsersDiffCompletion)completion;

- (void)fetchAllUsersOrderedBy:(NSString * _Nullable)orderField
                      ascending:(BOOL)ascending
                          queue:(dispatch_queue_t _Nullable)callbackQueue
                     completion:(FUUsersCompletion)completion;

/// Reusable query builder
+ (FIRQuery *)usersBaseQueryOrderedBy:(NSString * _Nullable)orderField
                            ascending:(BOOL)ascending;

#pragma mark - Auth Listener (top level)

- (void)startAuthListenerWithChangeBlock:(void(^)(FIRUser * _Nullable authUser,
                                                  UserModel * _Nullable userModel))block;

- (void)reloadCurrentUserWithCompletion:(void(^)(UserModel * _Nullable user,
                                                 NSError * _Nullable error))completion;

- (id<FIRListenerRegistration>)listenStaffUsersWithCompletion:(void(^)(NSArray<UserModel *> * _Nullable staff, NSError * _Nullable error))completion;

#pragma mark - Arbitrary field updates

- (void)updateUserFieldsForUID:(NSString *)uid
                        fields:(NSDictionary<NSString *, id> *)fields
                    completion:(FUErrorBlock)completion;

#pragma mark - Admin-side account creation (minimal write-through)

- (void)createUserWithEmail:(NSString *)email
                   password:(NSString *)password
                   username:(NSString *)username
                       role:(NSInteger)role            // stored as-is; no role logic here
                permissions:(NSDictionary<NSString *, NSNumber *> *)perms  // stored as-is
                    isAdmin:(BOOL)isAdmin
                 completion:(void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
