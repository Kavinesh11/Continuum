# Continuum Demo — Total End-to-End Mock & Simulation

## Context

**Why:** The Continuum Flutter app cannot reach its real backends (Node `core_backend`, FastAPI gateway, oracle/crew_ai/risk_profiler/rasa/web_intel services) and a complete product demo is required tomorrow. Every screen currently either blanks out, hangs, or shows error snackbars. We need a fully self-contained, deterministic, *narratively rich* simulation that lights up **every screen and every feature** in the app without any backend, plus hidden "backdoor" gestures the presenter can use during the live demo to trigger scripted moments (flood alert → auto-claim → payout, fraud queue, kill switch, reserve breach).

**What good looks like:** The presenter opens the app cold. They walk through Login → Sandbox driver pick → Dashboard (live triggers, earnings chart, recent activity) → Claims tab (filters, summary pills, detail sheets, auto vs manual) → Assist chat → Profile (stats, history, dark mode toggle) → Edit Profile → Payments (plan, methods, Pay Now, history) → Policy (6 sections) → Apply Form (photo + audio + description) → Status Tracker (auto-advancing stepper). At any point the presenter can secretly tap on the logo / avatar / pill / bot icon to fire scripted scenarios (incoming alerts, payout notifications, fraud queue, kill switch, reserve floor, zone lock). Bad-path scenarios are demonstrable. **No screen ever shows a network error or empty state during the demo.**

**Approach:** Make `lib/services/api_service.dart` mock-first — every public method returns rich, persona-aware, deterministic fake data via a new `DemoBackend` singleton. Wire `DriverProviderRoot` into `main.dart` so the active sandbox driver propagates everywhere (currently defined but never mounted — V71 / sandbox README says it should be). Build a `DemoOrchestrator` that owns scriptable scenarios and pushes events into existing `DemoState` and `NotificationState`. Layer hidden tap-counter gestures onto existing widgets via a reusable `EasterEggDetector`.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│  main.dart                                                         │
│   └── DriverProviderRoot         ← NEW wiring                      │
│        └── ContinuumApp / MaterialApp                              │
│             └── routes/ (login, sandbox, home, apply, status,      │
│                          profile, editProfile, payments, policy)   │
│                                                                    │
│  Every screen calls ApiService → mock-first DemoBackend            │
│  Every screen listens to DemoState / NotificationState (existing)  │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────────┐
        │   DemoBackend     (NEW singleton)      │
        │   • Persona-aware data store           │
        │   • Stateful claims/payouts/messages   │
        │   • Simulated latency (200–600ms)      │
        │   • Drives every ApiService method     │
        └────────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────────┐
        │   DemoOrchestrator (NEW singleton)     │
        │   Scenarios:                           │
        │    • floodAlert()                      │
        │    • appOutageAlert()                  │
        │    • autoClaimAndPayout()              │
        │    • fraudQueueEscalation()            │
        │    • killSwitchTrip()                  │
        │    • reserveFloorBreach()              │
        │    • zoneEnrollmentLock()              │
        │    • premiumDebited()                  │
        │    • claimRejected()                   │
        │    • seedDemoNotifications()           │
        │    • resetAll()                        │
        └────────────────────────────────────────┘
                              │
                              ▼
        ┌────────────────────────────────────────┐
        │   DemoState + NotificationState        │
        │   (existing — only minor additions)    │
        └────────────────────────────────────────┘
```

---

## Files To Create

| File | Purpose |
|------|---------|
| `lib/services/demo_backend.dart` | Mock backend that backs every `ApiService` call. Owns claim/payout/assist stores, advances claim stages over time, returns persona-tailored data. |
| `lib/state/demo_orchestrator.dart` | Singleton with named scenario methods for every scripted moment. Composes `DemoState` + `NotificationState` + `DemoBackend`. |
| `lib/widgets/easter_egg_detector.dart` | `EasterEggDetector(taps: 4, window: const Duration(seconds: 2), onTrigger: ...)` widget — wraps existing children invisibly. |
| `lib/widgets/demo_banner.dart` | Top-of-screen banner widget shown when killSwitch / reserveFloor / zoneLock is active. |

## Files To Modify

| File | Change |
|------|--------|
| `lib/main.dart` | Wrap `MaterialApp` in `DriverProviderRoot`. Initialize `DemoBackend.instance.bootstrap()` and `DemoOrchestrator.instance.bootstrap()` before `runApp`. Skip live FCM token POST in demo mode (already best-effort try/catch — leave). |
| `lib/services/api_service.dart` | Rewire **every** public method to short-circuit through `DemoBackend` with simulated 200-600ms latency. HTTP layer kept but unreachable. Methods touched: `login`, `getCurrentWorkerId`, `getWorkerProfile`, `getWorkerProfileCurrent`, `updateWorkerProfile`, `updateWorkerProfileCurrent`, `getClaims`, `getClaimStatus`, `submitClaim`, `getPayouts`, `createPolicy`, `getPolicyContent`, `fetchRiskProfile`, `getAssistMessages`, `sendAssistMessage`, `clearAssistHistory`, `registerFcmToken`, `saveToken`, `clearToken`, `isTokenValid`. Preserve method signatures so screens are untouched. |
| `lib/screens/new/login.dart` | Add `EasterEggDetector(taps:4)` on the logo → `loginAsSudarshan()` shortcut. Long-press logo → goes to sandbox picker (alongside the existing Partner ID button). Make any non-empty creds succeed by routing through `DemoBackend.login()`. |
| `lib/screens/new/dashboard.dart` | (a) Listen to `DemoOrchestrator` so injected data refreshes the screen. (b) Wrap leading avatar with `EasterEggDetector(taps:4)` → `floodAlert()`. (c) Wrap weekly-premium pill with `EasterEggDetector(taps:3)` → `killSwitchTrip()`. (d) Wrap plan-status card with `EasterEggDetector(taps:4)` → `reserveFloorBreach()`. (e) Long-press CONTINUUM title (existing) keeps `_fireDemoSequence()`. (f) Show `DemoBanner` if any flag is active. (g) Greeting / plan / pills / activity feed all sourced through `DemoBackend` (no behavioral change — only data). |
| `lib/screens/new/claims.dart` | Listen to `DemoOrchestrator`. Pre-seed claims via `DemoBackend.getClaims()` (3 per persona — mixed Approved/In Review/Rejected/Auto). Filter chips ('All' / 'Manual' / 'Auto') keep working. |
| `lib/screens/new/claim_detail_sheet.dart` | Already shows fields off the `claim` map — no change. Demo data ensures `upiRef`, `claim_description`, `statusColor` all populate. |
| `lib/screens/new/claim_flow.dart` | Already self-contained (5-step verify → ₹247 success). Just confirm `DemoState.addAutoClaim` adds it to the claims list (existing behavior). |
| `lib/screens/new/manual_claim_flow.dart` | Already self-contained. Pipe its outcome into `DemoOrchestrator.submitManualClaim()` so notifications + claim list both update (was DemoState-only). |
| `lib/screens/new/apply_form.dart` | After `submitClaim` returns, push the result into `DemoOrchestrator.submitManualClaim(reason, description, photos, audio)` which decides Approved / Rejected / FraudQueue based on reason + active feature flags. Status tracker then auto-advances. |
| `lib/screens/new/status_tracker.dart` | Already polls `getClaimStatus`. `DemoBackend` will advance the stage (SUBMITTED → REVIEW → APPROVED → PAYOUT) over ~12s with jittered timestamps. If `killSwitch` flag is active mid-flow, status stalls at REVIEW with verification message "Payouts paused — safety review in progress." |
| `lib/screens/new/assists.dart` | Pre-seed conversation via `DemoBackend.assistHistory`. Bot replies are deterministic per-keyword (claim, payout, premium, weather, fraud, status). Add `EasterEggDetector(taps:4)` on bot avatar → `autoClaimAndPayout()` (chat bubble narrates). |
| `lib/screens/new/profile.dart` | Wrap profile avatar with `EasterEggDetector(taps:4)` → `fraudQueueEscalation()`. Long-press header → `resetAll()`. Long-press zone label → `zoneEnrollmentLock()`. Persona data already wired off `_workerData` — no shape change, only the data source. |
| `lib/screens/new/edit_profile.dart` | Save calls `updateWorkerProfile` → `DemoBackend` mutates persona overlay so changes persist within session. |
| `lib/screens/new/payments.dart` | Pay Now also calls `DemoOrchestrator.premiumDebited()` which (a) drops a notification, (b) prepends a Success row to payment history. Plan card sourced from active driver. |
| `lib/screens/new/policy.dart` | `getPolicyContent()` returns 6-section, persona-tier-tailored content (subtitle changes per tier). |
| `lib/screens/new/plan_details.dart` | Currently hardcoded — leave (already populated). |
| `lib/screens/new/home_shell.dart` | No change — IndexedStack already wired. |
| `lib/widgets/notification_action.dart` | No structural change. With `DriverProvider` now wired, partnerId resolves correctly so notifications scope per persona. |
| `lib/widgets/claim_processing_dialog.dart` | No change — self-contained. |
| `lib/state/demo_state.dart` | Add `injectClaim(Map)`, `injectPayout(Map)`, `flagKillSwitch(bool)`, `flagReserveFloor(bool)`, `flagZoneLock(bool)` — small additions, existing methods kept. |
| `lib/state/notification_state.dart` | Add `addNotification(partnerId, NotificationItem)` convenience for the orchestrator (current API requires resetting full list). |

---

## Persona-Driven Mock Data (sourced through DemoBackend)

`DemoBackend` reads the active driver from `DriverProviderRoot._activeDriver`. For each persona it returns:

### `GET /workers/:id` (V65, V66, V69, V70, V72)
- `worker_id`, `full_name`, `phone`, `email`, `city`, `zone_id`, `platform`, `tier` ← from `SandboxDriver`
- `claims_approved_count`, `total_protected_amount` ← top-level (V65)
- `weekly_premium`, `next_renewal` (V69, V70)
- `registered_at` (ISO) (V72)
- `recent_claims[]` — derived from store
- `emergency_contact`

### `GET /claims` — 3 seeded per persona
| Persona | Seeded claims |
|---------|---------------|
| Sudarshan (Platinum) | CLM-9824-21 Approved ₹450 (Severe Weather), CLM-9102-54 In Review ₹0 (Platform Outage), CLM-8833-12 Auto-Approved ₹247 (Weather + Outage) |
| Dakshina (Gold) | CLM-7711-08 Approved ₹312 (Heavy Rain), CLM-7611-22 In Review ₹0 (App Outage), CLM-7322-90 Rejected ₹0 (Vehicle Breakdown) |
| Sudha (Silver) | CLM-5510-44 Approved ₹180 (Network Failure), CLM-5388-19 Auto-Approved ₹224 (Severe Weather) |

### `GET /claims/:id/status`
Stages auto-advance for any newly submitted claim. SUBMITTED → REVIEW (3s) → APPROVED (5s) → PAYOUT (4s). Each tick exposes `decided_at` ISO timestamp.

### `GET /payouts` — 3-4 per persona
Mix of Success + Pending with `payu_txn_ref` like `UPI/040426/CONT847291`.

### `POST /onboard` (risk profiler)
`risk_score` = 0.82 / 0.65 / 0.48 by tier (matches `SandboxService.fetchRiskProfile`).
`weekly_premium` = 199 / 99 / 49 by tier.

### `GET /policies/content`
```json
{
  "hero": {
    "badge": "{TIER} TIER",
    "title": "{TIER} Shield Plan",
    "subtitle": "Coverage active in {ZONE}"
  },
  "sections": [
    {"title": "Coverage", "icon_key": "coverage", "body": "..."},
    {"title": "Eligibility", "icon_key": "eligibility", "body": "..."},
    {"title": "Claim Process", "icon_key": "claim_process", "body": "..."},
    {"title": "Payouts", "icon_key": "payouts", "body": "..."},
    {"title": "Exclusions", "icon_key": "exclusions", "body": "..."},
    {"title": "Renewal", "icon_key": "renewal", "body": "..."}
  ]
}
```

### `GET /assist/messages` — pre-seeded per persona
3 messages: bot welcome, user "How does payout work?", bot keyword reply.

### `POST /assist/chat` — keyword router
| Keyword (any case) | Reply |
|---|---|
| `claim` / `apply` | "Tap *Apply Claim* on the dashboard. Most weather/outage claims auto-approve in under 5 minutes." |
| `payout` / `money` | "Approved payouts hit your linked UPI within 5 minutes. We use eNACH on PayU." |
| `premium` / `pay` | "Your weekly premium is ₹{X} — auto-debited every Monday from your UPI." |
| `weather` / `rain` / `flood` | "Yes — IMD/AccuWeather/NASA-GPM oracles run continuously. 3-of-4 consensus triggers auto-claim." |
| `fraud` / `review` | "Fraud detection runs an isolation-forest model + crew-AI guardrails. ESCALATED_TO_HUMAN claims clear within 24h." |
| `status` / `track` | "Tap any claim from the *Claims* tab to see live progress." |
| anything else | "I'm here for claims, payouts, premium and policy questions — try *'how does payout work?'*" |

### `POST /claims` (submit)
`DemoBackend` decides outcome based on reason + flags:
- "Heavy Rain / Waterlogging" / "Severe Weather" → Approved (auto-advance to PAYOUT) unless `killSwitch` then stall at REVIEW.
- "App Outage" / "Platform Outage" → Approved.
- "Vehicle Breakdown" → Rejected with `verification_message: "GPS proximity log shows worker outside disruption zone."`
- "Network Failure" → In Review (stays).
- "Other Disruption" → In Review.

If `fraudFlag` was tripped earlier → the latest claim is force-routed to fraud queue.

---

## Easter Eggs / Backdoor Commands

| # | Gesture | Where | Scenario fired | Visible effect |
|---|---------|-------|----------------|----------------|
| 1 | **4 taps on Continuum logo** | Login screen | `loginAsSudarshan()` | Skips sandbox picker, lands on Home as Platinum-tier driver. |
| 2 | **Long-press Continuum logo** | Login screen | `goToSandbox()` | Opens sandbox persona picker. |
| 3 | **Long-press "CONTINUUM" title** (existing) | Dashboard | `_fireDemoSequence()` | Plays through 5 live triggers, auto-opens claim flow modal at 2 alerts. |
| 4 | **4 taps on user avatar** | Dashboard | `floodAlert()` | Trigger #3 (Municipal Advisory) lights red. Notification "Red Alert: Flood advisory active." After 4s second notification "₹450 credited to UPI" arrives. New auto-claim added. |
| 5 | **3 taps on weekly-premium pill** | Dashboard | `killSwitchTrip()` | Top banner: "PAYOUT_KILL_SWITCH active — payouts paused for safety review." Next manual claim stalls at REVIEW. |
| 6 | **4 taps on plan-status card** | Dashboard | `reserveFloorBreach()` | Plan badge flips SECURE → REVIEW. Notification "Reserve runway 87 days — autopay paused on new policies." |
| 7 | **4 taps on bot avatar (Assist)** | Assist tab | `autoClaimAndPayout()` | Pushes chat bubble "🚨 Disruption near you. Initiating auto-claim…" → 4s later "✅ ₹247 credited to your UPI." Adds auto-claim + 2 notifications. |
| 8 | **4 taps on profile avatar** | Profile screen | `fraudQueueEscalation()` | Notification "⚠ Claim CLM-XXXX routed to fraud review." Latest in-review claim flips to "Under Review — Fraud Queue". |
| 9 | **Long-press profile header** | Profile screen | `resetAll()` | Wipes scripted state. Demo can be re-run cleanly. |
| 10 | **Long-press zone label** | Profile screen | `zoneEnrollmentLock()` | Apply Form returns "Zone temporarily closed for new policies — adverse selection lock active." |
| 11 | **Triple-tap notification bell** | Any screen | `seedDemoNotifications()` | Drops 3 notifications: weather alert, premium debited, claim approved. |
| 12 | **Tap Pay Now** (no gesture, normal flow) | Payments | `premiumDebited()` | Success dialog + "Premium debited ₹{amount}" notification + new payment-history row. |

All wrapped in `EasterEggDetector` so layout is unchanged.

---

## Bad-Path / Failure Simulation (mapped to SPEC invariants)

| # | Scenario | Trigger | SPEC ref |
|---|----------|---------|----------|
| 1 | Rejected claim — outside disruption window | Submit Apply Form with reason "Vehicle Breakdown" | V18 (verification message) |
| 2 | Fraud queue escalation | Backdoor #8 (4-tap profile avatar) | V10, V11, V14, V17 |
| 3 | Kill switch active — payouts paused | Backdoor #5 (3-tap premium pill) | V35, V36 |
| 4 | Reserve floor breach — autopay paused | Backdoor #6 (4-tap plan card) | V37, V47 |
| 5 | Zone enrollment lock — adverse selection | Backdoor #10 (long-press zone label) | V31, C9 |
| 6 | Convergence freeze — 50+ claims/zone/5min | Bundled into fraud-queue path | V10 |
| 7 | Service unavailable retry snackbar | Already wired in every screen — never fires in demo because mock never throws ServerException | I.api |

Each bad-path resolves cleanly: the presenter long-presses the profile header to `resetAll()` and re-runs the script.

---

## End-to-End Demo Script (the user journey we are simulating)

1. **Cold start the app** → Login screen with glowing logo.
2. **Tap "Login with Partner ID (Swiggy/Zomato)"** OR **4-tap logo** → Sandbox picker (3 personas with stats).
3. **Select Sudarshan (Platinum)** → Dashboard. Greeting "Hello, Sudarshan K.". Plan status SECURE, zone Bangalore South, next renewal Apr 10, weekly premium ₹199. 5 monitoring triggers all pulsing green. Earnings chart renders monthly trend. Recent activity shows seeded events.
4. **Long-press CONTINUUM title** → 5 triggers fire red sequentially over ~7s. After 2nd alert, claim-flow modal slides up: 5 verification steps animate (GPS, oracle, policy, fraud, UPI) → ₹247 credited animation. UPI ref `UPI/040426/CONT847291` shown. **Done**.
5. **Tap Claims tab** → 3 seeded + 1 just-added auto-claim. Auto-claim card has indigo gradient, lightning bolt, zero-touch tag, UPI ref. Filter chips work (All / Manual / Auto). Tap any card → detail sheet opens.
6. **Tap Assist tab** → seeded conversation visible. Type "How does payout work?" → keyword-matched bot reply within 500ms.
7. **4-tap bot avatar** (hidden) → second auto-claim plays inline as chat narration + payout notification.
8. **Tap profile avatar (top-left of dashboard)** → Profile. Header shows tier badge, persona name, "Since {registered_at}". Stats: Total Protected ₹24,800, Claims Approved 8. Personal Data rows. Settings → Payments / Edit Profile / Policy Details / Dark Mode toggle.
9. **Toggle Dark Mode** → app re-renders (existing `ThemeProvider`).
10. **Tap Payments** → Plan card (Platinum, ₹199/wk, next renewal). Auto-Pay switch. 2 saved methods (UPI default, Card). Payment history seeded. **Tap Pay Now** → success dialog, notification arrives, new history row prepended.
11. **Back to Profile, tap Policy Details** → 6-section policy card with persona-tailored subtitle.
12. **Back to Dashboard, tap Apply Claim** → Apply Form. Pick "Heavy Rain / Waterlogging", set date, type "Velachery flooded my entire route from 6pm", capture a real photo (camera works on device), record audio (mic works on device), submit.
13. **Status Tracker auto-opens** → progress stepper animates SUBMITTED → REVIEW → APPROVED → PAYOUT over ~12s. Payout card shows expected amount. Verification panel updates message at each stage.
14. **(Optional bad path 1) — claim rejected**: Repeat step 12 with "Vehicle Breakdown" → status shows red header, no payout card, verification message explains.
15. **(Optional bad path 2) — fraud queue**: 4-tap profile avatar before submitting → fraud notification arrives, latest claim flips to "Under Review — Fraud Queue". Detail sheet shows crew-AI audit message.
16. **(Optional bad path 3) — kill switch**: 3-tap premium pill → red banner. Submit a manual claim → stalls at REVIEW with "payouts paused" verification message.
17. **(Optional bad path 4) — reserve floor**: 4-tap plan card → SECURE flips to REVIEW. Notification arrives.
18. **Long-press profile header** → resetAll, demo re-runs cleanly.
19. **Sign Out** → back to login.

---

## Verification

1. **Static**: `flutter analyze` from repo root — no new errors. Run before declaring done.
2. **Cold-start build** (no backend, no `.env`): `flutter run -d chrome` AND `flutter run` on Android emulator. App must:
   - Render login without errors.
   - Successfully reach Home via either login path within 1s of tap.
3. **Per-screen smoke** (manual on emulator):
   - Login → 4-tap logo → lands on Home as Sudarshan within 1s.
   - Dashboard → renders persona name, tier-aware plan, 5 trigger cards, earnings chart, recent activity (≥3 entries).
   - Long-press CONTINUUM → all 5 triggers go red within 7s, claim-flow modal opens, ₹247 success view shows.
   - Claims tab → ≥3 seeded + auto-claim from above; filter chips switch correctly; tap any card → detail sheet opens with all fields populated.
   - Assist → seeded messages visible; sending "payout?" returns deterministic reply within 600ms.
   - Profile → tier badge, total protected > 0, claims approved > 0, history section shows latest claim.
   - Edit Profile → fields pre-filled; save shows success snackbar.
   - Payments → plan card ₹199 not "—", history list ≥3 entries, Pay Now → dialog + notification + new row.
   - Policy → 6 sections rendered.
   - Apply Form → submits without error, routes to Status Tracker, stepper animates through all 4 stages within 15s.
4. **Backdoor smoke** (run in this order on a fresh app):
   - 4-tap login logo → home as Sudarshan.
   - 4-tap dashboard avatar → flood alert + payout notification within 5s.
   - 3-tap weekly-premium pill → kill-switch banner appears.
   - 4-tap plan card → SECURE → REVIEW flip.
   - Tab to Assist → 4-tap bot avatar → chat narration + payout.
   - Tab to Profile → 4-tap avatar → fraud-queue notification + claim flip.
   - Long-press profile header → all flags reset; bell badge clears.
5. **Notifications**: Bell badge increments correctly across all scenarios; dropdown lists items; tapping check mark removes them; clearAll path works.
6. **Re-runnability**: After `resetAll()`, the entire script can be replayed end-to-end without restart.
7. **No CI / unit tests** — visual smoke only; no time for tests.

---

## Out of Scope

- Real backend connectivity (mock layer is permanent for this branch).
- Real FCM push notifications (in-app only).
- Persistence of `DemoOrchestrator` state across cold start (intentional reset).
- Modifying the legacy `lib/screens/` folder (V71 — not on import path).
- Test additions.
