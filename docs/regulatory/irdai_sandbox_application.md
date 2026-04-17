# IRDAI Regulatory Sandbox Application

**Product:** Continuum — Parametric Micro-Insurance for Gig Workers  
**Applicant:** [Company Legal Entity Name]  
**Date:** [Filing Date]  
**Sandbox Cohort:** [IRDAI Sandbox Cohort Number]

## 1. Executive Summary

Continuum is a technology-driven parametric micro-insurance product designed for India's gig economy workforce. It provides automated, trigger-based payouts for weather events (heavy rainfall, cyclones), air quality degradation, and platform outages that prevent gig workers from earning.

**Key innovation:** Fully automated oracle-consensus payout engine that eliminates claims processing delays, enabling payouts within 2 hours of a qualifying trigger event.

## 2. Product Structure

| Attribute | Value |
|-----------|-------|
| Product type | Parametric (index-based) micro-insurance |
| Target segment | Gig economy workers (delivery, ride-hailing) |
| Coverage triggers | Heavy rainfall, cyclone, AQI exceedance, platform outage |
| Coverage cap | ₹500 – ₹5,000 per event (tier-dependent) |
| Premium model | Weekly debit via UPI mandate |
| Payout mechanism | Automated UPI credit within 2 hours of trigger |
| Geographic scope | Mumbai (pilot), expandable to Tier-1 cities |
| Policy duration | Weekly rolling enrollment |

## 3. Technology Architecture

### Oracle Consensus Engine
- Minimum 3 independent data sources per trigger type
- Byzantine fault-tolerant consensus with weighted voting
- Data sources: IMD, AccuWeather, NASA GPM (weather); CPCB (AQI); Downdetector, synthetic ping (platform outage)

### Payout Pipeline
- Kafka-based event streaming from oracle engine to payout processor
- Double-entry ledger for all financial transactions
- Reserve floor enforcement prevents payouts below ₹100,000 threshold
- Kill switches (global and per-zone) for operational control

### Data Protection (DPDP Act 2023 Compliance)
- Explicit consent collection with granular purpose tracking
- PII encryption at rest using envelope encryption (AES-256-GCM)
- GPS data retention limited to 60 days
- Breach notification pipeline meeting 72-hour regulatory requirement

## 4. Actuarial Basis

- Historical backtest against 24+ months of weather data
- Multi-scenario stress testing (3x rainfall, consecutive cyclones, compound events)
- Combined loss ratio target: < 80% at BCR > 1.05
- CI gate enforces actuarial thresholds before deployment

## 5. Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Adverse selection | Enrollment locks activated during forecast severe weather |
| Fraud | Multi-factor identity (Aadhaar + device + liveness), isolation forest scoring |
| Basis risk | Adjacency factor modulation, zone-level granularity |
| Catastrophic loss | Reserve floor, portfolio daily cap, reinsurance (pending) |
| Technology failure | Circuit breakers, DLQ for failed messages, comprehensive monitoring |

## 6. Sandbox Objectives

1. Validate parametric trigger accuracy against actual worker impact
2. Measure payout latency SLA compliance (target: 95th percentile < 2 hours)
3. Confirm actuarial model stability under real weather patterns
4. Test adverse selection mitigation effectiveness
5. Validate DPDP Act compliance in production conditions

## 7. Success Metrics

| Metric | Target | Measurement |
|--------|--------|------------|
| Trigger accuracy | > 90% correlation with ground truth | Post-event surveys |
| Payout SLA | p95 < 2 hours | Prometheus metrics |
| Loss ratio | < 80% | Ledger-based calculation |
| Fraud rate | < 2% of payouts | Isolation forest flagging |
| Worker satisfaction | > 4.0/5.0 | In-app feedback |

## 8. Exit Strategy

If sandbox results are unsatisfactory:
1. Honor all outstanding coverage commitments
2. Return unearned premiums pro-rata
3. Provide 30-day notice to enrolled workers
4. Archive all data per DPDP Act retention requirements

## 9. Appendices

- [ ] Appendix A: Actuarial certification (see `docs/regulatory/actuarial_cert_template.md`)
- [ ] Appendix B: Product filing matrix (see `docs/regulatory/product_filing_matrix.md`)
- [ ] Appendix C: Technology architecture diagram
- [ ] Appendix D: Data protection impact assessment
- [ ] Appendix E: Reinsurance term sheet (see `docs/regulatory/reinsurance_skeleton.md`)
