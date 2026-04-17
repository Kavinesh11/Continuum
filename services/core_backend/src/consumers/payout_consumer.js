// Kafka consumer: payout_authorized topic → BullMQ payout_disbursement jobs
// Bridges the Oracle Consensus Engine to the payout pipeline
// Requirements: 8.1, 14.1 — zero-touch automated payout flow

'use strict';

const { Kafka } = require('kafkajs');
const db = require('../db');
const { enqueueJob, QUEUE_NAMES } = require('../workers/queues');
const { createPayoutRecord } = require('../services/ledger');
const { v4: uuidv4 } = require('uuid');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const GROUP_ID = 'continuum-payout-consumer';
const TOPIC = 'payout_authorized';

let consumer = null;
let running = false;

/**
 * Compute payout amount for a given policy based on oracle result.
 *
 * Formula:
 *   payout_amount = coverage_cap × payout_cap
 *
 * Where payout_cap is:
 *   1.0 — normal trigger (3-of-N consensus met)
 *   0.5 — benefit-of-doubt protocol (oracle infrastructure failure)
 *
 * @param {object} policy — { coverage_cap, tier }
 * @param {number} payoutCap — 1.0 or 0.5
 * @returns {number}
 */
function computePayoutAmount(policy, payoutCap) {
  const coverageCap = parseFloat(policy.coverage_cap);
  return Math.round(coverageCap * payoutCap * 100) / 100;
}

/**
 * Process a single payout_authorized message.
 *
 * For each eligible active policy in the triggered zone:
 *   1. Check claim_eligible_from (72h activation delay)
 *   2. Check payout cycle cap (≤1 per 7-day cycle)
 *   3. Compute payout amount from policy tier + payout_cap
 *   4. Create payout record with serialized reserve debit (ledger.js)
 *   5. Enqueue BullMQ job for UPI disbursement (PayU gateway)
 *
 * @param {object} message — parsed Kafka message payload
 */
async function handlePayoutAuthorized(message) {
  const {
    zone_id,
    oracle_votes,
    payout_cap = 1.0,
    benefit_of_doubt = false,
    authorized_at,
  } = message;

  if (!zone_id) {
    console.error('[payout_consumer] Message missing zone_id — skipping');
    return;
  }

  console.log(
    `[payout_consumer] Processing payout_authorized for zone ${zone_id}, ` +
    `cap=${payout_cap}, benefit_of_doubt=${benefit_of_doubt}`
  );

  // Fetch all active, eligible policies in this zone
  const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
  const sevenDaysAgo = new Date(Date.now() - SEVEN_DAYS_MS);

  const policyResult = await db.query(
    `SELECT p.policy_id, p.worker_id, p.tier, p.coverage_cap,
            p.claim_eligible_from, p.billing_cycle_start, p.billing_cycle_end
     FROM policies p
     WHERE p.zone_id = $1
       AND p.status = 'active'
       AND p.cancelled_at IS NULL
       AND p.claim_eligible_from <= NOW()`,
    [zone_id]
  );

  const policies = policyResult.rows;
  console.log(`[payout_consumer] Found ${policies.length} eligible policies in zone ${zone_id}`);

  let processed = 0;
  let skipped = 0;

  for (const policy of policies) {
    try {
      // Check payout cycle cap: ≤1 successful payout per 7-day billing cycle
      const existingPayout = await db.query(
        `SELECT payout_id FROM payouts
         WHERE worker_id = $1
           AND policy_id = $2
           AND status = 'disbursed'
           AND created_at >= $3`,
        [policy.worker_id, policy.policy_id, sevenDaysAgo]
      );

      if (existingPayout.rows.length > 0) {
        console.log(
          `[payout_consumer] Skipping policy ${policy.policy_id} — ` +
          `payout cycle cap already reached`
        );
        skipped++;
        continue;
      }

      // Compute payout amount
      const amount = computePayoutAmount(policy, payout_cap);
      if (amount <= 0) {
        console.warn(`[payout_consumer] Computed amount ≤ 0 for policy ${policy.policy_id} — skipping`);
        skipped++;
        continue;
      }

      // Create claim record for audit trail
      const claimId = uuidv4();
      await db.query(
        `INSERT INTO claims
           (claim_id, worker_id, policy_id, event_type, event_timestamp,
            zone_id, status, fraud_score, estimated_payout, submitted_at, decided_at)
         VALUES ($1, $2, $3, 'parametric_trigger', $4, $5, 'auto_approved', 1.0, $6, NOW(), NOW())`,
        [claimId, policy.worker_id, policy.policy_id, authorized_at || new Date(), zone_id, amount]
      );

      // Create payout record with serialized reserve debit
      const payoutId = uuidv4();
      await createPayoutRecord({
        payout_id: payoutId,
        worker_id: policy.worker_id,
        claim_id: claimId,
        policy_id: policy.policy_id,
        amount,
        oracle_votes: oracle_votes || [],
        zone_id,
        tier: policy.tier,
        status: 'pending',
        created_at: new Date(),
      });

      // Enqueue BullMQ job for UPI disbursement via PayU
      await enqueueJob(
        QUEUE_NAMES.PAYOUT_DISBURSEMENT,
        'oracle_triggered_payout',
        {
          payout_id: payoutId,
          worker_id: policy.worker_id,
          claim_id: claimId,
          policy_id: policy.policy_id,
          amount,
          zone_id,
          tier: policy.tier,
          oracle_votes: oracle_votes || [],
          trigger_fired_at: authorized_at,
          benefit_of_doubt,
        }
      );

      // Enqueue FCM notification
      await enqueueJob(
        QUEUE_NAMES.NOTIFICATION_DISPATCH,
        'payout_initiated',
        {
          worker_id: policy.worker_id,
          title: 'Payout Initiated',
          body: `A ₹${amount} payout has been initiated to your UPI account.`,
          data: {
            event_type: 'payout_initiated',
            payout_id: payoutId,
            amount: String(amount),
          },
        }
      );

      processed++;
      console.log(
        `[payout_consumer] Created payout ${payoutId} for worker ${policy.worker_id}, ₹${amount}`
      );
    } catch (err) {
      console.error(
        `[payout_consumer] Failed to process policy ${policy.policy_id}:`,
        err.message
      );
      // Continue processing remaining policies — don't fail the entire batch
    }
  }

  console.log(
    `[payout_consumer] Zone ${zone_id}: processed=${processed}, skipped=${skipped}, total=${policies.length}`
  );
}

/**
 * Start the Kafka consumer for the payout_authorized topic.
 * Runs in the background and processes messages as they arrive.
 *
 * @returns {Promise<void>}
 */
async function startPayoutConsumer() {
  if (running) {
    console.warn('[payout_consumer] Already running — skipping start');
    return;
  }

  const kafka = new Kafka({
    clientId: 'continuum-payout-consumer',
    brokers: KAFKA_BROKERS,
    retry: { retries: 5 },
  });

  consumer = kafka.consumer({ groupId: GROUP_ID });
  await consumer.connect();
  await consumer.subscribe({ topic: TOPIC, fromBeginning: false });

  running = true;
  console.log(`[payout_consumer] Connected and subscribed to topic: ${TOPIC}`);

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const startMs = Date.now();
      try {
        const payload = JSON.parse(message.value.toString());
        await handlePayoutAuthorized(payload);
        const durationMs = Date.now() - startMs;
        console.log(
          `[payout_consumer] Processed message offset=${message.offset} in ${durationMs}ms`
        );
      } catch (err) {
        console.error(
          `[payout_consumer] Error processing message offset=${message.offset}:`,
          err.message
        );
        // Don't re-throw — commit the offset to avoid infinite retry loops.
        // Failed payouts are logged for manual investigation.
      }
    },
  });
}

/**
 * Gracefully stop the Kafka consumer.
 * @returns {Promise<void>}
 */
async function stopPayoutConsumer() {
  if (consumer) {
    await consumer.disconnect();
    running = false;
    console.log('[payout_consumer] Disconnected');
  }
}

module.exports = {
  startPayoutConsumer,
  stopPayoutConsumer,
  handlePayoutAuthorized,
  computePayoutAmount,
};
