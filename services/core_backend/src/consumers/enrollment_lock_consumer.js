// Kafka consumer: adverse_selection_lock topic → zone_enrollment_locks DB upsert
// Bridges the Oracle Forecast Engine to the enrollment lock enforcement
// Requirements: G3 — pre-event enrollment lockout for adverse selection prevention

'use strict';

const { Kafka } = require('kafkajs');
const db = require('../db');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const GROUP_ID = 'continuum-enrollment-lock-consumer';
const TOPIC = 'adverse_selection_lock';

let consumer = null;
let running = false;

/**
 * Process a single adverse_selection_lock message.
 *
 * Upserts into zone_enrollment_locks with:
 *   - zone_id from message
 *   - event_type from message
 *   - expires_at from message (typically NOW() + 72h, set by oracle engine)
 *   - forecast_data from message (raw forecast payload for audit)
 *
 * Uses ON CONFLICT DO UPDATE to extend the lock if a new forecast arrives
 * before the previous lock expires.
 *
 * @param {object} message — parsed Kafka message payload
 */
async function handleEnrollmentLock(message) {
  const {
    zone_id,
    event_type,
    expires_at,
    forecast_data = {},
    locked_at,
  } = message;

  if (!zone_id || !event_type) {
    console.error('[enrollment_lock_consumer] Message missing zone_id or event_type — skipping');
    return;
  }

  // Default expires_at to 72 hours from now if not provided
  const expiresAt = expires_at
    ? new Date(expires_at)
    : new Date(Date.now() + 72 * 60 * 60 * 1000);

  const lockedAt = locked_at ? new Date(locked_at) : new Date();

  try {
    await db.query(
      `INSERT INTO zone_enrollment_locks
         (zone_id, event_type, locked_at, expires_at, forecast_data)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (zone_id, event_type)
       DO UPDATE SET
         locked_at = EXCLUDED.locked_at,
         expires_at = GREATEST(zone_enrollment_locks.expires_at, EXCLUDED.expires_at),
         forecast_data = EXCLUDED.forecast_data`,
      [zone_id, event_type, lockedAt, expiresAt, JSON.stringify(forecast_data)]
    );

    console.log(
      `[enrollment_lock_consumer] Upserted enrollment lock: ` +
      `zone=${zone_id}, event=${event_type}, expires=${expiresAt.toISOString()}`
    );
  } catch (err) {
    console.error(
      `[enrollment_lock_consumer] Failed to upsert lock for zone ${zone_id}:`,
      err.message
    );
    throw err;
  }
}

/**
 * Start the Kafka consumer for the adverse_selection_lock topic.
 * @returns {Promise<void>}
 */
async function startEnrollmentLockConsumer() {
  if (running) {
    console.warn('[enrollment_lock_consumer] Already running — skipping start');
    return;
  }

  const kafka = new Kafka({
    clientId: 'continuum-enrollment-lock-consumer',
    brokers: KAFKA_BROKERS,
    retry: { retries: 5 },
  });

  consumer = kafka.consumer({ groupId: GROUP_ID });
  await consumer.connect();
  await consumer.subscribe({ topic: TOPIC, fromBeginning: false });

  running = true;
  console.log(`[enrollment_lock_consumer] Connected and subscribed to topic: ${TOPIC}`);

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const payload = JSON.parse(message.value.toString());
        await handleEnrollmentLock(payload);
      } catch (err) {
        console.error(
          `[enrollment_lock_consumer] Error processing message offset=${message.offset}:`,
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
async function stopEnrollmentLockConsumer() {
  if (consumer) {
    await consumer.disconnect();
    running = false;
    console.log('[enrollment_lock_consumer] Disconnected');
  }
}

module.exports = {
  startEnrollmentLockConsumer,
  stopEnrollmentLockConsumer,
  handleEnrollmentLock,
};
