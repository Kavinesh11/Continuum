# PayoutGateway Integration

## Adapter: `services/core_backend/src/adapters/payoutGateway/index.js`

### Providers

| Provider | Env Var | Description |
|----------|---------|-------------|
| `mock` | `PAYOUT_GATEWAY_PROVIDER=mock` | Deterministic stub; always returns success. Default for dev/CI. |
| `sandbox` | `PAYOUT_GATEWAY_PROVIDER=sandbox` | PayU sandbox UAT environment. |
| `prod` | `PAYOUT_GATEWAY_PROVIDER=prod` | PayU production UPI disbursement. |

### Acceptance Checklist (before setting `PAYOUT_GATEWAY_PROVIDER=prod`)

- [ ] PayU production merchant account created and KYC complete
- [ ] Production API key issued and stored in secrets manager (not env file)
- [ ] `PAYU_PROD_URL` and `PAYU_PROD_API_KEY` set in production environment
- [ ] Webhook endpoint `/payouts/webhook` registered with PayU production
- [ ] End-to-end test: real ₹1 payout to test UPI ID, confirmed in bank statement
- [ ] Retry/backoff behavior tested: simulate PayU 5xx and verify 5 retries + DLQ
- [ ] Transaction reconciliation: verify `payu_txn_ref` maps to PayU dashboard entry
- [ ] Rate limits documented: max TPS, daily limits per merchant
- [ ] SLA documented: expected disbursement latency p50/p95/p99
