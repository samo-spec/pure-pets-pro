#import "PPProviderApplicationManager.h"
#import <math.h>
#import "PPFirebaseCompat.h"
#if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>)
#import <FirebaseAppCheck/FirebaseAppCheck.h>
#define PP_FIREBASE_APP_CHECK_IMPORTED 1
#elif __has_include(<FirebaseAppCheck/FirebaseAppCheck-Swift.h>)
#import <FirebaseAppCheck/FirebaseAppCheck-Swift.h>
#define PP_FIREBASE_APP_CHECK_IMPORTED 1
#endif
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
static NSString * const kPPProviderStatusChangesRequested = @"changes_requested";
static NSString * const kPPProviderStatusResubmitted = @"resubmitted";
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
    self.subscriptionPlanHash = PPSafeString(dictionary[@"planHash"]);
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
        _reviewFindings = @[];
        _rejectionReason = @"";
        _rejectionCode = @"";
        _resubmissionCount = 0;
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
    self.reviewFindings = [dictionary[@"reviewFindings"] isKindOfClass:NSArray.class] ? dictionary[@"reviewFindings"] : @[];
    self.rejectionReason = PPSafeString(dictionary[@"rejectionReason"]);
    self.rejectionCode = PPSafeString(dictionary[@"rejectionCode"]);
    self.resubmissionCount = PPSafeIntegerUniversal(dictionary[@"resubmissionCount"]);
    self.submittedAt = PPProviderDateFromValue(dictionary[@"submittedAt"]);
    self.reviewedAt = PPProviderDateFromValue(dictionary[@"reviewedAt"]);
    self.form = [dictionary[@"form"] isKindOfClass:NSDictionary.class] ? dictionary[@"form"] : @{};
    self.operationalState = PPSafeString(dictionary[@"operationalState"]);
    self.setupState = PPSafeString(dictionary[@"setupState"]);
    self.activationChecklist = [dictionary[@"activationChecklist"] isKindOfClass:NSDictionary.class] ? dictionary[@"activationChecklist"] : @{};
    self.documents = [dictionary[@"documents"] isKindOfClass:NSDictionary.class] ? dictionary[@"documents"] : @{};
}

- (NSArray<NSDictionary *> *)expiringDocumentsWithinDays:(NSInteger)days {
    NSMutableArray<NSDictionary *> *expiring = [NSMutableArray array];
    NSDate *now = [NSDate date];
    NSTimeInterval maxInterval = (days > 0 ? days : 30) * 86400.0;

    [self.documents enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:NSDictionary.class]) return;
        NSDictionary *doc = (NSDictionary *)obj;
        NSString *expiryStr = PPSafeString(doc[@"expiryDate"]);
        if (expiryStr.length == 0) expiryStr = PPSafeString(doc[@"expiresAt"]);
        if (expiryStr.length == 0) return;

        NSDate *expiryDate = PPProviderDateFromValue(expiryStr);
        if (!expiryDate) return;

        NSTimeInterval diff = [expiryDate timeIntervalSinceDate:now];
        if (diff <= maxInterval) {
            NSInteger daysRemaining = (NSInteger)ceil(diff / 86400.0);
            if (daysRemaining < 0) daysRemaining = 0;
            NSMutableDictionary *entry = [doc mutableCopy];
            entry[@"key"] = key;
            entry[@"daysRemaining"] = @(daysRemaining);
            entry[@"isExpired"] = @(diff <= 0);
            [expiring addObject:entry];
        }
    }];

    [expiring sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"daysRemaining"] compare:b[@"daysRemaining"]];
    }];
    return expiring.copy;
}

- (NSString *)localizedPlanName {
    return PPProviderLocalizedText(self.planName);
}

- (NSString *)localizedPlanDescription {
    return PPProviderLocalizedText(self.planDescription);
}

- (BOOL)isUnderReview {
    NSString *normalized = PPProviderNormalizedStatus(self.status);
    return [normalized isEqualToString:kPPProviderStatusUnderReview] ||
           [normalized isEqualToString:kPPProviderStatusPending] ||
           [normalized isEqualToString:kPPProviderStatusResubmitted];
}

- (BOOL)isChangesRequested {
    NSString *normalized = PPProviderNormalizedStatus(self.status);
    return [normalized isEqualToString:kPPProviderStatusChangesRequested];
}

- (BOOL)isRejected {
    NSString *normalized = PPProviderNormalizedStatus(self.status);
    return [normalized isEqualToString:kPPProviderStatusRejected];
}

- (BOOL)isApproved {
    NSString *normalized = PPProviderNormalizedStatus(self.status);
    return [normalized isEqualToString:kPPProviderStatusApproved] ||
           [normalized isEqualToString:kPPProviderProfileStatusActive];
}

- (BOOL)isSetupRequired {
    return [self.operationalState isEqualToString:@"setup_required"] ||
           [self.setupState isEqualToString:@"not_started"] ||
           [self.setupState isEqualToString:@"in_progress"] ||
           [self.setupState isEqualToString:@"ready_for_activation"];
}

- (BOOL)isReadyForActivation {
    return [self.setupState isEqualToString:@"ready_for_activation"];
}

@end

@interface PPProviderProfile ()
- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID;
@end

@implementation PPProviderProfile

- (BOOL)hasManagedSubscription { return self.subscription[@"schemaVersion"] != nil; }
- (NSDate *)subscriptionExpiresAt {
    id value = self.subscription[@"expiresAt"];
    if ([value isKindOfClass:NSNumber.class]) return isfinite([value doubleValue]) ? [NSDate dateWithTimeIntervalSince1970:[value doubleValue] / 1000.0] : nil;
    return PPProviderDateFromValue(value);
}
- (NSString *)effectiveSubscriptionStatus {
    if (!self.hasManagedSubscription) return @"unmanaged";
    id version = self.subscription[@"schemaVersion"];
    if (![version isKindOfClass:NSNumber.class] || [version doubleValue] != 1) return @"unavailable";
    NSString *status = PPSafeString(self.subscription[@"status"]);
    if (![@[@"active", @"paused", @"expired", @"cancelled"] containsObject:status]) return @"unavailable";
    NSDate *end = self.subscriptionExpiresAt;
    if (self.subscription[@"expiresAt"] && self.subscription[@"expiresAt"] != NSNull.null && !end) return @"unavailable";
    if (([status isEqualToString:@"active"] || [status isEqualToString:@"paused"]) && end && end.timeIntervalSinceNow <= 0) return @"expired";
    return status.length ? status : @"unavailable";
}
- (NSString *)localizedSubscriptionSummary {
    if (!self.hasManagedSubscription) return kLang(@"PartnerSub_UnmanagedHint");
    NSString *status = kLang([@"PartnerSub_Status_" stringByAppendingString:self.effectiveSubscriptionStatus]);
    NSString *term = kLang(@"PartnerSub_NoEnd");
    if (self.subscriptionExpiresAt) {
        NSDateFormatter *formatter = [NSDateFormatter new]; formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar" : @"en"];
        formatter.dateStyle = NSDateFormatterMediumStyle; term = [formatter stringFromDate:self.subscriptionExpiresAt];
    }
    return [NSString stringWithFormat:kLang(@"PartnerSub_StatusTerm"), status, term];
}

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
        _operationalState = @"";
        _setupState = @"";
        _activationChecklist = @{};
    }
    return self;
}

- (void)pp_populateWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID {
    NSDictionary *planSnapshot = [dictionary[@"planSnapshot"] isKindOfClass:NSDictionary.class] ? dictionary[@"planSnapshot"] : @{};
    self.profileID = documentID ?: @"";
    self.subscription = PPSafeDict(dictionary[@"subscription"]);
    if (dictionary[@"subscription"] && dictionary[@"subscription"] != NSNull.null && ![dictionary[@"subscription"] isKindOfClass:NSDictionary.class]) self.subscription = @{@"schemaVersion":NSNull.null};
    self.providerType = PPProviderTypeFromIdentifier(PPSafeString(dictionary[@"providerType"]));
    self.status = PPSafeString(dictionary[@"status"]);
    self.planID = PPSafeString(dictionary[@"planId"]);
    self.planName = PPSafeDict(planSnapshot[@"name"]);
    self.form = [dictionary[@"form"] isKindOfClass:NSDictionary.class] ? dictionary[@"form"] : @{};
    self.approvedAt = PPProviderDateFromValue(dictionary[@"approvedAt"]);
    self.billingInterval = PPSafeString(planSnapshot[@"billingInterval"]);
    self.priceAmount = PPSafeDouble(planSnapshot[@"priceAmount"] ?: planSnapshot[@"costValue"]);
    self.currency = PPSafeString(planSnapshot[@"currency"]).length ? PPSafeString(planSnapshot[@"currency"]) : @"QAR";
    self.operationalState = PPSafeString(dictionary[@"operationalState"]);
    self.setupState = PPSafeString(dictionary[@"setupState"]);
    self.activationChecklist = [dictionary[@"activationChecklist"] isKindOfClass:NSDictionary.class] ? dictionary[@"activationChecklist"] : @{};
    self.documents = [dictionary[@"documents"] isKindOfClass:NSDictionary.class] ? dictionary[@"documents"] : @{};
    self.profileDomains = [dictionary[@"profileDomains"] isKindOfClass:NSDictionary.class] ? dictionary[@"profileDomains"] : @{};
    self.maskedIban = PPSafeString(dictionary[@"maskedIban"]);
    self.restrictions = [dictionary[@"restrictions"] isKindOfClass:NSArray.class] ? dictionary[@"restrictions"] : @[];
    self.activeRestrictions = [dictionary[@"activeRestrictions"] isKindOfClass:NSArray.class] ? dictionary[@"activeRestrictions"] : @[];
}

- (nullable NSDictionary *)publicProfile {
    return [self.profileDomains[@"public"] isKindOfClass:NSDictionary.class] ? self.profileDomains[@"public"] : nil;
}

- (nullable NSDictionary *)operationalProfile {
    return [self.profileDomains[@"operational"] isKindOfClass:NSDictionary.class] ? self.profileDomains[@"operational"] : nil;
}

- (nullable NSDictionary *)legalProfile {
    return [self.profileDomains[@"legal"] isKindOfClass:NSDictionary.class] ? self.profileDomains[@"legal"] : nil;
}

- (nullable NSDictionary *)financialProfile {
    return [self.profileDomains[@"financial"] isKindOfClass:NSDictionary.class] ? self.profileDomains[@"financial"] : nil;
}

- (NSString *)localizedPlanName {
    return PPProviderLocalizedText(self.planName);
}

- (BOOL)isSetupRequired {
    return [self.operationalState isEqualToString:@"setup_required"] ||
           [self.setupState isEqualToString:@"not_started"] ||
           [self.setupState isEqualToString:@"in_progress"] ||
           [self.setupState isEqualToString:@"ready_for_activation"];
}

- (BOOL)isReadyForActivation {
    return [self.setupState isEqualToString:@"ready_for_activation"];
}

- (BOOL)isRestricted {
    if ([self.operationalState isEqualToString:@"restricted"]) {
        return YES;
    }
    return self.activeRestrictions.count > 0;
}

- (BOOL)isSuspended {
    if ([self.operationalState isEqualToString:@"suspended"]) {
        return YES;
    }
    for (NSDictionary *r in self.activeRestrictions) {
        if ([r[@"type"] isEqualToString:@"suspension"]) {
            return YES;
        }
    }
    return NO;
}

- (nullable NSDictionary *)primaryActiveRestriction {
    if (!self.activeRestrictions.count) return nil;
    for (NSDictionary *r in self.activeRestrictions) {
        if ([r[@"type"] isEqualToString:@"suspension"]) {
            return r;
        }
    }
    return self.activeRestrictions.firstObject;
}

- (BOOL)isSellingBlocked {
    if ([self.operationalState isEqualToString:@"suspended"]) return YES;
    for (NSDictionary *r in self.activeRestrictions) {
        NSString *scope = PPSafeString(r[@"scope"]);
        if ([scope isEqualToString:@"full_account"] || [scope isEqualToString:@"selling_only"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)areNewOrdersBlocked {
    if ([self.operationalState isEqualToString:@"suspended"]) return YES;
    for (NSDictionary *r in self.activeRestrictions) {
        NSString *scope = PPSafeString(r[@"scope"]);
        if ([scope isEqualToString:@"full_account"] || [scope isEqualToString:@"new_orders_only"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)arePayoutsBlocked {
    if ([self.operationalState isEqualToString:@"suspended"]) return YES;
    for (NSDictionary *r in self.activeRestrictions) {
        NSString *scope = PPSafeString(r[@"scope"]);
        if ([scope isEqualToString:@"full_account"] || [scope isEqualToString:@"payouts_only"]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSDictionary *> *)expiringDocumentsWithinDays:(NSInteger)days {
    NSMutableArray<NSDictionary *> *expiring = [NSMutableArray array];
    NSDate *now = [NSDate date];
    NSTimeInterval maxInterval = (days > 0 ? days : 30) * 86400.0;

    [self.documents enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:NSDictionary.class]) return;
        NSDictionary *doc = (NSDictionary *)obj;
        NSString *expiryStr = PPSafeString(doc[@"expiryDate"]);
        if (expiryStr.length == 0) expiryStr = PPSafeString(doc[@"expiresAt"]);
        if (expiryStr.length == 0) return;

        NSDate *expiryDate = PPProviderDateFromValue(expiryStr);
        if (!expiryDate) return;

        NSTimeInterval diff = [expiryDate timeIntervalSinceDate:now];
        if (diff <= maxInterval) {
            NSInteger daysRemaining = (NSInteger)ceil(diff / 86400.0);
            if (daysRemaining < 0) daysRemaining = 0;
            NSMutableDictionary *entry = [doc mutableCopy];
            entry[@"key"] = key;
            entry[@"daysRemaining"] = @(daysRemaining);
            entry[@"isExpired"] = @(diff <= 0);
            [expiring addObject:entry];
        }
    }];

    [expiring sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"daysRemaining"] compare:b[@"daysRemaining"]];
    }];
    return expiring.copy;
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
        _selectedPlanId = @"";
        _selectedCapabilities = @[];
        _logoURL = @"";
        _coverURL = @"";
        _descriptionText = @"";
        _idempotencyKey = nil;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [self init];
    if (self && [dict isKindOfClass:[NSDictionary class]]) {
        _providerType = [dict[@"providerType"] respondsToSelector:@selector(integerValue)] ? [dict[@"providerType"] integerValue] : PPProviderTypeUnspecified;
        _fullName = PPSafeString(dict[@"fullName"]);
        _phone = PPSafeString(dict[@"phone"]);
        _email = PPSafeString(dict[@"email"]);
        _businessName = PPSafeString(dict[@"businessName"]);
        _companyName = PPSafeString(dict[@"companyName"]);
        _legalName = PPSafeString(dict[@"legalName"]);
        _address = PPSafeString(dict[@"address"]);
        _licenseNumber = PPSafeString(dict[@"licenseNumber"]);
        _commercialRegistrationNumber = PPSafeString(dict[@"commercialRegistrationNumber"]);
        _licenseDocumentURL = PPSafeString(dict[@"licenseDocumentURL"]);
        _commercialRegistrationDocumentURL = PPSafeString(dict[@"commercialRegistrationDocumentURL"]);
        _city = PPSafeString(dict[@"city"]);
        _notes = PPSafeString(dict[@"notes"]);
        _coverageAreas = [dict[@"coverageAreas"] isKindOfClass:[NSArray class]] ? dict[@"coverageAreas"] : @[];
        _selectedPlanId = PPSafeString(dict[@"selectedPlanId"]);
        _selectedCapabilities = [dict[@"selectedCapabilities"] isKindOfClass:[NSArray class]] ? dict[@"selectedCapabilities"] : @[];
        _logoURL = PPSafeString(dict[@"logoURL"]);
        _coverURL = PPSafeString(dict[@"coverURL"]);
        _descriptionText = PPSafeString(dict[@"descriptionText"]);
        _idempotencyKey = PPSafeString(dict[@"idempotencyKey"]).length ? PPSafeString(dict[@"idempotencyKey"]) : nil;
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"providerType"] = @(self.providerType);
    dict[@"fullName"] = self.fullName ?: @"";
    dict[@"phone"] = self.phone ?: @"";
    dict[@"email"] = self.email ?: @"";
    dict[@"businessName"] = self.businessName ?: @"";
    dict[@"companyName"] = self.companyName ?: @"";
    dict[@"legalName"] = self.legalName ?: @"";
    dict[@"address"] = self.address ?: @"";
    dict[@"licenseNumber"] = self.licenseNumber ?: @"";
    dict[@"commercialRegistrationNumber"] = self.commercialRegistrationNumber ?: @"";
    dict[@"licenseDocumentURL"] = self.licenseDocumentURL ?: @"";
    dict[@"commercialRegistrationDocumentURL"] = self.commercialRegistrationDocumentURL ?: @"";
    dict[@"city"] = self.city ?: @"";
    dict[@"notes"] = self.notes ?: @"";
    dict[@"coverageAreas"] = self.coverageAreas ?: @[];
    if (self.selectedPlanId.length) dict[@"selectedPlanId"] = self.selectedPlanId;
    if (self.selectedCapabilities.count) dict[@"selectedCapabilities"] = self.selectedCapabilities;
    if (self.logoURL.length) dict[@"logoURL"] = self.logoURL;
    if (self.coverURL.length) dict[@"coverURL"] = self.coverURL;
    if (self.descriptionText.length) dict[@"descriptionText"] = self.descriptionText;
    if (self.idempotencyKey.length) dict[@"idempotencyKey"] = self.idempotencyKey;
    return dict.copy;
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
        _operationalState = @"";
        _setupState = @"not_started";
        _activationChecklist = @{};
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
    PPProviderProfile *profile = [self profileForType:type];
    if (profile.hasManagedSubscription && ![profile.effectiveSubscriptionStatus isEqualToString:@"active"]) return NO;
    if (profile.hasManagedSubscription && profile.isSetupRequired) return NO;
    if ([@[@"paused", @"inactive", @"suspended", @"disabled"] containsObject:profile.status.lowercaseString ?: @""] || profile.isRestricted || profile.isSuspended) return NO;
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
    if ([self profileForType:type].hasManagedSubscription) return NO;
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

- (BOOL)isSetupRequired {
    if ([self.operationalState isEqualToString:@"setup_required"]) {
        return YES;
    }
    for (PPProviderApplication *app in self.applications) {
        if (app.isApproved && app.isSetupRequired) {
            return YES;
        }
    }
    for (PPProviderProfile *profile in self.profilesByType.allValues) {
        if (profile.isSetupRequired) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isReadyForActivation {
    if ([self.setupState isEqualToString:@"ready_for_activation"]) {
        return YES;
    }
    for (PPProviderApplication *app in self.applications) {
        if (app.isApproved && app.isReadyForActivation) {
            return YES;
        }
    }
    for (PPProviderProfile *profile in self.profilesByType.allValues) {
        if (profile.isReadyForActivation) {
            return YES;
        }
    }
    return NO;
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

- (BOOL)isRestricted {
    if ([self.operationalState isEqualToString:@"restricted"]) {
        return YES;
    }
    if (self.activeRestrictions.count > 0) {
        return YES;
    }
    for (PPProviderProfile *profile in self.profilesByType.allValues) {
        if ([profile isRestricted]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isSuspended {
    if ([self.operationalState isEqualToString:@"suspended"]) {
        return YES;
    }
    for (PPProviderProfile *profile in self.profilesByType.allValues) {
        if ([profile isSuspended]) {
            return YES;
        }
    }
    return NO;
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

@implementation PPProviderOwnedSubscription
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
- (void)pp_refreshAppCheckTokenWithCompletion:(void(^)(BOOL refreshed))completion;
- (NSError *)pp_friendlyProviderPlansError:(NSError *)error;
@end

@implementation PPProviderApplicationManager

#pragma mark - Owned subscription inventory and reviewed requests

+ (BOOL)isDefinitiveSubscriptionRequestError:(NSError *)error {
    return [error.domain isEqualToString:FIRFunctionsErrorDomain] &&
        [@[@(FIRFunctionsErrorCodeInvalidArgument), @(FIRFunctionsErrorCodeNotFound), @(FIRFunctionsErrorCodeAlreadyExists),
           @(FIRFunctionsErrorCodePermissionDenied), @(FIRFunctionsErrorCodeFailedPrecondition), @(FIRFunctionsErrorCodeAborted),
           @(FIRFunctionsErrorCodeUnauthenticated)] containsObject:@(error.code)];
}

- (void)pp_callSubscriptionFunction:(NSString *)name payload:(NSDictionary *)payload
                         completion:(void(^)(NSDictionary *, NSError *))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (!uid.length) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, PPProviderError(kLang(@"Please login first"))); });
        return;
    }
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:name];
    callable.timeoutInterval = 20;
    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![[FIRAuth auth].currentUser.uid isEqualToString:uid]) {
                completion(nil, PPProviderError(kLang(@"ProSubscriptions_AccountChanged")));
            } else {
                completion(error ? nil : PPSafeDict(result.data), error);
            }
        });
    }];
}

- (PPProviderOwnedSubscription *)pp_ownedSubscriptionFromDictionary:(NSDictionary *)record uid:(NSString *)uid {
    if (![PPSafeString(record[@"userId"]) isEqualToString:uid] || !PPSafeString(record[@"profileId"]).length ||
        !PPProviderTypeIsEnabledInProApp(PPProviderTypeFromIdentifier(PPSafeString(record[@"providerType"])))) return nil;
    NSDictionary *subscription = PPSafeDict(record[@"subscription"]);
    NSDictionary *snapshot = PPSafeDict(subscription[@"planSnapshot"]);
    if (!snapshot.count) snapshot = @{@"name": PPSafeDict(record[@"planName"])};
    PPProviderProfile *profile = [[PPProviderProfile alloc] init];
    [profile pp_populateWithDictionary:@{@"providerType": PPSafeString(record[@"providerType"]),
        @"status": PPSafeString(record[@"operationalStatus"]), @"operationalState": PPSafeString(record[@"operationalStatus"]),
        @"planId": PPSafeString(record[@"planId"]), @"planSnapshot": snapshot, @"subscription": subscription,
        @"form": @{@"businessName": PPSafeString(record[@"displayName"])}}
                             documentID:PPSafeString(record[@"profileId"])];
    PPProviderOwnedSubscription *owned = [[PPProviderOwnedSubscription alloc] init];
    owned.profile = profile;
    owned.userID = uid;
    owned.displayName = PPSafeString(record[@"displayName"]);
    owned.operationalStatus = PPSafeString(record[@"operationalStatus"]);
    owned.subscriptionStatus = PPSafeString(record[@"status"]);
    owned.currentPriceLine = @"";
    id amount = snapshot[@"costValue"] ?: snapshot[@"priceAmount"];
    if ([amount isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)amount) != CFBooleanGetTypeID() &&
        isfinite([amount doubleValue]) && [amount doubleValue] >= 0 && PPSafeString(snapshot[@"currency"]).length) {
        PPProviderPlan *currentPlan = [[PPProviderPlan alloc] init];
        [currentPlan pp_populateWithDictionary:snapshot documentID:profile.planID];
        owned.currentPriceLine = currentPlan.localizedPriceLine;
    }
    owned.version = [PPSafeNumber(record[@"version"]) integerValue];
    NSArray *actions = [record[@"requestActions"] isKindOfClass:NSArray.class] ? record[@"requestActions"] : @[];
    owned.requestActions = [actions filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id item, __unused NSDictionary *bindings) {
        return [item isKindOfClass:NSString.class] && [@[@"renew", @"change_plan"] containsObject:item];
    }]];
    owned.subscriptionRequest = PPSafeDict(record[@"subscriptionRequest"]);
    return owned;
}

- (void)fetchOwnedSubscriptionsWithCompletion:(void(^)(NSArray<PPProviderOwnedSubscription *> *, NSError *))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    [self pp_fetchOwnedSubscriptionsAfter:@"" uid:uid records:[NSMutableDictionary dictionary]
                                  cursors:[NSMutableSet set] completion:completion];
}

- (void)pp_fetchOwnedSubscriptionsAfter:(NSString *)cursor uid:(NSString *)uid
                                records:(NSMutableDictionary<NSString *, PPProviderOwnedSubscription *> *)records
                                cursors:(NSMutableSet<NSString *> *)cursors
                             completion:(void(^)(NSArray<PPProviderOwnedSubscription *> *, NSError *))completion {
    [self pp_callSubscriptionFunction:@"getMyProviderSubscriptions" payload:cursor.length ? @{@"after": cursor} : @{}
                           completion:^(NSDictionary *result, NSError *error) {
        if (error || ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) {
            completion(nil, error ?: PPProviderError(kLang(@"ProSubscriptions_AccountChanged"))); return;
        }
        NSArray *items = [result[@"partners"] isKindOfClass:NSArray.class] ? result[@"partners"] : @[];
        for (id item in items) {
            if (![item isKindOfClass:NSDictionary.class]) continue;
            PPProviderOwnedSubscription *owned = [self pp_ownedSubscriptionFromDictionary:item uid:uid];
            if (owned) records[owned.profile.profileID] = owned;
        }
        NSString *next = PPSafeString(result[@"nextCursor"]);
        if (next.length) {
            if ([cursors containsObject:next]) { completion(nil, PPProviderError(kLang(@"ProSubscription_LoadFailed"))); return; }
            [cursors addObject:next];
            [self pp_fetchOwnedSubscriptionsAfter:next uid:uid records:records cursors:cursors completion:completion];
            return;
        }
        NSArray *ordered = [records.allValues sortedArrayUsingComparator:^NSComparisonResult(PPProviderOwnedSubscription *a, PPProviderOwnedSubscription *b) {
            NSComparisonResult type = [PPProviderTypeIdentifier(a.profile.providerType) compare:PPProviderTypeIdentifier(b.profile.providerType)];
            return type == NSOrderedSame ? [a.profile.profileID compare:b.profile.profileID] : type;
        }];
        completion(ordered, nil);
    }];
}

- (void)fetchSubscriptionOptionsForProfileID:(NSString *)profileID
                                completion:(void(^)(PPProviderOwnedSubscription *, NSArray<PPProviderPlan *> *, NSError *))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    [self pp_callSubscriptionFunction:@"getMyProviderSubscriptions" payload:@{@"profileId": profileID ?: @""}
                           completion:^(NSDictionary *result, NSError *error) {
        PPProviderOwnedSubscription *owned = error ? nil : [self pp_ownedSubscriptionFromDictionary:PPSafeDict(result[@"partner"]) uid:uid];
        if (!owned || ![owned.profile.profileID isEqualToString:profileID]) {
            completion(nil, nil, error ?: PPProviderError(kLang(@"ProSubscriptions_Unavailable"))); return;
        }
        NSMutableArray *plans = [NSMutableArray array];
        for (id row in [result[@"plans"] isKindOfClass:NSArray.class] ? result[@"plans"] : @[]) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            PPProviderPlan *plan = [[PPProviderPlan alloc] init];
            [plan pp_populateWithDictionary:row documentID:PPSafeString(row[@"id"])];
            if (plan.providerType == owned.profile.providerType && plan.planID.length && plan.subscriptionPlanHash.length == 64) [plans addObject:plan];
        }
        completion(owned, plans.copy, nil);
    }];
}

- (void)submitSubscriptionRequest:(NSDictionary *)request completion:(void(^)(NSDictionary *, NSError *))completion {
    // The request identity is supplied by the reviewed intent and reused on a
    // retry. Never retry this write by silently generating another identity.
    [self pp_callSubscriptionFunction:@"submitMyProviderSubscriptionRequest" payload:request completion:completion];
}

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

static NSString *PPProviderDraftStorageKey(NSString *uid, PPProviderType type) {
    return [NSString stringWithFormat:@"PPProviderApplicationDraft_%@_%ld", uid.length ? uid : @"anon", (long)type];
}

- (void)saveDraft:(PPProviderApplicationDraft *)draft forProviderType:(PPProviderType)providerType {
    if (!draft) return;
    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *key = PPProviderDraftStorageKey(authUser.uid, providerType);
    NSDictionary *dict = [draft dictionaryRepresentation];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (nullable PPProviderApplicationDraft *)savedDraftForProviderType:(PPProviderType)providerType {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *key = PPProviderDraftStorageKey(authUser.uid, providerType);
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([dict isKindOfClass:[NSDictionary class]]) {
        return [[PPProviderApplicationDraft alloc] initWithDictionary:dict];
    }
    return nil;
}

- (void)clearDraftForProviderType:(PPProviderType)providerType {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    NSString *key = PPProviderDraftStorageKey(authUser.uid, providerType);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    if ([normalized isEqualToString:kPPProviderStatusChangesRequested]) {
        return kLang(@"ProviderStatusChangesRequested");
    }
    if ([normalized isEqualToString:kPPProviderStatusResubmitted]) {
        return kLang(@"ProviderStatusResubmitted");
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
    // Resume application intent only after every required initial snapshot.
    NSMutableSet<NSString *> *awaitingInitial = [NSMutableSet setWithArray:@[@"user", @"applications"]];
    NSMutableSet<NSString *> *awaitingServer = [NSMutableSet setWithArray:@[@"user", @"applications"]];
    for (NSNumber *value in @[@(PPProviderTypeVet), @(PPProviderTypePharmacy), @(PPProviderTypeDeliverySubscription), @(PPProviderTypeDeliveryCompany), @(PPProviderTypeService), @(PPProviderTypeMarketplace)]) {
        if (!PPProviderTypeIsEnabledInProApp(value.integerValue)) continue;
        NSString *type = PPProviderTypeIdentifier(value.integerValue);
        [awaitingInitial addObject:[@"profile:" stringByAppendingString:type]];
        [awaitingServer addObject:[@"profile:" stringByAppendingString:type]];
        [awaitingInitial addObject:[@"legacy:" stringByAppendingString:type]];
    }

    __weak typeof(self) weakSelf = self;
    void (^emitState)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!completion || !self || ![[FIRAuth auth].currentUser.uid isEqualToString:authUser.uid]) {
            return;
        }
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        if (awaitingInitial.count > 0) return;
        PPProviderOnboardingState *state = [self pp_buildStateForUser:authUser root:userRoot applications:applicationDocs profiles:profileDocs];
        state.initialDataAuthoritative = awaitingServer.count == 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(state, nil);
        });
    };

    FIRDocumentReference *userRef = [[self.db collectionWithPath:@"UsersCol"] documentWithPath:authUser.uid];
    id<FIRListenerRegistration> userReg = [userRef addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            emitState(error);
            return;
        }
        userRoot = snapshot.exists ? (snapshot.data ?: @{}) : nil;
        [awaitingInitial removeObject:@"user"];
        if (!snapshot.metadata.isFromCache) [awaitingServer removeObject:@"user"];
        emitState(nil);
    }];
    if (userReg) {
        [token.registrations addObject:userReg];
    }

    FIRQuery *applicationsQuery = [[self.db collectionWithPath:kPPProviderApplicationsCollection]
                                   queryWhereField:@"userId"
                                   isEqualTo:authUser.uid];
    id<FIRListenerRegistration> applicationsReg = [applicationsQuery addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
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
        [awaitingInitial removeObject:@"applications"];
        if (!snapshot.metadata.isFromCache) [awaitingServer removeObject:@"applications"];
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
            [awaitingInitial removeObject:[@"legacy:" stringByAppendingString:typeIdentifier]];
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
        id<FIRListenerRegistration> profileReg = [profileRef addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) {
                [profileDocs removeObjectForKey:typeIdentifier];
                emitState(error);
                return;
            }
            [awaitingInitial removeObject:[@"profile:" stringByAppendingString:typeIdentifier]];
            if (!snapshot.metadata.isFromCache) [awaitingServer removeObject:[@"profile:" stringByAppendingString:typeIdentifier]];
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

    // An "unauthenticated" rejection from a callable can originate from EITHER
    // layer: the Firebase Auth ID token OR the App Check token (the submit
    // callables run with enforceAppCheck = true, and the iOS SDK surfaces an
    // App Check rejection as FIRFunctionsErrorCodeUnauthenticated). The previous
    // implementation only force-refreshed the ID token, so a transient App Check
    // failure could never be recovered and was mislabeled as a sign-in problem.
    // Refresh both layers, then allow the single retry if either produced a
    // fresh token.
    __weak typeof(self) weakSelf = self;
    [authUser getIDTokenForcingRefresh:YES completion:^(NSString * _Nullable token, NSError * _Nullable error) {
        BOOL idTokenRefreshed = (token.length > 0 && error == nil);
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) { completion(idTokenRefreshed); }
            });
            return;
        }
        [strongSelf pp_refreshAppCheckTokenWithCompletion:^(BOOL appCheckRefreshed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(idTokenRefreshed || appCheckRefreshed);
                }
            });
        }];
    }];
}

// Force-refreshes the App Check token so a transient App Check failure (expired
// or not-yet-minted attestation) can be recovered by the single submit retry.
// Reports NO gracefully when FirebaseAppCheck is unavailable at compile time or
// no default app exists, so the caller still retries on a fresh ID token.
- (void)pp_refreshAppCheckTokenWithCompletion:(void(^)(BOOL refreshed))completion {
#if defined(PP_FIREBASE_APP_CHECK_IMPORTED)
    FIRAppCheck *appCheck = [FIRAppCheck appCheck];
    if (!appCheck) {
        if (completion) { completion(NO); }
        return;
    }
    [appCheck tokenForcingRefresh:YES completion:^(FIRAppCheckToken * _Nullable token, NSError * _Nullable error) {
        BOOL refreshed = (token.token.length > 0 && error == nil);
        if (completion) { completion(refreshed); }
    }];
#else
    if (completion) { completion(NO); }
#endif
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

    if (draft.idempotencyKey.length == 0) {
        draft.idempotencyKey = [NSString stringWithFormat:@"sub_%@_%@", authUser.uid, [[NSUUID UUID] UUIDString].lowercaseString];
    }
    NSString *idempotencyKey = draft.idempotencyKey;

    NSDictionary *payload = @{
        @"providerType": PPProviderTypeIdentifier(draft.providerType),
        @"planId": selectedPlan.planID ?: @"",
        @"idempotencyKey": idempotencyKey,
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

    NSString *rootOpState = PPSafeString(safeRoot[@"operationalState"]);
    NSString *rootSetupState = PPSafeString(safeRoot[@"setupState"]);
    NSDictionary *rootChecklist = [safeRoot[@"activationChecklist"] isKindOfClass:NSDictionary.class] ? safeRoot[@"activationChecklist"] : nil;

    for (PPProviderApplication *app in state.applications) {
        if (rootOpState.length == 0 && app.operationalState.length > 0) {
            rootOpState = app.operationalState;
        }
        if (rootSetupState.length == 0 && app.setupState.length > 0) {
            rootSetupState = app.setupState;
        }
        if (!rootChecklist && app.activationChecklist.count > 0) {
            rootChecklist = app.activationChecklist;
        }
    }
    for (PPProviderProfile *prof in state.profilesByType.allValues) {
        if (rootOpState.length == 0 && prof.operationalState.length > 0) {
            rootOpState = prof.operationalState;
        }
        if (rootSetupState.length == 0 && prof.setupState.length > 0) {
            rootSetupState = prof.setupState;
        }
        if (!rootChecklist && prof.activationChecklist.count > 0) {
            rootChecklist = prof.activationChecklist;
        }
    }
    NSMutableArray *allActiveRestrictions = [NSMutableArray array];
    for (PPProviderProfile *prof in state.profilesByType.allValues) {
        if (prof.activeRestrictions.count > 0) {
            [allActiveRestrictions addObjectsFromArray:prof.activeRestrictions];
        }
    }
    state.activeRestrictions = allActiveRestrictions.copy;

    state.operationalState = rootOpState.length ? rootOpState : @"";
    state.setupState = rootSetupState.length ? rootSetupState : @"not_started";
    state.activationChecklist = rootChecklist ?: @{};

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

- (void)updateChecklistProgressForKey:(NSString *)key
                            completed:(BOOL)completed
                           completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"updatePartnerSetupChecklist"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
        @"checklistKey": key ?: @"",
        @"completed": @(completed),
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            if (completion) {
                completion(YES, nil);
            }
        });
    }];
}

- (void)activatePartnerAccountWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"activatePartnerAccount"];
    callable.timeoutInterval = 30.0;

    NSString *idempotencyKey = [NSString stringWithFormat:@"act_%@_%@", authUser.uid, [[NSUUID UUID] UUIDString].lowercaseString];
    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
        @"idempotencyKey": idempotencyKey,
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            if (completion) {
                completion(YES, nil);
            }
        });
    }];
}

- (void)updateProfileDomain:(NSString *)domain
                      patch:(NSDictionary *)patch
            expectedVersion:(nullable NSNumber *)expectedVersion
                 completion:(void(^)(BOOL success, NSDictionary * _Nullable result, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"updatePartnerProfileDomain"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    payload[@"domain"] = domain ?: @"";
    payload[@"patch"] = patch ?: @{};
    if (expectedVersion) {
        payload[@"expectedVersion"] = expectedVersion;
    }

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            if (completion) {
                completion(YES, dict, nil);
            }
        });
    }];
}

- (void)fetchProfileDomain:(NSString *)domain
                completion:(void(^)(NSDictionary * _Nullable domainData, NSError * _Nullable error))completion {
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
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerProfileDomain"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
        @"domain": domain ?: @"",
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSDictionary *domainData = [dict[@"data"] isKindOfClass:NSDictionary.class] ? dict[@"data"] : nil;
            if (completion) {
                completion(domainData, nil);
            }
        });
    }];
}

- (void)fetchSyncSnapshotWithClientVersion:(nullable NSNumber *)clientVersion
                                completion:(void(^)(BOOL inSync, BOOL catchUpRequired, NSDictionary * _Nullable snapshot, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, NO, nil, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"fetchPartnerSyncSnapshot"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    if (clientVersion) {
        payload[@"clientVersion"] = clientVersion;
    }

    [callable callWithObject:payload.copy completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, NO, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL inSync = [dict[@"inSync"] boolValue];
            BOOL catchUp = [dict[@"catchUpRequired"] boolValue];
            if (completion) {
                completion(inSync, catchUp, dict, nil);
            }
        });
    }];
}

- (void)reconcileReadModelsWithServer:(void(^)(BOOL reconciled, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (authUser.uid.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, PPProviderError(kLang(@"ProviderSubmitSessionFailed")));
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"syncPartnerReadModels"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
        @"force": @YES,
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL reconciled = [dict[@"reconciled"] boolValue];
            if (completion) {
                completion(reconciled, nil);
            }
        });
    }];
}

- (void)fetchRestrictionsSummary:(void(^)(NSDictionary * _Nullable summary, NSError * _Nullable error))completion {
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
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerRestrictionsSummary"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSDictionary *summary = [dict[@"summary"] isKindOfClass:NSDictionary.class] ? dict[@"summary"] : dict;
            if (completion) {
                completion(summary, nil);
            }
        });
    }];
}

- (void)submitReactivationRequestWithActionTaken:(NSString *)actionTaken
                                  actionTakenAr:(nullable NSString *)actionTakenAr
                              evidenceDocuments:(NSArray<NSDictionary *> *)documents
                                   partnerNotes:(nullable NSString *)notes
                                  restrictionId:(nullable NSString *)restrictionId
                                expectedVersion:(nullable NSNumber *)expectedVersion
                                 idempotencyKey:(nullable NSString *)idempotencyKey
                                     completion:(void(^)(BOOL success, NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                        code:401
                                                    userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"submitPartnerReactivationRequest"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    payload[@"actionTaken"] = actionTaken ?: @"";
    if (actionTakenAr.length > 0) payload[@"actionTaken_ar"] = actionTakenAr;
    if (documents) payload[@"evidenceDocuments"] = documents;
    if (notes.length > 0) payload[@"partnerNotes"] = notes;
    if (restrictionId.length > 0) payload[@"restrictionId"] = restrictionId;
    if (expectedVersion) payload[@"expectedVersion"] = expectedVersion;
    if (idempotencyKey.length > 0) payload[@"idempotencyKey"] = idempotencyKey;

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL ok = [dict[@"ok"] boolValue];
            if (completion) {
                completion(ok, dict, nil);
            }
        });
    }];
}

- (void)fetchReactivationDossierWithCompletion:(void(^)(NSDictionary * _Nullable dossier, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                    code:401
                                                userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerReactivationDossierData"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSDictionary *dossier = [dict[@"dossier"] isKindOfClass:NSDictionary.class] ? dict[@"dossier"] : dict;
            if (completion) {
                completion(dossier, nil);
            }
        });
    }];
}

- (void)initiateVoluntaryOffboardingWithReasonCode:(NSString *)reasonCode
                                           reason:(NSString *)reason
                                         reasonAr:(nullable NSString *)reasonAr
                                  expectedVersion:(nullable NSNumber *)expectedVersion
                                   idempotencyKey:(nullable NSString *)idempotencyKey
                                       completion:(void(^)(BOOL success, NSDictionary * _Nullable response, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                        code:401
                                                    userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"initiatePartnerOffboardingWorkflow"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    payload[@"offboardingType"] = @"voluntary";
    payload[@"reasonCode"] = reasonCode ?: @"other";
    payload[@"reason"] = reason ?: @"";
    if (reasonAr.length > 0) payload[@"reason_ar"] = reasonAr;
    if (expectedVersion) payload[@"expectedVersion"] = expectedVersion;
    if (idempotencyKey.length > 0) payload[@"idempotencyKey"] = idempotencyKey;

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL ok = [dict[@"ok"] boolValue];
            if (completion) {
                completion(ok, dict, nil);
            }
        });
    }];
}

- (void)fetchOffboardingDossierWithCompletion:(void(^)(NSDictionary * _Nullable dossier, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                    code:401
                                                userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerOffboardingDossierData"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            NSDictionary *dossier = [dict[@"dossier"] isKindOfClass:NSDictionary.class] ? dict[@"dossier"] : dict;
            if (completion) {
                completion(dossier, nil);
            }
        });
    }];
}

- (void)fetchPartnerAuditTrailWithLimit:(nullable NSNumber *)limit
                         filterCategory:(nullable NSString *)filterCategory
                             completion:(void(^)(BOOL success, NSArray<NSDictionary *> * _Nullable entries, NSDictionary * _Nullable verification, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                            code:401
                                                        userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerAuditTrail"];
    callable.timeoutInterval = 30.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    if (limit) {
        payload[@"limit"] = limit;
    }
    if (filterCategory && filterCategory.length > 0) {
        payload[@"filterCategory"] = filterCategory;
    }

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL ok = [dict[@"ok"] boolValue];
            NSArray *entries = [dict[@"entries"] isKindOfClass:NSArray.class] ? dict[@"entries"] : @[];
            NSDictionary *verification = [dict[@"verification"] isKindOfClass:NSDictionary.class] ? dict[@"verification"] : nil;
            if (completion) {
                completion(ok, entries, verification, nil);
            }
        });
    }];
}

- (void)exportPrivacyDataWithCompletion:(void(^)(BOOL success, NSDictionary * _Nullable exportData, NSError * _Nullable error))completion {
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, [NSError errorWithDomain:@"PPProviderApplicationManager"
                                                        code:401
                                                    userInfo:@{NSLocalizedDescriptionKey: @"User must be authenticated."}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"exportPartnerPrivacyData"];
    callable.timeoutInterval = 30.0;

    NSDictionary *payload = @{
        @"partnerId": authUser.uid ?: @"",
    };

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL ok = [dict[@"ok"] boolValue];
            NSDictionary *exportData = [dict[@"export"] isKindOfClass:NSDictionary.class] ? dict[@"export"] : dict;
            if (completion) {
                completion(ok, exportData, nil);
            }
        });
    }];
}

- (void)fetchCockpitSummaryWithClientEtag:(nullable NSString *)clientEtag
                             forceRefresh:(BOOL)forceRefresh
                               completion:(void(^)(BOOL notModified, NSDictionary * _Nullable cockpit, NSString * _Nullable etag, NSNumber * _Nullable generation, NSError * _Nullable error))completion
{
    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, nil, nil, [NSError errorWithDomain:@"PPProviderApplicationManager" code:401 userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_not_authenticated")}]);
            });
        }
        return;
    }

    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:@"getPartnerCockpitSummary"];
    callable.timeoutInterval = 20.0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"partnerId"] = authUser.uid ?: @"";
    if (clientEtag.length > 0) {
        payload[@"clientEtag"] = clientEtag;
    }
    if (forceRefresh) {
        payload[@"forceRefresh"] = @YES;
    }

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) {
                    completion(NO, nil, nil, nil, [self pp_friendlyFunctionsError:error]);
                }
                return;
            }
            NSDictionary *dict = [result.data isKindOfClass:NSDictionary.class] ? (NSDictionary *)result.data : @{};
            BOOL notModified = [dict[@"notModified"] boolValue];
            NSDictionary *cockpit = [dict[@"cockpit"] isKindOfClass:NSDictionary.class] ? dict[@"cockpit"] : nil;
            NSString *etag = PPSafeString(dict[@"etag"]);
            NSNumber *generation = [dict[@"generation"] isKindOfClass:NSNumber.class] ? dict[@"generation"] : @(1);
            if (completion) {
                completion(notModified, cockpit, etag, generation, nil);
            }
        });
    }];
}

@end

