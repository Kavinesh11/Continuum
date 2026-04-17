'use strict';

const db = require('../../db');

/**
 * Handle a `fraud_alert` Kafka event.
 * Logs the alert and escalates based on alert_type.
 */
async function handleFraudAlert(event) {
  const { alert_type, triggered_at, worker_id, claim_id, job_id } = event;

  await db.query(
    `INSERT INTO agent_audit_log (claim_id, agent_name, action, payload)
     VALUES ($1, 'fraud_alert_consumer', $2, $3)`,
    [
      claim_id || null,
      `fraud_alert:${alert_type}`,
      JSON.stringify(event),
    ]
  );

  console.log(
    `[fraud-alert] Alert type=${alert_type} worker=${worker_id || 'zone-level'} at ${triggered_at}`
  );

  return { alert_type, logged: true };
}

module.exports = { handleFraudAlert };
