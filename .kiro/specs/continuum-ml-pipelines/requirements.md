# Requirements Document

## Introduction

Continuum is a parametric income protection app for gig delivery workers (Swiggy/Zomato partners). The Flutter frontend currently operates on mock data only. This feature spec covers the full backend and ML pipeline implementation required to make Continuum production-ready, including:

- Risk Profile Engine: ML-driven dynamic premium pricing per worker per week
- Claims Detection & Fraud Scoring Pipeline: Isolation Forest anomaly detection with auto-approve/fraud-queue routing
- Core Backend Services: Express.js REST API, policy management, user services
- Real-Time Data Infrastructure: Apache Kafka streaming, BullMQ task queue
- Financial Ledger: CockroachDB distributed SQL
- Intelligence Layer: RAG pipeline (MongoDB Atlas + BGE-Large + LangChain/LlamaIndex), ScrapeGraph.AI web intelligence, Go knowledge graph cache
- AI Inference and Agents: Gemini/Groq/GPT-4o, Crew AI multi-agent orchestration
- Conversational AI: RASA assistant, IndicConformer multilingual NLP
- Payments and Notifications: PayU UPI payouts, Firebase Cloud Messaging
- Trust Architecture: GPS spoofing prevention, multi-oracle consensus engine, device attestation
- Observability: Prometheus monitoring, Power BI admin dashboard

---

## Glossary

- **Worker**: A gig delivery partner registered on Swiggy or Zomato who holds an active Continuum policy
- **Policy**: A weekly income protection contract binding a Worker to a coverage tier and premium
- **Claim**: A Worker-submitted request for payout following a qualifying disruption event
- **Risk_Score**: A floating-point value in [0.0, 1.0] produced by the Gradient Boosting Model representing a Worker's weekly risk level
- **Fraud_Score**: A floating-point value in [0.0, 1.0] produced by the Isolation Forest model representing the anomaly likelihood of a Claim
- **FastAPI_Gateway**: The Python FastAPI service that receives ML pipeline requests from the Flutter app and routes them to downstream services
- **Risk_Profiler**: The Python microservice that orchestrates feature building and risk scoring for premium calculation
- **Feature_Builder**: The component within Risk_Profiler that collects and assembles feature vectors from TimescaleDB, Weather_API, and PostgreSQL
- **Gradient_Boosting_Model**: The scikit-learn/XGBoost model that produces Risk_Score from a feature vector
- **Claims_Scoring_Service**: The Rust-based microservice that orchestrates fraud detection for submitted claims
- **Isolation_Forest_Model**: The scikit-learn anomaly detection model that produces Fraud_Score
- **PostGIS**: The PostgreSQL spatial extension used for zone-level geographic verification
- **TimescaleDB**: The time-series PostgreSQL extension storing historical weather event data
- **Weather_API**: The external IMD/AccuWeather/NASA GPM API integration providing current weather conditions
- **Core_Backend**: The Express.js Node.js service providing the primary REST API for policy, user, and payout management
- **Kafka_Broker**: The Apache Kafka cluster handling real-time event streaming between services
- **BullMQ_Worker**: The BullMQ-based background job processor for payout retries and notification dispatch
- **CockroachDB**: The distributed SQL database serving as the financial ledger for premiums and payouts
- **Vector_Store**: The MongoDB Atlas collection with vector index used for RAG retrieval
- **RAG_Orchestrator**: The LangChain/LlamaIndex pipeline that embeds queries, retrieves context, and generates responses
- **Knowledge_Graph_Cache**: The Go service that caches location-aware disruption knowledge built from scraped data
- **Web_Intelligence_Service**: The ScrapeGraph.AI-powered service that scrapes Downdetector, IMD advisories, and municipal feeds
- **Oracle_Consensus_Engine**: The service that aggregates votes from IMD, AccuWeather, NASA GPM, and ground sensors to authorize parametric triggers
- **Crew_AI_Orchestrator**: The multi-agent pipeline that delegates autonomous claim validation steps
- **RASA_Assistant**: The conversational AI bot embedded in the Flutter app for partner support
- **IndicConformer**: The AI4Bharat multilingual NLP model for regional Indian language processing
- **PayU_Gateway**: The PayU payment integration handling UPI payout disbursement
- **FCM**: Firebase Cloud Messaging service for push notifications
- **Prometheus**: The metrics collection and alerting service
- **Device_Attestation**: The Play Integrity API / SafetyNet hardware attestation check
- **Fraud_Queue**: The manual review queue for claims with Fraud_Score below 0.7
- **Zone**: A geographic polygon representing a delivery area, stored in PostGIS
- **Tier**: A coverage level (Silver / Gold / Platinum) mapped to weekly premium and payout cap

---

## Requirements

### Requirement 1: Worker Onboarding and Risk Profile Initiation

**User Story:** As a delivery partner, I want my risk profile to be calculated when I onboard, so that I receive a dynamically priced weekly premium tailored to my zone and activity level.

#### Acceptance Criteria

1. WHEN a Worker completes onboarding in the Flutter app, THE FastAPI_Gateway SHALL accept a JSON payload containing worker_id, zone_id, platform, tier, gps_coordinates, and activity_history.
2. THE FastAPI_Gateway SHALL validate that all required onboarding fields are present and correctly typed before forwarding to Risk_Profiler.
3. IF the onboarding payload is missing required fields, THEN THE FastAPI_Gateway SHALL return HTTP 422 with a structured error body identifying each missing field.
4. WHEN a valid onboarding payload is received, THE Risk_Profiler SHALL invoke Feature_Builder to assemble the feature vector within 3 seconds.
5. THE Feature_Builder SHALL query TimescaleDB for the 30-day historical weather event frequency for the Worker's zone_id.
6. THE Feature_Builder SHALL query Weather_API for current weather conditions (rainfall mm/hr, wind speed km/hr, temperature degrees C) for the Worker's gps_coordinates.
7. THE Feature_Builder SHALL query PostgreSQL for the Worker's GPS activity history and profile metadata (platform, tier, active_days_last_30).
8. WHEN all feature sources have responded, THE Feature_Builder SHALL assemble a feature vector and return it to Risk_Profiler within 500ms of the last source response.
9. IF any feature source is unavailable, THEN THE Feature_Builder SHALL substitute the unavailable feature with the zone-level median value and log the substitution.
10. WHEN the feature vector is assembled, THE Gradient_Boosting_Model SHALL compute a Risk_Score in [0.0, 1.0] and return it to Risk_Profiler.
11. THE Risk_Profiler SHALL persist the Risk_Score, feature vector, and timestamp to PostgreSQL for audit and backtesting.
12. WHEN the Risk_Score is computed, THE FastAPI_Gateway SHALL return the Risk_Score and computed weekly premium to the Flutter app in the HTTP response.
13. THE Flutter app SHALL display the Risk_Score and weekly premium on the Worker's dashboard within 500ms of receiving the API response.

---

### Requirement 2: Dynamic Weekly Premium Recalculation

**User Story:** As a delivery partner, I want my premium recalculated every week based on current conditions, so that I pay a fair price that reflects my actual risk environment.

#### Acceptance Criteria

1. THE BullMQ_Worker SHALL schedule a weekly premium recalculation job for every active Policy at the start of each 7-day billing cycle.
2. WHEN the weekly recalculation job fires, THE Risk_Profiler SHALL re-run the full feature assembly and Gradient_Boosting_Model scoring pipeline for the Worker.
3. THE Risk_Profiler SHALL apply the actuarial formula: FinalPremium = max(AffordabilityAnchor, TechnicalPremium) where TechnicalPremium incorporates ExpectedLoss, ExpenseLoad, FraudLoad, ReinsuranceLoad, and RiskMargin.
4. WHEN a zone's 4-week rolling loss ratio exceeds 80%, THE Risk_Profiler SHALL apply a mandatory premium escalation multiplier for all Workers in that zone.
5. THE Core_Backend SHALL notify the Worker via FCM at least 7 days before a premium change takes effect.
6. THE CockroachDB SHALL record each premium version with effective_date, zone_id, tier, risk_score, and computed_premium for audit trail.
7. FOR ALL valid Risk_Score inputs, THE Gradient_Boosting_Model SHALL produce a deterministic Risk_Score such that identical feature vectors always yield identical scores (model determinism property).

---

### Requirement 3: Claims Submission and Fraud Scoring Pipeline

**User Story:** As a delivery partner, I want to submit a claim after a disruption and receive an instant decision, so that I am not left waiting days for a payout.

#### Acceptance Criteria

1. WHEN a Worker submits a claim via the Flutter app, THE FastAPI_Gateway SHALL accept a JSON payload containing claim_id, worker_id, event_type, event_timestamp, gps_coordinates, zone_id, and device_attestation_token.
2. THE FastAPI_Gateway SHALL forward the validated claim payload to Claims_Scoring_Service within 200ms.
3. IF the device_attestation_token fails Play Integrity API verification, THEN THE Claims_Scoring_Service SHALL reject the claim with status "DEVICE_NOT_ATTESTED" and Fraud_Score of 0.0.
4. WHEN a claim is received, THE Claims_Scoring_Service SHALL perform three parallel checks: PostGIS spatial zone verification, PostgreSQL duplicate/frequency check, and Isolation_Forest_Model anomaly scoring.
5. THE PostGIS spatial zone verification SHALL confirm that the Worker's gps_coordinates fall within the claimed zone_id polygon at the event_timestamp.
6. IF the Worker's gps_coordinates do not fall within the zone_id polygon, THEN THE Claims_Scoring_Service SHALL assign a zone_mismatch penalty reducing the Fraud_Score by 0.3.
7. THE PostgreSQL duplicate check SHALL verify that the Worker has not submitted more than 3 approved claims in the prior 90-day rolling window.
8. IF the Worker has exceeded 3 approved claims in 90 days, THEN THE Claims_Scoring_Service SHALL route the claim to Fraud_Queue regardless of Isolation_Forest_Model score.
9. THE Isolation_Forest_Model SHALL compute a Fraud_Score in [0.0, 1.0] from the claim feature vector (event_type, zone_id, hour_of_day, day_of_week, claim_velocity_7d, zone_claim_density_1h).
10. WHEN all three checks are complete, THE Claims_Scoring_Service SHALL compute a composite Fraud_Score as the weighted combination of spatial, frequency, and anomaly sub-scores.
11. IF the composite Fraud_Score is greater than or equal to 0.7, THEN THE Claims_Scoring_Service SHALL set claim status to "AUTO_APPROVED" and publish a payout event to Kafka_Broker.
12. IF the composite Fraud_Score is less than 0.7, THEN THE Claims_Scoring_Service SHALL set claim status to "FRAUD_QUEUE" and publish a review event to Kafka_Broker.
13. THE Claims_Scoring_Service SHALL complete the full scoring pipeline and return a decision to FastAPI_Gateway within 2 seconds of receiving the claim.
14. THE FastAPI_Gateway SHALL return the claim decision (status, Fraud_Score, estimated_payout) to the Flutter app.
15. THE Flutter app SHALL display the claim status and decision on the Claims screen within 500ms of receiving the API response.

---

### Requirement 4: GPS Spoofing Prevention and Device Attestation

**User Story:** As an insurer, I want every claim to be verified against multiple location signals, so that GPS spoofing attacks cannot fraudulently trigger payouts.

#### Acceptance Criteria

1. THE Device_Attestation SHALL verify the Play Integrity API certificate for every claim submission before any scoring begins.
2. IF a device lacks a valid hardware attestation certificate (emulator or rooted device), THEN THE Claims_Scoring_Service SHALL reject the claim with status "DEVICE_NOT_ATTESTED".
3. THE Claims_Scoring_Service SHALL compare the GPS coordinate against the Cell-ID triangulation coordinate for the same timestamp.
4. IF the divergence between GPS coordinate and Cell-ID triangulation exceeds 2km, THEN THE Claims_Scoring_Service SHALL flag the claim as "LOCATION_MISMATCH" and reduce the Fraud_Score by 0.3.
5. THE Claims_Scoring_Service SHALL verify that the Worker's GPS history shows continuous presence within the zone_id polygon for at least 45 minutes before the event_timestamp (soak period).
6. IF the soak period requirement is not met, THEN THE Claims_Scoring_Service SHALL route the claim to Fraud_Queue.
7. THE Claims_Scoring_Service SHALL cross-reference the Swiggy/Zomato platform API to verify that the Worker completed zero orders during the claimed disruption window.
8. IF the platform API reports completed orders during the disruption window, THEN THE Claims_Scoring_Service SHALL veto the claim with status "PLATFORM_ACTIVITY_VETO".
9. THE Claims_Scoring_Service SHALL sample the Worker's GPS coordinates at a minimum of 3 independent timestamps within the disruption window to detect static-lock fraud.
10. IF all sampled GPS coordinates are identical (velocity equals 0 for the full disruption window), THEN THE Claims_Scoring_Service SHALL flag the claim for elevated manual review.

---

### Requirement 5: Multi-Oracle Consensus Engine

**User Story:** As an insurer, I want parametric triggers to require consensus from multiple independent data oracles, so that no single compromised or failed data source can unilaterally authorize a payout.

#### Acceptance Criteria

1. THE Oracle_Consensus_Engine SHALL poll four independent oracles: IMD Primary API, AccuWeather commercial feed, NASA GPM satellite precipitation API, and ground-level sensor aggregation.
2. WHEN polling oracles, THE Oracle_Consensus_Engine SHALL require a minimum of 3 affirmative votes out of 4 to authorize a parametric trigger.
3. THE Oracle_Consensus_Engine SHALL treat oracle data older than 15 minutes as an abstention, not an affirmative vote.
4. IF fewer than 3 oracles return affirmative votes, THEN THE Oracle_Consensus_Engine SHALL not authorize the parametric trigger and SHALL log the vote breakdown.
5. THE Oracle_Consensus_Engine SHALL use certificate pinning on all HTTPS calls to external oracle endpoints.
6. IF an oracle endpoint presents an unexpected TLS certificate, THEN THE Oracle_Consensus_Engine SHALL nullify that oracle's vote for the current polling cycle and log the anomaly.
7. THE Oracle_Consensus_Engine SHALL randomize polling intervals within a plus or minus 8 minute window around the base cron schedule.
8. WHEN 2 or more oracles are simultaneously offline during a confirmed disaster event and at least 1 oracle confirms the event, THE Oracle_Consensus_Engine SHALL apply the "Benefit of Doubt" protocol and authorize a 50% capped payout for all active policies in the affected zone.
9. THE Oracle_Consensus_Engine SHALL publish authorized trigger events to Kafka_Broker with oracle vote breakdown, event_type, zone_id, and timestamp.

---

### Requirement 6: Core Backend REST API

**User Story:** As a developer, I want a well-structured REST API backend, so that the Flutter app can manage policies, users, and payouts through a single reliable interface.

#### Acceptance Criteria

1. THE Core_Backend SHALL expose REST endpoints for: user registration, user authentication (JWT), policy creation, policy retrieval, policy cancellation, premium payment, payout history, and claim status retrieval.
2. THE Core_Backend SHALL authenticate all non-public endpoints using JWT bearer tokens with a maximum token lifetime of 24 hours.
3. IF a request is made with an expired or invalid JWT, THEN THE Core_Backend SHALL return HTTP 401 with a structured error body.
4. THE Core_Backend SHALL enforce role-based access control (RBAC) with roles: Worker, Admin, and Insurer.
5. WHEN a Worker registers, THE Core_Backend SHALL enforce a 72-hour activation delay before the Policy becomes claim-eligible.
6. WHEN a Worker upgrades their Tier, THE Core_Backend SHALL enforce a 5-day waiting period before the upgraded Tier applies to claim eligibility.
7. THE Core_Backend SHALL persist all Policy and User records to CockroachDB with ACID transaction guarantees.
8. THE Core_Backend SHALL publish user lifecycle events (registration, policy creation, cancellation) to Kafka_Broker for downstream consumption.
9. THE Core_Backend SHALL enforce a hard cap of one successful payout per Worker per 7-day policy cycle.
10. WHEN a policy cancellation is requested, THE Core_Backend SHALL not process the cancellation until the current 7-day billing cycle completes.

---

### Requirement 7: Apache Kafka Real-Time Event Streaming

**User Story:** As a platform engineer, I want all inter-service events to flow through a message queue, so that services are decoupled and events are never lost during transient failures.

#### Acceptance Criteria

1. THE Kafka_Broker SHALL provide topics for: worker_onboarding, claim_submitted, claim_decision, payout_authorized, oracle_trigger, premium_updated, and fraud_alert.
2. WHEN a service publishes an event, THE Kafka_Broker SHALL guarantee at-least-once delivery to all subscribed consumers.
3. THE Kafka_Broker SHALL retain messages for a minimum of 7 days to support replay and audit.
4. IF a consumer fails to acknowledge a message, THEN THE Kafka_Broker SHALL redeliver the message to the consumer group after the configured retry interval.
5. THE Core_Backend, Risk_Profiler, Claims_Scoring_Service, BullMQ_Worker, and Oracle_Consensus_Engine SHALL each consume only the Kafka topics relevant to their function.

---

### Requirement 8: BullMQ Background Job Processing

**User Story:** As a platform engineer, I want background jobs to be reliably queued and retried, so that payout disbursements and notifications are never silently dropped.

#### Acceptance Criteria

1. THE BullMQ_Worker SHALL process jobs from queues: premium_recalculation, payout_disbursement, notification_dispatch, and fraud_review_escalation.
2. WHEN a payout_disbursement job fails, THE BullMQ_Worker SHALL retry with exponential backoff for a maximum of 5 attempts before moving the job to the dead-letter queue.
3. THE BullMQ_Worker SHALL emit a Prometheus metric for job completion rate, failure rate, and queue depth per queue name.
4. IF a payout_disbursement job remains in the dead-letter queue for more than 24 hours, THEN THE BullMQ_Worker SHALL publish a fraud_alert event to Kafka_Broker for manual intervention.
5. THE BullMQ_Worker SHALL process premium_recalculation jobs for all active policies within a 1-hour window at the start of each billing cycle.

---

### Requirement 9: CockroachDB Financial Ledger

**User Story:** As an insurer, I want all financial transactions to be stored in a distributed, ACID-compliant ledger, so that premium and payout records are tamper-evident and auditable.

#### Acceptance Criteria

1. THE CockroachDB SHALL store all premium payments, payout disbursements, and policy records with full ACID transaction guarantees.
2. THE CockroachDB SHALL enforce a minimum 90-day payout reserve balance constraint at the ledger level.
3. WHEN a payout is authorized, THE CockroachDB SHALL record the payout with: payout_id, worker_id, claim_id, amount, oracle_vote_breakdown, zone_id, tier, and timestamp.
4. THE CockroachDB SHALL support horizontal scaling across at least 3 nodes to ensure availability during node failures.
5. THE Core_Backend SHALL use optimistic concurrency control when writing payout records to prevent double-disbursement.

---

### Requirement 10: RAG Intelligence Pipeline

**User Story:** As a delivery partner, I want the in-app assistant to answer questions about my policy and disruption events using accurate, up-to-date information, so that I do not need to contact support for routine queries.

#### Acceptance Criteria

1. THE RAG_Orchestrator SHALL embed incoming Worker queries using BGE-Large embeddings before retrieval.
2. THE Vector_Store SHALL store chunked policy documents, disruption event summaries, and municipal advisory content as vector embeddings in MongoDB Atlas.
3. WHEN a Worker query is received, THE RAG_Orchestrator SHALL retrieve the top-5 most semantically relevant chunks from Vector_Store using cosine similarity.
4. THE RAG_Orchestrator SHALL pass the retrieved context and Worker query to the AI inference engine (Gemini/Groq/GPT-4o) to generate a grounded response.
5. IF no relevant chunks are retrieved with similarity above 0.6, THEN THE RAG_Orchestrator SHALL respond with a fallback message directing the Worker to human support.
6. THE RAG_Orchestrator SHALL update Vector_Store with new disruption event summaries within 30 minutes of a confirmed oracle trigger event.
7. FOR ALL policy document chunks, THE RAG_Orchestrator SHALL parse a chunk into a PolicyDocument object and re-serialize it to produce an equivalent representation (round-trip property).

---

### Requirement 11: Web Intelligence and Knowledge Graph

**User Story:** As a platform engineer, I want disruption signals to be automatically scraped and cached, so that the oracle consensus engine has fresh, structured data without manual intervention.

#### Acceptance Criteria

1. THE Web_Intelligence_Service SHALL scrape Downdetector for Swiggy and Zomato outage reports on a configurable polling interval with a default of 5 minutes.
2. THE Web_Intelligence_Service SHALL parse IMD weather advisory RSS feeds and municipal lockdown advisory feeds into structured JSON events.
3. IF a scraped source returns malformed or unparseable content, THEN THE Web_Intelligence_Service SHALL log the error and skip the record without crashing.
4. THE Knowledge_Graph_Cache SHALL store scraped disruption events keyed by zone_id and event_type with a TTL of 15 minutes.
5. WHEN the Knowledge_Graph_Cache TTL expires for a zone, THE Knowledge_Graph_Cache SHALL evict the stale entry and trigger a re-scrape via Web_Intelligence_Service.
6. THE Oracle_Consensus_Engine SHALL query Knowledge_Graph_Cache before making external API calls to reduce oracle polling latency.
7. FOR ALL valid advisory text inputs, THE Web_Intelligence_Service SHALL parse advisory text into a DisruptionEvent object and THE Knowledge_Graph_Cache SHALL serialize it back to advisory text to produce an equivalent representation (round-trip property).

---

### Requirement 12: Crew AI Multi-Agent Claim Orchestration

**User Story:** As a claims adjuster, I want autonomous agents to handle routine claim validation steps, so that the fraud queue only contains genuinely ambiguous cases requiring human judgment.

#### Acceptance Criteria

1. THE Crew_AI_Orchestrator SHALL deploy agents for: document_verification, oracle_cross_check, fraud_signal_aggregation, and payout_authorization.
2. WHEN a claim enters the Fraud_Queue, THE Crew_AI_Orchestrator SHALL assign the claim to the fraud_signal_aggregation agent for secondary analysis within 60 seconds.
3. THE fraud_signal_aggregation agent SHALL query the Knowledge_Graph_Cache, Vector_Store, and PostgreSQL claim history to produce a structured fraud_analysis_report.
4. IF the fraud_signal_aggregation agent produces a fraud_analysis_report with confidence above 0.85, THEN THE Crew_AI_Orchestrator SHALL escalate the claim to a human adjuster with the report attached.
5. THE Crew_AI_Orchestrator SHALL log all agent actions, tool calls, and decisions to PostgreSQL for audit.
6. THE Crew_AI_Orchestrator SHALL complete secondary analysis for Fraud_Queue claims within 5 minutes of claim submission.

---

### Requirement 13: RASA Conversational Assistant and Multilingual NLP

**User Story:** As a delivery partner, I want to interact with the app in my regional language, so that I can understand my policy and claim status without language barriers.

#### Acceptance Criteria

1. THE RASA_Assistant SHALL handle intents for: policy_inquiry, claim_status, payout_inquiry, disruption_alert, and escalate_to_human.
2. WHEN a Worker sends a message in a regional Indian language, THE IndicConformer SHALL transliterate and translate the message to English before passing it to RASA_Assistant.
3. THE RASA_Assistant SHALL respond in the Worker's detected language by passing the English response through IndicConformer for back-translation.
4. IF RASA_Assistant cannot resolve a Worker query with confidence above 0.7, THEN THE RASA_Assistant SHALL escalate to a human support agent and notify the Worker.
5. THE RASA_Assistant SHALL retrieve policy and claim context from Core_Backend via authenticated REST calls before generating responses.
6. THE RASA_Assistant SHALL support a minimum of 5 Indian regional languages: Hindi, Tamil, Telugu, Kannada, and Bengali.

---

### Requirement 14: PayU UPI Payout Disbursement

**User Story:** As a delivery partner, I want approved payouts to be credited to my UPI wallet automatically, so that I receive compensation without any manual steps.

#### Acceptance Criteria

1. WHEN a payout_authorized event is consumed from Kafka_Broker, THE BullMQ_Worker SHALL enqueue a payout_disbursement job for the PayU_Gateway.
2. THE PayU_Gateway SHALL disburse the approved payout amount to the Worker's registered UPI ID within 60 seconds of job execution.
3. IF the PayU_Gateway returns a failure response, THEN THE BullMQ_Worker SHALL retry the disbursement with exponential backoff up to 5 attempts.
4. WHEN a SIM change is detected on the Worker's account within the prior 6 hours, THE PayU_Gateway SHALL hold the disbursement and require biometric re-confirmation before releasing funds.
5. THE CockroachDB SHALL record the final disbursement status (success or failure), PayU transaction reference, and timestamp for every payout attempt.
6. THE FCM SHALL send a push notification to the Worker's device within 30 seconds of a successful payout disbursement.

---

### Requirement 15: Firebase Cloud Messaging Push Notifications

**User Story:** As a delivery partner, I want real-time lock-screen alerts for payouts and disruption events, so that I am immediately informed without opening the app.

#### Acceptance Criteria

1. THE FCM SHALL deliver push notifications for: payout_credited, claim_approved, claim_rejected, disruption_alert, and premium_updated events.
2. WHEN a payout_credited event occurs, THE FCM SHALL deliver the notification to the Worker's device within 30 seconds.
3. WHEN a disruption_alert is triggered by Oracle_Consensus_Engine, THE FCM SHALL deliver zone-specific alerts to all Workers with active policies in the affected zone within 60 seconds.
4. IF a notification delivery fails, THEN THE FCM SHALL retry delivery for up to 24 hours using Firebase's built-in retry mechanism.
5. THE Core_Backend SHALL manage FCM device token registration and refresh for all active Workers.

---

### Requirement 16: Prometheus Monitoring and Observability

**User Story:** As a platform engineer, I want all services to emit structured metrics, so that I can detect anomalies and SLA breaches before they impact partners.

#### Acceptance Criteria

1. THE Risk_Profiler, Claims_Scoring_Service, Core_Backend, BullMQ_Worker, Oracle_Consensus_Engine, and RAG_Orchestrator SHALL each expose a /metrics endpoint in Prometheus exposition format.
2. THE Prometheus SHALL scrape all service /metrics endpoints at a 15-second interval.
3. THE Prometheus SHALL alert when: Risk_Profiler p95 latency exceeds 3 seconds, Claims_Scoring_Service p95 latency exceeds 2 seconds, BullMQ dead-letter queue depth exceeds 10 jobs, or Oracle_Consensus_Engine oracle failure rate exceeds 50%.
4. THE Core_Backend SHALL emit a metric for active_policies_count, weekly_premiums_collected, and payouts_disbursed_total.
5. THE Claims_Scoring_Service SHALL emit a metric for claims_auto_approved_total, claims_fraud_queued_total, and fraud_score_histogram.

---

### Requirement 17: Population-Level Fraud Detection

**User Story:** As an insurer, I want coordinated fraud rings to be detected at the population level, so that a single fraudulent claim pattern cannot be replicated across hundreds of accounts simultaneously.

#### Acceptance Criteria

1. THE Claims_Scoring_Service SHALL monitor the rate of claims pointing to identical or near-identical zone polygons within any 5-minute window.
2. IF 50 or more unique policy IDs submit claims for the same zone polygon within a 5-minute window, THEN THE Claims_Scoring_Service SHALL trigger a "Convergence Freeze" and queue all pending claims for that zone for a mandatory 24-hour review hold.
3. THE Claims_Scoring_Service SHALL analyze device Bluetooth and WiFi proximity logs to detect claims from devices that have been co-located within the prior 7 days.
4. IF a cluster of 5 or more devices shows prior co-location within 7 days and submits claims within the same event window, THEN THE Claims_Scoring_Service SHALL flag all claims in the cluster for elevated manual review.
5. THE Claims_Scoring_Service SHALL enforce a maximum of 3 successful claims per Worker per 90-day rolling window, routing any excess claims directly to Fraud_Queue.
6. THE Claims_Scoring_Service SHALL publish a fraud_alert event to Kafka_Broker whenever a Convergence Freeze is triggered, including zone_id, claim_count, and timestamp.

---

### Requirement 18: Flutter App Integration with Live Backend

**User Story:** As a delivery partner, I want the Flutter app to connect to the live backend instead of mock data, so that my dashboard, claims, and profile reflect real-time information.

#### Acceptance Criteria

1. THE Flutter app SHALL replace all MockApiService calls with authenticated HTTP calls to Core_Backend REST endpoints.
2. THE Flutter app SHALL store and refresh JWT tokens using secure storage (flutter_secure_storage) and automatically re-authenticate on token expiry.
3. WHEN the Flutter app is offline, THE Flutter app SHALL display the last cached data and show an offline indicator.
4. THE Flutter app SHALL display the Risk_Score and computed weekly premium returned by FastAPI_Gateway on the dashboard screen.
5. THE Flutter app SHALL display real-time claim status updates by polling the Core_Backend claim status endpoint at 30-second intervals while a claim is in "Processing" state.
6. IF the Core_Backend returns HTTP 5xx, THEN THE Flutter app SHALL display a user-friendly error message and offer a retry action.
7. THE Flutter app SHALL send the device FCM token to Core_Backend on every app launch to ensure notification delivery is current.
