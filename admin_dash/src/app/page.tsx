"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";
import { Badge } from "@/components/ui/badge";
import {
  Clock, CheckCircle2, XCircle, AlertTriangle,
  MapPin, DollarSign, TrendingUp, Activity,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ── Status badge ──────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    Approved:        { bg: "rgba(34,197,94,0.12)",   color: "#22C55E" },
    Rejected:        { bg: "rgba(239,68,68,0.12)",   color: "#EF4444" },
    Pending:         { bg: "rgba(245,158,11,0.12)",  color: "#F59E0B" },
    "Auto-Approved": { bg: "rgba(0,191,166,0.15)",   color: "#00BFA6" },
  };
  const s = map[status] ?? { bg: "rgba(148,163,184,0.12)", color: "#94A3B8" };
  return (
    <span className="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold" style={{ background: s.bg, color: s.color }}>
      {status}
    </span>
  );
}

function TierPill({ tier }: { tier: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    Platinum: { bg: "rgba(139,92,246,0.15)", color: "#A78BFA" },
    Gold:     { bg: "rgba(245,158,11,0.15)", color: "#FCD34D" },
    Silver:   { bg: "rgba(148,163,184,0.1)", color: "#94A3B8" },
  };
  const s = map[tier] ?? { bg: "rgba(148,163,184,0.1)", color: "#94A3B8" };
  return (
    <span className="rounded px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider" style={{ background: s.bg, color: s.color }}>
      {tier}
    </span>
  );
}

// ── KPI card ──────────────────────────────────────────────────────────────────

function KpiCard({
  label, value, sub, icon: Icon, accentColor, alert, taps, onTrigger,
}: {
  label: string;
  value: string | number;
  sub?: string;
  icon: React.ElementType;
  accentColor: string;
  alert?: boolean;
  taps: number;
  onTrigger: () => void;
}) {
  const inner = (
    <div className={cn(
      "relative rounded-xl p-5 cursor-pointer transition-all duration-200 group overflow-hidden",
      "border hover:border-opacity-80",
    )} style={{
      background: alert ? "rgba(239,68,68,0.08)" : "rgba(30,41,59,0.9)",
      borderColor: alert ? "rgba(239,68,68,0.3)" : "rgba(51,65,85,0.5)",
    }}>
      <div className="absolute top-0 right-0 w-24 h-24 rounded-full opacity-[0.04] -translate-y-6 translate-x-6 group-hover:opacity-[0.07] transition-opacity"
        style={{ background: accentColor }} />
      <div className="flex items-start justify-between mb-4">
        <div className="p-2 rounded-lg" style={{ background: `${accentColor}18` }}>
          <Icon className="w-4 h-4" style={{ color: accentColor }} />
        </div>
        <span className="w-1.5 h-1.5 rounded-full mt-1" style={{ background: accentColor, opacity: 0.6 }} />
      </div>
      <div className="text-3xl font-bold tracking-tight mb-1" style={{ color: alert ? "#EF4444" : accentColor }}>
        {value}
      </div>
      <div className="text-[11px] font-medium uppercase tracking-widest" style={{ color: "#475569" }}>{label}</div>
      {sub && <div className="text-[10px] mt-1" style={{ color: "#475569" }}>{sub}</div>}
    </div>
  );

  return (
    <EasterEggDetector taps={taps} onTrigger={onTrigger}>
      {inner}
    </EasterEggDetector>
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────

export default function Home() {
  const {
    kpis, claims, auditLogs,
    bulkApproveWave, reserveFloorBreach, fraudFlagging, claimRejectionCascade,
    approveClaim, rejectClaim,
  } = useDemo();

  const [showAuditOverlay, setShowAuditOverlay] = useState(false);
  const [rejectingId, setRejectingId]           = useState<string | null>(null);
  const [rejectReason, setRejectReason]         = useState("");

  const pendingClaims = claims.filter((c) => c.status === "Pending");
  const recentClaims  = claims.slice(0, 12);

  const handleApprove = (id: string, reason: string, amount: number) => {
    const tierDefault = claims.find((c) => c.id === id)?.tier === "Platinum" ? 450 : claims.find((c) => c.id === id)?.tier === "Gold" ? 312 : 180;
    approveClaim(id, `₹${amount > 0 ? amount : tierDefault} — ${reason}`);
  };

  const handleRejectConfirm = (id: string) => {
    if (!rejectReason.trim()) return;
    rejectClaim(id, rejectReason.trim());
    setRejectingId(null);
    setRejectReason("");
  };

  return (
    <AdminShell title="Operations Overview" subtitle="Live claims pipeline, payout activity, and zone health.">
      <div className="flex flex-col gap-5">

        {/* ── KPI strip ──────────────────────────────────────────────── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <KpiCard
            label="Pending"
            value={kpis.pendingQueue}
            sub="awaiting review"
            icon={Clock}
            accentColor="#F59E0B"
            taps={4}
            onTrigger={bulkApproveWave}
          />
          <EasterEggDetector taps={4} onTrigger={() => setShowAuditOverlay(true)}>
            <div className="relative rounded-xl p-5 cursor-pointer transition-all duration-200 group overflow-hidden border"
              style={{ background: "rgba(30,41,59,0.9)", borderColor: "rgba(51,65,85,0.5)" }}>
              <div className="absolute top-0 right-0 w-24 h-24 rounded-full opacity-[0.04] -translate-y-6 translate-x-6" style={{ background: "#22C55E" }} />
              <div className="flex items-start justify-between mb-4">
                <div className="p-2 rounded-lg" style={{ background: "rgba(34,197,94,0.12)" }}>
                  <CheckCircle2 className="w-4 h-4" style={{ color: "#22C55E" }} />
                </div>
                <span className="w-1.5 h-1.5 rounded-full mt-1" style={{ background: "#22C55E", opacity: 0.6 }} />
              </div>
              <div className="text-3xl font-bold tracking-tight mb-1" style={{ color: "#22C55E" }}>{kpis.approvedToday}</div>
              <div className="text-[11px] font-medium uppercase tracking-widest" style={{ color: "#475569" }}>Approved</div>
              <div className="text-[10px] mt-1" style={{ color: "#475569" }}>today so far</div>
            </div>
          </EasterEggDetector>
          <KpiCard
            label="Rejected"
            value={kpis.rejectedToday}
            sub="denied today"
            icon={XCircle}
            accentColor="#EF4444"
            alert={kpis.rejectedToday > 5}
            taps={3}
            onTrigger={claimRejectionCascade}
          />
          <KpiCard
            label="Fraud Flagged"
            value={kpis.fraudFlagged}
            sub="high-risk signals"
            icon={AlertTriangle}
            accentColor="#F59E0B"
            taps={3}
            onTrigger={() => fraudFlagging()}
          />
        </div>

        {/* ── Secondary stats ─────────────────────────────────────────── */}
        <div className="grid grid-cols-3 gap-3">
          <KpiCard
            label="Reserve Runway"
            value={`${kpis.reserveRunwayDays}d`}
            sub={kpis.reserveRunwayDays < 60 ? "below threshold" : "days covered"}
            icon={Activity}
            accentColor={kpis.reserveRunwayDays < 60 ? "#EF4444" : "#008A8A"}
            alert={kpis.reserveRunwayDays < 60}
            taps={4}
            onTrigger={reserveFloorBreach}
          />
          <div className="rounded-xl p-5 border" style={{ background: "rgba(30,41,59,0.9)", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="flex items-start justify-between mb-4">
              <div className="p-2 rounded-lg" style={{ background: "rgba(0,138,138,0.12)" }}>
                <MapPin className="w-4 h-4" style={{ color: "#008A8A" }} />
              </div>
            </div>
            <div className="text-3xl font-bold tracking-tight mb-1" style={{ color: "#00BFA6" }}>
              {kpis.zonesActive}<span className="text-sm font-normal" style={{ color: "#475569" }}>/{kpis.zonesTotal}</span>
            </div>
            <div className="text-[11px] font-medium uppercase tracking-widest" style={{ color: "#475569" }}>Zones Active</div>
          </div>
          <div className="rounded-xl p-5 border" style={{ background: "rgba(30,41,59,0.9)", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="flex items-start justify-between mb-4">
              <div className="p-2 rounded-lg" style={{ background: "rgba(0,138,138,0.12)" }}>
                <DollarSign className="w-4 h-4" style={{ color: "#008A8A" }} />
              </div>
            </div>
            <div className="text-3xl font-bold tracking-tight mb-1" style={{ color: "#00BFA6" }}>
              ₹{kpis.totalPayoutToday.toLocaleString()}
            </div>
            <div className="text-[11px] font-medium uppercase tracking-widest" style={{ color: "#475569" }}>Payout Today</div>
            <div className="text-[10px] mt-1" style={{ color: "#475569" }}>avg ₹{kpis.avgPayout} / claim</div>
          </div>
        </div>

        {/* ── Priority queue ──────────────────────────────────────────── */}
        {pendingClaims.length > 0 && (
          <div className="rounded-xl border overflow-hidden" style={{ background: "rgba(245,158,11,0.04)", borderColor: "rgba(245,158,11,0.2)" }}>
            <div className="px-5 py-3.5 border-b flex items-center gap-3" style={{ borderColor: "rgba(245,158,11,0.15)" }}>
              <span className="flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-bold" style={{ background: "rgba(245,158,11,0.15)", color: "#F59E0B" }}>
                <span className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ background: "#F59E0B" }} />
                {pendingClaims.length} pending
              </span>
              <span className="text-xs font-semibold" style={{ color: "#CBD5E1" }}>Claims need a decision</span>
            </div>
            <div className="divide-y" style={{ borderColor: "rgba(245,158,11,0.08)" }}>
              {pendingClaims.map((claim) => {
                const isFraud = (claim.fraudScore ?? 0) > 0.7 || (claim as { isFraud?: boolean }).isFraud;
                const defaultPayout = claim.tier === "Platinum" ? 450 : claim.tier === "Gold" ? 312 : 180;
                const displayAmount = claim.amount > 0 ? claim.amount : defaultPayout;
                return (
                  <div key={claim.id} className="px-5 py-4 flex items-center justify-between gap-4">
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-1.5 mb-1">
                        <span className="font-mono text-[10px]" style={{ color: "#475569" }}>{claim.id}</span>
                        <TierPill tier={claim.tier} />
                        {isFraud && (
                          <span className="rounded px-1.5 py-0.5 text-[9px] font-bold" style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444" }}>
                            FRAUD {((claim.fraudScore ?? 0) * 100).toFixed(0)}%
                          </span>
                        )}
                      </div>
                      <p className="text-sm font-medium truncate" style={{ color: "#F1F5F9" }}>
                        {claim.driver} — {claim.reason}
                      </p>
                      <p className="text-[11px] mt-0.5" style={{ color: "#64748B" }}>{claim.zone} · ₹{displayAmount}</p>
                    </div>
                    {rejectingId === claim.id ? (
                      <div className="flex flex-col gap-2 w-52 shrink-0">
                        <input
                          className="rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:ring-1"
                          style={{ background: "#0F172A", border: "1px solid #334155", color: "#F1F5F9" }}
                          placeholder="Rejection reason…"
                          value={rejectReason}
                          onChange={(e) => setRejectReason(e.target.value)}
                          onKeyDown={(e) => e.key === "Enter" && handleRejectConfirm(claim.id)}
                          autoFocus
                        />
                        <div className="flex gap-2">
                          <button onClick={() => handleRejectConfirm(claim.id)}
                            className="flex-1 rounded-lg py-1.5 text-xs font-bold text-white transition-opacity hover:opacity-90"
                            style={{ background: "#EF4444" }}>Confirm</button>
                          <button onClick={() => { setRejectingId(null); setRejectReason(""); }}
                            className="flex-1 rounded-lg py-1.5 text-xs font-medium transition-colors"
                            style={{ background: "#273548", color: "#94A3B8" }}>Cancel</button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex items-center gap-2 shrink-0">
                        <button onClick={() => handleApprove(claim.id, claim.reason, claim.amount)}
                          className="rounded-lg px-4 py-2 text-xs font-bold text-white transition-opacity hover:opacity-90"
                          style={{ background: "#008A8A" }}>
                          Approve ₹{displayAmount}
                        </button>
                        <button onClick={() => setRejectingId(claim.id)}
                          className="rounded-lg px-4 py-2 text-xs font-bold transition-colors border"
                          style={{ background: "transparent", borderColor: "rgba(239,68,68,0.3)", color: "#EF4444" }}>
                          Reject
                        </button>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* ── Activity: claims table + audit ─────────────────────────── */}
        <div className="grid gap-4 lg:grid-cols-5">

          {/* Claims table */}
          <div className="rounded-xl border overflow-hidden lg:col-span-3" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b flex items-center justify-between" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
              <div>
                <h3 className="text-xs font-semibold uppercase tracking-widest" style={{ color: "#94A3B8" }}>Recent Claims</h3>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="live-dot w-1.5 h-1.5 rounded-full" style={{ background: "#22C55E" }} />
                <span className="text-[10px]" style={{ color: "#475569" }}>live</span>
              </div>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr style={{ borderBottom: "1px solid rgba(51,65,85,0.4)" }}>
                    {["Claim ID", "Driver", "Zone", "Status", "Amount"].map((h) => (
                      <th key={h} className="px-5 py-3 text-left font-semibold uppercase tracking-widest" style={{ color: "#475569", fontSize: "10px" }}>
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {recentClaims.map((claim, i) => (
                    <tr key={claim.id} className="transition-colors" style={{
                      borderBottom: "1px solid rgba(51,65,85,0.3)",
                      background: i % 2 === 1 ? "rgba(15,23,42,0.3)" : "transparent",
                    }}>
                      <td className="px-5 py-3">
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono" style={{ color: "#64748B" }}>{claim.id}</span>
                          {(claim.fraudScore ?? 0) > 0.7 && (
                            <span className="rounded px-1 py-0.5 text-[8px] font-bold" style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444" }}>FRAUD</span>
                          )}
                        </div>
                        <p className="text-[10px] mt-0.5 truncate max-w-[130px]" style={{ color: "#475569" }}>{claim.reason}</p>
                      </td>
                      <td className="px-5 py-3">
                        <p className="font-medium" style={{ color: "#CBD5E1" }}>{claim.driver}</p>
                        <div className="mt-0.5"><TierPill tier={claim.tier} /></div>
                      </td>
                      <td className="px-5 py-3" style={{ color: "#64748B" }}>{claim.zone}</td>
                      <td className="px-5 py-3"><StatusBadge status={claim.status} /></td>
                      <td className="px-5 py-3 font-semibold" style={{ color: claim.amount > 0 ? "#00BFA6" : "#334155" }}>
                        {claim.amount > 0 ? `₹${claim.amount}` : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Audit timeline */}
          <div className="rounded-xl border overflow-hidden lg:col-span-2" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
              <h3 className="text-xs font-semibold uppercase tracking-widest" style={{ color: "#94A3B8" }}>Audit Log</h3>
            </div>
            <div className="px-5 py-4">
              <ol className="relative ml-3 space-y-4" style={{ borderLeft: "1px solid rgba(51,65,85,0.4)" }}>
                {auditLogs.slice(0, 7).map((log, i) => {
                  const isApproved = log.action.includes("APPROVE");
                  const isRejected = log.action === "REJECTED";
                  const dotColor = isApproved ? "#22C55E" : isRejected ? "#EF4444" : "#334155";
                  return (
                    <li key={i} className="pl-4 relative">
                      <span className="absolute -left-[5px] top-1 w-2.5 h-2.5 rounded-full ring-2 flex-shrink-0"
                        style={{ background: dotColor }} />
                      <p className="text-[10px] mb-0.5" style={{ color: "#475569" }} suppressHydrationWarning>{log.timestamp} · {log.actor}</p>
                      <p className="text-xs leading-snug">
                        <span className="font-bold" style={{ color: isApproved ? "#22C55E" : isRejected ? "#EF4444" : "#94A3B8" }}>
                          {log.action}
                        </span>{" "}
                        <span style={{ color: "#64748B" }}>{log.target}</span>
                      </p>
                      <p className="text-[10px] mt-0.5 line-clamp-1" style={{ color: "#475569" }}>{log.details}</p>
                    </li>
                  );
                })}
              </ol>
            </div>
          </div>
        </div>

      </div>

      {/* ── Payout audit overlay ─────────────────────────────────────── */}
      {showAuditOverlay && (
        <div className="fixed inset-0 flex items-end justify-center z-50" style={{ background: "rgba(0,0,0,0.6)", backdropFilter: "blur(8px)" }}
          onClick={() => setShowAuditOverlay(false)}>
          <div className="w-full max-w-2xl rounded-t-2xl p-6 shadow-2xl" style={{ background: "#1E293B", border: "1px solid rgba(51,65,85,0.5)" }}
            onClick={(e) => e.stopPropagation()}>
            <div className="mx-auto mb-5 h-1 w-10 rounded-full" style={{ background: "#334155" }} />
            <div className="flex items-center justify-between mb-5">
              <h2 className="text-base font-bold" style={{ color: "#F1F5F9" }}>Payout Audit Trail</h2>
              <button onClick={() => setShowAuditOverlay(false)} className="p-1.5 rounded-lg transition-colors hover:bg-white/5" style={{ color: "#64748B" }}>
                <XCircle className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-2">
              {auditLogs.filter((l) => l.action.includes("APPROVE") || l.details.includes("₹")).slice(0, 5).map((log, i) => (
                <div key={i} className="flex items-center justify-between rounded-lg p-4" style={{ background: "#273548", border: "1px solid rgba(51,65,85,0.4)" }}>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <span className="font-semibold text-sm truncate" style={{ color: "#F1F5F9" }}>{log.target}</span>
                      <span className="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-bold" style={{ background: "rgba(34,197,94,0.15)", color: "#22C55E" }}>{log.action}</span>
                    </div>
                    <p className="text-xs" style={{ color: "#64748B" }}>{log.details}</p>
                    <p className="text-[10px] mt-0.5" style={{ color: "#475569" }} suppressHydrationWarning>{log.timestamp} · {log.actor}</p>
                  </div>
                  <code className="ml-4 shrink-0 font-mono text-[10px] px-2 py-1 rounded" style={{ background: "#0F172A", color: "#475569", border: "1px solid rgba(51,65,85,0.4)" }}>
                    UPI/{log.timestamp.replace(/[- :]/g, "").slice(2, 8)}/CONT{10000 + (i * 12345 % 90000)}
                  </code>
                </div>
              ))}
            </div>
            <button onClick={() => setShowAuditOverlay(false)}
              className="mt-4 w-full rounded-lg py-2.5 text-sm font-medium transition-colors hover:bg-white/5"
              style={{ background: "#273548", color: "#94A3B8" }}>
              Close
            </button>
          </div>
        </div>
      )}
    </AdminShell>
  );
}
