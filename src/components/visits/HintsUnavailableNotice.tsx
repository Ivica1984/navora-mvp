import { VISIT_ALERTS_UNAVAILABLE_NOTICE } from "@/features/team/aux-list";

// PERF1 (CGR-272): one visible line in place of the visit hint list while it cannot be loaded; sits where the list
// would be and above the visit cards. `role="status"`: announced once, never steals focus. Wording and placement are
// for the `uxa` gate; `cra` checks that a carer is never left without hints silently.
export default function HintsUnavailableNotice() {
  return (
    <p role="status" data-testid="visit-alerts-unavailable" data-tone="warning"
      className="mb-4 rounded-xl border border-amber-600 bg-amber-50 p-3 text-sm font-semibold text-amber-900">
      {VISIT_ALERTS_UNAVAILABLE_NOTICE}
    </p>
  );
}
