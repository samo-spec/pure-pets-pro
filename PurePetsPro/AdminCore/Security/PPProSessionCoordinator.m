#import "PPProSessionCoordinator.h"
#import "PPProRememberedAccountStore.h"
#import "PPProSessionFence.h"

#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
#import "PPFirebaseCompat.h"
#import "PPProFirebaseAccountRuntime.h"
#import "PPImageCacheHelper.h"
#import "SDImageCache.h"
#import "YYKit.h"
#endif

NSString * const PPProSessionCoordinatorErrorDomain = @"PPProSessionCoordinator";
NSString * const PPProSessionDidSuspendNotification = @"PPProSessionDidSuspendNotification";
NSString * const PPProSessionDidChangeActiveRuntimeNotification = @"PPProSessionDidChangeActiveRuntimeNotification";
NSString * const PPProSessionTransitionRecoveryRequiredNotification = @"PPProSessionTransitionRecoveryRequiredNotification";

static NSTimeInterval const PPProPendingWritesTimeoutSeconds = 6.0;
static NSString * const PPProScopedDefaultsPrefix = @"pp_acct.";

static NSError *PPWrapCoordinatorError(PPProSessionCoordinatorErrorCode code,
                                       NSString * _Nullable reason,
                                       NSError * _Nullable underlying) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (reason.length > 0) info[NSLocalizedDescriptionKey] = reason;
    if (underlying) info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:PPProSessionCoordinatorErrorDomain code:code userInfo:info.count ? info : nil];
}

static NSError *PPCoordinatorError(PPProSessionCoordinatorErrorCode code, NSString * _Nullable reason) {
    return PPWrapCoordinatorError(code, reason, nil);
}

static NSString *PPSanitizedUIDForDefaults(NSString * _Nullable uid) {
    NSString *trimmed = [uid isKindOfClass:NSString.class]
        ? [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (trimmed.length == 0) {
        return @"guest";
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    NSMutableString *result = [NSMutableString stringWithCapacity:trimmed.length];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar ch = [trimmed characterAtIndex:i];
        if ([allowed characterIsMember:ch]) {
            [result appendFormat:@"%C", ch];
        } else {
            [result appendString:@"_"];
        }
    }
    return result.length > 0 ? result.copy : @"guest";
}

#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
@interface PPProFirebaseAccountRuntime (PPProSessionSlotHandleConformance) <PPProSessionSlotHandle>
@end

@interface PPProDefaultRuntimeProvider : NSObject <PPProSessionRuntimeProvider>
@end

@implementation PPProDefaultRuntimeProvider

- (BOOL)isMultiAccountEnabled {
    return [PPProRememberedAccountStore rolloutEnabled];
}

- (nullable NSString *)defaultAuthCurrentUID {
    return [FIRAuth auth].currentUser.uid;
}

- (void)waitForDefaultPendingWritesWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (![FIRAuth auth].currentUser) {
        if (completion) completion(nil);
        return;
    }
    __block BOOL finished = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PPProPendingWritesTimeoutSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (finished) return;
        finished = YES;
        if (completion) completion(PPCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed, @"Timed out waiting for pending Firestore writes"));
    });
    [[FIRFirestore firestore] waitForPendingWritesWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (finished) return;
            finished = YES;
            if (completion) completion(error);
        });
    }];
}

- (void)signOutDefaultAuthWithCompletion:(void (^)(NSError * _Nullable))completion {
    void (^work)(void) = ^{
        FIRAuth *defaultAuth = [FIRAuth auth];
        if (!defaultAuth.currentUser) {
            if (completion) completion(nil);
            return;
        }
        NSError *error = nil;
        BOOL ok = [defaultAuth signOut:&error];
        if (completion) completion(ok ? nil : (error ?: PPCoordinatorError(PPProSessionCoordinatorErrorSignOutFailed, @"Default auth sign-out failed")));
    };
    if (NSThread.isMainThread) work();
    else dispatch_async(dispatch_get_main_queue(), work);
}

- (nullable id<PPProSessionSlotHandle>)openSlotForRememberedUID:(NSString *)uid error:(NSError **)error {
    return (id<PPProSessionSlotHandle>)[PPProFirebaseAccountRuntime openRememberedUID:uid error:error];
}

- (nullable id<PPProSessionSlotHandle>)createProvisionalSlotWithError:(NSError **)error {
    return (id<PPProSessionSlotHandle>)[PPProFirebaseAccountRuntime createProvisionalSlotWithError:error];
}

- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedRecordsWithError:(NSError **)error {
    return [PPProRememberedAccountStore recordsWithError:error];
}

- (BOOL)rememberUID:(NSString *)uid
        maskedLabel:(NSString *)label
             method:(NSString *)method
             slotID:(nullable NSUUID *)slotID
              error:(NSError **)error {
    if (slotID) {
        return [PPProRememberedAccountStore rememberUID:uid maskedLabel:label method:method slotID:slotID error:error];
    }
    return [PPProRememberedAccountStore rememberUID:uid maskedLabel:label method:method error:error];
}

- (BOOL)removeRememberedUID:(NSString *)uid error:(NSError **)error {
    return [PPProRememberedAccountStore removeUID:uid error:error];
}

@end
#endif

@interface PPProSessionCoordinator ()
@property (nonatomic, strong, readwrite) PPProAccountTransitionCoordinator *transitionCoordinator;
@property (nonatomic, strong, readwrite) PPProSessionFence *sessionFence;
@property (nonatomic, strong) id<PPProSessionRuntimeProvider> runtimeProvider;
@property (nonatomic, strong, readwrite, nullable) id<PPProSessionSlotHandle> activeSlot;
@property (nonatomic, strong, readwrite, nullable) id<PPProSessionSlotHandle> pendingSlot;
@property (nonatomic, copy, readwrite, nullable) NSUUID *activeTransitionTicket;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProActiveWorkBlocker> *workBlockers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProSessionTeardownHandler> *teardownHandlers;
@property (nonatomic, copy, nullable) PPProNotificationBarrierHandler notificationBarrierHandler;
@end

@implementation PPProSessionCoordinator

+ (instancetype)shared {
    static PPProSessionCoordinator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id<PPProSessionRuntimeProvider> provider = nil;
#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
        provider = [[PPProDefaultRuntimeProvider alloc] init];
#endif
        instance = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:[PPProAccountTransitionCoordinator shared]
                                                                            fence:[PPProSessionFence shared]
                                                                  runtimeProvider:provider];
    });
    return instance;
}

- (instancetype)initWithTransitionCoordinator:(PPProAccountTransitionCoordinator *)transitionCoordinator
                                        fence:(PPProSessionFence *)fence
                              runtimeProvider:(nullable id<PPProSessionRuntimeProvider>)runtimeProvider {
    self = [super init];
    if (self) {
        _transitionCoordinator = transitionCoordinator ?: [PPProAccountTransitionCoordinator shared];
        _sessionFence = fence ?: [PPProSessionFence shared];
        _runtimeProvider = runtimeProvider;
        _workBlockers = [NSMutableDictionary dictionary];
        _teardownHandlers = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - State Queries

- (PPProTransitionPhase)transitionPhase {
    return self.transitionCoordinator.phase;
}

- (BOOL)requiresTransitionRecovery {
    return self.transitionCoordinator.phase == PPProTransitionRecoveryRequired;
}

- (BOOL)isTransitionInProgress {
    PPProTransitionPhase phase = self.transitionCoordinator.phase;
    return phase != PPProTransitionIdle;
}

- (nullable PPProFirebaseAccountRuntime *)activeRuntime {
#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
    if ([self.activeSlot isKindOfClass:[PPProFirebaseAccountRuntime class]]) {
        return (PPProFirebaseAccountRuntime *)self.activeSlot;
    }
#endif
    return nil;
}

- (nullable PPProFirebaseAccountRuntime *)pendingRuntime {
#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
    if ([self.pendingSlot isKindOfClass:[PPProFirebaseAccountRuntime class]]) {
        return (PPProFirebaseAccountRuntime *)self.pendingSlot;
    }
#endif
    return nil;
}

- (nullable NSString *)activeUID {
    PPProTransitionPhase phase = self.transitionCoordinator.phase;
    if (phase == PPProTransitionRecoveryRequired ||
        phase == PPProTransitionSuspended ||
        phase == PPProTransitionAuthenticating) {
        return nil;
    }
    if (self.activeSlot) {
        if (!self.activeSlot.isAuthorizedSession) {
            return nil;
        }
        return self.activeSlot.currentUID ?: self.activeSlot.expectedUID;
    }
    return [self.runtimeProvider defaultAuthCurrentUID];
}

#pragma mark - Active Firebase Service Accessors

#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
- (BOOL)pp_allowsDataServiceAccess {
    PPProTransitionPhase phase = self.transitionCoordinator.phase;
    if (phase == PPProTransitionRecoveryRequired ||
        phase == PPProTransitionSuspended ||
        phase == PPProTransitionAuthenticating) {
        return NO;
    }
    return YES;
}

- (nullable FIRAuth *)activeAuth {
    if (self.pendingRuntime) {
        return self.pendingRuntime.auth;
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return self.activeRuntime.auth;
    }
    return [FIRAuth auth];
}

- (nullable FIRUser *)currentUser {
    if (self.requiresTransitionRecovery) {
        return nil;
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return self.activeRuntime.isAuthorizedSession ? self.activeRuntime.auth.currentUser : nil;
    }
    return [self activeAuth].currentUser;
}

- (nullable FIRFirestore *)activeFirestore {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return self.activeRuntime.firestore;
    }
    return [FIRFirestore firestore];
}

- (nullable FIRFunctions *)activeFunctions {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return self.activeRuntime.functions;
    }
    return [FIRFunctions functionsForRegion:@"us-central1"];
}

- (nullable FIRStorage *)activeStorage {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return self.activeRuntime.storage;
    }
    return [FIRStorage storage];
}

- (nullable FIRPhoneAuthProvider *)activePhoneProvider {
    if (self.pendingRuntime) {
        return [self.pendingRuntime phoneProvider];
    }
    if (self.activeRuntime && [self.runtimeProvider isMultiAccountEnabled]) {
        return [self.activeRuntime phoneProvider];
    }
    FIRAuth *auth = [self activeAuth];
    return auth ? [FIRPhoneAuthProvider providerWithAuth:auth] : [FIRPhoneAuthProvider provider];
}

- (BOOL)canHandleAuthURL:(NSURL *)url {
    if (!url) return NO;
    if (self.pendingRuntime && [self.pendingRuntime.auth canHandleURL:url]) return YES;
    if (self.activeRuntime && [self.activeRuntime.auth canHandleURL:url]) return YES;
    return [[FIRAuth auth] canHandleURL:url];
}

- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo {
    if (!userInfo) return NO;
    if (self.pendingRuntime && [self.pendingRuntime.auth canHandleNotification:userInfo]) return YES;
    if (self.activeRuntime && [self.activeRuntime.auth canHandleNotification:userInfo]) return YES;
    return [[FIRAuth auth] canHandleNotification:userInfo];
}

- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken {
    if (!deviceToken.length) return;
    [[FIRAuth auth] setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    if (self.pendingRuntime.auth && self.pendingRuntime.auth != [FIRAuth auth]) {
        [self.pendingRuntime.auth setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    }
    if (self.activeRuntime.auth &&
        self.activeRuntime.auth != [FIRAuth auth] &&
        self.activeRuntime.auth != self.pendingRuntime.auth) {
        [self.activeRuntime.auth setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    }
}
#else
- (nullable id)activeAuth { return nil; }
- (nullable id)currentUser { return nil; }
- (nullable id)activeFirestore { return nil; }
- (nullable id)activeFunctions { return nil; }
- (nullable id)activeStorage { return nil; }
- (nullable id)activePhoneProvider { return nil; }
- (BOOL)canHandleAuthURL:(NSURL *)url { (void)url; return NO; }
- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo { (void)userInfo; return NO; }
- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken { (void)deviceToken; }
#endif

#pragma mark - Blockers & Teardown Handlers

- (void)registerActiveWorkBlocker:(PPProActiveWorkBlocker)blocker forKey:(NSString *)key {
    if (!blocker || !key.length) return;
    @synchronized (self) {
        self.workBlockers[key] = [blocker copy];
    }
}

- (void)unregisterActiveWorkBlockerForKey:(NSString *)key {
    if (!key.length) return;
    @synchronized (self) {
        [self.workBlockers removeObjectForKey:key];
    }
}

- (void)registerSessionTeardownHandler:(PPProSessionTeardownHandler)handler forKey:(NSString *)key {
    if (!handler || !key.length) return;
    @synchronized (self) {
        self.teardownHandlers[key] = [handler copy];
    }
}

- (void)unregisterSessionTeardownHandlerForKey:(NSString *)key {
    if (!key.length) return;
    @synchronized (self) {
        [self.teardownHandlers removeObjectForKey:key];
    }
}

- (void)registerNotificationBarrierHandler:(nullable PPProNotificationBarrierHandler)handler {
    @synchronized (self) {
        self.notificationBarrierHandler = [handler copy];
    }
}

- (BOOL)hasBlockingActiveWorkWithReason:(NSString * _Nullable * _Nullable)outReason {
    NSArray<PPProActiveWorkBlocker> *blockers = nil;
    @synchronized (self) {
        blockers = self.workBlockers.allValues;
    }
    for (PPProActiveWorkBlocker blocker in blockers) {
        NSString *reason = nil;
        if (blocker(&reason)) {
            if (outReason) *outReason = reason;
            return YES;
        }
    }
    return NO;
}

#pragma mark - Teardown & Suspension

- (void)pp_dispatchMain:(dispatch_block_t)block {
    if (!block) return;
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

- (void)pp_runTeardownHandlersWithReason:(NSString *)reason {
    [self.sessionFence invalidate];
    NSArray<PPProSessionTeardownHandler> *handlers = nil;
    @synchronized (self) {
        handlers = self.teardownHandlers.allValues;
    }
    for (PPProSessionTeardownHandler handler in handlers) {
        handler(reason ?: @"session_teardown");
    }
    [self purgeSharedMediaCaches];
    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidSuspendNotification
                                                        object:self
                                                      userInfo:@{@"reason": reason ?: @"session_teardown"}];
}

- (void)suspendAndResetAccountStateForReason:(NSString *)reason
                                  completion:(nullable void (^)(NSError * _Nullable error))completion {
    [self pp_dispatchMain:^{
        PPProNotificationBarrierHandler barrier = nil;
        @synchronized (self) {
            barrier = self.notificationBarrierHandler;
        }
        void (^finishSuspension)(NSError * _Nullable) = ^(NSError * _Nullable barrierError) {
            [self pp_runTeardownHandlersWithReason:reason];
            if (completion) completion(barrierError);
        };
        if (barrier) {
            barrier(reason ?: @"session_teardown", ^(NSError * _Nullable barrierError) {
                [self pp_dispatchMain:^{
                    finishSuspension(barrierError);
                }];
            });
        } else {
            finishSuspension(nil);
        }
    }];
}

/// Runs the async Notification V2 deactivation barrier while the outgoing session's
/// `FIRFunctions` / `FIRAuth` are still accessible, then advances the journal to
/// `Suspended` and synchronously tears down listeners and in-memory caches.
- (void)pp_suspendTicket:(NSUUID *)ticket
                  reason:(NSString *)reason
              completion:(void (^)(NSError * _Nullable suspendError))completion {
    PPProNotificationBarrierHandler barrier = nil;
    @synchronized (self) {
        barrier = self.notificationBarrierHandler;
    }
    void (^advanceAndTeardown)(void) = ^{
        NSError *suspendErr = nil;
        BOOL advanced = [self.transitionCoordinator advance:ticket
                                                    toPhase:PPProTransitionSuspended
                                                verifiedUID:nil
                                                      error:&suspendErr];
        [self pp_runTeardownHandlersWithReason:reason];
        if (!advanced) {
            [self.transitionCoordinator requireRecoveryForTicket:ticket];
            [self pp_notifyRecoveryRequiredWithReason:@"suspend_failed"];
            if (completion) completion(suspendErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
            return;
        }
        if (completion) completion(nil);
    };
    if (barrier) {
        barrier(reason ?: @"session_teardown", ^(__unused NSError *barrierError) {
            [self pp_dispatchMain:^{
                advanceAndTeardown();
            }];
        });
    } else {
        advanceAndTeardown();
    }
}

- (void)completeExternalSignOutWithUID:(nullable NSString *)uid {
    [self pp_dispatchMain:^{
        id<PPProSessionSlotHandle> currentSlot = self.activeSlot;
        id<PPProSessionSlotHandle> stagedSlot = self.pendingSlot;
        self.activeSlot = nil;
        self.pendingSlot = nil;
        if (currentSlot && (!uid.length || [currentSlot.expectedUID isEqualToString:uid] || [currentSlot.currentUID isEqualToString:uid])) {
            [currentSlot signOutAndInvalidate:YES completion:nil];
        }
        if (stagedSlot && stagedSlot != currentSlot) {
            [stagedSlot signOutAndInvalidate:YES completion:nil];
        }
        [self pp_runTeardownHandlersWithReason:@"external_signout"];
        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification
                                                            object:self];
    }];
}

- (void)pp_waitForPendingWritesOnCurrentSessionWithCompletion:(void (^)(NSError * _Nullable error))completion {
    id<PPProSessionSlotHandle> currentSlot = self.activeSlot;
    if (currentSlot) {
        if (!currentSlot.isAuthorizedSession) {
            if (completion) completion(nil);
            return;
        }
        __block BOOL completed = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PPProPendingWritesTimeoutSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (completed) return;
            completed = YES;
            if (completion) completion(PPCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed, @"Timed out flushing active account pending writes"));
        });
        [currentSlot waitForPendingWritesWithCompletion:^(NSError * _Nullable error) {
            [self pp_dispatchMain:^{
                if (completed) return;
                completed = YES;
                NSError *wrapped = error
                    ? PPWrapCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed,
                                             error.localizedDescription ?: @"Pending writes could not be confirmed",
                                             error)
                    : nil;
                if (completion) completion(wrapped);
            }];
        }];
        return;
    }
    NSString *defaultUID = [self.runtimeProvider defaultAuthCurrentUID];
    if (defaultUID.length > 0 && [self.runtimeProvider respondsToSelector:@selector(waitForDefaultPendingWritesWithCompletion:)]) {
        [self.runtimeProvider waitForDefaultPendingWritesWithCompletion:^(NSError * _Nullable error) {
            [self pp_dispatchMain:^{
                NSError *wrapped = error
                    ? PPWrapCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed,
                                             error.localizedDescription ?: @"Pending writes could not be confirmed",
                                             error)
                    : nil;
                if (completion) completion(wrapped);
            }];
        }];
    } else {
        if (completion) completion(nil);
    }
}

#pragma mark - Remembered Account Switch / Sign-In

- (void)beginRememberedAccountSignInOrSwitchToUID:(NSString *)targetUID
                                          fromUID:(nullable NSString *)sourceUID
                                       completion:(void (^)(BOOL, NSUUID * _Nullable, id<PPProSessionSlotHandle> _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionBusy, nil));
            return;
        }
        NSString *safeTarget = [targetUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *safeSource = [sourceUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *effectiveSource = safeSource.length > 0 ? safeSource : nil;
        if (!safeTarget.length) {
            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Missing target account"));
            return;
        }
        if (effectiveSource.length > 0) {
            NSString *blockReason = nil;
            if ([self hasBlockingActiveWorkWithReason:&blockReason]) {
                if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, blockReason));
                return;
            }
        }
        NSError *journalError = nil;
        NSUUID *ticket = [self.transitionCoordinator beginFromUID:effectiveSource targetUID:safeTarget error:&journalError];
        if (!ticket) {
            if (completion) completion(NO, nil, nil, journalError ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
            return;
        }
        self.activeTransitionTicket = ticket;

        void (^continueAfterWrites)(void) = ^{
            [self pp_suspendTicket:ticket reason:@"account_switch" completion:^(NSError * _Nullable suspendErr) {
                if (suspendErr) {
                    if (completion) completion(NO, nil, nil, suspendErr);
                    return;
                }
                void (^afterSourceCleared)(NSError * _Nullable) = ^(NSError * _Nullable signOutError) {
                    if (signOutError) {
                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                        [self pp_notifyRecoveryRequiredWithReason:@"source_signout_failed"];
                        if (completion) completion(NO, nil, nil, signOutError);
                        return;
                    }
                    self.activeSlot = nil;
                    NSError *authPhaseErr = nil;
                    if (![self.transitionCoordinator advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&authPhaseErr]) {
                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                        [self pp_notifyRecoveryRequiredWithReason:@"authenticating_journal_failed"];
                        if (completion) completion(NO, nil, nil, authPhaseErr);
                        return;
                    }
                    id<PPProSessionSlotHandle> stagedSlot = nil;
                    if ([self.runtimeProvider isMultiAccountEnabled]) {
                        NSError *slotErr = nil;
                        stagedSlot = [self.runtimeProvider openSlotForRememberedUID:safeTarget error:&slotErr];
                        if (!stagedSlot) {
                            [self.transitionCoordinator requireRecoveryForTicket:ticket];
                            [self pp_notifyRecoveryRequiredWithReason:@"slot_open_failed"];
                            if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                            return;
                        }
                        if (stagedSlot.expectedUID.length > 0 &&
                            stagedSlot.currentUID.length > 0 &&
                            ![stagedSlot.currentUID isEqualToString:stagedSlot.expectedUID]) {
                            [stagedSlot signOutAndInvalidate:YES completion:^(NSError * _Nullable mismatchedErr) {
                                if (mismatchedErr) {
                                    [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                    [self pp_notifyRecoveryRequiredWithReason:@"slot_mismatched_signout_failed"];
                                    if (completion) completion(NO, nil, nil, mismatchedErr);
                                    return;
                                }
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"slot_mismatched_uid"];
                                if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                            }];
                            return;
                        }
                    }
                    self.pendingSlot = stagedSlot;
                    if (completion) completion(YES, ticket, stagedSlot, nil);
                };

                if ([self.runtimeProvider isMultiAccountEnabled] && self.activeSlot) {
                    // Multi-account mode keeps remembered slot credentials isolated per slot; only detach active runtime.
                    afterSourceCleared(nil);
                } else if (effectiveSource.length > 0) {
                    [self.runtimeProvider signOutDefaultAuthWithCompletion:afterSourceCleared];
                } else {
                    afterSourceCleared(nil);
                }
            }];
        };

        if (effectiveSource.length > 0) {
            [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                if (writeError) {
                    [self.transitionCoordinator cancelPreflight:ticket error:nil];
                    if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                    if (completion) completion(NO, nil, nil, writeError);
                    return;
                }
                continueAfterWrites();
            }];
        } else {
            continueAfterWrites();
        }
    }];
}

- (void)beginProvisionalSignInFromUID:(nullable NSString *)sourceUID
                           completion:(void (^)(BOOL, NSUUID * _Nullable, id<PPProSessionSlotHandle> _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionBusy, nil));
            return;
        }
        NSString *safeSource = [sourceUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (safeSource.length > 0) {
            NSString *blockReason = nil;
            if ([self hasBlockingActiveWorkWithReason:&blockReason]) {
                if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, blockReason));
                return;
            }
            NSError *journalErr = nil;
            NSUUID *suspendTicket = [self.transitionCoordinator beginFromUID:safeSource targetUID:@"__pending_signout__" error:&journalErr];
            if (!suspendTicket) {
                if (completion) completion(NO, nil, nil, journalErr);
                return;
            }
            self.activeTransitionTicket = suspendTicket;
            [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                if (writeError) {
                    [self.transitionCoordinator cancelPreflight:suspendTicket error:nil];
                    if ([self.activeTransitionTicket isEqual:suspendTicket]) self.activeTransitionTicket = nil;
                    if (completion) completion(NO, nil, nil, writeError);
                    return;
                }
                [self pp_suspendTicket:suspendTicket reason:@"provisional_switch_out" completion:^(NSError * _Nullable suspendErr) {
                    if (suspendErr) {
                        if (completion) completion(NO, nil, nil, suspendErr);
                        return;
                    }
                    void (^afterSuspended)(NSError * _Nullable) = ^(NSError * _Nullable signOutErr) {
                        if (signOutErr) {
                            [self.transitionCoordinator requireRecoveryForTicket:suspendTicket];
                            [self pp_notifyRecoveryRequiredWithReason:@"provisional_signout_failed"];
                            if (completion) completion(NO, nil, nil, signOutErr);
                            return;
                        }
                        self.activeSlot = nil;
                        [self.transitionCoordinator requireRecoveryForTicket:suspendTicket];
                        if (![self.transitionCoordinator clearAfterVerifiedSignOut:nil]) {
                            [self pp_notifyRecoveryRequiredWithReason:@"provisional_clear_failed"];
                            if (completion) completion(NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                            return;
                        }
                        self.activeTransitionTicket = nil;
                        NSError *slotErr = nil;
                        id<PPProSessionSlotHandle> provisionalSlot = nil;
                        if ([self.runtimeProvider isMultiAccountEnabled]) {
                            provisionalSlot = [self.runtimeProvider createProvisionalSlotWithError:&slotErr];
                            if (!provisionalSlot) {
                                if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                                return;
                            }
                            self.pendingSlot = provisionalSlot;
                        }
                        if (completion) completion(YES, nil, provisionalSlot, nil);
                    };

                    if ([self.runtimeProvider isMultiAccountEnabled] && self.activeSlot) {
                        afterSuspended(nil);
                    } else {
                        [self.runtimeProvider signOutDefaultAuthWithCompletion:afterSuspended];
                    }
                }];
            }];
            return;
        }

        id<PPProSessionSlotHandle> provisionalSlot = nil;
        if ([self.runtimeProvider isMultiAccountEnabled]) {
            NSError *slotErr = nil;
            provisionalSlot = [self.runtimeProvider createProvisionalSlotWithError:&slotErr];
            if (!provisionalSlot) {
                if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                return;
            }
            self.pendingSlot = provisionalSlot;
        }
        if (completion) completion(YES, nil, provisionalSlot, nil);
    }];
}

- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                             completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        NSString *safeAuthUID = [authenticatedUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *safeExpected = [expectedUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

        if (!safeAuthUID.length || (safeExpected.length > 0 && ![safeAuthUID isEqualToString:safeExpected])) {
            [self handleAuthenticationFailureForTicket:ticket
                                         provisionalSlot:slot
                                                   error:PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil)
                                     mismatchExpectedUID:safeExpected
                                              completion:^(__unused BOOL recoveryRequired, NSError *finalError) {
                if (completion) completion(NO, finalError);
            }];
            return;
        }

        NSUUID *effectiveTicket = ticket;
        if (!effectiveTicket) {
            if (self.transitionCoordinator.phase != PPProTransitionIdle) {
                [self handleAuthenticationFailureForTicket:nil
                                             provisionalSlot:slot
                                                       error:PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil)
                                         mismatchExpectedUID:nil
                                                  completion:^(__unused BOOL r, NSError *finalError) {
                    if (completion) completion(NO, finalError);
                }];
                return;
            }
            NSError *journalErr = nil;
            effectiveTicket = [self.transitionCoordinator beginFromUID:nil targetUID:safeAuthUID error:&journalErr];
            if (!effectiveTicket ||
                ![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionSuspended verifiedUID:nil error:&journalErr] ||
                ![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&journalErr]) {
                if (effectiveTicket) [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                [self pp_notifyRecoveryRequiredWithReason:@"install_journal_prepare_failed"];
                if (completion) completion(NO, journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = effectiveTicket;
        }

        NSError *authAdvanceErr = nil;
        if (![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionAuthorized verifiedUID:safeAuthUID error:&authAdvanceErr]) {
            [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
            [self pp_notifyRecoveryRequiredWithReason:@"authorized_phase_failed"];
            if (completion) completion(NO, authAdvanceErr);
            return;
        }

        void (^installValidatedSlot)(id<PPProSessionSlotHandle> _Nullable) = ^(id<PPProSessionSlotHandle> _Nullable finalSlot) {
            if ([self.runtimeProvider isMultiAccountEnabled] && finalSlot) {
                NSString *label = maskedLabel.length ? maskedLabel : safeAuthUID;
                NSString *authMethod = method.length ? method : @"phone";
                NSError *rememberErr = nil;
                [self.runtimeProvider rememberUID:safeAuthUID
                                      maskedLabel:label
                                           method:authMethod
                                           slotID:finalSlot.slotID
                                            error:&rememberErr];
                self.activeSlot = finalSlot;
            }
            if (self.pendingSlot == finalSlot || !finalSlot) {
                self.pendingSlot = nil;
            }
            NSError *installErr = nil;
            if (![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionInstalled verifiedUID:safeAuthUID error:&installErr] ||
                ![self.transitionCoordinator commit:effectiveTicket verifiedUID:safeAuthUID error:&installErr]) {
                self.activeSlot = nil;
                [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                [self pp_notifyRecoveryRequiredWithReason:@"commit_phase_failed"];
                if (completion) completion(NO, installErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification
                                                                object:self
                                                              userInfo:@{@"uid": safeAuthUID}];
            if (completion) completion(YES, nil);
        };

        if ([self.runtimeProvider isMultiAccountEnabled] && slot) {
            NSArray<NSDictionary<NSString *, NSString *> *> *existing = [self.runtimeProvider rememberedRecordsWithError:nil] ?: @[];
            NSString *existingSlotUUIDString = nil;
            for (NSDictionary *rec in existing) {
                if ([rec[@"uid"] isEqual:safeAuthUID]) {
                    existingSlotUUIDString = rec[@"slotID"];
                    break;
                }
            }
            if (existingSlotUUIDString.length > 0 && ![existingSlotUUIDString isEqualToString:slot.slotID.UUIDString]) {
                id<PPProSessionSlotHandle> priorSlot = [self.runtimeProvider openSlotForRememberedUID:safeAuthUID error:nil];
                if (priorSlot && [priorSlot isAuthorizedSession]) {
                    [priorSlot waitForPendingWritesWithCompletion:^(NSError * _Nullable writeError) {
                        [self pp_dispatchMain:^{
                            if (writeError) {
                                // Preserve existing slot's unconfirmed writes instead of silently discarding them.
                                [slot signOutAndInvalidate:YES completion:^(__unused NSError *e) {
                                    self.pendingSlot = nil;
                                    [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                                    [self pp_notifyRecoveryRequiredWithReason:@"existing_slot_pending_writes"];
                                    if (completion) completion(NO, writeError);
                                }];
                                return;
                            }
                            [priorSlot teardownSlotAppWithCompletion:^(__unused BOOL deleted, __unused NSError *teardownErr) {
                                [self.runtimeProvider removeRememberedUID:safeAuthUID error:nil];
                                installValidatedSlot(slot);
                            }];
                        }];
                    }];
                    return;
                } else {
                    [self.runtimeProvider removeRememberedUID:safeAuthUID error:nil];
                }
            }
        }
        installValidatedSlot(slot);
    }];
}

- (void)handleAuthenticationFailureForTicket:(nullable NSUUID *)ticket
                             provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                                       error:(nullable NSError *)authError
                         mismatchExpectedUID:(nullable NSString *)expectedUID
                                  completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        id<PPProSessionSlotHandle> targetSlot = slot ?: self.pendingSlot;
        NSUUID *effectiveTicket = ticket ?: self.activeTransitionTicket;
        if (effectiveTicket) {
            if (expectedUID.length > 0) {
                [self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionAuthorized verifiedUID:@"__mismatch__" error:nil];
            }
            [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
        }
        [self suspendAndResetAccountStateForReason:@"auth_failure" completion:^(__unused NSError *barrierErr) {
            void (^afterDefaultSignOut)(NSError * _Nullable) = ^(NSError * _Nullable defaultSignOutError) {
                NSError *signOutErr = defaultSignOutError;
                if (signOutErr) {
                    if (effectiveTicket) [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                    [self pp_notifyRecoveryRequiredWithReason:@"auth_failure_signout_failed"];
                    if (completion) completion(YES, signOutErr);
                    return;
                }
                self.pendingSlot = nil;
                self.activeSlot = nil;
                if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
                    if ([self.transitionCoordinator clearAfterVerifiedSignOut:nil]) {
                        self.activeTransitionTicket = nil;
                    } else {
                        [self pp_notifyRecoveryRequiredWithReason:@"recovery_clear_failed"];
                        if (completion) completion(YES, authError ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                        return;
                    }
                } else {
                    self.activeTransitionTicket = nil;
                }
                if (completion) completion(NO, authError);
            };

            if (targetSlot) {
                [targetSlot signOutAndInvalidate:YES completion:^(NSError * _Nullable slotSignOutErr) {
                    if (slotSignOutErr) {
                        afterDefaultSignOut(slotSignOutErr);
                        return;
                    }
                    [self.runtimeProvider signOutDefaultAuthWithCompletion:afterDefaultSignOut];
                }];
            } else {
                [self.runtimeProvider signOutDefaultAuthWithCompletion:afterDefaultSignOut];
            }
        }];
    }];
}

- (void)cancelPendingAuthenticationForTicket:(nullable NSUUID *)ticket
                                  completion:(nullable void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        NSUUID *effectiveTicket = ticket ?: self.activeTransitionTicket;
        if (effectiveTicket && self.transitionCoordinator.phase == PPProTransitionPreflight) {
            NSError *err = nil;
            BOOL ok = [self.transitionCoordinator cancelPreflight:effectiveTicket error:&err];
            if (ok) {
                self.activeTransitionTicket = nil;
                self.pendingSlot = nil;
            }
            if (completion) completion(ok, err);
            return;
        }
        [self handleAuthenticationFailureForTicket:effectiveTicket
                                     provisionalSlot:self.pendingSlot
                                               error:nil
                                 mismatchExpectedUID:nil
                                          completion:^(BOOL recoveryRequired, NSError *finalError) {
            if (completion) completion(!recoveryRequired && !finalError, finalError);
        }];
    }];
}

#pragma mark - Recovery

- (void)pp_notifyRecoveryRequiredWithReason:(NSString *)reason {
    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionRecoveryRequiredNotification
                                                        object:self
                                                      userInfo:@{@"reason": reason ?: @"recovery_required"}];
}

- (void)performColdStartRecoveryCheckWithCompletion:(void (^)(BOOL, BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase != PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, NO, nil);
            return;
        }
        [self suspendAndResetAccountStateForReason:@"cold_start_recovery" completion:^(__unused NSError *barrierErr) {
            [self retryTransitionRecoverySignOutWithCompletion:^(BOOL cleared, NSError * _Nullable error) {
                if (completion) completion(YES, cleared, error);
            }];
        }];
    }];
}

- (void)retryTransitionRecoverySignOutWithCompletion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase != PPProTransitionRecoveryRequired) {
            if (completion) completion(YES, nil);
            return;
        }
        [self pp_runTeardownHandlersWithReason:@"transition_recovery"];

        id<PPProSessionSlotHandle> pending = self.pendingSlot;
        id<PPProSessionSlotHandle> active = self.activeSlot;

        void (^signOutDefaultAndClear)(NSError * _Nullable) = ^(NSError * _Nullable priorErr) {
            if (priorErr) {
                [self pp_notifyRecoveryRequiredWithReason:@"recovery_slot_signout_failed"];
                if (completion) completion(NO, priorErr);
                return;
            }
            [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defaultErr) {
                if (defaultErr) {
                    [self pp_notifyRecoveryRequiredWithReason:@"recovery_default_signout_failed"];
                    if (completion) completion(NO, defaultErr);
                    return;
                }
                self.pendingSlot = nil;
                self.activeSlot = nil;
                NSError *clearErr = nil;
                BOOL cleared = [self.transitionCoordinator clearAfterVerifiedSignOut:&clearErr];
                if (cleared) {
                    self.activeTransitionTicket = nil;
                    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                } else {
                    [self pp_notifyRecoveryRequiredWithReason:@"recovery_journal_clear_failed"];
                }
                if (completion) completion(cleared, clearErr);
            }];
        };

        if (pending) {
            [pending signOutAndInvalidate:YES completion:^(NSError * _Nullable pendingErr) {
                if (pendingErr) {
                    signOutDefaultAndClear(pendingErr);
                    return;
                }
                if (active && active != pending) {
                    [active signOutAndInvalidate:YES completion:signOutDefaultAndClear];
                } else {
                    signOutDefaultAndClear(nil);
                }
            }];
        } else if (active) {
            [active signOutAndInvalidate:YES completion:signOutDefaultAndClear];
        } else {
            signOutDefaultAndClear(nil);
        }
    }];
}

- (void)removeRememberedAccountWithUID:(NSString *)uid
                            completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        NSString *safeUID = [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!safeUID.length) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Missing UID"));
            return;
        }
        if ([self.activeUID isEqualToString:safeUID] || [self.pendingSlot.expectedUID isEqualToString:safeUID]) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorAccountActive, @"Sign out of the active account before removing it"));
            return;
        }
        id<PPProSessionSlotHandle> slot = [self.runtimeProvider isMultiAccountEnabled]
            ? [self.runtimeProvider openSlotForRememberedUID:safeUID error:nil]
            : nil;
        void (^finishRemoval)(void) = ^{
            NSError *remErr = nil;
            BOOL removed = [self.runtimeProvider removeRememberedUID:safeUID error:&remErr];
            if (removed) {
                [PPProSessionCoordinator purgeScopedDefaultsForUID:safeUID];
            }
            if (completion) completion(removed, remErr);
        };
        if (slot) {
            [slot teardownSlotAppWithCompletion:^(BOOL deleted, NSError * _Nullable teardownErr) {
                if (teardownErr || !deleted) {
                    if (completion) completion(NO, teardownErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed, nil));
                    return;
                }
                finishRemoval();
            }];
        } else {
            finishRemoval();
        }
    }];
}

#pragma mark - Scoped Preferences & Media Cache Teardown

+ (NSString *)scopedDefaultsKey:(NSString *)baseKey forUID:(nullable NSString *)uid {
    NSString *safeBase = [baseKey isKindOfClass:NSString.class] ? baseKey : @"key";
    NSString *safeUID = PPSanitizedUIDForDefaults(uid);
    return [NSString stringWithFormat:@"%@%@.%@", PPProScopedDefaultsPrefix, safeUID, safeBase];
}

+ (void)purgeScopedDefaultsForUID:(NSString *)uid {
    NSString *trimmedUID = [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmedUID.length) return;
    NSString *sanitizedUID = PPSanitizedUIDForDefaults(trimmedUID);
    NSString *scopedPrefix = [NSString stringWithFormat:@"%@%@.", PPProScopedDefaultsPrefix, sanitizedUID];
    NSString *draftPrefix = [NSString stringWithFormat:@"PPProviderApplicationDraft_%@_", trimmedUID];
    NSString *quickActionPrefix = [NSString stringWithFormat:@"PPProDashboardQuickActionSeen.%@.", trimmedUID];
    NSString *deliveryCompanyKey = [NSString stringWithFormat:@"PPDeliveryCompanyConfiguredID.%@", trimmedUID];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString *, id> *all = defaults.dictionaryRepresentation;
    for (NSString *key in all) {
        if ([key hasPrefix:scopedPrefix] ||
            [key hasPrefix:draftPrefix] ||
            [key hasPrefix:quickActionPrefix] ||
            [key isEqualToString:deliveryCompanyKey]) {
            [defaults removeObjectForKey:key];
        }
    }
}

- (void)purgeSharedMediaCaches {
#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
    [[SDImageCache sharedImageCache] clearMemory];
    [[YYCache cacheWithName:@"PPImageCache"].memoryCache removeAllObjects];
    [[YYCache cacheWithName:@"LottieJSONCache"].memoryCache removeAllObjects];
    [[YYCache cacheWithName:@"PPImageCache"].diskCache removeAllObjects];
#endif
}

@end
