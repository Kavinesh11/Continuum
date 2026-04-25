import { AdminShell } from "@/components/admin-shell";
import { getClaims, getPayouts, getCoreHealth, hasBackendCredentials } from "@/lib/backend";

export default async function Home() {
  const [claims, payouts, coreHealth] = await Promise.all([
    getClaims(),
    getPayouts(),
    getCoreHealth(),
  ]);

  const kpis = [
    { label: "Claims Loaded", value: String(claims.length), trend: "Live from backend" },
    { label: "Payout Records", value: String(payouts.length), trend: "Live from backend" },
    {
      label: "Core Backend",
      value: coreHealth.ok ? "Connected" : "Unavailable",
      trend: coreHealth.url,
    },
    {
      label: "Credentials",
      value: hasBackendCredentials() ? "Configured" : "Missing",
      trend: "Set ADMIN_API_TOKEN + ADMIN_WORKER_ID",
    },
  ];

  return (
    <AdminShell
      title="Admin Dashboard"
      subtitle="Monitor claims, payouts, and zone risk in real time."
    >
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {kpis.map((item) => (
              <article
                key={item.label}
                className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100"
              >
                <p className="text-sm text-teal-700">{item.label}</p>
                <p className="mt-2 text-2xl font-semibold">{item.value}</p>
                <p className="mt-2 text-sm text-teal-600">{item.trend} from yesterday</p>
              </article>
            ))}
      </section>

      <section className="grid gap-6 lg:grid-cols-3">
            <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100 lg:col-span-2">
              <h3 className="text-lg font-semibold">Recent Claims</h3>
              <div className="mt-4 overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-teal-100 text-teal-700">
                    <tr>
                      <th className="py-3 pr-3">Claim ID</th>
                      <th className="py-3 pr-3">Partner</th>
                      <th className="py-3 pr-3">Zone</th>
                      <th className="py-3 pr-3">Status</th>
                      <th className="py-3">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {claims.slice(0, 8).map((claim) => (
                      <tr key={claim.id} className="border-b border-teal-50">
                        <td className="py-3 pr-3 font-medium">{claim.id}</td>
                        <td className="py-3 pr-3">Worker</td>
                        <td className="py-3 pr-3">{claim.zone}</td>
                        <td className="py-3 pr-3">{claim.status}</td>
                        <td className="py-3">INR {claim.amount.toFixed(2)}</td>
                      </tr>
                    ))}
                    {claims.length === 0 && (
                      <tr>
                        <td className="py-3 pr-3 text-teal-700" colSpan={5}>
                          No live claims available. Check API token/worker id configuration.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
              <h3 className="text-lg font-semibold">System Activity</h3>
              <ul className="mt-4 space-y-3 text-sm text-teal-800">
                <li className="rounded-lg bg-teal-50 p-3">
                  Oracle consensus reached for Mumbai-East weather trigger.
                </li>
                <li className="rounded-lg bg-teal-50 p-3">
                  Enrollment lock enabled in Mumbai-North for 72h forecast risk.
                </li>
                <li className="rounded-lg bg-teal-50 p-3">
                  Fraud escalation queue processed 18 cases in the last hour.
                </li>
              </ul>
            </div>
      </section>
    </AdminShell>
  );
}
