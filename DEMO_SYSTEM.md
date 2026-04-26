# Continuum — Demo Simulation System

A fully self-contained, offline presentation layer for the Continuum Flutter app. No backend server required. Every screen, flow, and data point is driven by a local mock stack that mirrors the real API contract exactly.

---

## Why it exists

The app needs to be demo-able to investors, pilots, and internal stakeholders without a live backend. The simulation layer intercepts every `ApiService` call and returns persona-aware, deterministic data with realistic latency. Presenters can walk through every screen, trigger edge-case scenarios via hidden gestures, and reset to a clean state in seconds.

---

## Architecture overview

```
Presenter gestures
       │
       ▼
DemoOrchestrator   ←─── scripted scenarios (13 total)
       │
   ┌───┴────────────────────┐
   ▼                        ▼
DemoState              NotificationState
(flags + claim lists)  (per-persona inbox + toast seq)
       │
       ▼
DemoBackend  ←─── all ApiService calls land here
(persona data, claim store, payout store, oracle status)
       │
       ▼
  UI Widgets  ←─── react via ChangeNotifier / AnimatedBuilder
       │
       ▼
NotificationToastLayer  ←─── OS-style sliding banner overlay
```

### Admin Bridge (optional — for live admin dashboard demo)

When `admin_dash/` is running at `localhost:3000`, manual and fraud claims are mirrored in real time:

```
Flutter DemoBackend.submitClaim()
  ├─ manual / fraud → HTTP POST http://localhost:3000/api/claims  (try/catch)
  └─ falls back to local store if Next.js not running

Flutter DemoBackend.getClaimStatus()
  ├─ HTTP GET http://localhost:3000/api/claims/:id  (try/catch)
  └─ returns local store status if API unreachable

Next.js API Bridge (admin_dash/src/app/api/claims/)
  GET  /api/claims       → all claims sorted by submittedAt desc
  POST /api/claims       → create new pending claim (Flutter-submitted)
  GET  /api/claims/[id]  → single claim
  PATCH /api/claims/[id] → { action: 'approve'|'reject', reason? } → updates status

Admin Dashboard — DemoProvider (admin_dash/src/components/demo-provider.tsx)
  • Polls /api/claims every 4s, merges Flutter-submitted claims into React state
  • approveClaim() / rejectClaim() → PATCH /api/claims/:id + update local state
```

All four singletons are bootstrapped in `main.dart` before `runApp`:

```dart
DemoBackend.instance.bootstrap();
DemoOrchestrator.instance.bootstrap(); // also seeds initial notifications
```

---

## Core files

| File | Role |
|---|---|
| `lib/services/demo_backend.dart` | Singleton mock backend. Owns all data stores, seeded persona data, claim advancement, oracle status, and deterministic API responses |
| `lib/state/demo_orchestrator.dart` | Owns all 13 scripted scenarios. Composes DemoState + NotificationState + DemoBackend |
| `lib/state/demo_state.dart` | `ChangeNotifier` holding kill-switch flags, zone lock, reserve breach, trigger alerts, and in-session claim lists |
| `lib/state/notification_state.dart` | Per-persona unread notification inbox. `ChangeNotifier`. Also carries `toastSeq`/`toastItem` for the OS-style banner |
| `lib/widgets/notification_toast.dart` | `NotificationToastLayer` — Stack overlay that slides a banner in from the top on every new notification. Stays 3.8s, tap to open Notifications screen |
| `lib/widgets/easter_egg_detector.dart` | Invisible gesture wrapper that counts N taps within a time window (default 3s) and fires a callback |
| `lib/widgets/demo_banner.dart` | Persistent top-of-screen banner that reacts to DemoState flags |
| `lib/widgets/notification_action.dart` | Bell icon with badge dot. Tap → Notifications screen. Long-press → seed 3 demo notifications |
| `lib/services/api_service.dart` | All public methods delegate to `DemoBackend.instance` — HTTP layer kept but unreachable |
| `lib/services/gemini_service.dart` | Gemini 2.0 Flash chat client with persona-aware RAG system context. Falls back to keyword mock if `GEMINI_API_KEY` is absent |
| `lib/screens/new/oracle_engine.dart` | Oracle Network screen — 5 source cards, consensus stepper, auto-event feed |
| `lib/screens/new/notifications_screen.dart` | Full notifications screen with filter chips (All/Claims/Payouts/Alerts), swipe-to-dismiss, mark-all-read |
| `admin_dash/src/app/api/claims/route.ts` | In-memory bridge store (`claimsStore` Map). GET all claims, POST new claim from Flutter |
| `admin_dash/src/app/api/claims/[id]/route.ts` | GET single claim, PATCH approve/reject; auto-fills payout by tier (Platinum ₹450, Gold ₹312, Silver ₹180) |
| `admin_dash/src/app/page.tsx` | Next.js admin dashboard — "Pending Review" amber section, inline Approve/Reject, KPI cards with easter eggs |

---

## Sandbox personas

Three real-world-inspired driver profiles. The active persona determines all profile data, seeded claims, payouts, risk score, policy content, premium amounts, earnings chart data, and payment method labels.

| Persona | Partner ID | Tier | City | Weekly Premium | Coverage Limit | Claims Approved |
|---|---|---|---|---|---|---|
| **Sudarshan K.** | `SWG-9284` | Platinum | Bangalore | ₹199 | ₹24,800 | 8 |
| **Dakshina Moorthy** | `ZMT-4471-338` | Gold | Chennai | ₹99 | ₹18,400 | 6 |
| **Sudha P.** | `SWG-7731-556` | Silver | Kolkata | ₹49 | ₹9,200 | 3 |

Switching persona (via Sandbox Selector or Registration flow) re-seeds all claim, payout, and chat stores immediately.

---

## Easter egg gestures (trigger map)

All triggers are invisible — no UI affordance is shown to the audience. Long-press gestures are used on prominent elements (they look accidental); tap-count gestures remain only on small elements where they're harder to notice.

| Location | Gesture | Action |
|---|---|---|
| Login screen logo | 4-tap | Fast-login as Sudarshan (Platinum) — bypasses form entirely |
| Login screen logo | Long-press | Open Sandbox Selector (persona picker) |
| Dashboard avatar (top-left) | Long-press | `floodAlert()` — flood advisory + auto-payout ₹450 after 4s |
| Dashboard plan status card | Long-press | `reserveFloorBreach()` — reserve runway banner |
| Dashboard weekly premium pill | 3-tap (3s window) | `killSwitchTrip()` — kill switch banner + payout-paused |
| Dashboard "CONTINUUM" title | Long-press | Fire 5 scenarios sequentially (flood → outage → auto-claim → fraud → kill switch) |
| **Dashboard "Live Triggers" header** | **Tap** | **Navigate to Oracle Engine screen** |
| **Dashboard "Live Triggers" header** | **Long-press** | **`bandhAlert()` — bandh advisory + auto-payout ₹380 after 4s** |
| Dashboard "Track Claim" button | Tap | Navigate to Status Tracker with most recent claim ID |
| **Assist bot avatar (shared counter)** | **4-tap total (any bubbles)** | **`autoClaimAndPayout()` — single shared counter, fires exactly once** |
| Assist phone icon (AppBar) | Tap | Voice Agent call bottom sheet |
| Status tracker payout card | Long-press | `forceApprove(claimId)` — instantly advances to APPROVED + UPI ref in 600ms |
| Claims "My Claims" heading | Long-press | `autoClaimAndPayout()` — injects new auto-approved claim |
| **Profile screen header** | **Long-press** | **`resetAll()` — wipe all flags, claims, notifications; reseed persona** |
| **Profile screen avatar** | **Long-press** | **`fraudQueueEscalation()` — fraud flag + escalate latest in-review claim** |
| Profile screen zone row | Long-press | `zoneEnrollmentLock()` — zone lock banner |
| **Notification bell** | **Tap** | **Navigate to full Notifications screen** |
| **Notification bell** | **Long-press** | **`seedDemoNotifications()` — inject 3 fresh notifications** |
| **New Claim title (AppBar)** | **Long-press** | **Prefill form with flood scenario demo data** |

---

## The 13 scenarios

All scenarios live in `DemoOrchestrator`. Each composes state mutations, claim injections, and notification pushes.

### 1. `floodAlert()` — *zero-touch flood scenario*
- Sets trigger alert #2 (Municipal Advisory) in DemoState
- Pushes "Red Alert: Flood advisory active" notification immediately
- After 4 seconds: injects an auto-approved claim for ₹450 with a UPI ref into both DemoState and DemoBackend; pushes "₹450 credited" notification
- **Easter egg:** Long-press the dashboard avatar (top-left)

### 2. `bandhAlert()` — *zero-touch bandh scenario* *(NEW)*
- Sets trigger alert #3 in DemoState
- Pushes "Bandh advisory — Zone 4B" notification immediately
- After 4 seconds: injects an auto-approved claim for ₹380 (Bandh / General Strike) with a UPI ref; pushes "₹380 credited" notification
- Uses a different claim type, amount, and oracle narrative from `floodAlert`
- **Easter egg:** Long-press the "Live Triggers" section header on the dashboard

### 3. `appOutageAlert()`
- Sets trigger alert #1 in DemoState
- Pushes "Platform outage detected" notification for the active persona's platform

### 4. `autoClaimAndPayout()` *(Assist screen backdoor)*
- Immediately injects a ₹247 auto-approved claim (Platform Outage)
- Pushes "₹247 credited" notification

### 5. `fraudQueueEscalation()`
- Sets `DemoBackend.fraudFlagActive = true` (subsequent `submitClaim` calls produce `ESCALATED_TO_HUMAN`)
- Finds the latest in-review claim and mutates it to `ESCALATED_TO_HUMAN` status
- **HTTP-POSTs the claim to the admin bridge** with `isFraud: true`, `fraudScore: 0.81`, `priority: 'High'` — claim appears in the admin Pending Review queue flagged as ESCALATED
- Pushes "Claim routed to specialist review" notification

### 6. `killSwitchTrip()`
- Sets `DemoState.killSwitchActive = true`
- DemoBanner renders "PAYOUT_KILL_SWITCH active" in red
- Subsequent manual claim submissions produce `REVIEW` status (no auto-approval)
- Pushes "Payout system under maintenance" notification

### 7. `reserveFloorBreach()`
- Sets `DemoState.reserveFloorBreached = true`
- DemoBanner renders "Reserve runway 87 days" in orange
- Pushes "Coverage status update" notification

### 8. `zoneEnrollmentLock()`
- Sets `DemoState.zoneEnrollmentLocked = true`
- DemoBanner renders "Zone enrollment locked" in orange
- `ApplyForm` checks this flag before submission and blocks with a snackbar

### 9. `premiumDebited()` *(Payments screen Pay Now)*
- Adds a premium debit entry to the payout history
- Pushes "Premium debited ₹N" notification

### 10. `submitManualClaim(reason, description, photos, audio)` *(called from ApplyForm)*
- Passes `_isManual: true` + kill-switch flag into `DemoBackend.submitClaim`
- Manual submissions always start as `REVIEW` ("In Progress"). They are **posted to the admin bridge** (`/api/claims`) and remain at REVIEW until an admin clicks Approve in the dashboard. The `_ClaimAdvancer` only fires for `isAuto == true` oracle claims.
- Vehicle Breakdown reason still produces `REJECTED`
- Adds result to `DemoState.manualClaims`; navigates to Status Tracker with claim ID
- On `ESCALATED_TO_HUMAN`: pushes specialist review notification

### 11. `forceApprove(claimId)` *(Status Tracker easter egg)*
- Immediately sets the given claim to `APPROVED` + generates UPI ref
- Mirrors update into DemoState.manualClaims if present
- Pushes "Claim approved" notification
- **Easter egg:** Long-press the payout card on the Status Tracker screen

### 12. `seedDemoNotifications()`
- Injects 3 notifications: Weather Alert, Premium Debited, Claim Approved

### 13. `resetAll()`
- Clears all DemoState flags and claim lists
- Clears the active persona's notification inbox
- Resets `fraudFlagActive = false`
- Re-seeds DemoBackend with the current persona's original data
- Re-seeds 2 initial notifications

---

## Claim submission logic (`DemoBackend.submitClaim`)

Outcome is determined by the `_isManual` flag first, then reason keywords + active flags:

| Condition | Status | Amount |
|---|---|---|
| `fraudFlagActive == true` (any) | `ESCALATED_TO_HUMAN` | ₹0 |
| `_isManual == true` + vehicle/breakdown reason | `REJECTED` | ₹0 |
| `_isManual == true` (all other reasons) | `REVIEW` → posted to admin bridge; advances only when admin approves | per tier |
| reason "rain / weather / flood" + kill switch OFF | `APPROVED` (auto) | ₹247 |
| reason "rain / weather / flood" + kill switch ON | `REVIEW` | ₹0 |
| reason "outage / app" + kill switch OFF | `APPROVED` | ₹180 |
| reason "outage / app" + kill switch ON | `REVIEW` | ₹0 |
| reason "vehicle / breakdown" | `REJECTED` | ₹0 |
| reason "network / failure" | `REVIEW` | ₹0 |
| anything else | `REVIEW` | ₹0 |

**Key rule:** All manual form submissions start as REVIEW regardless of weather/rain keywords. Only oracle-triggered (non-manual) calls auto-approve based on reason.

---

## Auto-advancing claim stages (`_ClaimAdvancer`)

When an **oracle-triggered (`isAuto == true`) claim** is submitted with `APPROVED` status, a `Timer.periodic(4s)` starts. Manual REVIEW claims are not auto-advanced — they wait for admin approval via the bridge.

```
Step 0 (4s):  SUBMITTED → REVIEW (progressPct 0.5)
Step 1 (8s):  REVIEW → APPROVED (amount = max(existing, 247))
Step 2 (12s): APPROVED → PAYOUT (generates UPI ref, timer stops)
```

The Status Tracker polls `ApiService().getClaimStatus(id)` every 4 seconds. Polling stops once `APPROVED` or `REJECTED` is reached.

---

## New claim reasons (India-specific)

The Apply Form now includes 10 reasons, including India-specific disruption types:

| Reason | Auto-approved (oracle) | Manual outcome |
|---|---|---|
| Heavy Rain / Waterlogging | ✅ ₹247 | REVIEW → APPROVED |
| **Bandh / General Strike** | via `bandhAlert()` only | REVIEW → APPROVED |
| **Roadblock / Road Closure** | — | REVIEW → APPROVED |
| **Cyclone / Severe Storm** | — | REVIEW → APPROVED |
| **Municipal Advisory** | — | REVIEW → APPROVED |
| **Curfew / Section 144** | — | REVIEW → APPROVED |
| App Outage (Swiggy/Zomato) | ✅ ₹180 | REVIEW → APPROVED |
| Network Failure | — | REVIEW |
| Vehicle Breakdown | — | REJECTED |

---

## Earnings chart — per-persona data

The dashboard earnings trend chart is now persona-aware. Data is selected based on the active driver's tier:

| Tier | Yearly (last payout) | Monthly (peak) | Weekly (peak) |
|---|---|---|---|
| **Platinum** (Sudarshan) | ₹48,900 | ₹5,800 | ₹950 |
| **Gold** (Dakshina) | ₹29,600 | ₹3,500 | ₹680 |
| **Silver** (Sudha) | ₹17,800 | ₹2,100 | ₹420 |

Data is defined in `_trendByTier` (static const map) in `dashboard.dart`. Switch persona → chart reloads automatically on next build.

---

## Assist chat — Gemini 2.0 Flash + RAG

`GeminiService` (`lib/services/gemini_service.dart`) powers the Assist chat:

- **System context (RAG):** Injected per-request, built from the active driver's tier, zone, city, platform, premium, and claims count. The model knows what's covered and what isn't.
- **Model:** `gemini-2.0-flash` via REST API
- **API key:** Read from `.env` → `GEMINI_API_KEY`. If empty/absent, falls back to a keyword-match mock reply.
- **Chat history:** Full conversation history is sent on every request (up to session length).
- **Typing indicator:** 3-dot bouncing animation shows while awaiting the model response.
- **Fallback mock keywords:** `claim`, `coverage`, `payout`, `bandh/strike`, `status/track`

Bot-avatar 4-tap still triggers `autoClaimAndPayout()` mid-conversation.

To enable real Gemini responses:
```bash
# In .env:
GEMINI_API_KEY=your_gemini_api_key_here
```

---

## Payments screen

- **Per-persona UPI handle:** Derived from driver's partner ID (`swg9284@okaxis`, etc.)
- **Per-persona card last-4:** Derived deterministically from partner ID hash
- **Add Method sheet:** Tapping "Add new" opens a bottom sheet with UPI / Credit-Debit Card / Net Banking options (each shows "coming soon" snackbar)
- **Transaction type:** Payouts show `+₹` in green; premium debits show `-₹` in red
- **Filter tabs:** All / Credits / Debits above the transaction history list

---

## Notifications system

### OS-style toast banner (`NotificationToastLayer`)
- Wraps the HomeShell `Scaffold` in a `Stack`
- Listens to `NotificationState.toastSeq` (increments on every `addNotification` call)
- Slides in from the top with `SlideTransition(Offset(0,-1))` + fade
- Auto-dismisses after 3.8 seconds; tap navigates to Notifications screen
- Icon and color are derived from notification title keywords (claim=green, payout=blue, alert=orange)

### Full Notifications screen (`/notifications`)
- Filter chips: All / Claims / Payouts / Alerts (derived from title keywords)
- `Dismissible` cards (swipe-to-dismiss = mark as read)
- "Mark all read" `TextButton` in AppBar
- Empty state with centered icon

### Profile screen bell
- Notification bell is embedded in the gradient header (frosted-glass style, white icon)
- Shows red badge dot when unread notifications exist
- Tap → Notifications screen; Long-press → seed 3 demo notifications

---

## Oracle Engine screen (`/oracle`)

Accessible by tapping the "Live Triggers" header on the dashboard or the "View Data" Quick Action button.

- **Header card:** Gradient, shows "Monitoring" or "Consensus Reached" with pulsing dot. Long-press → `floodAlert()`.
- **5 oracle source cards:** IMD India, AccuWeather, NASA-GPM, CPCB AQI, DownDetector — each shows status chip, last reading, and confidence bar.
- **Consensus stepper:** Animates 1-of-4 → 2-of-4 → 3-of-4 → CONSENSUS when alerts fire.
- **Auto-event feed:** Recent auto-triggered claims from DemoBackend (filtered to `isAuto == true`).
- Listens to `DemoState.instance` for reactive reload when alerts fire.

**ML model data** (from `DemoBackend.getOracleStatus`):
- Model: `IsoForest-XGB Ensemble v2.4` — accuracy 0.947, precision 0.931, recall 0.962
- Top 5 features: Weather severity (0.34), GPS proximity (0.28), Platform status (0.19), Historical frequency (0.12), Zone risk (0.07)
- SHAP top factor: "weather_severity_score = 0.81"
- Prediction confidence: 0.94, anomaly score: 0.23
- 5 data sources with per-source latency (ms) and `records_last_hour` counts

---

## Admin Dashboard (`admin_dash/`)

A Next.js 14 admin interface running at `localhost:3000` alongside the Flutter demo. Optional — the Flutter demo is fully self-contained without it, but the bridge unlocks live approve/reject interactions.

### Running

```bash
cd admin_dash
npm install
npm run dev    # starts on http://localhost:3000
```

### Features

- **KPI cards** — Pending Queue, Approved Today, Rejected Today, Fraud Flagged, Reserve Runway, Zones Active, Avg Payout, Total Payout Today
- **Pending Review section** — amber-highlighted section appears when Flutter-submitted manual/fraud claims arrive. Each card shows claim ID, tier badge, driver name, reason, description (truncated), zone, amount, FRAUD badge (fraudScore > 0.7), ESCALATED badge (isFraud).
- **Inline approve/reject** — Approve button shows payout amount (tier default when amount is 0). Reject opens an inline text input for the rejection reason.
- **Recent Claims table** — last 8 claims with hover states, status badges, and tier sub-rows
- **Audit Log** — last 5 actions; APPROVED entries shown in green, REJECTED in red
- **Payout Audit overlay** — 4-tap "Approved Today" KPI → slide-up sheet with UPI references

### Easter egg triggers (admin dashboard)

| Gesture | Action |
|---|---|
| 4-tap Pending Queue | `bulkApproveWave()` — approves all high/medium priority claims, adds ₹5,400 to payout total |
| 4-tap Approved Today | Shows Payout Audit Trail overlay |
| 3-tap Rejected Today | `claimRejectionCascade()` — injects 2 GPS-rejected claims |
| 3-tap Fraud Flagged | `fraudFlagging()` — flags CLM-9102-54 with isolation-forest score 0.71 |
| 4-tap Reserve Runway | `reserveFloorBreach()` — sets runway to 31 days, triggers reserve alert banner |

### Seeded claims (initial state)

8 claims across BLR-South, CHN-Central, and KOL-South zones for Sudarshan K., Dakshina Moorthy, and Sudha P. — names, zones, and amounts match the Flutter app's persona data exactly.

---

## Seeded data per persona

Each persona starts with pre-populated history so every screen feels lived-in from the first tap.

**Sudarshan (Platinum)**
- 3 claims: Severe Weather (Approved ₹450), Platform Outage (In Review), Weather auto-approved (₹247)
- 4 payouts: ₹450, ₹247, ₹199, ₹247 (pending)

**Dakshina (Gold)**
- 3 claims: Heavy Rain (Approved ₹312), App Outage (In Review), Vehicle Breakdown (Rejected)
- 3 payouts: ₹312, ₹99, ₹247 (pending)

**Sudha (Silver)**
- 2 claims: Network Failure (Approved ₹180), Severe Weather auto-approved (₹224)
- 3 payouts: ₹180, ₹224, ₹49

All personas get 2 seed notifications on bootstrap: "Coverage active" and "Premium debited".

---

## Login credentials

The standard login form requires exact credentials:

| Field | Value |
|---|---|
| Worker ID | `SWG-9284` |
| Password | `Continuum@2026` |

A subtle hint is shown below the Sign In button on the login screen.

**Fast-path (demo shortcut):** 4-tap the Continuum logo on the login screen → bypasses the form, directly loads Sudarshan's Platinum profile.

---

## Persona switching

**Via Sandbox Selector screen:**
1. `DemoBackend.instance.setDriver(driver)` — re-seeds all stores
2. `DemoOrchestrator.instance.seedInitialNotifications()` — 2 notifications for new persona
3. `DriverProvider.of(context).switchDriver(driver)` — propagates persona down the widget tree
4. Navigate to home

**Via Registration flow (`registration.dart`):**
- Collects name, phone, email, platform, city, partner ID, vehicle type, plan, UPI ID
- Calls `DemoBackend.instance.completeRegistration(...)` which maps plan tier → closest sandbox persona

**Via login screen:**
- Standard form: `SWG-9284` / `Continuum@2026` → Sudarshan persona
- 4-tap logo: fast-path directly to Sudarshan

---

## Profile editing

`EditProfileScreen` calls `ApiService().updateWorkerProfileCurrent(data)` → `DemoBackend.updateWorkerProfile` → stores changes in `_profileOverlay`. Subsequent `getWorkerProfile` calls layer the overlay on top of the persona defaults. Overlay is cleared on `resetAll()` or persona switch.

---

## Policy content

`PlanDetailsScreen` calls `ApiService().getPolicyContent()` → DemoBackend returns a persona-tailored 6-section map:

1. **Coverage** — what events are covered, tier-specific limit
2. **Eligibility** — order history requirements per tier
3. **Claim Process** — step-by-step instructions, auto vs manual timelines
4. **Payouts** — UPI eNACH, PayU, reference format
5. **Exclusions** — vehicle breakdowns, out-of-zone events, fraud
6. **Renewal** — weekly premium amount, next debit date, grace period

---

## DemoBanner

Always rendered at the top of the Dashboard body column. Listens to `DemoState` via `AnimatedBuilder`. Shows stacked banners when multiple flags are active simultaneously:

| Flag | Color | Text |
|---|---|---|
| `killSwitchActive` | Red | "PAYOUT_KILL_SWITCH active — payouts paused for safety review" |
| `reserveFloorBreached` | Orange | "Reserve runway 87 days — autopay paused on new policies" |
| `zoneEnrollmentLocked` | Orange | "Zone enrollment locked — adverse selection guard active" |

Renders nothing (`SizedBox.shrink`) when all flags are false.

---

## Key data conventions

DemoBackend uses **camelCase** for claim map keys:

| Key | Meaning |
|---|---|
| `eventType` | Display title for the claim event |
| `statusCode` | Machine-readable status: `SUBMITTED`, `REVIEW`, `APPROVED`, `REJECTED`, `ESCALATED_TO_HUMAN` |
| `progressPct` | Float 0–1 for progress bar |
| `upiRef` | UPI reference string, `null` until payout stage |
| `verificationMsg` | Human-readable status explanation |
| `isAuto` | `true` for oracle-triggered auto-claims |
| `claim_description` | Free-text description submitted by the user |
| `complete` | Boolean per stage in `getClaimStatus` response |

Date strings from seeded data are pre-formatted ("Apr 2, 2026") — not ISO-8601. `DateTime.tryParse` will return null for these and display code passes them through as-is.

---

## Reset procedure (live demo recovery)

**Full reset:** Long-press the gradient header on the Profile screen → `resetAll()` — all flags cleared, all injected claims gone, notification inbox back to 2 seed items, persona data restored to original.

**Partial reset:** Navigate to Sandbox Selector and tap any persona to reseed that persona's data.

---

## How to run the demo (mock-only)

### The mock is always on — no toggle needed

`ApiService` delegates **every** public method directly to `DemoBackend.instance`. There is no feature flag, no environment switch, no `USE_MOCK=true`. The HTTP layer still compiles but is completely unreachable — no method calls it. You do not need a server, a VPN, or a working `.env` to run the demo.

### Prerequisites

```bash
# Flutter SDK (3.x stable or later)
flutter --version

# Dependencies
flutter pub get
```

Copy the example env file (no edits needed for the mock):

```bash
cp .env.example .env
# Optional: add GEMINI_API_KEY= for real Gemini responses in Assist chat
# All other backend vars are ignored by the mock layer
```

### Running

```bash
# Android emulator or physical device
flutter run

# iOS simulator (macOS)
flutter run -d "iPhone 15"

# Flutter web
flutter run -d chrome --web-port 5000
```

### Confirming the mock is active

On the login screen, enter `SWG-9284` / `Continuum@2026` and tap Sign In. If you land on the dashboard with Sudarshan's Platinum data (HSR Layout, Bangalore, ₹199/week), the mock layer is active. No network request is made.

Alternatively, 4-tap the Continuum logo to skip the form entirely.

---

## Suggested demo walkthrough

Run this in order for a clean investor/stakeholder presentation. Total time: ~10–12 minutes.

### 1. Boot and login (30s)

- Launch the app. The login screen appears with a subtle hint below the button.
- Enter **SWG-9284** / **Continuum@2026** and tap Sign In — or **4-tap the logo** to jump directly.
- Sudarshan's Platinum dashboard loads.

### 2. Dashboard tour (1 min)

- Point out the coverage card (Platinum Shield Plan, ₹24,800 coverage, next renewal).
- Show the earnings chart — Platinum tier data, toggle between Weekly/Monthly/Yearly.
- Show the 4 Quick Action buttons: Track Claim, Pay Now, View Policy, and **View Data** (→ Oracle Engine).
- Show the Live Triggers section with 5 oracle cards monitoring in real time.

### 3. Zero-touch flood scenario (2 min)

- **Long-press the dashboard avatar** (top-left profile photo).
- An OS-style banner slides in from the top: "Red Alert — Flood advisory Zone 4B".
- Wait 4 seconds — a second banner: "₹450 credited to your UPI".
- Navigate to the **Claims** tab → the auto-approved claim appears in indigo with the lightning bolt badge.
- Tap it → Status Tracker shows all four stages completed with UPI reference.

### 4. Zero-touch bandh scenario (2 min)

- Return to the Dashboard.
- **Long-press the "Live Triggers" section header**.
- Banner: "Bandh advisory — Zone 4B. Parametric coverage is now active."
- After 4 seconds: "Bandh payout credited — ₹380. UPI Ref: ..."
- Navigate to Claims → the ₹380 Bandh / General Strike claim appears alongside the flood claim.
- Point out: two different zero-touch triggers, different reasons, different amounts, same oracle-speed settlement.

### 5. Submit a manual claim (2 min)

- Tap **Apply Claim** on the dashboard.
- **Long-press "New Claim" in the AppBar** → form auto-fills with flood scenario data.
- Tap Submit → navigates to Status Tracker showing "In Progress" (REVIEW). The claim is **simultaneously posted to the admin bridge**.
- Switch to the **admin dashboard** (`localhost:3000`) → the claim appears in the amber "Pending Review" section with Approve/Reject buttons.
- Click **Approve** in the admin dashboard → within 4 seconds (next Flutter poll), the Status Tracker updates to APPROVED and the payout processes.
- Bell badge increments; tap it → full Notifications screen with filter chips.

### 6. Oracle Engine (1 min)

- Return to Dashboard, tap the "Live Triggers" header (or tap **View Data** in Quick Actions).
- Oracle Network screen shows 5 data source cards (IMD, AccuWeather, NASA-GPM, CPCB, DownDetector).
- Show the confidence bars and consensus stepper — already at "Consensus Reached" from the flood trigger.
- Mention the ML model: IsoForest-XGB Ensemble — 94.7% accuracy, 5 weighted features, SHAP-backed decisions.

### 7. Kill-switch demo (1 min)

- Return to Dashboard.
- **3-tap the weekly premium pill** → red "PAYOUT_KILL_SWITCH active" banner appears.
- Tap Apply Claim, submit any weather reason → Status Tracker stays at REVIEW (auto-approval blocked).

### 8. Fraud escalation (1 min)

- Navigate to **Profile**.
- Note the notification bell in the top-right (frosted glass, white).
- **Long-press the avatar** → fraud flag activates; latest in-review claim mutates to "Under Review — Fraud Queue". The claim is also posted to the admin bridge with `isFraud: true`.
- Switch to the admin dashboard → claim appears in Pending Review with the ESCALATED badge and fraud score 0.81.
- Bell badge shows the new notification; tap → Notifications screen with the escalation entry.

### 9. Assist chat (1 min)

- Navigate to **Assist**.
- Type "what does my coverage include?" → Gemini responds with persona-aware coverage details (or keyword mock if no API key).
- Typing indicator (3 bouncing dots) shows while awaiting response.
- **4-tap the bot avatar across any bubbles** → instant ₹247 auto-claim fires; banner slides in.
- Tap the phone icon → Voice Agent call sheet with pulsing animation.

### 10. Payments (30s)

- Navigate to **Profile → Payments**.
- UPI handle shows Sudarshan's persona-specific ID (`swg9284@okaxis`).
- Tap Pay Now → dialog confirms payment; transaction history shows `-₹199` in red.
- Filter to "Debits" → only premium payments. Filter to "Credits" → only payouts.
- Tap "Add new" → bottom sheet with UPI / Card / Net Banking options.

### 11. Reset (30s)

- Navigate to **Profile**.
- **Long-press the gradient header** → `resetAll()` fires.
- All flags clear, all injected claims gone, notifications back to 2 seed items.
- App is clean and ready for the next presenter.

---

## What NOT to do before a demo

- Do not set `API_HOST` to a live server IP — it has no effect on the mock, but a stale auth token in secure storage may trigger one real HTTP call at startup. Uninstall/reinstall the app if this is a concern.
- Do not run `flutter clean` right before presenting — forces a full rebuild.
- Do not leave kill switch or zone lock banners active between segments — use the Profile header long-press reset between segments.
- Do not add `GEMINI_API_KEY` to `.env` right before a demo unless you have tested it — the mock fallback is reliable and covers all expected audience questions.
