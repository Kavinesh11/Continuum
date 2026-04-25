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
DemoOrchestrator   ←─── scripted scenarios (11 total)
       │
   ┌───┴────────────────────┐
   ▼                        ▼
DemoState              NotificationState
(flags + claim lists)  (per-persona inbox)
       │
       ▼
DemoBackend  ←─── all ApiService calls land here
(persona data, claim store, payout store, assist chat)
       │
       ▼
  UI Widgets  ←─── react via ChangeNotifier / AnimatedBuilder
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
| `lib/services/demo_backend.dart` | Singleton mock backend. Owns all data stores, seeded persona data, claim advancement, and deterministic API responses |
| `lib/state/demo_orchestrator.dart` | Owns all 11 scripted scenarios. Composes DemoState + NotificationState + DemoBackend |
| `lib/state/demo_state.dart` | `ChangeNotifier` holding kill-switch flags, zone lock, reserve breach, and in-session claim lists |
| `lib/state/notification_state.dart` | Per-persona unread notification inbox. `ChangeNotifier` |
| `lib/widgets/easter_egg_detector.dart` | Invisible gesture wrapper that counts N taps within a time window and fires a callback |
| `lib/widgets/demo_banner.dart` | Persistent top-of-screen banner that reacts to DemoState flags |
| `lib/services/api_service.dart` | All public methods delegate to `DemoBackend.instance` — HTTP layer kept but unreachable |

---

## Sandbox personas

Three real-world-inspired driver profiles. The active persona determines all profile data, seeded claims, payouts, risk score, policy content, and premium amounts.

| Persona | Partner ID | Tier | City | Weekly Premium | Coverage Limit | Claims Approved |
|---|---|---|---|---|---|---|
| **Sudarshan K.** | `SWG-9284-912` | Platinum | Bangalore | ₹199 | ₹24,800 | 8 |
| **Dakshina Moorthy** | `ZMT-4471-338` | Gold | Chennai | ₹99 | ₹18,400 | 6 |
| **Sudha P.** | `SWG-7731-556` | Silver | Kolkata | ₹49 | ₹9,200 | 3 |

Switching persona (via Sandbox Selector or Registration flow) re-seeds all claim, payout, and chat stores immediately.

---

## Easter egg gestures (trigger map)

All triggers are invisible — no UI affordance is shown to the audience.

| Location | Gesture | Action |
|---|---|---|
| Login screen logo | 4-tap | Fast-login as Sudarshan (Platinum) |
| Login screen logo | Long-press | Login prompt with partner ID field |
| Dashboard avatar (top-left) | 4-tap | `floodAlert()` — flood advisory notification + auto-payout after 4s |
| Dashboard plan status card | 4-tap | `reserveFloorBreach()` — reserve runway banner + notification |
| Dashboard weekly premium pill | 3-tap | `killSwitchTrip()` — kill switch banner + payout-paused notification |
| Dashboard "CONTINUUM" title | Long-press | Fire 5 scenarios sequentially (flood → outage → auto-claim → fraud → kill switch) |
| Assist bot avatar | 4-tap | `autoClaimAndPayout()` — instant ₹247 auto-approved claim |
| Profile screen header | Long-press | `resetAll()` — wipe all flags, claims, notifications; reseed persona |
| Profile screen avatar | 4-tap | `fraudQueueEscalation()` — activate fraud flag, escalate latest in-review claim |
| Profile screen zone row | Long-press | `zoneEnrollmentLock()` — zone lock banner + notification |
| Notification bell | 3-tap | `seedDemoNotifications()` — inject 3 fresh notifications |

---

## The 11 scenarios

All scenarios live in `DemoOrchestrator`. Each one composes state mutations, claim injections, and notification pushes.

### 1. `floodAlert()`
- Sets trigger alert #2 (Municipal Advisory) in DemoState
- Pushes "Red Alert: Flood advisory active" notification immediately
- After 4 seconds: injects an auto-approved claim for ₹450 with a UPI ref into both DemoState and DemoBackend, pushes "₹450 credited" notification

### 2. `appOutageAlert()`
- Sets trigger alert #1 in DemoState
- Pushes "Platform outage detected" notification for the active persona's platform

### 3. `autoClaimAndPayout()` *(Assist screen backdoor)*
- Immediately injects a ₹247 auto-approved claim (Platform Outage)
- Pushes "₹247 credited" notification

### 4. `fraudQueueEscalation()`
- Sets `DemoBackend.fraudFlagActive = true` (subsequent `submitClaim` calls will produce `ESCALATED_TO_HUMAN` status)
- Finds the latest in-review claim and mutates it to `ESCALATED_TO_HUMAN` status
- Pushes "Claim routed to specialist review" notification

### 5. `killSwitchTrip()`
- Sets `DemoState.killSwitchActive = true`
- DemoBanner renders "PAYOUT_KILL_SWITCH active" in red
- Subsequent claim submissions with weather/outage reasons produce `REVIEW` status instead of `APPROVED`
- Pushes "Payout system under maintenance" notification

### 6. `reserveFloorBreach()`
- Sets `DemoState.reserveFloorBreached = true`
- DemoBanner renders "Reserve runway 87 days" in orange
- Pushes "Coverage status update — Reserve runway at 87 days" notification

### 7. `zoneEnrollmentLock()`
- Sets `DemoState.zoneEnrollmentLocked = true`
- DemoBanner renders "Zone enrollment locked" in orange
- `ApplyForm` checks this flag before submission and shows a snackbar block
- Pushes "Zone enrollment paused" notification

### 8. `premiumDebited()` *(Payments screen Pay Now)*
- Adds a premium debit entry to the payout history in DemoBackend
- Pushes "Premium debited ₹N" notification
- Payments screen prepends the row to the history list and shows a dialog

### 9. `submitManualClaim(reason, description, photos, audio)` *(called from ApplyForm)*
- Checks `DemoState.killSwitchActive` — passes it into the payload
- Calls `DemoBackend.submitClaim` → deterministic outcome based on reason keywords
- Adds result to `DemoState.manualClaims`
- On `APPROVED`: pushes "Claim approved — ₹N incoming" notification
- On `ESCALATED_TO_HUMAN`: pushes specialist review notification
- Returns the claim map (contains `id` for navigation to Status Tracker)

### 10. `seedDemoNotifications()`
- Injects 3 notifications: Weather Alert, Premium Debited, Claim Approved

### 11. `resetAll()`
- Clears all DemoState flags and claim lists
- Clears the active persona's notification inbox
- Resets `fraudFlagActive = false`
- Re-seeds DemoBackend with the current persona's original data
- Re-seeds 2 initial notifications

---

## Claim submission logic (`DemoBackend.submitClaim`)

Outcome is determined by reason keywords + active flags:

| Condition | Status | Amount |
|---|---|---|
| `fraudFlagActive == true` (any reason) | `ESCALATED_TO_HUMAN` | ₹0 |
| reason contains "rain / weather / flood" + kill switch OFF | `APPROVED` (auto) | ₹247 |
| reason contains "rain / weather / flood" + kill switch ON | `REVIEW` | ₹0 |
| reason contains "outage / app" + kill switch OFF | `APPROVED` | ₹180 |
| reason contains "outage / app" + kill switch ON | `REVIEW` | ₹0 |
| reason contains "vehicle / breakdown" | `REJECTED` | ₹0 |
| reason contains "network / failure" | `REVIEW` | ₹0 |
| anything else | `REVIEW` | ₹0 |

Auto-approved claims (rain/weather and outage without kill switch) set `isAuto: true`, which renders the distinctive indigo auto-claim card in the Claims screen.

---

## Auto-advancing claim stages (`_ClaimAdvancer`)

When a claim is submitted with `APPROVED` or `REVIEW` status, a `Timer.periodic(4s)` starts:

```
Step 0 (4s): SUBMITTED → REVIEW
Step 1 (8s): REVIEW → APPROVED (amount = max(existing, 247))
Step 2 (12s): APPROVED → PAYOUT (generates UPI ref, timer stops)
```

The Status Tracker screen polls `ApiService().getClaimStatus(id)` every 4 seconds. The polling stops once `APPROVED` or `REJECTED` is reached. The stepper reads the `complete` boolean per stage from DemoBackend.

---

## Seeded data per persona

Each persona starts with pre-populated history so every screen feels lived-in from the first tap.

**Sudarshan (Platinum)**
- 3 claims: Severe Weather (Approved ₹450), Platform Outage (In Review), Weather+Outage auto-approved (₹247)
- 4 payouts: ₹450, ₹247, ₹199, ₹247 (pending)

**Dakshina (Gold)**
- 3 claims: Heavy Rain (Approved ₹312), App Outage (In Review), Vehicle Breakdown (Rejected)
- 3 payouts: ₹312, ₹99, ₹247 (pending)

**Sudha (Silver)**
- 2 claims: Network Failure (Approved ₹180), Severe Weather auto-approved (₹224)
- 3 payouts: ₹180, ₹224, ₹49

All personas get 2 seed notifications on bootstrap: "Coverage active" and "Premium debited".

---

## Persona switching

**Via Sandbox Selector screen:**
1. `DemoBackend.instance.setDriver(driver)` — re-seeds all stores
2. `DemoOrchestrator.instance.seedInitialNotifications()` — 2 notifications for new persona
3. `DriverProvider.of(context).switchDriver(driver)` — propagates persona down the widget tree
4. Navigate to home

**Via Registration flow (`registration.dart`):**
- Collects name, phone, email, platform, city, partner ID, vehicle type, plan, UPI ID
- Calls `DemoBackend.instance.completeRegistration(...)` which maps plan tier → closest sandbox persona and calls `setDriver`
- Returns a generated policy ID (`POL-PL-XXXXX` format)

**Via login screen (fast-login easter egg):**
- 4-tap logo → sets Sudarshan driver, seeds notifications, navigates directly to home

---

## Profile editing

`EditProfileScreen` calls `ApiService().updateWorkerProfileCurrent(data)` → `DemoBackend.updateWorkerProfile` → stores changes in `_profileOverlay`. Subsequent `getWorkerProfile` calls layer the overlay on top of the persona defaults. Overlay is cleared on `resetAll()` or persona switch.

---

## Assist chat

`AssistsScreen` loads seeded 3-message history (greeting + "how does payout work?" exchange). User messages are keyword-matched:

| Keywords | Bot reply topic |
|---|---|
| claim / apply | How to file a claim, auto-approval timeline |
| payout / money | UPI eNACH disbursement, reference format |
| premium / pay | Weekly debit amount, next renewal date |
| weather / rain / flood | Oracle network, 3-of-4 consensus |
| fraud / review | Isolation-forest model, 24h human review |
| status / track | How to use the Claims tab status tracker |
| *(anything else)* | Scope redirect message |

Bot-avatar 4-tap triggers `autoClaimAndPayout()` mid-conversation.

---

## Policy content

`PlanDetailsScreen` calls `ApiService().getPolicyContent()` → DemoBackend returns a persona-tailored 6-section map:

1. **Coverage** — what events are covered, tier-specific limit
2. **Eligibility** — order history requirements per tier
3. **Claim Process** — step-by-step instructions, auto vs manual timelines
4. **Payouts** — UPI eNACH, PayU, reference format
5. **Exclusions** — vehicle breakdowns, out-of-zone events, fraud
6. **Renewal** — weekly premium amount, next debit date, grace period

Hero card shows: `{Tier} TIER` badge, `{Tier} Shield Plan` title, zone name.

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

## EasterEggDetector

`EasterEggDetector({taps, window, onTrigger, onLongPress, behavior})` wraps any widget invisibly. Internal counter resets if taps are separated by more than `window` (default 2 seconds). Fires `onTrigger` on the Nth tap; `onLongPress` is passed through to the underlying `GestureDetector`.

---

## Key data conventions

DemoBackend uses **camelCase** for claim map keys. All screen code must read these (not snake_case equivalents):

| Key | Meaning |
|---|---|
| `eventType` | Display title for the claim event |
| `statusCode` | Machine-readable status: `SUBMITTED`, `REVIEW`, `APPROVED`, `REJECTED`, `ESCALATED_TO_HUMAN` |
| `progressPct` | Float 0–1 for progress bar |
| `upiRef` | UPI reference string, `null` until payout stage |
| `verificationMsg` | Human-readable status explanation |
| `isAuto` | `true` for oracle-triggered auto-claims |
| `complete` | Boolean per stage in `getClaimStatus` response |

Date strings from seeded data are pre-formatted ("Apr 2, 2026") — they are not ISO-8601. `DateTime.tryParse` will return null for these and the display code passes them through as-is.

---

## Reset procedure (live demo recovery)

**Full reset:** Long-press the gradient header on the Profile screen → `resetAll()` — all flags cleared, all injected claims gone, notification inbox back to 2 seed items, persona data restored to original.

**Partial reset:** Navigate to Sandbox Selector (accessible from the app's debug/sandbox entry point) and tap any persona to reseed that persona's data without changing which persona is active.

---

## How to run the demo (mock-only)

### The mock is always on — no toggle needed

`ApiService` delegates **every** public method directly to `DemoBackend.instance`. There is no feature flag, no environment switch, no `USE_MOCK=true`. The HTTP layer (`_get`, `_post`, `_put`) still compiles but is completely unreachable — no method calls it. You do not need a server, a VPN, or a working `.env` to run the demo.

### Prerequisites

```bash
# Flutter SDK (any recent stable)
flutter --version   # 3.x or later

# Dependencies
flutter pub get
```

You need a `.env` file at the project root (Flutter reads it as an asset). It does not need real values for the demo. Copy the example:

```bash
cp .env.example .env
# No edits required — all backend vars are ignored by the mock layer
```

### Running on a device or emulator

**Android emulator:**
```bash
flutter run
```

**Physical Android device (USB):**
```bash
flutter run
```

**iOS simulator (macOS only):**
```bash
flutter run -d "iPhone 15"
```

**Flutter web (browser):**
```bash
flutter run -d chrome
# or for a specific port:
flutter run -d chrome --web-port 5000
```

No `--dart-define` flags are needed. The `API_HOST` and `USE_NGINX` variables in `.env` are read by `ApiService` but never reached because every call short-circuits into `DemoBackend` before the HTTP helpers are called.

### Confirming the mock is active

On the login screen, enter **any non-empty credentials** (e.g. `test` / `test`) and tap Login. If you land on the dashboard with Sudarshan's data (Platinum tier, HSR Layout, Bangalore), the mock layer is active. No network request is made.

Alternatively, 4-tap the logo on the login screen to skip the form entirely and land directly on Sudarshan's dashboard.

---

## Suggested demo walkthrough

Run this in order for a clean investor/stakeholder presentation. Total time: ~8–10 minutes.

### 1. Boot and choose a persona (30s)

- Launch the app. The login screen appears.
- **4-tap the Continuum logo** → jumps straight to Sudarshan's dashboard (Platinum, Bangalore).
- Or enter any credentials and tap Login.

### 2. Dashboard tour (1 min)

- Point out the coverage card (Platinum Shield Plan, coverage limit, next renewal).
- Point out the DemoBanner area — it is empty, which is the "everything nominal" state.
- Show the recent claims section and weekly earnings.

### 3. Trigger a flood alert + auto-payout (2 min)

- **4-tap the avatar** (top-left of the dashboard header).
- A red "Flood Advisory" notification appears immediately in the bell.
- Wait 4 seconds — a second notification arrives: "₹450 credited to your UPI".
- Navigate to the **Claims** tab → the new Auto-Approved claim appears in indigo with the lightning bolt badge and the UPI reference.
- Tap the claim → Status Tracker shows all four stages completed.

### 4. Submit a manual claim (2 min)

- Tap **Apply Claim** on the dashboard.
- Enter reason: "Heavy rain flooding in delivery zone" → tap Next through the steps → Submit.
- The form navigates to Status Tracker. Watch the stepper advance every 4 seconds: SUBMITTED → REVIEW → APPROVED → PAYOUT (UPI ref appears).
- The bell shows a new "Claim approved" notification.

### 5. Kill-switch demo (1 min)

- Go back to the dashboard.
- **3-tap the weekly premium pill** → the red "PAYOUT_KILL_SWITCH active" banner appears at the top.
- Tap Apply Claim again, enter any weather reason, submit → Status Tracker shows REVIEW (not auto-approved) because the kill switch is active.

### 6. Fraud escalation (1 min)

- Navigate to **Profile**.
- **4-tap the avatar** → the latest in-review claim mutates to "Under Review — Fraud Queue".
- Bell shows "Claim routed to specialist review".
- Go to Claims → the affected claim shows the escalated status.

### 7. Assist chat (1 min)

- Navigate to **Assist**.
- Show the seeded conversation history.
- Type "how does payout work?" — the bot replies with the UPI eNACH details.
- **4-tap the bot avatar** → instant ₹247 auto-claim fires in the background; bell badge increments.

### 8. Persona switch (1 min)

- Navigate to the Sandbox Selector (debug entry point or via route `/sandbox`).
- Tap **Dakshina Moorthy (Gold, Chennai)** → all data reseeds immediately.
- Return to dashboard — plan shows Gold tier, ₹99 weekly premium, Chennai zone.
- Claims tab shows Dakshina's history including the rejected vehicle breakdown claim.

### 9. Reset (30s)

- Navigate to **Profile**.
- **Long-press the gradient header** → `resetAll()` fires.
- All flags clear, all injected claims gone, notifications back to 2 seed items.
- App is clean and ready for the next presenter.

---

## What NOT to do before a demo

- Do not set `API_HOST` to a live server IP in `.env`. It will have no effect on the mock, but the FCM token registration call at startup does use the real `isTokenValid()` check — if a stale token is stored in secure storage from a previous real-login session, the app will attempt one real HTTP call on launch. Clear secure storage if this is a concern (uninstall and reinstall the app).
- Do not run `flutter clean` right before presenting — it forces a full rebuild which takes several minutes.
- Do not leave the kill switch or zone lock banners active between demo segments unless intentional — use the Profile long-press reset between segments.
