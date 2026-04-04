// Feature: continuum-ml-pipelines
// CockroachDB payout record completeness enforcement and reserve balance constraint
// Requirements: 9.2, 9.3

'use strict';

const db = require('../db');

/**
 * Required fields for a complete payout record (Requirement 9.3).
 * Maps spec field names to the object property names used in this service.
 */
const REQUIRED_PAYOUT_FIELDS = [
  'payout_id',
  'worker_id',
  'claim_id',
  'amount',
  'oracle_votes',   // oracle_vote_breakdown in spec terminology
  'zone_id',
  'tier',
  'created_at',     // timestamp in spec terminology
];

/**
 * Validate that all required payout fields are present and non-null/non-undefined.
 *
 * Throws a descriptive Error listing every missing field if any are absent.
 *
 * Requirements: 9.3
 *
 * @param {object} record - Payout record to validate
 * @throws {Error} if any required field is null or undefined
 */
function validatePayoutRecord(record) {
  if (!record || typeof record !== 'object') {
    throw new Error('validatePayoutRecord: record must be a non-null object');
  }

  const missing = REQUIRED_PAYOUT_FIELDS.filter(
    (field) => record[field] === null || record[field] === undefined
  );

  if (missing.length > 0) {
    throw new Error(
      `Payout record is missing required fields: ${missing.join(', ')}`
    );
  }
}

/**
 * Check that the current reserve balance is sufficient to cover the requested
 * payout amount. Enforces the 90-day reserve balance constraint at the
 * application layer (Requirement 9.2).
 *
 * Queries the `reserve_balance` table (single-row, id=1) and throws if
 * balance < amount.
 *
 * @param {number} amount - Payout amount in INR
 * @returns {Promise<number>} The current reserve balance
 * @throws {Error} if reserve balance is insufficient or the table is empty
 */
async function checkReserveBalance(amount) {
  const result = await db.query(
    'SELECT balance FROM reserve_balance WHERE id = 1'
  );

  if (result.rows.length === 0) {
    throw new Error('checkReserveBalance: reserve_balance table has no row');
  }

  const balance = parseFloat(result.rows[0].balance);

  if (balance < amount) {
    throw new Error(
      `Insufficient reserve balance: balance ${balance} < requested payout ${amount} ` +
      '(90-day reserve constraint violated)'
    );
  }

  return balance;
}

/**
 * Validate a payout record for completeness, check reserve balance, then
 * INSERT the record into the CockroachDB `payouts` table.
 *
 * The `created_at` field defaults to NOW() if not supplied (the DB column
 * default also covers this, but we set it explicitly for the completeness
 * check to pass before the INSERT).
 *
 * Requirements: 9.2, 9.3
 *
 * @param {object} record - Payout record with all required fields
 * @param {string}  record.payout_id
 * @param {string}  record.worker_id
 * @param {string}  record.claim_id
 * @param {string}  record.policy_id
 * @param {number}  record.amount
 * @param {Array}   record.oracle_votes   - oracle_vote_breakdown array
 * @param {string}  record.zone_id
 * @param {string}  record.tier
 * @param {string|null} [record.payu_txn_ref]
 * @param {string}  [record.status]       - defaults to 'pending'
 * @param {Date|string} [record.created_at] - defaults to current timestamp
 * @returns {Promise<object>} The inserted payout row
 * @throws {Error} on validation failure, insufficient reserve, or DB error
 */
async function createPayoutRecord(record) {
  // Default created_at so the completeness check can pass even if caller omits it
  const normalized = {
    ...record,
    created_at: record.created_at ?? new Date(),
  };

  // 1. Enforce field completeness before any DB interaction
  validatePayoutRecord(normalized);

  // 2. Enforce 90-day reserve balance constraint (Requirement 9.2)
  await checkReserveBalance(normalized.amount);

  // 3. INSERT into CockroachDB payouts table
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

module.exports = { validatePayoutRecord, createPayoutRecord, checkReserveBalance };
