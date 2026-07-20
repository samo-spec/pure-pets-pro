#import "PPProviderApplicationManager.h"
#import "PPFirebaseCompat.h"
#import "FUManager.h"
#import "Language.h"
#import "UserManager.h"
#import "UserModel.h"

static NSString * const kPPProviderPlansCollection = @"providerPlans";
static NSString * const kPPProviderApplicationsCollection = @"providerApplications";
static NSString * const kPPProviderProfilesCollection = @"providerProfiles";
static NSString * const kPPProviderFunctionSubmit = @"submitProviderApplication";
static NSString * const kPPProviderFunctionSubmitDeliveryCompany = @"submitDeliveryCompanyApplication";

static NSString * const kPPProviderStatusPending = @"pending";
static NSString * const kPPProviderStatusUnderReview = @"under_review";
static NSString * const kPPProviderStatusApproved = @"approved";
static NSString * const kPPProviderStatusRejected = @"rejected";
static NSString * const kPPProviderStatusArchived = @"archived";
static NSString * const kPPProviderStatusCancelled = @"cancelled";
static NSString * const kPPProviderStatusWithdrawn = @"withdrawn";
static NSString * const kPPProviderStatusExpired = @"expired";
static NSString * const kPPProviderProfileStatusActive = @"active";

NSString *PPProviderTypeIdentifier(PPProviderType type) {
    switch (type) {
        case PPProviderTypeUnspecified:
            return @"";
        case PPProviderTypePharmacy:
            return @"pharmacy";
        case PPProviderTypeVet:
            return @"vet";
        case PPProviderTypeService:
            return @"service";
        case PPProviderTypeMarketplace:
            return @"marketplace";
        case PPProviderTypeDeliveryCompany:
            return @"delivery_company";
        case PPProviderTypeDeliverySubscription:
        default:
            return @"delivery_subscription";
    }
}

PPProviderType PPProviderTypeFromIdentifier(NSString *value) {
    NSString *safeValue = [[PPSafeString(value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (safeValue.length == 0) {
        return PPProviderTypeUnspecified;
    }
    if ([safeValue isEqualToString:@"pharmacy"]) {
        return PPProviderTypePharmacy;
    }
    if ([safeValue isEqualToString:@"vet"]) {
        return PPProviderTypeVet;
    }
    if ([safeValue isEqualToString:@"service"]) {
        return PPProviderTypeService;
    }
    if ([safeValue isEqualToString:@"marketplace"]) {
        return PPProviderTypeMarketplace;
    }
    if ([safeValue isEqualToString:@"delivery_company"]) {
        return PPProviderTypeDeliveryCompany;
    }
    if ([safeValue isEqualToString:@"delivery_subscription"]) {
        return PPProviderTypeDeliverySubscription;
    }
    return PPProviderTypeUnspecified;
}

BOOL PPProviderTypeIsEnabledInProApp(PPProviderType type) {
    return type != PPProviderTypeUnspecified &&
           type != PPProviderTypeDeliverySubscription;
}

static NSString *PPProviderLocalizedText(NSDictionary *localizedDictionary) {
    NSString *arabic = PPSafeString(localizedDictionary[@"ar"]);
    NSString *english = PPSafeString(localizedDictionary[@"en"]);
    return [Language isRTL] ? (arabic.length ? arabic : english) : (english.length ? english : arabic);
}

static NSString *PPProviderNormalizedStatus(NSString *status) {
    return [[PPSafeString(status).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

static BOOL PPProviderApplicationStatusAllowsReapply(NSString *status) {
    NSString *normalized = PPProviderNormalizedStatus(status);
    if (normalized.length == 0) {
        return YES;
    }
    return [normalized isEqualToString:kPPProviderStatusRejected] ||
           [normalized isEqualToString:kPPProviderStatusArchived] ||
           [normalized isEqualToString:kPPProviderStatusCancelled] ||
           [normalized isEqualToString:kPPProviderStatusWithdrawn] ||
           [normalized isEqualToString:kPPProviderStatusExpired];
}

static NSString *PPProviderPlanFeatureTitle(NSDictionary *feature) {
    NSDictionary *title = [feature[@"title"] isKindOfClass:NSDictionary.class] ? feature[@"title"] : @{};
    NSString *localizedTitle = PPProviderLocalizedText(title);
    if (localizedTitle.length > 0) {
        return localizedTitle;
    }
    NSString *fallback = PPSafeString(feature[@"featureId"]);
    if (fallback.length == 0) {
        fallback = PPSafeString(feature[@"featureKey"]);
    }
    if (fallback.length == 0) {
        fallback = PPSafeString(feature[@"key"]);
    }
    return fallback;
}

static NSDictionary *PPProviderPlanFeatureRowFromDocument(FIRDocumentSnapshot *featureDocument) {
    NSDictionary *data = featureDocument.data ?: @{};
    id enabledValue = data[@"enabled"];
    if (enabledValue && ![PPSafeNumber(enabledValue) boolValue]) {
        return nil;
    }
    NSMutableDictionary *row = [data mutableCopy];
    row[@"_documentID"] = featureDocument.documentID ?: @"";
    return row.copy;
}

static NSArray<NSDictionary *> *PPProviderPlanFeatureRowsFromSnapshot(FIRQuerySnapshot * _Nullable snapshot) {
    NSMutableArray<NSDictionary *> *featureRows = [NSMutableArray array];
    if (!snapshot) {
        return featureRows.copy;
    }
    for (FIRDocumentSnapshot *featureDocument in snapshot.documents) {
        NSDictionary *row = PPProviderPlanFeatureRowFromDocument(featureDocument);
        if (row) {
            [featureRows addObject:row];
        }
    }
    [featureRows sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSInteger leftOrder = PPSafeIntegerUniversal(left[@"sortOrder"]);
        NSInteger rightOrder = PPSafeIntegerUniversal(right[@"sortOrder"]);
        if (leftOrder != rightOrder) {
            return leftOrder < rightOrder ? NSOrderedAscending : NSOrderedDescending;
        }
        return [PPProviderPlanFeatureTitle(left) localizedCaseInsensitiveCompare:PPProviderPlanFeatureTitle(right)];
    }];
    return featureRows.copy;
}

static NSArray<NSString *> *PPProviderPlanFeatureTitlesFromRows(NSArray<NSDictionary *> *featureRows) {
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSDictionary *feature in featureRows) {
        NSString *title = PPProviderPlanFeatureTitle(feature);
        if (title.length > 0) {
            [titles addObject:title];
        }
    }
    return titles.copy;
}

static PPProviderPlanCostType PPProviderPlanCostTypeFromValue(id value) {
    NSString *safeValue = [PPSafeString(value).lowercaseString copy];
    return [safeValue isEqualToString:@"percentage"] ? PPProviderPlanCostTypePercentage : PPProviderPlanCostTypePrice;
}

static NSString *PPProviderPlanPercentageBasisValue(id value) {
    NSString *safeValue = [PPSafeString(value).lowercaseString copy];
    if ([safeValue isEqualToString:@"product"] ||
        [safeValue isEqualToString:@"service"] ||
        [safeValue isEqualToString:@"medicine"] ||
        [safeValue isEqualToString:@"subscription"] ||
        [safeValue isEqualToString:@"custom"]) {
        return safeValue;
    }
    return @"item";
}

static NSString *PPProviderLocalizedPercentageBasis(NSString *basis, NSString *customLabel) {
    NSString *normalizedBasis = PPProviderPlanPercentageBasisValue(basis);
    NSString *trimmedCustomLabel = [PPSafeString(customLabel) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([normalizedBasis isEqualToString:@"custom"] && trimmedCustomLabel.length > 0) {
        return [Language isRTL]
            ? [NSString stringWithFormat:@"لكل %@", trimmedCustomLabel]
            : [NSString stringWithFormat:@"per %@", trimmedCustomLabel];
    }
    if ([normalizedBasis isEqualToString:@"product"]) return kLang(@"ProviderPlanPercentageBasisProduct");
    if ([normalizedBasis isEqualToString:@"service"]) return kLang(@"ProviderPlanPercentageBasisService");
    if ([normalizedBasis isEqualToString:@"medicine"]) return kLang(@"ProviderPlanPercentageBasisMedicine");
    if ([normalizedBasis isEqualToString:@"subscription"]) return kLang(@"ProviderPlanPercentageBasisSubscription");
    return kLang(@"ProviderPlanPercentageBasisItem");
}

static NSError *PPProviderError(NSString *description) {
    return [NSError errorWithDomain:@"PurePetsPro.ProviderApplication"
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: description ?: kLang(@"Error")}];
}

static BOOL PPProviderErrorContainsText(NSError *error, NSString *needle) {
    if (!error || needle.length == 0) {
        return NO;
    }
    NSString *lowerNeedle = needle.lowercaseString;
    NSArray<NSString *> *parts = @[
        error.domain ?: @"",
        error.localizedDescription ?: @"",
        error.localizedFailureReason ?: @"",
        error.localizedRecoverySuggestion ?: @"",
    ];
    for (NSString *part in parts) {
        if ([[part lowercaseString] containsString:lowerNeedle]) {
            return YES;
        }
    }
    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:NSString.class] &&
            [[(NSString *)value lowercaseString] containsString:lowerNeedle]) {
            return YES;
        }
        if ([value isKindOfClass:NSError.class] && PPProviderErrorContainsText((NSError *)value, needle)) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPProviderErrorContainsCode(NSError *error, NSString *domain, NSInteger code) {
    if (!error) {
        return NO;
    }
    BOOL domainMatches = domain.length == 0 || [error.domain isEqualToString:domain];
    if (domainMatches && error.code == code) {
        return YES;
    }
    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:NSError.class] && PPProviderErrorContainsCode((NSError *)value, domain, code)) {
            return YES;
        }
    }
    return NO;
}

static BOOL PPProviderFirestoreErrorNeedsSessionRefresh(NSError *error) {
    return PPProviderErrorContainsCode(error, FIRFirestoreErrorDomain, FIRFirestoreErrorCodePermissionDenied) ||
           PPProviderErrorContainsCode(error, FIRFirestoreErrorDomain, FIRFirestoreErrorCodeUnauthenticated) ||
           PPProviderErrorContainsText(error, @"missing or insufficient permissions") ||
           PPProviderErrorContainsText(error, @"permission-denied") ||
           PPProviderErrorContainsText(error, @"unauthenticated");
}

static BOOL PPProviderFunctionErrorIsUnauthenticated(NSError *error) {
    return error.code == FIRFunctionsErrorCodeUnauthenticated ||
           PPProviderErrorContainsText(error, @"unauthenticated");
}

static BOOL PPProviderFunctionErrorIsPermissionDenied(NSError *error) {
    return error.code == FIRFunctionsErrorCodePermissionDenied ||
           PPProviderErrorContainsText(error, @"permission-denied");
}

static BOOL PPProviderFunctionErrorIsAlreadyExists(NSError *error) {
    return error.code == FIRFunctionsErrorCodeAlreadyExists ||
           PPProviderErrorContainsText(error, @"already-exists") ||
           PPProviderErrorContainsText(error, @"already exists");
}

static NSString *PPProviderSubmitCallableName(PPProviderType providerType) {
    if (providerType == PPProviderTypeDeliveryCompany) {
        return kPPProviderFunctionSubmitDeliveryCompany;
    }
    return kPPProviderFunctionSubmit;
}

static NSDate * _Nullable PPProviderDateFromValue(id value) {
    if ([value isKindOfClass:NSDate.class]) {
        return value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return [(FIRTimestamp *)value dateValue];
    }
    return nil;
}

static BOOL PPProviderBool(id value) {
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return NO;
}

@interface PPProviderPlan ()
- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID;
@end

@implementation PPProviderPlan

- (instancetype)init {
    self = [super init];
    if (self) {
        _planID = @"";
        _status = @"";
        _name = @{};
        _planDescription = @{};
        _currency = @"QAR";
        _billingInterval = @"monthly";
        _percentageBasis = @"item";
        _percentageCustomLabel = @"";
        _platformCommissionRate = 0.0;
        _featureRows = @[];
        _features = @[];
    }
    return self;
}

- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID {
    NSDictionary *planSnapshot = [dictionary[@"planSnapshot"] isKindOfClass:NSDictionary.class] ? dictionary[@"planSnapshot"] : @{};
    self.planID = documentID ?: @"";
    self.providerType = PPProviderTypeFromIdentifier(PPSafeString(dictionary[@"providerType"]));
    self.status = PPSafeString(dictionary[@"status"]);
    self.name = PPSafeDict(dictionary[@"name"]).count ? PPSafeDict(dictionary[@"name"]) : PPSafeDict(planSnapshot[@"name"]);
    self.planDescription = PPSafeDict(dictionary[@"description"]).count ? PPSafeDict(dictionary[@"description"]) : PPSafeDict(planSnapshot[@"description"]);
    self.costType = PPProviderPlanCostTypeFromValue(dictionary[@"costType"] ?: planSnapshot[@"costType"]);
    self.costValue = PPSafeDouble(dictionary[@"costValue"]) > 0 ? PPSafeDouble(dictionary[@"costValue"]) : PPSafeDouble(planSnapshot[@"costValue"]);
    self.priceAmount = PPSafeDouble(dictionary[@"priceAmount"]) > 0 ? PPSafeDouble(dictionary[@"priceAmount"]) : PPSafeDouble(planSnapshot[@"priceAmount"]);
    self.currency = PPSafeString(dictionary[@"currency"]).length ? PPSafeString(dictionary[@"currency"]) : (PPSafeString(planSnapshot[@"currency"]).length ? PPSafeString(planSnapshot[@"currency"]) : @"QAR");
    self.billingInterval = PPSafeString(dictionary[@"billingInterval"]).length ? PPSafeString(dictionary[@"billingInterval"]) : (PPSafeString(planSnapshot[@"billingInterval"]).length ? PPSafeString(planSnapshot[@"billingInterval"]) : @"monthly");
    self.percentageBasis = PPProviderPlanPercentageBasisValue(dictionary[@"percentageBasis"] ?: planSnapshot[@"percentageBasis"]);
    self.percentageCustomLabel = PPSafeString(dictionary[@"percentageCustomLabel"]).length ? PPSafeString(dictionary[@"percentageCustomLabel"]) : PPSafeString(planSnapshot[@"percentageCustomLabel"]);
    self.platformCommissionRate = PPSafeDouble(dictionary[@"platformCommissionRate"] ?: dictionary[@"commissionRate"] ?: planSnapshot[@"platformCommissionRate"] ?: planSnapshot[@"commissionRate"]);
    self.rank = PPSafeIntegerUniversal(dictionary[@"rank"] ?: planSnapshot[@"rank"]);
    self.recommended = [PPSafeNumber(dictionary[@"recommended"] ?: planSnapshot[@"recommended"]) boolValue];
    self.features = PPSafeArray(dictionary[@"features"]).count ? PPSafeArray(dictionary[@"features"]) : PPSafeArray(planSnapshot[@"features"]);
}

- (NSString *)localizedName {
    return PPProviderLocalizedText(self.name);
}

- (NSString *)localizedDescriptionText {
    return PPProviderLocalizedText(self.planDescription);
}

- (NSString *)localizedPriceLine {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    double displayValue = self.costValue > 0.0 ? self.costValue : self.priceAmount;
    formatter.maximumFractionDigits = (fabs(displayValue - round(displayValue)) < 0.001) ? 0 : 2;
    NSString *amount = [formatter stringFromNumber:@(displayValue)] ?: @"0";

    NSString *intervalKey = @"ProviderPlanIntervalMonthly";
    if ([self.billingInterval isEqualToString:@"yearly"]) {
        intervalKey = @"ProviderPlanIntervalYearly";
    } else if ([self.billingInterval isEqualToString:@"one_time"]) {
        intervalKey = @"ProviderPlanIntervalOneTime";
    }
    if (self.costType == PPProviderPlanCostTypePercentage) {
        return [NSString stringWithFormat:@"%@%% · %@", amount, PPProviderLocalizedPercentageBasis(self.percentageBasis, self.percentageCustomLabel)];
    }
    return [NSString stringWithFormat:@"%@ %@ · %@", amount, self.currency ?: @"QAR", kLang(intervalKey)];
}

@end

@interface PPProviderApplication ()
- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID;
@end

@implementation PPProviderApplication

- (instancetype)init {
    self = [super init];
    if (self) {
        _applicationID = @"";
        _status = @"";
        _planID = @"";
        _planName = @{};
        _planDescription = @{};
        _reviewNotes = @"";
        _form = @{};
    }
    return self;
}

- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID {
    NSDictionary *planSnapshot = [dictionary[@"planSnapshot"] isKindOfClass:NSDictionary.class] ? dictionary[@"planSnapshot"] : @{};
    self.applicationID = documentID ?: @"";
    self.providerType = PPProviderTypeFromIdentifier(PPSafeString(dictionary[@"providerType"]));
    self.status = PPSafeString(dictionary[@"status"]);
    self.planID = PPSafeString(dictionary[@"planId"]);
    self.planName = PPSafeDict(planSnapshot[@"name"]);
    self.planDescription = PPSafeDict(planSnapshot[@"description"]);
    self.reviewNotes = PPSafeString(dictionary[@"reviewNotes"]);
    self.submittedAt = PPProviderDateFromValue(dictionary[@"submittedAt"]);
    self.reviewedAt = PPProviderDateFromValue(dictionary[@"reviewedAt"]);
    self.form = [dictionary[@"form"] isKindOfClass:NSDictionary.class] ? dictionary[@"form"] : @{};
}

- (NSString *)localizedPlanName {
    return PPProviderLocalizedText(self.planName);
}

- (NSString *)localizedPlanDescription {
    return PPProviderLocalizedText(self.planDescription);
}

@end

@interface PPProviderProfile ()
- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID;
@end

@implementation PPProviderProfile

- (instancetype)init {
    self = [super init];
    if (self) {
        _profileID = @"";
        _status = @"";
        _planID = @"";
        _planName = @{};
        _form = @{};
        _billingInterval = @"";
        _currency = @"QAR";
    }
    return self;
}

- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID {
    NSDictionary *planSnapshot = [dictionary[@"planSnapshot"] isKindOfClass:NSDictionary.class] ? dictionary[@"planSnapshot"] : @{};
    self.profileID = documentID ?: @"";
    self.providerType = PPProviderTypeFromIdentifier(PPSafeString(dictionary[@"providerType"]));
    self.status = PPSafeString(dictionary[@"status"]);
    self.planID = PPSafeString(dictionary[@"planId"]);
    self.planName = PPSafeDict(planSnapshot[@"name"]);
    self.form = [dictionary[@"form"] isKindOfClass:NSDictionary.class] ? dictionary[@"form"] : @{};
    self.approvedAt = PPProviderDateFromValue(dictionary[@"approvedAt"]);
    self.billingInterval = PPSafeString(planSnapshot[@"billingInterval"]);
    self.priceAmount = PPSafeDouble(planSnapshot[@"priceAmount"] ?: planSnapshot[@"costValue"]);
    self.currency = PPSafeString(planSnapshot[@"currency"]).length ? PPSafeString(planSnapshot[@"currency"]) : @"QAR";
}

- (NSString *)localizedPlanName {
    return PPProviderLocalizedText(self.planName);
}

@end

@implementation PPProviderApplicationDraft

- (instancetype)init {
    self = [super init];
    if (self) {
        _fullName = @"";
        _phone = @"";
        _email = @"";
        _businessName = @"";
        _companyName = @"";
        _legalName = @"";
        _address = @"";
    _licenseNumber = @"";
    _commercialRegistrationNumber = @"";
    _licenseDocumentURL = @"";
    _commercialRegistrationDocumentURL = @"";
    _city = @"";
        _notes = @"";
        _coverageAreas = @[];
    }
    return self;
}

@end

@implementation PPProviderOnboardingState

- (instancetype)init {
    self = [super init];
    if (self) {
        _uid = @"";
        _displayName = @"";
        _email = @"";
        _phone = @"";
        _partnerApplicationStatus = @"not_started";
        _applications = @[];
        _applicationsByType = @{};
        _profilesByType = @{};
    }
    return self;
}

- (PPProviderApplication *)applicationForType:(PPProviderType)type {
    return self.applicationsByType[PPProviderTypeIdentifier(type)];
}

- (NSArray<PPProviderApplication *> *)applicationsForType:(PPProviderType)type {
    NSMutableArray<PPProviderApplication *> *matches = [NSMutableArray array];
    for (PPProviderApplication *application in self.applications) {
        if (application.providerType == type) {
            [matches addObject:application];
        }
    }
    return matches.copy;
}

- (PPProviderApplication *)blockingApplicationForType:(PPProviderType)type planID:(NSString *)planID {
    NSString *normalizedPlanID = PPSafeString(planID);
    if (normalizedPlanID.length == 0) {
        return nil;
    }
    for (PPProviderApplication *application in [self applicationsForType:type]) {
        if ([application.planID isEqualToString:normalizedPlanID] &&
            !PPProviderApplicationStatusAllowsReapply(application.status)) {
            return application;
        }
    }
    return nil;
}

- (PPProviderProfile *)profileForType:(PPProviderType)type {
    return self.profilesByType[PPProviderTypeIdentifier(type)];
}

- (BOOL)isActiveForType:(PPProviderType)type {
    if (!PPProviderTypeIsEnabledInProApp(type)) {
        return NO;
    }
    if (type == PPProviderTypePharmacy && self.canPharmacy) {
        return YES;
    }
    if (type == PPProviderTypeVet && self.canVet) {
        return YES;
    }
    if (type == PPProviderTypeService && self.canOfferServices) {
        return YES;
    }
    if (type == PPProviderTypeMarketplace && self.canAccessProviderMarketplace) {
        return YES;
    }
    if (type == PPProviderTypeDeliveryCompany && self.canDeliveryCompany) {
        return YES;
    }
    if (type == PPProviderTypeDeliverySubscription && self.canDelivery) {
        return YES;
    }
    NSString *profileStatus = [self profileForType:type].status.lowercaseString ?: @"";
    return [profileStatus isEqualToString:kPPProviderProfileStatusActive];
}

- (BOOL)canApplyForType:(PPProviderType)type {
    if (!PPProviderTypeIsEnabledInProApp(type)) {
        return NO;
    }
    if (self.isBlocked || [self isActiveForType:type]) {
        return NO;
    }
    for (PPProviderApplication *application in [self applicationsForType:type]) {
        if (!PPProviderApplicationStatusAllowsReapply(application.status)) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)canApplyForType:(PPProviderType)type planID:(NSString *)planID {
    if (![self canApplyForType:type]) {
        return NO;
    }
    return [self blockingApplicationForType:type planID:planID] == nil;
}

- (NSArray<NSNumber *> *)eligibleProviderTypes {
    NSMutableArray<NSNumber *> *types = [NSMutableArray array];
    for (NSNumber *value in @[@(PPProviderTypeMarketplace), @(PPProviderTypeDeliveryCompany), @(PPProviderTypeVet), @(PPProviderTypePharmacy), @(PPProviderTypeDeliverySubscription), @(PPProviderTypeService)]) {
        PPProviderType type = value.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) {
            continue;
        }
        if ([self canApplyForType:type]) {
            [types addObject:value];
        }
    }
    return types.copy;
}

- (BOOL)hasAnyLifecycleRecord {
    BOOL hasDeliveryCompany = self.canDeliveryCompany;
    return self.canOfferServices ||
           hasDeliveryCompany ||
           self.canVet ||
           self.canPharmacy ||
           self.canAccessProviderMarketplace ||
           self.applications.count > 0 ||
           self.applicationsByType.count > 0 ||
           self.profilesByType.count > 0;
}

@end

@interface PPProviderCompositeRegistration : NSObject <FIRListenerRegistration>
@property (nonatomic, strong) NSMutableArray<id<FIRListenerRegistration>> *registrations;
@end

@implementation PPProviderCompositeRegistration

- (instancetype)init {
    self = [super init];
    if (self) {
        _registrations = [NSMutableArray array];
    }
    return self;
}

- (void)remove {
    for (id<FIRListenerRegistration> registration in self.registrations.copy) {
        [registration remove];
    }
    [self.registrations removeAllObjects];
}

@end

@interface PPProviderApplicationManager ()
@property (nonatomic, strong) FIRFirestore *db;
- (void)pp_fetchPlansForProviderType:(PPProviderType)providerType
                       didRefreshAuth:(BOOL)didRefreshAuth
                           completion:(void(^)(NSArray<PPProviderPlan *> * _Nullable plans, NSError * _Nullable error))completion;
- (void)pp_submitDraft:(PPProviderApplicationDraft *)draft
          selectedPlan:(PPProviderPlan *)selectedPlan
        didRefreshAuth:(BOOL)didRefreshAuth
            completion:(void(^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;
- (void)pp_refreshAuthSessionWithCompletion:(void(^)(BOOL refreshed))completion;
- (NSError *)pp_friendlyProviderPlansError:(NSError *)error;
@end

@implementation PPProviderApplicationManager

+ (instancetype)shared {
    static PPProviderApplicationManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPProviderApplicationManager alloc] initPrivate];
    });
    return manager;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (instancetype)init {
    return [PPProviderApplicationManager shared];
}

+ (NSString *)localizedTitleForProviderType:(PPProviderType)type {
    switch (type) {
        case PPProviderTypeUnspecified:
            return kLang(@"ProviderTypeSelect");
        case PPProviderTypePharmacy:
            return kLang(@"ProviderTypePharmacyTitle");
        case PPProviderTypeVet:
            return kLang(@"ProviderTypeVetTitle");
        case PPProviderTypeService:
            return kLang(@"ProviderTypeServiceTitle");
        case PPProviderTypeMarketplace:
            return kLang(@"ProviderTypeMarketplaceTitle");
        case PPProviderTypeDeliveryCompany:
            return kLang(@"ProviderTypeDeliveryCompanyTitle");
        case PPProviderTypeDeliverySubscription:
        default:
            return kLang(@"ProviderTypeDeliveryTitle");
    }
}

+ (NSString *)localizedSubtitleForProviderType:(PPProviderType)type {
    switch (type) {
        case PPProviderTypeUnspecified:
            return kLang(@"ProviderTypeSelectSubtitle");
        case PPProviderTypePharmacy:
            return kLang(@"ProviderTypePharmacySubtitle");
        case PPProviderTypeVet:
            return kLang(@"ProviderTypeVetSubtitle");
        case PPProviderTypeService:
            return kLang(@"ProviderTypeServiceSubtitle");
        case PPProviderTypeMarketplace:
            return kLang(@"ProviderTypeMarketplaceSubtitle");
        case PPProviderTypeDeliveryCompany:
            return kLang(@"ProviderTypeDeliveryCompanySubtitle");
        case PPProviderTypeDeliverySubscription:
        default:
            return kLang(@"ProviderTypeDeliverySubtitle");
    }
}

+ (NSString *)localizedStatusTitle:(NSString *)status {
    NSString *normalized = [status.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([normalized isEqualToString:kPPProviderStatusPending]) {
        return kLang(@"ProviderStatusPending");
    }
    if ([normalized isEqualToString:kPPProviderStatusUnderReview]) {
        return kLang(@"ProviderStatusUnderReview");
    }
    if ([normalized isEqualToString:kPPProviderStatusApproved]) {
        return kLang(@"ProviderStatusApproved");
    }
    if ([normalized isEqualToString:kPPProviderStatusRejected]) {
        return kLang(@"ProviderStatusRejected");
    }
    if ([normalized isEqualToString:kPPProviderStatusArchived]) {
        return kLang(@"ProviderStatusArchived");
    }
    if ([normalized isEqualToString:kPPProviderProfileStatusActive]) {
        return kLang(@"ProviderStatusActive");
    }
    return kLang(@"ProviderStatusNotApplied");
}

+ (NSString *)symbolNameForProviderType:(PPProviderType)type {
    switch (type) {
        case PPProviderTypeUnspecified:
            return @"questionmark.circle.fill";
        case PPProviderTypePharmacy:
            return @"pills.fill";
        case PPProviderTypeVet:
            return @"cross.case.fill";
        case PPProviderTypeService:
            return @"scissors";
        case PPProviderTypeMarketplace:
            return @"bag.fill";
        case PPProviderTypeDeliveryCompany:
            return @"building.2.crop.circle.fill";
        case PPProviderTypeDeliverySubscription:
        default:
            return @"shippingbox.fill";
    }
}

- (id<FIRListenerRegistration>)observeProviderStateForCurrentUser:(void(^)(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    PPProviderCompositeRegistration *token = [[PPProviderCompositeRegistration alloc] init];
    if (!authUser.uid.length) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, PPProviderError(kLang(@"Please login first")));
            });
        }
        return token;
    }

    NSMutableDictionary<NSString *, NSDictionary *> *applicationDocs = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSDictionary *> *profileDocs = [NSMutableDictionary dictionary];
    __block NSDictionary *userRoot = nil;

    __weak typeof(self) weakSelf = self;
    void (^emitState)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!completion || !self) {
            return;
        }
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        PPProviderOnboardingState *state = [self pp_buildStateForUser:authUser root:userRoot applications:applicationDocs profiles:profileDocs];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(state, nil);
        });
    };

    FIRDocumentReference *userRef = [[self.db collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    id<FIRListenerRegistration> userReg = [userRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            emitState(error);
            return;
        }
        userRoot = snapshot.exists ? (snapshot.data ?: @{}) : nil;
        emitState(nil);
    }];
    if (userReg) {
        [token.registrations addObject:userReg];
    }

    FIRQuery *applicationsQuery = [[self.db collectionWithPath:kPPProviderApplicationsCollection]
                                   queryWhereField:@"userId"
                                   isEqualTo:authUser.uid];
    id<FIRListenerRegistration> applicationsReg = [applicationsQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            emitState(error);
            return;
        }
        for (NSString *key in applicationDocs.allKeys.copy) {
            if (![key hasPrefix:@"legacy:"]) {
                [applicationDocs removeObjectForKey:key];
            }
        }
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            if (document.exists) {
                applicationDocs[document.documentID ?: @""] = document.data ?: @{};
            }
        }
        emitState(nil);
    }];
    if (applicationsReg) {
        [token.registrations addObject:applicationsReg];
    }

    for (NSNumber *typeNumber in @[@(PPProviderTypeVet), @(PPProviderTypePharmacy), @(PPProviderTypeDeliverySubscription), @(PPProviderTypeDeliveryCompany), @(PPProviderTypeService), @(PPProviderTypeMarketplace)]) {
        PPProviderType type = typeNumber.integerValue;
        if (!PPProviderTypeIsEnabledInProApp(type)) {
            continue;
        }
        NSString *typeIdentifier = PPProviderTypeIdentifier(type);
        NSString *documentID = [NSString stringWithFormat:@"%@_%@", authUser.uid, typeIdentifier];
        NSString *legacyApplicationKey = [NSString stringWithFormat:@"legacy:%@", documentID];

        FIRDocumentReference *applicationRef = [[self.db collectionWithPath:kPPProviderApplicationsCollection] documentWithPath:documentID];
        id<FIRListenerRegistration> applicationReg = [applicationRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                [applicationDocs removeObjectForKey:legacyApplicationKey];
                emitState(nil);
                return;
            }
            if (snapshot.exists) {
                applicationDocs[legacyApplicationKey] = snapshot.data ?: @{};
            } else {
                [applicationDocs removeObjectForKey:legacyApplicationKey];
            }
            emitState(nil);
        }];
        if (applicationReg) {
            [token.registrations addObject:applicationReg];
        }

        FIRDocumentReference *profileRef = [[self.db collectionWithPath:kPPProviderProfilesCollection] documentWithPath:documentID];
        id<FIRListenerRegistration> profileReg = [profileRef addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                [profileDocs removeObjectForKey:typeIdentifier];
                emitState(nil);
                return;
            }
            if (snapshot.exists) {
                profileDocs[typeIdentifier] = snapshot.data ?: @{};
            } else {
                [profileDocs removeObjectForKey:typeIdentifier];
            }
            emitState(nil);
        }];
        if (profileReg) {
            [token.registrations addObject:profileReg];
        }
    }

    return token;
}

- (void)fetchPlansForProviderType:(PPProviderType)providerType
                       completion:(void(^)(NSArray<PPProviderPlan *> * _Nullable plans, NSError * _Nullable error))completion {
    if (!PPProviderTypeIsEnabledInProApp(providerType)) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[], nil);
            });
        }
        return;
    }
    [self pp_fetchPlansForProviderType:providerType didRefreshAuth:NO completion:completion];
}

- (void)pp_fetchPlansForProviderType:(PPProviderType)providerType
                       didRefreshAuth:(BOOL)didRefreshAuth
                           completion:(void(^)(NSArray<PPProviderPlan *> * _Nullable plans, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, PPProviderError(kLang(@"ProviderPlansSessionFailed")));
            });
        }
        return;
    }

    FIRQuery *query = [[self.db collectionWithPath:kPPProviderPlansCollection]
                       queryWhereField:@"providerType"
                       isEqualTo:PPProviderTypeIdentifier(providerType)];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            if (!didRefreshAuth && PPProviderFirestoreErrorNeedsSessionRefresh(error)) {
                [self pp_refreshAuthSessionWithCompletion:^(BOOL refreshed) {
                    if (refreshed) {
                        [self pp_fetchPlansForProviderType:providerType didRefreshAuth:YES completion:completion];
                    } else if (completion) {
                        completion(nil, [self pp_friendlyProviderPlansError:error]);
                    }
                }];
                return;
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, [self pp_friendlyProviderPlansError:error]);
                });
            }
            return;
        }

        NSMutableArray<PPProviderPlan *> *plans = [NSMutableArray array];
        dispatch_group_t featureGroup = dispatch_group_create();
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            NSDictionary *data = document.data ?: @{};
            NSString *status = PPSafeString(data[@"status"]).lowercaseString;
            if (![status isEqualToString:@"active"]) {
                continue;
            }
            PPProviderPlan *plan = [[PPProviderPlan alloc] init];
            [plan pp_populateWithDictionary:data documentID:document.documentID];
            [plans addObject:plan];

            dispatch_group_enter(featureGroup);
            [[document.reference collectionWithPath:@"features"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable featureSnapshot, NSError * _Nullable featureError) {
                if (!featureError) {
                    NSArray<NSDictionary *> *featureRows = PPProviderPlanFeatureRowsFromSnapshot(featureSnapshot);
                    plan.featureRows = featureRows;
                    NSArray<NSString *> *featureTitles = PPProviderPlanFeatureTitlesFromRows(featureRows);
                    if (featureTitles.count > 0) {
                        plan.features = featureTitles;
                    } else if (featureSnapshot && featureSnapshot.documents.count > 0) {
                        plan.features = @[];
                    }
                }
                dispatch_group_leave(featureGroup);
            }];
        }

        void (^finish)(void) = ^{
            [plans sortUsingComparator:^NSComparisonResult(PPProviderPlan *obj1, PPProviderPlan *obj2) {
            if (obj1.recommended != obj2.recommended) {
                return obj1.recommended ? NSOrderedAscending : NSOrderedDescending;
            }
            if (obj1.rank != obj2.rank) {
                return obj1.rank < obj2.rank ? NSOrderedAscending : NSOrderedDescending;
            }
            double leftCost = obj1.costValue > 0.0 ? obj1.costValue : obj1.priceAmount;
            double rightCost = obj2.costValue > 0.0 ? obj2.costValue : obj2.priceAmount;
            if (fabs(leftCost - rightCost) > 0.001) {
                return leftCost < rightCost ? NSOrderedAscending : NSOrderedDescending;
            }
            return [obj1.localizedName localizedCaseInsensitiveCompare:obj2.localizedName];
            }];

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(plans.copy, nil);
                });
            }
        };

        dispatch_group_notify(featureGroup, dispatch_get_main_queue(), finish);
    }];
}

- (void)pp_refreshAuthSessionWithCompletion:(void(^)(BOOL refreshed))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
        }
        return;
    }

    [authUser getIDTokenForcingRefresh:YES completion:^(NSString * _Nullable token, NSError * _Nullable error) {
        BOOL refreshed = (token.length > 0 && error == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(refreshed);
            }
        });
    }];
}

- (NSError *)pp_friendlyProviderPlansError:(NSError *)error {
    if (PPProviderFirestoreErrorNeedsSessionRefresh(error)) {
        return PPProviderError(kLang(@"ProviderPlansSessionFailed"));
    }
    return PPProviderError(kLang(@"ProviderPlansLoadFailed"));
}

- (NSError * _Nullable)validateDraft:(PPProviderApplicationDraft *)draft
                        selectedPlan:(PPProviderPlan * _Nullable)selectedPlan {
    if (draft.providerType == PPProviderTypeUnspecified) {
        return PPProviderError(kLang(@"ProviderTypeRequired"));
    }
    if (!PPProviderTypeIsEnabledInProApp(draft.providerType)) {
        return PPProviderError(kLang(@"ProviderTypeRequired"));
    }
    if (!selectedPlan) {
        return PPProviderError(kLang(@"ProviderPlanRequired"));
    }
    if (PPSafeString(draft.fullName).length == 0) {
        return PPProviderError(kLang(@"ProviderFullNameRequired"));
    }
    if (PPSafeString(draft.phone).length == 0) {
        return PPProviderError(kLang(@"ProviderPhoneRequired"));
    }
    if (PPSafeString(draft.city).length == 0) {
        return PPProviderError(kLang(@"ProviderCityRequired"));
    }
    if (draft.providerType == PPProviderTypeService && PPSafeString(draft.businessName).length == 0) {
        return PPProviderError(kLang(@"ProviderBusinessNameRequired"));
    }
    if (draft.providerType == PPProviderTypeDeliveryCompany) {
        if (PPSafeString(draft.companyName).length == 0) {
            return PPProviderError(kLang(@"ProviderCompanyNameRequired"));
        }
        if (PPSafeString(draft.legalName).length == 0) {
            return PPProviderError(kLang(@"ProviderLegalNameRequired"));
        }
        if (PPSafeString(draft.address).length == 0) {
            return PPProviderError(kLang(@"ProviderAddressRequired"));
        }
    }
    return nil;
}

- (void)submitDraft:(PPProviderApplicationDraft *)draft
       selectedPlan:(PPProviderPlan *)selectedPlan
         completion:(void(^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    NSError *validationError = [self validateDraft:draft selectedPlan:selectedPlan];
    if (validationError) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, validationError);
            });
        }
        return;
    }

    [self pp_submitDraft:draft selectedPlan:selectedPlan didRefreshAuth:NO completion:completion];
}

- (void)pp_submitDraft:(PPProviderApplicationDraft *)draft
          selectedPlan:(PPProviderPlan *)selectedPlan
        didRefreshAuth:(BOOL)didRefreshAuth
            completion:(void(^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:PPProviderSubmitCallableName(draft.providerType)];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"providerType": PPProviderTypeIdentifier(draft.providerType),
        @"planId": selectedPlan.planID ?: @"",
        @"form": @{
            @"fullName": PPSafeString(draft.fullName),
            @"phone": PPSafeString(draft.phone),
            @"email": PPSafeString(draft.email),
            @"businessName": PPSafeString(draft.businessName),
            @"companyName": PPSafeString(draft.companyName),
            @"legalName": PPSafeString(draft.legalName),
            @"address": PPSafeString(draft.address),
            @"licenseNumber": PPSafeString(draft.licenseNumber),
            @"commercialRegistrationNumber": PPSafeString(draft.commercialRegistrationNumber),
            @"licenseDocumentURL": PPSafeString(draft.licenseDocumentURL),
            @"commercialRegistrationDocumentURL": PPSafeString(draft.commercialRegistrationDocumentURL),
            @"city": PPSafeString(draft.city),
            @"notes": PPSafeString(draft.notes),
            @"coverageAreas": draft.coverageAreas ?: @[],
        },
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (!didRefreshAuth && PPProviderFunctionErrorIsUnauthenticated(error)) {
                    [self pp_refreshAuthSessionWithCompletion:^(BOOL refreshed) {
                        if (refreshed) {
                            [self pp_submitDraft:draft selectedPlan:selectedPlan didRefreshAuth:YES completion:completion];
                        } else if (completion) {
                            completion(nil, [self pp_friendlyFunctionsError:error]);
                        }
                    }];
                    return;
                }
                if (completion) {
                    completion(nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            if (completion) {
                completion([result.data isKindOfClass:NSDictionary.class] ? result.data : @{}, nil);
            }
        });
    }];
}

- (PPProviderOnboardingState *)pp_buildStateForUser:(FIRUser *)authUser
                                               root:(NSDictionary * _Nullable)root
                                       applications:(NSDictionary<NSString *, NSDictionary *> *)applicationDocs
                                           profiles:(NSDictionary<NSString *, NSDictionary *> *)profileDocs {
    PPProviderOnboardingState *state = [[PPProviderOnboardingState alloc] init];
    UserModel *cachedUser = UserManager.shared.currentUser;

    NSDictionary *safeRoot = [root isKindOfClass:NSDictionary.class] ? root : @{};
    NSDictionary *features = [safeRoot[@"features"] isKindOfClass:NSDictionary.class] ? safeRoot[@"features"] : safeRoot;

    state.uid = authUser.uid ?: @"";
    state.displayName = PPSafeString(safeRoot[@"displayName"]).length ? PPSafeString(safeRoot[@"displayName"]) :
                        (PPSafeString(safeRoot[@"UserName"]).length ? PPSafeString(safeRoot[@"UserName"]) :
                         (PPSafeString(cachedUser.UserName).length ? PPSafeString(cachedUser.UserName) :
                          PPSafeString(authUser.displayName)));
    state.email = PPSafeString(safeRoot[@"email"]).length ? PPSafeString(safeRoot[@"email"]) :
                  (PPSafeString(safeRoot[@"UserEmail"]).length ? PPSafeString(safeRoot[@"UserEmail"]) :
                   (PPSafeString(cachedUser.UserEmail).length ? PPSafeString(cachedUser.UserEmail) :
                    PPSafeString(authUser.email)));
    state.phone = PPSafeString(safeRoot[@"MobileNo"]).length ? PPSafeString(safeRoot[@"MobileNo"]) :
                  (PPSafeString(safeRoot[@"phone"]).length ? PPSafeString(safeRoot[@"phone"]) :
                   PPSafeString(cachedUser.MobileNo));
    NSString *accountStatus = [PPSafeString(safeRoot[@"accountStatus"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    state.isBlocked = [PPSafeNumber(safeRoot[@"isBlocked"]) boolValue] ||
                      [PPSafeNumber(safeRoot[@"blocked"]) boolValue] ||
                      [PPSafeNumber(safeRoot[@"isDeleted"]) boolValue] ||
                      [accountStatus isEqualToString:@"blocked"] ||
                      [accountStatus isEqualToString:@"disabled"];
    state.canOfferServices = [PPSafeNumber(features[@"canOfferServices"]) boolValue] || [PPSafeNumber(features[@"service_provider"]) boolValue] || cachedUser.canOfferServices || cachedUser.canOfferServicesFeature;
    state.canDelivery = [PPSafeNumber(features[@"canDelivery"]) boolValue] || [PPSafeNumber(features[@"delivery"]) boolValue] || cachedUser.canDelivery || cachedUser.canDeliveryFeature;
    state.canDeliveryCompany = [PPSafeNumber(features[@"canDeliveryCompany"]) boolValue];
    state.canVet = [PPSafeNumber(features[@"canVet"]) boolValue] || [PPSafeNumber(features[@"vet"]) boolValue] || cachedUser.canVetFeature;
    state.canPharmacy = [PPSafeNumber(features[@"canPharmacy"]) boolValue] || [PPSafeNumber(features[@"pharmacy"]) boolValue] || cachedUser.canPharmacyFeature;
    state.canAccessProviderMarketplace = [PPSafeNumber(features[@"canAccessProviderMarketplace"]) boolValue] || cachedUser.canAccessProviderMarketplaceFeature;
    NSDictionary *onboarding = [safeRoot[@"onboarding"] isKindOfClass:NSDictionary.class] ? safeRoot[@"onboarding"] : @{};
    NSDictionary *partnerRoot = onboarding.count > 0 ? onboarding : safeRoot;
    state.partnerOnboardingVisible = [PPSafeNumber(partnerRoot[@"partnerOnboardingVisible"]) boolValue] || cachedUser.partnerOnboardingVisible;
    NSString *partnerStatus = [PPSafeString(partnerRoot[@"partnerApplicationStatus"]).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    state.partnerApplicationStatus = partnerStatus.length > 0 ? partnerStatus : PPSafeString(cachedUser.partnerApplicationStatus);
    if (state.partnerApplicationStatus.length == 0) {
        state.partnerApplicationStatus = @"not_started";
    }

    NSMutableDictionary<NSString *, PPProviderApplication *> *applicationsByID = [NSMutableDictionary dictionary];
    [applicationDocs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, __unused BOOL *stop) {
        NSString *documentID = [key hasPrefix:@"legacy:"] ? [key substringFromIndex:@"legacy:".length] : key;
        PPProviderApplication *application = [[PPProviderApplication alloc] init];
        [application pp_populateWithDictionary:obj documentID:documentID];
        if (application.providerType == PPProviderTypeDeliverySubscription) {
            return;
        }
        if (application.applicationID.length > 0) {
            applicationsByID[application.applicationID] = application;
        }
    }];
    NSMutableArray<PPProviderApplication *> *applications = [applicationsByID.allValues mutableCopy];
    [applications sortUsingComparator:^NSComparisonResult(PPProviderApplication *left, PPProviderApplication *right) {
        NSTimeInterval leftTime = left.submittedAt ? left.submittedAt.timeIntervalSince1970 : 0.0;
        NSTimeInterval rightTime = right.submittedAt ? right.submittedAt.timeIntervalSince1970 : 0.0;
        if (fabs(leftTime - rightTime) > 0.001) {
            return leftTime > rightTime ? NSOrderedAscending : NSOrderedDescending;
        }
        return [left.applicationID localizedCaseInsensitiveCompare:right.applicationID];
    }];
    state.applications = applications.copy;

    NSMutableDictionary<NSString *, PPProviderApplication *> *applicationsByType = [NSMutableDictionary dictionary];
    for (PPProviderApplication *application in state.applications) {
        NSString *typeIdentifier = PPProviderTypeIdentifier(application.providerType);
        PPProviderApplication *current = applicationsByType[typeIdentifier];
        if (!current ||
            (!PPProviderApplicationStatusAllowsReapply(application.status) && PPProviderApplicationStatusAllowsReapply(current.status)) ||
            ((application.submittedAt ?: NSDate.distantPast).timeIntervalSince1970 > (current.submittedAt ?: NSDate.distantPast).timeIntervalSince1970)) {
            applicationsByType[typeIdentifier] = application;
        }
    }
    state.applicationsByType = applicationsByType.copy;

    NSMutableDictionary<NSString *, PPProviderProfile *> *profilesByType = [NSMutableDictionary dictionary];
    [profileDocs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, __unused BOOL *stop) {
        PPProviderProfile *profile = [[PPProviderProfile alloc] init];
        NSString *documentID = [NSString stringWithFormat:@"%@_%@", state.uid ?: authUser.uid ?: @"", key];
        [profile pp_populateWithDictionary:obj documentID:documentID];
        if (profile.providerType == PPProviderTypeDeliverySubscription) {
            return;
        }
        profilesByType[key] = profile;
    }];
    state.profilesByType = profilesByType.copy;

    return state;
}

- (NSError *)pp_friendlyFunctionsError:(NSError *)error {
    NSDictionary *details = nil;
    NSDictionary *userInfo = error.userInfo;
    id rawDetails = [userInfo objectForKey:@"details"];
    if ([rawDetails isKindOfClass:NSDictionary.class]) {
        details = (NSDictionary *)rawDetails;
    }

    NSString *message = PPSafeString(details[@"message"]);
    NSString *code = PPSafeString(details[@"status"]);
    if (message.length == 0 || [message caseInsensitiveCompare:@"INTERNAL"] == NSOrderedSame) {
        message = error.localizedDescription;
    }
    if (code.length == 0) {
        code = PPSafeString(userInfo[@"code"]);
    }
    if (PPProviderFunctionErrorIsUnauthenticated(error)) {
        message = kLang(@"ProviderSubmitSessionFailed");
    } else if (PPProviderFunctionErrorIsAlreadyExists(error)) {
        message = kLang(@"ProviderSubmitDuplicate");
    } else if (PPProviderErrorContainsText(error, @"blocked accounts cannot submit") ||
               PPProviderErrorContainsText(error, @"blocked account")) {
        message = kLang(@"ProviderSubmitBlocked");
    } else if (PPProviderFunctionErrorIsPermissionDenied(error)) {
        NSString *lowerMessage = message.lowercaseString ?: @"";
        message = (message.length > 0 &&
                   ![lowerMessage containsString:@"permission"] &&
                   ![lowerMessage containsString:@"denied"])
            ? message
            : kLang(@"ProviderSubmitPermissionFailed");
    }
    if (error.code == FIRFunctionsErrorCodeInternal ||
        [code caseInsensitiveCompare:@"internal"] == NSOrderedSame ||
        [message caseInsensitiveCompare:@"INTERNAL"] == NSOrderedSame ||
        [message caseInsensitiveCompare:@"internal"] == NSOrderedSame) {
        message = kLang(@"ProviderSubmitFailed");
    }

    return PPProviderError(message);
}

@end
