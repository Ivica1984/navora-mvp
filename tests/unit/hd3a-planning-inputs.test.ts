// HD-3a FE-128 (brief HD.md §5b, PO amendment 2026-11-25 10:39): the planning-input forms on /heim. T-2: a wrong value
// is refused with a visible text and nothing is sent; «nicht eingetragen» is only ever an explicit choice (R-6-3); the
// stale-value check (R-6-2 option (a)) compares what the form showed with a fresh read. The database checks role and
// range again (pgTAP 171, 172). Fixed rules, no AI.
import { describe, expect, it } from "vitest";
import {
  NOT_ENTERED, NO_CLASS, parseHours, parseWhole, readLimitsForm, readShiftClassForm, readStaffPlanningForm, sameAsShown,
  shiftClassLabel, shiftModelLabel, shownValue,
} from "@/features/home-plan/planning-inputs";
import { SHIFT_MODELS } from "@/features/home-plan/draft";
import { canPlan, canSettle, messageText, withAffected, withMessage } from "@/features/home-plan/rules";

const form = (v: Record<string, string>) => {
  const f = new FormData();
  for (const [k, x] of Object.entries(v)) f.set(k, x);
  return f;
};

describe("HD-3a planning inputs: numbers", () => {
  it("reads whole numbers and refuses decimals, signs, exponents and empty", () => {
    expect(parseWhole("11")).toBe(11);
    expect(parseWhole(" 6 ")).toBe(6);
    for (const bad of ["11,5", "11.5", "-1", "1e1", "", " ", "abc", "1000", null]) expect(parseWhole(bad as string | null)).toBeNull();
  });
  it("reads hours with a decimal comma or point", () => {
    expect(parseHours("42")).toBe(42);
    expect(parseHours("42,5")).toBe(42.5);
    expect(parseHours("42.25")).toBe(42.25);
    for (const bad of ["42,555", "4 2", "-42", "", "42h", null]) expect(parseHours(bad as string | null)).toBeNull();
  });
});

describe("HD-3a planning inputs: home limits form", () => {
  const base = { rest: "11", days: "6" };
  it("sends the typed values, with a decimal comma", () => {
    expect(readLimitsForm(form({ ...base, weekly_choice: "wert", weekly: "42,5" })))
      .toEqual({ ok: true, value: { minRestHours: 11, maxConsecutiveDays: 6, weeklyTargetHours: 42.5 } });
    // a typed number without a radio button is explicit enough
    expect(readLimitsForm(form({ ...base, weekly: "42" }))).toEqual({ ok: true, value: { minRestHours: 11, maxConsecutiveDays: 6, weeklyTargetHours: 42 } });
  });
  it("writes «nicht eingetragen» only when chosen and the field is empty", () => {
    expect(readLimitsForm(form({ ...base, weekly_choice: NOT_ENTERED, weekly: "" })))
      .toEqual({ ok: true, value: { minRestHours: 11, maxConsecutiveDays: 6, weeklyTargetHours: null } });
    expect(readLimitsForm(form({ ...base, weekly_choice: NOT_ENTERED, weekly: "42" }))).toEqual({ ok: false, error: "weekly_conflict" });
  });
  it("never turns a cleared field into NULL (T-2, R-6-3)", () => {
    expect(readLimitsForm(form({ ...base, weekly: "" }))).toEqual({ ok: false, error: "weekly_choice_missing" });
    expect(readLimitsForm(form({ ...base, weekly_choice: "wert", weekly: "" }))).toEqual({ ok: false, error: "weekly_not_number" });
    expect(readLimitsForm(form({ ...base, weekly_choice: "wert", weekly: "viel" }))).toEqual({ ok: false, error: "weekly_not_number" });
  });
  it("refuses a rest of 11,5 h and days of 6.5 with their own text", () => {
    expect(readLimitsForm(form({ rest: "11,5", days: "6", weekly: "42" }))).toEqual({ ok: false, error: "rest_not_whole" });
    expect(readLimitsForm(form({ rest: "11", days: "6.5", weekly: "42" }))).toEqual({ ok: false, error: "days_not_whole" });
    expect(readLimitsForm(form({ rest: "", days: "6", weekly: "42" }))).toEqual({ ok: false, error: "rest_not_whole" });
  });
});

describe("HD-3a planning inputs: person form", () => {
  it("sends Pensum and model", () => {
    expect(readStaffPlanningForm(form({ pensum_choice: "wert", pensum: "80", model: "no_night" })))
      .toEqual({ ok: true, value: { pensumPct: 80, shiftModel: "no_night" } });
    expect(readStaffPlanningForm(form({ pensum_choice: NOT_ENTERED, pensum: "", model: "any" })))
      .toEqual({ ok: true, value: { pensumPct: null, shiftModel: "any" } });
  });
  it("refuses a decimal Pensum, a contradiction, an empty field and an unknown model", () => {
    expect(readStaffPlanningForm(form({ pensum: "80,5", model: "any" }))).toEqual({ ok: false, error: "pensum_not_whole" });
    expect(readStaffPlanningForm(form({ pensum_choice: NOT_ENTERED, pensum: "80", model: "any" }))).toEqual({ ok: false, error: "pensum_conflict" });
    expect(readStaffPlanningForm(form({ pensum: "", model: "any" }))).toEqual({ ok: false, error: "pensum_choice_missing" });
    expect(readStaffPlanningForm(form({ pensum: "80", model: "day_only" }))).toEqual({ ok: false, error: "shift_model_unknown" });
  });
  it("labels every model of the database and nothing else", () => {
    expect(SHIFT_MODELS.map(shiftModelLabel)).toEqual(["alle Dienste", "nur Frühdienst", "nur Spätdienst", "nur Nachtdienst", "kein Nachtdienst"]);
    expect(shiftModelLabel("day_only")).toBe("unbekannt");
  });
});

describe("HD-3a planning inputs: shift class form", () => {
  it("sends a class or NULL for «keine Klasse», refuses a day class", () => {
    expect(readShiftClassForm(form({ class: "night" }))).toEqual({ ok: true, value: "night" });
    expect(readShiftClassForm(form({ class: NO_CLASS }))).toEqual({ ok: true, value: null });
    expect(readShiftClassForm(form({ class: "day" }))).toEqual({ ok: false, error: "shift_class_unknown" });
    expect(readShiftClassForm(form({}))).toEqual({ ok: false, error: "shift_class_unknown" });
    expect([shiftClassLabel("early"), shiftClassLabel(null)]).toEqual(["Früh", "keine Klasse"]);
  });
  it("words the affected count read back from the database (T-1)", () => {
    expect(messageText("shift_class_saved", { applied: 0, refused: 0, affected: 0 })?.text).toContain("Keine eingeteilte Person");
    expect(messageText("shift_class_saved", { applied: 0, refused: 0, affected: 1 })?.text).toContain("1 Einteilung passt");
    expect(messageText("shift_class_saved", { applied: 0, refused: 0, affected: 3 })?.text).toContain("3 Einteilungen passen");
    expect(withMessage(withAffected("/heim?ansicht=einstellungen", 3), "shift_class_saved")).toBe("/heim?ansicht=einstellungen&betroffen=3&meldung=shift_class_saved");
  });
});

describe("HD-3a planning inputs: stale values (R-6-2 option (a))", () => {
  it("matches only the value the form showed", () => {
    expect(sameAsShown(shownValue(11), 11)).toBe(true);
    expect(sameAsShown(shownValue(null), null)).toBe(true);
    expect(sameAsShown(shownValue(null), undefined)).toBe(true);
    expect(sameAsShown(shownValue(11), 12)).toBe(false);
    expect(sameAsShown(shownValue(null), 42)).toBe(false);
    expect(sameAsShown(shownValue(42.5), 42.5)).toBe(true);
    expect(sameAsShown(null, 11)).toBe(false);
  });
});

describe("HD-3a planning inputs: who sees which form", () => {
  it("limits and class: lead only; Pensum and model: lead and planner; viewer none", () => {
    expect([canSettle("lead"), canSettle("planner"), canSettle("viewer")]).toEqual([true, false, false]);
    expect([canPlan("lead"), canPlan("planner"), canPlan("viewer")]).toEqual([true, true, false]);
  });
  it("words every refusal of the three commands and of the form", () => {
    for (const code of [
      "rest_not_whole", "days_not_whole", "weekly_not_number", "weekly_choice_missing", "weekly_conflict", "limits_not_valid",
      "weekly_target_hours_not_valid", "pensum_not_whole", "pensum_choice_missing", "pensum_conflict", "pensum_not_valid",
      "shift_model_unknown", "shift_model_not_valid", "shift_class_unknown", "shift_class_not_valid", "changed_meanwhile",
    ]) {
      const m = messageText(code);
      expect(m?.kind, code).toBe("error");
      expect(m?.text, code).toMatch(/Nichts wurde gespeichert/);
    }
    expect(messageText("limits_saved")?.kind).toBe("ok");
    expect(messageText("staff_planning_saved")?.kind).toBe("ok");
  });
});
