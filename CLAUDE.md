# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Continuum** is a parametric income-protection insurance platform for gig delivery partners (Zomato/Swiggy). When a verified disruption occurs (weather, platform outage, lockdown), the system pays partners automatically via UPI — no claims form required. It was built for the Devtrails Guidewire Hackathon with IRDAI compliance as a design constraint.

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
```

## Running Tests

```bash
# Node.js (core_backend)
cd services/core_backend && npm test
# Run a single test file:
npx jest tests/test_ledger.test.js --runInBand

# Python services (pytest)
cd services/oracle_engine && pytest tests/
cd services/fastapi_gateway && pytest tests/
cd services/crew_ai && pytest tests/

# Rust (claims_scoring)
cd services/claims_scoring && cargo test

# Go (kg_cache)
cd services/kg_cache && go test ./...

# Actuarial CI gate (requires live DB DSNs)
python -m services.actuarial_lab.ci_gate \
  --ts-dsn "postgresql://..." \
  --crdb-dsn "postgresql://..."
```

## Architecture Overview

The system is a microservice mesh coordinated by Kafka and BullMQ. The critical data path for a payout is:

1. **Oracle Engine** (`services/oracle_engine/`) — polls IMD, AccuWeather, NASA GPM, and CPCB concurrently. Uses event-type-aware oracle sets (weather: 3-of-4, AQI: 2-of-3). Data older than 15 min is treated as abstention, not a vote. Publishes `oracle_trigger` to Kafka when consensus is reached.

2. **Core Backend** (`services/core_backend/`) — Express.js REST API on port 3000. Consumes Kafka events and routes work to BullMQ. Five worker queues: `premium_recalculation`, `payout_disbursement`, `notification_dispatch`, `fraud_review_escalation`, `weekly_premium_debit`. All payout debits use double-entry ledger with `SELECT ... FOR UPDATE` serialization to prevent concurrent overdraw.

3. **Claims Scoring** (`services/claims_scoring/`) — Rust/Axum service. Composite fraud score = 0.4×spatial + 0.2×frequency + 0.4×isolation_forest. Score ≥ 0.7 → `AUTO_APPROVED`; below → `FRAUD_QUEUE`. Platform activity veto and soak period failure are hard overrides regardless of score. Communicates with the isolation forest sidecar via Unix socket at `/tmp/isolation_forest.sock`.

4. **Isolation Forest Sidecar** (`services/isolation_forest_sidecar/`) — Python process that loads a pre-trained joblib model. On startup it verifies the model SHA-256 hash against `model/model_card.json`.

5. **Risk Profiler** (`services/risk_profiler/`) — 16-dimensional feature vector assembled from TimescaleDB (historical weather), Weather API (current conditions), and PostgreSQL (worker profile). Each source has a 500ms timeout; misses fall back to zone-level medians. Zones with < 90 days of history use proxy-zone KNN bootstrap with a 1.25× risk margin multiplier.

6. **FastAPI Gateway** (`services/fastapi_gateway/`) — Python gateway on port 8000, routes proof uploads and claim processing into the Rust scoring pipeline.

7. **Crew AI** (`services/crew_ai/`) — Multi-agent orchestration for claim pipeline steps: document verification, fraud signal aggregation, oracle cross-check, and payout authorization.

8. **RAG Orchestrator** (`services/rag_orchestrator/`) — LlamaIndex + BGE-Large embeddings against MongoDB Atlas vector index for policy knowledge retrieval. Port 8001.

9. **KG Cache** (`services/kg_cache/`) — Go service that caches scraped disruption knowledge graph from `web_intelligence`. Port 8004 (internal 8080).

10. **Rasa Assistant** (`services/rasa_assistant/`) — Gemini-backed in-app support bot with IndicConformer for regional language support. Port 8002.

11. **Actuarial Lab** (`services/actuarial_lab/`) — CLI-only Python service. Runs historical backtests (Brier score, rolling 13-week loss ratios), stress scenarios (catastrophic event, systemic outage, climate drift), and a CI gate that exits non-zero if portfolio loss ratio > 100% or reserve depletion < 90 days.

## Database Layout

Two SQL databases with separate migration directories:

- **PostgreSQL** (`db/migrations/postgres/`) — worker profiles, policies, claims, KYC, UPI mandates, zone enrollment locks, proximity logs (auto-purged after 30 days via `pg_cron`)
- **CockroachDB** (`db/migrations/cockroachdb/`) — financial ledger (`ledger_accounts` + `ledger_entries`), mandate state, adjacency payout flags
- **MongoDB** (`db/mongodb/`) — vector store for RAG, using Atlas vector index defined in `vector_index.json`

## Key Business Rules Encoded in Code

- **72-hour activation delay**: new policies cannot claim for 72 hours (enforced in `routes/policies.js`)
- **Enrollment freeze**: `POST /policies` returns HTTP 423 if `zone_enrollment_locks` has an active entry for that zone (oracle engine publishes these from 72h forecast)
- **One payout per 7-day cycle**: hard cap enforced in payout disbursement processor
- **Velocity cap**: max 3 claims per 90-day window; excess → FRAUD_QUEUE (enforced in Rust frequency check)
- **Adjacency grace**: PostGIS `ST_Touches` check returns 50% payout for bordering zones
- **Benefit of doubt**: ≥2 oracles offline + ≥1 confirming → 50% payout cap authorized
- **BullMQ thundering herd prevention**: weekly premium debit jobs are spread across a 1-hour window

## Kafka Topics

`worker_onboarding`, `claim_submitted`, `claim_decision`, `payout_authorized`, `oracle_trigger`, `premium_updated`, `fraud_alert`

Topics created via `infra/kafka/create_topics.sh` using config in `infra/kafka/topics.json`.

## Environment Setup

Copy `services/core_backend/.env.example` to `services/core_backend/.env`. Required vars: `JWT_SECRET`, `DB_HOST`, `DB_PASSWORD`, `KAFKA_BROKERS`, `FIREBASE_CREDENTIALS_PATH`. The `GEMINI_API_KEY` used by the Rasa assistant is in `docker-compose.yml` (replace before production).

## Monitoring

Prometheus scrape targets:
- Core backend metrics: `GET /metrics` (port 3000)
- BullMQ worker metrics: port 9102
- Oracle engine: internal Prometheus counters

Alert rules in `infra/prometheus/oracle_alerts.yml`: oracle abstention rate > 40%, payout SLA breach > 2h, reserve balance < ₹100,000.
