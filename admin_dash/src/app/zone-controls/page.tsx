import { AdminShell } from "@/components/admin-shell";
import { getCoreHealth } from "@/lib/backend";

const zones = [
  { name: "Mumbai-North", lockState: "Enabled", killSwitch: "Off", risk: "High" },
  { name: "Mumbai-East", lockState: "Disabled", killSwitch: "Off", risk: "Medium" },
  { name: "Mumbai-Central", lockState: "Enabled", killSwitch: "On", risk: "Critical" },
];

export default async function ZoneControlsPage() {
  const health = await getCoreHealth();

  return (
    <AdminShell
      title="Zone Controls"
      subtitle="Manage enrollment locks, kill switches, and zone risk visibility."
    >
      <section className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold">Zone Control Matrix</h3>
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-teal-100 text-teal-700">
                <tr>
                  <th className="py-3 pr-3">Zone</th>
                  <th className="py-3 pr-3">Enrollment Lock</th>
                  <th className="py-3 pr-3">Kill Switch</th>
                  <th className="py-3">Risk</th>
                </tr>
              </thead>
              <tbody>
                {zones.map((zone) => (
                  <tr key={zone.name} className="border-b border-teal-50">
                    <td className="py-3 pr-3 font-medium">{zone.name}</td>
                    <td className="py-3 pr-3">{zone.lockState}</td>
                    <td className="py-3 pr-3">{zone.killSwitch}</td>
                    <td className="py-3">{zone.risk}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
          <h3 className="text-lg font-semibold">Zone Map</h3>
          <p className="mt-1 text-sm text-teal-700">
            Embedded map view for quick zone-level inspection. Backend status:{" "}
            {health.ok ? "connected" : "unreachable"}.
          </p>
          <div className="mt-4 overflow-hidden rounded-xl border border-teal-100">
            <iframe
              title="Mumbai Zones Map"
              src="https://www.openstreetmap.org/export/embed.html?bbox=72.77%2C18.87%2C72.99%2C19.18&layer=mapnik"
              className="h-80 w-full"
              loading="lazy"
              referrerPolicy="no-referrer-when-downgrade"
            />
          </div>
        </div>
      </section>
    </AdminShell>
  );
}
