# Continuum Admin Dashboard — Easter Egg Guide

All interactive demo triggers built into the dashboard for live presentations.

---

## Global Shell (every page)

| Target | How to trigger | Effect |
|--------|----------------|--------|
| **Bell icon** (top-right header) | Tap **3×** within 1.5s | Seeds 3 demo notifications — reserve alert, claim approval, flood advisory |
| **`v4.0.0`** label (sidebar footer) | Tap **5×** within 2s | **Full reset** — all state reverts to seed data, persona resets to Adjuster, all incidents cleared |
| **Claims Queue** nav item | **Long-press** 600ms | Injects `CLM-RBK-9284`: Sudarshan K. roadblock claim (Koramangala 5th Block). Auto-rejects after 10s with GPS justification |

---

## Home Dashboard (`/`)

| Target | Taps | Effect |
|--------|------|--------|
| **Pending** KPI card | 4× | **Bulk approve wave** — all High/Medium pending claims approved, ₹5,400 cleared, orange banner |
| **Approved** KPI card | 4× | Opens **Payout Audit Trail** overlay with UPI transaction reference codes |
| **Rejected** KPI card | 3× | **Rejection cascade** — injects 2 GPS-rejected claims, increments rejected count |
| **Fraud Flagged** KPI card | 3× | Flags `CLM-9102-54` with fraud score 0.71, fires notification |
| **Reserve Runway** KPI card | 4× | **Reserve floor breach** — runway drops to 31 days, red banner, notification |

---

## Executive Dashboard (`/executive`)

| Target | Taps | Effect |
|--------|------|--------|
| **Benefit-Cost Ratio** card | 4× | Reserve floor breach — runway drops to 31 days, red banner fires |

---

## Claims Queue (`/claims`)

| Target | Taps | Effect |
|--------|------|--------|
| **Adjuster Note** section label (dossier panel) | 4× | Flags the selected driver for fraud — open claim gets score 0.81, escalation notification fires |

---

## Driver Profiles (`/drivers`)

| Target | How to trigger | Effect |
|--------|----------------|--------|
| **Driver name** (detail panel header) | Tap **4×** | Flags that driver for fraud — increments counter, notification fires |
| **Zone label** (detail panel) | **Right-click** | `zoneEnrollmentLock` — closes that zone for new enrollments, amber banner |

---

## Risk Intelligence (`/risk-intelligence`)

Each layer card has a metric value in the top-right corner. Tap it **3 times** to simulate a live incident for that layer.

| Layer | Metric | Simulated incident |
|-------|--------|-------------------|
| **GeoFence Integrity™** | Blocked count | Nithya R. zone-snipe attempt in BLR-North — 6-min pre-trigger GPS jump, 45-min soak not satisfied → **Blocked** |
| **TrustSignal™** | `100%` | AccuWeather TLS certificate mismatch detected, oracle vote nullified, amber banner (6s), 50% benefit-of-doubt cap applied → **Nullified** |
| **IdentityAnchor™** | Blocked count | Kiran P. SIM-swap on enrolled device — payout frozen, re-KYC + OTP required → **Payout Frozen** |
| **ActivityCross™** | ₹ blocked | Priya V. — 2 Zomato deliveries confirmed during claimed disruption window (14:15 and 16:40) → **Vetoed** |
| **FairTime™** | `₹0` | BLR-North outage 02:15–04:45, driver's last order at 22:55 — zero working-hour overlap → **₹0 paid** |

---

## Background Simulation (automatic)

These run continuously without any interaction while the dashboard is open.

| Interval | What fires |
|----------|-----------|
| Every **18s** | New pending claim generated from 6 disruption templates |
| Every **12s** | Oldest low-fraud pending claim auto-approved, UPI notification sent |
| Every **8s** | `totalPayoutToday` and MTD payout figures tick up |
| Every **22s** | Oracle confidence scores nudge ±3%, service latencies shift ±30ms, Kafka lag fluctuates |
| Every **30s** | Notification drip — cycles through the 10-item simulation pool |

---

## Persona Switching

Click the **user avatar in the top-right header** to open the persona switcher dropdown.

| Persona | Role | Nav items visible |
|---------|------|-------------------|
| **Vikram Anand** | CEO / Executive | Dashboard, Executive View, Analytics, Risk Intelligence |
| **Arjun Mehta** | Platform Engineer | Dashboard, Operations, Risk Intelligence |
| **Preethi Nair** | Claims Adjuster | Claims Queue, Driver Profiles, Analytics, Risk Intelligence |
