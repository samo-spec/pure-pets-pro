#import <Foundation/Foundation.h>
#import "PPProAccountTransitionCoordinator.h"

@class FIRAuth, FIRFirestore, FIRFunctions, FIRPhoneAuthProvider, FIRStorage, FIRUser;
@class PPProFirebaseAccountRuntime, PPProSessionFence;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PPProSessionCoordinatorErrorDomain;
FOUNDATION_EXPORT NSString * const PPProSessionDidSuspendNotification;
FOUNDATION_EXPORT NSString * const PPProSessionDidChangeActiveRuntimeNotification;
FOUNDATION_EXPORT NSString * const PPProSessionTransitionRecoveryRequiredNotification;

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
};

/// Returns YES to block an account transition / removal, optionally setting `outReason`.
typedef BOOL (^PPProActiveWorkBlocker)(NSString * _Nullable * _Nullable outReason);
/// Invoked when the current session is suspended or torn down (account switch, logout, or recovery).
typedef void (^PPProSessionTeardownHandler)(NSString *reason);
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
@property (nonatomic, readonly) PPProTransitionPhase transitionPhase;
@property (nonatomic, readonly) BOOL requiresTransitionRecovery;
@property (nonatomic, readonly) BOOL isTransitionInProgress;

#pragma mark - Active Account Firebase Services

/// Active FirebaseAuth instance (staged slot during auth, else installed slot, else default when permitted).
- (nullable FIRAuth *)activeAuth;
- (nullable FIRUser *)currentUser;
/// Active Firestore instance (nil when suspended or recovery-locked).
- (nullable FIRFirestore *)activeFirestore;
/// Active Cloud Functions (`us-central1`, nil when suspended or recovery-locked).
- (nullable FIRFunctions *)activeFunctions;
/// Active Cloud Storage (nil when suspended or recovery-locked).
- (nullable FIRStorage *)activeStorage;
/// Active Phone Auth provider bound to `activeAuth`.
- (nullable FIRPhoneAuthProvider *)activePhoneProvider;

#pragma mark - Auth Redirect & APNs Forwarding Across Slots

- (BOOL)canHandleAuthURL:(NSURL *)url;
- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo;
- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken;

#pragma mark - Preflight & Teardown Registration

- (void)registerActiveWorkBlocker:(PPProActiveWorkBlocker)blocker forKey:(NSString *)key;
- (void)unregisterActiveWorkBlockerForKey:(NSString *)key;
- (void)registerSessionTeardownHandler:(PPProSessionTeardownHandler)handler forKey:(NSString *)key;
- (void)unregisterSessionTeardownHandlerForKey:(NSString *)key;
- (void)registerNotificationBarrierHandler:(nullable PPProNotificationBarrierHandler)handler;
- (BOOL)hasBlockingActiveWorkWithReason:(NSString * _Nullable * _Nullable)outReason;

#pragma mark - Atomic Switch, Provisional Sign-In & Recovery

/// Synchronously invalidates the session fence, notifies teardown observers,
/// clears in-memory session state, and runs the async notification barrier before calling completion.
- (void)suspendAndResetAccountStateForReason:(NSString *)reason
                                  completion:(nullable void (^)(NSError * _Nullable error))completion;

/// Called after an external sign-out (e.g. `UserManager signOutWithCompletion:`) already ran
/// Notification V2 deactivation and signed out FirebaseAuth, to tear down other singletons and clear active slots.
- (void)completeExternalSignOutWithUID:(nullable NSString *)uid;

/// Checks active work & pending writes, transitions through Preflight -> Suspended -> Authenticating,
/// and opens the target account's slot when multi-account rollout is enabled.
- (void)beginRememberedAccountSignInOrSwitchToUID:(NSString *)targetUID
                                          fromUID:(nullable NSString *)sourceUID
                                       completion:(void (^)(BOOL allowed,
                                                            NSUUID * _Nullable ticket,
                                                            id<PPProSessionSlotHandle> _Nullable stagedSlot,
                                                            NSError * _Nullable error))completion;

/// Prepares a provisional sign-in (suspending `sourceUID` if signed in first).
- (void)beginProvisionalSignInFromUID:(nullable NSString *)sourceUID
                           completion:(void (^)(BOOL allowed,
                                                NSUUID * _Nullable ticket,
                                                id<PPProSessionSlotHandle> _Nullable provisionalSlot,
                                                NSError * _Nullable error))completion;

/// Completes authentication after credentials succeed, enforcing identity match,
/// remembering the identity with its slot ID, installing the runtime, and committing the journal.
- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                             completion:(void (^)(BOOL installed, NSError * _Nullable error))completion;

/// Fails closed when authentication errors or authenticates the wrong UID.
/// If sign-out fails, locks the coordinator in `PPProTransitionRecoveryRequired`.
- (void)handleAuthenticationFailureForTicket:(nullable NSUUID *)ticket
                             provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                                       error:(nullable NSError *)authError
                         mismatchExpectedUID:(nullable NSString *)expectedUID
                                  completion:(void (^)(BOOL recoveryRequired, NSError * _Nullable finalError))completion;

/// Cancels an unauthenticated switch only if still in preflight, or fails closed into recovery.
- (void)cancelPendingAuthenticationForTicket:(nullable NSUUID *)ticket
                                  completion:(nullable void (^)(BOOL cleared, NSError * _Nullable error))completion;

/// On cold launch, checks for an incomplete journal (`PPProTransitionRecoveryRequired`),
/// tears down any exposed state, and clears recovery only after verified sign-out.
- (void)performColdStartRecoveryCheckWithCompletion:(void (^)(BOOL recoveryRequired,
                                                              BOOL cleared,
                                                              NSError * _Nullable error))completion;

/// User-initiated recovery retry when locked in `PPProTransitionRecoveryRequired`.
- (void)retryTransitionRecoverySignOutWithCompletion:(void (^)(BOOL cleared, NSError * _Nullable error))completion;

/// Verifies pending writes are flushed (when not active) and tears down the slot app + Keychain entry + scoped defaults.
- (void)removeRememberedAccountWithUID:(NSString *)uid
                            completion:(void (^)(BOOL removed, NSError * _Nullable error))completion;

#pragma mark - Account-Scoped Preferences & Cleanup

+ (NSString *)scopedDefaultsKey:(NSString *)baseKey forUID:(nullable NSString *)uid;
+ (void)purgeScopedDefaultsForUID:(NSString *)uid;
- (void)purgeSharedMediaCaches;

@end

NS_ASSUME_NONNULL_END
