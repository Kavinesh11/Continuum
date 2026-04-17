# WeatherHistoricalSource Integration

## Loader: `scripts/load_weather_historical.py`

### Providers

| Provider | Flag | Description |
|----------|------|-------------|
| `synthetic` | `--provider synthetic` | 24 months of random daily weather for 3 pilot zones. Default. |
| `imd` | `--provider imd --imd-data-dir ./data/imd` | Reads IMD CSV files with columns: zone_id, event_type, rainfall_mm, wind_kmh, recorded_at. |

### Acceptance Checklist (before using `--provider imd` in production)

- [ ] IMD historical data sourced for all target cities (minimum 24 months)
- [ ] CSV format validated: columns match expected schema
- [ ] Zone IDs in CSV mapped to zone_id values in `zones` table
- [ ] Deduplication: verify no duplicate (zone_id, recorded_at) pairs
- [ ] Data quality: verify rainfall_mm and wind_kmh fall within physically plausible ranges
- [ ] TimescaleDB hypertable compression policy applied for old data (> 90 days)
