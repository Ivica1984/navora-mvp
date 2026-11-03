import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import PlanAssessmentBasis from "@/app/(protected)/team/plan-assessment-basis";
import VoidReasonForm from "@/app/(protected)/team/assessment-void-fields";
import {
  VOID_CONFIRM_SENTENCE,
  VOID_PRESETS,
  VOID_PRESET_REASON,
  VOID_REASONS,
  VOID_REASON_HINT,
  VOID_SUPERSEDE_SENTENCE,
  basisFactText,
  newerAssessmentText,
  planBasisText,
  planReviewText,
  recordsToConfirm,
  reviewOffered,
  toCaseAssessments,
  voidSubmitEnabled,
  voidedLine,
  type AssessmentRecord,
  type CaseAssessments,
  type VoidedRecord,
} from "@/features/assessment/rules";

// ASM1-C6 with C6 (8) (migration 0106, ADR-140; brief docs/agents/briefs/ASM1.md 13:28, 15:00, 15:55, 18:25; `uxa`
// 15:50). Synthetic records and names only.

function record(over: Partial<AssessmentRecord> = {}): AssessmentRecord {
  return {
    id: "r-1",
    assessment_date: "2026-10-10",
    instrument_name: "Testinstrument Bedarf",
    instrument_version: "1.0",
    instrument_third_party_mark: false,
    assessor_name: "Synthetisch RN Nord",
    assessor_is_me: true,
    state: "confirmed",
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

function voided(over: Partial<VoidedRecord> = {}): VoidedRecord {
  return {
    id: "r-9",
    voided_on: "2026-11-02",
    voided_by_name: "Synthetisch RN Nord",
    reason: VOID_PRESET_REASON,
    assessor_is_me: false,
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
    basis_fact: null,
    voided_records: [],
    ...over,
  };
}

const items = [{ id: "i-1", service: "Synthetisch Morgenpflege", category: "C", minutes: 30, frequency: "2x täglich" }];

describe("ASM1-C6 (3): what the team sees of a voided record (lca (a), po 13:28 wording)", () => {
  it("one line: date of the void, who, reason; no minutes, period, instrument, reference or assessment date", () => {
    expect(voidedLine(voided({ reason: "Synthetisch: gehört zu einem anderen Fall" }))).toBe(
      "Irrtümlich erfasst am 02.11.2026 von Synthetisch RN Nord. Grund: Synthetisch: gehört zu einem anderen Fall",
    );
    // The reader's voided entry carries no field of the record (pgTAP 107 asserts the reader; this the type).
    const keys = Object.keys(voided()).sort();
    expect(keys).toEqual(["assessor_is_me", "id", "reason", "voided_by_name", "voided_on"]);
  });
  it("the reader's new columns are normalised; a voided record never reaches the open-confirmation list (C6 (5))", () => {
    const rows = toCaseAssessments([
      { case_id: "c-1", records: [], current_id: null, basis_fact: "voided", voided_records: [voided({ assessor_is_me: true })] },
    ]);
    expect(rows["c-1"].basis_fact).toBe("voided");
    expect(rows["c-1"].voided_records).toHaveLength(1);
    expect(recordsToConfirm(rows)).toHaveLength(0);
    expect(toCaseAssessments([{ case_id: "c-2" }])["c-2"].basis_fact).toBeNull();
    expect(toCaseAssessments([{ case_id: "c-2" }])["c-2"].voided_records).toEqual([]);
  });
});

describe("ASM1-C6 (4) with P-37 (po 18:25): two options, neither preselected, the supersede sentence first", () => {
  it("the preset list holds the wrong-client text only", () => {
    expect(VOID_PRESETS).toEqual(["Falsche Klientin oder falscher Klient gewählt"]);
  });
  it("neither option is preselected and submit is disabled until one is chosen", () => {
    const html = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: null, text: "", pending: false }));
    expect(html).not.toMatch(/checked/);
    expect(html).toMatch(/<button[^>]*type="submit"[^>]*disabled/);
    expect(voidSubmitEnabled(null, "")).toBe(false);
  });
  it("the free-text field and its hint appear only after «Anderer Grund», tied by aria-describedby", () => {
    const none = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: null, text: "", pending: false }));
    const preset = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: "wrong_client", text: "", pending: false }));
    const other = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: "other", text: "", pending: false }));
    for (const html of [none, preset]) {
      expect(html).not.toContain("<textarea");
      expect(html).not.toContain(VOID_REASON_HINT);
    }
    expect(other).toContain("<textarea");
    expect(other).toContain(VOID_REASON_HINT);
    expect(other).toMatch(/<textarea[^>]*aria-describedby="v1-hint"/);
    expect(other).toMatch(/id="v1-hint"/);
  });
  it("the preset needs no text; «Anderer Grund» needs 10 to 500 characters", () => {
    expect(voidSubmitEnabled("wrong_client", "")).toBe(true);
    expect(voidSubmitEnabled("other", "zu kurz")).toBe(false);
    expect(voidSubmitEnabled("other", "Synthetisch: falscher Fall gewählt")).toBe(true);
    expect(voidSubmitEnabled("other", "x".repeat(501))).toBe(false);
    const preset = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: "wrong_client", text: "", pending: false }));
    expect(preset).not.toMatch(/<button[^>]*type="submit"[^>]*disabled/);
  });
  it("`cra` condition: the step shows the supersede sentence before the two options", () => {
    const html = renderToStaticMarkup(createElement(VoidReasonForm, { idBase: "v1", choice: null, text: "", pending: false }));
    const sentence = html.indexOf(VOID_SUPERSEDE_SENTENCE);
    expect(sentence).toBeGreaterThanOrEqual(0);
    expect(sentence).toBeLessThan(html.indexOf(VOID_PRESET_REASON));
    expect(sentence).toBeLessThan(html.indexOf("Anderer Grund"));
  });
  it("the confirming sentence says the entry stays and the team sees only that it was voided", () => {
    expect(VOID_CONFIRM_SENTENCE).toContain("bleibt gespeichert");
    expect(VOID_CONFIRM_SENTENCE).toContain("das Team sieht nur noch, dass er irrtümlich erfasst wurde");
  });
  it("every refusal of the void command has a German text", () => {
    for (const code of ["not_team_member", "not_rn", "already_voided", "superseded", "reason_kind_invalid", "reason_required"]) {
      expect(VOID_REASONS[code]).toBeTruthy();
    }
  });
});

describe("ASM1-C6 (8): the plan's basis is read by identity, not by date (CGR-104, `uxa` 15:50 wording)", () => {
  it("(ii) a same-date parallel record: one sentence naming the current date, and no «Neuere» marker", () => {
    const v = view({ basis_fact: "not_current", newer_assessment_date: null });
    expect(basisFactText(v)).toBe(
      "Der Pflegeplan ist gegen eine Bedarfsabklärung geschrieben, die nicht mehr die aktuelle ist. Aktuell ist die Bedarfsabklärung vom 10.10.2026.",
    );
    expect(newerAssessmentText(v)).toBeNull();
    const html = renderToStaticMarkup(createElement(PlanAssessmentBasis, { view: v, items }));
    expect(html).not.toContain("Neuere");
    expect(html.indexOf('data-testid="plan-basis-fact"')).toBeLessThan(html.indexOf('data-testid="plan-assessment-line"'));
    expect(html).toMatch(/data-testid="plan-basis-fact"[^>]*data-tone="info"/);
  });
  it("(ii) a voided basis with an older record left: no field of the voided record, the current date only", () => {
    const v = view({
      basis_fact: "voided",
      plan_basis_date: null,
      records: [record({ id: "r-1", assessment_date: "2026-09-01" })],
      voided_records: [voided()],
    });
    expect(basisFactText(v)).toBe(
      "Die Bedarfsabklärung, gegen die der Pflegeplan geschrieben ist, wurde als irrtümlich erfasst markiert. Aktuell ist die Bedarfsabklärung vom 01.09.2026.",
    );
  });
  it("(iii) planBasisText never names a voided record; the review line of a voided record is not shown", () => {
    expect(planBasisText(view({ basis_fact: "voided", plan_basis_date: "2026-10-10" }))).toBeNull();
    expect(
      planReviewText({ record_id: "r-9", assessment_date: null, record_voided: true, state_at_review: "confirmed", reviewed_on: "2026-11-01", reviewer_name: "X" }),
    ).toBeNull();
  });
  it("(iv) the act is offered for a parallel record and for a voided basis while a record is current", () => {
    expect(reviewOffered(view({ basis_fact: "not_current" }))).toBe(true);
    expect(reviewOffered(view({ basis_fact: "voided" }))).toBe(true);
    expect(reviewOffered(view({ basis_fact: null }))).toBe(false);
  });
  it("(iv)/(v) po 18:25: only record voided → the sentence stays, no review command is offered, no voided field shown", () => {
    const v = view({
      records: [],
      current_id: null,
      plan_basis_date: null,
      basis_fact: "voided",
      voided_records: [voided({ id: "r-1" })],
    });
    expect(reviewOffered(v)).toBe(false);
    expect(basisFactText(v)).toBe(
      "Die Bedarfsabklärung, gegen die der Pflegeplan geschrieben ist, wurde als irrtümlich erfasst markiert. Es gibt keine aktuelle Bedarfsabklärung.",
    );
    const html = renderToStaticMarkup(createElement(PlanAssessmentBasis, { view: v, items, reviewAction: null }));
    expect(html).toContain("Es gibt keine aktuelle Bedarfsabklärung.");
    expect(html).not.toContain("plan-review-command");
    // lca 17:45 proviso: no date or field of the voided record in the care-plan block.
    expect(html).not.toMatch(/Kategorie [ABC] · Bedarfsabklärung: \d/);
    expect(html).not.toContain("Referenz");
    expect(html).not.toContain("Geschrieben gegen");
    expect(html).not.toMatch(/\d{2}\.\d{2}\.\d{4}/);
  });
  it("no due date, reminder or signal wording in the new code (ASM1 negative)", () => {
    const src = readFileSync("src/app/(protected)/team/assessment-void-fields.tsx", "utf8") + readFileSync("src/app/(protected)/team/assessment-void-form.tsx", "utf8");
    expect(src).not.toMatch(/fällig|Erinnerung|Frist|amber-/);
  });
});
