// Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
// Validates: Requirements 9.2, 9.3

'use strict';

const fc = require('fast-check');

// ─── Mocks ────────────────────────────────────────────────────────────────────
// debitReserve (called by createPayoutRecord) uses db.connect() for transactions.
// mockClientQuery / mockRelease are declared here so tests can configure them.

jest.mock('../src/db', () => ({ query: jest.fn(), connect: jest.fn() }));

const db = require('../src/db');

// Shared mock client — configured in beforeEach so each test starts clean
const mockClientQuery = jest.fn().mockResolvedValue({ rows: [] });
const mockRelease = jest.fn();
const {
  validatePayoutRecord,
  createPayoutRecord,
  checkReserveBalance,
  creditReserve,
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
// checkReserveBalance now queries ledger_accounts (primary) and falls back to
// the legacy reserve_balance table when ledger_accounts has no RESERVE_MAIN row.

describe('checkReserveBalance', () => {
  beforeEach(() => jest.clearAllMocks());

  test('resolves with balance when balance >= amount (ledger_accounts path)', async () => {
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
    await expect(checkReserveBalance(500)).rejects.toThrow(/Insufficient reserve/);
  });

  test('error message includes balance and amount', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '200.00' }] });
    await expect(checkReserveBalance(999)).rejects.toThrow(/200.*999|999.*200/);
  });

  test('throws when both ledger_accounts and reserve_balance table are empty', async () => {
    // First call: ledger_accounts returns empty → fallback triggered
    // Second call: reserve_balance also empty → throw
    db.query
      .mockResolvedValueOnce({ rows: [] })   // ledger_accounts
      .mockResolvedValueOnce({ rows: [] });  // reserve_balance fallback
    await expect(checkReserveBalance(100)).rejects.toThrow(/no reserve account found/);
  });

  test('queries ledger_accounts as primary reserve source', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ balance: '5000.00' }] });
    await checkReserveBalance(100);
    const [sql] = db.query.mock.calls[0];
    expect(sql).toMatch(/ledger_accounts/);
    expect(sql).toMatch(/RESERVE_MAIN/);
  });

  test('fallback: uses reserve_balance table when ledger_accounts is empty', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] })                           // ledger_accounts empty
      .mockResolvedValueOnce({ rows: [{ balance: '500.00' }] });    // reserve_balance fallback
    const balance = await checkReserveBalance(100);
    expect(balance).toBe(500);
    // Second query should target reserve_balance with id = 1
    const [sql] = db.query.mock.calls[1];
    expect(sql).toMatch(/reserve_balance/);
    expect(sql).toMatch(/id\s*=\s*1/);
  });
});

// ─── createPayoutRecord — unit tests ─────────────────────────────────────────

describe('createPayoutRecord', () => {
  // createPayoutRecord calls debitReserve which uses db.connect() for a transaction.
  // client.query calls in order: BEGIN, SELECT FOR UPDATE, UPDATE RESERVE, UPDATE EXPENSE, INSERT entry, COMMIT
  // Then db.query is called for the final INSERT INTO payouts.
  beforeEach(() => {
    jest.clearAllMocks();
    // Set up connect() to return mock client with default empty-row responses
    mockClientQuery.mockResolvedValue({ rows: [] });
    db.connect.mockResolvedValue({ query: mockClientQuery, release: mockRelease });
  });

  // Helper: configure client.query for a successful debitReserve (balance=10000)
  function setupSuccessfulDebit() {
    mockClientQuery
      .mockResolvedValueOnce({ rows: [] })                           // BEGIN
      .mockResolvedValueOnce({ rows: [{ balance: '10000.00' }] })   // SELECT FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })                           // UPDATE RESERVE_MAIN
      .mockResolvedValueOnce({ rows: [] })                           // UPDATE PAYOUT_EXPENSE
      .mockResolvedValueOnce({ rows: [] })                           // INSERT ledger_entry
      .mockResolvedValueOnce({ rows: [] });                          // COMMIT
  }

  // Helper: configure client.query for a failed debitReserve (insufficient balance)
  function setupInsufficientDebit() {
    mockClientQuery
      .mockResolvedValueOnce({ rows: [] })                          // BEGIN
      .mockResolvedValueOnce({ rows: [{ balance: '10.00' }] })     // SELECT FOR UPDATE (low)
      .mockResolvedValueOnce({ rows: [] });                         // ROLLBACK
  }

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
    setupSuccessfulDebit();
    db.query.mockResolvedValueOnce({ rows: [insertedRow] }); // INSERT INTO payouts

    const result = await createPayoutRecord(validRecord());

    expect(result.payout_id).toBe('payout-uuid-001');
    expect(result.worker_id).toBe('worker-uuid-001');
    expect(result.status).toBe('pending');
  });

  test('throws when a required field is missing (no DB calls made)', async () => {
    const rec = validRecord({ payout_id: null });

    await expect(createPayoutRecord(rec)).rejects.toThrow('payout_id');
    // DB should not be called at all (validation fails before any DB access)
    expect(db.connect).not.toHaveBeenCalled();
    expect(db.query).not.toHaveBeenCalled();
  });

  test('throws when reserve balance is insufficient (INSERT not called)', async () => {
    setupInsufficientDebit();

    await expect(createPayoutRecord(validRecord())).rejects.toThrow(/Insufficient reserve/);
    // db.query (INSERT payouts) must NOT be called — error happened inside debitReserve
    expect(db.query).not.toHaveBeenCalled();
  });

  test('defaults created_at to current time when not provided', async () => {
    const rec = validRecord();
    delete rec.created_at;

    setupSuccessfulDebit();
    db.query.mockResolvedValueOnce({ rows: [{ ...insertedRow }] });

    await createPayoutRecord(rec);

    // The INSERT INTO payouts call's 11th parameter ($11) should be a Date
    const insertCall = db.query.mock.calls[0];
    const createdAtParam = insertCall[1][10]; // 0-indexed, $11 is index 10
    expect(createdAtParam).toBeInstanceOf(Date);
  });

  test('defaults status to pending when not provided', async () => {
    const rec = validRecord();
    delete rec.status;

    setupSuccessfulDebit();
    db.query.mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(rec);

    const insertCall = db.query.mock.calls[0];
    const statusParam = insertCall[1][9]; // $10 = status
    expect(statusParam).toBe('pending');
  });

  test('passes oracle_votes as JSON string to INSERT', async () => {
    const votes = [{ oracle: 'imd', vote: 'affirm' }, { oracle: 'nasa_gpm', vote: 'affirm' }];
    const rec = validRecord({ oracle_votes: votes });

    setupSuccessfulDebit();
    db.query.mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(rec);

    const insertCall = db.query.mock.calls[0];
    const oracleVotesParam = insertCall[1][5]; // $6 = oracle_votes
    expect(typeof oracleVotesParam).toBe('string');
    expect(JSON.parse(oracleVotesParam)).toEqual(votes);
  });

  test('INSERT SQL targets the payouts table', async () => {
    setupSuccessfulDebit();
    db.query.mockResolvedValueOnce({ rows: [insertedRow] });

    await createPayoutRecord(validRecord());

    const insertCall = db.query.mock.calls[0];
    expect(insertCall[0]).toMatch(/INSERT INTO payouts/i);
    expect(insertCall[0]).toMatch(/RETURNING/i);
  });
});

// ─── creditReserve — unit tests ──────────────────────────────────────────────

describe('creditReserve', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockClientQuery.mockResolvedValue({ rows: [] });
    db.connect.mockResolvedValue({ query: mockClientQuery, release: mockRelease });
  });

  test('credits reserve and returns new balance on success', async () => {
    mockClientQuery
      .mockResolvedValueOnce({ rows: [] })                          // BEGIN
      .mockResolvedValueOnce({ rows: [] })                          // SELECT FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })                          // UPDATE RESERVE_MAIN
      .mockResolvedValueOnce({ rows: [] })                          // UPDATE PREMIUM_INCOME
      .mockResolvedValueOnce({ rows: [] })                          // INSERT ledger_entry
      .mockResolvedValueOnce({ rows: [] });                         // COMMIT
    db.query.mockResolvedValueOnce({ rows: [{ balance: '10500.00' }] }); // final SELECT

    const balance = await creditReserve(500, 'mandate-debit-001');
    expect(balance).toBe(10500);
  });

  test('releases client on success', async () => {
    mockClientQuery.mockResolvedValue({ rows: [] });
    db.query.mockResolvedValueOnce({ rows: [{ balance: '1000.00' }] });

    await creditReserve(100, 'ref-001');
    expect(mockRelease).toHaveBeenCalledTimes(1);
  });

  test('rolls back and rethrows on error', async () => {
    const boom = new Error('constraint violation');
    mockClientQuery
      .mockResolvedValueOnce({ rows: [] })     // BEGIN
      .mockRejectedValueOnce(boom)             // SELECT FOR UPDATE throws
      .mockResolvedValueOnce({ rows: [] });    // ROLLBACK

    await expect(creditReserve(100, 'ref-002')).rejects.toThrow('constraint violation');
    const rollbackCall = mockClientQuery.mock.calls.find(c => c[0] && c[0].includes('ROLLBACK'));
    expect(rollbackCall).toBeDefined();
  });

  test('releases client even after error', async () => {
    mockClientQuery
      .mockResolvedValueOnce({ rows: [] })
      .mockRejectedValueOnce(new Error('db error'))
      .mockResolvedValueOnce({ rows: [] }); // ROLLBACK

    await expect(creditReserve(50, 'ref-003')).rejects.toThrow();
    expect(mockRelease).toHaveBeenCalledTimes(1);
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

          // Must have thrown, and neither db.connect nor db.query must be called
          return threw && db.connect.mock.calls.length === 0 && db.query.mock.calls.length === 0;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — checkReserveBalance throws for any amount exceeding balance', () => {
    // Feature: continuum-ml-pipelines, Property 26: Payout Record Completeness
    // Validates: Requirements 9.2
    // checkReserveBalance queries ledger_accounts (primary path); one mock suffices.
    return fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 0, max: 9999 }),   // balance (INR, integer for simplicity)
        fc.integer({ min: 1, max: 10000 }),  // amount
        async (balance, amount) => {
          jest.clearAllMocks();
          // Mock the ledger_accounts primary query
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
