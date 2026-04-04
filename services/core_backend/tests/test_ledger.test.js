// Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
// Validates: Requirements 9.2, 9.3

'use strict';

const fc = require('fast-check');

// ─── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('../src/db', () => ({ query: jest.fn() }));

const db = require('../src/db');
const {
  validatePayoutRecord,
  createPayoutRecord,
  checkReserveBalance,
} = require('../src/services/ledger');

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** A fully-populated valid payout record */
function validRecord(overrides = {}) {
  return {
    payout_id:   'payout-uuid-001',
    worker_id:   'worker-uuid-001',
    claim_id:    'claim-uuid-001',
    policy_id:   'policy-uuid-001',
    amount:      500,
    oracle_votes: [{ oracle: 'imd', vote: 'affirm' }],
    zone_id:     'MUM_ANDHERI_W',
    tier:        'silver',
    created_at:  new Date('2024-01-22T10:00:00Z'),
    ...overrides,
  };
}

// ─── validatePayoutRecord — unit tests ───────────────────────────────────────

describe('validatePayoutRecord', () => {
  test('passes for a fully-populated record', () => {
    expect(() => validatePayoutRecord(validRecord())).not.toThrow();
  });

  test('throws when record is null', () => {
    expect(() => validatePayoutRecord(null)).toThrow(/non-null object/);
  });

  test('throws when record is not an object', () => {
    expect(() => validatePayoutRecord('string')).toThrow(/non-null object/);
  });

  const requiredFields = [
    'payout_id',
    'worker_id',
    'claim_id',
    'amount',
    'oracle_votes',
    'zone_id',
    'tier',
    'created_at',
  ];

  requiredFields.forEach((field) => {
    test(`throws when ${field} is null`, () => {
      expect(() => validatePayoutRecord(validRecord({ [field]: null }))).toThrow(field);
    });

    test(`throws when ${field} is undefined`, () => {
      const rec = validRecord();
      delete rec[field];
      expect(() => validatePayoutRecord(rec)).toThrow(field);
    });
  });

  test('error message lists all missing fields', () => {
    const rec = validRecord({ payout_id: null, worker_id: undefined });
    delete rec.zone_id;
    expect(() => validatePayoutRecord(rec)).toThrow(/payout_id.*worker_id.*zone_id|zone_id.*payout_id/);
  });
});

// ─── checkReserveBalance — unit tests ────────────────────────────────────────

describe('checkReserveBalance', () => {
  beforeEach(() => jest.clearAllMocks());

  test('resolves with balance when balance >= amount', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] });
    const balance = await checkReserveBalance(500);
    expect(balance).toBe(10000);
  });

  test('resolves when balance exactly equals amount', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '500.00' }] });
    await expect(checkReserveBalance(500)).resolves.toBe(500);
  });

  test('throws when balance < amount', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '100.00' }] });
    await expect(checkReserveBalance(500)).rejects.toThrow(/Insufficient reserve balance/);
  });

  test('error message includes balance and amount', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '200.00' }] });
    await expect(checkReserveBalance(999)).rejects.toThrow(/200.*999|999.*200/);
  });

  test('throws when reserve_balance table is empty', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    await expect(checkReserveBalance(100)).rejects.toThrow(/no row/);
  });

  test('queries reserve_balance with id = 1', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '5000.00' }] });
    await checkReserveBalance(100);
    const [sql] = db.query.mock.calls[0];
    expect(sql).toMatch(/reserve_balance/);
    expect(sql).toMatch(/id\s*=\s*1/);
  });
});

// ─── createPayoutRecord — unit tests ─────────────────────────────────────────

describe('createPayoutRecord', () => {
  beforeEach(() => jest.clearAllMocks());

  const insertedRow = {
    payout_id:   'payout-uuid-001',
    worker_id:   'worker-uuid-001',
    claim_id:    'claim-uuid-001',
    policy_id:   'policy-uuid-001',
    amount:      '500.00',
    oracle_votes: [{ oracle: 'imd', vote: 'affirm' }],
    zone_id:     'MUM_ANDHERI_W',
    tier:        'silver',
    payu_txn_ref: null,
    status:      'pending',
    created_at:  new Date('2024-01-22T10:00:00Z'),
  };

  test('inserts and returns the payout row on success', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] }) // checkReserveBalance
      .mockResolvedValueOnce({ rows: [insertedRow] });             // INSERT

    const result = await createPayoutRecord(validRecord());

    expect(result.payout_id).toBe('payout-uuid-001');
    expect(result.worker_id).toBe('worker-uuid-001');
    expect(result.status).toBe('pending');
  });

  test('throws when a required field is missing (no DB calls made)', async () => {
    const rec = validRecord({ payout_id: null });

    await expect(createPayoutRecord(rec)).rejects.toThrow('payout_id');
    // DB should not be called at all
    expect(db.query).not.toHaveBeenCalled();
  });

  test('throws when reserve balance is insufficient (INSERT not called)', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '10.00' }] }); // low balance

    await expect(createPayoutRecord(validRecord())).rejects.toThrow(/Insufficient reserve/);
    // Only one DB call (reserve check), no INSERT
    expect(db.query).toHaveBeenCalledTimes(1);
  });

  test('defaults created_at to current time when not provided', async () => {
    const rec = validRecord();
    delete rec.created_at;

    db.query
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] })
      .mockResolvedValueOnce({ rows: [{ ...insertedRow }] });

    await createPayoutRecord(rec);

    // The INSERT call's 11th parameter ($11) should be a Date
    const insertCall = db.query.mock.calls[1];
    const createdAtParam = insertCall[1][10]; // 0-indexed, $11 is index 10
    expect(createdAtParam).toBeInstanceOf(Date);
  });

  test('defaults status to pending when not provided', async () => {
    const rec = validRecord();
    delete rec.status;

    db.query
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] })
      .mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(rec);

    const insertCall = db.query.mock.calls[1];
    const statusParam = insertCall[1][9]; // $10 = status
    expect(statusParam).toBe('pending');
  });

  test('passes oracle_votes as JSON string to INSERT', async () => {
    const votes = [{ oracle: 'imd', vote: 'affirm' }, { oracle: 'nasa_gpm', vote: 'affirm' }];
    const rec = validRecord({ oracle_votes: votes });

    db.query
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] })
      .mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(rec);

    const insertCall = db.query.mock.calls[1];
    const oracleVotesParam = insertCall[1][5]; // $6 = oracle_votes
    expect(typeof oracleVotesParam).toBe('string');
    expect(JSON.parse(oracleVotesParam)).toEqual(votes);
  });

  test('INSERT SQL targets the payouts table', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] })
      .mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(validRecord());

    const insertCall = db.query.mock.calls[1];
    expect(insertCall[0]).toMatch(/INSERT INTO payouts/i);
    expect(insertCall[0]).toMatch(/RETURNING/i);
  });
});

// ─── Property 26: Payout Record Completeness ─────────────────────────────────
// For any payout input, all required fields must be present and non-null in
// the persisted record. Any record missing a required field must be rejected
// before reaching the database.

describe('Property 26: Payout Record Completeness', () => {
  // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
  // Validates: Requirements 9.3

  const requiredFields = [
    'payout_id',
    'worker_id',
    'claim_id',
    'amount',
    'oracle_votes',
    'zone_id',
    'tier',
    'created_at',
  ];

  test('PBT — validatePayoutRecord rejects any record with at least one null required field', () => {
    // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
    // Validates: Requirements 9.3
    return fc.assert(
      fc.property(
        // Pick a non-empty subset of required fields to null out
        fc.subarray(requiredFields, { minLength: 1 }),
        (fieldsToNull) => {
          const overrides = Object.fromEntries(fieldsToNull.map((f) => [f, null]));
          const rec = validRecord(overrides);
          let threw = false;
          try {
            validatePayoutRecord(rec);
          } catch (e) {
            threw = true;
            // Error message must mention at least one of the nulled fields
            const mentionsField = fieldsToNull.some((f) => e.message.includes(f));
            if (!mentionsField) return false;
          }
          return threw;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — validatePayoutRecord accepts any record where all required fields are non-null', () => {
    // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
    // Validates: Requirements 9.3
    return fc.assert(
      fc.property(
        fc.record({
          payout_id:    fc.uuid(),
          worker_id:    fc.uuid(),
          claim_id:     fc.uuid(),
          amount:       fc.integer({ min: 1, max: 100000 }),
          oracle_votes: fc.array(fc.constant({ oracle: 'imd', vote: 'affirm' }), { minLength: 0 }),
          zone_id:      fc.string({ minLength: 1 }),
          tier:         fc.constantFrom('silver', 'gold', 'platinum'),
          created_at:   fc.date(),
        }),
        (rec) => {
          let threw = false;
          try {
            validatePayoutRecord(rec);
          } catch (_) {
            threw = true;
          }
          return !threw;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — createPayoutRecord never calls INSERT when a required field is null', () => {
    // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
    // Validates: Requirements 9.3
    // Note: created_at is excluded here because createPayoutRecord auto-defaults it
    // to new Date() when absent — that defaulting behaviour is tested separately.
    const fieldsCheckedBeforeDB = requiredFields.filter((f) => f !== 'created_at');

    return fc.assert(
      fc.asyncProperty(
        fc.subarray(fieldsCheckedBeforeDB, { minLength: 1 }),
        async (fieldsToNull) => {
          jest.clearAllMocks();
          const overrides = Object.fromEntries(fieldsToNull.map((f) => [f, null]));
          const rec = validRecord(overrides);

          let threw = false;
          try {
            await createPayoutRecord(rec);
          } catch (_) {
            threw = true;
          }

          // Must have thrown, and DB must not have been called at all
          return threw && db.query.mock.calls.length === 0;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — checkReserveBalance throws for any amount exceeding balance', () => {
    // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
    // Validates: Requirements 9.2
    return fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 0, max: 9999 }),   // balance (INR, integer for simplicity)
        fc.integer({ min: 1, max: 10000 }),  // amount
        async (balance, amount) => {
          jest.clearAllMocks();
          db.query.mockResolvedValueOnce({ rows: [{ balance: String(balance) }] });

          let threw = false;
          try {
            await checkReserveBalance(amount);
          } catch (_) {
            threw = true;
          }

          if (balance < amount) {
            return threw; // must throw
          } else {
            return !threw; // must not throw
          }
        }
      ),
      { numRuns: 100 }
    );
  });
});
