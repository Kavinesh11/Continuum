// Feature: continuum-ml-pipelines
// payout_disbursement queue processor
// Requirements: 8.1, 8.2, 14.1, 14.2, 14.3, 14.4, 14.5

'use strict';

const db = require('../../db');
const { sendNotification } = require('../../services/fcm');
const {
  callPayUGateway,
  hasSIMChangedRecently,
  recordDisbursementStatus,
} = require('../../services/payu');
const { recordPayoutLatency } = require('../../services/metrics');

/**
 * Process a payout_disbursement job.
 *
 * Job data shape:
 *   { payout_id, worker_id, claim_id, policy_id, amount, zone_id, tier, oracle_votes }
 *
 * Requirements: 8.1, 8.2, 14.1, 14.2, 14.3, 14.4, 14.5
 *
 * @param {import('bullmq').Job} job
 */
async function processPayoutDisbursement(job) {
  const { payout_id, worker_id, claim_id, amount } = job.data;

  if (!payout_id || !worker_id || !claim_id || !amount) {
    throw new Error(`payout_disbursement: missing required fields in job ${job.id}`);
  }

  console.log(`[payout_disbursement] Processing job ${job.id} for payout ${payout_id}`);

  // Fetch worker UPI ID and FCM token
  const workerResult = await db.query(
    `SELECT upi_id, fcm_token, sim_changed_at FROM workers WHERE worker_id = $1`,
    [worker_id]
  );

  if (workerResult.rows.length === 0) {
    throw new Error(`payout_disbursement: worker ${worker_id} not found`);
  }

  const worker = workerResult.rows[0];

  // SIM change detection — hold disbursement if SIM changed within 6 hours (Req 14.4)
  const simChangedRecently = await hasSIMChangedRecently(worker_id);
  if (simChangedRecently) {
    console.warn(
      `[payout_disbursement] SIM change detected for worker ${worker_id} — holding payout ${payout_id}`
    );

    await recordDisbursementStatus(payout_id, 'held_sim_change');

    if (worker.fcm_token) {
      await sendNotification(
        worker.fcm_token,
        'Payout On Hold',
        'Your payout is on hold due to a recent SIM change. Please complete biometric re-confirmation.',
        { event_type: 'payout_held_sim_change', payout_id, worker_id }
      );
    }

    // Return without throwing — hold is intentional, job completes successfully
    return { payout_id, status: 'held_sim_change', reason: 'sim_change_detected' };
  }

  // Call PayU Gateway (Req 14.2)
  const payuResult = await callPayUGateway(payout_id, worker_id, worker.upi_id, amount);

  if (!payuResult.success) {
    // Record failed attempt then throw so BullMQ retries with exponential backoff (Req 8.2, 14.3)
    await recordDisbursementStatus(payout_id, 'failed');
    throw new Error(`PayU disbursement failed for payout ${payout_id}: ${payuResult.error}`);
  }

  // Record successful disbursement (Req 14.5, 9.3)
  await recordDisbursementStatus(payout_id, 'disbursed', payuResult.transaction_ref);

  // Record payout latency — trigger_fired_at is set by the oracle engine (G4)
  const triggerFiredAt = job.data.trigger_fired_at;
  if (triggerFiredAt) {
    const latencySeconds = (Date.now() - new Date(triggerFiredAt).getTime()) / 1000;
    recordPayoutLatency(latencySeconds);
  }

  // Send FCM notification within 30 seconds of successful disbursement (Req 15.2, 14.6)
  if (worker.fcm_token) {
    try {
      await sendNotification(
        worker.fcm_token,
        'Payout Credited',
        `₹${amount} has been credited to your UPI account.`,
        {
          event_type: 'payout_credited',
          payout_id,
          worker_id,
          amount: String(amount),
        }
      );
    } catch (fcmErr) {
      console.error(
        `[payout_disbursement] FCM notification failed for worker ${worker_id}:`,
        fcmErr.message
      );
    }
  }

  console.log(
    `[payout_disbursement] Completed job ${job.id}: payout ${payout_id} disbursed, txn ${payuResult.transaction_ref}`
  );
  return {
    payout_id,
    status: 'disbursed',
    transaction_ref: payuResult.transaction_ref,
  };
}

module.exports = {
  processPayoutDisbursement,
  // Re-export for backward compatibility and direct testing
  callPayUGateway,
  hasSIMChangedRecently,
};
