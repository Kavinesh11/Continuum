import { AdminShell } from "@/components/admin-shell";
import { getClaims } from "@/lib/backend";

export default async function ClaimsPage() {
  const claimRows = await getClaims();

  return (
    <AdminShell
      title="Claims"
      subtitle="Review latest claims and route exceptions quickly."
    >
      <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
        <h3 className="text-lg font-semibold">Claim Queue</h3>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-teal-100 text-teal-700">
              <tr>
                <th className="py-3 pr-3">Claim ID</th>
                <th className="py-3 pr-3">Partner</th>
                <th className="py-3 pr-3">Zone</th>
                <th className="py-3 pr-3">Trigger</th>
                <th className="py-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {claimRows.map((claim) => (
                <tr key={claim.id} className="border-b border-teal-50">
                  <td className="py-3 pr-3 font-medium">{claim.id}</td>
                  <td className="py-3 pr-3">Worker</td>
                  <td className="py-3 pr-3">{claim.zone}</td>
                  <td className="py-3 pr-3">{claim.title}</td>
                  <td className="py-3">{claim.status}</td>
                </tr>
              ))}
              {claimRows.length === 0 && (
                <tr>
                  <td className="py-3 pr-3 text-teal-700" colSpan={5}>
                    No claims returned from backend. Configure `ADMIN_API_TOKEN` and
                    `ADMIN_WORKER_ID`.
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
