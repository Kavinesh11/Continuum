# Continuum - Terms and Conditions (Income Protection)

This document sets out the binding terms for Continuum's parametric income protection product for delivery partners. By enrolling, renewing, or claiming under a Continuum policy, you agree to these Terms.

Important: This is a policy terms draft derived from Continuum's adversarial risk scenarios and technical controls. It must be reviewed by qualified legal counsel before production rollout.

## 1) Definitions

- **Continuum / Company** means the policy provider and its authorized operators.
- **Partner** means the enrolled delivery worker who holds an active policy.
- **Policy Cycle** means the 7-day billing and coverage cycle.
- **Home Zone** means the enrolled operating zone used for pricing and claim logic.
- **Trigger Event** means a qualifying, machine-verified disruption event.
- **Oracle** means an approved data source used in trigger determination.
- **Valid Claim** means a claim that satisfies all eligibility, verification, and exclusion rules.

## 2) Product Scope

2.1 Continuum provides parametric income protection for temporary disruption events.

2.2 Continuum does not provide life insurance, health insurance, medical reimbursement, vehicle insurance, or employment termination protection.

2.3 Coverage is a predefined policy benefit and is not a full indemnity of actual daily income unless specifically stated in the Partner's policy schedule.

## 3) Eligibility and Enrollment

3.1 Enrollment requires successful KYC and identity validation under applicable law.

3.2 One verified identity may hold only one active policy at a time.

3.3 One device may be bound to one active policy. Device sharing, account lending, synthetic accounts, and identity farming are prohibited.

3.4 Continuum may require liveness checks, biometric verification, and device integrity checks at onboarding and claim time.

3.5 Emulators, rooted/jailbroken devices, tampered environments, and failed attestation states may be ineligible for claims.

## 4) Policy Activation, Upgrades, and Cancellation

4.1 New enrollments have a 72-hour activation delay before first claim eligibility.

4.2 Tier upgrades take effect for claim eligibility after a 5-day waiting period.

4.3 Policy cancellations become effective only at the end of the current Policy Cycle.

4.4 A Partner may maintain only one active Home Zone per Policy Cycle.

## 5) Premiums, Taxes, and Pricing

5.1 Premiums are charged weekly via UPI eNACH mandate (autopay) unless otherwise disclosed. By enrolling, the Partner authorizes Continuum to create a recurring debit mandate on their registered UPI account.

5.2 Continuum may use dynamic risk pricing by zone, tier, and historical loss trends. Pricing is computed from a multi-dimensional feature vector that includes weather history, AQI event frequency, zone loss ratio, and partner activity profile.

5.3 Premium changes apply prospectively and do not retroactively alter an already active paid cycle.

5.4 Taxes are applied as required by law. Premium presentation may be tax-inclusive where applicable.

5.5 Data-sparse zones (with fewer than 90 days of local history) may carry a conservative uncertainty loading on the risk margin until sufficient local data has been collected.

## 6) Trigger Events and Oracle Determination

6.1 A Trigger Event is determined solely by Continuum's oracle and rules engine.

6.2 No single data source can unilaterally authorize payout.

6.3 Continuum uses event-type-weighted multi-oracle consensus, stale-data abstention rules, and source reliability weighting. Different trigger categories (weather, AQI, technology outage) consult distinct oracle sets and require majority consensus within their respective set.

6.4 Trigger logic parameters may be adjusted to protect solvency, prevent abuse, and reflect risk changes.

6.5 Public rumors, social media posts, and unverified community reports are not accepted trigger evidence.

6.6 Continuum may use forecast-based enrollment freezes to prevent adverse selection. When a high-confidence forecast predicts a qualifying event within 72 hours, new enrollments and tier upgrades in the affected zone may be temporarily suspended until the risk period passes.

## 7) Claim Eligibility and Verification

7.1 A claim is eligible only if the Partner was active and verifiably present in the impacted zone during the applicable disruption window.

7.2 Location validation is multi-signal and may include GPS, telecom/cell corroboration, device telemetry, time consistency checks, and platform activity verification.

7.3 Client-side timestamps are non-authoritative. Server-synced time is the source of truth.

7.4 Continuum may require pre-trigger zone presence (soak period), repeated timestamp consistency, and minimum movement/activity evidence.

7.5 Contradictory activity records (including completed deliveries during the claimed inability-to-work window) may result in claim denial.

7.6 Claim data submitted outside the eligible event window may be denied.

## 8) Payout Rules and Limits

8.1 Maximum one successful payout is allowed per Policy Cycle unless otherwise stated in the policy schedule.

8.2 Claim frequency controls apply. Excessive successful claims within rolling windows may be held for manual review.

8.3 Payout is capped by enrolled tier, Home Zone rules, and policy limits.

8.4 Adjacent-zone and partial-boundary situations may be paid on a prorated basis where policy rules permit.

8.5 Off-peak or low-activity periods may be weighted or prorated where payout methodology requires historical earnings profiles.

## 9) Exclusions

9.1 No payout is due for:

- war, invasion, armed conflict, civil war, insurrection, or military action
- terrorism, sabotage, or politically motivated violent acts
- pandemics, epidemics, or public-health emergency events unless an approved rider states otherwise
- nuclear, radiological, biological, or chemical contamination/events
- voluntary shutdowns or non-mandatory business pauses
- events below defined severity thresholds
- non-qualifying municipal or infrastructure incidents outside covered trigger definitions
- platform-initiated workforce reductions, restructuring, or account terminations
- claims based on death, injury, or medical events
- fraudulent, manipulated, or collusive conduct

9.2 Coverage applies only while policy is active and all eligibility conditions are satisfied.

## 10) Anti-Fraud, Collusion, and Abuse Controls

10.1 Continuum may automatically flag, freeze, queue, reject, or reverse suspicious claims.

10.2 High-risk patterns include but are not limited to spoofed location, static coordinate locking, identity misuse, synthetic account creation, coordinated mass submissions, referral abuse, and anomalous social/device clustering.

10.3 Continuum may impose temporary or permanent account restrictions following confirmed or suspected abuse.

10.4 Continuum may recover wrongful payouts and report misconduct to applicable authorities.

## 11) Infrastructure, Oracle Failure, and Emergency Fallback

11.1 If external data sources or payment rails fail, Continuum may queue payouts and process them once systems recover.

11.2 In exceptional disaster conditions, Continuum may apply capped emergency fallback payouts based on reduced evidence thresholds, if defined by policy logic.

11.3 Continuum may use alternative disbursement rails, retry queues, or cooling periods (for example, after payout destination changes) to reduce fraud and payment risk.

## 12) Payout SLA and Payment Handling

12.1 Valid claims are targeted for settlement within 2 hours of trigger confirmation (oracle trigger to UPI disbursement). This SLA is continuously monitored and enforced.

12.2 Where Continuum expressly commits to a payout SLA and misses it, compensation credits may apply according to published SLA terms. SLA breaches are tracked and alerted in real time.

12.3 Payouts are made only to verified payout credentials linked to the Partner account.

## 13) Data Use, Privacy, and Retention

13.1 By enrolling, the Partner consents to processing of operational data needed for underwriting, trigger validation, fraud prevention, and payout execution.

13.2 Data may include location telemetry, device integrity signals, claims metadata, and platform corroboration data.

13.3 Continuum may minimize, hash, aggregate, or delete high-granularity location data after retention windows as required by policy and law.

13.4 Partners who disable required telemetry may retain enrollment status but may become ineligible for claims.

13.5 Bluetooth and Wi-Fi proximity data used for population-level fraud detection requires explicit, separate consent in compliance with the Digital Personal Data Protection Act 2023. Partners may grant or withdraw proximity consent at any time. Proximity logs are automatically purged after 30 days.

13.6 National identity data (Aadhaar) is stored only as a one-way cryptographic hash for uniqueness enforcement and is never stored or transmitted in plaintext.

## 14) Appeals and Dispute Resolution

14.1 Claim denials may be appealed within the timeline shown in the app or policy portal.

14.2 Continuum will offer a fast-track internal review process for contested outcomes.

14.3 If unresolved, disputes may proceed to binding arbitration where contractually valid and legally permitted.

14.4 Mandatory consumer rights under applicable law remain unaffected.

## 15) Regulatory and Solvency Safeguards

15.1 Continuum may maintain reserve requirements, tier-specific risk pools, and reinsurance structures to protect solvency.

15.2 Continuum may modify product availability by jurisdiction to comply with regulatory directions.

15.3 Continuum may suspend enrollment, modify triggers, or cap exposure where required for legal compliance or capital protection.

## 16) Suspension and Termination

16.1 Continuum may suspend or terminate a policy for fraud, material breach, legal non-compliance, or repeated abuse.

16.2 On termination for cause, pending claims may be denied and unpaid benefits may be forfeited to the extent permitted by law.

## 17) Liability Limits

17.1 To the maximum extent permitted by law, Continuum is not liable for indirect, incidental, special, or consequential losses beyond stated policy benefits.

17.2 Continuum's total liability for a claim is limited to the applicable policy benefit cap.

## 18) Amendments and Notices

18.1 Continuum may update these Terms by publishing revised versions with an effective date.

18.2 Continued use after the effective date constitutes acceptance of revised Terms.

18.3 Material changes may be communicated through in-app, SMS, email, or dashboard notices.

## 19) Governing Law

19.1 These Terms are governed by the laws of India, subject to mandatory local consumer protections.

19.2 Jurisdiction and arbitration venue, where applicable, will be specified in the Partner's policy schedule.

---

## Appendix A - Contract Design Controls Mapped from Adversarial Scenarios

- Event-type-weighted multi-oracle consensus and anti-stale handling
- Multi-signal location corroboration (not GPS-only) with PostGIS adjacency grace
- Identity-perimeter controls (KYC with Aadhaar hash uniqueness, liveness, device fingerprint binding)
- Population-level anomaly detection and ring suppression with DPDP-compliant proximity logging
- Claim velocity and cycle-limit controls
- Waiting periods and anti-opportunistic timing safeguards
- Forecast-driven enrollment lockout for active adverse selection prevention
- Infrastructure fallback logic for outages and payment rail failures
- Double-entry ledger reserve management with serialized debit transactions
- Reinsurance and solvency protection controls
- UPI eNACH mandate-based premium collection
- Model provenance verification (SHA-256 hash checking at service startup)
- Prometheus-based alerting for oracle health, payout SLA, and reserve levels
- Actuarial backtesting and stress testing CI/CD gates

This appendix is explanatory and does not override the binding clauses above.
