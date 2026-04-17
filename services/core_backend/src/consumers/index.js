// Kafka consumer manager — starts and stops all Kafka consumers
// Requirements: 8.1, G3, 14.1

'use strict';

const { startPayoutConsumer, stopPayoutConsumer } = require('./payout_consumer');
const { startEnrollmentLockConsumer, stopEnrollmentLockConsumer } = require('./enrollment_lock_consumer');
const { startClaimDecisionConsumer, stopClaimDecisionConsumer } = require('./claim_decision_consumer');

/**
 * Start all Kafka consumers.
 * Each consumer runs in the background and processes messages independently.
 *
 * Consumers:
 *   1. payout_consumer — payout_authorized → BullMQ payout_disbursement
 *   2. enrollment_lock_consumer — adverse_selection_lock → zone_enrollment_locks
 *   3. claim_decision_consumer — claim_decision → DB update + FCM + payout
 *
 * @returns {Promise<void>}
 */
async function startAllConsumers() {
  console.log('[consumers] Starting all Kafka consumers...');

  const results = await Promise.allSettled([
    startPayoutConsumer(),
    startEnrollmentLockConsumer(),
    startClaimDecisionConsumer(),
  ]);

  for (const result of results) {
    if (result.status === 'rejected') {
      console.error('[consumers] A consumer failed to start:', result.reason?.message);
    }
  }

  console.log('[consumers] All Kafka consumers started');
}

/**
 * Gracefully stop all Kafka consumers.
 * @returns {Promise<void>}
 */
async function stopAllConsumers() {
  console.log('[consumers] Stopping all Kafka consumers...');

  await Promise.allSettled([
    stopPayoutConsumer(),
    stopEnrollmentLockConsumer(),
    stopClaimDecisionConsumer(),
  ]);

  console.log('[consumers] All Kafka consumers stopped');
}

module.exports = { startAllConsumers, stopAllConsumers };
