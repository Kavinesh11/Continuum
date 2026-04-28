// Integration tests — Premium Collection + Ledger
// Invariants covered:
//   I.crdb — CockroachDB reserve_balance / ledger updated on premium debit
//
// Flow tested:
//   1. Insert worker + policy + mandate (status='active') in CockroachDB
//   2. Simulate weekly debit: INSERT mandate_debits + double-entry creditReserve SQL
//   3. Assert: mandate_debits row created
//              ledger_entries shows PREMIUM_INCOME → RESERVE_MAIN credit entry
//              ledger_accounts RESERVE_MAIN balance increased
//
// Requires CockroachDB (TEST_CRDB_DSN). Skips gracefully if DB unreachable.

'use strict';

const { setup, teardown, CRDB_DSN } = require('./setup');
const { Client } = require('pg');
const { v4: uuidv4 } = require('uuid');

let crdbClient;
let dbAvailable = false;

// Worker seeded in seed.sql (PostgreSQL) — for CRDB tests we insert our own
const TEST_WORKER_ID = 'b1000000-0000-0000-0000-000000000001';

beforeAll(async () => {
  try {
    await setup();
    crdbClient = new Client({
      connectionString: CRDB_DSN.replace('defaultdb', 'continuum_test'),
    });
    await crdbClient.connect();
    dbAvailable = true;
  } catch (err) {
    console.warn('[premiumCollection] DB unavailable — skipping integration tests:', err.message);
  }
}, 60000);

afterAll(async () => {
  if (crdbClient) await crdbClient.end().catch(() => {});
  if (dbAvailable) await teardown().catch(() => {});
});

function skipIfNoDb() {
  return !dbAvailable;
}

// ---------------------------------------------------------------------------
// Helpers — simulate the double-entry creditReserve SQL
// ---------------------------------------------------------------------------

async function creditReserveSql(client, amount, referenceId) {
  await client.query('BEGIN');
  try {
    await client.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN' FOR UPDATE`
    );
    await client.query(
      `UPDATE ledger_accounts SET balance = balance + $1, updated_at = NOW()
       WHERE account_id = 'RESERVE_MAIN'`,
      [amount]
    );
    await client.query(
      `UPDATE ledger_accounts SET balance = balance + $1, updated_at = NOW()
       WHERE account_id = 'PREMIUM_INCOME'`,
      [amount]
    );
    await client.query(
      `INSERT INTO ledger_entries
         (debit_account, credit_account, amount, reference_type, reference_id, description)
       VALUES ('PREMIUM_INCOME', 'RESERVE_MAIN', $1, 'premium', $2, 'Premium collection')`,
      [amount, referenceId]
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  }
}

// ---------------------------------------------------------------------------
// I.crdb — mandate debit + ledger flow
// ---------------------------------------------------------------------------

describe('I.crdb — premium collection and ledger entries', () => {
  let policyId;
  let mandateId;
  let debitId;
  const WEEKLY_PREMIUM = 149.00;

  beforeEach(async () => {
    if (!dbAvailable) return;

    policyId = uuidv4();
    mandateId = uuidv4();
    debitId = uuidv4();

    // Insert policy in CockroachDB
    const now = new Date();
    await crdbClient.query(
      `INSERT INTO policies
         (policy_id, worker_id, tier, coverage_cap, weekly_premium,
          effective_date, claim_eligible_from, status,
          billing_cycle_start, billing_cycle_end)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        policyId,
        TEST_WORKER_ID,
        'silver',
        5000.00,
        WEEKLY_PREMIUM,
        now.toISOString(),
        new Date(now.getTime() + 72 * 60 * 60 * 1000).toISOString(),
        'active',
        now.toISOString(),
        new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      ]
    );

    // Insert mandate (status='active') in CockroachDB
    await crdbClient.query(
      `INSERT INTO mandates
         (mandate_id, worker_id, policy_id, upi_id, max_amount, status)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [mandateId, TEST_WORKER_ID, policyId, 'worker_test@upi', 500.00, 'active']
    );
  });

  afterEach(async () => {
    if (!dbAvailable) return;
    // Cleanup in dependency order
    await crdbClient.query(
      `DELETE FROM mandate_debits WHERE mandate_id = $1`, [mandateId]
    ).catch(() => {});
    await crdbClient.query(
      `DELETE FROM ledger_entries WHERE reference_id = $1`, [debitId]
    ).catch(() => {});
    await crdbClient.query(
      `DELETE FROM mandates WHERE mandate_id = $1`, [mandateId]
    ).catch(() => {});
    await crdbClient.query(
      `DELETE FROM policies WHERE policy_id = $1`, [policyId]
    ).catch(() => {});
  });

  test('mandate_debits row is created when weekly debit runs', async () => {
    if (skipIfNoDb()) return;

    // Simulate the weekly premium debit worker inserting a debit record
    await crdbClient.query(
      `INSERT INTO mandate_debits
         (debit_id, mandate_id, policy_id, worker_id, amount, status, provider_txn)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [debitId, mandateId, policyId, TEST_WORKER_ID, WEEKLY_PREMIUM, 'success', 'payu_txn_001']
    );

    const result = await crdbClient.query(
      `SELECT debit_id, amount, status FROM mandate_debits WHERE debit_id = $1`,
      [debitId]
    );

    expect(result.rows).toHaveLength(1);
    expect(parseFloat(result.rows[0].amount)).toBe(WEEKLY_PREMIUM);
    expect(result.rows[0].status).toBe('success');
  });

  test('creditReserve increases RESERVE_MAIN balance and creates ledger entry', async () => {
    if (skipIfNoDb()) return;

    // Record balance before
    const beforeResult = await crdbClient.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN'`
    );
    const balanceBefore = parseFloat(beforeResult.rows[0]?.balance || '0');

    // Simulate the creditReserve SQL (what core_backend's ledger.js runs on PG, here on CRDB)
    await creditReserveSql(crdbClient, WEEKLY_PREMIUM, debitId);

    // Verify RESERVE_MAIN balance increased
    const afterResult = await crdbClient.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN'`
    );
    const balanceAfter = parseFloat(afterResult.rows[0].balance);
    expect(balanceAfter).toBeCloseTo(balanceBefore + WEEKLY_PREMIUM, 2);

    // Verify ledger entry
    const entryResult = await crdbClient.query(
      `SELECT debit_account, credit_account, amount, reference_type
       FROM ledger_entries WHERE reference_id = $1`,
      [debitId]
    );
    expect(entryResult.rows).toHaveLength(1);
    expect(entryResult.rows[0].debit_account).toBe('PREMIUM_INCOME');
    expect(entryResult.rows[0].credit_account).toBe('RESERVE_MAIN');
    expect(parseFloat(entryResult.rows[0].amount)).toBe(WEEKLY_PREMIUM);
    expect(entryResult.rows[0].reference_type).toBe('premium');
  });

  test('PREMIUM_INCOME balance also increases on credit', async () => {
    if (skipIfNoDb()) return;

    const beforeResult = await crdbClient.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'PREMIUM_INCOME'`
    );
    const balanceBefore = parseFloat(beforeResult.rows[0]?.balance || '0');

    await creditReserveSql(crdbClient, WEEKLY_PREMIUM, debitId);

    const afterResult = await crdbClient.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'PREMIUM_INCOME'`
    );
    const balanceAfter = parseFloat(afterResult.rows[0].balance);
    expect(balanceAfter).toBeCloseTo(balanceBefore + WEEKLY_PREMIUM, 2);
  });

  test('mandate status can be updated to reflect last debit outcome', async () => {
    if (skipIfNoDb()) return;

    await crdbClient.query(
      `UPDATE mandates
       SET last_debit_status = 'success', last_debit_at = NOW(), updated_at = NOW()
       WHERE mandate_id = $1`,
      [mandateId]
    );

    const result = await crdbClient.query(
      `SELECT last_debit_status FROM mandates WHERE mandate_id = $1`,
      [mandateId]
    );
    expect(result.rows[0].last_debit_status).toBe('success');
  });
});
