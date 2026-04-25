"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

export default function ClaimsPage() {
  const { claims, approveClaim, rejectClaim, escalateClaim, lockedZones } = useDemo();
  
  const [filterStatus, setFilterStatus] = useState("All");
  const [sortPriority, setSortPriority] = useState("High");
  const [selectedClaimId, setSelectedClaimId] = useState<string | null>(null);

  const statuses = ["All", "Pending", "Escalated", "Approved", "Rejected"];
  const priorities = ["High", "Medium", "Low"];

  let filtered = claims;
  if (filterStatus !== "All") {
    filtered = filtered.filter(c => c.status === filterStatus || (c.status.includes(filterStatus)));
  }

  // Basic priority sort
  filtered = [...filtered].sort((a, b) => {
    const pval = { "High": 3, "Medium": 2, "Low": 1 };
    const pA = pval[a.priority as keyof typeof pval] || 0;
    const pB = pval[b.priority as keyof typeof pval] || 0;
    if (sortPriority === "High") return pB - pA;
    if (sortPriority === "Low") return pA - pB;
    return 0; // if Medium, don't strictly sort by ends
  });

  const selectedClaim = claims.find(c => c.id === selectedClaimId);

  return (
    <AdminShell
      title="Claims Queue"
      subtitle="Review latest claims and route exceptions quickly."
    >
      <div className="flex gap-6 relative">
        <div className={`flex-1 flex flex-col gap-4 ${selectedClaim ? 'w-2/3' : 'w-full'}`}>
          <div className="flex gap-4 items-center bg-white p-4 rounded-xl shadow-sm ring-1 ring-teal-100">
            <span className="text-sm font-semibold text-teal-900">Filter:</span>
            {statuses.map(s => (
              <button 
                key={s} 
                onClick={() => setFilterStatus(s)}
                className={`px-3 py-1 text-sm rounded-full ${filterStatus === s ? 'bg-teal-700 text-white' : 'bg-teal-50 text-teal-700 hover:bg-teal-100'}`}
              >
                {s}
              </button>
            ))}
            
            <div className="ml-auto flex gap-2 items-center">
              <span className="text-sm font-semibold text-teal-900">Sort:</span>
              <select 
                value={sortPriority} 
                onChange={(e) => setSortPriority(e.target.value)}
                className="text-sm bg-teal-50 border-none rounded-lg p-2 text-teal-900 focus:ring-0"
              >
                {priorities.map(p => <option key={p} value={p}>{p} Priority First</option>)}
              </select>
            </div>
          </div>

          <div className="grid gap-3">
            {filtered.map(claim => {
              const isLocked = lockedZones.includes(claim.zone);
              return (
                <div 
                  key={claim.id} 
                  onClick={() => setSelectedClaimId(claim.id)}
                  className={`bg-white p-5 rounded-xl shadow-sm ring-1 cursor-pointer transition-all ${
                    selectedClaimId === claim.id ? 'ring-teal-500 ring-2' : 'ring-teal-100 hover:shadow-md'
                  }`}
                >
                  <div className="flex justify-between items-start mb-2">
                    <div className="flex items-center gap-2">
                      <h4 className="font-semibold text-teal-950">{claim.id}</h4>
                      {claim.fraudScore > 0.7 && <span className="px-1.5 py-0.5 text-[10px] font-bold bg-red-100 text-red-700 rounded">FRAUD</span>}
                      {isLocked && <span className="px-1.5 py-0.5 text-[10px] font-bold bg-amber-100 text-amber-800 rounded">ZONE LOCKED</span>}
                    </div>
                    <span className="text-lg font-semibold text-teal-900">₹{claim.amount}</span>
                  </div>
                  <div className="flex justify-between text-sm text-teal-700">
                    <div>
                      <span className="font-medium text-teal-900">{claim.driver}</span> ({claim.tier}) • {claim.zone}
                    </div>
                    <div>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        claim.status.includes('Approved') ? 'bg-green-100 text-green-700' :
                        claim.status === 'Rejected' ? 'bg-red-100 text-red-700' :
                        claim.status === 'Escalated' ? 'bg-orange-100 text-orange-700' :
                        'bg-teal-50 text-teal-700'
                      }`}>
                        {claim.status}
                      </span>
                    </div>
                  </div>
                  <div className="text-xs text-teal-600 mt-2 flex justify-between">
                    <span>{claim.reason}</span>
                    <span className="opacity-70">Priority: {claim.priority}</span>
                  </div>
                </div>
              );
            })}
            
            {filtered.length === 0 && (
              <div className="p-8 text-center text-teal-600 bg-white rounded-xl shadow-sm ring-1 ring-teal-100">
                No claims match your filters.
              </div>
            )}
          </div>
        </div>

        {selectedClaim && (
          <div className="w-1/3 flex-shrink-0">
            <div className="sticky top-6 bg-white p-6 rounded-2xl shadow-lg ring-1 ring-teal-200">
              <div className="flex justify-between items-start mb-6">
                <h3 className="text-xl font-bold text-teal-950">Claim Details</h3>
                <button 
                  onClick={() => setSelectedClaimId(null)}
                  className="text-teal-400 hover:text-teal-800"
                >
                  ✕
                </button>
              </div>
              
              <div className="space-y-4 text-sm">
                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Driver</span>
                  <div className="font-medium">{selectedClaim.driver} • <span className="text-teal-600">{selectedClaim.tier} Tier</span></div>
                </div>
                
                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Context</span>
                  <div className="font-medium">{selectedClaim.reason} in {selectedClaim.zone}</div>
                  <div className="text-xs mt-1 text-teal-500">Amount requested: ₹{selectedClaim.amount}</div>
                </div>

                <div className="p-3 bg-teal-50 rounded-lg">
                  <span className="text-teal-800 font-semibold block mb-2">Oracle Signals</span>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="flex items-center gap-1">✅ IMD</div>
                    <div className="flex items-center gap-1">✅ AccuWeather</div>
                    <div className="flex items-center gap-1">✅ NASA-GPM</div>
                    <div className="flex items-center gap-1 text-red-500">❌ Windy</div>
                  </div>
                  <div className="mt-2 pt-2 border-t border-teal-100 text-xs italic">
                    3/4 consensus reached
                  </div>
                </div>

                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">GPS Log</span>
                  <div className="text-green-600 text-xs bg-green-50 p-2 rounded">
                    {selectedClaim.reason === "Vehicle Breakdown" 
                      ? <span className="text-red-600">Outside disruption zone radius.</span>
                      : "Driver within disruption zone radius — confirmed"
                    }
                  </div>
                </div>

                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Fraud Score</span>
                  <div className={`p-2 rounded text-xs font-semibold ${selectedClaim.fraudScore > 0.7 ? 'bg-red-100 text-red-800' : 'bg-teal-50 text-teal-800'}`}>
                    {selectedClaim.fraudScore} ({selectedClaim.fraudScore > 0.7 ? 'HIGH RISK' : selectedClaim.fraudScore > 0.3 ? 'MEDIUM RISK' : 'LOW RISK'})
                  </div>
                  {selectedClaim.fraudScore > 0.7 && (
                    <div className="mt-1 text-xs text-red-600">
                      crew-AI analysis: Unusual claim frequency for zone proximity.
                    </div>
                  )}
                </div>

                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Verification</span>
                  <div className="text-xs">
                    &quot;Oracle consensus confirmed. GPS proximity verified. Auto-eligible.&quot;
                  </div>
                </div>
                
                <div>
                  <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">UPI Ref</span>
                  <div className="font-mono text-xs">UPI/040426/CONT847291</div>
                </div>

                {selectedClaim.status === "Pending" && (
                  <div className="pt-4 flex flex-col gap-2">
                    <button 
                      onClick={() => { approveClaim(selectedClaim.id); setSelectedClaimId(null); }}
                      className="w-full py-2 bg-teal-600 text-white font-medium rounded-lg hover:bg-teal-700"
                    >
                      Approve Payout
                    </button>
                    <div className="flex gap-2">
                      <button 
                        onClick={() => {
                          const reason = selectedClaim.reason === "Vehicle Breakdown" ? "GPS proximity log shows worker outside disruption zone." : "Manual rejection.";
                          rejectClaim(selectedClaim.id, reason);
                          setSelectedClaimId(null);
                        }}
                        className="flex-1 py-2 border border-red-200 text-red-700 font-medium rounded-lg hover:bg-red-50"
                      >
                        Reject
                      </button>
                      <button 
                        onClick={() => { escalateClaim(selectedClaim.id); setSelectedClaimId(null); }}
                        className="flex-1 py-2 border border-orange-200 text-orange-700 font-medium rounded-lg hover:bg-orange-50"
                      >
                        Escalate
                      </button>
                    </div>
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
