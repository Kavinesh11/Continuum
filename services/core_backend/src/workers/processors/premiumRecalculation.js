// Feature: continuum-ml-pipelines
// premium_recalculation queue processor
// Requirements: 2.1, 2.2, 8.1, 8.5

'use strict';

const db = require('../../db');
const kafka = require('../../services/kafka');

/**
 * Process a premium_recalculation job.
 *
 * Job data shape:
 *   { worker_id, policy_id, zone_id, tier }
 *
 * Calls the Risk Profiler service to re-run feature assembly and scoring,
 * then updates the policy's weekly_premium and publishes a premium_updated
 * Kafka event.
 *
 * Requirements: 2.1, 2.2
 *
 * @param {import('bullmq').Job} job
 */
async function processPremiumRecalculation(job) {
  const { worker_id, policy_id, zone_id, tier } = job.data;

  if (!worker_id || !policy_id) {
    throw new Error(`premium_recalculation: missing required fields in job ${job.id}`);
  }

  console.log(`[premium_recalculation] Processing job ${job.id} for worker ${worker_id}`);

  // Fetch current policy details
  const policyResult = await db.query(
    `SELECT policy_id, worker_id, tier, weekly_premium, status
     FROM policies
     WHERE policy_id = $1 AND status = 'active'`,
    [policy_id]
  );

  if (policyResult.rows.length === 0) {
    console.warn(`[premium_recalculation] Policy ${policy_id} not found or not active — skipping`);
    return { skipped: true, reason: 'policy_not_active' };
  }

  const policy = policyResult.rows[0];
  const oldPremium = parseFloat(policy.weekly_premium);

  // Call Risk Profiler service to re-run scoring (Requirements 2.2)
  const riskProfilerUrl = process.env.RISK_PROFILER_URL || 'http://localhost:8001';
  let newPremium = oldPremium;
  let riskScore = null;

  try {
    const fetch = require('node-fetch');
    const response = await fetch(`${riskProfilerUrl}/recalculate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ worker_id, policy_id, zone_id: zone_id || null, tier: tier || policy.tier }),
      timeout: 10000,
    });

    if (response.ok) {
      const result = await response.json();
      newPremium = result.final_premium || oldPremium;
      riskScore = result.risk_score || null;
    } else {
      console.warn(`[premium_recalculation] Risk Profiler returned ${response.status} for worker ${worker_id}`);
    }
  } catch (err) {
    // Non-fatal: log and continue with old premium
    console.error(`[premium_recalculation] Risk Profiler call failed for worker ${worker_id}:`, err.message);
  }

  // Update policy weekly_premium if changed
  if (newPremium !== oldPremium) {
    await db.query(
      `UPDATE policies SET weekly_premium = $1 WHERE policy_id = $2`,
      [newPremium, policy_id]
    );

    // Record premium version for audit trail (Requirements 2.6)
    if (riskScore !== null) {
      try {
        await db.query(
          `INSERT INTO premium_versions
             (policy_id, effective_date, zone_id, tier, risk_score, computed_premium)
           VALUES ($1, NOW(), $2, $3, $4, $5)`,
          [policy_id, zone_id || null, policy.tier, riskScore, newPremium]
        );
      } catch (dbErr) {
        console.error(`[premium_recalculation] Failed to insert premium_version:`, dbErr.message);
      }
    }

    // Publish premium_updated Kafka event (Requirements 2.6)
    try {
      await kafka.publishEvent('premium_updated', {
        worker_id,
        policy_id,
        old_premium: oldPremium,
        new_premium: newPremium,
        effective_date: new Date().toISOString(),
      });
    } catch (kafkaErr) {
      console.error(`[premium_recalculation] Kafka publish failed:`, kafkaErr.message);
    }
  }

  console.log(`[premium_recalculation] Completed job ${job.id}: premium ${oldPremium} → ${newPremium}`);
  return { worker_id, policy_id, old_premium: oldPremium, new_premium: newPremium };
}

module.exports = { processPremiumRecalculation };
