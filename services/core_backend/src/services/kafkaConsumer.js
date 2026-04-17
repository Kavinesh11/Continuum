'use strict';

const { Kafka } = require('kafkajs');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const client = require('prom-client');
const db = require('../db');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const GROUP_ID_PREFIX = process.env.KAFKA_GROUP_PREFIX || 'continuum-consumer';

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

// ─── Prometheus metrics ──────────────────────────────────────────────────────

const messagesTotal = new client.Counter({
  name: 'kafka_messages_total',
  help: 'Total Kafka messages processed',
  labelNames: ['topic', 'status'],
});

const consumerLag = new client.Histogram({
  name: 'continuum_kafka_consumer_lag_seconds',
  help: 'Kafka consumer lag in seconds',
  labelNames: ['topic'],
  buckets: [0.1, 0.5, 1, 5, 10, 30, 60, 120],
});

// ─── Idempotency: ensure each event_id is processed exactly once ─────────────

const IDEMPOTENCY_TABLE = 'consumed_events';

async function ensureIdempotencyTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS ${IDEMPOTENCY_TABLE} (
      event_id   TEXT PRIMARY KEY,
      topic      TEXT NOT NULL,
      consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function isAlreadyConsumed(eventId) {
  const result = await db.query(
    `SELECT 1 FROM ${IDEMPOTENCY_TABLE} WHERE event_id = $1`,
    [eventId]
  );
  return result.rows.length > 0;
}

async function markConsumed(eventId, topic) {
  await db.query(
    `INSERT INTO ${IDEMPOTENCY_TABLE} (event_id, topic) VALUES ($1, $2)
     ON CONFLICT (event_id) DO NOTHING`,
    [eventId, topic]
  );
}

// ─── KafkaConsumer dispatcher ────────────────────────────────────────────────

class KafkaConsumer {
  constructor() {
    this._kafka = new Kafka({
      clientId: `${GROUP_ID_PREFIX}-dispatcher`,
      brokers: KAFKA_BROKERS,
      retry: { retries: 5 },
    });
    this._handlers = new Map();
    this._consumers = [];
    this._running = false;
  }

  register(topic, schema, handler) {
    const validate = ajv.compile(schema);
    this._handlers.set(topic, { validate, handler });
  }

  async start() {
    await ensureIdempotencyTable();

    for (const [topic, { validate, handler }] of this._handlers) {
      const consumer = this._kafka.consumer({
        groupId: `${GROUP_ID_PREFIX}-${topic}`,
        retry: { retries: 3 },
      });

      await consumer.connect();
      await consumer.subscribe({ topic, fromBeginning: false });

      await consumer.run({
        eachMessage: async ({ topic: t, partition, message }) => {
          const raw = message.value.toString();
          let event;

          try {
            event = JSON.parse(raw);
          } catch (err) {
            console.error(`[kafka-consumer] ${t}: invalid JSON`, err.message);
            messagesTotal.inc({ topic: t, status: 'parse_error' });
            return;
          }

          if (!validate(event)) {
            console.error(`[kafka-consumer] ${t}: schema validation failed`, ajv.errorsText(validate.errors));
            messagesTotal.inc({ topic: t, status: 'schema_error' });
            return;
          }

          const eventId = event.event_id || event.payout_id || `${t}-${partition}-${message.offset}`;

          if (await isAlreadyConsumed(eventId)) {
            console.log(`[kafka-consumer] ${t}: duplicate event ${eventId}, skipping`);
            messagesTotal.inc({ topic: t, status: 'duplicate' });
            return;
          }

          const lagMs = Date.now() - (message.timestamp ? parseInt(message.timestamp, 10) : Date.now());
          consumerLag.observe({ topic: t }, lagMs / 1000);

          try {
            await handler(event);
            await markConsumed(eventId, t);
            messagesTotal.inc({ topic: t, status: 'processed' });
          } catch (err) {
            console.error(`[kafka-consumer] ${t}: handler error for ${eventId}`, err.message);
            messagesTotal.inc({ topic: t, status: 'handler_error' });

            try {
              const dlqProducer = this._kafka.producer();
              await dlqProducer.connect();
              await dlqProducer.send({
                topic: `${t}.dlq`,
                messages: [{
                  value: JSON.stringify({
                    original_event: event,
                    error: err.message,
                    failed_at: new Date().toISOString(),
                  }),
                }],
              });
              await dlqProducer.disconnect();
            } catch (dlqErr) {
              console.error(`[kafka-consumer] ${t}: DLQ publish failed`, dlqErr.message);
            }
          }
        },
      });

      this._consumers.push(consumer);
      console.log(`[kafka-consumer] Subscribed to topic: ${topic}`);
    }

    this._running = true;
  }

  async stop() {
    for (const consumer of this._consumers) {
      await consumer.disconnect();
    }
    this._consumers = [];
    this._running = false;
    console.log('[kafka-consumer] All consumers stopped');
  }
}

module.exports = {
  KafkaConsumer,
  messagesTotal,
  consumerLag,
  ensureIdempotencyTable,
  isAlreadyConsumed,
  markConsumed,
};
