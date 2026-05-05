"use client";

import { useState, useEffect } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

// ── Metric card ───────────────────────────────────────────────────────────────

function MetricCard({
  label, value, unit, threshold, thresholdLabel, dangerWhen, sub, onTaps, taps,
}: {
  label: string; value: number; unit?: string; threshold: number;
  thresholdLabel: string; dangerWhen: "above" | "below";
  sub?: string; onTaps?: () => void; taps?: number;
}) {
  const isDanger = dangerWhen === "above" ? value > threshold : value < threshold;
  const isWarn   = !isDanger && (dangerWhen === "above" ? value > threshold * 0.85 : value < threshold * 1.15);
  const accentColor = isDanger ? "#EF4444" : isWarn ? "#F59E0B" : "#22C55E";

  const inner = (
    <div className="relative rounded-xl p-5 overflow-hidden border transition-all duration-200 hover:border-opacity-60 cursor-default"
      style={{ background: "#1E293B", borderColor: isDanger ? "rgba(239,68,68,0.3)" : "rgba(51,65,85,0.5)" }}>
      <div className="absolute top-0 right-0 w-32 h-32 rounded-full -translate-y-10 translate-x-10 opacity-[0.05]"
        style={{ background: accentColor }} />
      <div className="flex items-start justify-between mb-4">
        <span className="text-[10px] font-semibold uppercase tracking-widest" style={{ color: "#475569" }}>{label}</span>
        <span className="w-2 h-2 rounded-full mt-0.5 flex-shrink-0" style={{ background: accentColor }} />
      </div>
      <div className="flex items-end gap-1 mb-2">
        <span className="text-4xl font-black tracking-tight" style={{ color: accentColor }}>{value}</span>
        {unit && <span className="text-base pb-0.5 font-medium" style={{ color: "#475569" }}>{unit}</span>}
      </div>
      <div className="text-[10px]" style={{ color: "#475569" }}>{thresholdLabel}</div>
      {sub && <div className="text-[10px] mt-2 pt-2" style={{ color: "#64748B", borderTop: "1px solid rgba(51,65,85,0.4)" }}>{sub}</div>}
    </div>
  );

  if (onTaps && taps) {
    return <EasterEggDetector taps={taps} onTrigger={onTaps}>{inner}</EasterEggDetector>;
  }
  return inner;
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

function BarChart({ data, labels }: { data: number[]; labels: string[] }) {
  const max = Math.max(...data);
  const [hovered, setHovered] = useState<number | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setMounted(true), 100);
    return () => clearTimeout(t);
  }, []);

  return (
    <div className="relative">
      {/* Y-axis grid lines */}
      <div className="absolute inset-x-0 top-0 bottom-8 pointer-events-none">
        {[0.25, 0.5, 0.75, 1].map((pct) => (
          <div key={pct} className="absolute w-full" style={{
            bottom: `${pct * 100}%`,
            borderTop: "1px dashed rgba(51,65,85,0.4)",
          }}>
            <span className="absolute -top-2.5 -left-8 text-[9px]" style={{ color: "#334155" }}>
              ₹{((max * pct) / 1000).toFixed(0)}K
            </span>
          </div>
        ))}
      </div>

      <div className="flex items-end gap-2 h-44 pl-8">
        {data.map((val, i) => {
          const isLast = i === data.length - 1;
          const pct = mounted ? (val / max) * 100 : 0;
          const isHov = hovered === i;
          return (
            <div key={i} className="flex-1 flex flex-col items-center gap-2 group relative"
              onMouseEnter={() => setHovered(i)} onMouseLeave={() => setHovered(null)}>
              {/* Tooltip */}
              {isHov && (
                <div className="absolute -top-8 left-1/2 -translate-x-1/2 px-2 py-1 rounded text-[10px] font-semibold whitespace-nowrap z-10"
                  style={{ background: "#0F172A", color: "#00BFA6", border: "1px solid rgba(0,191,166,0.3)" }}>
                  ₹{(val / 1000).toFixed(1)}K
                </div>
              )}
              <div className="w-full rounded-t-md transition-all duration-700 ease-out relative overflow-hidden"
                style={{
                  height: `${pct}%`,
                  minHeight: "4px",
                  background: isLast
                    ? "linear-gradient(180deg, #00BFA6 0%, #008A8A 100%)"
                    : isHov
                    ? "linear-gradient(180deg, #008A8A 0%, #005F5F 100%)"
                    : "linear-gradient(180deg, rgba(0,138,138,0.6) 0%, rgba(0,138,138,0.2) 100%)",
                  boxShadow: isLast ? "0 0 20px rgba(0,191,166,0.3)" : "none",
                }}>
                {isLast && (
                  <div className="absolute inset-0 opacity-30"
                    style={{ background: "linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent)" }} />
                )}
              </div>
              <span className="text-[9px] font-medium" style={{ color: isLast ? "#00BFA6" : "#334155" }}>
                {labels[i]}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Donut mini ────────────────────────────────────────────────────────────────

function RunwayGauge({ days }: { days: number }) {
  const maxDays = 120;
  const pct = Math.min(days / maxDays, 1);
  const color = days < 60 ? "#EF4444" : days < 90 ? "#F59E0B" : "#008A8A";
  const r = 44;
  const circ = 2 * Math.PI * r;
  const dash = circ * pct;

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="relative">
        <svg width="120" height="120" className="-rotate-90">
          <circle cx="60" cy="60" r={r} fill="none" stroke="rgba(51,65,85,0.4)" strokeWidth="8" />
          <circle cx="60" cy="60" r={r} fill="none" stroke={color} strokeWidth="8"
            strokeDasharray={`${dash} ${circ - dash}`}
            strokeLinecap="round"
            style={{ filter: `drop-shadow(0 0 6px ${color}60)`, transition: "stroke-dasharray 1s ease" }} />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-3xl font-black" style={{ color }}>{days}</span>
          <span className="text-[10px]" style={{ color: "#475569" }}>days</span>
        </div>
      </div>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ExecutivePage() {
  const { executiveKpis, reserveFloorBreach } = useDemo();
  const [lastUpdated, setLastUpdated] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setLastUpdated((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <AdminShell
      title="Executive Dashboard"
      subtitle="Board-level health metrics — loss ratio, actuarial solvency, and zone profitability."
      badge="CEO"
    >
      <div className="flex flex-col gap-5">

        {/* ── Live indicator ──────────────────────────────────────────── */}
        <div className="flex items-center gap-2 px-1">
          <span className="live-dot w-1.5 h-1.5 rounded-full" style={{ background: "#22C55E" }} />
          <span className="text-xs" style={{ color: "#475569" }}>
            Live — refreshed {lastUpdated}s ago
          </span>
        </div>

        {/* ── KPI strip ───────────────────────────────────────────────── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <MetricCard
            label="Loss Ratio"
            value={executiveKpis.lossRatio}
            unit="%"
            threshold={100}
            thresholdLabel="Target ≤ 100% (invariant V24)"
            dangerWhen="above"
            sub="Claims paid ÷ premiums collected"
          />
          <MetricCard
            label="Benefit-Cost Ratio"
            value={executiveKpis.bcr}
            threshold={1.05}
            thresholdLabel="Floor ≥ 1.05 (invariant V25)"
            dangerWhen="below"
            sub="Social return per ₹ operating cost"
            onTaps={reserveFloorBreach}
            taps={4}
          />
          <MetricCard
            label="Brier Score"
            value={executiveKpis.brierScore}
            threshold={0.20}
            thresholdLabel="CI gate < 0.20 (invariant V26)"
            dangerWhen="above"
            sub="Oracle forecast accuracy — lower is better"
          />
          <MetricCard
            label="Partner Retention"
            value={executiveKpis.partnerRetention}
            unit="%"
            threshold={85}
            thresholdLabel="Target ≥ 85%"
            dangerWhen="below"
            sub="Drivers renewing after first claim"
          />
        </div>

        {/* ── Chart row ───────────────────────────────────────────────── */}
        <div className="grid lg:grid-cols-3 gap-4">

          {/* Weekly payout bar chart */}
          <div className="lg:col-span-2 rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-6 py-4 border-b flex items-center justify-between" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
              <div>
                <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Weekly Payout Volume</h3>
                <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>Rolling 7 weeks — ₹ disbursed to gig workers</p>
              </div>
              <div className="text-right">
                <div className="text-xl font-bold" style={{ color: "#00BFA6" }}>
                  ₹{(executiveKpis.totalPayoutMTD / 1000).toFixed(1)}K
                </div>
                <div className="text-[10px] uppercase tracking-widest" style={{ color: "#475569" }}>MTD</div>
              </div>
            </div>
            <div className="px-6 pb-5 pt-6">
              <BarChart
                data={executiveKpis.weeklyPayoutTrend}
                labels={["W-6","W-5","W-4","W-3","W-2","W-1","This"]}
              />
            </div>
          </div>

          {/* Reserve runway gauge */}
          <div className="rounded-xl border flex flex-col" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
              <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Reserve Runway</h3>
              <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>Days covered at current burn rate</p>
            </div>
            <div className="flex-1 flex flex-col items-center justify-center p-6 gap-4">
              <RunwayGauge days={executiveKpis.reserveRunwayDays} />
              <p className="text-[11px] text-center leading-relaxed" style={{ color: "#64748B" }}>
                {executiveKpis.reserveRunwayDays >= 90
                  ? "Runway healthy — next actuarial review in 12 days"
                  : executiveKpis.reserveRunwayDays >= 60
                  ? "Approaching threshold — monitor closely"
                  : "Below threshold — autopay paused on new policies"}
              </p>
            </div>
          </div>
        </div>

        {/* ── Zone profitability matrix ────────────────────────────────── */}
        <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
          <div className="px-6 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
            <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Zone Profitability Matrix</h3>
            <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>
              Active zones — {executiveKpis.activePolicies.toLocaleString()} total policies enrolled
            </p>
          </div>
          <table className="w-full text-sm">
            <thead>
              <tr style={{ borderBottom: "1px solid rgba(51,65,85,0.4)" }}>
                {["Zone", "Active Policies", "Loss Ratio", "BCR", "Status"].map((h, i) => (
                  <th key={h} className={`py-3 text-[10px] font-semibold uppercase tracking-widest ${i === 0 ? "text-left px-6" : i === 4 ? "text-right px-6" : "text-right px-4"}`}
                    style={{ color: "#475569" }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {executiveKpis.zoneMetrics.map((z, i) => (
                <tr key={z.zone} style={{ borderBottom: i < executiveKpis.zoneMetrics.length - 1 ? "1px solid rgba(51,65,85,0.3)" : "none" }}>
                  <td className="px-6 py-4 font-medium" style={{ color: "#CBD5E1" }}>{z.zone}</td>
                  <td className="px-4 py-4 text-right" style={{ color: "#94A3B8" }}>{z.policies.toLocaleString()}</td>
                  <td className="px-4 py-4 text-right">
                    <span className="font-semibold" style={{ color: z.lossRatio > 90 ? "#F59E0B" : "#22C55E" }}>
                      {z.lossRatio}%
                    </span>
                  </td>
                  <td className="px-4 py-4 text-right">
                    <span className="font-semibold" style={{ color: z.bcr < 1.1 ? "#F59E0B" : "#00BFA6" }}>
                      {z.bcr.toFixed(2)}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <span className="px-2.5 py-1 rounded-full text-[10px] font-semibold" style={{
                      background: z.status === "Optimal" ? "rgba(34,197,94,0.15)" : "rgba(0,138,138,0.15)",
                      color: z.status === "Optimal" ? "#22C55E" : "#00BFA6",
                    }}>
                      {z.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* ── Bottom KPI row ───────────────────────────────────────────── */}
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: "Active Policies",   value: executiveKpis.activePolicies.toLocaleString(), sub: "across all zones" },
            { label: "Avg Payout / Claim", value: `₹${executiveKpis.avgPayoutPerClaim}`,        sub: "weighted by tier" },
            { label: "MTD Disbursements",  value: `₹${(executiveKpis.totalPayoutMTD / 1000).toFixed(0)}K`, sub: "month to date" },
          ].map((s) => (
            <div key={s.label} className="rounded-xl border p-5" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
              <div className="text-[10px] uppercase tracking-widest mb-2" style={{ color: "#475569" }}>{s.label}</div>
              <div className="text-2xl font-bold" style={{ color: "#00BFA6" }}>{s.value}</div>
              <div className="text-[10px] mt-1" style={{ color: "#475569" }}>{s.sub}</div>
            </div>
          ))}
        </div>

      </div>
    </AdminShell>
  );
}
