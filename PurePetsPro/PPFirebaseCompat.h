#ifndef PPFirebaseCompat_h
#define PPFirebaseCompat_h

#import <Foundation/Foundation.h>

// Firebase iOS 11+ ships several Swift-backed pods whose generated Objective-C
// compatibility headers are not always present in this workspace. This header
// provides the stable Objective-C surface the admin app relies on, while
// preferring the public FirebaseFirestore framework headers when available.

#if __has_include(<FirebaseAuth/FirebaseAuth.h>)
#import <FirebaseAuth/FirebaseAuth.h>
#define PP_FIREBASE_AUTH_TYPES_IMPORTED 1
#elif __has_include("FIRAuth.h")
#import "FIRAuth.h"
#define PP_FIREBASE_AUTH_TYPES_IMPORTED 1
#endif

#if __has_feature(modules)
@import FirebaseAuth;
#define PP_FIREBASE_AUTH_TYPES_IMPORTED 1
#endif

#if __has_include(<FirebaseAuth/FIRUser.h>)
#import <FirebaseAuth/FIRUser.h>
#elif __has_include("FIRUser.h")
#import "FIRUser.h"
#endif

#if __has_include(<FirebaseAuth/FIRAuthErrors.h>)
#import <FirebaseAuth/FIRAuthErrors.h>
#elif __has_include("FIRAuthErrors.h")
#import "FIRAuthErrors.h"
#endif

#if __has_include(<FirebaseCore/FirebaseCore.h>)
#import <FirebaseCore/FirebaseCore.h>
#define PP_FIREBASE_CORE_TYPES_IMPORTED 1
#elif __has_include("FirebaseCore.h")
#import "FirebaseCore.h"
#define PP_FIREBASE_CORE_TYPES_IMPORTED 1
#endif

#if !defined(PP_FIREBASE_CORE_TYPES_IMPORTED) && __has_include(<FirebaseCore/FIRApp.h>)
#import <FirebaseCore/FIRApp.h>
#elif !defined(PP_FIREBASE_CORE_TYPES_IMPORTED) && __has_include("FIRApp.h")
#import "FIRApp.h"
#endif

#if !defined(PP_FIREBASE_CORE_TYPES_IMPORTED) && __has_include(<FirebaseCore/FIROptions.h>)
#import <FirebaseCore/FIROptions.h>
#define PP_FIREBASE_CORE_TYPES_IMPORTED 1
#elif !defined(PP_FIREBASE_CORE_TYPES_IMPORTED) && __has_include("FIROptions.h")
#import "FIROptions.h"
#define PP_FIREBASE_CORE_TYPES_IMPORTED 1
#endif

#if __has_include(<FirebaseFirestore/FIRFirestore.h>)
#import <FirebaseFirestore/FIRFirestore.h>
#elif __has_include("FIRFirestore.h")
#import "FIRFirestore.h"
#endif
#if __has_include(<FirebaseFirestore/FIRFirestoreErrors.h>)
#import <FirebaseFirestore/FIRFirestoreErrors.h>
#define PP_FIREBASE_FIRESTORE_ERRORS_IMPORTED 1
#elif __has_include("FIRFirestoreErrors.h")
#import "FIRFirestoreErrors.h"
#define PP_FIREBASE_FIRESTORE_ERRORS_IMPORTED 1
#endif
#if __has_include(<FirebaseFirestore/FIRQuery.h>)
#import <FirebaseFirestore/FIRQuery.h>
#elif __has_include("FIRQuery.h")
#import "FIRQuery.h"
#endif
#if __has_include(<FirebaseFirestore/FIRCollectionReference.h>)
#import <FirebaseFirestore/FIRCollectionReference.h>
#elif __has_include("FIRCollectionReference.h")
#import "FIRCollectionReference.h"
#endif
#if __has_include(<FirebaseFirestore/FIRDocumentReference.h>)
#import <FirebaseFirestore/FIRDocumentReference.h>
#elif __has_include("FIRDocumentReference.h")
#import "FIRDocumentReference.h"
#endif
#if __has_include(<FirebaseFirestore/FIRDocumentSnapshot.h>)
#import <FirebaseFirestore/FIRDocumentSnapshot.h>
#elif __has_include("FIRDocumentSnapshot.h")
#import "FIRDocumentSnapshot.h"
#endif
#if __has_include(<FirebaseFirestore/FIRQuerySnapshot.h>)
#import <FirebaseFirestore/FIRQuerySnapshot.h>
#elif __has_include("FIRQuerySnapshot.h")
#import "FIRQuerySnapshot.h"
#endif
#if __has_include(<FirebaseFirestore/FIRDocumentChange.h>)
#import <FirebaseFirestore/FIRDocumentChange.h>
#elif __has_include("FIRDocumentChange.h")
#import "FIRDocumentChange.h"
#endif
#if __has_include(<FirebaseFirestore/FIRSnapshotMetadata.h>)
#import <FirebaseFirestore/FIRSnapshotMetadata.h>
#elif __has_include("FIRSnapshotMetadata.h")
#import "FIRSnapshotMetadata.h"
#endif
#if __has_include(<FirebaseFirestore/FIRFieldValue.h>)
#import <FirebaseFirestore/FIRFieldValue.h>
#elif __has_include("FIRFieldValue.h")
#import "FIRFieldValue.h"
#endif
#if __has_include(<FirebaseFirestore/FIRWriteBatch.h>)
#import <FirebaseFirestore/FIRWriteBatch.h>
#elif __has_include("FIRWriteBatch.h")
#import "FIRWriteBatch.h"
#endif
#if __has_include(<FirebaseFirestore/FIRTransaction.h>)
#import <FirebaseFirestore/FIRTransaction.h>
#elif __has_include("FIRTransaction.h")
#import "FIRTransaction.h"
#endif
#if __has_include(<FirebaseFirestore/FIRFirestoreSource.h>)
#import <FirebaseFirestore/FIRFirestoreSource.h>
#elif __has_include("FIRFirestoreSource.h")
#import "FIRFirestoreSource.h"
#endif
#if __has_include(<FirebaseFirestore/FIRListenerRegistration.h>)
#import <FirebaseFirestore/FIRListenerRegistration.h>
#elif __has_include("FIRListenerRegistration.h")
#import "FIRListenerRegistration.h"
#endif
#if __has_include(<FirebaseFirestore/FIRTimestamp.h>)
#import <FirebaseFirestore/FIRTimestamp.h>
#elif __has_include("FIRTimestamp.h")
#import "FIRTimestamp.h"
#endif

#if __has_include(<FirebaseFunctions/FirebaseFunctions.h>)
#import <FirebaseFunctions/FirebaseFunctions.h>
#define PP_FIREBASE_FUNCTIONS_TYPES_IMPORTED 1
#elif __has_include("FirebaseFunctions.h")
#import "FirebaseFunctions.h"
#define PP_FIREBASE_FUNCTIONS_TYPES_IMPORTED 1
#endif

#if __has_feature(modules)
@import FirebaseFunctions;
#define PP_FIREBASE_FUNCTIONS_TYPES_IMPORTED 1
#endif

#if __has_include(<FirebaseStorage/FirebaseStorage.h>)
#import <FirebaseStorage/FirebaseStorage.h>
#define PP_FIREBASE_STORAGE_TYPES_IMPORTED 1
#define PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED 1
#elif __has_include("FirebaseStorage.h")
#import "FirebaseStorage.h"
#define PP_FIREBASE_STORAGE_TYPES_IMPORTED 1
#define PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED 1
#endif

#if __has_feature(modules)
@import FirebaseStorage;
#define PP_FIREBASE_STORAGE_TYPES_IMPORTED 1
#define PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED 1
#endif

#if __has_include(<FirebaseStorage/FIRStorageTypedefs.h>)
#import <FirebaseStorage/FIRStorageTypedefs.h>
#define PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED 1
#elif __has_include("FIRStorageTypedefs.h")
#import "FIRStorageTypedefs.h"
#define PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED 1
#endif

NS_ASSUME_NONNULL_BEGIN

#if !defined(PP_FIREBASE_AUTH_TYPES_IMPORTED)
typedef NS_ENUM(NSInteger, FIRAuthErrorCode) {
    FIRAuthErrorCodeInvalidCredential = 17004,
    FIRAuthErrorCodeUserDisabled = 17005,
    FIRAuthErrorCodeWrongPassword = 17009,
    FIRAuthErrorCodeUserNotFound = 17011,
    FIRAuthErrorCodeNetworkError = 17020,
    FIRAuthErrorCodeInternalError = 17999,
};

#ifndef PP_FIREBASE_FIRESTORE_ERRORS_IMPORTED
FOUNDATION_EXPORT NSString * const FIRFirestoreErrorDomain;

typedef NS_ERROR_ENUM(FIRFirestoreErrorDomain, FIRFirestoreErrorCode) {
    FIRFirestoreErrorCodeOK = 0,
    FIRFirestoreErrorCodeCancelled = 1,
    FIRFirestoreErrorCodeUnknown = 2,
    FIRFirestoreErrorCodeInvalidArgument = 3,
    FIRFirestoreErrorCodeDeadlineExceeded = 4,
    FIRFirestoreErrorCodeNotFound = 5,
    FIRFirestoreErrorCodeAlreadyExists = 6,
    FIRFirestoreErrorCodePermissionDenied = 7,
    FIRFirestoreErrorCodeResourceExhausted = 8,
    FIRFirestoreErrorCodeFailedPrecondition = 9,
    FIRFirestoreErrorCodeAborted = 10,
    FIRFirestoreErrorCodeOutOfRange = 11,
    FIRFirestoreErrorCodeUnimplemented = 12,
    FIRFirestoreErrorCodeInternal = 13,
    FIRFirestoreErrorCodeUnavailable = 14,
    FIRFirestoreErrorCodeDataLoss = 15,
    FIRFirestoreErrorCodeUnauthenticated = 16,
};
#endif

@protocol FIRUserInfo <NSObject>
@property(nonatomic, copy, readonly, nullable) NSString *providerID;
@property(nonatomic, copy, readonly, nullable) NSString *uid;
@property(nonatomic, copy, readonly, nullable) NSString *displayName;
@property(nonatomic, copy, readonly, nullable) NSString *email;
@property(nonatomic, strong, readonly, nullable) NSURL *photoURL;
@end

typedef NS_ENUM(NSInteger, FIRFunctionsErrorCode) {
    FIRFunctionsErrorCodeOK = 0,
    FIRFunctionsErrorCodeCancelled = 1,
    FIRFunctionsErrorCodeUnknown = 2,
    FIRFunctionsErrorCodeInvalidArgument = 3,
    FIRFunctionsErrorCodeDeadlineExceeded = 4,
    FIRFunctionsErrorCodeNotFound = 5,
    FIRFunctionsErrorCodeAlreadyExists = 6,
    FIRFunctionsErrorCodePermissionDenied = 7,
    FIRFunctionsErrorCodeResourceExhausted = 8,
    FIRFunctionsErrorCodeFailedPrecondition = 9,
    FIRFunctionsErrorCodeAborted = 10,
    FIRFunctionsErrorCodeOutOfRange = 11,
    FIRFunctionsErrorCodeUnimplemented = 12,
    FIRFunctionsErrorCodeInternal = 13,
    FIRFunctionsErrorCodeUnavailable = 14,
    FIRFunctionsErrorCodeDataLoss = 15,
    FIRFunctionsErrorCodeUnauthenticated = 16,
};

FOUNDATION_EXPORT NSString * const FIRFunctionsErrorDomain;
FOUNDATION_EXPORT NSString * const FIRFunctionsErrorDetailsKey;

#ifndef PP_FIREBASE_STORAGE_TYPEDEFS_IMPORTED
typedef NSString *FIRStorageHandle;
typedef void (^FIRStorageVoidDataError)(NSData *_Nullable data, NSError *_Nullable error);
typedef void (^FIRStorageVoidError)(NSError *_Nullable error);
typedef void (^FIRStorageVoidMetadataError)(id _Nullable metadata, NSError *_Nullable error);
typedef void (^FIRStorageVoidURLError)(NSURL *_Nullable URL, NSError *_Nullable error);
#endif

typedef NS_ENUM(NSInteger, FIRStorageTaskStatus) {
    FIRStorageTaskStatusUnknown = 0,
    FIRStorageTaskStatusResume,
    FIRStorageTaskStatusProgress,
    FIRStorageTaskStatusPause,
    FIRStorageTaskStatusSuccess,
    FIRStorageTaskStatusFailure,
};

@interface FIRAuthDataResult : NSObject
@property(nonatomic, strong, readonly, nullable) FIRUser *user;
@end

@interface FIRAuthTokenResult : NSObject
@property(nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *claims;
@end

@interface FIRUserProfileChangeRequest : NSObject
@property(nonatomic, copy, nullable) NSString *displayName;
@property(nonatomic, strong, nullable) NSURL *photoURL;
- (void)commitChangesWithCompletion:(FIRUserProfileChangeCallback)completion;
@end

@interface FIRUser : NSObject
@property(nonatomic, copy, readonly) NSString *uid;
@property(nonatomic, copy, readonly, nullable) NSString *email;
@property(nonatomic, copy, readonly, nullable) NSString *displayName;
@property(nonatomic, strong, readonly, nullable) NSURL *photoURL;
@property(nonatomic, assign, readonly, getter=isAnonymous) BOOL anonymous;
@property(nonatomic, assign, readonly, getter=isEmailVerified) BOOL emailVerified;
@property(nonatomic, copy, readonly, nullable) NSArray<id<FIRUserInfo>> *providerData;
- (void)getIDTokenWithCompletion:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion;
- (void)getIDTokenForcingRefresh:(BOOL)forceRefresh
                      completion:(void (^)(NSString * _Nullable token, NSError * _Nullable error))completion;
- (void)getIDTokenResultWithCompletion:(FIRAuthTokenResultCallback)completion;
- (void)getIDTokenResultForcingRefresh:(BOOL)forceRefresh completion:(FIRAuthTokenResultCallback)completion;
- (void)reloadWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)updateEmail:(NSString *)email completion:(FIRUserUpdateCallback)completion;
- (void)updatePassword:(NSString *)password completion:(FIRUserUpdateCallback)completion;
- (void)deleteWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)reauthenticateWithCredential:(FIRAuthCredential *)credential
                          completion:(FIRAuthDataResultCallback)completion;
- (void)linkWithCredential:(FIRAuthCredential *)credential
                completion:(FIRAuthDataResultCallback)completion;
- (void)unlinkFromProvider:(NSString *)provider completion:(FIRAuthResultCallback)completion;
- (FIRUserProfileChangeRequest *)profileChangeRequest;
@end

@protocol FIRAuthUIDelegate;
@class FIRAuthCredential;

@interface FIRAuth : NSObject
@property(nonatomic, strong, readonly, nullable) FIRUser *currentUser;
+ (nullable instancetype)auth;
+ (nullable instancetype)authWithApp:(FIRApp *)app;
- (FIRAuthStateDidChangeListenerHandle)addAuthStateDidChangeListener:(FIRAuthStateDidChangeListenerBlock)listener;
- (void)removeAuthStateDidChangeListener:(FIRAuthStateDidChangeListenerHandle)listenerHandle;
- (void)createUserWithEmail:(NSString *)email
                   password:(NSString *)password
                 completion:(FIRAuthDataResultCallback)completion;
- (void)signInWithEmail:(NSString *)email
               password:(NSString *)password
             completion:(FIRAuthDataResultCallback)completion;
- (void)signInWithCredential:(FIRAuthCredential *)credential
                  completion:(FIRAuthDataResultCallback)completion;
- (void)sendPasswordResetWithEmail:(NSString *)email completion:(FIRSendPasswordResetCallback)completion;
- (BOOL)signOut:(NSError * _Nullable * _Nullable)error;
@end

@interface FIREmailAuthProvider : NSObject
+ (FIRAuthCredential *)credentialWithEmail:(NSString *)email password:(NSString *)password;
@end

@interface FIRPhoneAuthProvider : NSObject
+ (instancetype)provider;
+ (instancetype)providerWithAuth:(FIRAuth *)auth;
- (void)verifyPhoneNumber:(NSString *)phoneNumber
               UIDelegate:(nullable id<FIRAuthUIDelegate>)uiDelegate
               completion:(void (^ _Nullable)(NSString * _Nullable verificationID,
                                              NSError * _Nullable error))completion;
- (FIRAuthCredential *)credentialWithVerificationID:(NSString *)verificationID
                                   verificationCode:(NSString *)verificationCode;
@end

@interface FIROAuthProvider : NSObject
+ (FIRAuthCredential *)appleCredentialWithIDToken:(NSString *)idToken
                                         rawNonce:(nullable NSString *)rawNonce
                                         fullName:(nullable NSPersonNameComponents *)fullName;
@end

@interface FIRGoogleAuthProvider : NSObject
+ (FIRAuthCredential *)credentialWithIDToken:(NSString *)idToken
                                 accessToken:(NSString *)accessToken;
@end
#endif

#if !defined(PP_FIREBASE_FUNCTIONS_TYPES_IMPORTED)
@interface FIRHTTPSCallableResult : NSObject
@property(nonatomic, strong, readonly) id data;
@end

@interface FIRHTTPSCallable : NSObject
@property(nonatomic, assign) NSTimeInterval timeoutInterval;
- (void)callWithObject:(nullable id)data
            completion:(void (^)(FIRHTTPSCallableResult * _Nullable result,
                                 NSError * _Nullable error))completion;
- (void)callWithCompletion:(void (^)(FIRHTTPSCallableResult * _Nullable result,
                                     NSError * _Nullable error))completion;
@end

@interface FIRFunctions : NSObject
+ (instancetype)functions;
+ (instancetype)functionsForApp:(FIRApp *)app;
+ (instancetype)functionsForRegion:(NSString *)region;
+ (instancetype)functionsForCustomDomain:(NSString *)customDomain;
+ (instancetype)functionsForApp:(FIRApp *)app region:(NSString *)region;
+ (instancetype)functionsForApp:(FIRApp *)app customDomain:(NSString *)customDomain;
- (FIRHTTPSCallable *)HTTPSCallableWithName:(NSString *)name;
- (FIRHTTPSCallable *)HTTPSCallableWithURL:(NSURL *)url;
@end
#endif

#if !defined(PP_FIREBASE_STORAGE_TYPES_IMPORTED)
@interface FIRStorageMetadata : NSObject
@property(nonatomic, copy, readonly, nullable) NSString *bucket;
@property(nonatomic, copy, nullable) NSString *cacheControl;
@property(nonatomic, copy, nullable) NSString *contentDisposition;
@property(nonatomic, copy, nullable) NSString *contentEncoding;
@property(nonatomic, copy, nullable) NSString *contentLanguage;
@property(nonatomic, copy, nullable) NSString *contentType;
@property(nonatomic, copy, readonly, nullable) NSString *md5Hash;
@property(nonatomic, assign, readonly) int64_t generation;
@property(nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *customMetadata;
@property(nonatomic, assign, readonly) int64_t metageneration;
@property(nonatomic, copy, nullable) NSString *path;
@property(nonatomic, copy, nullable) NSString *name;
@property(nonatomic, assign, readonly) int64_t size;
@property(nonatomic, strong, readonly, nullable) NSDate *timeCreated;
@property(nonatomic, strong, readonly, nullable) NSDate *updated;
@end

@class FIRStorage;
@class FIRStorageReference;

@interface FIRStorageTaskSnapshot : NSObject
@property(nonatomic, strong, readonly, nullable) NSProgress *progress;
@property(nonatomic, strong, readonly, nullable) NSError *error;
@property(nonatomic, strong, readonly, nullable) FIRStorageMetadata *metadata;
@property(nonatomic, strong, readonly) FIRStorageReference *reference;
@property(nonatomic, assign, readonly) FIRStorageTaskStatus status;
@end

@interface FIRStorageUploadTask : NSObject
- (FIRStorageHandle)observeStatus:(FIRStorageTaskStatus)status
                          handler:(void (^)(FIRStorageTaskSnapshot *snapshot))handler;
- (void)removeObserverWithHandle:(FIRStorageHandle)handle;
- (void)cancel;
- (void)pause;
- (void)resume;
@end

@interface FIRStorageReference : NSObject
@property(nonatomic, strong, readonly) FIRStorage *storage;
@property(nonatomic, copy, readonly) NSString *bucket;
@property(nonatomic, copy, readonly) NSString *fullPath;
@property(nonatomic, copy, readonly) NSString *name;
- (FIRStorageReference *)root;
- (nullable FIRStorageReference *)parent;
- (FIRStorageReference *)child:(NSString *)path;
- (FIRStorageUploadTask *)putData:(NSData *)uploadData metadata:(nullable FIRStorageMetadata *)metadata;
- (FIRStorageUploadTask *)putData:(NSData *)uploadData
                         metadata:(nullable FIRStorageMetadata *)metadata
                       completion:(void (^ _Nullable)(FIRStorageMetadata * _Nullable metadata,
                                                      NSError * _Nullable error))completion;
- (FIRStorageUploadTask *)putFile:(NSURL *)fileURL
                         metadata:(nullable FIRStorageMetadata *)metadata
                       completion:(void (^ _Nullable)(FIRStorageMetadata * _Nullable metadata,
                                                      NSError * _Nullable error))completion;
- (void)downloadURLWithCompletion:(FIRStorageVoidURLError)completion;
- (void)dataWithMaxSize:(int64_t)size completion:(FIRStorageVoidDataError)completion;
- (void)deleteWithCompletion:(FIRStorageVoidError)completion;
@end

@interface FIRStorage : NSObject
+ (instancetype)storage;
+ (instancetype)storageWithURL:(NSString *)url;
+ (instancetype)storageForApp:(FIRApp *)app;
+ (instancetype)storageForApp:(FIRApp *)app URL:(NSString *)url;
- (FIRStorageReference *)reference;
- (FIRStorageReference *)referenceWithPath:(NSString *)path;
- (FIRStorageReference *)referenceForURL:(NSString *)url;
@end
#endif

NS_ASSUME_NONNULL_END

#endif
