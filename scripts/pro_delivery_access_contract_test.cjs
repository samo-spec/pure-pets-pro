// Source-contract checks only. Native behavior still requires an authorized iPhone run.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const service = read('PurePetsPro/DeliveryCompanySection/PPDeliveryService.m');
const company = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyService.m');
const view = read('PurePetsPro/DeliveryCompanySection/PPDeliveryListView.swift');
const method = (source, start, end) => {
  const begin = source.indexOf(start);
  const finish = source.indexOf(end, begin + start.length);
  assert(begin >= 0 && finish > begin, `Missing method boundary: ${start}`);
  return source.slice(begin, finish);
};
let passed = 0;
function check(name, body) { body(); passed++; console.log(`PASS ${name}`); }

check('localized errors retain backend details and original error', () => {
  const body = method(company, '- (NSError *)normalizedError:', '- (void)callFunction:');
  assert(body.includes('error.userInfo.mutableCopy'));
  assert(body.includes('info[NSUnderlyingErrorKey] = error'));
});
check('classification follows bounded underlying errors', () => {
  for (const body of [
    method(service, '+ (NSDictionary<NSString *,id> *)domainDetailsForError:', '+ (NSString *)domainCodeForError:'),
    method(service, '+ (BOOL)isPermissionError:', '#pragma mark - Command Center'),
  ]) {
    assert(body.includes('NSUnderlyingErrorKey'));
    assert(body.includes('depth < 8'));
    assert(body.includes('underlying != current'));
  }
});
check('company-normalized permission and unauthenticated errors stay classified', () => {
  const body = method(service, '+ (BOOL)isPermissionError:', '#pragma mark - Command Center');
  assert(body.includes('@"PurePetsPro.DeliveryCompany"'));
  assert(body.includes('FIRFunctionsErrorCodePermissionDenied'));
  assert(body.includes('FIRFunctionsErrorCodeUnauthenticated'));
});
check('company verification precedes workspace requests', () => {
  const body = method(service, '- (void)fetchCommandCenterWithCompletion:', '- (void)fetchVerifiedCommandCenterForProfile:');
  assert(body.indexOf('refreshConfiguredProfileWithCompletion:') < body.indexOf('fetchVerifiedCommandCenterForProfile:'));
  assert(body.includes('if (error || profile.companyID.length == 0)'));
  assert(body.includes('error ?: PPDeliveryCompanyContextError()'));
  assert(!body.includes('callFunction:'));
});
check('drivers select the company path before the staff endpoint', () => {
  const body = method(service, '- (void)fetchVerifiedCommandCenterForProfile:', '- (void)fetchPartnerCommandCenterSnapshotWithCompletion:');
  assert(body.indexOf('if (profile.isDriver)') < body.indexOf('callFunction:@"getDeliveryCommandCenter"'));
  assert(body.includes('@"companyId": profile.companyID'));
  assert(body.includes('currentUser.uid isEqualToString:uid'));
});
check('transport or malformed responses never trigger an alternate authority', () => {
  for (const body of [
    method(service, '- (void)fetchVerifiedCommandCenterForProfile:', '- (void)fetchPartnerCommandCenterSnapshotWithCompletion:'),
    method(service, '- (void)fetchDossierForRequestID:', '- (void)fetchPartnerDossierForRequestID:'),
  ]) {
    assert(body.includes('error.code == FIRFunctionsErrorCodePermissionDenied && [PPDeliveryService isPermissionError:error]'));
    assert(body.includes('completion(nil, error ?: PPDeliveryInvalidResponseError())'));
  }
});
check('request lists cannot send an empty company identifier', () => {
  const body = method(company, '- (void)listRequestsForProfile:', '- (void)getRequestWithID:');
  assert(body.indexOf('if (profile.companyID.length == 0)') < body.indexOf('[self callFunction:'));
  assert(body.includes('@"DELIVERY_COMPANY_NOT_CONFIGURED"'));
});
check('simultaneous profile readers wait for the actual verification result', () => {
  const body = method(company, '- (void)refreshConfiguredProfileWithCompletion:', '- (void)discoverCompanyMembershipsWithCompletion:');
  assert(body.includes('profileRefreshCompletions addObject:'));
  assert(body.includes('if (self.isRefreshingProfile) return;'));
  assert(!body.includes('completion(self.verifiedProfile, nil)'));
  assert(body.includes('finish(nil, error)'));
  assert(body.includes('finish(nil, sessionError)'));
  assert(body.includes('if (![self.configuredCompanyID isEqualToString:companyID])'));
  assert(body.includes('finish(nil, contextError)'));
});
check('unverified company header makes no official-fleet claim', () => {
  const body = method(view, 'private var companyDisplayName:', 'private var utilityTabs:');
  assert(body.includes('deliveryText("DeliveryCompany_Title")'));
  assert(!body.includes('DeliveryCompany_Official_Name'));
  assert(!body.includes('DeliveryWorkspace_FleetCaption'));
  assert(body.includes('PPDeliveryCompanyRoleDisplayName(profile.role.rawValue)'));
});
check('recovery and company context keys exist in both languages', () => {
  const keys = ['DeliveryCompany_Title', 'DeliveryCompany_DashboardShell_OpenCompanySubtitle',
    'DeliveryCompany_Setup_CompanyIDRequired', 'DeliveryCompany_Error_InvalidProfile',
    'Delivery_Error_State_Access_Denied', 'Delivery_Error_Cause_Permission',
    'Delivery_Error_Recovery_Request_Access'];
  for (const language of ['ar', 'en']) {
    const strings = read(`PurePetsPro/${language}.lproj/Localizable.strings`);
    for (const key of keys) assert(new RegExp(`"${key}"\\s*=`).test(strings), `${language}: ${key}`);
  }
});
check('Home requires provider identity before starting or requiring the provider fulfillment feed', () => {
  const home = read('PurePetsPro/AdminDashboardViewController.m');
  const gate = method(home, '- (BOOL)pp_shouldObserveProviderFulfillmentForUser:(UserModel *)user {',
    '- (PPProCommandDataSource)pp_requiredCommandDataSourcesForUser:(UserModel *)user {');
  assert(gate.includes('[user.accountType isEqualToString:@"user"]'));
  assert(!/\.role|isAdmin|isOwner|canAccessPro|FIRFirestore/.test(gate));
  const required = method(home, '- (PPProCommandDataSource)pp_requiredCommandDataSourcesForUser:(UserModel *)user {',
    '- (void)pp_beginCommandDataSources:');
  assert(required.includes('if ([self pp_shouldObserveProviderFulfillmentForUser:user])'));
  const start = method(home, '- (void)pp_startQuickActionSignalObserversForUser:(UserModel *)user {',
    '- (void)pp_stopQuickActionSignalObservers {');
  assert(start.includes('BOOL observesFulfillment = uid.length > 0 && [self pp_shouldObserveProviderFulfillmentForUser:user]'));
});
check('Canonical account type is a read-only profile projection with backward-compatible secure cache', () => {
  const header = read('PurePetsPro/AdminCore/Models/UserModel.h');
  const model = read('PurePetsPro/AdminCore/Models/UserModel.m');
  assert(header.includes('@property (nonatomic, copy, readonly) NSString *accountType;'));
  const parse = method(model, '- (void)pp_applyDictionary:(NSDictionary *)dict fallbackDocumentID:(nullable NSString *)fallbackDocumentID {',
    '- (NSDictionary *)toDictionary {');
  assert(parse.includes('safeDict[kUserKeyAccountType]'));
  assert(!parse.includes('self.accountType = @"user"'));
  const encode = method(model, '- (void)encodeWithCoder:', '- (instancetype)initWithCoder:');
  assert(encode.includes('[coder encodeObject:self.accountType forKey:kUserKeyAccountType]'));
  const decode = method(model, '- (instancetype)initWithCoder:', '#pragma mark -');
  assert(decode.includes('decodeObjectOfClass:NSString.class forKey:kUserKeyAccountType'));
  assert(decode.includes('PPSafeString'));
});
check('Account type is never serialized into a client profile write', () => {
  const model = read('PurePetsPro/AdminCore/Models/UserModel.m');
  const write = method(model, '- (NSDictionary *)toDictionary {', '- (void)SYNC:');
  assert(!/dict\[kUserKeyAccountType\]\s*=/.test(write));
  assert(!/dict\[@"accountType"\]\s*=/.test(write));
  const home = read('PurePetsPro/AdminDashboardViewController.m');
  const finish = method(home, '- (void)pp_finishCommandDataSource:(PPProCommandDataSource)source error:(NSError *)error {',
    '- (void)pp_clearCommandDataSources:');
  assert(finish.includes('self.commandDegradedSources |= source'));
  assert(finish.includes('self.commandDegradedSources &= ~source'));
});
console.log(`PASS ${passed} source contracts. Native runtime is UNVERIFIED.`);
