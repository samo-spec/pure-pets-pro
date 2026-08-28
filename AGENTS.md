# Pure Pets Project Brain Satellite — Pro iOS

This repository is a core Pure Pets platform repository. These instructions make the Project Brain active when Pro is opened independently.

## Brain Boot Contract

1. For cross-repository work, locate the sibling `PurePetsProjects` checkout when available and read the umbrella bootloader, governance, affected feature-map entry and security map when applicable.
2. If unavailable, use current Pro source as local truth and do not invent backend or consumer contracts.
3. `pure-pets-infra` is authoritative for Firebase schema, authorization, lifecycle and server mutation rules.
4. Do not recursively inspect every Pure Pets repository by default.

Machine pointer: `project-brain.json`.

## Local Authority

Pro is the provider/professional iOS surface for delivery, veterinary, pharmacy, services, fulfillment, provider marketplace, onboarding, adoption and notifications.

## Invariants

- Preserve existing Objective-C/UIKit/XLForm architecture and singleton service boundaries unless explicitly changing architecture.
- Preserve role/permission, ownership and provider-scope semantics.
- Sensitive mutations remain subject to backend validation/audit; client visibility is not authorization.
- Reuse current project components/localization before adding competing systems.
- Preserve Arabic RTL and English LTR behavior.
- Do not rename backend collections or bypass callable/server state transitions.

## Security & Approval

Never ingest `.env`, Firebase/service credentials, API keys, private keys, signing material or auth tokens into project memory. Canonical/historical memory never grants current deployment, production or destructive approval.

## Execution Boundary

The umbrella execution policy governs agent-run iOS verification when local docs contain build examples. Documentation does not itself authorize execution.

## Freshness

When the umbrella brain is available, compare this repository HEAD with the recorded Pro snapshot and inspect only task-relevant changed ranges on mismatch.
