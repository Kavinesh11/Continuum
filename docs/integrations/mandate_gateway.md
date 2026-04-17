# MandateGateway Integration

## Adapter: `services/core_backend/src/adapters/mandateGateway/index.js`

### Providers

| Provider | Env Var | Description |
|----------|---------|-------------|
| `mock` | `MANDATE_GATEWAY_PROVIDER=mock` | Deterministic stub. Default for dev/CI. |
| `sandbox` | `MANDATE_GATEWAY_PROVIDER=sandbox` | PayU sandbox eNACH environment. |
| `prod` | `MANDATE_GATEWAY_PROVIDER=prod` | PayU production UPI eNACH. |

### Acceptance Checklist (before setting `MANDATE_GATEWAY_PROVIDER=prod`)

- [ ] PayU eNACH feature enabled on production merchant account
- [ ] Production API key issued and stored in secrets manager
- [ ] `PAYU_PROD_MANDATE_URL` and `PAYU_PROD_API_KEY` set in production environment
- [ ] Webhook endpoint `/mandates/webhook` registered with PayU production
- [ ] End-to-end test: create mandate → authorize → execute ₹1 debit → verify bank debit
- [ ] Mandate lifecycle tested: created → approved → active → debit → revoked
- [ ] Failed debit retry behavior verified (exponential backoff, max 3 retries)
- [ ] Mandate revocation propagation latency measured
- [ ] NPCI eNACH limits documented: max amount, frequency constraints
