# ZonePolygonSource Integration

## Loader: `scripts/load_zone_polygons.py`

### Providers

| Provider | Flag | Description |
|----------|------|-------------|
| `fixture` | `--provider fixture` | 3 hardcoded Mumbai test zones. Default. |
| `geojson` | `--provider geojson --geojson-file ./data/mumbai_wards.geojson` | Reads GeoJSON FeatureCollection. |

### Acceptance Checklist (before using `--provider geojson` in production)

- [ ] Municipal GIS / OpenStreetMap ward-level polygon data obtained for target cities
- [ ] GeoJSON FeatureCollection format with properties: zone_id, city, risk_index
- [ ] Polygons validated: no self-intersections, correct winding order, WGS84 SRID 4326
- [ ] Zone IDs are unique and follow naming convention (CITY_WARD_DIRECTION)
- [ ] PostGIS GIST index verified after load (`EXPLAIN` shows index scan for ST_Contains)
- [ ] Edge cases: verify ST_Touches returns expected results for adjacent polygons
