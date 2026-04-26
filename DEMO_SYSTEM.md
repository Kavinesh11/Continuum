# Continuum — Demo Guide

> **The single reference for running the Continuum demo.** Read this before any investor, stakeholder, or pilot presentation. Every screen, trigger, and edge case is covered.

---

## What Continuum is

Continuum is a gig-worker income-protection platform for Swiggy/Zomato delivery partners in India. It pays out instantly when an oracle network detects a disruption event (flood, bandh, app outage) — no manual claim filing required. This demo shows the complete lifecycle: real-time disruption detection → parametric payout → admin review → partner notification.

---

## Quick-start (5 minutes to demo-ready)

### Flutter app

```bash
# Clone and install
flutter pub get

# Copy env (no edits needed for mock-only demo)
cp .env.example .env

# Optional: add your Gemini API key for real AI responses in Assist chat
# GEMINI_API_KEY=your_key_here

# Run on device
flutter run

# Or web
flutter run -d chrome --web-port 5000
```

Login: **SWG-9284** / **Continuum@2026** — or **4-tap the logo** to skip the form.

### Admin dashboard (optional — enables live Approve/Reject)

```bash
cd admin_dash
npm install
npm run dev    # http://localhost:3000
```

The Flutter app routes manual/fraud claims to `https://admin-dash-kappa.vercel.app` by default — no config needed for the live Vercel demo.

**For local admin dev:** set `ADMIN_BRIDGE_URL=http://localhost:3000` in the Flutter `.env` file to point at your local `npm run dev` instance instead.

---

## The three personas

| Persona | Partner ID | Tier | Platform | City | Zone | Weekly Premium | Coverage |
|---|---|---|---|---|---|---|---|
| **Sudarshan K.** | `SWG-9284` | Platinum | Swiggy + Zomato | Bangalore | HSR Layout | ₹199/wk | ₹24,800 |
| **Dakshina Moorthy** | `ZMT-4471-338` | Gold | Swiggy + Zomato | Chennai | Anna Nagar | ₹99/wk | ₹18,400 |
| **Sudha P.** | `SWG-7731-556` | Silver | Swiggy only | Kolkata | Ballygunge | ₹49/wk | ₹9,200 |

### What each persona sees in their Assist chat

All three have full persona-aware AI context. Gemini (or the mock fallback) knows their exact claim history, UPI references, policy details, renewal dates, and tier-specific coverage rules.

**Sudarshan (Platinum):** 8 approved claims. Active: Severe Weather approved ₹450 (CLM-9824-21), Platform Outage in review (CLM-9102-54). Instant oracle auto-approval. Ask: "where is my flood payout?" or "what's under review?"

**Dakshina (Gold):** 6 approved claims. Active: Heavy Rain approved ₹312 (CLM-7711-08), App Outage in review (CLM-7611-22), Vehicle Breakdown rejected — GPS outside zone (CLM-7322-90). Ask: "why was my claim rejected?" or "when will my outage claim resolve?"

**Sudha (Silver):** 3 approved claims. Active: Network Failure approved ₹180 (CLM-5510-44), Severe Weather auto-approved ₹224 (CLM-5388-19). Bandh/cyclone NOT covered on Silver. Ask: "when does my policy renew?" or "am I covered for bandh?"

### Switching personas

- **Sandbox Selector:** Long-press the logo on the login screen → choose a persona → seeded data swaps immediately.
- **Sign Up flow:** Tap "New to Continuum? Sign Up" on the login screen → 4-step registration → plan tier maps to closest sandbox persona.
- **Registration flow:** Complete registration → plan tier maps to closest sandbox persona.
- **Fast-path:** 4-tap logo on login → direct to Sudarshan (Platinum).

---

## All easter egg triggers

> These are invisible — never point at them. Activate them naturally mid-conversation.

### Flutter app

| Where | Gesture | What happens |
|---|---|---|
| Login screen logo | **4-tap** | Fast-login as Sudarshan — bypasses form entirely |
| Login screen logo | **Long-press** | Open Sandbox Selector (persona picker) |
| Dashboard avatar (top-left) | **Long-press** | `floodAlert()` — flood advisory + ₹450 auto-payout after 4s |
| Dashboard "Live Triggers" header | **Tap** | Navigate to Oracle Engine screen |
| Dashboard "Live Triggers" header | **Long-press** | `bandhAlert()` — bandh advisory + ₹380 auto-payout after 4s |
| Dashboard plan status card | **Long-press** | `reserveFloorBreach()` — reserve runway banner |
| Dashboard weekly premium pill | **3-tap (3s)** | `killSwitchTrip()` — kill switch banner, payouts paused |
| Dashboard "CONTINUUM" title | **Long-press** | Fire 5 scenarios sequentially (flood → outage → claim → fraud → kill switch) |
| Dashboard "Track Claim" button | **Tap** | Status Tracker for most recent claim |
| Assist bot avatar (shared counter) | **4-tap total** | `autoClaimAndPayout()` — injects ₹247 auto-approved claim |
| Assist phone icon (AppBar) | **Tap** | Voice Agent call bottom sheet |
| Status Tracker payout card | **Long-press** | `forceApprove(claimId)` — instantly approves claim + UPI ref in 600ms |
| Claims "My Claims" heading | **Long-press** | `autoClaimAndPayout()` — injects new auto-approved claim |
| New Claim AppBar title | **Long-press** | Prefill form with flood scenario data |
| Profile header (gradient) | **Long-press** | `resetAll()` — full reset to clean state |
| Profile avatar | **Long-press** | `fraudQueueEscalation()` — fraud flag + escalate claim to admin |
| Profile zone row | **Long-press** | `zoneEnrollmentLock()` — zone lock banner |
| Notification bell | **Tap** | Open full Notifications screen |
| Notification bell | **Long-press** | Seed 3 demo notifications |

### Admin dashboard (localhost:3000)

| Where | Gesture | What happens |
|---|---|---|
| **Pending** stat card | **4-tap** | `bulkApproveWave()` — approves all queued claims, adds ₹5,400 to payout total |
| **Approved** stat card | **4-tap** | Shows Payout Audit Trail overlay (UPI refs, amounts, timestamps) |
| **Rejected** stat card | **3-tap** | `claimRejectionCascade()` — injects 2 GPS-rejected claims |
| **Fraud** stat card | **3-tap** | `fraudFlagging()` — flags CLM-9102-54 with isolation-forest score 0.71 |
| **Reserve Runway** operations card | **4-tap** | `reserveFloorBreach()` — runway drops to 31 days, red alert banner |
| Notification bell (header) | **3-tap** | `seedDemoNotifications()` — 3 fresh notifications |
| **Preethi Nair** (user name, header) | **5-tap** | `killSwitchTrip()` — kill switch trips, banner appears |
| **v4.0.0 / DEMO** (footer) | **5-tap** | `resetAll()` — full admin state reset |

---

## Suggested demo walkthrough (~12 minutes)

### 1. Boot and login (30s)

Launch the app. Enter **SWG-9284** / **Continuum@2026** — or **4-tap the logo** for the fast path. Sudarshan's Platinum dashboard loads instantly.

> New users can tap **"New to Continuum? Sign Up"** to walk through the 4-step registration flow. Image uploads are optional — tap the upload button a second time to soft-bypass each step.

> *"This is Sudarshan — a Platinum-tier delivery partner in Bangalore. He's been with us since January 2024 and has ₹24,800 of income protection active right now."*

---

### 2. Dashboard tour (1 min)

- Coverage card: Platinum Shield Plan, ₹24,800, next renewal date.
- Earnings chart: toggle Weekly/Monthly/Yearly — Platinum tier data.
- 4 Quick Actions: Track Claim, Pay Now, View Policy, View Data (→ Oracle Engine).
- Live Triggers section: 5 oracle source cards showing real-time monitoring.

> *"The platform is always watching — IMD weather feeds, AccuWeather, NASA GPM rainfall, CPCB air quality, and platform status from DownDetector. When 3 of 5 sources agree, an event is declared and claims auto-fire."*

---

### 3. Zero-touch flood payout (2 min)

**Long-press the dashboard avatar (top-left).**

- OS-style banner slides in from the top: *"Red Alert — Flood advisory Zone 4B. Parametric coverage activated."*
- Wait 4 seconds: *"₹450 credited to your UPI account. Ref: UPI/020426/CONT847291."*
- Navigate to **Claims** → the auto-approved claim is there with a lightning bolt (oracle auto-approval badge).
- Tap the claim → Status Tracker shows all four stages completed with UPI reference.

> *"No form. No photos. No waiting. The oracle declared the event, cross-checked GPS data, and settled ₹450 directly to UPI — in under 5 minutes."*

---

### 4. Zero-touch bandh payout (2 min)

Return to Dashboard. **Long-press the "Live Triggers" section header.**

- Banner: *"Bandh advisory — Zone 4B. Parametric coverage is now active."*
- After 4 seconds: *"Bandh payout credited — ₹380."*
- Claims tab now shows both the ₹450 flood and ₹380 bandh claims.

> *"Bandh, cyclones, app outages — all handled parametrically. Sudarshan didn't have to do anything."*

---

### 5. Manual claim + live admin review (2 min)

Tap **Apply Claim**. **Long-press "New Claim" in the AppBar** to prefill the form.

- Tap Submit → Status Tracker shows "In Progress" (REVIEW).
- Switch to **admin dashboard** (localhost:3000) → claim appears in the amber **Priority Queue** section.
- The claim shows: driver name, tier pill, zone, amount, reason, description excerpt.
- Click **Approve ₹X** → within 4 seconds Flutter's Status Tracker updates to APPROVED, payout processes, notification arrives.

> *"For edge cases that need human review, the oracle routes them here. The admin can see everything — tier, zone, claim history — and approve in one click."*

---

### 6. Oracle Engine deep-dive (1 min)

Tap the "Live Triggers" header (or **View Data** quick action).

- 5 data source cards: IMD India, AccuWeather, NASA-GPM, CPCB AQI, DownDetector.
- Confidence bars, last reading, per-source latency.
- Consensus stepper: already at "Consensus Reached" from the flood trigger.
- ML model: IsoForest-XGB Ensemble v2.4 — 94.7% accuracy, SHAP-backed decisions.

> *"The model weights weather severity at 34%, GPS proximity at 28%, platform status at 19%. Every payout is explainable — we can show exactly why it fired."*

---

### 7. Fraud escalation (1 min)

Navigate to **Profile**. **Long-press the avatar.**

- Fraud flag activates; latest in-review claim mutates to "Under Review — Specialist Queue."
- Switch to admin dashboard → claim appears with **ESCALATED** badge and fraud score 0.81.
- Notification bell badge increments.

> *"High-risk claims are automatically routed to specialist review with a fraud score. The oracle's isolation-forest model flags anomalies before any payout fires."*

---

### 8. Assist AI chat (1 min)

Navigate to **Assist**. Type naturally:

- *"Where is my flood claim?"* → responds with CLM-9824-21 and ₹450 UPI reference.
- *"When does my policy renew?"* → gives exact renewal date and premium.
- *"What's covered under my plan?"* → tier-specific coverage rules.

**4-tap the bot avatar** → instant ₹247 auto-claim fires mid-conversation.

Tap the phone icon → Voice Agent call sheet.

> *"Every partner has a dedicated AI that knows their exact claim history, renewal date, and coverage tier — no generic chatbot."*

---

### 9. Kill switch (30s, optional)

Return to Dashboard. **3-tap the weekly premium pill.**

- Red banner: *"PAYOUT_KILL_SWITCH active — payouts paused for safety review."*
- Submit any claim → stays at REVIEW (auto-approval disabled).

> *"We have a live kill switch for compliance incidents. One gesture pauses all automated payouts system-wide."*

---

### 10. Payments screen (30s)

**Profile → Payments.** UPI handle: `swg9284@okaxis` (persona-specific). Tap Pay Now → premium debit appears. Filter Credits / Debits.

---

### 11. Reset (30s)

Navigate to **Profile**. **Long-press the gradient header.** All flags clear, injected claims gone, notifications back to 2 seed items. App is clean for the next presenter.

---

## Admin dashboard layout

The admin dashboard (`localhost:3000`) has four clear sections:

### Stats strip
Four KPI cards across the top:
- **Pending** (amber) — 4-tap → `bulkApproveWave()`
- **Approved** (emerald) — 4-tap → Payout Audit overlay
- **Rejected** (red) — 3-tap → `claimRejectionCascade()`
- **Fraud** (amber) — 3-tap → `fraudFlagging()`

### Priority Queue
Only visible when Flutter-submitted claims are pending. Amber-bordered section with:
- Claim ID, driver name, tier pill (Platinum/Gold/Silver), zone, reason, amount
- FRAUD and ESCALATED badges when applicable
- **Approve ₹X** button (uses tier default when amount is 0) or **Reject** (expands inline text input for reason)

### Operations row
- **Reserve Runway** — turns red if < 60 days. 4-tap → `reserveFloorBreach()`.
- **Zones Active** — zones with live coverage.
- **Total Payout Today** — running total + avg per claim.

### Activity section (2 columns)
- **Recent Claims table** (left): last 8 claims — ID, Driver+Tier, Zone, Status badge, Amount.
- **Audit Timeline** (right): last 6 actions as a color-coded timeline (emerald=approved, red=rejected).

### Sidebar
- Teal-900 with nav icons for Dashboard, Claims Queue, Analytics, Driver Profiles.
- Active page: left-border accent + highlighted background.
- Footer: `v4.0.0` + **DEMO** badge. 5-tap → `resetAll()`.
- Header: Preethi Nair (Claims Reviewer). 5-tap her name → `killSwitchTrip()`. 3-tap bell → seed notifications.

---

## Architecture overview

```
Presenter gestures
       │
       ▼
DemoOrchestrator   ←─── 13 scripted scenarios
       │
   ┌───┴────────────────────┐
   ▼                        ▼
DemoState              NotificationState
(flags + claim lists)  (per-persona inbox + toasts)
       │
       ▼
DemoBackend  ←─── all ApiService calls land here
       │
       ├── manual/fraud claims ──► HTTP POST → admin_dash /api/claims
       │                            (falls back to local store if offline)
       └── getClaimStatus ─────► HTTP GET → admin_dash /api/claims/:id
                                    (falls back to local store)

Admin dashboard (Next.js)
  DemoProvider polls /api/claims every 4s
  approveClaim / rejectClaim → PATCH /api/claims/:id
  Flutter Status Tracker picks up status on next 4s poll
```

### URL configuration

The admin bridge URL is managed by `lib/config/app_config.dart` (`AppConfig.adminBridgeUrl`).

**Default (no `.env` needed):** `https://admin-dash-kappa.vercel.app`

To override for local dev, add to `.env`:
```
ADMIN_BRIDGE_URL=http://localhost:3000
```

Both `demo_backend.dart` and `demo_orchestrator.dart` pick it up automatically via `AppConfig.adminBridgeUrl`.

The admin dashboard's internal `/api/claims` routes are relative Next.js routes — they auto-resolve on Vercel, no URL config needed in `admin_dash`.

---

## Core files

| File | Role |
|---|---|
| `lib/services/demo_backend.dart` | Mock backend singleton. All persona data, seeded claims, payouts, oracle status, claim submission logic, admin bridge HTTP calls |
| `lib/state/demo_orchestrator.dart` | All 13 scenarios. Composes DemoState + NotificationState + DemoBackend |
| `lib/state/demo_state.dart` | Kill-switch flags, zone lock, reserve breach, trigger alerts, in-session claim lists (`ChangeNotifier`) |
| `lib/state/notification_state.dart` | Per-persona notification inbox + toast sequence (`ChangeNotifier`) |
| `lib/config/app_config.dart` | `AppConfig.adminBridgeUrl` — reads `ADMIN_BRIDGE_URL` from dotenv, fallback to `https://admin-dash-kappa.vercel.app` |
| `lib/services/gemini_service.dart` | Gemini 2.0 Flash chat. Injects full persona-aware RAG system context. Keyword mock fallback if no API key |
| `lib/services/api_service.dart` | Every public method delegates to `DemoBackend.instance` — HTTP layer unreachable |
| `lib/widgets/notification_toast.dart` | OS-style sliding banner overlay. Auto-dismisses 3.8s, tap → Notifications screen |
| `lib/widgets/easter_egg_detector.dart` | Invisible N-tap gesture wrapper with time window |
| `lib/widgets/demo_banner.dart` | Kill switch / reserve breach / zone lock persistent banners on Dashboard |
| `lib/screens/new/registration.dart` | Registration flow — `completeRegistration()` maps plan → persona. Image uploads are optional (soft bypass on second tap) |
| `lib/screens/new/oracle_engine.dart` | Oracle Network screen — 5 source cards, consensus stepper, auto-event feed |
| `lib/screens/new/notifications_screen.dart` | Full notifications — filter chips, swipe-to-dismiss, mark-all-read |
| `admin_dash/src/app/page.tsx` | Admin dashboard — 4-section layout, all 7 easter egg triggers |
| `admin_dash/src/components/admin-shell.tsx` | Sidebar with nav icons + active indicator, notification bell, user identity triggers |
| `admin_dash/src/components/demo-provider.tsx` | React context — polls /api/claims, manages all admin scenario state |
| `admin_dash/src/components/easter-egg-detector.tsx` | Same N-tap pattern as Flutter, for admin triggers |
| `admin_dash/src/app/api/claims/route.ts` | In-memory bridge store. GET all claims, POST new from Flutter |
| `admin_dash/src/app/api/claims/[id]/route.ts` | GET single claim, PATCH approve/reject (auto-fills tier default amounts) |

---

## The 13 scenarios

### 1. `floodAlert()`
Sets trigger alert in DemoState. Pushes "Red Alert: Flood advisory" notification. After 4s: injects auto-approved ₹450 claim + "₹450 credited" notification.
**Trigger:** Long-press dashboard avatar.

### 2. `bandhAlert()`
Sets trigger alert. Pushes "Bandh advisory — Zone 4B". After 4s: injects ₹380 Bandh / General Strike claim + "₹380 credited" notification.
**Trigger:** Long-press "Live Triggers" section header.

### 3. `appOutageAlert()`
Sets trigger alert. Pushes "Platform outage detected" for the active persona's platform.

### 4. `autoClaimAndPayout()`
Immediately injects ₹247 auto-approved Platform Outage claim. Pushes "₹247 credited" notification.
**Trigger:** 4-tap Assist bot avatar, or long-press "My Claims" heading.

### 5. `fraudQueueEscalation()`
Sets `fraudFlagActive = true`. Mutates latest in-review claim to `ESCALATED_TO_HUMAN`. HTTP-POSTs to admin bridge with `isFraud: true`, `fraudScore: 0.81`, `priority: 'High'`.
**Trigger:** Long-press Profile avatar.

### 6. `killSwitchTrip()`
Sets `killSwitchActive = true`. DemoBanner shows red "PAYOUT_KILL_SWITCH active". Subsequent manual claims stay at REVIEW.
**Trigger:** 3-tap dashboard premium pill. Also available in admin header (5-tap user name).

### 7. `reserveFloorBreach()`
Sets `reserveFloorBreached = true`. DemoBanner shows orange "Reserve runway 87 days". Pushes "Coverage status update" notification.
**Trigger:** Long-press plan status card. Also available in admin Operations row (4-tap Reserve Runway card).

### 8. `zoneEnrollmentLock()`
Sets `zoneEnrollmentLocked = true`. DemoBanner shows orange "Zone enrollment locked". `ApplyForm` blocks submission.
**Trigger:** Long-press Profile zone row.

### 9. `premiumDebited()`
Adds premium debit entry to payout history. Pushes "Premium debited ₹N" notification.
**Trigger:** Payments screen "Pay Now".

### 10. `submitManualClaim(reason, description, photos, audio)`
Called from ApplyForm. Manual submissions always start as `REVIEW`. Posted to admin bridge. `_ClaimAdvancer` does NOT auto-advance manual claims — they wait for admin Approve. Vehicle Breakdown → `REJECTED`.

### 11. `forceApprove(claimId)`
Instantly sets claim to `APPROVED` + generates UPI ref. Pushes "Claim approved" notification.
**Trigger:** Long-press payout card on Status Tracker.

### 12. `seedDemoNotifications()`
Injects 3 notifications: Weather Alert, Premium Debited, Claim Approved.
**Trigger:** Long-press notification bell.

### 13. `resetAll()`
Clears all flags, claim lists, notification inbox. Resets `fraudFlagActive`. Re-seeds persona data. Re-seeds 2 initial notifications.
**Trigger:** Long-press Profile gradient header. Also available in admin sidebar footer (5-tap version tag).

---

## Claim submission logic

| Condition | Status | Amount |
|---|---|---|
| `fraudFlagActive == true` | `ESCALATED_TO_HUMAN` | ₹0 |
| Manual + vehicle/breakdown | `REJECTED` | ₹0 |
| Manual + any other reason | `REVIEW` → posted to admin bridge | per tier on approve |
| Oracle rain/flood + kill switch OFF | `APPROVED` (auto) | ₹247 |
| Oracle rain/flood + kill switch ON | `REVIEW` | ₹0 |
| Oracle outage + kill switch OFF | `APPROVED` (auto) | ₹180 |
| Oracle outage + kill switch ON | `REVIEW` | ₹0 |
| Oracle breakdown | `REJECTED` | ₹0 |

**Key rule:** All manual form submissions start as REVIEW regardless of reason. Only oracle-triggered (`isAuto == true`) calls auto-approve.

Auto-approved oracle claims advance via `_ClaimAdvancer` timer: SUBMITTED (0s) → REVIEW (4s) → APPROVED (8s) → PAYOUT + UPI ref (12s).

---

## Seeded data per persona

**Sudarshan K. (Platinum, Bangalore — HSR Layout)**
- Partner ID: `SWG-9284-912` | Member since: Jan 2024 | Next renewal: Apr 10, 2026
- Claims: CLM-9824-21 Severe Weather (Approved ₹450, UPI/020426/CONT847291), CLM-9102-54 Platform Outage (In Review), CLM-8833-12 Weather auto-approved (₹247, UPI/220326/CONT829130)
- Payouts: ₹450, ₹247, ₹199, ₹247 (pending)
- Weekly: ₹454 across 6/7 orders (86% completion)

**Dakshina Moorthy (Gold, Chennai — Anna Nagar)**
- Partner ID: `ZMT-4471-338` | Member since: Mar 2023 | Next renewal: Apr 8, 2026
- Claims: CLM-7711-08 Heavy Rain (Approved ₹312, UPI/010426/CONT711082), CLM-7611-22 App Outage (In Review), CLM-7322-90 Vehicle Breakdown (Rejected — GPS outside zone)
- Payouts: ₹312, ₹99, ₹247 (pending)
- Weekly: ₹320 across 5/6 orders (83% completion)

**Sudha P. (Silver, Kolkata — Ballygunge)**
- Partner ID: `SWG-7731-556` | Member since: Jun 2024 | Next renewal: Apr 12, 2026
- Claims: CLM-5510-44 Network Failure (Approved ₹180, UPI/300326/CONT551044), CLM-5388-19 Severe Weather (Auto-Approved ₹224, UPI/200326/CONT538819)
- Payouts: ₹180, ₹224, ₹49
- Weekly: ₹183 across 4/5 orders (80% completion)

All personas get 2 seed notifications on bootstrap: "Coverage active" and "Premium debited".

---

## Tier coverage matrix

| Event | Silver | Gold | Platinum |
|---|---|---|---|
| Heavy rain / waterlogging | ✅ | ✅ | ✅ |
| App outage (Swiggy) | ✅ | ✅ | ✅ |
| App outage (Zomato) | ❌ | ✅ | ✅ |
| Network failure | ✅ | ✅ | ✅ |
| Bandh / general strike | ❌ | ✅ | ✅ |
| Roadblock / road closure | ❌ | ✅ | ✅ |
| Cyclone / severe storm | ❌ | ✅ | ✅ |
| Municipal advisory | ❌ | ✅ | ✅ |
| Curfew / Section 144 | ❌ | ❌ | ✅ |
| Vehicle breakdown | ❌ | ❌ | ❌ (GPS zone required) |

Oracle auto-approval speed: Silver 24–48h review · Gold 4–12h priority · Platinum instant (<5 min)

---

## Assist chat — Gemini + persona RAG

`GeminiService` injects a full system context per request built from `DemoBackend.instance.activeDriver`:

- Partner ID, tier, city, zone, platform, member since
- Policy: coverage limit, weekly premium, next renewal, claims approved count
- Full claims history with status, amounts, and UPI references
- Recent payouts (last 3)
- Weekly earnings, completion rate, order count
- Tier-specific covered events + NOT covered events

With `GEMINI_API_KEY` set, responses come from Gemini 2.0 Flash. Without a key, a keyword mock provides persona-specific replies for:

| Topic | Example question |
|---|---|
| Flood / weather | "Where is my flood claim?" |
| App outage | "Is Swiggy down?" |
| Rejected / breakdown | "Why was my claim rejected?" |
| Claim status | "What's in review?" |
| Payout / UPI | "When will I get paid?" |
| Payout timing | "How long do payouts take?" |
| Filing a claim | "How do I file a claim?" |
| What is Continuum | "What is Continuum?" / "How does this work?" |
| Oracle network | "How does oracle work?" / "How does it auto-detect?" |
| Tier comparison | "Silver vs Gold vs Platinum?" / "Which plan is better?" |
| Auto-debit / eNACH | "How does auto-debit work?" / "When is my next debit?" |
| Premium / renewal | "When does my policy renew?" |
| Coverage rules | "Am I covered for bandh?" |
| Zone / earnings | "What zone am I in?" |

All mock responses are persona-specific — they reference the active driver's actual tier, premium, UPI handle, renewal date, and claim history.

To enable real Gemini:
```
GEMINI_API_KEY=your_key   # in .env
```

---

## Policy screen

Navigate via the **View Policy** quick action on the dashboard.

- **Overview card:** Active tier pill, zone (truncates gracefully on narrow screens), shield plan label, total coverage amount.
- **Risk Recalculation:** Tap "Run Risk Recalculation" → 5 factors animate sequentially (driving hours, claim history, weather risk, zone density, oracle accuracy) → result card shows calculated premium and savings.
- **History chart:** Animated bar chart showing 4-week premium history. Bars render after recalculation completes — value labels are clamped so they never clip above the canvas.
- **FAQs section:** 5 expandable FAQ tiles covering coverage events, claim timelines, oracle triggers, auto-debit, and zone changes.

---

## Oracle Engine screen

Tap "Live Triggers" header (Dashboard) or "View Data" Quick Action.

- **5 source cards:** IMD India, AccuWeather, NASA-GPM, CPCB AQI, DownDetector
- **Consensus stepper:** animates 1-of-4 → 2-of-4 → 3-of-4 → CONSENSUS when alerts fire
- **Auto-event feed:** oracle-triggered claims filtered from DemoBackend
- **ML model:** IsoForest-XGB Ensemble v2.4 — accuracy 0.947, precision 0.931, recall 0.962
- **Feature weights:** weather_severity 0.34, gps_proximity 0.28, platform_status 0.19, historical_freq 0.12, zone_risk 0.07
- **SHAP top factor:** weather_severity_score = 0.81, prediction confidence 0.94

Long-press the Oracle header card → `floodAlert()`.

---

## DemoBanner flags

| Flag | Color | Message |
|---|---|---|
| `killSwitchActive` | Red | "PAYOUT_KILL_SWITCH active — payouts paused for safety review" |
| `reserveFloorBreached` | Orange | "Reserve runway 87 days — autopay paused on new policies" |
| `zoneEnrollmentLocked` | Orange | "Zone enrollment locked — adverse selection guard active" |

All three can stack simultaneously. Banners clear on `resetAll()`.

---

## What NOT to do before a demo

- **Don't set `API_HOST` to a live server.** The mock intercepts everything, but a stale token in secure storage may cause one real HTTP call at boot. Uninstall/reinstall if concerned.
- **Don't `flutter clean` right before presenting.** It forces a full rebuild.
- **Don't leave flags active between segments.** Profile header long-press resets everything in seconds.
- **Don't add `GEMINI_API_KEY` without testing it first.** The keyword mock is reliable and covers all expected audience questions.
- **Don't run `npm run build`** right before presenting — dev mode is faster to start.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| App launches but shows blank/loading | Run `flutter pub get`, then `flutter run` again |
| Claims don't appear in admin dashboard | By default the app posts to `https://admin-dash-kappa.vercel.app` — open that URL and check the Priority Queue. For local dev, set `ADMIN_BRIDGE_URL=http://localhost:3000` in `.env` and run `npm run dev`. |
| Gemini chat gives generic responses | API key is missing or empty — that's fine, keyword mock is active |
| Persona data looks wrong after switch | Long-press Profile header → `resetAll()`, then switch persona again via Sandbox Selector |
| Admin dashboard showing old claims from previous run | 5-tap the version tag (bottom of sidebar) → `resetAll()` |
| Easter egg doesn't fire | Tap count resets if taps are too slow. Retry within the time window (2–3s for most triggers) |
