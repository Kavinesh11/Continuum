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
    fraudEscalation, 
    claimRejectionCascade 
  } = useDemo();

  const [showAuditOverlay, setShowAuditOverlay] = useState(false);

  const payoutAuditTrail = () => {
    setShowAuditOverlay(true);
  };

  return (
    <AdminShell
      title="Admin Dashboard"
      subtitle="Monitor claims, payouts, and zone risk in real time."
    >
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <EasterEggDetector taps={4} onTrigger={bulkApproveWave}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors">
            <p className="text-sm text-teal-700">Pending Queue</p>
            <p className="mt-2 text-2xl font-semibold">{kpis.pendingQueue}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={4} onTrigger={payoutAuditTrail}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors">
            <p className="text-sm text-teal-700">Approved Today</p>
            <p className="mt-2 text-2xl font-semibold text-green-600">{kpis.approvedToday}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={3} onTrigger={claimRejectionCascade}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors">
            <p className="text-sm text-teal-700">Rejected Today</p>
            <p className="mt-2 text-2xl font-semibold text-red-600">{kpis.rejectedToday}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={3} onTrigger={() => fraudEscalation()}>
          <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100 hover:bg-teal-50 transition-colors">
            <p className="text-sm text-teal-700">Fraud Escalated</p>
            <p className="mt-2 text-2xl font-semibold text-orange-500">{kpis.fraudEscalated}</p>
          </article>
        </EasterEggDetector>

        <EasterEggDetector taps={4} onTrigger={reserveFloorBreach}>
          <article className={`rounded-2xl p-5 shadow-sm ring-1 transition-colors ${kpis.reserveRunwayDays < 60 ? 'bg-red-50 ring-red-200 text-red-900' : 'bg-white ring-teal-100 hover:bg-teal-50'}`}>
            <p className={`text-sm ${kpis.reserveRunwayDays < 60 ? 'text-red-700' : 'text-teal-700'}`}>Reserve Runway</p>
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
                {claims.slice(0, 8).map((claim) => (
                  <tr key={claim.id} className="border-b border-teal-50">
                    <td className="py-3 pr-3 font-medium flex items-center gap-2">
                      {claim.id}
                      {claim.fraudScore > 0.7 && (
                        <span className="px-1.5 py-0.5 text-[10px] font-bold bg-red-100 text-red-700 rounded">FRAUD</span>
                      )}
                    </td>
                    <td className="py-3 pr-3">{claim.driver}</td>
                    <td className="py-3 pr-3">{claim.zone}</td>
                    <td className="py-3 pr-3">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        claim.status === 'Approved' ? 'bg-green-100 text-green-700' :
                        claim.status === 'Rejected' ? 'bg-red-100 text-red-700' :
                        claim.status === 'Escalated' ? 'bg-orange-100 text-orange-700' :
                        claim.status.includes('Queued') ? 'bg-amber-100 text-amber-700' :
                        'bg-gray-100 text-gray-700'
                      }`}>
                        {claim.status}
                      </span>
                    </td>
                    <td className="py-3">₹{claim.amount}</td>
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
                <div><span className="font-semibold">{log.action}</span> {log.target}</div>
                <div className="text-xs text-teal-700 mt-1 opacity-80">{log.details}</div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {showAuditOverlay && (
        <div className="fixed inset-0 bg-black/40 flex items-end justify-center z-50 animate-in fade-in" onClick={() => setShowAuditOverlay(false)}>
          <div 
            className="bg-white w-full max-w-3xl rounded-t-3xl p-6 shadow-2xl animate-in slide-in-from-bottom"
            onClick={e => e.stopPropagation()}
          >
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-bold text-teal-950">Payout Audit Trail</h2>
              <button onClick={() => setShowAuditOverlay(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            
            <div className="space-y-3">
              {auditLogs.filter(l => l.action.includes('APPROVE') || l.details.includes('₹')).slice(0, 5).map((log, i) => (
                <div key={i} className="flex justify-between items-center p-4 rounded-xl bg-teal-50 ring-1 ring-teal-100">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-teal-900">{log.target}</span>
                      <span className="px-2 py-0.5 bg-green-100 text-green-700 text-[10px] font-bold rounded">{log.action}</span>
                    </div>
                    <div className="text-sm text-teal-700 mt-1">{log.details}</div>
                    <div className="text-xs text-teal-500 mt-1">{log.timestamp} • by {log.actor}</div>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="font-mono text-xs text-slate-500 bg-white px-2 py-1 rounded ring-1 ring-slate-200 select-all">
                      UPI/{log.timestamp.replace(/[- :]/g, '').slice(2, 8)}/CONT{10000 + (i * 12345 % 90000)}
                    </div>
                    <button className="text-teal-600 hover:text-teal-800" title="Copy UPI Ref">
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
                    </button>
                  </div>
                </div>
              ))}
            </div>
            
            <div className="mt-6 text-center">
              <button onClick={() => setShowAuditOverlay(false)} className="px-6 py-2 bg-slate-100 text-slate-700 font-medium rounded-lg hover:bg-slate-200">
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminShell>
  );
}
