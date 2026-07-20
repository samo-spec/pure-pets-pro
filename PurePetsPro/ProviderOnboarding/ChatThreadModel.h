//
//  ChatThreadModel.h
//  PurePetsPro
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UserModel;

FOUNDATION_EXPORT NSString * const PPChatParticipantTypeUser;
FOUNDATION_EXPORT NSString * const PPChatParticipantTypeProvider;
FOUNDATION_EXPORT NSString * const PPChatParticipantTypeConsole;
FOUNDATION_EXPORT NSString *PPChatParticipantTypeForProfile(NSDictionary * _Nullable profile,
                                                            NSString * _Nullable sourcePlatform);

@interface ChatThreadModel : NSObject <NSSecureCoding>

@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSArray<NSString *> *memberIDs;
@property (nonatomic, strong) NSString *lastMessage;
@property (nonatomic, strong) NSString *lastSenderID;
@property (nonatomic, strong) NSDate *lastMessageAt;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) UserModel *otherUser;
@property (nonatomic, strong) NSString *conversationType;
@property (nonatomic, strong) NSString *threadType;
@property (nonatomic, assign) BOOL supportThread;
@property (nonatomic, strong) NSString *supportUserID;
@property (nonatomic, strong) NSString *customerId;
@property (nonatomic, strong) NSString *supportDisplayName;
@property (nonatomic, strong) NSString *supportPhotoURLString;
@property (nonatomic, strong) NSString *sourcePlatform;
@property (nonatomic, strong) NSString *participantType;
@property (nonatomic, strong) NSArray<NSString *> *mutedBy;
@property (nonatomic, strong) NSArray<NSString *> *binnedBy;
@property (nonatomic, strong) NSArray<NSString *> *reportedBy;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) NSInteger messagesCount;
@property (nonatomic, strong) NSDate *lastReadAt;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isBinned;
@property (nonatomic, assign) BOOL isReportedByMe;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

// iOS messaging helpers
+ (BOOL)isSupportThread:(ChatThreadModel *)thread;
+ (NSString *)purePetsOfficialSupportUserID;
+ (NSString *)canonicalSupportThreadIDForCustomerID:(NSString *)customerID;
+ (UserModel *)resolveOtherUserFromThread:(ChatThreadModel *)thread;

@end

NS_ASSUME_NONNULL_END
