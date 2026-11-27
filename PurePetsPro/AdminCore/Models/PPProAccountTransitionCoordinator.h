#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPProTransitionPhase) {
    PPProTransitionIdle = 0,
    PPProTransitionPreflight,
    PPProTransitionSuspended,
    PPProTransitionAuthenticating,
    PPProTransitionAuthorized,
    PPProTransitionInstalled,
    PPProTransitionRecoveryRequired
};

FOUNDATION_EXPORT NSString * const PPProTransitionProvisionalTargetUID;

/// Records contain transition identifiers and slot UUIDs, never authentication secrets or tokens.
@protocol PPProTransitionJournal <NSObject>
- (nullable NSDictionary *)readRecord:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeRecord:(nullable NSDictionary *)record error:(NSError * _Nullable * _Nullable)error;
@end

@interface PPProDeviceTransitionJournal : NSObject <PPProTransitionJournal>
@end

/// Transaction ordering and crash recovery. The operational runtime must perform
/// each real barrier before advancing. This type does not itself authenticate users.
@interface PPProAccountTransitionCoordinator : NSObject
@property(nonatomic, readonly) PPProTransitionPhase phase;
@property(nonatomic, copy, readonly, nullable) NSDictionary *persistedRecordSnapshot;
+ (instancetype)shared;
- (instancetype)initWithJournal:(id<PPProTransitionJournal>)journal NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSUUID *)beginFromUID:(nullable NSString *)sourceUID targetUID:(NSString *)targetUID error:(NSError * _Nullable * _Nullable)error;
- (nullable NSUUID *)beginProvisionalTransitionFromUID:(nullable NSString *)sourceUID mode:(NSString *)mode sourceSlotID:(nullable NSUUID *)sourceSlotID error:(NSError * _Nullable * _Nullable)error;
- (nullable NSUUID *)beginFromUID:(nullable NSString *)sourceUID targetUID:(NSString *)targetUID sourceSlotID:(nullable NSUUID *)sourceSlotID targetSlotID:(nullable NSUUID *)targetSlotID mode:(NSString *)mode error:(NSError * _Nullable * _Nullable)error;
- (BOOL)recordSlotMetadataForTicket:(NSUUID *)ticket sourceSlotID:(nullable NSUUID *)sourceSlotID targetSlotID:(nullable NSUUID *)targetSlotID provisionalSlotID:(nullable NSUUID *)provisionalSlotID targetUID:(nullable NSString *)targetUID error:(NSError * _Nullable * _Nullable)error;
- (BOOL)advance:(NSUUID *)ticket toPhase:(PPProTransitionPhase)phase verifiedUID:(nullable NSString *)uid error:(NSError * _Nullable * _Nullable)error;
- (BOOL)cancelPreflight:(NSUUID *)ticket error:(NSError * _Nullable * _Nullable)error;
- (BOOL)commit:(NSUUID *)ticket verifiedUID:(NSString *)uid error:(NSError * _Nullable * _Nullable)error;
- (void)requireRecoveryForTicket:(NSUUID *)ticket;
/// The runtime must verify signed-out state and completed detachment before invoking.
- (BOOL)clearAfterVerifiedSignOut:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
