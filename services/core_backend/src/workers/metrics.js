// Feature: continuum-ml-pipelines
// Prometheus metrics for BullMQ workers
// Requirements: 8.3, 16.1, 16.3

'use strict';

const client = require('prom-client');

// Use a dedicated registry to avoid conflicts with the main app's default registry
const registry = new client.Registry();
registry.setDefaultLabels({ service: 'bullmq_worker' });

// ─── Counters ─────────────────────────────────────────────────────────────────

const jobsCompletedTotal = new client.Counter({
  name: 'bullmq_jobs_completed_total',
  help: 'Total number of BullMQ jobs completed successfully',
  labelNames: ['queue'],
  registers: [registry],
});

const jobsFailedTotal = new client.Counter({
  name: 'bullmq_jobs_failed_total',
  help: 'Total number of BullMQ jobs that failed (all attempts exhausted)',
  labelNames: ['queue'],
  registers: [registry],
});

// ─── Gauges ───────────────────────────────────────────────────────────────────

const queueDepth = new client.Gauge({
  name: 'bullmq_queue_depth',
  help: 'Current number of waiting jobs in the queue',
  labelNames: ['queue'],
  registers: [registry],
});

// Alert rule: DLQ depth > 10 jobs → trigger manual intervention (Requirements 16.3)
const dlqDepth = new client.Gauge({
  name: 'bullmq_dlq_depth',
  help: 'Current number of jobs in the dead-letter queue (failed set). Alert when > 10.',
  labelNames: ['queue'],
  registers: [registry],
});

// ─── Public helpers ───────────────────────────────────────────────────────────

/**
 * Record a job lifecycle event for a given queue.
 * Called from BullMQ worker event listeners.
 *
 * @param {string} queueName
 * @param {'completed'|'failed'|'dlq'} eventType
 */
function recordJobEvent(queueName, eventType) {
  switch (eventType) {
    case 'completed':
      jobsCompletedTotal.inc({ queue: queueName });
      break;
    case 'failed':
      jobsFailedTotal.inc({ queue: queueName });
      break;
    case 'dlq':
      // DLQ depth is a gauge updated by refreshQueueDepths; this is a belt-and-suspenders inc
      dlqDepth.inc({ queue: queueName });
      break;
    default:
      break;
  }
}

/**
 * Refresh queue depth gauges by querying BullMQ for current waiting + failed counts.
 * Call this periodically (e.g., every 15s) to keep gauges accurate.
 *
 * @param {Function} getQueue - `getQueue(name)` from queues.js
 * @param {string[]} queueNames - list of queue names to refresh
 */
async function refreshQueueDepths(getQueue, queueNames) {
  for (const name of queueNames) {
    try {
      const queue = getQueue(name);
      const [waiting, failed] = await Promise.all([
        queue.getWaitingCount(),
        queue.getFailedCount(),
      ]);
      queueDepth.set({ queue: name }, waiting);
      dlqDepth.set({ queue: name }, failed);
    } catch (err) {
      // Non-fatal — log and continue
      console.error(`[metrics] Failed to refresh depth for queue ${name}:`, err.message);
    }
  }
}

/**
 * Return the Prometheus metrics string for the /metrics endpoint.
 * @returns {Promise<string>}
 */
async function getMetrics() {
  return registry.metrics();
}

/**
 * Content type for Prometheus exposition format.
 */
const contentType = client.Registry.OPENMETRICS_CONTENT_TYPE;

module.exports = { recordJobEvent, refreshQueueDepths, getMetrics, contentType, registry };
