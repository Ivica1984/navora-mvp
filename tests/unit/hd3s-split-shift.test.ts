// HD-3s «geteilter Dienst» (brief docs/agents/briefs/HD-3s.md; founder FE-127 (3); rules draft
// docs/engineering/probes/HD-3s_RULES_DRAFT.md). The probe's shape and S5 cases, now against the integrated solver
// (`draft.ts`) and its independent verifier. Synthetic example times («Beispielwert des Heims»).
import { describe, expect, it } from "vitest";
import {
  buildDraft,
  draftContextRange,
  modelAllows,
  shiftMinutes,
  verifyDraft,
  type DraftInput,
  type DraftShiftType,
  type DraftStaff,
} from "@/features/home-plan/draft";
import { draftInputFromPlan } from "@/features/home-plan/draft-screen";
import { readShiftClassForm, SELECTABLE_SHIFT_CLASSES } from "@/features/home-plan/planning-inputs";
import { addDays, type AssignedPerson, type PlanCell } from "@/features/home-plan/rules";
import {
  blocksOf,
  dailyTargetHint,
  dailyTargetText,
  shiftTimesText,
  validateSplitShift,
  type SplitShiftTimes,
} from "@/features/home-plan/split";

const t = (a: string, b: string, c: string, d: string): SplitShiftTimes => ({
  block1: { starts_at: a, ends_at: b },
  block2: { starts_at: c, ends_at: d },
});

describe("HD-3s V1–V5: invalid input is refused, first failing check wins (same codes as the database)", () => {
  it("accepts the test home's split shift", () => {
    expect(validateSplitShift(t("07:00", "12:00", "16:30", "20:00"))).toEqual({ ok: true });
  });
  it.each([
    ["7:00", "12:00", "16:30", "20:00", "time_format"],
    ["07:00", "12:00", "16:30", "24:00", "time_format"],
    ["07:00", "07:00", "16:30", "20:00", "zero_length"],
    ["07:00", "12:00", "22:00", "02:00", "block_crosses_midnight"],
    ["16:30", "20:00", "07:00", "12:00", "block_order"],
    ["07:00", "12:00", "11:00", "15:00", "block_order"],
    ["07:00", "12:00", "12:00", "16:00", "no_pause"],
    ["07:00", "07:00", "07:00", "07:00", "zero_length"],
  ])("%s–%s + %s–%s => %s", (a, b, c, d, reason) => {
    expect(validateSplitShift(t(a, b, c, d))).toEqual({ ok: false, reason });
  });
  it("names the first failing check when several fail (time_format before block_order)", () => {
    expect(validateSplitShift(t("25:00", "12:00", "06:00", "07:00"))).toEqual({ ok: false, reason: "time_format" });
  });
});

const SPLIT: DraftShiftType = {
  id: "t4-split", code: "G", label: "Geteilt", starts_at: "07:00", ends_at: "20:00", shift_class: "split",
  block1_ends_at: "11:30", block2_starts_at: "16:00",
};
const EARLY: DraftShiftType = { id: "t1-early", code: "F", label: "Früh", starts_at: "07:00", ends_at: "15:30", shift_class: "early" };
const EARLY0630: DraftShiftType = { id: "t0-early", code: "F0", label: "Früh früh", starts_at: "06:30", ends_at: "14:00", shift_class: "early" };
const MIDDAY: DraftShiftType = { id: "t5-mid", code: "M", label: "Mittag", starts_at: "12:00", ends_at: "15:00", shift_class: null };
const LIMITS = { minRestHours: 11, maxConsecutiveDays: 6, fullTimeMinutesPerWeek: 42 * 60 };

describe("HD-3s S2: the pause is not working time", () => {
  it("07:00–11:30 + 16:00–20:00 = 510 minutes, not the 780 minutes of the whole day", () => {
    expect(shiftMinutes("2027-02-10", SPLIT)).toBe(510);
    expect(shiftMinutes("2027-02-10", EARLY)).toBe(510);
  });
  it("is unchanged on both DST days (blocks lie outside 02:00–03:00)", () => {
    expect(shiftMinutes("2027-03-28", SPLIT)).toBe(510);
    expect(shiftMinutes("2027-10-31", SPLIT)).toBe(510);
  });
  it("words the two blocks", () => {
    expect(blocksOf(SPLIT)).toHaveLength(2);
    expect(shiftTimesText(SPLIT)).toBe("07:00–11:30 und 16:00–20:00");
    expect(shiftTimesText(EARLY)).toBe("07:00–15:30");
  });
});

describe("HD-3s S5: daily target is a hint, never a block", () => {
  it("42 h / 5 = 504 min; 510 worked => +6 min", () => {
    expect(dailyTargetHint(510, 42, 5)).toEqual({ targetMinutes: 504, diffMinutes: 6 });
    expect(dailyTargetText(510, { targetMinutes: 504, diffMinutes: 6 })).toBe(
      "Arbeitszeit 8 h 30 (ohne Pause); Soll pro Tag 8 h 24: 6 min mehr. Hinweis, keine Sperre.",
    );
  });
  it("39.5 h / 5 = 474 min => +36 min; with 6 working days 420 min => +90 min", () => {
    expect(dailyTargetHint(510, 39.5, 5)).toEqual({ targetMinutes: 474, diffMinutes: 36 });
    expect(dailyTargetHint(510, 42, 6)).toEqual({ targetMinutes: 420, diffMinutes: 90 });
  });
  it("no hint when equal, without a weekly target, or with days outside 1–7", () => {
    expect(dailyTargetHint(504, 42, 5)).toBeNull();
    expect(dailyTargetHint(510, null, 5)).toBeNull();
    expect(dailyTargetHint(510, 42, 0)).toBeNull();
    expect(dailyTargetHint(510, 42, 8)).toBeNull();
  });
});

describe("HD-3s R-c: a split shift only for «alle Dienste» and «keine Nacht»", () => {
  it("never for «nur Früh», «nur Spät», «nur Nacht»", () => {
    expect(modelAllows("any", "split")).toBe(true);
    expect(modelAllows("no_night", "split")).toBe(true);
    for (const m of ["early_only", "late_only", "night_only"] as const) expect(modelAllows(m, "split")).toBe(false);
  });
  it("the class form never offers `split` for a one-block type", () => {
    expect(SELECTABLE_SHIFT_CLASSES).toEqual(["early", "late", "night"]);
    const f = new FormData();
    f.set("class", "split");
    expect(readShiftClassForm(f)).toEqual({ ok: false, error: "shift_class_unknown" });
  });
});

// --- The solver with split shifts ---------------------------------------------------------------------------------------
const person = (id: string, over: Partial<DraftStaff> = {}): DraftStaff => ({
  id, display_name: id, grade: "fage_efz", home_station_id: null, active: true, pensum_pct: 100, shift_model: "any", ...over,
});
type Rule = { total: number };
function input(o: {
  from: string;
  to: string;
  types: DraftShiftType[];
  staff: DraftStaff[];
  rules: Record<string, Rule | null>;
  existing?: Array<{ date: string; type: string; staff: string }>;
  limits?: Partial<DraftInput["limits"]>;
}): DraftInput {
  const limits = { ...LIMITS, ...o.limits };
  const ctx = draftContextRange(o.from, o.to, limits);
  const cells: PlanCell[] = [];
  let n = 0;
  for (let d = ctx.from; d <= ctx.to; d = addDays(d, 1)) {
    for (const ty of o.types) {
      const rule = o.rules[ty.id] ?? null;
      const assigned: AssignedPerson[] = (o.existing ?? [])
        .filter((e) => e.date === d && e.type === ty.id)
        .map((e) => ({ assignment_id: `a${n++}`, staff_id: e.staff, display_name: e.staff, grade: "fage_efz", absent: false, inactive: false }));
      cells.push({
        date: d, station_id: "s1", shift_type_id: ty.id, required_total: rule ? rule.total : null, required_grade: null,
        required_grade_count: 0, example: true, assigned, present: assigned.length, grade_present: 0,
        missing: rule ? Math.max(rule.total - assigned.length, 0) : 0,
        status: !rule ? "no_rule" : assigned.length >= rule.total ? "ok" : "gap", external_covered: 0, order: null,
      });
    }
  }
  return { from: o.from, to: o.to, shiftTypes: o.types, staff: o.staff, absences: [], cells, limits };
}
function draft(i: DraftInput) {
  const r = buildDraft(i);
  if (r.result !== "ok") throw new Error(r.result);
  return r;
}
const MON = "2027-02-08";

describe("HD-3s in the draft: the same hard rules, with the founder's split shift rules", () => {
  it("plans a split shift and the verifier finds 0 violations", () => {
    const i = input({ from: MON, to: addDays(MON, 6), types: [SPLIT], staff: [person("a"), person("b")], rules: { [SPLIT.id]: { total: 1 } } });
    const r = draft(i);
    expect(r.rows).toHaveLength(7);
    expect(r.gaps).toEqual([]);
    expect(verifyDraft(i, r.rows)).toEqual([]);
  });
  it("R-h: 25 % of 42 h = 630 min takes one split shift (510 min); counted with the pause (780 min) it would not", () => {
    const i = input({ from: MON, to: MON, types: [SPLIT], staff: [person("a", { pensum_pct: 25 })], rules: { [SPLIT.id]: { total: 1 } } });
    const r = draft(i);
    expect(r.rows).toEqual([{ date: MON, station_id: "s1", shift_type_id: SPLIT.id, staff_id: "a" }]);
    expect(verifyDraft(i, r.rows)).toEqual([]);
  });
  it("R-h: two split shifts (1020 min) are over 25 % (630 min): the second stays a gap with «Pensum ausgeschöpft»", () => {
    const i = input({ from: MON, to: addDays(MON, 1), types: [SPLIT], staff: [person("a", { pensum_pct: 25 })], rules: { [SPLIT.id]: { total: 1 } } });
    const r = draft(i);
    expect(r.rows).toHaveLength(1);
    expect(r.gaps).toHaveLength(1);
    expect(r.gaps[0].blocked.pensum_full).toBe(1);
  });
  it("K1: a split shift alone is never a rest violation (4 h 30 between its blocks)", () => {
    const i = input({ from: MON, to: MON, types: [SPLIT], staff: [person("a")], rules: { [SPLIT.id]: { total: 1 } } });
    expect(draft(i).rows).toHaveLength(1);
  });
  it("K3: a shift inside the pause is `busy` for the person of the split shift", () => {
    const i = input({
      from: MON, to: MON, types: [SPLIT, MIDDAY], staff: [person("a")], rules: { [MIDDAY.id]: { total: 1 } },
      existing: [{ date: MON, type: SPLIT.id, staff: "a" }],
    });
    const r = draft(i);
    expect(r.rows).toEqual([]);
    expect(r.gaps[0].blocked.busy).toBe(1);
  });
  it("R-f: rest starts after block 2: 20:00 → 07:00 (11 h) allowed, 20:00 → 06:30 (10 h 30) refused", () => {
    const base = { from: addDays(MON, 1), to: addDays(MON, 1), staff: [person("a")], existing: [{ date: MON, type: SPLIT.id, staff: "a" }] };
    const ok = input({ ...base, types: [SPLIT, EARLY], rules: { [EARLY.id]: { total: 1 } } });
    expect(draft(ok).rows).toHaveLength(1);
    expect(verifyDraft(ok, draft(ok).rows)).toEqual([]);
    const tooShort = input({ ...base, types: [SPLIT, EARLY0630], rules: { [EARLY0630.id]: { total: 1 } } });
    const r = draft(tooShort);
    expect(r.rows).toEqual([]);
    expect(r.gaps[0].blocked.rest).toBe(1);
  });
  it("R-g: a split shift is one working day (2 days in a row allowed: day 3 is refused, day 2 is not)", () => {
    const i = input({
      from: MON, to: addDays(MON, 2), types: [SPLIT], staff: [person("a")], rules: { [SPLIT.id]: { total: 1 } },
      limits: { maxConsecutiveDays: 2 },
    });
    const r = draft(i);
    expect(r.rows.map((x) => x.date)).toEqual([MON, addDays(MON, 1)]);
    expect(r.gaps[0].blocked.consecutive).toBe(1);
    expect(verifyDraft(i, r.rows)).toEqual([]);
  });
  it("negative: «nur Früh» never gets a split shift; «keine Nacht» does", () => {
    const i = input({
      from: MON, to: MON, types: [SPLIT], staff: [person("e", { shift_model: "early_only" }), person("n", { shift_model: "no_night" })],
      rules: { [SPLIT.id]: { total: 2 } },
    });
    const r = draft(i);
    expect(r.rows.map((x) => x.staff_id)).toEqual(["n"]);
    expect(r.gaps[0].blocked.shift_model).toBe(1);
    expect(verifyDraft(i, [{ date: MON, station_id: "s1", shift_type_id: SPLIT.id, staff_id: "e" }])).toContainEqual({
      staff_id: "e", date: MON, rule: "shift_model",
    });
  });
  it("minimum staffing (fail closed): a person in the split shift never fills the early shift gap", () => {
    const i = input({
      from: MON, to: MON, types: [SPLIT, EARLY], staff: [person("a")], rules: { [EARLY.id]: { total: 1 } },
      existing: [{ date: MON, type: SPLIT.id, staff: "a" }],
    });
    const r = draft(i);
    expect(r.rows).toEqual([]);
    expect(r.predicted.find((p) => p.shift_type_id === EARLY.id)?.status).toBe("gap");
  });
  it("the verifier counts the pause apart from the solver: a split row over Pensum is named", () => {
    const i = input({ from: MON, to: addDays(MON, 1), types: [SPLIT], staff: [person("a", { pensum_pct: 25 })], rules: {} });
    const rows = [MON, addDays(MON, 1)].map((date) => ({ date, station_id: "s1", shift_type_id: SPLIT.id, staff_id: "a" }));
    expect(verifyDraft(i, rows).map((v) => v.rule)).toContain("pensum_full");
  });
});

describe("HD-3s screen input (fail closed)", () => {
  const plan = (types: Array<Record<string, unknown>>) =>
    ({
      institution: { id: "h", display_name: "H", simulation: true, role: "lead", min_rest_hours: 11, max_consecutive_days: 6, weekly_target_hours: 42 },
      from: MON, to: MON, stations: [{ id: "s1", name: "S" }], shift_types: types, staff: [], absences: [], cells: [], wishes: [],
    }) as unknown as Parameters<typeof draftInputFromPlan>[0];
  it("passes both blocks of a split type into the solver", () => {
    const i = draftInputFromPlan(plan([{ ...SPLIT }]), MON, MON);
    expect(i?.shiftTypes[0]).toMatchObject({ shift_class: "split", block1_ends_at: "11:30", block2_starts_at: "16:00" });
  });
  it("refuses a split type without blocks, blocks without the class, or broken blocks (no draft)", () => {
    expect(draftInputFromPlan(plan([{ ...SPLIT, block1_ends_at: null, block2_starts_at: null }]), MON, MON)).toBeNull();
    expect(draftInputFromPlan(plan([{ ...EARLY, block1_ends_at: "11:00", block2_starts_at: "12:00" }]), MON, MON)).toBeNull();
    expect(draftInputFromPlan(plan([{ ...SPLIT, block2_starts_at: "11:30" }]), MON, MON)).toBeNull();
  });
});
