"""
Zone Polygon Data Loader.

Adapter pattern: reads from a configured source and upserts into the zones table.

Usage:
  python scripts/load_zone_polygons.py --provider fixture --pg-dsn "postgresql://..."
  python scripts/load_zone_polygons.py --provider geojson --pg-dsn "postgresql://..." --geojson-file ./data/mumbai_wards.geojson
"""
from __future__ import annotations

import abc
import argparse
import asyncio
import json
from dataclasses import dataclass
from typing import Iterator

import asyncpg


@dataclass
class ZoneRecord:
    zone_id: str
    city: str
    wkt_polygon: str
    risk_index: float


class ZonePolygonSource(abc.ABC):
    @abc.abstractmethod
    def zones(self) -> Iterator[ZoneRecord]:
        ...


class FixtureZoneSource(ZonePolygonSource):
    """3 hardcoded Mumbai test zones."""

    def zones(self) -> Iterator[ZoneRecord]:
        yield ZoneRecord("MUM_ANDHERI_W", "Mumbai",
            "POLYGON((72.82 19.12, 72.85 19.12, 72.85 19.15, 72.82 19.15, 72.82 19.12))", 0.65)
        yield ZoneRecord("MUM_BANDRA_W", "Mumbai",
            "POLYGON((72.82 19.05, 72.85 19.05, 72.85 19.08, 72.82 19.08, 72.82 19.05))", 0.55)
        yield ZoneRecord("MUM_DADAR", "Mumbai",
            "POLYGON((72.84 19.01, 72.87 19.01, 72.87 19.04, 72.84 19.04, 72.84 19.01))", 0.45)


class GeoJSONZoneSource(ZonePolygonSource):
    """Reads GeoJSON FeatureCollection file. Expects properties: zone_id, city, risk_index."""

    def __init__(self, path: str):
        self._path = path

    def zones(self) -> Iterator[ZoneRecord]:
        with open(self._path) as f:
            fc = json.load(f)
        for feature in fc.get("features", []):
            props = feature.get("properties", {})
            geom = feature.get("geometry", {})
            coords = geom.get("coordinates", [[]])
            ring = coords[0] if coords else []
            wkt_points = ", ".join(f"{lon} {lat}" for lon, lat in ring)
            wkt = f"POLYGON(({wkt_points}))"
            yield ZoneRecord(
                zone_id=props.get("zone_id", "UNKNOWN"),
                city=props.get("city", "Unknown"),
                wkt_polygon=wkt,
                risk_index=float(props.get("risk_index", 0.5)),
            )


def create_source(provider: str, **kwargs) -> ZonePolygonSource:
    if provider == "geojson":
        return GeoJSONZoneSource(kwargs["geojson_file"])
    return FixtureZoneSource()


async def load(pg_dsn: str, source: ZonePolygonSource) -> int:
    conn = await asyncpg.connect(pg_dsn)
    count = 0
    try:
        for zone in source.zones():
            await conn.execute(
                """INSERT INTO zones (zone_id, city, polygon, risk_index)
                   VALUES ($1, $2, ST_GeomFromText($3, 4326), $4)
                   ON CONFLICT (zone_id) DO UPDATE SET
                     polygon = ST_GeomFromText(EXCLUDED.polygon::text, 4326),
                     risk_index = EXCLUDED.risk_index""",
                zone.zone_id, zone.city, zone.wkt_polygon, zone.risk_index,
            )
            count += 1
    finally:
        await conn.close()
    print(f"[zone-loader] Loaded {count} zones")
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description="Zone polygon data loader")
    parser.add_argument("--provider", default="fixture", choices=["fixture", "geojson"])
    parser.add_argument("--pg-dsn", required=True)
    parser.add_argument("--geojson-file", default="./data/mumbai_wards.geojson")
    args = parser.parse_args()

    source = create_source(args.provider, geojson_file=args.geojson_file)
    asyncio.run(load(args.pg_dsn, source))


if __name__ == "__main__":
    main()
