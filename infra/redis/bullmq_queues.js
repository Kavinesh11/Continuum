// Feature: continuum-ml-pipelines
// Initializes BullMQ queues backed by Redis for the Continuum platform.
// Requirements: 8.1, 8.2

import { Queue } from "bullmq";
import { createClient } from "redis";

const REDIS_URL = process.env.REDIS_URL ?? "redis://localhost:6379";

// Parse host/port from REDIS_URL for BullMQ's IORedis connection options.
const url = new URL(REDIS_URL);
const connection = {
  host: url.hostname,
  port: parseInt(url.port || "6379", 10),
  ...(url.password ? { password: url.password } : {}),
};

// Exponential backoff delays: 1s, 2s, 4s, 8s, 16s (max 5 attempts).
const defaultJobOptions = {
  attempts: 5,
  backoff: {
    type: "exponential",
    delay: 1000, // initial delay ms; BullMQ doubles on each retry: 1000, 2000, 4000, 8000, 16000
  },
};

const QUEUE_NAMES = [
  "premium_recalculation",
  "payout_disbursement",
  "notification_dispatch",
  "fraud_review_escalation",
];

/**
 * Creates and returns a BullMQ Queue instance for the given name.
 * @param {string} name
 * @returns {Queue}
 */
function createQueue(name) {
  return new Queue(name, {
    connection,
    defaultJobOptions,
  });
}

export const premiumRecalculationQueue = createQueue("premium_recalculation");
export const payoutDisbursementQueue = createQueue("payout_disbursement");
export const notificationDispatchQueue = createQueue("notification_dispatch");
export const fraudReviewEscalationQueue = createQueue("fraud_review_escalation");

/** All queue instances indexed by name for convenience. */
export const queues = {
  premium_recalculation: premiumRecalculationQueue,
  payout_disbursement: payoutDisbursementQueue,
  notification_dispatch: notificationDispatchQueue,
  fraud_review_escalation: fraudReviewEscalationQueue,
};

/**
 * Logs all queue names to stdout. Called on service startup.
 */
export async function main() {
  console.log(`Connecting to Redis at ${REDIS_URL}`);
  console.log("BullMQ queues initialized:");
  for (const name of QUEUE_NAMES) {
    console.log(`  • ${name}`);
  }
}

// Run when executed directly (node infra/redis/bullmq_queues.js)
if (process.argv[1] === new URL(import.meta.url).pathname) {
  main().catch((err) => {
    console.error("Failed to initialize BullMQ queues:", err);
    process.exit(1);
  });
}
