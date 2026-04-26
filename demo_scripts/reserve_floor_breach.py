"""
reserve_floor_breach.py
───────────────────────
Simulates the actuarial reserve monitor detecting that the reserve runway
has dropped below the 45-day floor threshold, pausing auto-enrollment
on new policies and alerting the finance team.

Demo scenario: Reserve runway drops to 31 days → breach detected →
autopay paused on new policies → finance alert raised.
"""

import time
import random

BASE_URL          = "http://4.186.27.77:8000/api/simulate"
CURRENT_RUNWAY    = 31          # days
THRESHOLD_RUNWAY  = 45          # days
RESERVE_BALANCE   = 4_120_000   # ₹ current reserve
BURN_RATE_DAILY   = 132_903     # ₹/day


class Response:
    def __init__(self, status_code=200, data=None):
        self.status_code = status_code
        self._data = data or {"message": "success"}

    def json(self):
        return self._data

    @property
    def text(self):
        return str(self._data)


def post_request(endpoint, payload):
    url = f"{BASE_URL}{endpoint}"
    print(f"  🌐 POST {url}")
    print(f"  📦 {payload}")
    time.sleep(1.1)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_reserve_breach():
    print("=" * 60)
    print("  CONTINUUM ACTUARIAL — RESERVE FLOOR MONITOR")
    print("=" * 60)

    print(f"\n📊 [MONITOR] Running daily reserve runway calculation...")
    time.sleep(1.2)
    print(f"  ↳ Current reserve balance  : ₹{RESERVE_BALANCE:,}")
    print(f"  ↳ 7-day avg burn rate      : ₹{BURN_RATE_DAILY:,} / day")
    print(f"  ↳ Projected runway         : {CURRENT_RUNWAY} days")
    print(f"  ↳ Floor threshold          : {THRESHOLD_RUNWAY} days")
    time.sleep(0.8)
    print(f"\n  🔴 BREACH DETECTED — runway {CURRENT_RUNWAY}d < floor {THRESHOLD_RUNWAY}d")

    print(f"\n🚫 [POLICY ENGINE] Suspending autopay on new policy enrollments...")
    time.sleep(1.0)
    zones_paused = [
        "Bangalore South — HSR Layout",
        "Bangalore North — Hebbal",
        "Chennai Central",
        "Hyderabad West",
    ]
    for zone in zones_paused:
        time.sleep(0.4)
        print(f"  🔴 PAUSED | New enrollments — {zone}")
    print(f"  🟢 Unchanged | Existing policies — all zones (no disruption to active partners)")

    ok = post_request("/reserve/breach", {
        "current_runway_days": CURRENT_RUNWAY,
        "threshold_days": THRESHOLD_RUNWAY,
        "reserve_balance": RESERVE_BALANCE,
        "burn_rate_daily": BURN_RATE_DAILY,
        "action_taken": "autopay_new_policies_paused",
        "zones_affected": zones_paused,
    })
    if not ok:
        print("🛑 Breach signal failed to propagate.")
        return

    print(f"\n📋 [REMEDIATION] Generating reserve restoration plan...")
    time.sleep(0.8)
    print(f"  Option A: Premium top-up drive — collect ₹2,800 advance from 200 partners")
    print(f"  Option B: Reinsurance drawdown — trigger ₹6,000,000 XoL treaty layer")
    print(f"  Option C: Reduce parametric payout cap by 15% for 30 days")
    print(f"  → Escalating to CFO + Actuarial for decision (SLA: 24h)")

    print(f"\n🔔 [NOTIFY] Alerting finance and ops teams...")
    post_request("/notification/finance", {
        "type": "reserve_floor_breach",
        "message": "⚠ Reserve runway 31 days — below 45-day floor. Autopay paused on new policies.",
        "runway_days": CURRENT_RUNWAY,
        "reserve_balance": RESERVE_BALANCE,
        "severity": "P2",
    })

    post_request("/notification/admin", {
        "type": "reserve_alert",
        "message": "⚠ Reserve runway 31 days — review autopay.",
    })

    print(f"\n{'=' * 60}")
    print(f"  ⚠ RESERVE BREACH — Runway {CURRENT_RUNWAY}d (floor: {THRESHOLD_RUNWAY}d)")
    print(f"  Action: autopay paused on new enrollments in {len(zones_paused)} zones")
    print(f"  Existing partners: unaffected")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_reserve_breach()
