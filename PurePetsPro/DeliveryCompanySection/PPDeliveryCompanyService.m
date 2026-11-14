#import "PPDeliveryCompanyService.h"
#import "PPFirebaseCompat.h"
#import "AppManager.h"
#if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>)
#import <FirebaseAppCheck/FirebaseAppCheck.h>
#elif __has_feature(modules)
@import FirebaseAppCheck;
#endif

NSString * const PPDeliveryCompanyMembershipDidChangeNotification = @"PPDeliveryCompanyMembershipDidChangeNotification";
NSString * const PPDeliveryDriverWorkspaceConfirmedNotification = @"PPDeliveryDriverWorkspaceConfirmedNotification";

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

@interface PPDriverAcceptanceObservation : NSObject
@property (nonatomic, strong) id<FIRListenerRegistration> registration;
@end
@implementation PPDriverAcceptanceObservation
- (void)dealloc { [_registration remove]; }
@end

@interface PPDeliveryCompanyService ()
@property (nonatomic, strong, readwrite, nullable) PPDeliveryCompanyProfile *verifiedProfile;
@property (nonatomic, copy, readwrite) NSArray<PPDeliveryCompanyProfile *> *discoveredProfiles;
@property (nonatomic, copy) NSString *verifiedUID;
/// Account for which the last membership discovery found a driver workspace.
@property (nonatomic, copy) NSString *driverWorkspaceUID;
/// Full membership discovery, independent of the configured-company profile.
@property (nonatomic, copy) NSString *deliveryWorkspaceUID;
@property (nonatomic, assign, readwrite) BOOL isRefreshingProfile;
@property (nonatomic, strong) NSMutableArray *profileRefreshCompletions;
/// Memory-only retry identity, scoped to issuer + carrier + target + role.
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *memberInvitationCommandIDs;
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

    NSString *lower = message.lowercaseString;
    NSString *domainCode = [details isKindOfClass:NSDictionary.class] && [details[@"domainCode"] isKindOfClass:NSString.class]
        ? details[@"domainCode"] : @"";
    if ([domainCode isEqualToString:@"DELIVERY_DRIVER_PROVISIONING_AUTHORITY_REQUIRED"]) {
        message = kLang(@"DriverRegistration_WorkforceAuthorityRequired");
    } else if ([domainCode isEqualToString:@"DELIVERY_WORKFORCE_GRANT_REQUIRED"]) {
        message = kLang(@"DriverRegistration_ExistingStaffGrantRequired");
    } else if ([domainCode isEqualToString:@"DELIVERY_DRIVER_TARGET_ACCOUNT_INACTIVE"]) {
        message = kLang(@"DriverRegistration_AccountInactive");
    } else if ([domainCode isEqualToString:@"DELIVERY_DRIVER_TARGET_REGISTRATION_REQUIRED"]) {
        message = kLang(@"DriverRegistration_AccountRequired");
    } else if (error.code == FIRFunctionsErrorCodeUnauthenticated ||
        [lower containsString:@"unauthenticated"] ||
        [lower containsString:@"authentication is required"] ||
        [lower containsString:@"authentication required"]) {
        message = kLang(@"DeliveryCompany_Error_Unauthenticated");
    } else if (error.code == FIRFunctionsErrorCodePermissionDenied ||
               [lower containsString:@"not a member"] ||
               [lower containsString:@"permission denied"]) {
        message = kLang(@"DeliveryCompany_Error_NotMember");
    }

    // Keep the server's domainCode and recovery details when localizing the
    // message. Dropping them turns a permission denial into a generic outage.
    NSMutableDictionary *info = error.userInfo.mutableCopy ?: [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = message;
    info[NSUnderlyingErrorKey] = error;
    return [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:error.code userInfo:info];
}

- (void)callFunction:(NSString *)name
             payload:(NSDictionary *)payload
          completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:name payload:payload allowRetry:YES completion:completion];
}

- (void)callFunction:(NSString *)name
             payload:(NSDictionary *)payload
          allowRetry:(BOOL)allowRetry
          completion:(PPDeliveryCompanyActionCompletion)completion {
    FIRUser *currentUser = [FIRAuth auth].currentUser;
    if (!currentUser) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *authError = [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany"
                                                     code:FIRFunctionsErrorCodeUnauthenticated
                                                 userInfo:@{
                NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_NotLoggedIn")
            }];
            if (completion) completion(nil, authError);
        });
        return;
    }

    FIRHTTPSCallable *callable = [[FIRFunctions functionsForRegion:@"us-central1"] HTTPSCallableWithName:name];
    callable.timeoutInterval = 30.0;
    __weak typeof(self) weakSelf = self;
    [callable callWithObject:payload ?: @{} completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        if (error && allowRetry && (error.code == FIRFunctionsErrorCodeUnauthenticated ||
                                    [error.localizedDescription.lowercaseString containsString:@"unauthenticated"])) {
            [currentUser getIDTokenForcingRefresh:YES completion:^(__unused NSString * _Nullable token, __unused NSError * _Nullable tokenError) {
                #if __has_include(<FirebaseAppCheck/FirebaseAppCheck.h>) || defined(PP_FIREBASE_APP_CHECK_IMPORTED)
                [[FIRAppCheck appCheck] tokenForcingRefresh:YES completion:^(__unused FIRAppCheckToken * _Nullable appCheckToken, __unused NSError * _Nullable appCheckError) {
                    [weakSelf callFunction:name payload:payload allowRetry:NO completion:completion];
                }];
                #else
                [weakSelf callFunction:name payload:payload allowRetry:NO completion:completion];
                #endif
            }];
            return;
        }

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
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshConfiguredProfileWithCompletion:completion]; });
        return;
    }
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
    if (!self.profileRefreshCompletions) self.profileRefreshCompletions = [NSMutableArray array];
    if (completion) [self.profileRefreshCompletions addObject:[completion copy]];
    if (self.isRefreshingProfile) return;
    self.isRefreshingProfile = YES;
    [self callFunction:PPDCFunctionGetProfile
               payload:@{@"companyId": companyID}
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        self.isRefreshingProfile = NO;
        NSArray *completions = self.profileRefreshCompletions.copy;
        [self.profileRefreshCompletions removeAllObjects];
        void (^finish)(PPDeliveryCompanyProfile *, NSError *) = ^(PPDeliveryCompanyProfile *profile, NSError *profileError) {
            for (PPDeliveryCompanyProfileCompletion pending in completions) pending(profile, profileError);
        };
        NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
        if (![activeUID isEqualToString:currentUID]) {
            self.verifiedProfile = nil;
            self.discoveredProfiles = @[];
            self.verifiedUID = @"";
            NSError *sessionError = [NSError errorWithDomain:@"com.firebase.functions"
                                                       code:FIRFunctionsErrorCodeUnauthenticated
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Unauthenticated")}];
            finish(nil, sessionError);
            return;
        }
        if (![self.configuredCompanyID isEqualToString:companyID]) {
            // A response for a disconnected/replaced company cannot restore it.
            NSError *contextError = [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:2 userInfo:@{
                NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Setup_CompanyIDRequired"),
                @"details": @{@"domainCode": @"DELIVERY_COMPANY_NOT_CONFIGURED"}
            }];
            finish(nil, contextError);
            return;
        }
        if (error) {
            self.verifiedProfile = nil;
            self.discoveredProfiles = @[];
            self.verifiedUID = @"";
            [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
            finish(nil, error);
            return;
        }
        PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyProfile modelFromResponse:result ?: @{}];
        self.verifiedProfile = profile.companyID.length ? profile : nil;
        self.discoveredProfiles = self.verifiedProfile ? @[self.verifiedProfile] : @[];
        self.verifiedUID = self.verifiedProfile ? currentUID : @"";
        [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryCompanyMembershipDidChangeNotification object:self];
        NSError *profileError = self.verifiedProfile ? nil :
            [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:2
                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_InvalidProfile")}];
        finish(self.verifiedProfile, profileError);
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
            // A failed refresh cannot keep a delivery Home grant alive.
            self.discoveredProfiles = @[];
            self.driverWorkspaceUID = @"";
            self.deliveryWorkspaceUID = @"";
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<PPDeliveryCompanyProfile *> *profiles = [NSMutableArray array];
        NSArray *items = [result[@"companies"] isKindOfClass:NSArray.class] ? result[@"companies"] : @[];
        BOOL anyDriverWorkspace = NO;
        BOOL anyDeliveryWorkspace = NO;
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:NSDictionary.class]) {
                continue;
            }
            PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyProfile modelFromResponse:item];
            if (profile.companyID.length > 0) {
                [profiles addObject:profile];
                if (profile.hasDriverWorkspace) anyDriverWorkspace = YES;
                if (profile.hasDriverWorkspace || profile.hasDispatchWorkspace) anyDeliveryWorkspace = YES;
            }
        }
        self.discoveredProfiles = profiles.copy;
        self.deliveryWorkspaceUID = anyDeliveryWorkspace ? currentUID : @"";
        self.driverWorkspaceUID = anyDriverWorkspace ? currentUID : @"";
        if (anyDriverWorkspace) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryDriverWorkspaceConfirmedNotification object:self];
        }
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
    if (profile.companyID.length == 0) {
        NSError *contextError = [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:2 userInfo:@{
            NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Setup_CompanyIDRequired"),
            @"details": @{@"domainCode": @"DELIVERY_COMPANY_NOT_CONFIGURED"}
        }];
        if (completion) completion(nil, nil, contextError);
        return;
    }
    BOOL driver = profile.isDriver;
    if (profile.isRestrictedWorkspace) {
        // A restricted membership has no workspace to list; asking the
        // dispatcher endpoint would only return a permission error.
        if (completion) completion(@[], nil, nil);
        return;
    }
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
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self inviteMemberIdentifier:identifier role:role companyID:companyID completion:completion];
        });
        return;
    }
    NSString *issuerUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSData *identity = [NSJSONSerialization dataWithJSONObject:@[issuerUID, companyID ?: @"", identifier, role ?: @""] options:0 error:nil];
    NSString *identityKey = [[NSString alloc] initWithData:identity encoding:NSUTF8StringEncoding];
    if (!self.memberInvitationCommandIDs) self.memberInvitationCommandIDs = [NSMutableDictionary dictionary];
    NSString *commandID = self.memberInvitationCommandIDs[identityKey];
    if (!commandID) {
        commandID = NSUUID.UUID.UUIDString;
        self.memberInvitationCommandIDs[identityKey] = commandID;
    }
    [self callFunction:PPDCFunctionInviteMember
               payload:@{
        @"companyId": companyID ?: @"",
        @"targetIdentifier": identifier,
        @"targetUid": identifier,
        @"role": role ?: @"",
        @"commandId": commandID
    }
            completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (![[FIRAuth auth].currentUser.uid isEqualToString:issuerUID]) return;
        if (!error) [self.memberInvitationCommandIDs removeObjectForKey:identityKey];
        if (completion) completion(result, error);
    }];
}
- (void)disableMemberUID:(NSString *)targetUID companyID:(NSString *)companyID completion:(PPDeliveryCompanyActionCompletion)completion {
    [self callFunction:PPDCFunctionDisableMember payload:@{@"companyId": companyID ?: @"", @"targetUid": targetUID ?: @""} completion:completion];
}

#pragma mark - Driver cockpit

+ (NSString *)currentAccountUID {
    return [FIRAuth auth].currentUser.uid ?: @"";
}

- (void)resolveDriverCockpitRequirementWithCompletion:(void(^)(BOOL requiresDriverCockpit, NSError * _Nullable error))completion {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (!uid.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, [NSError errorWithDomain:@"com.firebase.functions" code:FIRFunctionsErrorCodeUnauthenticated
                                           userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Unauthenticated")}]);
        });
        return;
    }
    [[AppManager shared] checkIfUserWithUID:uid canAccessPro:^(BOOL allowed, NSDictionary * _Nullable userDoc, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *activeUID = [FIRAuth auth].currentUser.uid ?: @"";
            if (![activeUID isEqualToString:uid]) {
                completion(NO, [NSError errorWithDomain:@"com.firebase.functions" code:FIRFunctionsErrorCodeUnauthenticated
                                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Unauthenticated")}]);
                return;
            }
            if (error) { completion(NO, error); return; }
            if ([AppManager isProAccountBlocked:userDoc ?: @{}]) {
                completion(NO, [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:403
                                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"StatusAccountBlocked")}]);
                return;
            }
            NSString *accountType = [PPSafeString(userDoc[@"accountType"]).lowercaseString
                                    stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            // Staff never operates through the provider-only transition API.
            // The canonical cockpit independently resolves grants or recovery.
            if ([accountType isEqualToString:@"staff"]) { completion(YES, nil); return; }
            if (![accountType isEqualToString:@"user"]) {
                completion(NO, [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:403
                                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"StatusNoPartnerAccess")}]);
                return;
            }
            [self discoverCompanyMembershipsWithCompletion:^(NSArray<PPDeliveryCompanyProfile *> * _Nullable profiles, NSError * _Nullable membershipError) {
                if (![[FIRAuth auth].currentUser.uid isEqualToString:uid]) {
                    completion(NO, [NSError errorWithDomain:@"com.firebase.functions" code:FIRFunctionsErrorCodeUnauthenticated
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Error_Unauthenticated")}]);
                    return;
                }
                if (membershipError) { completion(NO, membershipError); return; }
                for (PPDeliveryCompanyProfile *profile in profiles ?: @[]) {
                    if (profile.hasDriverWorkspace || profile.isRestrictedWorkspace ||
                        [profile.role isEqualToString:PPDeliveryCompanyRoleDriver]) {
                        completion(YES, nil);
                        return;
                    }
                }
                if (!allowed) {
                    completion(NO, [NSError errorWithDomain:@"PurePetsPro.DeliveryCompany" code:403
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"StatusNoPartnerAccess")}]);
                    return;
                }
                completion(NO, nil);
            }];
        });
    }];
}

- (NSObject *)observeOwnDriverAcceptanceForCompanyID:(NSString *)companyID
                                         completion:(void(^)(BOOL, NSError *))completion {
    PPDriverAcceptanceObservation *token = [PPDriverAcceptanceObservation new];
    NSString *uid = FIRAuth.auth.currentUser.uid ?: @"";
    if (!uid.length || !companyID.length || [companyID containsString:@"/"]) return token;
    FIRCollectionReference *companies = [[FIRFirestore firestore] collectionWithPath:@"deliveryCompanies"];
    FIRDocumentReference *member = [[[companies documentWithPath:companyID]
        collectionWithPath:@"members"] documentWithPath:uid];
    __weak PPDriverAcceptanceObservation *weakToken = token;
    token.registration = [member addSnapshotListenerWithIncludeMetadataChanges:YES listener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        // Metadata-only server confirmation matters when the first copy came
        // from cache. Neither cached grants nor pending local writes enable a claim.
        BOOL confirmed = snapshot && !snapshot.metadata.fromCache && !snapshot.metadata.hasPendingWrites;
        NSError *policyError = error;
        if (!policyError && !confirmed) {
            policyError = [NSError errorWithDomain:@"PurePetsPro.DriverCockpit" code:503
                userInfo:@{NSLocalizedDescriptionKey: kLang(@"Delivery_Driver_Acceptance_Sync_Error")}];
        }
        NSDictionary *data = [snapshot.data isKindOfClass:NSDictionary.class] ? snapshot.data : @{};
        BOOL restricted = [data[@"isActive"] isEqual:@NO];
        for (NSString *field in @[@"blocked", @"isBlocked", @"banned", @"disabled", @"isDisabled",
                                  @"suspended", @"isSuspended", @"deleted", @"isDeleted", @"deactivated"]) {
            if ([data[field] isEqual:@YES]) { restricted = YES; break; }
        }
        NSString *accountStatus = [data[@"accountStatus"] isKindOfClass:NSString.class] ?
            [[data[@"accountStatus"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString] : @"";
        id memberUID = data[@"uid"], memberCompanyID = data[@"companyId"];
        BOOL uidMatches = !memberUID || memberUID == NSNull.null || [memberUID isEqual:@""] || [memberUID isEqual:uid];
        BOOL companyMatches = !memberCompanyID || memberCompanyID == NSNull.null || [memberCompanyID isEqual:@""] || [memberCompanyID isEqual:companyID];
        id grant = data[@"canSelfAcceptOrders"];
        BOOL explicitGrant = [grant isKindOfClass:NSNumber.class] &&
            CFGetTypeID((__bridge CFTypeRef)grant) == CFBooleanGetTypeID() && [grant boolValue];
        BOOL allowed = !policyError && confirmed && snapshot.exists && uidMatches && companyMatches && [data[@"status"] isEqual:@"active"] &&
            !restricted && (!accountStatus.length || [accountStatus isEqual:@"active"]) &&
            [data[@"role"] isEqual:@"driver"] && explicitGrant;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakToken || ![FIRAuth.auth.currentUser.uid ?: @"" isEqualToString:uid]) return;
            if (completion) completion(allowed, policyError);
        });
    }];
    return token;
}

- (void)callDriverCockpitFunction:(NSString *)name
                          payload:(NSDictionary<NSString *,id> *)payload
                       completion:(PPDriverCockpitCompletion)completion {
    static NSSet<NSString *> *allowedFunctions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedFunctions = [NSSet setWithArray:@[
            @"getDriverDeliveryWorkspace",
            @"executeDriverDeliveryTask",
            @"setDriverDeliveryAvailability",
            PPDCFunctionGetMyCompanies,
            PPDCFunctionListAssigned,
            PPDCFunctionGetRequest,
            PPDCFunctionUpdateStatus,
            PPDCFunctionAssign,
            @"setCompanyDriverAvailability",
        ]];
    });
    if (![allowedFunctions containsObject:name ?: @""]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"PurePetsPro.DriverCockpit"
                                                 code:FIRFunctionsErrorCodeInvalidArgument
                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"DriverCockpit_Error_Generic")}];
            if (completion) completion(nil, error);
        });
        return;
    }
    [self callFunction:name payload:payload ?: @{} completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        // These calls succeed only for an authorized driver, official or partner.
        static NSSet<NSString *> *driverConfirmingFunctions;
        static dispatch_once_t confirmOnce;
        dispatch_once(&confirmOnce, ^{
            driverConfirmingFunctions = [NSSet setWithArray:@[@"getDriverDeliveryWorkspace", @"setDriverDeliveryAvailability",
                                                              PPDCFunctionListAssigned, @"setCompanyDriverAvailability"]];
        });
        if (!error && [driverConfirmingFunctions containsObject:name]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PPDeliveryDriverWorkspaceConfirmedNotification object:self];
        }
        if (completion) completion(result, error);
    }];
}

- (PPDeliveryCompanyProfile *)preferredProfileFromProfiles:(NSArray<PPDeliveryCompanyProfile *> *)profiles
                                         requiresSelection:(BOOL *)requiresSelection {
    if (requiresSelection) *requiresSelection = NO;
    NSMutableArray<PPDeliveryCompanyProfile *> *usable = [NSMutableArray array];
    for (PPDeliveryCompanyProfile *profile in profiles ?: @[]) {
        if (profile.companyID.length > 0 && !profile.isRestrictedWorkspace) [usable addObject:profile];
    }
    NSString *configured = self.configuredCompanyID;
    if (configured.length > 0) {
        for (PPDeliveryCompanyProfile *profile in usable) {
            if ([profile.companyID isEqualToString:configured]) return profile;
        }
    }
    if (usable.count == 1) return usable.firstObject;
    if (usable.count > 1) {
        if (requiresSelection) *requiresSelection = YES;
        // The dashboard is company-centric, so a dispatch workspace leads;
        // driver work stays reachable through the cockpit's own chooser.
        for (PPDeliveryCompanyProfile *profile in usable) {
            if (profile.hasDispatchWorkspace) return profile;
        }
        return usable.firstObject;
    }
    for (PPDeliveryCompanyProfile *profile in profiles ?: @[]) {
        if (profile.companyID.length > 0) return profile;
    }
    return nil;
}

- (BOOL)hasDiscoveredDriverWorkspace {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    return uid.length > 0 && [self.driverWorkspaceUID isEqualToString:uid];
}

- (BOOL)hasDiscoveredDeliveryWorkspace {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    return uid.length > 0 && [self.deliveryWorkspaceUID isEqualToString:uid];
}

@end
