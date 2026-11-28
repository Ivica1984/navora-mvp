// HD-3a-F3 (brief docs/agents/briefs/HD-3a-F3.md, founder FE-135 option A, ADR-231): R-m in the plan draft. The
// database reads the same rule (`private.institution_rule_breaches`, pgTAP 187); here the planner side: with a monthly
// target the month is the condition instead of R-h, stored minutes of the month come from the database, without a
// target R-h is unchanged, «weder Monatssoll noch Pensum» is never planned, the hard rules stay hard, and the
// independent check (verifyDraft) finds a row over the target. Synthetic data only.
import { describe, expect, it } from "vitest";
import {
  buildDraft,
  draftContextRange,
  monthOf,
  shiftMinutes,
  verifyDraft,
  type DraftInput,
  type DraftMonthTarget,
  type DraftShiftType,
  type DraftStaff,
} from "@/features/home-plan/draft";
import { draftInputFromPlan, mergePlans, type DraftPlan } from "@/features/home-plan/draft-screen";
import {
  NO_VALUE, expectedMonthTarget, expectedThreshold, minutesAsHours, readMonthTargetForm, readThresholdForm, shownValue,
} from "@/features/home-plan/planning-inputs";
import { addDays, messageText, monthTargetOf, type PlanCell } from "@/features/home-plan/rules";

const FAGE = "fage_efz";
const EARLY: DraftShiftType = { id: "t1-early", code: "F", label: "Früh", starts_at: "07:00", ends_at: "15:30", shift_class: "early" };
const LIMITS = { minRestHours: 11, maxConsecutiveDays: 6, fullTimeMinutesPerWeek: 42 * 60 };
const F = 510; // minutes of one early shift (no DST change in July)
const FROM = "2027-07-01";
const TO = "2027-07-31";

function person(id: string, over: Partial<DraftStaff> = {}): DraftStaff {
  return { id, display_name: id, grade: FAGE, home_station_id: null, active: true, pensum_pct: 100, shift_model: "any", ...over };
}

/** One station, the early shift needs `need` persons every day of [FROM, TO]; no stored assignment unless `stored`. */
function input(staff: DraftStaff[], targets: DraftMonthTarget[], need = 1, stored: Array<{ date: string; staff: string }> = []): DraftInput {
  const ctx = draftContextRange(FROM, TO, LIMITS);
  const cells: PlanCell[] = [];
  let n = 0;
  for (let d = ctx.from; d <= ctx.to; d = addDays(d, 1)) {
    const assigned = stored.filter((s) => s.date === d).map((s) => ({
      assignment_id: `a${n++}`, staff_id: s.staff, display_name: s.staff, grade: FAGE, absent: false, inactive: false,
    }));
    cells.push({
      date: d, station_id: "st", shift_type_id: EARLY.id, required_total: need, required_grade: null, required_grade_count: 0,
      example: true, assigned, present: assigned.length, grade_present: 0, missing: Math.max(need - assigned.length, 0),
      status: assigned.length >= need ? "ok" : "gap", external_covered: 0, order: null,
    });
  }
  return { from: FROM, to: TO, shiftTypes: [EARLY], staff, absences: [], cells, limits: LIMITS, monthTargets: targets };
}

function rowsOf(i: DraftInput) {
  const r = buildDraft(i);
  if (r.result !== "ok") throw new Error(r.result);
  return r;
}
const count = (rows: ReadonlyArray<{ staff_id: string }>, id: string) => rows.filter((r) => r.staff_id === id).length;

describe("HD-3a-F3 R-m in the plan draft", () => {
  it("counts a shift to the month of its work date and a split shift without its pause", () => {
    expect(monthOf("2027-07-31")).toBe("2027-07-01");
    expect(shiftMinutes("2027-07-05", EARLY)).toBe(F);
  });

  it("with a target the month is the condition instead of R-h (Pensum 10 % would allow no shift at all)", () => {
    const i = input([person("p", { pensum_pct: 10 })], [{ staff_id: "p", month: "2027-07-01", target_minutes: 4 * F, planned_minutes: 0 }]);
    const r = rowsOf(i);
    expect(count(r.rows, "p")).toBe(4);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    // The remaining days are gaps whose reason is the monthly target, never «Pensum ausgeschöpft».
    const blocked = r.gaps.reduce((a, g) => a + g.blocked.month_target_full, 0);
    expect(blocked).toBe(31 - 4);
    expect(r.gaps.reduce((a, g) => a + g.blocked.pensum_full, 0)).toBe(0);
  });

  it("stored minutes of the month come from the database (planned_minutes), also outside the cells read", () => {
    const i = input([person("p", { pensum_pct: 10 })], [{ staff_id: "p", month: "2027-07-01", target_minutes: 3 * F, planned_minutes: 2 * F }]);
    expect(count(rowsOf(i).rows, "p")).toBe(1);
  });

  it("equal to the target passes, one minute short refuses", () => {
    const exact = input([person("p")], [{ staff_id: "p", month: "2027-07-01", target_minutes: F, planned_minutes: 0 }]);
    expect(count(rowsOf(exact).rows, "p")).toBe(1);
    const short = input([person("p")], [{ staff_id: "p", month: "2027-07-01", target_minutes: F - 1, planned_minutes: 0 }]);
    expect(count(rowsOf(short).rows, "p")).toBe(0);
  });

  it("without a target R-h is unchanged (regression)", () => {
    const i = input([person("q", { pensum_pct: 10 })], []);
    const r = rowsOf(i);
    expect(count(r.rows, "q")).toBe(0);
    expect(r.gaps.every((g) => g.blocked.pensum_full === 1 && g.blocked.month_target_full === 0)).toBe(true);
  });

  it("weder Monatssoll noch Pensum: never planned; with a target and no Pensum: planned by the target", () => {
    const none = rowsOf(input([person("r", { pensum_pct: null })], []));
    expect(count(none.rows, "r")).toBe(0);
    expect(none.gaps.every((g) => g.blocked.pensum_missing === 1)).toBe(true);
    const i = input([person("r", { pensum_pct: null })], [{ staff_id: "r", month: "2027-07-01", target_minutes: 2 * F, planned_minutes: 0 }]);
    const r = rowsOf(i);
    expect(count(r.rows, "r")).toBe(2);
    expect(verifyDraft(i, r.rows)).toEqual([]);
  });

  it("hard rules stay hard with a target that never binds (days in a row, rest)", () => {
    const i = input([person("w")], [{ staff_id: "w", month: "2027-07-01", target_minutes: 44640, planned_minutes: 0 }]);
    const r = rowsOf(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    // One person, one shift a day: at most 6 days in a row, so July cannot be filled completely.
    expect(count(r.rows, "w")).toBeLessThan(31);
    expect(r.gaps.some((g) => g.blocked.consecutive === 1)).toBe(true);
  });

  it("the independent check finds a proposed row over the target", () => {
    const i = input([person("p")], [{ staff_id: "p", month: "2027-07-01", target_minutes: F, planned_minutes: F }]);
    const v = verifyDraft(i, [{ date: "2027-07-05", station_id: "st", shift_type_id: EARLY.id, staff_id: "p" }]);
    expect(v).toEqual([{ staff_id: "p", date: "2027-07-01", rule: "month_target_full" }]);
  });

  it("spreads by load across persons with and without a target (order only, no rule)", () => {
    const i = input(
      [person("a", { pensum_pct: 50 }), person("b", { pensum_pct: null })],
      [{ staff_id: "b", month: "2027-07-01", target_minutes: 8 * F, planned_minutes: 0 }],
    );
    const r = rowsOf(i);
    expect(verifyDraft(i, r.rows)).toEqual([]);
    expect(count(r.rows, "b")).toBe(8);
    expect(count(r.rows, "a")).toBeGreaterThan(0);
  });
});

describe("HD-3a-F3 month_targets from institution_plan", () => {
  const base = (month_targets?: DraftPlan["month_targets"]): DraftPlan => ({
    result: "ok",
    institution: { id: "i", display_name: "Testheim", simulation: true, role: "lead", min_rest_hours: 11, max_consecutive_days: 6, weekly_target_hours: 42 },
    from: FROM, to: TO, stations: [{ id: "st", name: "St" }], shift_types: [{ ...EARLY }],
    staff: [{ ...person("p") }], absences: [], cells: [], wishes: [],
    ...(month_targets ? { month_targets } : {}),
  }) as unknown as DraftPlan;
  const row = { staff_id: "p", month: "2027-07-01", target_minutes: 900, planned_minutes: 510, remaining_minutes: 390, comparison_minutes: 11160, deviates: true };

  it("passes only entries with a target to the draft", () => {
    const i = draftInputFromPlan(base([row, { ...row, staff_id: "q", target_minutes: null, remaining_minutes: null, deviates: null }]), FROM, TO);
    expect(i?.monthTargets).toEqual([{ staff_id: "p", month: "2027-07-01", target_minutes: 900, planned_minutes: 510 }]);
  });

  it("an older answer without month_targets plans as before (no targets)", () => {
    expect(draftInputFromPlan(base(), FROM, TO)?.monthTargets).toEqual([]);
  });

  it("a malformed entry fails closed (no draft)", () => {
    expect(draftInputFromPlan(base([{ ...row, target_minutes: -5 }]), FROM, TO)).toBeNull();
    expect(draftInputFromPlan(base([{ ...row, month: "2027-07-05" }]), FROM, TO)).toBeNull();
    expect(draftInputFromPlan(base([{ ...row, target_minutes: 900.5 }]), FROM, TO)).toBeNull();
  });

  it("merges the month targets of several reads, each month once", () => {
    const m = mergePlans([base([row]), base([row, { ...row, month: "2027-08-01" }])]);
    expect(m?.month_targets?.map((x) => x.month).sort()).toEqual(["2027-07-01", "2027-08-01"]);
  });
});

describe("HD-3a-F3 monthly target forms (T-2)", () => {
  const form = (o: Record<string, string>) => {
    const f = new FormData();
    for (const [k, v] of Object.entries(o)) f.set(k, v);
    return f;
  };
  it("reads hours as working minutes and «kein Monatssoll» as a delete", () => {
    expect(readMonthTargetForm(form({ month: "2027-07-01", target_choice: "wert", target: "120,5" })))
      .toEqual({ ok: true, value: { month: "2027-07-01", targetMinutes: 7230 } });
    expect(readMonthTargetForm(form({ month: "2027-07-01", target_choice: NO_VALUE, target: "" })))
      .toEqual({ ok: true, value: { month: "2027-07-01", targetMinutes: null } });
  });
  it("refuses a negative, unreadable or contradictory value and a month that is not a first day", () => {
    for (const target of ["-5", "1e2", "12,345", "abc"]) {
      expect(readMonthTargetForm(form({ month: "2027-07-01", target_choice: "wert", target }))).toEqual({ ok: false, error: "target_not_number" });
    }
    expect(readMonthTargetForm(form({ month: "2027-07-01", target: "" }))).toEqual({ ok: false, error: "target_choice_missing" });
    expect(readMonthTargetForm(form({ month: "2027-07-01", target_choice: NO_VALUE, target: "40" }))).toEqual({ ok: false, error: "target_conflict" });
    expect(readMonthTargetForm(form({ month: "2027-07-05", target_choice: "wert", target: "40" }))).toEqual({ ok: false, error: "month_not_valid" });
    expect(readMonthTargetForm(form({ month: "2027-13-01", target_choice: "wert", target: "40" }))).toEqual({ ok: false, error: "month_not_valid" });
  });
  it("carries the shown value (R-6-2 (b) pattern); a missing one sends nothing", () => {
    expect(expectedMonthTarget(form({ was_target: "2400" }))).toEqual({ target_minutes: 2400 });
    expect(expectedMonthTarget(form({ was_target: shownValue(null) }))).toEqual({ target_minutes: null });
    expect(expectedMonthTarget(form({}))).toBeNull();
    expect(readThresholdForm(form({ threshold_choice: "wert", threshold: "8,5" }))).toEqual({ ok: true, value: 8.5 });
    expect(readThresholdForm(form({ threshold_choice: NO_VALUE, threshold: "" }))).toEqual({ ok: true, value: null });
    expect(readThresholdForm(form({ threshold_choice: "wert", threshold: "-1" }))).toEqual({ ok: false, error: "threshold_not_number" });
    expect(expectedThreshold(form({ was_threshold: "8.5" }))).toEqual({ monthly_target_deviation_hours: 8.5 });
  });
  it("words minutes as hours with a decimal comma and every refusal code as a visible text", () => {
    expect(minutesAsHours(7230)).toBe("120,5 h");
    expect(minutesAsHours(2400)).toBe("40 h");
    expect(minutesAsHours(-30)).toBe("-0,5 h");
    for (const code of ["target_not_number", "target_choice_missing", "target_conflict", "target_not_valid", "month_not_valid",
      "threshold_not_number", "threshold_choice_missing", "threshold_conflict", "threshold_not_valid"]) {
      expect(messageText(code)?.kind).toBe("error");
    }
    expect(messageText("monthly_target_saved")?.kind).toBe("ok");
    expect(messageText("monthly_target_removed")?.text).toContain("Wochenbudget");
  });
  it("finds the entry of one person for the month of a date", () => {
    const plan = { month_targets: [{ staff_id: "p", month: "2027-07-01", target_minutes: 2400, planned_minutes: 0, remaining_minutes: 2400, comparison_minutes: null, deviates: null }] };
    expect(monthTargetOf(plan, "p", "2027-07-31")?.target_minutes).toBe(2400);
    expect(monthTargetOf(plan, "p", "2027-08-01")).toBeNull();
    expect(monthTargetOf({}, "p", "2027-07-01")).toBeNull();
  });
});
