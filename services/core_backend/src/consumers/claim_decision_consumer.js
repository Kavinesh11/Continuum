// Kafka consumer: claim_decision topic → DB update + FCM notification
// Bridges the Rust claims scoring service back to the Node.js core backend
// Requirements: 6.1, 15.2

'use strict';

const { Kafka } = require('kafkajs');
const db = require('../db');
const { enqueueJob, QUEUE_NAMES } = require('../workers/queues');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const GROUP_ID = 'continuum-claim-decision-consumer';
const TOPIC = 'claim_decision';

let consumer = null;
let running = false;

/**
 * Process a single claim_decision message from the Rust claims scoring service.
 *
 * Updates the claim status in the database and dispatches FCM notifications:
 *   - auto_approved → enqueue payout disbursement + success notification
 *   - fraud_queue → enqueue fraud review escalation + hold notification
 *   - device_not_attested / platform_activity_veto → denial notification
 *
 * @param {object} message — { claim_id, worker_id, status, fraud_score, decided_at }
 */
async function handleClaimDecision(message) {
  const { claim_id, worker_id, status, fraud_score, decided_at } = message;

  if (!claim_id || !worker_id || !status) {
    console.error('[claim_decision_consumer] Message missing required fields — skipping');
    return;
  }

  console.log(
    `[claim_decision_consumer] Claim ${claim_id}: status=${status}, fraud_score=${fraud_score}`
  );

  // Update claim record in the database
  await db.query(
    `UPDATE claims
     SET status = $1, fraud_score = $2, decided_at = $3
     WHERE claim_id = $4`,
    [status, fraud_score, decided_at || new Date(), claim_id]
  );

  // Route based on decision status
  switch (status) {
    case 'auto_approved': {
      // Fetch claim details for payout creation
      const claimResult = await db.query(
        `SELECT c.claim_id, c.worker_id, c.policy_id, c.zone_id, c.estimated_payout,
                p.tier, p.coverage_cap
         FROM claims c
         LEFT JOIN policies p ON p.policy_id = c.policy_id
         WHERE c.claim_id = $1`,
        [claim_id]
      );

      if (claimResult.rows.length > 0) {
        const claim = claimResult.rows[0];
        const amount = claim.estimated_payout
          ? parseFloat(claim.estimated_payout)
          : parseFloat(claim.coverage_cap || 0);

        if (amount > 0) {
          await enqueueJob(
            QUEUE_NAMES.PAYOUT_DISBURSEMENT,
            'claim_approved_payout',
            {
              payout_id: null, // Will be created by the disbursement processor
              worker_id: claim.worker_id,
              claim_id: claim.claim_id,
              policy_id: claim.policy_id,
              amount,
              zone_id: claim.zone_id,
              tier: claim.tier,
              trigger_fired_at: decided_at,
            }
          );
        }
      }

      // Send approval notification
      await enqueueJob(
        QUEUE_NAMES.NOTIFICATION_DISPATCH,
        'claim_approved',
        {
          worker_id,
          title: 'Claim Approved',
          body: 'Your claim has been approved. Payout will be credited shortly.',
          data: { event_type: 'claim_approved', claim_id },
        }
      );
      break;
    }

    case 'fraud_queue': {
      // Enqueue fraud review escalation
      await enqueueJob(
        QUEUE_NAMES.FRAUD_REVIEW_ESCALATION,
        'claim_fraud_review',
        { claim_id, worker_id, fraud_score, decided_at }
      );

      await enqueueJob(
        QUEUE_NAMES.NOTIFICATION_DISPATCH,
        'claim_under_review',
        {
          worker_id,
          title: 'Claim Under Review',
          body: 'Your claim is being reviewed. We will notify you once the review is complete.',
          data: { event_type: 'claim_under_review', claim_id },
        }
      );
      break;
    }

    case 'device_not_attested':
    case 'platform_activity_veto': {
      await enqueueJob(
        QUEUE_NAMES.NOTIFICATION_DISPATCH,
        'claim_denied',
        {
          worker_id,
          title: 'Claim Not Eligible',
          body: 'Your claim could not be processed. Please contact support for details.',
          data: { event_type: 'claim_denied', claim_id, reason: status },
        }
      );
      break;
    }

    default:
      console.warn(`[claim_decision_consumer] Unknown status: ${status}`);
  }
}

/**
 * Start the Kafka consumer for the claim_decision topic.
 * @returns {Promise<void>}
 */
async function startClaimDecisionConsumer() {
  if (running) {
    console.warn('[claim_decision_consumer] Already running — skipping start');
    return;
  }

  const kafka = new Kafka({
    clientId: 'continuum-claim-decision-consumer',
    brokers: KAFKA_BROKERS,
    retry: { retries: 5 },
  });

  consumer = kafka.consumer({ groupId: GROUP_ID });
  await consumer.connect();
  await consumer.subscribe({ topic: TOPIC, fromBeginning: false });

  running = true;
  console.log(`[claim_decision_consumer] Connected and subscribed to topic: ${TOPIC}`);

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const payload = JSON.parse(message.value.toString());
        await handleClaimDecision(payload);
      } catch (err) {
        console.error(
          `[claim_decision_consumer] Error processing message offset=${message.offset}:`,
          err.message
        );
      }
    },
  });
}

/**
 * Gracefully stop the Kafka consumer.
 * @returns {Promise<void>}
 */
async function stopClaimDecisionConsumer() {
  if (consumer) {
    await consumer.disconnect();
    running = false;
    console.log('[claim_decision_consumer] Disconnected');
  }
}

module.exports = {
  startClaimDecisionConsumer,
  stopClaimDecisionConsumer,
  handleClaimDecision,
};
