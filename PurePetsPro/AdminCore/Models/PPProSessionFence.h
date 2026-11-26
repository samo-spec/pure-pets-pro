#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// In-memory generation fence. No credentials or persistent account data.
@interface PPProSessionFence : NSObject
+ (instancetype)shared;
- (void)observeActiveUID:(nullable NSString *)uid identity:(nullable id)identity;
- (nullable NSUUID *)captureForUID:(NSString *)requestedUID activeUID:(nullable NSString *)activeUID identity:(nullable id)identity;
- (BOOL)accepts:(nullable NSUUID *)generation requestedUID:(NSString *)requestedUID activeUID:(nullable NSString *)activeUID identity:(nullable id)identity;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
