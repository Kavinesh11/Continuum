// Reserve management API — read-only balance, audit trail, runway check
// Requirements: 9.2, 9.3, R6, 15.1

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');
const { creditReserve, debitReserve } = require('../services/ledger');

const router = express.Router();

/**
 * GET /reserves/balance
 * Returns current reserve balance and runway estimate.
 * Admin/insurer access only.
 * Requirements: 15.1
 */
router.get('/balance', authenticate, requireRole('admin', 'insurer'), async (req, res, next) => {
  try {
    // Get balance from double-entry ledger
    const ledgerResult = await db.query(
      `SELECT account_id, balance FROM ledger_accounts
       WHERE account_id IN ('RESERVE_MAIN', 'PREMIUM_INCOME', 'PAYOUT_EXPENSE')
       ORDER BY account_id`
    );

    const accounts = {};
    for (const row of ledgerResult.rows) {
      accounts[row.account_id] = parseFloat(row.balance);
    }

    // Compute 90-day runway
    const payoutBaseline = await db.query(
      `SELECT COALESCE(SUM(amount), 0) / GREATEST(COUNT(DISTINCT DATE(created_at)), 1) AS daily_avg
       FROM payouts
       WHERE status = 'disbursed' AND created_at >= NOW() - INTERVAL '180 days'`
    );
    const dailyAvg = parseFloat(payoutBaseline.rows[0]?.daily_avg || 0);
    const reserveBalance = accounts.RESERVE_MAIN || 0;
    const runwayDays = dailyAvg > 0 ? Math.floor(reserveBalance / dailyAvg) : null;

    return res.status(200).json({
      reserve_balance: reserveBalance,
      premium_income_total: accounts.PREMIUM_INCOME || 0,
      payout_expense_total: accounts.PAYOUT_EXPENSE || 0,
      daily_payout_average: Math.round(dailyAvg * 100) / 100,
      runway_days: runwayDays,
      runway_sufficient: runwayDays === null || runwayDays >= 90,
      checked_at: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /reserves/ledger
 * Returns recent ledger entries (last 100).
 * Admin/insurer access only.
 */
router.get('/ledger', authenticate, requireRole('admin', 'insurer'), async (req, res, next) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || '100', 10), 500);
    const offset = parseInt(req.query.offset || '0', 10);

    const result = await db.query(
      `SELECT entry_id, debit_account, credit_account, amount,
              reference_type, reference_id, description, created_at
       FROM ledger_entries
       ORDER BY created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    const entries = result.rows.map(row => ({
      entry_id: row.entry_id,
      debit_account: row.debit_account,
      credit_account: row.credit_account,
      amount: parseFloat(row.amount),
      reference_type: row.reference_type,
      reference_id: row.reference_id,
      description: row.description,
      created_at: row.created_at instanceof Date
        ? row.created_at.toISOString()
        : row.created_at,
    }));

    return res.status(200).json({ entries, limit, offset });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /reserves/credit
 * Manually credit the reserve (e.g., capital injection, reinsurance payout).
 * Admin access only — all automated credits flow through ledger.js directly.
 * Requirements: 9.3
 */
router.post('/credit', authenticate, requireRole('admin'), async (req, res, next) => {
  try {
    const { amount, reference_id, description } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'amount must be positive' });
    }
    if (!reference_id) {
      return res.status(400).json({ error: 'reference_id is required' });
    }

    const newBalance = await creditReserve(amount, reference_id);

    console.log(
      `[reserves] Manual credit: ₹${amount}, ref=${reference_id}, new_balance=₹${newBalance}`
    );

    return res.status(200).json({
      status: 'credited',
      amount: parseFloat(amount),
      new_balance: newBalance,
      reference_id,
      description: description || null,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
