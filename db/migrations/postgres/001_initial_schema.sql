-- =============================================================================
-- Migration: 001_initial_schema.sql
-- Description: Initial PostgreSQL/PostGIS/TimescaleDB schema for Continuum
-- Requirements: 1.5, 1.7, 3.4, 3.5, 9.1
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- zones (must be created first — referenced by workers and claims)
-- =============================================================================
CREATE TABLE IF NOT EXISTS zones (
  zone_id     TEXT PRIMARY KEY,
  city        TEXT NOT NULL,
  polygon     GEOMETRY(POLYGON, 4326) NOT NULL,
  risk_index  DOUBLE PRECISION DEFAULT 0.5
);

-- PostGIS GIST index for spatial queries (ST_Contains, ST_Within, etc.)
CREATE INDEX IF NOT EXISTS zones_polygon_gist ON zones USING GIST(polygon);

-- =============================================================================
-- workers
-- =============================================================================
CREATE TABLE IF NOT EXISTS workers (
  worker_id       UUID PRIMARY KEY,
  platform        TEXT NOT NULL CHECK (platform IN ('swiggy', 'zomato')),
  tier            TEXT NOT NULL CHECK (tier IN ('silver', 'gold', 'platinum')),
  zone_id         TEXT NOT NULL REFERENCES zones(zone_id),
  upi_id          TEXT NOT NULL,
  fcm_token       TEXT,
  registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sim_changed_at  TIMESTAMPTZ
);

-- =============================================================================
-- gps_activity (range-partitioned by day)
-- =============================================================================
CREATE TABLE IF NOT EXISTS gps_activity (
  worker_id   UUID REFERENCES workers(worker_id),
  lat         DOUBLE PRECISION NOT NULL,
  lon         DOUBLE PRECISION NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (worker_id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- =============================================================================
-- risk_scores (audit log for ML model outputs)
-- =============================================================================
CREATE TABLE IF NOT EXISTS risk_scores (
  score_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id       UUID REFERENCES workers(worker_id),
  policy_id       UUID,
  risk_score      DOUBLE PRECISION NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
  feature_vector  DOUBLE PRECISION[] NOT NULL,
  final_premium   NUMERIC(10,2) NOT NULL,
  model_version   TEXT NOT NULL,
  computed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for efficient worker-level audit queries
CREATE INDEX IF NOT EXISTS risk_scores_worker_id_idx ON risk_scores (worker_id, computed_at DESC);

-- =============================================================================
-- claims
-- =============================================================================
CREATE TABLE IF NOT EXISTS claims (
  claim_id                  UUID PRIMARY KEY,
  worker_id                 UUID REFERENCES workers(worker_id),
  policy_id                 UUID,
  event_type                TEXT NOT NULL,
  event_timestamp           TIMESTAMPTZ NOT NULL,
  gps_lat                   DOUBLE PRECISION,
  gps_lon                   DOUBLE PRECISION,
  zone_id                   TEXT REFERENCES zones(zone_id),
  device_attestation_token  TEXT,
  status                    TEXT NOT NULL DEFAULT 'processing',
  fraud_score               DOUBLE PRECISION CHECK (fraud_score BETWEEN 0 AND 1),
  estimated_payout          NUMERIC(10,2),
  submitted_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  decided_at                TIMESTAMPTZ
);

-- Index for 90-day rolling window frequency checks (Requirement 3.7)
CREATE INDEX IF NOT EXISTS claims_worker_submitted_idx ON claims (worker_id, submitted_at DESC);
-- Index for zone-level claim density queries (Requirement 17.1)
CREATE INDEX IF NOT EXISTS claims_zone_submitted_idx ON claims (zone_id, submitted_at DESC);

-- =============================================================================
-- weather_events (TimescaleDB hypertable — time-series partitioned)
-- =============================================================================
CREATE TABLE IF NOT EXISTS weather_events (
  zone_id       TEXT NOT NULL,
  event_type    TEXT NOT NULL,
  rainfall_mm   DOUBLE PRECISION,
  wind_kmh      DOUBLE PRECISION,
  recorded_at   TIMESTAMPTZ NOT NULL
);

-- Convert to TimescaleDB hypertable partitioned by recorded_at
SELECT create_hypertable(
  'weather_events',
  'recorded_at',
  if_not_exists => TRUE
);

-- Composite index for zone-level time-series queries (Requirement 1.5)
CREATE INDEX IF NOT EXISTS weather_events_zone_time_idx ON weather_events (zone_id, recorded_at DESC);

-- =============================================================================
-- agent_audit_log (Crew AI agent action log)
-- =============================================================================
CREATE TABLE IF NOT EXISTS agent_audit_log (
  log_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id    UUID REFERENCES claims(claim_id),
  agent_name  TEXT NOT NULL,
  action      TEXT NOT NULL,
  payload     JSONB,
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for claim-level audit trail lookups
CREATE INDEX IF NOT EXISTS agent_audit_log_claim_idx ON agent_audit_log (claim_id, logged_at DESC);
