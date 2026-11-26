#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Local identity hints only. This store never contains credentials, roles or authorization.
@interface PPProRememberedAccountStore : NSObject
+ (BOOL)rolloutEnabled;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method inRecords:(NSArray *)records;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRememberingUID:(NSString *)uid label:(NSString *)label method:(NSString *)method slotID:(nullable NSUUID *)slotID inRecords:(NSArray *)records;
+ (NSString *)firebaseAppNameForSlotID:(NSUUID *)slotID;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)recordsByRemovingUID:(NSString *)uid inRecords:(NSArray *)records;
+ (NSString *)maskedLabelForPhone:(nullable NSString *)phone email:(nullable NSString *)email;
+ (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)recordsWithError:(NSError **)error;
+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method error:(NSError **)error;
+ (BOOL)rememberUID:(NSString *)uid maskedLabel:(NSString *)label method:(NSString *)method slotID:(NSUUID *)slotID error:(NSError **)error;
+ (BOOL)removeUID:(NSString *)uid error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
