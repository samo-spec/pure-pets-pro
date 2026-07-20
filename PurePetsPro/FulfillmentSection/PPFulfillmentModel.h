#import <Foundation/Foundation.h>

@interface PPFulfillmentModel : NSObject

@property (nonatomic, copy) NSString *fulfillmentID;
@property (nonatomic, copy) NSString *parentOrderId;
@property (nonatomic, copy) NSString *parentUserId;
@property (nonatomic, copy) NSString *parentOrderNumber;
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, copy) NSString *ownerType;
@property (nonatomic, copy) NSString *fulfillmentMode;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) double subtotal;
@property (nonatomic, assign) double platformCommission;
@property (nonatomic, assign) double providerNet;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, copy) NSDate *updatedAt;
@property (nonatomic, copy) NSString *adminOverrideReason;
@property (nonatomic, copy) NSDate *adminOverrideAt;
@property (nonatomic, copy) NSArray<NSDictionary *> *items;
@property (nonatomic, copy) NSArray<NSDictionary *> *events;

+ (instancetype)modelFromDictionary:(NSDictionary *)dict fulfillmentID:(NSString *)fulfillmentID;
- (NSString *)statusDisplayName;
- (UIColor *)statusColor;
- (NSString *)nextActionForStatus;
- (NSArray<NSString *> *)availableActions;
- (BOOL)isTerminal;

@end
