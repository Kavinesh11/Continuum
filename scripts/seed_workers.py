#!/usr/bin/env python3
import asyncpg
import bcrypt
import sys
from uuid import UUID

async def seed_workers(pg_dsn: str):
    conn = await asyncpg.connect(pg_dsn)
    
    workers = [
        {
            'worker_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'platform': 'zomato',
            'tier': 'silver',
            'zone_id': 'MUM_ANDHERI_W',
            'upi_id': 'rider1@upi',
            'password': 'password123'
        },
        {
            'worker_id': 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'platform': 'swiggy',
            'tier': 'gold',
            'zone_id': 'MUM_BANDRA_W',
            'upi_id': 'rider2@upi',
            'password': 'password456'
        },
        {
            'worker_id': 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
            'platform': 'zomato',
            'tier': 'platinum',
            'zone_id': 'MUM_DADAR',
            'upi_id': 'rider3@upi',
            'password': 'password789'
        }
    ]
    
    for w in workers:
        password_hash = bcrypt.hashpw(w['password'].encode(), bcrypt.gensalt()).decode()
        await conn.execute(
            '''INSERT INTO workers (worker_id, platform, tier, zone_id, upi_id, password_hash, registered_at)
               VALUES ($1, $2, $3, $4, $5, $6, NOW())
               ON CONFLICT DO NOTHING''',
            UUID(w['worker_id']), w['platform'], w['tier'], w['zone_id'], w['upi_id'], password_hash
        )
        print(f"Seeded: {w['worker_id']} / {w['platform']} / pwd={w['password']}")
    
    await conn.close()

if __name__ == '__main__':
    import asyncio
    pg_dsn = sys.argv[1] if len(sys.argv) > 1 else "postgresql://postgres:continuum_dev_password_12345@localhost:5432/continuum"
    asyncio.run(seed_workers(pg_dsn))
