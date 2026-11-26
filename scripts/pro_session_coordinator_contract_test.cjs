const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');

const pbxproj = read('PurePetsPro.xcodeproj/project.pbxproj');
const pch = read('PurePetsPro/PrefixHeader.pch');
const bridging = read('PurePetsPro/PurePetsPro-Bridging-Header.h');
const store = read('PurePetsPro/AdminCore/Models/PPProRememberedAccountStore.m');
const coordinatorH = read('PurePetsPro/AdminCore/Security/PPProSessionCoordinator.h');
const coordinatorM = read('PurePetsPro/AdminCore/Security/PPProSessionCoordinator.m');
const runtimeM = read('PurePetsPro/AdminCore/Security/PPProFirebaseAccountRuntime.m');
const appDelegate = read('PurePetsPro/AppDelegate.m');
const sceneDelegate = read('PurePetsPro/SceneDelegate.m');
const loginVC = read('PurePetsPro/AdminCore/Auth/AdminLoginViewController.m');
const loginSurface = read('PurePetsPro/AdminCore/Auth/PPProLoginSurfaceController.swift');
const cockpitModels = read('PurePetsPro/DeliverySection/PPDriverCockpitModels.swift');
const tracker = read('PurePetsPro/DeliverySection/PPDriverLocationTracker.swift');
const scheduleVC = read('PurePetsPro/ServiceSection/PPServiceScheduleViewController.m');
const notifSettings = read('PurePetsPro/NotificationsSection/NotificationSettingsViewController.m');
const inAppPresenter = read('PurePetsPro/NotificationsSection/PPProInAppNotificationPresenter.m');
const enStrings = read('PurePetsPro/en.lproj/Localizable.strings');
const arStrings = read('PurePetsPro/ar.lproj/Localizable.strings');

assert(store.includes('return NO; // Release gate'), 'Rollout gate must stay disabled until release gates are signed off');
assert(pbxproj.includes('PPProSessionCoordinator.m') && pbxproj.includes('PPProSessionCoordinator.h'), 'Xcode target must compile PPProSessionCoordinator');
assert(pch.includes('PPProSessionCoordinator.h') && bridging.includes('PPProSessionCoordinator.h'), 'PCH and Swift bridging header must expose PPProSessionCoordinator');
assert(coordinatorH.includes('beginRememberedAccountSignInOrSwitchToUID:') && coordinatorM.includes('pp_suspendTicket:'), 'Coordinator must stage atomic ticket transitions');
assert(runtimeM.includes('teardownSlotAppWithCompletion:') && runtimeM.includes('waitForPendingWritesWithCompletion:'), 'Runtime teardown must flush pending writes before app deletion');

assert(appDelegate.includes('setAPNSTokenForActiveAuths:deviceToken'), 'AppDelegate must forward APNs token across active/staged auth slots');
assert(appDelegate.includes('canHandleAuthURL:url') && appDelegate.includes('canHandleAuthNotification:userInfo'), 'AppDelegate must route auth redirects and silent pushes across slots');
assert(appDelegate.includes('registerNotificationBarrierHandler:') && appDelegate.includes('PPProSessionDidChangeActiveRuntimeNotification'), 'AppDelegate must wire Notification V2 barrier and re-attach auth listener on slot switch');
assert(appDelegate.includes('PPProSessionCoordinator.shared activeFunctions'), 'AppDelegate Notification V2 callables must use coordinator activeFunctions');

assert(sceneDelegate.includes('performColdStartRecoveryCheckWithCompletion:'), 'SceneDelegate must run cold-start recovery check');
assert(sceneDelegate.includes('[PPProSessionCoordinator.shared requiresTransitionRecovery]'), 'SceneDelegate must lock out workspace routes during transition recovery');
assert(sceneDelegate.includes('canHandleAuthURL:ctx.URL'), 'SceneDelegate must forward auth callback URLs across slots');
assert(sceneDelegate.includes('slotID:PPProSessionCoordinator.shared.activeSlot.slotID'), 'Remembered identity persistence must include active slot ID');

assert(loginVC.includes('beginRememberedAccountSignInOrSwitchToUID:') && loginVC.includes('beginProvisionalSignInFromUID:'), 'AdminLoginViewController must stage sessions through coordinator');
assert(loginVC.includes('completeAuthenticationForTicket:') && loginVC.includes('handleAuthenticationFailureForTicket:'), 'AdminLoginViewController must commit/fail closed through coordinator');
assert(loginVC.includes('activePhoneProvider'), 'AdminLoginViewController must use active slot phone auth provider');
assert(loginVC.includes('proLoginSurfaceDidTapRecoveryRetry:') && loginVC.includes('didRequestRemoveRememberedAccount:'), 'AdminLoginViewController must own recovery retry and account removal');

assert(loginSurface.includes('pro.login.recoveryBanner') && loginSurface.includes('pro.login.recoveryRetry') && loginSurface.includes('pro.login.removeRememberedAccount'), 'Login surface must expose recovery banner and account removal controls');
assert(!/^\s*import\s+Firebase|Auth\.auth|Firestore\.firestore|Functions\.functions|Storage\.storage|FIRAuth|FIRFirestore/m.test(loginSurface), 'Swift login presentation must stay free of Firebase imports and calls');

assert(cockpitModels.includes('registerActiveWorkBlocker') && cockpitModels.includes('registerSessionTeardownHandler'), 'Driver cockpit must block switches during active deliveries and tear down on suspend');
assert(tracker.includes('registerSessionTeardownHandler') && tracker.includes('resetForSessionTeardown'), 'Driver location tracker must stop and reset telemetry on session teardown');

for (const file of [scheduleVC, notifSettings, inAppPresenter]) {
  assert(file.includes('scopedDefaultsKey:'), 'Per-user defaults must use account-scoped keys');
}

for (const key of [
  'DriverCockpit_ActiveWork_SwitchBlocked',
  'ProIdentityRecoveryTitle',
  'ProIdentityRecoveryMessage',
  'ProIdentityRecoveryRetry',
  'ProIdentityRemoveAccount',
  'ProIdentityRemoveAccountTitle',
  'ProIdentityRemoveAccountMessage',
]) {
  assert(enStrings.includes(`"${key}"`) && arStrings.includes(`"${key}"`), `Missing AR/EN localization key: ${key}`);
}

console.log('PASS session coordinator, lifecycle wiring, isolation, and UI recovery contracts');
