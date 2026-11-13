// Source-contract checks for the unified driver cockpit (official Pure Pets
// fleet + partner fleets). They prove wiring and invariants in source only;
// native behavior still requires an authorized physical-device run.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const slice = (source, start, end) => {
  const begin = source.indexOf(start);
  const finish = source.indexOf(end, begin + start.length);
  assert(begin >= 0 && finish > begin, `Missing boundary: ${start}`);
  return source.slice(begin, finish);
};
// Objective-C methods are often declared in a class extension before they are
// defined; this skips declarations (ending in ";") and slices the definition.
const method = (source, start, end) => {
  let begin = source.indexOf(start);
  while (begin >= 0) {
    const brace = source.indexOf('{', begin);
    const semicolon = source.indexOf(';', begin);
    if (brace >= 0 && (semicolon < 0 || brace < semicolon)) break;
    begin = source.indexOf(start, begin + start.length);
  }
  assert(begin >= 0, `Missing definition: ${start}`);
  const finish = source.indexOf(end, begin + start.length);
  assert(finish > begin, `Missing boundary after: ${start}`);
  return source.slice(begin, finish);
};

const project = read('PurePetsPro.xcodeproj/project.pbxproj');
const models = read('PurePetsPro/DeliverySection/PPDriverCockpitModels.swift');
const view = read('PurePetsPro/DeliverySection/PPDriverCockpitView.swift');
const legacyModels = read('PurePetsPro/DeliverySection/PPDeliveryDriverModels.swift');
const legacyControl = read('PurePetsPro/DeliverySection/PPDeliveryDriverControlView.swift');
const legacyHome = read('PurePetsPro/DeliverySection/PPDeliveryDriverHomeControlSection.swift');
const companyService = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyService.m');
const companyModels = read('PurePetsPro/DeliveryCompanySection/PPDeliveryCompanyModels.m');
const deliveryService = read('PurePetsPro/DeliveryCompanySection/PPDeliveryService.m');
const scene = read('PurePetsPro/SceneDelegate.m');
const sceneHeader = read('PurePetsPro/SceneDelegate.h');
const appDelegate = read('PurePetsPro/AppDelegate.m');
const login = read('PurePetsPro/AdminCore/Auth/AdminLoginViewController.m');
const dashboard = read('PurePetsPro/AdminDashboardViewController.m');
const tabBar = read('PurePetsPro/Main Controllers/PPProRootTabBarController.swift');
const targets = read('PurePetsPro/NotificationsSection/NotificationManager+Targets.m');
const strings = {
  en: read('PurePetsPro/en.lproj/Localizable.strings'),
  ar: read('PurePetsPro/ar.lproj/Localizable.strings'),
};

let passed = 0;
function check(name, body) { body(); passed++; console.log(`PASS ${name}`); }

check('both cockpit sources are compiled by the app target', () => {
  for (const file of ['PPDriverCockpitModels.swift', 'PPDriverCockpitView.swift']) {
    const ref = new RegExp(`(\\w{24}) /\\* ${file} \\*/ = \\{isa = PBXFileReference;`).exec(project);
    assert(ref, `${file}: missing file reference`);
    const build = new RegExp(`(\\w{24}) /\\* ${file} in Sources \\*/ = \\{isa = PBXBuildFile; fileRef = ${ref[1]} `).exec(project);
    assert(build, `${file}: missing build file`);
    const appSources = slice(project, 'F2B41E8E2E5647BD0054D8CD /* Sources */ = {', 'runOnlyForDeploymentPostprocessing');
    assert(appSources.includes(`${build[1]} /* ${file} in Sources */`), `${file}: not in the app Sources phase`);
    assert(project.includes(`${ref[1]} /* ${file} */,`), `${file}: not in a group`);
  }
});

check('cockpit transport is an allowlist of driver callables only', () => {
  const body = method(companyService, '- (void)callDriverCockpitFunction:', '- (PPDeliveryCompanyProfile *)preferredProfileFromProfiles:');
  for (const name of ['getDriverDeliveryWorkspace', 'executeDriverDeliveryTask', 'setDriverDeliveryAvailability',
    'PPDCFunctionGetMyCompanies', 'PPDCFunctionListAssigned', 'PPDCFunctionGetRequest', 'PPDCFunctionUpdateStatus',
    'setCompanyDriverAvailability']) {
    assert(body.includes(name), `allowlist lacks ${name}`);
  }
  assert(body.includes('if (![allowedFunctions containsObject:name ?: @""])'));
  const called = new Set([...models.matchAll(/call\("([A-Za-z]+)"/g)].map(match => match[1]));
  for (const name of called) {
    assert(['getMyDeliveryCompanies', 'getDriverDeliveryWorkspace', 'listMyAssignedCompanyDeliveries',
      'getCompanyDeliveryRequest'].includes(name), `unexpected cockpit read ${name}`);
  }
  assert(models.includes('action.code == "CLAIM" ? "assignCompanyDeliveryDriver" : "updateCompanyDeliveryStatus"'));
  assert(models.includes('"setDriverDeliveryAvailability" : "setCompanyDriverAvailability"'));
  assert(!/collection\(|Firestore\.firestore|FIRFirestore/.test(models + view), 'cockpit must not read Firestore directly');
});

check('self-acceptance is company-controlled and live revocation clears offers', () => {
  assert(models.includes('var canSelfAcceptOrders: Bool'));
  assert(models.includes('context.capabilities["claimOffers"] == true'));
  assert(models.includes('guard self.loadsOffers && self.canSelfAcceptOrders else'));
  assert(models.includes('guard action.code != "CLAIM" || canSelfAcceptOrders else'));
  const observation = slice(models, 'private func observeAcceptancePolicy()', 'private func installObservers()');
  assert(observation.includes('self.liveSelfAcceptance = allowed'));
  assert(observation.includes('self.offers = []'));
  assert(observation.includes('self.isSameAccount()'));
  assert(companyService.includes('addSnapshotListenerWithIncludeMetadataChanges:YES'));
  assert(companyService.includes('!snapshot.metadata.fromCache && !snapshot.metadata.hasPendingWrites'));
  assert(companyService.includes('BOOL allowed = !policyError && confirmed && snapshot.exists'));
  assert(companyService.includes('- (void)dealloc { [_registration remove]; }'));
  assert(models.includes('acceptanceObservationNeedsRetry = !confirmed'));
  assert(models.includes('if acceptanceObservationNeedsRetry && isVisible'));
  assert(!/setDriverSelfAcceptance|setDeliveryDriverAcceptancePolicy/.test(legacyHome + view),
    'driver Home and cockpit may display a mode, never edit their own grant');
  assert(view.includes('.accessibilityIdentifier("driver.acceptance.mode")'));
  assert(models.includes('mine: projection["mine"] == nil ? true : cpBool(projection["mine"])'));
});

check('company permission changes require a current target revision and fresh readback', () => {
  const permission = method(deliveryService, '- (void)setDriverSelfAcceptance:', '- (void)fetchCompanyMembersForCompanyID:');
  for (const token of ['setDeliveryDriverAcceptancePolicy','@"companyId"','@"driverUid"','@"canSelfAcceptOrders"',
    '@"expectedRevision"','@"commandId"','@"reason"','fetchCompanyMembersForCompanyID',
    'member.canSelfAcceptOrders == allowed','member.revision >= revision.integerValue']) assert(permission.includes(token), token);
  assert(permission.includes('@"driver_self_acceptance.enabled"'), 'retry identity uses stable audit reason codes');
  assert.equal((permission.match(/currentUser\.uid isEqualToString:actorUID/g) || []).length, 2,
    'command receipt and member readback both stay bound to the issuing account');
});

check('success appears only after the backend confirms the command', () => {
  const body = slice(models, 'private func send(_ command: PPDriverCommand, isRetry: Bool)', 'private func handleCommandFailure');
  const success = body.indexOf('case .success:');
  assert(success > 0);
  assert(body.indexOf('tone: .success') > success, 'success notice must be inside the confirmed branch');
  assert(body.indexOf('DriverCockpit_Notice_Waiting') < success, 'pending state precedes the result');
  assert(body.includes('guard self.isSameAccount() else'), 'responses for another account are dropped');
});

check('an uncertain outcome keeps the same command for a safe retry', () => {
  const failure = slice(models, 'private func handleCommandFailure', 'private func verifyPendingCommand');
  assert(/case \.transport, \.unknown:[\s\S]*uncertainCommand = command/.test(failure));
  const retry = slice(models, 'func retryUncertainCommand()', 'func discardUncertainCommand()');
  assert(retry.includes('send(command, isRetry: true)'));
  assert(models.includes('commandID: UUID().uuidString'));
  assert(/"commandId": commandID/.test(models));
  assert(/case \.changed, \.notEligible:[\s\S]*if isRetry \{[\s\S]*pendingVerification = command/.test(failure));
});

check('a retried command is confirmed only by progressed server state', () => {
  const helper = slice(models, 'func ppDriverStageProgressed', '\n}\n');
  assert(helper.includes('stage != .unknown') && helper.includes('stage != .ended') && helper.includes('stage > expected'));
  const verify = slice(models, 'private func verifyPendingCommand()', 'private func reportVerification');
  assert(verify.includes('ppDriverStageProgressed(task.stage, from: expected)'));
  assert(verify.includes('verifyWithFreshRead(command, expected: expected)'));
  assert(!/\["DELIVER", "CONFIRM_PAYMENT", "COMPLETE"\]\.contains\(command\.actionCode\)/.test(verify),
    'a vanished task must not be assumed delivered');
});

check('unknown server actions are never offered', () => {
  assert(models.includes('static let supportedCodes: Set<String> = ["CLAIM", "PICK_UP", "START_TRANSIT"'));
  assert((models.match(/PPDriverTaskAction\.supportedCodes\.contains\(code\)/g) || []).length === 2);
});

check('official and partner authorities stay single-writer', () => {
  const command = slice(models, 'static func task(_ action: PPDriverTaskAction', 'static func availability(');
  assert(command.includes('functionName: partner ? (action.code == "CLAIM" ? "assignCompanyDeliveryDriver" : "updateCompanyDeliveryStatus") : "executeDriverDeliveryTask"'));
  assert(command.includes('let partner = task.authority == .partnerCompanyRequest'));
});

check('scene routing opens the cockpit for well-formed driver tasks only', () => {
  const parser = slice(scene, 'static NSDictionary<NSString *, NSString *> *PPSceneDriverTaskRoute', '\n}\n');
  assert(parser.includes('[route isEqualToString:@"driver_task"]'));
  assert(parser.includes('[authority isEqualToString:@"FULFILLMENT_V1"]'));
  assert(parser.includes('[authority isEqualToString:@"COMPANY_DELIVERY_REQUEST"]'));
  assert(parser.includes('[route isEqualToString:@"fleet_partner"] && [authority isEqualToString:@"PARTNER_COMPANY_REQUEST"]'));
  assert(parser.includes('taskID.length > 256 || [taskID containsString:@"/"]'));
  const consume = method(scene, '- (void)pp_consumePendingNotificationRouteIfPossible\n{', '- (UINavigationController *)pp_notificationsNavigationController');
  assert(consume.indexOf('PPSceneDriverTaskRoute(') < consume.indexOf('pp_notificationsNavigationController'),
    'driver route is handled before the notifications tab is selected');
  assert(consume.indexOf('PPSceneDriverTaskRoute(') < consume.indexOf('[NotificationManager routePayload:'));
  const company = method(scene, '- (void)pp_handleCompanyDeliveryNotification:', '- (void)pp_routePendingCompanyDeliveryNotificationIfPossible');
  assert(company.indexOf('PPSceneDriverTaskRoute(payload)') < company.indexOf('self.pp_pendingCompanyDeliveryPayload = payload.copy'));
  const open = method(scene, '- (void)openDriverCockpitWithTaskID:', '- (void)pp_handleCompanyDeliveryNotification:');
  assert(open.includes('focusWithTaskID:safeTaskID'), 'an open cockpit is refocused, not duplicated');
  assert(open.includes('initWithFocusTaskID:safeTaskID'));
  assert(sceneHeader.includes('- (void)openDriverCockpitWithTaskID:'));
  assert(sceneHeader.includes('- (void)showDeliveryWorkspaceForProfile:'));
});

check('inbox rows for workforce driver tasks hand off to the scene router', () => {
  const kind = slice(targets, 'static BOOL PPProNotificationTargetsIsCompanyDeliveryPayload', '\n}\n');
  assert(kind.includes('[route isEqualToString:@"driver_task"]'));
});

check('sign-in selects a server-resolved workspace instead of the first profile', () => {
  for (const [name, source] of [['scene', method(scene, '- (void)pp_routeAfterDeliveryCompanyPreflightForUID:', '- (void)showDashboardWithDeliveryCompanyProfile:')],
    ['login', method(login, '- (void)pp_preflightDeliveryCompanyMembershipForUID:', '- (void)pp_gatekeepServiceProviderForUID:')]]) {
    assert(source.includes('preferredProfileFromProfiles:'), `${name}: preferred profile`);
    assert(!source.includes('profiles.firstObject'), `${name}: first-profile shortcut`);
    assert(source.includes('if (!profile.isRestrictedWorkspace) {'), `${name}: storage guard`);
    assert(source.includes('showDeliveryWorkspaceForProfile:'), `${name}: workspace landing`);
  }
  assert(companyModels.includes('if (!self.hasServerWorkspaceProjection) return NO;'),
    'pre-v2 responses keep the legacy destinations');
});

check('dashboard and tab routes send driver-only workspaces to the cockpit', () => {
  assert(dashboard.includes('opensDriverCockpit\n               ? PPDriverCockpitHostController.class'));
  assert(dashboard.includes('[self adminRowWithTag:@"driverCockpit"'));
  assert(dashboard.includes('? @"driverCockpit"\n            : @"deliveryCompany";'));
  const action = method(dashboard, '- (void)pp_executeCommandCenterActionTarget:', '- (void)pp_executeCommandCenterQuickActionTarget:');
  assert(/if \(profile\.prefersDriverCockpit\) \{[\s\S]*initWithFocusTaskID:target\.requestID/.test(action));
  assert(tabBar.includes('"driverCockpit": "PPDriverCockpitHostController"'));
});

check('Pro registers workforce drivers as hosted staff, never as providers', () => {
  const registration = method(appDelegate, '- (void)pp_attemptNotificationV2RegistrationForReason:(NSString *)reason {', '- (void)pp_finishNotificationV2RegistrationCycle');
  assert(registration.includes('if (profile.isOfficialDriverWorkspace) hostedStaff = YES;'));
  assert(registration.includes('discoverCompanyMembershipsWithCompletion:'));
  assert(registration.includes('? @[@"staff.delivery"]'));
  assert(registration.includes('NSArray<NSString *> *providerIds = hostedStaff ? @[] : @[uid];'));
  assert(registration.includes('@"provider": @(!hostedStaff)'));
  assert(registration.includes('@"staff": @(hostedStaff)'));
  assert(/pp_notificationV2RegistrationIsCurrentForUID:uid epoch:registrationEpoch\][\s\S]*BOOL hostedStaff/.test(registration),
    'the account check re-validates the registration epoch');
  assert(appDelegate.includes('isEqualToString:@"staff"]'));
});

check('driver pushes refresh a visible cockpit and keep their route', () => {
  assert(appDelegate.includes('@"PPDriverCockpitShouldRefreshNotification"'));
  assert(models.includes('Notification.Name("PPDriverCockpitShouldRefreshNotification")'));
  const banner = method(appDelegate, '- (BOOL)pp_showProInAppNotificationWithPayload:', '- (void)pp_showProInAppNotificationAfterActivationWithPayload:');
  assert(banner.indexOf('postNotificationName:kPPDriverCockpitShouldRefreshNotification') <
    banner.indexOf('notificationPreferencesAllowPayload:'), 'refresh does not depend on banner preferences');
  assert(banner.indexOf('if (isDriverTask) {\n        // Shown with the generic presenter') <
    banner.indexOf('PPAdminIsCompanyDeliveryPayload(safePayload)'), 'driver payloads are not rewritten as company pushes');
});

check('legacy cockpit no longer fabricates metrics or local duty state', () => {
  for (const source of [legacyModels, legacyControl, legacyHome]) {
    assert(!/todayTotalEarningsQAR|onTimeScorePercentage|func toggleDuty/.test(source));
  }
  assert(!/eligible"\]\s*=\s*@YES|eligible\s*=\s*YES|"eligible":\s*@YES/.test(deliveryService), 'partner fallbacks must not grant eligibility');
});

check('review fixes: focus, workspace switching, paging and truthful states', () => {
  const finish = method(scene, '- (void)showDeliveryWorkspaceForProfile:', '- (void)openDriverCockpitWithTaskID:');
  assert(finish.includes('hasPendingRoute'), 'a tapped notification is not covered by the auto-opened cockpit');
  assert(scene.includes('One cockpit per scene'));
  const refreshEnd = slice(models, 'private func finishRefresh(failure:', 'private func reconcile(');
  assert(refreshEnd.indexOf('refreshQueued = false') < refreshEnd.indexOf('applyPendingFocus()'));
  assert(!slice(models, 'private func reconcile(', 'private func explainVanishedTask').includes('applyPendingFocus()'));
  const select = slice(models, 'func select(_ context: PPDriverContext)', 'func showContextChooser()');
  assert(select.includes('guard selectedContext == nil || canSwitchContext else { return }'));
  assert(select.includes('listGeneration += 1'));
  assert(models.includes('self.phase = .loadFailed'));
  assert(models.includes('case 1, 2, 4, 13, 14, 16: failure = .transport'));
  assert(models.includes('fetchOfficialLane("active", maxPages: 4)'));
  assert(models.includes('service.verifyAndStoreCompanyID(context.companyID)'));
  assert(!models.includes('"status": "active"'), 'no synthetic company profile is stored');
  const failure = method(models, 'private func handleCommandFailure', 'private func verifyPendingCommand');
  assert(/case \.invalidCode:[\s\S]*uncertainCommand = nil/.test(failure));
  assert(failure.includes('DriverCockpit_Notice_AvailabilityChanged'));
  const list = method(companyService, '- (void)listRequestsForProfile:', '- (void)getRequestWithID:');
  assert(list.indexOf('if (profile.isRestrictedWorkspace)') < list.indexOf('[self callFunction:'));
  assert(dashboard.includes('pp_commandCapabilityWithIdentifier:@"driverCockpit"'));
});
check('verification stays pending until its asynchronous read settles', () => {
  const guard = slice(models, 'var canSwitchContext: Bool', '\n');
  assert(guard.includes('!isVerifying'));
  const failure = slice(models, 'private func handleCommandFailure', 'private func verifyPendingCommand');
  assert(/pendingVerification = command\s+isVerifying = true/.test(failure));
  const verify = slice(models, 'private func verifyPendingCommand()', 'private func reportVerification');
  assert(!verify.includes('pendingVerification = nil'), 'a fresh read must keep the verification lock');
  const perform = slice(models, 'func perform(', 'func retryUncertainCommand()');
  assert(perform.includes('guard canSwitchContext'));
  assert(perform.includes('guard canChangeAvailability'));
  const availabilityGuard = slice(models, 'var canChangeAvailability: Bool', 'func refreshAvailability');
  assert(availabilityGuard.includes('canSwitchContext'));
  assert(availabilityGuard.includes('!isStale'));
  assert(availabilityGuard.includes('!isResolvingContexts'));
  assert(view.includes('store.isSubmitting || store.isVerifying'));
});
check('partner lists separate live work from history and retain the page cursor', () => {
  assert(models.includes('"pageSize": 30, "lane": "active"'));
  assert(models.includes('"lane": "history", "pageSize": 15'));
  assert(models.includes('nextPageToken: token.isEmpty ? nil : token'));
  assert(models.includes('"nextPageToken": cursor'));
  assert(view.includes('store.loadMoreActive()'));
});
check('partner recovery uses the company dispatcher contact with an honest missing-contact state', () => {
  assert(models.includes('dispatcherPhone: cpString(entry["dispatcherPhone"])'));
  assert(models.includes(': context.dispatcherPhone'));
  assert(view.includes('DriverCockpit_DispatchContactMissing'));
});
check('cockpit copy is localized in Arabic and English with matching formats', () => {
  assert(!/(?<![A-Za-z_])(Text|Label|Button)\("/.test(view), 'no hard-coded user-facing literals');
  const used = new Set([...(models + view + dashboard).matchAll(/"(DriverCockpit_[A-Za-z0-9_]+)"/g)].map(match => match[1]));
  for (const code of ['CLAIM', 'PICK_UP', 'START_TRANSIT', 'DELIVER', 'CONFIRM_PAYMENT', 'COMPLETE']) {
    used.add(`DriverCockpit_Action_${code}`); used.add(`DriverCockpit_Success_${code}`); used.add(`DriverCockpit_Consequence_${code}`);
  }
  for (const status of ['delivery_requested', 'accepted_by_company', 'offered', 'delivery_assigned', 'awaiting_handover',
    'assigned_to_driver', 'handed_over', 'picked_up', 'in_transit', 'delivered', 'payment_pending', 'payment_confirmed',
    'completed', 'cancelled', 'failed', 'returned', 'rejected', 'expired', 'unknown', 'customer_unavailable',
    'address_issue', 'payment_issue', 'return_required', 'returning']) used.add(`DriverCockpit_Status_${status}`);
  for (const reason of ['ACCOUNT_NOT_ACTIVE', 'ASSIGNMENTS_PAUSED', 'OFFLINE', 'PRESENCE_STALE', 'ON_BREAK', 'OFF_SHIFT',
    'CAPACITY_EXCEEDED']) used.add(`DriverCockpit_Reason_${reason}`);
  for (const reason of ['WORKFORCE_DRIVER_GRANT_REQUIRED', 'OFFICIAL_DELIVERY_GRANT_REQUIRED', 'ROLE_NOT_RECOGNIZED']) {
    used.add(`DriverCockpit_Restricted_${reason}`);
  }
  const value = (language, key) => {
    const match = new RegExp(`^"${key}"\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)";`, 'm').exec(strings[language]);
    assert(match, `${language}: ${key}`);
    return match[1];
  };
  const specifiers = text => (text.match(/%(\d+\$)?(ld|@|d)/g) || []).sort().join(',');
  for (const key of used) {
    const en = value('en', key);
    const ar = value('ar', key);
    assert.equal(specifiers(en), specifiers(ar), `format mismatch: ${key}`);
    assert(/[\u0600-\u06FF]/.test(ar), `Arabic copy missing: ${key}`);
  }
  assert(used.size > 100, `expected the full cockpit key set, saw ${used.size}`);
});

check('Home reads assigned work without offers and keeps the same availability and fleet routes', () => {
  const home = slice(legacyHome, 'struct PPDriverHomeAvailabilitySection', '// MARK: - Reusable Tactile');
  assert(home.includes('@ObservedObject var store: PPDriverCockpitStore'));
  assert(models.includes('init(loadsTaskQueue: Bool = true, loadsOffers: Bool = true)'));
  assert.equal((models.match(/guard self\.loadsOffers && self\.canSelfAcceptOrders else/g) || []).length, 2,
    'Home skips the available-offer read for both official and partner companies');
  assert(models.includes('["availabilityOnly": true]'));
  assert(home.includes('PPDriverAvailabilityControl(store: store)'));
  assert(home.includes('store.setVisible(false)'));
  assert(home.includes('store.retryUncertainCommand()'));
  assert(home.includes('store.select(choice)'));
  assert(!home.includes('PPDeliveryDriverObservableState'));
  assert(view.includes('PPDriverAvailabilityControl(store: store)'));
  const surface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
  const pulse = slice(surface, 'struct PPProPulseView', 'private struct PPProMoreDestinationView');
  assert(pulse.includes('@State private var driverHomeStore: PPDriverCockpitStore?'));
  assert(pulse.includes('driverHomeStore = PPDriverCockpitStore(loadsOffers: false)'));
  assert.equal((pulse.match(/PPDriverHomeAvailabilitySection/g) || []).length, 1, 'one delivery integration shared by compact and regular layouts');
  assert.equal((pulse.match(/activate\(driverRoute\)/g) || []).length, 1);
  assert(pulse.includes('driverHomeStore.boundUID == PPDeliveryCompanyService.currentAccountUID()'));
  assert(pulse.includes('$0.routeTag == "driverCockpit"'));
  assert(pulse.includes('.id(PPDeliveryCompanyService.currentAccountUID())'));
  assert(!/\.collection\(|Firestore\.firestore/.test(home));
});
check('Home prioritizes owned active work and never returns idle availability on an uncertain read', () => {
  const home = slice(legacyHome, 'struct PPDriverHomeAvailabilitySection', 'private struct PPDriverHomeMissionSummary');
  assert(home.includes('store.activeTasks.filter { $0.mine && !$0.isTerminal }'));
  assert(home.indexOf('if let task = activeTask') < home.indexOf('} else if isExpanded {'));
  assert(home.includes('PPDriverHomeMissionSummary(task: task)'));
  const hold = slice(home, 'private var holdsAvailabilityForTaskRead:', 'private var missionHeader:');
  for (const token of ['store.uncertainCommand != nil', 'store.isSubmitting', 'store.isVerifying',
    'store.lastConfirmedAt == nil', 'store.isStale', 'activeCount > 0']) assert(hold.includes(token), token);
  assert(home.includes('assignedTasks.first(where: { $0.id == store.focusedTaskKey })'));
  assert(home.includes('store.focus(on: task)'));
  assert(home.includes('store.setVisible(isOnScreen && isActive && phase == .active)'));
  assert(home.includes('confirmation = nil'));
  const sent = slice(models, 'private func send(_ command:', 'private func handleCommandFailure');
  assert(sent.includes('if self.selectedContext?.kind == .partnerDriver'),
    'task completion refreshes partner membership workload as well as assigned tasks');
  assert(!sent.includes('command.kind == .availability && self.selectedContext?.kind == .partnerDriver'));
});
check('Delivery is a presentation-only grouped workspace with permitted doors and distinct work counts', () => {
  const surface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
  const lenses = slice(surface, 'struct PPProWorkspaceLens:', '@MainActor\nfinal class PPProCommandCenterStore');
  for (const token of ['deliveryWorkspace', '"deliveryCompany"', '"driverCockpit"', 'snapshot.capabilities.filter(isDelivery)',
    'counted.insert(signal.id).inserted', '!ids.isDisjoint(with: signal.capabilityIDs)', 'Language.get("DeliverySection"']) {
    assert(lenses.includes(token), token);
  }
  assert(!/onRoute|activate\(|FIRFirestore|\.collection\(/.test(lenses), 'the group cannot navigate or grant authority');
  const store = slice(surface, 'final class PPProCommandCenterStore:', '@objc public protocol PPProCommandCenterSurfaceControllerDelegate');
  assert(store.includes('!workspaceLenses.contains(where: { $0.id == selectedCapabilityID })'));
  assert(store.includes('$0.capabilityIDs.isEmpty || !ids.isDisjoint(with: $0.capabilityIDs)'));
  const scope = slice(surface, 'struct PPProPulseScope', '// MARK: - Capability Theme');
  assert(scope.includes('for capability in snapshot.capabilities where visibleIDs.contains(capability.id)'));
  const pulse = slice(surface, 'struct PPProPulseView:', 'private struct PPProMoreDestinationView');
  assert(pulse.includes('store.workspaceLenses.count > 1 || hasDeliveryCapability'), 'driver-only accounts retain the Delivery tab');
  assert(pulse.includes('id == "all" || store.workspaceLenses.contains(where: { $0.id == id })'));
});
check('workspace switching preserves command ownership and hides delivery from interaction, accessibility and polling', () => {
  const surface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
  const pulse = slice(surface, 'struct PPProPulseView:', 'private struct PPProMoreDestinationView');
  for (const token of ['ForEach(sectionOrder, id: \\.self)', '.frame(height: showsDeliverySection ? nil : 0)',
    '.allowsHitTesting(showsDeliverySection)', '.accessibilityHidden(!showsDeliverySection)', 'sectionGap(after:',
    'isActive: showsDeliverySection']) assert(pulse.includes(token), token);
  assert(!/\.id\(store\.selected/.test(pulse), 'a selected tab is never the driver store identity');
  const driver = slice(legacyHome, 'struct PPDriverHomeAvailabilitySection:', '// MARK: Active delivery');
  assert(driver.includes('if isActive { store.start(focus: nil) }'));
  assert(driver.includes('else { confirmation = nil }'));
  assert(!driver.includes('uncertainCommand = nil'), 'tab hiding must retain the issued command');
  const entry = slice(legacyHome, 'struct PPDeliveryHomeEntrySection:', '/// Company drivers');
  assert(entry.includes('guard isActive else { return }'));
  assert(/case \.provider:\s*if isActive/.test(entry));
});
check('workspace motion has one selected indicator and stable identities with static reduced-motion recovery', () => {
  const surface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
  const rail = slice(surface, 'private struct PPProLensRail:', '// MARK: - Attention stage');
  assert.equal((rail.match(/matchedGeometryEffect\(id: "workspaceSelection"/g) || []).length, 1);
  assert(rail.includes('ForEach(workspaces)'));
  assert(rail.includes('.accessibilityAddTraits(selected ? .isSelected : [])'));
  assert(/if reduceMotion\s*\{\s*transaction\.animation = nil\s+transaction\.disablesAnimations = true\s*\}/.test(rail),
    'Reduce Motion clears inherited animation and prevents child modifiers from reintroducing it');
  const pulse = slice(surface, 'struct PPProPulseView:', 'private struct PPProMoreDestinationView');
  assert(pulse.includes('!reduceMotion && isOnScreen && scenePhase == .active'));
  assert(pulse.includes('withAnimation(workspaceAnimation)'));
  assert(pulse.includes('transaction.disablesAnimations = true'));
  const selection = slice(pulse, 'private func selectLens(', 'private func focusSignal(');
  assert(!selection.includes('appeared ='), 'tab changes must not replay staged entrances');
});
check('Home and cockpit share exact confirmation and proof/cash blocking', () => {
  const home = slice(legacyHome, 'struct PPDriverHomeAvailabilitySection', 'private struct PPDriverHomeMissionSummary');
  for (const source of [home, view]) {
    assert(source.includes('PPDriverConfirmSheet(task: request.task, action: request.action)'));
    assert(source.includes('contextID: request.contextID'));
    assert(source.includes('ppDriverActionBlockKey(action, task: task, canSelfAcceptOrders: store.canSelfAcceptOrders)'));
  }
  assert(home.includes('store.canPerformCurrentAction(action, on: task)'));
  assert(home.includes('["DELIVER", "CONFIRM_PAYMENT", "COMPLETE"].contains(action.code)'));
  const block = slice(models, 'func ppDriverActionBlockKey', 'func ppDriverActionSnapshotMatches');
  for (const token of ['task.proof.photoRequired', 'task.proof.signatureRequired', 'DriverCockpit_Blocked_Cash',
    'DriverCockpit_Blocked_Proof', 'task.cash?.amount', 'task.authority != .fulfillmentV1']) assert(block.includes(token));
});
check('Home recovery remains actionable without a notice and dashboard navigation is independent of an uncertain mutation', () => {
  const home = slice(legacyHome, 'struct PPDriverHomeAvailabilitySection', 'private struct PPDriverHomeMissionSummary');
  const step = slice(home, 'private func nextStep(for task:', 'private var refreshTaskButton:');
  assert(/else if store\.uncertainCommand != nil \{\s*uncertainCommandRecovery/.test(step));
  const recovery = slice(home, 'private var uncertainCommandRecovery:', 'private var refreshTaskButton:');
  assert(recovery.includes('store.retryUncertainCommand()'));
  assert(recovery.includes('store.checkUncertainCommandStatus()'));
  assert(recovery.includes('.buttonStyle(PPDriverPrimaryButtonStyle'));
  const dashboard = slice(home, 'private var dashboardRow:', '// MARK: Derived state');
  assert(!dashboard.includes('canSwitchContext'), 'an unknown mutation must not disable read-only dashboard navigation');
  assert(dashboard.includes('store.isSubmitting || store.isVerifying'));
});
check('fresh reads reconcile an uncertain command while retaining its identity until progress is verified', () => {
  const refresh = slice(models, 'func refresh() {', 'func loadHistory()');
  assert(refresh.indexOf('if isRefreshing {') < refresh.indexOf('pendingVerification = command'),
    'a read already in flight before the uncertain result cannot verify that result');
  assert(refresh.includes('let command = uncertainCommand'));
  const failure = slice(models, 'private func handleCommandFailure', 'private func verifyPendingCommand');
  assert(/case \.transport, \.unknown:[\s\S]*uncertainCommand = command[\s\S]*refreshAll\(\)/.test(failure));
  const checkLatest = slice(models, 'func checkUncertainCommandStatus()', 'func dismissNotice()');
  assert(checkLatest.includes('refreshAll()'));
  assert(!checkLatest.includes('uncertainCommand = nil'), 'a status check must not discard the retry identity');
  const report = slice(models, 'private func reportVerification(', '// MARK: Helpers');
  assert(report.includes('if confirmed || endedStatus != nil'));
  assert(report.includes('else if uncertainCommand != nil'));
  assert(report.includes('DriverCockpit_Notice_Unconfirmed'));
  assert(view.includes('store.checkUncertainCommandStatus()'));
});
check('a captured Home action must still match the latest task before the only command writer', () => {
  const snapshot = slice(models, 'func ppDriverActionSnapshotMatches', 'struct PPDriverFocusRequest');
  for (const token of ['snapshot.id == current.id', 'snapshot.companyID == current.companyID',
    'snapshot.status == current.status', 'snapshot.revision == current.revision', 'snapshot.mine == current.mine',
    'snapshot.proof == current.proof', 'snapshot.cash == current.cash', 'current.actions.contains(action)',
    '!current.isTerminal']) assert(snapshot.includes(token), token);
  const allowed = slice(models, 'func canPerformCurrentAction', 'func perform(');
  for (const token of ['isSameAccount()', '!isStale', '!isRefreshing', '!isResolvingContexts',
    'contextID == selectedContext?.id', 'ppDriverActionSnapshotMatches']) assert(allowed.includes(token), token);
  const perform = slice(models, 'func perform(', 'func setOnline(');
  assert(perform.indexOf('canPerformCurrentAction') < perform.indexOf('send(PPDriverCommand.task'));
});
check('Home progress is model-backed, accessible, direction-aware, and localized', () => {
  const summary = slice(legacyHome, 'private struct PPDriverHomeMissionSummary', '// MARK: - Reusable Tactile');
  for (const token of ['task.stage != .unknown', 'task.stage.railIndex', 'dynamicTypeSize.isAccessibilitySize',
    'AnyLayout(VStackLayout', 'ppDriverIsolated', 'accessibilityElement(children: .ignore)',
    'reduceMotion ? nil', 'value: task.status']) assert(summary.includes(token), token);
  for (const language of ['ar', 'en']) {
    for (const key of ['DriverHome_ActiveDelivery', 'DriverHome_ChooseDelivery', 'DriverHome_CheckAssigned',
      'DriverHome_ProgressHint']) assert.equal((strings[language].match(new RegExp(`^"${key}"\\s*=`, 'gm')) || []).length, 1,
        `${language}: ${key}`);
  }
});
check('availability has fresh-revision guards, contextual confirmation and honest status', () => {
  const control = slice(view, 'struct PPDriverAvailabilityControl', 'struct PPDriverCockpitView');
  assert(control.includes('store.canChangeAvailability'));
  assert(control.includes('store.isSubmitting || store.isVerifying'));
  assert(control.includes('store.availability?.activeDeliveryCount'));
  assert(control.includes('store.setOnline(false)'));
  assert(control.includes('DriverAvailability_RestrictedHint'));
  assert(control.includes('minHeight: AdminTouchTarget.comfortable'));
  assert(control.includes('.accessibilityIdentifier("driver.availability.toggle")'));
  assert(!control.includes('Toggle('), 'no optimistic local switch state');
  const polling = slice(models, 'private func startTimer()', 'private func stopTimer()');
  assert(polling.includes('refreshAll()'), 'partner polling must renew membership presence too');
});
check('fleet registration retries retain command identity and localize protected-grant failures', () => {
  const invite = method(companyService, '- (void)inviteMemberIdentifier:', '- (void)disableMemberUID:');
  assert(invite.includes('self.memberInvitationCommandIDs[identityKey]'));
  assert(invite.includes('@"commandId": commandID'));
  assert(invite.includes('isEqualToString:issuerUID'));
  assert(invite.includes('if (!error) [self.memberInvitationCommandIDs removeObjectForKey:identityKey]'));
  for (const code of ['DELIVERY_DRIVER_PROVISIONING_AUTHORITY_REQUIRED','DELIVERY_WORKFORCE_GRANT_REQUIRED','DELIVERY_DRIVER_TARGET_ACCOUNT_INACTIVE','DELIVERY_DRIVER_TARGET_REGISTRATION_REQUIRED']) {
    assert(companyService.includes(code));
  }
  assert(dashboard.includes('hasResolvedDeliveryMembership'));
  assert(dashboard.includes('(hasReviewApplication && !hasResolvedDeliveryMembership)'));
  for (const key of new Set([...view.matchAll(/"(DriverAvailability_[A-Za-z_]+)"/g),
    ...legacyHome.matchAll(/"(DriverAvailability_[A-Za-z_]+)"/g),
    ...companyService.matchAll(/@"(DriverRegistration_[A-Za-z_]+)"/g)].map(match => match[1]))) {
    for (const language of ['ar','en']) {
      assert.equal((strings[language].match(new RegExp(`^"${key}" = `,'gm')) || []).length, 1, `${language}: ${key}`);
    }
  }
});

check('member-only drivers register for delivery pushes without provider feature or staff elevation', () => {
  const registration = slice(appDelegate, '// Membership is an independent Pro grant.', '#pragma mark -');
  assert(registration.includes('discoverCompanyMembershipsWithCompletion:'));
  assert(registration.includes('profile.isOfficialDriverWorkspace'));
  assert(registration.includes('[profile.workspaceKinds containsObject:@"PARTNER_DRIVER"]'));
  assert(registration.includes('companyIDs.count < 10'));
  assert(registration.includes('deliveryCompanyIDs.count > 0 ? @[@"provider.orders"]'));
  assert(registration.includes('@"deliveryCompanyIds": deliveryCompanyIDs ?: @[]'));
  assert(registration.includes('pp_notificationV2RegistrationIsCurrentForUID:uid epoch:registrationEpoch'));
});

check('membership-check failure is recoverable and never treated as confirmed onboarding', () => {
  const preflight = method(login, '- (void)pp_preflightDeliveryCompanyMembershipForUID:', '- (void)pp_gatekeepServiceProviderForUID:');
  const failure = slice(preflight, 'if (error) {', '[self pp_continueToProviderOnboarding];');
  assert(failure.includes('ProAccess_CheckFailedBody'));
  assert(!failure.includes('ProAccess_NotEnabledTitle'));
  assert(failure.includes('secondaryBlock:'));
  assert(failure.includes('[retrySelf pp_gatekeepServiceProviderForUID:uid]'));
  assert(failure.includes('return;'));
  const scenePreflight = method(scene, '- (void)pp_routeAfterDeliveryCompanyPreflightForUID:', '- (void)showDashboardWithDeliveryCompanyProfile:');
  const sceneFailure = slice(scenePreflight, 'if (error) {', 'self.pp_autoPresentProviderStatusOnNextRoot = autoPresentOnboarding;');
  assert(sceneFailure.includes('ProAccess_CheckFailedBody'));
  assert(sceneFailure.includes('if (hasProviderAccess)'));
  assert(sceneFailure.includes('setRoot:AppRootLogin'));
  assert(sceneFailure.includes('pp_applyAdminRoutingForAuthUser:'));
  assert(sceneFailure.includes('return;'));
  assert(!preflight.includes('continuing onboarding:') && !scenePreflight.includes('continuing onboarding:'));
});

check('restricted drivers keep an explanatory availability surface without a client grant', () => {
  const companyView = read('PurePetsPro/DeliveryCompanySection/PPDeliveryListView.swift');
  assert(dashboard.includes('hasResolvedDeliveryMembership'));
  assert(dashboard.includes('[deliveryCompanyProfile.role isEqualToString:PPDeliveryCompanyRoleDriver]'));
  assert(dashboard.includes('[self.deliveryCompanyContext.role isEqualToString:PPDeliveryCompanyRoleDriver]'));
  assert(legacyHome.includes('if case .noWorkspace(let reason) = store.phase'));
  assert(view.includes('DriverAvailability_AccessRequired'));
  assert(view.includes('.disabled(!store.canChangeAvailability)'));
  assert(companyView.includes('Delivery_Driver_Active_Offline_Hint'));
  for (const key of ['Driver_Dispatcher_Assignments_Enabled', 'Driver_Dispatcher_Account_Active',
    'Driver_Dispatcher_Account_Restricted', 'Delivery_Driver_Active_Offline_Hint',
    'Delivery_Value_WORKFORCE_DRIVER_GRANT_REQUIRED', 'DriverAvailability_AccessRequired',
    'DeliveryLogin_CheckFailed_Title', 'DeliveryLogin_CheckFailed_Body', 'DeliveryLogin_UseAnotherAccount']) {
    for (const language of ['ar', 'en']) {
      assert.equal((strings[language].match(new RegExp(`^"${key}"\\s*=`, 'gm')) || []).length, 1, `${language}: ${key}`);
    }
  }
});

check('older delivery shortcuts resolve the account-bound driver workspace before showing provider tasks', () => {
  const entry = read('PurePetsPro/DeliverySection/PPDeliveryDriverDashboardHostController.swift');
  assert(entry.includes('resolveDriverCockpitRequirement'));
  assert(entry.includes('PPDriverCockpitView(store: store'));
  assert(entry.includes('PPDeliveryDriverControlView(onDismiss:'));
  assert(entry.includes('requestedUID == PPDeliveryCompanyService.currentAccountUID()'));
  assert(entry.includes('if let error'));
  assert(tabBar.includes('"delivery": "PPDeliveryDriverDashboardHostController"'));
  assert(!dashboard.includes('PPDeliveryDashboardViewController *vc = [[PPDeliveryDashboardViewController alloc] init]'));
  const gate = method(companyService, '- (void)resolveDriverCockpitRequirementWithCompletion:', '- (void)callDriverCockpitFunction:');
  assert(gate.includes('checkIfUserWithUID:uid canAccessPro:'));
  assert(gate.includes('[accountType isEqualToString:@"staff"]'));
  assert(gate.includes('discoverCompanyMembershipsWithCompletion:'));
  assert(gate.includes('profile.hasDriverWorkspace || profile.isRestrictedWorkspace'));
  assert(gate.includes('[activeUID isEqualToString:uid]'));
  assert(legacyHome.includes('struct PPDeliveryHomeEntrySection'));
});

check('stale provider records cannot submit official staff actions through the provider adapter', () => {
  const manager = read('PurePetsPro/DeliverySection/PPDeliveryManager.m');
  const action = method(manager, '- (void)performDeliveryAction:', '- (void)pp_performProviderDeliveryAction:');
  assert(action.includes('resolveDriverCockpitRequirementWithCompletion:'));
  assert(action.includes('error || requiresDriverCockpit'));
  assert(action.includes('DriverCockpit_UseDriverWorkspace'));
  assert(!action.includes('HTTPSCallableWithName:'));
  const listening = method(manager, '- (void)startListeningForDeliveryOrders', '- (void)pp_startProviderOrderListenersForUID:');
  assert(listening.includes('resolveDriverCockpitRequirementWithCompletion:'));
  assert(listening.includes('generation != self.staffListenerGeneration'));
  assert(listening.includes('if (requiresDriverCockpit)'));
  assert(!listening.includes('startOrderListenersForStaff:'));
  for (const language of ['ar', 'en']) {
    assert.equal((strings[language].match(/^"DriverCockpit_UseDriverWorkspace"\s*=/gm) || []).length, 1);
  }
});

check('fulfillment accept-and-assign uses one canonical command, never company-request mutations', () => {
  const submit = method(deliveryService, '- (void)executeAllowedAction:', '- (void)executeCanonicalAllowedAction:');
  const atomic = slice(submit, 'if ([act isEqualToString:@"ACCEPT_AND_ASSIGN"]) {', '// Delegate directly to partner-authorized actions');
  assert(atomic.includes('executeCanonicalAllowedAction:allowedAction'));
  assert(atomic.includes('targetDriver.length == 0'));
  assert(atomic.includes('allowedAction.expectedRevision < 0'));
  assert(atomic.includes('allowedAction.expectedState isEqualToString:@"delivery_requested"'));
  assert(!/acceptRequestID:|assignRequestID:/.test(atomic));
  assert(submit.includes('if ([act isEqualToString:@"ACCEPT"]) {'), 'legacy partner acceptance remains separate');
  assert(!submit.includes('allowedAction.expectedRevision + 2'), 'an atomic fulfillment command never manufactures a two-write result');
});

check('canonical acceptance preserves the envelope and returns only the backend result', () => {
  const body = method(deliveryService, '- (void)executeCanonicalAllowedAction:', '- (void)executeDriverAction:');
  for (const field of ['@"requestId": requestID', '@"commandId": commandID', '@"action": allowedAction.action',
    '@"expectedRevision": @(allowedAction.expectedRevision)', '@"expectedState": allowedAction.expectedState',
    'payload[@"driverUid"] = driverUID']) assert(body.includes(field), field);
  assert.equal((body.match(/callFunction:@"executeDeliveryCommand"/g) || []).length, 1);
  assert(body.includes('initWithDictionary:result'));
  assert(!/acceptRequestID:|assignRequestID:|@"APPLIED"/.test(body));
});

check('explicit empty server actions and fulfillment authority cannot acquire guessed partner actions', () => {
  const body = slice(deliveryService, '@implementation PPDeliveryRequestRecord', '@implementation PPDeliveryDriverRecord');
  assert(body.includes('if ([rawActionsValue isKindOfClass:NSArray.class])'));
  assert(body.includes('else if ([_authority isEqualToString:@"COMPANY_DELIVERY_REQUEST"])'));
  assert(!body.includes('if (rawActions.count > 0)'));
});

check('dossier commands require a fresh matching server action and recover before re-enabling', () => {
  const companyView = read('PurePetsPro/DeliveryCompanySection/PPDeliveryListView.swift');
  const gate = slice(companyView, 'var canExecuteDossierCommands:', 'var records:');
  for (const token of ['dossier?.record.requestID == selectedRequestID', '!isExecuting', '!isLoadingDossier',
    'dossierIncident == nil', 'commandIncident == nil']) assert(gate.includes(token), token);
  const execute = slice(companyView, 'func execute(_ action:', 'func executeDriver(');
  assert(execute.includes('selectedRequestID, canExecuteDossierCommands'));
  assert(execute.includes('$0.expectedRevision == action.expectedRevision'));
  assert(execute.includes('$0.expectedState == action.expectedState'));
  for (const code of ['DELIVERY_REQUEST_NOT_FOUND', 'DELIVERY_AUTHORITY_MISMATCH']) assert(execute.includes(code));
  const load = slice(companyView, 'func loadDossier(', 'func execute(_ action:');
  assert(load.includes('guard let dossier, dossier.record.requestID == requestID'));
  assert(load.indexOf('self.commandIncident = nil') > load.indexOf('self.dossier = dossier'));
  const footer = slice(companyView, 'private var actionFooter:', 'private func close()');
  const dock = slice(companyView, 'private func commandDock(', 'private func deliveryActionButton(');
  assert(footer.includes('.disabled(!viewModel.canExecuteDossierCommands'));
  assert(dock.includes('.disabled(!viewModel.canExecuteDossierCommands)'));
});

check('store handover waiting state is restricted to an assigned official task with no server action', () => {
  const task = slice(models, 'var awaitsStoreHandover:', 'static func key(authority:');
  for (const token of ['mine', 'authority == .fulfillmentV1', 'status == "delivery_assigned"', 'actions.isEmpty']) {
    assert(task.includes(token), token);
  }
  const state = slice(view, 'private var dockState:', 'private var dock:');
  assert(state.includes('if task.awaitsStoreHandover { return .awaitingStoreHandover }'));
  assert(state.includes('guard let action = task.primaryAction'));
});

check('the waiting dock offers a read-only readiness check and preserves server pickup authority', () => {
  const pending = slice(view, 'case .awaitingStoreHandover:', 'case .blocked(_, let reason)');
  assert(pending.includes('Button { store.refresh() }'));
  assert(pending.includes('.disabled(store.isRefreshing)'));
  assert(pending.includes('ProgressView()'));
  for (const key of ['DriverCockpit_Handover_Check', 'DriverCockpit_Handover_Checking', 'DriverCockpit_Handover_Check_Hint']) assert(pending.includes(key));
  assert(!/store\.perform|PPDriverTaskAction\(/.test(pending));
  assert(!pending.includes('DriverCockpit_Handover_Instructions'), 'long guidance belongs in scrollable mission content, outside the pinned dock');
  const card = slice(view, 'private struct PPDriverMissionCard:', 'private func cashBadge(');
  assert(card.includes('if task.awaitsStoreHandover'));
  assert(card.includes('DriverCockpit_Handover_Next'));
  assert(card.includes('DriverCockpit_Handover_Instructions'));
  assert(card.includes('.fixedSize(horizontal: false, vertical: true)'));
});

check('pickup readiness is announced only after a fresh server-projected action arrives', () => {
  const body = slice(models, 'private func reconcile(active:', 'private func explainVanishedTask(');
  assert(body.includes('previousTasks.first(where: { $0.id == focused.id })?.awaitsStoreHandover == true'));
  assert(body.includes('focused.actions.contains(where: { $0.code == "PICK_UP" })'));
  assert(body.includes('DriverCockpit_Handover_Ready'));
  assert(body.includes('UIAccessibility.post(notification: .announcement'));
});

check('handover guidance and readiness controls have one Arabic and English translation each', () => {
  for (const language of ['ar', 'en']) {
    for (const key of ['DriverCockpit_Handover_Next', 'DriverCockpit_Handover_Instructions',
      'DriverCockpit_Handover_Check', 'DriverCockpit_Handover_Checking',
      'DriverCockpit_Handover_Check_Hint', 'DriverCockpit_Handover_Ready']) {
      assert.equal((strings[language].match(new RegExp(`^"${key}"\\s*=`, 'gm')) || []).length, 1, `${language}: ${key}`);
    }
  }
});

console.log(`PASS ${passed} driver cockpit source contracts. Native runtime is UNVERIFIED.`);
