const CORE_BACKEND_URL = process.env.CORE_BACKEND_URL || "http://localhost:3000";
const ADMIN_API_TOKEN = process.env.ADMIN_API_TOKEN;
const ADMIN_WORKER_ID = process.env.ADMIN_WORKER_ID;

type FetchOptions = {
  requireWorkerId?: boolean;
};

export type ClaimItem = {
  id: string;
  title: string;
  zone: string;
  status: string;
  amount: number;
  eventDate: string;
};

export type PayoutItem = {
  payoutId: string;
  claimId: string;
  amount: number;
  status: string;
  createdAt: string;
};

export type BackendHealth = {
  name: string;
  url: string;
  ok: boolean;
};

async function fetchFromCore<T>(path: string, options: FetchOptions = {}): Promise<T | null> {
  if (!ADMIN_API_TOKEN) return null;
  if (options.requireWorkerId && !ADMIN_WORKER_ID) return null;

  const url = new URL(path, CORE_BACKEND_URL);
  if (options.requireWorkerId) {
    url.searchParams.set("worker_id", ADMIN_WORKER_ID as string);
  }

  try {
    const response = await fetch(url.toString(), {
      headers: {
        Authorization: `Bearer ${ADMIN_API_TOKEN}`,
      },
      cache: "no-store",
    });

    if (!response.ok) return null;
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

export async function getClaims(): Promise<ClaimItem[]> {
  const claims = await fetchFromCore<
    Array<{
      id?: string;
      claim_id?: string;
      title?: string;
      zone_id?: string;
      status?: string;
      amount?: number;
      event_date?: string;
      date?: string;
    }>
  >("/claims", { requireWorkerId: true });

  if (!claims) return [];

  return claims.map((item) => ({
    id: item.id || item.claim_id || "unknown",
    title: item.title || "Claim",
    zone: item.zone_id || "Unknown Zone",
    status: item.status || "Unknown",
    amount: Number(item.amount || 0),
    eventDate: item.event_date || item.date || "",
  }));
}

export async function getPayouts(): Promise<PayoutItem[]> {
  const payouts = await fetchFromCore<
    Array<{
      payout_id?: string;
      claim_id?: string;
      amount?: number;
      status?: string;
      created_at?: string;
    }>
  >("/payouts");

  if (!payouts) return [];

  return payouts.map((item) => ({
    payoutId: item.payout_id || "unknown",
    claimId: item.claim_id || "unknown",
    amount: Number(item.amount || 0),
    status: item.status || "unknown",
    createdAt: item.created_at || "",
  }));
}

export async function getCoreHealth(): Promise<BackendHealth> {
  try {
    const healthUrl = new URL("/health", CORE_BACKEND_URL).toString();
    const response = await fetch(healthUrl, { cache: "no-store" });
    return {
      name: "Core Backend",
      url: healthUrl,
      ok: response.ok,
    };
  } catch {
    return {
      name: "Core Backend",
      url: new URL("/health", CORE_BACKEND_URL).toString(),
      ok: false,
    };
  }
}

export function hasBackendCredentials(): boolean {
  return Boolean(ADMIN_API_TOKEN && ADMIN_WORKER_ID);
}
