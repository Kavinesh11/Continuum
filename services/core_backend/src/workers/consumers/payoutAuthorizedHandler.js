'use strict';

const db = require('../../db');
const { createPayoutRecord, checkReserveBalance } = require('../../services/ledger');
const { enqueueJob, QUEUE_NAMES } = require('../queues');

const PAYOUT_AUTOMATION_ENABLED = process.env.PAYOUT_AUTOMATION_ENABLED === 'true';
const KILL_SWITCH = process.env.PAYOUT_KILL_SWITCH === 'true';
const DAILY_PORTFOLIO_CAP = parseFloat(process.env.DAILY_PORTFOLIO_CAP || '500000');
const RESERVE_FLOOR_INR = parseFloat(process.env.RESERVE_FLOOR_INR || '100000');

const TIER_COVERAGE = {
  silver:   { coverage_cap: 500,  payout_cap: 0.50 },
  gold:     { coverage_cap: 1000, payout_cap: 0.75 },
  platinum: { coverage_cap: 2000, payout_cap: 1.00 },
};

const ADJACENCY_FACTORS = {
  exact: 1.0,
  buffer: 0.7,
  touch: 0.5,
};

/**
 * Handle a `payout_authorized` Kafka event.
 * Resolves per-worker payouts for all active policies in the affected zone.
 */
async function handlePayoutAuthorized(event) {
  const { payout_id, zone_id, oracle_votes, authorized_at, payout_cap, benefit_of_doubt } = event;

  // ── Pre-guard: kill switch ─────────────────────────────────────────────────
  if (KILL_SWITCH) {
    console.warn(`[payout-handler] KILL_SWITCH active — dropping event ${payout_id}`);
    return { status: 'dropped', reason: 'kill_switch' };
  }

  if (!PAYOUT_AUTOMATION_ENABLED) {
    console.warn(`[payout-handler] PAYOUT_AUTOMATION_ENABLED=false — dropping event ${payout_id}`);
    return { status: 'dropped', reason: 'automation_disabled' };
  }

  // ── Pre-guard: zone-level pause ────────────────────────────────────────────
  const zoneKill = await db.query(
    `SELECT 1 FROM zone_kill_switches WHERE zone_id = $1 AND active = true LIMIT 1`,
    [zone_id]
  ).catch(() => ({ rows: [] }));

  if (zoneKill.rows.length > 0) {
    console.warn(`[payout-handler] Zone ${zone_id} is paused — dropping event ${payout_id}`);
    return { status: 'dropped', reason: 'zone_paused' };
  }

  // ── Pre-guard: reserve floor ───────────────────────────────────────────────
  try {
    await checkReserveBalance(RESERVE_FLOOR_INR);
  } catch (err) {
    console.error(`[payout-handler] Reserve floor check failed: ${err.message}`);
    return { status: 'dropped', reason: 'reserve_floor_breach' };
  }

  // ── Pre-guard: daily portfolio cap ─────────────────────────────────────────
  const dailyTotal = await db.query(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM payouts
     WHERE created_at >= NOW() - INTERVAL '24 hours' AND status != 'cancelled'`
  );
  if (parseFloat(dailyTotal.rows[0].total) >= DAILY_PORTFOLIO_CAP) {
    console.warn(`[payout-handler] Daily portfolio cap reached — dropping event ${payout_id}`);
    return { status: 'dropped', reason: 'daily_cap_reached' };
  }

  // ── Resolve per-worker payouts ─────────────────────────────────────────────
  const policiesResult = await db.query(
    `SELECT p.policy_id, p.worker_id, p.tier, p.coverage_cap, w.zone_id AS worker_zone
     FROM policies p
     JOIN workers w ON w.worker_id = p.worker_id
     WHERE p.status = 'active'
       AND p.claim_eligible_from <= NOW()
       AND w.zone_id = $1`,
    [zone_id]
  );

  const results = [];

  for (const policy of policiesResult.rows) {
    const tierConfig = TIER_COVERAGE[policy.tier] || TIER_COVERAGE.silver;
    const coverageCap = parseFloat(policy.coverage_cap) || tierConfig.coverage_cap;

    // Determine adjacency factor (default exact for same-zone)
    const adjacencyFactor = ADJACENCY_FACTORS.exact;

    const amount = coverageCap * (payout_cap || tierConfig.payout_cap) * adjacencyFactor;

    if (amount <= 0) continue;

    try {
      const claimId = require('uuid').v4();

      const payout = await createPayoutRecord({
        payout_id: require('uuid').v4(),
        worker_id: policy.worker_id,
        claim_id: claimId,
        policy_id: policy.policy_id,
        amount,
        oracle_votes,
        zone_id,
        tier: policy.tier,
        status: 'pending',
        created_at: new Date(),
      });

      await enqueueJob(
        QUEUE_NAMES.PAYOUT_DISBURSEMENT,
        'auto_payout',
        {
          payout_id: payout.payout_id,
          worker_id: policy.worker_id,
          claim_id: claimId,
          policy_id: policy.policy_id,
          amount,
          zone_id,
          tier: policy.tier,
          oracle_votes,
          trigger_fired_at: authorized_at,
        }
      );

      results.push({ policy_id: policy.policy_id, status: 'enqueued', amount });
    } catch (err) {
      console.error(
        `[payout-handler] Failed for policy ${policy.policy_id}: ${err.message}`
      );
      results.push({ policy_id: policy.policy_id, status: 'failed', error: err.message });
    }
  }

  console.log(`[payout-handler] Processed zone ${zone_id}: ${results.length} policies`);
  return { zone_id, payouts: results };
}

module.exports = { handlePayoutAuthorized, TIER_COVERAGE, ADJACENCY_FACTORS };
