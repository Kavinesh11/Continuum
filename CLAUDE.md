# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Continuum** is a parametric income-protection insurance platform for gig delivery partners (Zomato/Swiggy). When a verified disruption occurs (weather, platform outage, lockdown), the system pays partners automatically via UPI — no claims form required. It was built for the Devtrails Guidewire Hackathon with IRDAI compliance as a design constraint.

Detailed documentation lives in `docs/`: product spec, technical architecture, security/compliance (all 100 adversarial scenarios), actuarial framework, operations runbook, and terms & conditions.

## Running the Full Stack

```bash
docker compose up --build    # starts all 11 services + 3 infra containers
```

Individual service startup for local development:

```bash
# Core backend (Node.js, port 3000)
cd services/core_backend && npm install && cp .env.example .env
npm run dev

# FastAPI gateway (Python, port 8000)
cd services/fastapi_gateway && pip install -r requirements.txt
uvicorn main:app --reload

# Flutter mobile app
flutter pub get && flutter run

# Claims scoring (Rust, port 8080)
cd services/claims_scoring && cargo build && cargo run

# Isolation Forest sidecar (must start before claims_scoring in local dev)
cd services/isolation_forest_sidecar
SOCKET_PATH=/tmp/isolation_forest.sock python sidecar.py
```

## Running Tests

```bash
# Node.js (core_backend)
cd services/core_backend && npm test
npx jest tests/test_ledger.test.js --runInBand   # single test file

# Integration tests (trigger-to-payout, requires live PostgreSQL with PostGIS + TimescaleDB)
cd tests/integration && npm install && npm test

# Python services (pytest)
cd services/oracle_engine && pytest tests/
cd services/fastapi_gateway && pip install -r requirements-test.txt && pytest tests/
cd services/crew_ai && pytest tests/

# Rust (claims_scoring)
cd services/claims_scoring && cargo test
cargo test scoring::tests    # single module

# Go (kg_cache)
cd services/kg_cache && go test ./...

# Flutter
flutter test

# Actuarial CI gate (requires live DB DSNs; exits 1 if loss ratio > 100% or reserve < 90 days)
python -m services.actuarial_lab.ci_gate \
  --ts-dsn "postgresql://..." \
  --crdb-dsn "postgresql://..."
```

`docker compose -f docker-compose.test.yml up` spins up ephemeral PostgreSQL + CockroachDB + Kafka for integration tests.

## Architecture Overview

The system is a microservice mesh coordinated by Kafka and BullMQ. The critical data path for a payout is:

1. **Oracle Engine** (`services/oracle_engine/`) — polls IMD, AccuWeather, NASA GPM, and CPCB concurrently. Uses event-type-aware oracle sets (weather: 3-of-4, AQI: 2-of-3). Data older than 15 min is treated as abstention, not a vote. `platform_outage.py` adds two additional oracle clients: `DowndetectorOracleClient` (complaint-spike detection) and `SyntheticPingOracleClient` (geo-distributed health pings for Swiggy/Zomato). `schedule_loader.py` reads per-oracle poll intervals from the `poll_schedules` table rather than hardcoding them. Publishes `oracle_trigger` to Kafka when consensus is reached.

2. **Core Backend** (`services/core_backend/`) — Express.js REST API on port 3000. Consumes Kafka events and routes work to BullMQ. Five worker queues: `premium_recalculation`, `payout_disbursement`, `notification_dispatch`, `fraud_review_escalation`, `weekly_premium_debit`. All payout debits use double-entry ledger with `SELECT ... FOR UPDATE` serialization to prevent concurrent overdraw. External integrations (KMS, liveness provider, mandate gateway, payout gateway) are isolated behind adapter interfaces in `src/adapters/` — swap implementations without touching business logic.

3. **Claims Scoring** (`services/claims_scoring/`) — Rust/Axum service. Composite fraud score = 0.4×spatial + 0.2×frequency + 0.4×isolation_forest. Score ≥ 0.7 → `AUTO_APPROVED`; below → `FRAUD_QUEUE`. Platform activity veto, soak period failure, and `platform_verifier` (checks that the worker had no active gig orders during the claimed disruption window by calling Swiggy/Zomato APIs) are hard overrides regardless of score. Communicates with the isolation forest sidecar via Unix socket at `/tmp/isolation_forest.sock`.

4. **Isolation Forest Sidecar** (`services/isolation_forest_sidecar/`) — Python process that loads a pre-trained joblib model. On startup it verifies the model SHA-256 hash against `model/model_card.json`.

5. **Risk Profiler** (`services/risk_profiler/`) — 16-dimensional feature vector assembled from TimescaleDB (historical weather), Weather API (current conditions), and PostgreSQL (worker profile). Each source has a 500ms timeout; misses fall back to zone-level medians. Zones with < 90 days of history use proxy-zone KNN bootstrap with a 1.25× risk margin multiplier.

6. **FastAPI Gateway** (`services/fastapi_gateway/`) — Python gateway on port 8000, routes proof uploads and claim processing into the Rust scoring pipeline.

7. **Crew AI** (`services/crew_ai/`) — Multi-agent orchestration for claim pipeline steps: document verification, fraud signal aggregation, oracle cross-check, and payout authorization.

8. **RAG Orchestrator** (`services/rag_orchestrator/`) — LlamaIndex + BGE-Large embeddings against MongoDB Atlas vector index for policy knowledge retrieval. Port 8001.

9. **KG Cache** (`services/kg_cache/`) — Go service that caches scraped disruption knowledge graph from `web_intelligence`. Port 8004 (internal 8080).

10. **Rasa Assistant** (`services/rasa_assistant/`) — Gemini-backed in-app support bot with IndicConformer for regional language support. Port 8002.

11. **Actuarial Lab** (`services/actuarial_lab/`) — CLI-only Python service. Runs historical backtests (Brier score, rolling 13-week loss ratios), stress scenarios (catastrophic event, systemic outage, climate drift), and a CI gate that exits non-zero if portfolio loss ratio > 100% or reserve depletion < 90 days.

## Database Layout and Migration Order

**Always run PostgreSQL migrations before CockroachDB** — financial tables reference worker/policy IDs from PostgreSQL.

```bash
# PostgreSQL (operational schema — workers, policies, claims, zones, GPS, KYC)
psql -h localhost -U postgres -d continuum
\i db/migrations/postgres/001_initial_schema.sql   # PostGIS, TimescaleDB hypertable, core tables
\i db/migrations/postgres/002_enrollment_lock.sql   # zone_enrollment_locks
\i db/migrations/postgres/003_identity_uniqueness.sql  # UNIQUE indexes on aadhaar_hash, device_fingerprint
\i db/migrations/postgres/004_dpdp_proximity_retention.sql  # device_proximity_log + pg_cron 30-day purge
\i db/migrations/postgres/005_ledger_and_mandate_tables.sql  # ledger mirror + mandate tables
\i db/migrations/postgres/005_poll_schedules.sql     # poll_schedules table (per-oracle intervals)
\i db/migrations/postgres/006_consent_receipts.sql   # DPDP consent receipts
\i db/migrations/postgres/006_premium_versions_and_policy_zone.sql  # premium versioning + policy zone
\i db/migrations/postgres/007_kill_switches.sql      # operator kill switches for circuit-breaking

# CockroachDB (financial data — ledger, payouts, mandates)
cockroach sql --insecure --database=continuum
\i db/migrations/cockroachdb/001_initial_schema.sql  # policies, payouts, reserve_balance
\i db/migrations/cockroachdb/002_mandates.sql          # mandates + mandate_debits
\i db/migrations/cockroachdb/003_adjacency_payout.sql  # adjacency_pro_rated flag on payouts
\i db/migrations/cockroachdb/004_double_entry_ledger.sql  # ledger_accounts + ledger_entries (seeds 4 core accounts)
\i db/migrations/cockroachdb/005_ledger_views.sql     # reporting views over ledger_entries

# Kafka topics (run once before starting any service that uses Kafka)
bash infra/kafka/create_topics.sh
```

- **PostgreSQL** — worker profiles, claims, KYC, zone data, GPS activity (TimescaleDB), enrollment locks, DPDP proximity logs
- **CockroachDB** — double-entry ledger (`ledger_accounts` + `ledger_entries`), payouts with `oracle_votes` JSONB, mandate lifecycle
- **MongoDB** — vector store for RAG, Atlas vector index in `db/mongodb/vector_index.json`

## Contracts and Scripts

**Kafka event schemas** live in `contracts/oracle_events/` as JSON Schema v7 files (`payout_authorized.schema.json`, `enrollment_lock.schema.json`, `fraud_alert.schema.json`). These are the canonical shapes of Kafka messages — update them when changing event structures.

**One-shot data loader scripts** in `scripts/`:
- `seed_synthetic_ledger.py` — generates 24 months of synthetic ledger data in CockroachDB for backtesting
- `load_weather_historical.py` — backfills the TimescaleDB `weather_events` hypertable
- `load_zone_polygons.py` — loads WGS84 zone polygons into PostgreSQL (required before integration tests pass)

**Architecture decisions** are documented in `docs/adr/`: ledger-first financial model (ADR-0001), Kafka consumer topology (ADR-0002), external adapter pattern (ADR-0003), PII envelope encryption (ADR-0004). Read these before changing the corresponding systems.

## Key Business Rules Encoded in Code

- **72-hour activation delay**: new policies cannot claim for 72 hours (enforced in `routes/policies.js`)
- **Enrollment freeze**: `POST /policies` returns HTTP 423 if `zone_enrollment_locks` has an active entry for that zone (oracle engine publishes these from 72h forecast)
- **One payout per 7-day cycle**: hard cap enforced in payout disbursement processor
- **Velocity cap**: max 3 claims per 90-day window; excess → FRAUD_QUEUE (enforced in Rust frequency check)
- **Adjacency grace**: PostGIS `ST_Touches` check returns 50% payout for bordering zones
- **Benefit of doubt**: ≥2 oracles offline + ≥1 confirming → 50% payout cap authorized
- **BullMQ thundering herd prevention**: weekly premium debit jobs are spread across a 1-hour window
- **Kill switches**: operator-controlled flags in `kill_switches` table (PostgreSQL). When active, the corresponding subsystem (payout, enrollment, oracle) is halted without a code deploy — checked in the relevant route/worker on each request
- **Consent receipts**: `POST /consent` records DPDP-compliant consent with a receipt ID; GPS data collection and proximity logging require an active consent receipt for that worker

## Kafka Topics

`worker_onboarding`, `claim_submitted`, `claim_decision`, `payout_authorized`, `oracle_trigger`, `premium_updated`, `fraud_alert`

Topics created via `infra/kafka/create_topics.sh` using config in `infra/kafka/topics.json`.

## Environment Setup

Copy `services/core_backend/.env.example` to `services/core_backend/.env`. Required vars: `JWT_SECRET`, `DB_HOST`, `DB_PASSWORD`, `KAFKA_BROKERS`, `FIREBASE_CREDENTIALS_PATH`. The `GEMINI_API_KEY` used by the Rasa assistant is hardcoded in `docker-compose.yml` — replace before production.

Install pre-commit hooks once after cloning: `pip install pre-commit && pre-commit install`. Hooks run gitleaks (secret scanning), detect-private-key, check-yaml/json, and trailing-whitespace on every commit. The same gitleaks scan runs in CI via `.github/workflows/security.yml`.

Oracle TLS certificate pins are set as environment variables on the `oracle_engine` container. Each oracle has a primary pin and a rotation-slot pin (`_NEXT`):
```
IMD_CERT_FINGERPRINT, ACCUWEATHER_CERT_FINGERPRINT, NASA_GPM_CERT_FINGERPRINT,
CPCB_CERT_FINGERPRINT, DOWNDETECTOR_CERT_FINGERPRINT  (+ *_NEXT variants for rotation)
```
Omitting a pin disables pinning for that oracle (acceptable in dev, required in production).

## Monitoring

Prometheus scrape targets:
- Core backend metrics: `GET /metrics` (port 3000)
- BullMQ worker metrics: port 9102
- Oracle engine: internal Prometheus counters (no HTTP endpoint)
- Claims scoring: `GET /metrics` (port 8080)

Three alert rules in `infra/prometheus/oracle_alerts.yml`:
- `OracleHighAbstentionRate` — oracle failure rate > 40% for 15 min → check TLS cert expiry and API health
- `PayoutSLABreach` — any payout exceeded 2h oracle-to-UPI SLA → triggers automatic 10% bonus credit to partner
- `ReserveLow` — `reserve_balance_inr < 100000` for 5 min → initiate reinsurance top-up

## Invariants That Must Not Be Broken

- **Never UPDATE or DELETE `ledger_entries` rows** — they are an immutable financial audit trail
- **Never lower the oracle consensus threshold** without an actuarial review — this directly controls payout authorization
- **`claim_eligible_from`** on a new policy must always be `enrolled_at + 72 hours` — the activation delay is a fraud control
- **Model provenance:** after replacing `isolation_forest.joblib`, always regenerate `model_card.json` with the new SHA-256 hash via `train_model.py`; the sidecar refuses requests if hashes mismatch
- **PostgreSQL `aadhaar_hash` and `device_fingerprint` indexes are partial UNIQUE** (`WHERE ... IS NOT NULL`) — do not convert them to full unique indexes or null handling breaks
