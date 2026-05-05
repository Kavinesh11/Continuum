"use client";

import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

function OutcomeBadge({ outcome }: { outcome: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    Blocked:         { bg: "rgba(239,68,68,0.12)",   color: "#EF4444" },
    Paid:            { bg: "rgba(34,197,94,0.12)",   color: "#22C55E" },
    Vetoed:          { bg: "rgba(239,68,68,0.12)",   color: "#EF4444" },
    Escalated:       { bg: "rgba(245,158,11,0.12)",  color: "#F59E0B" },
    Eligible:        { bg: "rgba(34,197,94,0.12)",   color: "#22C55E" },
    Nullified:       { bg: "rgba(239,68,68,0.12)",   color: "#EF4444" },
    Abstained:       { bg: "rgba(148,163,184,0.12)", color: "#94A3B8" },
    Affirm:          { bg: "rgba(34,197,94,0.12)",   color: "#22C55E" },
    "Payout Frozen": { bg: "rgba(245,158,11,0.12)",  color: "#F59E0B" },
    Rejected:        { bg: "rgba(239,68,68,0.12)",   color: "#EF4444" },
    Cleared:         { bg: "rgba(34,197,94,0.12)",   color: "#22C55E" },
  };
  const s = map[outcome] ?? { bg: "rgba(148,163,184,0.12)", color: "#94A3B8" };
  return (
    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold flex-shrink-0" style={{ background: s.bg, color: s.color }}>
      {outcome}
    </span>
  );
}

function DescriptionText({ text }: { text: string }) {
  const parts = text.split(/(<strong>.*?<\/strong>|<code>.*?<\/code>)/g);
  return (
    <p className="text-[11px] mt-3 leading-relaxed" style={{ color: "#64748B" }}>
      {parts.map((part, i) => {
        if (part.startsWith("<strong>")) {
          return <span key={i} style={{ color: "#CBD5E1", fontWeight: 600 }}>{part.slice(8, -9)}</span>;
        }
        if (part.startsWith("<code>")) {
          return (
            <code key={i} style={{ background: "rgba(51,65,85,0.4)", color: "#94A3B8", padding: "1px 5px", borderRadius: "3px", fontSize: "10px", fontFamily: "monospace" }}>
              {part.slice(6, -7)}
            </code>
          );
        }
        return part;
      })}
    </p>
  );
}

function LayerCard({
  layer, title, tagline, metric, metricLabel, description, cols, rows, onTap,
}: {
  layer: number; title: string; tagline: string;
  metric: string; metricLabel: string; description: string;
  cols: string[]; rows: { cells: (string | number)[]; outcome: string; detail: string; id: string }[];
  onTap: () => void;
}) {
  return (
    <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
      {/* Header */}
      <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.4)" }}>
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1.5">
              <span className="px-2 py-0.5 text-[9px] font-bold uppercase tracking-widest rounded-full"
                style={{ background: "rgba(0,138,138,0.2)", color: "#00BFA6", border: "1px solid rgba(0,138,138,0.3)" }}>
                Layer {layer}
              </span>
              <h3 className="text-sm font-bold" style={{ color: "#F1F5F9" }}>{title}</h3>
            </div>
            <p className="text-xs" style={{ color: "#64748B" }}>{tagline}</p>
          </div>
          <EasterEggDetector taps={3} onTrigger={onTap}>
            <div className="text-right shrink-0 cursor-pointer select-none rounded-lg px-3 py-2 transition-colors hover:bg-white/5">
              <div className="text-xl font-bold" style={{ color: "#00BFA6" }}>{metric}</div>
              <div className="text-[9px] uppercase tracking-widest mt-0.5" style={{ color: "#475569" }}>{metricLabel}</div>
              <div className="text-[8px] mt-0.5" style={{ color: "#334155" }}>tap 3× to simulate</div>
            </div>
          </EasterEggDetector>
        </div>
        <DescriptionText text={description} />
      </div>

      {/* Table */}
      <div>
        <div className="flex items-center gap-3 px-5 py-2.5" style={{ borderBottom: "1px solid rgba(51,65,85,0.3)", background: "rgba(15,23,42,0.4)" }}>
          <div className="flex-1 grid gap-3" style={{ gridTemplateColumns: `repeat(${cols.length}, minmax(0,1fr))` }}>
            {cols.map((c) => (
              <span key={c} className="text-[9px] uppercase tracking-widest font-semibold" style={{ color: "#334155" }}>{c}</span>
            ))}
          </div>
          <span className="text-[9px] uppercase tracking-widest font-semibold flex-shrink-0 w-24 text-right" style={{ color: "#334155" }}>Outcome</span>
        </div>

        {rows.map((row) => (
          <details key={row.id} className="group">
            <summary className="flex items-center gap-3 px-5 py-3 cursor-pointer list-none [&::-webkit-details-marker]:hidden hover:bg-white/[0.02]"
              style={{ borderBottom: "1px solid rgba(51,65,85,0.25)" }}>
              <div className="flex-1 grid gap-3" style={{ gridTemplateColumns: `repeat(${cols.length}, minmax(0,1fr))` }}>
                {row.cells.map((c, ci) => (
                  <span key={ci} className="text-xs truncate"
                    style={{ color: ci === 0 ? "#94A3B8" : "#64748B", fontFamily: ci === 0 ? "monospace" : "inherit" }}>
                    {c}
                  </span>
                ))}
              </div>
              <OutcomeBadge outcome={row.outcome} />
            </summary>
            <div className="mx-5 mb-3 mt-1.5 rounded-lg px-4 py-3 text-[11px] leading-relaxed"
              style={{ background: "#273548", border: "1px solid rgba(51,65,85,0.4)", color: "#94A3B8" }}>
              {row.detail}
            </div>
          </details>
        ))}

        {rows.length === 0 && (
          <div className="px-5 py-4 text-xs" style={{ color: "#334155" }}>
            No incidents recorded. Tap the metric 3× to simulate one.
          </div>
        )}
      </div>
    </div>
  );
}

export default function RiskIntelligencePage() {
  const {
    geoFenceIncidents, trustSignalIncidents, identityAnchorIncidents,
    activityCrossIncidents, fairTimeIncidents,
    addGeoFenceIncident, addTrustSignalIncident, addIdentityAnchorIncident,
    addActivityCrossIncident, addFairTimeIncident,
  } = useDemo();

  return (
    <AdminShell
      title="Risk Intelligence"
      subtitle="Five independent protection layers — fraud prevention, oracle integrity, identity assurance."
    >
      <div className="flex flex-col gap-4">

        {/* Overview banner */}
        <div className="rounded-xl p-5" style={{ background: "rgba(0,138,138,0.06)", border: "1px solid rgba(0,138,138,0.18)" }}>
          <p className="text-sm font-semibold mb-1.5" style={{ color: "#F1F5F9" }}>Five-Layer Protection Architecture</p>
          <p className="text-xs leading-relaxed mb-3" style={{ color: "#64748B" }}>
            Every claim passes through five independent layers before a rupee moves.
            Each layer targets a distinct attack vector and produces a structured audit record.
            Tap any metric 3× to simulate a live incident.
          </p>
          <div className="flex flex-wrap gap-2">
            {["GeoFence Integrity™", "TrustSignal™", "IdentityAnchor™", "ActivityCross™", "FairTime™"].map((name) => (
              <span key={name} className="px-2.5 py-1 text-[10px] font-semibold rounded-full"
                style={{ background: "rgba(0,138,138,0.15)", color: "#00BFA6", border: "1px solid rgba(0,138,138,0.2)" }}>
                {name}
              </span>
            ))}
          </div>
        </div>

        <LayerCard
          layer={1}
          title="GeoFence Integrity™"
          tagline="Catches partners who race into a flood zone seconds before the trigger fires."
          metric={String(geoFenceIncidents.filter(i => i.outcome === "Blocked").length + 44)}
          metricLabel="zone-snipe attempts blocked (30d)"
          description="Requires continuous zone presence for <strong>45+ minutes</strong> before trigger. Late-entry GPS jumps, cell-ID divergence >2 km, and static-lock coordinates are all flagged."
          cols={["Claim ID", "Driver", "Zone", "Entry delta"]}
          rows={geoFenceIncidents.map(r => ({ id: r.id, cells: [r.id, r.driver, r.zone, r.entryDelta], outcome: r.outcome, detail: r.detail }))}
          onTap={addGeoFenceIncident}
        />

        <LayerCard
          layer={2}
          title="TrustSignal™"
          tagline="Neutralises man-in-the-middle attacks injecting fake oracle signals."
          metric="100%"
          metricLabel="oracle feeds TLS-pinned"
          description="Each oracle endpoint is validated against a SHA-256 certificate pin on every poll. A mismatched cert converts the vote to OFFLINE. Stale data (>15 min) abstains. If 2+ oracles go offline with 1 genuine affirm, benefit-of-doubt caps payout at <strong>50%</strong>."
          cols={["Event ID", "Time", "Oracle source", "Incident"]}
          rows={trustSignalIncidents.map(r => ({ id: r.id, cells: [r.id, r.time, r.source, r.event], outcome: r.outcome, detail: r.detail }))}
          onTap={addTrustSignalIncident}
        />

        <LayerCard
          layer={3}
          title="IdentityAnchor™"
          tagline="Detects SIM-swap attacks before a payout reaches the wrong UPI handle."
          metric={String(identityAnchorIncidents.filter(i => ["Payout Frozen","Rejected"].includes(i.outcome)).length)}
          metricLabel="account-takeover attempts blocked (30d)"
          description="Every payout is gated on PlayIntegrity device attestation + IMSI cross-check. A new IMSI on a known device freezes the payout and triggers a <strong>re-KYC flow</strong>."
          cols={["Driver ID", "Driver", "Security event", "Trigger"]}
          rows={identityAnchorIncidents.map(r => ({ id: r.id, cells: [r.id, r.driver, r.event, r.trigger], outcome: r.outcome, detail: r.detail }))}
          onTap={addIdentityAnchorIncident}
        />

        <LayerCard
          layer={4}
          title="ActivityCross™"
          tagline="Real-time cross-reference with Swiggy and Zomato — orders during disruption = veto."
          metric={`+₹${(activityCrossIncidents.filter(i => i.outcome === "Vetoed").length * 4120).toLocaleString()}`}
          metricLabel="fraudulent claims blocked (30d)"
          description="During every claim window, the verifier queries Swiggy and Zomato for active orders. Any confirmed delivery within the disruption window triggers an automatic <strong>veto</strong>. Partial activity escalates to human review."
          cols={["Claim ID", "Driver", "Platform", "Orders found"]}
          rows={activityCrossIncidents.map(r => ({ id: r.id, cells: [r.id, r.driver, r.platform, `${r.ordersFound} order${r.ordersFound !== 1 ? "s" : ""} in ${r.claimWindow}`], outcome: r.outcome, detail: r.detail }))}
          onTap={addActivityCrossIncident}
        />

        <LayerCard
          layer={5}
          title="FairTime™"
          tagline="A 3-hour outage at 2 AM pays nothing if nobody was working — proportional to hours lost."
          metric="₹0"
          metricLabel="paid for zero-overlap outages (30d)"
          description="Payout = <code>tier_benefit × (overlap_hours / outage_hours)</code>. Overlap computed from last-active-order timestamp vs confirmed outage window. Zero overlap = zero benefit."
          cols={["Outage ID", "Zone", "Outage window", "Overlap"]}
          rows={fairTimeIncidents.map(r => ({ id: r.id, cells: [r.id, r.zone, r.outageWindow, `${r.overlapHours}h / ${r.outageHours}h (${r.benefitPct}%)`], outcome: r.outcome, detail: r.detail }))}
          onTap={addFairTimeIncident}
        />

      </div>
    </AdminShell>
  );
}
