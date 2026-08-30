//
//  PPDeliveryManager.h
//  PurePetsPro
//
//  Singleton manager for delivery operations: Firestore queries, Cloud Function calls.
//

#import <Foundation/Foundation.h>
#import "PPDeliveryOrderModel.h"

@class UserModel;

NS_ASSUME_NONNULL_BEGIN

/// Notification posted when orders list changes (real-time listener).
extern NSString * const PPDeliveryOrdersDidChangeNotification;

typedef void(^PPDeliveryOrdersBlock)(NSArray<PPDeliveryOrderModel *> * _Nullable orders, NSError * _Nullable error);
typedef void(^PPDeliveryOrderBlock)(PPDeliveryOrderModel * _Nullable order, NSError * _Nullable error);
typedef void(^PPDeliveryActionBlock)(BOOL success, NSString * _Nullable message, NSError * _Nullable error);

@interface PPDeliveryManager : NSObject

+ (instancetype)shared;

// ── Real-time Listener ──
/// Starts a snapshot listener on Orders filtered for delivery-relevant statuses.
- (void)startListeningForDeliveryOrders;
/// Stops the active snapshot listener.
- (void)stopListening;

/// Current cached orders (updated by snapshot listener).
@property (nonatomic, strong, readonly) NSArray<PPDeliveryOrderModel *> *allOrders;

/// Filter orders by delivery segment.
- (NSArray<PPDeliveryOrderModel *> *)ordersForFilter:(PPDeliveryFilter)filter;
- (NSArray<PPDeliveryOrderModel *> *)ordersForFilter:(PPDeliveryFilter)filter searchText:(nullable NSString *)searchText;

/// Fetches one current delivery record without adding another listener.
- (void)fetchDeliveryOrderWithID:(NSString *)orderID completion:(PPDeliveryOrderBlock)completion;
/// Returns the current listener-backed projection, including exact assigned-child state for V1.
- (nullable PPDeliveryOrderModel *)currentDeliveryOrderWithID:(NSString *)orderID;

// ── Cloud Function Actions ──
/// Confirm handover and mark package as picked up from store.
- (void)markOrderShipped:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Mark assigned package as on the way.
- (void)markOrderInTransit:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Mark order as delivered.
- (void)markOrderDelivered:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Collect cash payment.
- (void)collectCashPayment:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Mark order as completed after delivery/payment confirmation.
- (void)markOrderCompleted:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Cancel order.
- (void)cancelOrder:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;
/// Accept delivery assignment — stores current user UID as the delivery agent for this order.
- (void)acceptDeliveryOrder:(NSString *)orderId completion:(PPDeliveryActionBlock)completion;

// ── Delivery-specific callable (for non-admin delivery users) ──
/// Calls `deliveryTransitionOrderStatus` Cloud Function instead of the admin callable.
/// Used for canonical delivery actions and supported legacy aliases.
- (void)performDeliveryAction:(NSString *)action orderId:(NSString *)orderId note:(nullable NSString *)note completion:(PPDeliveryActionBlock)completion;

// ── Provider Name Caching ──
- (NSString *)providerDisplayNameForID:(NSString *)providerID;
- (void)cacheProviderUser:(UserModel *)user forID:(NSString *)providerID;

@end

NS_ASSUME_NONNULL_END
