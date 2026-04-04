// Feature: continuum-ml-pipelines
// Auth endpoints — Requirements 6.1, 6.2, 6.5

const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { signToken } = require('../utils/jwt');
const db = require('../db');

const router = express.Router();

const BCRYPT_ROUNDS = 10;
const POLICY_ELIGIBLE_DELAY_MS = 72 * 60 * 60 * 1000; // 72 hours in ms

/**
 * POST /auth/register
 * Accept {worker_id, platform, upi_id, tier}, hash password with bcrypt,
 * insert worker into DB, issue JWT (role: "worker", 24h expiry).
 * Returns {token, expires_at, policy_eligible_from}
 */
router.post('/register', async (req, res, next) => {
  try {
    const { worker_id, platform, upi_id, tier, password } = req.body;

    if (!worker_id || !platform || !upi_id || !tier) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    // Hash password (use worker_id as password if none provided, for initial registration)
    const rawPassword = password || worker_id;
    const passwordHash = await bcrypt.hash(rawPassword, BCRYPT_ROUNDS);

    // Insert worker into DB
    await db.query(
      `INSERT INTO workers (worker_id, platform, tier, upi_id, password_hash, registered_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (worker_id) DO NOTHING`,
      [worker_id, platform, tier, upi_id, passwordHash]
    );

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const policyEligibleFrom = new Date(now.getTime() + POLICY_ELIGIBLE_DELAY_MS);

    const token = signToken({
      worker_id,
      role: 'worker',
      platform,
      tier,
    });

    return res.status(201).json({
      token,
      expires_at: expiresAt.toISOString(),
      policy_eligible_from: policyEligibleFrom.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/login
 * Accept {worker_id, password}, verify bcrypt hash, issue JWT.
 * Returns {token, expires_at}
 * Returns HTTP 401 {"error": "invalid_credentials"} on bad login
 */
router.post('/login', async (req, res, next) => {
  try {
    const { worker_id, password } = req.body;

    if (!worker_id || !password) {
      return res.status(401).json({ error: 'invalid_credentials' });
    }

    const result = await db.query(
      'SELECT worker_id, platform, tier, password_hash FROM workers WHERE worker_id = $1',
      [worker_id]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'invalid_credentials' });
    }

    const worker = result.rows[0];
    const passwordMatch = await bcrypt.compare(password, worker.password_hash);

    if (!passwordMatch) {
      return res.status(401).json({ error: 'invalid_credentials' });
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const token = signToken({
      worker_id: worker.worker_id,
      role: 'worker',
      platform: worker.platform,
      tier: worker.tier,
    });

    return res.status(200).json({
      token,
      expires_at: expiresAt.toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
