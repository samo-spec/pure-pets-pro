#import "PPProSessionCoordinator.h"
#import "PPProRememberedAccountStore.h"
#import "PPProSessionFence.h"

#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
#import "PPFirebaseCompat.h"
#import "PPProFirebaseAccountRuntime.h"
#import "PPImageCacheHelper.h"
#import "SDImageCache.h"
#import "SDWebImageManager.h"
#import "YYKit.h"
#endif

NSString * const PPProSessionCoordinatorErrorDomain = @"PPProSessionCoordinator";
NSString * const PPProSessionDidSuspendNotification = @"PPProSessionDidSuspendNotification";
NSString * const PPProSessionDidChangeActiveRuntimeNotification = @"PPProSessionDidChangeActiveRuntimeNotification";
NSString * const PPProSessionTransitionRecoveryRequiredNotification = @"PPProSessionTransitionRecoveryRequiredNotification";
NSString * const PPProSessionTransitionWillBeginNotification = @"PPProSessionTransitionWillBeginNotification";
NSString * const PPProSessionTransitionPhaseDidChangeNotification = @"PPProSessionTransitionPhaseDidChangeNotification";
NSString * const PPProSessionDidCommitNotification = @"PPProSessionDidCommitNotification";
NSString * const PPProSessionTransitionDidRollbackNotification = @"PPProSessionTransitionDidRollbackNotification";
NSString * const PPProSessionAccountListDidChangeNotification = @"PPProSessionAccountListDidChangeNotification";

static NSTimeInterval const PPProPendingWritesTimeoutSeconds = 6.0;
static NSTimeInterval const PPProAsyncTeardownTimeoutSeconds = 4.0;
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

static BOOL PPProErrorLooksPermanentRevocation(NSError * _Nullable error) {
    if (!error) return NO;
    // Firebase Auth codes for disabled/deleted/revoked/expired refresh token:
    // 17005 (userDisabled), 17011 (userNotFound), 17021 (userTokenExpired), 17017 (invalidUserToken), 17014 (requiresRecentLogin)
    NSInteger code = error.code;
    if (code == 17005 || code == 17011 || code == 17014 || code == 17017 || code == 17021 || code == 17004 || code == 6) {
        return YES;
    }
    NSString *msg = error.localizedDescription.lowercaseString ?: @"";
    return [msg containsString:@"disabled"] ||
        [msg containsString:@"revoked"] ||
        [msg containsString:@"user_not_found"] ||
        [msg containsString:@"expired"] ||
        [msg containsString:@"invalid_refresh_token"] ||
        [msg containsString:@"requires recent login"];
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

- (nullable id<PPProSessionSlotHandle>)openSlotWithID:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID error:(NSError **)error {
    return (id<PPProSessionSlotHandle>)[PPProFirebaseAccountRuntime openSlot:slotID expectedUID:expectedUID error:error];
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

- (nullable NSDictionary<NSString *, NSString *> *)activeIdentityHintWithError:(NSError **)error {
    return [PPProRememberedAccountStore activeIdentityHintWithError:error];
}

- (BOOL)setActiveIdentityUID:(NSString *)uid slotID:(nullable NSUUID *)slotID error:(NSError **)error {
    return [PPProRememberedAccountStore setActiveIdentityUID:uid slotID:slotID error:error];
}

- (BOOL)clearActiveIdentityWithError:(NSError **)error {
    return [PPProRememberedAccountStore clearActiveIdentityWithError:error];
}

- (BOOL)updateSessionStatusHint:(NSString *)status forUID:(NSString *)uid error:(NSError **)error {
    return [PPProRememberedAccountStore updateSessionStatusHint:status verifiedAt:nil forUID:uid error:error];
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
@property (nonatomic, readwrite) NSUInteger sessionGeneration;
@property (nonatomic, copy, readwrite, nullable) NSString *transitionStatusKey;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProActiveWorkBlocker> *workBlockers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProAsyncActiveWorkValidator> *asyncWorkValidators;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProSessionTeardownHandler> *teardownHandlers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPProAsyncSessionTeardownHandler> *asyncTeardownHandlers;
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
        _sessionGeneration = 1;
        _workBlockers = [NSMutableDictionary dictionary];
        _asyncWorkValidators = [NSMutableDictionary dictionary];
        _teardownHandlers = [NSMutableDictionary dictionary];
        _asyncTeardownHandlers = [NSMutableDictionary dictionary];
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

- (BOOL)isSuspendedOrLocked {
    PPProTransitionPhase phase = self.transitionCoordinator.phase;
    return phase == PPProTransitionRecoveryRequired ||
        phase == PPProTransitionSuspended ||
        phase == PPProTransitionAuthenticating;
}

- (BOOL)pp_isMultiAccountRuntime {
    if ([self.runtimeProvider isMultiAccountEnabled]) {
        return YES;
    }
    return [PPProRememberedAccountStore rolloutEnabled];
}

- (BOOL)pp_slotIsAuthenticated:(id<PPProSessionSlotHandle>)slot {
    if (!slot) return NO;
    if ([slot respondsToSelector:@selector(isAuthenticatedSession)]) {
        return slot.isAuthenticatedSession;
    }
    return !slot.isInvalidated && slot.currentUID.length > 0 &&
        (slot.expectedUID.length == 0 || [slot.currentUID isEqualToString:slot.expectedUID]);
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
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    return [self.runtimeProvider defaultAuthCurrentUID];
}

- (nullable NSString *)stagedAuthenticatedUID {
    id<PPProSessionSlotHandle> pending = self.pendingSlot;
    if (!pending || ![self pp_slotIsAuthenticated:pending]) {
        return nil;
    }
    return pending.currentUID ?: pending.expectedUID;
}

#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
- (nullable FIRUser *)stagedAuthenticatedUser {
    PPProFirebaseAccountRuntime *pending = self.pendingRuntime;
    return (pending && pending.isAuthenticatedSession) ? pending.auth.currentUser : nil;
}
#else
- (nullable id)stagedAuthenticatedUser {
    return nil;
}
#endif

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
    if (self.activeRuntime && [self pp_isMultiAccountRuntime]) {
        return self.activeRuntime.auth;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    return [FIRAuth auth];
}

- (nullable FIRUser *)currentUser {
    if (self.isSuspendedOrLocked) {
        return nil;
    }
    if (self.activeRuntime && [self pp_isMultiAccountRuntime]) {
        return self.activeRuntime.isAuthorizedSession ? self.activeRuntime.auth.currentUser : nil;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    return [self activeAuth].currentUser;
}

- (nullable FIRFirestore *)activeFirestore {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return (self.activeRuntime && self.activeRuntime.isAuthorizedSession) ? self.activeRuntime.firestore : nil;
    }
    return [FIRFirestore firestore];
}

- (nullable FIRFunctions *)activeFunctions {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return (self.activeRuntime && self.activeRuntime.isAuthorizedSession) ? self.activeRuntime.functions : nil;
    }
    return [FIRFunctions functionsForRegion:@"us-central1"];
}

- (nullable FIRStorage *)activeStorage {
    if (![self pp_allowsDataServiceAccess]) {
        return nil;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return (self.activeRuntime && self.activeRuntime.isAuthorizedSession) ? self.activeRuntime.storage : nil;
    }
    return [FIRStorage storage];
}

- (nullable FIRFirestore *)bootstrapFirestoreForStagedSlot {
    if (self.requiresTransitionRecovery || self.transitionCoordinator.phase == PPProTransitionSuspended) {
        return nil;
    }
    if (self.pendingRuntime && self.pendingRuntime.isAuthenticatedSession) {
        return self.pendingRuntime.bootstrapFirestore;
    }
    if (self.activeRuntime && self.activeRuntime.isAuthenticatedSession) {
        return self.activeRuntime.bootstrapFirestore;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    return [FIRFirestore firestore];
}

- (nullable FIRFunctions *)bootstrapFunctionsForStagedSlot {
    if (self.requiresTransitionRecovery || self.transitionCoordinator.phase == PPProTransitionSuspended) {
        return nil;
    }
    if (self.pendingRuntime && self.pendingRuntime.isAuthenticatedSession) {
        return self.pendingRuntime.bootstrapFunctions;
    }
    if (self.activeRuntime && self.activeRuntime.isAuthenticatedSession) {
        return self.activeRuntime.bootstrapFunctions;
    }
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    return [FIRFunctions functionsForRegion:@"us-central1"];
}

- (nullable FIRPhoneAuthProvider *)activePhoneProvider {
    if (self.pendingRuntime) {
        return [self.pendingRuntime phoneProvider];
    }
    if (self.activeRuntime && [self pp_isMultiAccountRuntime]) {
        return [self.activeRuntime phoneProvider];
    }
    if ([self pp_isMultiAccountRuntime]) {
        return nil;
    }
    FIRAuth *auth = [self activeAuth];
    return auth ? [FIRPhoneAuthProvider providerWithAuth:auth] : [FIRPhoneAuthProvider provider];
}

- (BOOL)canHandleAuthURL:(NSURL *)url {
    if (!url) return NO;
    if (self.pendingRuntime && [self.pendingRuntime.auth canHandleURL:url]) return YES;
    if (self.activeRuntime && [self.activeRuntime.auth canHandleURL:url]) return YES;
    return ![self pp_isMultiAccountRuntime] && [[FIRAuth auth] canHandleURL:url];
}

- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo {
    if (!userInfo) return NO;
    if (self.pendingRuntime && [self.pendingRuntime.auth canHandleNotification:userInfo]) return YES;
    if (self.activeRuntime && [self.activeRuntime.auth canHandleNotification:userInfo]) return YES;
    return ![self pp_isMultiAccountRuntime] && [[FIRAuth auth] canHandleNotification:userInfo];
}

- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken {
    if (!deviceToken.length) return;
    if (![self pp_isMultiAccountRuntime]) {
        [[FIRAuth auth] setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    }
    if (self.pendingRuntime.auth) {
        [self.pendingRuntime.auth setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    }
    if (self.activeRuntime.auth && self.activeRuntime.auth != self.pendingRuntime.auth) {
        [self.activeRuntime.auth setAPNSToken:deviceToken type:FIRAuthAPNSTokenTypeUnknown];
    }
}

- (void)authenticateStagedSlot:(nullable id<PPProSessionSlotHandle>)slot
                withCredential:(FIRAuthCredential *)credential
                   expectedUID:(nullable NSString *)expectedUID
                    completion:(void (^)(FIRUser * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (!credential) {
            if (completion) completion(nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Missing credential"));
            return;
        }
        PPProFirebaseAccountRuntime *targetRuntime = nil;
        if ([slot isKindOfClass:[PPProFirebaseAccountRuntime class]]) {
            targetRuntime = (PPProFirebaseAccountRuntime *)slot;
        } else if (self.pendingRuntime) {
            targetRuntime = self.pendingRuntime;
        }
        if ([self pp_isMultiAccountRuntime]) {
            if (!targetRuntime || targetRuntime.isInvalidated) {
                if (completion) completion(nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Staged slot unavailable"));
                return;
            }
            [targetRuntime authenticateCredential:credential completion:^(FIRUser * _Nullable user, NSError * _Nullable error) {
                if (error || !user.uid.length) {
                    if (completion) completion(nil, nil, error ?: PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                    return;
                }
                if (expectedUID.length > 0 && ![user.uid isEqualToString:expectedUID]) {
                    if (completion) completion(nil, user.uid, PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                    return;
                }
                if (completion) completion(user, user.uid, nil);
            }];
            return;
        }
        FIRAuth *legacyAuth = targetRuntime.auth ?: [FIRAuth auth];
        [legacyAuth signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable result, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                FIRUser *user = result.user ?: (error ? nil : legacyAuth.currentUser);
                if (error || !user.uid.length) {
                    if (completion) completion(nil, nil, error ?: PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                    return;
                }
                if (expectedUID.length > 0 && ![user.uid isEqualToString:expectedUID]) {
                    if (completion) completion(nil, user.uid, PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                    return;
                }
                if (completion) completion(user, user.uid, nil);
            });
        }];
    }];
}
#else
- (nullable id)activeAuth { return nil; }
- (nullable id)currentUser { return nil; }
- (nullable id)activeFirestore { return nil; }
- (nullable id)activeFunctions { return nil; }
- (nullable id)activeStorage { return nil; }
- (nullable id)bootstrapFirestoreForStagedSlot { return nil; }
- (nullable id)bootstrapFunctionsForStagedSlot { return nil; }
- (nullable id)activePhoneProvider { return nil; }
- (BOOL)canHandleAuthURL:(NSURL *)url { (void)url; return NO; }
- (BOOL)canHandleAuthNotification:(NSDictionary *)userInfo { (void)userInfo; return NO; }
- (void)setAPNSTokenForActiveAuths:(NSData *)deviceToken { (void)deviceToken; }
- (void)authenticateStagedSlot:(nullable id<PPProSessionSlotHandle>)slot
                withCredential:(FIRAuthCredential *)credential
                   expectedUID:(nullable NSString *)expectedUID
                    completion:(void (^)(FIRUser * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {
    (void)slot; (void)credential; (void)expectedUID;
    if (completion) completion(nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Stub build"));
}
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

- (void)registerAsyncActiveWorkValidator:(PPProAsyncActiveWorkValidator)validator forKey:(NSString *)key {
    if (!validator || !key.length) return;
    @synchronized (self) {
        self.asyncWorkValidators[key] = [validator copy];
    }
}

- (void)unregisterAsyncActiveWorkValidatorForKey:(NSString *)key {
    if (!key.length) return;
    @synchronized (self) {
        [self.asyncWorkValidators removeObjectForKey:key];
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

- (void)registerAsyncSessionTeardownHandler:(PPProAsyncSessionTeardownHandler)handler forKey:(NSString *)key {
    if (!handler || !key.length) return;
    @synchronized (self) {
        self.asyncTeardownHandlers[key] = [handler copy];
    }
}

- (void)unregisterAsyncSessionTeardownHandlerForKey:(NSString *)key {
    if (!key.length) return;
    @synchronized (self) {
        [self.asyncTeardownHandlers removeObjectForKey:key];
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

- (void)pp_runAsyncValidators:(NSArray<PPProAsyncActiveWorkValidator> *)validators
                        index:(NSUInteger)index
                   currentUID:(nullable NSString *)currentUID
                    targetUID:(nullable NSString *)targetUID
                       reason:(NSString *)reason
                   completion:(void (^)(BOOL, NSString * _Nullable, NSError * _Nullable))completion {
    if (index >= validators.count) {
        if (completion) completion(YES, nil, nil);
        return;
    }
    PPProAsyncActiveWorkValidator validator = validators[index];
    validator(currentUID ?: targetUID, reason ?: @"account_transition", ^(BOOL blocked, NSString * _Nullable blockReason) {
        [self pp_dispatchMain:^{
            if (blocked) {
                if (completion) completion(NO, blockReason, PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, blockReason));
                return;
            }
            [self pp_runAsyncValidators:validators
                                  index:index + 1
                             currentUID:currentUID
                              targetUID:targetUID
                                 reason:reason
                             completion:completion];
        }];
    });
}

- (void)preflightAccountTransitionForTargetUID:(nullable NSString *)targetUID
                                        reason:(NSString *)reason
                                    completion:(void (^)(BOOL, NSString * _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        NSString *syncReason = nil;
        if ([self hasBlockingActiveWorkWithReason:&syncReason]) {
            if (completion) completion(NO, syncReason, PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, syncReason));
            return;
        }
        NSArray<PPProAsyncActiveWorkValidator> *validators = nil;
        @synchronized (self) {
            validators = self.asyncWorkValidators.allValues;
        }
        [self pp_runAsyncValidators:validators
                              index:0
                         currentUID:[self.activeUID copy]
                          targetUID:targetUID
                             reason:reason
                         completion:completion];
    }];
}

#pragma mark - Teardown & Suspension

- (void)pp_dispatchMain:(dispatch_block_t)block {
    if (!block) return;
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

- (void)pp_emitPhaseChange:(NSString *)statusKey userInfo:(nullable NSDictionary *)extra {
    self.transitionStatusKey = [statusKey copy];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"phase"] = @(self.transitionCoordinator.phase);
    if (statusKey.length > 0) info[@"statusKey"] = statusKey;
    if (extra.count > 0) [info addEntriesFromDictionary:extra];
    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionPhaseDidChangeNotification
                                                        object:self
                                                      userInfo:[info copy]];
}

- (void)pp_runAsyncTeardownHandlersWithReason:(NSString *)reason completion:(dispatch_block_t)completion {
    NSArray<PPProAsyncSessionTeardownHandler> *asyncHandlers = nil;
    @synchronized (self) {
        asyncHandlers = self.asyncTeardownHandlers.allValues;
    }
    if (asyncHandlers.count == 0) {
        if (completion) completion();
        return;
    }
    __block NSInteger remaining = (NSInteger)asyncHandlers.count;
    __block BOOL finished = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PPProAsyncTeardownTimeoutSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (finished) return;
        finished = YES;
        if (completion) completion();
    });
    for (PPProAsyncSessionTeardownHandler handler in asyncHandlers) {
        __block BOOL singleAcked = NO;
        handler(reason ?: @"session_teardown", ^{
            [self pp_dispatchMain:^{
                if (singleAcked || finished) return;
                singleAcked = YES;
                remaining -= 1;
                if (remaining <= 0 && !finished) {
                    finished = YES;
                    if (completion) completion();
                }
            }];
        });
    }
}

- (void)pp_runTeardownHandlersWithReason:(NSString *)reason {
    self.sessionGeneration += 1;
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
        [self pp_runAsyncTeardownHandlersWithReason:reason completion:^{
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
    }];
}

/// Runs async teardown handlers and Notification V2 deactivation while the outgoing
/// session's `FIRFunctions` / `FIRAuth` are still accessible. Fails closed on barrier errors.
- (void)pp_suspendTicket:(NSUUID *)ticket
                  reason:(NSString *)reason
              completion:(void (^)(NSError * _Nullable suspendError))completion {
    [self pp_emitPhaseChange:@"freeze" userInfo:@{@"reason": reason ?: @"session_teardown"}];
    [self pp_runAsyncTeardownHandlersWithReason:reason completion:^{
        PPProNotificationBarrierHandler barrier = nil;
        @synchronized (self) {
            barrier = self.notificationBarrierHandler;
        }
        void (^advanceAndTeardown)(NSError * _Nullable) = ^(NSError * _Nullable barrierError) {
            if (barrierError) {
                [self pp_runTeardownHandlersWithReason:reason];
                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                [self pp_notifyRecoveryRequiredWithReason:@"notification_barrier_failed"];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification
                                                                    object:self
                                                                  userInfo:@{@"reason": @"notification_barrier_failed"}];
                if (completion) {
                    completion(PPWrapCoordinatorError(PPProSessionCoordinatorErrorNotificationBarrierFailed,
                                                      barrierError.localizedDescription ?: @"Notification deactivation failed",
                                                      barrierError));
                }
                return;
            }
            NSError *suspendErr = nil;
            BOOL advanced = [self.transitionCoordinator advance:ticket
                                                        toPhase:PPProTransitionSuspended
                                                    verifiedUID:nil
                                                          error:&suspendErr];
            [self pp_runTeardownHandlersWithReason:reason];
            [self pp_emitPhaseChange:@"suspended" userInfo:@{@"reason": reason ?: @"session_teardown"}];
            if (!advanced) {
                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                [self pp_notifyRecoveryRequiredWithReason:@"suspend_failed"];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification
                                                                    object:self
                                                                  userInfo:@{@"reason": @"suspend_failed"}];
                if (completion) completion(suspendErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            if (completion) completion(nil);
        };
        if (barrier) {
            [self pp_emitPhaseChange:@"detach_notifications" userInfo:nil];
            barrier(reason ?: @"session_teardown", ^(NSError * _Nullable barrierError) {
                [self pp_dispatchMain:^{
                    advanceAndTeardown(barrierError);
                }];
            });
        } else {
            advanceAndTeardown(nil);
        }
    }];
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
        if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
            [self.runtimeProvider clearActiveIdentityWithError:nil];
        }
        [self pp_runAsyncTeardownHandlersWithReason:@"external_signout" completion:^{
            [self pp_runTeardownHandlersWithReason:@"external_signout"];
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification
                                                                object:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification
                                                                object:self];
        }];
    }];
}

- (void)pp_waitForPendingWritesOnCurrentSessionWithCompletion:(void (^)(NSError * _Nullable error))completion {
    id<PPProSessionSlotHandle> currentSlot = self.activeSlot;
    if (currentSlot) {
        if (![self pp_slotIsAuthenticated:currentSlot]) {
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

#pragma mark - Remembered Account Switch / Sign-In / Add Account

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

        void (^startSwitch)(void) = ^{
            NSError *journalError = nil;
            NSUUID *ticket = [self.transitionCoordinator beginFromUID:effectiveSource
                                                            targetUID:safeTarget
                                                         sourceSlotID:self.activeSlot.slotID
                                                         targetSlotID:nil
                                                                 mode:(effectiveSource.length > 0 ? @"switch" : @"remembered_signin")
                                                                error:&journalError];
            if (!ticket) {
                if (completion) completion(NO, nil, nil, journalError ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = ticket;
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionWillBeginNotification
                                                                object:self
                                                              userInfo:@{@"targetUID": safeTarget}];
            [self pp_emitPhaseChange:@"preflight" userInfo:@{@"targetUID": safeTarget}];

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
                        if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                            [self.runtimeProvider clearActiveIdentityWithError:nil];
                        }
                        NSError *authPhaseErr = nil;
                        if (![self.transitionCoordinator advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&authPhaseErr]) {
                            [self.transitionCoordinator requireRecoveryForTicket:ticket];
                            [self pp_notifyRecoveryRequiredWithReason:@"authenticating_journal_failed"];
                            if (completion) completion(NO, nil, nil, authPhaseErr);
                            return;
                        }
                        [self pp_emitPhaseChange:@"authenticating" userInfo:@{@"targetUID": safeTarget}];
                        id<PPProSessionSlotHandle> stagedSlot = nil;
                        if ([self pp_isMultiAccountRuntime]) {
                            NSError *slotErr = nil;
                            stagedSlot = [self.runtimeProvider openSlotForRememberedUID:safeTarget error:&slotErr];
                            if (!stagedSlot) {
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"slot_open_failed"];
                                if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                                return;
                            }
                            NSError *metaErr = nil;
                            if (![self.transitionCoordinator recordSlotMetadataForTicket:ticket
                                                                            sourceSlotID:nil
                                                                            targetSlotID:stagedSlot.slotID
                                                                       provisionalSlotID:nil
                                                                               targetUID:safeTarget
                                                                                   error:&metaErr]) {
                                [stagedSlot signOutAndInvalidate:YES completion:nil];
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"slot_journal_failed"];
                                if (completion) completion(NO, nil, nil, metaErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
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

                    if ([self pp_isMultiAccountRuntime] && self.activeSlot) {
                        // Multi-account mode keeps remembered slot credentials isolated per slot; detach active runtime cleanly.
                        afterSourceCleared(nil);
                    } else if (effectiveSource.length > 0) {
                        [self.runtimeProvider signOutDefaultAuthWithCompletion:afterSourceCleared];
                    } else {
                        afterSourceCleared(nil);
                    }
                }];
            };

            if (effectiveSource.length > 0) {
                [self pp_emitPhaseChange:@"drain" userInfo:@{@"targetUID": safeTarget}];
                [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                    if (writeError) {
                        [self.transitionCoordinator cancelPreflight:ticket error:nil];
                        if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                        if (completion) completion(NO, nil, nil, writeError);
                        return;
                    }
                    continueAfterWrites();
                }];
            } else {
                continueAfterWrites();
            }
        };

        if (effectiveSource.length > 0) {
            [self preflightAccountTransitionForTargetUID:safeTarget reason:@"account_switch" completion:^(BOOL allowed, __unused NSString * _Nullable blockReason, NSError * _Nullable preflightErr) {
                if (!allowed) {
                    if (completion) completion(NO, nil, nil, preflightErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, nil));
                    return;
                }
                startSwitch();
            }];
        } else {
            startSwitch();
        }
    }];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedAccountRecords {
    return [self.runtimeProvider rememberedRecordsWithError:nil] ?: @[];
}

- (BOOL)isMultiAccountRolloutEnabled {
    return [self pp_isMultiAccountRuntime];
}

- (void)fastSwitchToRememberedUID:(NSString *)targetUID
                          fromUID:(nullable NSString *)sourceUID
                       completion:(void (^)(BOOL, BOOL, NSUUID * _Nullable, id<PPProSessionSlotHandle> _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionBusy, nil));
            return;
        }
        NSString *safeTarget = [targetUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!safeTarget.length) {
            if (completion) completion(NO, NO, nil, nil, PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, @"Missing target account"));
            return;
        }
        NSString *currentActiveUID = [self.activeUID copy];
        NSString *safeSource = [sourceUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *effectiveSource = safeSource.length > 0 ? safeSource : (currentActiveUID.length > 0 ? currentActiveUID : nil);
        if (effectiveSource.length > 0 && [effectiveSource isEqualToString:safeTarget]) {
            if (completion) completion(YES, NO, nil, self.activeSlot, nil);
            return;
        }
        if (![self pp_isMultiAccountRuntime]) {
            [self beginRememberedAccountSignInOrSwitchToUID:safeTarget
                                                    fromUID:effectiveSource
                                                 completion:^(BOOL allowed, NSUUID * _Nullable ticket, id<PPProSessionSlotHandle> _Nullable stagedSlot, NSError * _Nullable error) {
                if (completion) completion(NO, allowed, ticket, stagedSlot, error);
            }];
            return;
        }

        // Resolve record metadata before committing switch so masked label & method survive install.
        NSArray<NSDictionary<NSString *, NSString *> *> *records = [self.runtimeProvider rememberedRecordsWithError:nil] ?: @[];
        NSDictionary<NSString *, NSString *> *targetRecord = nil;
        for (NSDictionary<NSString *, NSString *> *rec in records) {
            if ([rec[@"uid"] isEqualToString:safeTarget]) {
                targetRecord = rec;
                break;
            }
        }
        if (!targetRecord || !targetRecord[@"slotID"].length) {
            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusVerificationRequired forUID:safeTarget error:nil];
            }
            if (completion) completion(NO, YES, nil, nil, nil);
            return;
        }

        void (^startFastSwitch)(void) = ^{
            NSError *journalError = nil;
            NSUUID *ticket = [self.transitionCoordinator beginFromUID:effectiveSource
                                                            targetUID:safeTarget
                                                         sourceSlotID:self.activeSlot.slotID
                                                         targetSlotID:nil
                                                                 mode:@"fast_switch"
                                                                error:&journalError];
            if (!ticket) {
                if (completion) completion(NO, NO, nil, nil, journalError ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = ticket;
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionWillBeginNotification
                                                                object:self
                                                              userInfo:@{@"targetUID": safeTarget}];
            [self pp_emitPhaseChange:@"preflight" userInfo:@{@"targetUID": safeTarget}];

            void (^continueAfterWrites)(void) = ^{
                [self pp_suspendTicket:ticket reason:@"account_switch" completion:^(NSError * _Nullable suspendErr) {
                    if (suspendErr) {
                        if (completion) completion(NO, NO, nil, nil, suspendErr);
                        return;
                    }
                    self.activeSlot = nil;
                    if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                        [self.runtimeProvider clearActiveIdentityWithError:nil];
                    }
                    NSError *authPhaseErr = nil;
                    if (![self.transitionCoordinator advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&authPhaseErr]) {
                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                        [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_authenticating_failed"];
                        if (completion) completion(NO, NO, nil, nil, authPhaseErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                        return;
                    }
                    [self pp_emitPhaseChange:@"authenticating" userInfo:@{@"targetUID": safeTarget}];

                    NSError *slotErr = nil;
                    id<PPProSessionSlotHandle> stagedSlot = [self.runtimeProvider openSlotForRememberedUID:safeTarget error:&slotErr];
                    if (!stagedSlot) {
                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                        if ([self.transitionCoordinator clearAfterVerifiedSignOut:nil]) {
                            self.activeTransitionTicket = nil;
                            self.sessionGeneration += 1;
                            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                                [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusVerificationRequired forUID:safeTarget error:nil];
                            }
                            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                            if (completion) completion(NO, YES, nil, nil, slotErr);
                        } else {
                            [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_slot_open_failed"];
                            if (completion) completion(NO, NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                        }
                        return;
                    }

                    NSError *metaErr = nil;
                    if (![self.transitionCoordinator recordSlotMetadataForTicket:ticket
                                                                    sourceSlotID:nil
                                                                    targetSlotID:stagedSlot.slotID
                                                               provisionalSlotID:nil
                                                                       targetUID:safeTarget
                                                                           error:&metaErr]) {
                        [stagedSlot signOutAndInvalidate:YES completion:nil];
                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                        [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_slot_journal_failed"];
                        if (completion) completion(NO, NO, nil, nil, metaErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                        return;
                    }

                    if (stagedSlot.expectedUID.length > 0 &&
                        stagedSlot.currentUID.length > 0 &&
                        ![stagedSlot.currentUID isEqualToString:stagedSlot.expectedUID]) {
                        [stagedSlot signOutAndInvalidate:YES completion:^(NSError * _Nullable mismatchedErr) {
                            [self.transitionCoordinator requireRecoveryForTicket:ticket];
                            [self pp_notifyRecoveryRequiredWithReason:mismatchedErr ? @"slot_mismatched_signout_failed" : @"slot_mismatched_uid"];
                            if (completion) completion(NO, NO, nil, nil, mismatchedErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorIdentityMismatch, nil));
                        }];
                        return;
                    }

                    void (^settleForReauth)(NSString *, NSError * _Nullable) = ^(NSString *statusHint, NSError * _Nullable causeErr) {
                        void (^finishReauthSettle)(void) = ^{
                            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                                [self.runtimeProvider updateSessionStatusHint:statusHint forUID:safeTarget error:nil];
                            }
                            self.pendingSlot = stagedSlot.isInvalidated ? nil : stagedSlot;
                            if (effectiveSource.length > 0) {
                                // Leaving a suspended active workspace to the login portal: cleanly settle
                                // the transition journal if the slot is signed out so the login screen
                                // offers interactive re-verification rather than a recovery lock.
                                [stagedSlot signOutAndInvalidate:YES completion:^(NSError * _Nullable signOutErr) {
                                    self.pendingSlot = nil;
                                    if (signOutErr) {
                                        [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                        [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_reauth_signout_failed"];
                                        if (completion) completion(NO, NO, nil, nil, signOutErr);
                                        return;
                                    }
                                    [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                    if ([self.transitionCoordinator clearAfterVerifiedSignOut:nil]) {
                                        self.activeTransitionTicket = nil;
                                        self.sessionGeneration += 1;
                                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                                        if (completion) completion(NO, YES, nil, nil, causeErr);
                                    } else {
                                        [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_reauth_clear_failed"];
                                        if (completion) completion(NO, NO, nil, nil, causeErr);
                                    }
                                }];
                            } else {
                                // Already on the login portal: keep the Authenticating ticket & staged slot
                                // open so the user can sign into this exact remembered identity immediately.
                                if (completion) completion(NO, YES, ticket, stagedSlot, causeErr);
                            }
                        };
                        finishReauthSettle();
                    };

                    if (![self pp_slotIsAuthenticated:stagedSlot]) {
                        settleForReauth(PPProSessionStatusVerificationRequired, nil);
                        return;
                    }

                    void (^commitTargetSlot)(void) = ^{
                        [self completeAuthenticationForTicket:ticket
                                              provisionalSlot:stagedSlot
                                             authenticatedUID:safeTarget
                                                  expectedUID:safeTarget
                                                  maskedLabel:targetRecord[@"label"]
                                                       method:targetRecord[@"method"]
                                            proAccessVerified:YES
                                                   completion:^(BOOL installed, NSError * _Nullable installErr) {
                            if (completion) completion(installed, NO, installed ? nil : ticket, installed ? nil : stagedSlot, installErr);
                        }];
                    };

                    void (^verifyProThenInstall)(void) = ^{
                        if ([self.runtimeProvider respondsToSelector:@selector(verifyProAccessForUID:slot:completion:)]) {
                            [self.runtimeProvider verifyProAccessForUID:safeTarget slot:stagedSlot completion:^(BOOL authorized, NSError * _Nullable authzErr) {
                                [self pp_dispatchMain:^{
                                    if (!authorized) {
                                        [stagedSlot signOutAndInvalidate:YES completion:^(NSError * _Nullable signOutErr) {
                                            if (signOutErr) {
                                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                                [self pp_notifyRecoveryRequiredWithReason:@"fast_switch_denied_signout_failed"];
                                                if (completion) completion(NO, NO, nil, nil, signOutErr);
                                                return;
                                            }
                                            settleForReauth(PPProErrorLooksPermanentRevocation(authzErr) ? PPProSessionStatusRevoked : PPProSessionStatusVerificationRequired,
                                                            authzErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorProAccessDenied, nil));
                                        }];
                                        return;
                                    }
                                    commitTargetSlot();
                                }];
                            }];
                        } else {
                            commitTargetSlot();
                        }
                    };

                    if ([stagedSlot respondsToSelector:@selector(validateSessionWithCompletion:)]) {
                        [stagedSlot validateSessionWithCompletion:^(id _Nullable user, NSError * _Nullable valErr) {
                            [self pp_dispatchMain:^{
                                if (!user || valErr) {
                                    BOOL permanent = PPProErrorLooksPermanentRevocation(valErr);
                                    NSString *statusHint = permanent ? PPProSessionStatusExpired : PPProSessionStatusUnavailable;
                                    if (permanent) {
                                        [stagedSlot signOutAndInvalidate:YES completion:^(__unused NSError *e) {
                                            settleForReauth(statusHint, valErr);
                                        }];
                                    } else {
                                        settleForReauth(statusHint, valErr);
                                    }
                                    return;
                                }
                                verifyProThenInstall();
                            }];
                        }];
                    } else {
                        verifyProThenInstall();
                    }
                }];
            };

            if (effectiveSource.length > 0) {
                [self pp_emitPhaseChange:@"drain" userInfo:@{@"targetUID": safeTarget}];
                [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                    if (writeError) {
                        [self.transitionCoordinator cancelPreflight:ticket error:nil];
                        if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                        if (completion) completion(NO, NO, nil, nil, writeError);
                        return;
                    }
                    continueAfterWrites();
                }];
            } else {
                continueAfterWrites();
            }
        };

        if (effectiveSource.length > 0) {
            [self preflightAccountTransitionForTargetUID:safeTarget reason:@"account_switch" completion:^(BOOL allowed, __unused NSString * _Nullable blockReason, NSError * _Nullable preflightErr) {
                if (!allowed) {
                    if (completion) completion(NO, NO, nil, nil, preflightErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, nil));
                    return;
                }
                startFastSwitch();
            }];
        } else {
            startFastSwitch();
        }
    }];
}

- (void)pp_beginProvisionalWithSourceUID:(nullable NSString *)sourceUID
                                    mode:(NSString *)mode
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
            [self preflightAccountTransitionForTargetUID:nil reason:mode completion:^(BOOL allowed, __unused NSString * _Nullable blockReason, NSError * _Nullable preflightErr) {
                if (!allowed) {
                    if (completion) completion(NO, nil, nil, preflightErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, nil));
                    return;
                }
                NSError *journalErr = nil;
                NSUUID *ticket = [self.transitionCoordinator beginProvisionalTransitionFromUID:safeSource
                                                                                          mode:mode
                                                                                  sourceSlotID:self.activeSlot.slotID
                                                                                         error:&journalErr];
                if (!ticket) {
                    if (completion) completion(NO, nil, nil, journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                    return;
                }
                self.activeTransitionTicket = ticket;
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionWillBeginNotification object:self];
                [self pp_emitPhaseChange:@"drain" userInfo:@{@"mode": mode}];

                [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                    if (writeError) {
                        [self.transitionCoordinator cancelPreflight:ticket error:nil];
                        if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                        if (completion) completion(NO, nil, nil, writeError);
                        return;
                    }
                    [self pp_suspendTicket:ticket reason:mode completion:^(NSError * _Nullable suspendErr) {
                        if (suspendErr) {
                            if (completion) completion(NO, nil, nil, suspendErr);
                            return;
                        }
                        void (^afterSourceCleared)(NSError * _Nullable) = ^(NSError * _Nullable signOutErr) {
                            if (signOutErr) {
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"provisional_signout_failed"];
                                if (completion) completion(NO, nil, nil, signOutErr);
                                return;
                            }
                            self.activeSlot = nil;
                            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                                [self.runtimeProvider clearActiveIdentityWithError:nil];
                            }
                            NSError *authAdvanceErr = nil;
                            if (![self.transitionCoordinator advance:ticket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&authAdvanceErr]) {
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"provisional_authenticating_failed"];
                                if (completion) completion(NO, nil, nil, authAdvanceErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                                return;
                            }
                            [self pp_emitPhaseChange:@"authenticating" userInfo:@{@"mode": mode}];
                            id<PPProSessionSlotHandle> provisionalSlot = nil;
                            if ([self pp_isMultiAccountRuntime]) {
                                NSError *slotErr = nil;
                                provisionalSlot = [self.runtimeProvider createProvisionalSlotWithError:&slotErr];
                                if (!provisionalSlot) {
                                    [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                    [self pp_notifyRecoveryRequiredWithReason:@"provisional_slot_failed"];
                                    if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                                    return;
                                }
                                NSError *metaErr = nil;
                                if (![self.transitionCoordinator recordSlotMetadataForTicket:ticket
                                                                                sourceSlotID:nil
                                                                                targetSlotID:nil
                                                                           provisionalSlotID:provisionalSlot.slotID
                                                                                   targetUID:nil
                                                                                       error:&metaErr]) {
                                    [provisionalSlot teardownSlotAppWithCompletion:nil];
                                    [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                    [self pp_notifyRecoveryRequiredWithReason:@"provisional_journal_slot_failed"];
                                    if (completion) completion(NO, nil, nil, metaErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                                    return;
                                }
                                self.pendingSlot = provisionalSlot;
                            }
                            if (completion) completion(YES, ticket, provisionalSlot, nil);
                        };

                        if ([self pp_isMultiAccountRuntime] && self.activeSlot) {
                            // Keep remembered source slot credentials intact on account switch/add-account.
                            afterSourceCleared(nil);
                        } else {
                            [self.runtimeProvider signOutDefaultAuthWithCompletion:afterSourceCleared];
                        }
                    }];
                }];
            }];
            return;
        }

        // Idle -> provisional slot (P0-06: journal ticket MUST exist BEFORE slot creation)
        NSError *journalErr = nil;
        NSUUID *ticket = [self.transitionCoordinator beginProvisionalTransitionFromUID:nil
                                                                                  mode:mode
                                                                          sourceSlotID:nil
                                                                                 error:&journalErr];
        if (!ticket) {
            if (completion) completion(NO, nil, nil, journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
            return;
        }
        id<PPProSessionSlotHandle> provisionalSlot = nil;
        if ([self pp_isMultiAccountRuntime]) {
            NSError *slotErr = nil;
            provisionalSlot = [self.runtimeProvider createProvisionalSlotWithError:&slotErr];
            if (!provisionalSlot) {
                [self.transitionCoordinator cancelPreflight:ticket error:nil];
                if (completion) completion(NO, nil, nil, slotErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil));
                return;
            }
            NSError *metaErr = nil;
            if (![self.transitionCoordinator recordSlotMetadataForTicket:ticket
                                                            sourceSlotID:nil
                                                            targetSlotID:nil
                                                       provisionalSlotID:provisionalSlot.slotID
                                                               targetUID:nil
                                                                   error:&metaErr]) {
                [provisionalSlot teardownSlotAppWithCompletion:nil];
                [self.transitionCoordinator cancelPreflight:ticket error:nil];
                if (completion) completion(NO, nil, nil, metaErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
        }
        self.activeTransitionTicket = ticket;
        self.pendingSlot = provisionalSlot;
        if (completion) completion(YES, ticket, provisionalSlot, nil);
    }];
}

- (void)beginProvisionalSignInFromUID:(nullable NSString *)sourceUID
                           completion:(void (^)(BOOL, NSUUID * _Nullable, id<PPProSessionSlotHandle> _Nullable, NSError * _Nullable))completion {
    [self pp_beginProvisionalWithSourceUID:sourceUID mode:(sourceUID.length ? @"provisional_switch_out" : @"provisional_signin") completion:completion];
}

- (void)beginProvisionalAddAccountFromUID:(nullable NSString *)sourceUID
                               completion:(void (^)(BOOL, NSUUID * _Nullable, id<PPProSessionSlotHandle> _Nullable, NSError * _Nullable))completion {
    [self pp_beginProvisionalWithSourceUID:sourceUID mode:@"add_account" completion:completion];
}

- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                             completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self completeAuthenticationForTicket:ticket
                          provisionalSlot:slot
                         authenticatedUID:authenticatedUID
                              expectedUID:expectedUID
                              maskedLabel:maskedLabel
                                   method:method
                        proAccessVerified:YES
                               completion:completion];
}

- (void)completeAuthenticationForTicket:(nullable NSUUID *)ticket
                        provisionalSlot:(nullable id<PPProSessionSlotHandle>)slot
                       authenticatedUID:(NSString *)authenticatedUID
                            expectedUID:(nullable NSString *)expectedUID
                            maskedLabel:(nullable NSString *)maskedLabel
                                 method:(nullable NSString *)method
                      proAccessVerified:(BOOL)proAccessVerified
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

        if (!proAccessVerified) {
            [self handleAuthenticationFailureForTicket:ticket
                                         provisionalSlot:slot
                                                   error:PPCoordinatorError(PPProSessionCoordinatorErrorProAccessDenied, @"Pro access verification did not pass")
                                     mismatchExpectedUID:nil
                                              completion:^(__unused BOOL recoveryRequired, NSError *finalError) {
                if (completion) completion(NO, finalError);
            }];
            return;
        }

        NSUUID *effectiveTicket = ticket ?: self.activeTransitionTicket;
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
            if (!effectiveTicket) {
                [self handleAuthenticationFailureForTicket:nil
                                             provisionalSlot:slot
                                                       error:journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil)
                                         mismatchExpectedUID:nil
                                                  completion:^(__unused BOOL r, NSError *finalError) {
                    if (completion) completion(NO, finalError);
                }];
                return;
            }
            self.activeTransitionTicket = effectiveTicket;
        }

        // Advance sequentially up to Authorized based on current phase cleanly
        NSError *journalStepErr = nil;
        if (self.transitionCoordinator.phase == PPProTransitionPreflight) {
            if (![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionSuspended verifiedUID:nil error:&journalStepErr]) {
                [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                [self pp_notifyRecoveryRequiredWithReason:@"suspended_phase_failed"];
                if (completion) completion(NO, journalStepErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
        }
        if (self.transitionCoordinator.phase == PPProTransitionSuspended) {
            if (![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionAuthenticating verifiedUID:nil error:&journalStepErr]) {
                [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                [self pp_notifyRecoveryRequiredWithReason:@"authenticating_phase_failed"];
                if (completion) completion(NO, journalStepErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
        }
        if (![self.transitionCoordinator advance:effectiveTicket toPhase:PPProTransitionAuthorized verifiedUID:safeAuthUID error:&journalStepErr]) {
            [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
            [self pp_notifyRecoveryRequiredWithReason:@"authorized_phase_failed"];
            if (completion) completion(NO, journalStepErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
            return;
        }

        void (^proceedAfterProviderCheck)(id<PPProSessionSlotHandle> _Nullable) = ^(id<PPProSessionSlotHandle> _Nullable finalSlot) {
            void (^installValidatedSlot)(id<PPProSessionSlotHandle> _Nullable) = ^(id<PPProSessionSlotHandle> _Nullable verifiedSlot) {
                if (verifiedSlot && [verifiedSlot respondsToSelector:@selector(markProAccessVerified:forUID:)]) {
                    [verifiedSlot markProAccessVerified:YES forUID:safeAuthUID];
                }
                if ([self pp_isMultiAccountRuntime] && verifiedSlot) {
                    NSString *label = maskedLabel.length ? maskedLabel : safeAuthUID;
                    NSString *authMethod = method.length ? method : @"phone";
                    NSError *rememberErr = nil;
                    BOOL remembered = [self.runtimeProvider rememberUID:safeAuthUID
                                                            maskedLabel:label
                                                                 method:authMethod
                                                                 slotID:verifiedSlot.slotID
                                                                  error:&rememberErr];
                    if (!remembered) {
                        [self handleAuthenticationFailureForTicket:effectiveTicket
                                                     provisionalSlot:verifiedSlot
                                                               error:rememberErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, @"Remembered identity persistence failed")
                                                 mismatchExpectedUID:nil
                                                          completion:^(__unused BOOL r, NSError *finalError) {
                            if (completion) completion(NO, finalError);
                        }];
                        return;
                    }
                    if ([self.runtimeProvider respondsToSelector:@selector(setActiveIdentityUID:slotID:error:)]) {
                        NSError *activeHintErr = nil;
                        if (![self.runtimeProvider setActiveIdentityUID:safeAuthUID slotID:verifiedSlot.slotID error:&activeHintErr]) {
                            [self handleAuthenticationFailureForTicket:effectiveTicket
                                                         provisionalSlot:verifiedSlot
                                                                   error:activeHintErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, @"Active pointer persistence failed")
                                                     mismatchExpectedUID:nil
                                                              completion:^(__unused BOOL r, NSError *finalError) {
                                if (completion) completion(NO, finalError);
                            }];
                            return;
                        }
                    }
                    if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                        [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusActive forUID:safeAuthUID error:nil];
                    }
                    self.activeSlot = verifiedSlot;
                }
                if (self.pendingSlot == verifiedSlot || !verifiedSlot) {
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
                self.sessionGeneration += 1;
                self.activeTransitionTicket = nil;
                [self pp_emitPhaseChange:@"installed" userInfo:@{@"uid": safeAuthUID}];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidCommitNotification
                                                                    object:self
                                                                  userInfo:@{@"uid": safeAuthUID}];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification
                                                                    object:self
                                                                  userInfo:@{@"uid": safeAuthUID}];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionAccountListDidChangeNotification
                                                                    object:self
                                                                  userInfo:@{@"uid": safeAuthUID}];
                if (completion) completion(YES, nil);
            };

            if ([self pp_isMultiAccountRuntime] && finalSlot) {
                NSError *readRecsErr = nil;
                NSArray<NSDictionary<NSString *, NSString *> *> *existing = [self.runtimeProvider rememberedRecordsWithError:&readRecsErr];
                if (!existing) {
                    [self handleAuthenticationFailureForTicket:effectiveTicket
                                                 provisionalSlot:finalSlot
                                                           error:readRecsErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil)
                                             mismatchExpectedUID:nil
                                                      completion:^(__unused BOOL r, NSError *finalError) {
                        if (completion) completion(NO, finalError);
                    }];
                    return;
                }
                NSString *existingSlotUUIDString = nil;
                for (NSDictionary *rec in existing) {
                    if ([rec[@"uid"] isEqual:safeAuthUID]) {
                        existingSlotUUIDString = rec[@"slotID"];
                        break;
                    }
                }
                if (existingSlotUUIDString.length > 0 && ![existingSlotUUIDString isEqualToString:finalSlot.slotID.UUIDString]) {
                    NSError *priorOpenErr = nil;
                    id<PPProSessionSlotHandle> priorSlot = [self.runtimeProvider openSlotForRememberedUID:safeAuthUID error:&priorOpenErr];
                    if (priorSlot && [self pp_slotIsAuthenticated:priorSlot]) {
                        [priorSlot waitForPendingWritesWithCompletion:^(NSError * _Nullable writeError) {
                            [self pp_dispatchMain:^{
                                if (writeError) {
                                    // Preserve existing slot's unconfirmed writes instead of silently discarding them.
                                    [finalSlot signOutAndInvalidate:YES completion:^(__unused NSError *e) {
                                        self.pendingSlot = nil;
                                        [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                                        [self pp_notifyRecoveryRequiredWithReason:@"existing_slot_pending_writes"];
                                        if (completion) completion(NO, writeError);
                                    }];
                                    return;
                                }
                                [priorSlot teardownSlotAppWithCompletion:^(BOOL deleted, NSError * _Nullable teardownErr) {
                                    if (teardownErr || !deleted) {
                                        [finalSlot signOutAndInvalidate:YES completion:^(__unused NSError *e) {
                                            self.pendingSlot = nil;
                                            [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                                            [self pp_notifyRecoveryRequiredWithReason:@"existing_slot_teardown_failed"];
                                            if (completion) completion(NO, teardownErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorPendingWritesUnconfirmed, nil));
                                        }];
                                        return;
                                    }
                                    NSError *removeErr = nil;
                                    if (![self.runtimeProvider removeRememberedUID:safeAuthUID error:&removeErr]) {
                                        [self.transitionCoordinator requireRecoveryForTicket:effectiveTicket];
                                        [self pp_notifyRecoveryRequiredWithReason:@"existing_slot_registry_remove_failed"];
                                        if (completion) completion(NO, removeErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                                        return;
                                    }
                                    installValidatedSlot(finalSlot);
                                }];
                            }];
                        }];
                        return;
                    } else if (priorSlot) {
                        [priorSlot teardownSlotAppWithCompletion:^(BOOL deleted, NSError * _Nullable teardownErr) {
                            if (teardownErr || !deleted) {
                                [self handleAuthenticationFailureForTicket:effectiveTicket
                                                             provisionalSlot:finalSlot
                                                                       error:teardownErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSlotUnavailable, nil)
                                                         mismatchExpectedUID:nil
                                                                  completion:^(__unused BOOL r, NSError *finalError) {
                                    if (completion) completion(NO, finalError);
                                }];
                                return;
                            }
                            NSError *removeErr = nil;
                            if (![self.runtimeProvider removeRememberedUID:safeAuthUID error:&removeErr]) {
                                [self handleAuthenticationFailureForTicket:effectiveTicket
                                                             provisionalSlot:finalSlot
                                                                       error:removeErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil)
                                                         mismatchExpectedUID:nil
                                                                  completion:^(__unused BOOL r, NSError *finalError) {
                                    if (completion) completion(NO, finalError);
                                }];
                                return;
                            }
                            installValidatedSlot(finalSlot);
                        }];
                        return;
                    } else {
                        NSError *removeErr = nil;
                        if (![self.runtimeProvider removeRememberedUID:safeAuthUID error:&removeErr]) {
                            [self handleAuthenticationFailureForTicket:effectiveTicket
                                                         provisionalSlot:finalSlot
                                                                   error:removeErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil)
                                                     mismatchExpectedUID:nil
                                                              completion:^(__unused BOOL r, NSError *finalError) {
                                if (completion) completion(NO, finalError);
                            }];
                            return;
                        }
                    }
                }
            }
            installValidatedSlot(finalSlot);
        };

        if (slot && [self.runtimeProvider respondsToSelector:@selector(verifyProAccessForUID:slot:completion:)]) {
            [self.runtimeProvider verifyProAccessForUID:safeAuthUID slot:slot completion:^(BOOL authorized, NSError * _Nullable authzErr) {
                [self pp_dispatchMain:^{
                    if (!authorized) {
                        [self handleAuthenticationFailureForTicket:effectiveTicket
                                                     provisionalSlot:slot
                                                               error:authzErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorProAccessDenied, nil)
                                                 mismatchExpectedUID:nil
                                                          completion:^(__unused BOOL r, NSError *finalError) {
                            if (completion) completion(NO, finalError);
                        }];
                        return;
                    }
                    proceedAfterProviderCheck(slot);
                }];
            }];
            return;
        }
        proceedAfterProviderCheck(slot);
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
                if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                    [self.runtimeProvider clearActiveIdentityWithError:nil];
                }
                if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
                    if ([self.transitionCoordinator clearAfterVerifiedSignOut:nil]) {
                        self.activeTransitionTicket = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                    } else {
                        [self pp_notifyRecoveryRequiredWithReason:@"recovery_clear_failed"];
                        if (completion) completion(YES, authError ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                        return;
                    }
                } else {
                    self.activeTransitionTicket = nil;
                    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
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
        id<PPProSessionSlotHandle> pending = self.pendingSlot;
        if (effectiveTicket && self.transitionCoordinator.phase == PPProTransitionPreflight) {
            void (^finishCancel)(void) = ^{
                NSError *err = nil;
                BOOL ok = [self.transitionCoordinator cancelPreflight:effectiveTicket error:&err];
                if (ok) {
                    self.activeTransitionTicket = nil;
                    self.pendingSlot = nil;
                    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
                }
                if (completion) completion(ok, err);
            };
            if (pending) {
                [pending teardownSlotAppWithCompletion:^(BOOL deleted, NSError * _Nullable teardownErr) {
                    if (teardownErr || !deleted) {
                        [self handleAuthenticationFailureForTicket:effectiveTicket
                                                     provisionalSlot:pending
                                                               error:teardownErr
                                                 mismatchExpectedUID:nil
                                                          completion:^(BOOL recoveryRequired, NSError *finalError) {
                            if (completion) completion(!recoveryRequired && !finalError, finalError);
                        }];
                        return;
                    }
                    finishCancel();
                }];
                return;
            }
            finishCancel();
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

#pragma mark - Cold-Start Active Restore & Sign Out All

- (void)restoreLastActiveSessionOnColdLaunchWithCompletion:(void (^)(BOOL, BOOL, NSString * _Nullable, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (![self pp_isMultiAccountRuntime]) {
            if (completion) completion(NO, NO, nil, nil);
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, NO, nil, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (![self.runtimeProvider respondsToSelector:@selector(activeIdentityHintWithError:)]) {
            if (completion) completion(NO, NO, nil, nil);
            return;
        }
        NSError *hintErr = nil;
        NSDictionary<NSString *, NSString *> *hint = [self.runtimeProvider activeIdentityHintWithError:&hintErr];
        if (hintErr || !hint || ![hint[@"uid"] length]) {
            if (completion) completion(NO, NO, nil, hintErr);
            return;
        }
        NSString *uid = hint[@"uid"];
        NSUUID *slotID = hint[@"slotID"].length ? [[NSUUID alloc] initWithUUIDString:hint[@"slotID"]] : nil;
        NSError *openErr = nil;
        id<PPProSessionSlotHandle> slot = slotID && [self.runtimeProvider respondsToSelector:@selector(openSlotWithID:expectedUID:error:)]
            ? [self.runtimeProvider openSlotWithID:slotID expectedUID:uid error:&openErr]
            : [self.runtimeProvider openSlotForRememberedUID:uid error:&openErr];
        if (!slot || ![self pp_slotIsAuthenticated:slot]) {
            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                [self.runtimeProvider clearActiveIdentityWithError:nil];
            }
            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusVerificationRequired forUID:uid error:nil];
            }
            if (completion) completion(NO, YES, uid, openErr);
            return;
        }

        void (^finishAuthorizedCheck)(BOOL, NSError * _Nullable) = ^(BOOL authorized, NSError * _Nullable authzErr) {
            if (!authorized) {
                [slot signOutAndInvalidate:YES completion:^(__unused NSError *e) {
                    if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                        [self.runtimeProvider clearActiveIdentityWithError:nil];
                    }
                    if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                        NSString *status = PPProErrorLooksPermanentRevocation(authzErr)
                            ? PPProSessionStatusRevoked
                            : PPProSessionStatusVerificationRequired;
                        [self.runtimeProvider updateSessionStatusHint:status forUID:uid error:nil];
                    }
                    if (completion) completion(NO, YES, uid, authzErr);
                }];
                return;
            }
            if ([slot respondsToSelector:@selector(markProAccessVerified:forUID:)]) {
                [slot markProAccessVerified:YES forUID:uid];
            }
            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusActive forUID:uid error:nil];
            }
            self.activeSlot = slot;
            self.sessionGeneration += 1;
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidCommitNotification
                                                                object:self
                                                              userInfo:@{@"uid": uid}];
            [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification
                                                                object:self
                                                              userInfo:@{@"uid": uid}];
            if (completion) completion(YES, NO, uid, nil);
        };

        void (^runProviderCheck)(void) = ^{
            if ([self.runtimeProvider respondsToSelector:@selector(verifyProAccessForUID:slot:completion:)]) {
                [self.runtimeProvider verifyProAccessForUID:uid slot:slot completion:^(BOOL authorized, NSError * _Nullable authzErr) {
                    [self pp_dispatchMain:^{
                        finishAuthorizedCheck(authorized, authzErr);
                    }];
                }];
            } else {
                finishAuthorizedCheck(YES, nil);
            }
        };

        if ([slot respondsToSelector:@selector(validateSessionWithCompletion:)]) {
            [slot validateSessionWithCompletion:^(id _Nullable user, NSError * _Nullable valErr) {
                [self pp_dispatchMain:^{
                    if (!user || valErr) {
                        BOOL permanent = PPProErrorLooksPermanentRevocation(valErr);
                        if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                            [self.runtimeProvider updateSessionStatusHint:(permanent ? PPProSessionStatusExpired : PPProSessionStatusUnavailable)
                                                               forUID:uid
                                                                error:nil];
                        }
                        if (permanent) {
                            [slot signOutAndInvalidate:YES completion:nil];
                            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                                [self.runtimeProvider clearActiveIdentityWithError:nil];
                            }
                            if (completion) completion(NO, YES, uid, valErr);
                        } else {
                            // Offline / transient network error: do not silently admit or destroy slot, let Portal present retry/offline state.
                            if (completion) completion(NO, NO, uid, valErr);
                        }
                        return;
                    }
                    runProviderCheck();
                }];
            }];
        } else {
            runProviderCheck();
        }
    }];
}

- (void)signOutActiveAccountWithReason:(NSString *)reason
                            completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionBusy, nil));
            return;
        }
        NSString *currentUID = [self.activeUID copy];
        if (!currentUID.length) {
            [self suspendAndResetAccountStateForReason:reason ?: @"sign_out" completion:^(NSError * _Nullable error) {
                if (completion) completion(error == nil, error);
            }];
            return;
        }
        [self preflightAccountTransitionForTargetUID:nil reason:reason ?: @"sign_out" completion:^(BOOL allowed, __unused NSString * _Nullable blockReason, NSError * _Nullable preflightErr) {
            if (!allowed) {
                if (completion) completion(NO, preflightErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, nil));
                return;
            }
            NSError *journalErr = nil;
            NSUUID *ticket = [self.transitionCoordinator beginFromUID:currentUID
                                                            targetUID:@"__signed_out__"
                                                         sourceSlotID:self.activeSlot.slotID
                                                         targetSlotID:nil
                                                                 mode:@"sign_out"
                                                                error:&journalErr];
            if (!ticket) {
                if (completion) completion(NO, journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = ticket;
            [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:^(NSError * _Nullable writeError) {
                if (writeError) {
                    [self.transitionCoordinator cancelPreflight:ticket error:nil];
                    if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                    if (completion) completion(NO, writeError);
                    return;
                }
                [self pp_suspendTicket:ticket reason:reason ?: @"sign_out" completion:^(NSError * _Nullable suspendErr) {
                    if (suspendErr) {
                        if (completion) completion(NO, suspendErr);
                        return;
                    }
                    id<PPProSessionSlotHandle> currentSlot = self.activeSlot;
                    void (^afterSlotSignOut)(NSError * _Nullable) = ^(NSError * _Nullable slotErr) {
                        if (slotErr) {
                            [self.transitionCoordinator requireRecoveryForTicket:ticket];
                            [self pp_notifyRecoveryRequiredWithReason:@"active_signout_failed"];
                            if (completion) completion(NO, slotErr);
                            return;
                        }
                        self.activeSlot = nil;
                        [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defErr) {
                            if (defErr) {
                                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                                [self pp_notifyRecoveryRequiredWithReason:@"default_signout_failed"];
                                if (completion) completion(NO, defErr);
                                return;
                            }
                            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                                [self.runtimeProvider clearActiveIdentityWithError:nil];
                            }
                            if ([self.runtimeProvider respondsToSelector:@selector(updateSessionStatusHint:forUID:error:)]) {
                                [self.runtimeProvider updateSessionStatusHint:PPProSessionStatusVerificationRequired forUID:currentUID error:nil];
                            }
                            [self.transitionCoordinator requireRecoveryForTicket:ticket];
                            NSError *clearErr = nil;
                            BOOL cleared = [self.transitionCoordinator clearAfterVerifiedSignOut:&clearErr];
                            if (cleared) {
                                self.activeTransitionTicket = nil;
                                self.sessionGeneration += 1;
                                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidCommitNotification object:self];
                                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionAccountListDidChangeNotification object:self];
                            } else {
                                [self pp_notifyRecoveryRequiredWithReason:@"signout_journal_clear_failed"];
                            }
                            if (completion) completion(cleared, clearErr);
                        }];
                    };
                    if (currentSlot) {
                        [currentSlot signOutAndInvalidate:YES completion:afterSlotSignOut];
                    } else {
                        afterSlotSignOut(nil);
                    }
                }];
            }];
        }];
    }];
}

- (void)signOutAllAccountsWithReason:(NSString *)reason
                          completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self pp_dispatchMain:^{
        if (self.transitionCoordinator.phase == PPProTransitionRecoveryRequired) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionRequired, nil));
            return;
        }
        if (self.transitionCoordinator.phase != PPProTransitionIdle) {
            if (completion) completion(NO, PPCoordinatorError(PPProSessionCoordinatorErrorTransitionBusy, nil));
            return;
        }
        NSString *currentUID = [self.activeUID copy];
        [self preflightAccountTransitionForTargetUID:nil reason:reason ?: @"sign_out_all" completion:^(BOOL allowed, __unused NSString * _Nullable blockReason, NSError * _Nullable preflightErr) {
            if (!allowed) {
                if (completion) completion(NO, preflightErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorActiveWorkBlocked, nil));
                return;
            }
            NSError *journalErr = nil;
            NSUUID *ticket = [self.transitionCoordinator beginFromUID:currentUID
                                                            targetUID:@"__signed_out_all__"
                                                         sourceSlotID:self.activeSlot.slotID
                                                         targetSlotID:nil
                                                                 mode:@"sign_out_all"
                                                                error:&journalErr];
            if (!ticket) {
                if (completion) completion(NO, journalErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
                return;
            }
            self.activeTransitionTicket = ticket;

            void (^afterPendingWrites)(NSError * _Nullable) = ^(NSError * _Nullable writeError) {
                if (writeError) {
                    [self.transitionCoordinator cancelPreflight:ticket error:nil];
                    if ([self.activeTransitionTicket isEqual:ticket]) self.activeTransitionTicket = nil;
                    if (completion) completion(NO, writeError);
                    return;
                }
                [self pp_suspendTicket:ticket reason:reason ?: @"sign_out_all" completion:^(NSError * _Nullable suspendErr) {
                    if (suspendErr) {
                        if (completion) completion(NO, suspendErr);
                        return;
                    }
                    NSArray<NSDictionary<NSString *, NSString *> *> *records = [self.runtimeProvider rememberedRecordsWithError:nil] ?: @[];
                    NSMutableArray<NSDictionary<NSString *, NSString *> *> *queue = [records mutableCopy];
                    [self pp_tearDownQueuedAccounts:queue
                                         firstError:nil
                                      currentActive:self.activeSlot
                                     currentPending:self.pendingSlot
                                             ticket:ticket
                                         completion:completion];
                }];
            };

            [self pp_waitForPendingWritesOnCurrentSessionWithCompletion:afterPendingWrites];
        }];
    }];
}

- (void)pp_tearDownQueuedAccounts:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)queue
                       firstError:(nullable NSError *)firstError
                    currentActive:(nullable id<PPProSessionSlotHandle>)currentActive
                   currentPending:(nullable id<PPProSessionSlotHandle>)currentPending
                           ticket:(NSUUID *)ticket
                       completion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (queue.count == 0) {
        void (^finishDefault)(NSError * _Nullable, NSError * _Nullable) = ^(NSError * _Nullable priorErr, NSError * _Nullable defErr) {
            NSError *finalErr = priorErr ?: defErr;
            if (finalErr) {
                [self.transitionCoordinator requireRecoveryForTicket:ticket];
                [self pp_notifyRecoveryRequiredWithReason:@"sign_out_all_failed"];
                if (completion) completion(NO, finalErr);
                return;
            }
            self.activeSlot = nil;
            self.pendingSlot = nil;
            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                [self.runtimeProvider clearActiveIdentityWithError:nil];
            }
            [self.transitionCoordinator requireRecoveryForTicket:ticket];
            NSError *clearErr = nil;
            BOOL cleared = [self.transitionCoordinator clearAfterVerifiedSignOut:&clearErr];
            if (cleared) {
                self.activeTransitionTicket = nil;
                self.sessionGeneration += 1;
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidCommitNotification object:self];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionAccountListDidChangeNotification object:self];
            } else {
                [self pp_notifyRecoveryRequiredWithReason:@"sign_out_all_journal_clear_failed"];
            }
            if (completion) completion(cleared, clearErr);
        };

        __block NSError *accumulatedErr = firstError;
        if (currentActive) {
            [currentActive teardownSlotAppWithCompletion:^(__unused BOOL d, NSError * _Nullable activeTearErr) {
                if (!accumulatedErr && activeTearErr) accumulatedErr = activeTearErr;
                if (currentPending && currentPending != currentActive) {
                    [currentPending teardownSlotAppWithCompletion:^(__unused BOOL d2, NSError * _Nullable pErr) {
                        if (!accumulatedErr && pErr) accumulatedErr = pErr;
                        [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defErr) {
                            finishDefault(accumulatedErr, defErr);
                        }];
                    }];
                } else {
                    [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defErr) {
                        finishDefault(accumulatedErr, defErr);
                    }];
                }
            }];
        } else {
            [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defErr) {
                finishDefault(accumulatedErr, defErr);
            }];
        }
        return;
    }

    NSDictionary<NSString *, NSString *> *rec = queue.firstObject;
    [queue removeObjectAtIndex:0];
    NSString *recUID = rec[@"uid"];
    if (!recUID.length) {
        [self pp_tearDownQueuedAccounts:queue
                             firstError:firstError
                          currentActive:currentActive
                         currentPending:currentPending
                                 ticket:ticket
                             completion:completion];
        return;
    }
    id<PPProSessionSlotHandle> slot = [self pp_isMultiAccountRuntime]
        ? [self.runtimeProvider openSlotForRememberedUID:recUID error:nil]
        : nil;
    void (^afterSlotTear)(BOOL, NSError * _Nullable) = ^(BOOL deleted, NSError * _Nullable tearErr) {
        NSError *nextErr = firstError;
        if (tearErr || !deleted) {
            nextErr = nextErr ?: (tearErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorSignOutFailed, nil));
        } else {
            NSError *remErr = nil;
            if ([self.runtimeProvider removeRememberedUID:recUID error:&remErr]) {
                [PPProSessionCoordinator purgeScopedDefaultsForUID:recUID];
            } else {
                nextErr = nextErr ?: (remErr ?: PPCoordinatorError(PPProSessionCoordinatorErrorJournalFailure, nil));
            }
        }
        [self pp_tearDownQueuedAccounts:queue
                             firstError:nextErr
                          currentActive:currentActive
                         currentPending:currentPending
                                 ticket:ticket
                             completion:completion];
    };
    if (slot) {
        [slot teardownSlotAppWithCompletion:afterSlotTear];
    } else {
        afterSlotTear(YES, nil);
    }
}

#pragma mark - Recovery

- (void)pp_notifyRecoveryRequiredWithReason:(NSString *)reason {
    [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionRecoveryRequiredNotification
                                                        object:self
                                                      userInfo:@{@"reason": reason ?: @"recovery_required"}];
}

- (NSArray<id<PPProSessionSlotHandle>> *)pp_collectRecoverySlotsFromJournal {
    NSMutableArray<id<PPProSessionSlotHandle>> *slots = [NSMutableArray array];
    NSMutableSet<NSString *> *seenSlotIDs = [NSMutableSet set];

    void (^addSlot)(id<PPProSessionSlotHandle> _Nullable) = ^(id<PPProSessionSlotHandle> _Nullable s) {
        if (!s || !s.slotID) return;
        NSString *key = s.slotID.UUIDString;
        if ([seenSlotIDs containsObject:key]) return;
        [seenSlotIDs addObject:key];
        [slots addObject:s];
    };

    addSlot(self.pendingSlot);
    addSlot(self.activeSlot);

    NSDictionary *record = self.transitionCoordinator.persistedRecordSnapshot;
    if (record && [self pp_isMultiAccountRuntime]) {
        NSArray<NSString *> *slotKeys = @[@"provisionalSlotID", @"targetSlotID", @"sourceSlotID"];
        for (NSString *key in slotKeys) {
            NSString *uuidStr = [record[key] isKindOfClass:NSString.class] ? record[key] : nil;
            NSUUID *uuid = uuidStr.length ? [[NSUUID alloc] initWithUUIDString:uuidStr] : nil;
            if (uuid && ![seenSlotIDs containsObject:uuid.UUIDString]) {
                NSString *expected = nil;
                if ([key isEqualToString:@"sourceSlotID"]) {
                    expected = [record[@"sourceUID"] isKindOfClass:NSString.class] ? record[@"sourceUID"] : nil;
                } else if ([key isEqualToString:@"targetSlotID"]) {
                    NSString *t = [record[@"targetUID"] isKindOfClass:NSString.class] ? record[@"targetUID"] : nil;
                    if (t.length && ![t isEqualToString:PPProTransitionProvisionalTargetUID] && ![t hasPrefix:@"__"]) {
                        expected = t;
                    }
                }
                id<PPProSessionSlotHandle> opened = [self.runtimeProvider respondsToSelector:@selector(openSlotWithID:expectedUID:error:)]
                    ? [self.runtimeProvider openSlotWithID:uuid expectedUID:expected error:nil]
                    : nil;
                addSlot(opened);
            }
        }
        for (NSString *uidKey in @[@"sourceUID", @"targetUID"]) {
            NSString *uid = [record[uidKey] isKindOfClass:NSString.class] ? record[uidKey] : nil;
            if (uid.length > 0 && ![uid isEqualToString:PPProTransitionProvisionalTargetUID] && ![uid hasPrefix:@"__"]) {
                addSlot([self.runtimeProvider openSlotForRememberedUID:uid error:nil]);
            }
        }
    }
    return [slots copy];
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

        NSMutableArray<id<PPProSessionSlotHandle>> *slots = [[self pp_collectRecoverySlotsFromJournal] mutableCopy];
        [self pp_processRecoverySlots:slots completion:completion];
    }];
}

- (void)pp_processRecoverySlots:(NSMutableArray<id<PPProSessionSlotHandle>> *)slots
                     completion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (slots.count == 0) {
        [self.runtimeProvider signOutDefaultAuthWithCompletion:^(NSError * _Nullable defaultErr) {
            if (defaultErr) {
                [self pp_notifyRecoveryRequiredWithReason:@"recovery_default_signout_failed"];
                if (completion) completion(NO, defaultErr);
                return;
            }
            self.pendingSlot = nil;
            self.activeSlot = nil;
            if ([self.runtimeProvider respondsToSelector:@selector(clearActiveIdentityWithError:)]) {
                [self.runtimeProvider clearActiveIdentityWithError:nil];
            }
            NSError *clearErr = nil;
            BOOL cleared = [self.transitionCoordinator clearAfterVerifiedSignOut:&clearErr];
            if (cleared) {
                self.activeTransitionTicket = nil;
                self.sessionGeneration += 1;
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionDidChangeActiveRuntimeNotification object:self];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionTransitionDidRollbackNotification object:self];
            } else {
                [self pp_notifyRecoveryRequiredWithReason:@"recovery_journal_clear_failed"];
            }
            if (completion) completion(cleared, clearErr);
        }];
        return;
    }

    id<PPProSessionSlotHandle> slot = slots.firstObject;
    [slots removeObjectAtIndex:0];
    [slot signOutAndInvalidate:YES completion:^(NSError * _Nullable slotSignOutErr) {
        if (slotSignOutErr) {
            [self pp_notifyRecoveryRequiredWithReason:@"recovery_slot_signout_failed"];
            if (completion) completion(NO, slotSignOutErr);
            return;
        }
        [slot teardownSlotAppWithCompletion:^(__unused BOOL deleted, __unused NSError *teardownErr) {
            [self pp_processRecoverySlots:slots completion:completion];
        }];
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
        id<PPProSessionSlotHandle> slot = [self pp_isMultiAccountRuntime]
            ? [self.runtimeProvider openSlotForRememberedUID:safeUID error:nil]
            : nil;
        void (^finishRemoval)(void) = ^{
            NSError *remErr = nil;
            BOOL removed = [self.runtimeProvider removeRememberedUID:safeUID error:&remErr];
            if (removed) {
                [PPProSessionCoordinator purgeScopedDefaultsForUID:safeUID];
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProSessionAccountListDidChangeNotification
                                                                    object:self
                                                                  userInfo:@{@"removedUID": safeUID}];
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
    NSString *bookingsKey = [NSString stringWithFormat:@"pp_provider_service_bookings_v1_%@", trimmedUID];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary<NSString *, id> *all = defaults.dictionaryRepresentation;
    for (NSString *key in all) {
        if ([key hasPrefix:scopedPrefix] ||
            [key hasPrefix:draftPrefix] ||
            [key hasPrefix:quickActionPrefix] ||
            [key isEqualToString:deliveryCompanyKey] ||
            [key isEqualToString:bookingsKey]) {
            [defaults removeObjectForKey:key];
        }
    }

    // Remove per-account cached profile archive from Library/Caches (`UserModel_<uid>.dat`)
    // and Application Support (`PurePetsUserCache/<uid>.archive` and `<uid>.age`).
    NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (cachesDir.length > 0) {
        NSString *modelCache = [cachesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"UserModel_%@.dat", sanitizedUID]];
        [[NSFileManager defaultManager] removeItemAtPath:modelCache error:nil];
        NSString *legacyCacheArchive = [[cachesDir stringByAppendingPathComponent:@"PurePetsUserCache"]
                                        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.archive", sanitizedUID]];
        [[NSFileManager defaultManager] removeItemAtPath:legacyCacheArchive error:nil];
    }
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    if (appSupportDir.length > 0) {
        NSString *userCacheDir = [appSupportDir stringByAppendingPathComponent:@"PurePetsUserCache"];
        for (NSString *candidate in @[trimmedUID, sanitizedUID]) {
            if (!candidate.length) continue;
            NSString *userArchive = [userCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.archive", candidate]];
            NSString *userAge = [userCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.age", candidate]];
            [[NSFileManager defaultManager] removeItemAtPath:userArchive error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:userAge error:nil];
        }
    }
}

- (void)purgeSharedMediaCaches {
#if !defined(PPPRO_UNIT_TEST_STUB_FIREBASE)
    [[SDWebImageManager sharedManager] cancelAll];
    [[SDImageCache sharedImageCache] clearMemory];
    [[YYCache cacheWithName:@"PPImageCache"].memoryCache removeAllObjects];
    [[YYCache cacheWithName:@"LottieJSONCache"].memoryCache removeAllObjects];
    [[YYCache cacheWithName:@"PPImageCache"].diskCache removeAllObjects];
    NSString *tempDir = NSTemporaryDirectory();
    if (tempDir.length > 0) {
        NSArray<NSString *> *tempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempDir error:nil] ?: @[];
        for (NSString *file in tempFiles) {
            if ([file hasPrefix:@"pp_pro_voice_"] && [file hasSuffix:@".m4a"]) {
                [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:file] error:nil];
            }
        }
    }
#endif
}

@end
