"""
Seed synthetic ledger data for CI actuarial gate.

Generates 24 months of premium credits and payout debits against the
double-entry ledger so that backtest and stress tests have non-zero data.
Run against the CockroachDB instance with ledger tables already migrated.

Usage:
  python scripts/seed_synthetic_ledger.py --crdb-dsn "postgresql://root@localhost:26257/continuum"
"""
from __future__ import annotations

import argparse
import asyncio
import random
import uuid
from datetime import datetime, timedelta, timezone

import asyncpg


ZONES = ["MUM_ANDHERI_W", "MUM_BANDRA_W", "MUM_DADAR"]
TIERS = ["silver", "gold", "platinum"]
TIER_PREMIUMS = {"silver": 49, "gold": 99, "platinum": 199}
TIER_COVERAGE = {"silver": 500, "gold": 1000, "platinum": 2000}

WEEKS_24_MONTHS = 104
INITIAL_RESERVE = 500_000.0


async def seed(crdb_dsn: str) -> None:
    pool = await asyncpg.create_pool(crdb_dsn, min_size=1, max_size=4)

    try:
        # Reset reserve to initial seed
        await pool.execute(
            "UPDATE ledger_accounts SET balance = $1 WHERE account_id = 'RESERVE_MAIN'",
            INITIAL_RESERVE,
        )
        await pool.execute(
            "UPDATE ledger_accounts SET balance = 0 WHERE account_id != 'RESERVE_MAIN'"
        )

        now = datetime.now(timezone.utc)
        start = now - timedelta(weeks=WEEKS_24_MONTHS)
        policies_created = 0
        premiums_posted = 0
        payouts_posted = 0

        # Create synthetic policies (10 per zone)
        for zone in ZONES:
            for i in range(10):
                tier = random.choice(TIERS)
                worker_id = str(uuid.uuid4())
                policy_id = str(uuid.uuid4())
                effective = start + timedelta(days=random.randint(0, 30))

                await pool.execute(
                    """INSERT INTO policies
                       (policy_id, worker_id, tier, coverage_cap, weekly_premium,
                        effective_date, claim_eligible_from, status,
                        billing_cycle_start, billing_cycle_end)
                     VALUES ($1, $2, $3, $4, $5, $6, $7, 'active', $8, $9)
                     ON CONFLICT (policy_id) DO NOTHING""",
                    policy_id, worker_id, tier,
                    TIER_COVERAGE[tier], TIER_PREMIUMS[tier],
                    effective, effective + timedelta(hours=72),
                    effective, effective + timedelta(days=7),
                )
                policies_created += 1

                # Generate weekly premium collections
                week_cursor = effective
                while week_cursor < now:
                    pv_id = str(uuid.uuid4())
                    premium = TIER_PREMIUMS[tier]

                    await pool.execute(
                        """INSERT INTO premium_versions
                           (version_id, policy_id, effective_date, zone_id, tier, risk_score, computed_premium)
                         VALUES ($1, $2, $3, $4, $5, $6, $7)
                         ON CONFLICT (version_id) DO NOTHING""",
                        pv_id, policy_id, week_cursor, zone, tier,
                        round(random.uniform(0.2, 0.8), 4), premium,
                    )

                    # Post ledger entry: premium credit to reserve
                    await pool.execute(
                        """INSERT INTO ledger_entries
                           (debit_account, credit_account, amount, reference_type, reference_id, description)
                         VALUES ('PREMIUM_INCOME', 'RESERVE_MAIN', $1, 'premium', $2, 'Synthetic premium')""",
                        premium, pv_id,
                    )
                    await pool.execute(
                        "UPDATE ledger_accounts SET balance = balance + $1 WHERE account_id = 'RESERVE_MAIN'",
                        premium,
                    )
                    await pool.execute(
                        "UPDATE ledger_accounts SET balance = balance + $1 WHERE account_id = 'PREMIUM_INCOME'",
                        premium,
                    )
                    premiums_posted += 1
                    week_cursor += timedelta(days=7)

                # Simulate occasional payouts (~8% weekly trigger rate)
                payout_cursor = effective + timedelta(hours=72)
                while payout_cursor < now:
                    if random.random() < 0.08:
                        payout_id = str(uuid.uuid4())
                        claim_id = str(uuid.uuid4())
                        amount = round(TIER_COVERAGE[tier] * random.uniform(0.3, 1.0), 2)

                        await pool.execute(
                            """INSERT INTO payouts
                               (payout_id, worker_id, claim_id, policy_id, amount,
                                oracle_votes, zone_id, tier, status, disbursed_at, created_at)
                             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'disbursed', $9, $9)
                             ON CONFLICT (payout_id) DO NOTHING""",
                            payout_id, worker_id, claim_id, policy_id, amount,
                            '[]', zone, tier, payout_cursor,
                        )

                        await pool.execute(
                            """INSERT INTO ledger_entries
                               (debit_account, credit_account, amount, reference_type, reference_id, description)
                             VALUES ('RESERVE_MAIN', 'PAYOUT_EXPENSE', $1, 'payout', $2, 'Synthetic payout')""",
                            amount, payout_id,
                        )
                        await pool.execute(
                            "UPDATE ledger_accounts SET balance = balance - $1 WHERE account_id = 'RESERVE_MAIN'",
                            amount,
                        )
                        await pool.execute(
                            "UPDATE ledger_accounts SET balance = balance + $1 WHERE account_id = 'PAYOUT_EXPENSE'",
                            amount,
                        )
                        payouts_posted += 1

                    payout_cursor += timedelta(days=7)

        # Also update legacy reserve_balance for backward compat
        reserve_row = await pool.fetchrow(
            "SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN'"
        )
        if reserve_row:
            await pool.execute(
                "UPDATE reserve_balance SET balance = $1 WHERE id = 1",
                float(reserve_row["balance"]),
            )

        print(f"[seed] Done: {policies_created} policies, {premiums_posted} premiums, {payouts_posted} payouts")

    finally:
        await pool.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed synthetic ledger data")
    parser.add_argument("--crdb-dsn", required=True, help="CockroachDB DSN")
    args = parser.parse_args()
    asyncio.run(seed(args.crdb_dsn))


if __name__ == "__main__":
    main()
