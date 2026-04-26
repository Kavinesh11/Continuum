"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

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
  const [rejectingId, setRejectingId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState("");

  const pendingClaims = claims.filter((c) => c.status === "Pending");
  const recentClaims = claims.slice(0, 8);

  const handleApprove = (id: string, reason: string, amount: number) => {
    approveClaim(id, `₹${amount} — ${reason}`);
  };

  const handleRejectConfirm = (id: string) => {
    if (!rejectReason.trim()) return;
    rejectClaim(id, rejectReason.trim());
    setRejectingId(null);
    setRejectReason("");
  };

  return (
    <AdminShell
      title="Admin Dashboard"
      subtitle="Monitor claims, payouts, and zone risk in real time."
    >
      {/* ── KPI cards ───────────────────────────────────────────────────────── */}
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <EasterEggDetector taps={4} onTrigger={bulkApproveWave}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors cursor-pointer">
            <p className="text-sm text-teal-700">Pending Queue</p>
            <p className="mt-2 text-2xl font-semibold">{kpis.pendingQueue}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={4} onTrigger={() => setShowAuditOverlay(true)}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors cursor-pointer">
            <p className="text-sm text-teal-700">Approved Today</p>
            <p className="mt-2 text-2xl font-semibold text-green-600">{kpis.approvedToday}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={3} onTrigger={claimRejectionCascade}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors cursor-pointer">
            <p className="text-sm text-teal-700">Rejected Today</p>
            <p className="mt-2 text-2xl font-semibold text-red-600">{kpis.rejectedToday}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={3} onTrigger={() => fraudFlagging()}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors cursor-pointer">
            <p className="text-sm text-teal-700">Fraud Flagged</p>
            <p className="mt-2 text-2xl font-semibold text-orange-500">{kpis.fraudFlagged}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={4} onTrigger={reserveFloorBreach}>
          <article className={`rounded-2xl p-5 shadow-sm ring-1 transition-colors cursor-pointer ${kpis.reserveRunwayDays < 60 ? "bg-red-50 ring-red-200 text-red-900" : "bg-white ring-teal-100 hover:bg-teal-50"}`}>
            <p className={`text-sm ${kpis.reserveRunwayDays < 60 ? "text-red-700" : "text-teal-700"}`}>Reserve Runway</p>
            <p className="mt-2 text-2xl font-semibold">{kpis.reserveRunwayDays} days</p>
          </article>
        </EasterEggDetector>

        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">Zones Active</p>
          <p className="mt-2 text-2xl font-semibold">{kpis.zonesActive}/{kpis.zonesTotal}</p>
        </article>

        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">Avg Payout</p>
          <p className="mt-2 text-2xl font-semibold">₹{kpis.avgPayout}</p>
        </article>

        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">Total Payout Today</p>
          <p className="mt-2 text-2xl font-semibold">₹{kpis.totalPayoutToday.toLocaleString()}</p>
        </article>
      </section>

      {/* ── Pending Review queue ─────────────────────────────────────────────── */}
      {pendingClaims.length > 0 && (
        <section className="rounded-2xl bg-amber-50 ring-1 ring-amber-200 p-6 shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-800 ring-1 ring-amber-300">
              <span className="inline-block h-2 w-2 rounded-full bg-amber-500 animate-pulse" />
              {pendingClaims.length} Pending Review
            </span>
            <h3 className="text-base font-semibold text-amber-900">Claims Awaiting Decision</h3>
          </div>
          <div className="space-y-3">
            {pendingClaims.map((claim) => (
              <div
                key={claim.id}
                className={`rounded-xl bg-white p-4 ring-1 shadow-sm flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between ${
                  (claim.fraudScore ?? 0) > 0.7 ? "ring-red-300" : "ring-amber-200"
                }`}
              >
                <div className="flex-1 min-w-0">
                  <div className="flex flex-wrap items-center gap-2 mb-1">
                    <span className="font-mono text-xs font-bold text-slate-500">{claim.id}</span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      claim.tier === "Platinum" ? "bg-purple-100 text-purple-700" :
                      claim.tier === "Gold" ? "bg-yellow-100 text-yellow-700" :
                      "bg-slate-100 text-slate-600"
                    }`}>{claim.tier}</span>
                    {(claim.fraudScore ?? 0) > 0.7 && (
                      <span className="px-1.5 py-0.5 text-[10px] font-bold bg-red-100 text-red-700 rounded">
                        FRAUD {((claim.fraudScore ?? 0) * 100).toFixed(0)}%
                      </span>
                    )}
                    {(claim as { isFraud?: boolean }).isFraud && (
                      <span className="px-1.5 py-0.5 text-[10px] font-bold bg-orange-100 text-orange-700 rounded">
                        ESCALATED
                      </span>
                    )}
                  </div>
                  <p className="text-sm font-semibold text-slate-800">{claim.driver} — {claim.reason}</p>
                  {(claim as { description?: string }).description && (
                    <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">
                      {(claim as { description?: string }).description}
                    </p>
                  )}
                  <p className="text-xs text-slate-400 mt-1">{claim.zone} · ₹{claim.amount}</p>
                </div>

                {rejectingId === claim.id ? (
                  <div className="flex flex-col gap-2 min-w-[220px]">
                    <input
                      className="rounded-lg border border-slate-200 px-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-red-300"
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
                        Confirm Reject
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
                  <div className="flex gap-2 shrink-0">
                    <button
                      onClick={() => handleApprove(claim.id, claim.reason, claim.amount)}
                      className="rounded-lg bg-green-600 px-4 py-2 text-xs font-bold text-white hover:bg-green-700 transition-colors"
                    >
                      Approve ₹{claim.amount > 0 ? claim.amount : (claim.tier === "Platinum" ? 450 : claim.tier === "Gold" ? 312 : 180)}
                    </button>
                    <button
                      onClick={() => setRejectingId(claim.id)}
                      className="rounded-lg bg-red-50 px-4 py-2 text-xs font-bold text-red-700 ring-1 ring-red-200 hover:bg-red-100 transition-colors"
                    >
                      Reject
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── Claims table + Audit log ─────────────────────────────────────────── */}
      <section className="grid gap-6 lg:grid-cols-3">
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100 lg:col-span-2">
          <h3 className="text-lg font-semibold">Recent Claims</h3>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-teal-100 text-teal-700">
                <tr>
                  <th className="py-3 pr-3">Claim ID</th>
                  <th className="py-3 pr-3">Driver</th>
                  <th className="py-3 pr-3">Zone</th>
                  <th className="py-3 pr-3">Status</th>
                  <th className="py-3">Amount</th>
                </tr>
              </thead>
              <tbody>
                {recentClaims.map((claim) => (
                  <tr key={claim.id} className="border-b border-teal-50 hover:bg-teal-50/40 transition-colors">
                    <td className="py-3 pr-3 font-medium">
                      <div className="flex items-center gap-2">
                        {claim.id}
                        {(claim.fraudScore ?? 0) > 0.7 && (
                          <span className="px-1.5 py-0.5 text-[10px] font-bold bg-red-100 text-red-700 rounded">FRAUD</span>
                        )}
                      </div>
                    </td>
                    <td className="py-3 pr-3">
                      <div>{claim.driver}</div>
                      <div className="text-[11px] text-slate-400">{claim.tier}</div>
                    </td>
                    <td className="py-3 pr-3 text-slate-500 text-xs">{claim.zone}</td>
                    <td className="py-3 pr-3">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        claim.status === "Approved" ? "bg-green-100 text-green-700" :
                        claim.status === "Rejected" ? "bg-red-100 text-red-700" :
                        claim.status === "Pending" ? "bg-amber-100 text-amber-700" :
                        "bg-gray-100 text-gray-700"
                      }`}>
                        {claim.status}
                      </span>
                    </td>
                    <td className="py-3 font-semibold">₹{claim.amount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold">Audit Log</h3>
          <ul className="mt-4 space-y-3 text-sm text-teal-800">
            {auditLogs.slice(0, 5).map((log, i) => (
              <li key={i} className="rounded-lg bg-teal-50 p-3">
                <div className="text-xs text-teal-600 mb-1">[{log.timestamp}] {log.actor}</div>
                <div>
                  <span className={`font-semibold ${
                    log.action === "APPROVED" || log.action === "AUTO-APPROVED" ? "text-green-700" :
                    log.action === "REJECTED" ? "text-red-700" : ""
                  }`}>{log.action}</span>{" "}
                  {log.target}
                </div>
                <div className="text-xs text-teal-700 mt-1 opacity-80">{log.details}</div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ── Payout Audit overlay ─────────────────────────────────────────────── */}
      {showAuditOverlay && (
        <div
          className="fixed inset-0 bg-black/40 flex items-end justify-center z-50 animate-in fade-in"
          onClick={() => setShowAuditOverlay(false)}
        >
          <div
            className="bg-white w-full max-w-3xl rounded-t-3xl p-6 shadow-2xl animate-in slide-in-from-bottom"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-bold text-teal-950">Payout Audit Trail</h2>
              <button onClick={() => setShowAuditOverlay(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>

            <div className="space-y-3">
              {auditLogs
                .filter((l) => l.action.includes("APPROVE") || l.details.includes("₹"))
                .slice(0, 5)
                .map((log, i) => (
                  <div key={i} className="flex justify-between items-center p-4 rounded-xl bg-teal-50 ring-1 ring-teal-100">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-teal-900">{log.target}</span>
                        <span className="px-2 py-0.5 bg-green-100 text-green-700 text-[10px] font-bold rounded">{log.action}</span>
                      </div>
                      <div className="text-sm text-teal-700 mt-1">{log.details}</div>
                      <div className="text-xs text-teal-500 mt-1">{log.timestamp} · by {log.actor}</div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="font-mono text-xs text-slate-500 bg-white px-2 py-1 rounded ring-1 ring-slate-200 select-all">
                        UPI/{log.timestamp.replace(/[- :]/g, "").slice(2, 8)}/CONT{10000 + (i * 12345 % 90000)}
                      </div>
                    </div>
                  </div>
                ))}
            </div>

            <div className="mt-6 text-center">
              <button
                onClick={() => setShowAuditOverlay(false)}
                className="px-6 py-2 bg-slate-100 text-slate-700 font-medium rounded-lg hover:bg-slate-200"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminShell>
  );
}
