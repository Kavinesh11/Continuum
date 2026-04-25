import { AdminShell } from "@/components/admin-shell";
import { getClaims } from "@/lib/backend";

function classifyPriority(status: string): string {
  const normalized = status.toLowerCase();
  if (normalized.includes("rejected")) return "Critical";
  if (normalized.includes("review")) return "High";
  return "Medium";
}

export default async function FraudReviewPage() {
  const claims = await getClaims();
  const fraudCases = claims
    .filter((claim) => claim.status !== "Approved")
    .slice(0, 10)
    .map((claim) => ({
      caseId: `FRD-${claim.id}`,
      claimId: claim.id,
      reason: `Flagged due to status: ${claim.status}`,
      priority: classifyPriority(claim.status),
    }));

  return (
    <AdminShell
      title="Fraud Review"
      subtitle="Investigate flagged claims and close high-risk events quickly."
    >
      <section className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-teal-100">
        <h3 className="text-lg font-semibold">Fraud Escalation Queue</h3>
        <ul className="mt-4 space-y-3">
          {fraudCases.map((item) => (
            <li
              key={item.caseId}
              className="rounded-xl border border-teal-100 bg-teal-50 p-4 text-sm text-teal-900"
            >
              <p className="font-semibold">
                {item.caseId} - {item.claimId}
              </p>
              <p className="mt-1">Reason: {item.reason}</p>
              <p className="mt-1 text-teal-700">Priority: {item.priority}</p>
            </li>
          ))}
          {fraudCases.length === 0 && (
            <li className="rounded-xl border border-teal-100 bg-teal-50 p-4 text-sm text-teal-900">
              No flagged cases from backend claim stream.
            </li>
          )}
        </ul>
      </section>
    </AdminShell>
  );
}
