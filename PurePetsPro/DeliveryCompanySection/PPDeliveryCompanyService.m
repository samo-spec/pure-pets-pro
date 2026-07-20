#import "PPDeliveryCompanyService.h"
#import "PPFirebaseCompat.h"

NSString * const PPDeliveryCompanyMembershipDidChangeNotification = @"PPDeliveryCompanyMembershipDidChangeNotification";

static NSString * const PPDCFunctionCreate = @"createCompanyDeliveryRequest";
static NSString * const PPDCFunctionGetProfile = @"getDeliveryCompanyProfile";
static NSString * const PPDCFunctionListRequests = @"listCompanyDeliveryRequests";
static NSString * const PPDCFunctionGetRequest = @"getCompanyDeliveryRequest";
static NSString * const PPDCFunctionListAssigned = @"listMyAssignedCompanyDeliveries";
static NSString * const PPDCFunctionListMembers = @"listCompanyMembers";
static NSString * const PPDCFunctionAccept = @"acceptCompanyDeliveryRequest";
static NSString * const PPDCFunctionReject = @"rejectCompanyDeliveryRequest";
static NSString * const PPDCFunctionAssign = @"assignCompanyDeliveryDriver";
static NSString * const PPDCFunctionReassign = @"reassignCompanyDeliveryDriver";
static NSString * const PPDCFunctionUpdateStatus = @"updateCompanyDeliveryStatus";
static NSString * const PPDCFunctionComplete = @"completeCompanyDeliveryRequest";
static NSString * const PPDCFunctionCancel = @"cancelCompanyDeliveryRequest";
static NSString * const PPDCFunctionInviteMember = @"inviteDeliveryCompanyMember";
static NSString * const PPDCFunctionDisableMember = @"disableDeliveryCompanyMember";
static NSString * const PPDCFunctionGetMyCompanies = @"getMyDeliveryCompanies";
static NSString * const PPDCConfiguredCompanyDefaultsPrefix = @"PPDeliveryCompanyConfiguredID";

@interface PPDeliveryCompanyService ()
@property (nonatomic, strong, readwrite, nullable) PPDeliveryCompanyProfile *verifiedProfile;
@property (nonatomic, copy, readwrite) NSArray<PPDeliveryCompanyProfile *> *discoveredProfiles;
@property (nonatomic, copy) NSString *verifiedUID;
@property (nonatomic, assign, readwrite) BOOL isRefreshingProfile;
@end

@implementation PPDeliveryCompanyService

+ (instancetype)shared {
    static PPDeliveryCompanyService *service;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ service = [[self alloc] init]; });
    return service;
}

- (NSString *)defaultsKey {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"guest";
    return [NSString stringWithFormat:@"%@.%@", PPDCConfiguredCompanyDefaultsPrefix, uid];
}

- (NSString *)configuredCompanyID {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:self.defaultsKey];
    return [value isKindOfClass:NSString.class] ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

- (NSError *)normalizedError:(NSError *)error {
    if (!error) return nil;
    NSString *message = error.localizedDescription ?: kLang(@"DeliveryCompany_Error_Generic");
    id details = error.userInfo[@"details"];
    if ([details isKindOfClass:NSDictionary.class]) {
        NSString *detailMessage = [details[@"message"] isKindOfClass:NSString.class] ? details[@"message"] : nil;
        if (detailMessage.length) message = detailMessage;
    } else if ([details isKindOfClass:NSString.class] && [details length]) {
        message = details;
    }
    return [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany"
                               code:error.code
                           userInfo:@{
        NSLocalizedDescriptionKey: message,
        NSUnderlyingErrorKey: error
    }];
}

- (void)callFunction:(NSString *)name
             payload:(NSDictionary *)payload
          completion:(PPDeliveryCompanyActionCompletion)completion {
    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:name];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:payload ?: @{} completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, [self normalizedError:error]);
                return;
            }
            NSDictionary *data = [result.data isKindOfClass:NSDictionary.class] ? result.data : @{};
            if (completion) completion(data, nil);
        });
    }];
}

- (void)refreshConfiguredProfileWithCompletion:(PPDeliveryCompanyProfileCompletion)completion {
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (self.verifiedUID.length && ![self.verifiedUID isEqualToString:currentUID]) {
        self.verifiedProfile = nil;
        self.discoveredProfiles = @[];
        self.verifiedUID = @"";
    }
    NSString *companyID = self.configuredCompanyID;
    if (!companyID.length) {
        self.verifiedProfile = nil;
        if (completion) completion(nil, nil);
        return;
    }
    if (self.isRefreshingProfile) {
        if (completion) completion(self.verifiedProfile, nil);
        return;
    }
    self.isRefreshingProfile = YES;
    [self callFunction:PPDCFunctionGetProfile
               payload:@{@"companyId": companyID}
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        self.isRefreshingProfile = NO;
        NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![activeUID isEqualToString:currentUID]) {
            self.verifiedProfile = nil;
            self.discoveredProfiles = @[];
            self.verifiedUID = @"";
            if (completion) completion(nil, nil);
            return;
        }
        if (error) {
            self.verifiedProfile = nil;
            self.discoveredProfiles = @[];
            self.verifiedUID = @"";
            [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
            if (completion) completion(nil, error);
            return;
        }
        PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyProfile modelFromResponse:result ?: @{}];
        self.verifiedProfile = profile.companyID.length ? profile : nil;
        self.discoveredProfiles = self.verifiedProfile ? @[self.verifiedProfile] : @[];
        self.verifiedUID = self.verifiedProfile ? currentUID : @"";
        [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
        if (completion) completion(self.verifiedProfile, nil);
    }];
}

- (void)discoverCompanyMembershipsWithCompletion:(void(^)(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable error))completion {
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (self.verifiedUID.length && ![self.verifiedUID isEqualToString:currentUID]) {
        self.verifiedProfile = nil;
        self.discoveredProfiles = @[];
        self.verifiedUID = @"";
    }
    [self callFunction:PPDCFunctionGetMyCompanies payload:@{} completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![activeUID isEqualToString:currentUID]) {
            if (completion) completion(@[], nil);
            return;
        }
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<PPDeliveryCompanyProfile *> *profiles = [NSMutableArray array];
        NSArray *items = [result[@"companies"] isKindOfClass:NSArray.class] ? result[@"companies"] : @[];
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:NSDictionary.class]) {
                continue;
            }
            PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyProfile modelFromResponse:item];
            if (profile.companyID.length > 0) {
                [profiles addObject:profile];
            }
        }
        self.discoveredProfiles = profiles.copy;
        if (completion) completion(self.discoveredProfiles, nil);
    }];
}

- (void)verifyAndStoreCompanyID:(NSString *)companyID completion:(PPDeliveryCompanyProfileCompletion)completion {
    NSString *cleanID = [companyID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!cleanID.length) {
        NSError *error = [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Setup_CompanyIDRequired")}];
        completion(nil, error);
        return;
    }
    [self callFunction:PPDCFunctionGetProfile
               payload:@{@"companyId": cleanID}
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyProfile modelFromResponse:result ?: @{}];
        if (!profile.companyID.length) {
            NSError *invalid = [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany"
                                                   code:2
                                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_InvalidProfile")}];
            completion(nil, invalid);
            return;
        }
        [self storeVerifiedProfile:profile];
        completion(profile, nil);
    }];
}

- (void)storeVerifiedProfile:(PPDeliveryCompanyProfile *)profile {
    if (!profile.companyID.length) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:profile.companyID forKey:self.defaultsKey];
    self.verifiedProfile = profile;
    self.discoveredProfiles = @[profile];
    self.verifiedUID = [FIRAuth auth].currentUser.uid ?: @"";
    [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
}

- (void)disconnectCompany {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:self.defaultsKey];
    self.verifiedProfile = nil;
    self.discoveredProfiles = @[];
    self.verifiedUID = @"";
    [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
}

- (void)listRequestsForProfile:(PPDeliveryCompanyProfile *)profile
                 nextPageToken:(NSString *)nextPageToken
                    completion:(PPDeliveryCompanyRequestsCompletion)completion {
    BOOL driver = profile.isDriver;
    NSString *function = driver ? PPDCFunctionListAssigned : PPDCFunctionListRequests;
    NSMutableDictionary *payload = [@{@"companyId": profile.companyID ?: @"", @"pageSize": @20} mutableCopy];
    if (nextPageToken.length) payload[@"nextPageToken"] = nextPageToken;
    [self callFunction:function payload:payload completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }
        NSMutableArray *requests = [NSMutableArray array];
        for (NSDictionary *item in [result[@"requests"] isKindOfClass:NSArray.class] ? result[@"requests"] : @[]) {
            if ([item isKindOfClass:NSDictionary.class]) [requests addObject:[PPDeliveryCompanyRequest modelFromDictionary:item]];
        }
        NSString *token = [result[@"nextPageToken"] isKindOfClass:NSString.class] ? result[@"nextPageToken"] : nil;
        completion(requests.copy, token, nil);
    }];
}

- (void)getRequestWithID:(NSString *)requestID completion:(PPDeliveryCompanyRequestCompletion)completion {
    NSMutableDictionary *payload = [@{
        @"requestId": requestID ?: @"",
        @"includeEvents": @YES
    } mutableCopy];
    if (self.verifiedProfile.companyID.length > 0) {
        payload[@"companyId"] = self.verifiedProfile.companyID;
    }
    [self callFunction:PPDCFunctionGetRequest
               payload:payload
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSDictionary *requestData = [result[@"request"] isKindOfClass:NSDictionary.class] ? result[@"request"] : @{};
        NSMutableDictionary *request = [requestData mutableCopy];
        request[@"id"] = requestID ?: @"";
        request[@"events"] = [result[@"events"] isKindOfClass:NSArray.class] ? result[@"events"] : @[];
        completion([PPDeliveryCompanyRequest modelFromDictionary:request], nil);
    }];
}

- (void)listMembersForCompanyID:(NSString *)companyID completion:(PPDeliveryCompanyMembersCompletion)completion {
    [self callFunction:PPDCFunctionListMembers
               payload:@{@"companyId": companyID ?: @""}
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSMutableArray *members = [NSMutableArray array];
        for (NSDictionary *item in [result[@"members"] isKindOfClass:NSArray.class] ? result[@"members"] : @[]) {
            if ([item isKindOfClass:NSDictionary.class]) [members addObject:[PPDeliveryCompanyMember modelFromDictionary:item]];
        }
        [members sortUsingComparator:^NSComparisonResult(PPDeliveryCompanyMember *a, PPDeliveryCompanyMember *b) {
            if (a.isActiveDriver != b.isActiveDriver) return a.isActiveDriver ? NSOrderedAscending : NSOrderedDescending;
            return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
        }];
        completion(members.copy, nil);
    }];
}

- (void)createRequestForOrderID:(NSString *)orderID
                      companyID:(NSString *)companyID
          marketplaceProviderID:(NSString *)marketplaceProviderID
                       branchID:(NSString *)branchID
                  pickupAddress:(NSDictionary *)pickupAddress
                 dropoffAddress:(NSDictionary *)dropoffAddress
                    deliveryFee:(double)deliveryFee
                  paymentStatus:(NSString *)paymentStatus
                paymentProvider:(NSString *)paymentProvider
                   deliveryNote:(NSString *)deliveryNote
                     completion:(PPDeliveryCompanyActionCompletion)completion {
    NSMutableDictionary *payload = [@{
        @"orderId": orderID ?: @"",
        @"marketplaceProviderId": marketplaceProviderID ?: @""
    } mutableCopy];
    if (companyID.length > 0) payload[@"companyId"] = companyID;
    if (branchID.length > 0) payload[@"branchId"] = branchID;
    if (pickupAddress.count > 0) payload[@"pickupAddress"] = pickupAddress;
    if (dropoffAddress.count > 0) payload[@"dropoffAddress"] = dropoffAddress;
    if (deliveryFee > 0.0) payload[@"deliveryFee"] = @(deliveryFee);
    if (paymentStatus.length > 0) payload[@"paymentStatus"] = paymentStatus;
    if (paymentProvider.length > 0) payload[@"paymentProvider"] = paymentProvider;
    if (deliveryNote.length > 0) payload[@"deliveryNote"] = deliveryNote;
    [self callFunction:PPDCFunctionCreate payload:payload completion:completion];
}

- (void)acceptRequestID:(NSString *)requestID completion:(PPDeliveryCompanyActionCompletion)completion {
    NSMutableDictionary *payload = [@{@"requestId": requestID ?: @""} mutableCopy];
    if (self.verifiedProfile.companyID.length > 0) {
        payload[@"companyId"] = self.verifiedProfile.companyID;
    }
    [self callFunction:PPDCFunctionAccept payload:payload completion:completion];
}
- (void)rejectRequestID:(NSString *)requestID reason:(NSString *)reason completion:(PPDeliveryCompanyActionCompletion)completion {
    NSMutableDictionary *payload = [@{@"requestId": requestID ?: @""} mutableCopy];
    if (self.verifiedProfile.companyID.length > 0) {
        payload[@"companyId"] = self.verifiedProfile.companyID;
    }
    if (reason.length) payload[@"reason"] = reason;
    [self callFunction:PPDCFunctionReject payload:payload completion:completion];
}
- (void)assignRequestID:(NSString *)requestID driverUID:(NSString *)driverUID completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:PPDCFunctionAssign payload:@{@"requestId": requestID ?: @"", @"driverUid": driverUID ?: @""} completion:completion];
}
- (void)reassignRequestID:(NSString *)requestID driverUID:(NSString *)driverUID completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:PPDCFunctionReassign payload:@{@"requestId": requestID ?: @"", @"newDriverUid": driverUID ?: @""} completion:completion];
}
- (void)updateRequestID:(NSString *)requestID toStatus:(NSString *)status receiverName:(NSString *)receiverName completion:(PPDeliveryCompanyActionCompletion)completion {
    NSMutableDictionary *payload = [@{@"requestId": requestID ?: @"", @"toStatus": status ?: @""} mutableCopy];
    if (receiverName.length) payload[@"receiverName"] = receiverName;
    [self callFunction:PPDCFunctionUpdateStatus payload:payload completion:completion];
}
- (void)completeRequestID:(NSString *)requestID completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:PPDCFunctionComplete payload:@{@"requestId": requestID ?: @""} completion:completion];
}
- (void)cancelRequestID:(NSString *)requestID reason:(NSString *)reason completion:(PPDeliveryCompanyActionCompletion)completion {
    NSMutableDictionary *payload = [@{@"requestId": requestID ?: @""} mutableCopy];
    if (reason.length) payload[@"reason"] = reason;
    [self callFunction:PPDCFunctionCancel payload:payload completion:completion];
}
- (void)inviteMemberIdentifier:(NSString *)targetIdentifier role:(NSString *)role companyID:(NSString *)companyID completion:(PPDeliveryCompanyActionCompletion)completion {
    NSString *identifier = [targetIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    [self callFunction:PPDCFunctionInviteMember
               payload:@{
        @"companyId": companyID ?: @"",
        @"targetIdentifier": identifier,
        @"targetUid": identifier,
        @"role": role ?: @""
    }
            completion:completion];
}
- (void)disableMemberUID:(NSString *)targetUID companyID:(NSString *)companyID completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:PPDCFunctionDisableMember payload:@{@"companyId": companyID ?: @"", @"targetUid": targetUID ?: @""} completion:completion];
}

@end
