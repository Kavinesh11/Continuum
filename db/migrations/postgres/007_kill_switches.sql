-- Migration: 007_kill_switches.sql
-- Description: Per-zone kill switches and portfolio daily cap for payout safety
-- Down: DROP TABLE IF EXISTS zone_kill_switches; DROP TABLE IF EXISTS portfolio_caps;

CREATE TABLE IF NOT EXISTS zone_kill_switches (
  zone_id    TEXT NOT NULL REFERENCES zones(zone_id),
  active     BOOLEAN NOT NULL DEFAULT TRUE,
  reason     TEXT,
  activated_by TEXT,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (zone_id)
);

CREATE TABLE IF NOT EXISTS portfolio_caps (
  cap_id     TEXT PRIMARY KEY DEFAULT 'daily_disbursement',
  max_amount DECIMAL(14,2) NOT NULL DEFAULT 500000,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO portfolio_caps (cap_id, max_amount) VALUES ('daily_disbursement', 500000)
ON CONFLICT (cap_id) DO NOTHING;
