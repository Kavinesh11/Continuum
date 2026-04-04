// Feature: continuum-ml-pipelines
// Kafka producer wrapper using kafkajs
// Requirements: 6.8, 7.1

'use strict';

const { Kafka } = require('kafkajs');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'localhost:9092').split(',');
const CLIENT_ID = process.env.KAFKA_CLIENT_ID || 'continuum-core-backend';

let producer = null;
let kafka = null;

/**
 * Get or create the Kafka producer instance.
 * Lazily initializes on first call.
 * @returns {Promise<import('kafkajs').Producer>}
 */
async function getProducer() {
  if (producer) return producer;

  kafka = new Kafka({
    clientId: CLIENT_ID,
    brokers: KAFKA_BROKERS,
    retry: { retries: 3 },
  });

  producer = kafka.producer();
  await producer.connect();
  return producer;
}

/**
 * Publish a message to a Kafka topic.
 * @param {string} topic - Kafka topic name
 * @param {object} payload - JSON-serializable message payload
 * @returns {Promise<void>}
 */
async function publishEvent(topic, payload) {
  const prod = await getProducer();
  await prod.send({
    topic,
    messages: [{ value: JSON.stringify(payload) }],
  });
}

/**
 * Disconnect the Kafka producer (for graceful shutdown).
 * @returns {Promise<void>}
 */
async function disconnect() {
  if (producer) {
    await producer.disconnect();
    producer = null;
  }
}

module.exports = { publishEvent, disconnect, getProducer };
