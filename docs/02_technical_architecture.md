# Continuum — Technical Architecture

**Version:** 1.0  
**Effective Date:** 2026-04-17  
**Classification:** Technical / Due Diligence  
**Audience:** Engineering team, technical due diligence reviewers

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Service Catalog](#2-service-catalog)
3. [End-to-End Payout Data Flow](#3-end-to-end-payout-data-flow)
4. [Oracle Engine](#4-oracle-engine)
5. [Claims Scoring Pipeline](#5-claims-scoring-pipeline)
6. [Risk Profiler](#6-risk-profiler)
7. [BullMQ Queue Architecture](#7-bullmq-queue-architecture)
8. [UPI eNACH Mandate Lifecycle](#8-upi-enach-mandate-lifecycle)
9. [Double-Entry Financial Ledger](#9-double-entry-financial-ledger)
10. [Database Schema](#10-database-schema)
11. [Kafka Topics and Event Flows](#11-kafka-topics-and-event-flows)
12. [ML Models and Provenance](#12-ml-models-and-provenance)
13. [Infrastructure and Deployment](#13-infrastructure-and-deployment)
14. [Monitoring and Observability](#14-monitoring-and-observability)

---

## 1. System Overview

Continuum is a **polyglot microservice architecture** built for financial-grade reliability at gig-worker scale. The system is composed of 11 application microservices and 3 infrastructure containers, all orchestrated via Docker Compose and communicating over a shared Docker bridge network (`continuum_net`).

The architecture prioritizes:
- **Determinism** — parametric payouts follow strict rule-based logic with no human judgment
- **Fault tolerance** — oracle failures, payment rail outages, and data-source timeouts all have explicit fallback paths
- **Financial integrity** — double-entry ledger with serialized transactions prevents concurrent overdraw
- **Anti-fraud layering** — fraud controls are distributed across Rust scoring, Python anomaly detection, and database constraints

The system currently runs on a **single Azure B-Series VM** (IP: `4.186.27.77`) in a Docker Compose topology. All inter-service communication is within the `continuum_net` bridge network; only the ports listed in the Service Catalog are externally exposed.

---

## 2. Service Catalog

| Service | Technology | Internal Port | External Port | Role |
|---------|-----------|--------------|--------------|------|
| `fastapi_gateway` | Python / FastAPI | 8000 | 8000 | REST gateway — proof upload, claim processing entry point |
| `rag_orchestrator` | Python / LlamaIndex | 8001 | 8001 | RAG knowledge retrieval — policy Q&A, BGE-Large embeddings |
| `rasa_assistant` | Python / Gemini API | 8002 | 8002 | In-app conversational support bot with multilingual support |
| `web_intelligence` | Python / ScrapeGraph | 8003 | 8003 | LLM-powered scraping of municipal advisories and disruption news |
| `core_backend` | Node.js / Express | 3000 | 3000 | Primary REST API — policy management, payouts, claims, auth |
| `claims_scoring` | Rust / Axum | 8080 | 8080 | Fraud scoring service — composite score, routing decision |
| `isolation_forest_sidecar` | Python | Unix socket | — | Anomaly detection sidecar; IPC via `/tmp/isolation_forest.sock` |
| `kg_cache` | Go | 8080 (internal) | 8004 | Knowledge graph cache for disruption data from web_intelligence |
| `crew_ai` | Python / CrewAI | — | — | Multi-agent orchestration for claim pipeline steps |
| `oracle_engine` | Python | — | — | Oracle polling, consensus, Kafka publisher |
| `risk_profiler` | Python / FastAPI | — | — | 16-dim feature vector assembly + Gradient Boosting premium |
| `postgres` | PostgreSQL 15 | 5432 | 5432 | Workers, policies, claims, KYC, zone data |
| `redis` | Redis Alpine | 6379 | 6379 | BullMQ job queue backing store |
| `kafka` + `zookeeper` | Confluent 7.4.0 | 9092 / 2181 | 9092 | Event streaming — oracle triggers, payout events, fraud alerts |

**Shared volume:** `continuum_shared_temps` — mounted by both `claims_scoring` and `isolation_forest_sidecar` to share the Unix socket at `/tmp/isolation_forest.sock`.

---

## 3. End-to-End Payout Data Flow

The complete path from oracle detection to UPI credit:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Oracle Engine                                                │
│    - Polls IMD, AccuWeather, NASA GPM, CPCB, Downdetector      │
│    - Randomized ±8 min schedule (never externally exposed)      │
│    - Applies 15-min staleness TTL (stale → abstention)         │
│    - Evaluates event-type-specific consensus threshold          │
│    - If authorized → publishes to Kafka: oracle_trigger         │
└────────────────────────────┬────────────────────────────────────┘
                             │ Kafka: oracle_trigger
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Core Backend (Kafka Consumer)                               │
│    - Consumes oracle_trigger event                             │
│    - Looks up all active policies in triggered zone            │
│    - Checks zone enrollment locks (adverse selection control)  │
│    - Enqueues payout_disbursement job in BullMQ                │
└────────────────────────────┬────────────────────────────────────┘
                             │ BullMQ: payout_disbursement queue
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Claims Scoring Service (Rust/Axum, port 8080)              │
│    - Spatial check: PostGIS zone membership + adjacency grace  │
│    - Cell-ID divergence check: mismatch >2km → LOCATION_MISMATCH│
│    - Soak period check: ≥45 min pre-trigger GPS presence       │
│    - Platform order cross-reference: completed orders → VETO   │
│    - Frequency check: >3 claims/90 days → velocity cap exceeded│
│    - Isolation Forest score via Unix socket sidecar IPC        │
│    - Composite: 0.4×spatial + 0.2×frequency + 0.4×IF_score   │
│    - Route: score ≥ 0.7 → AUTO_APPROVED                       │
│             hard overrides → FRAUD_QUEUE                        │
└────────────────────────────┬────────────────────────────────────┘
                             │ Kafka: claim_decision
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Payout Disbursement Processor                               │
│    - Validates mandate is ACTIVE                               │
│    - Debits reserve via double-entry ledger (SELECT FOR UPDATE)│
│    - Calls PayU UPI disbursement API                           │
│    - Records payout with oracle_votes JSONB for audit trail    │
│    - Publishes payout_authorized to Kafka                      │
│    - Updates payout Prometheus latency histogram               │
└────────────────────────────┬────────────────────────────────────┘
                             │ BullMQ: notification_dispatch queue
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Firebase Cloud Messaging                                    │
│    - Lock-screen push notification to partner's device         │
│    - Delivered via fcm_token stored in workers table           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Oracle Engine

**Location:** `services/oracle_engine/`  
**Technology:** Python, asyncio, structlog, Prometheus client

### 4.1 Oracle Sets by Event Type

Oracle sets are selected per event type. This prevents irrelevant oracles from voting on events outside their competency:

| Event Type | Oracle Set | Consensus Threshold |
|-----------|-----------|---------------------|
| `weather` | IMD Primary API, AccuWeather commercial, NASA GPM satellite, Ground sensors | 3-of-4 affirmative |
| `aqi` | CPCB CAAQMS API, Ground air quality sensors, IMD meteorological | 2-of-3 affirmative |
| `outage` | Downdetector, Synthetic ping (3+ geo-distributed), Platform API status | 2-of-3 affirmative |
| `curfew` | Municipal RSS feeds (PGP signature validated) | 1-of-1 (single authoritative source) |

The `_resolve_clients()` and `_resolve_threshold()` methods in `OracleConsensusEngine` dynamically select the oracle set and minimum threshold for each `run_cycle()` call. Threshold is `max(2, len(set) // 2 + 1)`.

### 4.2 Oracle Vote Types

Each oracle returns one of four vote types:

| Vote | Meaning |
|------|---------|
| `affirm` | Oracle data confirms the trigger condition is met |
| `deny` | Oracle data confirms the trigger condition is NOT met |
| `abstain` | Oracle data is unavailable or the 15-minute staleness TTL has expired |
| `nullified` | TLS certificate pinning verification failed; vote is discarded |

### 4.3 Staleness Rule

Oracle data carries a maximum TTL of **15 minutes**. Any `affirm` or `deny` vote whose `data_timestamp` is older than 15 minutes is converted to `abstain` before consensus evaluation. An abstaining oracle does **not** vote "yes" — it does not count toward the affirmative threshold.

### 4.4 Benefit-of-Doubt Protocol

When a catastrophic event physically damages data infrastructure:
- **Condition:** ≥2 oracles offline (abstain/nullified) AND ≥1 oracle affirms
- **Result:** Trigger authorized with a **50% payout cap** (`payout_cap = 0.5`)
- **Rationale:** Waiting for full oracle consensus during a disaster is a design failure

### 4.5 TLS Certificate Pinning

All external API calls use dual-pin rotation:
```python
def _get_pinned_fingerprints(env_var: str) -> list[str]:
    # Checks both ENV_VAR and ENV_VAR_NEXT (rotation slot)
    # Returns both fingerprints; a match against either is valid
```

Environment variables `IMD_CERT_FINGERPRINT`, `ACCUWEATHER_CERT_FINGERPRINT`, etc. (plus `_NEXT` variants) configure the expected SHA-256 fingerprints. A certificate mismatch produces a `nullified` vote and triggers a `oracle_tls_nullification` warning log.

### 4.6 Randomized Polling Schedule

Oracle polling intervals are randomized within **±8 minutes** around the base cron schedule. The schedule is never exposed externally, making it computationally infeasible to time fraudulent activity to the exact millisecond between sensor checks.

### 4.7 Prometheus Metrics

| Metric | Type | Labels |
|--------|------|--------|
| `oracle_polls_total` | Counter | `oracle_name` |
| `oracle_failures_total` | Counter | `oracle_name`, `reason` |
| `oracle_failure_rate` | Gauge | `oracle_name` |
| `oracle_trigger_authorized_total` | Counter | — |
| `oracle_trigger_denied_total` | Counter | — |
| `benefit_of_doubt_applied_total` | Counter | — |

---

## 5. Claims Scoring Pipeline

**Location:** `services/claims_scoring/`  
**Technology:** Rust, Axum, SQLx (PostgreSQL), Prometheus

### 5.1 Composite Fraud Score Formula

```
Fraud_Score = 0.4 × spatial_score
            + 0.2 × frequency_score
            + 0.4 × isolation_forest_score
```

All inputs and the final score are clamped to `[0.0, 1.0]`.

### 5.2 Routing Decision Tree

```
if platform_activity_veto → PLATFORM_ACTIVITY_VETO (no payout)
else if velocity_cap_exceeded OR soak_period_failed → FRAUD_QUEUE
else if Fraud_Score >= 0.7 → AUTO_APPROVED
else → FRAUD_QUEUE
```

Hard overrides (platform veto, velocity cap, soak period) take priority over the composite score. A partner who simultaneously completed deliveries during a claimed disruption window is vetoed regardless of their fraud score.

### 5.3 Spatial Check

**File:** `services/claims_scoring/src/checks/spatial.rs`

The spatial check validates:
1. Partner GPS coordinates fall within the triggered zone polygon (PostGIS query against PostgreSQL)
2. If outside the triggered zone but inside an `ST_Touches`-adjacent zone → `adjacency_grace: true`, `score` penalized proportionally
3. Cell-ID vs GPS mismatch > 2km → `LOCATION_MISMATCH` flag, `-0.3` spatial penalty applied

### 5.4 Frequency Check

- Queries `claims` table for successful claims by this `worker_id` in the trailing 90-day window
- `claims_90d >= 3` → `velocity_cap_exceeded = true` → forced FRAUD_QUEUE routing
- Frequency score: `1.0 - (claims_90d / 4.0)` clamped to `[0.0, 1.0]`

### 5.5 Isolation Forest Sidecar IPC

The Rust service communicates with the Python Isolation Forest sidecar via **Unix domain socket** at `/tmp/isolation_forest.sock` (shared via Docker named volume `continuum_shared_temps`).

Request: JSON payload with claim features  
Response: `{"score": float}` in `[0.0, 1.0]`  
Interpretation: Higher score = more "normal" (less anomalous) = less fraud risk

### 5.6 Adjacency Grace — PostGIS

When a claim falls in a zone adjacent to (but not inside) the triggered polygon:
- `ST_Touches(claim_zone_polygon, triggered_zone_polygon)` is TRUE
- Payout is set to **50% of the full tier benefit**
- Payout record flagged `adjacency_pro_rated = TRUE`, `adjacent_zone_id` stored

---

## 6. Risk Profiler

**Location:** `services/risk_profiler/`  
**Technology:** Python, FastAPI, asyncio, Gradient Boosting (scikit-learn)

### 6.1 16-Dimensional Feature Vector

| Index | Feature | Source |
|-------|---------|--------|
| 0 | `rainfall_mm_hr_current` | Weather API |
| 1 | `wind_speed_kmh_current` | Weather API |
| 2 | `temperature_c_current` | Weather API |
| 3 | `weather_event_freq_30d` | TimescaleDB |
| 4 | `flood_event_count_30d` | TimescaleDB |
| 5 | `cyclone_event_count_30d` | TimescaleDB |
| 6 | `aqi_event_count_30d` | TimescaleDB |
| 7 | `active_days_last_30` | PostgreSQL |
| 8 | `avg_daily_orders` | PostgreSQL |
| 9 | `platform_encoded` | PostgreSQL (0=Swiggy, 1=Zomato) |
| 10 | `tier_encoded` | PostgreSQL (0=Silver, 1=Gold, 2=Platinum) |
| 11 | `zone_risk_index` | PostgreSQL |
| 12 | `hour_of_day` | System clock (UTC) |
| 13 | `day_of_week` | System clock (UTC) |
| 14 | `month` | System clock (UTC) |
| 15 | `claim_velocity_90d` | PostgreSQL |

### 6.2 Three-Source Concurrent Fetch

The `FeatureBuilder` assembles features from three independent sources using `asyncio.gather`:

```
TimescaleDB (historical weather) ──┐
Weather API (current conditions)  ─┼─→ asyncio.gather → 16-dim vector
PostgreSQL (worker profile)       ──┘
```

Each source has a **500ms timeout**. On timeout or error, zone-level median values are substituted and the substitution is logged via structured logging (`source`, `features_substituted`, `reason`).

### 6.3 Data-Sparse Zone Handling

If a zone has fewer than **90 days of local event history**, the profiler:
1. Logs a `Sparse zone — using proxy-zone KNN bootstrap` warning
2. Fetches proxy-zone medians using KNN (k=3 nearest zones by geography)
3. Applies a **1.25× uncertainty multiplier** on the `risk_margin` component in the premium formula

### 6.4 Premium Formula (from `premium.py`)

```python
expected_loss      = risk_score × coverage_cap × zone_loss_ratio

if sparse_zone:
    effective_risk_margin = risk_margin × 1.25

technical_premium  = expected_loss + expense_load + fraud_load
                   + reinsurance_load + effective_risk_margin

if zone_loss_ratio > 0.80:
    escalation = 1 + (zone_loss_ratio − 0.80) × 2.5
    technical_premium *= escalation

final_premium = max(affordability_anchor, technical_premium)
```

All values use `Decimal` with `ROUND_HALF_UP` to prevent floating-point errors in financial calculations.

---

## 7. BullMQ Queue Architecture

**Location:** `services/core_backend/src/workers/`  
**Technology:** Node.js, BullMQ, Redis

### 7.1 Queue Inventory

| Queue Name | Processor | Purpose |
|-----------|-----------|---------|
| `premium_recalculation` | `premiumRecalculation.js` | Weekly re-pricing per active policy |
| `payout_disbursement` | `payoutDisbursement.js` | Execute validated payouts via PayU |
| `notification_dispatch` | `notificationDispatch.js` | Firebase push notifications |
| `fraud_review_escalation` | `fraudReviewEscalation.js` | Escalate FRAUD_QUEUE claims to manual review |
| `weekly_premium_debit` | `weeklyPremiumDebit.js` | Trigger UPI eNACH debit per mandate |

### 7.2 Retry and DLQ Strategy

All queues use **exponential backoff** with at most 5 attempts:

| Attempt | Delay |
|---------|-------|
| 1 | 1,000 ms |
| 2 | 2,000 ms |
| 3 | 4,000 ms |
| 4 | 8,000 ms |
| 5 | 16,000 ms |

After 5 failures, the job moves to the **Dead Letter Queue** (BullMQ failed set).

### 7.3 DLQ Monitor

A monitor runs every 5 minutes and checks for `payout_disbursement` jobs that have been in the DLQ for more than 24 hours. These are escalated by publishing a `fraud_alert` Kafka event with `alert_type: "dlq_escalation"`.

### 7.4 Thundering Herd Prevention — Weekly Debits

Weekly premium debit jobs for all active policies are spread across a **1-hour scheduling window**:

```
delayStep = 1_hour_ms / total_active_policies
job[i].delay = i × delayStep
```

This prevents Redis from being overwhelmed by simultaneous debit attempts at the billing cycle boundary.

### 7.5 Prometheus Metrics

| Metric | Labels |
|--------|--------|
| `bullmq_jobs_completed_total` | `queue_name` |
| `bullmq_jobs_failed_total` | `queue_name` |
| `bullmq_jobs_dlq_total` | `queue_name` |

Metrics server runs on port **9102** within the `core_backend` container.

---

## 8. UPI eNACH Mandate Lifecycle

**Location:** `services/core_backend/src/services/upi_mandate.js`, `src/routes/mandates.js`

### 8.1 Mandate State Machine

```
CREATED ──→ APPROVED ──→ ACTIVE ──→ PAUSED ──→ REVOKED
                              └──────────────→ FAILED
```

State transitions are driven by **PayU webhook events** received at `POST /mandates/webhook`. Webhook payloads are verified via HMAC signature (`x-payu-signature` header) before processing.

### 8.2 Database Storage

Mandates are stored in CockroachDB `mandates` table with:
- `status` — current lifecycle state (enumerated CHECK constraint)
- `last_debit_at` — timestamp of most recent debit attempt
- `last_debit_status` — `success | failed | pending`
- `provider_ref` — PayU transaction reference

Each debit attempt is separately recorded in `mandate_debits` for a full audit trail.

### 8.3 REST API

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/mandates` | POST | Worker JWT | Create a new mandate |
| `/mandates/policy/:policyId` | GET | Worker/Admin JWT | Get active mandate for a policy |
| `/mandates/webhook` | POST | HMAC signature | PayU state-change notifications |

---

## 9. Double-Entry Financial Ledger

**Location:** `services/core_backend/src/services/ledger.js`  
**Database:** CockroachDB (`004_double_entry_ledger.sql`)

### 9.1 Design Rationale

A single-row balance counter is vulnerable to **concurrent overdraw** under race conditions: two payout jobs reading the same balance simultaneously would each see sufficient funds and both proceed, collectively overdrawing the reserve.

The double-entry ledger eliminates this with `SELECT ... FOR UPDATE` row locking:

```sql
BEGIN;
SELECT balance FROM ledger_accounts
  WHERE account_id = 'RESERVE_MAIN'
  FOR UPDATE;                    -- exclusive row lock
-- balance check happens here
INSERT INTO ledger_entries (...);
UPDATE ledger_accounts SET balance = balance - amount WHERE account_id = 'RESERVE_MAIN';
COMMIT;
```

CockroachDB's serializable transaction isolation guarantees that concurrent transactions see a consistent view.

### 9.2 Core Accounts

| Account ID | Type | Role |
|-----------|------|------|
| `RESERVE_MAIN` | `reserve` | Primary payout reserve |
| `PREMIUM_INCOME` | `premium_income` | Incoming weekly premium credits |
| `PAYOUT_EXPENSE` | `payout_expense` | Outgoing payout debits |
| `REINSURANCE_FUND` | `reinsurance` | Reinsurance treaty capital |

### 9.3 Ledger Entry Schema

Every financial movement is recorded as an immutable double-entry:

```sql
ledger_entries (
  entry_id      UUID PRIMARY KEY,
  debit_account TEXT REFERENCES ledger_accounts,
  credit_account TEXT REFERENCES ledger_accounts,
  amount        DECIMAL(14,2) CHECK (amount > 0),
  reference_type TEXT,   -- e.g., 'payout', 'premium'
  reference_id  UUID,    -- payout_id or policy_id
  description   TEXT,
  created_at    TIMESTAMPTZ
)
```

Entries are never updated or deleted — they form an immutable audit trail of all financial movements.

---

## 10. Database Schema

### 10.1 PostgreSQL (Operational Data)

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `zones` | `zone_id`, `city`, `polygon` (PostGIS GEOMETRY), `risk_index` | Geographic zone definitions with spatial indexing |
| `workers` | `worker_id`, `platform`, `tier`, `zone_id`, `upi_id`, `fcm_token`, `sim_changed_at`, `aadhaar_hash`, `device_fingerprint`, `proximity_consent` | Partner identity and device binding |
| `gps_activity` | `worker_id`, `lat`, `lon`, `recorded_at` | Partner location history (TimescaleDB range-partitioned by day) |
| `risk_scores` | `worker_id`, `policy_id`, `risk_score`, `feature_vector`, `final_premium`, `model_version` | ML risk scoring output per premium cycle |
| `claims` | `claim_id`, `worker_id`, `zone_id`, `fraud_score`, `status`, `submitted_at`, `decided_at` | Claim submissions and scoring outcomes |
| `weather_events` | `zone_id`, `event_type`, `rainfall_mm`, `wind_kmh`, `recorded_at` | TimescaleDB hypertable for weather history |
| `agent_audit_log` | `claim_id`, `agent_name`, `action`, `payload` (JSONB) | CrewAI agent action audit trail |
| `zone_enrollment_locks` | `zone_id`, `event_type`, `expires_at`, `forecast_data` (JSONB) | Forecast-driven enrollment freeze records |
| `device_proximity_log` | `device_id_a`, `device_id_b`, `recorded_at` | DPDP-consented Bluetooth/WiFi proximity data (30-day TTL) |

**Identity uniqueness constraints:**
```sql
UNIQUE partial index workers_aadhaar_unique ON aadhaar_hash WHERE aadhaar_hash IS NOT NULL
UNIQUE partial index workers_device_unique ON device_fingerprint WHERE device_fingerprint IS NOT NULL
```

### 10.2 CockroachDB (Financial Data)

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `policies` | `policy_id`, `worker_id`, `tier`, `coverage_cap`, `weekly_premium`, `claim_eligible_from`, `billing_cycle_start`, `status` | Policy lifecycle and coverage terms |
| `payouts` | `payout_id`, `worker_id`, `claim_id`, `amount`, `oracle_votes` (JSONB), `adjacency_pro_rated`, `payu_txn_ref`, `status` | Payout records with full oracle vote audit |
| `premium_versions` | `policy_id`, `effective_date`, `risk_score`, `computed_premium` | Premium change history |
| `mandates` | `mandate_id`, `worker_id`, `policy_id`, `status`, `last_debit_status` | UPI eNACH mandate state |
| `mandate_debits` | `debit_id`, `mandate_id`, `amount`, `status`, `attempted_at` | Per-debit attempt records |
| `ledger_accounts` | `account_id`, `account_type`, `balance` | Double-entry account balances |
| `ledger_entries` | `entry_id`, `debit_account`, `credit_account`, `amount`, `reference_id` | Immutable financial journal |

### 10.3 MongoDB Atlas (Vector Store)

- **Collection:** `policy_chunks` — policy document text chunks for RAG
- **Vector index:** BGE-Large embeddings (1536-dim), configured via `db/mongodb/vector_index.json`
- **Features:** Pre-Filtering, Fast-Filtering, Re-Ranking
- **Purpose:** Powering the in-app assistant's policy knowledge retrieval

---

## 11. Kafka Topics and Event Flows

**Broker:** Confluent Kafka 7.4.0  
**Topic initialization:** `infra/kafka/create_topics.sh`

| Topic | Partitions | Retention | Published By | Consumed By |
|-------|-----------|-----------|-------------|-------------|
| `worker_onboarding` | 3 | 7 days | core_backend | crew_ai |
| `claim_submitted` | 3 | 7 days | fastapi_gateway | claims_scoring, crew_ai |
| `claim_decision` | 3 | 7 days | claims_scoring | core_backend |
| `payout_authorized` | 3 | 7 days | core_backend | crew_ai, notification worker |
| `oracle_trigger` | 3 | 7 days | oracle_engine | core_backend |
| `premium_updated` | 3 | 7 days | core_backend | notification worker |
| `fraud_alert` | 3 | 7 days | core_backend (DLQ monitor) | crew_ai, admin systems |

All topics use `cleanup.policy: delete` (not compacted). The `enrollment_lock` signal is not a separate Kafka topic — the oracle engine writes directly to the PostgreSQL `zone_enrollment_locks` table.

---

## 12. ML Models and Provenance

### 12.1 Isolation Forest (Anomaly Detection)

**Location:** `services/isolation_forest_sidecar/`  
**Model file:** `model/isolation_forest.joblib`  
**Training:** `train_model.py`

At sidecar startup, the model's SHA-256 hash is computed and verified against the expected hash in `model/model_card.json`. A hash mismatch causes the sidecar to refuse requests, preventing tampered models from scoring claims.

```python
# On startup
with open(MODEL_PATH, "rb") as f:
    actual_hash = hashlib.sha256(f.read()).hexdigest()
assert actual_hash == model_card["model_sha256"]
```

The `model_card.json` contains:
- `model_sha256` — expected SHA-256 of the joblib file
- `training_date`, `feature_count`, `n_estimators` — provenance metadata

### 12.2 Gradient Boosting (Risk Premium)

**Location:** `services/risk_profiler/`  
**Input:** 16-dimensional feature vector  
**Output:** `risk_score` in `[0.0, 1.0]`

The risk score is passed to `compute_final_premium()` in `premium.py` as the primary scaling factor for expected loss. The model is retrained weekly as part of the premium recalculation cycle.

### 12.3 RAG Pipeline

**Location:** `services/rag_orchestrator/`  
**Embeddings:** BGE-Large (HuggingFace)  
**Vector store:** MongoDB Atlas  
**Orchestration:** LangChain + LlamaIndex

Policy documents are chunked, embedded, and upserted to MongoDB Atlas. The in-app assistant queries the vector store using semantic similarity to answer partner questions about coverage, claims, and eligibility.

---

## 13. Infrastructure and Deployment

### 13.1 Full Stack Startup

```bash
docker compose up --build
```

This starts all 11 microservices and 3 infrastructure containers, creates the `continuum_net` bridge network, and mounts the shared Unix socket volume.

### 13.2 Azure Deployment — Current Live Endpoints

| Service | URL |
|---------|-----|
| FastAPI Gateway (Swagger) | http://4.186.27.77:8000/docs |
| RAG Orchestrator | http://4.186.27.77:8001 |
| Rasa Assistant | http://4.186.27.77:8002 |
| Web Intelligence | http://4.186.27.77:8003 |
| KG Cache | http://4.186.27.77:8004 |
| Core Backend | http://4.186.27.77:3000 |

### 13.3 Flutter Mobile App

- **Platform:** Android (primary), iOS (secondary)
- **Min SDK target:** Budget devices (₹8k–₹15k tier)
- **Offline resilience:** Hive/SQFlite offline-first persistence; syncs on network restore
- **Push notifications:** Firebase Cloud Messaging

### 13.4 Environment Variables

Copy `services/core_backend/.env.example` to `.env`:

```env
JWT_SECRET=<long random secret>
PORT=3000
DB_HOST=localhost / postgres (Docker)
DB_PORT=5432
DB_NAME=continuum
DB_USER=postgres
DB_PASSWORD=<password>
DB_SSL=false
KAFKA_BROKERS=localhost:9092 / kafka:9092 (Docker)
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

Certificate pin environment variables per oracle (set in container environment or `.env`):
```env
IMD_CERT_FINGERPRINT=<sha256-hex>
IMD_CERT_FINGERPRINT_NEXT=<sha256-hex-rotation-slot>
ACCUWEATHER_CERT_FINGERPRINT=<sha256-hex>
# ... etc for each oracle
```

---

## 14. Monitoring and Observability

### 14.1 Prometheus Scrape Targets

| Target | Port | Path |
|--------|------|------|
| Core Backend | 3000 | `GET /metrics` |
| BullMQ Worker | 9102 | `GET /metrics` |
| Oracle Engine | internal | Prometheus counters (no HTTP endpoint) |
| Claims Scoring | 8080 | `GET /metrics` |

### 14.2 Alert Rules

Defined in `infra/prometheus/oracle_alerts.yml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `OracleHighAbstentionRate` | `oracle_failure_rate > 0.4` for 15 min | critical |
| `PayoutSLABreach` | `increase(payout_sla_breach_total[1h]) > 0` | critical (immediate) |
| `ReserveLow` | `reserve_balance_inr < 100000` for 5 min | warning |

### 14.3 Structured Logging

Python services use **structlog** for JSON-structured logging. Key log events:
- `oracle_vote_converted_stale` — staleness conversion with before/after state
- `oracle_tls_nullification` — TLS pinning failure
- `benefit_of_doubt_applied` — emergency protocol activation
- `Feature substitution` — risk profiler source timeout with substituted features

Node.js services log to stdout in plain text with `[queue_name] Job ID status` format.
