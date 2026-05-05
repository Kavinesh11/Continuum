"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Search, X } from "lucide-react";

function TierPill({ tier }: { tier: string }) {
  const map: Record<string, { bg: string; color: string }> = {
    Platinum: { bg: "rgba(139,92,246,0.15)", color: "#A78BFA" },
    Gold:     { bg: "rgba(245,158,11,0.15)", color: "#FCD34D" },
    Silver:   { bg: "rgba(148,163,184,0.1)", color: "#94A3B8" },
  };
  const s = map[tier] ?? { bg: "rgba(148,163,184,0.1)", color: "#94A3B8" };
  return (
    <span className="px-1.5 py-0.5 rounded text-[9px] font-bold uppercase tracking-wider" style={{ background: s.bg, color: s.color }}>
      {tier}
    </span>
  );
}

function initials(name: string) {
  return name.split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase();
}

function avatarColor(name: string) {
  const colors = ["#008A8A", "#8B5CF6", "#F59E0B", "#EF4444", "#22C55E", "#3B82F6"];
  const idx = name.charCodeAt(0) % colors.length;
  return colors[idx];
}

export default function DriversPage() {
  const { drivers, fraudFlagging, zoneEnrollmentLock } = useDemo();

  const [searchTerm, setSearchTerm] = useState("");
  const [tierFilter, setTierFilter] = useState("All");
  const [selectedDriverName, setSelectedDriverName] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);

  const tiers = ["All", "Platinum", "Gold", "Silver"];

  let filtered = drivers.filter((d) => d.name.toLowerCase().includes(searchTerm.toLowerCase()));
  if (tierFilter !== "All") filtered = filtered.filter((d) => d.tier === tierFilter);

  const selectedDriver = drivers.find((d) => d.name === selectedDriverName);

  return (
    <AdminShell title="Driver Profiles" subtitle="Partner risk profiles, payout history, and tier management.">
      <div className="flex gap-4 relative">

        {/* ── Driver list ──────────────────────────────────────────────── */}
        <div className={`flex flex-col gap-3 ${selectedDriver ? "w-[52%] shrink-0" : "flex-1"}`}>

          {/* Search + filter */}
          <div className="flex gap-2 items-center p-3 rounded-xl border" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <Search className="w-3.5 h-3.5 shrink-0" style={{ color: "#475569" }} />
            <input
              type="text"
              placeholder="Search partners…"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="flex-1 bg-transparent text-xs focus:outline-none"
              style={{ color: "#F1F5F9" }}
            />
            <div className="flex gap-1">
              {tiers.map((t) => (
                <button key={t} onClick={() => setTierFilter(t)}
                  className="px-2 py-1 text-[10px] rounded-lg font-medium transition-all"
                  style={{
                    background: tierFilter === t ? "#008A8A" : "rgba(51,65,85,0.3)",
                    color:      tierFilter === t ? "#fff"    : "#64748B",
                  }}>
                  {t}
                </button>
              ))}
            </div>
          </div>

          {/* Table */}
          <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <table className="w-full text-xs">
              <thead>
                <tr style={{ background: "rgba(15,23,42,0.4)", borderBottom: "1px solid rgba(51,65,85,0.4)" }}>
                  {["Partner", "Tier", "Zone", "Risk", "Payout"].map((h, i) => (
                    <th key={h} className={`py-3 text-[9px] font-semibold uppercase tracking-widest ${i === 0 ? "pl-5 text-left" : i === 4 ? "pr-5 text-right" : "text-left px-3"}`}
                      style={{ color: "#475569" }}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map((driver, i) => {
                  const isSel = selectedDriverName === driver.name;
                  const color = avatarColor(driver.name);
                  const riskColor = driver.riskScore > 0.6 ? "#EF4444" : driver.riskScore > 0.3 ? "#F59E0B" : "#22C55E";
                  return (
                    <tr key={driver.name}
                      onClick={() => { setSelectedDriverName(driver.name); setIsEditing(false); }}
                      className="cursor-pointer transition-all"
                      style={{
                        background: isSel ? "rgba(0,138,138,0.08)" : i % 2 === 1 ? "rgba(15,23,42,0.2)" : "transparent",
                        borderBottom: "1px solid rgba(51,65,85,0.25)",
                        borderLeft: isSel ? "2px solid rgba(0,191,166,0.5)" : "2px solid transparent",
                      }}
                      onMouseEnter={(e) => { if (!isSel) e.currentTarget.style.background = "rgba(255,255,255,0.02)"; }}
                      onMouseLeave={(e) => { if (!isSel) e.currentTarget.style.background = i % 2 === 1 ? "rgba(15,23,42,0.2)" : "transparent"; }}
                    >
                      <td className="pl-5 py-3">
                        <div className="flex items-center gap-2.5">
                          <Avatar className="h-7 w-7 shrink-0">
                            <AvatarFallback className="text-[10px] font-bold" style={{ background: `${color}20`, color }}>
                              {initials(driver.name)}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <div className="font-medium" style={{ color: "#CBD5E1" }}>{driver.name}</div>
                            <div className="text-[9px]" style={{ color: "#475569" }}>{driver.platform}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-3 py-3"><TierPill tier={driver.tier} /></td>
                      <td className="px-3 py-3" style={{ color: "#64748B" }}>{driver.zone}</td>
                      <td className="px-3 py-3">
                        <span className="font-semibold tabular-nums text-[11px]" style={{ color: riskColor }}>{driver.riskScore}</span>
                      </td>
                      <td className="pr-5 py-3 text-right font-semibold" style={{ color: "#00BFA6" }}>
                        ₹{driver.totalPayout.toLocaleString()}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {filtered.length === 0 && (
              <div className="p-8 text-center text-xs" style={{ color: "#475569" }}>No partners match your search.</div>
            )}
          </div>
        </div>

        {/* ── Driver detail panel ──────────────────────────────────────── */}
        {selectedDriver && (
          <div className="flex-1 min-w-0">
            <div className="sticky top-0 rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(0,191,166,0.25)" }}>

              {/* Header */}
              <div className="px-5 py-4 border-b" style={{
                background: "linear-gradient(135deg, rgba(15,23,42,0.9) 0%, rgba(26,39,68,0.9) 100%)",
                borderColor: "rgba(0,191,166,0.2)",
              }}>
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <Avatar className="h-10 w-10">
                      <AvatarFallback className="text-sm font-bold" style={{
                        background: `${avatarColor(selectedDriver.name)}25`,
                        color: avatarColor(selectedDriver.name),
                      }}>
                        {initials(selectedDriver.name)}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <EasterEggDetector taps={4} onTrigger={() => fraudFlagging(selectedDriver.name)}>
                        <h3 className="text-sm font-bold cursor-pointer" style={{ color: "#F1F5F9" }}>{selectedDriver.name}</h3>
                      </EasterEggDetector>
                      <div className="flex items-center gap-1.5 mt-0.5">
                        <TierPill tier={selectedDriver.tier} />
                        <span className="text-[10px]" style={{ color: "#475569" }}>{selectedDriver.platform}</span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {!isEditing && (
                      <button onClick={() => setIsEditing(true)}
                        className="px-3 py-1.5 text-[10px] font-semibold rounded-lg transition-colors hover:bg-white/5"
                        style={{ background: "rgba(0,138,138,0.15)", color: "#00BFA6" }}>
                        Edit
                      </button>
                    )}
                    <button onClick={() => { setSelectedDriverName(null); setIsEditing(false); }}
                      className="p-1.5 rounded-lg transition-colors hover:bg-white/5" style={{ color: "#475569" }}>
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>

              {!isEditing ? (
                <div className="p-5 space-y-4">
                  {/* Stats grid */}
                  <div className="grid grid-cols-3 gap-3">
                    {[
                      ["Zone",        selectedDriver.zone],
                      ["Risk Score",  String(selectedDriver.riskScore)],
                      ["Claims",      String(selectedDriver.claims)],
                      ["Total Payout",`₹${selectedDriver.totalPayout.toLocaleString()}`],
                      ["Premium",     `₹${(selectedDriver as { weeklyPremium?: number }).weeklyPremium ?? "—"}/wk`],
                      ["Member Since", (selectedDriver as { partnerSince?: string }).partnerSince ?? "—"],
                    ].map(([k, v]) => (
                      <div key={k} className="rounded-lg p-3" style={{ background: "#273548" }}>
                        <div className="text-[9px] uppercase tracking-widest mb-1" style={{ color: "#475569" }}>{k}</div>
                        <div className="text-xs font-semibold" style={{
                          color: k === "Risk Score"
                            ? (parseFloat(v) > 0.6 ? "#EF4444" : parseFloat(v) > 0.3 ? "#F59E0B" : "#22C55E")
                            : "#00BFA6",
                        }}>
                          {v}
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Contact */}
                  <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} className="pt-4">
                    <h4 className="text-[9px] uppercase tracking-widest mb-3" style={{ color: "#475569" }}>Contact</h4>
                    <div className="grid grid-cols-2 gap-y-2 text-xs">
                      {[
                        ["Phone",      (selectedDriver as { phone?: string }).phone ?? "—"],
                        ["UPI Handle", (selectedDriver as { upiHandle?: string }).upiHandle ?? "—"],
                        ["Partner ID", (selectedDriver as { partnerId?: string }).partnerId ?? "—"],
                      ].map(([k, v]) => (
                        <div key={k}>
                          <div className="text-[9px] uppercase tracking-widest mb-0.5" style={{ color: "#475569" }}>{k}</div>
                          <div className="font-medium truncate" style={{ color: "#94A3B8" }}>{v}</div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Zone lock easter egg */}
                  <div style={{ borderTop: "1px solid rgba(51,65,85,0.4)" }} className="pt-3">
                    <button
                      onContextMenu={(e) => { e.preventDefault(); zoneEnrollmentLock(selectedDriver.zone); }}
                      className="w-full text-left rounded-lg px-3 py-2 text-xs transition-colors hover:bg-white/5"
                      style={{ color: "#64748B", border: "1px dashed rgba(51,65,85,0.4)" }}>
                      Zone: {selectedDriver.zone} · Right-click to trigger lock demo
                    </button>
                  </div>
                </div>
              ) : (
                <div className="p-5">
                  <h4 className="text-[9px] uppercase tracking-widest mb-4" style={{ color: "#475569" }}>Edit Profile</h4>
                  <div className="space-y-3">
                    {[
                      { label: "Phone", type: "text", defaultValue: (selectedDriver as { phone?: string }).phone ?? "+91 98765 43210" },
                    ].map(({ label, type, defaultValue }) => (
                      <div key={label}>
                        <label className="text-[9px] uppercase tracking-widest mb-1 block" style={{ color: "#475569" }}>{label}</label>
                        <input type={type} defaultValue={defaultValue}
                          className="w-full rounded-lg px-3 py-2 text-xs focus:outline-none"
                          style={{ background: "#0F172A", border: "1px solid rgba(51,65,85,0.5)", color: "#F1F5F9" }} />
                      </div>
                    ))}
                    <div>
                      <label className="text-[9px] uppercase tracking-widest mb-1 block" style={{ color: "#475569" }}>Zone Override</label>
                      <select defaultValue={selectedDriver.zone}
                        className="w-full rounded-lg px-3 py-2 text-xs focus:outline-none"
                        style={{ background: "#0F172A", border: "1px solid rgba(51,65,85,0.5)", color: "#F1F5F9" }}>
                        {["BLR-South", "BLR-North", "CHN-Central"].map((z) => (
                          <option key={z} value={z} style={{ background: "#1E293B" }}>{z}</option>
                        ))}
                      </select>
                    </div>
                    <div className="flex gap-2 pt-2">
                      <button onClick={() => setIsEditing(false)}
                        className="flex-1 py-2 text-xs font-bold text-white rounded-lg transition-opacity hover:opacity-90"
                        style={{ background: "#008A8A" }}>
                        Save Changes
                      </button>
                      <button onClick={() => setIsEditing(false)}
                        className="flex-1 py-2 text-xs font-medium rounded-lg transition-colors"
                        style={{ background: "#273548", color: "#94A3B8" }}>
                        Cancel
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

      </div>
    </AdminShell>
  );
}
