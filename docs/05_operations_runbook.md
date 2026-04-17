# Continuum — Operations Runbook

**Version:** 1.0  
**Effective Date:** 2026-04-17  
**Classification:** Internal / Engineering / Operations  
**Audience:** Engineering team, DevOps, on-call engineers

---

## Table of Contents

1. [Prerequisites and Environment Setup](#1-prerequisites-and-environment-setup)
2. [Full Stack Startup](#2-full-stack-startup)
3. [Database Migration Order](#3-database-migration-order)
4. [Kafka Topic Initialization](#4-kafka-topic-initialization)
5. [Running Tests](#5-running-tests)
6. [Actuarial CI Gate](#6-actuarial-ci-gate)
7. [Prometheus Alert Runbooks](#7-prometheus-alert-runbooks)
8. [BullMQ Dead Letter Queue Procedure](#8-bullmq-dead-letter-queue-procedure)
9. [Oracle Failure Procedure](#9-oracle-failure-procedure)
10. [UPI Payment Rail Failure Procedure](#10-upi-payment-rail-failure-procedure)
11. [Weekly Premium Debit Operations](#11-weekly-premium-debit-operations)
12. [SIM-Swap Cooling Period](#12-sim-swap-cooling-period)
13. [Forecast Enrollment Lockout Management](#13-forecast-enrollment-lockout-management)
14. [Isolation Forest Model Update Procedure](#14-isolation-forest-model-update-procedure)
15. [Scaling and Capacity](#15-scaling-and-capacity)

---

## 1. Prerequisites and Environment Setup

### 1.1 Required Runtimes

| Runtime | Minimum Version | Used By |
|---------|----------------|---------|
| Node.js | 20.x | `core_backend` |
| Python | 3.11 | `oracle_engine`, `risk_profiler`, `fastapi_gateway`, `crew_ai`, `isolation_forest_sidecar`, `actuarial_lab`, `rag_orchestrator`, `rasa_assistant` |
| Rust / Cargo | Stable (2021 edition) | `claims_scoring` |
| Go | 1.21+ | `kg_cache` |
| Flutter / Dart | 3.19+ | Mobile app |
| PostgreSQL | 15 | `postgres` container |
| Docker + Docker Compose | Latest stable | All containerized services |

### 1.2 Environment Configuration

```bash
cd services/core_backend
cp .env.example .env
# Edit .env with actual values:
# JWT_SECRET=<long-random-secret>
# DB_HOST=localhost (or 'postgres' in Docker)
# DB_PASSWORD=<password>
# KAFKA_BROKERS=localhost:9092 (or 'kafka:9092' in Docker)
# FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

### 1.3 Oracle Certificate Pins

Set the following environment variables before starting the oracle engine. Use actual SHA-256 certificate fingerprints from each oracle's HTTPS endpoint:

```bash
IMD_CERT_FINGERPRINT=<sha256-hex>
IMD_CERT_FINGERPRINT_NEXT=<sha256-hex-rotation-slot>
ACCUWEATHER_CERT_FINGERPRINT=<sha256-hex>
NASA_GPM_CERT_FINGERPRINT=<sha256-hex>
CPCB_CERT_FINGERPRINT=<sha256-hex>
DOWNDETECTOR_CERT_FINGERPRINT=<sha256-hex>
```

Omitting these disables certificate pinning for the corresponding oracle (acceptable in development; required in production).

---

## 2. Full Stack Startup

### 2.1 Docker Compose (Recommended)

```bash
# Start all 11 microservices + 3 infra containers
docker compose up --build

# Start in background
docker compose up --build -d

# View logs for a specific service
docker compose logs -f oracle_engine
docker compose logs -f core_backend
docker compose logs -f claims_scoring

# Restart a single service after code change
docker compose up --build -d claims_scoring
```

### 2.2 Individual Service Startup (Local Development)

**Core Backend (Node.js):**
```bash
cd services/core_backend
npm install
npm run dev       # --watch mode, restarts on file change
# OR
npm start         # production start
```

**FastAPI Gateway (Python):**
```bash
cd services/fastapi_gateway
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

**Oracle Engine (Python):**
```bash
cd services/oracle_engine
pip install -r requirements.txt
python -m oracle_engine.main
```

**Risk Profiler (Python):**
```bash
cd services/risk_profiler
pip install -r requirements.txt
uvicorn main:app --reload --port 8005
```

**Claims Scoring (Rust):**
```bash
cd services/claims_scoring
cargo build --release
./target/release/claims_scoring
# With Kafka support:
cargo build --release --features kafka
```

**KG Cache (Go):**
```bash
cd services/kg_cache
go run .
```

**Isolation Forest Sidecar (Python):**
```bash
cd services/isolation_forest_sidecar
pip install -r requirements.txt
SOCKET_PATH=/tmp/isolation_forest.sock python sidecar.py
```

**Flutter Mobile App:**
```bash
flutter pub get
flutter run                    # targets connected device or emulator
flutter run --release         # release build
```

---

## 3. Database Migration Order

**Always run PostgreSQL migrations before CockroachDB migrations.** PostgreSQL holds the operational schema that CockroachDB financials depend on.

### 3.1 PostgreSQL Migrations

```bash
# Connect to PostgreSQL
psql -h localhost -U postgres -d continuum

# Run migrations in order
\i db/migrations/postgres/001_initial_schema.sql
\i db/migrations/postgres/002_enrollment_lock.sql
\i db/migrations/postgres/003_identity_uniqueness.sql
\i db/migrations/postgres/004_dpdp_proximity_retention.sql
```

Migration `001` creates the core schema including the PostGIS extension, TimescaleDB hypertable for `weather_events`, and all primary tables.

Migration `004` sets up the `device_proximity_log` table and the pg_cron scheduled job for DPDP 30-day auto-purge.

### 3.2 CockroachDB Migrations

```bash
# Connect to CockroachDB
cockroach sql --host=localhost --insecure --database=continuum

# Run migrations in order
\i db/migrations/cockroachdb/001_initial_schema.sql
\i db/migrations/cockroachdb/002_mandates.sql
\i db/migrations/cockroachdb/003_adjacency_payout.sql
\i db/migrations/cockroachdb/004_double_entry_ledger.sql
```

Migration `004` creates the double-entry ledger and seeds the four core accounts (`RESERVE_MAIN`, `PREMIUM_INCOME`, `PAYOUT_EXPENSE`, `REINSURANCE_FUND`) with ₹0.00 opening balances. After seeding, fund the `RESERVE_MAIN` account with the initial capitalization amount before enabling payouts.

### 3.3 MongoDB Atlas Setup

```bash
# Apply vector index definition
mongosh "mongodb+srv://..." --file db/mongodb/vector_index.json
```

---

## 4. Kafka Topic Initialization

Topics must be created before any service that produces or consumes Kafka messages is started.

```bash
# Initialize all 7 Kafka topics
bash infra/kafka/create_topics.sh
```

The script creates topics defined in `infra/kafka/topics.json`:

| Topic | Partitions | Retention |
|-------|-----------|-----------|
| `worker_onboarding` | 3 | 7 days |
| `claim_submitted` | 3 | 7 days |
| `claim_decision` | 3 | 7 days |
| `payout_authorized` | 3 | 7 days |
| `oracle_trigger` | 3 | 7 days |
| `premium_updated` | 3 | 7 days |
| `fraud_alert` | 3 | 7 days |

If topics already exist, the script is idempotent (existing topics are not modified).

---

## 5. Running Tests

### 5.1 Core Backend (Node.js / Jest)

```bash
cd services/core_backend
npm test                              # all tests (sequential)
npx jest tests/test_ledger.test.js   # single test file
npx jest --testNamePattern "reserve" # tests matching pattern
```

Test files in `services/core_backend/tests/`:
- `test_auth_middleware.test.js` — JWT auth + RBAC middleware
- `test_bullmq.test.js` — BullMQ queue and worker behavior
- `test_core_backend.test.js` — integration tests
- `test_fcm.test.js` — Firebase Cloud Messaging dispatch
- `test_ledger.test.js` — double-entry ledger, overdraw prevention
- `test_notification_dispatch.test.js` — notification pipeline
- `test_payouts.test.js` — payout disbursement flow
- `test_payu.test.js` — PayU integration
- `test_policies.test.js` — policy lifecycle, enrollment lock, waiting periods

### 5.2 Python Services (pytest)

```bash
# Oracle Engine
cd services/oracle_engine
pytest tests/ -v

# FastAPI Gateway
cd services/fastapi_gateway
pip install -r requirements-test.txt
pytest tests/ -v

# CrewAI
cd services/crew_ai
pytest tests/ -v

# RAG Orchestrator
cd services/rag_orchestrator
pytest tests/ -v
```

### 5.3 Rust Claims Scoring (cargo test)

```bash
cd services/claims_scoring
cargo test                            # all tests
cargo test scoring::tests             # specific module
cargo test -- --nocapture             # show stdout output
```

Property-based tests use the `proptest` crate to validate scoring invariants across random inputs.

### 5.4 Go KG Cache

```bash
cd services/kg_cache
go test ./... -v
```

### 5.5 Flutter Tests

```bash
flutter test
```

---

## 6. Actuarial CI Gate

The actuarial CI gate must pass before any release that changes pricing logic, reserve management, or oracle consensus behavior.

```bash
python -m services.actuarial_lab.ci_gate \
    --ts-dsn "postgresql://postgres:password@localhost:5432/continuum" \
    --crdb-dsn "postgresql://root@localhost:26257/continuum?sslmode=disable"
```

**Exit codes:**
- `0` — All checks pass; deployment can proceed
- `1` — One or more checks failed; **deployment must be blocked**

**What causes exit code 1:**
1. Rolling 13-week portfolio loss ratio > 100% in any backtest window
2. Any stress scenario produces reserve depletion < 90 days

**On failure:** Do not proceed with deployment. Review the structured log output identifying which backtesting window or stress scenario failed. Escalate to the actuarial reviewer.

---

## 7. Prometheus Alert Runbooks

Alerts are defined in `infra/prometheus/oracle_alerts.yml`. All three alerts page the on-call engineer.

### 7.1 `OracleHighAbstentionRate` — CRITICAL

**Condition:** `oracle_failure_rate > 0.4` for any oracle, sustained for 15 minutes  
**Meaning:** A specific oracle has been returning abstentions (failures, timeouts, or stale data) more than 40% of the time over the past hour. Oracle consensus may be degraded.

**Investigation steps:**
1. Check which oracle is failing: `oracle_failure_rate` metric label `oracle_name`
2. Check oracle API health directly:
   - IMD: Verify IMD API endpoint is reachable
   - AccuWeather: Check commercial API key validity and rate limits
   - NASA GPM: Check satellite data endpoint
   - CPCB CAAQMS: Check AQI data endpoint
3. Check oracle certificate expiry: If `oracle_tls_nullification` events appear in logs, the TLS pinned certificate may have been rotated by the provider
4. Check `IMD_CERT_FINGERPRINT` and `IMD_CERT_FINGERPRINT_NEXT` environment variables; update with new fingerprint if cert was rotated
5. Check network connectivity from `oracle_engine` container to external APIs
6. If abstention is persistent and oracle is confirmed down: benefit-of-doubt protocol activates automatically when ≥2 oracles are offline + ≥1 affirms

**Resolution:** Restore oracle connectivity or update certificate pin. Alert auto-resolves once `oracle_failure_rate` drops below 40% for 15 minutes.

---

### 7.2 `PayoutSLABreach` — CRITICAL (immediate)

**Condition:** `increase(payout_sla_breach_total[1h]) > 0` — any payout exceeded 2-hour SLA  
**Meaning:** At least one payout took more than 2 hours from oracle trigger authorization to UPI credit. Per the product SLA, an automatic 10% bonus compensation credit is triggered.

**Investigation steps:**
1. Check BullMQ queue depth for `payout_disbursement`:
   - Connect to Redis: `redis-cli -h localhost -p 6379`
   - `LLEN bull:payout_disbursement:waiting`
   - High queue depth = processing backlog
2. Check for stuck jobs in BullMQ:
   - `LLEN bull:payout_disbursement:failed` — failed jobs
   - `LLEN bull:payout_disbursement:active` — jobs currently processing
3. Check PayU API status: PayU outage or rate limiting delays disbursement
4. Check Redis connectivity from `core_backend`: Redis unavailability blocks BullMQ
5. Check worker logs:
   ```bash
   docker compose logs -f core_backend | grep payout_disbursement
   ```
6. Apply 10% bonus compensation credit to affected payout records

**Resolution:** Clear the queue backlog, resolve PayU or Redis connectivity issues. Alert does not auto-resolve (counter-based); acknowledge and resolve manually after investigation.

---

### 7.3 `ReserveLow` — WARNING

**Condition:** `reserve_balance_inr < 100000` (₹100,000) sustained for 5 minutes  
**Meaning:** The `RESERVE_MAIN` ledger account balance has fallen below ₹1,00,000. Immediate top-up action required to maintain the 90-day payout runway.

**Investigation steps:**
1. Query current reserve balance:
   ```sql
   SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN';
   ```
2. Calculate days of runway remaining:
   ```sql
   SELECT balance / (
     SELECT AVG(amount) * 7 FROM payouts 
     WHERE created_at > NOW() - INTERVAL '30 days'
   ) AS runway_days
   FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN';
   ```
3. If runway < 30 days: **halt new policy enrollments immediately** (update `zone_enrollment_locks` for all active zones)
4. Initiate reinsurance top-up procedure (contact reinsurance broker)
5. Notify CFO and actuarial reviewer

**Resolution:** Fund `RESERVE_MAIN` via ledger entry (debit external funding account, credit RESERVE_MAIN). Alert auto-resolves when balance exceeds ₹100,000 for 5 minutes.

---

## 8. BullMQ Dead Letter Queue Procedure

### 8.1 DLQ Monitor Behavior

The DLQ monitor (`services/core_backend/src/workers/index.js`) checks every **5 minutes** for `payout_disbursement` jobs that have been in the failed queue for more than 24 hours. These are escalated by publishing a `fraud_alert` Kafka event with:
```json
{
  "alert_type": "dlq_escalation",
  "queue": "payout_disbursement",
  "job_id": "...",
  "job_data": {...},
  "failed_at": "..."
}
```

### 8.2 Manual DLQ Inspection

```javascript
// Via BullMQ admin API or Redis CLI
// Get failed job count
LLEN bull:payout_disbursement:failed

// Via BullMQ Node.js API (in a temporary script):
const { Queue } = require('bullmq');
const queue = new Queue('payout_disbursement', { connection: { host: 'localhost', port: 6379 } });
const failedJobs = await queue.getFailed(0, 100);
```

### 8.3 Manual Retry

```javascript
// Retry a specific failed job
const job = await queue.getJob(jobId);
await job.retry();

// Retry all failed jobs
for (const job of failedJobs) {
  await job.retry();
}
```

### 8.4 Permanent Failure Action

If a `payout_disbursement` job cannot be retried (e.g., partner UPI account permanently invalid):
1. Mark the payout record as `failed` in CockroachDB `payouts` table
2. Create a ledger credit entry to reverse the reserve debit
3. Notify the partner via Firebase push notification and SMS
4. Create an internal support ticket for manual resolution

---

## 9. Oracle Failure Procedure

### 9.1 Automatic Benefit-of-Doubt Protocol

When **≥2 of 4 oracles are simultaneously offline** (abstain/nullified) AND **≥1 oracle affirms**, the benefit-of-doubt protocol activates automatically in `OracleConsensusEngine.check_benefit_of_doubt()`:
- Trigger is authorized
- Payout cap set to **50%** (`payout_cap = 0.5`)
- `benefit_of_doubt_applied_total` Prometheus counter incremented
- Log event `benefit_of_doubt_applied` emitted

No manual intervention required for this scenario.

### 9.2 Certificate Rotation

When an oracle provider rotates their TLS certificate:
1. Retrieve the new certificate fingerprint:
   ```bash
   openssl s_client -connect api.imd.gov.in:443 2>/dev/null | \
     openssl x509 -fingerprint -sha256 -noout
   ```
2. Update the `*_CERT_FINGERPRINT_NEXT` environment variable with the new fingerprint
3. After the old certificate expires, update `*_CERT_FINGERPRINT` and clear `_NEXT`
4. Restart `oracle_engine`: `docker compose up -d oracle_engine`

The dual-pin rotation slot ensures zero-downtime rotation — both old and new fingerprints are accepted during the transition window.

### 9.3 Oracle Vendor Replacement

If an oracle vendor goes offline permanently (Scenario 62 — vendor bankruptcy):
1. Update `ORACLE_SETS` in `services/oracle_engine/oracles.py` to replace the vendor client
2. Add new oracle client class implementing the `OracleClient` protocol
3. Update `ALL_ORACLE_CLIENTS` list
4. Rebuild and deploy `oracle_engine`
5. Verify new oracle is registering polls in `oracle_polls_total` metric

---

## 10. UPI Payment Rail Failure Procedure

### 10.1 Automatic Retry Behavior

When PayU or NPCI UPI rails are unavailable:
- `payout_disbursement` BullMQ jobs automatically retry with exponential backoff: 1s → 2s → 4s → 8s → 16s
- After 5 failures: job moves to DLQ
- DLQ monitor escalates jobs after 24 hours in DLQ

### 10.2 Razorpay Escrow Activation

For partners requiring immediate liquidity during a prolonged UPI outage:
1. Access Razorpay wallet escrow (configured in PayU integration)
2. Manually disburse from escrow to partner UPI IDs listed in the failed payout records
3. Record escrow disbursements as ledger entries:
   ```sql
   INSERT INTO ledger_entries (debit_account, credit_account, amount, reference_type, reference_id, description)
   VALUES ('RESERVE_MAIN', 'PAYOUT_EXPENSE', <amount>, 'payout_escrow', <payout_id>, 'Razorpay escrow interim disbursement');
   ```

### 10.3 Queue Drain After Rail Recovery

When UPI rails recover:
1. Retry all failed DLQ jobs (see Section 8.3)
2. Monitor `payout_sla_breach_total` — breached payouts should be tracked for bonus compensation credits
3. Verify all affected payout records are updated to `disbursed` status in CockroachDB

---

## 11. Weekly Premium Debit Operations

### 11.1 Scheduler Behavior

The weekly premium debit scheduler runs automatically when the `core_backend` starts. It:
1. Queries all active policies with `ACTIVE` mandate status
2. Spreads debit jobs across a 1-hour window (thundering herd prevention)
3. Each job triggers a `weeklyPremiumDebit` processor that calls the PayU eNACH debit API

**Do not restart `core_backend` at the billing cycle boundary** — this would re-trigger the scheduler and potentially double-schedule debit jobs. Schedule restarts for off-peak hours.

### 11.2 Failed Debit Handling

If a debit attempt fails (insufficient balance, mandate expired):
1. `mandate.last_debit_status` is updated to `failed`
2. `mandate_debits` record created with `status = failed` and `failure_reason`
3. If mandate fails repeatedly (≥3 consecutive failures): mandate transitions to `FAILED` state
4. Partner is notified via Firebase push and SMS to update payment method
5. Policy status transitions to `suspended` until mandate is re-authorized

### 11.3 Manual Debit Trigger

To trigger a manual debit for a specific policy (e.g., catch-up after a failed cycle):

```bash
# Enqueue a single weekly_premium_debit job via Redis
# (adjust job data as needed)
redis-cli LPUSH bull:weekly_premium_debit:waiting \
  '{"policy_id":"...","worker_id":"...","mandate_id":"...","amount":62.40}'
```

---

## 12. SIM-Swap Cooling Period

### 12.1 Behavior

When a partner's SIM changes (detected via `sim_changed_at` update in the `workers` table), all pending payout disbursements for that worker are held for **6 hours**.

The `payoutDisbursement` processor checks:
```javascript
const simChangedAt = new Date(worker.sim_changed_at);
const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
if (simChangedAt > sixHoursAgo) {
  // Hold payout; require biometric reconfirmation
}
```

### 12.2 Biometric Re-Confirmation

After the 6-hour cooling period, the partner must complete a biometric face scan in the app before the payout is released. This prevents SIM-swap fraudsters from redirecting funds to a new UPI number.

### 12.3 Monitoring

SIM-swap events can be monitored by querying:
```sql
SELECT worker_id, sim_changed_at
FROM workers
WHERE sim_changed_at > NOW() - INTERVAL '24 hours'
ORDER BY sim_changed_at DESC;
```

---

## 13. Forecast Enrollment Lockout Management

### 13.1 How Locks Are Created

The oracle engine publishes enrollment lock signals when IMD 72-hour forecasts predict high-risk events. Locks are written directly to the PostgreSQL `zone_enrollment_locks` table:

```sql
INSERT INTO zone_enrollment_locks (zone_id, event_type, expires_at, forecast_data)
VALUES ($1, $2, $3, $4)
ON CONFLICT (zone_id, event_type) DO UPDATE SET expires_at = $3, forecast_data = $4;
```

### 13.2 Effect on Enrollment

`POST /policies` checks for active locks:
```javascript
const lockResult = await db.query(
  `SELECT zone_id, event_type, expires_at FROM zone_enrollment_locks
   WHERE zone_id = $1 AND expires_at > NOW() LIMIT 1`,
  [zone_id]
);
if (lockResult.rows.length > 0) {
  return res.status(423).json({ error: 'enrollment_locked', expires_at: lock.expires_at });
}
```

### 13.3 Manual Lock Management

```sql
-- List all active locks
SELECT * FROM zone_enrollment_locks WHERE expires_at > NOW();

-- Manually remove a lock (e.g., false alarm forecast)
DELETE FROM zone_enrollment_locks WHERE zone_id = 'BLR_SOUTH' AND event_type = 'weather';

-- Manually add a lock
INSERT INTO zone_enrollment_locks (zone_id, event_type, expires_at, forecast_data)
VALUES ('MUM_CENTRAL', 'weather', NOW() + INTERVAL '72 hours', '{"forecast_source": "manual"}');
```

---

## 14. Isolation Forest Model Update Procedure

### 14.1 Retraining

```bash
cd services/isolation_forest_sidecar
python train_model.py
# Outputs: model/isolation_forest.joblib + updated model/model_card.json
```

`train_model.py` automatically:
1. Trains a new Isolation Forest model on current claim data
2. Computes the SHA-256 hash of the output joblib file
3. Updates `model_card.json` with the new hash, training date, and metadata

### 14.2 Deploying a New Model

```bash
# Copy new model files to sidecar directory
cp isolation_forest.joblib services/isolation_forest_sidecar/model/
cp model_card.json services/isolation_forest_sidecar/model/

# Restart sidecar (it verifies hash on startup)
docker compose up --build -d isolation_forest_sidecar

# Verify startup (should see "Model provenance verified" in logs)
docker compose logs isolation_forest_sidecar | grep provenance
```

If the hash in `model_card.json` does not match the joblib file, the sidecar will refuse to serve requests — preventing tampered models from scoring claims.

### 14.3 Rollback

If the new model produces unexpected scoring behavior:
1. Replace the model files with the previous version
2. Restart the sidecar: `docker compose up --build -d isolation_forest_sidecar`

---

## 15. Scaling and Capacity

### 15.1 Current Deployment

Single Azure B-Series VM running all services in Docker Compose. Suitable for prototype and early production with moderate policy counts.

### 15.2 Horizontal Scaling Path

| Service | Scaling Approach |
|---------|-----------------|
| `core_backend` | Multiple instances behind load balancer; Redis/BullMQ is already external |
| `claims_scoring` | Stateless; multiple instances with load balancer |
| `oracle_engine` | Single instance preferred; multiple instances risk duplicate kafka publishes — use leader election |
| `isolation_forest_sidecar` | Scale with `claims_scoring`; each instance has its own sidecar via Docker named volume |
| `postgres` | Read replicas for query load; master for writes |
| `redis` | Redis Cluster for high queue throughput |
| `kafka` | Increase partition count; add brokers |
| `cockroachdb` | Native horizontal scale; replace single-node with CockroachDB cluster |

### 15.3 BullMQ Throughput

Current configuration: 1 worker per queue, 500ms processing concurrency per job.

To increase throughput:
```javascript
// In createWorker(), increase concurrency
const worker = new Worker(queueName, processor, {
  connection: REDIS_CONNECTION,
  concurrency: 10,  // default is 1
});
```

### 15.4 Kafka Consumer Lag Monitoring

Monitor `claim_submitted` and `oracle_trigger` consumer lag to ensure the core backend is keeping up with events:

```bash
kafka-consumer-groups.sh --bootstrap-server kafka:9092 \
  --describe --group core-backend-consumer
```

High lag on `oracle_trigger` means payouts are delayed — scale `core_backend` workers or increase BullMQ concurrency.
