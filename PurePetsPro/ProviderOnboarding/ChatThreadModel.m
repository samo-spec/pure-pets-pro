//
//  ChatThreadModel.m
//  PurePetsPro
//
//  Updated for iOS messaging parity

#import "ChatThreadModel.h"
#import "UserModel.h"
#import <FirebaseFirestore/FirebaseFirestore.h>

NSString * const PPChatParticipantTypeUser = @"user";
NSString * const PPChatParticipantTypeProvider = @"provider";
NSString * const PPChatParticipantTypeConsole = @"console";

static NSString *PPChatTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSDate *PPChatThreadDateFromValue(id value)
{
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)value doubleValue]];
    }
    return nil;
}

static BOOL PPChatIdentityFlagEnabled(id value)
{
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    NSString *normalized = [PPChatTrimmedString(value) lowercaseString];
    return [normalized isEqualToString:@"true"] ||
           [normalized isEqualToString:@"yes"] ||
           [normalized isEqualToString:@"1"] ||
           [normalized isEqualToString:@"enabled"] ||
           [normalized isEqualToString:@"active"];
}

NSString *PPChatParticipantTypeForProfile(NSDictionary *profile, NSString *sourcePlatform)
{
    NSDictionary *safeProfile = [profile isKindOfClass:NSDictionary.class] ? profile : @{};
    NSString *accountType = [PPChatTrimmedString(safeProfile[@"accountType"]) lowercaseString];
    if ([accountType isEqualToString:@"staff"]) {
        return PPChatParticipantTypeConsole;
    }

    NSDictionary *features = [safeProfile[@"features"] isKindOfClass:NSDictionary.class] ? safeProfile[@"features"] : @{};
    NSArray<NSString *> *providerFeatureKeys = @[
        @"delivery",
        @"production",
        @"serviceProvider",
        @"service_provider",
        @"veterinarians",
        @"vet",
        @"pharmacy",
        @"canDelivery",
        @"canOfferServices",
        @"canVet",
        @"canPharmacy",
        @"canAccessProviderMarketplace"
    ];
    for (NSString *key in providerFeatureKeys) {
        if (PPChatIdentityFlagEnabled(features[key]) || PPChatIdentityFlagEnabled(safeProfile[key])) {
            return PPChatParticipantTypeProvider;
        }
    }

    NSString *source = [PPChatTrimmedString(sourcePlatform) lowercaseString];
    if ([source containsString:@"console"] ||
        [source containsString:@"admin"] ||
        [source containsString:@"staff"] ||
        [source containsString:@"web"]) {
        return PPChatParticipantTypeConsole;
    }
    if ([source containsString:@"provider"] || [source containsString:@"pro_"] || [source isEqualToString:@"pro"]) {
        return PPChatParticipantTypeProvider;
    }
    return PPChatParticipantTypeUser;
}

@implementation ChatThreadModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.ID forKey:@"ID"];
    [coder encodeObject:self.memberIDs forKey:@"memberIDs"];
    [coder encodeObject:self.lastMessage forKey:@"lastMessage"];
    [coder encodeObject:self.lastSenderID forKey:@"lastSenderID"];
    [coder encodeObject:self.lastMessageAt forKey:@"lastMessageAt"];
    [coder encodeObject:self.lastReadAt forKey:@"lastReadAt"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeObject:self.otherUser forKey:@"otherUser"];
    [coder encodeObject:self.conversationType forKey:@"conversationType"];
    [coder encodeObject:self.threadType forKey:@"threadType"];
    [coder encodeBool:self.supportThread forKey:@"supportThread"];
    [coder encodeObject:self.supportUserID forKey:@"supportUserId"];
    [coder encodeObject:self.customerId forKey:@"customerId"];
    [coder encodeObject:self.supportDisplayName forKey:@"supportDisplayName"];
    [coder encodeObject:self.supportPhotoURLString forKey:@"supportPhotoUrl"];
    [coder encodeObject:self.sourcePlatform forKey:@"sourcePlatform"];
    [coder encodeObject:self.participantType forKey:@"participantType"];
    [coder encodeObject:self.mutedBy forKey:@"mutedBy"];
    [coder encodeObject:self.binnedBy forKey:@"binnedBy"];
    [coder encodeObject:self.reportedBy forKey:@"reportedBy"];
    [coder encodeInteger:self.unreadCount forKey:@"unreadCount"];
    [coder encodeInteger:self.messagesCount forKey:@"messagesCount"];
    [coder encodeBool:self.isMuted forKey:@"isMuted"];
    [coder encodeBool:self.isBinned forKey:@"isBinned"];
    [coder encodeBool:self.isReportedByMe forKey:@"isReportedByMe"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (!self) return nil;

    NSSet<Class> *stringArrayClasses = [NSSet setWithObjects:NSArray.class, NSString.class, nil];
    self.ID = [coder decodeObjectOfClass:NSString.class forKey:@"ID"] ?: @"";
    self.memberIDs = [coder decodeObjectOfClasses:stringArrayClasses forKey:@"memberIDs"] ?: @[];
    self.lastMessage = [coder decodeObjectOfClass:NSString.class forKey:@"lastMessage"] ?: @"";
    self.lastSenderID = [coder decodeObjectOfClass:NSString.class forKey:@"lastSenderID"] ?: @"";
    self.lastMessageAt = [coder decodeObjectOfClass:NSDate.class forKey:@"lastMessageAt"];
    self.lastReadAt = [coder decodeObjectOfClass:NSDate.class forKey:@"lastReadAt"];
    self.timestamp = [coder decodeObjectOfClass:NSDate.class forKey:@"timestamp"];
    self.otherUser = [coder decodeObjectOfClass:UserModel.class forKey:@"otherUser"];
    self.conversationType = [coder decodeObjectOfClass:NSString.class forKey:@"conversationType"] ?: @"";
    self.threadType = [coder decodeObjectOfClass:NSString.class forKey:@"threadType"] ?: @"";
    self.supportThread = [coder decodeBoolForKey:@"supportThread"];
    self.supportUserID = [coder decodeObjectOfClass:NSString.class forKey:@"supportUserId"] ?: @"";
    self.customerId = [coder decodeObjectOfClass:NSString.class forKey:@"customerId"] ?: @"";
    self.supportDisplayName = [coder decodeObjectOfClass:NSString.class forKey:@"supportDisplayName"] ?: @"";
    self.supportPhotoURLString = [coder decodeObjectOfClass:NSString.class forKey:@"supportPhotoUrl"] ?: @"";
    self.sourcePlatform = [coder decodeObjectOfClass:NSString.class forKey:@"sourcePlatform"] ?: @"";
    self.participantType = [coder decodeObjectOfClass:NSString.class forKey:@"participantType"] ?: PPChatParticipantTypeUser;
    self.mutedBy = [coder decodeObjectOfClasses:stringArrayClasses forKey:@"mutedBy"] ?: @[];
    self.binnedBy = [coder decodeObjectOfClasses:stringArrayClasses forKey:@"binnedBy"] ?: @[];
    self.reportedBy = [coder decodeObjectOfClasses:stringArrayClasses forKey:@"reportedBy"] ?: @[];
    self.unreadCount = [coder decodeIntegerForKey:@"unreadCount"];
    self.messagesCount = [coder decodeIntegerForKey:@"messagesCount"];
    self.isMuted = [coder decodeBoolForKey:@"isMuted"];
    self.isBinned = [coder decodeBoolForKey:@"isBinned"];
    self.isReportedByMe = [coder decodeBoolForKey:@"isReportedByMe"];
    return self;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    self.unreadCount = 0;
    self.messagesCount = 0;
    self.sourcePlatform = @"";
    self.participantType = PPChatParticipantTypeUser;
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [self init];
    if (!self) return nil;
    
    self.ID = dict[@"id"] ?: dict[@"threadID"] ?: @"";
    self.conversationType = PPChatTrimmedString(dict[@"conversationType"]);
    self.threadType = PPChatTrimmedString(dict[@"threadType"]);
    self.supportThread = PPChatIdentityFlagEnabled(dict[@"supportThread"]);
    self.supportUserID = PPChatTrimmedString(dict[@"supportUserId"]) ?: PPChatTrimmedString(dict[@"supportUserID"]);
    self.customerId = PPChatTrimmedString(dict[@"customerId"]);
    self.supportDisplayName = PPChatTrimmedString(dict[@"supportDisplayName"]);
    self.supportPhotoURLString = PPChatTrimmedString(dict[@"supportPhotoUrl"]) ?: PPChatTrimmedString(dict[@"supportPhotoURLString"]);
    self.sourcePlatform = PPChatTrimmedString(dict[@"sourcePlatform"]);
    self.participantType = PPChatParticipantTypeForProfile(nil, self.sourcePlatform);
    
    id members = dict[@"members"];
    if ([members isKindOfClass:[NSArray class]]) {
        self.memberIDs = members;
    }
    
    self.lastMessage = dict[@"lastMessage"] ?: @"";
    self.lastSenderID = PPChatTrimmedString(dict[@"lastSenderID"]) ?: PPChatTrimmedString(dict[@"lastSenderId"]);
    
    self.lastMessageAt = PPChatThreadDateFromValue(dict[@"lastMessageAt"]);
    self.lastReadAt = PPChatThreadDateFromValue(dict[@"lastReadAt"]);
    
    self.timestamp = PPChatThreadDateFromValue(dict[@"timestamp"]);
    
    id mutedBy = dict[@"mutedBy"];
    if ([mutedBy isKindOfClass:[NSArray class]]) {
        self.mutedBy = mutedBy;
    }
    
    id binnedBy = dict[@"binnedBy"];
    if ([binnedBy isKindOfClass:[NSArray class]]) {
        self.binnedBy = binnedBy;
    }
    
    id reportedBy = dict[@"reportedBy"];
    if ([reportedBy isKindOfClass:[NSArray class]]) {
        self.reportedBy = reportedBy;
    }
    
    // Check if current user reported this thread
    NSString *currentUserID = [FIRAuth auth].currentUser.uid ?: @"";
    if ([self.reportedBy containsObject:currentUserID]) {
        self.isReportedByMe = YES;
    }
    
    self.unreadCount = [dict[@"unreadCount"] integerValue] ?: 0;
    self.messagesCount = [dict[@"messagesCount"] integerValue] ?: 0;
    
    return self;
}

- (UserModel *)otherUser
{
    if (_otherUser.ID.length > 0) {
        return _otherUser;
    }

    NSString *customerID = self.customerId.length > 0 ? self.customerId : @"";
    if (customerID.length == 0) {
        for (NSString *memberID in self.memberIDs) {
            NSString *candidate = PPChatTrimmedString(memberID);
            if (candidate.length > 0 && ![candidate isEqualToString:self.supportUserID]) {
                customerID = candidate;
                break;
            }
        }
    }

    if (customerID.length == 0) {
        return nil;
    }

    UserModel *user = [UserModel new];
    user.ID = customerID;
    user.UserName = self.supportDisplayName.length > 0 ? self.supportDisplayName : customerID;
    if (self.supportPhotoURLString.length > 0) {
        user.UserImageUrl = [NSURL URLWithString:self.supportPhotoURLString];
    }
    _otherUser = user;
    return _otherUser;
}

#pragma mark - iOS Messaging Helpers

+ (BOOL)isSupportThread:(ChatThreadModel *)thread
{
    if (!thread) return NO;
    return thread.supportThread || 
           [thread.ID hasPrefix:@"support_"] ||
           [thread.threadType isEqualToString:@"support"];
}

+ (NSString *)purePetsOfficialSupportUserID
{
    // Canonical support user ID from iOS - returns the configured support agent ID
    static NSString *cachedSupportID = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedSupportID = PPChatTrimmedString([[NSUserDefaults standardUserDefaults] stringForKey:@"PPOfficialSupportUserID"]);
    });
    return cachedSupportID ?: @"purepets_support";
}

+ (NSString *)canonicalSupportThreadIDForCustomerID:(NSString *)customerID
{
    NSString *supportID = [self purePetsOfficialSupportUserID];
    NSArray *sortedIDs = [@[customerID, supportID] sortedArrayUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"support_%@_%@", sortedIDs[0], sortedIDs[1]];
}

+ (UserModel *)resolveOtherUserFromThread:(ChatThreadModel *)thread
{
    if (!thread) return nil;
    return thread.otherUser ?: [thread otherUser];
}

@end