# Product Filing Matrix

Comprehensive checklist of all regulatory filings required before and during product operation.

## Pre-Launch Filings

| # | Filing | Authority | Status | Blocker | Notes |
|---|--------|-----------|--------|---------|-------|
| 1 | Regulatory Sandbox Application | IRDAI | Draft ready | None | See `irdai_sandbox_application.md` |
| 2 | Product UIN Registration | IRDAI | Pending | #1 approval | Unique Identification Number |
| 3 | Appointed Actuary Certificate | IRDAI | Template ready | Actuary engagement | See `actuarial_cert_template.md` |
| 4 | Reinsurance Treaty Filing | IRDAI | Skeleton ready | Reinsurer negotiation | See `reinsurance_skeleton.md` |
| 5 | Data Processing Registration | Data Protection Board | Pending | DPB operational | DPDP Act 2023 |
| 6 | Payment Aggregator License | RBI | Pending | UPI integration | For direct premium collection |
| 7 | KYC/AML Registration | FIU-IND | Pending | Company incorporation | Financial Intelligence Unit |
| 8 | GSTIN Registration | GST Council | Pending | Company incorporation | Insurance services GST |

## Technology Filings

| # | Filing | Authority | Status | Blocker | Notes |
|---|--------|-----------|--------|---------|-------|
| 9 | IT Infrastructure Audit | IRDAI | Pending | System deployment | IRDAI IT Governance Guidelines 2023 |
| 10 | Cyber Insurance | IRDAI | Pending | Insurer quotation | Mandatory for tech-driven products |
| 11 | CERT-In Registration | MeitY | Pending | Company incorporation | Incident reporting requirement |
| 12 | Cloud Security Certification | Internal | In progress | SOC 2 Type II audit | Required by IRDAI for cloud hosting |

## Ongoing Compliance

| # | Obligation | Frequency | Authority | Automated? |
|---|-----------|-----------|-----------|-----------|
| 13 | Premium & claims report | Quarterly | IRDAI | Partial — ledger queries ready |
| 14 | Solvency return | Quarterly | IRDAI | No — actuary attestation |
| 15 | Reinsurance cession statement | Quarterly | IRDAI | No — pending treaty |
| 16 | Policyholder grievance report | Monthly | IRDAI | No — grievance system pending |
| 17 | DPDP Act annual report | Annual | DPB | Partial — consent tracking ready |
| 18 | Anti-money laundering report | As needed | FIU-IND | No — KYC pipeline pending |
| 19 | Appointed actuary annual report | Annual | IRDAI | No — actuary attestation |
| 20 | IT governance report | Annual | IRDAI | Partial — metrics ready |

## Filing Dependencies Graph

```
Sandbox Application (#1)
  └─> Product UIN (#2)
       └─> Reinsurance Filing (#4)
       └─> Premium Collection Start
            └─> Quarterly Reports (#13)
            └─> Solvency Returns (#14)

Company Incorporation
  └─> KYC/AML (#7)
  └─> GSTIN (#8)
  └─> CERT-In (#11)

DPB Operational
  └─> Data Processing Registration (#5)
       └─> Annual DPDP Report (#17)

Actuary Engagement
  └─> Actuary Certificate (#3)
       └─> Annual Actuary Report (#19)
```

## External Blockers Summary

| Blocker | Dependencies | Owner | Target Resolution |
|---------|-------------|-------|-------------------|
| IRDAI sandbox cohort opening | #1 | Regulatory team | Next open cohort |
| Reinsurer negotiation | #4 | Finance team | Within 60 days of #1 approval |
| Appointed actuary engagement | #3, #14, #19 | HR / Legal | Before #1 submission |
| DPB becoming operational | #5, #17 | Government | External — monitor announcements |
| Company incorporation | #7, #8, #11 | Legal team | Pre-requisite for all filings |
| UPI payment aggregator | #6 | Payment team | RBI approval timeline ~90 days |
