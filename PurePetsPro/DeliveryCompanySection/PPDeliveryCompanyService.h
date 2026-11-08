#import <Foundation/Foundation.h>
#import "PPDeliveryCompanyModels.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PPDeliveryCompanyMembershipDidChangeNotification;

typedef void (^PPDeliveryCompanyProfileCompletion)(PPDeliveryCompanyProfile * _Nullable profile, NSError * _Nullable error);
typedef void (^PPDeliveryCompanyRequestsCompletion)(NSArray<PPDeliveryCompanyRequest *> * _Nullable requests, NSString * _Nullable nextPageToken, NSError * _Nullable error);
typedef void (^PPDeliveryCompanyRequestCompletion)(PPDeliveryCompanyRequest * _Nullable request, NSError * _Nullable error);
typedef void (^PPDeliveryCompanyMembersCompletion)(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable error);
typedef void (^PPDeliveryCompanyActionCompletion)(NSDictionary * _Nullable result, NSError * _Nullable error);
typedef void (^PPDriverCockpitCompletion)(NSDictionary<NSString *, id> * _Nullable result, NSError * _Nullable error);

@interface PPDeliveryCompanyService : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly, nullable) PPDeliveryCompanyProfile *verifiedProfile;
@property (nonatomic, copy, readonly) NSArray<PPDeliveryCompanyProfile *> *discoveredProfiles;
@property (nonatomic, copy, readonly) NSString *configuredCompanyID;
@property (nonatomic, assign, readonly) BOOL isRefreshingProfile;

- (void)discoverCompanyMembershipsWithCompletion:(void(^)(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error))completion;
- (void)refreshConfiguredProfileWithCompletion:(nullable PPDeliveryCompanyProfileCompletion)completion;
- (void)verifyAndStoreCompanyID:(NSString *)companyID completion:(PPDeliveryCompanyProfileCompletion)completion;
- (void)storeVerifiedProfile:(PPDeliveryCompanyProfile *)profile;
- (void)disconnectCompany;

- (void)listRequestsForProfile:(PPDeliveryCompanyProfile *)profile
                 nextPageToken:(nullable NSString *)nextPageToken
                    completion:(PPDeliveryCompanyRequestsCompletion)completion;
- (void)getRequestWithID:(NSString *)requestID completion:(PPDeliveryCompanyRequestCompletion)completion;
- (void)listMembersForCompanyID:(NSString *)companyID completion:(PPDeliveryCompanyMembersCompletion)completion;

- (void)createRequestForOrderID:(NSString *)orderID
                      companyID:(nullable NSString *)companyID
          marketplaceProviderID:(NSString *)marketplaceProviderID
                       branchID:(nullable NSString *)branchID
                  pickupAddress:(nullable NSDictionary *)pickupAddress
                 dropoffAddress:(nullable NSDictionary *)dropoffAddress
                    deliveryFee:(double)deliveryFee
                  paymentStatus:(nullable NSString *)paymentStatus
                paymentProvider:(nullable NSString *)paymentProvider
                   deliveryNote:(nullable NSString *)deliveryNote
                     completion:(PPDeliveryCompanyActionCompletion)completion;

- (void)acceptRequestID:(NSString *)requestID completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)rejectRequestID:(NSString *)requestID reason:(nullable NSString *)reason completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)assignRequestID:(NSString *)requestID driverUID:(NSString *)driverUID completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)reassignRequestID:(NSString *)requestID driverUID:(NSString *)driverUID completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)updateRequestID:(NSString *)requestID toStatus:(NSString *)status receiverName:(nullable NSString *)receiverName completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)completeRequestID:(NSString *)requestID completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)cancelRequestID:(NSString *)requestID reason:(nullable NSString *)reason completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)inviteMemberIdentifier:(NSString *)targetIdentifier role:(NSString *)role companyID:(NSString *)companyID completion:(PPDeliveryCompanyActionCompletion)completion;
- (void)disableMemberUID:(NSString *)targetUID companyID:(NSString *)companyID completion:(PPDeliveryCompanyActionCompletion)completion;

#pragma mark - Driver cockpit

/// Signed-in Firebase user identifier, or an empty string.
+ (NSString *)currentAccountUID;

/// Resolves older delivery entry points from the authenticated profile and
/// server membership projection. Staff and fleet drivers use the canonical
/// cockpit; unresolved identity never falls back to provider operations.
/// Routing only: this method does not grant any delivery capability.
- (void)resolveDriverCockpitRequirementWithCompletion:(void(^)(BOOL requiresDriverCockpit, NSError * _Nullable error))completion
    NS_SWIFT_NAME(resolveDriverCockpitRequirement(completion:));

/// Transport for the allowlisted driver-cockpit callables (official workforce
/// driver workspace, partner driver assignments/status/presence and context
/// discovery). The completion always runs on the main queue and every call is
/// re-authorized by the backend; this is not a generic callable gateway.
- (void)callDriverCockpitFunction:(NSString *)name
                          payload:(NSDictionary<NSString *, id> *)payload
                       completion:(PPDriverCockpitCompletion)completion;

/// Chooses the company profile for the dashboard shell: the configured company,
/// else a single usable workspace. With several usable workspaces it prefers a
/// dispatch workspace (else the first) and sets requiresSelection; driver work
/// stays reachable through the cockpit's own workspace chooser. A profile whose
/// only workspace is restricted is returned last so the explanation can be
/// shown instead of unrelated provider onboarding.
- (nullable PPDeliveryCompanyProfile *)preferredProfileFromProfiles:(NSArray<PPDeliveryCompanyProfile *> *)profiles
                                                  requiresSelection:(BOOL * _Nullable)requiresSelection;

/// YES when the last membership discovery for the signed-in account found a
/// driver workspace in any company (not only the configured one).
@property (nonatomic, assign, readonly) BOOL hasDiscoveredDriverWorkspace;

@end

NS_ASSUME_NONNULL_END
