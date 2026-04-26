"""
zone_enrollment_lock.py
───────────────────────
Simulates adverse-selection detection triggering an enrollment lock on a
high-risk zone — a flood-prone or protest-affected area where claim
frequency has spiked, making continued open enrollment uneconomical.

Demo scenario: BLR-South zone — rolling 7-day claim frequency hits 3.2×
baseline → zone locked → existing partners unaffected → new signups blocked.
"""

import time
import random

BASE_URL      = "http://4.186.27.77:8000/api/simulate"
ZONE          = "BLR-South — Koramangala / HSR"
ZONE_CODE     = "BLR-S-KOR"
TRIGGER_RATIO = 3.2   # current / baseline
BASELINE_FREQ = 0.8   # claims per partner per week (historical)
CURRENT_FREQ  = 2.56  # claims per partner per week (last 7 days)


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


def run_zone_lock():
    print("=" * 60)
    print("  CONTINUUM RISK ENGINE — ZONE ENROLLMENT LOCK")
    print("=" * 60)

    print(f"\n📍 [RISK SCAN] Analysing zone-level claim frequency...")
    time.sleep(1.2)
    print(f"  Zone       : {ZONE}")
    print(f"  Partners   : 284 active")
    print(f"  Baseline   : {BASELINE_FREQ} claims/partner/week (12-month rolling)")
    print(f"  Current    : {CURRENT_FREQ} claims/partner/week (last 7 days)")
    print(f"  Ratio      : {TRIGGER_RATIO}× baseline")
    print(f"  Threshold  : 2.5× — BREACHED ✓")
    time.sleep(0.8)

    print(f"\n🔬 [ROOT CAUSE] Correlating external signals...")
    signals = [
        ("IMD Rainfall (last 7d)",  "142mm",  True,  "⚠ Above seasonal norm (68mm)"),
        ("Road closure reports",    "11",     True,  "⚠ Active BMC flood alerts"),
        ("Platform breakdown rate", "+38%",   True,  "⚠ Swiggy/Zomato slowdown correlated"),
        ("Fraud score (zone avg)",  "0.31",   False, "✓ Within normal range"),
    ]
    for sig, val, flagged, note in signals:
        time.sleep(0.4)
        icon = "🔴" if flagged else "🟢"
        print(f"  {icon} {sig:<32} {val:<10} {note}")

    time.sleep(0.6)
    print(f"\n  → Adverse selection risk confirmed (natural cause, not fraud)")
    print(f"  → Lock type: NEW_ENROLLMENT (existing partners unaffected)")

    print(f"\n🔒 [LOCK ENGINE] Applying enrollment lock to {ZONE_CODE}...")
    ok = post_request("/zone/lock", {
        "zone_code": ZONE_CODE,
        "zone_name": ZONE,
        "lock_type": "new_enrollment",
        "trigger_ratio": TRIGGER_RATIO,
        "baseline_freq": BASELINE_FREQ,
        "current_freq": CURRENT_FREQ,
        "existing_partners": 284,
        "affected_new_signups": True,
        "duration_days": 14,
        "reason": "Adverse selection — claim frequency 3.2× baseline. Flood correlation confirmed.",
    })
    if not ok:
        print("🛑 Zone lock failed.")
        return

    print(f"\n📣 [COMMS] Queuing waitlist notification for zone...")
    post_request("/notification/zone-waitlist", {
        "zone_code": ZONE_CODE,
        "message": f"New enrollment for {ZONE} temporarily paused due to adverse weather. Join waitlist — we'll notify you when it reopens.",
        "estimated_reopen": "14 days",
    })

    post_request("/notification/admin", {
        "type": "zone_lock",
        "message": f"Zone {ZONE} temporarily closed for new policies — adverse selection lock active.",
        "zone_code": ZONE_CODE,
    })

    print(f"\n{'=' * 60}")
    print(f"  🔒 ZONE LOCKED — {ZONE}")
    print(f"  Lock type: new enrollment only  |  Duration: 14 days")
    print(f"  Existing 284 partners: fully protected and unaffected")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_zone_lock()
