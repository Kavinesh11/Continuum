# IRDAI Disclosure Schedule

Regulatory disclosures required for Continuum parametric micro-insurance product.

## Quarterly Disclosures

| Disclosure | Due | Recipient | Format |
|-----------|-----|-----------|--------|
| Premium collection report | Q+15 days | IRDAI | Form NL-1 equivalent |
| Claims/payout report | Q+15 days | IRDAI | Form NL-4 equivalent |
| Investment of funds | Q+15 days | IRDAI | Form NL-6 equivalent |
| Solvency ratio | Q+30 days | IRDAI | IRDAI prescribed format |
| Reinsurance summary | Q+30 days | IRDAI | Cession statement |

## Annual Disclosures

| Disclosure | Due | Recipient | Format |
|-----------|-----|-----------|--------|
| Audited financial statements | FY+90 days | IRDAI, MCA | IndAS format |
| Appointed actuary report | FY+90 days | IRDAI | IRDAI template |
| DPDP Act annual data report | FY+60 days | Data Protection Board | DPB template |
| Product performance review | FY+30 days | IRDAI | Sandbox-specific template |
| IT governance & cyber security | FY+60 days | IRDAI | IRDAI IT Governance guidelines |

## Event-Based Disclosures

| Trigger | Deadline | Recipient | Notes |
|---------|----------|-----------|-------|
| Data breach | 72 hours | Data Protection Board + affected workers | DPDP Act Section 8 |
| Material adverse event | 24 hours | IRDAI | Catastrophic payout event |
| Change in key personnel | 15 days | IRDAI | Actuary, principal officer |
| Product modification | Pre-approval | IRDAI | File & Use process |
| Technology platform change | 30 days prior | IRDAI | IT governance requirement |

## Sandbox-Specific Disclosures

| Disclosure | Frequency | Notes |
|-----------|-----------|-------|
| Monthly progress report | Monthly | Enrollment, payouts, trigger accuracy, loss ratio |
| Technology audit report | Quarterly | Oracle accuracy, system uptime, security incidents |
| Policyholder grievance report | Monthly | Resolution rate, average time |
| Exit readiness assessment | Quarterly | Premium return capacity, data portability |

## Internal Tracking

Each disclosure event should be logged in the `agent_audit_log` table:
```sql
INSERT INTO agent_audit_log (agent, action, detail)
VALUES ('regulatory_compliance', 'disclosure_submitted', '{"type": "quarterly_premium", "period": "Q1_FY26", "submitted_at": "2026-04-15"}');
```

## Responsible Parties

| Role | Responsibility |
|------|---------------|
| Appointed Actuary | Annual actuarial report, reserve certification |
| Compliance Officer | Filing deadlines, regulatory correspondence |
| DPO (Data Protection Officer) | DPDP disclosures, breach notifications |
| CTO | Technology disclosures, IT governance |
