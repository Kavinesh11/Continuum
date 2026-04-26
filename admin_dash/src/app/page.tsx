"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

// ── Icon helpers ──────────────────────────────────────────────────────────────

function Icon({ path, className = "w-5 h-5" }: { path: string; className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      <path d={path} />
    </svg>
  );
}

const ICONS = {
  clock:   "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 5v5l3.5 3.5",
  check:   "M22 11.08V12a10 10 0 1 1-5.93-9.14M22 4 12 14.01l-3-3",
  x:       "M18 6 6 18M6 6l12 12",
  shield:  "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z",
  warning: "M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0zM12 9v4M12 17h.01",
  reserve: "M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
  zone:    "M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z",
  payout:  "M12 2v20M17 5H9.5a3.5 3.5 0 1 0 0 7h5a3.5 3.5 0 1 1 0 7H6",
  avg:     "M18 20V10M12 20V4M6 20v-6",
};

// ── Status badge ──────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    Approved:     "bg-emerald-50 text-emerald-700 ring-emerald-200",
    Rejected:     "bg-red-50 text-red-700 ring-red-200",
    Pending:      "bg-amber-50 text-amber-700 ring-amber-200",
    "Auto-Approved": "bg-teal-50 text-teal-700 ring-teal-200",
  };
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1 ${styles[status] ?? "bg-slate-100 text-slate-600 ring-slate-200"}`}>
      {status}
    </span>
  );
}

// ── Tier pill ─────────────────────────────────────────────────────────────────

function TierPill({ tier }: { tier: string }) {
  const styles: Record<string, string> = {
    Platinum: "bg-violet-50 text-violet-700",
    Gold:     "bg-amber-50 text-amber-700",
    Silver:   "bg-slate-100 text-slate-600",
  };
  return (
    <span className={`rounded px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${styles[tier] ?? "bg-slate-100 text-slate-500"}`}>
      {tier}
    </span>
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────

function StatCard({
  label, value, icon, color, taps, onTrigger, highlight,
}: {
  label: string;
  value: string | number;
  icon: string;
  color: "teal" | "emerald" | "red" | "amber";
  taps: number;
  onTrigger: () => void;
  highlight?: boolean;
}) {
  const palette = {
    teal:    { bg: "bg-teal-50",   icon: "text-teal-500",   val: "text-teal-900"   },
    emerald: { bg: "bg-emerald-50",icon: "text-emerald-500",val: "text-emerald-900"},
    red:     { bg: "bg-red-50",    icon: "text-red-500",    val: "text-red-900"    },
    amber:   { bg: "bg-amber-50",  icon: "text-amber-500",  val: "text-amber-900"  },
  }[color];

  return (
    <EasterEggDetector taps={taps} onTrigger={onTrigger}>
      <div className={`group relative rounded-2xl ${highlight ? "bg-red-50 ring-1 ring-red-200" : "bg-white ring-1 ring-slate-100"} p-5 shadow-sm cursor-pointer hover:shadow-md transition-all`}>
        <div className={`mb-3 inline-flex rounded-xl p-2 ${highlight ? "bg-red-100" : palette.bg}`}>
          <Icon path={icon} className={`w-4 h-4 ${highlight ? "text-red-600" : palette.icon}`} />
        </div>
        <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">{label}</p>
        <p className={`mt-1 text-2xl font-bold ${highlight ? "text-red-700" : palette.val}`}>{value}</p>
        <div className="absolute inset-x-0 bottom-0 h-0.5 rounded-b-2xl bg-gradient-to-r from-transparent via-current to-transparent opacity-0 group-hover:opacity-20 transition-opacity" />
      </div>
    </EasterEggDetector>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function Home() {
  const {
    kpis,
    claims,
    auditLogs,
    bulkApproveWave,
    reserveFloorBreach,
    fraudFlagging,
    claimRejectionCascade,
    approveClaim,
    rejectClaim,
  } = useDemo();

  const [showAuditOverlay, setShowAuditOverlay] = useState(false);
  const [rejectingId, setRejectingId]           = useState<string | null>(null);
  const [rejectReason, setRejectReason]         = useState("");

  const pendingClaims = claims.filter((c) => c.status === "Pending");
  const recentClaims  = claims.slice(0, 10);

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
    <AdminShell title="Operations" subtitle="Live claims, payouts, and zone health.">

      {/* ── Stats strip ──────────────────────────────────────────────────── */}
      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard
          label="Pending"
          value={kpis.pendingQueue}
          icon={ICONS.clock}
          color="amber"
          taps={4}
          onTrigger={bulkApproveWave}
        />
        <EasterEggDetector taps={4} onTrigger={() => setShowAuditOverlay(true)}>
          <div className="group relative rounded-2xl bg-white ring-1 ring-slate-100 p-5 shadow-sm cursor-pointer hover:shadow-md transition-all">
            <div className="mb-3 inline-flex rounded-xl p-2 bg-emerald-50">
              <Icon path={ICONS.check} className="w-4 h-4 text-emerald-500" />
            </div>
            <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">Approved</p>
            <p className="mt-1 text-2xl font-bold text-emerald-900">{kpis.approvedToday}</p>
          </div>
        </EasterEggDetector>
        <StatCard
          label="Rejected"
          value={kpis.rejectedToday}
          icon={ICONS.x}
          color="red"
          taps={3}
          onTrigger={claimRejectionCascade}
        />
        <StatCard
          label="Fraud Flagged"
          value={kpis.fraudFlagged}
          icon={ICONS.warning}
          color="amber"
          taps={3}
          onTrigger={() => fraudFlagging()}
        />
      </section>

      {/* ── Priority review queue ─────────────────────────────────────────── */}
      {pendingClaims.length > 0 && (
        <section className="rounded-2xl border border-amber-200 bg-amber-50/60 p-5">
          <div className="mb-4 flex items-center gap-3">
            <span className="flex items-center gap-1.5 rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-800 ring-1 ring-amber-300">
              <span className="h-1.5 w-1.5 rounded-full bg-amber-500 animate-pulse" />
              {pendingClaims.length} awaiting review
            </span>
            <p className="text-sm font-semibold text-amber-900">Claims need a decision</p>
          </div>

          <div className="space-y-2">
            {pendingClaims.map((claim) => {
              const isFraud = (claim.fraudScore ?? 0) > 0.7 || (claim as { isFraud?: boolean }).isFraud;
              const defaultPayout = claim.tier === "Platinum" ? 450 : claim.tier === "Gold" ? 312 : 180;
              const displayAmount = claim.amount > 0 ? claim.amount : defaultPayout;

              return (
                <div
                  key={claim.id}
                  className={`rounded-xl bg-white p-4 shadow-sm ring-1 transition-all ${isFraud ? "ring-red-200" : "ring-slate-100"}`}
                >
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    {/* Left: claim info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-1.5 mb-1.5">
                        <span className="font-mono text-[11px] font-semibold text-slate-400">{claim.id}</span>
                        <TierPill tier={claim.tier} />
                        {isFraud && (
                          <span className="rounded px-1.5 py-0.5 text-[10px] font-bold bg-red-100 text-red-700">
                            FRAUD {((claim.fraudScore ?? 0) * 100).toFixed(0)}%
                          </span>
                        )}
                        {(claim as { isFraud?: boolean }).isFraud && (
                          <span className="rounded px-1.5 py-0.5 text-[10px] font-bold bg-orange-100 text-orange-700">
                            ESCALATED
                          </span>
                        )}
                      </div>
                      <p className="text-sm font-semibold text-slate-800 truncate">
                        {claim.driver} — {claim.reason}
                      </p>
                      {(claim as { description?: string }).description && (
                        <p className="mt-0.5 text-xs text-slate-400 line-clamp-1">
                          {(claim as { description?: string }).description}
                        </p>
                      )}
                      <p className="mt-1 text-xs text-slate-400">
                        {claim.zone} · <span className="font-semibold text-slate-600">₹{displayAmount}</span>
                      </p>
                    </div>

                    {/* Right: actions */}
                    {rejectingId === claim.id ? (
                      <div className="flex flex-col gap-2 min-w-[210px]">
                        <input
                          className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-red-300"
                          placeholder="Rejection reason…"
                          value={rejectReason}
                          onChange={(e) => setRejectReason(e.target.value)}
                          onKeyDown={(e) => e.key === "Enter" && handleRejectConfirm(claim.id)}
                          autoFocus
                        />
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleRejectConfirm(claim.id)}
                            className="flex-1 rounded-lg bg-red-600 px-3 py-1.5 text-xs font-bold text-white hover:bg-red-700 transition-colors"
                          >
                            Confirm
                          </button>
                          <button
                            onClick={() => { setRejectingId(null); setRejectReason(""); }}
                            className="flex-1 rounded-lg bg-slate-100 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-200 transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex items-center gap-2 shrink-0">
                        <button
                          onClick={() => handleApprove(claim.id, claim.reason, claim.amount)}
                          className="rounded-lg bg-emerald-600 px-4 py-2 text-xs font-bold text-white hover:bg-emerald-700 transition-colors"
                        >
                          Approve ₹{displayAmount}
                        </button>
                        <button
                          onClick={() => setRejectingId(claim.id)}
                          className="rounded-lg bg-white px-4 py-2 text-xs font-bold text-red-600 ring-1 ring-red-200 hover:bg-red-50 transition-colors"
                        >
                          Reject
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* ── Operations row ────────────────────────────────────────────────── */}
      <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard
          label="Reserve Runway"
          value={`${kpis.reserveRunwayDays} days`}
          icon={ICONS.reserve}
          color={kpis.reserveRunwayDays < 60 ? "red" : "teal"}
          highlight={kpis.reserveRunwayDays < 60}
          taps={4}
          onTrigger={reserveFloorBreach}
        />
        <div className="rounded-2xl bg-white ring-1 ring-slate-100 p-5 shadow-sm">
          <div className="mb-3 inline-flex rounded-xl p-2 bg-teal-50">
            <Icon path={ICONS.zone} className="w-4 h-4 text-teal-500" />
          </div>
          <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">Zones Active</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{kpis.zonesActive}<span className="text-sm font-normal text-slate-400">/{kpis.zonesTotal}</span></p>
        </div>
        <div className="rounded-2xl bg-white ring-1 ring-slate-100 p-5 shadow-sm">
          <div className="mb-3 inline-flex rounded-xl p-2 bg-teal-50">
            <Icon path={ICONS.payout} className="w-4 h-4 text-teal-500" />
          </div>
          <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">Total Payout Today</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">₹{kpis.totalPayoutToday.toLocaleString()}</p>
          <p className="mt-0.5 text-xs text-slate-400">avg ₹{kpis.avgPayout} / claim</p>
        </div>
      </section>

      {/* ── Activity: claims table + audit timeline ───────────────────────── */}
      <section className="grid gap-4 lg:grid-cols-5">

        {/* Claims table */}
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-100 lg:col-span-3">
          <h3 className="mb-4 text-sm font-semibold text-slate-700 uppercase tracking-wide">Recent Claims</h3>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-slate-100">
                  <th className="pb-2.5 pr-3 text-xs font-medium text-slate-400 uppercase tracking-wide">Claim</th>
                  <th className="pb-2.5 pr-3 text-xs font-medium text-slate-400 uppercase tracking-wide">Driver</th>
                  <th className="pb-2.5 pr-3 text-xs font-medium text-slate-400 uppercase tracking-wide hidden sm:table-cell">Zone</th>
                  <th className="pb-2.5 pr-3 text-xs font-medium text-slate-400 uppercase tracking-wide">Status</th>
                  <th className="pb-2.5 text-xs font-medium text-slate-400 uppercase tracking-wide">Amount</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {recentClaims.map((claim) => (
                  <tr key={claim.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-2.5 pr-3">
                      <div className="flex items-center gap-1.5">
                        <span className="font-mono text-xs text-slate-600">{claim.id}</span>
                        {(claim.fraudScore ?? 0) > 0.7 && (
                          <span className="rounded px-1 py-0.5 text-[9px] font-bold bg-red-100 text-red-600">FRAUD</span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-400 mt-0.5 truncate max-w-[120px]">{claim.reason}</p>
                    </td>
                    <td className="py-2.5 pr-3">
                      <p className="text-sm font-medium text-slate-700">{claim.driver}</p>
                      <TierPill tier={claim.tier} />
                    </td>
                    <td className="py-2.5 pr-3 hidden sm:table-cell">
                      <span className="text-xs text-slate-400">{claim.zone}</span>
                    </td>
                    <td className="py-2.5 pr-3">
                      <StatusBadge status={claim.status} />
                    </td>
                    <td className="py-2.5 font-semibold text-slate-800">
                      {claim.amount > 0 ? `₹${claim.amount}` : <span className="text-slate-300">—</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Audit timeline */}
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-100 lg:col-span-2">
          <h3 className="mb-4 text-sm font-semibold text-slate-700 uppercase tracking-wide">Audit Log</h3>
          <ol className="relative border-l border-slate-100 ml-2 space-y-4">
            {auditLogs.slice(0, 6).map((log, i) => {
              const isApproved = log.action.includes("APPROVE");
              const isRejected = log.action === "REJECTED";
              return (
                <li key={i} className="ml-4">
                  <span className={`absolute -left-[7px] flex h-3.5 w-3.5 items-center justify-center rounded-full ring-2 ring-white ${
                    isApproved ? "bg-emerald-400" : isRejected ? "bg-red-400" : "bg-slate-300"
                  }`} />
                  <p className="text-[10px] text-slate-400 mb-0.5">{log.timestamp} · {log.actor}</p>
                  <p className="text-xs leading-snug">
                    <span className={`font-bold ${isApproved ? "text-emerald-700" : isRejected ? "text-red-700" : "text-slate-600"}`}>
                      {log.action}
                    </span>{" "}
                    <span className="text-slate-500">{log.target}</span>
                  </p>
                  <p className="text-[10px] text-slate-400 mt-0.5 line-clamp-1">{log.details}</p>
                </li>
              );
            })}
          </ol>
        </div>
      </section>

      {/* ── Payout audit overlay ──────────────────────────────────────────── */}
      {showAuditOverlay && (
        <div
          className="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-end justify-center z-50"
          onClick={() => setShowAuditOverlay(false)}
        >
          <div
            className="bg-white w-full max-w-2xl rounded-t-3xl p-6 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-slate-200" />
            <div className="flex items-center justify-between mb-5">
              <h2 className="text-lg font-bold text-slate-900">Payout Audit Trail</h2>
              <button onClick={() => setShowAuditOverlay(false)} className="rounded-full p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-600 transition-colors">
                <Icon path={ICONS.x} className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-2">
              {auditLogs
                .filter((l) => l.action.includes("APPROVE") || l.details.includes("₹"))
                .slice(0, 5)
                .map((log, i) => (
                  <div key={i} className="flex items-center justify-between rounded-xl bg-slate-50 p-4 ring-1 ring-slate-100">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <span className="font-semibold text-sm text-slate-800 truncate">{log.target}</span>
                        <span className="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-bold bg-emerald-100 text-emerald-700">{log.action}</span>
                      </div>
                      <p className="text-xs text-slate-500">{log.details}</p>
                      <p className="text-[10px] text-slate-400 mt-0.5">{log.timestamp} · {log.actor}</p>
                    </div>
                    <code className="ml-4 shrink-0 font-mono text-[10px] text-slate-400 bg-white px-2 py-1 rounded ring-1 ring-slate-200 select-all">
                      UPI/{log.timestamp.replace(/[- :]/g, "").slice(2, 8)}/CONT{10000 + (i * 12345 % 90000)}
                    </code>
                  </div>
                ))}
            </div>
            <button
              onClick={() => setShowAuditOverlay(false)}
              className="mt-5 w-full rounded-xl bg-slate-100 py-2.5 text-sm font-medium text-slate-600 hover:bg-slate-200 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </AdminShell>
  );
}
