# ADR 0004: PII Envelope Encryption

**Status:** Accepted  
**Date:** 2026-04-17  
**Deciders:** Continuum engineering team

## Context

The DPDP Act 2023 requires encryption of personal data at rest. Continuum stores several PII fields:
- `workers.aadhaar_hash` (SHA-256 of Aadhaar number)
- `workers.upi_id` (UPI Virtual Payment Address)
- `gps_activity.lat`, `gps_activity.lon` (raw GPS coordinates)

While `aadhaar_hash` is already a one-way hash, the source Aadhaar number transits through the system before hashing. UPI IDs and GPS coordinates are stored in plaintext.

## Decision

Apply envelope encryption using the `KmsAdapter` interface (ADR 0003):

1. **UPI ID:** Encrypt at write time in `routes/workers.js` and `routes/policies.js`. Decrypt at read time in the payout disbursement processor.
2. **GPS raw coordinates:** Encrypt at write time. The `gps_activity` table stores encrypted lat/lon. Spatial checks decrypt on-the-fly.
3. **Aadhaar source:** Encrypt the raw Aadhaar number before hashing, then store only the hash. The encrypted source is discarded after hashing.

The `piiEncryption` service module wraps the KMS adapter with field-level helpers.

## Consequences

- Read-time decryption adds latency (~2ms for local KMS, ~50ms for AWS KMS).
- Encrypted fields cannot be indexed or queried by value; use the hash column for lookups.
- Key rotation requires a migration script that re-encrypts all existing ciphertext.

## Rollback Procedure

Set `KMS_PROVIDER=local` and keep the local KMS secret stable. All encrypted data remains readable.
