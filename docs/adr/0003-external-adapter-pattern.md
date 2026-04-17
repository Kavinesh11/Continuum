# ADR 0003: External Adapter Pattern

**Status:** Accepted  
**Date:** 2026-04-17  
**Deciders:** Continuum engineering team

## Context

Continuum depends on multiple external systems that are unavailable during development, testing, or pre-regulatory-approval phases: PayU (UPI disbursement + mandates), Swiggy/Zomato APIs (order verification), iProov (biometric liveness), IMD bulk weather data, municipal GIS data, and cloud KMS.

The IRDAI compliance audit flagged that these integrations are either sandbox-only or entirely mocked, with no clear boundary between real and stub implementations.

## Decision

Every external dependency is abstracted behind a typed adapter interface with three implementations:

1. **MockAdapter** — deterministic, seeded, for unit/integration tests and local dev.
2. **SandboxAdapter** — calls the vendor's sandbox/UAT environment (where available).
3. **ProdAdapter** — typed shell that validates configuration and calls production APIs. Throws `AdapterNotConfiguredError` if required credentials are missing.

Selection is via environment variable: `<NAME>_PROVIDER=mock|sandbox|prod`.

Each adapter ships with:
- Contract tests against shared JSON fixtures.
- An acceptance checklist document at `docs/integrations/<name>.md`.

## Consequences

- No code path depends on a live third-party at merge time.
- Acceptance checklists provide a clear go/no-go per vendor.
- Adapter interfaces must be kept narrow to avoid vendor lock-in leaking through.
- Runtime adapter selection adds one level of indirection.

## Rollback Procedure

Set `<NAME>_PROVIDER=mock` for any adapter that needs to be disabled. The mock adapter is always available and requires no external connectivity.
