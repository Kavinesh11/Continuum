"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";
import { Check, X } from "lucide-react";

const RISK_LAYERS = [
  { name: "GeoFence Integrity™",  key: "geo"      },
  { name: "TrustSignal™",         key: "trust"    },
  { name: "IdentityAnchor™",      key: "identity" },
  { name: "ActivityCross™",       key: "activity" },
  { name: "FairTime™",            key: "fairtime" },
];

function riskLayerResult(fraudScore: number, layerKey: string) {
  if (layerKey === "activity" && fraudScore > 0.6) return "FAIL";
  if (layerKey === "geo"      && fraudScore > 0.5) return "WARN";
  if (fraudScore > 0.7) return "FAIL";
  if (fraudScore > 0.4) return "WARN";
  return "PASS";
}

function RiskBadge({ result }: { result: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    PASS: { bg: "rgba(34,197,94,0.12)",  color: "#22C55E" },
    WARN: { bg: "rgba(245,158,11,0.12)", color: "#F59E0B" },
    FAIL: { bg: "rgba(239,68,68,0.12)",  color: "#EF4444" },
  };
  const s = map[result] ?? map.PASS;
  return (
    <span className="px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wide" style={{ background: s.bg, color: s.color }}>
      {result}
    </span>
  );
}

function StatusPill({ status }: { status: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    Approved:        { bg: "rgba(34,197,94,0.12)",  color: "#22C55E" },
    Rejected:        { bg: "rgba(239,68,68,0.12)",  color: "#EF4444" },
    Pending:         { bg: "rgba(245,158,11,0.12)", color: "#F59E0B" },
    "Auto-Approved": { bg: "rgba(0,191,166,0.15)",  color: "#00BFA6" },
  };
  const s = map[status] ?? { bg: "rgba(148,163,184,0.1)", color: "#94A3B8" };
  return (
    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold" style={{ background: s.bg, color: s.color }}>
      {status}
    </span>
  );
}


export default function ClaimsPage() {
  const { claims, approveClaim, rejectClaim, lockedZones, drivers, fraudFlagging } = useDemo();

  const [filterStatus, setFilterStatus] = useState("All");
  const [sortPriority, setSortPriority] = useState("High");
  const [selectedClaimId, setSelectedClaimId] = useState<string | null>(null);
  const [actionReason, setActionReason] = useState("");

  const statuses   = ["All", "Pending", "Approved", "Rejected"];
  const priorities = ["High", "Medium", "Low"];

  let filtered = claims;
  if (filterStatus !== "All") filtered = filtered.filter((c) => c.status.includes(filterStatus));
  filtered = [...filtered].sort((a, b) => {
    const pval = { High: 3, Medium: 2, Low: 1 };
    const pA = pval[a.priority as keyof typeof pval] || 0;
    const pB = pval[b.priority as keyof typeof pval] || 0;
    return sortPriority === "High" ? pB - pA : sortPriority === "Low" ? pA - pB : 0;
  });

  const selectedClaim  = claims.find((c) => c.id === selectedClaimId);
  const selectedDriver = selectedClaim ? drivers.find((d) => d.name === selectedClaim.driver) : null;

  return (
    <AdminShell title="Claims Queue" subtitle="Full driver dossier — review, verify, and decide." badge="Adjuster">
      <div className="flex gap-4 relative">

        {/* ── Claims list ──────────────────────────────────────────────── */}
        <div className={`flex flex-col gap-3 ${selectedClaim ? "w-[42%] shrink-0" : "flex-1"}`}>

          {/* Filter bar */}
          <div className="flex gap-2 items-center p-3 rounded-xl border" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <span className="text-[10px] uppercase tracking-widest font-semibold shrink-0" style={{ color: "#475569" }}>Filter</span>
            <div className="flex gap-1.5 flex-1">
              {statuses.map((s) => (
                <button key={s} onClick={() => setFilterStatus(s)}
                  className="px-2.5 py-1 text-[10px] rounded-lg font-medium transition-all duration-150"
                  style={{
                    background: filterStatus === s ? "#008A8A" : "rgba(51,65,85,0.3)",
                    color:      filterStatus === s ? "#fff"    : "#64748B",
                  }}>
                  {s}
                </button>
              ))}
            </div>
            <select value={sortPriority} onChange={(e) => setSortPriority(e.target.value)}
              className="text-[10px] rounded-lg px-2 py-1 border-none focus:ring-0 bg-transparent"
              style={{ color: "#64748B", background: "rgba(51,65,85,0.3)" }}>
              {priorities.map((p) => <option key={p} value={p} style={{ background: "#1E293B" }}>{p} first</option>)}
            </select>
          </div>

          {/* Claim cards */}
          <div className="flex flex-col gap-2">
            {filtered.map((claim) => {
              const isLocked = lockedZones.includes(claim.zone);
              const isSel = selectedClaimId === claim.id;
              const isFraud = (claim.fraudScore ?? 0) > 0.7;
              return (
                <div key={claim.id} onClick={() => setSelectedClaimId(claim.id)}
                  className="rounded-xl p-4 cursor-pointer transition-all duration-150"
                  style={{
                    background: isSel ? "#273548" : "#1E293B",
                    border: isSel
                      ? "1px solid rgba(0,191,166,0.5)"
                      : isFraud
                      ? "1px solid rgba(239,68,68,0.2)"
                      : "1px solid rgba(51,65,85,0.4)",
                    boxShadow: isSel ? "0 0 0 1px rgba(0,191,166,0.2)" : "none",
                  }}>
                  <div className="flex items-start justify-between mb-2">
                    <div className="flex items-center gap-1.5">
                      <span className="font-mono text-[10px]" style={{ color: "#475569" }}>{claim.id}</span>
                      {isFraud && (
                        <span className="px-1 py-0.5 rounded text-[8px] font-bold" style={{ background: "rgba(239,68,68,0.15)", color: "#EF4444" }}>
                          FRAUD {((claim.fraudScore ?? 0) * 100).toFixed(0)}%
                        </span>
                      )}
                      {isLocked && (
                        <span className="px-1 py-0.5 rounded text-[8px] font-bold" style={{ background: "rgba(245,158,11,0.15)", color: "#F59E0B" }}>
                          ZONE LOCKED
                        </span>
                      )}
                    </div>
                    <StatusPill status={claim.status} />
                  </div>
                  <div className="flex items-baseline justify-between">
                    <p className="text-sm font-semibold truncate" style={{ color: "#F1F5F9" }}>{claim.driver}</p>
                    <span className="text-sm font-bold ml-2 shrink-0" style={{ color: "#00BFA6" }}>₹{claim.amount}</span>
                  </div>
                  <p className="text-[10px] mt-1" style={{ color: "#64748B" }}>
                    {claim.tier} · {claim.zone} · {claim.reason}
                  </p>
                </div>
              );
            })}
            {filtered.length === 0 && (
              <div className="p-8 text-center rounded-xl border" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.4)", color: "#475569", fontSize: "13px" }}>
                No claims match your filters.
              </div>
            )}
          </div>
        </div>

        {/* ── Driver dossier ───────────────────────────────────────────── */}
        {selectedClaim && (
          <div className="flex-1 min-w-0">
            <div className="sticky top-0 rounded-xl border overflow-y-auto" style={{
              maxHeight: "calc(100vh - 120px)",
              background: "#1E293B",
              borderColor: "rgba(0,191,166,0.3)",
            }}>

              {/* Dossier header */}
              <div className="px-5 py-4 flex items-start justify-between" style={{
                background: "linear-gradient(135deg, #0F172A 0%, #1A2744 100%)",
                borderBottom: "1px solid rgba(0,191,166,0.2)",
              }}>
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-[9px] uppercase tracking-widest font-semibold" style={{ color: "#00BFA6" }}>Driver Dossier</span>
                    <span className="font-mono text-[10px]" style={{ color: "#475569" }}>{selectedClaim.id}</span>
                  </div>
                  <h3 className="text-base font-bold" style={{ color: "#F1F5F9" }}>{selectedClaim.driver}</h3>
                  <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>{selectedClaim.reason} · {selectedClaim.zone}</p>
                </div>
                <button onClick={() => { setSelectedClaimId(null); setActionReason(""); }}
                  className="p-1.5 rounded-lg transition-colors hover:bg-white/5" style={{ color: "#475569" }}>
                  <X className="w-4 h-4" />
                </button>
              </div>

              <div className="p-5 space-y-5">

                {/* A — Identity */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Identity & Platform</h4>
                  <div className="grid grid-cols-2 gap-x-5 gap-y-3">
                    {[
                      ["Partner ID",   selectedDriver?.partnerId ?? "—"],
                      ["Phone",        selectedDriver?.phone ?? "—"],
                      ["UPI Handle",   selectedDriver?.upiHandle ?? "—"],
                      ["Platform",     selectedDriver?.platform ?? "—"],
                      ["Zone",         selectedClaim.zone],
                      ["Member Since", selectedDriver?.partnerSince ?? "—"],
                    ].map(([k, v]) => (
                      <div key={k}>
                        <div className="text-[9px] uppercase tracking-widest mb-0.5" style={{ color: "#475569" }}>{k}</div>
                        <div className="text-xs font-medium truncate" style={{ color: "#CBD5E1" }}>{v}</div>
                      </div>
                    ))}
                  </div>
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* B — Coverage */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Coverage & Premiums</h4>
                  <div className="grid grid-cols-3 gap-3">
                    {[
                      ["Tier",           selectedClaim.tier],
                      ["Weekly Premium", `₹${selectedDriver?.weeklyPremium ?? "—"}`],
                      ["Total Coverage", `₹${selectedDriver?.totalCoverage?.toLocaleString() ?? "—"}`],
                      ["Premiums Paid",  `${selectedDriver?.premiumsPaid ?? "—"}w`],
                      ["Missed",         `${selectedDriver?.premiumsMissed ?? 0}w`],
                    ].map(([k, v]) => (
                      <div key={k} className="rounded-lg p-2.5" style={{ background: "#273548" }}>
                        <div className="text-[9px] uppercase tracking-widest mb-1" style={{ color: "#475569" }}>{k}</div>
                        <div className="text-sm font-bold" style={{ color: "#00BFA6" }}>{v}</div>
                      </div>
                    ))}
                  </div>
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* C — Claim history */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Claim History</h4>
                  <div className="rounded-lg overflow-hidden" style={{ border: "1px solid rgba(51,65,85,0.4)" }}>
                    <table className="w-full">
                      <thead>
                        <tr style={{ background: "#273548", borderBottom: "1px solid rgba(51,65,85,0.4)" }}>
                          {["ID", "Reason", "Amt", "Status"].map((h, i) => (
                            <th key={h} className={`py-2 text-[9px] font-semibold uppercase tracking-widest ${i === 0 ? "pl-3 text-left" : i === 3 ? "pr-3 text-right" : "text-right px-2"}`}
                              style={{ color: "#475569" }}>
                              {h}
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {(selectedDriver?.claimHistory ?? []).slice(0, 5).map((c, i) => (
                          <tr key={c.id} style={{ borderBottom: "1px solid rgba(51,65,85,0.25)" }}>
                            <td className="pl-3 py-2 font-mono text-[9px]" style={{ color: "#475569" }}>{c.id}</td>
                            <td className="px-2 py-2 text-[10px]" style={{ color: "#94A3B8" }}>{c.reason}</td>
                            <td className="px-2 py-2 text-right text-[10px] font-medium" style={{ color: "#CBD5E1" }}>₹{c.amount}</td>
                            <td className="pr-3 py-2 text-right">
                              <span className="px-1.5 py-0.5 rounded text-[9px] font-semibold" style={{
                                background: c.status === "Approved" ? "rgba(34,197,94,0.12)" : c.status === "Rejected" ? "rgba(239,68,68,0.12)" : "rgba(245,158,11,0.12)",
                                color:      c.status === "Approved" ? "#22C55E"              : c.status === "Rejected" ? "#EF4444"               : "#F59E0B",
                              }}>
                                {c.status}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* D — Oracle signals */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Oracle Consensus</h4>
                  <div className="rounded-lg p-3" style={{ background: "#273548", border: "1px solid rgba(0,138,138,0.2)" }}>
                    <div className="grid grid-cols-2 gap-y-2 gap-x-4">
                      {[["IMD India","ok"],["AccuWeather","ok"],["NASA-GPM","ok"],["Windy","fail"]].map(([name, status]) => (
                        <div key={name} className="flex items-center gap-2 text-[11px]" style={{ color: status === "ok" ? "#22C55E" : "#EF4444" }}>
                          <div className="w-4 h-4 rounded flex items-center justify-center flex-shrink-0"
                            style={{ background: status === "ok" ? "rgba(34,197,94,0.15)" : "rgba(239,68,68,0.15)" }}>
                            {status === "ok"
                              ? <Check className="w-2.5 h-2.5" strokeWidth={3} />
                              : <X className="w-2.5 h-2.5" strokeWidth={3} />}
                          </div>
                          <span style={{ color: "#94A3B8" }}>{name}</span>
                        </div>
                      ))}
                    </div>
                    <div className="text-[10px] mt-2.5 pt-2 font-medium" style={{ borderTop: "1px solid rgba(51,65,85,0.4)", color: "#00BFA6" }}>
                      3/4 consensus — threshold met
                    </div>
                  </div>
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* E — ActivityCross */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>ActivityCross™ — Platform Orders</h4>
                  <div className="rounded-lg overflow-hidden" style={{ border: "1px solid rgba(51,65,85,0.4)" }}>
                    {(selectedDriver?.recentOrders ?? []).slice(0, 5).map((o, i) => (
                      <div key={i} className="flex items-center justify-between px-3 py-2.5 text-[11px]" style={{
                        borderBottom: i < 4 ? "1px solid rgba(51,65,85,0.3)" : "none",
                        background: i % 2 === 1 ? "rgba(15,23,42,0.3)" : "transparent",
                      }}>
                        <span className="font-mono text-[9px]" style={{ color: "#475569" }}>{o.date.slice(5)}</span>
                        <span style={{ color: "#94A3B8" }}>{o.platform}</span>
                        <span className="font-medium" style={{ color: o.completed ? "#CBD5E1" : "#475569" }}>
                          {o.completed ? `₹${o.earnings}` : "Cancelled"}
                        </span>
                        <span style={{ color: o.completed ? "#22C55E" : "#475569" }}>
                          {o.completed ? <Check className="w-3 h-3" strokeWidth={3} /> : <X className="w-3 h-3" strokeWidth={2} />}
                        </span>
                      </div>
                    ))}
                  </div>
                  {selectedClaim.isFraud && (
                    <div className="mt-2 rounded-lg px-3 py-2 text-[10px] font-medium" style={{ background: "rgba(239,68,68,0.1)", color: "#EF4444" }}>
                      Orders detected during disruption window — ActivityCross™ veto applied
                    </div>
                  )}
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* F — Five-layer risk */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Five-Layer Risk Assessment</h4>
                  <div className="space-y-2">
                    {RISK_LAYERS.map((layer) => {
                      const result = riskLayerResult(selectedClaim.fraudScore, layer.key);
                      return (
                        <div key={layer.key} className="flex items-center justify-between">
                          <span className="text-xs" style={{ color: "#94A3B8" }}>{layer.name}</span>
                          <RiskBadge result={result} />
                        </div>
                      );
                    })}
                  </div>
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* G — Security events */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>Security Events</h4>
                  {(selectedDriver?.securityEvents ?? []).map((ev, i) => (
                    <div key={i} className="flex items-start justify-between py-2" style={{ borderBottom: "1px solid rgba(51,65,85,0.25)" }}>
                      <div>
                        <div className="text-[11px]" style={{ color: "#94A3B8" }}>{ev.event}</div>
                        <div className="text-[10px] mt-0.5" style={{ color: "#475569" }}>{ev.date.slice(0, 10)}</div>
                      </div>
                      <span className="ml-3 px-1.5 py-0.5 rounded text-[9px] font-bold flex-shrink-0" style={{
                        background: ev.outcome === "Cleared" ? "rgba(34,197,94,0.12)" : ev.outcome.includes("Blocked") ? "rgba(239,68,68,0.12)" : "rgba(245,158,11,0.12)",
                        color:      ev.outcome === "Cleared" ? "#22C55E"               : ev.outcome.includes("Blocked") ? "#EF4444"               : "#F59E0B",
                      }}>
                        {ev.outcome.split(" ")[0]}
                      </span>
                    </div>
                  ))}
                </section>

                <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />

                {/* H — GPS + Fraud score */}
                <section>
                  <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3" style={{ color: "#008A8A" }}>GPS Log & Fraud Score</h4>
                  <div className="rounded-lg p-3 mb-2 text-[11px]" style={{
                    background: selectedClaim.fraudScore > 0.7 ? "rgba(239,68,68,0.08)" : "rgba(0,138,138,0.08)",
                    border: `1px solid ${selectedClaim.fraudScore > 0.7 ? "rgba(239,68,68,0.2)" : "rgba(0,138,138,0.2)"}`,
                  }}>
                    <div className="flex items-center justify-between mb-1">
                      <span className="font-semibold" style={{ color: selectedClaim.fraudScore > 0.7 ? "#EF4444" : "#00BFA6" }}>
                        Fraud Score: {selectedClaim.fraudScore}
                      </span>
                      <span className="text-[9px] font-bold px-1.5 py-0.5 rounded" style={{
                        background: selectedClaim.fraudScore > 0.7 ? "rgba(239,68,68,0.15)" : selectedClaim.fraudScore > 0.3 ? "rgba(245,158,11,0.15)" : "rgba(34,197,94,0.15)",
                        color:      selectedClaim.fraudScore > 0.7 ? "#EF4444"               : selectedClaim.fraudScore > 0.3 ? "#F59E0B"               : "#22C55E",
                      }}>
                        {selectedClaim.fraudScore > 0.7 ? "HIGH RISK" : selectedClaim.fraudScore > 0.3 ? "MEDIUM" : "LOW RISK"}
                      </span>
                    </div>
                    {selectedClaim.fraudScore > 0.7 && (
                      <div style={{ color: "#EF4444" }}>crew-AI: Unusual claim frequency for zone proximity.</div>
                    )}
                  </div>
                  {selectedDriver?.gpsZoneHistory && (
                    <div className="text-[10px] italic" style={{ color: "#475569" }}>{selectedDriver.gpsZoneHistory}</div>
                  )}
                </section>

                {/* I — Approve / Reject */}
                {selectedClaim.status === "Pending" && (
                  <>
                    <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} />
                    <section>
                      <EasterEggDetector taps={4} onTrigger={() => fraudFlagging(selectedClaim.driver)}>
                        <h4 className="text-[9px] uppercase tracking-widest font-semibold mb-3 cursor-pointer" style={{ color: "#008A8A" }}>
                          Adjuster Note (Required)
                        </h4>
                      </EasterEggDetector>
                      <textarea
                        value={actionReason}
                        onChange={(e) => setActionReason(e.target.value)}
                        placeholder="Enter justification for approval or rejection..."
                        className="w-full rounded-lg p-3 text-xs focus:outline-none min-h-[64px] resize-none transition-colors"
                        style={{
                          background: "#0F172A",
                          border: "1px solid rgba(51,65,85,0.5)",
                          color: "#F1F5F9",
                        }}
                        onFocus={(e) => { e.currentTarget.style.borderColor = "rgba(0,191,166,0.5)"; }}
                        onBlur={(e) => { e.currentTarget.style.borderColor = "rgba(51,65,85,0.5)"; }}
                      />
                      <div className="flex gap-2 mt-3">
                        <button
                          onClick={() => {
                            if (!actionReason) return alert("Enter a reason.");
                            approveClaim(selectedClaim.id, actionReason);
                            setSelectedClaimId(null);
                            setActionReason("");
                          }}
                          className="flex-1 py-2.5 text-xs font-bold text-white rounded-lg transition-opacity hover:opacity-90"
                          style={{ background: "#008A8A" }}>
                          Approve Payout
                        </button>
                        <button
                          onClick={() => {
                            if (!actionReason) return alert("Enter a reason.");
                            rejectClaim(selectedClaim.id, actionReason);
                            setSelectedClaimId(null);
                            setActionReason("");
                          }}
                          className="flex-1 py-2.5 text-xs font-bold rounded-lg transition-colors border"
                          style={{ borderColor: "rgba(239,68,68,0.3)", color: "#EF4444", background: "transparent" }}>
                          Reject
                        </button>
                      </div>
                    </section>
                  </>
                )}

                {selectedClaim.status !== "Pending" && selectedClaim.justification && (
                  <div className="rounded-lg p-3" style={{ background: "rgba(0,138,138,0.08)", border: "1px solid rgba(0,138,138,0.2)" }}>
                    <span className="text-[9px] uppercase tracking-widest font-semibold block mb-1.5" style={{ color: "#008A8A" }}>Decision</span>
                    <p className="text-xs italic" style={{ color: "#94A3B8" }}>&quot;{selectedClaim.justification}&quot;</p>
                  </div>
                )}

              </div>
            </div>
          </div>
        )}

      </div>
    </AdminShell>
  );
}
