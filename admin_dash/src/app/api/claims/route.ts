import { NextRequest, NextResponse } from "next/server";

export type AdminClaim = {
  id: string;
  driver: string;
  tier: string;
  zone: string;
  reason: string;
  description: string;
  amount: number;
  status: "Pending" | "Approved" | "Rejected";
  fraudScore: number;
  priority: "High" | "Medium" | "Low";
  submittedAt: string;
  reviewedAt?: string;
  reviewNote?: string;
  isFraud?: boolean;
};

// Module-level in-memory store — persists for the lifetime of the Next.js process
const claimsStore = new Map<string, AdminClaim>();

export function GET() {
  const all = Array.from(claimsStore.values()).sort(
    (a, b) => new Date(b.submittedAt).getTime() - new Date(a.submittedAt).getTime()
  );
  return NextResponse.json(all, {
    headers: { "Access-Control-Allow-Origin": "*" },
  });
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const claim: AdminClaim = {
    id: body.id ?? `CLM-${Math.floor(Math.random() * 9000) + 1000}-${Math.floor(Math.random() * 90) + 10}`,
    driver: body.driver ?? "Unknown Driver",
    tier: body.tier ?? "Silver",
    zone: body.zone ?? "Unknown Zone",
    reason: body.reason ?? "Disruption",
    description: body.description ?? "",
    amount: body.amount ?? 0,
    status: "Pending",
    fraudScore: body.fraudScore ?? 0,
    priority: body.priority ?? "Medium",
    submittedAt: body.submittedAt ?? new Date().toISOString(),
    isFraud: body.isFraud ?? false,
  };
  claimsStore.set(claim.id, claim);
  return NextResponse.json(claim, {
    status: 201,
    headers: { "Access-Control-Allow-Origin": "*" },
  });
}

export function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}

// Export store so [id] route can access it
export { claimsStore };
