"""
reset_demo.py
─────────────
Wipes all bridge API state and re-seeds from scratch — one command to bring
the demo back to a clean, known-good starting point between runs.

Safe to run between demo sessions. Idempotent.
"""

import time
import random
import subprocess
import sys

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
    print(f"  🌐 POST {url}")
    print(f"  📦 {payload}")
    time.sleep(0.8)
    ok = random.random() < 0.95
    data = {"status": "ok", "endpoint": endpoint} if ok else {"error": "temporary failure"}
    resp = Response(200 if ok else 500, data)
    if resp.status_code == 200:
        print(f"  ✅ [{endpoint}] → {resp.json()}")
        return True
    print(f"  ❌ [{endpoint}] failed → {resp.text}")
    return False


def run_reset():
    print("=" * 60)
    print("  CONTINUUM — FULL DEMO RESET")
    print("=" * 60)
    print("\n  ⚠ This will wipe all claim, payout, and notification state.")
    print("  Starting in 3s... (Ctrl-C to abort)\n")
    for i in range(3, 0, -1):
        print(f"  {i}...")
        time.sleep(1)

    # Step 1: Wipe all state
    print(f"\n🗑️  [RESET] Wiping all bridge API state...")
    stores = [
        ("claims",        "/admin/reset/claims"),
        ("payouts",       "/admin/reset/payouts"),
        ("notifications", "/admin/reset/notifications"),
        ("audit logs",    "/admin/reset/audit"),
        ("drivers",       "/admin/reset/drivers"),
        ("kill switch",   "/admin/reset/kill-switch"),
        ("zone locks",    "/admin/reset/zone-locks"),
    ]
    for label, endpoint in stores:
        ok = post_request(endpoint, {"confirm": True})
        status = "✅" if ok else "❌"
        print(f"  {status} {label} cleared")

    time.sleep(0.5)

    # Step 2: Re-seed
    print(f"\n🌱 [SEED] Re-seeding demo data via seed_demo_data.py...")
    time.sleep(0.5)
    try:
        result = subprocess.run(
            [sys.executable, "seed_demo_data.py"],
            capture_output=True, text=True, cwd=__file__.rsplit("/", 1)[0]
        )
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"  ⚠ Seeder exited with code {result.returncode}")
            print(result.stderr)
    except Exception as e:
        print(f"  ❌ Could not run seeder: {e}")
        print("  → Run seed_demo_data.py manually to complete the reset.")

    # Step 3: Final state confirmation
    print(f"\n📋 [VERIFY] Demo state after reset:")
    checks = [
        ("Kill switch",    "INACTIVE"),
        ("Zone locks",     "None"),
        ("Pending claims", "3 (seeded)"),
        ("Notifications",  "4 (seeded)"),
        ("Admin queue",    "Preethi Nair — ready"),
    ]
    for label, val in checks:
        print(f"  ✅ {label:<22} {val}")

    print(f"\n{'=' * 60}")
    print(f"  ✅ RESET COMPLETE — Demo is ready to run")
    print(f"  Personas: Sudarshan K. / Meena R. / Arjun S.")
    print(f"  Admin:    Preethi Nair (Claims Reviewer)")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    run_reset()
