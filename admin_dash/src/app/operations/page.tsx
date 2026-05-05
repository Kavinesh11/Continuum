"use client";

import { useState, useEffect } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { Activity, Radio, Zap, Search, AlertCircle, Heart } from "lucide-react";

// ── Status dot ────────────────────────────────────────────────────────────────

function StatusDot({ status }: { status: string }) {
  const color = status === "healthy" || status === "nominal" ? "#22C55E"
    : status === "degraded" || status === "alert" ? "#F59E0B"
    : "#EF4444";
  return (
    <span className="w-2 h-2 rounded-full inline-flex flex-shrink-0" style={{ background: color, boxShadow: `0 0 6px ${color}60` }} />
  );
}

// ── Confidence bar ────────────────────────────────────────────────────────────

function ConfidenceBar({ value, alert }: { value: number; alert?: boolean }) {
  return (
    <div className="flex items-center gap-2 w-full">
      <div className="flex-1 rounded-full h-1.5 overflow-hidden" style={{ background: "rgba(51,65,85,0.4)" }}>
        <div className="h-full rounded-full transition-all duration-700"
          style={{
            width: `${value * 100}%`,
            background: alert
              ? "linear-gradient(90deg, #F59E0B, #EF4444)"
              : "linear-gradient(90deg, #008A8A, #00BFA6)",
            boxShadow: alert ? "none" : "0 0 8px rgba(0,191,166,0.4)",
          }} />
      </div>
      <span className="text-[10px] font-semibold w-7 text-right tabular-nums"
        style={{ color: alert ? "#F59E0B" : "#00BFA6" }}>
        {(value * 100).toFixed(0)}%
      </span>
    </div>
  );
}

// ── Lag bar ───────────────────────────────────────────────────────────────────

function LagBar({ lag }: { lag: number }) {
  const color = lag === 0 ? "#22C55E" : lag <= 4 ? "#F59E0B" : "#EF4444";
  return (
    <div className="flex items-center gap-3">
      <div className="flex-1 rounded-full h-1.5 overflow-hidden" style={{ background: "rgba(51,65,85,0.4)" }}>
        <div className="h-full rounded-full transition-all duration-500"
          style={{ width: `${Math.min(100, lag * 14)}%`, background: color }} />
      </div>
      <span className="text-xs font-bold tabular-nums w-4 text-right" style={{ color }}>{lag}</span>
    </div>
  );
}

// ── Event type icon ───────────────────────────────────────────────────────────

const EVENT_ICONS: Record<string, { Icon: React.ElementType; color: string }> = {
  oracle:  { Icon: Radio,      color: "#008A8A" },
  kafka:   { Icon: Zap,        color: "#F59E0B" },
  payout:  { Icon: Activity,   color: "#22C55E" },
  scoring: { Icon: Search,     color: "#8B5CF6" },
  health:  { Icon: AlertCircle, color: "#EF4444" },
};

// ── Page ──────────────────────────────────────────────────────────────────────

export default function OperationsPage() {
  const { opsHealth } = useDemo();
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 1000);
    return () => clearInterval(id);
  }, []);

  const healthyCount = opsHealth.services.filter((s) => s.status === "healthy").length;
  const degradedCount = opsHealth.services.filter((s) => s.status === "degraded").length;

  return (
    <AdminShell
      title="Operations Monitor"
      subtitle="Infrastructure health — oracle feeds, Kafka queues, service latencies."
      badge="DevOps"
    >
      <div className="flex flex-col gap-5">

        {/* ── Live status banner ──────────────────────────────────────── */}
        <div className="flex items-center justify-between px-1">
          <div className="flex items-center gap-3">
            <span className="live-dot w-1.5 h-1.5 rounded-full" style={{ background: "#22C55E" }} />
            <span className="text-xs" style={{ color: "#475569" }}>Live polling — {tick}s session uptime</span>
          </div>
          <div className="flex items-center gap-4">
            <span className="flex items-center gap-1.5 text-[11px]" style={{ color: "#22C55E" }}>
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: "#22C55E" }} />
              {healthyCount} healthy
            </span>
            {degradedCount > 0 && (
              <span className="flex items-center gap-1.5 text-[11px]" style={{ color: "#F59E0B" }}>
                <span className="w-1.5 h-1.5 rounded-full" style={{ background: "#F59E0B" }} />
                {degradedCount} degraded
              </span>
            )}
          </div>
        </div>

        {/* ── Service health grid ─────────────────────────────────────── */}
        <div>
          <h3 className="text-[10px] font-semibold uppercase tracking-widest mb-3 px-1" style={{ color: "#475569" }}>
            Service Health
          </h3>
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
            {opsHealth.services.map((svc) => {
              const isHealthy = svc.status === "healthy";
              const isDegraded = svc.status === "degraded";
              return (
                <div key={svc.name} className="rounded-xl p-4 border transition-all duration-200"
                  style={{
                    background: isDegraded ? "rgba(245,158,11,0.06)" : "#1E293B",
                    borderColor: isDegraded ? "rgba(245,158,11,0.25)" : "rgba(51,65,85,0.5)",
                  }}>
                  <div className="flex items-center justify-between mb-4">
                    <StatusDot status={svc.status} />
                    <span className="text-[9px] font-semibold px-1.5 py-0.5 rounded-full uppercase tracking-wide" style={{
                      background: isHealthy ? "rgba(34,197,94,0.1)" : "rgba(245,158,11,0.15)",
                      color: isHealthy ? "#22C55E" : "#F59E0B",
                    }}>
                      {svc.status}
                    </span>
                  </div>
                  <div className="text-[11px] font-semibold mb-2 leading-tight" style={{ color: "#CBD5E1" }}>{svc.name}</div>
                  <div className="text-2xl font-bold tabular-nums" style={{ color: svc.latencyMs > 1000 ? "#F59E0B" : "#00BFA6" }}>
                    {svc.latencyMs}
                    <span className="text-xs font-normal ml-0.5" style={{ color: "#475569" }}>ms</span>
                  </div>
                  <div className="text-[10px] mt-1" style={{ color: "#475569" }}>{svc.uptime}% uptime</div>
                </div>
              );
            })}
          </div>
        </div>

        {/* ── Oracle + Kafka ──────────────────────────────────────────── */}
        <div className="grid lg:grid-cols-2 gap-4">

          {/* Oracle feeds */}
          <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
            <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
              <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Oracle Feed Status</h3>
              <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>5 sources — consensus requires ≥ 3 affirm votes</p>
            </div>
            <div>
              {opsHealth.oracleFeeds.map((feed, i) => (
                <div key={feed.name} className="px-5 py-3.5 flex items-center gap-4" style={{
                  borderBottom: i < opsHealth.oracleFeeds.length - 1 ? "1px solid rgba(51,65,85,0.3)" : "none",
                }}>
                  <StatusDot status={feed.status} />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs font-medium truncate" style={{ color: "#CBD5E1" }}>{feed.name}</span>
                      <span className="text-[10px] ml-2 flex-shrink-0 tabular-nums" style={{ color: "#475569" }}>{feed.lastPollMs}ms</span>
                    </div>
                    <ConfidenceBar value={feed.confidence} alert={feed.status === "alert"} />
                  </div>
                  <span className="text-[9px] font-semibold px-1.5 py-0.5 rounded-full flex-shrink-0 uppercase tracking-wide" style={{
                    background: feed.status === "nominal" ? "rgba(0,138,138,0.15)" : "rgba(245,158,11,0.15)",
                    color: feed.status === "nominal" ? "#00BFA6" : "#F59E0B",
                  }}>
                    {feed.status}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Kafka + Zone controls */}
          <div className="flex flex-col gap-4">
            {/* Kafka queue monitor */}
            <div className="rounded-xl border overflow-hidden flex-1" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
              <div className="px-5 py-4 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
                <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>Kafka Queue Monitor</h3>
                <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>Consumer lag across claim processing topics</p>
              </div>
              <div className="px-5 py-4 space-y-5">
                {opsHealth.kafkaQueues.map((q) => (
                  <div key={q.topic}>
                    <div className="flex justify-between items-center mb-2">
                      <span className="text-xs font-mono font-medium" style={{ color: "#94A3B8" }}>{q.topic}</span>
                      <span className="text-[9px] font-semibold px-1.5 py-0.5 rounded-full uppercase tracking-wide" style={{
                        background: q.lag === 0 ? "rgba(34,197,94,0.1)" : q.lag <= 4 ? "rgba(245,158,11,0.15)" : "rgba(239,68,68,0.15)",
                        color:      q.lag === 0 ? "#22C55E"             : q.lag <= 4 ? "#F59E0B"               : "#EF4444",
                      }}>
                        {q.lag === 0 ? "clear" : `lag ${q.lag}`}
                      </span>
                    </div>
                    <LagBar lag={q.lag} />
                  </div>
                ))}
                <div className="text-[10px] pt-2 border-t" style={{ color: "#334155", borderColor: "rgba(51,65,85,0.3)" }}>
                  Lag 0 = all processed · 1–4 = within SLA · 5+ = alert
                </div>
              </div>
            </div>

            {/* Zone controls */}
            <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
              <div className="px-5 py-3.5 border-b" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
                <h3 className="text-xs font-semibold uppercase tracking-widest" style={{ color: "#475569" }}>Zone Controls</h3>
              </div>
              {[
                { zone: "BLR-South",   enrollLock: false, killSwitch: false },
                { zone: "CHN-Central", enrollLock: false, killSwitch: false },
                { zone: "KOL-South",   enrollLock: false, killSwitch: false },
              ].map((z, i, arr) => (
                <div key={z.zone} className="flex items-center justify-between px-5 py-3" style={{
                  borderBottom: i < arr.length - 1 ? "1px solid rgba(51,65,85,0.3)" : "none",
                }}>
                  <span className="text-xs font-medium" style={{ color: "#94A3B8" }}>{z.zone}</span>
                  <div className="flex gap-1.5">
                    <span className="px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase" style={{
                      background: z.enrollLock ? "rgba(245,158,11,0.15)" : "rgba(34,197,94,0.1)",
                      color: z.enrollLock ? "#F59E0B" : "#22C55E",
                    }}>
                      {z.enrollLock ? "locked" : "open"}
                    </span>
                    <span className="px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase" style={{
                      background: z.killSwitch ? "rgba(239,68,68,0.15)" : "rgba(51,65,85,0.3)",
                      color: z.killSwitch ? "#EF4444" : "#475569",
                    }}>
                      KS {z.killSwitch ? "on" : "off"}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ── System event log ────────────────────────────────────────── */}
        <div className="rounded-xl border overflow-hidden" style={{ background: "#1E293B", borderColor: "rgba(51,65,85,0.5)" }}>
          <div className="px-5 py-4 border-b flex items-center justify-between" style={{ borderColor: "rgba(51,65,85,0.5)" }}>
            <div>
              <h3 className="text-sm font-semibold" style={{ color: "#F1F5F9" }}>System Event Log</h3>
              <p className="text-xs mt-0.5" style={{ color: "#64748B" }}>Oracle votes, Kafka consumer events, UPI disbursements</p>
            </div>
            <span className="live-dot w-1.5 h-1.5 rounded-full" style={{ background: "#22C55E" }} />
          </div>
          <div>
            {opsHealth.eventLog.slice(0, 8).map((ev, i) => {
              const { Icon, color } = EVENT_ICONS[ev.type] ?? { Icon: Heart, color: "#94A3B8" };
              return (
                <div key={i} className="px-5 py-3.5 flex items-center gap-3" style={{
                  borderBottom: i < Math.min(7, opsHealth.eventLog.length - 1) ? "1px solid rgba(51,65,85,0.3)" : "none",
                }}>
                  <div className="p-1.5 rounded-lg flex-shrink-0" style={{ background: `${color}15` }}>
                    <Icon className="w-3 h-3" style={{ color }} strokeWidth={2} />
                  </div>
                  <p className="flex-1 text-xs leading-relaxed" style={{ color: "#94A3B8" }}>{ev.msg}</p>
                  <span className="text-[10px] font-mono flex-shrink-0" style={{ color: "#475569" }}>{ev.ts.slice(11)}</span>
                </div>
              );
            })}
          </div>
        </div>

      </div>
    </AdminShell>
  );
}
