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
  incrementPremiumsCollected,
  incrementPayoutsDisbursed,
  createMetricsHandler,
};
