import { NextRequest, NextResponse } from "next/server";
import { claimsStore } from "../route";

const cors = { "Access-Control-Allow-Origin": "*" };

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  const claim = claimsStore.get(params.id);
  if (!claim) {
    return NextResponse.json({ error: "Not found" }, { status: 404, headers: cors });
  }
  return NextResponse.json(claim, { headers: cors });
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const claim = claimsStore.get(params.id);
  if (!claim) {
    return NextResponse.json({ error: "Not found" }, { status: 404, headers: cors });
  }
  const body = await req.json();
  const action = body.action as "approve" | "reject";
  const updated = {
    ...claim,
    status: (action === "approve" ? "Approved" : "Rejected") as "Approved" | "Rejected",
    reviewedAt: new Date().toISOString(),
    reviewNote: body.reason ?? (action === "approve" ? "Approved by reviewer" : "Rejected by reviewer"),
    amount: action === "approve" && claim.amount === 0
      ? _defaultPayout(claim.tier)
      : claim.amount,
  };
  claimsStore.set(params.id, updated);
  return NextResponse.json(updated, { headers: cors });
}

export function OPTIONS() {
  return new NextResponse(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, PATCH, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}

function _defaultPayout(tier: string): number {
  if (tier === "Platinum") return 450;
  if (tier === "Gold") return 312;
  return 180;
}
