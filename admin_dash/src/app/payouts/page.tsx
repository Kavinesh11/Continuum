import { AdminShell } from "@/components/admin-shell";
import { getPayouts } from "@/lib/backend";

export default async function PayoutsPage() {
  const payoutRows = await getPayouts();
  const disbursed = payoutRows.filter((row) => row.status === "disbursed").length;
  const inQueue = payoutRows.filter((row) => row.status === "pending").length;
  const atRisk = payoutRows.filter((row) => row.status !== "disbursed").length;

  return (
    <AdminShell
      title="Payouts"
      subtitle="Track disbursement execution and payout pipeline health."
    >
      <section className="grid gap-4 sm:grid-cols-3">
        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">Successful Today</p>
          <p className="mt-2 text-2xl font-semibold">{disbursed}</p>
        </article>
        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">In Queue</p>
          <p className="mt-2 text-2xl font-semibold">{inQueue}</p>
        </article>
        <article className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-teal-100">
          <p className="text-sm text-teal-700">SLA Breach Risk</p>
          <p className="mt-2 text-2xl font-semibold">{atRisk}</p>
        </article>
      </section>

      <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
        <h3 className="text-lg font-semibold">Recent Payout Jobs</h3>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-teal-100 text-teal-700">
              <tr>
                <th className="py-3 pr-3">Payout ID</th>
                <th className="py-3 pr-3">Claim ID</th>
                <th className="py-3 pr-3">Amount</th>
                <th className="py-3">State</th>
              </tr>
            </thead>
            <tbody>
              {payoutRows.map((row) => (
                <tr key={row.payoutId} className="border-b border-teal-50">
                  <td className="py-3 pr-3 font-medium">{row.payoutId}</td>
                  <td className="py-3 pr-3">{row.claimId}</td>
                  <td className="py-3 pr-3">INR {row.amount.toFixed(2)}</td>
                  <td className="py-3">{row.status}</td>
                </tr>
              ))}
              {payoutRows.length === 0 && (
                <tr>
                  <td className="py-3 pr-3 text-teal-700" colSpan={4}>
                    No payouts returned from backend. Use a valid worker token in `ADMIN_API_TOKEN`.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </AdminShell>
  );
}
