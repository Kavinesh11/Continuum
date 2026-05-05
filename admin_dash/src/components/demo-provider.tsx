"use client";

import React, { createContext, useContext, useState, useCallback, useEffect, useRef, ReactNode } from "react";
import {
  initialKpis, initialClaims, initialDrivers, initialAuditLogs,
  initialExecutiveKpis, initialOpsHealth,
  initialGeoFenceIncidents, initialTrustSignalIncidents,
  initialIdentityAnchorIncidents, initialActivityCrossIncidents, initialFairTimeIncidents,
  simulationNotifications, claimTemplates,
  personas, PersonaKey,
} from "@/lib/demo-data";

export type NotificationItem = { id: string; message: string; read: boolean; };
export type BannerAlert = { active: boolean; message: string; type: "red" | "amber" | "orange"; };

type DemoState = {
  // Persona
  activePersona: PersonaKey;
  setPersona: (p: PersonaKey) => void;

  // Core ops state
  kpis: typeof initialKpis;
  claims: typeof initialClaims;
  drivers: typeof initialDrivers;
  auditLogs: typeof initialAuditLogs;
  notifications: NotificationItem[];
  banner: BannerAlert;
  lockedZones: string[];
  killSwitchActive: boolean;

  // Executive + Ops state
  executiveKpis: typeof initialExecutiveKpis;
  opsHealth: typeof initialOpsHealth;

  // Risk Intelligence incident arrays
  geoFenceIncidents: typeof initialGeoFenceIncidents;
  trustSignalIncidents: typeof initialTrustSignalIncidents;
  identityAnchorIncidents: typeof initialIdentityAnchorIncidents;
  activityCrossIncidents: typeof initialActivityCrossIncidents;
  fairTimeIncidents: typeof initialFairTimeIncidents;

  // Easter egg / demo actions
  bulkApproveWave: () => void;
  reserveFloorBreach: () => void;
  fraudFlagging: (driverName?: string) => void;
  zoneEnrollmentLock: (zone: string) => void;
  claimRejectionCascade: () => void;
  payoutAuditTrail: () => void;
  killSwitchTrip: () => void;
  seedDemoNotifications: () => void;
  resetAll: () => void;
  approveClaim: (id: string, message: string) => void;
  rejectClaim: (id: string, reason: string) => void;
  sudarshanRoadblock: () => Promise<void>;

  // Risk Intelligence easter egg actions
  addGeoFenceIncident: () => void;
  addTrustSignalIncident: () => void;
  addIdentityAnchorIncident: () => void;
  addActivityCrossIncident: () => void;
  addFairTimeIncident: () => void;
};

const DemoContext = createContext<DemoState | null>(null);

let claimTemplateIdx = 0;
let notifDripIdx = 0;

export function DemoProvider({ children }: { children: ReactNode }) {
  const [activePersona, setActivePersona] = useState<PersonaKey>("adjuster");
  const [kpis, setKpis] = useState(initialKpis);
  const [claims, setClaims] = useState(initialClaims);
  const [drivers, setDrivers] = useState(initialDrivers);
  const [auditLogs, setAuditLogs] = useState(initialAuditLogs);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [banner, setBanner] = useState<BannerAlert>({ active: false, message: "", type: "red" });
  const [lockedZones, setLockedZones] = useState<string[]>([]);
  const [killSwitchActive, setKillSwitchActive] = useState(false);
  const [executiveKpis, setExecutiveKpis] = useState(initialExecutiveKpis);
  const [opsHealth, setOpsHealth] = useState(initialOpsHealth);
  const [geoFenceIncidents, setGeoFenceIncidents] = useState(initialGeoFenceIncidents);
  const [trustSignalIncidents, setTrustSignalIncidents] = useState(initialTrustSignalIncidents);
  const [identityAnchorIncidents, setIdentityAnchorIncidents] = useState(initialIdentityAnchorIncidents);
  const [activityCrossIncidents, setActivityCrossIncidents] = useState(initialActivityCrossIncidents);
  const [fairTimeIncidents, setFairTimeIncidents] = useState(initialFairTimeIncidents);

  // Keep a stable ref so simulation loops don't close over stale state
  const claimsRef = useRef(claims);
  useEffect(() => { claimsRef.current = claims; }, [claims]);

  // ── Bridge API polling ──────────────────────────────────────────────────────
  useEffect(() => {
    let cancelled = false;
    const poll = async () => {
      try {
        const res = await fetch("/api/claims");
        if (!res.ok || cancelled) return;
        const apiClaims: Array<{
          id: string; driver: string; tier: string; zone: string;
          reason: string; description: string; amount: number;
          status: string; fraudScore: number; priority: string;
          submittedAt: string; isFraud?: boolean; reviewNote?: string;
        }> = await res.json();
        if (cancelled) return;
        setClaims((prev) => {
          const existingIds = new Set(prev.map((c) => c.id));
          const newEntries = apiClaims
            .filter((c) => !existingIds.has(c.id))
            .map((c) => ({
              id: c.id, driver: c.driver, tier: c.tier as "Platinum" | "Gold" | "Silver",
              reason: c.reason, description: c.description, amount: c.amount,
              status: c.status as "Pending" | "Approved" | "Rejected",
              priority: (c.priority ?? "Medium") as "High" | "Medium" | "Low",
              fraudScore: c.fraudScore ?? 0, zone: c.zone,
              justification: c.reviewNote ?? "", submittedAt: c.submittedAt ?? new Date().toISOString(),
              isFraud: c.isFraud ?? false,
            }));
          if (newEntries.length === 0) return prev;
          setKpis((k) => ({ ...k, pendingQueue: k.pendingQueue + newEntries.length }));
          return [...newEntries, ...prev];
        });
      } catch (_) {}
    };
    poll();
    const id = setInterval(poll, 4000);
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  // ── Live simulation engine ──────────────────────────────────────────────────
  useEffect(() => {
    const now = () => {
      const d = new Date();
      return `${d.getHours().toString().padStart(2,"0")}:${d.getMinutes().toString().padStart(2,"0")}`;
    };
    const dateNow = () => {
      const d = new Date();
      return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")} ${now()}`;
    };
    const rand = (lo: number, hi: number) => Math.floor(Math.random() * (hi - lo + 1)) + lo;
    const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

    // Loop 1: Claim generator — new pending claim every 18s
    const claimGenId = setInterval(() => {
      const tpl = claimTemplates[claimTemplateIdx % claimTemplates.length];
      claimTemplateIdx++;
      const suffix = `${Date.now().toString().slice(-4)}-${rand(10, 99)}`;
      const newClaim = {
        id: `CLM-${suffix}`,
        driver: tpl.driver,
        tier: tpl.tier as "Platinum" | "Gold" | "Silver",
        reason: tpl.reason,
        description: `${tpl.reason} reported in ${tpl.zone}. Auto-detected via oracle feed.`,
        amount: tpl.amount,
        status: "Pending" as const,
        priority: "High" as const,
        fraudScore: tpl.fraudScore,
        zone: tpl.zone,
        justification: "",
        submittedAt: dateNow(),
        isFraud: false,
      };
      setClaims((prev) => [newClaim, ...prev]);
      setKpis((k) => ({ ...k, pendingQueue: k.pendingQueue + 1 }));
    }, 18000);

    // Loop 2: Auto-approver — finds oldest low-risk pending, approves it every 12s
    const autoApproveId = setInterval(() => {
      const current = claimsRef.current;
      const eligible = current.find((c) => c.status === "Pending" && c.fraudScore < 0.3);
      if (!eligible) return;
      const claimId = eligible.id;
      const amount = eligible.amount;
      setClaims((prev) =>
        prev.map((c) => c.id === claimId ? { ...c, status: "Auto-Approved" as unknown as "Approved", justification: "Oracle consensus confirmed. GPS verified. Auto-eligible." } : c)
      );
      setKpis((prev) => ({
        ...prev,
        pendingQueue: Math.max(0, prev.pendingQueue - 1),
        approvedToday: prev.approvedToday + 1,
        totalPayoutToday: prev.totalPayoutToday + amount,
      }));
      setAuditLogs((prev) => [
        { timestamp: dateNow(), actor: "System", action: "AUTO-APPROVED", target: claimId, details: `₹${amount}, oracle 3/4 consensus` },
        ...prev,
      ]);
      const upiRef = `UPI/${new Date().toLocaleDateString("en-GB").replace(/\//g,"")}/CONT${rand(100000,999999)}`;
      setNotifications((prev) => [
        { id: Math.random().toString(), message: `[OK] ${claimId} auto-approved — Rs.${amount} → ${upiRef}`, read: false },
        ...prev,
      ]);
    }, 12000);

    // Loop 3: KPI pulse — ticks payouts every 8s
    const kpiId = setInterval(() => {
      const drip = rand(80, 260);
      setKpis((prev) => ({
        ...prev,
        totalPayoutToday: prev.totalPayoutToday + drip,
        avgPayout: Math.round((prev.totalPayoutToday + drip) / Math.max(1, prev.approvedToday)),
      }));
      setExecutiveKpis((prev) => ({
        ...prev,
        totalPayoutMTD: prev.totalPayoutMTD + rand(200, 800),
      }));
    }, 8000);

    // Loop 4: Oracle + ops pulse — nudges confidence, latencies, kafka lag every 22s
    const oracleId = setInterval(() => {
      setOpsHealth((prev) => {
        const oracleFeeds = prev.oracleFeeds.map((f) => ({
          ...f,
          confidence: clamp(+(f.confidence + (Math.random() - 0.5) * 0.06).toFixed(2), 0.4, 0.98),
          lastPollMs: clamp(f.lastPollMs + rand(-40, 40), 20, 1500),
        }));
        const services = prev.services.map((s) => ({
          ...s,
          latencyMs: clamp(s.latencyMs + rand(-30, 30), 12, 2000),
        }));
        // Occasionally drain / increment kafka lag
        const kafkaQueues = prev.kafkaQueues.map((q) => ({
          ...q,
          lag: clamp(q.lag + (Math.random() < 0.3 ? rand(-1, 2) : 0), 0, 8),
        }));
        return { ...prev, oracleFeeds, services, kafkaQueues };
      });
    }, 22000);

    // Loop 5: Notification drip — one contextual notification every 30s
    const notifId = setInterval(() => {
      const msg = simulationNotifications[notifDripIdx % simulationNotifications.length];
      notifDripIdx++;
      setNotifications((prev) => [{ id: Math.random().toString(), message: msg, read: false }, ...prev]);
    }, 30000);

    return () => {
      clearInterval(claimGenId);
      clearInterval(autoApproveId);
      clearInterval(kpiId);
      clearInterval(oracleId);
      clearInterval(notifId);
    };
  }, []);

  // ── Helpers ─────────────────────────────────────────────────────────────────
  const addNotification = useCallback((message: string) => {
    setNotifications((prev) => [{ id: Math.random().toString(), message, read: false }, ...prev]);
  }, []);

  const addAuditLog = useCallback((actor: string, action: string, target: string, details: string) => {
    const d = new Date();
    const ts = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")} ${d.getHours().toString().padStart(2,"0")}:${d.getMinutes().toString().padStart(2,"0")}`;
    setAuditLogs((prev) => [{ timestamp: ts, actor, action, target, details }, ...prev]);
  }, []);

  // ── Persona ──────────────────────────────────────────────────────────────────
  const setPersona = useCallback((p: PersonaKey) => setActivePersona(p), []);

  // ── Easter egg actions ───────────────────────────────────────────────────────
  const bulkApproveWave = useCallback(() => {
    setClaims((prev) =>
      prev.map((c) => c.status === "Pending" && (c.priority === "High" || c.priority === "Medium")
        ? { ...c, status: "Approved" as const } : c)
    );
    setKpis((prev) => ({ ...prev, pendingQueue: 5, approvedToday: prev.approvedToday + 18, totalPayoutToday: prev.totalPayoutToday + 5400 }));
    setBanner({ active: true, message: "Wave approved — ₹5,400 cleared to drivers.", type: "orange" });
    setTimeout(() => setBanner((b) => ({ ...b, active: false })), 5000);
  }, []);

  const reserveFloorBreach = useCallback(() => {
    setKpis((prev) => ({ ...prev, reserveRunwayDays: 31 }));
    setExecutiveKpis((prev) => ({ ...prev, reserveRunwayDays: 31 }));
    setBanner({ active: true, message: "Reserve runway below threshold — autopay paused on new policies.", type: "red" });
    addNotification("[ALERT] Reserve runway 31 days — review autopay.");
  }, [addNotification]);

  const fraudFlagging = useCallback((driverName?: string) => {
    setKpis((prev) => ({ ...prev, fraudFlagged: prev.fraudFlagged + 1 }));
    if (driverName) {
      addNotification(`[FRAUD] ${driverName} flagged — crew-AI isolation-forest score 0.81.`);
      setClaims((prev) => {
        let flagged = false;
        return prev.map((c) => {
          if (!flagged && c.driver === driverName && c.status === "Pending") { flagged = true; return { ...c, fraudScore: 0.81, isFraud: true }; }
          return c;
        });
      });
    } else {
      addNotification("[FRAUD] CLM-9102-54 flagged — crew-AI isolation-forest score 0.71.");
      setClaims((prev) => prev.map((c) => c.id === "CLM-9102-54" ? { ...c, fraudScore: 0.71, isFraud: true } : c));
    }
  }, [addNotification]);

  const zoneEnrollmentLock = useCallback((zone: string) => {
    setLockedZones((prev) => [...prev, zone]);
    setBanner({ active: true, message: `Zone ${zone} temporarily closed for new policies — adverse selection lock active.`, type: "amber" });
  }, []);

  const claimRejectionCascade = useCallback(() => {
    setKpis((prev) => ({ ...prev, rejectedToday: prev.rejectedToday + 2 }));
    addNotification("2 claims auto-rejected — GPS proximity failed.");
    setClaims((prev) => [
      { id: "CLM-9999-01", driver: "Ravi T.",  tier: "Platinum" as const, reason: "Vehicle Breakdown", description: "GPS log mismatch.", amount: 0, status: "Rejected" as const, priority: "Low" as const, fraudScore: 0.55, zone: "BLR-North", justification: "GPS proximity log shows worker outside disruption zone.", submittedAt: new Date().toISOString(), isFraud: false },
      { id: "CLM-9999-02", driver: "Sudha P.", tier: "Silver"   as const, reason: "Outside Zone",       description: "Claim outside active zone.",     amount: 0, status: "Rejected" as const, priority: "Low" as const, fraudScore: 0.60, zone: "KOL-South", justification: "Claim originated outside active zone.",             submittedAt: new Date().toISOString(), isFraud: false },
      ...prev,
    ]);
  }, [addNotification]);

  const payoutAuditTrail = useCallback(() => {}, []);

  const killSwitchTrip = useCallback(() => {
    setKillSwitchActive(true);
    setBanner({ active: true, message: "PAYOUT_KILL_SWITCH active — all payouts paused for safety review.", type: "red" });
  }, []);

  const seedDemoNotifications = useCallback(() => {
    addNotification("[ALERT] Reserve runway 31 days — review autopay.");
    addNotification("[OK] CLM-9824-21 approved — Rs.450 to Sudarshan K.");
    addNotification("[RAIN] Flood advisory — BLR-South zone");
  }, [addNotification]);

  const resetAll = useCallback(() => {
    setActivePersona("adjuster");
    setKpis(initialKpis);
    setClaims(initialClaims);
    setDrivers(initialDrivers);
    setAuditLogs(initialAuditLogs);
    setExecutiveKpis(initialExecutiveKpis);
    setOpsHealth(initialOpsHealth);
    setNotifications([]);
    setBanner({ active: false, message: "", type: "red" });
    setLockedZones([]);
    setKillSwitchActive(false);
    setGeoFenceIncidents(initialGeoFenceIncidents);
    setTrustSignalIncidents(initialTrustSignalIncidents);
    setIdentityAnchorIncidents(initialIdentityAnchorIncidents);
    setActivityCrossIncidents(initialActivityCrossIncidents);
    setFairTimeIncidents(initialFairTimeIncidents);
    claimTemplateIdx = 0;
    notifDripIdx = 0;
  }, []);

  const approveClaim = useCallback(async (id: string, message: string) => {
    setClaims((prev) => prev.map((c) => c.id === id ? { ...c, status: "Approved" as const, justification: message } : c));
    setKpis((prev) => ({ ...prev, pendingQueue: Math.max(0, prev.pendingQueue - 1), approvedToday: prev.approvedToday + 1 }));
    addAuditLog("Preethi Nair", "APPROVED", id, killSwitchActive ? `Payout Queued: ${message}` : `Approved: ${message}`);
    if (!killSwitchActive) addNotification(`[OK] ${id} approved.`);
    try { await fetch(`/api/claims/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "approve", reason: message }) }); } catch (_) {}
  }, [killSwitchActive, addAuditLog, addNotification]);

  const rejectClaim = useCallback(async (id: string, reason: string) => {
    setClaims((prev) => prev.map((c) => c.id === id ? { ...c, status: "Rejected" as const, justification: reason } : c));
    setKpis((prev) => ({ ...prev, pendingQueue: Math.max(0, prev.pendingQueue - 1), rejectedToday: prev.rejectedToday + 1 }));
    addAuditLog("Preethi Nair", "REJECTED", id, reason);
    try { await fetch(`/api/claims/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "reject", reason }) }); } catch (_) {}
  }, [addAuditLog]);

  const sudarshanRoadblock = useCallback(async () => {
    const claimId = "CLM-RBK-9284";
    const newClaim = {
      id: claimId, driver: "Sudarshan K.", tier: "Platinum" as const,
      reason: "Roadblock / Road Closure",
      description: "Road closure near Koramangala 5th Block — police barricade blocking all delivery routes.",
      amount: 0, status: "Pending" as const, priority: "High" as const,
      fraudScore: 0.05, zone: "Bangalore South", justification: "", submittedAt: new Date().toISOString(), isFraud: false,
    };
    setClaims((prev) => { if (prev.some((c) => c.id === claimId)) return prev; return [newClaim, ...prev]; });
    setKpis((prev) => ({ ...prev, pendingQueue: prev.pendingQueue + 1 }));
    addAuditLog("Sudarshan K.", "SUBMITTED", claimId, "Roadblock / Road Closure — manual review required");
    addNotification("[MANUAL] CLM-RBK-9284 — Sudarshan K. filed a roadblock claim (Zone 4B).");
    try { await fetch("/api/claims", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(newClaim) }); } catch (_) {}
    setTimeout(() => { rejectClaim(claimId, "Route outside parametric disruption zone. GPS proximity data shows alternative access routes available."); }, 10_000);
  }, [rejectClaim, addAuditLog, addNotification]);

  // ── Risk Intelligence easter eggs ────────────────────────────────────────────
  const addGeoFenceIncident = useCallback(() => {
    const ts = new Date().toISOString().slice(0, 10);
    setGeoFenceIncidents((prev) => [
      { id: `CLM-${Date.now().toString().slice(-4)}-EG`, driver: "Nithya R.", zone: "BLR-North",
        entryDelta: "6 min before trigger", soakMinutes: 6, outcome: "Blocked",
        detail: `Entry at ${ts}: GPS jump from MG Road to flood zone 6 min pre-trigger. 45-min soak not satisfied.` },
      ...prev,
    ]);
    addNotification("[BLOCKED] GeoFence Integrity™ — new zone-snipe attempt blocked (Nithya R., BLR-North)");
  }, [addNotification]);

  const addTrustSignalIncident = useCallback(() => {
    const ts = new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
    setTrustSignalIncidents((prev) => [
      { id: `ORC-${Date.now().toString().slice(-3)}`, time: `${new Date().toISOString().slice(0,10)} ${ts}`,
        source: "AccuWeather Feed", event: "TLS cert mismatch — possible MITM intercept",
        outcome: "Nullified",
        detail: "Received certificate SHA-256: 7B1E…44 — expected 3A9F…C2. Vote nullified. Benefit-of-doubt protocol engaged (cap 50%)." },
      ...prev,
    ]);
    setBanner({ active: true, message: "TrustSignal™ — AccuWeather TLS mismatch detected. Oracle vote nullified.", type: "amber" });
    setTimeout(() => setBanner((b) => ({ ...b, active: false })), 6000);
    addNotification("[SHIELD] TrustSignal™ — AccuWeather certificate mismatch. Vote counted as OFFLINE.");
  }, [addNotification]);

  const addIdentityAnchorIncident = useCallback(() => {
    const drvId = `DRV-${Date.now().toString().slice(-4)}`;
    setIdentityAnchorIncidents((prev) => [
      { id: drvId, driver: "Kiran P.", event: "SIM swap detected",
        trigger: "New IMSI on enrolled device — flagged within 3-min window",
        outcome: "Payout Frozen",
        detail: "IMSI rotation on device fingerprint SWG-4421. Payout frozen. Re-attestation + OTP required before disbursement." },
      ...prev,
    ]);
    addNotification(`[SHIELD] IdentityAnchor™ — SIM swap blocked for Kiran P. Payout frozen pending re-KYC.`);
  }, [addNotification]);

  const addActivityCrossIncident = useCallback(() => {
    const clmId = `CLM-${Date.now().toString().slice(-4)}-AC`;
    setActivityCrossIncidents((prev) => [
      { id: clmId, driver: "Priya V.", platform: "Zomato", ordersFound: 2,
        claimWindow: "14:00–18:00", outcome: "Vetoed",
        detail: "2 Zomato orders delivered during claimed disruption window (14:15 and 16:40). Platform API veto applied — claim auto-rejected." },
      ...prev,
    ]);
    addNotification(`[VETO] ActivityCross™ — ${clmId} vetoed. Priya V. completed 2 Zomato orders during disruption window.`);
  }, [addNotification]);

  const addFairTimeIncident = useCallback(() => {
    const outId = `OUT-${Date.now().toString().slice(-4)}`;
    setFairTimeIncidents((prev) => [
      { id: outId, zone: "BLR-North", outageWindow: "02:15–04:45", outageHours: 2.5,
        driverActiveHours: 0, overlapHours: 0, benefitPct: 0, outcome: "₹0 paid",
        detail: "3-hour outage at 02:15–04:45. Driver's last active order: 22:55. Zero working-hour overlap → ₹0 benefit paid." },
      ...prev,
    ]);
    addNotification("[FAIRTIME] FairTime™ — off-hours outage (BLR-North, 02:15–04:45). Zero active overlap. Rs.0 disbursed.");
  }, [addNotification]);

  return (
    <DemoContext.Provider value={{
      activePersona, setPersona,
      kpis, claims, drivers, auditLogs, notifications, banner, lockedZones, killSwitchActive,
      executiveKpis, opsHealth,
      geoFenceIncidents, trustSignalIncidents, identityAnchorIncidents, activityCrossIncidents, fairTimeIncidents,
      bulkApproveWave, reserveFloorBreach, fraudFlagging, zoneEnrollmentLock,
      claimRejectionCascade, payoutAuditTrail, killSwitchTrip, seedDemoNotifications, resetAll,
      approveClaim, rejectClaim, sudarshanRoadblock,
      addGeoFenceIncident, addTrustSignalIncident, addIdentityAnchorIncident,
      addActivityCrossIncident, addFairTimeIncident,
    }}>
      {children}
    </DemoContext.Provider>
  );
}

export function useDemo() {
  const context = useContext(DemoContext);
  if (!context) throw new Error("useDemo must be used within a DemoProvider");
  return context;
}
