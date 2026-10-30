"use client";

// ASM1-C4 (migration 0101, ADR-125, `aia` AUT-26): one review act re-bases the care plan on the current assessment;
// no care-plan item is inserted, retired or changed. Offered while the marker, "vor jeder erfassten Bedarfsabklärung" or
// the ASM1-C5 sentence shows, to a registered nurse of the team (the database decides; provisional set, PO 09:15).
// No due date, reminder or colour above `info` (ASM1 negative).

import { useRouter } from "next/navigation";
import { useState } from "react";
import { reviewCarePlan } from "@/features/assessment/commands";
import { reviewLabel, type AssessmentRecord } from "@/features/assessment/rules";

export default function PlanReviewButton({ caseId, current }: { caseId: string; current: AssessmentRecord }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function review() {
    setPending(true);
    setError(null);
    const result = await reviewCarePlan({ caseId, recordId: current.id, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    router.refresh();
  }

  return (
    <div>
      <button
        type="button"
        disabled={pending}
        onClick={review}
        className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-left text-xs font-semibold disabled:opacity-60"
      >
        {reviewLabel(current)}
      </button>
      <p className="mt-1 text-xs text-secondary">Leistungen, die nicht mehr passen, änderst du wie bisher einzeln.</p>
      {error && (
        <p role="alert" data-testid="plan-review-error" className="mt-1 rounded-lg border border-rose-300 bg-rose-50 p-2 text-xs font-semibold text-rose-800">
          {error}
        </p>
      )}
    </div>
  );
}
