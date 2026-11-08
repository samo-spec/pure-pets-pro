# Pure Pets Pro Delivery Experience Reinvention — Living Execution Handoff

## 2026-11-07 — Missing delivery route address repair

- Current request: Company Deliveries incorrectly shows missing pickup/drop-off. Scope is the canonical read projection consumed by existing Admin/Pro lists/details and official/partner driver tasks; no redesign or client authorization change.
- Read-only live evidence: Firebase environment was verified as `pure-pets-49199`. The specifically supplied order `PP-261029-A455UL` has an immutable shipping snapshot containing non-empty address lines, location name, and `locationPoints`. Its linked fulfillment has the same shipping snapshot but no explicit pickup address/provider snapshot or branch ID. No personal address values are persisted here. No production data was changed.
- Root cause: `normalizeDeliveryJob` forwarded only `pickupAddress`/`dropoffAddress`; fulfillment records store `shippingAddressSnapshot`. The shared native formatter does not recognize checkout `addressLine1`/`addressLine2`/`locationName`/`locatioName`, and official-driver address projection omitted CSV `locationPoints`. Empty maps also incorrectly prevented snapshot fallback.
- Implementation: Infra normalizes the canonical snapshot into existing `formattedAddress`/numeric latitude/longitude fields. Explicit delivery endpoints take precedence; fallback uses the child or original order checkout snapshot, never a mutable customer profile. A missing pickup may resolve only from a linked active canonical branch, with provider ownership checked and per-page reads cached. Missing branch identity remains missing; no arbitrary warehouse/default location is invented. Hotel transport legs retain their own endpoints.
- Integration: `getDeliveryCommandCenter`, `getDeliveryDossier`, `getDriverDeliveryWorkspace`, `getCompanyDeliveryRequest`, `listCompanyDeliveryRequests`, and `listMyAssignedCompanyDeliveries`. Existing membership, staff scope, assignment, and pre-assignment address redaction stay in place. No new callable, collection, rules, indexes, app UI strings or layouts; English/Arabic address content passes through unchanged.
- Files: Infra `functions/deliveryDomain.js`, new `functions/deliveryRouteProjection.js`, the three existing delivery callable owners, route unit tests and expanded Command Center/company/driver tests. Existing unrelated dirty changes were preserved.
- Verification: final rerun PASS for route normalization/branch ownership-cache tests, Command Center tests, company-delivery tests (including list/detail/assigned-driver route parity), official-delivery tests, and 30 driver workspace integration cases. PASS JavaScript syntax for all five changed source modules and scoped whitespace checks. Assigned recipient contact remains separately projected; available drivers still cannot read exact addresses, coordinates or phone. Serving deployment evidence remains UNVERIFIED.
- User subsequently authorized building/running Pro on the connected iPhone 13 Pro Max (`00008110-00046D640EB8401E`). PASS physical-device Debug build of `PurePetsPro.xcworkspace` / `PurePetsPro` with default Xcode DerivedData (`** BUILD SUCCEEDED **`); log `/tmp/purepets-pro-device-build-20261107.log`. PASS installation through `devicectl`, then launch of `Ali-Ahmed.PurePetsPro`; process readback confirmed the installed executable running as PID 2307. These gates prove compilation/install/launch, not route rendering or studio interaction. This authorization did not include Functions deployment or missing historic pickup-data mutation; neither was performed.
- Remaining operational gap: the inspected historic fulfillment has no saved pickup location or branch. An operator must identify the actual pickup branch before a full route can be restored for that record. No production backfill is authorized or performed.
- Release selector, only after explicit authorization: `functions:getDeliveryCommandCenter,functions:getDeliveryDossier,functions:getDriverDeliveryWorkspace,functions:getCompanyDeliveryRequest,functions:listCompanyDeliveryRequests,functions:listMyAssignedCompanyDeliveries`. No app build is needed for this address projection repair; refreshing the existing clients after server deployment consumes their existing supported fields. Device rendering is still unverified.

Date: 2026-11-04
Mode: Local-only, production-grade implementation (Zero unauthorized pushes, deployments, or simulator builds).

---

## 1. Focused Evidence Audit & Contract Matrix

### 1.1 Actor × Authority × Action × Callable Matrix

| Actor | Order Authority | Permitted Status Transitions | Underlying Callable | Server Enforcement & Auditing |
|---|---|---|---|---|
| **Company Owner** (`owner`) | `COMPANY_DELIVERY_REQUEST` | • `offered` → `accepted_by_company`<br>• `offered` → `rejected`<br>• `accepted_by_company` → `assigned_to_driver`<br>• `assigned_to_driver` → reassign<br>• `delivered` → `completed`<br>• Any active → `cancelled` | • `acceptCompanyDeliveryRequest`<br>• `rejectCompanyDeliveryRequest`<br>• `assignCompanyDeliveryDriver`<br>• `reassignCompanyDeliveryDriver`<br>• `completeCompanyDeliveryRequest`<br>• `cancelCompanyDeliveryRequest` | `requireCompanyManager(companyId, callerUid, "delivery.dispatch")`. Evaluates driver eligibility, capacity, location staleness. Audited via `writeAuditLog`. |
| **Company Dispatcher** (`dispatcher`) | `COMPANY_DELIVERY_REQUEST` | Same operational actions as Owner (cannot disable members or delete company). | Same dispatch callables | `requireCompanyManager` verifies dispatcher role. Audited. |
| **Company Driver** (`driver`) | `COMPANY_DELIVERY_REQUEST` | • `assigned_to_driver` → `picked_up`<br>• `picked_up` → `in_transit`<br>• `in_transit` → `delivered`<br>• Online presence toggle | • `updateCompanyDeliveryStatus`<br>• `setCompanyDriverAvailability` (Dedicated) | Validates `assignedDriverUid === callerUid`. Enforces `isValidDriverTransition`. Validates Proof of Delivery & COD. Audited. |
| **Company Viewer** (`viewer`) | `COMPANY_DELIVERY_REQUEST` | Read-only listing and inspection | • `listCompanyDeliveryRequests`<br>• `getCompanyDeliveryRequest`<br>• `listCompanyMembers` | `canViewAllDeliveries(member.data)`. Mutation attempts throw `permission-denied`. |
| **Marketplace Provider** (`canDelivery`) | `FULFILLMENT_V1` & `COMPANY_DELIVERY_REQUEST` | Provider dispatch & handover | • `executeFulfillmentV1DeliveryCommand`<br>• `createCompanyDeliveryRequest` | Managed via `PPDeliveryManager` & `PPFulfillmentManager`. |

---

### 1.2 Identified Architectural & UX Gaps (Ranked)

- **[P0] Missing Driver Availability Mutation for Partner Companies:**
  - `deliveryCompanies.js` tracks `isOnline`, `isAvailable`, `canReceiveAssignments`, and `activeDeliveryCount` on members, but only set `isOnline: false` upon invite/disable. There was no callable allowing a partner driver to toggle online/offline presence with revision concurrency and audit.
  - *Fix:* Implement `setCompanyDriverAvailability` in `Pure Pets Infra/functions/deliveryCompanies.js` and wire to `PPDeliveryCompanyService.m`.
- **[P0] Opaque Dispatcher Assignment Action Sheet:**
  - `PPDeliveryCompanyDetailViewController` and `PPDeliveryCompanyDashboardViewController` used an uninformative `UIAlertController` action sheet displaying only driver names. If a driver was over capacity, on break, paused, or location-stale, the dispatcher had no visibility into why the assignment would fail.
  - *Fix:* Implement a category-defining driver selection surface (`PPDeliveryDriverPickerSheet`) displaying live readiness chips, workload vs capacity, pause flags, and actionable eligibility blocker explanations.
- **[P1] Subordinate Driver Experience & Missing Journey Hero:**
  - Drivers viewing `PPDeliveryCompanyDashboardViewController` saw the same request table as owners, filtered only by status tab, without a prominent **status/readiness control** or **current task / next step** journey hero.
  - *Fix:* Provide dedicated driver operational modes: clear **Online/Offline switch**, single **Current Route / Next Action** card, and unmistakable pickup/dropoff steps with 1-tap navigation and phone calling.
- **[P1] Inaccurate Totals vs Page Counts:**
  - Dashboard displayed `requests.count` (the number of items loaded in memory from pagination) as the total company request count.
  - *Fix:* Clearly label loaded page items, indicate server sync freshness, and preserve search/filter context across pulls.
- **[P2] Complete Proof of Delivery & COD Safe Fallback:**
  - Ensure photo, signature, OTP, and cash requirements explain exact operational requirements to drivers without forged client assertions.

---

## 2. Implementation Progress by Phase

*Status tracking updated as each phase completes.*
