"""
app_outage_trigger.py
─────────────────────
Simulates DownDetector picking up a Swiggy/Zomato platform outage, building
oracle consensus, and auto-approving a parametric income-protection payout.

Demo scenario: Sudarshan's dashboard shows "Platform Outage" banner → ₹180
credited automatically within 12 seconds.
"""

import time
import random

BASE_URL = "http://4.186.27.77:8000/api/simulate"

PLATFORM = "Swiggy"
PARTNER_ID = "SWG-9284-912"
ZONE = "Bangalore South — HSR Layout"


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
    resp = Response(200 if ok else 500, {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"})
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def trigger_app_outage():
    print("=" * 60)
    print("  CONTINUUM ORACLE — APP OUTAGE DETECTION")
    print("=" * 60)

    print(f"\n🔭 [DOWNDETECTOR] Polling {PLATFORM} status feed...")
    time.sleep(1.5)
    print(f"  ↳ Reports spike: 2,847 complaint posts in last 15 min")
    print(f"  ↳ Anomaly threshold: 800 — BREACHED ✓")

    print(f"\n📡 [ORACLE] Cross-referencing 5 data sources...")
    sources = [
        ("DownDetector",  True,  "98%", "API errors in BLR-South region"),
        ("Swiggy API",    True,  "95%", "503 responses on /orders endpoint"),
        ("TRAI Status",   False, "82%", "No cellular anomaly detected"),
        ("IMD Weather",   False, "88%", "Clear skies — not weather-related"),
        ("GPS Telemetry", True,  "91%", "Partners stationary > 20 min"),
    ]
    for i, (src, triggered, conf, note) in enumerate(sources, 1):
        time.sleep(0.6)
        flag = "🔴 TRIGGER" if triggered else "🟢 Clear  "
        print(f"  [{i}/5] {flag} | {src:<18} conf={conf}  — {note}")

    time.sleep(0.8)
    consensus_count = sum(1 for _, t, _, _ in sources if t)
    print(f"\n🧠 [ML ENGINE] IsoForest-XGB Ensemble v2.4")
    print(f"  ↳ Consensus: {consensus_count}/5 sources triggered  (threshold: 3/5)")
    print(f"  ↳ Prediction confidence: 0.93  |  SHAP: platform_status=0.74")
    print(f"  ↳ Decision: {'PARAMETRIC PAYOUT APPROVED ✓' if consensus_count >= 3 else 'BELOW THRESHOLD — NO PAYOUT'}")

    if consensus_count < 3:
        print("\n🛑 Consensus not reached. No payout fired.")
        return

    print(f"\n📋 [CLAIM ENGINE] Generating auto-claim for {PARTNER_ID}...")
    payload_claim = {
        "claim_id": "CLM-OUT-7821",
        "partner_id": PARTNER_ID,
        "zone": ZONE,
        "event_type": "Platform Outage",
        "platform": PLATFORM,
        "amount": 180,
        "status": "APPROVED",
        "is_oracle_triggered": True,
        "approval_path": "parametric_auto",
    }
    ok = post_request("/claim/create", payload_claim)
    if not ok:
        print("🛑 Claim creation failed.")
        return

    print(f"\n💸 [UPI SETTLEMENT] Initiating instant transfer...")
    time.sleep(2)
    upi_ref = f"UPI/OUT/{int(time.time()) % 100000}/CONT7821"
    payload_payout = {
        "partner_id": PARTNER_ID,
        "claim_id": "CLM-OUT-7821",
        "amount": 180,
        "upi_ref": upi_ref,
        "gateway": "PayU eNACH",
        "status": "SETTLED",
    }
    ok = post_request("/payout", payload_payout)
    if not ok:
        print("🛑 UPI settlement failed.")
        return

    print(f"\n🔔 [NOTIFY] Pushing notification to {PARTNER_ID}...")
    post_request("/notification/push", {
        "partner_id": PARTNER_ID,
        "title": f"₹180 credited — {PLATFORM} outage compensation",
        "body": f"Parametric payout settled. Ref: {upi_ref}",
    })

    print(f"\n{'=' * 60}")
    print(f"  🎯 DONE — ₹180 auto-payout settled for {PLATFORM} outage")
    print(f"  Claim: CLM-OUT-7821  |  UPI Ref: {upi_ref}")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    trigger_app_outage()
