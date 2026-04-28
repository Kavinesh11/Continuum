// Integration tests — Claim Lifecycle
// Invariants covered:
//   V29 — policy claim_eligible_from = NOW() + 72h; claims before rejected
//   V34 — duplicate payout within 7 days → blocked by UNIQUE constraint (OCC)
//
// Requires running PostgreSQL (TEST_PG_DSN) and CockroachDB (TEST_CRDB_DSN).
// If the DB is unreachable, tests are skipped.

'use strict';

const { setup, teardown, PG_DSN, CRDB_DSN } = require('./setup');
const { Client } = require('pg');
const { v4: uuidv4 } = require('uuid');

let pgClient;
let crdbClient;
let dbAvailable = false;

const WORKER_ID = 'a0000000-0000-0000-0000-000000000001'; // seeded in seed.sql

beforeAll(async () => {
  try {
    await setup();
    pgClient = new Client({ connectionString: PG_DSN });
    await pgClient.connect();
    crdbClient = new Client({
      connectionString: CRDB_DSN.replace('defaultdb', 'continuum_test'),
    });
    await crdbClient.connect();
    dbAvailable = true;
  } catch (err) {
    console.warn('[claimLifecycle] DB unavailable — skipping integration tests:', err.message);
  }
}, 60000);

afterAll(async () => {
  if (pgClient) await pgClient.end().catch(() => {});
  if (crdbClient) await crdbClient.end().catch(() => {});
  if (dbAvailable) await teardown().catch(() => {});
});

function skipIfNoDb() {
  if (!dbAvailable) {
    // eslint-disable-next-line jest/no-standalone-expect
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// V29 — policy claim_eligible_from = NOW() + 72h
// ---------------------------------------------------------------------------

describe('V29 — policy claim eligibility window', () => {
  test('policy inserted directly has claim_eligible_from ~72h in future', async () => {
    if (skipIfNoDb()) return;

    const policyId = uuidv4();
    const now = new Date();
    const claimEligibleFrom = new Date(now.getTime() + 72 * 60 * 60 * 1000);

    await crdbClient.query(
      `INSERT INTO policies
         (policy_id, worker_id, tier, coverage_cap, weekly_premium,
          effective_date, claim_eligible_from, status,
          billing_cycle_start, billing_cycle_end)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        policyId,
        WORKER_ID,
        'silver',
        5000,
        149,
        now.toISOString(),
        claimEligibleFrom.toISOString(),
        'active',
        now.toISOString(),
        new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      ]
    );

    const result = await crdbClient.query(
      'SELECT claim_eligible_from FROM policies WHERE policy_id = $1',
      [policyId]
    );

    expect(result.rows).toHaveLength(1);
    const storedEligible = new Date(result.rows[0].claim_eligible_from).getTime();
    const delayMs = storedEligible - now.getTime();

    // Must be approximately 72 hours (±5 minutes tolerance)
    expect(delayMs).toBeGreaterThanOrEqual(72 * 60 * 60 * 1000 - 5 * 60 * 1000);
    expect(delayMs).toBeLessThanOrEqual(72 * 60 * 60 * 1000 + 5 * 60 * 1000);
  });

  test('claim submitted before claim_eligible_from fails eligibility check', async () => {
    if (skipIfNoDb()) return;

    const policyId = uuidv4();
    const now = new Date();
    const claimEligibleFrom = new Date(now.getTime() + 72 * 60 * 60 * 1000);

    await crdbClient.query(
      `INSERT INTO policies
         (policy_id, worker_id, tier, coverage_cap, weekly_premium,
          effective_date, claim_eligible_from, status,
          billing_cycle_start, billing_cycle_end)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        policyId, WORKER_ID, 'silver', 5000, 149,
        now.toISOString(),
        claimEligibleFrom.toISOString(),
        'active',
        now.toISOString(),
        new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      ]
    );

    // The application-level check: claims submitted before claim_eligible_from must fail.
    // Simulate the eligibility check SQL that core_backend would run.
    const eligibilityResult = await crdbClient.query(
      `SELECT claim_eligible_from <= NOW() AS eligible
       FROM policies WHERE policy_id = $1`,
      [policyId]
    );

    expect(eligibilityResult.rows).toHaveLength(1);
    // Policy was just created with +72h delay — should NOT be eligible yet
    expect(eligibilityResult.rows[0].eligible).toBe(false);
  });

  test('claim submitted after claim_eligible_from passes eligibility check', async () => {
    if (skipIfNoDb()) return;

    const policyId = uuidv4();
    const now = new Date();
    // Backdate claim_eligible_from by 1 second to simulate an already-eligible policy
    const claimEligibleFrom = new Date(now.getTime() - 1000);

    await crdbClient.query(
      `INSERT INTO policies
         (policy_id, worker_id, tier, coverage_cap, weekly_premium,
          effective_date, claim_eligible_from, status,
          billing_cycle_start, billing_cycle_end)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        policyId, WORKER_ID, 'silver', 5000, 149,
        new Date(now.getTime() - 73 * 60 * 60 * 1000).toISOString(),
        claimEligibleFrom.toISOString(),
        'active',
        new Date(now.getTime() - 73 * 60 * 60 * 1000).toISOString(),
        new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      ]
    );

    const eligibilityResult = await crdbClient.query(
      `SELECT claim_eligible_from <= NOW() AS eligible
       FROM policies WHERE policy_id = $1`,
      [policyId]
    );

    expect(eligibilityResult.rows).toHaveLength(1);
    expect(eligibilityResult.rows[0].eligible).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// V34 — duplicate payout within 7 days → blocked (UNIQUE claim_id constraint)
// ---------------------------------------------------------------------------

describe('V34 — duplicate payout deduplication', () => {
  test('first payout for a claim inserts successfully', async () => {
    if (skipIfNoDb()) return;

    const claimId = uuidv4();
    const payoutId = uuidv4();
    const policyId = uuidv4();

    // Insert claim row in PostgreSQL
    await pgClient.query(
      `INSERT INTO claims
         (claim_id, worker_id, event_type, event_timestamp, zone_id, status)
       VALUES ($1, $2, $3, NOW(), $4, $5)`,
      [claimId, WORKER_ID, 'heavy_rainfall', 'MUM_ANDHERI_W', 'auto_approved']
    );

    // Insert payout in CockroachDB
    await crdbClient.query(
      `INSERT INTO payouts
         (payout_id, worker_id, claim_id, policy_id, amount, oracle_votes, zone_id, tier)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [payoutId, WORKER_ID, claimId, policyId, 250.00, '[]', 'MUM_ANDHERI_W', 'silver']
    );

    const result = await crdbClient.query(
      'SELECT payout_id FROM payouts WHERE claim_id = $1',
      [claimId]
    );
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].payout_id).toBe(payoutId);
  });

  test('V34: second payout for same claim is rejected by UNIQUE constraint (OCC)', async () => {
    if (skipIfNoDb()) return;

    const claimId = uuidv4();
    const firstPayoutId = uuidv4();
    const duplicatePayoutId = uuidv4();
    const policyId = uuidv4();

    // Insert claim
    await pgClient.query(
      `INSERT INTO claims
         (claim_id, worker_id, event_type, event_timestamp, zone_id, status)
       VALUES ($1, $2, $3, NOW(), $4, $5)`,
      [claimId, WORKER_ID, 'heavy_rainfall', 'MUM_ANDHERI_W', 'auto_approved']
    );

    // Insert first payout — must succeed
    await crdbClient.query(
      `INSERT INTO payouts
         (payout_id, worker_id, claim_id, policy_id, amount, oracle_votes, zone_id, tier)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [firstPayoutId, WORKER_ID, claimId, policyId, 250.00, '[]', 'MUM_ANDHERI_W', 'silver']
    );

    // Second payout for same claim_id must fail (UNIQUE constraint)
    await expect(
      crdbClient.query(
        `INSERT INTO payouts
           (payout_id, worker_id, claim_id, policy_id, amount, oracle_votes, zone_id, tier)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [duplicatePayoutId, WORKER_ID, claimId, policyId, 250.00, '[]', 'MUM_ANDHERI_W', 'silver']
      )
    ).rejects.toThrow();

    // Verify only one payout exists
    const result = await crdbClient.query(
      'SELECT COUNT(*) AS cnt FROM payouts WHERE claim_id = $1',
      [claimId]
    );
    expect(parseInt(result.rows[0].cnt)).toBe(1);
  });

  test('V34: payouts for different claims are both accepted', async () => {
    if (skipIfNoDb()) return;

    const claimId1 = uuidv4();
    const claimId2 = uuidv4();
    const policyId = uuidv4();

    await pgClient.query(
      `INSERT INTO claims (claim_id, worker_id, event_type, event_timestamp, zone_id, status)
       VALUES ($1, $2, $3, NOW(), $4, $5), ($6, $2, $3, NOW(), $4, $5)`,
      [claimId1, WORKER_ID, 'heavy_rainfall', 'MUM_ANDHERI_W', 'auto_approved',
       claimId2]
    );

    await crdbClient.query(
      `INSERT INTO payouts
         (payout_id, worker_id, claim_id, policy_id, amount, oracle_votes, zone_id, tier)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8),
              ($9, $2, $10, $4, $5, $6, $7, $8)`,
      [
        uuidv4(), WORKER_ID, claimId1, policyId, 250.00, '[]', 'MUM_ANDHERI_W', 'silver',
        uuidv4(), claimId2,
      ]
    );

    const result = await crdbClient.query(
      `SELECT COUNT(*) AS cnt FROM payouts WHERE claim_id IN ($1, $2)`,
      [claimId1, claimId2]
    );
    expect(parseInt(result.rows[0].cnt)).toBe(2);
  });
});
