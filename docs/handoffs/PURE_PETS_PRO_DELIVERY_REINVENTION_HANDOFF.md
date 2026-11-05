# Pure Pets Pro Delivery Experience Reinvention — Living Execution Handoff
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
