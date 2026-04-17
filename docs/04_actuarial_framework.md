# Continuum — Actuarial Framework

**Version:** 1.0  
**Effective Date:** 2026-04-17  
**Classification:** Regulatory / Investor / Actuarial Review  
**Audience:** IRDAI regulators, investors, licensed actuaries, CFO/finance team

> **Validation Status:** The framework and controls described in this document are implemented and runnable. Before production rate-filing, final rates and exclusions require licensed actuarial review and legal/regulatory sign-off. This document constitutes the technical actuarial specification for that review process.

---

## Table of Contents

1. [Actuarial Adequacy Principle](#1-actuarial-adequacy-principle)
2. [Technical Premium Formula](#2-technical-premium-formula)
3. [Pricing Inputs and Update Cadence](#3-pricing-inputs-and-update-cadence)
4. [16-Dimensional Risk Feature Vector](#4-16-dimensional-risk-feature-vector)
5. [Data-Sparse Zone Handling](#5-data-sparse-zone-handling)
6. [Loss Ratio Escalation Mechanism](#6-loss-ratio-escalation-mechanism)
7. [Governance Triggers and Intervention Thresholds](#7-governance-triggers-and-intervention-thresholds)
8. [Reserve Architecture](#8-reserve-architecture)
9. [Stress Scenarios and Solvency Testing](#9-stress-scenarios-and-solvency-testing)
10. [Backtesting Methodology](#10-backtesting-methodology)
11. [Actuarial CI/CD Gate](#11-actuarial-cicd-gate)
12. [Reinsurance Architecture](#12-reinsurance-architecture)
13. [Illustrative Worked Example](#13-illustrative-worked-example)
14. [Production Readiness Gates](#14-production-readiness-gates)

---

## 1. Actuarial Adequacy Principle

The foundational design constraint of Continuum's pricing engine is:

> **Solvency is never subordinated to UX affordability.**

The "One-Order Rule" (weekly premium should approximate the cost of 1–2 successful deliveries) is a **UX affordability ceiling**, not a pricing floor. The actuarial engine always computes the technically adequate premium first; the affordability anchor is applied only if it exceeds the technical premium.

If the technical premium exceeds the affordability anchor, the technical premium is charged. This ensures the product never operates at a structural loss for actuarial convenience.

This principle is enforced in code:
```python
# services/risk_profiler/premium.py
final_premium = max(affordability_anchor, technical_premium)
```

---

## 2. Technical Premium Formula

### 2.1 Three-Stage Formula

For zone `z`, tier `t`, week `w`:

**Stage 1 — Expected Loss Calculation**

```
ExpectedLoss(z,t,w) = Σ_e [ P(e | z, w) × Severity(e, z, t, w) × Exposure(t, w) ]
```

Where:
- `P(e | z, w)` = probability of trigger event `e` occurring in zone `z` during week `w`, derived from historical oracle events and forecast priors
- `Severity(e, z, t, w)` = expected payout weight for event type `e` in zone `z` for tier `t` in week `w`, bounded by tier coverage cap
- `Exposure(t, w)` = active policy-days and hourly activity curves for tier `t` in week `w`

**Simplified implementation in `premium.py`:**
```python
expected_loss = risk_score × coverage_cap × zone_loss_ratio
```

Where `risk_score` (output of the Gradient Boosting model on the 16-dim feature vector) encodes the combined probability × severity signal, and `zone_loss_ratio` is the 4-week rolling empirical loss ratio.

**Stage 2 — Technical Premium with Load Components**

```
TechnicalPremium(z,t,w) = ExpectedLoss
                        + ExpenseLoad
                        + FraudLoad
                        + ReinsuranceLoad
                        + RiskMargin
```

**Stage 3 — Final Premium (Affordability Ceiling Applied)**

```
FinalPremium(z,t,w) = max(AffordabilityAnchor(z,t,w), TechnicalPremium(z,t,w))
```

### 2.2 Load Component Definitions

| Component | Definition | Typical Range |
|-----------|-----------|--------------|
| `ExpenseLoad` | Payment rail fees, infrastructure cost, support and ops allocation per policy | ~24% of expected loss |
| `FraudLoad` | Anomaly detection rates × recovery cost for fraud events | ~10% of expected loss |
| `ReinsuranceLoad` | Treaty cost allocation per policy per week | ~13% of expected loss |
| `RiskMargin` | Solvency buffer targeting minimum 150% coverage ratio | ~16% of expected loss |

### 2.3 Implementation

```python
# services/risk_profiler/premium.py (simplified)
from decimal import Decimal, ROUND_HALF_UP

ESCALATION_THRESHOLD = Decimal("0.80")
ESCALATION_SLOPE = Decimal("2.5")

def compute_final_premium(
    risk_score,          # [0.0, 1.0] from Gradient Boosting model
    zone_loss_ratio,     # 4-week rolling empirical loss ratio
    coverage_cap,        # Tier coverage cap in INR
    affordability_anchor,# UX ceiling in INR
    expense_load,        # INR
    fraud_load,          # INR
    reinsurance_load,    # INR
    risk_margin,         # INR
    sparse_zone=False,   # True if zone has <90 days history
) -> Decimal:

    expected_loss = Decimal(str(risk_score)) * coverage_cap * Decimal(str(zone_loss_ratio))

    effective_risk_margin = risk_margin * Decimal("1.25") if sparse_zone else risk_margin

    technical_premium = (
        expected_loss + expense_load + fraud_load + reinsurance_load + effective_risk_margin
    )

    if Decimal(str(zone_loss_ratio)) > ESCALATION_THRESHOLD:
        escalation = Decimal("1") + (Decimal(str(zone_loss_ratio)) - ESCALATION_THRESHOLD) * ESCALATION_SLOPE
        technical_premium *= escalation

    return max(affordability_anchor, technical_premium).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
```

`Decimal` arithmetic is used throughout to avoid floating-point precision errors in financial calculations.

---

## 3. Pricing Inputs and Update Cadence

| Input | Symbol | Data Source | Update Cadence |
|-------|--------|-------------|----------------|
| Event probability by trigger type | `P(e\|z,w)` | Historical oracle events (TimescaleDB) + IMD 7-day forecast | Weekly |
| Event severity / expected payout weight | `Severity(e,z,t,w)` | Tier coverage caps + disruption intensity mapping | Weekly |
| Exposure (active policy and activity profile) | `Exposure(t,w)` | Active partner-days and hourly activity curves (PostgreSQL) | Daily → Weekly aggregate |
| Fraud adjustment load | `FraudLoad` | Claims anomaly rates + confirmed fraud recovery cost | Weekly |
| Expense load | `ExpenseLoad` | Payment rail cost, infra, support ops cost allocation | Monthly |
| Reinsurance load | `ReinsuranceLoad` | Treaty pricing + catastrophe attachment terms | Monthly / Quarterly |
| Risk margin | `RiskMargin` | Solvency target + volatility buffer | Weekly |

### Pricing Cadence Summary

- **Weekly recalculation:** For all active policies at the start of each 7-day billing cycle
- **Intra-week:** Exposure metrics updated daily; fed into next cycle
- **Monthly:** Expense and reinsurance loads reviewed and updated
- **Quarterly:** Full actuarial adequacy review including reinsurance treaty renegotiation if needed

---

## 4. 16-Dimensional Risk Feature Vector

The Gradient Boosting model ingests a 16-dimensional feature vector assembled by `FeatureBuilder` in `services/risk_profiler/feature_builder.py`:

| Index | Feature | Source | Fallback |
|-------|---------|--------|---------|
| 0 | `rainfall_mm_hr_current` | Weather API (live) | Zone median |
| 1 | `wind_speed_kmh_current` | Weather API (live) | Zone median |
| 2 | `temperature_c_current` | Weather API (live) | 25.0°C default |
| 3 | `weather_event_freq_30d` | TimescaleDB historical | Zone median |
| 4 | `flood_event_count_30d` | TimescaleDB historical | Zone median |
| 5 | `cyclone_event_count_30d` | TimescaleDB historical | Zone median |
| 6 | `aqi_event_count_30d` | TimescaleDB historical | Zone median |
| 7 | `active_days_last_30` | PostgreSQL worker profile | 15 days default |
| 8 | `avg_daily_orders` | PostgreSQL worker profile | 8 orders default |
| 9 | `platform_encoded` | PostgreSQL worker profile | 0 (Swiggy) |
| 10 | `tier_encoded` | PostgreSQL worker profile | 0 (Silver) |
| 11 | `zone_risk_index` | PostgreSQL zone table | 0.5 default |
| 12 | `hour_of_day` | System clock (UTC) | — |
| 13 | `day_of_week` | System clock (UTC) | — |
| 14 | `month` | System clock (UTC) | — |
| 15 | `claim_velocity_90d` | PostgreSQL claims history | 0.0 default |

### Concurrent Source Fetching

All three data sources are queried concurrently via `asyncio.gather`. Each source has a **500ms timeout**:

```python
ts_result, wx_result, pg_result = await asyncio.gather(
    self._fetch_timescale(zone_id, medians),   # historical weather
    self._fetch_weather(lat, lon, medians),     # live conditions
    self._fetch_postgres(worker_id, medians),   # worker profile
)
```

On timeout or error, zone-level median values substitute for the failing source. Substitutions are logged with `source`, `features_substituted`, and `reason` fields for actuarial audit.

---

## 5. Data-Sparse Zone Handling

Zones with fewer than **90 days of local event history** cannot generate reliable actuarial estimates from local data alone.

### Proxy-Zone KNN Bootstrap

For sparse zones:
1. The `fetch_zone_history_days(zone_id)` query checks local data maturity
2. If < 90 days: `fetch_proxy_zone_medians(zone_id, k=3)` retrieves medians from the 3 nearest zones by WGS84 geographic distance
3. Proxy medians are used in place of local zone medians for all feature fallbacks

### Uncertainty Multiplier

For sparse zones, the `risk_margin` component is scaled by **1.25× (25% uncertainty loading)**:

```python
if sparse_zone:
    effective_risk_margin = risk_margin * Decimal("1.25")
```

This conservative loading reflects the increased estimation uncertainty from proxied data. The multiplier is removed once the zone accumulates ≥90 days of local event history.

### Bootstrap Exit Criteria

A zone exits the sparse-zone bootstrap regime when:
- 90 consecutive days of local oracle event data have been collected
- At least 3 trigger events have been observed locally (minimum calibration sample)
- Local loss ratio has been computed for at least 4 billing cycles

---

## 6. Loss Ratio Escalation Mechanism

### 6.1 Escalation Formula

When a zone's 4-week rolling loss ratio (`zone_loss_ratio`) exceeds **80%**, an automatic premium escalation is applied:

```
EscalationMultiplier = 1 + (zone_loss_ratio − 0.80) × 2.5
TechnicalPremium_escalated = TechnicalPremium × EscalationMultiplier
```

**Examples:**
| Zone Loss Ratio | Escalation Multiplier | Effect |
|----------------|----------------------|--------|
| 80% (threshold) | 1.00× | No escalation |
| 90% | 1.25× | +25% premium |
| 100% | 1.50× | +50% premium |
| 120% | 2.00× | +100% premium |

### 6.2 Partner Notification

Partners in escalating zones receive **7 days advance notice** of premium changes through the app and push notification.

### 6.3 Sustained Loss Ratio Response

| Threshold | Duration | Response |
|-----------|----------|---------|
| Loss ratio > 80% | 4 consecutive weeks | Mandatory premium recalibration |
| Loss ratio > 100% | 13 consecutive weeks | Exposure controls + underwriting review |
| Simultaneous policies impacted > 1,000 | Single event | Reinsurance treaty activation |
| Reserve balance < 90-day runway | Any point | Immediate escalation — halt new enrollments |

---

## 7. Governance Triggers and Intervention Thresholds

Continuum's actuarial governance is automated, not discretionary. The following triggers are hard-coded and cannot be overridden by management without a formal rate-change process:

### 7.1 Zone-Level Triggers

| Trigger | Condition | Automatic Action |
|---------|-----------|-----------------|
| Zone loss ratio escalation | 4-week rolling LR > 80% | Premium escalation applied immediately via `EscalationMultiplier` |
| Zone underwriting review | 13-week rolling LR > 100% | New enrollment suspended in zone; actuarial review initiated |
| Annual claim day cap breach | Zone records >60 claim-days/year | Premium auto-escalates; zone flagged for manual review |

### 7.2 Portfolio-Level Triggers

| Trigger | Condition | Automatic Action |
|---------|-----------|-----------------|
| Reinsurance activation | >1,000 simultaneous impacted policies | Mandatory reinsurance treaty invocation |
| Reserve floor breach | Reserve < 90-day payout runway | Halt new enrollments; notify CFO; initiate reinsurance top-up |
| CI gate failure | Rolling 13-week portfolio LR > 100% in backtest | CI pipeline fails; deployment blocked |
| Stress scenario failure | Reserve depletion < 90 days in any stress run | CI pipeline fails; deployment blocked |

### 7.3 Concentration Controls

- **Per-trigger-type cap:** Maximum 5,000 simultaneous active policies exposed to any single oracle trigger type (e.g., Zomato outage)
- **Per-zone cap:** Maximum simultaneous policy exposure per zone to prevent single-zone liquidity shock
- **Tier-wise reserve isolation:** Silver, Gold, and Platinum reserve pools are isolated — Platinum payouts cannot deplete Silver reserves

---

## 8. Reserve Architecture

### 8.1 Minimum Reserve Requirement

Continuum maintains a minimum **90-day payout runway** in reserve at all times, calculated as:

```
MinimumReserve = ExpectedWeeklyPayouts × 13 (weeks)
```

Reserve funds are held exclusively in **RBI-approved low-risk liquid instruments**:
- Government Treasury bills
- RBI-approved money market funds
- No equity, no alternatives, no illiquid assets

Zero equity exposure is permitted on reserve capital.

### 8.2 Double-Entry Ledger Design

Reserve management uses a **full double-entry accounting system** in CockroachDB:

```
ledger_accounts:
  RESERVE_MAIN       -- primary payout reserve
  PREMIUM_INCOME     -- incoming weekly premium credits
  PAYOUT_EXPENSE     -- outgoing payout debits
  REINSURANCE_FUND   -- reinsurance treaty capital

ledger_entries:
  Every financial movement → one debit + one credit entry
  Amount must be > 0 (immutable constraint)
  Never updated or deleted — permanent audit trail
```

### 8.3 Concurrent Overdraw Prevention

The `SELECT ... FOR UPDATE` lock in `debitReserve()` (`services/core_backend/src/services/ledger.js`) serializes access to the `RESERVE_MAIN` account:

```javascript
await client.query('BEGIN');
const lockResult = await client.query(
    `SELECT balance FROM ledger_accounts
     WHERE account_id = 'RESERVE_MAIN' FOR UPDATE`
);
const balance = parseFloat(lockResult.rows[0].balance);
if (balance < amount) throw new InsufficientReserveError();
// Insert ledger entry + update balance atomically
await client.query('COMMIT');
```

This eliminates the race condition where two concurrent payouts both read a sufficient balance and both proceed, collectively overdrawing the reserve.

### 8.4 Reserve Monitoring

| Metric | Type | Alert Threshold |
|--------|------|----------------|
| `reserve_balance_inr` | Gauge | < ₹100,000 → `ReserveLow` alert (warning, 5 min) |
| `payout_sla_breach_total` | Counter | Any increase → `PayoutSLABreach` alert (critical, immediate) |

---

## 9. Stress Scenarios and Solvency Testing

Continuum's actuarial model is validated against three quantitative stress classes. These scenarios are implemented in `services/actuarial_lab/stress_scenarios.py` and run automatically as part of the CI/CD pipeline.

### 9.1 Scenario Class 1 — Catastrophic Correlated Event

**Description:** A cyclone or flood cluster simultaneously impacts a large number of policyholders in one or multiple contiguous zones.

**Simulation parameters:**
- Simultaneous impacted policy count: 500 to 5,000 (stress sweep)
- Payout rate: 100% of affected policies (worst case)
- Payout amount: Tier-weighted average coverage cap
- Reinsurance: Activated at >1,000 simultaneous policies

**Pass criterion:** Reserve remains above 90-day runway after full payout, accounting for reinsurance recovery. Benefit-Claim Ratio (BCR) ≥ 1.0.

### 9.2 Scenario Class 2 — Systemic Technology Outage

**Description:** A platform-wide Zomato or Swiggy outage affects all policies in all zones simultaneously.

**Simulation parameters:**
- Affected policies: All active policies on the affected platform
- Duration: Up to 8 hours (maximum outage window)
- Payout trigger: Outage oracle consensus achieved (2-of-3)
- Payout rate: 60% of affected policies (historical participation rate in outage claims)

**Pass criterion:** Reserve sustains payout without reinsurance activation (below 1,000-policy threshold). Reserve depletion > 90 days post-event.

**Systemic risk cap:** Maximum 5,000 simultaneous policies exposed to a single outage trigger type, enforced at policy enrollment.

### 9.3 Scenario Class 3 — Climate Drift

**Description:** A multi-season increase in severe-event frequency versus the training baseline — modeled as climate change increasing monsoon severity over a 3-year horizon.

**Simulation parameters:**
- Trigger frequency multiplier: 1.5× to 3.0× current baseline (stress sweep)
- Premium adjustment: Model recalibrated with new frequencies; premium escalation applied
- Loss ratio trajectory: Rolling 13-week LR tracked under stressed frequencies

**Pass criterion:** At 2.0× trigger frequency, automatic premium escalation (via `EscalationMultiplier`) is sufficient to bring the portfolio LR below 100% within 4 recalibration cycles.

### 9.4 Benefit-Claim Ratio (BCR) Calculation

```
BCR = TotalPremiumsCollected / TotalClaimsPaid
```

Target BCR: ≥ 1.3 (at least ₹1.30 collected for every ₹1.00 paid out), reflecting the need to fund expenses, reinsurance, and reserves.

---

## 10. Backtesting Methodology

Implemented in `services/actuarial_lab/historical_backtest.py`.

### 10.1 Data Sources

| Source | Database | Data Type |
|--------|---------|-----------|
| Historical oracle events | TimescaleDB | Trigger event frequency, zone, intensity |
| Historical payouts | CockroachDB | Paid amounts, zone, tier, oracle votes |
| Historical premiums | CockroachDB | Premium versions, effective dates |
| Zone metadata | PostgreSQL | Zone polygons, risk index |

### 10.2 Backtest Metrics

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Brier Score** | Calibration of trigger probability forecasts | < 0.25 (well-calibrated) |
| **Calibration buckets** | Predicted vs. actual trigger rates in decile bins | Deviation < 15% per bucket |
| **Rolling 13-week portfolio loss ratio** | Claims paid / premiums collected in trailing 13 weeks | < 100% in all windows |
| **Zone-level loss ratio** | Per-zone 4-week and 13-week rolling loss ratios | Flags zones above 80% threshold |
| **Expected vs. realized trigger count** | Model prediction accuracy vs. historical events | Within ±25% at zone level |

### 10.3 Backtesting Depth Requirements

| Zone Type | Minimum History | Rationale |
|-----------|-----------------|-----------|
| Mature zone (Tier 1 cities) | 24 months event history | Minimum for rolling out-of-sample validation |
| Developing zone (Tier 2/3 cities) | 12 months + proxy bootstrap | Proxy data supplements local history |
| New zone (<90 days) | Proxy-zone KNN | Full bootstrap until local history matures |

### 10.4 Calibration Quality Gate

Probability calibration checks are performed on trigger frequencies and payout incidence — not only point prediction error. A model with high accuracy on average but poor calibration in tail events is insufficient for actuarial adequacy.

### 10.5 Backtest Output

```python
# BacktestResult
BacktestResult(
    portfolio_loss_ratio=0.74,
    portfolio_bcr=1.35,
    rolling_13w_loss_ratios=[...],  # list of {week, loss_ratio} dicts
    brier_score=0.18,
    zones_below_24m=['BLR_NORTH_FRINGE'],  # zones flagged for insufficient history
    passed=True,  # False if any 13w window exceeds 100%
)
```

---

## 11. Actuarial CI/CD Gate

**File:** `services/actuarial_lab/ci_gate.py`

The actuarial CI gate is an executable script that **blocks deployment** if actuarial adequacy criteria are not met.

### 11.1 Gate Conditions (Either Condition Fails the Build)

| Condition | Check | Fail Action |
|-----------|-------|-------------|
| Portfolio loss ratio | Rolling 13-week portfolio LR > 100% in any backtest window | `sys.exit(1)` |
| Stress scenario | Any stress scenario produces reserve depletion < 90 days | `sys.exit(1)` |

### 11.2 Usage

```bash
python -m services.actuarial_lab.ci_gate \
    --ts-dsn "postgresql://user:pass@timescaledb:5432/continuum" \
    --crdb-dsn "postgresql://user:pass@cockroachdb:26257/continuum"
```

### 11.3 CI Gate Output (Success)

```json
{
  "event": "ci_gate_passed",
  "portfolio_bcr": 1.35,
  "portfolio_lr": 0.74,
  "stress_all_passed": true
}
```

### 11.4 Rationale

Integrating actuarial validation into CI/CD prevents:
- Premium schedule changes that inadvertently push the portfolio LR above 100%
- Reserve configuration changes that reduce the buffer below the 90-day minimum under stress
- Model updates that degrade pricing calibration without triggering human review

---

## 12. Reinsurance Architecture

### 12.1 Treaty Trigger

A mandatory reinsurance treaty is activated for any single event breaching the **1,000-simultaneous-policyholder threshold**. This is the capital backstop preventing catastrophic liquidity events from invalidating outstanding policies.

### 12.2 Treaty Structure

| Parameter | Design |
|-----------|--------|
| Attachment point | 1,000 simultaneous impacted policyholders |
| Coverage limit | Up to 10,000 simultaneous policyholders (above: aggregate excess-of-loss layer) |
| Treaty pricing | INR-locked multi-year fixed rates (eliminates FX risk) |
| Recovery mechanism | Automatic treaty invocation upon threshold breach |
| Settlement | Reinsurer funds deposited to `REINSURANCE_FUND` ledger account |

### 12.3 Reinsurance Reserve Account

The `REINSURANCE_FUND` account in the double-entry ledger tracks reinsurance treaty capital separately from operational reserves, enabling clean audit separation between policyholder reserves and treaty recoveries.

### 12.4 Climate Risk Reinsurance

For scenarios where climate drift increases trigger frequency beyond 2.0× baseline, an additional catastrophe-layer reinsurance attachment is designed at the portfolio level. Specific terms require licensed actuarial and treaty negotiation before production.

---

## 13. Illustrative Worked Example

**Zone:** Bangalore South  
**Tier:** Silver  
**Risk Week:** Moderate-risk week (illustrative only; production values require licensed actuarial calibration against ≥24 months of historical event data)

```
Step 1: Expected Loss
  P(weather_event | zone, week)  = 0.12  (12% weekly trigger probability, IMD historical)
  AvgSeverity                    = ₹320  (weighted avg payout across disruption intensities)
  Exposure                       = 1.0   (full active week)
  ExpectedLoss = 0.12 × 320 × 1.0 = ₹38.40

  Simplified via implementation:
  risk_score = 0.48 (Gradient Boosting model output)
  coverage_cap = ₹500 (Silver tier)
  zone_loss_ratio = 0.16 (low recent loss ratio)
  ExpectedLoss = 0.48 × 500 × 0.16 = ₹38.40

Step 2: Load Components
  ExpenseLoad     = ₹9.00   (~24% of expected loss — payment rails, infra, support)
  FraudLoad       = ₹4.00   (anomaly rate × recovery cost)
  ReinsuranceLoad = ₹5.00   (treaty cost allocation per policy)
  RiskMargin      = ₹6.00   (solvency buffer targeting 150% coverage ratio)

Step 3: Technical Premium
  TechnicalPremium = 38.40 + 9.00 + 4.00 + 5.00 + 6.00 = ₹62.40

Step 4: Loss Ratio Check
  zone_loss_ratio = 0.16 < 0.80 → No escalation multiplier applied

Step 5: Affordability Anchor vs. Technical Premium
  AffordabilityAnchor (One-Order Rule) = ₹55.00
  FinalPremium = max(₹55.00, ₹62.40) = ₹62.40

Result: Partner is charged ₹62.40/week for Silver tier coverage.
        Technical premium exceeds affordability anchor → solvency wins.

[If zone_loss_ratio were 0.90 (>0.80):]
  EscalationMultiplier = 1 + (0.90 − 0.80) × 2.5 = 1.25
  TechnicalPremium_escalated = 62.40 × 1.25 = ₹78.00
  FinalPremium = max(₹55.00, ₹78.00) = ₹78.00
```

---

## 14. Production Readiness Gates

The following conditions must be satisfied before Continuum moves from prototype to production rate-filing:

### 14.1 Actuarial

- [ ] Licensed actuarial firm review of premium formula, inputs, and update cadence
- [ ] Minimum 24 months of historical oracle event data per mature zone
- [ ] Backtesting depth certification: Brier score < 0.25, rolling 13-week LR < 100% in all historical windows
- [ ] Probability calibration certification: deviation < 15% per decile bin
- [ ] Stress scenario sign-off for all three classes (catastrophic, systemic, climate drift)
- [ ] Capital protection certification: 90-day reserve runway under all stress scenarios
- [ ] Concentration control sign-off: per-zone and per-trigger-type exposure caps validated

### 14.2 Legal and Regulatory

- [ ] IRDAI sandbox license (Year 1) — income protection indemnity product classification
- [ ] Legal review of Terms and Conditions (`docs/06_terms_and_conditions.md`) by qualified insurance law counsel
- [ ] Exclusion clause legal certification (war, terrorism, pandemic, CBRN)
- [ ] Dispute resolution clause compliance (Consumer Protection Act 2019)
- [ ] DPDP Act 2023 data processing agreement finalized

### 14.3 Financial

- [ ] Initial reserve capitalization (minimum 90-day runway per zone)
- [ ] Reinsurance treaty finalized with specific attachment points and INR-locked pricing
- [ ] Tier-wise reserve pool isolation verified in CockroachDB double-entry ledger
- [ ] Razorpay/PayU production merchant account and eNACH mandate approval

### 14.4 Technical

- [ ] Actuarial CI gate passing in production environment with live DSNs
- [ ] Oracle certificate fingerprints configured for all production oracle endpoints
- [ ] Model provenance verification active (SHA-256 hash checked on sidecar startup)
- [ ] Prometheus alerting live and tested (`OracleHighAbstentionRate`, `PayoutSLABreach`, `ReserveLow`)
- [ ] IRDAI reporting infrastructure operational

---

*This document is the technical actuarial specification. Final rates, exclusions, and reserve requirements must be confirmed by a licensed actuary before production deployment. Illustrative examples are conceptual and are not intended as filed rates.*
