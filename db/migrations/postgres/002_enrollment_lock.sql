-- Migration: 002_enrollment_lock.sql
-- Description: Zone enrollment lock table for adverse selection control
-- Requirements: G3 — pre-event enrollment lockout

CREATE TABLE IF NOT EXISTS zone_enrollment_locks (
  zone_id       TEXT NOT NULL REFERENCES zones(zone_id),
  event_type    TEXT NOT NULL,
  locked_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at    TIMESTAMPTZ NOT NULL,
  forecast_data JSONB,
  PRIMARY KEY (zone_id, event_type)
);

CREATE INDEX IF NOT EXISTS zone_locks_expires_idx
  ON zone_enrollment_locks (expires_at);
