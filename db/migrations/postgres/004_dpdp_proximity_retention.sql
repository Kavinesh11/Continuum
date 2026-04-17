-- Migration: 004_dpdp_proximity_retention.sql
-- Description: DPDP Act compliance — 30-day TTL on device_proximity_log
-- Requirements: medium-controls — privacy protection

-- device_proximity_log (if not created by earlier migration)
CREATE TABLE IF NOT EXISTS device_proximity_log (
    id           BIGSERIAL PRIMARY KEY,
    device_id_a  TEXT        NOT NULL,
    device_id_b  TEXT        NOT NULL,
    recorded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS dpl_device_a_idx ON device_proximity_log (device_id_a, recorded_at DESC);
CREATE INDEX IF NOT EXISTS dpl_device_b_idx ON device_proximity_log (device_id_b, recorded_at DESC);

-- Auto-purge records older than 30 days via pg_cron (if available)
-- Fallback: application-level cron deletes rows WHERE recorded_at < NOW() - INTERVAL '30 days'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'purge_proximity_logs',
            '0 3 * * *',
            $$DELETE FROM device_proximity_log WHERE recorded_at < NOW() - INTERVAL '30 days'$$
        );
    END IF;
END
$$;
