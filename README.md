# Pure Pets Pro

> **Provider/professional iOS app for the Pure Pets ecosystem** — XLForm dashboard, delivery/vet/pharmacy/service management, staff authentication

![Status](https://img.shields.io/badge/status-development-yellow)
![iOS](https://img.shields.io/badge/iOS-15.0+-blue)
![ObjC](https://img.shields.io/badge/ObjC-~98%25-orange)
![Swift](https://img.shields.io/badge/Swift-~2%25-red)
![Firebase](https://img.shields.io/badge/Firebase-pure--pets--49199-orange)
![Bundle](https://img.shields.io/badge/bundle-Ali--Ahmed.PurePetsPro-lightgrey)
![License](https://img.shields.io/badge/license-Proprietary-inactive)

---

## Overview

Pure Pets Pro is the provider-facing iOS application within the Pure Pets ecosystem. It serves veterinarians, pharmacies, delivery companies, service providers (training/grooming), and internal staff with tools for managing orders, fulfillment, products, listings, and professional profiles. Built almost entirely in Objective-C with a UIKit code-only architecture and an XLForm-based dashboard hub.

---

## Features

- **Provider dashboard**: XLForm-based navigation hub with role-gated feature access
- **Delivery management**: Real-time order listener, Cloud Function transitions, status timeline, location visibility
- **Delivery company management**: Company profiles, member management, event handling, Cloud Function bridge
- **Veterinarian management**: Company/personal profiles, Free/Basic/Premium subscription tiers
- **Pharmacy management**: Medicine catalog CRUD with image support
- **Service management**: Training/grooming service offers with subscription tiers
- **Fulfillment management**: Fulfillment order listing and detail views
- **Provider marketplace**: Market item CRUD with branch management
- **Provider onboarding**: Full application flow (plans, drafts, status tracking)
- **Pet adoption management**: Adoptable pet listings CRUD
- **Staff authentication**: 3-method sign-in (Phone OTP, Apple ID, Google Sign-In)
- **Biometric unlock**: Face ID / Touch ID via LAContext + Keychain
- **Role-based permissions**: UserRole 0–8 enum with bitmask permissions
- **Notifications**: In-app notification inbox, push token management, audience targeting
- **Dark mode**: System/Light/Dark theme toggle
- **RTL support**: Full Arabic (RTL) + English (LTR) bilingual
- **App Check**: App Attest → DeviceCheck → Debug resilient chain

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SceneDelegate (AppRoot enum)                  │
│  Splash → Login → Dashboard / ProviderStatus                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │  UINavigationController  │
              │  (single stack, no tabs) │
              └────────────┬────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                  ▼
  AdminDashboard    Domain Screens      Modals (Bottom
  (XLForm hub)      (pushed onto           Sheets,
                     nav stack)          Popups, HUD)
```

### Singleton-Manager Architecture

Each domain has a dedicated singleton manager that owns Firebase listeners and business logic:

```
AppManager          — Global singleton, Firebase setup, user session, MainKindsArray
UserManager         — Current user model, profile, Refs
FUManager           — Firebase Auth lifecycle, AuthStateDidChangeListener
RPManager           — Real-time permission listener
PPStaffAuth         — Staff authorization (40+ permission keys)
PPBiometric         — Face ID / Touch ID
PPDeliveryManager   — Real-time Orders listener, Cloud Function transitions
PPDeliveryCompanyService — Delivery company Cloud Function bridge
PPVetManager        — Veterinarian subscription and CRUD
PPServiceManager    — Service offer subscription and CRUD
PPFulfillmentManager — Fulfillment order management
PPProviderMarketplaceManager — Marketplace items and branches
PPProviderApplicationManager — Provider onboarding applications
PPAdoptPetManager   — Adoption pet listings
PPNotificationsManager — Push tokens, audience targeting
NotificationManager — In-app notification inbox (CRUD)
MainKindsArrayManager — Shared MainKindsArray (pet categories)
CitiesManager       — Address/city/state/country models
```

### Navigation Flow

```
SceneDelegate.pp_applyAdminRoutingForAuthUser
    │
    ├── No user → AppRootSplash → AppRootLogin
    └── User exists
         ├── PPUserDocAllowsProAccess = NO → AppRootProviderStatus
         └── Allowed
              ├── Delivery company preflight → company dashboard
              └── Standard → AdminDashboardViewController (XLForm)
```

---

## Folder Structure

```
Pure Pets Pro/
├── PurePetsPro/
│   ├── AppDelegate.h/m
│   ├── SceneDelegate.h/m               # 1204 lines — auth routing, app root, foreground lock
│   ├── AppManager.h/m                  # Global singleton
│   ├── main.m
│   ├── PrefixHeader.pch                # 524 lines — macros, shortcuts, colors, fonts
│   ├── Info.plist
│   ├── PurePetsPro.entitlements
│   ├── GoogleService-Info.plist
│   ├── PurePetsPro-Bridging-Header.h
│   ├── PPFirebaseCompat.h
│   ├── AdminCore/
│   │   ├── Auth/
│   │   │   ├── AdminLoginViewController.h/m    # Phone OTP, Apple ID, Google
│   │   │   ├── PPProLoginSurfaceController.swift  # SwiftUI login surface
│   │   │   └── ...
│   │   ├── Security/
│   │   │   ├── FUManager.h/m             # Firebase Auth lifecycle
│   │   │   ├── PPRolePermission.h/m      # UserRole 0-8, permission bitmask
│   │   │   ├── RPManager.h/m             # Permission listener
│   │   │   ├── PPStaffAuth.h/m           # Staff authorization (40+ keys)
│   │   │   └── PPBiometric.h/m           # Face ID / Touch ID
│   │   ├── Models/
│   │   │   ├── UserManager.h/m           # Current user, Refs
│   │   │   ├── UserManager+Refs.h/m
│   │   │   ├── UserModel.h/m
│   │   │   └── MockFIRDocumentSnapshot.h  # Test mock
│   │   └── AdoptSection/
│   │       ├── PPAdoptPetManager.h/m
│   │       ├── PPAdoptPetModel.h/m
│   │       ├── PPAdoptPetCell.h/m
│   │       ├── PPAdoptPetsListViewController.h/m
│   │       ├── PPAddEditAdoptPetViewController.h/m
│   │       └── PPAdoptPetDetailViewController.h/m
│   ├── Main Controllers/
│   │   ├── SplashViewController.h/m
│   │   ├── AdminDashboardViewController.h/m  # XLForm hub
│   │   ├── PPProProfileSettingsViewController.h/m
│   │   └── PPProviderProfileEditorViewController.h/m
│   ├── DeliverySection/
│   │   ├── PPDeliveryManager.h/m
│   │   ├── PPDeliveryOrderModel.h/m    # 20+ timestamps, status enums
│   │   ├── PPDeliveryDashboardViewController.h/m
│   │   ├── PPDeliveryOrderDetailViewController.h/m
│   │   └── PPDeliveryStatusTimelineView.h/m
│   ├── DeliveryCompanySection/
│   │   ├── PPDeliveryCompanyModels.h/m
│   │   ├── PPDeliveryCompanyService.h/m
│   │   ├── PPDeliveryCompanyDashboardViewController.h/m
│   │   ├── PPDeliveryCompanyDetailViewController.h/m
│   │   ├── PPDeliveryCompanyMembersViewController.h/m
│   │   └── PPDeliveryCompanySetupViewController.h/m
│   ├── VeterinarianSection/
│   │   ├── PPVetManager.h/m
│   │   ├── PPVetModel.h/m              # Personal/Company, Free/Basic/Premium
│   │   ├── PPVetsListViewController.h/m
│   │   ├── PPAddEditVetViewController.h/m
│   │   ├── PPVetDetailViewController.h/m
│   │   └── PPVetSubscriptionViewController.h/m
│   ├── PharmacySection/
│   │   ├── PPPharmacyMedicinesViewController.h/m
│   │   └── PPPharmacyMedicineEditorViewController.h/m
│   ├── ServiceSection/
│   │   ├── PPServiceManager.h/m
│   │   ├── PPServiceModel.h/m          # Training/Grooming
│   │   ├── PPServiceCell.h/m
│   │   ├── PPServicesListViewController.h/m
│   │   ├── PPAddEditServiceViewController.h/m
│   │   ├── PPServiceDetailViewController.h/m
│   │   └── PPServiceSubscriptionViewController.h/m
│   ├── FulfillmentSection/
│   │   ├── PPFulfillmentManager.h/m
│   │   ├── PPFulfillmentModel.h/m
│   │   ├── PPFulfillmentCell.h/m
│   │   ├── PPFulfillmentListViewController.h/m
│   │   └── PPFulfillmentDetailViewController.h/m
│   ├── MarketSection/
│   │   ├── PPProviderMarketplaceManager.h/m
│   │   ├── PPProviderMarketItem.h/m
│   │   ├── PPProviderMarketItemsViewController.h/m
│   │   ├── PPProviderMarketItemEditorViewController.h/m
│   │   └── PPMarketplaceBranchesViewController.h/m
│   ├── NotificationsSection/
│   │   ├── NotificationManager.h/m
│   │   ├── PPNotificationsManager.h/m
│   │   ├── PPProInAppNotificationPresenter.h/m
│   │   ├── NotificationsListViewController.h/m
│   │   └── NotificationComposerViewController.h/m
│   ├── ProviderOnboarding/
│   │   ├── PPProviderApplicationManager.h/m
│   │   ├── PPBecomeProviderBottomSheetViewController.h/m
│   │   ├── PPProviderApplicationStatusViewController.h/m
│   │   └── ...
│   ├── AgentSection/
│   │   └── PPAgentModel.h/m
│   ├── AddressManager/
│   │   └── (City/State/Country models)
│   ├── Bridges/
│   │   └── HXPHPickerBridge/
│   │       └── PPEditorBridge.swift     # Swift editor bridge
│   ├── BasicClasses/
│   │   ├── MainKindsModel.h/m
│   │   ├── SubKindModel.h/m
│   │   ├── PetAccessory.h/m
│   │   ├── ArabicNormalizer.h/m
│   │   ├── ItemModel.h/m
│   │   └── PetImageItem.h/m
│   ├── Utilities/
│   ├── ThirdParty/
│   ├── Resourses/
│   ├── Assets.xcassets/
│   ├── ar.lproj/
│   ├── en.lproj/
│   └── PackageDelivery.json
├── PurePetsPro.xcodeproj/
├── PurePetsPro.xcworkspace/
├── PurePetsProTests/                    # Unit tests (placeholder)
├── PurePetsProUITests/                  # UI tests (placeholder)
├── Pods/
├── Podfile                              # 20+ CocoaPods
├── Podfile.lock
├── boringssl/
├── build/
├── fix_scene_delegate.py
├── opencode.json
├── .git/
└── README.md
```

---

## Technology Stack

| Component        | Technology                    | Detail                           |
|------------------|-------------------------------|----------------------------------|
| Language         | Objective-C (~98%), Swift (~2%) | 2 Swift files                    |
| UI Framework     | UIKit (code-only)             | No storyboards (except legacy splash) |
| Navigation       | Single UINavigationController | Push model, no tab bar           |
| Dashboard        | XLForm                        | Form rows as navigation menu     |
| Auth             | Firebase Auth                 | Phone OTP, Apple ID, Google      |
| Biometric        | LAContext + Keychain          | Face ID / Touch ID               |
| Database         | Firebase Firestore            | Real-time listeners              |
| Storage          | Firebase Storage              | Image upload                      |
| Messaging        | Firebase Cloud Messaging      | Push notifications               |
| Functions        | Firebase Cloud Functions      | Delivery company bridge          |
| App Check        | Firebase App Check            | App Attest → DeviceCheck → Debug |
| Image Loading    | SDWebImage                    | Async image caching              |
| Animations       | lottie-ios ~> 2.5.3           | JSON-based animations            |
| Forms            | XLForm                        | Dynamic form building            |
| Keyboard         | IQKeyboardManager             | Automatic keyboard avoidance     |
| HUD              | JGProgressHUD + JDStatusBarNotification | Loading + status bar |
| Image Editor     | TOCropViewController          | Crop, rotate, resize             |
| Font             | Beiruti (TTF)                 | 3 weights (Regular, Medium, Bold) |
| Icons            | SF Symbols 4+                 | Custom assets                     |
| Minimum iOS      | 15.0                          | In Podfile post_install           |

---

## Requirements

- **Xcode**: 15.x or 16.x
- **iOS**: 15.0 minimum deployment target
- **CocoaPods**: 1.15+ (`gem install cocoapods`)
- **Swift**: 5.x (for 2 Swift bridge files)
- **Physical device**: Required for QIB integration testing (not present in Pro)

---

## Installation

```bash
cd "Pure Pets Pro"
pod install
# Always open PurePetsPro.xcworkspace, NOT .xcodeproj
```

---

## Configuration

### Info.plist Keys

| Key | Value |
|-----|-------|
| `GIDClientID` | `646051621158-i8h3uu898vj19sqtm5ff5f1irv2r51h8.apps.googleusercontent.com` |
| `CFBundleURLTypes` | Google Sign-In reverse client ID |
| `NSFaceIDUsageDescription` | "Use Face ID to securely sign in to your Pure Pets Pro account." |
| `NSMicrophoneUsageDescription` | "Pure Pets Pro needs microphone access to send voice replies." |
| `NSPhotoLibraryUsageDescription` | "Pure Pets Pro needs photo library access to upload medicine images." |
| `UIBackgroundModes` | `audio`, `remote-notification` |
| `UIAppFonts` | `Beiruti-Bold.ttf`, `Beiruti-Medium.ttf`, `Beiruti-Regular.ttf` |

### Build Settings (post_install in Podfile)

- `IPHONEOS_DEPLOYMENT_TARGET` = 15.0
- `EXCLUDED_ARCHS[sdk=iphonesimulator*]` = `arm64` (YYKit WebP binary lacks simulator arm64 slice)
- `SWIFT_INSTALL_OBJC_HEADER` = `NO` (FirebaseFirestore fix for Xcode 16+)
- `-weak_framework "FirebaseFirestoreInternal"` stripped from xcconfigs (linker crash fix)
- `HEADER_SEARCH_PATHS` extended with pod header paths

### Theme Preference

Defined in `PrefixHeader.pch`:
```objc
static NSString * const PPProThemePreferenceSystem = @"system";
static NSString * const PPProThemePreferenceLight  = @"light";
static NSString * const PPProThemePreferenceDark   = @"dark";
```

---

## Build

```bash
cd "Pure Pets Pro"
pod install
xcodebuild -workspace 'PurePetsPro.xcworkspace' -scheme 'PurePetsPro' \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  CODE_SIGNING_ALLOWED=NO build
```

For device build, omit `CODE_SIGNING_ALLOWED=NO` and ensure valid signing certificate.

---

## Running

1. Open `PurePetsPro.xcworkspace` in Xcode
2. Select the `PurePetsPro` scheme
3. Choose a simulator or connected device
4. Press Run (⌘R)

### Simulator Note

`arm64` is excluded from simulator builds (YYKit limitation). Simulator targets must use `x86_64` architecture. Use iPhone 15 Pro or earlier simulator models if running on Apple Silicon Mac with Rosetta.

---

## Project Structure Details

### SceneDelegate (1204 lines)

The SceneDelegate manages the entire application lifecycle:

- **AppRoot enum**: `AppRootSplash`, `AppRootLogin`, `AppRootDashboard`, `AppRootProviderStatus`
- **Auth listener**: `FIRAuthStateDidChangeListenerHandle` — routes on auth state change
- **Delivery company preflight**: `pp_routeAfterDeliveryCompanyPreflightForUID:userDoc:fallbackRoot:autoPresentOnboarding:animated:`
- **Foreground lock infrastructure**: `ppLockOverlay`, `ppUnlockButton`, `pp_requiresForegroundUnlock`
- **Notification routing**: Pending notification payload consumption, company delivery notification handling
- **Splash minimum display**: 2.2 second minimum (`kPPSplashMinDisplayTime`)
- **User block check**: `PPSceneUserDocIsBlocked()` — checks `isBlocked`, `blocked`, `isDeleted`, `accountStatus`

### AppManager (Singleton)

- `configureFirebase` — Firebase setup
- `checkIfCurrentUserCanAccessPro:` — Session + role gating
- `checkIfUserWithUID:canAccessPro:` — Firestore-backed access check
- `fetchMainKindsWithCompletion:` — Pet categories cache
- `MainKindsArray` — Shared mutable array

### PrefixHeader.pch (524 lines)

Global macros and includes:

- **App shortcuts**: `AppMgr`, `UsrMgr`, `RPM`, `FUM`, `PPCurrentUser`
- **Design tokens**: `PPAdminDashboardHorizontalInset` (12), `PPAdminDashboardHeroRadius` (34), `PPAdminDashboardActionButtonSize` (42)
- **Color macros**: `AppPrimaryClr`, `AppSecondaryClr`, `AppBackgroundClr` (dynamic dark/light), `AppSurfColor`, `PrimaryTextClr`, `SeconderyTextClr`
- **Font macros**: `PPFontBold(size)`, `PPFontMedium(size)`, `PPFontRegular(size)` — Beiruti
- **RTL helper**: `PPIsRL` — `UIUserInterfaceLayoutDirectionRightToLeft`
- **iOS 26 check**: `PPIOS26()` — `@available(iOS 26.0, *)`
- **Error handling**: `ShowError(err)` global macro
- **Safe value macros**: `PPSafeString`, `PPSafeNumber`, `PPSafeArray`, `PPSafeDict`, `PPSafeURL`, `PPSafeIntegerUniversal`
- **Logging**: `DLog(fmt, ...)` — Debug-only NSLog

---

## Module Documentation

### AdminCore/Security

| Class | Purpose |
|-------|---------|
| `FUManager` | Firebase Auth lifecycle, AuthStateDidChangeListener |
| `PPRolePermission` | UserRole 0–8 enum, permission bitmask, feature flag gating |
| `RPManager` | Real-time permission document listener |
| `PPStaffAuth` | Staff authorization with 40+ permission keys |
| `PPBiometric` | Face ID / Touch ID via LAContext + Keychain |

### DeliverySection

| Class | Purpose |
|-------|---------|
| `PPDeliveryManager` | Real-time Firestore listener on Orders, Cloud Function calls for status transitions |
| `PPDeliveryOrderModel` | 20+ timestamp fields, status enum, location visibility flags |
| `PPDeliveryDashboardViewController` | Active deliveries list with real-time updates |
| `PPDeliveryOrderDetailViewController` | Order detail with timeline and actions |
| `PPDeliveryStatusTimelineView` | Visual timeline of status transitions |

### DeliveryCompanySection

| Class | Purpose |
|-------|---------|
| `PPDeliveryCompanyModels` | Profile, request, member, event models |
| `PPDeliveryCompanyService` | Firebase Cloud Function callable bridge |
| `PPDeliveryCompanyDashboardViewController` | Company overview and stats |
| `PPDeliveryCompanyDetailViewController` | Company profile detail |
| `PPDeliveryCompanyMembersViewController` | Member management list |
| `PPDeliveryCompanySetupViewController` | Company setup wizard |

### VeterinarianSection

| Class | Purpose |
|-------|---------|
| `PPVetManager` | Vet CRUD and subscription management |
| `PPVetModel` | Personal/Company types, Free/Basic/Premium subscription |
| `PPVetsListViewController` | Searchable list of veterinarians |
| `PPAddEditVetViewController` | Create or edit vet profile |
| `PPVetDetailViewController` | Vet detail view |
| `PPVetSubscriptionViewController` | Subscription plan selector |

### ServiceSection

| Class | Purpose |
|-------|---------|
| `PPServiceManager` | Service offer CRUD and subscription |
| `PPServiceModel` | Training/Grooming service types |
| `PPServicesListViewController` | Manage service offers |
| `PPAddEditServiceViewController` | Create or edit service |
| `PPServiceDetailViewController` | Service detail view |
| `PPServiceSubscriptionViewController` | Subscription management |

### FulfillmentSection

| Class | Purpose |
|-------|---------|
| `PPFulfillmentManager` | Fulfillment order queries |
| `PPFulfillmentModel` | Fulfillment order data model |
| `PPFulfillmentListViewController` | Ordered listing |
| `PPFulfillmentDetailViewController` | Fulfillment detail |

### MarketSection

| Class | Purpose |
|-------|---------|
| `PPProviderMarketplaceManager` | Marketplace item CRUD |
| `PPProviderMarketItem` | Market item data model |
| `PPProviderMarketItemsViewController` | Manage items listing |
| `PPProviderMarketItemEditorViewController` | Item creation/editing |
| `PPMarketplaceBranchesViewController` | Branch management |

### NotificationsSection

| Class | Purpose |
|-------|---------|
| `NotificationManager` | In-app notification inbox with CRUD |
| `PPNotificationsManager` | Push token management, audience targeting |
| `PPProInAppNotificationPresenter` | In-app toast/banner presentation |
| `NotificationsListViewController` | Notification inbox list |
| `NotificationComposerViewController` | Compose and send notifications |

---

## Data Flow

### Authentication Flow

```
Phone/Apple/Google Sign-In
       │
       ▼
FUManager → FIRAuth signInWithProvider / signInWithCredential
       │
       ▼
AuthStateDidChangeListener (SceneDelegate)
       │
       ▼
pp_applyAdminRoutingForAuthUser
       │
       ├── No user → Splash → Login
       └── User exists
            └── AppManager.checkIfUserWithUID:canAccessPro:
                 │
                 ├── UsersCol document check (canOfferServices, staff role)
                 ├── PPUserDocAllowsProAccess → BOOL
                 │
                 ├── NO → AppRootProviderStatus (blocked/ineligible)
                 └── YES
                      ├── Delivery company preflight
                      │    └── Profile exists → company dashboard
                      └── Standard → AdminDashboardViewController
```

### Delivery Order Flow

```
PPDeliveryManager real-time listener (Orders collection)
       │
       ▼
New/updated order document
       │
       ▼
PPDeliveryOrderModel parsed (20+ timestamps, status)
       │
       ▼
Dashboard table updated
       │
       ▼
Provider action (accept, pickup, deliver)
       │
       ▼
Cloud Function call via PPDeliveryManager
       │
       ▼
Firestore transaction updates order + audit log
       │
       ▼
Parent order status sync (fulfillment v1)
```

---

## Database

### Firebase Collections

| Collection | Purpose |
|------------|---------|
| `UsersCol` | User profiles, permissions, feature flags |
| `PermisstionsCol` | Permission documents (typo intentional and permanent) |
| `staff_users` | Staff authorization records |
| `veterinarians` | Vet profiles and subscriptions |
| `serviceOffers` | Training/grooming service offers |
| `petAccessories` | Accessory inventory (only stock collection) |
| `adopt_pets` | Adoption pet listings |
| `Orders` | Parent orders with fulfillment bridge |
| `FulfillmentOrders` | Child fulfillment orders |
| `MainKindsCollection` | Pet category taxonomy |
| `providerApplications` | Provider onboarding applications |
| `providerPlans` | Provider subscription plans |
| `branches` | Marketplace branches |
| `agents` | Nova agent configurations |
| `chatThreads` | Customer chats |
| `inbox` | Notification inbox (subcollection) |

---

## API

### Firebase Cloud Functions (External)

- `PPDeliveryCompanyService` — Delivery company Cloud Function bridge
- ProviderTransitionFulfillment, AdminOverrideFulfillment — Fulfillment status transitions
- Delivery status sync, parent order sync

### Internal Singletons (No REST API)

All data access is through direct Firestore reads/writes via domain managers. No internal REST API layer.

---

## Authentication

| Method | Detail |
|--------|--------|
| **Phone OTP** | Firebase Phone Auth via `AdminLoginViewController` |
| **Apple ID** | Sign in with Apple via Firebase Auth |
| **Google Sign-In** | `GoogleSignIn 8.0.0` via Firebase Auth |
| **Biometric** | Face ID / Touch ID via `PPBiometric` (LAContext + Keychain) |
| **Staff Auth** | `PPStaffAuth` with 40+ permission keys for granular access |

### 3-Layer Security Model

1. **Firestore Security Rules** — Collection-level access control
2. **Cloud Functions** — Server-side permission validation
3. **Client UI** — Role-gated feature visibility and action buttons

---

## Notifications

- **Provider**: Firebase Cloud Messaging (FCM)
- **Token management**: `PPNotificationsManager` (register, update, audience targeting)
- **In-app inbox**: `NotificationManager` — subcollection of UsersCol
- **Presentation**: `PPProInAppNotificationPresenter` — toast/banner overlay
- **Background modes**: `remote-notification` + `audio`
- **Notification routing**: SceneDelegate consumes pending notification payloads on cold start

---

## Background Tasks

- `remote-notification` background mode for push delivery
- `audio` background mode for voice message playback
- Real-time Firestore listeners (`addSnapshotListener`) in `PPDeliveryManager` and domain managers
- No `BGTaskScheduler` or explicit background fetch implementation detected

---

## Caching

- **Firestore**: Default persistence (offline cache) — Firestore SDK handles local cache automatically
- **SDWebImage**: Async image loading with disk cache
- **YYKit**: Memory cache for model objects (YYCache)
- **MainKindsArray**: In-memory array cached via `MainKindsArrayManager`
- No explicit offline-first strategy documented in source

---

## Offline Support

- Firestore offline persistence is enabled by default
- Real-time listeners reconnect automatically when connectivity returns
- No explicit offline queue or conflict resolution strategy detected
- YYKit WebP binary issue prevents simulator arm64 builds (offline-unrelated)

---

## Permissions

| Permission | Usage Context | Info.plist Key |
|------------|---------------|----------------|
| Face ID | Biometric authentication | `NSFaceIDUsageDescription` |
| Microphone | Voice reply messages | `NSMicrophoneUsageDescription` |
| Photo Library | Medicine image upload | `NSPhotoLibraryUsageDescription` |
| Remote Notifications | Push delivery | `UIBackgroundModes` |
| Audio | Voice message playback | `UIBackgroundModes` |

---

## Error Handling

- **`ShowError(err)` macro**: Global error display via `UIAlertController` with localized description
- **`DLog`**: Debug-only logging with file, line number, and formatted message
- **PPSafe* macros**: Null-safe value extraction from Firestore documents (`PPSafeString`, `PPSafeNumber`, `PPSafeArray`, `PPSafeDict`)
- **XLForm validation**: Form-level validation via XLForm built-in rules
- **Cloud Function error handling**: Callback-based with `NSError` parameter

---

## Logging

- **Debug**: `DLog(fmt, ...)` — wraps `NSLog` with `[DEBUG]` prefix, file name, and line number
- **Production**: `DLog(...)` compiles to no-op (`#ifdef DEBUG` gate)
- No formal logging framework (CocoaLumberjack, SwiftyBeaver, etc.) detected

---

## Security

- **3-layer permission model**: Firestore rules, Cloud Functions, client UI
- **App Check**: App Attest → DeviceCheck → Debug (resilient chain)
- **Biometric**: Face ID / Touch ID with LAContext + Keychain storage
- **Auth methods**: Phone OTP, Apple ID, Google Sign-In (no email/password)
- **No secrets committed**: GoogleService-Info.plist present (standard Firebase config)
- **Feature flags**: Role-gated via `PPRolePermission` (canOfferServices, canDelivery, canVet, canPharmacy, etc.)
- **Foreground lock**: Infrastructure exists but disabled (`pp_didAutoPromptForCurrentLockCycle`, `ppLockOverlay`)

---

## Performance

- **Real-time listeners**: Firestore snapshot listeners across multiple domain managers
- **Image caching**: SDWebImage for async loading and disk cache
- **Memory cache**: YYKit for model object caching
- **Main thread**: UIKit operations on main thread; Firestore callbacks on main queue
- **No lazy loading**: Controllers push eagerly; no preloading strategy detected
- **Build size**: Unknown (no IPA analysis performed)

---

## Accessibility

- **Dynamic Type**: Not detected in current source (no `UIFontMetrics` usage visible)
- **VoiceOver**: Not detected in current source (no `UIAccessibility` overrides visible)
- **RTL**: Full support via `PPIsRL` macro and leading/trailing Auto Layout anchors
- **Dark/Light mode**: Dynamic colors via `UIColor colorWithDynamicProvider:` and `Assets.xcassets` color catalog
- **SF Symbols**: Icons via `UIImage systemImageNamed:` — automatically supports accessibility sizes

---

## UI/Design System

### Design Tokens (PrefixHeader.pch)

```objc
PPAdminDashboardHorizontalInset = 12.0
PPAdminDashboardHeroRadius     = 34.0
PPAdminDashboardActionButtonSize = 42.0
```

### Colors (Assets.xcassets)

| Macro | Purpose |
|-------|---------|
| `AppPrimaryClr` | Main brand color |
| `AppPrimaryClrDarker` | Darker brand variant |
| `AppPrimaryClrShiner` | Lighter brand variant |
| `AppSecondaryClr` | Accent/secondary (systemTealColor) |
| `AppBackgroundClr` | `pp_canvasColor()` — dynamic dark/light |
| `AppSurfColor` | Surface color |
| `PrimaryTextClr` | Primary text color |
| `SeconderyTextClr` | Secondary text color |
| `AccentColor` | UI accent |

### Typography

- **Font**: Beiruti (3 TTF weights in bundle)
- **Regular**: `PPFontRegular(size)` — Beiruti-Regular
- **Medium**: `PPFontMedium(size)` — Beiruti-Medium
- **Bold**: `PPFontBold(size)` — Beiruti-Bold

### Icons

- SF Symbols 4+ via `UIImage systemImageNamed:`
- Custom assets in `Assets.xcassets`
- `PPSymbolHelper` — Symbol utility class

### Theme

- System/Light/Dark toggle via `PPProThemePreference`
- Dynamic colors via `UIColor colorWithDynamicProvider:`
- Full RTL layout via leading/trailing Auto Layout anchors

---

## Dependencies

### CocoaPods (Podfile)

| Pod | Version | Purpose |
|-----|---------|---------|
| Firebase/Core | Latest | Firebase core |
| Firebase/Auth | Latest | Authentication |
| Firebase/Firestore | Latest | Database |
| Firebase/Storage | Latest | File storage |
| Firebase/Messaging | Latest | Push notifications |
| Firebase/Functions | Latest | Cloud Functions callable |
| FirebaseAppCheck | Latest | App Check |
| FirebaseInstallations | Latest | Installation ID |
| GoogleSignIn | 8.0.0 | Google Sign-In |
| YYKit | Latest | Utilities, caching (unmaintained) |
| SDWebImage | Latest | Async image loading |
| lottie-ios | ~> 2.5.3 | JSON animations |
| XLForm | Latest | Dynamic forms |
| IQKeyboardManager | Latest | Keyboard management |
| SSZipArchive | Latest | ZIP handling |
| PopupDialog | ~> 1.1 | Modal popups |
| ShowTime | Latest | Touch display for demos |
| JGProgressHUD | Latest | Loading indicators |
| JDStatusBarNotification | Latest | Status bar notifications |
| TOCropViewController | Latest | Image cropping |

### Transitive Dependencies

`abseil`, `BoringSSL`, `gRPC`, `leveldb`, `PromisesObjC`, `nanopb`, `RecaptchaInterop`, `DynamicBlurView`, `AppAuth`, `GTMSessionFetcher`, `GTMAppAuth`

---

## Testing

### PurePetsProTests

- Unit test target exists but is **placeholder** (no implemented test cases detected)
- `MockFIRDocumentSnapshot.h` exists as a test mock

### PurePetsProUITests

- UI test target exists but is **placeholder** (no implemented test cases detected)

### Test Dependencies

Not detected in current source. No XCUnitTest or XCUITest method implementations found.

---

## Known Limitations

1. **YYKit is unmaintained** — compiler warning suppression (`-Wno-parentheses`) required
2. **No simulator arm64 support** — YYKit's vendored WebP binary lacks simulator arm64 slice; `EXCLUDED_ARCHS` workaround in Podfile
3. **FirebaseFirestore requires `SWIFT_INSTALL_OBJC_HEADER = NO`** — Xcode 16+ fix for `FirebaseFirestore-Swift.h`
4. **`-weak_framework FirebaseFirestoreInternal` must be stripped** — classic linker `dylibToOrdinal` assertion crash
5. **Foreground lock is disabled** — infrastructure exists (`ppLockOverlay`, `ppUnlockButton`) but unused
6. **No offline-first strategy** — default Firestore persistence only
7. **DeliveryCompany preflight depends on Cloud Function availability** — no fallback for offline
8. **Single navigation stack** — no tab bar; all screens push onto one `UINavigationController`
9. **No QIB payment** — consumer-only feature (present in Pure Pets IOS)
10. **No chat/streaming agent** — Nova consumer agent is in the main app only; Pro has `PPAgentModel` only
11. **SplashViewController is a placeholder** — minimum display time of 2.2s enforced
12. **No formal logging framework** — `DLog` only compiles in DEBUG builds

---

## Future Improvements

- [ ] Replace YYKit with modern alternatives (Alamofire, Kingfisher)
- [ ] Add SwiftUI migration for select screens
- [ ] Enable foreground lock for idle session timeout
- [ ] Implement offline-first with pending writes queue
- [ ] Add comprehensive unit test coverage
- [ ] Add UI test coverage with XCUITest
- [ ] Add Cloud Function fallback for DeliveryCompany preflight
- [ ] Enable simulator arm64 by updating YYKit's WebP binary
- [ ] Add tab-based navigation for multi-tasking workflows
- [ ] Integrate Nova agent for provider assistance
- [ ] Add payment capabilities (QIB or other provider)
- [ ] Add `BGTaskScheduler` for background data refresh
- [ ] Implement proper logging framework (CocoaLumberjack)
- [ ] Add analytics and crash reporting (Crashlytics)
- [ ] Add SwiftUI-based settings and profile screens

---

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| `ld: Assertion failed: (dylibToOrdinal ...)` | `-weak_framework FirebaseFirestoreInternal` conflict | Run `pod install` — post_install strips it |
| `FirebaseFirestore-Swift.h` not found | Xcode 16+ | Podfile sets `SWIFT_INSTALL_OBJC_HEADER = NO` |
| Simulator build fails on arm64 | YYKit WebP binary | Use x86_64 simulator (iPhone 15 Pro or older) |
| `YYKit` compile error (chained comparison) | Unmaintained pod | Podfile adds `-Wno-parentheses` flag |
| Google Sign-In crash | URL scheme misconfigured | Verify `CFBundleURLSchemes` matches `GIDClientID` reversed |
| `FIRApp configure` crash | Missing `GoogleService-Info.plist` | Ensure file exists in project root |
| Push notifications not arriving | App Check / token | Verify FCM token registration in `PPNotificationsManager` |
| XLForm rows not appearing | Form descriptor error | Check `XLFormDescriptor` setup in `AdminDashboardViewController` |
| Delivery listener not firing | Firestore rules | Verify read access on `Orders` collection |
| Biometric auth fails | `NSFaceIDUsageDescription` missing | Check Info.plist |

---

## FAQ

**Q: Why is the app ~98% Objective-C?**  
A: The codebase predates Swift adoption. Only 2 Swift files exist for bridging specific features.

**Q: Why no tab bar?**  
A: The app uses a single XLForm-based dashboard with push navigation. Tab navigation was not needed for the provider workflow.

**Q: Why is `PermisstionsCol` misspelled?**  
A: The typo is intentional and permanent. Renaming it would break Firestore rules and production data.

**Q: Does Pro support QIB payment?**  
A: No. QIB Payment is a consumer-only feature in Pure Pets IOS.

**Q: Can Pro run on a simulator?**  
A: Yes, but `arm64` simulator slices are excluded. Use x86_64 simulator targets.

**Q: How do I add a new feature module?**  
A: Create a new domain manager singleton (e.g., `PPNewFeatureManager`), add XLForm rows in `AdminDashboardViewController`, and implement the view controllers.

**Q: Is there a Nova agent in Pro?**  
A: Only a basic `PPAgentModel` exists. The full Nova streaming+ambient agent is in the consumer iOS app.

---

## Key Differences from Pure Pets IOS (Consumer)

| Aspect | Pure Pets Pro | Pure Pets IOS |
|--------|--------------|---------------|
| Purpose | Provider/professional tools | Consumer marketplace |
| Dashboard | XLForm hub | Tab bar (Home, Search, Cart, Profile) |
| Auth | Phone + Apple + Google | Email + Phone + Social |
| Core | Delivery, vet, pharmacy, service | Pet ads, accessory market |
| QIB Payment | Not present | QIBPayment.framework |
| Nova | PPAgentModel only | Full streaming + ambient agent |
| Navigation | Single push stack | Tab bar + push |

---

## Changelog

### [1.0.0] — Initial Release (Unreleased)

- XLForm-based admin dashboard
- Delivery management with real-time Firestore listeners
- Delivery company CRUD and Cloud Function bridge
- Veterinarian profiles with Free/Basic/Premium subscriptions
- Pharmacy medicine CRUD with image support
- Service offers (Training/Grooming) with subscriptions
- Fulfillment order management
- Provider marketplace items and branches
- Provider onboarding application flow
- Pet adoption listings CRUD
- Staff authentication (Phone OTP, Apple ID, Google)
- Biometric authentication (Face ID / Touch ID)
- Role-based permissions (UserRole 0–8)
- 40+ staff permission keys
- App Check with resilient chain
- RTL bilingual support (Arabic + English)
- Dark/Light/System theme toggle
- Notification inbox with push and in-app presentation
- YYKit, XLForm, SDWebImage, lottie-ios integration

---

## License

Proprietary. All rights reserved. Not open source.
