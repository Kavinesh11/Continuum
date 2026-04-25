"use client";

import { useState } from "react";
import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";
import { EasterEggDetector } from "@/components/easter-egg-detector";

export default function DriversPage() {
  const { drivers, fraudEscalation, zoneEnrollmentLock } = useDemo();
  
  const [searchTerm, setSearchTerm] = useState("");
  const [tierFilter, setTierFilter] = useState("All");
  const [selectedDriverName, setSelectedDriverName] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);

  const tiers = ["All", "Platinum", "Gold", "Silver"];

  let filtered = drivers.filter(d => d.name.toLowerCase().includes(searchTerm.toLowerCase()));
  if (tierFilter !== "All") {
    filtered = filtered.filter(d => d.tier === tierFilter);
  }

  const selectedDriver = drivers.find(d => d.name === selectedDriverName);

  return (
    <AdminShell
      title="Driver Profiles"
      subtitle="Manage partner profiles, analyze risk, and view histories."
    >
      <div className="flex gap-6 relative">
        <div className={`flex-1 flex flex-col gap-4 ${selectedDriver ? 'w-2/3' : 'w-full'}`}>
          <div className="flex gap-4 items-center bg-white p-4 rounded-xl shadow-sm ring-1 ring-teal-100">
            <input 
              type="text" 
              placeholder="Search drivers..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="flex-1 bg-teal-50 border-none rounded-lg p-2 text-sm text-teal-900 focus:ring-1 focus:ring-teal-500"
            />
            
            <div className="flex gap-2 items-center">
              <span className="text-sm font-semibold text-teal-900">Tier:</span>
              <select 
                value={tierFilter} 
                onChange={(e) => setTierFilter(e.target.value)}
                className="text-sm bg-teal-50 border-none rounded-lg p-2 text-teal-900 focus:ring-0"
              >
                {tiers.map(t => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm ring-1 ring-teal-100 overflow-hidden">
            <table className="w-full text-left text-sm">
              <thead className="bg-teal-50 text-teal-700 border-b border-teal-100">
                <tr>
                  <th className="p-4">Name</th>
                  <th className="p-4">Tier</th>
                  <th className="p-4">Zone</th>
                  <th className="p-4">Risk Score</th>
                  <th className="p-4">Total Payout</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(driver => (
                  <tr 
                    key={driver.name} 
                    onClick={() => { setSelectedDriverName(driver.name); setIsEditing(false); }}
                    className={`border-b border-teal-50 cursor-pointer transition-colors ${
                      selectedDriverName === driver.name ? 'bg-teal-50' : 'hover:bg-teal-50/50'
                    }`}
                  >
                    <td className="p-4 font-medium text-teal-900">{driver.name}</td>
                    <td className="p-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        driver.tier === 'Platinum' ? 'bg-slate-200 text-slate-800' :
                        driver.tier === 'Gold' ? 'bg-amber-100 text-amber-800' :
                        'bg-slate-100 text-slate-600'
                      }`}>
                        {driver.tier}
                      </span>
                    </td>
                    <td className="p-4">{driver.zone}</td>
                    <td className="p-4 text-orange-600">{driver.riskScore}</td>
                    <td className="p-4 font-medium">₹{driver.totalPayout.toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filtered.length === 0 && (
              <div className="p-8 text-center text-teal-600">
                No drivers match your search.
              </div>
            )}
          </div>
        </div>

        {selectedDriver && !isEditing && (
          <div className="w-1/3 flex-shrink-0">
            <div className="sticky top-6 bg-white p-6 rounded-2xl shadow-lg ring-1 ring-teal-200">
              <div className="flex justify-between items-start mb-6">
                <h3 className="text-xl font-bold text-teal-950">Driver Profile</h3>
                <div className="flex gap-2">
                  <button onClick={() => setIsEditing(true)} className="text-sm font-medium text-teal-600 hover:text-teal-800">Edit</button>
                  <button onClick={() => setSelectedDriverName(null)} className="text-teal-400 hover:text-teal-800">✕</button>
                </div>
              </div>
              
              <div className="space-y-5 text-sm">
                <div className="flex items-center gap-4 border-b border-teal-50 pb-4">
                  <div className="h-16 w-16 rounded-full bg-teal-100 flex items-center justify-center text-2xl">
                    👤
                  </div>
                  <div>
                    <div className="font-bold text-lg text-teal-900">{selectedDriver.name}</div>
                    <EasterEggDetector taps={4} onTrigger={() => fraudEscalation(selectedDriver.name)}>
                      <div className="inline-block mt-1">
                        <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                          selectedDriver.tier === 'Platinum' ? 'bg-slate-200 text-slate-800' :
                          selectedDriver.tier === 'Gold' ? 'bg-amber-100 text-amber-800' :
                          'bg-slate-100 text-slate-600'
                        }`}>
                          {selectedDriver.tier} Tier
                        </span>
                      </div>
                    </EasterEggDetector>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Zone</span>
                    <EasterEggDetector taps={1} windowMs={1000} onTrigger={() => {
                      // Simulating long press via click wrapper for simplicity, we map 5 taps to long press, wait, user instruction: "Long-press zone label"
                    }}>
                      <div className="font-medium cursor-pointer" onContextMenu={(e) => { e.preventDefault(); zoneEnrollmentLock(selectedDriver.zone); }}>
                        {selectedDriver.zone}
                      </div>
                    </EasterEggDetector>
                  </div>
                  <div>
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Platform</span>
                    <div className="font-medium">{selectedDriver.platform}</div>
                  </div>
                  <div>
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Risk Score</span>
                    <div className="font-bold text-orange-600">{selectedDriver.riskScore}</div>
                  </div>
                  <div>
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Claims Hist</span>
                    <div className="font-medium">{selectedDriver.claims} claims</div>
                  </div>
                  <div className="col-span-2">
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Total Payouts</span>
                    <div className="font-medium text-lg">₹{selectedDriver.totalPayout.toLocaleString()}</div>
                  </div>
                  <div className="col-span-2">
                    <span className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Registered</span>
                    <div className="font-medium text-teal-800">14 Aug 2024</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {selectedDriver && isEditing && (
          <div className="w-1/3 flex-shrink-0">
            <div className="sticky top-6 bg-white p-6 rounded-2xl shadow-lg ring-1 ring-teal-200 border-l-4 border-l-teal-500">
              <div className="flex justify-between items-start mb-6">
                <h3 className="text-xl font-bold text-teal-950">Edit Profile</h3>
              </div>
              
              <div className="space-y-4 text-sm">
                <div>
                  <label className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Phone</label>
                  <input type="text" defaultValue="+91 98765 43210" className="w-full bg-teal-50 border-none rounded p-2 focus:ring-1 focus:ring-teal-500" />
                </div>
                <div>
                  <label className="text-teal-600 block text-xs uppercase tracking-wider mb-1">Zone Override</label>
                  <select defaultValue={selectedDriver.zone} className="w-full bg-teal-50 border-none rounded p-2 focus:ring-1 focus:ring-teal-500">
                    <option value="BLR-South">BLR-South</option>
                    <option value="BLR-North">BLR-North</option>
                    <option value="CHN-Central">CHN-Central</option>
                  </select>
                </div>
                
                <div className="pt-4 flex gap-2">
                  <button onClick={() => { alert("Profile saved."); setIsEditing(false); }} className="flex-1 py-2 bg-teal-600 text-white font-medium rounded hover:bg-teal-700">Save</button>
                  <button onClick={() => setIsEditing(false)} className="flex-1 py-2 bg-slate-200 text-slate-800 font-medium rounded hover:bg-slate-300">Cancel</button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </AdminShell>
  );
}
