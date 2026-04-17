# LivenessProvider Integration

## Adapter: `services/core_backend/src/adapters/livenessProvider/index.js`

### Providers

| Provider | Env Var | Description |
|----------|---------|-------------|
| `mock` | `LIVENESS_PROVIDER=mock` | Always returns passed=true. Default for dev/CI. |
| `iproov` | `LIVENESS_PROVIDER=iproov` | iProov Genuine Presence Assurance. |

### Acceptance Checklist (before setting `LIVENESS_PROVIDER=iproov`)

- [ ] iProov account created and service plan selected
- [ ] `IPROOV_BASE_URL`, `IPROOV_API_KEY`, `IPROOV_SECRET` provisioned and in secrets manager
- [ ] Flutter SDK integrated for capture (out of scope for backend; document mobile contract)
- [ ] End-to-end test: real face capture → verify API → pass/fail response
- [ ] False rejection rate measured and documented (target: < 3%)
- [ ] Latency p95 measured (target: < 5s for verify call)
- [ ] DPDP consent for biometric data collection documented in consent flow
