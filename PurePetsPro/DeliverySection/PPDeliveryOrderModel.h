//
//  PPDeliveryOrderModel.h
//  PurePetsPro
//
//  Delivery order model parsed from Firestore "Orders" documents.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Status Constants

typedef NSString *PPOrderRawStatus NS_TYPED_EXTENSIBLE_ENUM;

static PPOrderRawStatus const PPOrderRawStatusPending           = @"pending";
static PPOrderRawStatus const PPOrderRawStatusProcessing        = @"processing";
static PPOrderRawStatus const PPOrderRawStatusPreparing         = @"preparing";
static PPOrderRawStatus const PPOrderRawStatusPacked            = @"packed";
static PPOrderRawStatus const PPOrderRawStatusConfirmed         = @"confirmed";
static PPOrderRawStatus const PPOrderRawStatusPaid              = @"paid";
static PPOrderRawStatus const PPOrderRawStatusReady             = @"ready";
static PPOrderRawStatus const PPOrderRawStatusShipped           = @"shipped";
static PPOrderRawStatus const PPOrderRawStatusShipping          = @"shipping";
static PPOrderRawStatus const PPOrderRawStatusInTransit         = @"in_transit";
static PPOrderRawStatus const PPOrderRawStatusOutForDelivery    = @"out_for_delivery";
static PPOrderRawStatus const PPOrderRawStatusDelivered         = @"delivered";
static PPOrderRawStatus const PPOrderRawStatusFulfilled         = @"fulfilled";
static PPOrderRawStatus const PPOrderRawStatusCompleted         = @"completed";
static PPOrderRawStatus const PPOrderRawStatusCancelled         = @"cancelled";
static PPOrderRawStatus const PPOrderRawStatusFailed            = @"failed";

typedef NSString *PPDeliveryStatus NS_TYPED_EXTENSIBLE_ENUM;

static PPDeliveryStatus const PPDeliveryStatusReadyToShip       = @"ready_to_ship";
static PPDeliveryStatus const PPDeliveryStatusRequested         = @"delivery_requested";
static PPDeliveryStatus const PPDeliveryStatusAssigned          = @"delivery_assigned";
static PPDeliveryStatus const PPDeliveryStatusAwaitingHandover  = @"awaiting_handover";
static PPDeliveryStatus const PPDeliveryStatusPickedUp          = @"picked_up";
static PPDeliveryStatus const PPDeliveryStatusInTransit         = @"in_transit";
static PPDeliveryStatus const PPDeliveryStatusDelivered         = @"delivered";
static PPDeliveryStatus const PPDeliveryStatusPaymentPending    = @"payment_pending";
static PPDeliveryStatus const PPDeliveryStatusPaymentConfirmed  = @"payment_confirmed";
static PPDeliveryStatus const PPDeliveryStatusCompleted         = @"completed";
static PPDeliveryStatus const PPDeliveryStatusCancelled         = @"delivery_cancelled";
static PPDeliveryStatus const PPDeliveryStatusFailed            = @"delivery_failed";
static PPDeliveryStatus const PPDeliveryStatusReturnedToStore   = @"returned_to_store";

#pragma mark - Delivery Filter Segment

typedef NS_ENUM(NSInteger, PPDeliveryFilter) {
    PPDeliveryFilterReady = 0,
    PPDeliveryFilterPendingPickup,
    PPDeliveryFilterInTransit,
    PPDeliveryFilterDelivered,
    PPDeliveryFilterCancelled,
    PPDeliveryFilterAll
};

#pragma mark - Order Item

@interface PPDeliveryOrderItem : NSObject
@property (nonatomic, copy)   NSString *itemID;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *imageURL;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) double price;
@property (nonatomic, copy, nullable) NSString *variant;
@property (nonatomic, copy, nullable) NSString *ownerID;
@property (nonatomic, copy, nullable) NSString *ownerType;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

#pragma mark - Order Model

@interface PPDeliveryOrderModel : NSObject <NSCopying>

// ── Identity ──
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy) NSString *orderNumber;
@property (nonatomic, copy) NSString *displayOrderNumber;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, assign) NSInteger fulfillmentVersion;
@property (nonatomic, strong) NSArray<NSString *> *fulfillmentOrderIDs;

// ── Customer ──
@property (nonatomic, copy) NSString *customerName;
@property (nonatomic, copy) NSString *customerPhone;
@property (nonatomic, copy) NSString *deliveryAddress;
@property (nonatomic, copy, nullable) NSString *pickupAddress;
@property (nonatomic, copy, nullable) NSString *deliveryAreaName;
@property (nonatomic, copy, nullable) NSString *deliveryLocationPoint;

// ── Items ──
@property (nonatomic, strong) NSArray<PPDeliveryOrderItem *> *items;
@property (nonatomic, strong) NSArray<NSString *> *marketplaceItemIDs;

// ── Marketplace Provider ──
@property (nonatomic, copy, nullable) NSString *marketplaceProviderID;
@property (nonatomic, copy, nullable) NSString *marketplaceOwnerType;
@property (nonatomic, copy, nullable) NSString *marketplaceProviderName;
@property (nonatomic, copy, nullable) NSString *marketplaceProviderPhone;
@property (nonatomic, copy, nullable) NSString *marketplaceProviderPhotoURLString;

// ── Financials ──
@property (nonatomic, assign) double totalAmount;
@property (nonatomic, copy)   NSString *currencyCode;
@property (nonatomic, copy)   NSString *paymentMethodId;
@property (nonatomic, copy)   NSString *paymentStatus;

// ── Status ──
@property (nonatomic, copy) NSString *rawStatus;
@property (nonatomic, copy) NSString *deliveryStatus;
@property (nonatomic, copy, nullable) NSString *notes;
@property (nonatomic, copy, nullable) NSString *latestDeliveryEventType;

// ── Delivery Assignment ──
@property (nonatomic, copy, nullable) NSString *deliveryUserId;
@property (nonatomic, copy, nullable) NSString *deliveryUserName;
@property (nonatomic, copy, nullable) NSString *deliveryUserPhone;
@property (nonatomic, copy, nullable) NSString *branchID;
@property (nonatomic, copy, nullable) NSString *branchName;

// ── Timestamps ──
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *processedAt;
@property (nonatomic, strong, nullable) NSDate *readyAt;
@property (nonatomic, strong, nullable) NSDate *readyToShipAt;
@property (nonatomic, strong, nullable) NSDate *deliveryRequestedAt;
@property (nonatomic, strong, nullable) NSDate *deliveryAcceptedAt;
@property (nonatomic, strong, nullable) NSDate *pickedUpAt;
@property (nonatomic, strong, nullable) NSDate *inTransitAt;
@property (nonatomic, strong, nullable) NSDate *shippedAt;
@property (nonatomic, strong, nullable) NSDate *deliveredAt;
@property (nonatomic, strong, nullable) NSDate *paymentPendingAt;
@property (nonatomic, strong, nullable) NSDate *paymentConfirmedAt;
@property (nonatomic, strong, nullable) NSDate *completedAt;
@property (nonatomic, strong, nullable) NSDate *paymentCollectedAt;
@property (nonatomic, strong, nullable) NSDate *cancelledAt;
@property (nonatomic, strong, nullable) NSDate *deliveryFailedAt;
@property (nonatomic, strong, nullable) NSDate *returnedToStoreAt;
@property (nonatomic, strong, nullable) NSDate *latestDeliveryEventAt;

// ── Serialization ──
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)docID;
- (NSDictionary *)toDictionary;

// ── Status Helpers ──
- (BOOL)isCashOrder;
- (BOOL)isReady;
- (BOOL)canAcceptDelivery;
- (BOOL)canConfirmPackageHandover;
- (BOOL)canMarkShipped;
- (BOOL)canMarkInTransit;
- (BOOL)canMarkDelivered;
- (BOOL)canCollectCashPayment;
- (BOOL)canMarkCompleted;
- (BOOL)canCancel;
- (BOOL)isTerminal;

// ── Display Helpers ──
- (NSString *)displayStatus;
- (NSString *)formattedTotal;
- (NSString *)bestOrderNumber;
- (BOOL)pp_canRevealExactDeliveryLocation;
- (BOOL)pp_canRevealCustomerPhoneForDeliveryUserID:(NSString *)deliveryUserID;
- (NSString *)pp_pickupLocationSummary;
- (NSString *)pp_deliveryAreaSummary;
- (NSString *)pp_visibleCustomerLocationSummary;
- (NSString *)pp_exactDeliveryLocationText;

@end

NS_ASSUME_NONNULL_END
