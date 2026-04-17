# Continuum — Product Specification

**Version:** 1.0  
**Effective Date:** 2026-04-17  
**Classification:** Regulatory / Investor / Partner Distribution  
**Product:** Parametric Income Protection for Gig Delivery Partners

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Scope and Definition](#2-product-scope-and-definition)
3. [Target Persona and Use Case](#3-target-persona-and-use-case)
4. [Covered Trigger Categories](#4-covered-trigger-categories)
5. [Standard Exclusions](#5-standard-exclusions)
6. [Coverage Tiers and Pricing](#6-coverage-tiers-and-pricing)
7. [Enrollment and Activation Lifecycle](#7-enrollment-and-activation-lifecycle)
8. [The Claim Process — How Automatic Payouts Work](#8-the-claim-process--how-automatic-payouts-work)
9. [Payout Rules and Limits](#9-payout-rules-and-limits)
10. [Adverse Selection Controls](#10-adverse-selection-controls)
11. [Appeals and Dispute Resolution](#11-appeals-and-dispute-resolution)
12. [Regulatory Positioning](#12-regulatory-positioning)
13. [Product Boundary Conditions](#13-product-boundary-conditions)

---

## 1. Executive Summary

Continuum is a **parametric income-protection product** designed for food delivery partners operating on platforms such as Zomato and Swiggy in India. It replaces traditional claims processing — which requires human adjusters, documentation, and days of waiting — with **fully automated, rule-based payouts** triggered the moment a verified disruption event occurs.

When a qualifying event fires (a severe weather event, a platform outage, or a government-mandated curfew), Continuum's oracle consensus engine detects it, validates it against multiple independent data sources, and disburses funds directly to the partner's UPI wallet — before the partner even submits a complaint.

**Key product facts:**

| Attribute | Value |
|-----------|-------|
| Product type | Parametric income protection |
| Coverage scope | Lost income from verified disruptions only |
| Premium cycle | Weekly (aligned to partner payout cadence) |
| Payment method | UPI eNACH recurring debit mandate |
| Payout SLA | ≤ 2 hours from oracle trigger to UPI credit |
| Claim process | Fully automated — no forms, no adjuster |
| Regulatory framework | India; IRDAI guidelines on parametric products |
| Active deployment | Azure VM (IP: 4.186.27.77), 11 microservices |

---

## 2. Product Scope and Definition

### 2.1 What Continuum Covers

Continuum provides **short-duration parametric income protection** against involuntary, machine-verifiable disruption events. Coverage is activated automatically when a qualifying parametric trigger fires. The payout is a **predefined policy benefit** — not a full indemnity of actual income.

Coverage is strictly bounded to **temporary loss of earning capacity** caused by:
- Severe meteorological events
- Severe air quality events
- Platform technology outages
- Government-mandated curfews or lockdowns

### 2.2 What Continuum Does NOT Cover

Continuum is not and does not substitute for:

| Category | Why Excluded |
|----------|-------------|
| Life insurance | Scope: partner death or survival benefit |
| Health / medical insurance | Scope: injury, illness, hospitalization |
| Vehicle insurance | Scope: damage to delivery vehicle |
| Employment protection | Scope: platform-initiated terminations, layoffs |
| Full income indemnity | Product type: parametric benefit, not reimbursement |
| Long-duration disruptions | Capital structure: micro-premium cannot support open-ended risk |

### 2.3 The Parametric Design Principle

Unlike indemnity insurance, Continuum pays a **fixed benefit amount upon verified trigger** — regardless of the partner's exact income loss on that day. This design:
- Eliminates subjective claims investigation entirely
- Enables sub-2-hour payout from trigger to UPI credit
- Removes the moral-hazard risk of income fabrication
- Allows mechanistic, auditable payout decisions

---

## 3. Target Persona and Use Case

### 3.1 Primary Persona: The Food Delivery Partner

Continuum was designed around primary field research — structured interviews with active Swiggy delivery partners — revealing extreme income volatility and zero employer safety net.

| Persona | Daily Schedule | Daily Orders | Net Daily Income | Key Vulnerability |
|---------|---------------|-------------|-----------------|------------------|
| Power User (Sudarshan) | 17-hour shift | 45–50 orders | ~₹2,100 | ₹250 platform penalty per failed delivery |
| Full-Time Earner (Dakshina Moorthy) | 15-hour shift (8AM–11PM) | ~30 orders | ~₹1,500 | Penalties frequently equal one order's revenue |
| Part-Time Operator (Sudha) | 8-hour block | ~20 orders | ₹700–800 | Exposure to municipal strikes and flooding |

**Common characteristics:**
- 100% income dependent on daily active hours
- No sick days, no employer safety net, no income buffer
- Highly sensitive to platform downtime during peak hours
- Operates hyper-locally within specific municipal zones
- Paid weekly via platform payout cycles

### 3.2 Why Traditional Insurance Fails This Persona

- Annual/monthly premiums misalign with gig worker cash flow
- Claims processes require documentation and waiting days
- Traditional underwriting cannot price hyper-local parametric risk
- Partners lack steady employment records for standard risk assessment

---

## 4. Covered Trigger Categories

All trigger events require machine-verifiable, objective data from approved oracle sources. No human judgment or subjective assessment is involved in trigger determination.

### 4.1 Severe Meteorological Events

- **Trigger:** IMD-classified severe weather event, with rainfall ≥50mm within any 2-hour window in the partner's active zone, or equivalent IMD Red Alert classification
- **Oracles:** IMD Primary API, Private Weather Network (AccuWeather commercial feed), NASA GPM satellite precipitation data, ground-level sensor aggregation
- **Consensus required:** 3-of-4 oracle affirmative votes
- **Examples:** Torrential downpour causing waterlogging, cyclone landfall, severe flooding

### 4.2 Severe Air Quality Events

- **Trigger:** AQI > 300 (Hazardous classification) from CPCB CAAQMS stations in the partner's zone, sustained for the disruption window
- **Oracles:** CPCB CAAQMS API, ground-level air quality sensors, IMD meteorological data
- **Consensus required:** 2-of-3 oracle affirmative votes
- **Rationale:** AQI >300 renders outdoor delivery unsafe; outdoor workers face health risk from continued operation

### 4.3 Platform Technology Outages

- **Trigger:** Verified systemic outage of Zomato or Swiggy delivery/order-routing API, meeting all of: ≥35% complaint spike on Downdetector AND synthetic ping timeout from ≥3 independent geographic locations
- **Oracles:** Downdetector scraping, synthetic API monitoring, platform API status endpoints
- **Consensus required:** 2-of-3 oracle affirmative votes
- **Scope:** Regional or platform-wide outages; minor latency alone is insufficient

### 4.4 Government-Mandated Curfews / Lockdowns

- **Trigger:** Machine-parseable advisory from municipal or state authority, delivered via official RSS feed or equivalent digital channel, mandating cessation of movement or commerce in the partner's zone
- **Validation:** Advisory must carry verifiable digital signature or PGP certificate from the issuing authority
- **Scope:** Only government-mandated, legally enforceable orders qualify. Voluntary shutdowns, religious festivals, and commercial decisions do not qualify

---

## 5. Standard Exclusions

These exclusions are permanent and cannot be waived by individual partners. They are aligned with standard IRDAI insurance product design conventions.

### 5.1 Exclusion Table

| Exclusion Class | Precise Scope | Risk Classification | Actuarial Rationale |
|----------------|--------------|---------------------|---------------------|
| **War / Armed conflict** | War, invasion, civil war, insurrection, military action of any kind | Catastrophic correlated | Unbounded correlated loss; cannot be priced in weekly micro-premiums |
| **Terrorism / Sabotage** | Terrorism, sabotage, politically motivated violent acts | Catastrophic correlated | Intentional extreme loss volatility and accumulation risk |
| **Pandemic / Epidemic** | Pandemics, epidemics, declared public-health emergencies | Systemic correlated | Long-tail, multi-zone, prolonged business interruption exceeds parametric product risk appetite |
| **Nuclear / CBRN** | Nuclear, radiological, biological, or chemical contamination/events | Extreme tail | Severity tail exceeds any parametric product's capital structure |
| **Platform layoffs** | Platform-initiated workforce reductions, restructuring, account terminations | Non-insurable under scope | Employment risk, not short-duration involuntary disruption |
| **Voluntary shutdowns** | Non-mandatory closures, events below parametric thresholds, partner's choice to stop working | Behavioral / moral hazard | No objectively verifiable involuntary trigger event |
| **Death / Injury** | Claims based on partner's death, injury, or medical events | Scope boundary | Separate product category; life and health insurance |
| **Below-threshold events** | Weather or AQI events that do not meet the quantitative trigger thresholds | Threshold control | Avoiding payouts for minor inconveniences |
| **Fraud / Collusion** | Fraudulent, manipulated, or collusive conduct | Conduct exclusion | Explicit legal and contractual bar |

### 5.2 Alignment with Market Standards

These exclusions mirror standard market practice:
- Lloyd's of London war exclusion clauses (LMA5400 series)
- Swiss Re pandemic exclusion frameworks
- IRDAI guidelines on parametric micro-insurance product exclusions

Full legal exclusion language is in `docs/06_terms_and_conditions.md` Section 9.

---

## 6. Coverage Tiers and Pricing

### 6.1 Tier Structure

Three tiers map directly to a partner's weekly order volume and income profile:

| Tier | Target Partner | Weekly Premium (Base) | Coverage Cap | Typical Weekly Orders |
|------|---------------|----------------------|--------------|----------------------|
| **Silver** | Part-time / low-volume | ₹49 | ₹500/event | ≤20 orders/week |
| **Gold** | Regular / mid-volume | ₹99 | ₹1,000/event | 21–40 orders/week |
| **Platinum** | Power user / high-volume | ₹199 | ₹2,000/event | 41+ orders/week |

> **Disclaimer:** Published base prices are UX affordability anchors. Final charged premiums are computed by the actuarial engine and may exceed these anchors. See `docs/04_actuarial_framework.md` for the technical premium formula.

### 6.2 The Weekly Premium Cycle

Premiums are collected via **UPI eNACH recurring mandate**, aligned to the partner's existing weekly Zomato/Swiggy payout cadence. This design:
- Abstracts the cognitive burden of upfront payments
- Ensures collection timing matches cash inflow
- Enables automatic debit without per-week manual action

The mandate lifecycle is tracked through states: `CREATED → APPROVED → ACTIVE → PAUSED → REVOKED/FAILED`.

### 6.3 Dynamic Risk Pricing

The weekly premium is recalculated every week using a **16-dimensional feature vector** processed by a Gradient Boosting model. Pricing inputs include:

- 7-day meteorological forecast (rainfall, wind, temperature)
- 30-day historical weather event frequency
- AQI event history for the zone
- Zone-level 4-week rolling loss ratio
- Partner activity profile (active days, average daily orders)
- Platform type (Swiggy/Zomato encoded)
- Enrolled tier
- Day/month/hour temporal features
- 90-day claim velocity

### 6.4 The "One-Order Rule" — Affordability Anchor

The weekly premium targets the behavioral cost equivalent of 1–2 successful deliveries. This is a **UX ceiling, not a pricing floor** — the technical premium always wins if it exceeds the affordability anchor.

```
FinalPremium(z,t,w) = max(AffordabilityAnchor, TechnicalPremium)
```

Solvency is never subordinated to UX affordability.

### 6.5 Loss Ratio Escalation

If a zone's 4-week rolling loss ratio exceeds 80%, an automatic escalation multiplier is applied:

```
EscalationMultiplier = 1 + (zone_loss_ratio − 0.80) × 2.5
TechnicalPremium_escalated = TechnicalPremium × EscalationMultiplier
```

Partners in affected zones are notified 7 days in advance of premium changes.

---

## 7. Enrollment and Activation Lifecycle

### 7.1 Onboarding Requirements

Before activation, partners must complete:
1. **Phone OTP verification** (Firebase)
2. **KYC identity validation** — Aadhaar/PAN verification; stored as one-way cryptographic hash
3. **Device integrity attestation** — Play Integrity API / SafetyNet; rooted or emulated devices rejected
4. **Biometric liveness check** — face scan to prevent identity lending
5. **UPI mandate authorization** — eNACH mandate created and approved

### 7.2 Activation Waiting Period

**72-hour activation delay** applies after enrollment. No claim may be submitted or approved during this window, regardless of whether a qualifying trigger fires. This prevents same-day enrollment exploitation.

### 7.3 Tier Upgrades

Tier upgrades (e.g., Silver → Platinum) are subject to a **5-day waiting period** before the upgraded coverage takes effect for claim purposes. Pre-event opportunistic coverage escalation yields zero payout advantage.

### 7.4 Cancellation Policy

Policy cancellations are not effective until the **end of the current 7-day billing cycle**. A partner cannot cancel mid-week after a disruption event is publicly announced and benefit from the disruption without having paid for the full cycle.

### 7.5 One Policy Per Identity

Each of the following is bound 1:1 to a single active policy:
- National identity (Aadhaar hash — enforced by `UNIQUE` partial index on `aadhaar_hash` in the `workers` database table)
- Device fingerprint (enforced by `UNIQUE` partial index on `device_fingerprint`)
- Active home zone

Family-member account farming and device-sharing schemes are structurally impossible within these database-level constraints.

---

## 8. The Claim Process — How Automatic Payouts Work

Continuum's payout process is fully deterministic. No adjuster, no form, no phone call is required.

### 8.1 End-to-End Flow

```
[Oracle Polling — every ~N min ± 8 min randomized window]
          ↓
[Oracle Consensus Engine evaluates votes]
  - Staleness check: data >15 min old → abstention (not a vote)
  - Event-type-aware oracle set selected
  - Threshold evaluated (3-of-4 weather / 2-of-3 AQI / 2-of-3 outage)
          ↓
[Trigger Authorized? YES]
          ↓
[Kafka topic: oracle_trigger published]
          ↓
[Core Backend: BullMQ payout_disbursement job queued]
          ↓
[Claims Scoring Service (Rust) evaluates:
  - Spatial check (is partner inside triggered zone?)
  - PostGIS ST_Touches adjacency grace (50% if bordering zone)
  - Frequency check (velocity cap: ≤3 claims/90 days)
  - Isolation Forest anomaly score
  - Composite Fraud_Score = 0.4×spatial + 0.2×frequency + 0.4×IF_score
  - Platform activity cross-reference (completed orders → veto)
  - Soak period check (≥45 min pre-trigger presence required)
  - Biometric re-verification]
          ↓
[Score ≥ 0.7 AND no hard overrides?]
  YES → AUTO_APPROVED → UPI disbursement via PayU
  NO  → FRAUD_QUEUE → manual review (partner notified)
          ↓
[Firebase Cloud Messaging: lock-screen alert to partner]
```

### 8.2 Target SLA

The **2-hour SLA** is measured from oracle trigger authorization to UPI credit confirmation. SLA breaches are tracked by a `payout_latency_seconds` Prometheus histogram and trigger a `PayoutSLABreach` alert in real time.

### 8.3 No Human Override for Standard Claims

The claims engine is fully automated. No human can override the oracle consensus or scoring pipeline for standard claims. This design:
- Removes reputational-pressure fraud vectors
- Ensures consistency and auditability
- Prevents insider corruption of individual claim outcomes

---

## 9. Payout Rules and Limits

### 9.1 One Payout Per Policy Cycle

A hard cap of **one successful payout per 7-day policy cycle** applies, regardless of the number of distinct parametric triggers that fire during that week. This constraint is foundational to actuarial solvency.

### 9.2 Payout Cap by Tier

Payouts are capped at the partner's enrolled coverage cap:
- Silver: ₹500 per event
- Gold: ₹1,000 per event
- Platinum: ₹2,000 per event

Tier-switching during an active disruption window yields no advantage (5-day upgrade wait).

### 9.3 Adjacency Grace — Bordering Zone Partners

Partners in zones **immediately bordering** a triggered polygon receive a **50% pro-rated payout** (the "Adjacency Grace" rule). This is implemented via PostGIS `ST_Touches` spatial query. The payout record is flagged with `adjacency_pro_rated = TRUE` for audit purposes.

### 9.4 GPS Boundary — Partial Zone Coverage

Where a partner's GPS centroid spans two municipal boundaries, payout is calculated against the municipality containing the centroid. Partial-zone events pay 50% if the centroid falls within the affected region.

### 9.5 Policy Week Boundary — Late-Firing Triggers

If a parametric trigger fires at 11:59 PM on the last day of the policy week, the **full week's coverage benefit is honored**. Policies do not expire mid-disruption.

### 9.6 Off-Peak Prorating

Trigger events during periods of zero historical delivery volume (e.g., 2–4 AM) may result in prorated payouts based on historical hourly earnings profiles. Payouts compensate for actual earning-capacity loss, not notional availability.

### 9.7 Velocity Cap

A maximum of **3 successful claims per policyholder per 90-day rolling window** is enforced at the database level. Claims exceeding this limit are routed to mandatory manual review hold regardless of technical validity.

---

## 10. Adverse Selection Controls

### 10.1 72-Hour Forecast Enrollment Lockout

A separate **Forecast Oracle** polls IMD 72-hour-ahead predictions. When a high-risk event is predicted in a zone, the Oracle Engine publishes an `enrollment_lock` Kafka event. The Core Backend inserts a `zone_enrollment_locks` record with an `expires_at` timestamp. Until expiry, `POST /policies` returns **HTTP 423 (Locked)** with the reason and expiry time.

This prevents opportunistic same-day enrollment before a known storm or outage.

### 10.2 72-Hour Activation Delay

Even without a forecast lock, the mandatory 72-hour delay between enrollment and claim eligibility structurally prevents:
- Same-day enrollment and claim
- Enrollment triggered by real-time storm warnings

### 10.3 Referral Reward Delay

Referral bonuses are withheld until the referred partner completes **60 days with zero claims**. This destroys the economics of referral-farming fraud rings.

---

## 11. Appeals and Dispute Resolution

### 11.1 Internal Fast-Track Review

Partners may appeal a claim denial through the app within the timeline displayed in the policy portal. Continuum commits to a **48-hour internal fast-track review** of contested outcomes.

### 11.2 Escalated Dispute Resolution

If internal review does not resolve the dispute, the partner may escalate to **third-party SEBI-approved arbitration** (where contractually valid and legally permitted). Arbitration venue and timeline details are specified in the partner's policy schedule.

### 11.3 Consumer Rights

Mandatory consumer rights under applicable Indian law remain unaffected by any contractual arbitration clause.

### 11.4 SLA Compensation

Where Continuum expressly commits to a payout SLA and misses it, **automatic 10% bonus compensation credit** applies. SLA breach is detected in real time by Prometheus and triggers operational escalation.

---

## 12. Regulatory Positioning

### 12.1 Product Classification

Continuum is designed as a **parametric income protection product** under IRDAI's framework for parametric micro-insurance products. It is not a general-purpose insurance product and does not provide open-ended indemnity.

### 12.2 IRDAI Compliance Design

The product was designed with an 11-point IRDAI compliance audit in mind. Key enhancements made for compliance:
- AQI/CPCB oracle integration (outdoor worker safety)
- Event-type-weighted oracle consensus (epistemic rigor)
- UPI eNACH mandate collection (frictionless premium collection)
- Forecast-driven enrollment lockout (adverse selection prevention)
- Double-entry financial ledger (reserve integrity)
- PostGIS adjacency grace (boundary fairness)
- Proxy-zone KNN bootstrap (data-sparse zone handling)
- Payout SLA metrics with Prometheus alerting
- Aadhaar/device uniqueness constraints (identity integrity)
- Model provenance verification (ML governance)
- DPDP Act consent and 30-day proximity log retention (data privacy)

### 12.3 Governing Law

These products and their terms are governed by the laws of India, subject to mandatory local consumer protections. Jurisdiction and arbitration venue are specified in each partner's policy schedule.

### 12.4 Production Readiness Gate

Before production deployment, final rates and exclusions require:
- Licensed actuarial review and sign-off
- Legal and regulatory counsel approval
- IRDAI sandbox license (Year 1)
- Backtesting against ≥24 months of historical event data per mature zone
- Capital protection certification and reserve adequacy sign-off

---

## 13. Product Boundary Conditions

These boundary conditions are handled explicitly in the product design:

| Scenario | Handling |
|----------|---------|
| Trigger fires at 11:59 PM on last day of policy week | Full week's benefit honored |
| Partner GPS centroid straddles two zones | Payout based on centroid zone |
| Two disruptions in same 7-day cycle | Hard cap: 1 payout per cycle maximum |
| Partner in adjacent (non-triggered) zone also stranded | 50% adjacency grace payout |
| ≥2 of 4 oracles offline during verified disaster | 50% benefit-of-doubt protocol activated |
| UPI payment rails down nationally | Payouts queued, auto-retried with exponential backoff |
| Partner's UPI SIM-swapped during payout | 6-hour cooling period + biometric reconfirmation |
| Zone data history <90 days | Proxy-zone KNN bootstrap + 1.25× risk margin multiplier |
| Zone loss ratio >80% for 4 consecutive weeks | Mandatory premium recalibration |
| >1,000 simultaneous policies impacted | Reinsurance treaty activation |

---

*This document is a product specification. For binding legal terms, see `docs/06_terms_and_conditions.md`. For actuarial methodology, see `docs/04_actuarial_framework.md`. For security controls, see `docs/03_security_and_compliance.md`.*
