"""
kill_switch.py
──────────────
Simulates a Continuum ops admin tripping the global payout kill switch —
pausing all outbound settlements system-wide and broadcasting an alert
to the operations team.

Demo scenario: Preethi Nair (Claims Reviewer) triggers PAYOUT_KILL_SWITCH →
all pending payouts are frozen → incident ticket auto-created.
"""

import time
import random

BASE_URL  = "http://4.186.27.77:8000/api/simulate"
ACTOR     = "Preethi Nair"
ACTOR_ID  = "ADM-PN-001"
REASON    = "Anomalous payout volume — 3× 30-day baseline in 90 minutes. Manual safety review required."
TICKET_ID = "INC-2024-0041"


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


def trip_kill_switch():
    print("=" * 60)
    print("  CONTINUUM OPS — PAYOUT KILL SWITCH")
    print("=" * 60)

    print(f"\n⚡ [TRIGGER] Kill switch initiated by {ACTOR}...")
    time.sleep(1.0)
    print(f"  ↳ Actor: {ACTOR} ({ACTOR_ID})")
    print(f"  ↳ Reason: {REASON}")
    print(f"  ↳ Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}")

    print(f"\n🔒 [KILL SWITCH] Broadcasting PAYOUT_KILL_SWITCH signal...")
    ok = post_request("/admin/kill-switch", {
        "actor_id": ACTOR_ID,
        "actor_name": ACTOR,
        "switch": "PAYOUT_KILL_SWITCH",
        "state": "ACTIVE",
        "reason": REASON,
    })
    if not ok:
        print("🛑 Kill switch failed to propagate — contact infra team immediately.")
        return

    print(f"\n🚫 [SETTLEMENT ENGINE] Halting outbound UPI queue...")
    time.sleep(0.8)
    services = [
        ("UPI Gateway — PayU eNACH",      True),
        ("UPI Gateway — Razorpay",        True),
        ("IMPS Direct Transfers",          True),
        ("Parametric Auto-Payout Queue",  True),
        ("Manual Review Queue",            False),  # read-only, unaffected
    ]
    for svc, affected in services:
        time.sleep(0.5)
        status = "🔴 PAUSED " if affected else "🟢 Unchanged"
        print(f"  {status} | {svc}")

    print(f"\n  → 23 pending payouts (₹9,840 total) are now frozen.")

    print(f"\n📋 [INCIDENT] Auto-creating incident ticket...")
    post_request("/incident/create", {
        "ticket_id": TICKET_ID,
        "type": "payout_freeze",
        "severity": "P1",
        "created_by": ACTOR_ID,
        "description": REASON,
        "affected_payouts": 23,
        "frozen_amount": 9840,
    })

    print(f"\n📡 [NOTIFY] Alerting operations team...")
    post_request("/notification/ops-team", {
        "type": "kill_switch_active",
        "message": "PAYOUT_KILL_SWITCH active — all payouts paused for safety review.",
        "ticket": TICKET_ID,
        "triggered_by": ACTOR,
        "severity": "P1",
    })

    print(f"\n📊 [AUDIT] Writing immutable audit entry...")
    post_request("/audit/log", {
        "actor": ACTOR,
        "action": "KILL_SWITCH_TRIP",
        "target": "PAYOUT_SYSTEM",
        "details": f"PAYOUT_KILL_SWITCH activated. 23 payouts frozen. Ticket: {TICKET_ID}.",
    })

    print(f"\n{'=' * 60}")
    print(f"  🔴 KILL SWITCH ACTIVE — All payouts paused system-wide")
    print(f"  Incident: {TICKET_ID}  |  Frozen: ₹9,840 across 23 payouts")
    print(f"  To resume: POST /admin/kill-switch {{state: INACTIVE}}")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    trip_kill_switch()
