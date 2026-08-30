#import <Foundation/Foundation.h>

@class PPFulfillmentModel;
@protocol FIRListenerRegistration;

@interface PPFulfillmentManager : NSObject

+ (instancetype)sharedManager;

- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                    onChange:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error))onChange;

/// Availability-aware variant used by operational surfaces. `fromCache` is YES
/// when Firestore has only supplied local data; callers may keep rendering the
/// models while communicating that live server confirmation is unavailable.
- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                stateHandler:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments,
                                                                         NSError *error,
                                                                         BOOL fromCache))stateHandler;

- (id<FIRListenerRegistration>)observeEventsForFulfillmentID:(NSString *)fulfillmentID
                                                     onChange:(void (^)(NSArray<NSDictionary *> *events))onChange;

/// Observes the authoritative child document used to gate detail actions.
- (id<FIRListenerRegistration>)observeFulfillmentWithID:(NSString *)fulfillmentID
                                                onChange:(void (^)(PPFulfillmentModel * _Nullable fulfillment,
                                                                     NSError * _Nullable error))onChange;

/// Metadata-aware child observer. Callers that expose transition controls must
/// wait for `fromCache == NO` before enabling an action.
- (id<FIRListenerRegistration>)observeFulfillmentWithID:(NSString *)fulfillmentID
                                            stateHandler:(void (^)(PPFulfillmentModel * _Nullable fulfillment,
                                                                     NSError * _Nullable error,
                                                                     BOOL fromCache))stateHandler;

/// Fetches one current fulfillment record without creating a second listener.
- (void)fetchFulfillmentWithID:(NSString *)fulfillmentID
                     completion:(void (^)(PPFulfillmentModel * _Nullable fulfillment, NSError * _Nullable error))completion;

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                           note:(NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

- (void)performTransitionAction:(NSString *)action
                  fulfillmentID:(NSString *)fulfillmentID
                 expectedStatus:(nullable NSString *)expectedStatus
                      commandID:(nullable NSString *)commandID
                           note:(nullable NSString *)note
                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

@end
