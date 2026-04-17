-- Integration test seed data
-- Run against the test Postgres instance after all migrations.

-- ─── Zones (3 Mumbai wards with real-ish WGS84 polygons) ─────────────────────

INSERT INTO zones (zone_id, city, polygon, risk_index) VALUES
  ('MUM_ANDHERI_W', 'Mumbai', ST_GeomFromText('POLYGON((72.82 19.12, 72.85 19.12, 72.85 19.15, 72.82 19.15, 72.82 19.12))', 4326), 0.65),
  ('MUM_BANDRA_W',  'Mumbai', ST_GeomFromText('POLYGON((72.82 19.05, 72.85 19.05, 72.85 19.08, 72.82 19.08, 72.82 19.05))', 4326), 0.55),
  ('MUM_DADAR',     'Mumbai', ST_GeomFromText('POLYGON((72.84 19.01, 72.87 19.01, 72.87 19.04, 72.84 19.04, 72.84 19.01))', 4326), 0.45)
ON CONFLICT (zone_id) DO NOTHING;

-- ─── Workers ─────────────────────────────────────────────────────────────────

INSERT INTO workers (worker_id, platform, tier, zone_id, upi_id, fcm_token, aadhaar_hash, device_fingerprint) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'swiggy',  'gold',     'MUM_ANDHERI_W', 'worker1@upi', 'fcm_token_1', 'aadh_hash_001', 'dev_fp_001'),
  ('a0000000-0000-0000-0000-000000000002', 'zomato',  'platinum', 'MUM_BANDRA_W',  'worker2@upi', 'fcm_token_2', 'aadh_hash_002', 'dev_fp_002')
ON CONFLICT (worker_id) DO NOTHING;

-- ─── Synthetic 24-month weather stream ───────────────────────────────────────
-- Generates ~730 daily events per zone (2 years × 365 days) for backtest support

INSERT INTO weather_events (zone_id, event_type, rainfall_mm, wind_kmh, recorded_at)
SELECT
  z.zone_id,
  'heavy_rainfall',
  CASE WHEN random() < 0.08 THEN 50 + random() * 100 ELSE random() * 20 END,
  10 + random() * 40,
  ts
FROM zones z
CROSS JOIN generate_series(
  NOW() - INTERVAL '24 months',
  NOW(),
  INTERVAL '1 day'
) AS ts;

-- AQI events (sparser)
INSERT INTO weather_events (zone_id, event_type, rainfall_mm, wind_kmh, recorded_at)
SELECT
  z.zone_id,
  'aqi',
  NULL,
  NULL,
  ts
FROM zones z
CROSS JOIN generate_series(
  NOW() - INTERVAL '24 months',
  NOW(),
  INTERVAL '3 days'
) AS ts
WHERE random() < 0.15;
