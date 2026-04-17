// Feature: continuum-ml-pipelines
// BullMQ worker entry point — starts all four queue workers
// Requirements: 2.1, 2.2, 8.1, 8.2, 8.3, 8.4, 8.5

'use strict';

require('dotenv').config();

const { Worker } = require('bullmq');
const { REDIS_CONNECTION, BACKOFF_DELAYS, QUEUE_NAMES, getQueue } = require('./queues');
const { processPremiumRecalculation } = require('./processors/premiumRecalculation');
const { processPayoutDisbursement } = require('./processors/payoutDisbursement');
const { processNotificationDispatch } = require('./processors/notificationDispatch');
const { processFraudReviewEscalation } = require('./processors/fraudReviewEscalation');
const { processWeeklyPremiumDebit, scheduleWeeklyDebits } = require('./processors/weeklyPremiumDebit');
const { processGpsRetentionSweep } = require('./processors/gpsRetentionSweep');
const kafka = require('../services/kafka');
const { recordJobEvent } = require('./metrics');
const { startMetricsServer } = require('./metricsServer');

// ─── Exponential backoff strategy ────────────────────────────────────────────
// delays = [1s, 2s, 4s, 8s, 16s], max 5 attempts, then DLQ (Requirements 8.2)

/**
 * Custom backoff strategy: returns delay in ms for attempt N (1-indexed).
 * Attempt 1 → 1000ms, 2 → 2000ms, 3 → 4000ms, 4 → 8000ms, 5 → 16000ms
 */
function customBackoffStrategy(attemptsMade) {
  const idx = Math.min(attemptsMade - 1, BACKOFF_DELAYS.length - 1);
  return BACKOFF_DELAYS[idx];
}

// ─── Worker factory ───────────────────────────────────────────────────────────

/**
 * Create a BullMQ Worker for a given queue with shared error handling.
 *
 * @param {string} queueName
 * @param {Function} processor - async (job) => result
 * @returns {Worker}
 */
function createWorker(queueName, processor) {
  const worker = new Worker(
    queueName,
    async (job) => {
      const start = Date.now();
      try {
        const result = await processor(job);
        const durationMs = Date.now() - start;
        console.log(`[${queueName}] Job ${job.id} completed in ${durationMs}ms`);
        return result;
      } catch (err) {
        const durationMs = Date.now() - start;
        console.error(`[${queueName}] Job ${job.id} failed after ${durationMs}ms:`, err.message);
        throw err; // Re-throw so BullMQ handles retry/DLQ
      }
    },
    {
      connection: REDIS_CONNECTION,
      // Custom backoff: BullMQ calls this to get delay for each retry
      settings: {
        backoffStrategy: customBackoffStrategy,
      },
    }
  );

  // ── Event listeners ──────────────────────────────────────────────────────

  worker.on('completed', (job, result) => {
    console.log(`[${queueName}] ✓ Job ${job.id} completed`);
    recordJobEvent(queueName, 'completed');
  });

  worker.on('failed', (job, err) => {
    const attempts = job ? job.attemptsMade : '?';
    console.error(`[${queueName}] ✗ Job ${job?.id} failed (attempt ${attempts}):`, err.message);
    recordJobEvent(queueName, 'failed');

    // After max attempts the job moves to the failed set (DLQ)
    if (job && job.attemptsMade >= 5) {
      console.warn(`[${queueName}] Job ${job.id} moved to DLQ after ${job.attemptsMade} attempts`);
      recordJobEvent(queueName, 'dlq');
    }
  });

  worker.on('error', (err) => {
    console.error(`[${queueName}] Worker error:`, err.message);
  });

  return worker;
}

// ─── Prometheus metric helpers ────────────────────────────────────────────────
// recordJobEvent is imported from ./metrics and wired into worker event listeners above.
// getJobCounters is kept for backward compatibility with existing tests.

const jobCounters = {};

function getJobCounters() {
  return { ...jobCounters };
}

// ─── DLQ monitor — publishes fraud_alert for payout_disbursement DLQ entries > 24h ──
// Requirements: 8.4

const DLQ_CHECK_INTERVAL_MS = 5 * 60 * 1000; // check every 5 minutes

async function checkDLQEscalations() {
  try {
    const queue = getQueue(QUEUE_NAMES.PAYOUT_DISBURSEMENT);
    const failedJobs = await queue.getFailed(0, 100);

    const twentyFourHoursAgo = Date.now() - 24 * 60 * 60 * 1000;

    for (const job of failedJobs) {
      const finishedOn = job.finishedOn || 0;
      if (finishedOn > 0 && finishedOn < twentyFourHoursAgo) {
        console.warn(`[DLQ monitor] payout_disbursement job ${job.id} has been in DLQ > 24h — publishing fraud_alert`);
        try {
          await kafka.publishEvent('fraud_alert', {
            alert_type: 'dlq_escalation',
            queue: QUEUE_NAMES.PAYOUT_DISBURSEMENT,
            job_id: job.id,
            job_data: job.data,
            failed_at: new Date(finishedOn).toISOString(),
            triggered_at: new Date().toISOString(),
          });
        } catch (kafkaErr) {
          console.error('[DLQ monitor] Kafka publish failed:', kafkaErr.message);
        }
      }
    }
  } catch (err) {
    console.error('[DLQ monitor] Error checking DLQ:', err.message);
  }
}

// ─── Weekly premium_recalculation scheduler ───────────────────────────────────
// Requirements: 2.1, 8.5 — schedule weekly jobs for all active policies at billing cycle start

const { enqueueJob } = require('./queues');
const db = require('../db');

/**
 * Schedule premium_recalculation jobs for all active policies.
 * Designed to run at the start of each 7-day billing cycle.
 * All jobs must complete within a 1-hour window (Requirements 8.5).
 *
 * @returns {Promise<number>} Number of jobs enqueued
 */
async function scheduleWeeklyPremiumRecalculation() {
  console.log('[scheduler] Starting weekly premium_recalculation scheduling...');

  let result;
  try {
    result = await db.query(
      `SELECT p.policy_id, p.worker_id, p.tier, w.zone_id
       FROM policies p
       JOIN workers w ON w.worker_id = p.worker_id
       WHERE p.status = 'active'`
    );
  } catch (err) {
    console.error('[scheduler] DB query failed:', err.message);
    return 0;
  }

  const policies = result.rows;
  console.log(`[scheduler] Found ${policies.length} active policies to recalculate`);

  // Spread jobs across 1-hour window to avoid thundering herd (Requirements 8.5)
  const windowMs = 60 * 60 * 1000; // 1 hour
  const delayStep = policies.length > 0 ? Math.floor(windowMs / policies.length) : 0;

  let enqueued = 0;
  for (let i = 0; i < policies.length; i++) {
    const policy = policies[i];
    const delay = i * delayStep;

    try {
      await enqueueJob(
        QUEUE_NAMES.PREMIUM_RECALCULATION,
        'weekly_recalculation',
        {
          worker_id: policy.worker_id,
          policy_id: policy.policy_id,
          zone_id: policy.zone_id,
          tier: policy.tier,
        },
        { delay }
      );
      enqueued++;
    } catch (err) {
      console.error(`[scheduler] Failed to enqueue recalculation for policy ${policy.policy_id}:`, err.message);
    }
  }

  console.log(`[scheduler] Enqueued ${enqueued}/${policies.length} premium_recalculation jobs`);
  return enqueued;
}

/**
 * Set up a weekly cron-like schedule for premium recalculation.
 * Fires every 7 days at the configured billing cycle start time.
 * Requirements: 2.1, 8.5
 */
function startWeeklyScheduler() {
  const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

  // Run immediately on startup (for billing cycle start), then every 7 days
  scheduleWeeklyPremiumRecalculation().catch((err) => {
    console.error('[scheduler] Initial run failed:', err.message);
  });

  const intervalId = setInterval(() => {
    scheduleWeeklyPremiumRecalculation().catch((err) => {
      console.error('[scheduler] Weekly run failed:', err.message);
    });
  }, SEVEN_DAYS_MS);

  return intervalId;
}

// ─── Main startup ─────────────────────────────────────────────────────────────

let workers = [];
let dlqIntervalId = null;
let schedulerIntervalId = null;

/**
 * Start all BullMQ workers and the weekly scheduler.
 * @returns {{ workers: Worker[], stop: Function }}
 */
function startWorkers() {
  console.log('[workers] Starting BullMQ workers...');

  workers = [
    createWorker(QUEUE_NAMES.PREMIUM_RECALCULATION, processPremiumRecalculation),
    createWorker(QUEUE_NAMES.PAYOUT_DISBURSEMENT, processPayoutDisbursement),
    createWorker(QUEUE_NAMES.NOTIFICATION_DISPATCH, processNotificationDispatch),
    createWorker(QUEUE_NAMES.FRAUD_REVIEW_ESCALATION, processFraudReviewEscalation),
    createWorker(QUEUE_NAMES.WEEKLY_PREMIUM_DEBIT, processWeeklyPremiumDebit),
    createWorker('gps_retention_sweep', processGpsRetentionSweep),
  ];

  console.log(`[workers] Started ${workers.length} workers: ${Object.values(QUEUE_NAMES).join(', ')}`);

  // Start Prometheus metrics server on port 9102 (Requirements 8.3, 16.1)
  const metricsServer = startMetricsServer();

  // Start DLQ escalation monitor (Requirements 8.4)
  dlqIntervalId = setInterval(checkDLQEscalations, DLQ_CHECK_INTERVAL_MS);

  // Start weekly premium recalculation scheduler (Requirements 2.1, 8.5)
  schedulerIntervalId = startWeeklyScheduler();

  // Schedule daily GPS retention sweep (DPDP compliance — 60-day TTL)
  const sweepQueue = getQueue('gps_retention_sweep');
  sweepQueue.add('daily_sweep', {}, {
    repeat: { pattern: '0 4 * * *' },
    removeOnComplete: 100,
    removeOnFail: 50,
  }).catch(err => console.error('[workers] Failed to schedule GPS retention sweep:', err.message));

  async function stop() {
    console.log('[workers] Shutting down...');
    clearInterval(dlqIntervalId);
    clearInterval(schedulerIntervalId);
    await Promise.all(workers.map((w) => w.close()));
    await metricsServer.stop();
    await kafka.disconnect();
    console.log('[workers] All workers stopped');
  }

  return { workers, stop };
}

// ─── Standalone execution ─────────────────────────────────────────────────────

if (require.main === module) {
  const { stop } = startWorkers();

  process.on('SIGTERM', async () => {
    await stop();
    process.exit(0);
  });

  process.on('SIGINT', async () => {
    await stop();
    process.exit(0);
  });
}

module.exports = {
  startWorkers,
  scheduleWeeklyPremiumRecalculation,
  customBackoffStrategy,
  getJobCounters,
  checkDLQEscalations,
};
