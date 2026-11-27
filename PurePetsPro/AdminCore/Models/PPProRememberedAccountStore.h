#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PPProSessionStatusActive;
FOUNDATION_EXPORT NSString * const PPProSessionStatusAvailable;
FOUNDATION_EXPORT NSString * const PPProSessionStatusVerificationRequired;
FOUNDATION_EXPORT NSString * const PPProSessionStatusExpired;
FOUNDATION_EXPORT NSString * const PPProSessionStatusRevoked;
FOUNDATION_EXPORT NSString * const PPProSessionStatusLocked;
FOUNDATION_EXPORT NSString * const PPProSessionStatusUnavailable;

/// Local identity hints only. This store never contains credentials, tokens, roles, or authorization.
@interface PPProRememberedAccountStore : NSObject
+ (BOOL)rolloutEnabled;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method inRecords:(NSArray *)records;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method slotID:(nullable NSUUID *)slotID inRecords:(NSArray *)records;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByUpdatingSessionStatus:(NSString *)status verifiedAt:(nullable NSString *)verifiedAt forUID:(NSString *)uid inRecords:(NSArray *)records;
+ (NSString *)firebaseAppNameForSlotID:(NSUUID *)slotID;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRemovingUID:(NSString *)uid inRecords:(NSArray *)records;
+ (NSString *)maskedLabelForPhone:(nullable NSString *)phone email:(nullable NSString *)email;
+ (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)recordsWithError:(NSError * _Nullable * _Nullable)error;
+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method slotID:(NSUUID *)slotID error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)updateSessionStatusHint:(NSString *)status verifiedAt:(nullable NSString *)verifiedAt forUID:(NSString *)uid error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)removeUID:(NSString *)uid error:(NSError * _Nullable * _Nullable)error;

/// Non-secret pointer to the last cleanly installed identity on device for cold-start restoration.
+ (nullable NSDictionary<NSString *, NSString *> *)activeIdentityHintWithError:(NSError * _Nullable * _Nullable)error;
+ (BOOL)setActiveIdentityUID:(NSString *)uid slotID:(nullable NSUUID *)slotID error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)clearActiveIdentityWithError:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
