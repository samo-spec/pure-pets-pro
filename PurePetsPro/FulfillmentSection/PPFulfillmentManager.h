#import <Foundation/Foundation.h>

@class PPFulfillmentModel;
@class FIRListenerRegistration;

@interface PPFulfillmentManager : NSObject

+ (instancetype)sharedManager;

- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                    onChange:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error))onChange;

- (id<FIRListenerRegistration>)observeEventsForFulfillmentID:(NSString *)fulfillmentID
                                                    onChange:(void (^)(NSArray<NSDictionary *> *events))onChange;

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                           note:(NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

@end
