// ASM1-7 and ASM1-11 (migration 0100, ADR-123): on the care plan, the assessment it rests on, the marker and the assessed
// minutes beside the items as written. Imports only the pure rules, so tests/unit/asm1-assessment.test.ts renders it.

import type { ReactNode } from "react";
import {
  assessmentLine,
  categoryRows,
  correctedBasisText,
  currentRecord,
  newerAssessmentText,
  newerEventText,
  planBasisText,
  planReviewText,
  type CaseAssessments,
  type PlanItemAsWritten,
} from "@/features/assessment/rules";

/**
 * ASM1-7 and ASM1-11 on the care plan: the assessment the plan rests on, "Neuere Bedarfsabklärung vom <Datum>", and per
 * category the current assessment's minutes with their period beside the plan's items of that category as written.
 * No total, sum, average, difference, conversion, colour, icon or warning: the same neutral classes whatever the numbers.
 */
export default function PlanAssessmentBasis({
  view,
  items,
  reviewAction = null,
}: {
  view: CaseAssessments | null;
  items: PlanItemAsWritten[];
  /** ASM1-C4: the "geprüft" command (a client component), passed in by the team view so this file stays pure. */
  reviewAction?: ReactNode;
}) {
  const current = currentRecord(view);
  const basis = planBasisText(view);
  const marker = newerAssessmentText(view);
  // ASM1-C5 (CGR-102): stays here, outside the closed history of the assessment block (ASM1-C2).
  const corrected = correctedBasisText(view);
  const reviewed = planReviewText(view?.plan_review);
  if (!current && !basis) return null;
  return (
    <div data-testid="plan-assessment" data-ref="ASM1-11" className="mt-2 grid gap-1 rounded-lg border border-stone-200 bg-white p-2 text-xs">
      {basis && <p data-testid="plan-basis">{basis}</p>}
      {marker && (
        <p data-testid="plan-newer-assessment" className="font-semibold">
          {marker}
        </p>
      )}
      {corrected && (
        <p data-testid="plan-corrected-basis" data-tone="info" className="font-semibold">
          {corrected}
        </p>
      )}
      {reviewAction}
      {reviewed && <p data-testid="plan-review">{reviewed}</p>}
      {current && (
        <>
          <p data-testid="plan-assessment-line">{assessmentLine(current)}</p>
          <ul aria-label="Abgeklärte Minuten und Leistungen nach Kategorie" className="grid gap-1">
            {categoryRows(current, items).map((row) => (
              <li key={row.category} data-testid={`plan-category-${row.category}`} className="text-xs">
                <span className="font-semibold">Kategorie {row.category}</span> · Bedarfsabklärung: {row.assessed ?? "keine Minuten erfasst"}
                {row.items.length > 0 ? (
                  <ul className="ml-3 list-disc">
                    {row.items.map((text, n) => (
                      <li key={n}>{text}</li>
                    ))}
                  </ul>
                ) : (
                  <span> · keine Leistung im Pflegeplan</span>
                )}
              </li>
            ))}
          </ul>
          {(view?.newer_events ?? []).map((e) => (
            <p key={`${e.kind}-${e.date}`} data-testid="plan-newer-event">
              {newerEventText(e)}
            </p>
          ))}
        </>
      )}
    </div>
  );
}
