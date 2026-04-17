-- Migration: 005_poll_schedules.sql
-- Description: DB-driven oracle polling schedules (replaces hardcoded POLL_ZONES)
-- Down: DROP TABLE IF EXISTS poll_schedules;

CREATE TABLE IF NOT EXISTS poll_schedules (
  zone_id          TEXT NOT NULL REFERENCES zones(zone_id),
  event_type       TEXT NOT NULL,
  interval_seconds INT NOT NULL DEFAULT 3600,
  enabled          BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (zone_id, event_type)
);

-- Seed defaults for pilot zones (safe ON CONFLICT for idempotency)
INSERT INTO poll_schedules (zone_id, event_type, interval_seconds, enabled) VALUES
  ('MUM_ANDHERI_W', 'heavy_rainfall',   3600, TRUE),
  ('MUM_ANDHERI_W', 'cyclone',          3600, TRUE),
  ('MUM_ANDHERI_W', 'aqi',              3600, TRUE),
  ('MUM_ANDHERI_W', 'platform_outage',  1800, TRUE),
  ('MUM_BANDRA_W',  'heavy_rainfall',   3600, TRUE),
  ('MUM_BANDRA_W',  'cyclone',          3600, TRUE),
  ('MUM_BANDRA_W',  'aqi',              3600, TRUE),
  ('MUM_BANDRA_W',  'platform_outage',  1800, TRUE),
  ('MUM_DADAR',     'heavy_rainfall',   3600, TRUE),
  ('MUM_DADAR',     'cyclone',          3600, TRUE),
  ('MUM_DADAR',     'aqi',              3600, TRUE),
  ('MUM_DADAR',     'platform_outage',  1800, TRUE)
ON CONFLICT (zone_id, event_type) DO NOTHING;
