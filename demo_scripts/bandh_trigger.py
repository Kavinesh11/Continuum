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

    time.sleep(1)  # simulate latency

    # simulate realistic response behavior
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


def trigger_bandh():
    print("🔍 [SCRAPEGRAPH] Analyzing Municipal RSS Feeds...")
    time.sleep(2)

    print("⚠️ [MATCH] General Strike (Bandh) confirmed for tomorrow.")

    payload_trigger = {
        "source": "Newspaper/ScrapeGraph",
        "trigger_name": "Bandh / General Strike",
        "zone_impact": "Ballygunge",
        "is_active": True
    }

    success_trigger = post_request("/oracle-update", payload_trigger)

    if not success_trigger:
        print("🛑 Aborting: Trigger update failed.")
        return

    payload_claim = {
        "claim_id": "CLM-STRK-4420",
        "reason": "Bandh Protection",
        "amount": 380,
        "status": "APPROVED",
        "is_oracle_triggered": True
    }

    success_claim = post_request("/payout", payload_claim)

    if not success_claim:
        print("🛑 Warning: Claim push failed.")
        return

    print("🎯 [DONE] Bandh alert and payout pushed successfully.")


if __name__ == "__main__":
    trigger_bandh()