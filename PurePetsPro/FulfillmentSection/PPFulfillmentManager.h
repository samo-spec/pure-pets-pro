#import <Foundation/Foundation.h>

@class PPFulfillmentModel;
@protocol FIRListenerRegistration;

/// Pure Pets' own account. Platform fulfillments (ownerType "platform") are
/// owned by it and are operated through the staff command, not the partner one.
FOUNDATION_EXPORT NSString * const PPFulfillmentOfficialOwnerUID;

@interface PPFulfillmentManager : NSObject

+ (instancetype)sharedManager;

/// YES when `uid` is the official account and the fulfillment is a platform
/// fulfillment it owns.
+ (BOOL)isOfficialPlatformFulfillment:(PPFulfillmentModel *)fulfillment forUID:(NSString *)uid;

- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                    onChange:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error))onChange;

/// Availability-aware variant used by operational surfaces. `fromCache` is YES
/// when Firestore has only supplied local data; callers may keep rendering the
/// models while communicating that live server confirmation is unavailable.
- (id<FIRListenerRegistration>)observeFulfillmentsForOwnerID:(NSString *)ownerID
                                                stateHandler:(void (^)(NSArray<PPFulfillmentModel *> *fulfillments,
                                                                         NSError *error,
                                                                         BOOL fromCache))stateHandler;

/// Expands the live, newest-first prefix by 50 records per authorized profile.
- (BOOL)canLoadMoreFulfillmentsForListener:(id<FIRListenerRegistration>)listener;
- (void)loadMoreFulfillmentsForListener:(id<FIRListenerRegistration>)listener;

- (id<FIRListenerRegistration>)observeEventsForFulfillmentID:(NSString *)fulfillmentID
                                                     onChange:(void (^)(NSArray<NSDictionary *> *events))onChange;

/// Keeps history failure/cache state distinct from an empty successful history.
- (id<FIRListenerRegistration>)observeEventsForFulfillmentID:(NSString *)fulfillmentID
                                              stateHandler:(void (^)(NSArray<NSDictionary *> *events, NSError *error, BOOL fromCache))stateHandler;

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

/// Fetches one server-only fulfillment record; cache/pending writes cannot confirm a command.
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

/// Platform fulfillments: Infra `staffTransitionOfficialFulfillment`, which
/// re-checks staff authority and requires a note of at least 3 characters.
- (void)performOfficialPlatformTransitionAction:(NSString *)action
                                  fulfillmentID:(NSString *)fulfillmentID
                                 expectedStatus:(NSString *)expectedStatus
                                           note:(NSString *)note
                                     completion:(void (^)(BOOL success, NSString *message, NSError *error))completion;

@end
