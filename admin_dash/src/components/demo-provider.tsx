"use client";

import React, { createContext, useContext, useState, useCallback, useEffect, ReactNode } from "react";
import { initialKpis, initialClaims, initialDrivers, initialAuditLogs } from "@/lib/demo-data";

export type NotificationItem = {
  id: string;
  message: string;
  read: boolean;
};

export type BannerAlert = {
  active: boolean;
  message: string;
  type: "red" | "amber" | "orange";
};

type DemoState = {
  kpis: typeof initialKpis;
  claims: typeof initialClaims;
  drivers: typeof initialDrivers;
  auditLogs: typeof initialAuditLogs;
  notifications: NotificationItem[];
  banner: BannerAlert;
  lockedZones: string[];
  killSwitchActive: boolean;
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
};

const DemoContext = createContext<DemoState | null>(null);

export function DemoProvider({ children }: { children: ReactNode }) {
  const [kpis, setKpis] = useState(initialKpis);
  const [claims, setClaims] = useState(initialClaims);
  const [drivers, setDrivers] = useState(initialDrivers);
  const [auditLogs, setAuditLogs] = useState(initialAuditLogs);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [banner, setBanner] = useState<BannerAlert>({ active: false, message: "", type: "red" });
  const [lockedZones, setLockedZones] = useState<string[]>([]);
  const [killSwitchActive, setKillSwitchActive] = useState(false);

  // Poll the bridge API and merge any new Flutter-submitted claims into the local state
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
              id: c.id,
              driver: c.driver,
              tier: c.tier as "Platinum" | "Gold" | "Silver",
              reason: c.reason,
              description: c.description,
              amount: c.amount,
              status: c.status as "Pending" | "Approved" | "Rejected",
              priority: (c.priority ?? "Medium") as "High" | "Medium" | "Low",
              fraudScore: c.fraudScore ?? 0,
              zone: c.zone,
              justification: c.reviewNote ?? "",
              submittedAt: c.submittedAt ?? new Date().toISOString(),
              isFraud: c.isFraud ?? false,
            }));
          if (newEntries.length === 0) return prev;
          setKpis((k) => ({ ...k, pendingQueue: k.pendingQueue + newEntries.length }));
          return [...newEntries, ...prev];
        });
      } catch (_) {
        // Bridge API not running — pure local mode, no-op
      }
    };

    poll();
    const interval = setInterval(poll, 4000);
    return () => { cancelled = true; clearInterval(interval); };
  }, []);

  const addNotification = useCallback((message: string) => {
    setNotifications((prev) => [{ id: Math.random().toString(), message, read: false }, ...prev]);
  }, []);

  const addAuditLog = useCallback((actor: string, action: string, target: string, details: string) => {
    setAuditLogs((prev) => [
      { timestamp: new Date().toISOString().slice(0, 16).replace("T", " "), actor, action, target, details },
      ...prev,
    ]);
  }, []);

  const bulkApproveWave = useCallback(() => {
    setClaims((prev) =>
      prev.map((c) =>
        c.status === "Pending" && (c.priority === "High" || c.priority === "Medium")
          ? { ...c, status: "Approved" as const }
          : c
      )
    );
    setKpis((prev) => ({
      ...prev,
      pendingQueue: 5,
      approvedToday: prev.approvedToday + 18,
      totalPayoutToday: prev.totalPayoutToday + 5400,
    }));
    setBanner({ active: true, message: "Wave approved — ₹5,400 cleared to drivers.", type: "orange" });
    setTimeout(() => setBanner((b) => ({ ...b, active: false })), 5000);
  }, []);

  const reserveFloorBreach = useCallback(() => {
    setKpis((prev) => ({ ...prev, reserveRunwayDays: 31 }));
    setBanner({ active: true, message: "⚠ Reserve runway below threshold — autopay paused on new policies.", type: "red" });
    addNotification("⚠ Reserve runway 31 days — review autopay.");
  }, [addNotification]);

  const fraudFlagging = useCallback((driverName?: string) => {
    setKpis((prev) => ({ ...prev, fraudFlagged: prev.fraudFlagged + 1 }));
    if (driverName) {
      addNotification(`⚠ ${driverName} flagged — crew-AI isolation-forest score 0.81.`);
      setClaims((prev) => {
        let flagged = false;
        return prev.map((c) => {
          if (!flagged && c.driver === driverName && c.status === "Pending") {
            flagged = true;
            return { ...c, fraudScore: 0.81, isFraud: true };
          }
          return c;
        });
      });
    } else {
      addNotification("⚠ CLM-9102-54 flagged — crew-AI isolation-forest score 0.71.");
      setClaims((prev) =>
        prev.map((c) => (c.id === "CLM-9102-54" ? { ...c, fraudScore: 0.71, isFraud: true } : c))
      );
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
      { id: "CLM-9999-01", driver: "Ravi T.", tier: "Platinum" as const, reason: "Vehicle Breakdown", description: "GPS log mismatch.", amount: 0, status: "Rejected" as const, priority: "Low" as const, fraudScore: 0.55, zone: "BLR-North", justification: "GPS proximity log shows worker outside disruption zone.", submittedAt: new Date().toISOString(), isFraud: false },
      { id: "CLM-9999-02", driver: "Sudha P.", tier: "Silver" as const, reason: "Outside Zone", description: "Claim originated outside active zone.", amount: 0, status: "Rejected" as const, priority: "Low" as const, fraudScore: 0.60, zone: "KOL-South", justification: "Claim originated outside active zone.", submittedAt: new Date().toISOString(), isFraud: false },
      ...prev,
    ]);
  }, [addNotification]);

  const payoutAuditTrail = useCallback(() => {
    // Handled locally in page.tsx as bottom sheet overlay
  }, []);

  const killSwitchTrip = useCallback(() => {
    setKillSwitchActive(true);
    setBanner({ active: true, message: "PAYOUT_KILL_SWITCH active — all payouts paused for safety review.", type: "red" });
  }, []);

  const seedDemoNotifications = useCallback(() => {
    addNotification("⚠ Reserve runway 31 days — review autopay.");
    addNotification("✅ CLM-9824-21 approved — ₹450 to Sudarshan K.");
    addNotification("🌧 Flood advisory — BLR-South zone");
  }, [addNotification]);

  const resetAll = useCallback(() => {
    setKpis(initialKpis);
    setClaims(initialClaims);
    setDrivers(initialDrivers);
    setAuditLogs(initialAuditLogs);
    setNotifications([]);
    setBanner({ active: false, message: "", type: "red" });
    setLockedZones([]);
    setKillSwitchActive(false);
  }, []);

  const approveClaim = useCallback(async (id: string, message: string) => {
    // Update local state immediately
    setClaims((prev) =>
      prev.map((c) =>
        c.id === id
          ? { ...c, status: (killSwitchActive ? "Approved" : "Approved") as const, justification: message }
          : c
      )
    );
    setKpis((prev) => ({
      ...prev,
      pendingQueue: Math.max(0, prev.pendingQueue - 1),
      approvedToday: prev.approvedToday + 1,
    }));
    addAuditLog("Preethi Nair", "APPROVED", id, killSwitchActive ? `Payout Queued: ${message}` : `Approved: ${message}`);
    if (!killSwitchActive) addNotification(`✅ ${id} approved.`);

    // Persist to bridge API so Flutter app picks it up
    try {
      await fetch(`/api/claims/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "approve", reason: message }),
      });
    } catch (_) {}
  }, [killSwitchActive, addAuditLog, addNotification]);

  const rejectClaim = useCallback(async (id: string, reason: string) => {
    setClaims((prev) =>
      prev.map((c) => (c.id === id ? { ...c, status: "Rejected" as const, justification: reason } : c))
    );
    setKpis((prev) => ({
      ...prev,
      pendingQueue: Math.max(0, prev.pendingQueue - 1),
      rejectedToday: prev.rejectedToday + 1,
    }));
    addAuditLog("Preethi Nair", "REJECTED", id, reason);

    try {
      await fetch(`/api/claims/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "reject", reason }),
      });
    } catch (_) {}
  }, [addAuditLog]);

  return (
    <DemoContext.Provider
      value={{
        kpis,
        claims,
        drivers,
        auditLogs,
        notifications,
        banner,
        lockedZones,
        killSwitchActive,
        bulkApproveWave,
        reserveFloorBreach,
        fraudFlagging,
        zoneEnrollmentLock,
        claimRejectionCascade,
        payoutAuditTrail,
        killSwitchTrip,
        seedDemoNotifications,
        resetAll,
        approveClaim,
        rejectClaim,
      }}
    >
      {children}
    </DemoContext.Provider>
  );
}

export function useDemo() {
  const context = useContext(DemoContext);
  if (!context) throw new Error("useDemo must be used within a DemoProvider");
  return context;
}
