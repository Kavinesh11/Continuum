"""
bulk_approve_wave.py
────────────────────
Simulates an admin bulk-approve wave — Preethi Nair approves all High and
Medium priority pending claims in one sweep, clearing ₹5,400 to drivers
and resetting the queue to only low-priority residual claims.

Demo scenario: 18 claims approved in 3 seconds → ₹5,400 settled → queue
drops to 5 residual low-priority items.
"""

import time
import random

BASE_URL = "http://4.186.27.77:8000/api/simulate"
ACTOR    = "Preethi Nair"

CLAIMS = [
    ("CLM-9102-41", "Sudarshan K.",  "High",   450,  "Platform Outage"),
    ("CLM-9102-42", "Meena R.",      "High",   380,  "Flood — BLR South"),
    ("CLM-9102-43", "Kiran P.",      "High",   420,  "App Crash > 4h"),
    ("CLM-9102-44", "Deepa L.",      "Medium", 290,  "Vehicle Breakdown"),
    ("CLM-9102-45", "Ramesh T.",     "Medium", 310,  "Bandh — Bangalore"),
    ("CLM-9102-46", "Anjali S.",     "Medium", 350,  "Platform Outage"),
    ("CLM-9102-47", "Vijay M.",      "High",   480,  "Flood — BLR North"),
    ("CLM-9102-48", "Priya K.",      "Medium", 260,  "Vehicle Breakdown"),
    ("CLM-9102-49", "Sanjay R.",     "High",   410,  "App Crash > 4h"),
    ("CLM-9102-50", "Lakshmi D.",    "Medium", 340,  "Bandh — Chennai"),
    ("CLM-9102-51", "Mohan G.",      "Medium", 300,  "Platform Outage"),
    ("CLM-9102-52", "Kavitha P.",    "High",   390,  "Flood — HYD West"),
    ("CLM-9102-53", "Rajan N.",      "Medium", 270,  "Vehicle Breakdown"),
    ("CLM-9102-55", "Sunita V.",     "Medium", 330,  "App Crash > 4h"),
    ("CLM-9102-56", "Arun B.",       "High",   460,  "Platform Outage"),
    ("CLM-9102-57", "Geetha S.",     "Medium", 280,  "Bandh — Pune"),
    ("CLM-9102-58", "Harish K.",     "High",   420,  "Flood — CHN Central"),
    ("CLM-9102-59", "Nalini R.",     "Medium", 360,  "Vehicle Breakdown"),
]


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
    time.sleep(0.5)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_bulk_approve():
    print("=" * 60)
    print("  CONTINUUM ADMIN — BULK APPROVE WAVE")
    print("=" * 60)

    total = sum(c[3] for c in CLAIMS)
    print(f"\n👩‍💼 [{ACTOR}] Initiating bulk approve for {len(CLAIMS)} claims...")
    time.sleep(0.8)
    print(f"  ↳ Priority filter: High + Medium")
    print(f"  ↳ Total payout   : ₹{total:,}")
    print(f"  ↳ Claims count   : {len(CLAIMS)}")

    print(f"\n⚡ [CLAIM ENGINE] Processing approvals...")
    approved = 0
    payout = 0
    for cid, driver, priority, amount, reason in CLAIMS:
        time.sleep(0.15)
        print(f"  ✅ {cid:<14} {driver:<16} {priority:<8} ₹{amount}  — {reason}")
        approved += 1
        payout += amount

    print(f"\n  → {approved} claims approved  |  ₹{payout:,} queued for settlement")

    print(f"\n💸 [SETTLEMENT] Batching UPI payouts via PayU eNACH...")
    ok = post_request("/payout/batch", {
        "actor": ACTOR,
        "approved_count": approved,
        "total_amount": payout,
        "priority_filter": ["High", "Medium"],
        "gateway": "PayU eNACH",
        "batch_ref": f"BATCH/BULK/{int(time.time()) % 100000}",
    })
    if not ok:
        print("🛑 Batch payout failed.")
        return

    print(f"\n🔔 [NOTIFY] Pushing settlement notifications to drivers...")
    post_request("/notification/bulk-push", {
        "count": approved,
        "message": "Your claim has been approved and ₹{amount} has been credited to your UPI account.",
        "type": "bulk_approval",
    })

    print(f"\n📊 [AUDIT] Logging bulk approval event...")
    post_request("/audit/log", {
        "actor": ACTOR,
        "action": "BULK_APPROVED",
        "target": f"{approved} claims",
        "details": f"Wave approved — ₹{payout:,} cleared to {approved} drivers. Queue: 5 residual (Low priority).",
    })

    print(f"\n{'=' * 60}")
    print(f"  ✅ WAVE DONE — ₹{payout:,} cleared to {approved} drivers")
    print(f"  Queue: 5 residual low-priority claims remain")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_bulk_approve()
