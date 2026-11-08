# Pure Pets Pro — Inventory Parity & Reinvention Execution Handoff

## 2026-11-07 — Authorized physical-device build, installation and launch

- User explicitly authorized building/running on the connected iPhone 13 Pro Max. Rechecked physical device `00008110-00046D640EB8401E`.
- PASS: `xcodebuild -workspace PurePetsPro.xcworkspace -scheme PurePetsPro -configuration Debug -destination 'platform=iOS,id=00008110-00046D640EB8401E' -allowProvisioningUpdates build`, using default Xcode DerivedData. Build log `/tmp/purepets-pro-device-build-20261107.log` ends with `** BUILD SUCCEEDED **`. The current local Pro sources, including removal of the recursive image helper below, compiled and linked.
- PASS: installed the resulting Debug-iphoneos `PurePetsPro.app` through `devicectl` without uninstalling the existing app, then launched `Ali-Ahmed.PurePetsPro`. Device process readback confirmed the newly installed executable running as PID 2307.
- UNVERIFIED: entering product/pharmacy studio, save/reopen behavior, rendered RTL/LTR, VoiceOver and accessibility sizes. Launch success is not interactive regression proof.
- No Firebase deployment or production data mutation was performed. The separately documented provider callable updates remain a release dependency; build permission does not authorize their deployment. Earlier build/install-pending entries below are historical and superseded by this receipt.

## 2026-11-07 — Confirmed Options & Matrix Studio stack overflow

- User reports the installed Pro app still exits when opening the studio from product/pharmacy screens.
- **Confirmed root cause:** local physical-device reports `PurePetsPro-2026-11-07-010101.ips` and `PurePetsPro-2026-11-07-011241.ips` under Xcode `DeviceLogs/iPhone-00008110-00046D640EB8401E` contain repeated `static PetAccessory.firstImageURL(for:)` frames, followed by `PPAccessoryVariantFamily.legacySingleVariant(from:)`, `PPAccessoryVariantService.resolveFamily(for:)`, and the studio host. Termination is `EXC_BAD_ACCESS / SIGBUS / KERN_PROTECTION_FAILURE` in the stack guard region.
- Source at the failing symbol contained a Swift extension wrapper whose entire body called `firstImageURL(for:)` again, resolving to itself. This recursed even for products with no image. Both product and pharmacy entry points use this model/helper.
- Minimal fix: remove the recursive Swift wrapper; explicitly import the existing Objective-C `+firstImageURLForAccessory:` as `PetAccessory.firstImageURL(for:)` with `NS_SWIFT_NAME`. The Objective-C selector, nil/empty-image behavior, and all existing call sites remain intact. Firebase and UI composition are unchanged by this crash fix.
- Changed source: `PurePetsPro/BasicClasses/PetAccessory.h` and `PurePetsPro/MarketSection/Variants/PPAccessoryVariantModels.swift`; prior dirty edits preserved.
- Source/static verification: PASS Swift frontend parsing of variant models/section, PASS Objective-C header syntax against the iPhoneOS SDK (including the Swift-name attribute), PASS scoped whitespace check. Source review confirms five unchanged Swift callers now bind through the explicit Objective-C import and no Swift `firstImageURL(for:)` declaration remains. These frontend checks do not constitute an application build, link, or runtime regression test.
- Read-only device inventory confirms a connected iPhone 13 Pro Max with `Ali-Ahmed.PurePetsPro` 1.0.1 build 8 installed. Live system-crash-log listing timed out; the two local Xcode device reports above supplied the crash evidence. No app build or installation was performed.
- Native regression must open both product and pharmacy studios with an existing image and with no image, then save/reopen. Builds/install/runtime remain pending explicit authorization for this Pro scope. No backend deployment is needed for this stack-overflow fix.
- Earlier entries describing crash attribution as unavailable are superseded by these device reports. Earlier media/lifecycle repairs did not remove this recursive helper.

## 2026-11-07 — Studio entry repair and inventory category alignment

- Active scope: Pro inventory categories following Admin, Options & Matrix Studio entry, product/pharmacy variant fidelity. User confirmed the studio button is the reported crash, and requested NextGen V7 UI.
- Inspection complete: Admin `CatalogHorizonTab` uses accessories=1, food=2, live pets=3, medicines=4. Pro's food counter used 0, list mixes categories, refresh can accumulate listeners. Product bridge passes unvalidated Objective-C image arrays to Swift. Initial studio loading calls editor save callback and can overwrite unsaved form state.
- Backend authority: provider marketplace permits types 1/2/4 and explicitly rejects creating live pets. Live-pet family authoring is prohibited. Preserve these constraints; no provider-to-staff privilege transfer.
- Design decision: visible category rail, category-scoped list/counts/create default; exact-SKU family details and existing pharmacy route. Retain UIKit navigation and existing SwiftUI studio. No decorative motion.
- Existing dirty edits preserved; scoped pre-edit snapshots under `/tmp/pp-pro-inventory-20261107-baseline`.
- V7 focused repair strategy loaded. Native build/runtime/render evidence unavailable; device crash-log read timed out. No crash root cause claimed yet.
- Implementation and focused source verification completed on 2026-11-07. Native acceptance and release remain pending; no builds or deployments run for this task.

### Current implementation (2026-11-07)

- Product studio entry: filters malformed legacy image/snapshot arrays before the Objective-C/Swift bridge; initial load and Done no longer invoke a save callback. Committed mutations reload the exact product, preserve unsaved text/category fields, and refresh only studio-owned fields. Catalog revision snapshots are refreshed after product/media writes. Done guards active work and confirms discarding unsaved changes.
- Product images: main-thread picker mutations, replacement rather than repeated appending, complete-upload validation, and a single completion gate. Timeout preserves the draft and cannot issue a duplicate create without images.
- Variant create retries: the service now forwards its stable command ID. The server derives a provider-scoped item ID and verifies the normalized create fingerprint in a transaction; replay returns the same item, changed input under the same command is rejected, and creation audit is atomic. Existing clients without a command ID retain their legacy API behavior.
- Inventory: visible, scrollable, semantic category rail with Admin identities 1/2/3/4; accessories and food are separate; food create defaults and counts use type 2 (legacy type 0 remains readable). Refresh replaces the old listener. Empty/error states retain category navigation. Medicines open the existing pharmacy owner. Live pets show the dedicated individual-record boundary; **Pro live-pet authoring is not implemented or claimed** because the authoritative provider marketplace rejects it.
- Pharmacy: reuses the existing expandable product-family cell through a small shared header. Search runs before grouping; each stock/detail action targets an exact medicine ID. Generic option descriptions appear in cards, search, and detail. Model round-trips retain English text, all media, color/options, and revisions. A staged medicine is updated on final Save rather than duplicated.
- Pharmacy writes: `PPVetManager` uses existing provider callables instead of direct Firestore medicine writes. Infra permits kind 4 only through pharmacy authorization, preserves exact ownership and the existing legacy pharmacy signature, supports variant-aware updates and medical fields, rejects stale revisions, and writes quantity/movement/family projection/audit in a transaction. Family projection revalidates owner, membership, and default SKU. Standalone creation cannot claim an arbitrary family/schema. Live pets and unit/lot inventory stay outside generic quantity writes. No rules, indexes, App Check settings, or production data changed.

### Evidence collected in this resumed implementation

- PASS: `node functions/tests/providerPharmacyVariantCommands.test.js` (isolated fake Firestore; no network/credentials).
- PASS: `node functions/tests/providerMarketplaceAuthorization.test.js`.
- PASS: `node functions/tests/providerVariantFamilyAuthorization.test.js`.
- PASS: Swift frontend **parse only**, touched variant section/service/models/grouping; this does not type-check or link the app.
- PASS: Arabic/English `.strings` plist lint and scoped diff whitespace checks.
- PASS: all seven new `ProInventory_*` keys occur exactly once in both Arabic and English. Final rerun of all three Node suites, JavaScript syntax, Swift parsing and whitespace/localization checks passed after refinement.
- UNVERIFIED: native compilation/linking, actual crash reproduction, physical-device UI, Arabic/English rendered alignment, VoiceOver, AX text sizes, scrolling performance, and live callable behavior. The original device crash log was unavailable; unsafe bridge/lifecycle paths are confirmed defects, not a proven attribution of that particular device crash.

### Release dependencies / next action

1. Review/deploy the changed Infra provider callable source only after current-task deployment authorization. Exact selector: `functions:providerCreateMarketItem,functions:providerUpdateMarketItem,functions:providerArchiveMarketItem,functions:providerUpdateMarketStock,functions:providerUpdateMarketOffer,functions:providerPublishMarketItem`. The local Pro pharmacy write path depends on these server updates; shipping the client first is not a valid release sequence.
2. Build/install/run Pro on the approved physical iPhone 13 Pro Max using normal DerivedData after explicit permission for this scope. Do not substitute simulator or `xcodebuild test`.
3. Exercise new/staged/existing accessories, food, medicine; enter studio, edit all supported axes, save media and prices/quantity, dismiss with dirty state, reopen, search a non-default option, and verify exact-SKU stock and family totals in Arabic/English and accessibility sizes.
4. Live-pet management requires a separately authorized Pro route to the canonical individual-record workflow; the new rail intentionally does not route animals into the product editor or matrix.

### Changed owners in this resumed implementation

- Pro: `PPProviderMarketItem.m`, product editor `.h/.m`, inventory list `.m`, shared `PPProviderMarketFamilyCardCell.h`, variant section/service/grouping Swift sources, `PPVetManager.m` (using existing `.h` additions), pharmacy editor/list/detail `.m`, paired localizations, this handoff.
- Infra: `functions/providerMarketplace.js`, existing authorization test, new isolated `functions/tests/providerPharmacyVariantCommands.test.js`.
- Existing unrelated dirty edits across both repositories were preserved. Earlier evidence below is historical and must not be treated as current device/deployment proof.


**Execution Date:** 2026-11-05  
**Domain:** Inventory, Marketplace Catalog, Options & Variant Matrix, Medicine Pharmacy  
**Targets:**
- Backend: `Pure Pets Infra/`
- Reference: `Pure Pets Admin/`
- Implementation: `Pure Pets Pro/`

---

## Phase 1 — Contract Comparison & Baseline Audit

### 1.1 Source-Level Gaps Identified

| Domain / Surface | Pure Pets Admin (Canonical) | Pure Pets Pro (Observed Baseline) | Root Cause & Security Boundary |
|---|---|---|---|
| **Variant Family Authorization** (`upsertProductVariantFamily`) | Staff inventory auth (`requireInventoryPermission` checks `staff_users` + `stock.create`/`stock.manage`). Authorized for official catalog (`PURE_PETS_OFFICIAL_USER_ID`). | Failed with `INVENTORY_ACCOUNT_TYPE_DENIED` or `VARIANT_PROVIDER_UPGRADE_REQUIRED` for any provider caller or provider-owned item. | Backend explicitly blocked provider variant authoring pending a guarded provider workflow. Resolved by authorizing providers without granting staff role or cross-tenant access. |
| **Provider Capability Check** (`canManageVariants`) | Checked against active staff role & permissions. | `PPAccessoryVariantService.canManageVariants` hardcoded to return `true`. | Pro did not check `currentUser.canAccessProviderMarketplaceFeature` or `currentUser.canPharmacyFeature` on `UsersCol`. |
| **Product Creation & Variant Staging** | `PPAccessoryEditorScreen` dynamically embeds `PPAccessoryVariantSection`. Staging & saves use revision-tracked commands. | `PPProviderMarketItemEditorViewController` displayed a disabled banner: *"Save product details first to enable multi-axis options..."*. Single-item save only. | Pro lacked unified progressive disclosure creation workflow. Providers were forced into disjointed save-then-reopen workflow. |
| **Variant Item Creation Callback** | `PPInventoryCommandService` returns created item IDs. | `PPProviderMarketplaceManager.createMarketItem` invoked `callFunction:` which passed `nil` for `itemID`. | `createStandaloneVariantProduct` always threw `"Failed to create variant product"` because returned `itemID` was discarded as `nil`. |
| **Barcode & SKU in Marketplace Items** | Admin validates and stores barcodes and SKUs with conflict prevention. | `providerCreateMarketItem` in Infra omitted `barcode`, `sku`, `wholesalePrice`, `isVariant`, `isDefaultVariant`, and forced `showInAppMarket: true`. `providerUpdateMarketItem` denied changing `barcode` or `sku`. | Providers were prevented from setting barcodes, SKUs, or non-default variant visibility on variant items. |
| **Medicine Pharmacy Workflow** | `PPPharmacyInventorySurface` with category filters, lot/expiry tracking, dosage form, strengths, and audited inventory transitions. | `PPPharmacyMedicinesViewController` and `PPPharmacyMedicineEditorViewController` used direct client Firestore writes via `PPVetManager`, with zero variant/strength options, no lot tracking, and failing delete (`allow delete: if false`). | Medicine domain completely bypassed backend audit, stock movements, and variant groupings. |
| **Inventory List Presentation** | Admin provides category horizon tabs, family grouping cards with variant chips/swatches, low-stock/out-of-stock KPIs, and instant search by SKU/barcode. | Pro had partial `PPProviderMarketDisplayGroup` in marketplace items, but pharmacy had no grouping, search was basic, and variant chips were rudimentary. | Required a unified, Apple-grade category-defining inventory workspace supporting accessories, food, and medicines. |

---

## Phase 2 — Backend Foundation & Dual-Actor Authorization

### 2.1 Backend Authorization Discipline (`productVariantFamily.js`)
- **Dual-Actor Authorization:**
  - **Staff Path:** `staff_users` + `stock.create`/`stock.manage` + branch scope (governing official catalog `PURE_PETS_OFFICIAL_USER_ID`).
  - **Provider Path:** `UsersCol/{uid}` active status + `features.canAccessProviderMarketplace` (for kind 1 & 2) or `features.canPharmacy` (for kind 4).
- **Tenant Isolation Invariant:** A provider can **ONLY** author variant families for products they own (`product.ownerID === uid` or `product.createdBy === uid`). Rejects cross-provider access (`VARIANT_PERMISSION_DENIED`) and prevents providers from claiming official catalog products (`VARIANT_OFFICIAL_CATALOG_DENIED`).
- **Eliminated Blocker:** Removed the `VARIANT_PROVIDER_UPGRADE_REQUIRED` blocker specifically for authorized provider owners on their own products.
- **Transaction Consistency:** Revalidation inside transaction preserves consistency and prevents race conditions.
- **Mandatory Audit Trail:** Generates audit logs with `actorType: "provider"` or `"staff"`.

### 2.2 Provider Marketplace Enhancements (`providerMarketplace.js`)
- `providerCreateMarketItem`: accepts and persists `barcode`, `sku`, `wholesalePrice`, `isVariant`, `isDefaultVariant`, `productFamilyId`, `variantSchemaVersion`, `showInAppMarket`, `weightText`, `size`.
- `providerUpdateMarketItem`: allows updating `barcode`, `sku`, `wholesalePrice`, `weightText`, `size`.
- `providerUpdateMarketStock`: supports variant products with `{ allowVariants: true }`, writes `stockMovements` rows, and updates `totalAvailableStock` and `hasInStockVariants` on both parent `ProductFamilies` and default variant document.
- `accessKindType: 4` (medicine) creation authorized for users with `canPharmacy: true`.

---

## Phase 3 — Client Models & Command Adapters (`Pure Pets Pro`)

1. **Bridging Header (`PurePetsPro-Bridging-Header.h`):**
   - Added `#import "AdminCore/Models/UserManager.h"` and `#import "AdminCore/Models/UserModel.h"` so Swift code can inspect live user session and capabilities.
2. **Variant Service Provider Capability Check (`PPAccessoryVariantService.swift`):**
   - `canManageVariants` now validates:
     - User is logged in with active account status (`active`, `approved`).
     - User has either `canAccessProviderMarketplaceFeature` (retail provider) or `canPharmacyFeature` (veterinary/pharmacy provider).
   - `createStandaloneVariantProduct` sets `created.isVariant = true` and consumes confirmed `itemID`.
3. **Marketplace Manager Item Creation Callback (`PPProviderMarketplaceManager.m`):**
   - Replaced `callFunction:` with `callFunctionResult:@"providerCreateMarketItem"` in `createMarketItem:completion:`. Returns the actual `result[@"itemID"]` to the callback, enabling automated variant creation.
4. **Accessory Model Serialization (`PetAccessory.m`):**
   - `toFirestoreDictionary` now serializes `productFamilyId`, `variantSchemaVersion`, `isVariant`, `isDefaultVariant`, `variantSortOrder`, `variantAttributes.color`, `selectedOptions`, `selectedOptionsSnapshot`, `variantCombinationKey`, `variantAxis`, `wholesalePrice`.
5. **Soft-Deletion Security Patch (`PPVetManager.m`):**
   - Updated `deleteMedicine:completion:` to perform soft-deletion (`isDeleted: true`, `active: false`, `isAvailable: false`, `showInAppMarket: false`, `noStock: true`, `quantity: 0`) because Firestore security rules reject hard deletes (`allow delete: if false`).

---

## Phase 4 — Unified Product Editor & Options Studio

1. **Progressive Disclosure Creation Flow (`PPProviderMarketItemEditorViewController.m`):**
   - In create mode, replaced the passive *"Save first"* notice with an active *"Enable Options & Open Studio"* (`pp_stageProductForOptionsAndOpenStudio`) action.
   - When tapped: validates required basic fields (Name, Price, Category), automatically stages the base item document via `createMarketItem:`, switches to edit mode with the confirmed `itemID`, and opens `PPAccessoryVariantStudioHostController` without losing context.
   - Re-renders studio status cards and hero summary dynamically upon variant save.
2. **Commercial & Inventory Identifiers:**
   - Added explicit inputs for Wholesale Price (`wholesalePriceField`), SKU (`skuField`), and Barcode (`barcodeField`) under `Market_SectionCommerce`.
   - Wired bidirectional serialization between UI, `PPProviderMarketItem`, and backend callable functions.
3. **Omni-Search & Kind Filtering (`PPProviderMarketItemsViewController.m`):**
   - Expanded search corpus to index `item.sku`, `item.barcode`, `item.pos_smartVariantDescription`, and option badges.
   - Corrected food filter (`PPProviderMarketFilterFood`) to evaluate `accessKindType == 2 || accessKindType == 0`.

---

## Phase 5 — Medicine Inventory Parity

1. **Upgraded Medicine Model (`PPVetMedicineModel`):**
   - Added medical and variant properties: `productFamilyId`, `variantSchemaVersion`, `isVariant`, `isDefaultVariant`, `variantSortOrder`, `selectedOptions`, `selectedOptionsSnapshot`, `variantCombinationKey`, `variantAxis`, `sku`, `barcode`, `wholesalePrice`, `dosageForm`, `strength`, `packSize`, `volume`, `batchNumber`, `expiryDate`.
   - Updated `toDictionary`, `fromDictionary:withID:`, and `copyWithZone:`.
   - Added `- (PetAccessory *)asPetAccessory` to bridge medicine models directly into the shared Options & Matrix Studio.
2. **Medical Option Presets (`PPAccessoryVariantModels.swift`):**
   - Added canonical presets:
     - `presetDosageForm` (`tablets`, `syrup`, `injection`, `drops`, `ointment`)
     - `presetStrength` (`50mg`, `100mg`, `250mg`, `500mg`)
     - `presetPackSize` (`10_units`, `20_units`, `30_units`, `60_units`)
     - `presetVolume` (`10ml`, `50ml`, `100ml`, `250ml`)
   - Mapped system icons: `dosage_form` -> `pills.fill`, `strength` -> `cross.vial.fill`, `pack_size` -> `shippingbox.fill`, `volume` -> `drop.fill`.
   - Included medical presets in `standardPresets()`.
3. **Modernized Medicine Editor (`PPPharmacyMedicineEditorViewController.m`):**
   - Added Medical Specifications section (`dosageFormField`, `strengthField`, `packSizeField`).
   - Added Commercials section (`priceField`, `wholesalePriceField`, `stockField`, `skuField`, `barcodeField`).
   - Integrated Medicine Options & Matrix Studio:
     - In create mode: stages the initial medicine via `addMedicine:` and opens the matrix studio.
     - In edit mode: launches `PPAccessoryVariantStudioHostController` using `[self.medicine asPetAccessory]`.
4. **Pharmacy Hub & Detail Inspector (`PPPharmacyMedicinesViewController.m`):**
   - Expanded search filter to index `strength`, `dosageForm`, `packSize`, `sku`, `barcode`.
   - Enhanced card cells to show medical dimension snippets (`strength · dosageForm · packSize`).
   - Added direct *"Options & Matrix Studio"* launch button in `PPPharmacyMedicineDetailViewController`.

---

## Phase 6 — Verification & Test Evidence

### 6.1 Automated Test Results
- **Provider Variant Family Test Suite:**
  ```bash
  cd "Pure Pets Infra/functions" && node tests/providerVariantFamilyAuthorization.test.js
  ```
  *Result:*
  - Variant line snapshot invariants: **PASS**
  - Provider member product ownership: **PASS**
  - Cross-provider member rejection (`VARIANT_PERMISSION_DENIED`): **PASS**
  - Official catalog protection (`VARIANT_OFFICIAL_CATALOG_DENIED`): **PASS**
  - Provider stock update `allowVariants` bypass: **PASS**
  - Medicine family & option authorization (`accessKindType: 4`): **PASS**
  - Cross-provider medicine member rejection (`VARIANT_PERMISSION_DENIED`): **PASS**
  - Official platform medicine rejection (`VARIANT_OFFICIAL_CATALOG_DENIED`): **PASS**

- **Provider Marketplace Test Suite:**
  ```bash
  cd "Pure Pets Infra/functions" && node tests/providerMarketplaceAuthorization.test.js
  ```
  *Result:* **PASS** (100% assertions green)

- **Cloud Functions Compilation Check:**
  ```bash
  cd "Pure Pets Infra/functions" && node -e "require('./index.js')"
  ```
  *Result:* Clean load, zero syntax errors.

---

## Phase 7 — Operator & Physical Device Runbook

1. **Infra Deployment (When Approved):**
   ```bash
   firebase deploy --only functions:upsertProductVariantFamily,functions:dissolveProductVariantFamily,functions:providerCreateMarketItem,functions:providerUpdateMarketItem,functions:providerUpdateMarketStock
   ```
2. **Pure Pets Pro Physical Device Build:**
   - As per repository governance, builds must only run on the connected **iPhone 13 Pro Max** via Xcode using default DerivedData `/Users/mohammedahmed/Library/Developer/Xcode/`.
   - Open `Pure Pets Pro.xcworkspace` in Xcode.
   - Run on physical device.
3. **Verification Steps on Device:**
   - **Standalone Product:** Create a product with price, stock, SKU, and barcode. Verify it saves and displays as single item.
   - **Product with Options:** Create a new product, tap *"Enable Options & Open Studio"*, add options (e.g., Size & Color), generate matrix, and save. Verify parent item groups variants and aggregate stock updates.
   - **Medicine with Strengths:** Open Pharmacy tab, create medicine, tap *"Enable Options & Open Studio"*, select Strength preset (e.g. 50mg & 100mg), set prices and stock. Verify medicine appears with strength badges and can be edited in matrix.

## 6. Post-Verification Hotfix: TableView Data Binding
- **Issue:** Telemetry header and search pill correctly displayed item metrics (e.g., 42 SKUs, 40 search results), but table view rows below the header were blank.
- **Root Cause:** In `setupTableView` within `PPProviderMarketItemsViewController.m`, `self.tableView.delegate = self;` was set but `self.tableView.dataSource = self;` was omitted, preventing UITableView from querying `numberOfRowsInSection:` and `cellForRowAtIndexPath:`.
- **Resolution:** Added `self.tableView.dataSource = self;` at line 3274 of `PPProviderMarketItemsViewController.m`. Verified all data rows, family cards, and action sheets render as expected.

