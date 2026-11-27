#import "PPProAccountTransitionCoordinator.h"
#import <Security/Security.h>

NSString * const PPProTransitionProvisionalTargetUID = @"__provisional__";

static NSString *const PPTransitionErrorDomain = @"PPProAccountTransition";
static NSError *PPTransitionError(NSInteger code) {
    return [NSError errorWithDomain:PPTransitionErrorDomain code:code userInfo:nil];
}
static void PPAssignError(NSError **error, NSInteger code) { if (error) *error = PPTransitionError(code); }
static BOOL PPValidUID(id value) {
    return [value isKindOfClass:NSString.class] && [value length] > 0 && [value length] <= 128;
}
static BOOL PPValidSlotUUIDString(id value) {
    if (![value isKindOfClass:NSString.class]) return NO;
    return [[NSUUID alloc] initWithUUIDString:(NSString *)value] != nil;
}

@implementation PPProDeviceTransitionJournal
- (NSDictionary *)query {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"PurePetsPro";
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:[bundle stringByAppendingString:@".account-transition.v1"],
             (__bridge id)kSecAttrAccount:@"pending-transition",
             (__bridge id)kSecAttrSynchronizable:@NO};
}
- (NSDictionary *)readRecord:(NSError **)error {
    NSMutableDictionary *query = [[self query] mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
    if (status == errSecItemNotFound) return nil;
    if (status != errSecSuccess || !result) { PPAssignError(error,status != errSecSuccess ? status : errSecDecode); return nil; }
    NSData *data = CFBridgingRelease(result);
    id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![value isKindOfClass:NSDictionary.class]) { PPAssignError(error,errSecDecode); return nil; }
    return value;
}
- (BOOL)writeRecord:(NSDictionary *)record error:(NSError **)error {
    NSDictionary *query = [self query];
    if (!record) {
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound) return YES;
        PPAssignError(error,status); return NO;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:0 error:error];
    if (!data) return NO;
    NSDictionary *attributes = @{(__bridge id)kSecValueData:data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        [item addEntriesFromDictionary:attributes];
        item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)item,NULL);
    }
    if (status == errSecSuccess) return YES;
    PPAssignError(error,status); return NO;
}
@end

@interface PPProAccountTransitionCoordinator ()
@property(nonatomic,strong) id<PPProTransitionJournal> journal;
@property(nonatomic,copy,nullable) NSDictionary *record;
@property(nonatomic) PPProTransitionPhase internalPhase;
@property(nonatomic,strong,nullable) NSUUID *ticket;
@end

@implementation PPProAccountTransitionCoordinator
+ (instancetype)shared {
    static PPProAccountTransitionCoordinator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPProAccountTransitionCoordinator alloc] initWithJournal:[PPProDeviceTransitionJournal new]];
    });
    return instance;
}
- (instancetype)initWithJournal:(id<PPProTransitionJournal>)journal {
    if ((self = [super init])) {
        _journal = journal;
        NSError *error = nil;
        _record = [journal readRecord:&error];
        // Never replay a partially completed external side effect after a crash.
        _internalPhase = (_record || error) ? PPProTransitionRecoveryRequired : PPProTransitionIdle;
        NSString *identifier = [_record[@"transactionID"] isKindOfClass:NSString.class] ? _record[@"transactionID"] : nil;
        if (identifier.length) _ticket = [[NSUUID alloc] initWithUUIDString:identifier];
    }
    return self;
}
- (PPProTransitionPhase)phase { @synchronized(self) { return self.internalPhase; } }
- (NSDictionary *)persistedRecordSnapshot { @synchronized(self) { return [self.record copy]; } }
- (BOOL)matches:(NSUUID *)ticket { return ticket && [self.ticket isEqual:ticket]; }

- (nullable NSUUID *)beginFromUID:(nullable NSString *)sourceUID targetUID:(NSString *)targetUID error:(NSError * _Nullable * _Nullable)error {
    return [self beginFromUID:sourceUID targetUID:targetUID sourceSlotID:nil targetSlotID:nil mode:@"switch" error:error];
}

- (nullable NSUUID *)beginFromUID:(nullable NSString *)sourceUID
                        targetUID:(NSString *)targetUID
                     sourceSlotID:(nullable NSUUID *)sourceSlotID
                     targetSlotID:(nullable NSUUID *)targetSlotID
                             mode:(NSString *)mode
                            error:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        if (self.internalPhase != PPProTransitionIdle || !PPValidUID(targetUID) ||
            (sourceUID && !PPValidUID(sourceUID)) || [sourceUID isEqualToString:targetUID]) {
            PPAssignError(error,1); return nil;
        }
        NSUUID *ticket = [NSUUID UUID];
        NSMutableDictionary *record = [@{
            @"schema": @2,
            @"transactionID": ticket.UUIDString,
            @"mode": mode.length ? mode : @"switch",
            @"sourceUID": sourceUID ?: @"",
            @"targetUID": targetUID,
            @"provisionalTarget": @NO,
            @"phase": @(PPProTransitionPreflight)
        } mutableCopy];
        if (sourceSlotID) record[@"sourceSlotID"] = sourceSlotID.UUIDString;
        if (targetSlotID) record[@"targetSlotID"] = targetSlotID.UUIDString;
        NSDictionary *frozen = [record copy];
        if (![self.journal writeRecord:frozen error:error]) return nil;
        self.ticket = ticket; self.record = frozen; self.internalPhase = PPProTransitionPreflight;
        return ticket;
    }
}

- (nullable NSUUID *)beginProvisionalTransitionFromUID:(nullable NSString *)sourceUID
                                                 mode:(NSString *)mode
                                         sourceSlotID:(nullable NSUUID *)sourceSlotID
                                                error:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        if (self.internalPhase != PPProTransitionIdle || (sourceUID.length > 0 && !PPValidUID(sourceUID))) {
            PPAssignError(error, 1);
            return nil;
        }
        NSUUID *ticket = [NSUUID UUID];
        NSMutableDictionary *record = [@{
            @"schema": @2,
            @"transactionID": ticket.UUIDString,
            @"mode": mode.length ? mode : @"provisional",
            @"sourceUID": sourceUID ?: @"",
            @"targetUID": PPProTransitionProvisionalTargetUID,
            @"provisionalTarget": @YES,
            @"phase": @(PPProTransitionPreflight)
        } mutableCopy];
        if (sourceSlotID) record[@"sourceSlotID"] = sourceSlotID.UUIDString;
        NSDictionary *frozen = [record copy];
        if (![self.journal writeRecord:frozen error:error]) return nil;
        self.ticket = ticket; self.record = frozen; self.internalPhase = PPProTransitionPreflight;
        return ticket;
    }
}

- (BOOL)recordSlotMetadataForTicket:(NSUUID *)ticket
                       sourceSlotID:(nullable NSUUID *)sourceSlotID
                       targetSlotID:(nullable NSUUID *)targetSlotID
                  provisionalSlotID:(nullable NSUUID *)provisionalSlotID
                          targetUID:(nullable NSString *)targetUID
                              error:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        if (![self matches:ticket] || self.internalPhase == PPProTransitionIdle) {
            PPAssignError(error, 2);
            return NO;
        }
        NSMutableDictionary *next = [self.record mutableCopy];
        if (sourceSlotID) next[@"sourceSlotID"] = sourceSlotID.UUIDString;
        if (targetSlotID) next[@"targetSlotID"] = targetSlotID.UUIDString;
        if (provisionalSlotID) next[@"provisionalSlotID"] = provisionalSlotID.UUIDString;
        if (targetUID.length > 0 && PPValidUID(targetUID) &&
            ![targetUID isEqualToString:@"__mismatch__"] &&
            ![targetUID isEqualToString:PPProTransitionProvisionalTargetUID]) {
            next[@"targetUID"] = targetUID;
            next[@"provisionalTarget"] = @NO;
        }
        NSDictionary *frozen = [next copy];
        if (![self.journal writeRecord:frozen error:error]) {
            return NO;
        }
        self.record = frozen;
        return YES;
    }
}

- (void)enterRecovery {
    self.internalPhase = PPProTransitionRecoveryRequired;
    if (self.record) {
        NSMutableDictionary *next = [self.record mutableCopy];
        next[@"phase"] = @(PPProTransitionRecoveryRequired);
        if (!PPValidSlotUUIDString(next[@"sourceSlotID"]) && PPValidSlotUUIDString(self.record[@"sourceSlotID"])) {
            next[@"sourceSlotID"] = self.record[@"sourceSlotID"];
        }
        // The previous durable journal is already sufficient to force recovery on restart.
        if ([self.journal writeRecord:[next copy] error:nil]) self.record = [next copy];
    }
}

- (BOOL)advance:(NSUUID *)ticket toPhase:(PPProTransitionPhase)phase verifiedUID:(NSString *)uid error:(NSError **)error {
    @synchronized(self) {
        if (![self matches:ticket] || self.internalPhase < PPProTransitionPreflight ||
            self.internalPhase >= PPProTransitionInstalled || phase != self.internalPhase + 1) {
            PPAssignError(error,2); return NO;
        }
        NSMutableDictionary *next = [self.record mutableCopy];
        if (phase == PPProTransitionAuthorized || phase == PPProTransitionInstalled) {
            BOOL isProvisional = [self.record[@"provisionalTarget"] boolValue] ||
                [self.record[@"targetUID"] isEqualToString:PPProTransitionProvisionalTargetUID];
            if ([uid isEqualToString:@"__mismatch__"] || !PPValidUID(uid)) {
                [self enterRecovery]; PPAssignError(error,3); return NO;
            }
            if (isProvisional && phase == PPProTransitionAuthorized && ![uid isEqualToString:PPProTransitionProvisionalTargetUID]) {
                next[@"targetUID"] = uid;
                next[@"provisionalTarget"] = @NO;
            } else if (![uid isEqualToString:self.record[@"targetUID"]]) {
                [self enterRecovery]; PPAssignError(error,3); return NO;
            }
        }
        next[@"phase"] = @(phase);
        if (![self.journal writeRecord:[next copy] error:error]) { [self enterRecovery]; return NO; }
        self.record = [next copy]; self.internalPhase = phase; return YES;
    }
}

- (BOOL)clearJournal:(NSError **)error {
    if (![self.journal writeRecord:nil error:error]) { [self enterRecovery]; return NO; }
    self.record = nil; self.ticket = nil; self.internalPhase = PPProTransitionIdle;
    return YES;
}

- (BOOL)cancelPreflight:(NSUUID *)ticket error:(NSError **)error {
    @synchronized(self) {
        if (![self matches:ticket] || self.internalPhase != PPProTransitionPreflight) {
            PPAssignError(error,4); return NO;
        }
        return [self clearJournal:error];
    }
}

- (BOOL)commit:(NSUUID *)ticket verifiedUID:(NSString *)uid error:(NSError **)error {
    @synchronized(self) {
        if (![self matches:ticket] || self.internalPhase != PPProTransitionInstalled) {
            PPAssignError(error,5); return NO;
        }
        if (![uid isEqualToString:self.record[@"targetUID"]]) {
            [self enterRecovery]; PPAssignError(error,3); return NO;
        }
        return [self clearJournal:error];
    }
}

- (void)requireRecoveryForTicket:(NSUUID *)ticket {
    @synchronized(self) { if ([self matches:ticket]) [self enterRecovery]; }
}

- (BOOL)clearAfterVerifiedSignOut:(NSError **)error {
    @synchronized(self) {
        if (self.internalPhase != PPProTransitionRecoveryRequired) { PPAssignError(error,6); return NO; }
        return [self clearJournal:error];
    }
}
@end
