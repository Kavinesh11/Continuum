"""
Weather Historical Data Loader.

Adapter pattern: reads from a configured source and bulk-inserts into
the weather_events TimescaleDB hypertable.

Usage:
  python scripts/load_weather_historical.py --provider synthetic --pg-dsn "postgresql://..."
  python scripts/load_weather_historical.py --provider imd --pg-dsn "postgresql://..." --imd-data-dir ./data/imd
"""
from __future__ import annotations

import abc
import argparse
import asyncio
import random
from datetime import datetime, timedelta, timezone
from typing import Iterator

import asyncpg


class WeatherRecord:
    __slots__ = ("zone_id", "event_type", "rainfall_mm", "wind_kmh", "recorded_at")

    def __init__(self, zone_id: str, event_type: str, rainfall_mm: float | None,
                 wind_kmh: float | None, recorded_at: datetime):
        self.zone_id = zone_id
        self.event_type = event_type
        self.rainfall_mm = rainfall_mm
        self.wind_kmh = wind_kmh
        self.recorded_at = recorded_at


class WeatherHistoricalSource(abc.ABC):
    @abc.abstractmethod
    def records(self) -> Iterator[WeatherRecord]:
        ...


class SyntheticWeatherSource(WeatherHistoricalSource):
    """Generates 24 months of synthetic daily weather for 3 pilot zones."""

    ZONES = ["MUM_ANDHERI_W", "MUM_BANDRA_W", "MUM_DADAR"]

    def records(self) -> Iterator[WeatherRecord]:
        now = datetime.now(timezone.utc)
        start = now - timedelta(days=730)
        cursor = start
        while cursor <= now:
            for zone in self.ZONES:
                is_heavy = random.random() < 0.08
                yield WeatherRecord(
                    zone_id=zone,
                    event_type="heavy_rainfall",
                    rainfall_mm=50 + random.random() * 100 if is_heavy else random.random() * 20,
                    wind_kmh=10 + random.random() * 40,
                    recorded_at=cursor,
                )
            cursor += timedelta(days=1)


class IMDWeatherSource(WeatherHistoricalSource):
    """Reads IMD CSV bulk data files. Requires --imd-data-dir."""

    def __init__(self, data_dir: str):
        self._data_dir = data_dir

    def records(self) -> Iterator[WeatherRecord]:
        import csv
        import os
        for fname in sorted(os.listdir(self._data_dir)):
            if not fname.endswith(".csv"):
                continue
            with open(os.path.join(self._data_dir, fname)) as f:
                reader = csv.DictReader(f)
                for row in reader:
                    yield WeatherRecord(
                        zone_id=row["zone_id"],
                        event_type=row.get("event_type", "heavy_rainfall"),
                        rainfall_mm=float(row["rainfall_mm"]) if row.get("rainfall_mm") else None,
                        wind_kmh=float(row["wind_kmh"]) if row.get("wind_kmh") else None,
                        recorded_at=datetime.fromisoformat(row["recorded_at"]),
                    )


def create_source(provider: str, **kwargs) -> WeatherHistoricalSource:
    if provider == "imd":
        return IMDWeatherSource(kwargs["imd_data_dir"])
    return SyntheticWeatherSource()


async def load(pg_dsn: str, source: WeatherHistoricalSource) -> int:
    conn = await asyncpg.connect(pg_dsn)
    count = 0
    batch = []
    try:
        for rec in source.records():
            batch.append((rec.zone_id, rec.event_type, rec.rainfall_mm, rec.wind_kmh, rec.recorded_at))
            if len(batch) >= 500:
                await conn.executemany(
                    "INSERT INTO weather_events (zone_id, event_type, rainfall_mm, wind_kmh, recorded_at) "
                    "VALUES ($1, $2, $3, $4, $5)",
                    batch,
                )
                count += len(batch)
                batch = []
        if batch:
            await conn.executemany(
                "INSERT INTO weather_events (zone_id, event_type, rainfall_mm, wind_kmh, recorded_at) "
                "VALUES ($1, $2, $3, $4, $5)",
                batch,
            )
            count += len(batch)
    finally:
        await conn.close()
    print(f"[weather-loader] Loaded {count} records")
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description="Weather historical data loader")
    parser.add_argument("--provider", default="synthetic", choices=["synthetic", "imd"])
    parser.add_argument("--pg-dsn", required=True)
    parser.add_argument("--imd-data-dir", default="./data/imd")
    args = parser.parse_args()

    source = create_source(args.provider, imd_data_dir=args.imd_data_dir)
    asyncio.run(load(args.pg_dsn, source))


if __name__ == "__main__":
    main()
