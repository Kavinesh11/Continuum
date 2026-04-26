"""
claim_rejection_cascade.py
──────────────────────────
Simulates the GPS proximity validation engine auto-rejecting two claims
because the submitting partner's GPS log places them outside the declared
disruption zone at the time of the incident.

Demo scenario: Ravi T. (BLR-North) and Sudha P. (KOL-South) both file
claims for disruptions, but GPS telemetry shows they were not in the
affected area → auto-rejected with detailed reason.
"""

import time
import random

BASE_URL = "http://4.186.27.77:8000/api/simulate"

CLAIMS = [
    {
        "claim_id":   "CLM-9999-01",
        "partner_id": "SWG-7741-112",
        "driver":     "Ravi T.",
        "zone":       "BLR-North — Hebbal",
        "event_type": "Vehicle Breakdown",
        "gps_lat":    13.0614,
        "gps_lng":    77.5939,
        "zone_lat":   13.0358,
        "zone_lng":   77.5970,
        "distance_km": 3.2,
        "threshold_km": 1.0,
        "reason": "GPS proximity log shows worker 3.2 km outside the Hebbal disruption zone at incident time.",
    },
    {
        "claim_id":   "CLM-9999-02",
        "partner_id": "ZOM-8821-304",
        "driver":     "Sudha P.",
        "zone":       "KOL-South — New Market",
        "event_type": "Outside Zone",
        "gps_lat":    22.5244,
        "gps_lng":    88.3301,
        "zone_lat":   22.5448,
        "zone_lng":   88.3426,
        "distance_km": 2.8,
        "threshold_km": 1.0,
        "reason": "Claim originated outside the active zone. GPS telemetry confirms partner was not present in disruption area.",
    },
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
    time.sleep(1.0)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_rejection_cascade():
    print("=" * 60)
    print("  CONTINUUM GPS ENGINE — CLAIM REJECTION CASCADE")
    print("=" * 60)

    for i, claim in enumerate(CLAIMS, 1):
        cid = claim["claim_id"]
        print(f"\n{'─' * 50}")
        print(f"  Claim {i}/{len(CLAIMS)}: {cid} — {claim['driver']}")
        print(f"{'─' * 50}")

        print(f"\n📍 [GPS CHECK] Validating partner location at incident time...")
        time.sleep(1.0)
        print(f"  ↳ Claim zone     : {claim['zone']}")
        print(f"  ↳ Zone centroid  : ({claim['zone_lat']}, {claim['zone_lng']})")
        print(f"  ↳ Partner GPS    : ({claim['gps_lat']}, {claim['gps_lng']})")
        print(f"  ↳ Distance       : {claim['distance_km']} km")
        print(f"  ↳ Max threshold  : {claim['threshold_km']} km")
        time.sleep(0.6)
        print(f"\n  🔴 PROXIMITY FAIL — {claim['distance_km']} km > {claim['threshold_km']} km threshold")

        print(f"\n❌ [CLAIM ENGINE] Auto-rejecting {cid}...")
        ok = post_request(f"/claim/{cid}/reject", {
            "claim_id": cid,
            "partner_id": claim["partner_id"],
            "status": "REJECTED",
            "reviewed_by": "gps_proximity_engine",
            "reason": claim["reason"],
            "gps_distance_km": claim["distance_km"],
        })
        if not ok:
            print(f"🛑 Rejection update for {cid} failed.")
            continue

        print(f"\n🔔 [NOTIFY] Informing {claim['driver']}...")
        post_request("/notification/push", {
            "partner_id": claim["partner_id"],
            "title": f"Claim {cid} — Not Approved",
            "body": claim["reason"],
            "status": "REJECTED",
        })

    print(f"\n📊 [AUDIT] Logging cascade rejection event...")
    post_request("/audit/log", {
        "actor": "gps_proximity_engine",
        "action": "CASCADE_REJECTED",
        "target": f"{len(CLAIMS)} claims",
        "details": "2 claims auto-rejected — GPS proximity failed.",
    })

    post_request("/notification/admin", {
        "type": "rejection_cascade",
        "message": "2 claims auto-rejected — GPS proximity failed.",
        "claim_ids": [c["claim_id"] for c in CLAIMS],
    })

    print(f"\n{'=' * 60}")
    print(f"  ❌ CASCADE DONE — {len(CLAIMS)} claims rejected (GPS proximity fail)")
    print(f"  CLM-9999-01: Ravi T.  — BLR-North (3.2 km outside zone)")
    print(f"  CLM-9999-02: Sudha P. — KOL-South (2.8 km outside zone)")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_rejection_cascade()
