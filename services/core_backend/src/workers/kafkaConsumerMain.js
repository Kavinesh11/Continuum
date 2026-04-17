'use strict';

require('dotenv').config();

const path = require('path');
const { KafkaConsumer } = require('../services/kafkaConsumer');
const { handlePayoutAuthorized } = require('./consumers/payoutAuthorizedHandler');
const { handleEnrollmentLock } = require('./consumers/enrollmentLockHandler');
const { handleFraudAlert } = require('./consumers/fraudAlertHandler');

function loadSchema(name) {
  return require(path.resolve(__dirname, '../../../../contracts/oracle_events', `${name}.schema.json`));
}

async function main() {
  const consumer = new KafkaConsumer();

  consumer.register(
    'payout_authorized',
    loadSchema('payout_authorized'),
    handlePayoutAuthorized
  );

  consumer.register(
    'adverse_selection_lock',
    loadSchema('enrollment_lock'),
    handleEnrollmentLock
  );

  consumer.register(
    'fraud_alert',
    loadSchema('fraud_alert'),
    handleFraudAlert
  );

  await consumer.start();
  console.log('[kafka-consumer-main] All topic consumers running');

  const shutdown = async () => {
    console.log('[kafka-consumer-main] Shutting down...');
    await consumer.stop();
    process.exit(0);
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  console.error('[kafka-consumer-main] Fatal error:', err);
  process.exit(1);
});
