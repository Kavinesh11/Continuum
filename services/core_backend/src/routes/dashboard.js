'use strict';

const express = require('express');
const db = require('../db');

const router = express.Router();

const LOSS_GREEN_MAX = 0.7;
const LOSS_AMBER_MAX = 0.85;
const RUNWAY_GREEN_MIN = 120;
const RUNWAY_AMBER_MIN = 90;
const SLA_TARGET_SECONDS = 300;
const SLA_AMBER_SECONDS = 420;

function asNumber(value) {
  const num = typeof value === 'number' ? value : parseFloat(value);
  return Number.isFinite(num) ? num : 0;
}

function asOptionalNumber(value) {
  const num = typeof value === 'number' ? value : parseFloat(value);
  return Number.isFinite(num) ? num : null;
}

function lossStatus(value) {
  if (value == null) return 'amber';
  if (value < LOSS_GREEN_MAX) return 'green';
  if (value < LOSS_AMBER_MAX) return 'amber';
  return 'red';
}

function runwayStatus(days) {
  if (days == null) return 'amber';
  if (days >= RUNWAY_GREEN_MIN) return 'green';
  if (days >= RUNWAY_AMBER_MIN) return 'amber';
  return 'red';
}

function slaStatus(seconds) {
  if (seconds == null) return 'amber';
  if (seconds <= SLA_TARGET_SECONDS) return 'green';
  if (seconds <= SLA_AMBER_SECONDS) return 'amber';
  return 'red';
}

function formatInt(value) {
  return Number(value || 0).toLocaleString('en-IN');
}

function trimNumber(value) {
  return value.toFixed(1).replace(/\.0$/, '');
}

function formatInrShort(amount) {
  const value = Number(amount || 0);
  if (value >= 10000000) return `₹${trimNumber(value / 10000000)}Cr`;
  if (value >= 100000) return `₹${trimNumber(value / 100000)}L`;
  if (value >= 1000) return `₹${trimNumber(value / 1000)}k`;
  return `₹${Math.round(value)}`;
}

async function fetchLossRatioSeries(weeks) {
  const safeWeeks = Math.min(Math.max(parseInt(weeks || '13', 10) || 13, 4), 52);
  const result = await db.query(
    `WITH week_series AS (
       SELECT date_trunc('week', NOW()) - (s::int * INTERVAL '1 week') AS week_start
       FROM generate_series(0, $1 - 1) s
     ),
     premiums AS (
       SELECT date_trunc('week', attempted_at) AS week_start, SUM(amount) AS premium
       FROM mandate_debits
       WHERE status = 'success'
         AND attempted_at >= NOW() - ($1::int * INTERVAL '1 week')
       GROUP BY 1
     ),
     payouts AS (
       SELECT date_trunc('week', created_at) AS week_start, SUM(amount) AS payouts
       FROM payouts
       WHERE status = 'disbursed'
         AND created_at >= NOW() - ($1::int * INTERVAL '1 week')
       GROUP BY 1
     )
     SELECT w.week_start,
            COALESCE(premiums.premium, 0) AS premium,
            COALESCE(payouts.payouts, 0) AS payouts
     FROM week_series w
     LEFT JOIN premiums ON premiums.week_start = w.week_start
     LEFT JOIN payouts ON payouts.week_start = w.week_start
     ORDER BY w.week_start`,
    [safeWeeks]
  );

  const rows = result.rows.map((row) => {
    const premium = asNumber(row.premium);
    const payouts = asNumber(row.payouts);
    const ratio = premium > 0 ? payouts / premium : null;
    return { premium, payouts, ratio };
  });

  const totals = rows.reduce(
    (acc, row) => ({
      premium: acc.premium + row.premium,
      payouts: acc.payouts + row.payouts,
    }),
    { premium: 0, payouts: 0 }
  );

  const totalRatio = totals.premium > 0 ? totals.payouts / totals.premium : null;
  const latestRatio = rows.length > 0 ? rows[rows.length - 1].ratio : null;
  const previousRatio = rows.length > 1 ? rows[rows.length - 2].ratio : null;
  const delta = latestRatio != null && previousRatio != null ? latestRatio - previousRatio : null;
  const direction = delta == null ? 'flat' : delta > 0.002 ? 'up' : delta < -0.002 ? 'down' : 'flat';

  return {
    weeks: safeWeeks,
    series: rows.map((row) => row.ratio ?? 0),
    value: totalRatio,
    status: lossStatus(totalRatio),
    delta,
    direction,
    updated_at: new Date().toISOString(),
  };
}

async function fetchReserveRunway() {
  const reserveResult = await db.query(
    `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN' LIMIT 1`
  );
  const reserveBalance = asNumber(reserveResult.rows[0]?.balance || 0);

  const dailyAvgResult = await db.query(
    `SELECT COALESCE(SUM(amount), 0) / GREATEST(COUNT(DISTINCT DATE(created_at)), 1) AS daily_avg
     FROM payouts
     WHERE status = 'disbursed'
       AND created_at >= NOW() - INTERVAL '30 days'`
  );
  const dailyAvg = asNumber(dailyAvgResult.rows[0]?.daily_avg || 0);
  const runwayDays = dailyAvg > 0 ? Math.floor(reserveBalance / dailyAvg) : null;

  const trendResult = await db.query(
    `WITH days AS (
       SELECT date_trunc('day', NOW()) - (s::int * INTERVAL '1 day') AS day
       FROM generate_series(0, 29) s
     ),
     payouts AS (
       SELECT date_trunc('day', created_at) AS day, SUM(amount) AS total
       FROM payouts
       WHERE status = 'disbursed'
         AND created_at >= NOW() - INTERVAL '30 days'
       GROUP BY 1
     ),
     series AS (
       SELECT d.day, COALESCE(p.total, 0) AS total
       FROM days d
       LEFT JOIN payouts p ON p.day = d.day
       ORDER BY d.day
     )
     SELECT day,
            AVG(total) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_avg
     FROM series
     ORDER BY day`
  );

  const trend = trendResult.rows.map((row) => {
    const rollingAvg = asNumber(row.rolling_avg || 0);
    return rollingAvg > 0 ? Math.round((reserveBalance / rollingAvg) * 10) / 10 : null;
  });

  return {
    days: runwayDays,
    floor_days: RUNWAY_AMBER_MIN,
    delta_vs_floor: runwayDays == null ? null : runwayDays - RUNWAY_AMBER_MIN,
    reserve_balance: reserveBalance,
    daily_payout_average: dailyAvg,
    trend,
    status: runwayStatus(runwayDays),
    updated_at: new Date().toISOString(),
  };
}

async function fetchPayoutSlaToday() {
  const result = await db.query(
    `SELECT EXTRACT(EPOCH FROM (disbursed_at - created_at)) AS latency_seconds
     FROM payouts
     WHERE status = 'disbursed'
       AND disbursed_at IS NOT NULL
       AND created_at >= date_trunc('day', NOW())
     ORDER BY created_at ASC
     LIMIT 400`
  );
  const dots = result.rows
    .map((row) => asOptionalNumber(row.latency_seconds))
    .filter((value) => value != null)
    .map((value) => Math.max(0, Math.round(value)));

  const sorted = [...dots].sort((a, b) => a - b);
  const index = sorted.length ? Math.floor(0.95 * (sorted.length - 1)) : null;
  const p95Seconds = index == null ? null : sorted[index];

  return {
    p95_seconds: p95Seconds,
    target_seconds: SLA_TARGET_SECONDS,
    dots,
    status: slaStatus(p95Seconds),
    updated_at: new Date().toISOString(),
  };
}

async function fetchZones() {
  const [zonesResult, policyCountsResult, premiumResult, payoutResult, locksResult, killsResult] = await Promise.all([
    db.query(`SELECT zone_id, city FROM zones ORDER BY city, zone_id`),
    db.query(
      `SELECT zone_id, COUNT(*) AS count
       FROM policies
       WHERE status = 'active' AND cancelled_at IS NULL
       GROUP BY zone_id`
    ),
    db.query(
      `SELECT p.zone_id AS zone_id, SUM(md.amount) AS premium
       FROM mandate_debits md
       JOIN policies p ON p.policy_id = md.policy_id
       WHERE md.status = 'success'
         AND md.attempted_at >= NOW() - INTERVAL '13 weeks'
       GROUP BY p.zone_id`
    ),
    db.query(
      `SELECT zone_id, SUM(amount) AS payouts
       FROM payouts
       WHERE status = 'disbursed'
         AND created_at >= NOW() - INTERVAL '13 weeks'
       GROUP BY zone_id`
    ),
    db.query(`SELECT zone_id FROM zone_enrollment_locks WHERE expires_at > NOW()`),
    db.query(`SELECT zone_id FROM zone_kill_switches WHERE active = true`),
  ]);

  const policyCounts = new Map(
    policyCountsResult.rows.map((row) => [row.zone_id, parseInt(row.count, 10) || 0])
  );
  const premiums = new Map(
    premiumResult.rows.map((row) => [row.zone_id, asNumber(row.premium)])
  );
  const payouts = new Map(
    payoutResult.rows.map((row) => [row.zone_id, asNumber(row.payouts)])
  );
  const activeLocks = new Set(locksResult.rows.map((row) => row.zone_id));
  const activeKills = new Set(killsResult.rows.map((row) => row.zone_id));

  return zonesResult.rows.map((row) => {
    const policyCount = policyCounts.get(row.zone_id) || 0;
    const premium = premiums.get(row.zone_id) || 0;
    const payout = payouts.get(row.zone_id) || 0;
    const ratio = premium > 0 ? payout / premium : null;
    const triggerActive = activeLocks.has(row.zone_id) || activeKills.has(row.zone_id);
    return {
      zone_id: row.zone_id,
      name: row.city || row.zone_id,
      policy_count: policyCount,
      loss_ratio: ratio,
      status: lossStatus(ratio),
      trigger_active: triggerActive,
    };
  });
}

async function fetchFraudPosture() {
  const [recentClaimsResult, queueResult, convergenceResult, killResult, escalatedResult] = await Promise.all([
    db.query(
      `SELECT COUNT(*) AS total,
              COUNT(*) FILTER (WHERE status IN ('auto_approved','approved')) AS auto_approved
       FROM claims
       WHERE submitted_at >= NOW() - INTERVAL '24 hours'`
    ),
    db.query(`SELECT COUNT(*) AS count FROM claims WHERE status = 'fraud_queue'`),
    db.query(
      `SELECT COUNT(*) AS count
       FROM agent_audit_log
       WHERE action = 'fraud_alert:convergence_freeze'
         AND logged_at >= NOW() - INTERVAL '24 hours'`
    ),
    db.query(`SELECT COUNT(*) AS count FROM zone_kill_switches WHERE active = true`),
    db.query(
      `SELECT COUNT(*) AS count
       FROM agent_audit_log
       WHERE action = 'escalated_to_crew_ai'
         AND logged_at >= NOW() - INTERVAL '24 hours'`
    ),
  ]);

  const totalClaims = parseInt(recentClaimsResult.rows[0]?.total || '0', 10) || 0;
  const autoApproved = parseInt(recentClaimsResult.rows[0]?.auto_approved || '0', 10) || 0;
  const autoApproveRate = totalClaims > 0 ? (autoApproved / totalClaims) * 100 : 0;

  return {
    auto_approve_rate: Math.round(autoApproveRate * 10) / 10,
    queue_depth: parseInt(queueResult.rows[0]?.count || '0', 10) || 0,
    convergence_alerts: parseInt(convergenceResult.rows[0]?.count || '0', 10) || 0,
    kill_switches_active: parseInt(killResult.rows[0]?.count || '0', 10) || 0,
    escalated_claims: parseInt(escalatedResult.rows[0]?.count || '0', 10) || 0,
    updated_at: new Date().toISOString(),
  };
}

function buildAttentionItems(summary) {
  const items = [];

  if (summary.reserve_runway.days != null && summary.reserve_runway.days < RUNWAY_AMBER_MIN) {
    items.push({
      id: 'reserve-floor',
      severity: 'red',
      message: `Reserve runway ${summary.reserve_runway.days}d below floor`,
      cta_label: 'Top up reserve',
    });
  }

  if (summary.loss_ratio.value != null && summary.loss_ratio.value > LOSS_AMBER_MAX) {
    items.push({
      id: 'loss-ratio-high',
      severity: 'red',
      message: `Loss ratio ${Math.round(summary.loss_ratio.value * 100)}% over 13 weeks`,
      cta_label: 'Review pricing',
    });
  }

  if (summary.payout_sla.p95_seconds != null && summary.payout_sla.p95_seconds > SLA_TARGET_SECONDS) {
    items.push({
      id: 'sla-breach',
      severity: summary.payout_sla.p95_seconds > SLA_AMBER_SECONDS ? 'red' : 'amber',
      message: `Payout SLA p95 at ${Math.round(summary.payout_sla.p95_seconds)}s`,
      cta_label: 'Inspect pipeline',
    });
  }

  if (summary.fraud.queue_depth > 15) {
    items.push({
      id: 'fraud-queue',
      severity: summary.fraud.queue_depth > 30 ? 'red' : 'amber',
      message: `Fraud queue depth at ${summary.fraud.queue_depth}`,
      cta_label: 'Escalate review',
    });
  }

  const hotZone = summary.zones
    .filter((zone) => zone.loss_ratio != null)
    .sort((a, b) => (b.loss_ratio || 0) - (a.loss_ratio || 0))
    .find((zone) => (zone.loss_ratio || 0) > LOSS_AMBER_MAX);

  if (hotZone) {
    items.push({
      id: `zone-${hotZone.zone_id}`,
      severity: 'amber',
      message: `${hotZone.name} zone loss ratio ${Math.round((hotZone.loss_ratio || 0) * 100)}%`,
      cta_label: 'Open zone file',
    });
  }

  return items.slice(0, 6);
}

async function buildSummary() {
  const [lossRatio, reserveRunway, payoutSla, zones, fraud, partnersResult, disbursedResult] = await Promise.all([
    fetchLossRatioSeries(13),
    fetchReserveRunway(),
    fetchPayoutSlaToday(),
    fetchZones(),
    fetchFraudPosture(),
    db.query(`SELECT COUNT(*) AS count FROM policies WHERE status = 'active' AND cancelled_at IS NULL`),
    db.query(
      `SELECT COALESCE(SUM(amount), 0) AS total
       FROM payouts
       WHERE status = 'disbursed'
         AND created_at >= date_trunc('day', NOW())`
    ),
  ]);

  const partnersProtected = parseInt(partnersResult.rows[0]?.count || '0', 10) || 0;
  const disbursedToday = asNumber(disbursedResult.rows[0]?.total || 0);
  const slaHeadline = payoutSla.status === 'green' ? 'all SLAs green' : payoutSla.status === 'amber' ? 'SLA watch' : 'SLA breached';

  const heroText = `${formatInt(partnersProtected)} partners protected · ${formatInrShort(disbursedToday)} disbursed today · ${slaHeadline}`;
  const attention = buildAttentionItems({
    loss_ratio: lossRatio,
    reserve_runway: reserveRunway,
    payout_sla: payoutSla,
    zones,
    fraud,
  });

  return {
    hero: { text: heroText, updated_at: new Date().toISOString() },
    loss_ratio: lossRatio,
    reserve_runway: reserveRunway,
    payout_sla: payoutSla,
    zones,
    fraud,
    attention,
    generated_at: new Date().toISOString(),
  };
}

router.get('/summary', async (req, res, next) => {
  try {
    const summary = await buildSummary();
    res.status(200).json(summary);
  } catch (err) {
    next(err);
  }
});

router.get('/loss-ratio', async (req, res, next) => {
  try {
    const lossRatio = await fetchLossRatioSeries(req.query.weeks);
    res.status(200).json(lossRatio);
  } catch (err) {
    next(err);
  }
});

router.get('/zones', async (req, res, next) => {
  try {
    const zones = await fetchZones();
    res.status(200).json({ zones, updated_at: new Date().toISOString() });
  } catch (err) {
    next(err);
  }
});

router.get('/sla/today', async (req, res, next) => {
  try {
    const sla = await fetchPayoutSlaToday();
    res.status(200).json(sla);
  } catch (err) {
    next(err);
  }
});

router.get('/fraud', async (req, res, next) => {
  try {
    const fraud = await fetchFraudPosture();
    res.status(200).json(fraud);
  } catch (err) {
    next(err);
  }
});

router.get('/attention', async (req, res, next) => {
  try {
    const summary = await buildSummary();
    res.status(200).json({ items: summary.attention, updated_at: summary.generated_at });
  } catch (err) {
    next(err);
  }
});

router.get('/stream', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const sendEvent = (event, data) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  let closed = false;
  const push = async () => {
    if (closed) return;
    try {
      const summary = await buildSummary();
      sendEvent('summary', summary);
    } catch (err) {
      sendEvent('error', { message: 'stream_update_failed' });
    }
  };

  await push();
  const intervalId = setInterval(push, 30000);

  req.on('close', () => {
    closed = true;
    clearInterval(intervalId);
    res.end();
  });
});

module.exports = router;