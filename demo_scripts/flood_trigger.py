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


def post_request(endpoint, payload):
    url = f"{BASE_URL}{endpoint}"

    print(f"🌐 POST {url}")
    print(f"📦 Payload: {payload}")

    time.sleep(1.2)  # simulate network latency

    # simulate realistic backend behavior
    if random.random() < 0.95:
        response = Response(200, {"status": "ok", "endpoint": endpoint})
    else:
        response = Response(500, {"error": "temporary failure"})

    if response.status_code == 200:
        print(f"✅ SUCCESS [{endpoint}] → {response.json()}")
        return True
    else:
        print(f"❌ FAILED [{endpoint}] → Status: {response.status_code}, Response: {response.text}")
        return False


def trigger_flood():
    print("🚀 [ORACLE] Detecting Heavy Rainfall in Bangalore South...")

    # Step 1: Global Alert
    payload_alert = {
        "event_type": "FLOOD",
        "zone": "Zone 4B",
        "status": "ALERT_ACTIVE",
        "intensity": "55mm/hr"
    }

    success_alert = post_request("/event", payload_alert)

    if not success_alert:
        print("🛑 Aborting: Alert trigger failed.")
        return

    print("⏳ [AI ENGINE] Verifying GPS soak-period and Cell-ID...")
    time.sleep(4)

    # Step 2: Automatic Payout
    payload_payout = {
        "claim_id": "CLM-AUTO-9921",
        "reason": "Severe Flood Payout",
        "amount": 450,
        "status": "APPROVED",
        "is_oracle_triggered": True,
        "upi_ref": "UPI/FLOD/2026/9921"
    }

    success_payout = post_request("/payout", payload_payout)

    if not success_payout:
        print("🛑 Warning: Payout push failed.")
        return

    print("🎯 [DONE] Alert + payout processed successfully.")


if __name__ == "__main__":
    trigger_flood()