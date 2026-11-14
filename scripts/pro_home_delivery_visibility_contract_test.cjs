/* Source contracts only: no Firebase calls, app build or native runtime claim. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
const service = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyService.m');
const header = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyService.h');
const dashboard = read('PurePetsPro/AdminDashboardViewController.m');
const surface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
const models = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyModels.m');
function section(source, start, end) {
  const a = source.indexOf(start);
  assert(a >= 0, `Missing source owner: ${start}`);
  const b = end ? source.indexOf(end, a + start.length) : source.length;
  assert(b > a, `Missing boundary: ${end}`);
  return source.slice(a, b);
}
const discovery = section(service, '- (void)discoverCompanyMembershipsWithCompletion:', '- (void)verifyAndStoreCompanyID:');
const homeAccess = section(service, '- (BOOL)hasDiscoveredDeliveryWorkspace {', '\n@end');
const refresh = section(dashboard, '- (void)pp_refreshDeliveryCompanyMembership {', '- (void)pp_refreshDeliveryCompanyDashboardSummary {');
const snapshot = section(dashboard, '- (void)pp_refreshCommandCenterSnapshot {', '\n- (');
const pulse = section(surface, 'struct PPProPulseView:', 'private struct PPProMoreDestinationView');
let passed = 0;
const check = (name, body) => { body(); passed++; console.log(`PASS ${name}`); };

check('Home access is a read-only service projection, not a user feature or remembered company', () => {
  assert(header.includes('readonly) BOOL hasDiscoveredDeliveryWorkspace;'));
  assert(discovery.includes('profile.hasDriverWorkspace || profile.hasDispatchWorkspace'));
  assert(discovery.includes('self.deliveryWorkspaceUID = anyDeliveryWorkspace ? currentUID : @"";'));
  assert(!/canDelivery|features|isAdmin|isStaff|configuredCompanyID|NSUserDefaults|\.role/.test(homeAccess));
});
check('unknown or changed accounts cannot reuse the previous Home grant', () => {
  assert(homeAccess.includes('return uid.length > 0 && [self.deliveryWorkspaceUID isEqualToString:uid];'));
  assert(discovery.includes('if (![activeUID isEqualToString:currentUID])'));
  assert(discovery.indexOf('if (![activeUID isEqualToString:currentUID])') < discovery.indexOf('self.deliveryWorkspaceUID = anyDeliveryWorkspace'));
});
check('failed membership discovery clears all Home grant inputs before returning the error', () => {
  const error = section(discovery, '        if (error) {', '        NSMutableArray');
  for (const token of ['self.discoveredProfiles = @[];', 'self.driverWorkspaceUID = @"";', 'self.deliveryWorkspaceUID = @"";']) {
    assert(error.includes(token), token);
    assert(error.indexOf(token) < error.indexOf('if (completion) completion(nil, error);'));
  }
});
check('only server driver and fleet workspace kinds qualify; restricted and legacy roles do not', () => {
  const driver = section(models, '- (BOOL)hasDriverWorkspace {', '- (BOOL)hasDispatchWorkspace {');
  const fleet = section(models, '- (BOOL)hasDispatchWorkspace {', '- (BOOL)isOfficialDriverWorkspace');
  for (const token of ['PPDeliveryWorkspaceKindOfficialDriver', 'PPDeliveryWorkspaceKindPartnerDriver']) assert(driver.includes(token));
  for (const token of ['PPDeliveryWorkspaceKindPartnerDispatch', 'PPDeliveryWorkspaceKindOfficialFleetStaff']) assert(fleet.includes(token));
  assert(!/Restricted|\.role|canDeliveryFeature/.test(driver + fleet));
});
check('Home resolves all memberships, including a driver in a different company, once per account refresh', () => {
  assert(refresh.includes('if ([self.refreshingDeliveryHomeUID isEqualToString:requestedUID]) return;'));
  assert(refresh.includes('discoverCompanyMembershipsWithCompletion:'));
  assert(refresh.includes('if (![[FIRAuth auth].currentUser.uid isEqualToString:requestedUID]) return;'));
  assert(refresh.includes('return profile.hasDriverWorkspace || profile.hasDispatchWorkspace;'));
  assert(refresh.includes('error ? @[]'));
  assert(!/verifyAndStoreCompanyID|setConfiguredCompanyID|setData:|updateData:/.test(refresh));
});
check('a selected-company refresh cannot replace the full discovery result used by Home', () => {
  const configuredRefresh = section(service, '- (void)refreshConfiguredProfileWithCompletion:', '- (void)discoverCompanyMembershipsWithCompletion:');
  const storeSelection = section(service, '- (void)storeVerifiedProfile:', '- (void)listRequestsForProfile:');
  assert(!configuredRefresh.includes('deliveryWorkspaceUID'));
  assert(!storeSelection.includes('deliveryWorkspaceUID'));
  assert(!homeAccess.includes('self.discoveredProfiles'));
});
check('an older account refresh cannot clear or apply the newer Home request', () => {
  const generationGuard = refresh.indexOf('if (strongSelf.deliveryHomeMembershipGeneration != generation) return;');
  assert(generationGuard > 0);
  assert(generationGuard < refresh.indexOf('strongSelf.refreshingDeliveryHomeUID = nil;'));
  assert(generationGuard < refresh.indexOf('[strongSelf pp_applyDeliveryCompanyProfile:profile]'));
  assert(refresh.includes('NSUInteger generation = ++self.deliveryHomeMembershipGeneration;'));
});
check('the Home membership refresh calls the declared profile selector without inventing an API', () => {
  assert(/preferredProfileFromProfiles:\(NSArray<PPDeliveryCompanyProfile \*> \*\)profiles\s+requiresSelection:/.test(header));
  assert(/preferredProfileFromProfiles:authorized\s+requiresSelection:NULL/.test(refresh));
});
check('pharmacy, vet and provider delivery flags alone cannot emit a Home delivery capability', () => {
  assert(snapshot.includes('BOOL hasDeliveryCompany = PPDeliveryCompanyService.shared.hasDiscoveredDeliveryWorkspace;'));
  assert(snapshot.includes('BOOL canManageDelivery = hasDeliveryCompany && [self pp_canManageDelivery];'));
  assert(snapshot.includes('if (hasDeliveryCompany) {'));
  assert(snapshot.includes('if (canManageDelivery) {'));
  assert(!snapshot.includes('BOOL hasDeliveryCompany = [self pp_hasDeliveryCompanyWorkspaceForUser:user];'));
});
check('driver discovery remains separate from fleet-only and selected-company role inference', () => {
  assert(snapshot.includes('BOOL hasDriverDelivery = hasDeliveryCompany && PPDeliveryCompanyService.shared.hasDiscoveredDriverWorkspace;'));
  const extraDriver = section(snapshot, 'if (hasDriverDelivery &&', '    if (canManageDelivery)');
  assert(extraDriver.includes('routeTag:@"driverCockpit"'));
  assert(!/PPDeliveryCompanyRoleDriver|isAdmin|\.isDriver/.test(extraDriver));
});
check('delivery counts and header describe only the same authorized Home doors', () => {
  assert(snapshot.includes('NSInteger deliveryCount = canManageDelivery ? [self pp_dashboardHeroDeliveryActionCount] : 0;'));
  assert(snapshot.includes('NSInteger deliveryCompanyCount = hasDeliveryCompany ? [self pp_dashboardHeroDeliveryCompanyActionCount] : 0;'));
  assert(snapshot.includes('for (PPProCommandCapabilityDescriptor *capability in capabilities)'));
  assert(snapshot.includes('snapshot.roleSummary = [visibleWorkspaceTitles componentsJoinedByString:@" & "];'));
});
check('My Deliveries requires the driver route, so a fleet-only account never gets a personal driver error card', () => {
  const delivery = section(pulse, 'private var deliverySection: some View {', 'private var workspaceBand:');
  assert(delivery.includes('let driverRoute = driverWorkspaceRoute'));
  assert(delivery.includes('driverHomeStore.boundUID == PPDeliveryCompanyService.currentAccountUID()'));
  assert(delivery.includes('PPDriverHomeAvailabilitySection'));
  assert(!delivery.includes('PPDeliveryHomeEntrySection('));
});
check('revocation and account changes release the Home driver store without a compatibility fallback', () => {
  const reconcile = section(pulse, 'private func reconcileDriverHomeStore() {', '// MARK: Command bar');
  assert(reconcile.includes('guard hasDeliveryCapability, driverWorkspaceRoute != nil, !uid.isEmpty else'));
  assert(reconcile.includes('driverHomeStore?.setVisible(false)'));
  assert(reconcile.includes('driverHomeStore = nil'));
  assert(pulse.includes('.onChange(of: driverWorkspaceRoute)'));
  assert(pulse.includes('.onChange(of: PPDeliveryCompanyService.currentAccountUID())'));
});
check('other provider workspaces and the backend command boundary remain in their existing owners', () => {
  for (const identifier of ['fulfillment', 'marketplace', 'pharmacy', 'services', 'veterinary', 'adoption']) {
    assert(snapshot.includes(`pp_commandCapabilityWithIdentifier:@"${identifier}"`), identifier);
  }
  assert(!/setData:|updateData:|setCustomUserClaims|executeDriverDeliveryTask/.test(refresh + homeAccess));
});
console.log(`PASS ${passed} Home delivery visibility source contracts. Native runtime is UNVERIFIED.`);
