# GEMINI.md — Pure Pets Project Brain Satellite: Provider Pro iOS

This repository is the provider/professional iOS application for Pure Pets (`pure-pets-49199`).

## Brain Boot Contract
1. For cross-repository context, locate sibling `PurePetsProjects` and read `AGENTS.md` and `docs/agent/INDEX.md`.
2. `pure-pets-infra` is authoritative for backend schema, rules, Cloud Functions, and lifecycle.
3. Machine pointer: `project-brain.json`.

## Core Invariants
- Provider workflows: delivery, vet, pharmacy, services, marketplace, adoption.
- Sensitive mutations route through audited Cloud Functions.
- Physical connected device only execution policy (iPhone 13 Pro Max).
- Arabic primary (RTL) localization.
- Never ingest secrets.
