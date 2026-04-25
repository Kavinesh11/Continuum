// Feature: continuum-ml-pipelines
// Tests for handlePayoutAuthorized — payout kill switches, runtime guards, and happy path
// Validates: V35 (automation disabled), V36 (kill switch), V37 (reserve floor), C8 (kill switches), C4

'use strict';

// ─── Mocks (hoisted by Jest — applied on every require including after resetModules) ─

jest.mock('../src/db', () => ({ query: jest.fn() }));
jest.mock('../src/services/ledger', () => ({
  createPayoutRecord: jest.fn(),
  checkReserveBalance: jest.fn(),
}));
jest.mock('../src/workers/queues', () => ({
  enqueueJob: jest.fn().mockResolvedValue(undefined),
  QUEUE_NAMES: { PAYOUT_DISBURSEMENT: 'payout_disbursement' },
}));

// ─── Shared fixture ──────────────────────────────────────────────────────────

const BASE_EVENT = {
  payout_id:        'payout-test-001',
  zone_id:          'MUM_ANDHERI_W',
  oracle_votes:     [{ oracle: 'imd', vote: 'affirm' }],
  authorized_at:    '2024-01-22T10:00:00.000Z',
  payout_cap:       1.0,
  benefit_of_doubt: false,
};

// ─── V36: PAYOUT_KILL_SWITCH=true ────────────────────────────────────────────
// Feature: continuum-ml-pipelines
// Validates: V36, C8

describe('V36: PAYOUT_KILL_SWITCH active — drops event before any DB call', () => {
  let handlePayoutAuthorized;
  let db;

  beforeEach(() => {
    jest.resetModules();
    process.env.PAYOUT_KILL_SWITCH = 'true';
    process.env.PAYOUT_AUTOMATION_ENABLED = 'true';
    // Re-require after resetModules so the handler reads the updated env constants
    db = require('../src/db');
    ({ handlePayoutAuthorized } = require('../src/workers/consumers/payoutAuthorizedHandler'));
  });

  afterEach(() => {
    delete process.env.PAYOUT_KILL_SWITCH;
    delete process.env.PAYOUT_AUTOMATION_ENABLED;
  });

  test('returns { status: dropped, reason: kill_switch }', async () => {
    const result = await handlePayoutAuthorized(BASE_EVENT);
    expect(result).toEqual({ status: 'dropped', reason: 'kill_switch' });
  });

  test('makes zero DB calls (kill switch checked before any query)', async () => {
    await handlePayoutAuthorized(BASE_EVENT);
    expect(db.query).not.toHaveBeenCalled();
  });
});

// ─── V35: PAYOUT_AUTOMATION_ENABLED=false ────────────────────────────────────
// Feature: continuum-ml-pipelines
// Validates: V35, C8

describe('V35: PAYOUT_AUTOMATION_ENABLED disabled — drops event before any DB call', () => {
  let handlePayoutAuthorized;
  let db;

  beforeEach(() => {
    jest.resetModules();
    delete process.env.PAYOUT_KILL_SWITCH;
    process.env.PAYOUT_AUTOMATION_ENABLED = 'false';
    db = require('../src/db');
    ({ handlePayoutAuthorized } = require('../src/workers/consumers/payoutAuthorizedHandler'));
  });

  afterEach(() => {
    delete process.env.PAYOUT_AUTOMATION_ENABLED;
  });

  test('returns { status: dropped, reason: automation_disabled }', async () => {
    const result = await handlePayoutAuthorized(BASE_EVENT);
    expect(result).toEqual({ status: 'dropped', reason: 'automation_disabled' });
  });

  test('makes zero DB calls (automation check before any query)', async () => {
    await handlePayoutAuthorized(BASE_EVENT);
    expect(db.query).not.toHaveBeenCalled();
  });
});

// ─── Runtime guards and happy path (automation ON, kill switch OFF) ───────────

describe('runtime guards (automation enabled, kill switch off)', () => {
  let handlePayoutAuthorized;
  let db, checkReserveBalance, createPayoutRecord, enqueueJob;

  beforeAll(() => {
    jest.resetModules();
    delete process.env.PAYOUT_KILL_SWITCH;
    process.env.PAYOUT_AUTOMATION_ENABLED = 'true';
    db = require('../src/db');
    ({ checkReserveBalance, createPayoutRecord } = require('../src/services/ledger'));
    ({ enqueueJob } = require('../src/workers/queues'));
    ({ handlePayoutAuthorized } = require('../src/workers/consumers/payoutAuthorizedHandler'));
  });

  beforeEach(() => {
    jest.clearAllMocks();
    checkReserveBalance.mockResolvedValue(100000);
  });

  // ── Zone-level pause ───────────────────────────────────────────────────────

  test('zone kill switch active — returns dropped:zone_paused', async () => {
    // zone_kill_switches query returns a hit
    db.query.mockResolvedValueOnce({ rows: [{ zone_id: 'MUM_ANDHERI_W' }] });

    const result = await handlePayoutAuthorized(BASE_EVENT);

    expect(result).toEqual({ status: 'dropped', reason: 'zone_paused' });
  });

  test('zone kill switch active — createPayoutRecord never called', async () => {
    db.query.mockResolvedValueOnce({ rows: [{}] });
    await handlePayoutAuthorized(BASE_EVENT);
    expect(createPayoutRecord).not.toHaveBeenCalled();
  });

  // ── Reserve floor breach (V37) ────────────────────────────────────────────

  test('V37: reserve floor breach — returns dropped:reserve_floor_breach', async () => {
    db.query.mockResolvedValueOnce({ rows: [] }); // zone check: no zone kill
    checkReserveBalance.mockRejectedValueOnce(new Error('Insufficient reserve: 50000 < 100000'));

    const result = await handlePayoutAuthorized(BASE_EVENT);

    expect(result).toEqual({ status: 'dropped', reason: 'reserve_floor_breach' });
  });

  test('V37: reserve floor breach — createPayoutRecord never called', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    checkReserveBalance.mockRejectedValueOnce(new Error('Insufficient reserve'));
    await handlePayoutAuthorized(BASE_EVENT);
    expect(createPayoutRecord).not.toHaveBeenCalled();
  });

  // ── Daily portfolio cap ────────────────────────────────────────────────────

  test('daily cap reached — returns dropped:daily_cap_reached', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })                         // zone check: clear
      .mockResolvedValueOnce({ rows: [{ total: '500000' }] });     // daily sum = cap

    const result = await handlePayoutAuthorized(BASE_EVENT);

    expect(result).toEqual({ status: 'dropped', reason: 'daily_cap_reached' });
  });

  test('daily cap at exactly DAILY_PORTFOLIO_CAP — still dropped (>= check)', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ total: '500000.00' }] });
    const result = await handlePayoutAuthorized(BASE_EVENT);
    expect(result.reason).toBe('daily_cap_reached');
  });

  // ── Happy path: two policies resolved and enqueued ────────────────────────

  test('happy path — returns zone_id + payouts array', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })                          // zone check
      .mockResolvedValueOnce({ rows: [{ total: '0' }] })           // daily sum
      .mockResolvedValueOnce({                                       // policies query
        rows: [
          { policy_id: 'pol-1', worker_id: 'wkr-1', tier: 'silver', coverage_cap: '500', worker_zone: 'MUM_ANDHERI_W' },
          { policy_id: 'pol-2', worker_id: 'wkr-2', tier: 'gold',   coverage_cap: '1000', worker_zone: 'MUM_ANDHERI_W' },
        ],
      });

    createPayoutRecord
      .mockResolvedValueOnce({ payout_id: 'out-1', worker_id: 'wkr-1', status: 'pending' })
      .mockResolvedValueOnce({ payout_id: 'out-2', worker_id: 'wkr-2', status: 'pending' });

    const result = await handlePayoutAuthorized(BASE_EVENT);

    expect(result.zone_id).toBe('MUM_ANDHERI_W');
    expect(result.payouts).toHaveLength(2);
    expect(result.payouts[0]).toMatchObject({ policy_id: 'pol-1', status: 'enqueued' });
    expect(result.payouts[1]).toMatchObject({ policy_id: 'pol-2', status: 'enqueued' });
  });

  test('happy path — enqueueJob called once per policy', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ total: '0' }] })
      .mockResolvedValueOnce({
        rows: [
          { policy_id: 'pol-1', worker_id: 'wkr-1', tier: 'silver', coverage_cap: '500', worker_zone: 'MUM_ANDHERI_W' },
          { policy_id: 'pol-2', worker_id: 'wkr-2', tier: 'gold',   coverage_cap: '1000', worker_zone: 'MUM_ANDHERI_W' },
        ],
      });

    createPayoutRecord
      .mockResolvedValueOnce({ payout_id: 'out-1', worker_id: 'wkr-1', status: 'pending' })
      .mockResolvedValueOnce({ payout_id: 'out-2', worker_id: 'wkr-2', status: 'pending' });

    await handlePayoutAuthorized(BASE_EVENT);

    expect(enqueueJob).toHaveBeenCalledTimes(2);
    expect(enqueueJob).toHaveBeenCalledWith(
      'payout_disbursement',
      'auto_payout',
      expect.objectContaining({ worker_id: 'wkr-1', zone_id: 'MUM_ANDHERI_W' })
    );
  });

  test('happy path — payout amount uses payout_cap from event when provided', async () => {
    // payout_cap=0.5 (BoD) should halve the amount
    const bodEvent = { ...BASE_EVENT, payout_cap: 0.5 };

    db.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ total: '0' }] })
      .mockResolvedValueOnce({
        rows: [{ policy_id: 'pol-1', worker_id: 'wkr-1', tier: 'silver', coverage_cap: '500', worker_zone: 'MUM_ANDHERI_W' }],
      });

    createPayoutRecord.mockResolvedValueOnce({ payout_id: 'out-1', worker_id: 'wkr-1', status: 'pending' });

    await handlePayoutAuthorized(bodEvent);

    // silver coverage_cap=500, payout_cap=0.5, adjacency=1.0 → amount=250
    const callArgs = createPayoutRecord.mock.calls[0][0];
    expect(callArgs.amount).toBe(250);
  });

  test('happy path — no active policies results in empty payouts array', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ total: '0' }] })
      .mockResolvedValueOnce({ rows: [] }); // no policies

    const result = await handlePayoutAuthorized(BASE_EVENT);

    expect(result.payouts).toHaveLength(0);
    expect(createPayoutRecord).not.toHaveBeenCalled();
  });
});
