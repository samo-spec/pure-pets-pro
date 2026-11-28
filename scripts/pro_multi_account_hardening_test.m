#import <Foundation/Foundation.h>
#import "../PurePetsPro/AdminCore/Models/PPProSessionFence.h"
#import "../PurePetsPro/AdminCore/Models/PPProRememberedAccountStore.h"
#import "../PurePetsPro/AdminCore/Models/PPProAccountTransitionCoordinator.h"
#import "../PurePetsPro/AdminCore/Security/PPProSessionCoordinator.h"

static void check(BOOL condition, const char *name) {
    if (!condition) {
        fprintf(stderr, "FAIL %s\n", name);
        exit(1);
    }
    printf("PASS %s\n", name);
}

@interface PPTestJournal : NSObject <PPProTransitionJournal>
@property (nonatomic, copy, nullable) NSDictionary *stored;
@property (nonatomic) BOOL failReads;
@property (nonatomic) BOOL failWrites;
@end

@implementation PPTestJournal
- (nullable NSDictionary *)readRecord:(NSError * _Nullable * _Nullable)error {
    if (self.failReads) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:501 userInfo:nil];
        return nil;
    }
    return self.stored;
}
- (BOOL)writeRecord:(nullable NSDictionary *)record error:(NSError * _Nullable * _Nullable)error {
    if (self.failWrites) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:502 userInfo:nil];
        return NO;
    }
    self.stored = record ? [record copy] : nil;
    return YES;
}
@end

@interface PPTestSlot : NSObject <PPProSessionSlotHandle>
@property (nonatomic, strong) NSUUID *slotID;
@property (nonatomic, copy, nullable) NSString *expectedUID;
@property (nonatomic, copy, nullable) NSString *currentUID;
@property (nonatomic) BOOL isAuthenticatedSession;
@property (nonatomic) BOOL isAuthorizedSession;
@property (nonatomic) BOOL isInvalidated;
@property (nonatomic) BOOL failPendingWrites;
@property (nonatomic) BOOL failSignOut;
@property (nonatomic) BOOL failTeardown;
@property (nonatomic) BOOL failOnDuplicateTeardown;
@property (nonatomic) NSUInteger teardownCount;
@property (nonatomic) BOOL teardownCalled;
@property (nonatomic) BOOL signOutCalled;
@property (nonatomic) NSUInteger slotGeneration;
@end

@implementation PPTestSlot
- (void)waitForPendingWritesWithCompletion:(void (^)(NSError * _Nullable error))completion {
    if (self.failPendingWrites) {
        if (completion) completion([NSError errorWithDomain:@"Test" code:601 userInfo:nil]);
        return;
    }
    if (completion) completion(nil);
}
- (void)signOutAndInvalidate:(BOOL)invalidate completion:(void (^ _Nullable)(NSError * _Nullable error))completion {
    self.signOutCalled = YES;
    if (self.failSignOut) {
        if (completion) completion([NSError errorWithDomain:@"Test" code:602 userInfo:nil]);
        return;
    }
    self.currentUID = nil;
    self.isAuthenticatedSession = NO;
    self.isAuthorizedSession = NO;
    if (invalidate) self.isInvalidated = YES;
    if (completion) completion(nil);
}
- (void)teardownSlotAppWithCompletion:(void (^ _Nullable)(BOOL deleted, NSError * _Nullable error))completion {
    self.teardownCalled = YES;
    if (self.failTeardown) {
        if (completion) completion(NO, [NSError errorWithDomain:@"Test" code:603 userInfo:nil]);
        return;
    }
    if (self.failOnDuplicateTeardown && self.teardownCount > 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"PPProFirebaseAccountRuntime" code:8 userInfo:nil]);
        return;
    }
    self.teardownCount += 1;
    self.currentUID = nil;
    self.isAuthenticatedSession = NO;
    self.isAuthorizedSession = NO;
    self.isInvalidated = YES;
    if (completion) completion(YES, nil);
}
- (void)markProAccessVerified:(BOOL)verified forUID:(nullable NSString *)uid {
    BOOL matches = self.expectedUID.length == 0 || [uid isEqualToString:self.expectedUID];
    self.isAuthenticatedSession = matches && self.currentUID.length > 0 && !self.isInvalidated;
    self.isAuthorizedSession = verified && self.isAuthenticatedSession;
}
@end

@interface PPTestProvider : NSObject <PPProSessionRuntimeProvider>
@property (nonatomic) BOOL multiAccountEnabled;
@property (nonatomic, copy, nullable) NSString *defaultUID;
@property (nonatomic) BOOL failDefaultSignOut;
@property (nonatomic) BOOL failRememberWrite;
@property (nonatomic) BOOL failRemoveWrite;
@property (nonatomic) BOOL failSlotCreation;
@property (nonatomic) BOOL proAccessAllowed;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSString *> *> *records;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPTestSlot *> *slotsByID;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *activeHint;
@property (nonatomic) BOOL failActiveHintWrite;
@end

@implementation PPTestProvider
- (instancetype)init {
    if ((self = [super init])) {
        _multiAccountEnabled = YES;
        _proAccessAllowed = YES;
        _records = [NSMutableArray array];
        _slotsByID = [NSMutableDictionary dictionary];
    }
    return self;
}
- (BOOL)isMultiAccountEnabled { return self.multiAccountEnabled; }
- (nullable NSString *)defaultAuthCurrentUID { return self.defaultUID; }
- (void)waitForDefaultPendingWritesWithCompletion:(void (^)(NSError * _Nullable error))completion {
    if (completion) completion(nil);
}
- (void)signOutDefaultAuthWithCompletion:(void (^)(NSError * _Nullable error))completion {
    if (self.failDefaultSignOut) {
        if (completion) completion([NSError errorWithDomain:@"Test" code:701 userInfo:nil]);
        return;
    }
    self.defaultUID = nil;
    if (completion) completion(nil);
}
- (nullable id<PPProSessionSlotHandle>)openSlotWithID:(NSUUID *)slotID expectedUID:(nullable NSString *)expectedUID error:(NSError **)error {
    if (!slotID) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:702 userInfo:nil];
        return nil;
    }
    PPTestSlot *slot = self.slotsByID[slotID.UUIDString];
    if (!slot) {
        slot = [PPTestSlot new];
        slot.slotID = slotID;
        slot.expectedUID = expectedUID;
        slot.currentUID = expectedUID;
        slot.isAuthenticatedSession = expectedUID.length > 0;
        slot.isAuthorizedSession = expectedUID.length > 0;
        slot.slotGeneration = self.slotsByID.count + 1;
        self.slotsByID[slotID.UUIDString] = slot;
    } else if (slot.isInvalidated) {
        PPTestSlot *fresh = [PPTestSlot new];
        fresh.slotID = slotID;
        fresh.expectedUID = expectedUID;
        fresh.currentUID = slot.signOutCalled ? nil : (expectedUID ?: slot.currentUID);
        fresh.isAuthenticatedSession = fresh.currentUID.length > 0;
        fresh.isAuthorizedSession = fresh.currentUID.length > 0;
        fresh.slotGeneration = slot.slotGeneration + 1;
        self.slotsByID[slotID.UUIDString] = fresh;
        slot = fresh;
    }
    return slot;
}
- (nullable id<PPProSessionSlotHandle>)openSlotForRememberedUID:(NSString *)uid error:(NSError **)error {
    for (NSDictionary *rec in self.records) {
        if ([rec[@"uid"] isEqualToString:uid] && rec[@"slotID"]) {
            NSUUID *sid = [[NSUUID alloc] initWithUUIDString:rec[@"slotID"]];
            return [self openSlotWithID:sid expectedUID:uid error:error];
        }
    }
    if (error) *error = [NSError errorWithDomain:@"Test" code:703 userInfo:nil];
    return nil;
}
- (nullable id<PPProSessionSlotHandle>)createProvisionalSlotWithError:(NSError **)error {
    if (self.failSlotCreation) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:704 userInfo:nil];
        return nil;
    }
    PPTestSlot *slot = [PPTestSlot new];
    slot.slotID = [NSUUID UUID];
    slot.slotGeneration = self.slotsByID.count + 1;
    self.slotsByID[slot.slotID.UUIDString] = slot;
    return slot;
}
- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)rememberedRecordsWithError:(NSError **)error {
    return [self.records copy];
}
- (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method slotID:(nullable NSUUID *)slotID error:(NSError **)error {
    if (self.failRememberWrite) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:705 userInfo:nil];
        return NO;
    }
    self.records = [[PPProRememberedAccountStore recordsByRememberingUID:uid label:label method:method slotID:slotID inRecords:self.records] mutableCopy];
    return YES;
}
- (BOOL)removeRememberedUID:(NSString *)uid error:(NSError **)error {
    if (self.failRemoveWrite) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:706 userInfo:nil];
        return NO;
    }
    self.records = [[PPProRememberedAccountStore recordsByRemovingUID:uid inRecords:self.records] mutableCopy];
    if ([self.activeHint[@"uid"] isEqualToString:uid]) {
        self.activeHint = nil;
    }
    return YES;
}
- (nullable NSDictionary<NSString *, NSString *> *)activeIdentityHintWithError:(NSError **)error {
    return [self.activeHint copy];
}
- (BOOL)setActiveIdentityUID:(NSString *)uid slotID:(nullable NSUUID *)slotID error:(NSError **)error {
    if (self.failActiveHintWrite) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:707 userInfo:nil];
        return NO;
    }
    if (!uid.length) {
        if (error) *error = [NSError errorWithDomain:@"Test" code:708 userInfo:nil];
        return NO;
    }
    self.activeHint = @{@"uid": uid, @"slotID": slotID.UUIDString ?: @""};
    return YES;
}
- (BOOL)clearActiveIdentityWithError:(NSError **)error {
    self.activeHint = nil;
    return YES;
}
- (BOOL)updateSessionStatusHint:(NSString *)status forUID:(NSString *)uid error:(NSError **)error {
    self.records = [[PPProRememberedAccountStore recordsByUpdatingSessionStatus:status verifiedAt:nil forUID:uid inRecords:self.records] mutableCopy];
    return YES;
}
- (void)verifyProAccessForUID:(NSString *)uid slot:(id<PPProSessionSlotHandle>)slot completion:(void (^)(BOOL authorized, NSError * _Nullable error))completion {
    if (!self.proAccessAllowed) {
        if (completion) completion(NO, [NSError errorWithDomain:@"Test" code:403 userInfo:@{NSLocalizedDescriptionKey: @"Pro access denied"}]);
        return;
    }
    if (completion) completion(YES, nil);
}
@end

int main(void) {
    @autoreleasepool {
        // 1. P0-06: Journal ticket MUST be created BEFORE creating provisional slot
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc fence:[PPProSessionFence new] runtimeProvider:provider];
            provider.failSlotCreation = YES;
            __block BOOL gotAllowed = YES;
            __block NSError *gotError = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable ticket, id<PPProSessionSlotHandle> _Nullable provisionalSlot, NSError * _Nullable error) {
                gotAllowed = allowed;
                gotError = error;
            }];
            check(!gotAllowed && gotError != nil && provider.slotsByID.count == 0, "P0-06 slot creation failure never leaves orphaned slot");

            provider.failSlotCreation = NO;
            journal.failWrites = YES;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable ticket, id<PPProSessionSlotHandle> _Nullable provisionalSlot, NSError * _Nullable error) {
                gotAllowed = allowed;
                gotError = error;
            }];
            check(!gotAllowed && provider.slotsByID.count == 0, "P0-06 journal failure prevents provisional slot creation");
        }

        // 2. P0-03 & P0-08: Notification barrier error stops switch & async teardown handlers must acknowledge
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc fence:[PPProSessionFence new] runtimeProvider:provider];

            __block id<PPProSessionSlotHandle> slotA = nil;
            __block NSUUID *ticketA = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable ticket, id<PPProSessionSlotHandle> _Nullable provisionalSlot, NSError * _Nullable error) {
                ticketA = ticket; slotA = provisionalSlot;
            }];
            PPTestSlot *typedA = (PPTestSlot *)slotA;
            typedA.currentUID = @"uidA";
            __block BOOL installedA = NO;
            [coord completeAuthenticationForTicket:ticketA provisionalSlot:slotA authenticatedUID:@"uidA" expectedUID:nil maskedLabel:@"•••• 1111" method:@"phone" proAccessVerified:YES completion:^(BOOL installed, NSError * _Nullable error) {
                installedA = installed;
            }];
            check(installedA && [coord.activeUID isEqualToString:@"uidA"], "Setup A active for barrier/teardown tests");

            __block BOOL asyncCleaned = NO;
            [coord registerAsyncSessionTeardownHandler:^(__unused NSString *reason, void (^done)(void)) {
                asyncCleaned = YES;
                done();
            } forKey:@"async_worker"];

            [coord registerNotificationBarrierHandler:^(__unused NSString *reason, void (^done)(NSError * _Nullable error)) {
                done([NSError errorWithDomain:@"Test" code:901 userInfo:@{NSLocalizedDescriptionKey: @"NotifV2 deactivation failed"}]);
            }];

            __block BOOL switchAllowed = YES;
            __block NSError *switchErr = nil;
            [coord beginProvisionalAddAccountFromUID:@"uidA" completion:^(BOOL allowed, NSUUID * _Nullable ticket, id<PPProSessionSlotHandle> _Nullable provisionalSlot, NSError * _Nullable error) {
                switchAllowed = allowed;
                switchErr = error;
            }];
            check(!switchAllowed && switchErr != nil && !coord.activeUID && coord.requiresTransitionRecovery, "P0-03 notification deactivation error fails closed into recovery rather than ignoring error");
            check(asyncCleaned, "P0-08 async teardown handler acknowledged before notification barrier");
            __block BOOL recovered = NO;
            [coord retryTransitionRecoverySignOutWithCompletion:^(BOOL cleared, __unused NSError * _Nullable error) {
                recovered = cleared;
            }];
            check(recovered && !coord.requiresTransitionRecovery, "P0-03 recovery sign-out clears barrier recovery state");
        }

        // 3. P0-02, P0-04, P0-10: Separated Pro authorization + Keychain write error fail-closed + Removal error retains metadata
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc fence:[PPProSessionFence new] runtimeProvider:provider];

            // P0-02: Auth succeeds, but proAccessVerified == NO MUST reject install and sign out slot
            __block id<PPProSessionSlotHandle> slot = nil;
            __block NSUUID *ticket = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                ticket = t; slot = s;
            }];
            ((PPTestSlot *)slot).currentUID = @"uidRejected";
            __block BOOL installed = YES;
            __block NSError *authzErr = nil;
            [coord completeAuthenticationForTicket:ticket provisionalSlot:slot authenticatedUID:@"uidRejected" expectedUID:nil maskedLabel:@"•••• 2222" method:@"phone" proAccessVerified:NO completion:^(BOOL ok, NSError * _Nullable error) {
                installed = ok; authzErr = error;
            }];
            check(!installed && authzErr != nil && !coord.activeUID && provider.records.count == 0, "P0-02 unverified Pro access cannot install session or persist hint");

            // P0-04: rememberUID failure must fail closed and not leave session installed
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                ticket = t; slot = s;
            }];
            ((PPTestSlot *)slot).currentUID = @"uidFailRemember";
            provider.failRememberWrite = YES;
            [coord completeAuthenticationForTicket:ticket provisionalSlot:slot authenticatedUID:@"uidFailRemember" expectedUID:nil maskedLabel:@"•••• 3333" method:@"phone" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable error) {
                installed = ok; authzErr = error;
            }];
            check(!installed && authzErr != nil && !coord.activeUID, "P0-04 registry write failure prevents silent partial session install");

            // Successful install for uidA & uidB
            provider.failRememberWrite = NO;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                ticket = t; slot = s;
            }];
            ((PPTestSlot *)slot).currentUID = @"uidA";
            [coord completeAuthenticationForTicket:ticket provisionalSlot:slot authenticatedUID:@"uidA" expectedUID:nil maskedLabel:@"•••• 1111" method:@"phone" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable error) {
                installed = ok;
            }];
            check(installed && [provider.activeHint[@"uid"] isEqualToString:@"uidA"], "Active identity pointer written on install");

            [coord beginProvisionalAddAccountFromUID:@"uidA" completion:^(BOOL allowed, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                ticket = t; slot = s;
            }];
            ((PPTestSlot *)slot).currentUID = @"uidB";
            [coord completeAuthenticationForTicket:ticket provisionalSlot:slot authenticatedUID:@"uidB" expectedUID:nil maskedLabel:@"•••• 4444" method:@"apple.com" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable error) {
                installed = ok;
            }];
            check(installed && [coord.activeUID isEqualToString:@"uidB"] && provider.records.count == 2, "Add account installs B and keeps A+B");

            // P0-10: Removal teardown failure must retain uidA metadata
            id<PPProSessionSlotHandle> slotAHandle = [provider openSlotForRememberedUID:@"uidA" error:nil];
            ((PPTestSlot *)slotAHandle).failTeardown = YES;
            __block BOOL removedA = YES;
            __block NSError *remErr = nil;
            [coord removeRememberedAccountWithUID:@"uidA" completion:^(BOOL removed, NSError * _Nullable error) {
                removedA = removed; remErr = error;
            }];
            check(!removedA && remErr != nil && provider.records.count == 2, "P0-10 slot teardown failure keeps remembered account metadata intact");
            ((PPTestSlot *)slotAHandle).failTeardown = NO;
            provider.failRemoveWrite = YES;
            [coord removeRememberedAccountWithUID:@"uidA" completion:^(BOOL removed, NSError * _Nullable error) {
                removedA = removed; remErr = error;
            }];
            check(!removedA && remErr != nil && provider.records.count == 2, "P0-10 keychain remove failure returns error and fails closed");
        }

        // 4. P0-05: Cold-start recovery after mid-switch process kill must tear down BOTH sourceSlotID and provisionalSlotID
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            NSUUID *srcSlotID = [NSUUID UUID];
            NSUUID *provSlotID = [NSUUID UUID];
            PPTestSlot *srcSlot = (PPTestSlot *)[provider openSlotWithID:srcSlotID expectedUID:@"uidSrc" error:nil];
            PPTestSlot *provSlot = (PPTestSlot *)[provider openSlotWithID:provSlotID expectedUID:@"uidProv" error:nil];
            journal.stored = @{
                @"ticket": [NSUUID UUID].UUIDString,
                @"phase": @(PPProTransitionAuthenticating),
                @"mode": @"add_account",
                @"sourceUID": @"uidSrc",
                @"targetUID": @"__provisional__",
                @"sourceSlotID": srcSlotID.UUIDString,
                @"provisionalSlotID": provSlotID.UUIDString
            };
            PPProAccountTransitionCoordinator *coldTC = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coldCoord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:coldTC fence:[PPProSessionFence new] runtimeProvider:provider];
            __block BOOL needsRec = NO;
            __block BOOL cleared = NO;
            [coldCoord performColdStartRecoveryCheckWithCompletion:^(BOOL recoveryRequired, BOOL clr, NSError * _Nullable error) {
                needsRec = recoveryRequired; cleared = clr;
            }];
            check(needsRec && cleared && srcSlot.signOutCalled && srcSlot.teardownCalled && provSlot.signOutCalled && provSlot.teardownCalled && journal.stored == nil,
                  "P0-05 cold-start recovery signs out and tears down all persisted transition slots");
        }

        // 5. P1: Sign out all + ActiveWorkBlocker gating + Cold-start active pointer restore
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc fence:[PPProSessionFence new] runtimeProvider:provider];

            __block id<PPProSessionSlotHandle> slotA = nil;
            __block NSUUID *ticketA = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL allowed, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                ticketA = t; slotA = s;
            }];
            ((PPTestSlot *)slotA).currentUID = @"uidRestoreA";
            [coord completeAuthenticationForTicket:ticketA provisionalSlot:slotA authenticatedUID:@"uidRestoreA" expectedUID:nil maskedLabel:@"•••• 5555" method:@"phone" proAccessVerified:YES completion:^(__unused BOOL ok, __unused NSError * _Nullable err) {}];

            // Cold launch restores active slot when journal is idle and active hint exists
            PPProAccountTransitionCoordinator *tc2 = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord2 = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc2 fence:[PPProSessionFence new] runtimeProvider:provider];
            __block BOOL restored = NO;
            __block NSString *restoredUID = nil;
            [coord2 restoreLastActiveSessionOnColdLaunchWithCompletion:^(BOOL ok, BOOL reqReauth, NSString * _Nullable uid, NSError * _Nullable error) {
                restored = ok; restoredUID = uid;
            }];
            check(restored && [restoredUID isEqualToString:@"uidRestoreA"] && [coord2.activeUID isEqualToString:@"uidRestoreA"],
                  "P1 cold launch restores last active remembered slot");

            // Async active-work validator blocks signOutAll when driver has active task
            [coord2 registerAsyncActiveWorkValidator:^(__unused NSString * _Nullable uid, __unused NSString *reason, void (^done)(BOOL blocked, NSString * _Nullable blockReason)) {
                done(YES, @"Active delivery in progress");
            } forKey:@"driver_active"];
            __block BOOL didSignOutAll = YES;
            __block NSError *signOutAllErr = nil;
            [coord2 signOutAllAccountsWithReason:@"sign_out_all" completion:^(BOOL ok, NSError * _Nullable error) {
                didSignOutAll = ok; signOutAllErr = error;
            }];
            check(!didSignOutAll && signOutAllErr.code == PPProSessionCoordinatorErrorActiveWorkBlocked && provider.records.count == 1,
                  "P0-13 async active-work validator blocks signOutAll before wiping slots");

            [coord2 unregisterAsyncActiveWorkValidatorForKey:@"driver_active"];
            [coord2 signOutAllAccountsWithReason:@"sign_out_all" completion:^(BOOL ok, NSError * _Nullable error) {
                didSignOutAll = ok; signOutAllErr = error;
            }];
            check(didSignOutAll && signOutAllErr == nil && !coord2.activeUID && provider.records.count == 0 && provider.activeHint == nil,
                  "P1 signOutAll removes all slots, active pointer, and remembered accounts");
        }

        // 6. Multi-account logout regressions: external single logout, duplicate-teardown signOutAll, Add-Account signOutAll, RecoveryRequired signOutAll
        {
            PPTestJournal *journal = [PPTestJournal new];
            PPTestProvider *provider = [PPTestProvider new];
            PPProAccountTransitionCoordinator *tc = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *coord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:tc fence:[PPProSessionFence new] runtimeProvider:provider];

            __block PPTestSlot *slotA = nil;
            __block NSUUID *tA = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL ok, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                tA = t; slotA = (PPTestSlot *)s;
            }];
            slotA.currentUID = @"multiA";
            slotA.isAuthenticatedSession = YES;
            slotA.failOnDuplicateTeardown = YES;
            __block BOOL okA = NO;
            [coord completeAuthenticationForTicket:tA provisionalSlot:slotA authenticatedUID:@"multiA" expectedUID:nil maskedLabel:@"•••• 1001" method:@"phone" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable e) {
                okA = ok;
            }];
            check(okA, "Multi-account logout setup A installed");

            __block PPTestSlot *slotB = nil;
            __block NSUUID *tB = nil;
            [coord beginProvisionalAddAccountFromUID:@"multiA" completion:^(BOOL ok, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                tB = t; slotB = (PPTestSlot *)s;
            }];
            slotB.currentUID = @"multiB";
            slotB.isAuthenticatedSession = YES;
            slotB.failOnDuplicateTeardown = YES;
            __block BOOL okB = NO;
            [coord completeAuthenticationForTicket:tB provisionalSlot:slotB authenticatedUID:@"multiB" expectedUID:nil maskedLabel:@"•••• 2002" method:@"apple.com" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable e) {
                okB = ok;
            }];
            check(okB && provider.records.count == 2 && [coord.activeUID isEqualToString:@"multiB"],
                  "Multi-account logout setup B installed with A+B remembered");

            // 6a. Single-account external sign-out (UserManager path) must demote status to verification_required while keeping A+B
            __block BOOL sawAccountListNote = NO;
            id acctObs = [NSNotificationCenter.defaultCenter addObserverForName:PPProSessionAccountListDidChangeNotification object:coord queue:nil usingBlock:^(__unused NSNotification * _Nonnull note) {
                sawAccountListNote = YES;
            }];
            __block BOOL extDone = NO;
            __block NSError *extErr = nil;
            [coord completeExternalSignOutWithUID:@"multiB" completion:^(NSError * _Nullable err) {
                extErr = err;
                extDone = YES;
            }];
            check(coord.activeSlot == nil && coord.activeUID == nil && provider.activeHint == nil,
                  "Single logout synchronously clears activeSlot, activeUID, and activeHint");
            check(extDone && extErr == nil && sawAccountListNote && slotB.signOutCalled && slotB.isInvalidated && coord.transitionPhase == PPProTransitionIdle,
                  "Single logout invalidates active slot cleanly and notifies account list");
            [NSNotificationCenter.defaultCenter removeObserver:acctObs];
            NSString *statusA = nil, *statusB = nil;
            for (NSDictionary *rec in provider.records) {
                if ([rec[@"uid"] isEqualToString:@"multiA"]) statusA = rec[@"sessionStatus"];
                if ([rec[@"uid"] isEqualToString:@"multiB"]) statusB = rec[@"sessionStatus"];
            }
            check(provider.records.count == 2 && [statusB isEqualToString:PPProSessionStatusVerificationRequired] && ![statusA isEqualToString:PPProSessionStatusActive],
                  "Single logout marks signed-out account verification_required without deleting other remembered accounts");

            // 6b. Forced security external sign-out during staged Add-Account must clear journal back to Idle
            __block PPTestSlot *slotC = nil;
            __block NSUUID *tC = nil;
            [coord beginProvisionalAddAccountFromUID:nil completion:^(BOOL ok, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                tC = t; slotC = (PPTestSlot *)s;
            }];
            slotC.currentUID = @"multiC";
            slotC.isAuthenticatedSession = YES;
            slotC.failOnDuplicateTeardown = YES;
            check(coord.transitionPhase == PPProTransitionPreflight && journal.stored != nil,
                  "Staged Add-Account begins in Preflight with journal");
            BOOL advAuth = [tc advance:tC toPhase:PPProTransitionSuspended verifiedUID:nil error:nil] &&
                           [tc advance:tC toPhase:PPProTransitionAuthenticating verifiedUID:nil error:nil];
            check(advAuth && coord.transitionPhase == PPProTransitionAuthenticating,
                  "Staged Add-Account advances to Authenticating before force logout");
            __block BOOL forceExtDone = NO;
            __block NSError *forceExtErr = nil;
            [coord completeExternalSignOutWithUID:@"multiC" completion:^(NSError * _Nullable err) {
                forceExtErr = err;
                forceExtDone = YES;
            }];
            check(forceExtDone && forceExtErr == nil && coord.transitionPhase == PPProTransitionIdle && journal.stored == nil && slotC.signOutCalled && slotC.isInvalidated,
                  "External sign-out during Authenticating clears staged slot and journal cleanly back to Idle");

            // 6c. Sign Out All when active slot is also in remembered records MUST NOT double-teardown (reproduces real FIRApp deleteApp failure)
            slotB = (PPTestSlot *)[provider openSlotForRememberedUID:@"multiB" error:nil];
            slotB.isInvalidated = NO;
            slotB.currentUID = @"multiB";
            slotB.isAuthenticatedSession = YES;
            slotB.failOnDuplicateTeardown = YES;
            slotB.teardownCount = 0;
            slotA.teardownCount = 0;
            __block BOOL okReB = NO;
            [coord completeAuthenticationForTicket:nil provisionalSlot:slotB authenticatedUID:@"multiB" expectedUID:@"multiB" maskedLabel:@"•••• 2002" method:@"apple.com" proAccessVerified:YES completion:^(BOOL ok, NSError * _Nullable e) {
                okReB = ok;
            }];
            check(okReB && [coord.activeUID isEqualToString:@"multiB"] && provider.records.count == 2,
                  "Re-installed multiB active before signOutAll");

            __block BOOL allSignedOut = NO;
            __block NSError *allErr = nil;
            [coord signOutAllAccountsWithReason:@"sign_out_all" completion:^(BOOL ok, NSError * _Nullable error) {
                allSignedOut = ok;
                allErr = error;
            }];
            check(allSignedOut && allErr == nil && slotA.teardownCount == 1 && slotB.teardownCount == 1 && coord.activeSlot == nil && coord.activeUID == nil && provider.records.count == 0 && provider.activeHint == nil && journal.stored == nil,
                  "Sign Out All tears down each remembered/active slot exactly once and clears all accounts");

            // 6d. Sign Out All works even directly from Authenticating (after Add Account) or RecoveryRequired
            __block PPTestSlot *slotX = nil;
            __block NSUUID *tX = nil;
            [coord beginProvisionalSignInFromUID:nil completion:^(BOOL ok, NSUUID * _Nullable t, id<PPProSessionSlotHandle> _Nullable s, NSError * _Nullable e) {
                tX = t; slotX = (PPTestSlot *)s;
            }];
            slotX.currentUID = @"multiX";
            slotX.isAuthenticatedSession = YES;
            slotX.failOnDuplicateTeardown = YES;
            [coord completeAuthenticationForTicket:tX provisionalSlot:slotX authenticatedUID:@"multiX" expectedUID:nil maskedLabel:@"•••• 3003" method:@"phone" proAccessVerified:YES completion:^(__unused BOOL ok, __unused NSError *e) {}];

            __block PPTestSlot *pendingY = nil;
            [coord beginProvisionalAddAccountFromUID:@"multiX" completion:^(__unused BOOL ok, __unused NSUUID *t, id<PPProSessionSlotHandle> _Nullable s, __unused NSError *e) {
                pendingY = (PPTestSlot *)s;
            }];
            pendingY.failOnDuplicateTeardown = YES;
            check(coord.transitionPhase == PPProTransitionAuthenticating, "Add Account staged pending slot before signOutAll");

            allSignedOut = NO;
            allErr = nil;
            [coord signOutAllAccountsWithReason:@"sign_out_all" completion:^(BOOL ok, NSError * _Nullable error) {
                allSignedOut = ok;
                allErr = error;
            }];
            check(allSignedOut && allErr == nil && slotX.teardownCount == 1 && pendingY.teardownCount == 1 && coord.pendingSlot == nil && provider.records.count == 0 && coord.transitionPhase == PPProTransitionIdle && journal.stored == nil,
                  "Sign Out All succeeds cleanly while Add-Account is in Authenticating phase");

            // 6e. Sign Out All clears RecoveryRequired lock and remaining slots safely
            NSUUID *recSlotID = [NSUUID UUID];
            PPTestSlot *recSlot = (PPTestSlot *)[provider openSlotWithID:recSlotID expectedUID:@"multiRec" error:nil];
            recSlot.currentUID = @"multiRec";
            recSlot.isAuthenticatedSession = YES;
            recSlot.failOnDuplicateTeardown = YES;
            [provider rememberUID:@"multiRec" maskedLabel:@"•••• 4004" method:@"phone" slotID:recSlotID error:nil];
            journal.stored = @{
                @"transactionID": [NSUUID UUID].UUIDString,
                @"phase": @(PPProTransitionRecoveryRequired),
                @"sourceUID": @"multiRec",
                @"sourceSlotID": recSlotID.UUIDString
            };
            PPProAccountTransitionCoordinator *recTC = [[PPProAccountTransitionCoordinator alloc] initWithJournal:journal];
            PPProSessionCoordinator *recCoord = [[PPProSessionCoordinator alloc] initWithTransitionCoordinator:recTC fence:[PPProSessionFence new] runtimeProvider:provider];
            check(recCoord.requiresTransitionRecovery, "Recovery coordinator starts locked in RecoveryRequired");
            allSignedOut = NO;
            allErr = nil;
            [recCoord signOutAllAccountsWithReason:@"sign_out_all" completion:^(BOOL ok, NSError * _Nullable error) {
                allSignedOut = ok;
                allErr = error;
            }];
            check(allSignedOut && allErr == nil && recSlot.teardownCount == 1 && !recCoord.requiresTransitionRecovery && provider.records.count == 0 && journal.stored == nil,
                  "Sign Out All from RecoveryRequired tears down all slots once and unlocks cleanly");
        }
    }
    return 0;
}
