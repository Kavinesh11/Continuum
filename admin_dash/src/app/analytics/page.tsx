"use client";

import { AdminShell } from "@/components/admin-shell";
import { useDemo } from "@/components/demo-provider";

export default function AnalyticsPage() {
  const { kpis } = useDemo();

  return (
    <AdminShell
      title="Analytics & Trends"
      subtitle="View payout volumes, claim types, and zone heatmaps."
    >
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold mb-4">Weekly Claim Trend</h3>
          <div className="h-64 flex items-end justify-between gap-2 px-2 pb-6 border-b border-l border-teal-100 relative">
            {/* Simple mock chart */}
            {[12, 18, 9, 22, 31, 14, 7].map((val, i) => (
              <div key={i} className="flex flex-col items-center flex-1 group">
                <div 
                  className="w-full bg-teal-200 rounded-t-sm group-hover:bg-teal-400 transition-colors relative"
                  style={{ height: `${(val / 35) * 100}%` }}
                >
                  <span className="absolute -top-6 left-1/2 -translate-x-1/2 text-xs font-semibold text-teal-700 opacity-0 group-hover:opacity-100">{val}</span>
                </div>
                <span className="text-xs text-teal-600 mt-2">
                  {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold mb-4">Payout Volume</h3>
          <div className="h-64 flex items-end justify-between gap-2 px-2 pb-6 border-b border-l border-teal-100 relative">
            {[3240, 5100, 2880, 6440, 8990, 4200, 1960 + (kpis.approvedToday > 41 ? 5400 : 0)].map((val, i) => (
              <div key={i} className="flex flex-col items-center flex-1 group">
                <div 
                  className="w-full bg-teal-600 rounded-t-sm group-hover:bg-teal-700 transition-colors relative"
                  style={{ height: `${(val / 15000) * 100}%` }}
                >
                  <span className="absolute -top-6 left-1/2 -translate-x-1/2 text-xs font-semibold text-teal-700 opacity-0 group-hover:opacity-100">₹{val}</span>
                </div>
                <span className="text-xs text-teal-600 mt-2">
                  {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold mb-4">Claim Type Breakdown</h3>
          <div className="flex items-center gap-6">
            <div className="w-32 h-32 rounded-full border-[16px] border-t-teal-600 border-r-teal-400 border-b-teal-200 border-l-teal-100 flex items-center justify-center">
              {/* Mock pie chart visually using borders */}
            </div>
            <div className="space-y-3 flex-1 text-sm">
              <div className="flex justify-between items-center"><div className="flex items-center gap-2"><div className="w-3 h-3 bg-teal-600 rounded-full"></div>Weather</div><span className="font-medium">48%</span></div>
              <div className="flex justify-between items-center"><div className="flex items-center gap-2"><div className="w-3 h-3 bg-teal-400 rounded-full"></div>Platform Outage</div><span className="font-medium">22%</span></div>
              <div className="flex justify-between items-center"><div className="flex items-center gap-2"><div className="w-3 h-3 bg-teal-200 rounded-full"></div>Network</div><span className="font-medium">16%</span></div>
              <div className="flex justify-between items-center"><div className="flex items-center gap-2"><div className="w-3 h-3 bg-teal-100 rounded-full"></div>Other</div><span className="font-medium">14%</span></div>
            </div>
          </div>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold mb-4">Zone Heatmap</h3>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-sm mb-1"><span>BLR-South</span><span className="font-semibold text-red-600">HIGH</span></div>
              <div className="w-full bg-teal-50 h-3 rounded-full overflow-hidden"><div className="bg-red-500 h-full w-4/5"></div></div>
            </div>
            <div>
              <div className="flex justify-between text-sm mb-1"><span>BLR-North</span><span className="font-semibold text-orange-500">MEDIUM</span></div>
              <div className="w-full bg-teal-50 h-3 rounded-full overflow-hidden"><div className="bg-orange-400 h-full w-1/2"></div></div>
            </div>
            <div>
              <div className="flex justify-between text-sm mb-1"><span>CHN-Central</span><span className="font-semibold text-teal-600">LOW</span></div>
              <div className="w-full bg-teal-50 h-3 rounded-full overflow-hidden"><div className="bg-teal-400 h-full w-1/4"></div></div>
            </div>
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
