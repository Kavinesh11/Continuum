# Continuum — 100 Adversarial Failure Scenarios

A structured simulation of every meaningful failure mode across six attack vectors.
Each entry includes: **Scenario**, **Root Cause**, **Impact**, **Fallback/Defense**.

---

## Category A: GPS & Location Spoofing (Scenarios 1–20)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 1 | Single partner fakes GPS into flood-affected zone using app (e.g., Fake GPS) | Mock location app injection | Fraudulent payout | Cross-reference with telecom Cell-ID triangulation; if GPS-cell mismatch > 2km → flag |
| 2 | 500 partners simultaneously spoof into the same Mumbai polygon | Coordinated ring; identical IP subnets | Liquidity drain | Statistical anomaly: ≥50 unique policies converging on the same lat/long poly → auto-freeze zone payouts, trigger manual audit |
| 3 | Partner spoofs into flood zone, then returns to real location before platform revalidates | Temporal GPS pinning | Escapes real-time check | Require GPS evidence across 3 time-stamps within disruption window, not just entry ping |
| 4 | Android emulator used to masquerade as a real device | Emulator fingerprint | Bypasses device checks | DeviceAttestation via Play Integrity API; emulators lack valid hardware attestation certificate |
| 5 | GPS jitter attack — partner stays at the edge of the payout polygon, oscillating in/out | Boundary exploitation | Partial payout gaming | Payout only if GPS centroid is inside polygon for ≥70% of sampled pings during disruption window |
| 6 | Partner drives into payout zone just before parametric trigger fires | Pre-trigger positioning | Technically valid location | Enforce "soak period": partner must have been in zone ≥45 minutes BEFORE trigger event |
| 7 | VPN used to spoof IP to a matching city while GPS is real but far away | IP-to-location mismatch | Misleads IP validation | IP-based checks are secondary signals only; cannot approve or deny solely on IP |
| 8 | Two partners share one device (SIM swap) to double-claim | Identity stacking | Double payout from one device | Device_ID : Policy_ID = 1:1 hard binding in database; second bind on same device_id rejected |
| 9 | Partner registers a false "home zone" to get lower premiums, then operates elsewhere | Zone fraud on enrollment | Pricing arbitrage | Zone must match first 30 days of GPS telemetry history at onboarding; anomalous zones rejected |
| 10 | GPS coordinates locked at a 3rd party address (e.g., restaurant) to simulate being "on route" | Static coordinate relay | Fools single-point checks | Detect velocity = 0 (stationary lock) for >20 mins during purported active shift → suspend eligibility |
| 11 | State actor or developer-mode GPS patched at OS level (rooted device) | Root/jailbreak | Defeats app-level attestation | Root detection via SafetyNet/Play Integrity; rooted devices ineligible for claims |
| 12 | Partner in zone A spoofs to zone B while zone B has higher payout tier | Cross-zone arbitrage | Payout inflation | Payout value is always capped at the partner's enrolled home-zone tier, not claim-zone tier |
| 13 | Social engineer a legitimate partner to "lend" their account to a fraud-zone spoofer | Account lending | Human-layer bypass | Enforce biometric check (face scan) on claim submission; mismatched face → auto-reject |
| 14 | Fraud ring uses custom hardware GPS repeaters near NFC checkpoints | Hardware-level spoof | Defeats phone-native checks | Cross-check delivery platform's own GPS logs (Swiggy/Zomato API audit); if platform shows no active orders in zone, reject |
| 15 | Flood zone is actually a park/uninhabited area; partner fakes being there | Uninhabited zone fraud | Easy to over-claim | Payout zones must be mapped against active merchant density (OSM data); no merchants = no valid delivery zone |
| 16 | Partner claims flood payout, but their delivery platform showed 3 completed orders during same window | Contradictory platform record | Direct evidence of fraud | Platform API cross-reference is a hard veto: if orders were completed during disruption → no payout |
| 17 | 80 partners from same WhatsApp group all claim simultaneously after group coordinator signals trigger | Social-coordinated ring | Pattern collusion | Flag claims where >15 policies from the same social graph (via device Bluetooth/WiFi proximity logs) file within 5 minutes |
| 18 | Fraud ring creates synthetic "new" accounts, accumulates 1 week of fake GPS history, claims | Manufactured credibility | Defeats history check | Minimum 4-week GPS history required; new accounts ineligible for claims in first month |
| 19 | Old phone clock set wrong — GPS pings fall outside disruption timestamp window but partner claims they were in zone | Timestamp manipulation | Edge between fraud and tech issue | All GPS timestamps must be NTP-synced server-side; client-reported time is discarded |
| 20 | Partner spoofs location into zone hours after disruption ended (lazy fraud) | Stale trigger exploit | Timestamps mismatch | Parametric window is hard-closed; all claim GPS data must fall within [trigger_start, trigger_end + 15 min] |

---

## Category B: Coordinated Collusion Rings (Scenarios 21–35)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 21 | Ring leader registers 50 accounts owned by family members | Identity farming | 50x payout amplification | PAN/Aadhaar KYC linkage; one national ID can own max 1 active policy |
| 22 | Corrupt local Swiggy sub-vendor confirms fake orders to validate GPS footprints | Internal collusion | Legitimized fraud path | Oracle uses Swiggy's central API, not sub-vendor data; local branches cannot inject fake data |
| 23 | Pharmacy/shop owner in zone colludes with riders to "confirm" their presence | Third-party confirmation fraud | Corrupts social proofing | Social proofing (3rd-party confirmation) is a supporting signal only, never a primary payout gate |
| 24 | Corrupt meteorological sensor in zone reports false rainfall | Oracle data poisoning | Trigger fires on false data | Use multi-oracle voting: IMD + 3 independent private weather stations; 2/3 consensus required |
| 25 | Ring creates "ghost" merchant pins in OSM to establish delivery zone validity | Map data poisoning | Fraudulent zone validation | OSM updates have a 72-hour review lag; use Swiggy's real-time merchant density, not OSM alone |
| 26 | Insider at Continuum sets payout threshold artificially low in a specific zone | Internal platform fraud | Triggers cascade of payouts | All threshold changes require cryptographic dual-approval (two separate admin keys); logged immutably |
| 27 | Ring member tests limits by filing 5 small claims before coordinated large claim | Probe-then-exploit | Slow escalation undetected | Velocity limiter: max 3 claims per partner per 90-day rolling window regardless of amount |
| 28 | Partners rotate between 2 cities to exploit two simultaneous disruptions | Multi-city arbitrage | Amplified claims | One active policy per GPS home zone per week; cannot claim from two cities in same cycle |
| 29 | Ring uses referral program to recruit 200 new members, files day-1 claims | Referral farming | Mass-scale new account fraud | Referral bonuses paid only after referee completes 60 days with zero claims |
| 30 | Lawyer-fronted ring files identical appeal templates after auto-rejections | Systematic appeal gaming | Manual audit overload | Auto-reject duplicate appeal structures; ML-based legal template clustering to identify boilerplate |
| 31 | Ring bribes a Continuum field agent doing manual audits | Insider audit corruption | Legitimate fraud approval | Field agents are randomized and cannot audit partners from their own zone; decisions require senior countersign |
| 32 | Coordinated negative press campaign to force hurried, lax payout reviews | Reputational pressure fraud | Manual override of risk engine | Claims engine payout is fully automated; no human override pathway for standard claims |
| 33 | Ring monitors Continuum's oracle cron schedule and fakes activity right before sensor checks | Timing-the-oracle attack | Escapes between checks | Oracle polling is randomized ± 8 minutes; schedule is never exposed externally |
| 34 | Ring registers in legitimate workers' names using stolen KYC documents | Identity theft | Legitimate worker's identity weaponized | Biometric liveness check (video selfie) at activation; stolen static IDs blocked by liveness failure |
| 35 | Ring uses deepfake video for liveness check to pass KYC | AI-generated liveness bypass | Defeats biometric guard | Integrate 3rd-party deepfake detection API (e.g., iProov); flag unusual blinking patterns or lighting artifacts |

---

## Category C: Actuarial & Pricing Model Failures (Scenarios 36–55)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 36 | Chennai experiences 90 rain days/year — Silver tier gets paid out constantly | Zone over-exposure | Unsustainable loss ratio | Zone-specific pricing: Endemic high-rainfall zones carry 1.5–2x premium multiplier |
| 37 | A single extreme cyclone hits 10,000 partners simultaneously | Catastrophic correlated loss | Existential liquidity event | Reinsurance treaty for any single event affecting >1,000 simultaneous policyholders |
| 38 | Platform-wide Zomato outage affects all 50,000+ active policies at once | Systemic technology risk | Total liquidity drain | Policy count cap per oracle type (e.g., max 5,000 active policies on Zomato-outage trigger at one time) |
| 39 | ML pricing model is trained on 2024 data; climate shift makes 2026 rain patterns 3x worse | Model drift | Systematic chronic underpricing | Weekly model retraining with real-time loss ratio feedback; automatic premium escalation if loss ratio >80% |
| 40 | Partner works in a new tier-3 city with no historical data for ML model | Cold-start pricing error | Premium too low or too high | Bootstrap new zone with regional proxy data; apply conservative 1.2x uncertainty multiplier for first 12 weeks |
| 41 | Too many partners in Platinum tier drain the high-payout reserve first during a major event | Reserve concentration risk | Disproportionate reserve depletion | Tier-wise reserve buckets: Silver/Gold/Platinum each maintain isolated capital pools |
| 42 | Partner upgrades from Silver to Platinum on Tuesday, claims on Thursday | Tier-switch timing exploit | Over-coverage just before known event | 5-day waiting period before tier upgrade takes effect for claim eligibility |
| 43 | Premium is set at ₹49 but average claim is ₹500; loss ratio = 1020% | Fundamental pricing error | Company insolvency | Actuarial floor: minimum premium must be ≥ (Expected_claims × avg_payout) / (policy_count × claim_probability) |
| 44 | Inflation erodes real value of ₹500/day coverage within 2 years | Static coverage value | Benefit becomes meaningless | Annual coverage indexation tied to CPI or Swiggy's base-rate changes |
| 45 | Partner earns ₹8,000/day (super rare) but is on Silver tier; claims only ₹500 | Undercoverage distortion | Partner dissatisfied; churns | Optional "earnings verification" upgrade path; allow income-linked tier auto-upgrade |
| 46 | Two disruptions occur in same week; partner claims twice | Double-event stacking | Double payout in one cycle | Maximum 1 successful payout per 7-day policy cycle regardless of distinct triggers |
| 47 | 3-hour outage occurs at 2 AM (zero delivery volume period); partner claims lost income | Off-peak trigger exploit | Zero real income lost | Payouts are prorated against partner's historical hourly earnings profile; 2 AM = near-zero weight |
| 48 | Competitor insurance product launches at ₹29/week, causing mass Silver tier churn | Competitive pricing undercut | Market exit | Silver is loss-leader tier; cross-subsidy from Platinum margins funds Silver long-term |
| 49 | Partner cancels policy mid-week after a disruption event is announced but before trigger fires | Pre-trigger cancellation | Payout without premium | Cancellations are not effective until the current 7-day cycle ends |
| 50 | New partner enrolls during a live disruption event and immediately claims | Same-day enrollment exploit | Zero premium paid, full payout | 72-hour activation delay between enrollment and first claim eligibility |
| 51 | Monsoon season causes 180+ claim-days per year in a specific zone | Actuarial underestimation | -tive reserve balance | Per-zone annual claim day cap: if historical rain events exceed 60 days/year, zone premium auto-escalates |
| 52 | Foreign exchange rate swings make reinsurance treaties more expensive | Macro-financial risk | Coverage gap | Reinsurance treaties locked at multi-year fixed rates in INR to eliminate FX exposure |
| 53 | Claim frequency spikes during regional election, as partners interpret curfew loosely | Semantic trigger ambiguity | Payouts for semi-valid events | Oracle only accepts machine-parseable municipal advisory codes; press-release language is excluded |
| 54 | Partner on leave (no GPS pings) still has active policy and claims for a disruption | Inactive-partner fraud | Payout without exposure | Claims require ≥2 hours of active GPS movement in the disruption zone on the claim day |
| 55 | Premium pool is invested in a volatile asset that crashes, wiping reserves | Treasury management failure | Insolvency | Premium pool held exclusively in FDIC/RBI-equivalent low-risk instruments (T-bills, liquid funds); no equity exposure |

---

## Category D: Data Oracle Manipulation (Scenarios 56–70)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 56 | IMD API returns stale cached data showing yesterday's rainfall | Data freshness failure | Missed trigger or false trigger | IMD data TTL: max 15 minutes; stale data = oracle vote abstention, not auto-trigger |
| 57 | Downdetector scraper gets rate-limited by Cloudflare anti-bot during an actual outage | Anti-scraping block | Misses legitimate trigger | Primary + 2 fallback outage oracles (IsItDownRightNow + synthetic ping from 3 geo-distributed servers) |
| 58 | Zomato/Swiggy push a silent API change that breaks the outage detection endpoint | Silent breaking API change | False "no-outage" reading | Daily smoke tests on all external API oracle endpoints; alert on status code changes |
| 59 | IMD rain gauge in a zone is physically damaged and reports 0mm | Sensor hardware fault | False negative; misses real flood | Cross-validate IMD with satellite precipitation data (NASA GPM API); sensor outliers flagged |
| 60 | Hostile actor sends forged RSS feed advisory to municipal advisory oracle | Advisory data injection | Triggers fraudulent payout | Advisory RSS feeds validated by signature/PGP cert from issuing municipality where available |
| 61 | DNS hijack redirects oracle API calls to attacker-controlled server | Man-in-the-middle | Completely fabricated oracle data | All oracle HTTPS endpoints pinned via certificate pinning; unexpected certs = oracle vote nullified |
| 62 | Satellite weather data API vendor goes bankrupt mid-season | Single vendor dependency | Loss of oracle redundancy | Multi-vendor oracle contracts with automatic failover to secondary vendors |
| 63 | Flood trigger fires for a zone, but it was a burst pipe, not weather | Non-parametric trigger event | Payout for non-qualifying event | Only IMD classified hydro-meteorological events qualify; municipal infrastructure events are out-of-scope |
| 64 | Downdetector shows minor latency, but system misclassifies it as an outage | Threshold sensitivity error | False positive payout | "Outage" requires ≥35% user complaint spike on Downdetector AND synthetic ping timeout from 3+ locations |
| 65 | Oracle consensus algorithm has a tie (2 oracles say yes, 2 say no) | Deadlock in voting | Unresolved trigger | Tie-breaking rule: weighted by historical oracle accuracy score; lowest-accuracy oracle is the swing vote only in emergencies |
| 66 | Rainfall event ends 10 minutes before trigger threshold is crossed | Near-miss gaming | Legitimate denial or confusion | Trigger is evaluated on a 2-hour rolling window; brief cessation does not reset the accumulation counter |
| 67 | Two cities have same name (e.g., Aurangabad, MH vs. Aurangabad, BR); wrong zone triggered | Geographic naming collision | Payout to wrong zone | All zones identified by unique WGS84 polygon IDs, not names; names are display-layer only |
| 68 | Oracle data temporarily unavailable during a real mega-storm | Storm disrupts data infrastructure | Cannot confirm trigger | If ≥2 of 4 oracles are offline simultaneously, automatic "benefit of the doubt" conservative payout at 50% cap |
| 69 | Attacker floods oracle ingestion queue with fake high-volume events | DoS on oracle pipeline | Processing delay or panic trigger | Ingestion queue rate-limited per source IP; duplicate sources filtered by signature hash |
| 70 | Platform detects oracle correctly, but notification delay causes partner to take unsafe action | Latency-induced harm | Reputational/safety liability | P95 notification latency target: <90 seconds from trigger confirmation to push notification |

---

## Category E: Regulatory & Legal Edge Cases (Scenarios 71–82)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 71 | IRDAI classifies Continuum as an unauthorized insurance product | Regulatory classification risk | Platform shutdown | Structure product as "income protection indemnity" not "insurance"; obtain IRDAI sandbox license in Year 1 |
| 72 | State government bans all micro-insurance products in one state | State-level regulatory action | Loss of user base | Policy contracts governed by central IRDAI framework; state-level bans preempted by federal insurance law |
| 73 | Partner files consumer complaint claiming payout was delayed by >24 hours | Consumer protection claim | Legal liability | SLA: all valid payouts completed within 4 hours; SLA breach triggers automatic 10% bonus compensation |
| 74 | GST rules change; weekly premiums become subject to 18% GST | Tax regime change | Pricing model broken | Premiums are quoted GST-inclusive; tax change absorbed into margin, not passed to user during current policy cycle |
| 75 | Partner sues claiming flood payout didn't cover their full day's income | Coverage gap litigation | Adverse precedent | Policy wording explicitly states coverage = flat-rate daily benefit, not income indemnity; parametric terms clear at enrollment |
| 76 | Data regulator (DPDP Act) demands deletion of all GPS history | Privacy regulatory action | Loss of fraud-prevention data | GPS history is hashed and aggregated post-claim; raw coordinates deleted after 60 days by default |
| 77 | Death of a delivery partner during a flood; family claims income protection payout | Scope boundary event | Potential misuse of payout | Policy explicitly excludes death/injury; payout is solely for living, active partner accounts |
| 78 | Partner operates in a zone that crosses two municipal boundaries; trigger fires in one only | Multi-jurisdiction edge | Partial-zone ambiguity | Payout zone is the partner's GPS centroid municipality; partial zone events pay 50% if centroid is in affected area |
| 79 | Partner disputes auto-rejection via consumer arbitration | Dispute resolution gap | Lengthy legal process | Mandatory 48-hour internal fast-track appeal; if not resolved, Continuum binds to third-party SEBI-approved arbitration |
| 80 | Continuous GPS tracking is challenged as unconstitutional surveillance | Privacy rights challenge | GPS mandate invalid | GPS is opt-in; partners who opt out forfeit claim eligibility but retain policy enrollment |
| 81 | Flood trigger in Zone A spills over geographically; partner in adjacent Zone B is also stranded | Zone boundary rigidity | Legitimate partner denied | "Adjacency grace": partners in zones immediately bordering the triggered polygon receive 50% payout |
| 82 | Curfew advisory issued at 11:59 PM on last day of policy week | Timing edge at policy boundary | Coverage ambiguity | If trigger fires while policy is active (even by 1 minute), full week's payout is honored |

---

## Category F: Systemic & Black Swan Edge Cases (Scenarios 83–100)

| # | Scenario | Root Cause | Impact | Fallback |
|---|----------|-----------|--------|----------|
| 83 | Catastrophic earthquake hits partner city; partners need cash, but platform infrastructure is down | Infrastructure loss during disaster | Cannot process payouts | Pre-authorized emergency payout to all active policies in earthquake zone triggers via offline SMS confirmation |
| 84 | UPI/NPCI payment rails go down nationally | Payment infrastructure failure | Cannot disburse funds | 24-hour payment queue with auto-retry; Razorpay wallet as interim escrow fallback |
| 85 | All 3 cloud regions (AWS/GCP/Azure) experience simultaneous outage | Hyper-scale infrastructure failure | Total platform blackout | Multi-cloud active-active deployment; if all 3 fail, payouts are queued in a cold standby database and executed on restore |
| 86 | Fake news about a "Continuum payout" for a fabricated mass flood event goes viral | Misinformation-driven mass claims | Surge of illegitimate submissions | All claims are validated solely by oracles; viral social media claims have zero weight in trigger logic |
| 87 | Swiggy/Zomato terminates all delivery partners in a city due to business restructuring | Platform-initiated mass layoff | 10,000 policies terminate simultaneously | Continuum does not cover platform-initiated terminations; employment risk is explicitly excluded |
| 88 | Climate change makes previously 1-in-100-year floods happen every 3 years | Secular risk shift | Chronic under-reserving | Annual actuarial review with climate adjustment factor; reserve buffer increased proactively |
| 89 | India experiences a nationwide internet shutdown during protests | Regulatory internet kill switch | Cannot validate claims or disburse | Pre-authorize payouts for all active policies in affected zones; disburse on internet restoration |
| 90 | Partner's registered UPI number is ported to a fraudster's SIM | SIM-swap during payout | Funds sent to wrong person | Payout held for 6-hour SIM-change cooling period; biometric reconfirmation required after SIM change |
| 91 | A competitor reverse-engineers Continuum's oracle thresholds and sells trigger prediction as a service | Oracle parameter leakage | Enables precise gaming | Thresholds are dynamic, ML-computed weekly, and never publicly disclosed |
| 92 | Exchange rate collapse makes INR payouts worthless | Currency collapse | Benefit irrelevance | Not applicable in Indian domestic market; INR exposure is total; covered by sovereign risk |
| 93 | Geomagnetic storm disables GPS satellites over India | Space weather event | All GPS validation fails | Cellular triangulation as full fallback GPS source; if both fail, apply automatic benefit-of-the-doubt payout |
| 94 | Partner becomes a Continuum "super-claimant" by moving to a new high-risk zone each week | Zone-hopping opportunism | Chronic adverse selection | Claim frequency cap: >3 successful claims in 90 days triggers a manual review hold |
| 95 | A Continuum employee leaks the fraud-detection rulebook publicly | Security breach | Rulebook weaponized by fraudsters | Fraud detection logic is a black-box ML model; no human-readable "if-then" rulebook exists to leak |
| 96 | Partner's account is hacked; fraudster claims on their behalf | Account takeover | Funds go to fraudster | Payout destination (UPI) locked for 24 hours after any credential change; email/SMS confirmation required |
| 97 | A severe dust storm (not covered by "flood" trigger) leaves partners unable to work | Coverage exclusion gap | Legitimate need not covered | Adverse weather oracle covers all IMD "red alert" issued events, including dust storms, cold waves, and heatwaves |
| 98 | "Rain" is detected by oracle but is a light drizzle; partners continue working normally | Low-intensity false trigger | Unnecessary payout | Trigger is "severe weather" (≥50mm/2h), not any rain; confirmed by IMD's formal alert classification |
| 99 | A major religious festival causes voluntary shutdowns; partners claim as "curfew" | Voluntary event misclassified | Claim abuse | Only government-mandated, machine-parseable curfew orders qualify; voluntary shutdowns are excluded |
| 100 | Continuum itself becomes insolvent due to a black swan series of claims | Platform insolvency risk | All policyholders lose coverage | Regulatory reserve requirement: minimum 90-day reserves held in escrow at all times; IRDAI-mandated solvency margin |

---

## Synthesized Defense Architecture

From the 100-scenario simulation, six meta-principles emerge:

1. **Multi-Oracle Consensus**: No single data source can unilaterally trigger a payout. A weighted 3-of-4 oracle consensus is the minimum standard.
2. **GPS is Necessary, Not Sufficient**: GPS coordinates must be corroborated by Cell-ID, device attestation, platform order data, and temporal soak periods.
3. **Identity is the First Perimeter**: National KYC (Aadhaar/PAN), 1:1 device binding, and biometric liveness checks form the identity layer that all fraud attempts must breach first.
4. **Statistical Abnormality > Individual Investigation**: The most powerful anti-fraud signal is population-level analytics — 500 claims from the same polygon in 5 minutes is a signature no individual fraudster can hide.
5. **Incentive Realignment**: Waiting periods, velocity limits, and zone-locking are not bureaucratic friction — they destroy the economic model of fraud rings.
6. **Reserve Architecture is Existential**: Isolated tier-based reserves, mandatory reinsurance for correlated events, and IRDAI-mandated solvency margins are non-negotiable for a parametric insurance product.
