import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import PlanAssessmentBasis from "@/app/(protected)/team/plan-assessment-basis";
import {
  ASSESSMENT_REASONS,
  assessedMinutes,
  assessmentLine,
  categoryRows,
  instrumentLabel,
  isValidReference,
  newerAssessmentText,
  newerEventText,
  planBasisText,
  toCaseAssessments,
  type AssessmentRecord,
  type CaseAssessments,
  type PlanItemAsWritten,
} from "@/features/assessment/rules";

// ASM1 (migration 0100, ADR-123). Synthetic records, names and references only.

function record(over: Partial<AssessmentRecord> = {}): AssessmentRecord {
  return {
    id: "r-1",
    assessment_date: "2026-10-10",
    instrument_name: "Testinstrument Bedarf",
    instrument_version: "1.0",
    instrument_third_party_mark: false,
    assessor_name: "Synthetisch RN Nord",
    assessor_is_me: false,
    state: "unconfirmed",
    document_ref: "TST-1001",
    minutes_a: 60,
    period_a: "pro Woche",
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

// The brief's example: "30 min, 2× täglich" and "60 min, 1× wöchentlich" in one category.
const ITEMS: PlanItemAsWritten[] = [
  { id: "i-1", service: "Synthetisch Morgenpflege", category: "C", minutes: 30, frequency: "2× täglich" },
  { id: "i-2", service: "Synthetisch Duschen", category: "C", minutes: 60, frequency: "1× wöchentlich", freq_times: 1, freq_period: "week" },
];

const render = (v: CaseAssessments | null, items: PlanItemAsWritten[]) => renderToStaticMarkup(createElement(PlanAssessmentBasis, { view: v, items }));
const classes = (html: string) => [...html.matchAll(/class="([^"]*)"/g)].map((m) => m[1]);

describe("ASM1-3: the reference is an opaque identifier (same rule as the database)", () => {
  it.each(["TST-1001", "BA:2026#42", "a12", "X".repeat(63) + "1"])("accepts %s", (ref) => expect(isValidReference(ref)).toBe(true));
  it.each(["TST 1001", "befund2026.pdf", "akte/2026", "Bedarfsabklaerung", "ab", "-TST1", "A1" + "x".repeat(63)])("refuses %s", (ref) =>
    expect(isValidReference(ref)).toBe(false),
  );
});

describe("ASM1-1 / ASM1-10: what is shown is what was recorded", () => {
  it("minutes carry their period as entered", () => {
    expect(assessedMinutes(record(), "A")).toBe("60 min pro Woche");
    expect(assessedMinutes(record(), "B")).toBeNull();
    expect(assessedMinutes(record({ minutes_b: 15, period_b: "je Quartal laut Instrument" }), "B")).toBe("15 min je Quartal laut Instrument");
  });

  it("the line names date, instrument, assessor and state", () => {
    expect(assessmentLine(record())).toBe(
      "Bedarfsabklärung vom 10.10.2026 · Testinstrument Bedarf 1.0 · Synthetisch RN Nord · nicht bestätigt",
    );
    expect(assessmentLine(record({ state: "confirmed" }))).toMatch(/· bestätigt$/);
  });

  it("ASM1-6: a third party's mark is shown as such", () => {
    expect(instrumentLabel("Testmarke HC", "9.1", true)).toBe("Testmarke HC 9.1 (Marke Dritter)");
    expect(instrumentLabel("Testinstrument Bedarf", "1.0", false)).toBe("Testinstrument Bedarf 1.0");
  });

  it("every refusal of the database has a German message", () => {
    for (const code of ["not_team_member", "date_in_future", "instrument_not_valid", "assessor_not_rn", "reference_invalid", "reference_required",
      "period_required", "minutes_invalid", "supersede_not_found", "already_superseded", "reason_required", "not_assessor", "already_confirmed", "superseded"])
      expect(ASSESSMENT_REASONS[code], code).toBeTruthy();
  });
});

describe("ASM1-7: the care plan against its assessment", () => {
  it("shows the date it was written against, and the marker only when a newer one exists", () => {
    expect(planBasisText(view())).toBe("Geschrieben gegen die Bedarfsabklärung vom 10.10.2026");
    expect(newerAssessmentText(view())).toBeNull();
    expect(newerAssessmentText(view({ newer_assessment_date: "2026-10-28" }))).toBe("Neuere Bedarfsabklärung vom 28.10.2026");
    expect(planBasisText(view({ plan_basis_date: null, plan_without_basis: true }))).toBe("Geschrieben vor jeder erfassten Bedarfsabklärung");
  });

  it("the reader's rows are normalised per case", () => {
    const out = toCaseAssessments([{ case_id: "c-1", records: [record()], current_id: "r-1", plan_basis_date: null, plan_without_basis: false,
      newer_assessment_date: null, newer_events: null }]);
    expect(out["c-1"].records).toHaveLength(1);
    expect(out["c-1"].newer_events).toEqual([]);
    expect(toCaseAssessments(null)).toEqual({});
  });
});

describe("ASM1-11: assessed minutes beside the planned items, no sum", () => {
  it("(1) no sum: both items with their text and no total anywhere", () => {
    const html = render(view(), ITEMS);
    expect(html).toContain("Synthetisch Morgenpflege · 30 min pro Einsatz · 2× täglich");
    expect(html).toContain("Synthetisch Duschen · 60 min pro Einsatz · 1× wöchentlich (Rhythmus erfasst: 1× pro Woche)");
    expect(html).not.toMatch(/\b90\b/); // 30 + 60
    expect(html).not.toMatch(/Total|Summe|gesamt|Durchschnitt|Differenz|Abweichung|zu viel|zu wenig|über|unter/i);
    expect(categoryRows(record(), ITEMS).find((r) => r.category === "C")).toEqual({
      category: "C",
      assessed: "300 min pro Woche",
      items: ["Synthetisch Morgenpflege · 30 min pro Einsatz · 2× täglich", "Synthetisch Duschen · 60 min pro Einsatz · 1× wöchentlich (Rhythmus erfasst: 1× pro Woche)"],
    });
  });

  it("(2) no colour, warning or icon derived from the numbers: two seeds with different minutes render identical classes", () => {
    const small = render(view({ records: [record({ minutes_c: 10 })] }), ITEMS);
    const large = render(view({ records: [record({ minutes_c: 9000 })] }), ITEMS.map((i) => ({ ...i, minutes: i.minutes * 7 })));
    expect(classes(small)).toEqual(classes(large));
    expect(small).not.toMatch(/⚠|amber-|rose-|red-|warn/);
    expect(large).not.toMatch(/⚠|amber-|rose-|red-|warn/);
  });

  it("(3) date, assessor and period are shown beside the assessed minutes", () => {
    const html = render(view(), ITEMS);
    expect(html).toContain("Bedarfsabklärung vom 10.10.2026");
    expect(html).toContain("Synthetisch RN Nord");
    expect(html).toContain("300 min pro Woche");
  });

  it("(4) a younger dated fact is named in words", () => {
    expect(newerEventText({ kind: "resume", date: "2026-10-29" })).toBe("Neueres Ereignis seit der Bedarfsabklärung: Wiederaufnahme nach Unterbruch, 29.10.2026");
    const html = render(view({ newer_events: [{ kind: "hospital_stay", date: "2026-10-20" }] }), ITEMS);
    expect(html).toContain("Neueres Ereignis seit der Bedarfsabklärung: Unterbruch wegen Spitalaufenthalt, 20.10.2026");
  });

  it("the component has no conditional class (source scan) and the rules module computes no sum", () => {
    const source = readFileSync("src/app/(protected)/team/plan-assessment-basis.tsx", "utf8");
    expect(source).not.toMatch(/className=\{/);
    const rules = readFileSync("src/features/assessment/rules.ts", "utf8").replace(/\/\/.*$/gm, "");
    expect(rules).not.toMatch(/\.reduce\(|\+=|Math\.(max|min)\(/);
  });
});

describe("Negative: no reassessment due date, interval or reminder", () => {
  it("no due-date wording in the ASM1 screens", () => {
    for (const path of ["src/app/(protected)/team/assessment-section.tsx", "src/app/(protected)/team/plan-assessment-basis.tsx", "src/features/assessment/rules.ts"]) {
      expect(readFileSync(path, "utf8"), path).not.toMatch(/fällig|Neubeurteilung|Erinnerung|Intervall/);
    }
  });
});
