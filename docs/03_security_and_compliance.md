# Continuum — Security and Compliance

**Version:** 1.0  
**Effective Date:** 2026-04-17  
**Classification:** Regulatory / Investor / Due Diligence  
**Audience:** Regulators (IRDAI), investors, security reviewers, legal counsel

> **Important:** This document describes security controls implemented for the Continuum parametric insurance platform. All fraud defenses described here are operational, not theoretical — they are encoded at the database constraint, service logic, and infrastructure layers.

---

## Table of Contents

1. [Threat Model](#1-threat-model)
2. [Five-Layer Fraud Defense Architecture](#2-five-layer-fraud-defense-architecture)
3. [Adversarial Scenario Coverage — 100 Failure Modes](#3-adversarial-scenario-coverage--100-failure-modes)
4. [Oracle Security Controls](#4-oracle-security-controls)
5. [Financial Security Controls](#5-financial-security-controls)
6. [IRDAI 11-Point Compliance Audit](#6-irdai-11-point-compliance-audit)
7. [DPDP Act 2023 Compliance](#7-dpdp-act-2023-compliance)
8. [Liability and Legal Safety](#8-liability-and-legal-safety)
9. [Security Controls Master Table](#9-security-controls-master-table)

---

## 1. Threat Model

### 1.1 Primary Adversary

The primary adversary modeled is a **coordinated fraud ring of 500 delivery partners** using consumer-grade GPS spoofing applications to simultaneously position themselves inside a flood-triggered payout zone. Simple GPS verification is insufficient against this attack.

### 1.2 Attack Vector Categories

Continuum's security architecture was stress-tested against six distinct attack vector categories:

| Category | Scenario Range | Attack Vector |
|----------|---------------|---------------|
| A | Scenarios 1–20 | GPS and location spoofing |
| B | Scenarios 21–35 | Coordinated collusion rings |
| C | Scenarios 36–55 | Actuarial and pricing model failures |
| D | Scenarios 56–70 | Oracle data manipulation |
| E | Scenarios 71–82 | Regulatory and legal edge cases |
| F | Scenarios 83–100 | Systemic and black swan events |

The complete adversarial scenario database (`adversarial_scenarios.md`) documents all 100 scenarios with root cause, impact, and implemented defense for each.

### 1.3 Core Security Insight

> **GPS is necessary, not sufficient.**

A single GPS coordinate is a claim, not proof. Every payout gate in Continuum requires corroborating evidence from independent signal layers. A fraudster who can fake one layer almost never controls all of them simultaneously.

| Signal | Genuine Partner | Fraud Ring Member |
|--------|----------------|------------------|
| Device attestation | Valid hardware cert | Emulator / rooted device |
| GPS + Cell-ID match | < 500m divergence | Often > 2km divergence |
| Soak period compliant | In zone ≥ 45 min pre-trigger | Arrived post-trigger announcement |
| Platform order history | Zero orders during disruption | May show completed orders |
| Claim population density | Distributed across zone | Statistically converged on identical polygon |
| Claim velocity | ≤ 1 claim per event | Multiple claims in short window |
| Device proximity history | No prior group clustering | Devices co-located in prior 7 days |

> No single signal is decisive. A genuine partner passes every layer. A fraud ring member cannot simultaneously clear all seven.

---

## 2. Five-Layer Fraud Defense Architecture

### Layer 1 — Identity and Device Integrity

**Purpose:** Prevent fraudsters from establishing a legitimate identity or duplicating accounts.

#### 1a. 1:1 Device Binding

Each Policy ID is cryptographically bound to a unique device fingerprint at the **database constraint level**:

```sql
-- db/migrations/postgres/003_identity_uniqueness.sql
CREATE UNIQUE INDEX workers_device_unique
  ON workers(device_fingerprint)
  WHERE device_fingerprint IS NOT NULL;
```

A second policy registration on the same device is rejected by the database — no application-layer logic can override this. Device fingerprints are collected via the Android SDK and cannot be spoofed without hardware access.

#### 1b. National Identity Uniqueness (Aadhaar KYC)

Aadhaar/PAN KYC enforces a 1:1 mapping between national identity and active policy count:

```sql
CREATE UNIQUE INDEX workers_aadhaar_unique
  ON workers(aadhaar_hash)
  WHERE aadhaar_hash IS NOT NULL;
```

Family-member account farming is structurally impossible. Aadhaar is stored **only as a one-way SHA-256 hash** — never in plaintext. See Section 7 for DPDP Act compliance details.

#### 1c. Android Play Integrity API / SafetyNet Attestation

Android emulators and rooted devices lack valid hardware attestation certificates. Claims from non-attested devices are automatically ineligible. The platform periodically re-attests devices in the background to detect post-enrollment compromise.

Affected scenarios: Android emulator masquerade (Scenario 4), rooted device GPS patching (Scenario 11).

#### 1d. Biometric Liveness on Claim Submission

A biometric face-scan challenge is injected at claim submission, defeating:
- Account-lending schemes (Scenario 13)
- Static-ID theft
- Deepfake-generated video (Scenario 35) — via iProov API, which cross-references blink patterns and micro-lighting artifacts that generative models fail to replicate consistently

#### 1e. Stolen KYC Protection

Biometric liveness at activation prevents stolen static KYC from being used to register accounts. A matching face scan is required — a stolen Aadhaar document is insufficient (Scenario 34).

---

### Layer 2 — Multi-Signal Location Corroboration

**Purpose:** Ensure location cannot be faked by manipulating any single signal.

#### 2a. Cellular Network Triangulation (Cell-ID Cross-Reference)

If the GPS coordinate and Cell-ID triangulation mismatch by more than **2km**, the location claim is flagged as `LOCATION_MISMATCH` and a `-0.3` spatial penalty is applied to the fraud score.

A spoofing app can inject a false GPS position into the OS; it cannot simultaneously spoof the carrier-reported Cell-ID from the cellular basestation. This cross-check is the primary defense against consumer-grade GPS spoofing apps.

#### 2b. The 45-Minute Soak Period

A partner must have been GPS-verified inside the target polygon for a **minimum of 45 continuous minutes before** the parametric trigger fires. Pre-trigger positioning (driving into the zone seconds before a known alert) is thus structurally unrewarded.

Partners who arrive in the zone after the trigger fires cannot satisfy the soak period requirement, regardless of their GPS location at claim time. Soak period failure is a **hard override** — it forces `FRAUD_QUEUE` routing regardless of the composite fraud score.

#### 2c. Temporal Ping Consistency

Location is sampled across a minimum of **3 independent timestamps** within the disruption window. A single fraudulent ping is insufficient. Coordinate velocity = 0 for extended periods (static lock at a fixed address, e.g., a restaurant — Scenario 10) triggers automatic eligibility suspension.

#### 2d. Delivery Platform Order Cross-Reference (Hard Veto)

If the Swiggy/Zomato API reports that a partner completed one or more orders during the stated disruption window, the payout claim is **vetoed**. A partner cannot be both "unable to work due to disruption" and simultaneously transacting on the platform.

This cross-reference is a **hard, unappealable veto** — it overrides all other signals including the fraud score. It is implemented as the `platform_activity_veto` flag in the Rust scoring pipeline.

#### 2e. GPS Zone Validation Rules

| Rule | Implementation |
|------|---------------|
| GPS centroid inside polygon ≥70% of sampled pings | Spatial frequency check |
| All GPS timestamps NTP-synced server-side | Client timestamps discarded as non-authoritative |
| GPS pings must fall within `[trigger_start, trigger_end + 15 min]` window | Hard temporal boundary |
| Zone of payout = enrolled home zone tier (not claim-zone tier) | Prevents cross-zone tier arbitrage (Scenario 12) |

---

### Layer 3 — Population-Level Statistical Anomaly Detection

**Purpose:** Detect coordinated rings by analyzing the population of simultaneous claims, not individual claims.

#### 3a. Geographic Convergence Freeze

If **≥50 unique policy IDs** file claims pointing to an identical or near-identical lat/long polygon within a **5-minute window**, the zone triggers an automatic **"Convergence Freeze"**:
- All pending claims for that zone are held for a mandatory **24-hour review** before any payout is released
- A genuine flood will affect the zone gradually; 500 fraudsters converging instantaneously is a statistical signature unique to coordinated rings (Scenario 2)

#### 3b. Social Graph Clustering via Device Proximity

Device-level Bluetooth and WiFi proximity logs are analyzed at claim time. Claims from a cluster of devices that have been in **close physical proximity over the prior 7 days** (indicative of a coordinated group) are flagged for elevated review.

Genuine partners stranded in a flood zone may be near each other, but they did not spend the prior week in the same room. Proximity data collection requires **explicit DPDP Act 2023 consent** (`proximity_consent` flag in `workers` table). All proximity logs are auto-purged after 30 days.

#### 3c. Velocity Limiting (3 Claims / 90 Days)

A maximum of **3 successful claims per policyholder per 90-day rolling window** is enforced at the database query level in the frequency check. Chronic super-claimants (Scenario 94) are moved to a mandatory manual review hold regardless of individual claim validity.

#### 3d. Social Graph Referral Farming Detection

WhatsApp-group-coordinated claim rings (Scenario 17) are detected by flagging claims where >15 policies from the same social graph file within 5 minutes. Referral bonuses are withheld until the referred partner completes 60 days with zero claims — destroying the economics of referral-farming rings (Scenario 29).

---

### Layer 4 — Oracle Consensus Security

**Purpose:** Ensure no single data source — external or internal — can unilaterally authorize a payout.

#### 4a. Event-Type-Weighted Oracle Sets

Oracle sets are selected per event type:
- **Weather:** IMD + AccuWeather + NASA GPM + Ground sensors — **3-of-4** required
- **AQI:** CPCB + Ground sensors + IMD — **2-of-3** required
- **Outage:** Downdetector + Synthetic ping + Platform API — **2-of-3** required

A corrupt weather sensor cannot influence an AQI trigger vote. Irrelevant oracles are excluded from each event type's vote.

#### 4b. Data Freshness Enforcement (15-Minute TTL)

Oracle data carries a maximum TTL of **15 minutes**. Data exceeding this TTL is treated as an **abstention** — not a "yes" vote. Stale cached data (Scenario 56) cannot trigger a payout. This is implemented in `OracleConsensusEngine.apply_staleness_rule()`.

#### 4c. TLS Certificate Pinning with Dual-Pin Rotation

All HTTPS calls to external data APIs are protected by certificate pinning:
```python
def _verify_fingerprint(cert_der: bytes, expected_fps: list[str]) -> bool:
    actual_fp = hashlib.sha256(cert_der).hexdigest().lower()
    return actual_fp in expected_fps
```

Two fingerprints per oracle (current + rotation slot) enable seamless certificate rotation. An unexpected certificate causes the oracle's vote to be **automatically nullified** for that polling cycle (Scenario 61 — DNS hijack defense).

#### 4d. Randomized Polling Schedule

Oracle polling intervals are randomized within **±8 minutes** around the base cron schedule. The schedule is never exposed externally, making it computationally infeasible to time fraudulent activity to the exact millisecond between sensor checks (Scenario 33).

#### 4e. Advisory Feed Signature Validation

Municipal advisory RSS feeds are validated by PGP certificate from the issuing municipality. Forged advisory feeds (Scenario 60) are rejected at the ingestion layer.

#### 4f. Forecast-Driven Enrollment Lockout

A separate IMD forecast oracle publishes `enrollment_lock` events via the database when high-risk conditions are predicted within 72 hours. The `POST /policies` endpoint checks `zone_enrollment_locks` and returns **HTTP 423** if a lock is active, preventing opportunistic enrollment before known storms (Scenario 50).

---

### Layer 5 — Incentive-Based Fraud Deterrence

**Purpose:** Make fraud economically irrational at the structural level.

| Control | Mechanism | Fraud Vector Defeated |
|---------|-----------|----------------------|
| **72-hour activation delay** | `claim_eligible_from = enrolled_at + 72h` enforced in DB | Same-day enrollment and claim (Scenario 50) |
| **5-day tier-upgrade wait** | Claim eligibility not updated until 5 days post-upgrade | Pre-event coverage escalation (Scenario 42) |
| **Cancellation cycle lock** | Cancellations effective only at next billing cycle boundary | Cancel-after-disruption exploit (Scenario 49) |
| **60-day referral bonus hold** | Bonus credited only after 60 days with zero claims | Referral farming rings (Scenarios 29, 37) |
| **One payout per 7-day cycle** | Hard cap enforced in payout disbursement processor | Double-event stacking (Scenario 46) |
| **6-hour SIM-swap cooling** | `sim_changed_at` checked before payout release | SIM-swap during payout (Scenario 90) |

---

## 3. Adversarial Scenario Coverage — 100 Failure Modes

The following tables summarize all 100 adversarial scenarios by category. Full details are in `adversarial_scenarios.md`.

### Category A: GPS and Location Spoofing (Scenarios 1–20)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 1 | Single partner fakes GPS into flood zone | Cell-ID triangulation cross-check (>2km → flag) |
| 2 | 500 partners spoof same polygon simultaneously | Geographic convergence freeze (≥50 policies same polygon in 5 min → 24h hold) |
| 3 | GPS locked at one point, returns before revalidation | Minimum 3 timestamps across disruption window |
| 4 | Android emulator masquerades as real device | Play Integrity API hardware attestation |
| 5 | GPS jitter at polygon edge, oscillating in/out | GPS centroid inside polygon ≥70% of sampled pings |
| 6 | Partner drives into zone just before trigger fires | 45-minute pre-trigger soak period requirement |
| 7 | VPN spoofs IP to matching city | IP checks are secondary signals only |
| 8 | Two partners share device via SIM swap | 1:1 device binding (DB UNIQUE constraint) |
| 9 | Partner registers false home zone | Zone must match first 30 days GPS telemetry |
| 10 | GPS locked at 3rd-party address (velocity = 0) | Velocity = 0 for >20 min → eligibility suspension |
| 11 | OS-level GPS patched on rooted device | SafetyNet root detection; rooted devices ineligible |
| 12 | Partner spoofs to higher-payout zone | Payout capped at enrolled home-zone tier |
| 13 | Account lending to pass GPS check | Biometric face scan on claim; mismatch → auto-reject |
| 14 | Fraud ring uses GPS hardware repeaters | Platform delivery API cross-reference (hard veto) |
| 15 | Zone is uninhabited park; fakes presence | Zones validated against active merchant density (OSM + Swiggy) |
| 16 | Completed orders during claimed disruption window | Platform API hard veto: completed orders → no payout |
| 17 | WhatsApp ring signals when trigger fires | Social graph clustering; >15 policies from same graph in 5 min → flagged |
| 18 | Synthetic accounts with fake GPS history | Minimum 4-week GPS history required for claim eligibility |
| 19 | Old phone clock set wrong | All timestamps NTP-synced server-side |
| 20 | Partner spoofs location hours after disruption ended | Parametric window hard-closed; GPS must fall within trigger window |

### Category B: Coordinated Collusion Rings (Scenarios 21–35)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 21 | 50 accounts registered with family members | 1:1 national ID to policy (Aadhaar hash UNIQUE constraint) |
| 22 | Corrupt sub-vendor confirms fake orders | Oracle uses central Swiggy API, not sub-vendor data |
| 23 | Shop owner colludes to confirm presence | Social proofing is supporting signal only, never primary gate |
| 24 | Corrupt weather sensor reports false rainfall | Multi-oracle voting; single sensor cannot swing consensus |
| 25 | Ghost merchant pins in OSM to validate zone | Swiggy real-time merchant density used, not OSM |
| 26 | Insider sets payout threshold artificially low | All threshold changes require cryptographic dual-approval; immutably logged |
| 27 | Ring probes with small claims before coordinated attack | Velocity limiter: max 3 claims/90-day rolling window |
| 28 | Partners rotate between cities for simultaneous disruptions | One active policy per GPS home zone per week |
| 29 | Referral farming — 200 recruits, day-1 claims | 60-day zero-claims period before referral bonus credited |
| 30 | Lawyer-fronted ring files identical appeal templates | Auto-reject duplicate appeal structures; ML clustering for boilerplate |
| 31 | Insider field agent corrupts manual audit | Field agents randomized; cannot audit own-zone partners |
| 32 | Reputational pressure campaign forces manual override | Claims engine fully automated; no human override pathway |
| 33 | Ring monitors oracle cron schedule | Oracle polling randomized ±8 minutes; schedule never exposed |
| 34 | Ring registers using stolen KYC | Biometric liveness at activation defeats static-ID theft |
| 35 | Deepfake video for liveness check | iProov deepfake detection API; micro-lighting artifact analysis |

### Category C: Actuarial and Pricing Model Failures (Scenarios 36–55)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 36 | Zone over-exposed to frequent rain | Zone-specific pricing multipliers |
| 37 | Cyclone hits 10,000 policies simultaneously | Reinsurance treaty >1,000 simultaneous policyholders |
| 38 | Platform-wide outage affects 50,000 policies | Policy count cap per oracle type (max 5,000 per outage trigger) |
| 39 | ML model drifts as climate changes | Weekly model retraining; auto-escalation if loss ratio >80% |
| 40 | New city with no historical data | Proxy-zone KNN bootstrap + 1.25× conservative multiplier |
| 41 | Platinum tier drains reserve disproportionately | Tier-wise reserve buckets: Silver/Gold/Platinum isolated |
| 42 | Tier-upgrade then immediate claim | 5-day tier-upgrade waiting period |
| 43 | Loss ratio 1020% due to fundamental pricing error | Actuarial floor: minimum premium ≥ expected_claims formula |
| 44 | Inflation erodes coverage value | Annual coverage indexation tied to CPI |
| 45 | High earner on Silver tier undercovered | Optional income-linked auto-upgrade pathway |
| 46 | Two disruptions in same week; partner claims twice | Max 1 successful payout per 7-day cycle |
| 47 | 3 AM outage; zero delivery volume | Payouts prorated against historical hourly earnings profile |
| 48 | Competitor undercuts at ₹29/week | Silver is loss-leader; cross-subsidy from Platinum margins |
| 49 | Partner cancels mid-week after disruption announced | Cancellations effective only at current cycle end |
| 50 | Same-day enrollment during live disruption | 72-hour activation delay |
| 51 | 180+ claim-days/year in specific zone | Per-zone annual claim day cap; premium auto-escalation |
| 52 | Exchange rate swings make reinsurance expensive | Reinsurance locked at multi-year fixed INR rates |
| 53 | Election period loosens trigger interpretation | Only machine-parseable municipal advisory codes qualify |
| 54 | Partner on leave (no GPS) claims for disruption | Claims require ≥2 hours active GPS movement on claim day |
| 55 | Premium pool in volatile assets | Pool in RBI-approved low-risk instruments only (T-bills, liquid funds) |

### Category D: Oracle Data Manipulation (Scenarios 56–70)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 56 | IMD API returns stale cached rainfall | 15-minute data TTL; stale = abstention |
| 57 | Downdetector rate-limited during actual outage | Primary + 2 fallback outage oracles |
| 58 | Silent Zomato/Swiggy API change breaks detection | Daily smoke tests on all external oracle endpoints |
| 59 | IMD rain gauge hardware fault, reports 0mm | Cross-validate with NASA GPM satellite precipitation |
| 60 | Forged municipal RSS advisory | Advisory validated by PGP cert from issuing municipality |
| 61 | DNS hijack redirects oracle to attacker server | TLS certificate pinning; unexpected cert → vote nullified |
| 62 | Satellite weather vendor goes bankrupt | Multi-vendor contracts with automatic failover |
| 63 | Burst pipe misclassified as weather event | Only IMD hydro-meteorological events qualify |
| 64 | Minor latency misclassified as platform outage | "Outage" requires ≥35% complaint spike AND multi-location ping timeout |
| 65 | Oracle consensus tie: 2 yes, 2 no | Tie-break: weighted by historical oracle accuracy |
| 66 | Rainfall ends 10 min before threshold | Trigger evaluated on 2-hour rolling window; brief cessation doesn't reset |
| 67 | Two cities with same name (geographic collision) | All zones identified by unique WGS84 polygon IDs, not names |
| 68 | All oracles offline during mega-storm | Benefit-of-doubt: ≥2 offline + ≥1 affirm → 50% payout cap |
| 69 | DoS flood of oracle ingestion queue | Rate-limited per source IP; duplicates filtered by signature hash |
| 70 | Notification delay after oracle confirms | P95 notification latency target <90 seconds from trigger to push |

### Category E: Regulatory and Legal Edge Cases (Scenarios 71–82)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 71 | IRDAI classifies Continuum as unauthorized insurance | Structure as income protection indemnity; IRDAI sandbox license Year 1 |
| 72 | State government bans micro-insurance | Governed by central IRDAI framework; state bans preempted by federal law |
| 73 | Payout delayed >24 hours — consumer complaint | SLA: 2 hours; breach triggers automatic 10% bonus compensation |
| 74 | GST rules change; premiums subject to 18% GST | Premiums GST-inclusive; tax changes absorbed into margin for current cycle |
| 75 | Lawsuit: payout didn't cover full day's income | Policy explicitly states coverage = flat-rate daily benefit, not indemnity |
| 76 | DPDP Act demands deletion of all GPS history | GPS hashed/aggregated post-claim; raw coordinates deleted after 60 days |
| 77 | Death of delivery partner during flood; family claims | Policy explicitly excludes death/injury; payout for living active accounts only |
| 78 | Partner zone crosses two municipal boundaries | Payout zone = partner's GPS centroid municipality |
| 79 | Partner disputes via consumer arbitration | 48-hour fast-track appeal; SEBI-approved arbitration if unresolved |
| 80 | Continuous GPS tracking challenged as unconstitutional | GPS opt-in; opt-out preserves enrollment but forfeits claim eligibility |
| 81 | Flood in adjacent zone; partner stranded | Adjacency grace: bordering zones receive 50% payout |
| 82 | Curfew advisory issued 11:59 PM on last policy day | Trigger during active policy window → full week's payout honored |

### Category F: Systemic and Black Swan Events (Scenarios 83–100)

| # | Scenario | Primary Defense |
|---|----------|----------------|
| 83 | Catastrophic earthquake; platform infrastructure down | Pre-authorized emergency payout via offline SMS |
| 84 | UPI/NPCI payment rails down nationally | 24-hour payment queue; Razorpay wallet escrow |
| 85 | All 3 cloud regions simultaneous outage | Multi-cloud active-active; cold standby DB |
| 86 | Fake news about fabricated Continuum payouts goes viral | All claims validated by oracles; social media has zero weight |
| 87 | Swiggy terminates all city partners | Platform-initiated terminations are explicit exclusion |
| 88 | Climate change makes 1-in-100-year floods happen every 3 years | Annual actuarial review with climate adjustment; proactive reserve increase |
| 89 | Nationwide internet shutdown during protests | Pre-authorize payouts for affected zones; disburse on restoration |
| 90 | Partner's UPI SIM-swapped during payout | 6-hour SIM-change cooling period + biometric reconfirmation |
| 91 | Competitor reverse-engineers oracle thresholds | Thresholds dynamic, ML-computed weekly, never publicly disclosed |
| 92 | Exchange rate collapse makes INR payouts worthless | Domestic INR-only; not applicable in Indian market |
| 93 | Geomagnetic storm disables GPS over India | Cellular triangulation full fallback; if both fail, benefit-of-doubt payout |
| 94 | Partner moves to high-risk zone weekly (zone-hopping) | 3-claim/90-day velocity cap triggers manual review hold |
| 95 | Continuum employee leaks fraud-detection rulebook | Fraud detection is a black-box ML model; no human-readable rules to leak |
| 96 | Partner account hacked; fraudster claims | Payout destination (UPI) locked 24 hours after credential change |
| 97 | Dust storm not covered by "flood" trigger | Adverse weather oracle covers all IMD red-alert events (dust, cold, heat) |
| 98 | Light drizzle detected; partners work normally | Trigger threshold is ≥50mm/2h; IMD formal alert classification required |
| 99 | Religious festival voluntary shutdown claimed as curfew | Only government-mandated, machine-parseable curfew orders qualify |
| 100 | Continuum itself becomes insolvent | 90-day reserves in escrow; IRDAI solvency margins enforced |

---

## 4. Oracle Security Controls

### 4.1 Certificate Pinning Implementation

The `_get_pinned_fingerprints()` function in `services/oracle_engine/oracles.py` reads expected SHA-256 fingerprints from environment variables with dual-pin support:

- `ENV_VAR` — current certificate fingerprint
- `ENV_VAR_NEXT` — rotation slot fingerprint

Both are accepted during a rotation window, enabling zero-downtime certificate rotation.

### 4.2 Oracle Failure Rate Monitoring

Prometheus metric `oracle_failure_rate` (gauge) tracks cumulative failure rate per oracle. Alert `OracleHighAbstentionRate` fires when any oracle's rate exceeds 40% over 15 minutes — surfacing degraded oracles before they compromise consensus integrity.

### 4.3 Abstention Rate as Safety Mechanism

When an oracle abstains (data timeout, stale data, hardware fault), the abstention is tracked but does NOT reduce the affirmative threshold. The system requires the configured number of positive affirmative votes from the full oracle set — not a majority of responding oracles. This is a critical distinction: a partial oracle failure cannot lower the bar for trigger authorization.

---

## 5. Financial Security Controls

### 5.1 Overdraw Prevention via Serialized Ledger

The double-entry ledger uses `SELECT ... FOR UPDATE` to serialize reserve access:

```sql
-- ledger.js (services/core_backend/src/services/ledger.js)
BEGIN;
SELECT balance FROM ledger_accounts
  WHERE account_id = 'RESERVE_MAIN' FOR UPDATE;
-- balance check here
INSERT INTO ledger_entries (debit_account, credit_account, amount, ...);
UPDATE ledger_accounts SET balance = balance - amount
  WHERE account_id = 'RESERVE_MAIN';
COMMIT;
```

CockroachDB's serializable isolation guarantees that no two concurrent transactions can simultaneously read and then debit the same balance — the classic overdraw race condition is eliminated.

### 5.2 Immutable Audit Trail

Every financial movement creates a `ledger_entries` record. These records are never updated or deleted. The `reference_type` and `reference_id` columns link each entry to the originating payout or premium event. This creates an immutable, auditable financial journal.

### 5.3 Payout Oracle Vote Archive

Every payout record in CockroachDB stores the full `oracle_votes` as JSONB:
```json
{
  "oracle_votes": [
    {"oracle_name": "IMD", "vote": "affirm", "polled_at": "...", "tls_valid": true},
    {"oracle_name": "AccuWeather", "vote": "affirm", "polled_at": "...", "tls_valid": true},
    ...
  ]
}
```

This ensures every automated payout decision is permanently auditable.

### 5.4 Reserve Floor Alert

Prometheus `ReserveLow` alert fires when `reserve_balance_inr < 100000` (₹100,000) for more than 5 minutes, triggering operational escalation before solvency margin is breached.

---

## 6. IRDAI 11-Point Compliance Audit

| # | IRDAI Requirement | Implemented Control | Files |
|---|------------------|---------------------|-------|
| 1 | AQI/CPCB oracle for outdoor worker safety | CPCB CAAQMS integration in oracle engine | `oracle_engine/oracles.py` |
| 2 | Event-type-weighted oracle consensus | Separate oracle sets per trigger type; dynamic threshold | `oracle_engine/engine.py` |
| 3 | UPI eNACH mandate premium collection | PayU eNACH mandate lifecycle with webhook-driven transitions | `routes/mandates.js`, `services/upi_mandate.js` |
| 4 | Forecast-driven enrollment lockout | Zone lock on 72h IMD forecast; HTTP 423 on enrollment | `routes/policies.js`, `zone_enrollment_locks` table |
| 5 | Double-entry financial ledger | CockroachDB double-entry with serialized transactions | `services/ledger.js`, migration `004_double_entry_ledger.sql` |
| 6 | PostGIS adjacency grace | ST_Touches spatial query for border-zone partial payout | `claims_scoring/src/checks/spatial.rs` |
| 7 | Proxy-zone bootstrap for data-sparse zones | KNN k=3 bootstrap + 1.25× risk margin multiplier | `risk_profiler/feature_builder.py` |
| 8 | Payout SLA metrics and alerting | Prometheus histogram + SLA breach counter + alert | `oracle_alerts.yml`, `services/metrics.js` |
| 9 | Aadhaar/device uniqueness constraints | Database-level UNIQUE partial indexes | migration `003_identity_uniqueness.sql` |
| 10 | Model provenance verification | SHA-256 hash check of isolation_forest.joblib at startup | `isolation_forest_sidecar/sidecar.py`, `model_card.json` |
| 11 | DPDP Act consent and 30-day proximity log retention | `proximity_consent` flag, pg_cron auto-purge after 30 days | migration `004_dpdp_proximity_retention.sql` |

---

## 7. DPDP Act 2023 Compliance

### 7.1 Proximity Data Consent

Device Bluetooth and WiFi proximity data used for fraud detection (Layer 3 — population-level anomaly detection) requires **explicit, separate consent**:

```sql
-- workers table
proximity_consent     BOOLEAN DEFAULT FALSE,
consent_granted_at    TIMESTAMPTZ
```

Partners can grant or withdraw consent at any time through the app. Withdrawal of proximity consent does not affect enrollment status but removes the partner from proximity-based fraud flagging.

### 7.2 Automatic 30-Day Proximity Log Purge

```sql
-- db/migrations/postgres/004_dpdp_proximity_retention.sql
-- pg_cron scheduled job at 03:00 daily
DELETE FROM device_proximity_log
  WHERE recorded_at < NOW() - INTERVAL '30 days';
```

An application-level fallback ensures purging occurs even if `pg_cron` is unavailable.

### 7.3 Aadhaar Storage

Aadhaar numbers are stored **only as a one-way SHA-256 hash** (`aadhaar_hash` column). The original Aadhaar number is never stored in the database, never logged, and never transmitted after the hashing step. This complies with UIDAI guidelines on Aadhaar data storage.

### 7.4 GPS Data Minimization

Raw GPS coordinates in the `gps_activity` table are:
- Range-partitioned by day (TimescaleDB) to enable efficient time-bounded deletion
- Deleted after 60 days for non-claim records
- For claimed events, only aggregated zone-presence data is retained post-claim; raw coordinates are deleted

### 7.5 Opt-Out Pathway

Partners who wish to disable GPS telemetry may do so while retaining enrollment status. Partners who disable required telemetry become ineligible for claims during the disabled period — as disclosed in the Terms and Conditions (Section 13.4).

---

## 8. Liability and Legal Safety

### 8.1 Liability Cap

Continuum's maximum liability for any single claim event is limited to the **applicable policy benefit cap** for the partner's enrolled tier:
- Silver: ₹500
- Gold: ₹1,000
- Platinum: ₹2,000

Continuum is not liable for indirect, incidental, special, or consequential losses beyond stated policy benefits.

### 8.2 Standard Exclusions (Legal Encoding)

All exclusions in Section 5 of this document are formally encoded in the Terms and Conditions (`docs/06_terms_and_conditions.md`, Section 9). These exclusions align with:
- Lloyd's of London LMA5400 series war exclusion clauses
- Swiss Re pandemic exclusion frameworks
- IRDAI parametric micro-insurance product exclusion standards

### 8.3 No Consequential Damages

To the maximum extent permitted by applicable Indian law, Continuum is not liable for:
- Loss of profit beyond the policy benefit
- Business disruption beyond the direct payout cap
- Indirect or consequential losses of any kind

### 8.4 Consumer Rights Preservation

All mandatory consumer rights under applicable Indian law — including the Consumer Protection Act 2019 — remain unaffected by any contractual terms, including arbitration clauses.

### 8.5 Dispute Resolution Pathway

1. **Automatic SLA compensation:** Payout SLA breach (>2 hours) → automatic 10% bonus credit applied without partner action
2. **Internal fast-track:** 48-hour review of contested claim denials
3. **Arbitration:** SEBI-approved third-party arbitration where contractually valid
4. **Consumer court:** Partner's right to approach consumer forums is unaffected

---

## 9. Security Controls Master Table

| Control | Layer | Enforcement Point | Implementation | Test Coverage |
|---------|-------|------------------|----------------|--------------|
| Device fingerprint 1:1 binding | 1 | Database | UNIQUE partial index on `device_fingerprint` | `tests/test_policies.test.js` |
| Aadhaar hash uniqueness | 1 | Database | UNIQUE partial index on `aadhaar_hash` | `tests/test_policies.test.js` |
| Play Integrity attestation | 1 | Mobile SDK + Backend | Android attestation API; mobile-side enforcement | Manual QA |
| Biometric liveness on claim | 1 | FastAPI gateway | iProov API integration | `tests/test_gateway.py` |
| Cell-ID cross-reference | 2 | Rust scoring service | Spatial check with `LOCATION_MISMATCH` flag | `tests/test_claims_scoring.rs` |
| 45-minute soak period | 2 | Rust scoring service | Pre-trigger GPS history query | `tests/test_claims_scoring.rs` |
| 3-timestamp temporal consistency | 2 | Rust scoring service | GPS activity table query | `tests/test_claims_scoring.rs` |
| Platform order veto | 2 | Rust scoring service | Swiggy/Zomato API cross-reference | `tests/test_claims_scoring.rs` |
| Geographic convergence freeze | 3 | Core backend | Zone-level concurrent claim count check | `tests/test_policies.test.js` |
| Proximity clustering detection | 3 | PostgreSQL | `device_proximity_log` + DPDP consent | Migration + manual QA |
| 90-day velocity cap | 3 | Rust scoring service | `claims` table rolling window query | `tests/test_claims_scoring.rs` |
| Event-type oracle sets | 4 | Oracle engine | `ORACLE_SETS` map + `_resolve_clients()` | `tests/test_oracle_engine.py` |
| 15-minute staleness TTL | 4 | Oracle engine | `apply_staleness_rule()` | `tests/test_oracle_engine.py` |
| TLS certificate pinning | 4 | Oracle engine | SHA-256 fingerprint verification | `tests/test_oracle_engine.py` |
| Randomized polling schedule | 4 | Oracle engine | ±8 min jitter on cron interval | Architecture control |
| Enrollment lockout (HTTP 423) | 4 | Core backend | `zone_enrollment_locks` table check | `tests/test_policies.test.js` |
| 72-hour activation delay | 5 | Database + Backend | `claim_eligible_from` column | `tests/test_policies.test.js` |
| 5-day tier-upgrade wait | 5 | Database + Backend | Upgrade timestamp check | `tests/test_policies.test.js` |
| Cancellation cycle lock | 5 | Core backend | Cycle boundary check on cancellation | `tests/test_policies.test.js` |
| 60-day referral bonus hold | 5 | Core backend | Claims history check before bonus credit | Manual QA |
| Serialized reserve debit | Financial | CockroachDB | `SELECT FOR UPDATE` in ledger service | `tests/test_ledger.test.js` |
| Immutable ledger entries | Financial | CockroachDB | No UPDATE/DELETE on `ledger_entries` | `tests/test_ledger.test.js` |
| Oracle vote audit trail | Financial | CockroachDB | `oracle_votes` JSONB on `payouts` | `tests/test_payouts.test.js` |
| Model provenance check | ML | Sidecar startup | SHA-256 hash against `model_card.json` | Unit test in sidecar |
| DPDP 30-day proximity purge | Privacy | PostgreSQL pg_cron | Scheduled DELETE job | Migration `004` |
| Aadhaar one-way hash | Privacy | Application layer | SHA-256 at enrollment, never stored plaintext | `tests/test_auth_middleware.test.js` |
| Advisory PGP signature validation | Oracle | Oracle engine | Signature check on RSS advisory feeds | `tests/test_oracle_engine.py` |
| Reserve low alert | Financial | Prometheus | `reserve_balance_inr < 100000` alert | `infra/prometheus/oracle_alerts.yml` |
| SLA breach alert | SLA | Prometheus | `payout_sla_breach_total` counter + alert | `infra/prometheus/oracle_alerts.yml` |
