"use client";

import { useState, useEffect } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";

// ── Donut chart ───────────────────────────────────────────────────────────────

function DonutChart({ segments }: { segments: { label: string; pct: number; color: string }[] }) {
  const r = 52;
  const circ = 2 * Math.PI * r;
  let offset = 0;

  return (
    <div className="relative flex items-center gap-6">
      <div className="relative flex-shrink-0">
        <svg width="140" height="140" className="-rotate-90">
          <circle cx="70" cy="70" r={r} fill="none" stroke="rgba(51,65,85,0.3)" strokeWidth="16" />
          {segments.map((seg, i) => {
            const dash = (seg.pct / 100) * circ;
            const gap  = circ - dash;
            const arc  = (
              <circle
                key={i} cx="70" cy="70" r={r}
                fill="none" stroke={seg.color} strokeWidth="16"
                strokeDasharray={`${dash} ${gap}`}
                strokeDashoffset={-offset}
                style={{ filter: `drop-shadow(0 0 4px ${seg.color}40)` }}
              />
            );
            offset += dash;
            return arc;
          })}
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-xl font-bold" style={{ color: "#00BFA6" }}>4</span>
          <span className="text-[9px]" style={{ color: "#475569" }}>types</span>
        </div>
      </div>
      <div className="space-y-2.5 flex-1">
        {segments.map((seg) => (
          <div key={seg.label} className="flex items-center justify-between text-xs">
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: seg.color }} />
              <span style={{ color: "#94A3B8" }}>{seg.label}</span>
            </div>
            <span className="font-semibold tabular-nums" style={{ color: "#CBD5E1" }}>{seg.pct}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Sparkline SVG ─────────────────────────────────────────────────────────────

function Sparkline({ data, color, height = 40 }: { data: number[]; color: string; height?: number }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const w = 100 / (data.length - 1);
  const points = data.map((v, i) => `${i * w},${height - ((v - min) / range) * height}`).join(" ");
  const areaPoints = `0,${height} ${points} ${(data.length - 1) * w},${height}`;

  return (
    <svg width="100%" height={height} viewBox={`0 0 100 ${height}`} preserveAspectRatio="none">
      <defs>
        <linearGradient id={`sg-${color.replace("#","")}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.3" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon points={areaPoints} fill={`url(#sg-${color.replace("#","")})`} />
      <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// ── Bar chart component ───────────────────────────────────────────────────────

function DarkBarChart({ data, labels, color, valuePrefix = "" }: {
  data: number[]; labels: string[]; color: string; valuePrefix?: string;
}) {
  const max = Math.max(...data);
  const [hovered, setHovered] = useState<number | null>(null);
  const [mounted, setMounted] = useState(false);
  useEffect(() => { const t = setTimeout(() => setMounted(true), 80); return () => clearTimeout(t); }, []);

  return (
    <div className="relative pl-6">
      {[0.5, 1].map((pct) => (
        <div key={pct} className="absolute left-0 right-0 pointer-events-none"
          style={{ bottom: `calc(${pct * 100}% + 16px)`, borderTop: "1px dashed rgba(51,65,85,0.4)" }}>
          <span className="absolute -top-2.5 -left-6 text-[9px]" style={{ color: "#334155" }}>
            {valuePrefix}{pct === 1 ? (max >= 1000 ? `${(max / 1000).toFixed(0)}K` : max) : ""}
          </span>
        </div>
      ))}
      <div className="flex items-end gap-1.5 h-40">
        {data.map((val, i) => {
          const pct = mounted ? (val / max) * 100 : 0;
          const isHov = hovered === i;
          return (
            <div key={i} className="flex-1 flex flex-col items-center gap-1.5"
              onMouseEnter={() => setHovered(i)} onMouseLeave={() => setHovered(null)}>
              {isHov && (
                <div className="text-[9px] font-semibold whitespace-nowrap px-1.5 py-0.5 rounded"
                  style={{ background: "#0F172A", color, border: `1px solid ${color}40` }}>
                  {valuePrefix}{val >= 1000 ? `${(val/1000).toFixed(1)}K` : val}
                </div>
              )}
              {!isHov && <div className="h-5" />}
              <div className="w-full rounded-t-sm transition-all duration-700"
                style={{
                  height: `${pct}%`,
                  minHeight: "3px",
                  background: isHov
                    ? `linear-gradient(180deg, ${color} 0%, ${color}80 100%)`
                    : `linear-gradient(180deg, ${color}80 0%, ${color}30 100%)`,
                  boxShadow: isHov ? `0 0 12px ${color}40` : "none",
                }} />
              <span className="text-[9px] font-medium" style={{ color: "#334155" }}>{labels[i]}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Zone heatmap bar ──────────────────────────────────────────────────────────

function ZoneBar({ zone, pct, risk }: { zone: string; pct: number; risk: "HIGH" | "MEDIUM" | "LOW" }) {
  const color = risk === "HIGH" ? "#EF4444" : risk === "MEDIUM" ? "#F59E0B" : "#22C55E";
  return (
    <div>
      <div className="flex justify-between items-center mb-1.5">
        <span className="text-xs font-medium" style={{ color: "#94A3B8" }}>{zone}</span>
        <span className="text-[10px] font-semibold" style={{ color }}>{risk}</span>
      </div>
      <div className="w-full h-1.5 rounded-full overflow-hidden" style={{ background: "rgba(51,65,85,0.4)" }}>
        <div className="h-full rounded-full transition-all duration-700"
          style={{ width: `${pct}%`, background: color, boxShadow: `0 0 6px ${color}40` }} />
      </div>
    </div>
  );
}

// ── KPI sparkline card ────────────────────────────────────────────────────────

function SparkCard({ label, value, change, data, color }: {
  label: string; value: string; change: string; data: number[]; color: string;
}) {
  const isPos = change.startsWith("+");
  return (
    <div className="rounded-xl border p-4 overflow-hidden relative" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
      <div className="flex justify-between items-start mb-3">
        <div>
          <div className="text-[10px] uppercase tracking-widest mb-1" style={{ color: "#475569" }}>{label}</div>
          <div className="text-xl font-bold" style={{ color: "#F1F5F9" }}>{value}</div>
        </div>
        <span className="text-[10px] font-semibold px-1.5 py-0.5 rounded" style={{
          background: isPos ? "rgba(34,197,94,0.12)" : "rgba(239,68,68,0.12)",
          color: isPos ? "#22C55E" : "#EF4444",
        }}>
          {change}
        </span>
      </div>
      <div className="h-10">
        <Sparkline data={data} color={color} height={40} />
      </div>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function AnalyticsPage() {
  const { kpis } = useDemo();

  const claimData = [12, 18, 9, 22, 31, 14, 7 + (kpis.approvedToday > 41 ? 12 : 0)];
  const payoutData = [3240, 5100, 2880, 6440, 8990, 4200, 1960 + (kpis.approvedToday > 41 ? 5400 : 0)];

  const claimTypeSegments = [
    { label: "Weather",         pct: 48, color: "#008A8A" },
    { label: "Platform Outage", pct: 22, color: "#00BFA6" },
    { label: "Network",         pct: 16, color: "#B2DFDB" },
    { label: "Other",           pct: 14, color: "#334155" },
  ];

  return (
    <AdminShell title="Analytics & Trends" subtitle="Payout volumes, claim types, zone heatmaps, and trend sparklines.">
      <div className="flex flex-col gap-5">

        {/* ── KPI sparkline row ────────────────────────────────────────── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <SparkCard label="Claims This Week" value={String(claimData.reduce((a, b) => a + b, 0))} change="+18%" data={claimData} color="#00BFA6" />
          <SparkCard label="Payout MTD" value={`₹${(payoutData.reduce((a, b) => a + b, 0) / 1000).toFixed(0)}K`} change="+12%" data={payoutData} color="#008A8A" />
          <SparkCard label="Fraud Rate" value="4.2%" change="-0.8%" data={[5.1, 4.8, 4.9, 4.5, 4.3, 4.4, 4.2]} color="#EF4444" />
          <SparkCard label="Auto-Approve %" value="76%" change="+3%" data={[68,70,71,73,74,75,76]} color="#22C55E" />
        </div>

        {/* ── Charts row ──────────────────────────────────────────────── */}
        <div className="grid lg:grid-cols-2 gap-4">

          {/* Weekly claim trend */}
          <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.4)" }}>
              <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Weekly Claim Volume</h3>
              <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>Total claims by day — this week</p>
            </div>
            <div className="px-5 pb-4 pt-5">
              <DarkBarChart data={claimData} labels={["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]} color="#00BFA6" />
            </div>
          </div>

          {/* Payout volume */}
          <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.4)" }}>
              <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Daily Payout Volume</h3>
              <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>₹ disbursed to gig workers — this week</p>
            </div>
            <div className="px-5 pb-4 pt-5">
              <DarkBarChart data={payoutData} labels={["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]} color="#008A8A" valuePrefix="₹" />
            </div>
          </div>
        </div>

        {/* ── Breakdown + Heatmap ──────────────────────────────────────── */}
        <div className="grid lg:grid-cols-2 gap-4">

          {/* Claim type donut */}
          <div className="rounded-xl border p-5" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <h3 className="text-sm font-semibold mb-4" style={{ color: "#F1F5F9" }}>Claim Type Breakdown</h3>
            <DonutChart segments={claimTypeSegments} />
          </div>

          {/* Zone risk heatmap */}
          <div className="rounded-xl border p-5" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <h3 className="text-sm font-semibold mb-4" style={{ color: "#F1F5F9" }}>Zone Risk Heatmap</h3>
            <div className="space-y-4">
              <ZoneBar zone="BLR-South"   pct={82} risk="HIGH"   />
              <ZoneBar zone="BLR-North"   pct={51} risk="MEDIUM" />
              <ZoneBar zone="CHN-Central" pct={28} risk="LOW"    />
              <ZoneBar zone="KOL-South"   pct={19} risk="LOW"    />
            </div>
            <div className="flex items-center gap-4 mt-5 pt-4" style={{ borderTop: "1px solid rgba(51,65,85,0.35)" }}>
              {[["HIGH","#EF4444"],["MEDIUM","#F59E0B"],["LOW","#22C55E"]].map(([label, color]) => (
                <div key={label} className="flex items-center gap-1.5 text-[10px]" style={{ color: "#64748B" }}>
                  <span className="w-2 h-2 rounded-full" style={{ background: color }} />
                  {label}
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ── Tier distribution ───────────────────────────────────────── */}
        <div className="rounded-xl border p-5" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
          <h3 className="text-sm font-semibold mb-4" style={{ color: "#F1F5F9" }}>Partner Tier Distribution</h3>
          <div className="flex items-end gap-2 h-32">
            {[
              { tier: "Platinum", pct: 18, color: "#A78BFA", count: 867 },
              { tier: "Gold",     pct: 44, color: "#FCD34D", count: 2121 },
              { tier: "Silver",   pct: 38, color: "#94A3B8", count: 1832 },
            ].map((item) => (
              <div key={item.tier} className="flex-1 flex flex-col items-center gap-2 group">
                <div className="text-[10px] font-semibold opacity-0 group-hover:opacity-100 transition-opacity tabular-nums"
                  style={{ color: item.color }}>{item.count.toLocaleString()}</div>
                <div className="w-full rounded-t-md transition-all duration-700"
                  style={{
                    height: `${item.pct}%`,
                    background: `linear-gradient(180deg, ${item.color} 0%, ${item.color}50 100%)`,
                    boxShadow: `0 0 12px ${item.color}30`,
                  }} />
                <span className="text-[10px]" style={{ color: "#64748B" }}>{item.tier}</span>
              </div>
            ))}
          </div>
        </div>

      </div>
    </AdminShell>
  );
}
