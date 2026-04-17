// Feature: continuum-ml-pipelines
// Prometheus metrics setup for Core Backend
// Requirements: 16.1, 16.4

'use strict';

const client = require('prom-client');

// Use a dedicated registry to avoid conflicts in tests
const registry = new client.Registry();

// ─── Metrics ──────────────────────────────────────────────────────────────────

/**
 * Gauge: number of currently active policies (status='active')
 * Refreshed on each /metrics scrape via a DB query.
 */
const activePoliciesCount = new client.Gauge({
  name: 'active_policies_count',
  help: 'Number of currently active policies',
  registers: [registry],
});

/**
 * Counter: total weekly premium amount collected (INR)
 * Incremented via incrementPremiumsCollected(amount).
 */
const weeklyPremiumsCollected = new client.Counter({
  name: 'weekly_premiums_collected',
  help: 'Total weekly premium amount collected in INR',
  registers: [registry],
});

/**
 * Counter: total number of payouts with status='disbursed'
 * Incremented via incrementPayoutsDisbursed().
 */
const payoutsDisbursedTotal = new client.Counter({
  name: 'payouts_disbursed_total',
  help: 'Total number of payouts with status disbursed',
  registers: [registry],
});

/**
 * Histogram: end-to-end payout latency from trigger firing to UPI credit.
 * Buckets span from 30s to 3h (10800s) to capture SLA breaches.
 * Requirements: G4 — IRDAI-publishable 2-hour SLA
 */
const payoutLatencySeconds = new client.Histogram({
  name: 'payout_latency_seconds',
  help: 'End-to-end latency from oracle trigger to UPI disbursement (seconds)',
  buckets: [30, 60, 120, 300, 600, 1200, 1800, 3600, 5400, 7200, 10800],
  registers: [registry],
});

/**
 * Counter: payout SLA breaches (latency > 2 hours = 7200 seconds).
 */
const payoutSlaBreachTotal = new client.Counter({
  name: 'payout_sla_breach_total',
  help: 'Number of payouts that breached the 2-hour SLA',
  registers: [registry],
});

/**
 * Histogram: end-to-end trigger-to-payout latency (matching SLO definition).
 */
const triggerToPayoutSeconds = new client.Histogram({
  name: 'continuum_trigger_to_payout_seconds',
  help: 'End-to-end latency from oracle trigger_fired_at to payout disbursement',
  buckets: [30, 60, 120, 300, 600, 1200, 1800, 3600, 5400, 7200, 10800],
  registers: [registry],
});

const dlqDepth = new client.Gauge({
  name: 'continuum_dlq_depth',
  help: 'Number of messages in dead-letter queues',
  labelNames: ['queue'],
  registers: [registry],
});

const reserveFloorBreachTotal = new client.Counter({
  name: 'continuum_reserve_floor_breach_total',
  help: 'Number of times payout was blocked due to reserve floor',
  registers: [registry],
});

const enrollmentLockActiveCount = new client.Gauge({
  name: 'continuum_enrollment_lock_active_count',
  help: 'Number of active zone enrollment locks',
  registers: [registry],
});

// ─── Helper functions ─────────────────────────────────────────────────────────

/**
 * Increment weekly_premiums_collected by the given amount (INR).
 * @param {number} amount
 */
function incrementPremiumsCollected(amount) {
  weeklyPremiumsCollected.inc(amount);
}

/**
 * Increment payouts_disbursed_total by 1.
 */
function incrementPayoutsDisbursed() {
  payoutsDisbursedTotal.inc(1);
}

const PAYOUT_SLA_SECONDS = 7200; // 2 hours

/**
 * Record payout latency and flag SLA breaches.
 * @param {number} latencySeconds — seconds from trigger to disbursement
 */
function recordPayoutLatency(latencySeconds) {
  payoutLatencySeconds.observe(latencySeconds);
  if (latencySeconds > PAYOUT_SLA_SECONDS) {
    payoutSlaBreachTotal.inc(1);
  }
}

/**
 * Build the Express route handler for GET /metrics.
 * Accepts a db pool so it can be injected in tests.
 * @param {object} db - pg Pool instance
 * @returns {Function} Express route handler
 */
function createMetricsHandler(db) {
  return async (req, res) => {
    try {
      // Refresh active_policies_count gauge from DB on each scrape
      const result = await db.query(
        "SELECT COUNT(*) AS count FROM policies WHERE status = 'active'"
      );
      const count = parseInt(result.rows[0].count, 10) || 0;
      activePoliciesCount.set(count);
    } catch (err) {
      // Log but don't fail the scrape — emit stale gauge value
      console.error('metrics: failed to refresh active_policies_count', err.message);
    }

    const output = await registry.metrics();
    res.set('Content-Type', registry.contentType);
    res.end(output);
  };
}

module.exports = {
  registry,
  activePoliciesCount,
  weeklyPremiumsCollected,
  payoutsDisbursedTotal,
  payoutLatencySeconds,
  payoutSlaBreachTotal,
  triggerToPayoutSeconds,
  dlqDepth,
  reserveFloorBreachTotal,
  enrollmentLockActiveCount,
  incrementPremiumsCollected,
  incrementPayoutsDisbursed,
  recordPayoutLatency,
  PAYOUT_SLA_SECONDS,
  createMetricsHandler,
};
