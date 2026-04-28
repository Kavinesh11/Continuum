---
name: Continuum local setup
overview: Step-by-step guide to set up the entire Continuum platform from a fresh clone, including all 11 microservices, 6 infrastructure containers, database migrations, seed data, the Flutter mobile app, and verification steps.
todos:
  - id: create-env
    content: Copy .env.example to .env and set POSTGRES_PASSWORD, DB_PASSWORD, JWT_SECRET
    status: pending
  - id: docker-up
    content: Run docker compose up --build to start all 17 containers
    status: pending
  - id: kafka-topics
    content: Create 8 Kafka topics via create_topics.sh
    status: pending
  - id: pg-migrations
    content: Run all 9 PostgreSQL migration files in order
    status: pending
  - id: crdb-migrations
    content: Create continuum database, run 5 CockroachDB migrations
    status: pending
  - id: seed-data
    content: Run zone polygon and weather data seed scripts
    status: pending
  - id: verify-backend
    content: Curl health endpoints to verify services are running
    status: pending
  - id: flutter-run
    content: flutter pub get && flutter run with --dart-define for backend URLs
    status: pending
isProject: false
---


# Continuum -- Complete Local Setup Guide

## Prerequisites (install these first)

- **Docker Desktop** (v4.x+) with at least 8 GB RAM allocated (16 services + infra)
- **Node.js 20+** (for core_backend local dev / running scripts)
- **Python 3.11+** (for oracle_engine, fastapi_gateway, crew_ai, scripts)
- **Flutter SDK** (stable channel, Dart SDK >= 3.8.0)
- **Rust toolchain** (stable, for claims_scoring local dev)
- **Go 1.21+** (for kg_cache local dev)
- **psql** CLI (for running Postgres migrations)
- **CockroachDB CLI** (for running CRDB migrations) -- or use `docker exec`

---

## Phase 1: Environment configuration

### 1.1 Create root `.env` from template

```bash
cp .env.example .env
```

Edit `.env` and set **at minimum**:

```
POSTGRES_PASSWORD=somesecretpassword
DB_PASSWORD=somesecretpassword
JWT_SECRET=a-long-random-string-at-least-32-chars
```

These are the only truly required values. Everything else has safe defaults for local dev:

- All `*_PROVIDER` vars default to `mock` (no real external APIs needed)
- `PAYOUT_AUTOMATION_ENABLED=false` is fine initially
- `GEMINI_API_KEY` only needed if you want the Rasa chatbot to work
- `KMS_PROVIDER=local` uses a dev-only in-process key

### 1.2 Install pre-commit hooks (optional but recommended)

```bash
pip install pre-commit && pre-commit install
```

---

## Phase 2: Start all infrastructure + services via Docker

### 2.1 Build and start everything

```bash
docker compose up --build
```

This starts **17 containers**:

**Infrastructure (6):**
- `postgres` -- PostGIS 15 on port 5432
- `cockroachdb` -- CockroachDB v23.2 on port 26257 (UI on 26080)
- `mongodb` -- Mongo 7 on port 27017
- `redis` -- Redis Alpine on port 6379
- `zookeeper` -- Confluent ZK on port 2181
- `kafka` -- Confluent Kafka on port 9092

**Application services (11):**
- `core_backend` (Node.js, port 3000) -- depends on postgres, cockroachdb, redis, kafka
- `fastapi_gateway` (Python, port 8000)
- `claims_scoring` (Rust, port 8080)
- `kg_cache` (Go, port 8004)
- `oracle_engine` (Python, no public port)
- `crew_ai` (Python, no public port) -- depends on kafka, postgres, mongodb
- `rag_orchestrator` (Python, port 8001) -- depends on mongodb
- `rasa_assistant` (Python, port 8002)
- `web_intelligence` (Python, port 8003)
- `isolation_forest_sidecar` (Python, no public port)
- `risk_profiler` is not in compose but has a Dockerfile for CI builds

### 2.2 Verify infrastructure is healthy

```bash
docker compose ps
```

All containers should show `healthy` or `running`. Common issues:

- If `postgres` fails: check `POSTGRES_PASSWORD` is set in `.env`
- If `kafka` fails: wait for `zookeeper` to be ready first (retry)
- If `cockroachdb` fails: ensure port 26257 is not in use

---

## Phase 3: Create Kafka topics

After Kafka is healthy, create topics:

```bash
docker compose exec kafka bash -c "KAFKA_BOOTSTRAP_SERVERS=localhost:9092 KAFKA_REPLICATION_FACTOR=1 /bin/bash /dev/stdin" < infra/kafka/create_topics.sh
```

Or connect directly:

```bash
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic worker_onboarding --partitions 3 --replication-factor 1
```

There are 8 topics total (see [infra/kafka/topics.json](infra/kafka/topics.json)):
`worker_onboarding`, `claim_submitted`, `claim_decision`, `payout_authorized`, `oracle_trigger`, `premium_updated`, `fraud_alert`, `adverse_selection_lock`

---

## Phase 4: Run database migrations

**PostgreSQL first** (CockroachDB financial tables reference Postgres worker/policy IDs):

```bash
# Run all Postgres migrations in order
for f in \
  db/migrations/postgres/001_initial_schema.sql \
  db/migrations/postgres/002_enrollment_lock.sql \
  db/migrations/postgres/003_identity_uniqueness.sql \
  db/migrations/postgres/004_dpdp_proximity_retention.sql \
  db/migrations/postgres/005_ledger_and_mandate_tables.sql \
  db/migrations/postgres/005_poll_schedules.sql \
  db/migrations/postgres/006_consent_receipts.sql \
  db/migrations/postgres/006_premium_versions_and_policy_zone.sql \
  db/migrations/postgres/007_kill_switches.sql; do
  PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -p 5432 -U postgres -d continuum -f "$f"
done
```

**CockroachDB:**

```bash
# Create the database first
docker compose exec cockroachdb cockroach sql --insecure -e "CREATE DATABASE IF NOT EXISTS continuum"

# Run CRDB migrations
for f in \
  db/migrations/cockroachdb/001_financial_ledger.sql \
  db/migrations/cockroachdb/002_mandates.sql \
  db/migrations/cockroachdb/003_adjacency_payout.sql \
  db/migrations/cockroachdb/004_double_entry_ledger.sql \
  db/migrations/cockroachdb/005_ledger_views.sql; do
  docker compose exec -T cockroachdb cockroach sql --insecure --database=continuum < "$f"
done
```

---

## Phase 5: Seed data (required for the app to function)

### 5.1 Zone polygons (required -- integration tests and claim processing need zones)

```bash
python scripts/load_zone_polygons.py \
  --provider fixture \
  --pg-dsn "postgresql://postgres:$POSTGRES_PASSWORD@localhost:5432/continuum"
```

### 5.2 Historical weather data (required for risk profiling)

```bash
python scripts/load_weather_historical.py \
  --provider synthetic \
  --pg-dsn "postgresql://postgres:$POSTGRES_PASSWORD@localhost:5432/continuum"
```

### 5.3 Synthetic ledger data (optional -- seeds 24 months of financial data)

```bash
python scripts/seed_synthetic_ledger.py \
  --crdb-dsn "postgresql://root@localhost:26257/continuum?sslmode=disable"
```

---

## Phase 6: Verify the backend is working

### 6.1 Health check

```bash
curl http://localhost:3000/health          # core_backend
curl http://localhost:8000/docs            # fastapi_gateway (Swagger UI)
curl http://localhost:8080/metrics         # claims_scoring (Prometheus)
```

### 6.2 Create a test worker via the API

```bash
# Register (depends on your auth route implementation)
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"worker_id": "test-worker-1", "password": "testpass123", "phone": "+919999999999"}'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"worker_id": "test-worker-1", "password": "testpass123"}'
# Save the returned JWT token
```

---

## Phase 7: Run the Flutter mobile app

### 7.1 Install dependencies

```bash
flutter pub get
```

### 7.2 Run on an emulator or device

For local development (backend on localhost):

```bash
# Android emulator (10.0.2.2 is the host machine from the emulator)
flutter run --dart-define=CORE_API_URL=http://10.0.2.2:3000 --dart-define=FASTAPI_URL=http://10.0.2.2:8000

# Physical device on same WiFi (replace with your machine's IP)
flutter run --dart-define=CORE_API_URL=http://192.168.x.x:3000 --dart-define=FASTAPI_URL=http://192.168.x.x:8000

# Chrome/web
flutter run -d chrome --dart-define=CORE_API_URL=http://localhost:3000 --dart-define=FASTAPI_URL=http://localhost:8000
```

The app reads `CORE_API_URL` and `FASTAPI_URL` via `String.fromEnvironment()` in [lib/services/api_service.dart](lib/services/api_service.dart). If omitted, defaults to `http://localhost:3000` and `http://localhost:8000`.

### 7.3 App flow

1. **Login** screen -- enter the worker ID and password you created in Phase 6
2. **Dashboard** -- shows risk profile (fetched from fastapi_gateway)
3. **Enrollment** (`/enrollment`) -- pick a tier (Silver/Gold/Platinum) and zone
4. **Consent** (`/consent`) -- DPDP consent for GPS, identity, UPI
5. **Mandate** (`/mandate`) -- enter UPI ID for auto-debit
6. **Apply for claim** -- submit a disruption claim
7. **Status tracker** -- track claim progress

### 7.4 Known limitations

- **Firebase**: FCM push notifications require `google-services.json` (Android) and `GoogleService-Info.plist` (iOS). Without them, notifications silently degrade to no-op.
- **iOS**: The `ios/` directory exists but is not tested. Android is the primary target.
- **Release builds**: Require a real keystore. The build.gradle.kts reads `CONTINUUM_KEYSTORE_PATH` env vars. Debug builds work without it.

---

## Phase 8: Enable the full payout flow (optional)

By default, `PAYOUT_AUTOMATION_ENABLED=false` -- authorized payouts are intentionally dropped. To test the complete end-to-end flow:

```bash
# In your .env, set:
PAYOUT_AUTOMATION_ENABLED=true
```

Then restart core_backend. With all providers set to `mock`, the flow is:

```
Oracle detects disruption
  --> publishes payout_authorized to Kafka
  --> core_backend consumes, creates payout record
  --> enqueues to BullMQ payout_disbursement queue
  --> MockPayoutGateway returns fake success
  --> worker gets FCM notification (if configured)
```

---

## Phase 9: Running tests

```bash
# Node.js unit tests
cd services/core_backend && npm test

# Python tests (per service)
cd services/oracle_engine && pytest tests/ -v
cd services/fastapi_gateway && pytest tests/ -v

# Rust tests
cd services/claims_scoring && cargo test

# Go tests
cd services/kg_cache && go test ./...

# Flutter tests
flutter test

# Full integration tests (needs the test compose stack)
docker compose -f docker-compose.test.yml up -d --wait
cd tests/integration && npm install && npm test
docker compose -f docker-compose.test.yml down -v
```

---

## Service dependency diagram

```mermaid
flowchart TB
  subgraph infra [Infrastructure]
    PG[PostgreSQL:5432]
    CRDB[CockroachDB:26257]
    MONGO[MongoDB:27017]
    REDIS[Redis:6379]
    ZK[Zookeeper:2181]
    KAFKA[Kafka:9092]
    ZK --> KAFKA
  end

  subgraph services [Application Services]
    CB[core_backend:3000]
    FG[fastapi_gateway:8000]
    CS[claims_scoring:8080]
    OE[oracle_engine]
    CA[crew_ai]
    RAG[rag_orchestrator:8001]
    RASA[rasa_assistant:8002]
    WI[web_intelligence:8003]
    KG[kg_cache:8004]
    IF[isolation_forest_sidecar]
  end

  CB --> PG
  CB --> CRDB
  CB --> REDIS
  CB --> KAFKA
  CS --> PG
  CS --> IF
  OE --> KAFKA
  CA --> KAFKA
  CA --> PG
  CA --> MONGO
  RAG --> MONGO
  KG --> WI
  FG --> CB
  RASA --> CB
end
```

---

## Quick reference -- ports

| Service | Port | Notes |
|---------|------|-------|
| core_backend | 3000 | REST API + Prometheus /metrics |
| fastapi_gateway | 8000 | Swagger at /docs |
| rag_orchestrator | 8001 | |
| rasa_assistant | 8002 | |
| web_intelligence | 8003 | |
| kg_cache | 8004 | Internal 8080 |
| claims_scoring | 8080 | Rust/Axum |
| PostgreSQL | 5432 | |
| CockroachDB | 26257 | Admin UI at 26080 |
| MongoDB | 27017 | |
| Redis | 6379 | |
| Kafka | 9092 | |

---

## Troubleshooting

- **"Set POSTGRES_PASSWORD in .env"** -- You must set `POSTGRES_PASSWORD` in your root `.env` file
- **Kafka topic creation fails** -- Wait for Kafka to be fully healthy, then retry. Check with `docker compose logs kafka`
- **CRDB "database continuum does not exist"** -- Run `CREATE DATABASE continuum` first (Phase 4)
- **Flutter "SocketException"** -- The emulator cannot reach `localhost`. Use `10.0.2.2` for Android emulator or your LAN IP for physical devices
- **PostGIS extension missing** -- The compose uses `postgis/postgis:15-3.4-alpine` which includes PostGIS. If running Postgres locally, install the PostGIS extension manually
- **claims_scoring build slow** -- Rust cold builds take 3-5 min. Subsequent builds use cargo cache
