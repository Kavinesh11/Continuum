// UPI eNACH mandate service — recurring premium collection via PayU
// Requirements: G2 — frictionless premium collection

'use strict';

const db = require('../db');
const { v4: uuidv4 } = require('uuid');
const { createMandateGateway } = require('../adapters/mandateGateway');

/**
 * Create a new UPI eNACH mandate for a worker's policy.
 *
 * @param {string} workerId
 * @param {string} policyId
 * @param {string} upiId
 * @param {number} maxAmount  — maximum debit per cycle (INR)
 * @returns {Promise<object>} mandate record
 */
async function createMandate(workerId, policyId, upiId, maxAmount) {
  const mandateId = uuidv4();
  const gateway = createMandateGateway();

  const providerResult = await gateway.createMandate(mandateId, upiId, maxAmount, 'weekly');

  await db.query(
    `INSERT INTO mandates
       (mandate_id, worker_id, policy_id, upi_id, max_amount, provider_ref, status, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, 'created', NOW(), NOW())`,
    [mandateId, workerId, policyId, upiId, maxAmount, providerResult.provider_ref || null]
  );

  return {
    mandate_id: mandateId,
    worker_id: workerId,
    policy_id: policyId,
    status: 'created',
    provider_ref: providerResult.provider_ref || null,
  };
}

/**
 * Process a mandate webhook callback from PayU.
 * Transitions: created→approved, approved→active, *→revoked, *→failed
 *
 * @param {object} event
 * @param {string} event.mandate_id
 * @param {string} event.status — 'APPROVED' | 'REVOKED' | 'FAILED'
 * @param {string} [event.provider_ref]
 */
async function handleMandateWebhook(event) {
  const { mandate_id, status: providerStatus, provider_ref } = event;

  const statusMap = {
    'APPROVED': 'approved',
    'ACTIVE': 'active',
    'REVOKED': 'revoked',
    'FAILED': 'failed',
    'PAUSED': 'paused',
  };

  const newStatus = statusMap[providerStatus];
  if (!newStatus) {
    throw new Error(`Unknown mandate webhook status: ${providerStatus}`);
  }

  const timestampCol = newStatus === 'approved' ? ', approved_at = NOW()'
    : newStatus === 'revoked' ? ', revoked_at = NOW()'
    : '';

  await db.query(
    `UPDATE mandates
     SET status = $1, provider_ref = COALESCE($2, provider_ref), updated_at = NOW() ${timestampCol}
     WHERE mandate_id = $3`,
    [newStatus, provider_ref || null, mandate_id]
  );

  return { mandate_id, status: newStatus };
}

/**
 * Execute a debit against an active mandate.
 *
 * @param {string} mandateId
 * @param {number} amount
 * @returns {Promise<object>} debit result
 */
async function executeDebit(mandateId, amount) {
  const mandateRow = await db.query(
    'SELECT mandate_id, worker_id, policy_id, provider_ref, status FROM mandates WHERE mandate_id = $1',
    [mandateId]
  );
  if (mandateRow.rows.length === 0) throw new Error(`Mandate ${mandateId} not found`);
  const mandate = mandateRow.rows[0];

  if (mandate.status !== 'active' && mandate.status !== 'approved') {
    throw new Error(`Mandate ${mandateId} is not active (status: ${mandate.status})`);
  }

  const debitId = uuidv4();

  try {
    const gateway = createMandateGateway();
    const result = await gateway.executeDebit(mandateId, mandate.provider_ref, amount, debitId);

    await db.query(
      `INSERT INTO mandate_debits
         (debit_id, mandate_id, policy_id, worker_id, amount, provider_txn, status, attempted_at, settled_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'success', NOW(), NOW())`,
      [debitId, mandateId, mandate.policy_id, mandate.worker_id, amount, result.txn_ref || null]
    );

    await db.query(
      `UPDATE mandates SET last_debit_at = NOW(), last_debit_status = 'success', updated_at = NOW()
       WHERE mandate_id = $1`,
      [mandateId]
    );

    return { debit_id: debitId, status: 'success', txn_ref: result.txn_ref };
  } catch (err) {
    await db.query(
      `INSERT INTO mandate_debits
         (debit_id, mandate_id, policy_id, worker_id, amount, status, failure_reason, attempted_at)
       VALUES ($1, $2, $3, $4, $5, 'failed', $6, NOW())`,
      [debitId, mandateId, mandate.policy_id, mandate.worker_id, amount, err.message]
    );

    await db.query(
      `UPDATE mandates SET last_debit_at = NOW(), last_debit_status = 'failed', updated_at = NOW()
       WHERE mandate_id = $1`,
      [mandateId]
    );

    throw err;
  }
}

/**
 * Get the active mandate for a given policy.
 */
async function getMandateByPolicy(policyId) {
  const result = await db.query(
    `SELECT * FROM mandates WHERE policy_id = $1 AND status IN ('active','approved') LIMIT 1`,
    [policyId]
  );
  return result.rows[0] || null;
}

module.exports = {
  createMandate,
  handleMandateWebhook,
  executeDebit,
  getMandateByPolicy,
};
