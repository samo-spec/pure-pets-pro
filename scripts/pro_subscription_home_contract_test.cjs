// Source contracts only. Compilation and native behavior need an authorized iPhone run.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const home = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
const dashboard = read('PurePetsPro/AdminDashboardViewController.m');
const login = read('PurePetsPro/AdminCore/Auth/AdminLoginViewController.m');
const scene = read('PurePetsPro/SceneDelegate.m');
const status = read('PurePetsPro/ProviderOnboarding/PPProviderApplicationStatusViewController.m');
const studio = read('PurePetsPro/ProviderOnboarding/PPProviderSubscriptionStudioView.swift');
const alert = read('PurePetsPro/ThirdParty/PPStyles/PPAlertHelper.m');
const section = (source, start, end) => {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `Missing source boundary ${start}`);
  return source.slice(a, b);
};
let passed = 0;
const check = (name, body) => { body(); passed++; console.log(`PASS ${name}`); };

check('Pro access remains feature/subscription based and separate from staff claims', () => {
  const gate = section(read('PurePetsPro/AppManager.m'), 'static BOOL PPUserDocAllowsProAccess', 'typedef void (^PPUsersColRootCompletion)');
  for (const feature of ['serviceProvider', 'production', 'veterinarians', 'pharmacy', 'delivery']) {
    assert(gate.includes(`@"${feature}"`));
  }
  assert(gate.includes('PPProAccountIsBlocked(root)'));
  assert(gate.includes('PPProSubscriptionIsActive'));
  assert(!/isAdmin|isOwner|customClaims/.test(gate));
});

check('failed access verification and confirmed no access have distinct recovery messages', () => {
  for (const [source, start, end] of [
    [login, '- (void)pp_preflightDeliveryCompanyMembershipForUID:', '- (void)pp_gatekeepServiceProviderForUID:'],
    [scene, '- (void)pp_routeAfterDeliveryCompanyPreflightForUID:', '- (void)showDashboardWithDeliveryCompanyProfile:']
  ]) {
    const body = section(source, start, end);
    assert(body.includes('ProAccess_CheckFailedTitle'));
    assert(body.includes('ProAccess_NotEnabledTitle'));
    assert(body.includes('ProAccess_BecomePartner'));
    assert(body.includes('ProAccess_UseAnotherAccount'));
    assert(!body.includes('DeliveryLogin_CheckFailed'));
    assert(body.includes('currentUser.uid isEqualToString:uid'));
  }
  assert(scene.includes('if (hasProviderAccess)'));
  assert(scene.includes('hasProviderAccess:YES'));
  assert(scene.includes('routingGeneration != self.pp_proAccessRoutingGeneration'));
  assert(scene.includes('if (generation != self.pp_rootTransitionGeneration) return;'));
  assert(scene.includes('generation:generation completion:completion'));
  assert(!scene.includes('weakSelf.currentRoot = AppRootSplash;\n                    [weakSelf setRoot:capturedTarget'));
  assert(login.includes('[retrySelf pp_gatekeepServiceProviderForUID:uid]'));
  assert(login.includes('onboarding.count > 0 ? onboarding : userDoc'));
  assert(login.includes('stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet'));
});

check('account switch requires an explicit action in the informational PPAlert', () => {
  const body = section(alert, 'primaryButton:(NSString *)primaryTitle', '+ (void)showInfoIn:(UIViewController *)vc\n             title:(NSString *)title\n          subtitle:(NSString * _Nullable)subtitle\n        completion:');
  assert(body.includes('PPAlertTypeInfo'));
  assert(body.includes('PPAlertActionStyleSecondary'));
  assert(body.includes('shouldDismissOnBackgroundTap:NO'));
});

check('Home card is account-level presentation in both width layouts', () => {
  const card = section(home, 'private struct PPProSubscriptionHomeCard:', 'struct PPProPulseView:');
  assert(!/FIRFirestore|observeProvider|fetchPlans|canApply/.test(card));
  assert(card.includes('summary.additionalActionRoute'));
  assert(card.includes('summary.pendingActionRoute'));
  assert(card.includes('pro.home.subscription.pendingRequest'));
  assert(card.includes('sizeCategory.isAccessibilityCategory'));
  assert(card.includes('.fixedSize(horizontal: false, vertical: true)'));
  assert(card.includes('layoutDirection == .rightToLeft'));
  assert(card.includes('PPProHomeControlStyle()'));
  const phone = section(home, 'private var phoneContent: some View {', '// MARK: iPad (Regular Width)');
  const pad = section(home, 'private var padContent: some View {', 'private func homeSection');
  assert(phone.includes('subscriptionCard'));
  assert(pad.includes('subscriptionCard'));
  assert(home.includes('snapshot.subscriptionCard == nil'));
  assert(dashboard.includes('snapshot.subscriptionCard = [self pp_subscriptionCardForUser:user]'));
});

check('pending provider application row is an interactive route to application status', () => {
  assert(dashboard.includes('card.pendingActionRoute = @"__providerApplicationStatus"'));
  const route = section(dashboard, '- (void)pp_routeCommandCenterRoute:(NSString *)route', '- (void)commandCenterSurface:');
  assert(route.includes('__providerApplicationStatus'));
  assert(route.includes('controller.prefersAutoPresentBecomeProvider = NO'));
  assert(route.includes('controller.suppressAutoDashboardTransition = YES'));
});

check('driver membership does not fabricate a plan or block the management entry on read failure', () => {
  const card = section(dashboard, '- (PPProSubscriptionCardDescriptor *)pp_subscriptionCardForUser:', '- (void)pp_refreshCommandCenterSnapshot {');
  assert(card.includes('ProSubscription_DriverBody'));
  assert(card.includes('ProSubscription_DriverRequirement'));
  assert(card.includes('ProSubscription_DriverLoadFailed'));
  assert(!/priceAmount|\[\[PPProviderProfile alloc\] init\]/.test(card));
  assert(card.includes('self.ownedSubscriptions'));
  assert(card.includes('[owned.userID isEqualToString:user.uid]'));
  assert(!card.includes('PPProviderProfile *activeProfile'));
  const route = section(dashboard, '- (void)pp_openSubscriptionManagement {', '- (');
  assert(route.includes('PPProviderSubscriptionManagmetVC'));
  assert(!route.includes('if (!hasProviderProfile)'));
  assert(route.includes('suppressAutoDashboardTransition = YES'));
});

check('onboarding intent waits for current authoritative eligibility and cancels stale work', () => {
  const body = section(status, '- (void)pp_presentBecomeProviderWithType:', '- (void)pp_transitionToDashboard');
  assert(status.includes('self.prefersAutoPresentBecomeProvider = NO'));
  assert(status.includes('[sceneDelegate cancelPendingProAccessRouting]'));
  assert(dashboard.includes('[sceneDelegate cancelPendingProAccessRouting]'));
  for (const text of ['generation != self.applicationIntentGeneration', 'currentUser.uid isEqualToString:uid',
    '!state.initialDataAuthoritative', 'state.isBlocked || state.eligibleProviderTypes.count == 0',
    'initWithState:state', 'eligibleProviderTypes:eligibleTypes', 'preferredProviderType:preferredType']) assert(body.includes(text));
  assert(!body.includes('initWithState:nil'));
  assert(!body.includes('eligibleProviderTypes:@[]'));
  assert(status.includes('[self.applicationIntentListener remove]'));
  assert(status.includes('15 * NSEC_PER_SEC'));
});

check('owned inventory, selected detail and request results stay with their account and profile', () => {
  assert(dashboard.includes('generation != strongSelf.providerSubscriptionObservationGeneration'));
  assert(studio.includes('cancelObservation = { registration.remove() }'));
  assert(studio.includes('.onDisappear { stopObserving() }'));
  assert(studio.includes('generation == requestGeneration'));
  assert(studio.includes('record.profile.profileID == profileID'));
  assert(studio.includes('generation == submissionGeneration'));
  const resolution = section(studio, 'private func reloadData(', 'private func prepareRequest');
  assert(!resolution.includes('eligibleProviderTypes'));
  assert(resolution.includes('fetchOwnedSubscriptions'));
  assert(resolution.includes('fetchSubscriptionOptions(forProfileID: profileID)'));
  assert(!studio.includes('primaryActiveProviderType'));
  assert(!/Standard Partner Tier|Regular Weekly Payouts|certified processing|Commission Based/.test(studio));
  const upgrade = section(read('PurePetsPro/ProviderOnboarding/PPProviderSubscriptionManagmetVC.m'), '- (void)pp_presentBecomeProviderForUpgradeWithType:', '#pragma mark - PPBecome');
  assert(upgrade.includes('showInfoIn:self'));
  assert(!/submitDraft|initWithState:nil/.test(upgrade));
});

check('provider requests freeze the reviewed identity and retry only that intent', () => {
  const submit = section(studio, 'private func submit(', 'private func showPendingMessage');
  assert(submit.includes('if reviewedPayload == nil'));
  for (const field of ['profileId', 'expectedPlanHash', 'expectedVersion', 'idempotencyKey']) assert(submit.includes('"' + field + '"'));
  assert(submit.includes('submitSubscriptionRequest(payload)'));
  assert(!submit.includes('submitDraft'));
  const rebinding = section(studio, 'private func startObserving()', 'private func reloadData(');
  assert(rebinding.includes('isSubmitting = false'));
  assert(rebinding.includes('reviewedPayload = nil'));
  assert(rebinding.includes('submissionGeneration = UUID()'));
  assert(studio.includes('onDismiss: showPendingMessage'));
  assert(!studio.includes('.alert('));
});

check('new Arabic and English copy is unique and format-compatible', () => {
  const localized = ['ar', 'en'].map(lang => read(`PurePetsPro/${lang}.lproj/Localizable.strings`));
  const sources = [home, dashboard, login, scene, status, studio, read('PurePetsPro/ProviderOnboarding/PPProviderSubscriptionManagmetVC.m')].join('\n');
  const keys = [...new Set(sources.match(/Pro(?:Access|Subscriptions?)_[A-Za-z_]+/g))].filter(key => !key.endsWith('_'));
  for (const key of keys) {
    const values = localized.map((text, i) => {
      const rows = [...text.matchAll(new RegExp(`^"${key}"\\s*=\\s*"(.*)";`, 'gm'))];
      assert.equal(rows.length, 1, `${['ar', 'en'][i]} ${key}`);
      return rows[0][1];
    });
    const formats = value => value.match(/%(?:\d+\$)?(?:lu|ld|@|d|f)/g) || [];
    assert.deepEqual(formats(values[0]), formats(values[1]), key);
  }
});

console.log(`PASS ${passed} subscription/access source contracts. Native build, rendering and runtime are UNVERIFIED.`);
