// Double-entry ledger service — serialized reserve enforcement
// Requirements: 9.2, 9.3, R6

'use strict';

const db = require('../db');

const REQUIRED_PAYOUT_FIELDS = [
  'payout_id',
  'worker_id',
  'claim_id',
  'amount',
  'oracle_votes',
  'zone_id',
  'tier',
  'created_at',
];

function validatePayoutRecord(record) {
  if (!record || typeof record !== 'object') {
    throw new Error('validatePayoutRecord: record must be a non-null object');
  }
  const missing = REQUIRED_PAYOUT_FIELDS.filter(
    (field) => record[field] === null || record[field] === undefined
  );
  if (missing.length > 0) {
    throw new Error(`Payout record is missing required fields: ${missing.join(', ')}`);
  }
}

/**
 * Atomically check reserve balance and debit reserve in a single serialized
 * transaction. Uses SELECT ... FOR UPDATE to prevent concurrent overdraw.
 *
 * @param {number} amount
 * @param {string} referenceId — payout_id or similar for the ledger entry
 * @returns {Promise<number>} remaining reserve balance after debit
 */
async function debitReserve(amount, referenceId) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    // Lock the reserve account row (serialized access)
    const lockResult = await client.query(
      `SELECT balance FROM ledger_accounts
       WHERE account_id = 'RESERVE_MAIN'
       FOR UPDATE`
    );

    if (lockResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw new Error('debitReserve: RESERVE_MAIN account not found');
    }

    const balance = parseFloat(lockResult.rows[0].balance);

    if (balance < amount) {
      await client.query('ROLLBACK');
      throw new Error(
        `Insufficient reserve: balance ${balance} < payout ${amount} (90-day constraint violated)`
      );
    }

    // Debit reserve, credit payout expense
    await client.query(
      `UPDATE ledger_accounts SET balance = balance - $1, updated_at = NOW()
       WHERE account_id = 'RESERVE_MAIN'`,
      [amount]
    );

    await client.query(
      `UPDATE ledger_accounts SET balance = balance + $1, updated_at = NOW()
       WHERE account_id = 'PAYOUT_EXPENSE'`,
      [amount]
    );

    // Record immutable ledger entry
    await client.query(
      `INSERT INTO ledger_entries
         (debit_account, credit_account, amount, reference_type, reference_id, description)
       VALUES ('RESERVE_MAIN', 'PAYOUT_EXPENSE', $1, 'payout', $2, 'Payout disbursement')`,
      [amount, referenceId]
    );

    await client.query('COMMIT');

    return balance - amount;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Credit the reserve from collected premiums. Serialized via FOR UPDATE.
 *
 * @param {number} amount
 * @param {string} referenceId — mandate debit ID or policy ID
 * @returns {Promise<number>} new reserve balance
 */
async function creditReserve(amount, referenceId) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

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

    const result = await db.query(
      `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN'`
    );
    return parseFloat(result.rows[0].balance);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Read-only reserve balance check (backward-compatible with old API).
 */
async function checkReserveBalance(amount) {
  const result = await db.query(
    `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN'`
  );

  if (result.rows.length === 0) {
    // Fall back to legacy single-row table
    const legacy = await db.query('SELECT balance FROM reserve_balance WHERE id = 1');
    if (legacy.rows.length === 0) {
      throw new Error('checkReserveBalance: no reserve account found');
    }
    const balance = parseFloat(legacy.rows[0].balance);
    if (balance < amount) {
      throw new Error(`Insufficient reserve: ${balance} < ${amount}`);
    }
    return balance;
  }

  const balance = parseFloat(result.rows[0].balance);
  if (balance < amount) {
    throw new Error(`Insufficient reserve: ${balance} < ${amount} (90-day constraint violated)`);
  }
  return balance;
}

/**
 * Validate, check reserve (serialized), and insert payout record.
 */
async function createPayoutRecord(record) {
  const normalized = {
    ...record,
    created_at: record.created_at ?? new Date(),
  };

  validatePayoutRecord(normalized);

  // Serialized reserve debit — prevents concurrent overdraw (R6)
  await debitReserve(normalized.amount, normalized.payout_id);

  const result = await db.query(
    `INSERT INTO payouts
       (payout_id, worker_id, claim_id, policy_id, amount,
        oracle_votes, zone_id, tier, payu_txn_ref, status, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING *`,
    [
      normalized.payout_id,
      normalized.worker_id,
      normalized.claim_id,
      normalized.policy_id ?? null,
      normalized.amount,
      JSON.stringify(normalized.oracle_votes),
      normalized.zone_id,
      normalized.tier,
      normalized.payu_txn_ref ?? null,
      normalized.status ?? 'pending',
      normalized.created_at,
    ]
  );

  return result.rows[0];
}

module.exports = {
  validatePayoutRecord,
  createPayoutRecord,
  checkReserveBalance,
  debitReserve,
  creditReserve,
};
