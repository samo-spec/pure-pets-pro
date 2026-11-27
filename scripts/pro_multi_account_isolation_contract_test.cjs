const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', 'PurePetsPro');
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

// 7.1 & baseline compile/leakage regression fixes
const appMgrH = read('ProviderOnboarding/PPProviderApplicationManager.h');
const appMgrM = read('ProviderOnboarding/PPProviderApplicationManager.m');
assert(appMgrH.includes('@property (nonatomic, copy, nullable) NSDictionary *userSummary;'),
  'PPProviderProfile must declare userSummary matching Infra providerProfiles');
assert(appMgrM.includes('self.userSummary ='),
  'PPProviderProfile must populate userSummary in pp_populateWithDictionary');
assert(!appMgrM.includes('PPProviderDraftStorageKey(authUser.uid'),
  'clearDraftForProviderType must not reference undefined authUser');
assert(appMgrM.includes('PPProviderDraftStorageKey(uid, providerType)'),
  'clearDraftForProviderType must scope key with active uid');

const subKind = read('BasicClasses/SubKindModel.m');
const blurHashStart = subKind.indexOf('- (void)pp_generateAndSaveBlurHashIfNeededWithImage:');
const blurHashEnd = subKind.indexOf('- (void)', blurHashStart + 20);
const blurHashFn = subKind.slice(blurHashStart, blurHashEnd > blurHashStart ? blurHashEnd : undefined);
assert(!blurHashFn.includes('if (completion)'), 'pp_generateAndSaveBlurHashIfNeededWithImage must not reference non-existent completion param');

// Release gate explicitly enabled per owner authorization
const storeM = read('AdminCore/Models/PPProRememberedAccountStore.m');
assert(storeM.includes('+ (BOOL)rolloutEnabled') && storeM.includes('return YES;'), 'PPProRememberedAccountStore.rolloutEnabled must be explicitly configured');

// P0-01: Credential authentication routes through staged runtime slot when multi-account enabled
const loginM = read('AdminCore/Auth/AdminLoginViewController.m');
assert(!loginM.slice(loginM.indexOf('- (void)pp_signInWithCredential:'), loginM.indexOf('- (NSString *)pp_friendlyFirebaseAuthErrorMessage:')).includes('[activeAuth signInWithCredential:'),
  'P0-01: pp_signInWithCredential must route through PPProSessionCoordinator staged slot auth, never direct FIRAuth fallback');

// P0-03: AppDelegate Notification V2 barrier propagates rotation errors and waits for coordinator commit/rollback
const appDelegate = read('AppDelegate.m');
assert(appDelegate.includes('PPProSessionDidCommitNotification') || appDelegate.includes('PPProSessionTransitionDidRollbackNotification'),
  'P0-03: AppDelegate logout notification barrier must stay active until commit or rollback notification');

// P0-07: No unsafe direct Firebase singletons in operational managers/view controllers
for (const file of [
  'AdminCore/Security/FUManager.m',
  'ThirdParty/Styling/Styling.m',
  'FulfillmentSection/PPFulfillmentManager.m',
  'FulfillmentSection/PPFulfillmentListViewController.m',
  'FulfillmentSection/PPFulfillmentPickupStoreViewController.m',
  'FulfillmentSection/PPFulfillmentDetailViewController.m'
]) {
  const src = read(file);
  assert(!src.includes('?: [FIRAuth auth]'), `${file}: remove fallback to default [FIRAuth auth]`);
  assert(!src.includes('?: FIRAuth.auth'), `${file}: remove fallback to default FIRAuth.auth`);
  assert(!src.includes('?: [FIRStorage storage]'), `${file}: remove fallback to default [FIRStorage storage]`);
  assert(!src.includes('?: [FIRFirestore firestore]'), `${file}: remove fallback to default [FIRFirestore firestore]`);
}

// P0-09: SceneDelegate composite root ownership key & privacy overlay
const sceneDelegate = read('SceneDelegate.m');
assert(sceneDelegate.includes('currentRootOwnershipKey'), 'P0-09: SceneDelegate must key root replacement on UID+generation+role/workspace');

// P0-11: FIRFirestore terminateWithCompletion + clearPersistenceWithCompletion before deleteApp
const runtimeM = read('AdminCore/Security/PPProFirebaseAccountRuntime.m');
assert(runtimeM.includes('terminateWithCompletion:') && runtimeM.includes('clearPersistenceWithCompletion:'),
  'P0-11: Slot teardown must terminate Firestore and clear persistence before deleteApp');

// P0-13: Active-work check isolated from cockpit UI lifecycle
const driverModels = read('DeliverySection/PPDriverCockpitModels.swift');
assert(driverModels.includes('scopedDefaultsKey') && !driverModels.includes('"pp_pro_driver_cockpit_selected_company_v1"'),
  'Driver cockpit company selection key must be UID-scoped');

// WebView & media & upload isolation
const webApp = read('Main Controllers/PPAdminWebAppViewController.m');
assert(webApp.includes('nonPersistentDataStore') && webApp.includes('removeDataOfTypes:') && webApp.includes('PPProSessionDidSuspendNotification'),
  'WKWebView must isolate/clear website data on session change');

const mapView = read('DeliverySection/PPInAppGoogleMapView.swift');
assert(mapView.includes('nonPersistent()'),
  'Map WKWebView must use non-persistent websiteDataStore');

// Catalog Firestore routing (no raw [FIRFirestore firestore])
const mainKinds = read('BasicClasses/MainKindsArrayManager.m');
assert(!mainKinds.includes('[FIRFirestore firestore]') && mainKinds.includes('catalogFirestore'),
  'MainKindsArrayManager must use coordinator catalogFirestore');

// In-app notification presenter suspend & recipient isolation
const presenter = read('NotificationsSection/PPProInAppNotificationPresenter.m');
assert(
  presenter.includes('PPProSessionDidSuspendNotification') &&
    presenter.includes('registerSessionTeardownHandler:') &&
    presenter.includes('PPProNoticePayloadRecipientUID') &&
    presenter.includes('isSuspendedOrLocked'),
  'PPProInAppNotificationPresenter must block suspended sessions, verify recipient UID, and dismiss on suspend'
);

// Chat voice upload active-work blocker & suspend cleanup
const messages = read('ProviderOnboarding/PPUserMessagesViewController.m');
assert(
  messages.includes('registerActiveWorkBlocker:') &&
    messages.includes('registerAsyncSessionTeardownHandler:') &&
    messages.includes('activeVoiceUploadURL') &&
    messages.includes('PPProSessionDidSuspendNotification'),
  'PPUserMessagesViewController must register active-work blocker and tear down uploads/audio on suspend'
);

// Draft & booking cache isolation (no anon / default fallback keys)
const appMgr = read('ProviderOnboarding/PPProviderApplicationManager.m');
assert(!appMgr.includes('@"anon"'),
  'PPProviderApplicationManager must never store drafts under shared anon key');

const svcMgr = read('ServiceSection/PPServiceManager.m');
assert(!svcMgr.includes('ownerID ?: @"default"') && svcMgr.includes('PPProSessionDidSuspendNotification'),
  'PPServiceManager must never use shared default bookings key and must cancel image uploads on suspend');

// GPS & profile upload teardown on session suspend
const orderDetail = read('DeliverySection/PPDeliveryOrderDetailViewController.m');
assert(orderDetail.includes('PPProSessionDidSuspendNotification') && orderDetail.includes('stopUpdatingLocation'),
  'PPDeliveryOrderDetailViewController must tear down locationManager on session suspend');

const provEditor = read('Main Controllers/PPProviderProfileEditorViewController.m');
assert(provEditor.includes('activeAvatarUploadTask') && provEditor.includes('PPProSessionDidSuspendNotification'),
  'PPProviderProfileEditorViewController must cancel in-flight uploads on session suspend');

const profVC = read('Main Controllers/PPProProfileSettingsViewController.m');
assert(
  profVC.includes('activeAvatarUploadTask') &&
    profVC.includes('PPProSessionDidSuspendNotification') &&
    profVC.includes('configureMultiAccountEnabled:'),
  'PPProProfileSettingsViewController must cancel uploads on suspend and configure multi-account surface'
);

// NextGen Multi-Account UI surfaces & localized strings
const loginSurface = read('AdminCore/Auth/PPProLoginSurfaceController.swift');
assert(
  loginSurface.includes('didRequestQuickSwitchToUID') &&
    loginSurface.includes('proLoginSurfaceDidTapCancelAddAccount') &&
    loginSurface.includes('proLoginSurfaceDidTapSignOutAll') &&
    loginSurface.includes('pro.login.cancelAddAccount') &&
    loginSurface.includes('pro.login.signOutAll'),
  'PPProLoginSurfaceController must wire quick switch, add-account cancel, and sign-out-all actions'
);

const profView = read('Main Controllers/PPProProfileSettingsView.swift');
assert(
  profView.includes('multiAccountGovernanceSection') &&
    profView.includes('pro.profile.addAccount') &&
    profView.includes('pro.profile.signOutAll'),
  'PPProProfileSettingsView must expose NextGen multi-account governance controls'
);

const enStrings = read('en.lproj/Localizable.strings');
const arStrings = read('ar.lproj/Localizable.strings');
for (const key of [
  'ProIdentitySignOutAllTitle',
  'ProIdentitySignOutAllMessage',
  'ProIdentitySignOutAll',
  'ProIdentityAddAccountTitle',
  'ProIdentityCancelAddAccount',
  'ProIdentitySwitchAction',
  'ProIdentityTransition_Preflight',
  'ProIdentityTransition_SignOutAll',
]) {
  assert(enStrings.includes(`"${key}"`) && arStrings.includes(`"${key}"`),
    `Missing EN/AR localization for ${key}`);
}

console.log('PASS all multi-account hardening & isolation contract assertions');
