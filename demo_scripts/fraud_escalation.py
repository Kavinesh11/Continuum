"""
fraud_escalation.py
───────────────────
Simulates the Crew-AI isolation-forest fraud engine flagging a suspicious claim,
computing an anomaly score, and escalating it to the specialist review queue.

Demo scenario: CLM-9102-54 (Arjun S.) shows behavioural anomalies →
scored 0.71 → escalated to fraud queue → admin notified.
"""

import time
import random

BASE_URL = "http://4.186.27.77:8000/api/simulate"

CLAIM_ID  = "CLM-9102-54"
DRIVER_ID = "DRV-ARJ-7712"
DRIVER    = "Arjun S."
ZONE      = "Chennai Central"


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
    time.sleep(1.2)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_fraud_escalation():
    print("=" * 60)
    print("  CONTINUUM CREW-AI — FRAUD DETECTION ENGINE")
    print("=" * 60)

    print(f"\n🔍 [INGESTION] Pulling claim {CLAIM_ID} for scoring...")
    time.sleep(1.0)
    print(f"  ↳ Driver: {DRIVER}  |  Zone: {ZONE}")
    print(f"  ↳ Claim type: Vehicle Breakdown  |  Amount: ₹420")
    print(f"  ↳ Submission time: 02:17 AM  (night-time flag)")

    print(f"\n🧬 [FEATURE EXTRACTION] Building behavioural vector...")
    features = [
        ("Submission hour",          "02:17",     "⚠ Outside active delivery window"),
        ("GPS — claim zone",         "MHB-North", "⚠ Mismatch vs. usual zone"),
        ("Avg breakdown freq (30d)", "4.1×",      "⚠ 3× fleet mean (1.3×)"),
        ("Platform login delta",     "8 min",     "✓ Active on app pre-claim"),
        ("Vehicle age",              "5.2 yrs",   "✓ Within breakdown-prone range"),
        ("Historical payout",        "₹2,840",    "⚠ Top 4% for tier"),
    ]
    for name, val, note in features:
        time.sleep(0.5)
        print(f"  {note[0]} {name:<30} {val:<12} {note}")

    print(f"\n🤖 [ML ENGINE] IsoForest-XGB Ensemble — Crew-AI v3.1")
    time.sleep(1.5)
    print(f"  ↳ IsolationForest anomaly score : 0.71")
    print(f"  ↳ XGBoost fraud probability     : 0.68")
    print(f"  ↳ Ensemble score (weighted avg) : 0.71")
    print(f"  ↳ Threshold for escalation      : 0.65")
    print(f"  ↳ SHAP top drivers: breakdown_freq=0.38, submit_hour=0.21, zone_mismatch=0.19")
    time.sleep(0.8)
    print(f"\n  🚨 FRAUD FLAG RAISED — Score 0.71 > threshold 0.65")

    print(f"\n📋 [ESCALATION] Routing {CLAIM_ID} to specialist queue...")
    ok = post_request("/fraud/flag", {
        "claim_id": CLAIM_ID,
        "driver_id": DRIVER_ID,
        "fraud_score": 0.71,
        "model_version": "crew-ai-isoforest-v3.1",
        "escalation_queue": "specialist_review",
        "shap_summary": {"breakdown_freq": 0.38, "submit_hour": 0.21, "zone_mismatch": 0.19},
    })
    if not ok:
        print("🛑 Escalation failed.")
        return

    print(f"\n🔔 [NOTIFY] Alerting admin team...")
    post_request("/notification/admin", {
        "type": "fraud_escalation",
        "claim_id": CLAIM_ID,
        "driver": DRIVER,
        "fraud_score": 0.71,
        "message": f"⚠ {CLAIM_ID} flagged — crew-AI isolation-forest score 0.71.",
        "queue": "specialist_review",
    })

    print(f"\n📊 [AUDIT] Logging escalation event...")
    post_request("/audit/log", {
        "actor": "crew-ai-engine",
        "action": "FRAUD_ESCALATED",
        "target": CLAIM_ID,
        "details": f"IsoForest score 0.71 — routed to specialist queue. {DRIVER} — {ZONE}.",
    })

    print(f"\n{'=' * 60}")
    print(f"  🚨 DONE — {CLAIM_ID} escalated to fraud specialist queue")
    print(f"  Driver: {DRIVER}  |  Score: 0.71  |  Threshold: 0.65")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_fraud_escalation()
