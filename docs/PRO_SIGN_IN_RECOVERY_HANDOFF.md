# Pro sign-in recovery — 2026-11-06

## Scope and authorization

- Active task: repair Pure Pets Pro sign-in and its client access gate against Infra authority.
- Admin was inspected read-only. The user reported **“admin app fixed”**; no Admin source changes are part of this task.
- Preserve existing dirty Pro edits. Baseline evidence: `/var/folders/n6/5p16xph116n5w19rfp1yvvxh0000gn/T/pp-admin-pro-auth-iumnebj0/`.
- No production writes, deployment, permission grants, App Check bypass, or rule changes authorized.
- The earlier iPhone build approval concerned the consumer service cell. Admin/Pro builds remain unapproved.

## Inspect — complete

Traced `AdminLoginViewController` → `FUManager` → `AppManager.checkIfUserWithUID:canAccessPro:` → `SceneDelegate`, plus Google SDK configuration and Infra `UsersCol`, provider-feature and account-status rules.

## Identify — complete

1. Profile bootstrap writes `providerIds`, outside Infra's safe owner create/update keys. A first profile can therefore fail to create.
2. Missing UID profiles trigger `UsersCol` collection queries by UID/ID/email. Normal providers cannot list that collection.
3. The Pro gate omits canonical `serviceProvider`, `production`, and `veterinarians` features, while staff/admin roles can bypass provider-feature checks.
4. Google Sign-In uses production App Check configuration even when Firebase uses the Debug provider. Google requires separate debug configuration.
5. Asynchronous bootstrap uses a mutable singleton document reference, and access callbacks do not consistently reject a changed authentication UID.

## Implementation — complete, native validation pending

- `AppManager.m/.h`: canonical and existing provider-feature projections; account/subscription gates; staff authority separated; UID-only profile lookup; shared blocked-account check; Google App Check provider alignment, main-thread readiness coalescing, retry and bounded setup timeout; Release never selects the Debug provider.
- `FUManager.m`: owner-safe profile metadata, transaction-protected creation timestamp, stable document reference, and changed-UID guards. Existing feature/subscription/role data remains untouched.
- `UserManager.m`: restore the signed-in user's document directly before legacy collection lookup; reject stale identity callbacks.
- `AdminLoginViewController.m`, `SceneDelegate.m`: wait for Google App Check readiness, use the same blocked-account check, ignore stale access callbacks, and retain the existing onboarding/company-membership paths.
- No Admin source, Infra rules/functions, user grants, new Firebase paths, UI layout or translations changed. Existing Arabic/English recovery messages are reused.

## Verification

- Source/rule inspection, changed-file whitespace checks, existing bilingual recovery keys, SDK selector inspection and entitlement plist lint: PASS.
- `scripts/pro_sign_in_rules_test.cjs`: **14/14 emulator regressions PASS** against the current Infra rules in isolated `demo-purepets-pro-auth`. Covers first/repeat/concurrent profile bootstrap, creation-time preservation, denied legacy payload, preserved provider authority, owner GET vs forbidden collection query, stale account write denial, privilege escalation denial, blocked/suspended/disabled/deleted accounts.
- Static payload extraction confirms every bootstrap field and metadata allowlist key is accepted by Infra's owner-profile create/update allowlists.
- Evidence: baseline directory above, `rules-test.log`, `pro-validation.json`; emulator exited successfully and shut down. This is not native runtime proof.
- Native build/install/sign-in: UNVERIFIED; no Pro build authorization yet.
- Device readback: approved iPhone 13 Pro Max `00008110-00046D640EB8401E` was **unavailable** on 2026-11-06. No alternate device or simulator used.
- Live account permissions, App Check registration and OAuth configuration: UNVERIFIED.
- Existing Google error text supplied by user: authenticity verification failed / Token failed. Do not treat this as proof of any particular Pro runtime configuration.

## Next

Reconnect/unlock the iPhone and obtain Pro-specific build/install authorization. Use Xcode default DerivedData and only the approved physical iPhone. Validate Google sign-in, repeated launch/session restore, an eligible provider, pending onboarding, and denied accounts. Verify Google Identity/Firebase App Check registration on-device; do not disable enforcement or log/copy debug tokens into artifacts.

## Company Deliveries screenshot — 2026-11-06 04:24 Cairo

### Inspect and identify — complete

- Exact surface: Pro `PPDeliveryListView` hosted from Company Deliveries. Existing delivery files contained other uncommitted work; preserved against a scoped before-copy.
- Live read-only evidence in `pure-pets-49199`, 02:23 UTC: Auth **VALID**, App Check **VALID**; `getDeliveryCommandCenter` returned **403**, then `listCompanyDeliveryRequests` returned **400**. The deployed command-center function was ACTIVE. This incident is not evidence of an App Check outage.
- Least-data account read: active `inventory_manager` staff authority with no delivery-management or driver-task permission; an active legacy driver membership also exists. Infra intentionally denies official-fleet access without the canonical delivery grant, even when an older membership exists. No account identifiers or private profile fields retained here.
- Client defects: new host skipped company-profile verification; unconditional fallback sent an empty company ID; error normalization dropped the structured domain code; wrapped permission errors became `DELIVERY_SERVICE_UNAVAILABLE`. Header also claimed the official fleet without verified company identity.

### Implement and refine — complete

- `PPDeliveryCompanyService.m`: preserves original error metadata; concurrent profile refresh callers wait for the verified result; changed-account/company responses are rejected; empty company IDs cannot reach list requests.
- `PPDeliveryService.m`: verifies company context before workspace loading; assigned drivers use the company path; staff-to-partner fallback requires a verified company plus permission-denied; transport and malformed responses retain their error; dossier loading has matching guards. Structured errors are read through a bounded underlying-error chain.
- `PPDeliveryListView.swift`: neutral company title until verified, then actual company/role; removed the false official-fleet subtitle. Existing localization and layout direction mechanisms retained.
- No Admin edits, backend code/rules deployment, permission grants, company seeding, data mutations, or App Check enforcement changes.

### Verification — complete for available gates

- **PASS**: 10 focused source contracts in `scripts/pro_delivery_access_contract_test.cjs`.
- **PASS**: existing Infra `functions/tests/deliveryCompanies.test.js`, including non-delivery staff denial despite legacy membership and disabled-staff denial. Mock-based suite; no production writes.
- **PASS**: Swift syntax parse of the changed view, bilingual key presence, bridging declaration presence, scoped diff/whitespace review.
- **UNVERIFIED**: native compilation, installation, rendered screen, and live retry after this client patch. No Pro build authorization received; `3` did not unambiguously answer the prior build question.
- Evidence: `/var/folders/n6/5p16xph116n5w19rfp1yvvxh0000gn/T/pp-pro-delivery-c2eaj534/` contains scoped baseline, before-copies, patch, test log and sanitized receipt.

### Remaining access decision

The patch reports the true restriction; it does not grant delivery access. If this account should operate the fleet, an authorized administrator must assign the appropriate canonical delivery permission/scope through the existing staff-management flow. Driver tasks and fleet management are separate grants. Any such production permission change needs explicit authorization.

## Company Deliveries permission screenshot — 2026-11-06 18:49 Cairo

### Inspection and live diagnosis — complete

- The new screenshot is the Pro Company Deliveries surface: neutral company title plus the Pro-only `DeliveryCompany_DashboardShell_OpenCompanySubtitle`, now displaying `DELIVERY_PERMISSION_DENIED` instead of the previous unavailable state.
- Matching `getDeliveryCompanyProfile` logs at 16:49:55 UTC show Auth **VALID**, App Check **VALID**, and HTTP **403**. Read-only evidence: `/var/folders/n6/5p16xph116n5w19rfp1yvvxh0000gn/T/pp-pro-delivery-permission-2fdgx2xh/readback.json`.
- The signed-in UID is not present in this bounded log read. Do not assume the earlier inventory-manager account is still the current account.
- Current Infra contract: `getDeliveryCompanyProfile` calls `validateCompanyAccess` with `delivery.view`. Active official-fleet staff require that permission (or the existing canonical admin / `payments.manage` compatibility grant). Dispatch operations separately require `delivery.dispatch`.
- Official workforce driver access is a different contract: `delivery.tasks.manage`, active staff/user state, active official-company driver membership, and matching assignment/resource scope in `deliveryDriverAuthorization.js`. Driver-only access should use the driver workspace.
- Existing negative regression coverage in `deliveryCompanies.test.js` explicitly preserves denial for unrelated staff permissions despite a legacy company membership, and for disabled staff. Source reviewed for this follow-up; tests were not rerun because no runtime source changed.
- Routing observation: the Pro tab shell directly maps `deliveryCompany` to `PPDeliveryListHostController`, while the dashboard dispatcher can select the driver workspace using verified company context. The intended account role is needed before deciding whether this report requires a routing correction or a staff grant. Do not grant fleet permissions solely to make a driver route open.

### Pending decision and safe continuation

A clarification is pending for the signed-in account and intended access: view-only fleet access, dispatch/assignment management, or assigned-driver jobs. Once supplied, inspect only that account's canonical authority and scope, prepare the exact change through the existing authorized staff-management path, and obtain explicit approval before a production permission mutation if not already clearly authorized.

No app source, backend source, Firebase rule, account permission, company membership, or production configuration changed for this follow-up. The existing Admin Google sign-in build approval is a separate pending task; this screenshot is not build or permission-grant approval.
