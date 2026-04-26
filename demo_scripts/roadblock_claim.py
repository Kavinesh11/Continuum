"""
roadblock_claim.py
──────────────────
Simulates the full lifecycle of Sudarshan's manual roadblock claim:
  1. Claim submitted from Flutter app (CLM-RBK-9284)
  2. Continuum oracle runs GPS proximity + road sensor check
  3. Admin review confirms alternative routes exist
  4. Claim auto-rejected with reason
  5. Flutter status tracker updated → partner notified

Demo scenario: Sudarshan is blocked near Koramangala 5th Block →
files claim → GPS shows alternative route available → REJECTED within ~25s.
"""

import time
import random

BASE_URL   = "http://4.186.27.77:8000/api/simulate"
CLAIM_ID   = "CLM-RBK-9284"
PARTNER_ID = "SWG-9284-912"
DRIVER     = "Sudarshan K."
ZONE       = "Bangalore South — Koramangala 5th Block"


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
    time.sleep(1.0)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_roadblock_claim():
    print("=" * 60)
    print("  CONTINUUM ORACLE — ROADBLOCK CLAIM LIFECYCLE")
    print("=" * 60)

    # Step 1: Claim submission
    print(f"\n📱 [FLUTTER] {DRIVER} submitting roadblock claim...")
    time.sleep(1.0)
    print(f"  ↳ Claim ID  : {CLAIM_ID}")
    print(f"  ↳ Zone      : {ZONE}")
    print(f"  ↳ Description: Police barricade blocking all delivery routes near 5th Block")
    print(f"  ↳ Amount    : ₹0 (manual — no parametric trigger)")

    ok = post_request("/claim/create", {
        "claim_id": CLAIM_ID,
        "partner_id": PARTNER_ID,
        "zone": ZONE,
        "event_type": "Roadblock / Road Closure",
        "description": "Police barricade blocking all delivery routes. Unable to complete any orders in Zone 4B.",
        "amount": 0,
        "status": "REVIEW",
        "is_oracle_triggered": False,
        "approval_path": "manual_review",
    })
    if not ok:
        print("🛑 Claim submission failed.")
        return

    print(f"\n📡 [ORACLE] Running GPS proximity and road sensor check...")
    checks = [
        ("GPS — claim location",       "12.9279° N, 77.6271° E",  True,  "✓ Sudarshan's GPS matches reported zone"),
        ("BMC road closure API",        "No active closure",        False, "⚠ No civic road-closure record found"),
        ("Police barricade feed",       "No record",               False, "⚠ DCP traffic database shows no barricade"),
        ("Google Maps routes",          "3 alternate routes",      False, "⚠ Sarjapur Rd / Inner Ring Rd available"),
        ("Partner stationary time",     "7 min",                   False, "✓ Short stop — not delivery-blocking"),
    ]
    for name, val, trigger, note in checks:
        time.sleep(0.7)
        icon = "🔴" if trigger else "🟡"
        print(f"  {icon} {name:<28} {val:<28} {note}")

    time.sleep(0.8)
    consensus = sum(1 for _, _, t, _ in checks if t)
    print(f"\n  🧠 Oracle consensus: {consensus}/5 sources confirm roadblock claim")
    print(f"  ↳ Threshold to approve: 3/5 sources")
    print(f"  ↳ Result: BELOW THRESHOLD — claim does not qualify for payout")

    print(f"\n👩‍💼 [ADMIN] Auto-review engine applying decision...")
    time.sleep(1.5)
    rejection_reason = (
        "Route outside parametric disruption zone. GPS proximity data shows alternative "
        "access routes available (Sarjapur Rd, Inner Ring Rd). Roadblock does not meet "
        "coverage trigger criteria."
    )
    print(f"  ↳ Rejection reason: {rejection_reason}")

    ok = post_request(f"/claim/{CLAIM_ID}/reject", {
        "claim_id": CLAIM_ID,
        "status": "REJECTED",
        "reviewed_by": "oracle_auto + Preethi Nair",
        "reason": rejection_reason,
    })
    if not ok:
        print("🛑 Rejection update failed.")
        return

    print(f"\n🔔 [NOTIFY] Pushing rejection notification to {PARTNER_ID}...")
    post_request("/notification/push", {
        "partner_id": PARTNER_ID,
        "title": f"Claim {CLAIM_ID} — Update",
        "body": "Your roadblock claim could not be approved. Route data shows alternative access routes were available.",
        "status": "REJECTED",
    })

    print(f"\n📊 [AUDIT] Logging final decision...")
    post_request("/audit/log", {
        "actor": "Preethi Nair",
        "action": "REJECTED",
        "target": CLAIM_ID,
        "details": rejection_reason,
    })

    print(f"\n{'=' * 60}")
    print(f"  ❌ {CLAIM_ID} REJECTED — {DRIVER}")
    print(f"  GPS data: alternative routes available → no payout eligible")
    print(f"  Flutter status tracker: updated within next poll cycle (~6s)")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_roadblock_claim()
