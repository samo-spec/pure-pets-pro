#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProAccountTransitionCoordinator.h"
#import "../PurePetsPro/AdminCore/Models/PPProRememberedAccountStore.h"
#import "../PurePetsPro/AdminCore/Security/PPProSessionCoordinator.h"
#import "../PurePetsPro/AdminCore/Models/PPProSessionFence.h"

static void check(BOOL ok, const char *name) {
    if (!ok) {
        fprintf(stderr, "FAIL %s\n", name);
        exit(1);
    }
    printf("PASS %s\n", name);
}

static void pumpMainLoopUntil(BOOL (^predicate)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
    while (!predicate() && [deadline timeIntervalSinceNow] > 0) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
    }
}

@interface PPMemoryTransitionJournal : NSObject <PPProTransitionJournal>
@property (nonatomic, copy, nullable) NSDictionary *record;
@property (nonatomic, assign) BOOL failWrites;
@property (nonatomic, assign) BOOL failReads;
@end

@implementation PPMemoryTransitionJournal
- (nullable NSDictionary *)readRecord:(NSError **)error {
    if (self.failReads) {
        if (error) *error = [NSError errorWithDomain:@"TestJournal" code:1 userInfo:nil];
        return nil;
    }
    return self.record;
}
- (BOOL)writeRecord:(nullable NSDictionary *)record error:(NSError **)error {
    if (self.failWrites) {
        if (error) *error = [NSError errorWithDomain:@"TestJournal" code:2 userInfo:nil];
        return NO;
    }
    self.record = record;
    return YES;
}
@end

@interface PPMockSlotHandle : NSObject <PPProSessionSlotHandle>
@property (nonatomic, strong) NSUUID *slotID;
@property (nonatomic, copy, nullable) NSString *expectedUID;
@property (nonatomic, copy, nullable) NSString *currentUID;
@property (nonatomic, assign) BOOL isAuthorizedSession;
@property (nonatomic, assign) BOOL isInvalidated;
@property (nonatomic, assign) BOOL failPendingWrites;
@property (nonatomic, assign) BOOL failSignOut;
@property (nonatomic, assign) BOOL tornDown;
@end

@implementation PPMockSlotHandle
- (instancetype)initWithSlotID:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID {
    self = [super init];
    if (self) {
        _slotID = slotID ?: [NSUUID UUID];
        _expectedUID = [expectedUID copy];
    }
    return self;
}
- (void)waitForPendingWritesWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.failPendingWrites) {
        if (completion) completion([NSError errorWithDomain:@"TestSlot" code:10 userInfo:@{NSLocalizedDescriptionKey: @"pending writes flush failed"}]);
        return;
    }
    if (completion) completion(nil);
}
- (void)signOutAndInvalidate:(BOOL)invalidate completion:(void (^ _Nullable)(NSError * _Nullable))completion {
    if (self.failSignOut) {
        if (completion) completion([NSError errorWithDomain:@"TestSlot" code:11 userInfo:@{NSLocalizedDescriptionKey: @"slot sign-out failed"}]);
        return;
    }
    self.currentUID = nil;
    self.isAuthorizedSession = NO;
    if (invalidate) self.isInvalidated = YES;
    if (completion) completion(nil);
}
- (void)teardownSlotAppWithCompletion:(void (^ _Nullable)(BOOL, NSError * _Nullable))completion {
    if (self.failPendingWrites) {
        if (completion) completion(NO, [NSError errorWithDomain:@"TestSlot" code:12 userInfo:nil]);
        return;
    }
    if (self.failSignOut) {
        if (completion) completion(NO, [NSError errorWithDomain:@"TestSlot" code:13 userInfo:nil]);
        return;
    }
    self.currentUID = nil;
    self.isAuthorizedSession = NO;
    self.isInvalidated = YES;
    self.tornDown = YES;
    if (completion) completion(YES, nil);
}
@end

@interface PPMockRuntimeProvider : NSObject <PPProSessionRuntimeProvider>
@property (nonatomic, assign) BOOL multiAccountEnabled;
@property (nonatomic, copy, nullable) NSString *defaultUID;
@property (nonatomic, assign) BOOL failDefaultPendingWrites;
@property (nonatomic, assign) BOOL failDefaultSignOut;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSString *> *> *records;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPMockSlotHandle *> *slotsByUUID;
@end

@implementation PPMockRuntimeProvider
- (instancetype)init {
    self = [super init];
    if (self) {
        _multiAccountEnabled = YES;
        _records = [NSMutableArray array];
        _slotsByUUID = [NSMutableDictionary dictionary];
    }
    return self;
}
- (BOOL)isMultiAccountEnabled { return self.multiAccountEnabled; }
- (nullable NSString *)defaultAuthCurrentUID { return self.defaultUID; }
- (void)waitForDefaultPendingWritesWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.failDefaultPendingWrites) {
        if (completion) completion([NSError errorWithDomain:@"TestProvider" code:20 userInfo:nil]);
        return;
    }
    if (completion) completion(nil);
}
- (void)signOutDefaultAuthWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.failDefaultSignOut) {
        if (completion) completion([NSError errorWithDomain:@"TestProvider" code:21 userInfo:@{NSLocalizedDescriptionKey: @"default sign-out failed"}]);
        return;
    }
    self.defaultUID = nil;
    if (completion) completion(nil);
}
- (nullable id<PPProSessionSlotHandle>)openSlotForRememberedUID:(NSString *)uid error:(NSError **)error {
    (void)error;
    for (NSDictionary *rec in self.records) {
        if ([rec[@"uid"] isEqualToString:uid] && rec[@"slotID"]) {
            PPMockSlotHandle *existing = self.slotsByUUID[rec[@"slotID"]];
            if (existing && !existing.isInvalidated) return existing;
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:rec[@"slotID"]] ?: [NSUUID UUID];
            PPMockSlotHandle *reopened = [[PPMockSlotHandle alloc] initWithSlotID:uuid expectedUID:uid];
            self.slotsByUUID[uuid.UUIDString] = reopened;
            return reopened;
        }
    }
    return [self createProvisionalSlotWithError:error];
}
- (nullable id<PPProSessionSlotHandle>)createProvisionalSlotWithError:(NSError **)error {
    (void)error;
    NSUUID *uuid = [NSUUID UUID];
    PPMockSlotHandle *slot = [[PPMockSlotHandle alloc] initWithSlotID:uuid expectedUID:nil];
    self.slotsByUUID[uuid.UUIDString] = slot;
    return slot;
}
- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedRecordsWithError:(NSError **)error {
    (void)error;
    return [self.records copy];
}
- (BOOL)rememberUID:(NSString *)uid
        maskedLabel:(NSString *)label
             method:(NSString *)method
             slotID:(nullable NSUUID *)slotID
              error:(NSError **)error {
    (void)error;
    NSArray *updated = [PPProRememberedAccountStore recordsByRememberingUID:uid
                                                                     label:label
                                                                    method:method
                                                                    slotID:slotID
                                                                 inRecords:self.records];
    self.records = [updated mutableCopy];
    return YES;
}
- (BOOL)removeRememberedUID:(NSString *)uid error:(NSError **)error {
    (void)error;
    self.records = [[PPProRememberedAccountStore recordsByRemovingUID:uid inRecords:self.records] mutableCopy];
    return YES;
}
@end

int main(void) {
    @autoreleasepool {
        PPMemoryTransitionJournal *journal = [PPMemoryTransitionJournal new];
        PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
        PPProSessionFence *fence = [[PPProSessionFence alloc] init];
        PPMockRuntimeProvider *provider = [PPMockRuntimeProvider new];
        PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc
                                                                                                  fence:fence
                                                                                        runtimeProvider:provider];

        NSMutableArray<NSString *> *events = [NSMutableArray array];
        __block NSInteger teardownCount = 0;
        __block BOOL blockSwitch = NO;

        [coord registerNotificationBarrierHandler:^(NSString *reason, void (^done)(NSError * _Nullable)) {
            [events addObject:[NSString stringWithFormat:@"barrier:%@", reason]];
            if (done) done(nil);
        }];
        [coord registerSessionTeardownHandler:^(NSString *reason) {
            teardownCount += 1;
            [events addObject:[NSString stringWithFormat:@"teardown:%@", reason]];
        } forKey:@"test_teardown"];
        [coord registerActiveWorkBlocker:^BOOL(NSString * _Nullable * _Nullable outReason) {
            if (blockSwitch) {
                if (outReason) *outReason = @"Active delivery in progress";
                return YES;
            }
            return NO;
        } forKey:@"cockpit"];

        // 1. Provisional sign-in for Account A (fresh, no source UID)
        __block BOOL stepDone = NO;
        __block BOOL stepAllowed = NO;
        __block NSUUID *ticketA = nil;
        __block PPMockSlotHandle *slotA = nil;
        __block NSError *stepErr = nil;
        [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID *t, id<PPProSessionSlotHandle> s, NSError *err) {
            stepAllowed = allowed;
            ticketA = t;
            slotA = (PPMockSlotHandle *)s;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(stepAllowed && slotA != nil && stepErr == nil, "provisional slot A created when idle");

        slotA.currentUID = @"UID_A";
        slotA.isAuthorizedSession = YES;
        stepDone = NO;
        __block BOOL installedA = NO;
        [coord completeAuthenticationForTicket:ticketA
                               provisionalSlot:slotA
                              authenticatedUID:@"UID_A"
                                   expectedUID:nil
                                   maskedLabel:@"•••• 1111"
                                        method:@"phone"
                                    completion:^(BOOL installed, NSError *err) {
            installedA = installed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(installedA && [coord.activeUID isEqualToString:@"UID_A"] && tc.phase == PPProTransitionIdle && journal.record == nil,
              "account A installed cleanly and journal committed");

        NSUUID *epochA = [fence captureForUID:@"UID_A" activeUID:coord.activeUID identity:coord.activeUID];
        check([fence accepts:epochA requestedUID:@"UID_A" activeUID:coord.activeUID identity:coord.activeUID],
              "fence accepts captured epoch for active session A");

        // 2. Active-work blocker prevents switch cleanly without tearing down or locking recovery
        blockSwitch = YES;
        stepDone = NO;
        [coord beginRememberedAccountSignInOrSwitchToUID:@"UID_B" fromUID:@"UID_A" completion:^(BOOL allowed, NSUUID *t, id<PPProSessionSlotHandle> s, NSError *err) {
            stepAllowed = allowed;
            ticketA = t;
            stepErr = err;
            (void)s;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(!stepAllowed && stepErr.code == PPProSessionCoordinatorErrorActiveWorkBlocked && tc.phase == PPProTransitionIdle && teardownCount == 0 && [coord.activeUID isEqualToString:@"UID_A"],
              "active-work blocker stops switch cleanly and preserves active session A");
        blockSwitch = NO;

        // 3. Pending-writes failure cancels preflight cleanly back to Idle
        slotA.failPendingWrites = YES;
        stepDone = NO;
        [coord beginRememberedAccountSignInOrSwitchToUID:@"UID_B" fromUID:@"UID_A" completion:^(BOOL allowed, NSUUID *t, id<PPProSessionSlotHandle> s, NSError *err) {
            stepAllowed = allowed;
            ticketA = t;
            stepErr = err;
            (void)s;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(!stepAllowed && stepErr.code == PPProSessionCoordinatorErrorPendingWritesUnconfirmed && tc.phase == PPProTransitionIdle && journal.record == nil && [coord.activeUID isEqualToString:@"UID_A"],
              "pending-writes failure cancels preflight back to idle without session teardown");
        slotA.failPendingWrites = NO;

        // 4. Switch A -> B: barrier runs BEFORE teardown, fence invalidates, B installs
        [events removeAllObjects];
        stepDone = NO;
        __block NSUUID *ticketB = nil;
        __block PPMockSlotHandle *slotB = nil;
        [coord beginRememberedAccountSignInOrSwitchToUID:@"UID_B" fromUID:@"UID_A" completion:^(BOOL allowed, NSUUID *t, id<PPProSessionSlotHandle> s, NSError *err) {
            stepAllowed = allowed;
            ticketB = t;
            slotB = (PPMockSlotHandle *)s;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(stepAllowed && ticketB != nil && slotB != nil && slotB != slotA,
              "remembered switch opens separate isolated slot B");
        check(events.count >= 2 && [events[0] isEqualToString:@"barrier:account_switch"] && [events[1] isEqualToString:@"teardown:account_switch"],
              "notification deactivation barrier runs before session teardown");
        check(![fence accepts:epochA requestedUID:@"UID_A" activeUID:coord.activeUID identity:coord.activeUID],
              "teardown invalidates old A epoch immediately");
        check(tc.phase == PPProTransitionAuthenticating && coord.activeUID == nil,
              "activeUID is hidden while Authenticating slot B");

        slotB.currentUID = @"UID_B";
        slotB.isAuthorizedSession = YES;
        stepDone = NO;
        __block BOOL installedB = NO;
        [coord completeAuthenticationForTicket:ticketB
                               provisionalSlot:slotB
                              authenticatedUID:@"UID_B"
                                   expectedUID:@"UID_B"
                                   maskedLabel:@"b•••@example.invalid"
                                        method:@"google.com"
                                    completion:^(BOOL installed, NSError *err) {
            installedB = installed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(installedB && [coord.activeUID isEqualToString:@"UID_B"] && tc.phase == PPProTransitionIdle,
              "slot B completes authentication and becomes active session");

        // 5. Switch B -> wrong UID when sign-out fails -> locks durable RecoveryRequired across restart
        stepDone = NO;
        __block NSUUID *ticketBack = nil;
        __block PPMockSlotHandle *slotMismatch = nil;
        [coord beginRememberedAccountSignInOrSwitchToUID:@"UID_A" fromUID:@"UID_B" completion:^(BOOL allowed, NSUUID *t, id<PPProSessionSlotHandle> s, NSError *err) {
            stepAllowed = allowed;
            ticketBack = t;
            slotMismatch = (PPMockSlotHandle *)s;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(stepAllowed && slotMismatch == slotA,
              "switching back to A reopens A's remembered slot");

        slotMismatch.currentUID = @"UID_WRONG";
        slotMismatch.isAuthorizedSession = YES;
        slotMismatch.failSignOut = YES;
        stepDone = NO;
        __block BOOL installedWrong = YES;
        [coord completeAuthenticationForTicket:ticketBack
                               provisionalSlot:slotMismatch
                              authenticatedUID:@"UID_WRONG"
                                   expectedUID:@"UID_A"
                                   maskedLabel:@"w•••@example.invalid"
                                        method:@"apple.com"
                                    completion:^(BOOL installed, NSError *err) {
            installedWrong = installed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(!installedWrong && coord.requiresTransitionRecovery && journal.record != nil && coord.activeUID == nil,
              "wrong-account sign-out failure locks durable RecoveryRequired and hides activeUID");

        // Simulated restart with same persisted journal while sign-out still fails
        PPProAccountTransitionCoordinator *restartedTC = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
        PPProSessionCoordinator *restartedCoord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:restartedTC
                                                                                                           fence:[PPProSessionFence new]
                                                                                                 runtimeProvider:provider];
        check(restartedCoord.requiresTransitionRecovery, "cold launch preserves RecoveryRequired lock from journal");
        provider.defaultUID = @"UID_WRONG";
        provider.failDefaultSignOut = YES;
        stepDone = NO;
        __block BOOL recRequired = NO;
        __block BOOL recCleared = YES;
        [restartedCoord performColdStartRecoveryCheckWithCompletion:^(BOOL recoveryRequired, BOOL cleared, NSError *err) {
            recRequired = recoveryRequired;
            recCleared = cleared;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(recRequired && !recCleared && restartedCoord.requiresTransitionRecovery,
              "failed cold-start sign-out remains locked in RecoveryRequired");

        // Retry after clearing failure unlocks back to Idle
        provider.failDefaultSignOut = NO;
        slotMismatch.failSignOut = NO;
        stepDone = NO;
        [restartedCoord retryTransitionRecoverySignOutWithCompletion:^(BOOL cleared, NSError *err) {
            recCleared = cleared;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(recCleared && !stepErr && !restartedCoord.requiresTransitionRecovery && journal.record == nil,
              "verified recovery sign-out clears journal and unlocks coordinator");

        // Reinstall A for removal + scoped defaults tests
        slotA.isInvalidated = NO;
        slotA.currentUID = @"UID_A";
        slotA.isAuthorizedSession = YES;
        stepDone = NO;
        [restartedCoord completeAuthenticationForTicket:nil
                                        provisionalSlot:slotA
                                       authenticatedUID:@"UID_A"
                                            expectedUID:nil
                                            maskedLabel:@"•••• 1111"
                                                 method:@"phone"
                                             completion:^(BOOL installed, NSError *err) {
            installedA = installed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(installedA && [restartedCoord.activeUID isEqualToString:@"UID_A"], "reinstalled A as active");

        // 6. Account removal refuses active UID, purges inactive UID + scoped defaults
        NSString *keyA = [PPProSessionCoordinator scopedDefaultsKey:@"pp_provider_schedule_matrix_v1" forUID:@"UID_A"];
        NSString *keyB = [PPProSessionCoordinator scopedDefaultsKey:@"pp_provider_schedule_matrix_v1" forUID:@"UID_B"];
        [NSUserDefaults.standardUserDefaults setObject:@[@"A"] forKey:keyA];
        [NSUserDefaults.standardUserDefaults setObject:@[@"B"] forKey:keyB];

        stepDone = NO;
        __block BOOL removedA = YES;
        [restartedCoord removeRememberedAccountWithUID:@"UID_A" completion:^(BOOL removed, NSError *err) {
            removedA = removed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(!removedA && stepErr.code == PPProSessionCoordinatorErrorAccountActive,
              "cannot remove currently active account before signing out");

        stepDone = NO;
        __block BOOL removedB = NO;
        [restartedCoord removeRememberedAccountWithUID:@"UID_B" completion:^(BOOL removed, NSError *err) {
            removedB = removed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(removedB && slotB.tornDown && [NSUserDefaults.standardUserDefaults objectForKey:keyB] == nil && [NSUserDefaults.standardUserDefaults objectForKey:keyA] != nil,
              "inactive account removal tears down slot and purges only that account's scoped defaults");

        [NSUserDefaults.standardUserDefaults removeObjectForKey:keyA];

        // 7. Slot replacement pending-writes guard fails closed into RecoveryRequired
        NSUUID *replacementUUID = [NSUUID UUID];
        PPMockSlotHandle *slotNewA = [[PPMockSlotHandle alloc] initWithSlotID:replacementUUID expectedUID:@"UID_A"];
        slotNewA.currentUID = @"UID_A";
        slotNewA.isAuthorizedSession = YES;
        slotA.failPendingWrites = YES; // Prior remembered slot for UID_A has unconfirmed writes
        stepDone = NO;
        __block BOOL replacementInstalled = YES;
        [restartedCoord completeAuthenticationForTicket:nil
                                        provisionalSlot:slotNewA
                                       authenticatedUID:@"UID_A"
                                            expectedUID:nil
                                            maskedLabel:@"•••• 1111"
                                                 method:@"phone"
                                             completion:^(BOOL installed, NSError *err) {
            replacementInstalled = installed;
            stepErr = err;
            stepDone = YES;
        }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        check(!replacementInstalled && restartedCoord.requiresTransitionRecovery && journal.record != nil,
              "slot replacement with unconfirmed prior pending writes fails closed without erasing prior writes");

        // Recover & verify external sign-out clears active slot
        slotA.failPendingWrites = NO;
        stepDone = NO;
        [restartedCoord retryTransitionRecoverySignOutWithCompletion:^(__unused BOOL c, __unused NSError *e) { stepDone = YES; }];
        pumpMainLoopUntil(^BOOL{ return stepDone; });
        [restartedCoord completeExternalSignOutWithUID:@"UID_A"];
        check(restartedCoord.activeSlot == nil && restartedCoord.activeUID == nil,
              "external sign-out clears active slot and activeUID");
    }
    return 0;
}
