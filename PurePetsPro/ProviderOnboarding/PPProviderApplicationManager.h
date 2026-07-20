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
@property (nonatomic, strong, nullable) NSDate *submittedAt;
@property (nonatomic, strong, nullable) NSDate *reviewedAt;
@property (nonatomic, strong) NSDictionary *form;

- (NSString *)localizedPlanName;
- (NSString *)localizedPlanDescription;

@end

@interface PPProviderProfile : NSObject

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

- (NSString *)localizedPlanName;

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

@end

@interface PPProviderOnboardingState : NSObject

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

@end

NS_ASSUME_NONNULL_END
