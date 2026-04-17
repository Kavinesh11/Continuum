# Runbook: Oracle Freshness Degraded

**Alert:** `OracleFreshnessBurnRate1h` / `OracleHighAbstentionRate`  
**SLO:** Oracle poll fresh ratio > 0.85 over 7d

## Triage

1. Check which oracle(s) are stale: `oracle_failure_rate` metric by `oracle_name` label
2. Check oracle_engine logs for `poll_cycle_error` entries
3. Verify TLS certificate expiry on oracle endpoints

## Common Causes

| Oracle | Typical Issue | Fix |
|--------|--------------|-----|
| IMD | Government site maintenance (usually scheduled) | Wait; abstention is handled by consensus |
| AccuWeather | API key quota exceeded | Rotate key or request quota increase |
| NASA GPM | Data pipeline delay (>15 min) | Expected occasionally; abstention is safe |
| CPCB | Rate limiting | Increase poll interval for AQI |
| Downdetector | API key not set | Set `DD_API_KEY` env var |

## Impact

Stale oracles abstain from voting. If >40% abstain, consensus falls back to benefit-of-doubt (50% payout cap). This is by design but should not persist > 1 hour.
