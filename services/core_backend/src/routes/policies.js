// Feature: continuum-ml-pipelines
// Policy management endpoints with business rule enforcement
// Requirements: 6.1, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10

'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');
const kafka = require('../services/kafka');
const { incrementPremiumsCollected } = require('../services/metrics');

const router = express.Router();

// Business rule constants
const ACTIVATION_DELAY_MS = 72 * 60 * 60 * 1000;       // 72 hours
const TIER_UPGRADE_DELAY_MS = 5 * 24 * 60 * 60 * 1000; // 5 days
const BILLING_CYCLE_MS = 7 * 24 * 60 * 60 * 1000;      // 7 days

const VALID_TIERS = ['silver', 'gold', 'platinum'];

/**
 * POST /policies
 * Create a new policy with 72-hour activation delay.
 * Publishes worker_onboarding and policy_created events to Kafka.
 * Requirements: 6.1, 6.5, 6.7, 6.8
 */
router.post('/', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { worker_id, tier, zone_id, coverage_cap, weekly_premium, aadhaar_hash, device_fingerprint } = req.body;

    const device_attestation_token = req.body.device_attestation_token;

    if (!worker_id || !tier || !zone_id || coverage_cap == null || weekly_premium == null || !aadhaar_hash || !device_fingerprint) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    if (!VALID_TIERS.includes(tier)) {
      return res.status(400).json({ error: 'invalid_tier' });
    }

    // Worker in JWT must match the worker_id in the body
    if (req.user.worker_id !== worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    // Play Integrity attestation check (calls the Rust claims_scoring /attest endpoint)
    if (device_attestation_token) {
      try {
        const CLAIMS_SCORING_URL = process.env.CLAIMS_SCORING_URL || 'http://claims_scoring:8080';
        const fetch = require('node-fetch');
        const attestResp = await fetch(`${CLAIMS_SCORING_URL}/attest`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: device_attestation_token }),
          timeout: 10000,
        });
        if (attestResp.ok) {
          const attestResult = await attestResp.json();
          if (!attestResult.valid) {
            return res.status(403).json({ error: 'device_attestation_failed', reason: attestResult.reason });
          }
        }
      } catch (attestErr) {
        console.warn('Play Integrity check unavailable, proceeding:', attestErr.message);
      }
    }

    // Adverse selection control: reject enrollment if zone is forecast-locked (G3)
    const lockResult = await db.query(
      `SELECT zone_id, event_type, expires_at FROM zone_enrollment_locks
       WHERE zone_id = $1 AND expires_at > NOW()
       LIMIT 1`,
      [zone_id]
    );
    if (lockResult.rows.length > 0) {
      const lock = lockResult.rows[0];
      return res.status(409).json({
        error: 'enrollment_locked',
        zone_id: lock.zone_id,
        reason: `Zone is under forecast-driven enrollment freeze until ${lock.expires_at}`,
        expires_at: lock.expires_at instanceof Date ? lock.expires_at.toISOString() : lock.expires_at,
      });
    }

    const now = new Date();
    const effectiveDate = now;
    const claimEligibleFrom = new Date(now.getTime() + ACTIVATION_DELAY_MS);
    const billingCycleStart = now;
    const billingCycleEnd = new Date(now.getTime() + BILLING_CYCLE_MS);
    const policyId = uuidv4();

    const client = await db.connect();
    try {
      await client.query('BEGIN');

      // 1. Enforce Identity + Device uniqueness directly via DB update/upsert (Requirements G5)
      // Attempt to update the worker with the provided hashes.
      // If the hash already belongs to another worker, this will throw a UNIQUE violation.
      try {
         await client.query(
          `UPDATE workers 
           SET aadhaar_hash = $1, device_fingerprint = $2
           WHERE worker_id = $3`,
          [aadhaar_hash, device_fingerprint, worker_id]
         );
      } catch (dbErr) {
        if (dbErr.code === '23505') { // unique violation
           await client.query('ROLLBACK');
           return res.status(409).json({ error: 'identity_or_device_already_registered' });
        }
        throw dbErr;
      }

      // 2. Persist policy (Requirements 6.7) - Include zone_id
      await client.query(
        `INSERT INTO policies
           (policy_id, worker_id, tier, zone_id, coverage_cap, weekly_premium,
            effective_date, claim_eligible_from, status,
            billing_cycle_start, billing_cycle_end, cancelled_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9, $10, NULL)`,
        [
          policyId, worker_id, tier, zone_id,
          coverage_cap, weekly_premium,
          effectiveDate, claimEligibleFrom,
          billingCycleStart, billingCycleEnd,
        ]
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    const policy = {
      policy_id: policyId,
      worker_id,
      tier,
      coverage_cap,
      weekly_premium,
      effective_date: effectiveDate.toISOString(),
      claim_eligible_from: claimEligibleFrom.toISOString(),
      status: 'pending',
      billing_cycle_start: billingCycleStart.toISOString(),
      billing_cycle_end: billingCycleEnd.toISOString(),
      cancelled_at: null,
    };

    // Publish worker_onboarding event (Requirements 6.8)
    try {
      await kafka.publishEvent('worker_onboarding', {
        worker_id,
        zone_id,
        platform: req.user.platform || null,
        tier,
        registered_at: now.toISOString(),
      });
    } catch (kafkaErr) {
      // Non-fatal: log but don't fail the request
      console.error('Kafka publish error (worker_onboarding):', kafkaErr.message);
    }

    // Publish policy lifecycle event (Requirements 6.8)
    try {
      await kafka.publishEvent('policy_lifecycle', {
        event: 'policy_created',
        policy_id: policyId,
        worker_id,
        tier,
        effective_date: effectiveDate.toISOString(),
        claim_eligible_from: claimEligibleFrom.toISOString(),
        created_at: now.toISOString(),
      });
    } catch (kafkaErr) {
      console.error('Kafka publish error (policy_lifecycle):', kafkaErr.message);
    }

    // Track weekly premium collected (Requirements 16.4)
    incrementPremiumsCollected(parseFloat(weekly_premium));

    return res.status(201).json(policy);
  } catch (err) {
    next(err);
  }
});

router.get('/content', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT section_id, number, title, icon_key, body
       FROM policy_content
       ORDER BY number ASC`
    );

    return res.status(200).json({
      hero: {
        badge: 'COMPREHENSIVE',
        title: 'Gig Worker Protection Plan',
        subtitle: 'Complete coverage for disruptions, outages, and accidents on platform.'
      },
      sections: result.rows
    });
  } catch (err) {
    next(err);
  }
});

router.post('/content', authenticate, requireRole('admin', 'insurer'), async (req, res, next) => {
  try {
    const { number, title, icon_key, body } = req.body;
    if (!number || !title || !icon_key || !body) return res.status(400).json({ error: 'missing_fields' });

    const row = await db.query(
      `INSERT INTO policy_content (section_id, number, title, icon_key, body)
       VALUES (gen_random_uuid(), $1, $2, $3, $4)
       RETURNING section_id, number, title, icon_key, body`,
      [number, title, icon_key, body]
    );

    return res.status(201).json(row.rows[0]);
  } catch (err) {
    next(err);
  }
});

router.put('/content/:sectionId', authenticate, requireRole('admin', 'insurer'), async (req, res, next) => {
  try {
    const { sectionId } = req.params;
    const { number, title, icon_key, body } = req.body;

    await db.query(
      `UPDATE policy_content
       SET number = COALESCE($1, number),
           title = COALESCE($2, title),
           icon_key = COALESCE($3, icon_key),
           body = COALESCE($4, body)
       WHERE section_id = $5`,
      [number, title, icon_key, body, sectionId]
    );

    return res.status(200).json({ updated: true, section_id: sectionId });
  } catch (err) {
    next(err);
  }
});

router.delete('/content/:sectionId', authenticate, requireRole('admin', 'insurer'), async (req, res, next) => {
  try {
    const { sectionId } = req.params;
    await db.query(`DELETE FROM policy_content WHERE section_id = $1`, [sectionId]);
    return res.status(200).json({ deleted: true, section_id: sectionId });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /policies/content
 * Static CMS-style policy content for the Flutter app (V67).
 * Must be registered before GET /:id to avoid Express capturing 'content' as an :id param.
 */
router.get('/content', authenticate, requireRole('worker', 'admin', 'insurer'), (req, res) => {
  return res.status(200).json({
    hero: {
      badge: 'COMPREHENSIVE',
      title: 'Gig Worker Protection Plan',
      subtitle: 'Parametric income protection triggered automatically when a covered disruption is detected — no claims paperwork needed.',
    },
    sections: [
      {
        title: 'Coverage',
        icon_key: 'coverage',
        body: 'Covers income loss due to accidents, vehicle breakdown, medical emergencies, weather disruptions, and platform outages while on active duty.',
      },
      {
        title: 'Eligibility',
        icon_key: 'eligibility',
        body: 'Active gig delivery workers with a verified policy. Coverage begins 72 hours after policy creation and resets 5 days after a tier upgrade.',
      },
      {
        title: 'Claim Process',
        icon_key: 'claim_process',
        body: 'Submit a claim with incident details. Our oracle engine validates the disruption event automatically — no documents required for parametric triggers.',
      },
      {
        title: 'Payouts',
        icon_key: 'payouts',
        body: 'Approved payouts are credited to your registered UPI wallet within 5 minutes of oracle authorization. A 7-day non-duplication window applies per billing cycle.',
      },
      {
        title: 'Exclusions',
        icon_key: 'exclusions',
        body: 'Pre-existing conditions, incidents outside active duty hours, and events flagged for fraud are excluded. Device attestation failure blocks the claim pipeline.',
      },
      {
        title: 'Renewal',
        icon_key: 'renewal',
        body: 'Weekly auto-renewal via eNACH mandate. Coverage lapses if the mandate payment fails. Re-enrollment is subject to zone availability and adverse-selection locks.',
      },
    ],
  });
});

/**
 * GET /policies/:id
 * Retrieve a policy by ID. Worker can only access their own policy.
 * Requirements: 6.1
 */
router.get('/:id', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT policy_id, worker_id, tier, coverage_cap, weekly_premium,
              effective_date, claim_eligible_from, status,
              billing_cycle_start, billing_cycle_end, cancelled_at
       FROM policies
       WHERE policy_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found' });
    }

    const policy = result.rows[0];

    // Workers can only access their own policy (Requirements 6.1)
    if (req.user.role === 'worker' && policy.worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    return res.status(200).json({
      policy_id: policy.policy_id,
      worker_id: policy.worker_id,
      tier: policy.tier,
      coverage_cap: parseFloat(policy.coverage_cap),
      weekly_premium: parseFloat(policy.weekly_premium),
      effective_date: policy.effective_date instanceof Date
        ? policy.effective_date.toISOString()
        : policy.effective_date,
      claim_eligible_from: policy.claim_eligible_from instanceof Date
        ? policy.claim_eligible_from.toISOString()
        : policy.claim_eligible_from,
      status: policy.status,
      billing_cycle_start: policy.billing_cycle_start instanceof Date
        ? policy.billing_cycle_start.toISOString()
        : policy.billing_cycle_start,
      billing_cycle_end: policy.billing_cycle_end instanceof Date
        ? policy.billing_cycle_end.toISOString()
        : policy.billing_cycle_end,
      cancelled_at: policy.cancelled_at
        ? (policy.cancelled_at instanceof Date
          ? policy.cancelled_at.toISOString()
          : policy.cancelled_at)
        : null,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /policies/:id
 * Cancel a policy — deferred to end of current billing cycle.
 * Sets cancelled_at = now but policy stays active until billing_cycle_end.
 * Requirements: 6.1, 6.10
 */
router.delete('/:id', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT policy_id, worker_id, status, billing_cycle_end, cancelled_at
       FROM policies
       WHERE policy_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found' });
    }

    const policy = result.rows[0];

    // Workers can only cancel their own policy
    if (policy.worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    if (policy.status === 'cancelled' || policy.cancelled_at) {
      return res.status(409).json({ error: 'already_cancelled' });
    }

    const now = new Date();

    // Set cancelled_at but keep status active until billing_cycle_end (Requirements 6.10)
    await db.query(
      `UPDATE policies SET cancelled_at = $1 WHERE policy_id = $2`,
      [now, id]
    );

    const billingCycleEnd = policy.billing_cycle_end instanceof Date
      ? policy.billing_cycle_end.toISOString()
      : policy.billing_cycle_end;

    // Publish policy cancellation event (Requirements 6.8)
    try {
      await kafka.publishEvent('policy_lifecycle', {
        event: 'policy_cancelled',
        policy_id: id,
        worker_id: policy.worker_id,
        cancelled_at: now.toISOString(),
        effective_cancellation: billingCycleEnd,
      });
    } catch (kafkaErr) {
      console.error('Kafka publish error (policy_lifecycle cancel):', kafkaErr.message);
    }

    return res.status(200).json({
      cancelled_at: now.toISOString(),
      effective_cancellation: billingCycleEnd,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /policies/:id/tier
 * Upgrade policy tier with 5-day waiting period on claim eligibility.
 * Requirements: 6.6
 */
router.put('/:id/tier', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { tier } = req.body;

    if (!tier || !VALID_TIERS.includes(tier)) {
      return res.status(400).json({ error: 'invalid_tier' });
    }

    const result = await db.query(
      `SELECT policy_id, worker_id, tier, status FROM policies WHERE policy_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found' });
    }

    const policy = result.rows[0];

    if (policy.worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    const now = new Date();
    // 5-day waiting period before upgraded tier applies to claim eligibility (Requirements 6.6)
    const newClaimEligibleFrom = new Date(now.getTime() + TIER_UPGRADE_DELAY_MS);

    await db.query(
      `UPDATE policies SET tier = $1, claim_eligible_from = $2 WHERE policy_id = $3`,
      [tier, newClaimEligibleFrom, id]
    );

    return res.status(200).json({
      policy_id: id,
      new_tier: tier,
      claim_eligible_from: newClaimEligibleFrom.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /policies/payout-check
 * Enforce 1 successful payout per worker per 7-day cycle.
 * Returns HTTP 409 with {"error": "payout_cycle_cap_exceeded"} on duplicate.
 * Requirements: 6.9
 *
 * Note: This endpoint is used internally by the payout flow to check the cap.
 * The actual enforcement is done here as a dedicated check endpoint.
 */
router.post('/payout-check', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { worker_id, policy_id } = req.body;

    if (!worker_id || !policy_id) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    // Workers can only check their own payout cap
    if (req.user.role === 'worker' && req.user.worker_id !== worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    // Check if worker already has a successful payout in the current 7-day cycle
    const sevenDaysAgo = new Date(Date.now() - BILLING_CYCLE_MS);

    const result = await db.query(
      `SELECT COUNT(*) as count
       FROM payouts
       WHERE worker_id = $1
         AND policy_id = $2
         AND status = 'disbursed'
         AND created_at >= $3`,
      [worker_id, policy_id, sevenDaysAgo]
    );

    const count = parseInt(result.rows[0].count, 10);

    if (count >= 1) {
      return res.status(409).json({ error: 'payout_cycle_cap_exceeded' });
    }

    return res.status(200).json({ eligible: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
