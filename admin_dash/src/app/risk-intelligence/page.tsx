"use client";

import { ReactNode } from "react";
import { AdminShell } from "@/components/admin-shell";

// ── Static demo data for each protection layer ────────────────────────────────

const GEOFENCE_INCIDENTS = [
  { id: "CLM-4491-77", driver: "Ranjit S.", zone: "BLR-South", entryDelta: "8 min before trigger", soakMinutes: 8, outcome: "Blocked", detail: "Entry detected 8 min before flood trigger. Soak threshold: 45 min." },
  { id: "CLM-3302-14", driver: "Meena V.", zone: "CHN-Central", entryDelta: "12 min before trigger", soakMinutes: 12, outcome: "Blocked", detail: "GPS jump from OMR to flood zone 12 min pre-trigger. Static-lock flag raised." },
  { id: "CLM-8821-03", driver: "Harish D.", zone: "BLR-North", entryDelta: "51 min before trigger", soakMinutes: 51, outcome: "Paid", detail: "Soak period satisfied. Genuine pre-positioning confirmed by cell-ID corroboration." },
];

const TRUSTSIGNAL_INCIDENTS = [
  { id: "ORC-001", time: "2026-05-02 14:31", source: "AccuWeather Feed", event: "TLS certificate mismatch", pin: "SHA-256 expected: 3A9F…C2 — received: 7B1E…44", outcome: "Nullified", detail: "Vote counted as OFFLINE. Benefit-of-doubt protocol engaged (2/4 online, 1 affirm → 50% cap)." },
  { id: "ORC-002", time: "2026-05-03 09:17", source: "IMD API", event: "Stale data replay (22 min old)", pin: "Staleness rule >15 min", outcome: "Abstained", detail: "Data timestamp 22 min old. Vote converted to ABSTAIN — did not count toward consensus." },
  { id: "ORC-003", time: "2026-05-04 18:55", source: "NASA GPM", event: "Valid response", pin: "SHA-256 verified", outcome: "Affirm", detail: "Certificate pinning passed. Fresh data (<8 min). Vote counted in consensus." },
];

const IDENTITY_ANCHOR_INCIDENTS = [
  { id: "DRV-7712", driver: "Priya K.", event: "SIM swap detected", trigger: "New IMSI on known device — 3-hour window", outcome: "Payout Frozen", detail: "UPI handle unchanged but IMSI rotated. Payout frozen pending re-attestation via PlayIntegrity + OTP." },
  { id: "DRV-3301", driver: "Selvam R.", event: "New device binding attempt", trigger: "PlayIntegrity verdict: FAILS_BASIC_INTEGRITY", outcome: "Rejected", detail: "Device attestation failed. JWT revoked. Account locked for 24h pending manual KYC re-verification." },
  { id: "DRV-9988", driver: "Anita B.", event: "Routine re-attestation", trigger: "JWT nearing 24h expiry — auto-refreshed", outcome: "Cleared", detail: "Re-attestation passed. IMSI, device fingerprint, and UPI cross-checked. No anomaly." },
];

const ACTIVITY_CROSS_INCIDENTS = [
  { id: "CLM-5541-99", driver: "Venkat P.", platform: "Swiggy", ordersFound: 3, claimWindow: "15:00–19:00", outcome: "Vetoed", detail: "3 orders completed on Swiggy during claimed disruption window. Platform API veto applied — claim auto-rejected." },
  { id: "CLM-6632-07", driver: "Deepa N.", platform: "Zomato", ordersFound: 1, claimWindow: "10:00–14:00", outcome: "Escalated", detail: "1 order found. Partial activity — escalated to human reviewer. Possible order accepted before disruption widened." },
  { id: "CLM-8870-12", driver: "Sunil T.", platform: "Swiggy + Zomato", ordersFound: 0, claimWindow: "09:00–13:00", outcome: "Eligible", detail: "Zero orders on both platforms during window. No active-work signal. Claim auto-approved at oracle consensus." },
];

const FAIRTIME_INCIDENTS = [
  { id: "OUT-2205-01", zone: "BLR-South", outageWindow: "01:45–04:30", outageHours: 2.75, driverActiveHours: 0, overlapHours: 0, benefitPct: 0, outcome: "₹0 paid", detail: "Outage occurred 1:45–4:30 AM. Driver's last active order was 23:10. Zero overlap → ₹0 benefit." },
  { id: "OUT-2205-02", zone: "CHN-Central", outageWindow: "07:00–10:00", outageHours: 3, driverActiveHours: 2.5, overlapHours: 2.5, benefitPct: 83, outcome: "₹374 paid", detail: "Outage 7–10 AM. Driver active 7:00–9:30 (2.5h overlap out of 3h outage = 83% benefit)." },
  { id: "OUT-2205-03", zone: "KOL-South", outageWindow: "02:00–05:00", outageHours: 3, driverActiveHours: 1, overlapHours: 1, benefitPct: 33, outcome: "₹149 paid", detail: "Late-night shift driver — 1h overlap with outage. 33% proportional benefit applied." },
];

// ── Outcome badge ─────────────────────────────────────────────────────────────

function OutcomeBadge({ outcome }: { outcome: string }) {
  const map: Record<string, string> = {
    Blocked: "bg-red-100 text-red-700",
    Paid: "bg-green-100 text-green-700",
    Vetoed: "bg-red-100 text-red-700",
    Escalated: "bg-amber-100 text-amber-700",
    Eligible: "bg-green-100 text-green-700",
    Nullified: "bg-red-100 text-red-700",
    Abstained: "bg-slate-100 text-slate-600",
    Affirm: "bg-green-100 text-green-700",
    Frozen: "bg-amber-100 text-amber-700",
    "Payout Frozen": "bg-amber-100 text-amber-700",
    Rejected: "bg-red-100 text-red-700",
    Cleared: "bg-green-100 text-green-700",
  };
  const cls = map[outcome] ?? "bg-slate-100 text-slate-600";
  return <span className={`px-2 py-0.5 rounded-full text-[11px] font-semibold ${cls}`}>{outcome}</span>;
}

// ── Section header ────────────────────────────────────────────────────────────

function SectionHeader({ tag, title, tagline, metric, metricLabel }: {
  tag: string; title: string; tagline: string; metric: string; metricLabel: string;
}) {
  return (
    <div className="flex items-start justify-between mb-5">
      <div>
        <div className="flex items-center gap-2 mb-1">
          <span className="px-2 py-0.5 text-[10px] font-bold uppercase tracking-widest rounded bg-teal-700 text-teal-100">{tag}</span>
          <h3 className="text-base font-bold text-slate-900">{title}</h3>
        </div>
        <p className="text-sm text-slate-500">{tagline}</p>
      </div>
      <div className="text-right shrink-0 ml-4">
        <div className="text-2xl font-bold text-teal-700">{metric}</div>
        <div className="text-xs text-slate-400 mt-0.5">{metricLabel}</div>
      </div>
    </div>
  );
}

// ── Incident row ──────────────────────────────────────────────────────────────

function IncidentRow({ cells, outcome, detail }: { cells: (string | number)[]; outcome: string; detail: string }) {
  return (
    <details className="group">
      <summary className="grid items-center gap-3 px-4 py-3 text-sm cursor-pointer hover:bg-teal-50 rounded-lg list-none [&::-webkit-details-marker]:hidden"
        style={{ gridTemplateColumns: `repeat(${cells.length}, minmax(0, 1fr)) auto` }}>
        {cells.map((c, i) => (
          <span key={i} className="text-slate-700 truncate">{c}</span>
        ))}
        <OutcomeBadge outcome={outcome} />
      </summary>
      <div className="mx-4 mb-3 mt-1 text-xs text-slate-600 bg-slate-50 rounded-lg p-3 border border-slate-100">
        {detail}
      </div>
    </details>
  );
}

// ── Feature card wrapper ──────────────────────────────────────────────────────

function FeatureCard({ children }: { children: ReactNode }) {
  return (
    <div className="bg-white rounded-2xl shadow-sm ring-1 ring-teal-100 p-6">
      {children}
    </div>
  );
}

// ── Column header row ─────────────────────────────────────────────────────────

function TableHeader({ cols }: { cols: string[] }) {
  return (
    <div className="grid px-4 pb-2 gap-3 border-b border-slate-100 mb-1"
      style={{ gridTemplateColumns: `repeat(${cols.length}, minmax(0, 1fr)) auto` }}>
      {cols.map((c) => (
        <span key={c} className="text-[10px] uppercase tracking-wider font-semibold text-slate-400">{c}</span>
      ))}
      <span className="text-[10px] uppercase tracking-wider font-semibold text-slate-400">Outcome</span>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function RiskIntelligencePage() {
  return (
    <AdminShell
      title="Risk Intelligence"
      subtitle="Five layered protection systems — edge-case detection, fraud prevention, and fair payout logic."
    >
      <div className="flex flex-col gap-6">

        {/* Overview banner */}
        <div className="bg-teal-900 text-teal-50 rounded-2xl p-6 flex flex-col gap-1">
          <h3 className="text-base font-semibold">Five-Layer Protection Architecture</h3>
          <p className="text-sm text-teal-300 leading-relaxed max-w-3xl">
            Every claim passes through five independent protection layers before a rupee moves. Each layer targets a
            distinct attack or edge-case vector — from zone-timing manipulation to oracle feed injection — and produces
            a structured audit record visible below.
          </p>
          <div className="mt-4 flex flex-wrap gap-3">
            {[
              "GeoFence Integrity™",
              "TrustSignal™",
              "IdentityAnchor™",
              "ActivityCross™",
              "FairTime™",
            ].map((name) => (
              <span key={name} className="px-3 py-1 text-xs font-semibold rounded-full bg-teal-800 text-teal-200 ring-1 ring-teal-700">
                {name}
              </span>
            ))}
          </div>
        </div>

        {/* ── 1. GeoFence Integrity™ ─────────────────────────────────────── */}
        <FeatureCard>
          <SectionHeader
            tag="Layer 1"
            title="GeoFence Integrity™"
            tagline="Catches partners who race into a flood zone seconds before the trigger fires — and nowhere near it before."
            metric="47"
            metricLabel="zone-snipe attempts blocked (30d)"
          />
          <p className="text-xs text-slate-500 mb-4">
            Requires continuous zone presence for <strong>≥45 minutes</strong> before a trigger fires. Late-entry GPS jumps,
            cell-ID vs GPS divergence &gt;2 km, and identical coordinate static-locks are all flagged.
          </p>
          <TableHeader cols={["Claim ID", "Driver", "Zone", "Entry delta"]} />
          {GEOFENCE_INCIDENTS.map((r) => (
            <IncidentRow
              key={r.id}
              cells={[r.id, r.driver, r.zone, r.entryDelta]}
              outcome={r.outcome}
              detail={r.detail}
            />
          ))}
        </FeatureCard>

        {/* ── 2. TrustSignal™ ───────────────────────────────────────────── */}
        <FeatureCard>
          <SectionHeader
            tag="Layer 2"
            title="TrustSignal™"
            tagline="Neutralises man-in-the-middle attacks that inject fake 'rain confirmed' signals into weather oracles."
            metric="100%"
            metricLabel="oracle feeds TLS-pinned"
          />
          <p className="text-xs text-slate-500 mb-4">
            Each oracle endpoint is validated against a SHA-256 certificate pin on every poll. A mismatched certificate
            converts the vote to <strong>OFFLINE</strong> — not <em>Affirm</em>. Stale data (&gt;15 min) abstains.
            If ≥2 oracles go offline with ≥1 genuine affirm, benefit-of-doubt caps payout at <strong>50%</strong>.
          </p>
          <TableHeader cols={["Event ID", "Time", "Oracle source", "Incident"]} />
          {TRUSTSIGNAL_INCIDENTS.map((r) => (
            <IncidentRow
              key={r.id}
              cells={[r.id, r.time, r.source, r.event]}
              outcome={r.outcome}
              detail={r.detail}
            />
          ))}
        </FeatureCard>

        {/* ── 3. IdentityAnchor™ ────────────────────────────────────────── */}
        <FeatureCard>
          <SectionHeader
            tag="Layer 3"
            title="IdentityAnchor™"
            tagline="Detects SIM-swap attacks and device hijacks before a payout can reach the wrong UPI handle."
            metric="3"
            metricLabel="account-takeover attempts blocked (30d)"
          />
          <p className="text-xs text-slate-500 mb-4">
            Every payout is gated on PlayIntegrity device attestation + IMSI cross-check against the enrolled device
            fingerprint. A new IMSI on a known device, or a failed integrity verdict, freezes the payout and triggers
            a re-KYC flow — no rupee moves until re-attestation and OTP confirmation.
          </p>
          <TableHeader cols={["Driver ID", "Driver", "Security event", "Trigger"]} />
          {IDENTITY_ANCHOR_INCIDENTS.map((r) => (
            <IncidentRow
              key={r.id}
              cells={[r.id, r.driver, r.event, r.trigger]}
              outcome={r.outcome}
              detail={r.detail}
            />
          ))}
        </FeatureCard>

        {/* ── 4. ActivityCross™ ─────────────────────────────────────────── */}
        <FeatureCard>
          <SectionHeader
            tag="Layer 4"
            title="ActivityCross™"
            tagline="Real-time cross-reference with Swiggy and Zomato APIs — if you completed orders, you weren't disrupted."
            metric="₹12,400"
            metricLabel="fraudulent claims blocked (30d)"
          />
          <p className="text-xs text-slate-500 mb-4">
            During every claim window, the platform verifier queries Swiggy and Zomato for active orders assigned to
            the claimant. Any confirmed order delivery within the disruption window triggers an automatic <strong>veto</strong>.
            Partial activity (1 order) escalates to human review.
          </p>
          <TableHeader cols={["Claim ID", "Driver", "Platform", "Orders found"]} />
          {ACTIVITY_CROSS_INCIDENTS.map((r) => (
            <IncidentRow
              key={r.id}
              cells={[r.id, r.driver, r.platform, `${r.ordersFound} order${r.ordersFound !== 1 ? "s" : ""} in ${r.claimWindow}`]}
              outcome={r.outcome}
              detail={r.detail}
            />
          ))}
        </FeatureCard>

        {/* ── 5. FairTime™ ──────────────────────────────────────────────── */}
        <FeatureCard>
          <SectionHeader
            tag="Layer 5"
            title="FairTime™"
            tagline="A 3-hour outage at 2 AM doesn't pay if nobody was working — benefit is proportional to actual earning hours lost."
            metric="₹0"
            metricLabel="paid for zero-overlap outages (30d)"
          />
          <p className="text-xs text-slate-500 mb-4">
            Payout = <code className="bg-slate-100 px-1 rounded text-slate-700">tier_daily_benefit × (overlap_hours / outage_hours)</code>.
            The overlap is computed from the driver's last-active-order timestamp on the platform API vs the confirmed outage window.
            Zero overlap = zero benefit. Full overlap = full benefit.
          </p>
          <TableHeader cols={["Outage ID", "Zone", "Outage window", "Overlap"]} />
          {FAIRTIME_INCIDENTS.map((r) => (
            <IncidentRow
              key={r.id}
              cells={[r.id, r.zone, r.outageWindow, `${r.overlapHours}h / ${r.outageHours}h (${r.benefitPct}%)`]}
              outcome={r.outcome}
              detail={r.detail}
            />
          ))}
        </FeatureCard>

      </div>
    </AdminShell>
  );
}
