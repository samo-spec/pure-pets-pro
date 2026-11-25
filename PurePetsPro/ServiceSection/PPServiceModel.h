//
//  PPServiceModel.h
//  PurePetsPro
//
//  Service offer model — maps to "serviceOffers" Firestore collection.
//  Provider-facing: exposes only fields the service provider controls.
//  Reads all Firestore fields for backward compatibility; writes only provider fields.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPServiceType) {
    PPServiceTypeTraining = 0,
    PPServiceTypeGrooming = 1
};

@interface PPServiceModel : NSObject <NSCopying>

// ── Core Provider Fields ──
@property (nonatomic, copy)   NSString *serviceID;
@property (nonatomic, copy)   NSString *serviceOwnerID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *searchTitle;
@property (nonatomic, copy)   NSString *descriptionText;
@property (nonatomic, assign) double price;
@property (nonatomic, copy)   NSString *currency;
@property (nonatomic, copy)   NSString *category;
@property (nonatomic, copy)   NSString *categoryID;
@property (nonatomic, assign) NSInteger petMainKindID;
@property (nonatomic, assign) PPServiceType type;
@property (nonatomic, copy)   NSString *imageURL;
@property (nonatomic, copy)   NSString *blurHash;
@property (nonatomic, assign) BOOL isAvailable;      ///< Provider-controlled availability toggle
@property (nonatomic, assign) NSInteger durationMinutes;
@property (nonatomic, assign) BOOL isHomeVisit;
@property (nonatomic, copy, nullable) NSArray<NSString *> *inclusions;

// ── System Status (read-only in Pro — set by admin/backend) ──
@property (nonatomic, assign, readonly) BOOL isDisabled;
@property (nonatomic, assign, readonly) BOOL isBlocked;
@property (nonatomic, assign, readonly) BOOL isDeleted;
@property (nonatomic, copy, readonly)   NSString *verificationStatus;

// ── Subscription (read-only in Pro — managed by backend/admin) ──
@property (nonatomic, copy, readonly)   NSString *subscriptionPlan;
@property (nonatomic, copy, readonly)   NSString *subscriptionStatus;
@property (nonatomic, assign, readonly) BOOL subscriptionActive;
@property (nonatomic, strong, readonly, nullable) NSDate *subscriptionStartDate;
@property (nonatomic, strong, readonly, nullable) NSDate *subscriptionEndDate;

// ── Timestamps ──
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

// ── Backward Compat (kept for Firestore round-trip; not shown in UI) ──
@property (nonatomic, strong, nullable) NSDate *availableDate;  ///< Legacy — superseded by isAvailable
@property (nonatomic, strong, nullable) NSDate *timestamp;      ///< Legacy creation marker
@property (nonatomic, strong) NSDictionary<NSString *, id> *extraFields;

// ── Serialization ──
/// Returns only provider-controlled fields (for add/edit writes).
- (NSDictionary *)providerToDictionary;
/// Returns all fields (full Firestore round-trip — used internally).
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)serviceID;

// ── Helpers ──
- (NSString *)localizedTypeName;
- (NSString *)localizedVerificationStatus;
- (NSString *)localizedAvailabilityStatus;
/// YES if not deleted, not blocked, not disabled, and provider has set available.
- (BOOL)isLive;

@end

#pragma mark - PPServiceBookingItem (Live Booking & Follow-Up Pipeline)

@interface PPServiceBookingItem : NSObject <NSCopying>
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *serviceID;
@property (nonatomic, copy) NSString *serviceTitle;
@property (nonatomic, copy) NSString *serviceOwnerID;
@property (nonatomic, copy) NSString *petName;
@property (nonatomic, copy) NSString *petBreed;
@property (nonatomic, copy) NSString *petPhotoURL;
@property (nonatomic, assign) NSInteger petKindID;
@property (nonatomic, copy) NSString *petAge;
@property (nonatomic, copy) NSString *petNotes;
@property (nonatomic, copy) NSString *customerID;
@property (nonatomic, copy) NSString *customerName;
@property (nonatomic, copy) NSString *customerPhone;
@property (nonatomic, copy) NSString *bookingDateText;
@property (nonatomic, strong, nullable) NSDate *bookingDate;
@property (nonatomic, copy) NSString *locationText;
@property (nonatomic, assign) BOOL isHomeVisit;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy) NSString *status; // @"new", @"scheduled", @"in_progress", @"completed", @"declined"
@property (nonatomic, copy) NSString *inclusionsText;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)requestID;
- (NSString *)localizedStatusText;
- (UIColor *)statusAccentColor;

@end

NS_ASSUME_NONNULL_END
