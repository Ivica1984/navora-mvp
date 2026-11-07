import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// UX2-30 (uxa UXR-56 to -58, UXR-61 to -63; ADR-135): the assessment form on /team. Display only, no migration.
// Synthetic records and names only.

vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: () => undefined }) }));
vi.mock("@/features/assessment/commands", () => ({
  recordAssessment: async () => ({ ok: true }),
  confirmAssessment: async () => ({ ok: true }),
  reviewCarePlan: async () => ({ ok: true }),
  // ASM1-C6 (#815): the section now imports the void form, which imports this command.
  voidAssessment: async () => ({ ok: true }),
}));

import AssessmentSection from "@/app/(protected)/team/assessment-section";
import {
  ASSESSMENT_REASONS,
  REFERENCE_HINT,
  isValidReference,
  planReviewText,
  prefillInstrumentId,
  supersedeFirstLine,
  type AssessmentRecord,
  type CaseAssessments,
  type Instrument,
} from "@/features/assessment/rules";

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

function instrument(over: Partial<Instrument> = {}): Instrument {
  return { id: "i-1", name: "Testinstrument Bedarf", version: "1.0", valid_from: "2026-01-01", valid_to: null, third_party_mark: false, ...over };
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

const read = (path: string) => readFileSync(path, "utf8");

describe("UX2-30 (1): one column at phone width (UXR-56)", () => {
  it("the field grid and every minutes row are one column below sm", () => {
    const source = read("src/app/(protected)/team/assessment-section.tsx");
    expect(source).toContain('className="grid grid-cols-1 gap-2 sm:grid-cols-2"');
    // a row of inputs never has two columns at phone width (the Speichern/Abbrechen row holds buttons only)
    const inputRows = source.match(/<div key=\{c\} className="[^"]*"/g) ?? [];
    expect(inputRows.length).toBe(1);
    expect(inputRows[0]).toMatch(/"grid grid-cols-1 [^"]*sm:grid-cols-2"/);
  });
});

describe("UX2-30 (2): the replace form names the record and prefills the instrument (UXR-57)", () => {
  it("first line: 'Ersetzt die Bedarfsabklärung vom <Datum>'", () => {
    expect(supersedeFirstLine(record({ assessment_date: "2026-10-28" }))).toBe("Ersetzt die Bedarfsabklärung vom 28.10.2026");
  });

  it("the instrument is prefilled when exactly one catalogue entry matches and is valid on the record's date", () => {
    const r = record({ assessment_date: "2026-10-10" });
    expect(prefillInstrumentId(r, [instrument()])).toBe("i-1");
    // valid_to on the record's date still counts (inclusive, as the database checks it)
    expect(prefillInstrumentId(r, [instrument({ valid_to: "2026-10-10" })])).toBe("i-1");
    // not valid on that date: nothing prefilled, she chooses
    expect(prefillInstrumentId(r, [instrument({ valid_to: "2026-10-09" })])).toBe("");
    expect(prefillInstrumentId(r, [instrument({ valid_from: "2026-10-11" })])).toBe("");
    // another name, version or mark: not the same instrument
    expect(prefillInstrumentId(r, [instrument({ version: "2.0" })])).toBe("");
    expect(prefillInstrumentId(r, [instrument({ third_party_mark: true })])).toBe("");
    // two matching entries: ambiguous, nothing prefilled (never a guess)
    expect(prefillInstrumentId(r, [instrument(), instrument({ id: "i-2", valid_from: "2026-06-01" })])).toBe("");
    // the matching one among others
    expect(prefillInstrumentId(r, [instrument({ id: "i-0", name: "Anderes" }), instrument({ id: "i-3" })])).toBe("i-3");
  });

  it("the form shows the line and uses the prefill; both selects stay editable", () => {
    const source = read("src/app/(protected)/team/assessment-section.tsx");
    expect(source).toMatch(/data-testid="supersede-target"[\s\S]*\{supersedeFirstLine\(prefill\)\}/);
    expect(source).toContain('defaultValue={prefill ? prefillInstrumentId(prefill, instruments) : ""}');
    expect(source).not.toMatch(/<select[^>]*disabled/);
  });
});

describe("UX2-30 (3): one error component on /team (UXR-58)", () => {
  it("assessment section, review command and team view use the shared ErrorText; no own red box", () => {
    for (const path of [
      "src/app/(protected)/team/assessment-section.tsx",
      "src/app/(protected)/team/plan-review-button.tsx",
      "src/app/(protected)/team/team-client.tsx",
    ]) {
      const source = read(path);
      expect(source, path).toMatch(/import \{ ErrorText \} from "\.\/error-text";/);
      expect(source, path).not.toMatch(/function ErrorText|function ErrorLine/);
    }
    for (const path of ["src/app/(protected)/team/assessment-section.tsx", "src/app/(protected)/team/plan-review-button.tsx"]) {
      expect(read(path), path).not.toContain("rose-");
    }
  });
});

describe("UX2-30 (4): the hint gives one example and is not the refusal (UXR-61)", () => {
  it("hint and refusal differ; the hint's example is itself a valid reference", () => {
    expect(REFERENCE_HINT).toBe("Kennung aus eurem Abklärungsinstrument, z. B. BA-2026-0042: mindestens eine Ziffer, ohne Leerzeichen, Punkt oder Schrägstrich.");
    expect(REFERENCE_HINT.match(/z\. B\./g)?.length).toBe(1);
    expect(ASSESSMENT_REASONS.reference_invalid).toBe("Diese Referenz ist keine Kennung: 3 bis 64 Zeichen, nur Buchstaben, Ziffern und _ : # -, mindestens eine Ziffer.");
    expect(REFERENCE_HINT).not.toBe(ASSESSMENT_REASONS.reference_invalid);
    expect(ASSESSMENT_REASONS.reference_invalid).not.toContain(REFERENCE_HINT);
    expect(REFERENCE_HINT).not.toContain(ASSESSMENT_REASONS.reference_invalid);
    expect(isValidReference("BA-2026-0042")).toBe(true);
  });
});

describe("UX2-30 (5): the review line is two sentences, the state its own (UXR-62; `cra` (a) stays visible)", () => {
  const base = { record_id: "r-1", assessment_date: "2026-10-28", reviewed_on: "2026-10-30", reviewer_name: "Synthetisch RN Nord" };

  it("not confirmed at the act: a second sentence names the state", () => {
    expect(planReviewText({ ...base, state_at_review: "unconfirmed" })).toBe(
      "Geprüft am 30.10.2026 von Synthetisch RN Nord gegen die Bedarfsabklärung vom 28.10.2026. Diese war damals nicht bestätigt.",
    );
  });

  it("confirmed at the act: one sentence; no parentheses in either form", () => {
    expect(planReviewText({ ...base, state_at_review: "confirmed" })).toBe(
      "Geprüft am 30.10.2026 von Synthetisch RN Nord gegen die Bedarfsabklärung vom 28.10.2026.",
    );
    for (const state of ["confirmed", "unconfirmed"] as const) expect(planReviewText({ ...base, state_at_review: state })).not.toMatch(/[()]/);
  });

  it("a reviewer without a recorded name keeps the existing fallback", () => {
    expect(planReviewText({ ...base, reviewer_name: null, state_at_review: "confirmed" })).toBe(
      "Geprüft am 30.10.2026 von Pflegefachperson ohne erfassten Namen gegen die Bedarfsabklärung vom 28.10.2026.",
    );
  });
});

describe("UX2-30 (6): with no current record, the fact comes before the history (UXR-63)", () => {
  const render = (v: CaseAssessments) =>
    renderToStaticMarkup(createElement(AssessmentSection, { caseId: "c-1", view: v, instruments: [instrument()], members: [] }));

  it("only superseded records: 'Keine aktuelle Bedarfsabklärung.' precedes the closed history, once", () => {
    const html = render(
      view({
        current_id: null,
        records: [record({ id: "r-1", current: false, superseded_by: "r-2" }), record({ id: "r-2", current: false, superseded_by: "r-3" })],
      }),
    );
    const fact = html.indexOf("Keine aktuelle Bedarfsabklärung.");
    const history = html.indexOf('data-testid="assessment-history-details"');
    expect(fact).toBeGreaterThan(-1);
    expect(history).toBeGreaterThan(-1);
    expect(fact).toBeLessThan(history);
    expect(html.split("Keine aktuelle Bedarfsabklärung.").length - 1).toBe(1);
  });

  it("with a current record the line is not shown", () => {
    expect(render(view())).not.toContain("Keine aktuelle Bedarfsabklärung.");
  });
});
