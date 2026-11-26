# Pro Identity Portal and multi-account release gates

Status: **guarded implementation; unrestricted multi-account switching disabled**.
Do not change PPProRememberedAccountStore.rolloutEnabled to YES until all gates below are demonstrated with current-source evidence.

## Implemented (code + unit/contract verified; hardware/staging gates remain open)
- PPProSessionFence: session epoch checks in UserManager profile fetches and listeners; logout invalidation.
- PPProRememberedAccountStore: device-only Keychain metadata with unique slot IDs, no credentials or role grants; bounded and UID-deduplicated; rollout stays disabled (`rolloutEnabled == NO`) until hardware/staging certification passes.
- PPProFirebaseAccountRuntime: isolated named-app `FIRApp` / `FIRAuth` / `FIRFirestore` / `FIRFunctions` / `FIRStorage` / `FIRPhoneAuthProvider` slot runtime with pending-write flush before teardown/deletion.
- PPProAccountTransitionCoordinator + PPProSessionCoordinator: atomic journal-backed state machine (`Idle -> Preflight -> Suspended -> Authenticating -> Authorized -> Installed -> Idle`), fail-closed `RecoveryRequired` lock, active-work preflight blockers, Notification V2 async barrier before suspension, synchronous observer/cache teardown, and account-scoped `NSUserDefaults` cleanup on removal.
- Security/Data Managers & ViewControllers: `UserManager`, `FUManager`, `PPStaffAuth`, `RPManager`, `AppManager`, `PPDeliveryCompanyService`, `PPDeliveryService`, `PPDeliveryManager`, `PPFulfillmentManager`, `PPServiceManager`, `PPVetManager`, `PPProviderMarketplaceManager`, `PPAdoptPetManager`, `PPProviderApplicationManager`, `NotificationManager`, `PPNotificationsManager`, `MainKindsArrayManager`, `CitiesManager`, `SubKindModel`, `Styling`, Swift stores/services, and Pro UI view controllers wired to `PPProSessionCoordinator.shared`.
- Auth, Routing, Notifications & Telemetry lifecycle: `AdminLoginViewController`, `SceneDelegate`, `AppDelegate`, `PPDriverCockpitModels`, `PPDriverLocationTracker`, and user preferences (`PPServiceScheduleViewController`, `NotificationSettingsViewController`, `PPProInAppNotificationPresenter`) wired for cold-start recovery, active-work blocking, APNs/Auth URL/Notification forwarding across named slots, Notification V2 barrier deactivation, and deterministic teardown.
- Native Identity Portal SwiftUI login surface (`PPProLoginSurfaceController`) + `AdminLoginViewController`: remembered identity selector (behind rollout gate), remembered account removal confirmation + scoped-defaults purge, and fail-closed transition recovery retry banner (`ar`/`en` localized).
- Selected UID mismatch check before profile bootstrap; fail-closed transition recovery on logout error or slot replacement pending-write failure.
- Native presentation improvements: country selection bridge, accessible focus and identifiers, brand contrast, localized copy, SDK Google mark, completion-driven OTP resend.
- Debug-only presentation fixture route with no Firebase/push initialization and no real auth actions; fixtures cannot authorize application access.

## Remaining release-blocking verification (device/staging/emulator required before flipping `rolloutEnabled = YES`)
1. End-to-end physical-device / staging verification of named-app `FIRApp` slots across Apple Sign-In, Google Sign-In, Phone Auth (SMS + reCAPTCHA + APNs silent push), App Check token exchange, token revocation, and cold-start slot rehydration (`PPProRememberedAccountStore.rolloutEnabled` temporarily enabled in staging/test builds only).
2. Two-account staging isolation proof (`A -> B -> A` with two unrelated staging accounts having distinct provider/fleet/staff roles): offline writes, interrupted switch/process termination, slot replacement with pending writes, delayed push notifications, stale Firestore listeners, active delivery lock, and remembered account removal checking zero cross-account data/preference/cache leakage across all local stores (`UsersCol` disk cache, `SDImageCache`, `YYCache`, `NSUserDefaults`, Notification Center).
3. Notification V2 multi-account server/device integration verification (`registerNotificationDeviceV2`, `deactivateNotificationDeviceV2`, FCM token rotation on account switch) against staging/emulator/production-equivalent Firebase project `pure-pets-49199`.
4. Authorized NextGen V10 visual/accessibility evidence on physical hardware across English LTR and Arabic RTL, Light and Dark appearance, Dynamic Type up to AX5, VoiceOver focus/actions, keyboard navigation, and recovery-locked banner state.
5. Final physical-device sign-off and explicit release approval before flipping `PPProRememberedAccountStore.rolloutEnabled` to `YES`.

Note: Backend rule/deploy changes remain out of scope for this client isolation slice. Keep `PPProRememberedAccountStore.rolloutEnabled` at `NO` until items 1–5 are evidenced on device/staging.
