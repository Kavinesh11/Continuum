"""
premium_debit.py
────────────────
Simulates the weekly eNACH auto-debit cycle — Continuum pulls weekly
premiums from all active partner UPI handles, updates policy balances,
and sends payment confirmation notifications.

Demo scenario: Weekly Sunday 06:00 IST debit run for BLR-South zone →
3 partners debited → reserve updated → receipts pushed.
"""

import time
import random

BASE_URL  = "http://4.186.27.77:8000/api/simulate"
BATCH_REF = f"ENACH/WEEKLY/{int(time.time()) % 100000}"
RUN_DATE  = "2024-01-21"  # Sunday


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
    time.sleep(0.9)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


PARTNERS = [
    {
        "id":         "SWG-9284-912",
        "name":       "Sudarshan K.",
        "tier":       "Platinum",
        "upi":        "sudarshan.k@oksbi",
        "premium":    149,
        "policy_id":  "POL-SWG-9284",
        "coverage":   "₹2,500 / week",
    },
    {
        "id":         "ZOM-5512-274",
        "name":       "Meena R.",
        "tier":       "Gold",
        "upi":        "meena.ramesh@paytm",
        "premium":    99,
        "policy_id":  "POL-ZOM-5512",
        "coverage":   "₹1,800 / week",
    },
    {
        "id":         "SWG-7712-188",
        "name":       "Arjun S.",
        "tier":       "Silver",
        "upi":        "arjun.shetty@ybl",
        "premium":    69,
        "policy_id":  "POL-SWG-7712",
        "coverage":   "₹1,200 / week",
    },
]


def run_premium_debit():
    print("=" * 60)
    print("  CONTINUUM — WEEKLY eNACH PREMIUM DEBIT RUN")
    print("=" * 60)

    total = sum(p["premium"] for p in PARTNERS)
    print(f"\n🗓️  [SCHEDULER] Weekly debit triggered — {RUN_DATE} 06:00 IST")
    time.sleep(1.0)
    print(f"  Batch ref    : {BATCH_REF}")
    print(f"  Partners     : {len(PARTNERS)}")
    print(f"  Total debit  : ₹{total}")
    print(f"  Gateway      : PayU eNACH NACH mandate")

    print(f"\n🏦 [eNACH] Initiating UPI mandate pull requests...")
    settled = []
    failed  = []
    for p in PARTNERS:
        time.sleep(0.7)
        success = random.random() < 0.97
        upi_ref = f"NACH/{int(time.time()) % 10000}/{p['id'][-3:]}"
        if success:
            print(f"  ✅ {p['name']:<16} {p['upi']:<28} ₹{p['premium']}  {upi_ref}")
            settled.append({**p, "upi_ref": upi_ref})
        else:
            print(f"  ❌ {p['name']:<16} {p['upi']:<28} FAILED — mandate bounce")
            failed.append(p)

    print(f"\n  Settled: {len(settled)}/{len(PARTNERS)}  |  Failed: {len(failed)}")

    print(f"\n📋 [POLICY ENGINE] Updating policy coverage windows...")
    for p in settled:
        ok = post_request("/policy/renew", {
            "policy_id":   p["policy_id"],
            "partner_id":  p["id"],
            "premium_paid": p["premium"],
            "upi_ref":     p["upi_ref"],
            "coverage_period": f"{RUN_DATE} to next Sunday",
            "batch_ref":   BATCH_REF,
        })

    if failed:
        print(f"\n⚠️  [RETRY] Scheduling 24h retry for {len(failed)} failed debit(s)...")
        for p in failed:
            post_request("/policy/debit-retry", {
                "partner_id": p["id"],
                "premium":    p["premium"],
                "retry_in":   "24h",
                "grace_period": "48h",
            })

    print(f"\n💰 [RESERVE] Updating actuarial reserve balance...")
    post_request("/reserve/credit", {
        "amount":    sum(p["premium"] for p in settled),
        "source":    "weekly_premium_collection",
        "batch_ref": BATCH_REF,
        "partners":  len(settled),
    })

    print(f"\n🔔 [NOTIFY] Pushing payment receipts to partners...")
    for p in settled:
        post_request("/notification/push", {
            "partner_id": p["id"],
            "title": "Weekly Premium — Collected",
            "body":  f"₹{p['premium']} debited for {p['coverage']} cover. Ref: {p['upi_ref']}",
        }, ) if False else None  # quiet mode — one batch call instead
    post_request("/notification/bulk-push", {
        "type":    "premium_receipt",
        "count":   len(settled),
        "message": "Weekly premium collected. Your Continuum cover is active.",
    })

    settled_total = sum(p["premium"] for p in settled)
    print(f"\n{'=' * 60}")
    print(f"  ✅ DEBIT RUN COMPLETE — {RUN_DATE}")
    print(f"  Settled : {len(settled)}/{len(PARTNERS)} partners  |  ₹{settled_total} collected")
    if failed:
        print(f"  Failed  : {len(failed)} partner(s) — 24h retry scheduled")
    print(f"  Reserve : credited ₹{settled_total}")
    print(f"  Batch   : {BATCH_REF}")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_premium_debit()
