-- =============================================================================
-- Migration: 006_premium_versions_and_policy_zone.sql
-- Description: Premium audit trail, policy zone_id, and data retention
-- Requirements: Actuarial backtest, GPS retention compliance
-- =============================================================================

-- =============================================================================
-- premium_versions — Audit trail for computed premiums per worker-zone-cycle
-- Referenced by actuarial_lab historical_backtest.py and stress_scenarios.py
-- =============================================================================
CREATE TABLE IF NOT EXISTS premium_versions (
    version_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id        UUID NOT NULL,
    worker_id        UUID NOT NULL REFERENCES workers(worker_id),
    zone_id          TEXT NOT NULL REFERENCES zones(zone_id),
    tier             TEXT NOT NULL CHECK (tier IN ('silver', 'gold', 'platinum')),
    risk_score       DOUBLE PRECISION NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
    computed_premium NUMERIC(10, 2) NOT NULL,
    model_version    TEXT NOT NULL,
    feature_vector   DOUBLE PRECISION[],
    effective_date   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS premium_versions_policy_idx
    ON premium_versions (policy_id, effective_date DESC);
CREATE INDEX IF NOT EXISTS premium_versions_zone_idx
    ON premium_versions (zone_id, effective_date DESC);
CREATE INDEX IF NOT EXISTS premium_versions_effective_idx
    ON premium_versions (effective_date DESC);

-- =============================================================================
-- Add zone_id to policies table (may not exist in initial schema)
-- Required for zone-level claim correlation and actuarial queries
-- =============================================================================
ALTER TABLE policies ADD COLUMN IF NOT EXISTS zone_id TEXT REFERENCES zones(zone_id);

-- =============================================================================
-- gps_activity partitions — Create initial partitions and auto-purge rule
-- Partitions are created monthly; records older than 60 days are purged
-- =============================================================================

-- Create a partition for the current month (idempotent via IF NOT EXISTS)
DO $$
DECLARE
    partition_name TEXT;
    start_date     DATE;
    end_date       DATE;
BEGIN
    start_date     := date_trunc('month', CURRENT_DATE);
    end_date       := start_date + INTERVAL '1 month';
    partition_name := 'gps_activity_' || to_char(start_date, 'YYYY_MM');

    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF gps_activity FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
    END IF;
END
$$;

-- Schedule GPS data purge (60-day retention) via pg_cron if available
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'purge_gps_activity_60d',
            '0 4 * * *',
            $$DELETE FROM gps_activity WHERE recorded_at < NOW() - INTERVAL '60 days'$$
        );
    END IF;
END
$$;
