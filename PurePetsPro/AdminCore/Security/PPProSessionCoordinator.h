#import <Foundation/Foundation.h>
#import "PPProAccountTransitionCoordinator.h"

@class FIRAuth, FIRAuthCredential, FIRFirestore, FIRFunctions, FIRPhoneAuthProvider, FIRStorage, FIRUser;
@class PPProFirebaseAccountRuntime, PPProSessionFence;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PPProSessionCoordinatorErrorDomain;
FOUNDATION_EXPORT NSString * const PPProSessionDidSuspendNotification;
FOUNDATION_EXPORT NSString * const PPProSessionDidChangeActiveRuntimeNotification;
FOUNDATION_EXPORT NSString * const PPProSessionTransitionRecoveryRequiredNotification;
FOUNDATION_EXPORT NSString * const PPProSessionTransitionWillBeginNotification;
FOUNDATION_EXPORT NSString * const PPProSessionTransitionPhaseDidChangeNotification;
FOUNDATION_EXPORT NSString * const PPProSessionDidCommitNotification;
FOUNDATION_EXPORT NSString * const PPProSessionTransitionDidRollbackNotification;
FOUNDATION_EXPORT NSString * const PPProSessionAccountListDidChangeNotification;

typedef NS_ENUM(NSInteger, PPProSessionCoordinatorErrorCode) {
    PPProSessionCoordinatorErrorTransitionRequired = 1001,
    PPProSessionCoordinatorErrorTransitionBusy = 1002,
    PPProSessionCoordinatorErrorActiveWorkBlocked = 1003,
    PPProSessionCoordinatorErrorPendingWritesUnconfirmed = 1004,
    PPProSessionCoordinatorErrorIdentityMismatch = 1005,
    PPProSessionCoordinatorErrorSignOutFailed = 1006,
    PPProSessionCoordinatorErrorSlotUnavailable = 1007,
    PPProSessionCoordinatorErrorJournalFailure = 1008,
    PPProSessionCoordinatorErrorAccountActive = 1009,
    PPProSessionCoordinatorErrorProAccessDenied = 1010,
    PPProSessionCoordinatorErrorNotificationBarrierFailed = 1011,
};

/// Returns YES to block an account transition / removal, optionally setting `outReason`.
typedef BOOL (^PPProActiveWorkBlocker)(NSString * _Nullable * _Nullable outReason);
/// Async account-level active-work validator (checks remote/account state even when UI is absent).
typedef void (^PPProAsyncActiveWorkValidator)(NSString * _Nullable uid, NSString *reason, void (^done)(BOOL blocked, NSString * _Nullable blockReason));
/// Invoked when the current session is suspended or torn down (account switch, logout, or recovery).
typedef void (^PPProSessionTeardownHandler)(NSString *reason);
/// Async teardown barrier for uploads/location/WebViews needing explicit acknowledgement before switch completes.
typedef void (^PPProAsyncSessionTeardownHandler)(NSString *reason, void (^done)(void));
/// Asynchronous Notification V2 deactivation barrier before finishing account suspension.
typedef void (^PPProNotificationBarrierHandler)(NSString *reason, void (^done)(NSError * _Nullable error));

@protocol PPProSessionSlotHandle <NSObject>
@property (nonatomic, readonly) NSUUID *slotID;
@property (nonatomic, copy, readonly, nullable) NSString *expectedUID;
@property (nonatomic, copy, readonly, nullable) NSString *currentUID;
@property (nonatomic, readonly) BOOL isAuthorizedSession;
@property (nonatomic, readonly) BOOL isInvalidated;
- (void)waitForPendingWritesWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)signOutAndInvalidate:(BOOL)invalidate completion:(void (^ _Nullable)(NSError * _Nullable error))completion;
- (void)teardownSlotAppWithCompletion:(void (^ _Nullable)(BOOL deleted, NSError * _Nullable error))completion;
@optional
@property (nonatomic, readonly) BOOL isAuthenticatedSession;
@property (nonatomic, readonly) NSUInteger slotGeneration;
- (void)markProAccessVerified:(BOOL)verified forUID:(nullable NSString *)uid;
- (void)validateSessionWithCompletion:(void (^)(id _Nullable user, NSError * _Nullable error))completion;
@end

@protocol PPProSessionRuntimeProvider <NSObject>
- (BOOL)isMultiAccountEnabled;
- (nullable NSString *)defaultAuthCurrentUID;
- (void)waitForDefaultPendingWritesWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)signOutDefaultAuthWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (nullable id<PPProSessionSlotHandle>)openSlotForRememberedUID:(NSString *)uid error:(NSError **)error;
- (nullable id<PPProSessionSlotHandle>)createProvisionalSlotWithError:(NSError **)error;
- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedRecordsWithError:(NSError **)error;
- (BOOL)rememberUID:(NSString *)uid
        maskedLabel:(NSString *)label
             method:(NSString *)method
             slotID:(nullable NSUUID *)slotID
              error:(NSError **)error;
- (BOOL)removeRememberedUID:(NSString *)uid error:(NSError **)error;
@optional
- (nullable id<PPProSessionSlotHandle>)openSlotWithID:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID error:(NSError **)error;
- (nullable NSDictionary<NSString *, NSString *> *)activeIdentityHintWithError:(NSError **)error;
- (BOOL)setActiveIdentityUID:(NSString *)uid slotID:(nullable NSUUID *)slotID error:(NSError **)error;
- (BOOL)clearActiveIdentityWithError:(NSError **)error;
- (BOOL)updateSessionStatusHint:(NSString *)status forUID:(NSString *)uid error:(NSError **)error;
- (void)verifyProAccessForUID:(NSString *)uid slot:(id<PPProSessionSlotHandle>)slot completion:(void (^)(BOOL authorized, NSError * _Nullable error))completion;
@end

/// Single coordinator binding account-scoped Firebase runtimes, transition recovery,
/// active work preflight, and deterministic observer/cache teardown.
@interface PPProSessionCoordinator : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

- (instancetype)initWithTransitionCoordinator:(PPProAccountTransitionCoordinator *)transitionCoordinator
                                        fence:(PPProSessionFence *)fence
                              runtimeProvider:(nullable id<PPProSessionRuntimeProvider>)runtimeProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) PPProAccountTransitionCoordinator *transitionCoordinator;
@property (nonatomic, strong, readonly) PPProSessionFence *sessionFence;
@property (nonatomic, strong, readonly, nullable) id<PPProSessionSlotHandle> activeSlot;
@property (nonatomic, strong, readonly, nullable) id<PPProSessionSlotHandle> pendingSlot;
@property (nonatomic, strong, readonly, nullable) PPProFirebaseAccountRuntime *activeRuntime;
@property (nonatomic, strong, readonly, nullable) PPProFirebaseAccountRuntime *pendingRuntime;
@property (nonatomic, copy, readonly, nullable) NSUUID *activeTransitionTicket;
@property (nonatomic, copy, readonly, nullable) NSString *activeUID;
@property (nonatomic, copy, readonly, nullable) NSString *stagedAuthenticatedUID;
@property (nonatomic, readonly, nullable) FIRUser *stagedAuthenticatedUser;
@property (nonatomic, readonly) NSUInteger sessionGeneration;
@property (nonatomic, readonly) PPProTransitionPhase transitionPhase;
@property (nonatomic, readonly) BOOL requiresTransitionRecovery;
@property (nonatomic, readonly) BOOL isTransitionInProgress;
@property (nonatomic, readonly) BOOL isSuspendedOrLocked;
@property (nonatomic, copy, readonly, nullable) NSString *transitionStatusKey;

#pragma mark - Active Account Firebase Services

/// Active FirebaseAuth instance (staged slot during auth, else installed slot, else default when permitted).
- (nullable FIRAuth *)activeAuth;
- (nullable FIRUser *)currentUser;
/// Active Firestore instance (nil when suspended, unverified, or recovery-locked).
- (nullable FIRFirestore *)activeFirestore;
/// Active Cloud Functions (`us-central1`, nil when suspended, unverified, or recovery-locked).
- (nullable FIRFunctions *)activeFunctions;
/// Active Cloud Storage (nil when suspended, unverified, or recovery-locked).
- (nullable FIRStorage *)activeStorage;
/// Bootstrap-only Firestore/Functions for verifying Pro access during staged authentication before install.
- (nullable FIRFirestore *)bootstrapFirestoreForStagedSlot;
- (nullable FIRFunctions *)bootstrapFunctionsForStagedSlot;
/// Active Phone Auth provider bound to `activeAuth`.
- (nullable FIRPhoneAuthProvider *)activePhoneProvider;

#pragma mark - Auth Redirect, Staged Auth & APNs Forwarding Across Slots

- (BOOL)canHandleAuthURL:(NSURL *)url;
- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo;
- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken;
- (void)authenticateStagedSlot:(nullable id<PPProSessionSlotHandle>)slot
                withCredential:(FIRAuthCredential *)credential
                   expectedUID:(nullable NSString *)expectedUID
                    completion:(void (^)(FIRUser * _Nullable user, NSString * _Nullable uid, NSError * _Nullable error))completion;

#pragma mark - Preflight & Teardown Registration

- (void)registerActiveWorkBlocker:(PPProActiveWorkBlocker)blocker forKey:(NSString *)key;
- (void)unregisterActiveWorkBlockerForKey:(NSString *)key;
- (void)registerAsyncActiveWorkValidator:(PPProAsyncActiveWorkValidator)validator forKey:(NSString *)key;
- (void)unregisterAsyncActiveWorkValidatorForKey:(NSString *)key;
- (void)registerSessionTeardownHandler:(PPProSessionTeardownHandler)handler forKey:(NSString *)key;
- (void)unregisterSessionTeardownHandlerForKey:(NSString *)key;
- (void)registerAsyncSessionTeardownHandler:(PPProAsyncSessionTeardownHandler)handler forKey:(NSString *)key;
- (void)unregisterAsyncSessionTeardownHandlerForKey:(NSString *)key;
- (void)registerNotificationBarrierHandler:(nullable PPProNotificationBarrierHandler)handler;
- (BOOL)hasBlockingActiveWorkWithReason:(NSString * _Nullable * _Nullable)outReason;
- (void)preflightAccountTransitionForTargetUID:(nullable NSString *)targetUID
                                        reason:(NSString *)reason
                                    completion:(void (^)(BOOL allowed, NSString * _Nullable blockReason, NSError * _Nullable error))completion;

#pragma mark - Atomic Switch, Provisional Sign-In, Cold Restore & Recovery

- (void)suspendAndResetAccountStateForReason:(NSString *)reason
                                  completion:(nullable void (^)(NSError * _Nullable error))completion;
- (void)completeExternalSignOutWithUID:(nullable NSString *)uid;
- (void)completeExternalSignOutWithUID:(nullable NSString *)uid
                            completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

- (void)beginRememberedAccountSignInOrSwitchToUID:(NSString *)targetUID
                                          fromUID:(nullable NSString *)sourceUID
                                       completion:(void (^)(BOOL allowed,
                                                            NSUUID * _Nullable ticket,
                                                            id<PPProSessionSlotHandle> _Nullable stagedSlot,
                                                            NSError * _Nullable error))completion;

/// Fast-switches to a remembered account slot when its isolated session validates cleanly
/// and passes Pro access verification, falling back with `requiresReauth = YES` when the
/// user must re-authenticate without forcing a manual recovery error state.
- (void)fastSwitchToRememberedUID:(NSString *)targetUID
                          fromUID:(nullable NSString *)sourceUID
                       completion:(void (^)(BOOL switched,
                                            BOOL requiresReauth,
                                            NSUUID * _Nullable ticket,
                                            id<PPProSessionSlotHandle> _Nullable stagedSlot,
                                            NSError * _Nullable error))completion;

- (NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedAccountRecords;
- (BOOL)isMultiAccountRolloutEnabled;

- (void)beginProvisionalSignInFromUID:(nullable NSString *)sourceUID
                           completion:(void (^)(BOOL allowed,
                                                NSUUID * _Nullable ticket,
                                                id<PPProSessionSlotHandle> _Nullable provisionalSlot,
                                                NSError * _Nullable error))completion;

- (void)beginProvisionalAddAccountFromUID:(nullable NSString *)sourceUID
                               completion:(void (^)(BOOL allowed,
                                                    NSUUID * _Nullable ticket,
                                                    id<PPProSessionSlotHandle> _Nullable provisionalSlot,
                                                    NSError * _Nullable error))completion;

- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                             completion:(void (^)(BOOL installed, NSError * _Nullable error))completion;

- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                      proAccessVerified:(BOOL)proAccessVerified
                             completion:(void (^)(BOOL installed, NSError * _Nullable error))completion;

- (void)handleAuthenticationFailureForTicket:(nullable NSUUID *)ticket
                             provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                                       error:(nullable NSError *)authError
                         mismatchExpectedUID:(nullable NSString *)expectedUID
                                  completion:(void (^)(BOOL recoveryRequired, NSError * _Nullable finalError))completion;

- (void)cancelPendingAuthenticationForTicket:(nullable NSUUID *)ticket
                                  completion:(nullable void (^)(BOOL cleared, NSError * _Nullable error))completion;

- (void)restoreLastActiveSessionOnColdLaunchWithCompletion:(void (^)(BOOL restored,
                                                                     BOOL requiresReauth,
                                                                     NSString * _Nullable uid,
                                                                     NSError * _Nullable error))completion;

- (void)signOutActiveAccountWithReason:(NSString *)reason
                            completion:(void (^)(BOOL signedOut, NSError * _Nullable error))completion;

- (void)signOutAllAccountsWithReason:(NSString *)reason
                          completion:(void (^)(BOOL signedOutAll, NSError * _Nullable error))completion;

- (void)performColdStartRecoveryCheckWithCompletion:(void (^)(BOOL recoveryRequired,
                                                              BOOL cleared,
                                                              NSError * _Nullable error))completion;

- (void)retryTransitionRecoverySignOutWithCompletion:(void (^)(BOOL cleared, NSError * _Nullable error))completion;

- (void)removeRememberedAccountWithUID:(NSString *)uid
                            completion:(void (^)(BOOL removed, NSError * _Nullable error))completion;

#pragma mark - Account-Scoped Preferences & Cleanup

+ (NSString *)scopedDefaultsKey:(NSString *)baseKey forUID:(nullable NSString *)uid;
+ (void)purgeScopedDefaultsForUID:(NSString *)uid;
- (void)purgeSharedMediaCaches;

@end

NS_ASSUME_NONNULL_END
