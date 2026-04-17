-- Migration: 003_adjacency_payout.sql
-- Description: Add adjacency pro-rated flag to payouts table
-- Requirements: G7 — basis-risk minimization via adjacency grace

ALTER TABLE payouts ADD COLUMN IF NOT EXISTS adjacency_pro_rated BOOLEAN DEFAULT FALSE;
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS adjacent_zone_id TEXT;
