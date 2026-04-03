// Feature: continuum-ml-pipelines
// fraud_review_escalation queue processor
// Requirements: 8.1, 12.1, 12.2

'use strict';

const db = require('../../db');
const kafka = require('../../services/kafka');

/**
 * Crew AI Orchestrator client stub.
 * Forwards the claim to the Crew AI multi-agent pipeline for secondary analysis.
 * In production this calls the Crew AI service endpoint.
 *
 * Requirements: 12.1, 12.2
 *
 * @param {string} claimId
 * @param {object} claimData
 * @returns {Promise<{ success: boolean, agent_task_id?: string, error?: string }>}
 */
async function callCrewAIOrchestrator(claimId, claimData) {
  const crewAiUrl = process.env.CREW_AI_URL || 'http://localhost:8010';

  try {
    const fetch = require('node-fetch');
    const response = await fetch(`${crewAiUrl}/fraud-queue/assign`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        claim_id: claimId,
        claim_data: claimData,
        agent: 'fraud_signal_aggregation',
        priority: 'high',
      }),
      timeout: 15000,
    });

    if (response.ok) {
      const result = await response.json();
      return { success: true, agent_task_id: result.task_id || result.agent_task_id };
    }

    const errBody = await response.text();
    return { success: false, error: `Crew AI returned ${response.status}: ${errBody}` };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Process a fraud_review_escalation job.
 *
 * Job data shape:
 *   { claim_id, worker_id, fraud_score, zone_id, event_type, submitted_at, ... }
 *
 * Forwards the claim to the Crew AI Orchestrator's fraud_signal_aggregation agent
 * within 60 seconds of the claim entering FRAUD_QUEUE (Requirements 12.2).
 *
 * Requirements: 8.1, 12.1, 12.2
 *
 * @param {import('bullmq').Job} job
 */
async function processFraudReviewEscalation(job) {
  const { claim_id, worker_id, fraud_score, zone_id, event_type } = job.data;

  if (!claim_id || !worker_id) {
    throw new Error(`fraud_review_escalation: missing required fields in job ${job.id}`);
  }

  console.log(`[fraud_review_escalation] Processing job ${job.id} for claim ${claim_id}`);

  // Fetch full claim details from DB
  const claimResult = await db.query(
    `SELECT claim_id, worker_id, policy_id, event_type, event_timestamp,
            gps_lat, gps_lon, zone_id, status, fraud_score, submitted_at
     FROM claims
     WHERE claim_id = $1`,
    [claim_id]
  );

  if (claimResult.rows.length === 0) {
    throw new Error(`fraud_review_escalation: claim ${claim_id} not found`);
  }

  const claim = claimResult.rows[0];

  // Verify claim is still in FRAUD_QUEUE status
  if (claim.status !== 'fraud_queue') {
    console.warn(`[fraud_review_escalation] Claim ${claim_id} is no longer in fraud_queue (status=${claim.status}) — skipping`);
    return { skipped: true, reason: 'claim_not_in_fraud_queue', claim_id };
  }

  // Forward to Crew AI Orchestrator (Requirements 12.1, 12.2)
  const crewResult = await callCrewAIOrchestrator(claim_id, {
    worker_id: claim.worker_id,
    policy_id: claim.policy_id,
    event_type: claim.event_type,
    event_timestamp: claim.event_timestamp,
    gps_coordinates: [claim.gps_lat, claim.gps_lon],
    zone_id: claim.zone_id,
    fraud_score: parseFloat(claim.fraud_score || fraud_score || 0),
    submitted_at: claim.submitted_at,
  });

  if (!crewResult.success) {
    throw new Error(`fraud_review_escalation: Crew AI call failed for claim ${claim_id}: ${crewResult.error}`);
  }

  // Log escalation to agent_audit_log
  try {
    await db.query(
      `INSERT INTO agent_audit_log (claim_id, agent_name, action, payload)
       VALUES ($1, 'fraud_signal_aggregation', 'escalated_to_crew_ai', $2)`,
      [claim_id, JSON.stringify({ agent_task_id: crewResult.agent_task_id, job_id: job.id })]
    );
  } catch (dbErr) {
    console.error(`[fraud_review_escalation] Failed to log to agent_audit_log:`, dbErr.message);
  }

  // Publish fraud_alert event to Kafka for tracking
  try {
    await kafka.publishEvent('fraud_alert', {
      alert_type: 'fraud_queue_escalation',
      claim_id,
      worker_id,
      zone_id: zone_id || claim.zone_id,
      fraud_score: parseFloat(claim.fraud_score || fraud_score || 0),
      agent_task_id: crewResult.agent_task_id,
      triggered_at: new Date().toISOString(),
    });
  } catch (kafkaErr) {
    console.error(`[fraud_review_escalation] Kafka publish failed:`, kafkaErr.message);
  }

  console.log(`[fraud_review_escalation] Completed job ${job.id}: claim ${claim_id} assigned to Crew AI, task=${crewResult.agent_task_id}`);
  return {
    claim_id,
    agent_task_id: crewResult.agent_task_id,
    status: 'escalated',
  };
}

module.exports = { processFraudReviewEscalation, callCrewAIOrchestrator };
