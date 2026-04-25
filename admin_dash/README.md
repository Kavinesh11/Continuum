# Continuum Admin Dashboard

This is the Continuum admin dashboard built with [Next.js](https://nextjs.org).

## Getting Started

1. Install dependencies and start the development server:

```bash
npm install
npm run dev
```

1. Configure backend connectivity:

```bash
cp .env.example .env.local
```

Then set these values in `.env.local`:

- `CORE_BACKEND_URL` (example: `http://localhost:3000`)
- `ADMIN_API_TOKEN` (JWT token from your auth flow)
- `ADMIN_WORKER_ID` (worker id used for claims list query)

1. Open [http://localhost:3000](http://localhost:3000).

## Connected Pages

- `/` dashboard KPIs + recent claims (live data when env is configured)
- `/claims` live claim stream from core backend
- `/payouts` live payout stream from core backend
- `/fraud-review` derived flagged queue from claim statuses
- `/zone-controls` zone matrix + embedded map + backend health signal
