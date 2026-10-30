"use client";

// ASM1-C4 (migration 0101, ADR-125, `aia` AUT-26): one review act re-bases the care plan on the current assessment;
// no care-plan item is inserted, retired or changed. Offered while the marker, "vor jeder erfassten Bedarfsabklärung" or
// the ASM1-C5 sentence shows, to a registered nurse of the team (the database decides; provisional set, PO 09:15).
// ASM1-C4 (d) (`uxa` UXR-60, PO 12:14): rendered last in the care-plan block, labelled as a command, and asks once
// (UX2-23 confirm-step pattern): "Abbrechen" runs nothing, so no act and no audit row.
// No due date, reminder or colour above `info` (ASM1 negative).

import { useRouter } from "next/navigation";
import { useState } from "react";
import ConfirmStep from "@/app/(protected)/admin/confirm-step";
import { reviewCarePlan } from "@/features/assessment/commands";
import { REVIEW_CONFIRM_ACTION, reviewConfirmSentence, reviewLabel, type AssessmentRecord } from "@/features/assessment/rules";

export default function PlanReviewButton({ caseId, current }: { caseId: string; current: AssessmentRecord }) {
  const router = useRouter();
  const [asking, setAsking] = useState(false);
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
    setAsking(false);
    router.refresh();
  }

  return (
    <div data-testid="plan-review-command" className="mt-1 grid gap-1">
      {asking ? (
        <ConfirmStep
          sentence={reviewConfirmSentence(current)}
          actionLabel={REVIEW_CONFIRM_ACTION}
          pending={pending}
          onConfirm={review}
          onCancel={() => setAsking(false)}
          testId="plan-review-confirm"
        />
      ) : (
        <button
          type="button"
          onClick={() => setAsking(true)}
          className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-left text-xs font-semibold"
        >
          {reviewLabel(current)}
        </button>
      )}
      <p className="text-xs text-secondary">Leistungen, die nicht mehr passen, änderst du wie bisher einzeln.</p>
      {error && (
        <p role="alert" data-testid="plan-review-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 text-xs font-semibold text-rose-800">
          {error}
        </p>
      )}
    </div>
  );
}
