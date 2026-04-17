# Continuum — Terms and Conditions (Income Protection)

**Version:** 2.0  
**Effective Date:** 2026-04-17  
**Product:** Parametric Income Protection for Gig Delivery Partners  
**Governing Law:** India

> **Legal Notice:** This document sets out the binding contractual terms for Continuum's parametric income protection product. Before production rollout, this document must be reviewed and certified by qualified insurance law counsel and approved by the relevant IRDAI regulatory authority. These terms supersede all prior versions.

---

## 1. Definitions

**"Continuum" / "Company"** means the policy provider, its licensed operators, and authorized agents acting on its behalf.

**"Partner"** means the enrolled gig delivery worker who holds an active policy under these Terms.

**"Policy Cycle"** means the 7-day billing and coverage cycle, commencing on the Partner's enrollment date and renewing automatically each week.

**"Home Zone"** means the geographic zone, identified by a unique WGS84 polygon ID, in which the Partner is enrolled and against which pricing and claim logic is applied.

**"Trigger Event"** means a qualifying, machine-verified disruption event that meets all parametric threshold requirements as determined by the Oracle consensus engine.

**"Oracle"** means an approved external data source consulted by Continuum's automated engine in determining whether a Trigger Event has occurred.

**"Valid Claim"** means a claim that satisfies all eligibility criteria, location verification requirements, and is not excluded under Section 9.

**"Technical Premium"** means the actuarially computed minimum weekly premium required to maintain solvency, calculated before application of the affordability anchor.

**"Tier"** means the Partner's enrolled coverage level: Silver, Gold, or Platinum.

**"Policy Benefit"** means the fixed predefined payout amount associated with the Partner's enrolled Tier, as specified in the Partner's policy schedule.

---

## 2. Product Scope

**2.1** Continuum provides **parametric income protection** for temporary, involuntary disruptions to a Partner's ability to earn income from gig delivery activities.

**2.2** Continuum does **not** provide, and shall not be construed to provide:
- life insurance or death benefit
- health insurance, medical reimbursement, or injury compensation
- vehicle insurance or property insurance
- employment protection or compensation for platform-initiated terminations
- full income indemnity of actual earnings (coverage is a predefined Policy Benefit)

**2.3** By enrolling, the Partner acknowledges that the Policy Benefit is a fixed parametric payout and not a reimbursement of actual income lost.

---

## 3. Eligibility and Enrollment

**3.1** Enrollment requires successful completion of all of the following:
- KYC identity validation under applicable Indian law (Aadhaar/PAN verification)
- Device integrity attestation via Android Play Integrity API or equivalent
- Biometric liveness verification
- Authorization of a UPI eNACH recurring debit mandate

**3.2** Each verified national identity (Aadhaar) may hold only **one active policy** at any time. Multiple policies under the same identity are structurally prevented at the database level.

**3.3** Each physical device may be bound to only **one active policy**. Device sharing, account lending, synthetic account creation, and identity farming are prohibited and will result in immediate termination for cause under Section 16.

**3.4** Continuum requires biometric liveness checks at claim submission. Emulators, rooted or jailbroken devices, and tampered device environments are permanently ineligible for claims.

**3.5** National identity data (Aadhaar number) is stored only as a one-way cryptographic hash for uniqueness enforcement. Aadhaar numbers are never stored or transmitted in plaintext by Continuum.

---

## 4. Policy Activation, Upgrades, and Cancellation

**4.1 Activation Delay:** New enrollments are subject to a **72-hour activation delay** from the time of enrollment. No claim may be submitted or honored during this period, regardless of whether a Trigger Event occurs.

**4.2 Tier Upgrades:** Tier upgrades (e.g., Silver to Gold or Platinum) take effect for claim eligibility only after a **5-day waiting period** from the time the upgrade is processed. This applies regardless of whether a Trigger Event occurs during the waiting period.

**4.3 Cancellation:** Policy cancellations submitted during an active Policy Cycle become effective only at the **end of that Policy Cycle**. A Partner cannot cancel mid-cycle to avoid paying for the current week's premium.

**4.4 Zone Restriction:** A Partner may maintain only one active Home Zone per Policy Cycle.

---

## 5. Premiums, Taxes, and Pricing

**5.1** Premiums are charged **weekly** via UPI eNACH recurring mandate (autopay). By enrolling, the Partner authorizes Continuum to create and execute a recurring debit mandate on their registered UPI account.

**5.2** Continuum uses dynamic risk pricing. The weekly premium is computed using an actuarial model that inputs weather history, AQI event frequency, zone loss ratio, partner activity profile, and other risk factors. The published Tier base prices (Silver ₹49/week, Gold ₹99/week, Platinum ₹199/week) are affordability anchors; the actual charged premium may exceed these if the actuarially computed Technical Premium is higher.

**5.3** The final premium is always: `FinalPremium = max(AffordabilityAnchor, TechnicalPremium)`. Solvency requirements take precedence over the affordability anchor.

**5.4** Premium changes apply prospectively from the next Policy Cycle and do not retroactively alter any premium already charged for the current cycle.

**5.5** All applicable taxes (including GST) are applied as required by law. Premium amounts communicated to Partners may be tax-inclusive.

**5.6** Zones with fewer than 90 days of local event history carry a conservative **1.25× uncertainty loading** on the risk margin, reflecting increased actuarial estimation uncertainty. This loading is removed once sufficient local data is collected.

---

## 6. Trigger Events and Oracle Determination

**6.1** A Trigger Event is determined solely by Continuum's automated oracle consensus engine. No single oracle, data source, or human can unilaterally authorize a payout.

**6.2** Oracle consensus uses **event-type-specific oracle sets** and majority thresholds:
- **Severe weather:** 3-of-4 oracle affirmative votes (IMD, AccuWeather, NASA GPM satellite, ground sensors)
- **AQI (air quality) events:** 2-of-3 oracle affirmative votes (CPCB CAAQMS, ground sensors, IMD)
- **Platform technology outage:** 2-of-3 affirmative votes (Downdetector, synthetic ping, platform API)
- **Curfew / lockdown:** Machine-parseable advisory from issuing authority with valid digital signature

**6.3** Oracle data older than **15 minutes** is treated as an abstention — not an affirmative vote. Stale data cannot trigger a payout.

**6.4** Public rumors, social media posts, news articles, and unverified community reports are not accepted as trigger evidence under any circumstances.

**6.5** Trigger logic parameters (thresholds, oracle sets, voting rules) may be adjusted by Continuum to protect solvency, prevent abuse, adapt to regulatory changes, or reflect updated risk assessments. Changes to trigger logic are disclosed to Partners in advance where operationally feasible.

**6.6 Forecast-Based Enrollment Lockout:** When Continuum's forecast oracle predicts a qualifying event in a zone within 72 hours with high confidence, new enrollments and tier upgrades in that zone are **temporarily suspended** until the risk period passes. This is an adverse selection control and does not affect existing active policies.

---

## 7. Claim Eligibility and Verification

**7.1** A claim is eligible only if all of the following are true:
- The Partner holds an active policy with `claim_eligible_from` timestamp in the past
- The Partner was verifiably present in the Home Zone during the Trigger Event window
- The Partner has not exceeded the velocity limit of 3 successful claims in the prior 90 days
- The Partner's device passes biometric liveness verification at claim time

**7.2** Location validation is **multi-signal** and may include:
- GPS coordinates (sampled across minimum 3 timestamps within the disruption window)
- Cellular network (Cell-ID) triangulation (GPS/cell mismatch >2km → location mismatch flag)
- Device telemetry (velocity, movement consistency)
- Server-side NTP time synchronization (client timestamps are non-authoritative)

**7.3** Partners must have been GPS-verified inside the Home Zone for a **minimum of 45 continuous minutes before** the parametric trigger fires (the "soak period"). Failure to meet the soak period requirement is a hard bar on claim eligibility.

**7.4** If the delivery platform (Zomato or Swiggy) records that the Partner **completed one or more orders** during the stated disruption window, the claim is denied. A Partner cannot simultaneously be "unable to work due to disruption" and active on the platform. This veto is hard and not subject to appeal on the facts.

**7.5** Claim data (GPS timestamps, device telemetry) submitted outside the qualifying event window will be denied.

---

## 8. Payout Rules and Limits

**8.1** A maximum of **one successful payout is permitted per Policy Cycle** (7-day period), regardless of the number of distinct Trigger Events that occur during that cycle.

**8.2** Payout is capped at the Partner's enrolled Tier coverage cap:

| Tier | Coverage Cap Per Event |
|------|----------------------|
| Silver | ₹500 |
| Gold | ₹1,000 |
| Platinum | ₹2,000 |

**8.3 Velocity Cap:** Partners with more than 3 successful claims in any rolling 90-day window are automatically moved to mandatory manual review for subsequent claims. This control applies regardless of individual claim validity.

**8.4 Adjacency Grace:** Partners whose Home Zone immediately borders a triggered zone (determined by PostGIS spatial adjacency query) may receive a **50% pro-rated payout** at Continuum's discretion, where the Partner can demonstrate their earning capacity was materially affected.

**8.5 GPS Boundary Proration:** Where a Partner's GPS centroid spans two municipal boundaries, the payout zone is the municipality containing the centroid. If a partial-zone event triggers and the centroid falls within the affected region, a 50% payout applies.

**8.6 Policy Week Boundary:** If a Trigger Event fires during the final minutes of an active Policy Cycle, the full Policy Benefit is honored for that cycle. Coverage does not expire mid-disruption.

**8.7 Off-Peak Proration:** Trigger events during historically low-delivery-volume hours may result in pro-rated payouts calibrated against historical hourly earnings profiles for that zone.

---

## 9. Exclusions

**9.1** No payout is due, regardless of any other provision, for losses caused directly or indirectly by:

**(a) War and Armed Conflict:**  
War, invasion, armed conflict (whether declared or not), civil war, insurrection, rebellion, revolution, military coup, or any action taken by military forces.

**(b) Terrorism and Politically Motivated Violence:**  
Terrorism, sabotage, politically motivated violent acts, or any incident classified as terrorism under Indian law or applicable international conventions.

**(c) Pandemic and Public Health Emergencies:**  
Pandemics, epidemics, declared public-health emergencies (national or state level), or any event arising from biological disease spread — unless a specific approved rider expressly provides such coverage.

**(d) Nuclear, Radiological, Biological, and Chemical Events:**  
Nuclear reaction, radiation, radioactive contamination, biological warfare agents, or chemical warfare agents of any kind.

**(e) Platform-Initiated Employment Actions:**  
Platform-initiated workforce reductions, restructuring, mass layoffs, partner account terminations, deactivations, or suspensions by the delivery platform employer.

**(f) Voluntary Shutdowns:**  
Voluntary cessation of work, non-mandatory business pauses, events below the defined parametric trigger thresholds, or commercial decisions by third parties that do not constitute a Trigger Event.

**(g) Non-Qualifying Municipal Events:**  
Municipal or infrastructure incidents that fall outside the covered trigger definitions (e.g., routine road closures, scheduled maintenance, non-emergency public works).

**(h) Death, Injury, and Medical Events:**  
Claims arising from the Partner's death, personal injury, illness, or hospitalization.

**(i) Fraud and Collusion:**  
Fraudulent, manipulated, or collusive conduct by the Partner or their associates, including but not limited to GPS spoofing, identity fabrication, coordinated mass submissions, device manipulation, or biometric fraud.

**9.2** Coverage applies only while the policy is active and all eligibility conditions in Section 3 and Section 7 are continuously satisfied.

**9.3** These exclusions are permanent and cannot be waived by individual Partners or Continuum agents. They align with standard insurance market practice including Lloyd's of London war exclusion clauses (LMA5400 series) and Swiss Re pandemic exclusion frameworks.

---

## 10. Anti-Fraud, Collusion, and Abuse Controls

**10.1** Continuum operates a multi-layer automated fraud detection system. Continuum may automatically flag, freeze, queue, reject, or reverse claims exhibiting suspicious patterns.

**10.2** High-risk patterns include but are not limited to:
- GPS coordinates inconsistent with cellular network triangulation (>2km mismatch)
- Failure to meet the 45-minute pre-trigger soak period
- Static GPS coordinates with zero movement velocity during a claimed work shift
- Claims submitted after completing deliveries during the same window
- Geographic convergence of ≥50 claims on an identical polygon within 5 minutes
- Social graph clustering of claiming devices based on prior physical proximity

**10.3** Continuum may impose **temporary or permanent account restrictions** following confirmed or reasonably suspected abuse. Partners subjected to account restrictions will be notified through the app.

**10.4** Continuum may recover wrongful payouts through account credit offset against future benefits, and may report confirmed fraud to relevant Indian law enforcement and regulatory authorities.

---

## 11. Infrastructure, Oracle Failure, and Emergency Fallback

**11.1** If external data sources or payment rails fail, Continuum will queue valid payouts and process them once systems recover. Queued payouts retain their original SLA start time for compensation calculation purposes.

**11.2 Benefit-of-Doubt Protocol:** When ≥2 of 4 oracles are simultaneously offline during a verified disruption (at least 1 oracle affirms), Continuum may authorize a **capped 50% payout** to active policyholders in the affected zone. This emergency fallback is automatic.

**11.3** Continuum may use alternative disbursement methods, retry queues, or cooling periods (for example, the 6-hour SIM-change cooling period) to reduce payment fraud risk.

**11.4** In extreme infrastructure failure scenarios (e.g., national internet shutdown during civil unrest), Continuum will pre-authorize payouts for affected zones and disburse upon network restoration.

---

## 12. Payout SLA and Payment Handling

**12.1** Valid claims are targeted for settlement within **2 hours** of oracle trigger authorization (measured from Oracle consensus confirmation to confirmed UPI credit). This SLA is monitored in real time via Prometheus metrics.

**12.2 SLA Breach Compensation:** Where Continuum misses the 2-hour payout SLA for a valid approved claim, the Partner will automatically receive a **10% bonus credit** applied to the payout amount, without requiring any Partner action. SLA breach compensation is recorded and applied before disbursement where the delay is identified in advance, or credited to the next payout where delay is identified after disbursement.

**12.3** Payouts are disbursed only to the verified UPI identifier linked to the Partner's account. Continuum does not disburse to third-party accounts or accounts added within 24 hours of a disbursement request.

**12.4** After any change to a Partner's registered UPI number or SIM, a **6-hour cooling period** applies before payout disbursement, and biometric re-confirmation is required.

---

## 13. Data Use, Privacy, and Retention

**13.1** By enrolling, the Partner consents to Continuum processing operational data required for: policy underwriting, parametric trigger validation, fraud prevention, payout execution, and regulatory compliance. This consent is a condition of enrollment.

**13.2** Data collected includes: location telemetry (GPS coordinates, Cell-ID data), device integrity signals (attestation tokens, device fingerprint), claims metadata, and delivery platform activity corroboration data.

**13.3 GPS Data Minimization:** Raw GPS coordinates are retained for a maximum of **60 days** following collection. Post-claim, only aggregated zone-presence records are retained; raw coordinates are deleted. GPS data is range-partitioned by day to enable efficient time-bounded deletion.

**13.4** Partners who choose to disable required location telemetry retain their enrollment status but become ineligible to file claims during any period in which telemetry is disabled.

**13.5 Proximity Data (DPDP Act 2023 Compliance):** Bluetooth and Wi-Fi device proximity data used for population-level fraud detection requires **explicit, separate consent** from the Partner (`proximity_consent` flag). Partners may grant or withdraw proximity consent at any time through the app. Withdrawal does not affect enrollment or claim eligibility. All proximity logs are **automatically purged after 30 days** via a scheduled database job.

**13.6 Aadhaar Data:** Aadhaar numbers are stored only as one-way SHA-256 cryptographic hashes for deduplication purposes. Continuum never stores, logs, or transmits Aadhaar numbers in plaintext. Partners have the right to request confirmation of the data processing methodology.

**13.7 Data Subject Rights:** In accordance with the Digital Personal Data Protection Act 2023, Partners may:
- Request information about what personal data Continuum holds about them
- Request correction of inaccurate personal data
- Request deletion of personal data (subject to legal retention obligations)
- Withdraw proximity consent at any time without penalty

**13.8** Continuum will respond to data rights requests within **30 days** of receipt.

---

## 14. Appeals and Dispute Resolution

**14.1** Partners may appeal a claim denial through the in-app portal within **14 days** of the denial notification.

**14.2 Fast-Track Internal Review:** Continuum will complete a fast-track internal review of contested claim denials within **48 hours** of receiving a valid appeal.

**14.3 Escalated Disputes:** If internal review does not resolve the dispute to the Partner's satisfaction, the Partner may escalate to **third-party arbitration** through a SEBI-approved arbitral body. Arbitration shall be conducted in accordance with the Arbitration and Conciliation Act 1996.

**14.4** Mandatory consumer rights under the Consumer Protection Act 2019 and all other applicable Indian consumer protection legislation remain fully unaffected by any contractual arbitration clause.

**14.5** Nothing in these Terms limits a Partner's right to approach the appropriate consumer court or regulatory authority.

---

## 15. Regulatory and Solvency Safeguards

**15.1** Continuum maintains a minimum **90-day payout reserve** in escrow at all times, held exclusively in RBI-approved low-risk liquid instruments (government Treasury bills, RBI-approved money market funds). No equity exposure is permitted on reserve capital.

**15.2** Continuum maintains a double-entry financial ledger with serialized transaction controls to prevent concurrent reserve overdraw.

**15.3** Reinsurance treaties are maintained to backstop catastrophic correlated events affecting more than 1,000 simultaneous policyholders.

**15.4** Continuum may modify product availability by jurisdiction, suspend enrollment, modify trigger parameters, or cap new policy exposure where required for regulatory compliance or capital protection. Material changes will be communicated with at least **14 days advance notice** where operationally feasible.

**15.5** Zone-level loss ratios are monitored weekly. A zone with a 4-week rolling loss ratio exceeding 80% triggers automatic premium recalibration. A 13-week rolling loss ratio exceeding 100% triggers exposure controls and mandatory actuarial review.

---

## 16. Suspension and Termination

**16.1** Continuum may suspend or terminate a policy immediately for:
- Confirmed or reasonably suspected fraud, collusion, or abuse
- Material breach of these Terms
- Non-compliance with applicable law
- Repeated pattern of claim behavior inconsistent with genuine disruption

**16.2** On termination for cause:
- Pending claims are denied
- Unpaid benefits are forfeited to the extent permitted by applicable law
- Outstanding refund obligations (for prepaid premiums for future cycles not yet served) will be honored

**16.3** Partners terminated for cause may be permanently barred from re-enrollment and may be reported to relevant authorities.

---

## 17. Liability Limits

**17.1** Continuum's **total liability** for any single claim event is strictly limited to the applicable Policy Benefit cap for the Partner's enrolled Tier, as specified in Section 8.2.

**17.2** To the maximum extent permitted by applicable Indian law, Continuum is **not liable** for:
- indirect, incidental, special, or consequential losses of any kind
- loss of profit beyond the stated Policy Benefit
- loss of business opportunities or commercial relationships
- reputational harm

**17.3** These liability limits do not apply to Continuum's obligations under mandatory consumer protection legislation, which are not contractually modifiable.

---

## 18. Amendments and Notices

**18.1** Continuum may update these Terms by publishing a revised version with a new effective date.

**18.2** For **material changes** (changes to coverage scope, exclusions, pricing methodology, or dispute resolution), Continuum will provide at least **14 days advance notice** through at least one of: in-app notification, push notification, SMS, or email.

**18.3** Continued use of the Continuum platform — including continuation of an active policy or submission of a claim — after the effective date of revised Terms constitutes acceptance of those Terms.

**18.4** Continuum will maintain a version history of Terms changes accessible through the app.

---

## 19. Governing Law and Jurisdiction

**19.1** These Terms are governed by and construed in accordance with the **laws of India**.

**19.2** All mandatory local consumer protections under Indian law apply and are not displaced by these Terms.

**19.3** Jurisdiction and arbitration venue, where applicable, shall be the city specified in the Partner's policy schedule. In the absence of such specification, jurisdiction shall be Bengaluru, Karnataka, India.

---

## Appendix A — Contract Design Controls Mapped from Adversarial Risk Analysis

The following controls are implemented in the Continuum platform and are referenced in these Terms. This appendix is explanatory and does not create additional binding obligations.

| Control | Relevant Term Section | Implementation |
|---------|----------------------|----------------|
| Event-type-weighted multi-oracle consensus | Section 6.2 | `oracle_engine/engine.py` — `ORACLE_SETS` map |
| 15-minute oracle staleness TTL | Section 6.3 | `apply_staleness_rule()` |
| Multi-signal location corroboration | Section 7.2 | `claims_scoring/src/checks/spatial.rs` |
| 45-minute pre-trigger soak period | Section 7.3 | `checks/spatial.rs` — soak period check |
| Platform order hard veto | Section 7.4 | `platform_activity_veto` flag in scoring pipeline |
| Aadhaar one-way hash uniqueness | Section 3.5 | DB: `UNIQUE` partial index on `aadhaar_hash` |
| 1:1 device fingerprint binding | Section 3.3 | DB: `UNIQUE` partial index on `device_fingerprint` |
| Biometric liveness on claim | Section 3.4 | iProov API integration |
| DPDP 30-day proximity log purge | Section 13.5 | pg_cron scheduled DELETE job |
| Double-entry ledger reserve management | Section 15.2 | CockroachDB `ledger_accounts` + `SELECT FOR UPDATE` |
| Forecast-driven enrollment lockout | Section 6.6 | `zone_enrollment_locks` table; HTTP 423 on `POST /policies` |
| 72-hour activation delay | Section 4.1 | `claim_eligible_from` = `enrolled_at + 72h` |
| 5-day tier-upgrade wait | Section 4.2 | Upgrade timestamp check in claims pipeline |
| Cancellation cycle lock | Section 4.3 | Cancellation effective date = cycle end |
| Reinsurance treaty >1,000 policies | Section 15.3 | Triggered via `payouts` count threshold |
| Model provenance verification | Internal | SHA-256 hash check on `isolation_forest.joblib` at startup |
| Prometheus SLA alerting | Section 12.2 | `payout_sla_breach_total` counter; `PayoutSLABreach` alert |
| Reserve floor monitoring | Section 15.1 | `reserve_balance_inr` gauge; `ReserveLow` alert at <₹100K |

---

*Continuum Terms and Conditions v2.0 — Effective 2026-04-17*  
*This document must be reviewed by qualified insurance law counsel before production deployment.*
