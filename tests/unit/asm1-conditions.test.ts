import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import PlanAssessmentBasis from "@/app/(protected)/team/plan-assessment-basis";
import {
  ASSESSMENT_REASONS,
  CONFIRM_TODO_LABEL,
  REFERENCE_HINT,
  REVIEW_REASONS,
  confirmTodoLabel,
  correctedBasisText,
  planReviewText,
  recordAnchor,
  recordsToConfirm,
  reviewLabel,
  reviewOffered,
  toCaseAssessments,
  type AssessmentRecord,
  type CaseAssessments,
} from "@/features/assessment/rules";

// ASM1-C1 to ASM1-C5 (migration 0101, ADR-125). Synthetic records and names only.

function record(over: Partial<AssessmentRecord> = {}): AssessmentRecord {
  return {
    id: "r-1",
    assessment_date: "2026-10-10",
    instrument_name: "Testinstrument Bedarf",
    instrument_version: "1.0",
    instrument_third_party_mark: false,
    assessor_name: "Synthetisch RN Nord",
    assessor_is_me: true,
    state: "unconfirmed",
    document_ref: "TST-1001",
    minutes_a: null,
    period_a: null,
    minutes_b: null,
    period_b: null,
    minutes_c: 300,
    period_c: "pro Woche",
    supersedes_id: null,
    superseded_by: null,
    supersede_reason: null,
    current: true,
    created_at: "2026-10-10T08:00:00Z",
    ...over,
  };
}

function view(over: Partial<CaseAssessments> = {}): CaseAssessments {
  return {
    case_id: "c-1",
    records: [record()],
    current_id: "r-1",
    plan_basis_date: "2026-10-10",
    plan_without_basis: false,
    newer_assessment_date: null,
    newer_events: [],
    corrected_basis_date: null,
    corrected_on: null,
    plan_review: null,
    ...over,
  };
}

const render = (v: CaseAssessments | null) => renderToStaticMarkup(createElement(PlanAssessmentBasis, { view: v, items: [] }));

describe("ASM1-C1: work that names her reaches her (UXR-59)", () => {
  it("counts only her unconfirmed, not superseded records; the link names the work and the count", () => {
    const views = {
      a: view({ records: [record({ id: "r-1" }), record({ id: "r-2", superseded_by: "r-3", current: false })] }),
      b: view({ case_id: "c-2", records: [record({ id: "r-4", assessor_is_me: false }), record({ id: "r-5", state: "confirmed" })] }),
    };
    expect(recordsToConfirm(views).map((r) => r.id)).toEqual(["r-1"]);
    expect(confirmTodoLabel(1)).toBe("Zu bestätigen: Bedarfsabklärung (1)");
    expect(recordAnchor("r-1")).toBe("bedarfsabklaerung-r-1");
  });

  it("a record entered by B naming A: A sees one, B and a second nurse C see none (assessor_is_me is per viewer)", () => {
    const forA = view({ records: [record({ assessor_is_me: true })] });
    const forB = view({ records: [record({ assessor_is_me: false })] });
    expect(recordsToConfirm([forA])).toHaveLength(1);
    expect(recordsToConfirm([forB])).toHaveLength(0);
    // after A confirms, or after the record is superseded, the line is gone
    expect(recordsToConfirm([view({ records: [record({ state: "confirmed" })] })])).toHaveLength(0);
    expect(recordsToConfirm([view({ records: [record({ superseded_by: "r-9", current: false })] })])).toHaveLength(0);
  });

  it("the line stays at info or below: no amber, rose or red class, no line when n = 0", () => {
    const source = readFileSync("src/app/(protected)/field/field-client.tsx", "utf8");
    const block = source.slice(source.indexOf("ASM1-C1"), source.indexOf("confirmTodoLabel(assessmentsToConfirm.count)"));
    expect(block).toContain("assessmentsToConfirm.count > 0");
    expect(block).not.toMatch(/amber-|rose-|red-|orange-/);
    expect(CONFIRM_TODO_LABEL).toBe("Zu bestätigen: Bedarfsabklärung");
  });
});

describe("ASM1-C2: the history waits (UXR-55)", () => {
  it("earlier records sit in a closed details; the current one and its 'Ersetzt …' line stay outside", () => {
    const source = readFileSync("src/app/(protected)/team/assessment-section.tsx", "utf8");
    expect(source).toMatch(/<details ref=\{historyRef\}[^>]*data-testid="assessment-history-details"/);
    expect(source).not.toMatch(/<details[^>]*\bopen\b/);
    expect(source).toContain("Frühere Erfassungen ({earlier.length})");
    expect(source.indexOf("renderRecord(current, false)")).toBeLessThan(source.indexOf("<details"));
    // the minutes with "Kategorie" are shown once per card, in the care-plan block
    expect(source).not.toMatch(/Kategorie \{c\}/);
  });
});

describe("ASM1-C3: a refusal says what to change (UXR-54)", () => {
  it("each refusal code maps to the new text", () => {
    expect(ASSESSMENT_REASONS.date_in_future).toBe("Das Datum der Bedarfsabklärung darf nicht in der Zukunft liegen.");
    expect(ASSESSMENT_REASONS.assessor_not_rn).toBe("Als abklärende Person kannst du nur eine Pflegefachperson des Teams wählen.");
  });

  it("the reference rule is rendered as hint text under the field, tied to it", () => {
    const source = readFileSync("src/app/(protected)/team/assessment-section.tsx", "utf8");
    expect(source).toContain("aria-describedby={`ref-hint-${caseId}`}");
    expect(source).toMatch(/data-testid="reference-hint"[\s\S]*\{REFERENCE_HINT\}/);
    expect(REFERENCE_HINT).toMatch(/mindestens eine Ziffer/);
  });
});

describe("ASM1-C4: one review act re-bases the plan (AUT-26)", () => {
  it("is offered while the marker, 'vor jeder erfassten Bedarfsabklärung' or the ASM1-C5 fact shows, never without a current record", () => {
    expect(reviewOffered(view())).toBe(false);
    expect(reviewOffered(view({ newer_assessment_date: "2026-10-28" }))).toBe(true);
    expect(reviewOffered(view({ plan_without_basis: true }))).toBe(true);
    expect(reviewOffered(view({ corrected_basis_date: "2026-10-10", corrected_on: "2026-10-30" }))).toBe(true);
    expect(reviewOffered(view({ current_id: null, newer_assessment_date: "2026-10-28" }))).toBe(false);
    expect(reviewLabel(record({ assessment_date: "2026-10-28" }))).toBe("Pflegeplan gegen Bedarfsabklärung vom 28.10.2026 geprüft");
  });

  it("`cra` (a): the act is shown with the record's state at the act; every refusal has a German text", () => {
    expect(
      planReviewText({ record_id: "r-1", assessment_date: "2026-10-28", state_at_review: "unconfirmed", reviewed_on: "2026-10-30", reviewer_name: "Synthetisch RN Nord" }),
    ).toBe("Pflegeplan geprüft gegen die Bedarfsabklärung vom 28.10.2026 am 30.10.2026 von Synthetisch RN Nord (Bedarfsabklärung damals nicht bestätigt)");
    for (const code of ["not_team_member", "not_rn", "not_current", "no_items", "nothing_to_review"]) expect(REVIEW_REASONS[code], code).toBeTruthy();
  });

  it("the reader's new columns are normalised", () => {
    const out = toCaseAssessments([{ case_id: "c-1", records: [], current_id: null, corrected_basis_date: "2026-10-10", corrected_on: "2026-10-30", plan_review: null }]);
    expect(out["c-1"].corrected_basis_date).toBe("2026-10-10");
    expect(out["c-1"].plan_review).toBeNull();
  });
});

describe("ASM1-C5: a corrected basis is visible on the plan (CGR-102)", () => {
  it("names both dates in words, at info, and shows nothing when there is no correction", () => {
    expect(correctedBasisText(view())).toBeNull();
    const text = correctedBasisText(view({ corrected_basis_date: "2026-10-10", corrected_on: "2026-10-30" }));
    expect(text).toBe("Die Bedarfsabklärung vom 10.10.2026, gegen die der Pflegeplan geschrieben ist, wurde am 30.10.2026 korrigiert.");
    const html = render(view({ corrected_basis_date: "2026-10-10", corrected_on: "2026-10-30" }));
    expect(html).toContain(text);
    expect(html).toContain('data-tone="info"');
    expect(html).not.toMatch(/amber-|rose-|red-|⚠/);
  });

  it("no due date, reminder or signal wording in the new code", () => {
    for (const path of ["src/app/(protected)/team/plan-review-button.tsx", "src/features/assessment/rules.ts"]) {
      expect(readFileSync(path, "utf8"), path).not.toMatch(/fällig|Neubeurteilung|Erinnerung|Intervall/);
    }
  });
});
