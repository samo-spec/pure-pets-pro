# Pure Pets Pro — NextGen V8 Clinical Passport Cells

Date: 2026-11-08
Target: PurePetsPro/VeterinarianSection/PPVetCell.m
Creative owner: swiftymax-nextgen-category-defining-v8
Verification class: source/tests only; native visual/runtime unverified.

## Creative decision
Reinvent the veterinarian record around three jobs:
1. Identity — understand the provider's name, type, actual supported animal types, description and subscription.
2. Operational truth — display active/disabled, not an unverified online state; consultation fee is real data, not a competing decorative pill.
3. Decision — explicit View profile CTA, separate accessible Call and WhatsApp controls; no phantom actions when contact channels are absent.

Chosen: Clinical Passport — semantic vertical state rail, portrait/identity stage, status-and-fee band, separate action dock.

Rejected: decorating the old large card wall; hiding core navigation in gestures; implying live availability from ambiguous availableDate.

## Implementation
- PPVetCell.m: native existing UIKit tokens and localized content, RTL, Dynamic Type, reused actions and permissions.
- Arabic and English Localizable.strings: Vet_Roster_View_Profile and Vet_Roster_Fee_Label.
- scripts/pro_vet_roster_v8_contract_test.cjs: regression coverage for state truth, 44pt actions, contact visibility, large-text reflow and permissions.

## Preserved
No change to provider ownership, existing Firestore listener, server/role contracts, profile navigation, confirmations, iPad inspector or backend. No new dependencies. Normal action targets are at least 44pt; very large text uses vertical stacked actions with visible labels; Reduce Motion path preserved.

## Verification
- V8 audit-source: zero static findings (not compilation or visual certification).
- Paradigm Genome: eight structural signature dimensions differ from previous layout; market originality unverified.
- Experience Physics: zero human samples; real usability unverified.
- Nine of nine focused roster contracts passed.
- Pro delivery-access and cockpit regression suites passed.
- Both Localizable.strings files passed plutil -lint.
- git diff --check passed.
- 12ui rendering service unavailable for authentication.
- No xcodebuild or simulator permitted in this project; native compile, VoiceOver, visual fidelity, dark/light, RTL/LTR and iPad runtime are UNVERIFIED.

## Physical-device next check
On an approved device validate long Arabic and English names, dark mode, VoiceOver, XXL text, missing phone/WhatsApp, decimal/zero fee, disable/enable permissions, selection, iPad inspector and interactions.

IMPLEMENTED IN SOURCE. NOT CERTIFIED ON DEVICE. No deploy, push or release.
