# Data Breach Response Runbook

## DPDP Act 2023 — 72-Hour Notification Requirement

Per Section 8 of the Digital Personal Data Protection Act 2023, Continuum must notify the Data Protection Board of India within 72 hours of becoming aware of a personal data breach.

## Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| Critical | PII exposed externally (Aadhaar, UPI, GPS) | Immediate (< 1 hour internal escalation) |
| High | Internal unauthorized access to PII | < 4 hours internal escalation |
| Medium | Metadata leak (no PII) | < 24 hours |
| Low | Policy violation, no data exposure | Document and review in weekly meeting |

## Response Steps

### 1. Detection & Recording (T+0)

```
POST /admin/breach
Authorization: Bearer <admin-jwt>
Content-Type: application/json

{
  "breach_type": "pii_exposure",
  "description": "Detailed description of what happened",
  "affected_data_principals": "estimated count or 'unknown'",
  "severity": "critical"
}
```

### 2. Containment (T+0 to T+1h)

- [ ] Activate `PAYOUT_KILL_SWITCH=true` if breach affects payout pipeline
- [ ] Rotate all potentially compromised secrets (API keys, KMS keys)
- [ ] Revoke compromised JWT tokens by rotating JWT_SECRET
- [ ] Isolate affected service containers

### 3. Assessment (T+1h to T+24h)

- [ ] Identify all affected data principals (workers)
- [ ] Determine scope of exposed data (which PII fields)
- [ ] Review audit logs: `SELECT * FROM agent_audit_log WHERE action LIKE 'breach%'`
- [ ] Determine root cause

### 4. Notification (T+24h to T+72h)

- [ ] Draft DPB notification with: nature of breach, categories of data, approximate number of affected individuals, likely consequences, measures taken
- [ ] Submit to Data Protection Board via official channel
- [ ] Notify affected data principals if severity is Critical or High

### 5. Remediation (T+72h onwards)

- [ ] Deploy technical fix for root cause
- [ ] Update KMS key rotation schedule if encryption was compromised
- [ ] Conduct post-incident review
- [ ] Update this runbook with lessons learned
