# Pure Pets Pro — Inventory Parity & Reinvention Execution Handoff

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
