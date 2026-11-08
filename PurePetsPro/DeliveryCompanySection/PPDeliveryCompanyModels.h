#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *PPDeliveryCompanyRole NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT PPDeliveryCompanyRole const PPDeliveryCompanyRoleOwner;
FOUNDATION_EXPORT PPDeliveryCompanyRole const PPDeliveryCompanyRoleDispatcher;
FOUNDATION_EXPORT PPDeliveryCompanyRole const PPDeliveryCompanyRoleDriver;
FOUNDATION_EXPORT PPDeliveryCompanyRole const PPDeliveryCompanyRoleViewer;

/// Server-resolved delivery workspace kinds (getMyDeliveryCompanies and
/// getDeliveryCompanyProfile contractVersion 2). Display and routing only;
/// every command is re-authorized by the backend.
typedef NSString *PPDeliveryWorkspaceKind NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT PPDeliveryWorkspaceKind const PPDeliveryWorkspaceKindOfficialDriver;
FOUNDATION_EXPORT PPDeliveryWorkspaceKind const PPDeliveryWorkspaceKindOfficialFleetStaff;
FOUNDATION_EXPORT PPDeliveryWorkspaceKind const PPDeliveryWorkspaceKindPartnerDriver;
FOUNDATION_EXPORT PPDeliveryWorkspaceKind const PPDeliveryWorkspaceKindPartnerDispatch;
FOUNDATION_EXPORT PPDeliveryWorkspaceKind const PPDeliveryWorkspaceKindRestricted;

typedef NSString *PPDeliveryCompanyStatus NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusOffered;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusAccepted;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusAssigned;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusPickedUp;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusInTransit;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusDelivered;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusCompleted;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusRejected;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusCancelled;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusFailed;
FOUNDATION_EXPORT PPDeliveryCompanyStatus const PPDeliveryCompanyStatusExpired;

typedef NS_ENUM(NSInteger, PPDeliveryCompanyDashboardFilter) {
    PPDeliveryCompanyDashboardFilterNewRequests = 0,
    PPDeliveryCompanyDashboardFilterAccepted,
    PPDeliveryCompanyDashboardFilterAssigned,
    PPDeliveryCompanyDashboardFilterInProgress,
    PPDeliveryCompanyDashboardFilterDelivered,
    PPDeliveryCompanyDashboardFilterCompleted,
    PPDeliveryCompanyDashboardFilterCancelledRejected,
    PPDeliveryCompanyDashboardFilterMembers,
};

FOUNDATION_EXPORT NSDate * _Nullable PPDeliveryCompanyDateFromValue(id _Nullable value);
FOUNDATION_EXPORT NSString *PPDeliveryCompanyFormattedDate(NSDate * _Nullable date);
FOUNDATION_EXPORT NSString *PPDeliveryCompanyRoleDisplayName(NSString * _Nullable role);
FOUNDATION_EXPORT NSString *PPDeliveryCompanyStatusDisplayName(NSString * _Nullable status);
FOUNDATION_EXPORT UIColor *PPDeliveryCompanyStatusColor(NSString * _Nullable status);
FOUNDATION_EXPORT NSString *PPDeliveryCompanyFilterTitle(PPDeliveryCompanyDashboardFilter filter);

@interface PPDeliveryCompanyProfile : NSObject
@property (nonatomic, copy) NSString *companyID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *legalName;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, copy) PPDeliveryCompanyRole role;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
/// Server-resolved workspace kinds; empty for responses that predate contractVersion 2.
@property (nonatomic, copy) NSArray<NSString *> *workspaceKinds;
/// Union of server-projected capabilities across the resolved workspaces.
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *serverCapabilities;
/// Server reason when the membership resolves no usable workspace.
@property (nonatomic, copy) NSString *restrictionReason;

+ (instancetype)modelFromResponse:(NSDictionary *)response;
- (BOOL)isOwner;
- (BOOL)isDispatcher;
- (BOOL)isDriver;
- (BOOL)isViewer;
- (BOOL)canDispatch;
- (BOOL)canViewMembers;
- (BOOL)canManageMembers;
- (BOOL)hasServerWorkspaceProjection;
- (BOOL)hasDriverWorkspace;
- (BOOL)hasDispatchWorkspace;
- (BOOL)isOfficialDriverWorkspace;
- (BOOL)isRestrictedWorkspace;
- (BOOL)serverAllowsCapability:(NSString *)capability;
/// YES when the unified driver cockpit is this profile's primary workspace:
/// the server resolved a driver workspace without dispatch, or a restricted
/// membership whose reason the cockpit explains. Responses that predate the
/// server workspace projection keep the legacy destinations.
- (BOOL)prefersDriverCockpit;
@end

@interface PPDeliveryCompanyEvent : NSObject
@property (nonatomic, copy) NSString *eventID;
@property (nonatomic, copy) NSString *eventType;
@property (nonatomic, copy) NSString *actorName;
@property (nonatomic, copy) NSString *actorRole;
@property (nonatomic, copy) NSString *fromStatus;
@property (nonatomic, copy) NSString *toStatus;
@property (nonatomic, copy) NSDictionary *metadata;
@property (nonatomic, strong, nullable) NSDate *createdAt;
+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary;
@end

@interface PPDeliveryCompanyRequest : NSObject
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *orderID;
@property (nonatomic, copy) NSString *orderNumber;
@property (nonatomic, copy) NSString *companyID;
@property (nonatomic, copy) NSString *companyName;
@property (nonatomic, copy) PPDeliveryCompanyStatus status;
@property (nonatomic, copy) NSDictionary *pickupAddress;
@property (nonatomic, copy) NSDictionary *dropoffAddress;
@property (nonatomic, copy) NSString *assignedDriverUID;
@property (nonatomic, copy) NSString *assignedDriverName;
@property (nonatomic, assign) double deliveryFee;
@property (nonatomic, copy) NSString *paymentStatus;
@property (nonatomic, copy) NSString *deliveryNote;
@property (nonatomic, copy) NSString *receiverName;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyEvent *> *events;

+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary;
- (NSString *)bestOrderNumber;
- (NSString *)pickupSummary;
- (NSString *)dropoffSummary;
- (NSString *)formattedFee;
- (NSString *)statusDisplayName;
- (UIColor *)statusColor;
- (BOOL)matchesFilter:(PPDeliveryCompanyDashboardFilter)filter;
- (nullable NSString *)nextDriverStatus;
@end

@interface PPDeliveryCompanyMember : NSObject
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *photoURL;
@property (nonatomic, copy) PPDeliveryCompanyRole role;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) BOOL online;
@property (nonatomic, assign) BOOL available;
@property (nonatomic, assign) BOOL canReceiveAssignments;
@property (nonatomic, assign) BOOL canSelfAcceptOrders;
@property (nonatomic, assign) BOOL canManageSelfAcceptance;
@property (nonatomic, assign) NSInteger revision;
@property (nonatomic, assign) NSInteger activeDeliveryCount;
@property (nonatomic, strong, nullable) NSDate *lastSeenAt;
+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary;
- (BOOL)isActiveDriver;
@end

NS_ASSUME_NONNULL_END
