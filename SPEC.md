# SPEC — Continuum

## §G Goal

Parametric income-protection insurance for gig delivery workers. Oracle consensus detects disruption → claim scored → fraud checked by AI agents → payout to UPI wallet within 5 minutes, zero human touch.

---

## §C Constraints

- C1. Sub-5-minute payout SLA from claim submission to wallet credit.
- C2. IRDAI parametric insurance guidelines compliance.
- C3. DPDP Act §6 consent and §17 proximity log 30-day retention cap.
- C4. Reserve floor: always > 90 days of daily-average payout runway.
- C5. No payout without oracle-authorized parametric trigger (≥3-of-4 oracle consensus).
- C6. No duplicate payout per worker per 7-day billing cycle.
- C7. Identity uniqueness: aadhaar_hash + device_fingerprint unique per worker.
- C8. Kill switches: `PAYOUT_AUTOMATION_ENABLED` and `PAYOUT_KILL_SWITCH` disable payouts.
- C9. Enrollment blocked when zone_enrollment_lock active (forecast-driven adverse selection).
- C10. Platform: Node.js (core_backend), Python (fastapi_gateway, crew_ai, oracle_engine, risk_profiler, rag_orchestrator, rasa_assistant, web_intelligence, actuarial_lab, isolation_forest_sidecar), Rust (claims_scoring), Go (kg_cache), Dart (Flutter app).

---

## §I External Surfaces

| id | surface | protocol | location |
|----|---------|----------|----------|
| I.api | core_backend REST | HTTP/JSON | :3000 |
| I.gateway | fastapi_gateway | HTTP/JSON | :8000 |
| I.kafka | Apache Kafka broker | Kafka protocol | :9092 |
| I.pg | PostgreSQL + PostGIS + TimescaleDB | asyncpg/pg | :5432 |
| I.crdb | CockroachDB ledger | asyncpg/pg | :26257 |
| I.mongo | MongoDB vector store | motor | :27017 |
| I.redis | Redis session/rate-limit | ioredis | :6379 |
| I.imd | India Met Dept API | HTTPS+pinned TLS | external |
| I.accuweather | AccuWeather API | HTTPS+pinned TLS | external |
| I.nasa_gpm | NASA GPM satellite | HTTPS+pinned TLS | external |
| I.cpcb | CPCB CAAQMS AQI | HTTPS+pinned TLS | external |
| I.downdetector | Downdetector scrape | HTTPS | external |
| I.payu | PayU eNACH mandate/payout | HTTPS | external |
| I.fcm | Firebase Cloud Messaging | HTTPS | external |
| I.play_integrity | Google Play Integrity API | HTTPS | external |
| I.ifsidecar | isolation_forest Unix socket | JSON-RPC 2.0 | /tmp/isolation_forest.sock |
| I.kgcache | kg_cache HTTP | HTTP/JSON | :8004 |
| I.flutter | Flutter mobile app | REST→I.api | N/A |

---

## §V Invariants

**Oracle Engine**

| id | invariant |
|----|-----------|
| V1 | `authorized = (fresh_affirm_count >= 3)` — oracle trigger requires ≥3-of-4 fresh affirm votes. |
| V2 | Data older than 15 minutes treated as abstain, NOT affirm. |
| V3 | TLS-nullified votes count as offline, NOT affirm. |
| V4 | Benefit of Doubt: if `offline_count >= 2 AND 1 <= affirm_count < 3` → `authorized=True`, `payout_cap=0.5`. |
| V5 | Without BoD and without ≥3 affirms: `authorized=False`, `payout_cap=1.0` unused. |
| V6 | Kafka publish on authorization: topics `oracle_trigger_authorized` + `payout_authorized` both receive event. |
| V7 | Polling jitter: interval lands in `[BASE_INTERVAL - 480s, BASE_INTERVAL + 480s]` (±8 min). |
| V8 | DB poll_schedule failure: falls back to hardcoded `FALLBACK_SCHEDULES` without crash. |

**Claims Scoring (Rust)**

| id | invariant |
|----|-----------|
| V9 | Play Integrity attestation failure → status `DeviceNotAttested`, pipeline halts. |
| V10 | Convergence Freeze: `claim_count_5min >= 50` for zone → `convergence_freeze=True`, FraudQueue override. |
| V11 | Device cluster: `cluster_size >= 5` co-located devices in 7 days → `device_cluster_flagged=True`. |
| V12 | Isolation Forest fraud_score = `clip(1 - (raw + 0.5), 0.0, 1.0)`. Feature vector must be exactly 6 dimensions. |
| V13 | Composite score routes: fraud_score below threshold → `AutoApproved`; at or above → `FraudQueue`. |

**Crew AI / Fraud Detection**

| id | invariant |
|----|-----------|
| V14 | Kafka consumer dispatches only messages with `status == "FRAUD_QUEUE"`; others silently dropped. |
| V15 | Assignment SLA: `_handle_message` scheduled within 60 seconds of Kafka message receipt. |
| V16 | Full pipeline SLA: 300 seconds; `asyncio.TimeoutError` → conservative escalate report returned. |
| V17 | `confidence > 0.85` → `ESCALATED_TO_HUMAN` logged to `agent_audit_log`. |
| V18 | `_validate_payout_decision`: output must CONTAIN one of `{APPROVED, REJECTED, ESCALATED_TO_HUMAN}` as a substring (simple `in` check). Substring match means "NOT APPROVED" and "MAYBE_APPROVED" both pass — deliberate LLM output leniency, not word-boundary matching. |
| V19 | `FraudAnalysisReport.confidence` in `[0.0, 1.0]`; values outside raise `ValidationError`. |

**Isolation Forest Sidecar**

| id | invariant |
|----|-----------|
| V20 | `normalize_score(-0.5)` == 1.0; `normalize_score(0.5)` == 0.0; output always in `[0.0, 1.0]`. |
| V21 | `handle_request`: wrong method → error -32601; missing `features` → -32602; wrong dim → -32602; bad JSON → -32700; jsonrpc != "2.0" → -32600. |
| V22 | Model hash mismatch with `model_card.json` → `RuntimeError` at startup; sidecar exits. |
| V23 | Feature dimension must be exactly 6; any other length → JSON-RPC error -32602. |

**Actuarial Lab / CI Gate**

| id | invariant |
|----|-----------|
| V24 | CI gate fails when any rolling 13-week loss ratio exceeds 100% (`loss_ratio > 1.0`). |
| V25 | CI gate fails when `portfolio_bcr < 1.05` (BCR floor). |
| V26 | CI gate FAILS (hard) when any zone Brier score > 0.2 — appended to `failures` list despite "WARNING:" prefix in message. |
| V27 | Stress test fails when `reserve_depletion_days < 90` for any scenario. |
| V28 | `_brier_score([], [])` == 0.0 (empty list guard). |

**Core Backend — Policies**

| id | invariant |
|----|-----------|
| V29 | Policy created with `claim_eligible_from = NOW() + 72h`; claims before that timestamp rejected. |
| V30 | Tier upgrade resets `claim_eligible_from = NOW() + 5 days`. |
| V31 | Policy creation blocked when `zone_enrollment_locks` has active row for zone. → HTTP 409. |
| V32 | Identity uniqueness: duplicate aadhaar_hash OR device_fingerprint → HTTP 409. |
| V33 | Play Integrity verification called at policy creation; failure → HTTP 403. |

**Core Backend — Payouts**

| id | invariant |
|----|-----------|
| V34 | Duplicate payout: second `payout_authorized` event for same worker+claim within 7 days → dropped (OCC). |
| V35 | `PAYOUT_AUTOMATION_ENABLED=false` → event dropped, no ledger debit. |
| V36 | `PAYOUT_KILL_SWITCH=true` → event dropped regardless of other flags. |
| V37 | Reserve debit uses `SELECT FOR UPDATE` (serialized); zero-balance reserve → payout fails. |

**Core Backend — Auth**

| id | invariant |
|----|-----------|
| V38 | JWT older than 86400 seconds (24h from `iat`) → HTTP 401 `invalid_token`. |
| V39 | JWT with role != required role → HTTP 403. |
| V40 | Rate limit: >15 auth attempts in 15 min → HTTP 429. |

**Core Backend — Consent (DPDP)**

| id | invariant |
|----|-----------|
| V41 | Unknown purpose → HTTP 400 `invalid_purpose` with list of invalid values. |
| V42 | Empty purpose list → HTTP 400 `invalid_purpose`. |
| V43 | Revoke non-existent/already-revoked consent → HTTP 404. |

**Core Backend — Mandates**

| id | invariant |
|----|-----------|
| V44 | Missing `policy_id`, `upi_id`, or `max_amount` → HTTP 400 `missing_fields`. |
| V45 | Webhook without `x-payu-signature` header → HTTP 401. |
| V46 | Webhook with wrong HMAC signature → HTTP 403 `invalid_signature`. |

**Core Backend — Reserves**

| id | invariant |
|----|-----------|
| V47 | `GET /reserves/balance` returns `runway_sufficient: false` when runway_days < 90. |
| V48 | `POST /reserves/credit` with `amount <= 0` → HTTP 400. |
| V49 | `POST /reserves/credit` with no `reference_id` → HTTP 400. |

**FastAPI Gateway**

| id | invariant |
|----|-----------|
| V50 | Downstream timeout (`httpx.TimeoutException`) → HTTP 504. |
| V51 | Downstream 5xx → gateway returns same status code. |
| V52 | Missing required request fields → HTTP 422 with per-field `detail`. |

**RASA Assistant**

| id | invariant |
|----|-----------|
| V53 | `intent == "escalate_to_human"` → `escalated=True` regardless of confidence. |
| V54 | `confidence < ESCALATION_THRESHOLD` → `escalated=True`. |
| V55 | `confidence >= ESCALATION_THRESHOLD` on non-escalate intent → `escalated=False`. |

**Web Intelligence**

| id | invariant |
|----|-----------|
| V56 | Exception in one scraper does NOT prevent other scrapers from running. |
| V57 | Malformed RSS/XML entry skipped without crashing the poll cycle. |

**Risk Profiler**

| id | invariant |
|----|-----------|
| V58 | `risk_score` output clipped to `[0.0, 1.0]`. |
| V59 | Premium floor = affordability_anchor (never zero for active zone). |
| V60 | Zone loss ratio > 0.80 applies escalation multiplier: `1 + (zlr - 0.80) * 2.5`. |

**Flutter Frontend — Integration Contracts**

| id | invariant |
|----|-----------|
| V61 | `assists.dart` send button must call `POST /assist/chat {message}` and append reply; `initState` must call `GET /assist/messages` to restore history. Static hardcoded `_messages` list must not exist in production path. |
| V62 | `apply_form.dart` `zone_id` in `POST /claims` payload must come from `GET /workers/:id` response — NOT hardcoded `'default'`. Worker profile must be fetched (or cached) before submission. |
| V63 | `apply_form.dart` `POST /claims` payload must include `claim_description` from text field. `device_attestation_token` field must be removed — Play Integrity runs in Rust scoring layer, not Flutter. |
| V64 | `GET /claims/:id/status` returns `{ claim_id, status, fraud_score, decided_at, verification_message }` — NO `stages` field. `status_tracker.dart` must derive `stages` list client-side from `status` string and timestamps. Progress stepper is blank when `stages` is not built. |
| V65 | `GET /workers/:id` returns `claims_approved_count` and `total_protected_amount` at TOP LEVEL. `profile.dart` must NOT read these from a nested `_workerData['stats']` map (that key does not exist in the response). |
| V66 | `GET /workers/:id` returns claim history under key `recent_claims`. `profile.dart` reads `_workerData['recent_history']` — key mismatch means history section always shows empty. Must use `recent_claims`. |
| V67 | `GET /policies/content` route does not exist in `policies.js`. Both `policy.dart` and `payments.dart` call this via `ApiService.getPolicyContent()`. Route must be added returning `{ hero: { badge, title, subtitle }, sections: [{ title, body, icon_key }] }`. |
| V68 | `CORS_ALLOWED_ORIGINS` must be non-empty in `.env` before any browser or Android emulator (10.0.2.2) call reaches core backend. Empty env var → empty allowed list → all cross-origin requests blocked. |
| V69 | `dashboard.dart` reads `_profile['next_renewal']` which `GET /workers/:id` does not return; falls back to literal `'upcoming cycle'` — not a crash but stale UI. Field must be added to worker query or fetched from policy endpoint. |
| V70 | `payments.dart` reads `_profile['weekly_premium']` which `GET /workers/:id` does not return; hardcodes fallback `57`. Real premium comes from `POST /onboard` (risk profiler) `weekly_premium` field. |
| V71 | `lib/screens/new/` is the ONLY screen folder imported by `lib/main.dart`. `lib/screens/` (without `/new`) is dead code never executed. All Flutter integration fixes must target `lib/screens/new/` exclusively — fixes to `lib/screens/` have zero runtime effect. |
| V72 | `GET /workers/:id` returns `registered_at` (ISO timestamp string). Key `member_since` does NOT exist in the response. Any screen reading `_workerData['member_since']` always receives `null` → shows fallback 'N/A' silently. Must use `registered_at`. |
| V73 | `GET /workers/:id` does NOT return `weekly_order_count`, `weekly_earnings`, `completion_rate`, `current_location`, or `location_history`. Any screen referencing these keys receives `null`/empty silently. These fields must be removed from the UI or sourced from a real endpoint. |

---

## §T Tasks

| id | status | description | cites |
|----|--------|-------------|-------|
| T1 | `x` | Create `services/isolation_forest_sidecar/tests/test_sidecar.py` — normalize_score math, JSON-RPC error codes, model hash check | V20,V21,V22,V23 |
| T2 | `x` | Create `services/actuarial_lab/tests/test_ci_gate.py` — CI gate pass/fail scenarios | V24,V25,V26,V27 |
| T3 | `x` | Create `services/actuarial_lab/tests/test_backtest.py` — _brier_score, _calibration_buckets pure functions | V28 |
| T4 | `x` | Create `services/actuarial_lab/tests/test_stress.py` — 3 scenario pass/fail, depletion math | V27 |
| T5 | `x` | Create `services/core_backend/tests/test_mandates.test.js` — mandate CRUD + webhook HMAC | V44,V45,V46 |
| T6 | `x` | Create `services/core_backend/tests/test_consent.test.js` — grant, revoke, invalid purpose, DPDP | V41,V42,V43 |
| T7 | `x` | Create `services/core_backend/tests/test_reserves.test.js` — balance, ledger, credit route | V47,V48,V49 |
| T8 | `x` | Create `services/core_backend/tests/test_workers.test.js` — FCM token update | I.api |
| T9 | `x` | Extend `services/crew_ai/tests/test_crew_ai.py` — tool mocks, Kafka consumer routing, 300s timeout, guardrail retry | V14,V15,V16,V17,V18 |
| T10 | `x` | Extend `services/oracle_engine/tests/test_oracle_engine.py` — Kafka publish schema, jitter range, DB fallback | V6,V7,V8 |
| T11 | `x` | Extend `services/fastapi_gateway/tests/test_gateway.py` — timeout→504, 5xx proxy, claims endpoint 422 | V50,V51,V52 |
| T12 | `x` | Extend `services/rasa_assistant/tests/test_rasa.py` — escalation threshold boundary | V53,V54,V55 |
| T13 | `x` | Extend `services/web_intelligence/tests/test_web_intel.py` — scraper fault isolation, malformed XML | V56,V57 |
| T14 | `x` | Create `tests/integration/claimLifecycle.test.js` — full lifecycle against real DB | V29,V34 |
| T15 | `x` | Create `tests/integration/oracleEnrollmentLock.test.js` — adverse selection lock → policy rejection | V31,C9 |
| T16 | `x` | Create `tests/integration/premiumCollection.test.js` — mandate debit + ledger entries | I.crdb |
| T17 | `x` | Create `tests/integration/reserveFloor.test.js` — insufficient reserve → payout blocked | V37,V47 |
| T18 | `x` | Extend `tests/contracts/kafkaSchemas.test.js` — claim_decision, payout_authorized, adverse_selection_lock schemas | I.kafka |
| T19 | `x` | Add pytest-cov `.coveragerc` to each Python service; fail_under=75 | C10 |
| T20 | `x` | Add Jest coverage config (collectCoverage, threshold lines:80) to core_backend | C10 |
| T21 | `x` | Fix `tests/test_payu.test.js` — mock `payoutGateway` adapter instead of `node-fetch` in `processPayoutDisbursement` suite | I.payu |
| T22 | `x` | Fix `tests/test_bullmq.test.js` — freeze clock with `jest.useFakeTimers()` in "exactly 24h" boundary test | — |
| T23 | `x` | Add `actuarial_lab` to `python-tests` matrix in `.github/workflows/ci.yml` | V24,V25,V26,V27,V28 |
| T24 | `x` | Fix `src/routes/policies.js:80` — HTTP 423 → 409 for `enrollment_locked`; add §B2 | V31 |
| T25 | `x` | Create `tests/test_payoutAuthorizedHandler.test.js` — kill switch, automation-disabled, zone pause, reserve floor, daily cap, happy path | V35,V36,V37,C8 |
| T26 | `x` | Wire `lib/screens/assists.dart` — call `getAssistMessages()` in `initState`, wire send button to `sendAssistMessage()`, append bot reply optimistically, remove hardcoded `_messages` list | V61,I.api |
| T27 | `x` | Fix `lib/screens/apply_form.dart` — fetch worker profile before submit, use `profile['zone_id']`, add `claim_description` to payload, remove `device_attestation_token` field | V62,V63,I.api |
| T28 | `x` | Fix `lib/screens/status_tracker.dart` — derive `stages` list client-side from `status`+`decided_at`; fix polling case match (`'in review'` variant) | V64,I.api |
| T29 | `x` | Fix `lib/screens/profile.dart` — read `claims_approved_count` + `total_protected_amount` from top-level; read history from `recent_claims` key | V65,V66,I.api |
| T30 | `x` | Add `GET /policies/content` route to `services/core_backend/src/routes/policies.js` returning `{ hero: { badge, title, subtitle }, sections: [{ title, body, icon_key }] }` | V67,I.api |
| T31 | `x` | Add `clearAssistHistory()` to `lib/services/api_service.dart` calling `DELETE /assist/messages` | V61,I.api |
| T32 | `x` | Fix `lib/screens/payments.dart` — source `weekly_premium` from risk profiler `POST /onboard` result or add field to `GET /workers/:id` via policy join, remove hardcoded `57` | V70,I.api,I.gateway |
| T33 | `x` | Fix `lib/screens/dashboard.dart` — source `next_renewal` from policy endpoint or add to `GET /workers/:id` via policy join | V69,I.api |
| T34 | `x` | Update `.env.example` — set `CORS_ALLOWED_ORIGINS=http://10.0.2.2:3000,http://localhost:3000,http://localhost:5000` for Android emulator + web dev | V68,I.api |
| T35 | `x` | Fix `lib/screens/new/profile.dart` — read `claims_approved_count` + `total_protected_amount` from top-level (not nested `_workerData['stats']`); use key `recent_claims` (not `recent_history`); use `registered_at` (not `member_since`); remove phantom fields `weekly_order_count`, `weekly_earnings`, `completion_rate`, `current_location`, `location_history` | V65,V66,V72,V73,I.api |
| T36 | `x` | Fix `lib/screens/new/apply_form.dart` — fetch worker profile before submit, read real `zone_id` from profile response, remove hardcoded `'default'`; remove `device_attestation_token` field; remove `gps_coordinates: [0.0, 0.0]` field | V62,V63,I.api |
| T37 | `x` | Fix `lib/screens/new/payments.dart` — replace hardcoded `57` fallback with `(_profile?['weekly_premium'] as num?)?.toStringAsFixed(0) ?? '—'` (3 occurrences: `_buildPlanData`, dialog content, Pay Now button label); source `nextBillingDate` from `_profile?['next_renewal']` with date formatting | V69,V70,I.api |
| T38 | `x` | Fix `lib/screens/new/status_tracker.dart` — replace raw key literal `'claim_description'` label text with human-readable `'Description'` | V64,I.api |

---

## §B Bug Log

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-04-25 | V26 spec said Brier>0.2 is warning-only; code adds it to `failures` → hard CI gate failure. Docstring omits this threshold. | Updated V26 to reflect hard failure. |
| B2 | 2026-04-25 | V31 spec says HTTP 409 for `enrollment_locked`; `policies.js:80` returned HTTP 423. | Changed status code to 409. |
| B3 | 2026-04-25 | T26–T31 fixes targeted `lib/screens/` (legacy); `lib/main.dart` imports only `lib/screens/new/`. All six fixes had zero runtime effect. Root cause: no invariant stated which folder was active. | Added V71. New tasks T35–T38 target the correct folder. |
