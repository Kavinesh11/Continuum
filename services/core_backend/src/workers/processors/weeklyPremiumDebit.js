// Weekly premium debit processor — debits active mandates for recurring premiums
// Requirements: G2 — frictionless premium collection via UPI eNACH

'use strict';

const db = require('../../db');
const { executeDebit } = require('../../services/upi_mandate');
const { incrementPremiumsCollected } = require('../../services/metrics');

/**
 * Process a weekly_premium_debit job.
 *
 * Job data: { policy_id, mandate_id, amount }
 *
 * @param {import('bullmq').Job} job
 */
async function processWeeklyPremiumDebit(job) {
  const { policy_id, mandate_id, amount } = job.data;

  if (!policy_id || !mandate_id || !amount) {
    throw new Error(`weekly_premium_debit: missing fields in job ${job.id}`);
  }

  console.log(`[weekly_premium_debit] Debiting ₹${amount} for policy ${policy_id} via mandate ${mandate_id}`);

  const result = await executeDebit(mandate_id, amount);

  incrementPremiumsCollected(parseFloat(amount));

  console.log(`[weekly_premium_debit] Completed: debit ${result.debit_id}, txn ${result.txn_ref}`);
  return { policy_id, mandate_id, debit_id: result.debit_id, status: result.status };
}

/**
 * Schedule weekly premium debits for all active policies with active mandates.
 * Called by the weekly scheduler.
 *
 * @returns {Promise<number>} number of debit jobs enqueued
 */
async function scheduleWeeklyDebits() {
  const { enqueueJob, QUEUE_NAMES } = require('../queues');

  const result = await db.query(
    `SELECT p.policy_id, p.weekly_premium, m.mandate_id
     FROM policies p
     JOIN mandates m ON m.policy_id = p.policy_id
     WHERE p.status = 'active'
       AND m.status IN ('active', 'approved')`
  );

  const policies = result.rows;
  console.log(`[weekly_premium_debit] Found ${policies.length} policies with active mandates`);

  const windowMs = 60 * 60 * 1000;
  const delayStep = policies.length > 0 ? Math.floor(windowMs / policies.length) : 0;

  let enqueued = 0;
  for (let i = 0; i < policies.length; i++) {
    const row = policies[i];
    try {
      await enqueueJob(
        QUEUE_NAMES.WEEKLY_PREMIUM_DEBIT,
        'weekly_debit',
        {
          policy_id: row.policy_id,
          mandate_id: row.mandate_id,
          amount: parseFloat(row.weekly_premium),
        },
        { delay: i * delayStep }
      );
      enqueued++;
    } catch (err) {
      console.error(`[weekly_premium_debit] Failed to enqueue for policy ${row.policy_id}:`, err.message);
    }
  }

  console.log(`[weekly_premium_debit] Enqueued ${enqueued}/${policies.length} debit jobs`);
  return enqueued;
}

module.exports = { processWeeklyPremiumDebit, scheduleWeeklyDebits };
