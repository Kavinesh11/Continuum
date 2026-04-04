// Feature: continuum-ml-pipelines
// PayU UPI Payout Gateway client
// Requirements: 14.2, 14.4

'use strict';

const db = require('../db');

/**
 * Call the PayU UPI payout API to disburse funds to a worker's UPI ID.
 *
 * The job must be executed within 60 seconds of enqueue (enforced by the
 * BullMQ processor timeout; this function itself has a 30-second HTTP timeout).
 *
 * @param {string} payoutId     - Unique payout identifier
 * @param {string} workerId     - Worker UUID
 * @param {string} upiId        - Worker's registered UPI ID
 * @param {number} amount       - Amount in INR
 * @returns {Promise<{ success: boolean, transaction_ref?: string, error?: string }>}
 */
async function callPayUGateway(payoutId, workerId, upiId, amount) {
  const payuBaseUrl = process.env.PAYU_BASE_URL || 'http://localhost:9000';
  const payuApiKey = process.env.PAYU_API_KEY || '';

  try {
    const fetch = require('node-fetch');
    const response = await fetch(`${payuBaseUrl}/api/payout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${payuApiKey}`,
      },
      body: JSON.stringify({
        payout_id: payoutId,
        worker_id: workerId,
        upi_id: upiId,
        amount,
        currency: 'INR',
      }),
      timeout: 30000,
    });

    if (response.ok) {
      const result = await response.json();
      return {
        success: true,
        transaction_ref: result.transaction_ref || result.txn_id,
      };
    }

    const errBody = await response.text();
    return { success: false, error: `PayU returned ${response.status}: ${errBody}` };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Check whether a SIM change was detected on the worker's account within the
 * last 6 hours. If so, the disbursement must be held and biometric
 * re-confirmation required before releasing funds.
 *
 * Requirements: 14.4
 *
 * @param {string} workerId
 * @returns {Promise<boolean>} true if SIM changed within the last 6 hours
 */
async function hasSIMChangedRecently(workerId) {
  const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
  const result = await db.query(
    `SELECT sim_changed_at FROM workers WHERE worker_id = $1`,
    [workerId]
  );
  if (result.rows.length === 0) return false;
  const { sim_changed_at } = result.rows[0];
  if (!sim_changed_at) return false;
  return new Date(sim_changed_at) >= sixHoursAgo;
}

/**
 * Record the final disbursement outcome to the CockroachDB `payouts` table.
 *
 * On success: sets status = 'disbursed', payu_txn_ref, disbursed_at = NOW()
 * On failure: sets status = 'failed'
 * On SIM hold: sets status = 'held_sim_change'
 *
 * Requirements: 14.5
 *
 * @param {string} payoutId
 * @param {'disbursed'|'failed'|'held_sim_change'} status
 * @param {string|null} [txnRef]
 * @returns {Promise<void>}
 */
async function recordDisbursementStatus(payoutId, status, txnRef = null) {
  if (status === 'disbursed') {
    await db.query(
      `UPDATE payouts
       SET status = 'disbursed',
           payu_txn_ref = $1,
           disbursed_at = NOW()
       WHERE payout_id = $2`,
      [txnRef, payoutId]
    );
  } else if (status === 'failed') {
    await db.query(
      `UPDATE payouts SET status = 'failed' WHERE payout_id = $1`,
      [payoutId]
    );
  } else if (status === 'held_sim_change') {
    await db.query(
      `UPDATE payouts SET status = 'held_sim_change' WHERE payout_id = $1`,
      [payoutId]
    );
  } else {
    throw new Error(`recordDisbursementStatus: unknown status '${status}'`);
  }
}

module.exports = { callPayUGateway, hasSIMChangedRecently, recordDisbursementStatus };
