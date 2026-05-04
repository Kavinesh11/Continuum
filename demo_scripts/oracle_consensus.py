"""
oracle_consensus.py
───────────────────
Full 5-source oracle consensus demonstration — shows how Continuum's
oracle engine cross-references multiple independent data feeds to
validate a disruption event before triggering a parametric payout.

Demo scenario: General BLR-South disruption event (heavy rain) →
oracle cross-checks 5 sources → consensus reached → payout approved.
Used standalone to walk through the oracle architecture in detail.
"""

import datetime
import time
import random
import hashlib

BASE_URL = "http://4.186.27.77:8000/api/simulate"

EVENT_ID   = f"EVT-ORG-{datetime.date.today().strftime('%Y-%m%d')}"
ZONE       = "Bangalore South — HSR Layout / Koramangala"
EVENT_TYPE = "Heavy Rainfall — Urban Flooding"


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


# Deterministic fake hash for oracle anchoring
def oracle_hash(event_id):
    return hashlib.sha256(event_id.encode()).hexdigest()[:24]


def run_oracle_consensus():
    print("=" * 60)
    print("  CONTINUUM ORACLE ENGINE — CONSENSUS DEMONSTRATION")
    print("=" * 60)

    print(f"\n🌍 [EVENT] Incoming disruption signal detected")
    time.sleep(1.0)
    print(f"  Event ID   : {EVENT_ID}")
    print(f"  Zone       : {ZONE}")
    print(f"  Event type : {EVENT_TYPE}")
    print(f"  Oracle hash: {oracle_hash(EVENT_ID)}")

    print(f"\n📡 [ORACLE] Phase 1 — Primary data source ingestion...")
    print(f"  Pulling from 5 independent feeds simultaneously:\n")

    sources = [
        {
            "name":     "IMD Weather API",
            "type":     "government",
            "endpoint": "api.imd.gov.in/rainfall/realtime",
            "result":   "142 mm rainfall in last 6h — Red Alert issued",
            "trigger":  True,
            "confidence": 0.97,
            "weight":   0.30,
        },
        {
            "name":     "BBMP Flood Sensor Network",
            "type":     "civic_iot",
            "endpoint": "sensors.bbmp.gov.in/flood/live",
            "result":   "14 of 22 BLR-South sensors above flood line",
            "trigger":  True,
            "confidence": 0.94,
            "weight":   0.25,
        },
        {
            "name":     "GPS Telemetry — Partner Fleet",
            "type":     "internal_telemetry",
            "endpoint": "telemetry.continuum.internal/gps/heatmap",
            "result":   "73% of BLR-South fleet stationary > 25 min",
            "trigger":  True,
            "confidence": 0.91,
            "weight":   0.25,
        },
        {
            "name":     "Swiggy/Zomato Platform APIs",
            "type":     "platform",
            "endpoint": "api.swiggy.com/platform/health",
            "result":   "Order completion rate down 64% in BLR-South",
            "trigger":  True,
            "confidence": 0.89,
            "weight":   0.15,
        },
        {
            "name":     "Social Signal (Twitter/X)",
            "type":     "social",
            "endpoint": "stream.twitter.com/search?q=BLR+flood",
            "result":   "4,210 BLR flood posts in last 2h — trending",
            "trigger":  True,
            "confidence": 0.78,
            "weight":   0.05,
        },
    ]

    for i, s in enumerate(sources, 1):
        time.sleep(0.8)
        flag = "🔴 TRIGGER" if s["trigger"] else "🟢 Clear  "
        print(f"  [{i}/5] {flag} | {s['name']:<32} conf={s['confidence']}  w={s['weight']}")
        print(f"         ↳ {s['result']}")

    print(f"\n🧠 [ML ENGINE] Phase 2 — IsoForest-XGB Ensemble v2.4")
    time.sleep(1.5)
    triggered = [s for s in sources if s["trigger"]]
    weighted_conf = sum(s["confidence"] * s["weight"] for s in triggered)
    print(f"  ↳ Sources triggered   : {len(triggered)}/5  (threshold: 3/5)")
    print(f"  ↳ Weighted confidence : {weighted_conf:.3f}  (threshold: 0.70)")
    print(f"  ↳ IsoForest anomaly   : 0.89  (high-confidence event cluster)")
    print(f"  ↳ XGBoost disruption  : 0.92")
    print(f"  ↳ Ensemble score      : {(0.89 + 0.92) / 2:.2f}")

    print(f"\n  SHAP feature importances:")
    shap = [
        ("imd_rainfall_mm",       0.41),
        ("fleet_stationary_pct",  0.28),
        ("bbmp_sensor_count",     0.19),
        ("platform_completion",   0.09),
        ("social_volume",         0.03),
    ]
    for feat, val in shap:
        bar = "█" * int(val * 30)
        print(f"  {feat:<28} {val:.2f}  {bar}")

    time.sleep(0.8)
    print(f"\n  ✅ CONSENSUS REACHED — PARAMETRIC PAYOUT APPROVED")
    print(f"  Oracle anchored: {oracle_hash(EVENT_ID)}")

    print(f"\n📋 [COMMIT] Writing oracle decision to chain...")
    ok = post_request("/oracle/consensus", {
        "event_id":          EVENT_ID,
        "zone":              ZONE,
        "event_type":        EVENT_TYPE,
        "sources_triggered": len(triggered),
        "weighted_conf":     round(weighted_conf, 3),
        "ensemble_score":    0.905,
        "oracle_hash":       oracle_hash(EVENT_ID),
        "decision":          "PAYOUT_APPROVED",
    })
    if not ok:
        print("🛑 Oracle commit failed.")
        return

    print(f"\n💸 [CLAIM ENGINE] Queuing parametric payouts for {ZONE}...")
    post_request("/claim/parametric-batch", {
        "event_id":   EVENT_ID,
        "zone":       ZONE,
        "payout_cap": 450,
        "eligibility": "all_active_partners",
        "gateway":    "PayU eNACH",
    })

    print(f"\n{'=' * 60}")
    print(f"  ✅ ORACLE CONSENSUS — {len(triggered)}/5 sources  |  Score: 0.91")
    print(f"  Event: {EVENT_TYPE}")
    print(f"  Zone:  {ZONE}")
    print(f"  Hash:  {oracle_hash(EVENT_ID)}")
    print(f"  → Parametric payouts queued for all eligible BLR-South partners")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_oracle_consensus()
