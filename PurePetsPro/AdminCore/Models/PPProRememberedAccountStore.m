#import "PPProRememberedAccountStore.h"
#import <Security/Security.h>

NSString * const PPProSessionStatusActive = @"active";
NSString * const PPProSessionStatusAvailable = @"available";
NSString * const PPProSessionStatusVerificationRequired = @"verification_required";
NSString * const PPProSessionStatusExpired = @"expired";
NSString * const PPProSessionStatusRevoked = @"revoked";
NSString * const PPProSessionStatusLocked = @"locked";
NSString * const PPProSessionStatusUnavailable = @"unavailable";

static NSString *const PPRegistryDomain = @"PPProRememberedAccountStore";
static NSUInteger const PPRegistryLimit = 8;

@implementation PPProRememberedAccountStore

+ (BOOL)rolloutEnabled {
    return YES; // Multi-account rollout enabled per explicit owner authorization.
}

+ (BOOL)validUID:(id)uid {
    return [uid isKindOfClass:NSString.class] && [uid length] > 0 && [uid length] <= 128;
}

+ (BOOL)validLabel:(id)label {
    return [label isKindOfClass:NSString.class] && [label length] > 0 && [label length] <= 160;
}

+ (BOOL)validMethod:(id)method {
    return [method isKindOfClass:NSString.class] &&
        [@[@"phone", @"google.com", @"apple.com"] containsObject:method];
}

+ (nullable NSString *)validStatus:(id)status {
    if (![status isKindOfClass:NSString.class]) return nil;
    NSArray<NSString *> *allowed = @[
        PPProSessionStatusActive,
        PPProSessionStatusAvailable,
        PPProSessionStatusVerificationRequired,
        PPProSessionStatusExpired,
        PPProSessionStatusRevoked,
        PPProSessionStatusLocked,
        PPProSessionStatusUnavailable
    ];
    return [allowed containsObject:status] ? status : nil;
}

+ (nullable NSString *)validTimestampString:(id)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return (trimmed.length > 0 && trimmed.length <= 64) ? trimmed : nil;
}

+ (NSString *)nowTimestampString {
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
    });
    return [formatter stringFromDate:[NSDate date]] ?: @"";
}

+ (NSString *)firebaseAppNameForSlotID:(NSUUID *)slotID {
    return [@"pppro_slot_" stringByAppendingString:[slotID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
}

+ (NSArray *)normalized:(NSArray *)records {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableSet *seenSlots = [NSMutableSet set];
    for (id entry in records) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        id uid = entry[@"uid"], label = entry[@"label"], method = entry[@"method"];
        if (![self validUID:uid] || ![self validLabel:label] || ![self validMethod:method] || [seen containsObject:uid]) continue;
        NSString *slot = [entry[@"slotID"] isKindOfClass:NSString.class] ? [[NSUUID alloc] initWithUUIDString:entry[@"slotID"]].UUIDString : nil;
        if (slot && [seenSlots containsObject:slot]) continue;
        NSMutableDictionary *record = [@{@"uid":uid, @"label":label, @"method":method} mutableCopy];
        if (slot) { record[@"slotID"] = slot; [seenSlots addObject:slot]; }
        NSString *status = [self validStatus:entry[@"sessionStatus"]];
        if (status.length > 0) record[@"sessionStatus"] = status;
        NSString *lastActiveAt = [self validTimestampString:entry[@"lastActiveAt"]];
        if (lastActiveAt.length > 0) record[@"lastActiveAt"] = lastActiveAt;
        NSString *lastVerifiedAt = [self validTimestampString:entry[@"lastVerifiedAt"]];
        if (lastVerifiedAt.length > 0) record[@"lastVerifiedAt"] = lastVerifiedAt;
        [seen addObject:uid];
        [result addObject:[record copy]];
        if (result.count == PPRegistryLimit) break;
    }
    return [result copy];
}

+ (NSArray *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method inRecords:(NSArray *)records {
    return [self recordsByRememberingUID:uid label:label method:method slotID:nil inRecords:records];
}

+ (NSArray *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method slotID:(NSUUID *)slotID inRecords:(NSArray *)records {
    NSArray *clean = [self normalized:records];
    if (![self validUID:uid] || ![self validLabel:label] || ![self validMethod:method]) return clean;
    NSString *requestedSlot = slotID.UUIDString;
    NSDictionary *prior = nil;
    BOOL hasSlots = NO;
    for (NSDictionary *record in clean) {
        NSString *existingSlot = record[@"slotID"];
        hasSlots |= existingSlot != nil;
        if ([record[@"uid"] isEqual:uid]) prior = record;
        else if (requestedSlot && [existingSlot isEqual:requestedSlot]) return clean;
    }
    if (prior[@"slotID"] && requestedSlot && ![prior[@"slotID"] isEqual:requestedSlot]) return clean;
    if (!prior && clean.count >= PPRegistryLimit && (hasSlots || requestedSlot)) return clean; // never evict an authenticated slot
    NSMutableDictionary *updated = [@{@"uid":uid, @"label":label, @"method":method} mutableCopy];
    NSString *slot = requestedSlot ?: prior[@"slotID"];
    if (slot) updated[@"slotID"] = slot;
    if (prior[@"sessionStatus"]) updated[@"sessionStatus"] = prior[@"sessionStatus"];
    if (prior[@"lastVerifiedAt"]) updated[@"lastVerifiedAt"] = prior[@"lastVerifiedAt"];
    if (prior[@"lastActiveAt"]) updated[@"lastActiveAt"] = prior[@"lastActiveAt"];
    if (slotID) {
        NSString *now = [self nowTimestampString];
        if (now.length > 0) {
            updated[@"lastActiveAt"] = now;
            updated[@"lastVerifiedAt"] = now;
        }
        updated[@"sessionStatus"] = PPProSessionStatusActive;
    }
    NSMutableArray *next = [NSMutableArray arrayWithObject:[updated copy]];
    for (NSDictionary *record in clean) {
        if (![record[@"uid"] isEqual:uid]) {
            NSMutableDictionary *other = [record mutableCopy];
            if ([other[@"sessionStatus"] isEqual:PPProSessionStatusActive]) {
                other[@"sessionStatus"] = PPProSessionStatusAvailable;
            }
            [next addObject:[other copy]];
        }
        if (next.count == PPRegistryLimit) break;
    }
    return [next copy];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByUpdatingSessionStatus:(NSString *)status verifiedAt:(nullable NSString *)verifiedAt forUID:(NSString *)uid inRecords:(NSArray *)records {
    NSArray *clean = [self normalized:records];
    NSString *validStatus = [self validStatus:status];
    if (![self validUID:uid] || !validStatus.length) return clean;
    NSString *validVerified = [self validTimestampString:verifiedAt];
    NSMutableArray *next = [NSMutableArray arrayWithCapacity:clean.count];
    for (NSDictionary *record in clean) {
        if ([record[@"uid"] isEqual:uid]) {
            NSMutableDictionary *updated = [record mutableCopy];
            updated[@"sessionStatus"] = validStatus;
            if ([validStatus isEqualToString:PPProSessionStatusActive]) {
                NSString *now = [self nowTimestampString];
                if (now.length > 0) updated[@"lastActiveAt"] = now;
            }
            if (validVerified.length > 0) {
                updated[@"lastVerifiedAt"] = validVerified;
            }
            [next addObject:[updated copy]];
        } else {
            NSMutableDictionary *other = [record mutableCopy];
            if ([validStatus isEqualToString:PPProSessionStatusActive] &&
                [other[@"sessionStatus"] isEqual:PPProSessionStatusActive]) {
                other[@"sessionStatus"] = PPProSessionStatusAvailable;
            }
            [next addObject:[other copy]];
        }
    }
    return [next copy];
}

+ (NSArray *)recordsByRemovingUID:(NSString *)uid inRecords:(NSArray *)records {
    NSMutableArray *next = [NSMutableArray array];
    for (NSDictionary *record in [self normalized:records]) {
        if (![record[@"uid"] isEqual:uid]) [next addObject:record];
    }
    return [next copy];
}

+ (NSString *)maskedLabelForPhone:(NSString *)phone email:(NSString *)email {
    if (phone.length > 4) return [@"•••• " stringByAppendingString:[phone substringFromIndex:phone.length-4]];
    NSRange at = [email rangeOfString:@"@" options:NSBackwardsSearch];
    if (email.length && at.location != NSNotFound && at.location > 0 && at.location+1 < email.length) {
        NSString *prefix = [email substringWithRange:[email rangeOfComposedCharacterSequenceAtIndex:0]];
        return [NSString stringWithFormat:@"%@•••%@", prefix, [email substringFromIndex:at.location]];
    }
    return @"••••";
}

+ (NSDictionary *)queryForAccount:(NSString *)account {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"PurePetsPro";
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:[bundle stringByAppendingString:@".remembered-identities.v1"],
             (__bridge id)kSecAttrAccount:account,
             (__bridge id)kSecAttrSynchronizable:@NO};
}

+ (NSDictionary *)query {
    return [self queryForAccount:@"identity-hints"];
}

+ (NSDictionary *)activeIdentityQuery {
    return [self queryForAccount:@"active-identity-hint"];
}

+ (void)setError:(NSError **)error status:(OSStatus)status {
    if (error) *error = [NSError errorWithDomain:PPRegistryDomain code:status userInfo:nil];
}

+ (NSArray *)recordsWithError:(NSError **)error {
    @synchronized(self) {
        NSMutableDictionary *query = [[self query] mutableCopy];
        query[(__bridge id)kSecReturnData] = @YES;
        query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
        if (status == errSecItemNotFound) return @[];
        if (status != errSecSuccess || !result) { [self setError:error status:status]; return nil; }
        NSData *data = CFBridgingRelease(result);
        id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if (![decoded isKindOfClass:NSArray.class]) {
            [self setError:error status:errSecDecode]; return nil;
        }
        return [self normalized:decoded];
    }
}

+ (BOOL)saveRecords:(NSArray *)records error:(NSError **)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self normalized:records] options:0 error:error];
    if (!data) return NO;
    NSDictionary *query = [self query];
    if (!records.count) {
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound) return YES;
        [self setError:error status:status]; return NO;
    }
    NSDictionary *attributes = @{(__bridge id)kSecValueData:data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        [item addEntriesFromDictionary:attributes];
        item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        status = SecItemAdd((__bridge CFDictionaryRef)item,NULL);
    }
    if (status == errSecSuccess) return YES;
    [self setError:error status:status]; return NO;
}

+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method error:(NSError **)error {
    @synchronized(self) {
        if (![self validUID:uid] || ![self validLabel:label] || ![self validMethod:method]) {
            [self setError:error status:errSecParam]; return NO;
        }
        NSArray *existing = [self recordsWithError:error];
        return existing && [self saveRecords:[self recordsByRememberingUID:uid label:label method:method inRecords:existing] error:error];
    }
}

+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method slotID:(NSUUID *)slotID error:(NSError **)error {
    @synchronized(self) {
        if (!slotID || ![self validUID:uid] || ![self validLabel:label] || ![self validMethod:method]) {
            [self setError:error status:errSecParam]; return NO;
        }
        NSArray *existing = [self recordsWithError:error];
        if (!existing) return NO;
        NSArray *next = [self recordsByRememberingUID:uid label:label method:method slotID:slotID inRecords:existing];
        NSDictionary *first = next.firstObject;
        if (![first[@"uid"] isEqual:uid] || ![first[@"slotID"] isEqual:slotID.UUIDString]) {
            [self setError:error status:errSecDuplicateItem]; return NO;
        }
        return [self saveRecords:next error:error];
    }
}

+ (BOOL)updateSessionStatusHint:(NSString *)status verifiedAt:(nullable NSString *)verifiedAt forUID:(NSString *)uid error:(NSError **)error {
    @synchronized(self) {
        if (![self validUID:uid] || ![self validStatus:status].length) {
            [self setError:error status:errSecParam];
            return NO;
        }
        NSArray *existing = [self recordsWithError:error];
        if (!existing) return NO;
        NSArray *next = [self recordsByUpdatingSessionStatus:status verifiedAt:verifiedAt forUID:uid inRecords:existing];
        return [self saveRecords:next error:error];
    }
}

+ (BOOL)removeUID:(NSString *)uid error:(NSError **)error {
    @synchronized(self) {
        NSArray *existing = [self recordsWithError:error];
        if (!existing) return NO;
        if (![self saveRecords:[self recordsByRemovingUID:uid inRecords:existing] error:error]) return NO;
        NSError *hintReadErr = nil;
        NSDictionary *activeHint = [self activeIdentityHintWithError:&hintReadErr];
        if (hintReadErr) {
            if (error) *error = hintReadErr;
            return NO;
        }
        if ([activeHint[@"uid"] isEqualToString:uid]) {
            return [self clearActiveIdentityWithError:error];
        }
        return YES;
    }
}

+ (nullable NSDictionary<NSString *, NSString *> *)activeIdentityHintWithError:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        NSMutableDictionary *query = [[self activeIdentityQuery] mutableCopy];
        query[(__bridge id)kSecReturnData] = @YES;
        query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (status == errSecItemNotFound) return nil;
        if (status != errSecSuccess || !result) {
            [self setError:error status:status];
            return nil;
        }
        NSData *data = CFBridgingRelease(result);
        id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if (![decoded isKindOfClass:NSDictionary.class]) {
            [self setError:error status:errSecDecode];
            return nil;
        }
        NSString *uid = decoded[@"uid"];
        if (![self validUID:uid]) {
            [self setError:error status:errSecDecode];
            return nil;
        }
        NSMutableDictionary<NSString *, NSString *> *hint = [NSMutableDictionary dictionary];
        hint[@"uid"] = uid;
        NSString *slot = [decoded[@"slotID"] isKindOfClass:NSString.class]
            ? [[NSUUID alloc] initWithUUIDString:decoded[@"slotID"]].UUIDString
            : nil;
        if (slot.length > 0) hint[@"slotID"] = slot;
        NSString *updatedAt = [self validTimestampString:decoded[@"updatedAt"]];
        if (updatedAt.length > 0) hint[@"updatedAt"] = updatedAt;
        return [hint copy];
    }
}

+ (BOOL)setActiveIdentityUID:(NSString *)uid slotID:(nullable NSUUID *)slotID error:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        if (![self validUID:uid]) {
            [self setError:error status:errSecParam];
            return NO;
        }
        NSMutableDictionary<NSString *, NSString *> *payload = [NSMutableDictionary dictionary];
        payload[@"uid"] = uid;
        if (slotID) payload[@"slotID"] = slotID.UUIDString;
        NSString *now = [self nowTimestampString];
        if (now.length > 0) payload[@"updatedAt"] = now;
        NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
        if (!data) return NO;
        NSDictionary *query = [self activeIdentityQuery];
        NSDictionary *attributes = @{(__bridge id)kSecValueData: data};
        OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            NSMutableDictionary *item = [query mutableCopy];
            [item addEntriesFromDictionary:attributes];
            item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
            status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        }
        if (status == errSecSuccess) return YES;
        [self setError:error status:status];
        return NO;
    }
}

+ (BOOL)clearActiveIdentityWithError:(NSError * _Nullable * _Nullable)error {
    @synchronized(self) {
        NSDictionary *query = [self activeIdentityQuery];
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound) return YES;
        [self setError:error status:status];
        return NO;
    }
}

@end
