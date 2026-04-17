// Feature: continuum-ml-pipelines
// BullMQ queue definitions and shared configuration
// Requirements: 8.1, 8.2

'use strict';

const { Queue } = require('bullmq');

const REDIS_CONNECTION = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  password: process.env.REDIS_PASSWORD || undefined,
};

// Exponential backoff delays: [1s, 2s, 4s, 8s, 16s] — Requirements 8.2
const BACKOFF_DELAYS = [1000, 2000, 4000, 8000, 16000];
const MAX_ATTEMPTS = 5;

/**
 * Default job options with exponential backoff and max 5 attempts.
 * After 5 failures the job is moved to the dead-letter queue (failed set).
 */
const DEFAULT_JOB_OPTIONS = {
  attempts: MAX_ATTEMPTS,
  backoff: {
    type: 'custom',
  },
};

// Queue names
const QUEUE_NAMES = {
  PREMIUM_RECALCULATION: 'premium_recalculation',
  PAYOUT_DISBURSEMENT: 'payout_disbursement',
  NOTIFICATION_DISPATCH: 'notification_dispatch',
  FRAUD_REVIEW_ESCALATION: 'fraud_review_escalation',
  WEEKLY_PREMIUM_DEBIT: 'weekly_premium_debit',
};

// Lazily-created queue instances
const _queues = {};

/**
 * Get (or create) a BullMQ Queue instance by name.
 * @param {string} name - Queue name
 * @returns {Queue}
 */
function getQueue(name) {
  if (!_queues[name]) {
    _queues[name] = new Queue(name, { connection: REDIS_CONNECTION });
  }
  return _queues[name];
}

/**
 * Add a job to a queue with the standard exponential-backoff options.
 * @param {string} queueName
 * @param {string} jobName
 * @param {object} data
 * @param {object} [extraOpts]
 */
async function enqueueJob(queueName, jobName, data, extraOpts = {}) {
  const queue = getQueue(queueName);
  return queue.add(jobName, data, { ...DEFAULT_JOB_OPTIONS, ...extraOpts });
}

module.exports = {
  REDIS_CONNECTION,
  BACKOFF_DELAYS,
  MAX_ATTEMPTS,
  DEFAULT_JOB_OPTIONS,
  QUEUE_NAMES,
  getQueue,
  enqueueJob,
};
