# Pure Pets Pro — Full Application Context

> **Firebase Project:** `pure-pets-49199` | **Region:** `us-central1`
> **Pro Bundle ID:** `Ali-Ahmed.PurePetsPro`
> **Primary Language:** Arabic (RTL) · Secondary: English (LTR)
> **Last Updated:** June 2026

---

## Table of Contents

1. [What Is Pure Pets Pro?](#1-what-is-pure-pets-pro)
2. [Supported Provider Types](#2-supported-provider-types)
3. [Architecture Overview](#3-architecture-overview)
4. [Frontend: How the Pro App Works](#4-frontend-how-the-pro-app-works)
   - [4.1 Entry & Auth Flow](#41-entry--auth-flow)
   - [4.2 Provider Onboarding](#42-provider-onboarding)
   - [4.3 Dashboard & Role-Gated Sections](#43-dashboard--role-gated-sections)
   - [4.4 Delivery Management Module](#44-delivery-management-module)
   - [4.5 Service Provider Module](#45-service-provider-module)
   - [4.6 Veterinarian Module](#46-veterinarian-module)
   - [4.7 Pharmacy Module](#47-pharmacy-module)
   - [4.8 Subscription Management in Pro](#48-subscription-management-in-pro)
   - [4.9 Notifications Module](#49-notifications-module)
   - [4.10 Agent/Sales Module](#410-agentsales-module)
5. [Backend: How the Pro App Works (Infra)](#5-backend-how-the-pro-app-works-infra)
   - [5.1 Cloud Functions Catalog](#51-cloud-functions-catalog)
   - [5.2 Firestore Security Rules](#52-firestore-security-rules)
   - [5.3 Storage Rules](#53-storage-rules)
   - [5.4 Audit Logging](#54-audit-logging)
   - [5.5 Staff Authorization System](#55-staff-authorization-system)
6. [How the Pro App Connects to the Consumer Apps](#6-how-the-pro-app-connects-to-the-consumer-apps)
   - [6.1 Consumer iOS App Integration](#61-consumer-ios-app-integration)
   - [6.2 Consumer Android App Integration](#62-consumer-android-app-integration)
   - [6.3 Shared Firestore Collections](#63-shared-firestore-collections)
7. [Subscription System — Complete Details](#7-subscription-system--complete-details)
   - [7.1 User-Level Subscriptions](#71-user-level-subscriptions)
   - [7.2 Provider Plans](#72-provider-plans)
   - [7.3 Vet Subscriptions](#73-vet-subscriptions)
   - [7.4 Service Subscriptions](#74-service-subscriptions)
   - [7.5 Delivery Subscriptions](#75-delivery-subscriptions)
8. [Provider Item Lifecycle: Add → Deliver](#8-provider-item-lifecycle-add--deliver)
   - [8.1 Pharmacy Provider: Medicine Lifecycle](#81-pharmacy-provider-medicine-lifecycle)
   - [8.2 Service Provider: Service Offer Lifecycle](#82-service-provider-service-offer-lifecycle)
   - [8.3 Accessory Seller: Pet Accessory Lifecycle](#83-accessory-seller-pet-accessory-lifecycle)
   - [8.4 Delivery Provider: Order Fulfillment Lifecycle](#84-delivery-provider-order-fulfillment-lifecycle)
9. [Product/Inventory Storage](#9-productinventory-storage)
   - [9.1 Frontend (Pro App + Consumer App)](#91-frontend-pro-app--consumer-app)
   - [9.2 Backend (Cloud Functions + Firestore)](#92-backend-cloud-functions--firestore)
10. [Console Admin: Pro Management Dashboard](#10-console-admin-pro-management-dashboard)
11. [Complete Firestore Collection Map](#11-complete-firestore-collection-map)
12. [Permission & Role Matrix](#12-permission--role-matrix)

---

## 1. What Is Pure Pets Pro?

**Pure Pets Pro** is the professional tools suite of the Pure Pets platform. It is a native iOS application (Objective-C + Swift, UIKit) that provides business-facing capabilities for:

- **Service Providers** — groomers, trainers, pet sitters, walkers
- **Veterinarians** — clinics and individual veterinarians
- **Pharmacies** — pet medicine inventory management
- **Delivery Partners** — order pickup and delivery
- **Sales Agents** — branch-based sales staff
- **Staff / Admins** — platform administration

The Pro app is **NOT** the consumer app. It has its own bundle ID (`Ali-Ahmed.PurePetsPro`), its own Firebase configuration, and a restrictive access gate that only allows users with Pro-enabled features to enter. Regular consumers who install Pro are routed to a provider application flow instead.

---

## 2. Supported Provider Types

| Provider Type | Firestore Key | Feature Flag | What They Do |
|---|---|---|---|
| **Delivery Subscription** | `delivery_subscription` | `canDelivery` | Pick up orders from sellers, deliver to customers, collect cash payments |
| **Service Provider** | `service` | `canOfferServices` | Offer grooming, training, walking, sitting, and other services |
| **Veterinarian** | `vet` | `canVet` | Create clinic profiles, post medicines, manage appointments |
| **Pharmacy** | `pharmacy` | `canPharmacy` | Upload and manage pet medicine inventory |
| **Seller / Accessory** | (built-in) | `canSellAccessories` | Post pet accessories, food, and live pets for sale |

A single user can hold multiple provider types simultaneously (e.g., a vet who also runs a pharmacy).

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                     Pure Pets Platform                            │
│                                                                   │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐          │
│  │ Consumer iOS │   │ Consumer     │   │ Marketing    │          │
│  │ (Pure Pets   │   │ Android      │   │ Website      │          │
│  │  IOS/)       │   │ (Pure Pets   │   │ (Pure Pets   │          │
│  │              │   │  Android/)   │   │  Website/)   │          │
│  └──────┬───────┘   └──────┬───────┘   └──────────────┘          │
│         │                  │                                      │
│         │    ┌─────────────┴──────────────┐                       │
│         │    │                            │                       │
│         ▼    ▼                            ▼                       │
│  ┌─────────────────────────────────────────────────┐              │
│  │              Firebase Backend                    │              │
│  │  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │              │
│  │  │ Firestore │ │  Auth    │ │ Cloud Functions │  │              │
│  │  │ Database  │ │(Phone,   │ │ (42 functions) │  │              │
│  │  │           │ │ Apple,   │ │                │  │              │
│  │  │           │ │ Google)  │ │                │  │              │
│  │  └───────────┘ └──────────┘ └────────────────┘  │              │
│  │  ┌───────────┐ ┌──────────┐ ┌────────────────┐  │              │
│  │  │ Storage   │ │  App     │ │  FCM / Push    │  │              │
│  │  │           │ │  Check   │ │  Notifications │  │              │
│  │  └───────────┘ └──────────┘ └────────────────┘  │              │
│  └─────────────────────────────────────────────────┘              │
│         ▲                  ▲                                      │
│         │                  │                                      │
│  ┌──────┴───────┐   ┌──────┴───────┐                              │
│  │ Pro iOS      │   │ Console Web  │                              │
│  │ (Pure Pets   │   │ Admin        │                              │
│  │  Pro/)       │   │ (Pure Pets   │                              │
│  │              │   │  Console/)   │                              │
│  └──────────────┘   └──────────────┘                              │
└──────────────────────────────────────────────────────────────────┘
```

The Pro app and the Console admin are the **management plane**. Consumer apps (iOS, Android) are the **discovery and purchase plane**. Both planes read from and write to the same Firestore collections, protected by role-based security rules enforced at the Firestore and Cloud Function layers.

---

## 4. Frontend: How the Pro App Works

### 4.1 Entry & Auth Flow

The app launches through `SceneDelegate` which implements a root-switching pattern:

```
App Launch
  │
  ▼
Splash Screen (2.2s minimum animated splash)
  │
  ▼
Firebase Auth listener fires
  │
  ├─ No auth user ──► Login Screen
  │                     │
  │                     ├─ Phone OTP (FIRPhoneAuthProvider)
  │                     ├─ Apple Sign-In (ASAuthorizationAppleIDProvider)
  │                     └─ Google Sign-In (GIDSignIn)
  │
  └─ Auth user present ──► AppManager.checkIfCurrentUserCanAccessPro:
        │
        ├─ subscription.status == "blocked" ──► Sign out → Login
        │
        ├─ Has Pro feature flags enabled ──► Dashboard (AdminDashboardViewController)
        │    (canOfferServices || canDelivery || canVet || canPharmacy)
        │
        └─ No Pro features ──► Provider Application Status
                               (PPProviderApplicationStatusViewController)
                               or "Become Provider" bottom sheet
```

**Key classes:**
- `SceneDelegate` — root routing controller
- `AppManager` (singleton `AppMgr`) — Firebase config, App Check, Pro access gate
- `AdminLoginViewController` — login screen with SwiftUI-branded surface
- `PPProLoginSurfaceController.swift` — SwiftUI login cards (Sign-In methods + Provider Application CTA)
- `PPBiometric` — Face ID / Touch ID for credential persistence in Keychain

**App Check:**
The Pro app uses a custom resilient App Check provider that wraps `AppAttest` with `DeviceCheck` fallback. On simulator, it uses a debug provider with token printing for Firebase Console registration.

---

### 4.2 Provider Onboarding

When a user without Pro features signs in, they are routed to the provider application flow:

1. **PPProviderApplicationStatusViewController** — Shows current application status (pending/approved/denied)
2. **PPBecomeProviderBottomSheetViewController** — Bottom sheet to:
   - Select provider type (Delivery, Service, Vet, Pharmacy)
   - Fill application form (fullName, phone, city, email, businessName, notes, coverageAreas)
   - Choose a plan from available `providerPlans`
   - Submit application
3. **PPProviderApplicationManager** — Fetches available plans, validates drafts, submits via `submitProviderApplication` Cloud Function

**Firestore writes during onboarding:**
- `providerApplications/{uid}_{type}` — application document with planId, form data, status="pending"
- On approval by staff: `providerProfiles/{uid}_{type}` is created, `UsersCol/{uid}.features` gets the corresponding flag enabled

---

### 4.3 Dashboard & Role-Gated Sections

`AdminDashboardViewController` builds sections dynamically based on user permissions:

| Section | Required Permission | Destination |
|---|---|---|
| Delivery Management | `canDelivery` + `canManageDeliveryPermission` | `PPDeliveryDashboardViewController` |
| Manage Services | `canOfferServices` + `canManageServiceProviderPermission` | `PPServicesListViewController` |
| Manage Veterinarians | `canVet` + `canManageVetPermission` | `PPVetsListViewController` |
| Manage Pharmacy | `canPharmacy` + `canManagePharmacyPermission` | `PPPharmacyMedicinesViewController` |
| Profile Settings | Always visible | Inline settings |
| Notification Settings | Always visible | `NotificationSettingsViewController` |

Each section follows a consistent MV-Singleton pattern:
- **Model** — pure data object (`PPServiceModel`, `PPVetModel`, etc.)
- **Manager (Singleton)** — Firestore CRUD + Cloud Function calls
- **List VC → Detail VC → Add/Edit VC** — standard drill-down navigation
- **Subscription VC** — plan management for vets and services

---

### 4.4 Delivery Management Module

**Files:** `DeliverySection/`

**PPDeliveryManager (singleton):**
- Real-time `onSnapshot` listener on `Orders` collection
- Filters orders by delivery-relevant statuses
- Cloud Function calls for delivery actions:
  - `deliveryTransitionOrderStatus` with actions: `accept`, `pickup`, `in_transit`, `deliver`, `collect_payment`, `complete`, `cancel`

**PPDeliveryDashboardViewController:**
- Segmented filter: Ready / Pending Pickup / In Transit / Delivered / Cancelled / All
- Order cards with customer info, items, delivery address

**PPDeliveryOrderModel:**
- Full order model with `items[]` (name, imageURL, quantity, price, variant)
- Customer info, delivery assignment, status constants
- Delivery workflow statuses

**PPDeliveryStatusTimelineView:**
- Visual timeline for order status progression
- Shows each state transition with timestamps

**Delivery State Machine:**
```
READY_TO_SHIP → DELIVERY_REQUESTED → AWAITING_HANDOVER
  → PICKED_UP → IN_TRANSIT → DELIVERED
  → PAYMENT_PENDING (cash orders) → PAYMENT_CONFIRMED → COMPLETED

Error paths: → DELIVERY_CANCELLED | DELIVERY_FAILED | RETURNED_TO_STORE
Reassignment: AWAITING_HANDOVER/DELIVERY_FAILED → back to DELIVERY_REQUESTED
```

---

### 4.5 Service Provider Module

**Files:** `ServiceSection/`

**PPServiceManager (singleton):**
- Owner-scoped CRUD: all queries filter by `serviceOwnerID` matching current user
- Image upload to Firebase Storage
- Availability toggle

**PPServiceModel:**
- Fields: `serviceID`, `serviceOwnerID`, `title`, `desc`, `price`, `currency`, `category`, `type` (Training/Grooming), `imageURL`, `isAvailable`
- Subscription fields (read-only in Pro, managed by backend/admin): `subscriptionPlan`, `subscriptionStatus`, `subscriptionActive`, `subscriptionStartDate`, `subscriptionEndDate`
- Review data: `ratingValue`, `reviewCount`, `reviews` (top 5)

**View Controllers:**
- `PPServicesListViewController` — list of provider's services
- `PPServiceCell` — cell with service info
- `PPServiceDetailViewController` — detail with subscription info + "My Plan" action
- `PPAddEditServiceViewController` — add/edit form with image picker
- `PPServiceSubscriptionViewController` — plan management

---

### 4.6 Veterinarian Module

**Files:** `VeterinarianSection/`

**PPVetManager (singleton):**
- Full CRUD for vet profiles
- Medicine management under `veterinarians/{vetID}/medicines/`
- Subscription update method: `updateSubscriptionForVetID:tier:active:startDate:endDate:`

**PPVetModel:**
- Profile fields: `vetID`, `userID`, `title`, `descriptionText`, `phone`, `whatsapp`, `type` (Personal/Company), `availableDate`, `vetCost`, `animalTypes`
- Subscription: `subscriptionTier` (Free=0, Basic=1, Premium=2), `subscriptionActive`, `subscriptionStartDate`, `subscriptionEndDate`
- Permissions: `canEditProfile`, `canPostServices`, `canPostMedicines`

**PPVetMedicineModel:**
- `medicineID`, `title`, `description`, `imageUrl`, `vetId`, `userId`
- `animalTypes`, `category`, `price`, `stockQuantity`, `isAvailable`, `isPublished`

**View Controllers:**
- `PPVetsListViewController` — list with subscription tier pills
- `PPVetCell` — displays subscription tier badge (red if expired, brand color if active)
- `PPVetDetailViewController` — detail with subscription info
- `PPAddEditVetViewController` — add/edit form
- `PPVetSubscriptionViewController` — XLForm-based subscription plan management

---

### 4.7 Pharmacy Module

**Files:** `PharmacySection/`

**PPPharmacyMedicinesViewController:**
- Medicine inventory list (table view)
- Each row shows medicine name, price, stock, availability

**PPPharmacyMedicineEditorViewController:**
- Add/Edit medicine form
- Fields: title, description, price, stockQuantity, animalTypes, category
- Photo picker for medicine image
- Writes to `petAccessories` collection with `accessKindType=4` (medicine type)

Products from pharmacies are stored in the unified `petAccessories` collection — the **only** stock/inventory collection. Medicine items are distinguished by `accessKindType == 4`.

---

### 4.8 Subscription Management in Pro

Subscriptions are managed differently by provider type:

**Vet Subscriptions** (`PPVetSubscriptionViewController`):
- XLForm-based controller
- Tier selection: Free (0), Basic (1), Premium (2)
- Start/end date pickers
- Active toggle
- Writes to `veterinarians/{vetID}` fields: `subscriptionTier`, `subscriptionActive`, `subscriptionStartDate`, `subscriptionEndDate`

**Service Subscriptions** (`PPServiceSubscriptionViewController`):
- Plan management for service providers
- Subscription fields on `serviceOffers` docs are read-only in the Pro app — only staff can modify them
- The VC displays current plan and allows management actions

**User Subscriptions** (backed by Cloud Functions):
- Stored on `UsersCol/{uid}.subscription` object
- Fields: `plan`, `status`, `source`, `startedAt`, `expiresAt`
- Managed via `updateUserSubscription` Cloud Function (staff only)
- The Pro access gate checks `subscription.status == "blocked"` to deny access

---

### 4.9 Notifications Module

**Files:** `NotificationsSection/`

**PPNotificationsManager:**
- FCM token management
- Audience-based push sending (specific users, all, admins, everyone)
- Notification composition with title, body, image, deep link

**NotificationManager:**
- Notification CRUD
- Merges notifications from `UsersCol/{uid}/items` and `staff_users/{uid}/items` subcollections

**View Controllers:**
- `NotificationsListViewController` — notification list
- `NotificationComposerViewController` — compose and send
- `NotificationSettingsViewController` — per-user notification preferences

---

### 4.10 Agent/Sales Module

**PPAgentModel:**
- Sales agent from `agents` Firestore collection
- Fields: `agentID`, `userID`, `branchID`, `role` (Sales/Manager/Cashier/Viewer), `commissionRate`

Used by staff with agent management permissions.

---

## 5. Backend: How the Pro App Works (Infra)

### 5.1 Cloud Functions Catalog

All functions use Node.js 22, CommonJS, located in `Pure Pets Infra/functions/`. There are **42 exported functions**:

#### Staff Authorization (`staffAuth.js`)
| Function | Purpose |
|---|---|
| `createStaffMember` | Creates Auth user + `staff_users` doc + `UsersCol` entry + custom claims |
| `assignExistingUserAsStaff` | Promotes existing non-staff user to staff role |
| `updateStaffMember` | Updates role, permissions, scope, status |
| `disableStaffMember` | Sets status to "disabled", clears `isStaff` claim |
| `downgradeStaffMemberToUser` | Converts staff back to regular user |
| `getStaffMember` | Reads single staff profile |
| `listStaffMembers` | Lists staff (requires `staff.view` permission) |

#### User Access Management (`userAccess.js`)
| Function | Purpose |
|---|---|
| `updateUserFeatures` | Enables/disables feature flags on `UsersCol.features` + syncs to custom claims |
| `updateUserSubscription` | Updates subscription plan/status/source on `UsersCol.subscription` |
| `updateUserRestrictions` | Toggles posting/chat/purchase/withdrawal restrictions |
| `updateUserStatus` | Changes accountStatus, userType, sellerStatus, vetStatus |
| `deleteUserAccount` | Self-deletes user from all collections + Auth |

#### Provider Applications (`providerApplications.js`)
| Function | Purpose |
|---|---|
| `submitProviderApplication` | User submits application to become a provider |
| `reviewProviderApplication` | Staff approves/rejects application; creates `providerProfiles` on approval |
| `updateProviderProfileStatus` | Suspends/pauses/disables/warns/reactivates provider with enforcement options |

#### Transactions & Delivery (`transactions.js`)
| Function | Purpose |
|---|---|
| `processTransaction` | POS sale with inventory deduction, stock movement, income recording |
| `adminTransitionOrderStatus` | Admin-only order status transitions (approve, processing, ready, shipped, delivered, cancel) |
| `deliveryTransitionOrderStatus` | Delivery agent transitions (accept, pickup, in_transit, deliver, collect_payment, complete, cancel) |
| `adminResolvePaymentRequest` | Admin resolves order payment requests (approve, reject, complete, refund) |

#### Payments / QIB (`qibPayment.js`)
| Function | Purpose |
|---|---|
| `updateCommercePaymentSettings` | Staff sets delivery fee, toggles payment methods |
| `createPendingOrder` | Customer creates pending order from cart items + shipping address |
| `createQibSession` | Creates QIB payment session with server-side secret |
| `verifyQibPayment` | Verifies QIB payment response, updates order status |
| `prepareOrderForRetry` | Resets failed order to pending for retry |
| `cancelOrderCheckout` | Customer cancels checkout |

#### Inventory & Products (`validateInventoryChange.js`, `getProducts.js`)
| Function | Purpose |
|---|---|
| `validateInventoryChange` | Create/update/delete/adjust/intake products in `petAccessories`. Enforces SKU uniqueness, live pet quantity rules. |
| `getProducts` | Fetches products by `petType` + optional `category` from `petAccessories` (hot path: 80 concurrency) |

#### Audit & Logging (`auditLogger.js`)
| Function | Purpose |
|---|---|
| `auditLogger` | Generic client-side audit log writer |
| `expensesAuditTrigger` | Auto-audits `expenses` collection changes (Firestore trigger) |
| `petAccessoriesAuditTrigger` | Auto-audits `petAccessories` collection changes |
| `transactionsAuditTrigger` | Auto-audits `transactions` collection changes |
| `usersAuditTrigger` | Auto-audits `UsersCol` collection changes |

#### Notifications (`notifications.js`)
| Function | Purpose |
|---|---|
| `sendChatNotification` | Push + inbox on chat message writes (Firestore trigger) |
| `sendConsoleNotification` | Staff-targeted console notifications |
| `notifyOrderStatusChanged` | Customer push notifications on order status changes |
| `notifyAdminOrderCreated` | Staff push + inbox on new orders |
| `notifySupportThreadCreated` | Admin notifications for new support threads |
| `notifySupportMessageCreated` | Admin notifications for new support messages |
| `notifyChatReportCreated` | Admin notifications for chat reports |

#### Reports & Reconciliation
| Function | Purpose |
|---|---|
| `generateDailyReport` | Daily sales/expenses/stock summary in `reports/daily_YYYY-MM-DD` |
| `nightlyReportScheduler` | Scheduled (23:58 Africa/Cairo) auto-generator |
| `reconciliationCron` | Every 30 min: expires stale QIB sessions, cancels abandoned orders >24h, restocks inventory |

#### Other
| Function | Purpose |
|---|---|
| `moderateUploadedImage` | Cloud Vision SafeSearch on uploads, flags NSFW |
| `serviceReviewsAggregateTrigger` | Recomputes review aggregates on `serviceOffers` docs |

---

### 5.2 Firestore Security Rules

Security uses a **two-tier authorization model**:

**Tier 1 — Staff Authorization:**
- Reads `staff_users/{uid}` for: status, role, permissions array, scope map
- Super admins and owners bypass all checks
- Custom roles inherit from role templates in `staff_roles/{roleId}`

**Tier 2 — User Feature Flags:**
- Reads `UsersCol/{uid}.features` for boolean flags
- Maps permission keys to feature flags (e.g., `ManageVet` → `canVet`)
- Staff members always bypass feature flag checks

**Collection-specific protections:**

| Collection | Read | Write |
|---|---|---|
| `petAccessories` | Public | Owner must have `canPharmacy` (for medicines) or `canSellAccessories` (for accessories) + match `ownerID`. Staff can write. |
| `serviceOffers` | Public | Owner must have `canOfferServices` + match `serviceOwnerID`. Subscription fields immutable by owner. |
| `veterinarians` | Public | Owner must have `canVet` + match `userID`. Staff can write. |
| `providerPlans` | Signed-in users | Staff with `providers.manage` only |
| `providerApplications` | Staff + own application | Client writes blocked (Cloud Functions only) |
| `providerProfiles` | Staff + own profile | Client writes blocked (Cloud Functions only) |
| `UsersCol` | Signed-in (get), staff (list) | Owner can update (admin flags immutable), staff can update full profile |
| `Orders` | Owner + assigned delivery + payment managers | State-machine gated transitions |

---

### 5.3 Storage Rules

| Path | Write Requirement |
|---|---|
| `petAccessories/**` | `canPharmacy` OR `canSellAccessories` OR staff |
| `serviceOffers/**` | `canOfferServices` OR staff |
| `vets/**` | `canVet` OR staff |
| `medicines/**` | Same as `petAccessories` |
| `services/**` | Same as `serviceOffers` |
| `uploads/users/{uid}/profile/**` | Owner only, max 10MB, JPEG/WebP only |
| `banners/**`, `LottieAnimations/**` | SuperAdmin/Owner only |
| `Chats/**` | Any signed-in user |
| **Public read (no auth):** `vets/`, `medicines/`, `banners/`, `LottieAnimations/`, `services/` |

---

### 5.4 Audit Logging

Every Cloud Function mutation follows the chain:
```
validateAuth() → requirePermission("permission.key") → validate input → business logic → writeAuditLog({...})
```

**Automated triggers:** `petAccessories`, `expenses`, `transactions`, `UsersCol` document writes auto-audit.

**Audit log structure:** `auditLogs/{id}` with userId, action, targetCollection, targetId, before/after snapshots, metadata, timestamp.

---

### 5.5 Staff Authorization System

**Staff roles (7 built-in):**

| Role | Permissions |
|---|---|
| `super_admin` / `owner` | ALL permissions |
| `operations_manager` | ALL except `staff.manage`, `audit.view` |
| `inventory_manager` | `stock.*`, `categories.*`, `reports.view`, `notifications.view` |
| `payments_manager` | `dashboard`, `payments.*`, `accounting.*`, `reports.*`, `pos.*`, `notifications.view` |
| `support_agent` | `dashboard`, `support.*`, `users.view`, `users.features.view`, `users.restrictions.view`, `notifications.view` |
| `viewer` | All `*.view` permissions only |

**Permission catalog:** 37 permissions across 19 modules (dashboard, staff, users, stock, listings, payments, pos, branches, agents, support, services, providers, settings, notifications, accounting, reports, audit, moderation, banners, categories, veterinarians).

---

## 6. How the Pro App Connects to the Consumer Apps

### 6.1 Consumer iOS App Integration

**Shared Firestore Collections (read by consumers):**

| Collection | What Consumers See |
|---|---|
| `veterinarians` | Vet profiles with subscription tier badges (if active) |
| `serviceOffers` | Service listings with ratings and reviews |
| `petAccessories` | Products, accessories, food, live pets, medicines (filtered by `showInAppMarket`) |
| `Orders` | Customer's own orders with delivery tracking |

**How consumers discover providers:**

1. **Home Services Section** — `PPHomeServicesCell` shows Vets, Food, MainService quick actions
2. **Premium Care Section** — `PPHomePremiumCareCell` opens `PPPetCareViewController` (Medicines + Veterinarians tabs)
3. **Search** — `PPSearchViewController` with multifield search across all collections
4. **Nova AI** — `PPNovaChatViewController` dynamically fetches and displays providers based on user questions

**How consumers purchase from providers:**

1. Browse → Add to Cart (`CartManager.addItem:`) → validates stock from `petAccessories`
2. Cart syncs to `UsersCol/{uid}/cartItems` subcollection in real-time
3. Checkout via `PPCheckoutCoordinator`:
   - Validates inventory (`PPOrderManager.validateInventoryForItems:`)
   - Creates pending order in `Orders` collection
   - QIB online payment or Cash on Delivery
   - Clears cart on success
4. Post-purchase: order tracking via `PPHomeOrderStatusCell`, `OrderDetailsViewController`, support requests

**Important:** There is NO in-app subscription purchase in the consumer app. Subscriptions are managed entirely through the Pro app and Console admin. The consumer app only reads subscription state to display badges.

---

### 6.2 Consumer Android App Integration

The Android app mirrors the iOS feature set:

**Provider Discovery:**
- `HomePremiumCareSection` → `PurePetsPetCareActivity` → `PetCareScreen` (medicines + vets tabs)
- `PPDataSection.SERVICES`, `PPDataSection.VETS`, `PPDataSection.PHARMACY` in XPureDataScreen
- Home quick actions: Pharmacy, Nearest Vet, Request Service

**Commerce Flow:**
- `CommerceCartState` for cart management
- `CommerceRepository` for Firestore queries
- `PPCheckoutPaymentScreen` for checkout with QIB/cash
- `PPOrder` model with full delivery status timeline

**Shared Models:**
- `PPVetModel` — same vet fields, subscription tiers
- `PPPetService` — service listings
- `PPPetMedicine` / `PPPetAccessory` — products from `petAccessories` collection
- `PPOrder` — full order with delivery status

---

### 6.3 Shared Firestore Collections

| Collection | Pro App (Write) | Consumer App (Read/Write) | Console Admin (Write) |
|---|---|---|---|
| `UsersCol` | Read own | Read own, write own profile | Read/write all |
| `veterinarians` | CRUD (owner) | Read all | CRUD all |
| `serviceOffers` | CRUD (owner) | Read all | CRUD all |
| `petAccessories` | CRUD (owner) | Read all | CRUD all |
| `Orders` | Read assigned | Create (checkout) | Manage all |
| `providerApplications` | Submit | — | Review |
| `providerPlans` | Read | — | CRUD |
| `providerProfiles` | Read own | — | Manage all |
| `cartItems` (UsersCol sub) | — | Read/write own | — |
| `favoritesServices` (UsersCol sub) | — | Read/write own | — |
| `favoritesVets` (UsersCol sub) | — | Read/write own | — |

---

## 7. Subscription System — Complete Details

### 7.1 User-Level Subscriptions

**Storage:** `UsersCol/{uid}.subscription` object

**Fields:**
```json
{
  "plan": "free" | "basic" | "premium" | "business" | "production" | "service_provider",
  "status": "active" | "inactive" | "past_due" | "canceled" | "trial" | "blocked",
  "source": "manual" | "app_store" | "play_store" | "internal",
  "startedAt": Timestamp,
  "expiresAt": Timestamp
}
```

**Impact:**
- `status == "blocked"` → Pro app access denied entirely
- `status == "active"` + Pro features → allowed into Pro dashboard
- No active Pro features → routed to provider application flow

**Management:**
- Cloud Function: `updateUserSubscription` (requires `users.subscriptions.manage` permission)
- Console: `ProviderFeatureAccess` page

---

### 7.2 Provider Plans

**Collection:** `providerPlans`

**Structure:**
```json
{
  "planID": "string",
  "providerType": "delivery_subscription" | "service" | "pharmacy" | "vet",
  "name": { "en": "...", "ar": "..." },
  "description": { "en": "...", "ar": "..." },
  "costType": "price" | "percentage",
  "costValue": 50,
  "currency": "QAR",
  "billingInterval": "monthly" | "yearly" | "one_time",
  "percentageBasis": "item" | "product" | "service" | "medicine" | "subscription" | "custom",
  "trialDays": 14,
  "rank": 1,
  "recommended": true,
  "status": "active" | "inactive",
  "features": ["feature1", "feature2"],
  "requiredDocuments": [
    { "name": { "en": "ID", "ar": "الهوية" }, "description": { "en": "...", "ar": "..." } }
  ]
}
```

**How plans are used:**
- During provider application, the user selects a plan
- The plan snapshot is saved with the application and later the provider profile
- Plans are read-only from client SDK (Cloud Functions manage writes)
- Changing a plan after approval requires staff intervention

---

### 7.3 Vet Subscriptions

**Storage:** `veterinarians/{vetID}` document fields

**Tiers:**
```
Free (0)   — Basic profile listing
Basic (1)  — Enhanced profile, can post services
Premium (2) — Full profile, can post services + medicines, priority listing
```

**Fields on vet document:**
```json
{
  "subscriptionTier": 0,
  "subscriptionActive": false,
  "subscriptionStartDate": Timestamp,
  "subscriptionEndDate": Timestamp,
  "canEditProfile": true,
  "canPostServices": false,
  "canPostMedicines": false
}
```

**Management flow:**
1. Pro app: `PPVetSubscriptionViewController` writes directly to vet document
2. Console: `Veterinarians` page has subscription management modal with plan selector, tier selector, duration quick-buttons (1/3/6/12 months)
3. Consumer app: Reads `subscriptionActive && subscriptionTier > 0` to display tier badge on vet viewer

**Permission gate:**
- Firestore rules allow vet owner to write their own document if `canVet` feature is enabled
- Subscription fields are writable by both the vet owner and staff

---

### 7.4 Service Subscriptions

**Storage:** `serviceOffers/{serviceID}` document fields

**Fields:**
```json
{
  "subscriptionType": "...",
  "subscriptionPlan": "free" | "pro" | "...",
  "subscriptionStatus": "active" | "inactive",
  "subscriptionActive": true,
  "subscriptionStartDate": Timestamp,
  "subscriptionEndDate": Timestamp
}
```

**Key distinction:** Service subscription fields are **immutable by the owner** in Firestore rules. Only staff can modify them. The Pro app's service subscription VC is read-only or triggers Cloud Functions.

---

### 7.5 Delivery Subscriptions

**Storage:** `providerProfiles/{uid}_delivery_subscription` (provider profile) + `UsersCol/{uid}.features.canDelivery`

**Delivery partners don't have tiered subscriptions** in the same way vets do. Instead, they:
1. Apply via provider onboarding
2. Get approved → `canDelivery` feature enabled on UsersCol
3. Are assigned to orders through the delivery dashboard
4. Earn per-delivery (managed outside the app)

The `delivery_subscription` provider type is tracked in `providerProfiles` with its linked plan from `providerPlans`.

---

## 8. Provider Item Lifecycle: Add → Deliver

### 8.1 Pharmacy Provider: Medicine Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHARMACY PROVIDER ADDS MEDICINE                                     │
│                                                                      │
│  1. Opens Pro app → Pharmacy Section                                 │
│  2. PPPharmacyMedicineEditorViewController:                          │
│     - Fills form: title, description, price, stock, animalTypes      │
│     - Selects photo via image picker                                 │
│  3. Save → PPVetManager writes to:                                   │
│     ├─ petAccessories/{autoID} (accessKindType=4, showInAppMarket=true)│
│     └─ Storage: petAccessories/{id}.jpg                              │
│  4. Storage trigger: moderateUploadedImage (SafeSearch)              │
│  5. Firestore trigger: petAccessoriesAuditTrigger (audit log)        │
│                                                                      │
│  ─────────────── MEDICINE IS NOW VISIBLE ───────────────             │
│                                                                      │
│  CONSUMER DISCOVERS:                                                 │
│  6. iOS: PetCareViewController → Medicines tab                       │
│     queries petAccessories where accessKindType==4                   │
│  7. Android: PetCareScreen → Medicines tab                           │
│     queries petAccessories where kindType==4                         │
│                                                                      │
│  CONSUMER PURCHASES:                                                 │
│  8. Views medicine → Add to Cart (CartManager)                      │
│     Validates stock quantity from petAccessories doc                 │
│  9. Cart syncs to UsersCol/{uid}/cartItems in Firestore              │
│  10. Checkout via PPCheckoutCoordinator:                             │
│      - Inventory validation (PPOrderManager.validateInventoryForItems)│
│      - Creates Orders/{orderId} with status="pending"               │
│      - Items[] carry itemID referencing petAccessories doc           │
│      - Payment: QIB (online) or Cash (COD)                          │
│  11. Order moves through status pipeline:                            │
│      pending → paid → processing → ready → shipped → delivered      │
│                                                                      │
│  DELIVERY PARTNER FULFILLS:                                          │
│  12. Delivery partner sees order in PPDeliveryDashboard              │
│  13. Accepts → Pickup → In Transit → Delivered                     │
│      Each transition via deliveryTransitionOrderStatus Cloud Function│
│  14. Cash orders: collect_payment → confirm_payment → completed     │
│                                                                      │
│  POST-DELIVERY:                                                      │
│  15. Consumer tracks via OrderDetails / HomeOrderStatusCell          │
│  16. Support requests if needed (Orders/{id}/requests subcollection) │
│  17. Inventory auto-decremented during createPendingOrder            │
│  18. Firebase Cloud Messaging pushes at each status change           │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Service Provider: Service Offer Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│  SERVICE PROVIDER CREATES SERVICE                                    │
│                                                                      │
│  1. Opens Pro app → Service Section                                 │
│  2. PPAddEditServiceViewController:                                  │
│     - Fills form: title, description, price, category, type          │
│     - Uploads image via FUManager                                    │
│  3. Save → PPServiceManager writes to serviceOffers/{autoID}:        │
│     - serviceOwnerID = current user's UID                           │
│     - isAvailable = true                                            │
│     - Subscription fields set by admin (read-only for owner)        │
│  4. Image upload to Storage: serviceOffers/{id}.jpg                  │
│                                                                      │
│  ─────────────── SERVICE IS NOW VISIBLE ───────────────              │
│                                                                      │
│  CONSUMER DISCOVERS:                                                 │
│  5. iOS: ServicesManager listens to serviceOffers collection         │
│     Filters by petMainKindID, sorts by availableDate                │
│  6. Android: CommerceRepository fetches serviceOffers                │
│  7. Nova AI can recommend services based on user questions           │
│                                                                      │
│  CONSUMER CONTACTS:                                                  │
│  8. View service detail → Contact via phone/WhatsApp/chat            │
│  9. Services are NOT added to cart (contact-based, not e-commerce)   │
│                                                                      │
│  REVIEW SYSTEM:                                                      │
│  10. Consumer writes review to:                                      │
│      serviceOffers/{id}/reviews/{reviewerUID}                       │
│  11. Firestore trigger recomputes aggregates on parent doc:          │
│      serviceReviewsAggregateTrigger →                                │
│      updates rating, reviewCount, averageRating, top 5 reviews      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.3 Accessory Seller: Pet Accessory Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│  SELLER ADDS ACCESSORY (can be done from Pro or Console)             │
│                                                                      │
│  1. From Pro app or Console → create item in petAccessories          │
│  2. validateInventoryChange Cloud Function (action="create"):        │
│     - Validates SKU uniqueness                                      │
│     - Enforces live pet quantity rules (max 1 for live pets)        │
│     - Records stock movement in stockMovements collection            │
│  3. Item fields:                                                     │
│     - accessKindType: 1=Accessory, 2=Food, 3=LivePet, 4=Medicine    │
│     - ownerID: seller's UID                                         │
│     - showInAppMarket: true (must be true for consumer visibility)   │
│     - quantity: stock count                                         │
│     - isBlocked, isDeleted, isDisabled: false                       │
│     - expiryDate: optional shelf-life                                │
│                                                                      │
│  ─────────────── ACCESSORY IS NOW VISIBLE ───────────────            │
│                                                                      │
│  CONSUMER PURCHASES (same as medicine flow Section 8.1):             │
│  4. PetAccessoryManager fetches items filtered by:                   │
│     - accessKindType, petMainCategoryID, petSubCategoryID            │
│     - showInAppMarket == true                                       │
│     - Not blocked/deleted/disabled/expired                          │
│  5. Add to cart → CartManager validates stock                       │
│  6. Checkout → createPendingOrder → QIB/Cash payment                │
│  7. Inventory decremented during order creation                     │
│                                                                      │
│  DELIVERY FULFILLMENT (same as Section 8.1):                         │
│  8. Order visible to delivery partners via PPDeliveryDashboard       │
│  9. Delivery partner accepts and delivers                           │
│  10. Status transitions via Cloud Functions                          │
│  11. Push notifications to customer at each stage                   │
│                                                                      │
│  RECONCILIATION:                                                     │
│  12. reconciliationCron (every 30 min):                              │
│      - Cancels orders abandoned > 24 hours                          │
│      - Restocks inventory for cancelled orders                      │
│  13. nightlyReportScheduler: generates daily sales report            │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.4 Delivery Provider: Order Fulfillment Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│  ORDER ENTERS DELIVERY PIPELINE                                      │
│                                                                      │
│  1. Order created by consumer checkout (status="pending")            │
│  2. Admin approves via adminTransitionOrderStatus("order_approve")   │
│     status → "processing"                                            │
│  3. Items prepared, status → "ready_to_ship"                        │
│  4. Admin marks ready: status → "DELIVERY_REQUESTED"                 │
│                                                                      │
│  ── ORDER NOW VISIBLE TO DELIVERY PARTNERS ──                        │
│                                                                      │
│  DELIVERY PARTNER (Pro App):                                         │
│  5. Sees order in PPDeliveryDashboard (Ready / Pending Pickup tab)   │
│  6. Accepts: deliveryTransitionOrderStatus("accept")                 │
│     - Order assigned to delivery partner's UID                       │
│     - status → "AWAITING_HANDOVER"                                   │
│     - Customer notified: "Delivery Partner Assigned"                 │
│  7. Pickup from seller: deliveryTransitionOrderStatus("pickup")      │
│     - status → "PICKED_UP"                                           │
│  8. Start delivery: deliveryTransitionOrderStatus("in_transit")      │
│     - status → "IN_TRANSIT"                                          │
│     - Customer notified: "On the Way"                                │
│  9. Deliver to customer: deliveryTransitionOrderStatus("deliver")    │
│     - status → "DELIVERED" (online payment)                          │
│     - status → "PAYMENT_PENDING" (cash order)                        │
│     - Customer notified: "Order Delivered"                           │
│  10a. [Online]: deliveryTransitionOrderStatus("complete")            │
│       status → "COMPLETED"                                           │
│  10b. [Cash]: deliveryTransitionOrderStatus("collect_payment")       │
│       → "PAYMENT_CONFIRMED" → "complete" → "COMPLETED"               │
│                                                                      │
│  ERROR HANDLING:                                                     │
│  - Cancel: → "DELIVERY_CANCELLED" (returns to stock)                 │
│  - Fail: → "DELIVERY_FAILED" (can be reassigned)                    │
│  - Return: → "RETURNED_TO_STORE"                                     │
│                                                                      │
│  NOTIFICATIONS:                                                      │
│  buildDeliveryNotificationPlan() sends push at each transition       │
│  to customer, driver, and admin audiences                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Product/Inventory Storage

### 9.1 Frontend (Pro App + Consumer App)

**Pro App Models:**

| Model | File | Firestore Source |
|---|---|---|
| `PetAccessory` | `BasicClasses/PetAccessory.h/.m` | `petAccessories` collection |
| `PPVetMedicineModel` | `VeterinarianSection/` | `petAccessories` (accessKindType=4) |
| `ItemModel` | `BasicClasses/ItemModel.h/.m` | Generic XLForm-compatible item |
| `MainKindsModel` | `BasicClasses/MainKindsModel.h/.m` | `MainKindsCollection` |
| `SubKindModel` | `BasicClasses/SubKindModel.h/.m` | Nested under MainKinds |

**PetAccessory Fields (complete):**
```
accessoryID, userID, userName, userPhone, userProfileImage
title, price, currency, descriptionText
categoryID, categoryName
condition (New/Used), accessType (Accessory/Pet)
stockQuantity, isAvailable, isSoldOut
weight, shipmentWeight
images[] (URLs), blurHash, imageItems[] (PetImageItem)
createdAt, updatedAt
ownerID, petMainCategoryID, petSubCategoryID
accessKindType (1=Accessory, 2=Food, 3=LivePet, 4=Medicine)
showInAppMarket, isBlocked, isDeleted, isDisabled
discountPercent, discountAmount, finalPrice
isNew, hasOffer, expiryDate
```

**Consumer App (iOS) Models:**
- `PetAccessory` — same model, shared across both apps
- `CartItem` — cart item with quantity, line totals, discount
- `PPOrder` — full order with delivery timeline

**Consumer App (Android) Models:**
- `PPPetAccessory` — same structure, Kotlin data class
- `PPPetMedicine` — wraps `petAccessories` with kindType=4
- `PPOrder` — full order with delivery statuses
- `PPCartCalculator` — centralized pricing (subtotal, discount, shipping, total)

### 9.2 Backend (Cloud Functions + Firestore)

**Inventory Management:**
- `validateInventoryChange` — centralized create/update/delete/adjust/intake
  - Enforces SKU uniqueness
  - Blocks duplicates by itemID
  - Live pets: max quantity = 1
  - Records stock movement in `stockMovements` collection
  - Writes audit log

**Order Validation:**
- `createPendingOrder` — validates stock before creating order
  - Checks each requested quantity against current stock
  - Deducts inventory atomically
  - Creates order with line items

**Reconciliation:**
- `reconciliationCron` (every 30 min):
  - Expires stale QIB sessions
  - Cancels orders abandoned > 24 hours
  - Restocks inventory for cancelled/abandoned orders

**Firestore Indexes for Products:**
```
petAccessories composite indexes:
  - showInAppMarket ASC + accessKindType ASC + petMainCategoryID ASC + createdAt DESC
  - showInAppMarket ASC + accessKindType ASC + petSubCategoryID ASC + createdAt DESC
  - showInAppMarket ASC + hasOffer ASC + createdAt DESC
  (12 total indexes for this collection)
```

---

## 10. Console Admin: Pro Management Dashboard

The Pure Pets Console (React 19, Vite 7, Tailwind 4, TypeScript) provides the administrative interface for Pro management:

### Provider Management Pages

| Page | Route | What It Does |
|---|---|---|
| **Provider Applications** | `/providers/applications` | Review queue: approve/reject provider applications, document upload, real-time subscription to `providerApplications` |
| **Provider Feature Access** | `/providers/access` | User-level Pro feature toggles: enable/disable `canOfferServices`, `canDelivery`, `canPharmacy`, `canVet` per user; manage account status; link feature plans |
| **Provider Plans** | `/providers/plans` | Plan CRUD: create/edit/delete plans with billing model, features, required documents, trial days |
| **Provider Subscriptions** | `/providers/subscriptions` | Active provider status enforcement: suspend/pause/disable/warn/reactivate with scheduled enforcement, notifications, reason codes, audit trail |

### Other Pro-Related Pages

| Page | Route | What It Does |
|---|---|---|
| **Veterinarians** | `/veterinarians` | Vet CRUD + subscription tier management + logo upload |
| **Services** | `/services` | Service offer moderation + subscription metadata management |

### Console Architecture Rules
- Dynamic Firebase imports only (never static npm Firebase)
- Session via `(window as any).__PUREPETS_SESSION__?.uid`
- Never use `writeBatch` — individual `updateDoc` calls
- Bilingual copy: `{ en: {...}, ar: {...} }` object maps
- Permission-gated routes via `ProtectedRoute` + `StaffRoute`

---

## 11. Complete Firestore Collection Map

| Collection | Purpose | Written By | Read By |
|---|---|---|---|
| `UsersCol` | User profiles, features, subscriptions | User (own), Staff (all), Cloud Functions | Everyone (own), Staff (all) |
| `UsersCol/{uid}/features` | Feature flags (Pro access) | Cloud Functions (`updateUserFeatures`) | Auth rules, Storage rules, Clients |
| `UsersCol/{uid}/subscription` | Subscription plan/status | Cloud Functions (`updateUserSubscription`) | Pro app (access gate) |
| `UsersCol/{uid}/cartItems` | Shopping cart | Consumer apps (via CartManager) | Consumer apps |
| `UsersCol/{uid}/favoritesServices` | Favorited services | Consumer apps | Consumer apps |
| `UsersCol/{uid}/favoritesVets` | Favorited vets | Consumer apps | Consumer apps |
| `UsersCol/{uid}/permissions` | Canonical permissions | Staff, Cloud Functions | Auth rules, Clients |
| `UsersCol/{uid}/PermisstionsCol` | Legacy permissions (typo intentional) | Frozen (read-only) | Migration audit |
| `PublicUserProfiles` | Public-facing user profiles | System | Public |
| `staff_users` | Staff authorization (source of truth) | Cloud Functions | Auth rules, Pro app, Console |
| `staff_roles` | Staff role templates | Staff with manage permission | System |
| `providerApplications` | Provider onboarding applications | Cloud Functions (`submitProviderApplication`) | Staff, Applicant |
| `providerPlans` | Provider plan definitions | Console (staff only) | Signed-in users |
| `providerProfiles` | Active provider profiles | Cloud Functions (`reviewProviderApplication`) | Staff, Own profile |
| `veterinarians` | Vet profiles | Pro app (owner), Console (staff) | Public |
| `veterinarians/{id}/medicines` | Vet medicine inventory | Pro app (owner), Console | Public |
| `serviceOffers` | Service listings | Pro app (owner), Console | Public |
| `serviceOffers/{id}/reviews` | Service reviews | Consumer apps | Public |
| `petAccessories` | **ONLY** stock/inventory collection | Pro app, Console, Cloud Functions | Public |
| `stockMovements` | Inventory change log | Cloud Functions | Staff |
| `Orders` | Customer orders | Consumer apps (create), Pro app (delivery), Console (manage) | Owner, delivery, staff |
| `Orders/{id}/requests` | Order support requests | Consumer apps | Owner, staff |
| `Orders/{id}/events` | Order timeline events | System | Owner, staff |
| `MainKindsCollection` | Pet taxonomy (dogs, cats, etc.) | Console | All apps |
| `CommerceConfig` | Payment settings, delivery fees | Console (staff) | Consumer apps |
| `Chats` | Chat threads | Consumer apps, Pro app | Thread members |
| `agents` | Sales agents | Pro app, Console | Staff |
| `branches` | Physical branch locations | Console | Pro app, Consumer apps |
| `auditLogs` | Central audit trail | Cloud Functions (auto) | Staff with audit.view |
| `AdminAuditLogs` | Admin-specific audit logs | Cloud Functions | Staff (area-specific) |
| `reports` | Daily reports | Cloud Functions (scheduled) | Staff |
| `transactions` | POS sales transactions | Pro app, Console | Staff |
| `expenses` | Expense records | Console | Staff |
| `AppConfigCol` | App configuration (home sections, etc.) | Console | Consumer apps |

---

## 12. Permission & Role Matrix

### User Roles (9 levels)

| Role | Value | Description |
|---|---|---|
| `User` | 0 | Regular consumer |
| `Breeder` | 1 | Pet breeder |
| `Owner` | 2 | Platform owner (full access) |
| `Vet` | 3 | Veterinarian provider |
| `Moderator` | 4 | Content moderator |
| `Admin` | 5 | General admin |
| `StoreManager` | 6 | Store/inventory manager |
| `FoodManager` | 7 | Food category manager |
| `SuperAdmin` | 8 | Full platform control |

### Provider Feature Flags (UsersCol.features)

| Flag | Pro App Access | What It Unlocks |
|---|---|---|
| `canOfferServices` | Service Provider Dashboard | Create/manage services, upload service images |
| `canDelivery` | Delivery Dashboard | View/accept/deliver orders |
| `canPharmacy` | Pharmacy Dashboard | Create/manage medicines, upload medicine images |
| `canVet` | Vet Dashboard | Create vet profile, manage subscription, post medicines |
| `canSellAccessories` | (built-in) | Post accessories, food, live pets for sale |
| `canPostPetAds` | (built-in) | Post pet ads |
| `canPostAdoption` | (built-in) | Post adoption listings |
| `canUseStories` | (built-in) | Post stories |
| `canUseChat` | (built-in) | Use chat feature |
| `canAccessPremiumMarketplace` | (built-in) | Access premium marketplace features |

### Staff Permission Modules (37 permissions across 19 modules)

**Provider-related:**
- `providers.view` — View provider applications
- `providers.manage` — Manage provider applications (approve/reject/upload)
- `veterinarians.view` — View veterinarians
- `veterinarians.manage` — Manage veterinarians (CRUD + subscriptions)
- `services.view` — View services
- `services.manage` — Manage services (CRUD + moderation)
- `users.features.view` — View user feature flags
- `users.features.manage` — Manage user feature flags
- `users.subscriptions.view` — View user subscriptions
- `users.subscriptions.manage` — Manage user subscriptions
- `users.manage` — Manage user accounts
- `users.view` — View user profiles

**Delivery-related:**
- `payments.manage` — Manage payments and orders
- `payments.view` — View payments

**Stock-related:**
- `stock.manage` — Manage inventory
- `stock.view` — View inventory
- `categories.manage` — Manage product categories
- `categories.view` — View product categories
- `listings.manage` — Manage marketplace listings
- `listings.view` — View marketplace listings

---

## Appendix: Tech Stack Summary

| Component | Technology |
|---|---|
| **Pro iOS App** | Objective-C + Swift, UIKit, CocoaPods, XLForm, SDWebImage, Lottie, Firebase SDK, QIBPayment.framework |
| **Consumer iOS App** | Objective-C + Swift, UIKit, CocoaPods, Firebase SDK, QIBPayment.framework |
| **Consumer Android App** | Kotlin, Jetpack Compose, Material 3, Coil, Firebase SDK |
| **Console Web Admin** | React 19, Vite 7, Tailwind 4, TypeScript, Firebase Web SDK (dynamic imports) |
| **Backend** | Node.js 22, Cloud Functions (CommonJS), Cloud Firestore, Firebase Auth, Cloud Storage, FCM, App Check |
| **AI Agent (Nova)** | Genkit on Cloud Run, Gemini API |
| **Payment Gateway** | QIB (Qatar Islamic Bank) native SDK |
| **Desktop Wrapper** | Tauri 2 (macOS + Windows) |
