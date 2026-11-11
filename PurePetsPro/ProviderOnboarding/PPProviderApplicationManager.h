#import <Foundation/Foundation.h>

@protocol FIRListenerRegistration;
@class PPProviderApplication;
@class PPProviderPlan;
@class PPProviderProfile;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPProviderPlanCostType) {
    PPProviderPlanCostTypePrice = 0,
    PPProviderPlanCostTypePercentage = 1,
};

typedef NS_ENUM(NSInteger, PPProviderType) {
    PPProviderTypeUnspecified = -1,
    PPProviderTypeDeliverySubscription = 0,
    PPProviderTypeService = 1,
    PPProviderTypeVet = 2,
    PPProviderTypePharmacy = 3,
    PPProviderTypeMarketplace = 4,
    PPProviderTypeDeliveryCompany = 5,
};

FOUNDATION_EXPORT NSString *PPProviderTypeIdentifier(PPProviderType type);
FOUNDATION_EXPORT PPProviderType PPProviderTypeFromIdentifier(NSString *value);
FOUNDATION_EXPORT BOOL PPProviderTypeIsEnabledInProApp(PPProviderType type);

@interface PPProviderPlan : NSObject

@property (nonatomic, copy) NSString *planID;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, strong) NSDictionary *name;
@property (nonatomic, strong) NSDictionary *planDescription;
@property (nonatomic, assign) PPProviderPlanCostType costType;
@property (nonatomic, assign) double costValue;
@property (nonatomic, assign) double priceAmount;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy) NSString *billingInterval;
@property (nonatomic, copy) NSString *percentageBasis;
@property (nonatomic, copy) NSString *percentageCustomLabel;
@property (nonatomic, assign) double platformCommissionRate;
@property (nonatomic, assign) NSInteger rank;
@property (nonatomic, assign) BOOL recommended;
@property (nonatomic, copy) NSArray<NSDictionary *> *featureRows;
@property (nonatomic, copy) NSArray<NSString *> *features;

- (NSString *)localizedName;
- (NSString *)localizedDescriptionText;
- (NSString *)localizedPriceLine;

@end

@interface PPProviderApplication : NSObject

@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *planID;
@property (nonatomic, strong) NSDictionary *planName;
@property (nonatomic, strong) NSDictionary *planDescription;
@property (nonatomic, copy) NSString *reviewNotes;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *reviewFindings;
@property (nonatomic, copy, nullable) NSString *rejectionReason;
@property (nonatomic, copy, nullable) NSString *rejectionCode;
@property (nonatomic, assign) NSInteger resubmissionCount;
@property (nonatomic, strong, nullable) NSDate *submittedAt;
@property (nonatomic, strong, nullable) NSDate *reviewedAt;
@property (nonatomic, strong) NSDictionary *form;

- (NSString *)localizedPlanName;
- (NSString *)localizedPlanDescription;
- (BOOL)isUnderReview;
- (BOOL)isChangesRequested;
- (BOOL)isRejected;
- (BOOL)isApproved;
- (BOOL)isSetupRequired;
- (BOOL)isReadyForActivation;

@property (nonatomic, copy, nullable) NSString *operationalState;
@property (nonatomic, copy, nullable) NSString *setupState;
@property (nonatomic, strong, nullable) NSDictionary *activationChecklist;
@property (nonatomic, strong, nullable) NSDictionary *documents;

- (NSArray<NSDictionary *> *)expiringDocumentsWithinDays:(NSInteger)days;

@end

@interface PPProviderProfile : NSObject

@property (nonatomic, copy) NSDictionary *subscription;
- (BOOL)hasManagedSubscription;
- (NSString *)effectiveSubscriptionStatus;
- (nullable NSDate *)subscriptionExpiresAt;
- (NSString *)localizedSubscriptionSummary;

@property (nonatomic, copy) NSString *profileID;
@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *planID;
@property (nonatomic, strong) NSDictionary *planName;
@property (nonatomic, strong) NSDictionary *form;
@property (nonatomic, strong, nullable) NSDate *approvedAt;
@property (nonatomic, copy) NSString *billingInterval;
@property (nonatomic, assign) double priceAmount;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy, nullable) NSString *operationalState;
@property (nonatomic, copy, nullable) NSString *setupState;
@property (nonatomic, strong, nullable) NSDictionary *activationChecklist;
@property (nonatomic, strong, nullable) NSDictionary *documents;
@property (nonatomic, strong, nullable) NSDictionary *profileDomains;
@property (nonatomic, copy, nullable) NSString *maskedIban;

@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *restrictions;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *activeRestrictions;

- (NSString *)localizedPlanName;
- (BOOL)isSetupRequired;
- (BOOL)isReadyForActivation;
- (BOOL)isRestricted;
- (BOOL)isSuspended;
- (nullable NSDictionary *)primaryActiveRestriction;
- (BOOL)isSellingBlocked;
- (BOOL)areNewOrdersBlocked;
- (BOOL)arePayoutsBlocked;
- (NSArray<NSDictionary *> *)expiringDocumentsWithinDays:(NSInteger)days;
- (nullable NSDictionary *)publicProfile;
- (nullable NSDictionary *)operationalProfile;
- (nullable NSDictionary *)legalProfile;
- (nullable NSDictionary *)financialProfile;

@end

@interface PPProviderApplicationDraft : NSObject

@property (nonatomic, assign) PPProviderType providerType;
@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *businessName;
@property (nonatomic, copy) NSString *companyName;
@property (nonatomic, copy) NSString *legalName;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *licenseNumber;
@property (nonatomic, copy) NSString *commercialRegistrationNumber;
@property (nonatomic, copy) NSString *licenseDocumentURL;
@property (nonatomic, copy) NSString *commercialRegistrationDocumentURL;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSArray<NSString *> *coverageAreas;
@property (nonatomic, copy, nullable) NSString *selectedPlanId;
@property (nonatomic, copy, nullable) NSArray<NSString *> *selectedCapabilities;
@property (nonatomic, copy, nullable) NSString *logoURL;
@property (nonatomic, copy, nullable) NSString *coverURL;
@property (nonatomic, copy, nullable) NSString *descriptionText;
@property (nonatomic, copy, nullable) NSString *idempotencyKey;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

@interface PPProviderOnboardingState : NSObject

/// Automatic application presentation requires server-observed initial data.
@property (nonatomic, assign) BOOL initialDataAuthoritative;

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, assign) BOOL isBlocked;
@property (nonatomic, assign) BOOL canOfferServices;
@property (nonatomic, assign) BOOL canDelivery;
@property (nonatomic, assign) BOOL canDeliveryCompany;
@property (nonatomic, assign) BOOL canVet;
@property (nonatomic, assign) BOOL canPharmacy;
@property (nonatomic, assign) BOOL canAccessProviderMarketplace;
@property (nonatomic, assign) BOOL partnerOnboardingVisible;
@property (nonatomic, copy) NSString *partnerApplicationStatus;
@property (nonatomic, copy, nullable) NSString *operationalState;
@property (nonatomic, copy, nullable) NSString *setupState;
@property (nonatomic, strong, nullable) NSDictionary *activationChecklist;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *activeRestrictions;
@property (nonatomic, copy) NSArray<PPProviderApplication *> *applications;
@property (nonatomic, strong) NSDictionary<NSString *, PPProviderApplication *> *applicationsByType;
@property (nonatomic, strong) NSDictionary<NSString *, PPProviderProfile *> *profilesByType;

- (nullable PPProviderApplication *)applicationForType:(PPProviderType)type;
- (NSArray<PPProviderApplication *> *)applicationsForType:(PPProviderType)type;
- (nullable PPProviderApplication *)blockingApplicationForType:(PPProviderType)type planID:(NSString *)planID;
- (nullable PPProviderProfile *)profileForType:(PPProviderType)type;
- (BOOL)isActiveForType:(PPProviderType)type;
- (BOOL)canApplyForType:(PPProviderType)type;
- (BOOL)canApplyForType:(PPProviderType)type planID:(NSString *)planID;
- (BOOL)isSetupRequired;
- (BOOL)isReadyForActivation;
- (BOOL)isRestricted;
- (BOOL)isSuspended;
- (NSArray<NSNumber *> *)eligibleProviderTypes;
- (BOOL)hasAnyLifecycleRecord;

@end

@interface PPProviderApplicationManager : NSObject

+ (instancetype)shared;

+ (NSString *)localizedTitleForProviderType:(PPProviderType)type;
+ (NSString *)localizedSubtitleForProviderType:(PPProviderType)type;
+ (NSString *)localizedStatusTitle:(NSString *)status;
+ (NSString *)symbolNameForProviderType:(PPProviderType)type;

- (id<FIRListenerRegistration>)observeProviderStateForCurrentUser:(void(^)(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error))completion;
- (void)fetchPlansForProviderType:(PPProviderType)providerType
                       completion:(void(^)(NSArray<PPProviderPlan *> * _Nullable plans, NSError * _Nullable error))completion;
- (NSError * _Nullable)validateDraft:(PPProviderApplicationDraft *)draft
                        selectedPlan:(PPProviderPlan * _Nullable)selectedPlan;
- (void)submitDraft:(PPProviderApplicationDraft *)draft
       selectedPlan:(PPProviderPlan *)selectedPlan
         completion:(void(^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;

- (void)updateChecklistProgressForKey:(NSString *)key
                            completed:(BOOL)completed
                           completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

- (void)activatePartnerAccountWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion;
- (void)updateProfileDomain:(NSString *)domain
                      patch:(NSDictionary *)patch
            expectedVersion:(nullable NSNumber *)expectedVersion
                 completion:(void(^)(BOOL success, NSDictionary * _Nullable result, NSError * _Nullable error))completion;
- (void)fetchProfileDomain:(NSString *)domain
                completion:(void(^)(NSDictionary * _Nullable domainData, NSError * _Nullable error))completion;

- (void)fetchSyncSnapshotWithClientVersion:(nullable NSNumber *)clientVersion
                                completion:(void(^)(BOOL inSync, BOOL catchUpRequired, NSDictionary * _Nullable snapshot, NSError * _Nullable error))completion;
- (void)reconcileReadModelsWithServer:(void(^)(BOOL reconciled, NSError * _Nullable error))completion;

- (void)fetchRestrictionsSummary:(void(^)(NSDictionary * _Nullable summary, NSError * _Nullable error))completion;

- (void)submitReactivationRequestWithActionTaken:(NSString *)actionTaken
                                  actionTakenAr:(nullable NSString *)actionTakenAr
                              evidenceDocuments:(NSArray<NSDictionary *> *)documents
                                   partnerNotes:(nullable NSString *)notes
                                  restrictionId:(nullable NSString *)restrictionId
                                expectedVersion:(nullable NSNumber *)expectedVersion
                                 idempotencyKey:(nullable NSString *)idempotencyKey
                                     completion:(void(^)(BOOL success, NSDictionary * _Nullable response, NSError * _Nullable error))completion;

- (void)fetchReactivationDossierWithCompletion:(void(^)(NSDictionary * _Nullable dossier, NSError * _Nullable error))completion;

- (void)initiateVoluntaryOffboardingWithReasonCode:(NSString *)reasonCode
                                           reason:(NSString *)reason
                                         reasonAr:(nullable NSString *)reasonAr
                                  expectedVersion:(nullable NSNumber *)expectedVersion
                                   idempotencyKey:(nullable NSString *)idempotencyKey
                                       completion:(void(^)(BOOL success, NSDictionary * _Nullable response, NSError * _Nullable error))completion;

- (void)fetchOffboardingDossierWithCompletion:(void(^)(NSDictionary * _Nullable dossier, NSError * _Nullable error))completion;

- (void)fetchPartnerAuditTrailWithLimit:(nullable NSNumber *)limit
                         filterCategory:(nullable NSString *)filterCategory
                             completion:(void(^)(BOOL success, NSArray<NSDictionary *> * _Nullable entries, NSDictionary * _Nullable verification, NSError * _Nullable error))completion;

- (void)exportPrivacyDataWithCompletion:(void(^)(BOOL success, NSDictionary * _Nullable exportData, NSError * _Nullable error))completion;

- (void)fetchCockpitSummaryWithClientEtag:(nullable NSString *)clientEtag
                             forceRefresh:(BOOL)forceRefresh
                               completion:(void(^)(BOOL notModified, NSDictionary * _Nullable cockpit, NSString * _Nullable etag, NSNumber * _Nullable generation, NSError * _Nullable error))completion;

- (void)saveDraft:(PPProviderApplicationDraft *)draft forProviderType:(PPProviderType)providerType;
- (nullable PPProviderApplicationDraft *)savedDraftForProviderType:(PPProviderType)providerType;
- (void)clearDraftForProviderType:(PPProviderType)providerType;

@end

NS_ASSUME_NONNULL_END
