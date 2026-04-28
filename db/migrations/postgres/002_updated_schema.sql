CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS zones (
  zone_id TEXT PRIMARY KEY,
  city TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workers (
  worker_id UUID PRIMARY KEY,
  platform TEXT NOT NULL,
  tier TEXT NOT NULL,
  zone_id TEXT REFERENCES zones(zone_id),
  upi_id TEXT,
  password_hash TEXT,
  fcm_token TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sim_changed_at TIMESTAMPTZ,
  full_name TEXT,
  city TEXT,
  phone TEXT,
  emergency_contact TEXT
);

CREATE TABLE IF NOT EXISTS policies (
  policy_id UUID PRIMARY KEY,
  worker_id UUID NOT NULL,
  tier TEXT NOT NULL,
  coverage_cap NUMERIC(12,2) NOT NULL,
  weekly_premium NUMERIC(10,2) NOT NULL,
  effective_date TIMESTAMPTZ NOT NULL,
  claim_eligible_from TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  billing_cycle_start TIMESTAMPTZ NOT NULL,
  billing_cycle_end TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS claims (
  claim_id UUID PRIMARY KEY,
  worker_id UUID REFERENCES workers(worker_id),
  policy_id UUID,
  event_type TEXT NOT NULL,
  event_timestamp TIMESTAMPTZ NOT NULL,
  gps_lat DOUBLE PRECISION,
  gps_lon DOUBLE PRECISION,
  zone_id TEXT,
  device_attestation_token TEXT,
  status TEXT NOT NULL DEFAULT 'processing',
  fraud_score DOUBLE PRECISION,
  estimated_payout NUMERIC(10,2),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  decided_at TIMESTAMPTZ,
  verification_message TEXT
);

CREATE TABLE IF NOT EXISTS payouts (
  payout_id UUID PRIMARY KEY,
  worker_id UUID NOT NULL,
  claim_id UUID NOT NULL UNIQUE,
  policy_id UUID NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  oracle_votes JSONB NOT NULL DEFAULT '[]'::jsonb,
  zone_id TEXT NOT NULL,
  tier TEXT NOT NULL,
  payu_txn_ref TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  disbursed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS premium_versions (
  version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID NOT NULL,
  effective_date TIMESTAMPTZ NOT NULL,
  zone_id TEXT NOT NULL,
  tier TEXT NOT NULL,
  risk_score DOUBLE PRECISION NOT NULL,
  computed_premium NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reserve_balance (
  id INT PRIMARY KEY,
  balance NUMERIC(14,2) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO reserve_balance (id, balance)
VALUES (1, 0.00)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS policy_content (
  section_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  number INT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO zones(zone_id, city)
VALUES ('default', 'Kolkata')
ON CONFLICT (zone_id) DO NOTHING;