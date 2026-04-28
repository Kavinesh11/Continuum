'use strict';

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const { readFileSync } = require('fs');
const path = require('path');

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

function loadSchema(name) {
  const schemaPath = path.resolve(__dirname, '../../contracts/oracle_events', `${name}.schema.json`);
  return JSON.parse(readFileSync(schemaPath, 'utf8'));
}

describe('contract tests: payout_authorized schema', () => {
  const schema = loadSchema('payout_authorized');
  const validate = ajv.compile(schema);

  test('valid event passes validation', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [
        { oracle_name: 'IMD', vote: 'affirm', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
        { oracle_name: 'AccuWeather', vote: 'affirm', polled_at: '2026-04-17T10:00:05Z', tls_valid: true },
        { oracle_name: 'NASA_GPM', vote: 'deny', polled_at: '2026-04-17T10:00:10Z', tls_valid: true },
      ],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.85,
    };
    expect(validate(event)).toBe(true);
  });

  test('missing required field payout_id fails', () => {
    const event = {
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'payout_id')).toBe(true);
  });

  test('payout_cap > 1 fails', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 1.5,
    };
    expect(validate(event)).toBe(false);
  });

  test('invalid vote value fails', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [
        { oracle_name: 'IMD', vote: 'maybe', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
      ],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
    };
    expect(validate(event)).toBe(false);
  });

  test('additional properties are rejected', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
      sneaky_field: 'should fail',
    };
    expect(validate(event)).toBe(false);
  });
});

describe('contract tests: enrollment_lock schema', () => {
  const schema = loadSchema('enrollment_lock');
  const validate = ajv.compile(schema);

  test('valid lock event passes', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440001',
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      forecast_data: { severity: 'red', probability: 0.92 },
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('missing event_id fails', () => {
    const event = {
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('invalid severity in forecast_data fails', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440001',
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      forecast_data: { severity: 'green', probability: 0.1 },
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });
});

describe('contract tests: fraud_alert schema', () => {
  const schema = loadSchema('fraud_alert');
  const validate = ajv.compile(schema);

  test('valid fraud alert passes', () => {
    const event = {
      alert_type: 'dlq_threshold_exceeded',
      queue: 'payout_disbursement',
      job_id: 'job-123',
      triggered_at: '2026-04-17T12:00:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('missing alert_type fails', () => {
    const event = {
      triggered_at: '2026-04-17T12:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('additional properties are allowed (schema permits)', () => {
    const event = {
      alert_type: 'anomaly_score',
      triggered_at: '2026-04-17T12:00:00Z',
      custom_field: 'extra info',
    };
    expect(validate(event)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// T18 — claim_decision schema (claim_id, worker_id, status, fraud_score, decided_at)
// ---------------------------------------------------------------------------

describe('contract tests: claim_decision schema', () => {
  const schema = loadSchema('claim_decision');
  const validate = ajv.compile(schema);

  test('valid auto_approved decision passes', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: 0.12,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('valid fraud_queue decision passes', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440011',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'fraud_queue',
      fraud_score: 0.87,
      decided_at: '2026-04-17T10:06:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('valid escalated_to_human decision with optional fields passes', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440012',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'escalated_to_human',
      fraud_score: 0.63,
      decided_at: '2026-04-17T10:07:00Z',
      zone_id: 'MUM_ANDHERI_W',
      policy_id: null,
      payout_cap: 0.5,
      reason: 'High confidence escalation',
    };
    expect(validate(event)).toBe(true);
  });

  test('missing claim_id fails', () => {
    const event = {
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: 0.1,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'claim_id')).toBe(true);
  });

  test('missing worker_id fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      status: 'auto_approved',
      fraud_score: 0.1,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'worker_id')).toBe(true);
  });

  test('missing status fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      fraud_score: 0.1,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('missing fraud_score fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('missing decided_at fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: 0.1,
    };
    expect(validate(event)).toBe(false);
  });

  test('invalid status enum value fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'pending',
      fraud_score: 0.1,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('fraud_score > 1.0 fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: 1.5,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('fraud_score < 0.0 fails', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: -0.1,
      decided_at: '2026-04-17T10:05:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('additional properties are rejected', () => {
    const event = {
      claim_id: '550e8400-e29b-41d4-a716-446655440010',
      worker_id: 'a0000000-0000-0000-0000-000000000001',
      status: 'auto_approved',
      fraud_score: 0.1,
      decided_at: '2026-04-17T10:05:00Z',
      extra_field: 'not allowed',
    };
    expect(validate(event)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// T18 — payout_authorized extended checks (zone_id, payout_cap, oracle_votes)
// Uses ajv.getSchema() to avoid re-compiling the already-registered schema.
// ---------------------------------------------------------------------------

describe('contract tests: payout_authorized — zone_id, payout_cap, oracle_votes JSONB shape', () => {
  // payout_authorized.v1 was already compiled in the first describe block above.
  // Retrieve the compiled validator rather than re-compiling (avoids $id conflict).
  const validate = ajv.getSchema('payout_authorized.v1');

  test('zone_id must be a non-empty string', () => {
    const base = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.85,
    };
    // Missing zone_id → fail
    expect(validate({ ...base })).toBe(false);

    // Empty zone_id → fail
    expect(validate({ ...base, zone_id: '' })).toBe(false);

    // Valid zone_id
    expect(validate({ ...base, zone_id: 'MUM_ANDHERI_W' })).toBe(true);
  });

  test('payout_cap must be between 0 and 1 inclusive', () => {
    const base = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
    };
    expect(validate({ ...base, payout_cap: 0.0 })).toBe(true);
    expect(validate({ ...base, payout_cap: 0.5 })).toBe(true);
    expect(validate({ ...base, payout_cap: 1.0 })).toBe(true);
    expect(validate({ ...base, payout_cap: -0.1 })).toBe(false);
    expect(validate({ ...base, payout_cap: 1.01 })).toBe(false);
  });

  test('oracle_votes each item has oracle_name and vote', () => {
    const base = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.75,
    };
    // Valid oracle_votes array
    expect(validate({
      ...base,
      oracle_votes: [
        { oracle_name: 'IMD', vote: 'affirm', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
        { oracle_name: 'NASA_GPM', vote: 'abstain', polled_at: '2026-04-17T10:00:01Z', tls_valid: true },
      ],
    })).toBe(true);

    // vote not in enum → fail
    expect(validate({
      ...base,
      oracle_votes: [{ oracle_name: 'IMD', vote: 'unknown' }],
    })).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// T18 — adverse_selection_lock schema (zone_id, event_type, expires_at)
// Uses enrollment_lock.schema.json which maps to the adverse_selection_lock topic
// ---------------------------------------------------------------------------

describe('contract tests: adverse_selection_lock (enrollment_lock schema)', () => {
  // enrollment_lock.v1 already compiled above; retrieve rather than re-compile.
  const validate = ajv.getSchema('enrollment_lock.v1');

  test('valid adverse_selection_lock event passes', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'adverse_selection_lock',
      forecast_data: { severity: 'orange', probability: 0.85 },
      locked_at: '2026-04-17T06:00:00Z',
      expires_at: '2026-04-19T06:00:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('zone_id is required', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      event_type: 'adverse_selection_lock',
      locked_at: '2026-04-17T06:00:00Z',
      expires_at: '2026-04-19T06:00:00Z',
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'zone_id')).toBe(true);
  });

  test('event_type is required', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      zone_id: 'MUM_ANDHERI_W',
      locked_at: '2026-04-17T06:00:00Z',
      expires_at: '2026-04-19T06:00:00Z',
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'event_type')).toBe(true);
  });

  test('expires_at is required (C9: lock must have defined expiry)', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'adverse_selection_lock',
      locked_at: '2026-04-17T06:00:00Z',
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'expires_at')).toBe(true);
  });

  test('expires_at must be ISO 8601 date-time', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'adverse_selection_lock',
      locked_at: '2026-04-17T06:00:00Z',
      expires_at: 'not-a-date',
    };
    expect(validate(event)).toBe(false);
  });

  test('forecast_data severity must be red/orange/yellow', () => {
    const base = {
      event_id: '550e8400-e29b-41d4-a716-446655440020',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'adverse_selection_lock',
      locked_at: '2026-04-17T06:00:00Z',
      expires_at: '2026-04-19T06:00:00Z',
    };
    expect(validate({ ...base, forecast_data: { severity: 'red', probability: 0.9 } })).toBe(true);
    expect(validate({ ...base, forecast_data: { severity: 'green', probability: 0.1 } })).toBe(false);
  });
});

describe('contract tests: cross-schema compatibility', () => {
  test('payout_authorized and enrollment_lock share zone_id format', () => {
    const payoutSchema = loadSchema('payout_authorized');
    const lockSchema = loadSchema('enrollment_lock');

    expect(payoutSchema.properties.zone_id.type).toBe(lockSchema.properties.zone_id.type);
    expect(payoutSchema.properties.zone_id.minLength).toBe(lockSchema.properties.zone_id.minLength);
  });

  test('all schemas use ISO 8601 date-time format for timestamps', () => {
    const schemas = ['payout_authorized', 'enrollment_lock', 'fraud_alert', 'claim_decision'];
    for (const name of schemas) {
      const schema = loadSchema(name);
      const timestampField = name === 'payout_authorized' ? 'authorized_at'
        : name === 'enrollment_lock' ? 'locked_at'
        : name === 'claim_decision' ? 'decided_at'
        : 'triggered_at';

      expect(schema.properties[timestampField].format).toBe('date-time');
    }
  });

  test('claim_decision and payout_authorized share zone_id as a string property', () => {
    const claimSchema = loadSchema('claim_decision');
    const payoutSchema = loadSchema('payout_authorized');

    expect(claimSchema.properties.zone_id.type).toContain('string');
    expect(payoutSchema.properties.zone_id.type).toBe('string');
  });
});
