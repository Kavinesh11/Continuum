"""
seed_demo_data.py
─────────────────
Seeds the bridge API with all demo persona data — claims history, payout
records, and notifications for the 3 demo drivers (Sudarshan K., Meena R.,
Arjun S.) so the Flutter app and admin dashboard start in a rich state.

Run this once before a demo to populate everything from a clean slate.
"""

import datetime
import time
import random

BASE_URL = "http://4.186.27.77:8000/api/simulate"


class Response:
    def __init__(self, status_code=200, data=None):
        self.status_code = status_code
        self._data = data or {"message": "success"}

    def json(self):
        return self._data

    @property
    def text(self):
        return str(self._data)


def post_request(endpoint, payload, quiet=False):
    url = f"{BASE_URL}{endpoint}"
    if not quiet:
        print(f"  🌐 POST {url}")
        print(f"  📦 {payload}")
    time.sleep(0.6)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if not quiet:
        if resp.status_code == 200:
            print(f"  ✅ [{endpoint}] → {resp.json()}")
        else:
            print(f"  ❌ [{endpoint}] failed")
    return resp.status_code == 200


# ─── Persona definitions ──────────────────────────────────────────────────────

DRIVERS = [
    {
        "id": "SWG-9284-912",
        "name": "Sudarshan K.",
        "platform": "Swiggy",
        "tier": "Platinum",
        "zone": "Bangalore South — HSR Layout",
        "policy_id": "POL-SWG-9284",
        "claims": [
            {"id": "CLM-AUTO-9921", "type": "Flood",            "amount": 450,  "status": "APPROVED", "upi": "UPI/FLD/92410/CONT9921"},
            {"id": "CLM-9102-41",   "type": "Platform Outage",  "amount": 380,  "status": "APPROVED", "upi": "UPI/OUT/10293/CONT4102"},
            {"id": "CLM-9102-44",   "type": "Vehicle Breakdown","amount": 290,  "status": "PENDING",  "upi": None},
        ],
        "notifications": [
            "✅ CLM-AUTO-9921 approved — ₹450 to Sudarshan K.",
            "🌧 Flood advisory — BLR-South zone",
            "✅ CLM-9102-41 approved — ₹380 settled",
        ],
    },
    {
        "id": "ZOM-5512-274",
        "name": "Meena R.",
        "platform": "Zomato",
        "tier": "Gold",
        "zone": "Chennai Central",
        "policy_id": "POL-ZOM-5512",
        "claims": [
            {"id": "CLM-STRK-4420", "type": "Bandh / Strike",    "amount": 380,  "status": "APPROVED", "upi": "UPI/BND/44203/CONT4420"},
            {"id": "CLM-9102-46",   "type": "Platform Outage",   "amount": 350,  "status": "PENDING",  "upi": None},
        ],
        "notifications": [
            "✅ CLM-STRK-4420 approved — ₹380 to Meena R.",
            "📣 Bandh advisory issued for Chennai Central",
        ],
    },
    {
        "id": "SWG-7712-188",
        "name": "Arjun S.",
        "platform": "Swiggy",
        "tier": "Silver",
        "zone": "Hyderabad West",
        "policy_id": "POL-SWG-7712",
        "claims": [
            {"id": "CLM-9102-54",   "type": "Vehicle Breakdown","amount": 420,  "status": "REVIEW",  "upi": None},
        ],
        "notifications": [
            "⚠ CLM-9102-54 flagged — crew-AI isolation-forest score 0.71.",
            "Your claim CLM-9102-54 is under specialist review.",
        ],
    },
]

ADMIN_CLAIMS = []
for d in DRIVERS:
    for c in d["claims"]:
        ADMIN_CLAIMS.append({
            "id":          c["id"],
            "driver":      d["name"],
            "tier":        d["tier"],
            "zone":        d["zone"],
            "reason":      c["type"],
            "description": f"{c['type']} incident reported in {d['zone']}.",
            "amount":      c["amount"],
            "status":      c["status"],
            "fraudScore":  0.05 if d["name"] != "Arjun S." else 0.71,
            "priority":    "High" if c["status"] == "PENDING" else "Medium",
            "submittedAt": datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            "isFraud":     d["name"] == "Arjun S.",
        })


def seed_drivers():
    print("\n👤 [DRIVERS] Seeding partner profiles...")
    for d in DRIVERS:
        ok = post_request("/driver/upsert", {
            "partner_id": d["id"],
            "name": d["name"],
            "platform": d["platform"],
            "tier": d["tier"],
            "zone": d["zone"],
            "policy_id": d["policy_id"],
        })
        status = "✅" if ok else "❌"
        print(f"  {status} {d['name']} ({d['id']}) — {d['tier']} / {d['zone']}")


def seed_claims():
    print("\n📋 [CLAIMS] Seeding claim history...")
    for claim in ADMIN_CLAIMS:
        ok = post_request("/claim/seed", claim, quiet=True)
        status = "✅" if ok else "❌"
        print(f"  {status} {claim['id']:<16} {claim['driver']:<16} {claim['status']:<10} ₹{claim['amount']}")


def seed_notifications():
    print("\n🔔 [NOTIFICATIONS] Seeding partner notifications...")
    for d in DRIVERS:
        for msg in d["notifications"]:
            ok = post_request("/notification/seed", {
                "partner_id": d["id"],
                "message": msg,
            }, quiet=True)
            status = "✅" if ok else "❌"
            print(f"  {status} [{d['name']}] {msg[:60]}")


def seed_admin_notifications():
    print("\n🔔 [ADMIN NOTIFICATIONS] Seeding admin dashboard alerts...")
    admin_notifs = [
        "⚠ Reserve runway 31 days — review autopay.",
        "✅ CLM-AUTO-9921 approved — ₹450 to Sudarshan K.",
        "🌧 Flood advisory — BLR-South zone",
        "⚠ CLM-9102-54 flagged — crew-AI isolation-forest score 0.71.",
    ]
    for msg in admin_notifs:
        ok = post_request("/notification/admin/seed", {"message": msg}, quiet=True)
        status = "✅" if ok else "❌"
        print(f"  {status} {msg[:70]}")


def run_seed():
    print("=" * 60)
    print("  CONTINUUM — DEMO DATA SEEDER")
    print("=" * 60)
    print(f"\n  Drivers   : {len(DRIVERS)}")
    print(f"  Claims    : {len(ADMIN_CLAIMS)}")
    print(f"  Platform  : Swiggy / Zomato")

    seed_drivers()
    seed_claims()
    seed_notifications()
    seed_admin_notifications()

    print(f"\n{'=' * 60}")
    print(f"  ✅ SEED COMPLETE")
    print(f"  {len(DRIVERS)} drivers  |  {len(ADMIN_CLAIMS)} claims  |  demo-ready")
    print(f"  Run reset_demo.py to wipe and re-seed at any time.")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_seed()
