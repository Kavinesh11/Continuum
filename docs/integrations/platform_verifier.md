# PlatformOrderVerifier Integration

## Adapter: `services/claims_scoring/src/checks/platform_verifier.rs`

### Providers

| Provider | Env Var | Description |
|----------|---------|-------------|
| `mock` | `PLATFORM_VERIFIER_PROVIDER=mock` | Always returns "no orders found". Default for dev/CI. |
| `prod` | `PLATFORM_VERIFIER_PROVIDER=prod` | Calls real Swiggy/Zomato APIs based on worker's platform. |

### Acceptance Checklist (before setting `PLATFORM_VERIFIER_PROVIDER=prod`)

- [ ] Swiggy partner API access negotiated; `SWIGGY_API_URL` and `SWIGGY_API_KEY` provisioned
- [ ] Zomato partner API access negotiated; `ZOMATO_API_URL` and `ZOMATO_API_KEY` provisioned
- [ ] End-to-end test: query for a known partner with completed orders in a known window
- [ ] Error handling: verify graceful degradation when API returns 5xx (no veto, log + alert)
- [ ] Rate limits documented per platform
- [ ] Data privacy: verify no PII is logged from API responses
