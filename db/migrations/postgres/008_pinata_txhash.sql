-- Migration 008: Pinata IPFS integration + transaction integrity columns.

-- workers: IPFS CID of the JSON profile pinned on registration.
ALTER TABLE workers ADD COLUMN IF NOT EXISTS pinata_cid TEXT;

-- payouts: human-readable transaction reference shown to the user.
-- tx_salt and tx_hash are the HMAC-SHA-256 tamper-detection fields — never exposed via API.
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS tx_ref  TEXT UNIQUE;
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS tx_salt TEXT;
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS tx_hash TEXT;

-- claims: JSONB array of Pinata CIDs for photo evidence uploaded during claim submission.
-- e.g. ["bafybeig...", "bafybeih..."]
ALTER TABLE claims ADD COLUMN IF NOT EXISTS photo_cids JSONB;

-- Index for fast tx_ref lookups (support queries, audit tooling).
CREATE INDEX IF NOT EXISTS idx_payouts_tx_ref ON payouts (tx_ref);
