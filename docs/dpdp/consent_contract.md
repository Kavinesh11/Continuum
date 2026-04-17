# DPDP Act 2023 — Consent Contract

## Overview

Per the Digital Personal Data Protection Act 2023, Sections 5–8, all personal data processing requires **freely given, specific, informed, unconditional, and unambiguous** consent.

## Consent Purposes

| Purpose | Data Collected | Retention | Required For |
|---------|----------------|-----------|--------------|
| `gps_location_tracking` | GPS coordinates (lat/lon) | 60 days post-collection | Spatial fraud check, zone verification |
| `biometric_liveness` | Face capture (processed, not stored) | Not retained after verification | Identity verification at enrollment |
| `proximity_detection` | Device-to-device Bluetooth/WiFi signals | 30 days | Collusion detection (Req 17.3) |
| `aadhaar_verification` | Aadhaar number (SHA-256 hashed) | Lifetime of policy | 1:1 identity binding (Req G5) |
| `upi_mandate` | UPI VPA, eNACH mandate ID | Until mandate revocation | Premium collection, payout disbursement |
| `push_notifications` | FCM token | Until consent withdrawal | Payout notifications, policy alerts |

## API Contract

### Grant consent
```
POST /consent
Authorization: Bearer <jwt>
Content-Type: application/json

{ "purpose": "gps_location_tracking", "template_version": "v1" }
```

### Revoke consent
```
DELETE /consent/gps_location_tracking
Authorization: Bearer <jwt>
```

### List consents
```
GET /consent
Authorization: Bearer <jwt>
```

## Flutter App Integration

The mobile app must:
1. Display a purpose-specific consent screen with plain-language explanation before each data type is collected.
2. Call `POST /consent` after the user taps "I Agree".
3. Provide a Settings > Privacy screen listing all granted consents with a "Revoke" button per purpose.
4. On revoke: call `DELETE /consent/:purpose`, then stop collecting that data type immediately.

## Data Subject Rights (DPDP Act §11–13)

- **Right to access:** `GET /consent` lists all consents and their status.
- **Right to erasure:** Revocation triggers data deletion per retention schedule. GPS data > 60 days is purged by `gpsRetentionSweep`.
- **Right to correction:** Workers can update their profile via `PUT /workers/:id`.
- **Right to grievance redressal:** Contact details in app and T&C §27.
