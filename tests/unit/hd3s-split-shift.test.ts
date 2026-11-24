// HD-3s PROBE (red by design until HD-3s is built after HD-3a): the founder's split shift rules of 2026-11-24 ca. 23:10
// (#1712 7145634673) as executable acceptance criteria. Rules and conflict resolution:
// docs/engineering/probes/HD-3s_RULES_DRAFT.md. Synthetic example times of the test home («Beispielwert des Heims»).
import { describe, expect, it } from "vitest";
import {
  dailyTargetHint,
  daySpanMinutes,
  restMinutesBetween,
  splitShiftSpans,
  splitWorkDays,
  splitWorkMinutes,
  validateSplitShift,
  type SplitShiftTimes,
} from "@/features/home-plan/split";

const testHome: SplitShiftTimes = { block1: { starts_at: "07:00", ends_at: "12:00" }, block2: { starts_at: "16:30", ends_at: "20:00" } };
const t = (a: string, b: string, c: string, d: string): SplitShiftTimes => ({ block1: { starts_at: a, ends_at: b }, block2: { starts_at: c, ends_at: d } });

describe("HD-3s V: invalid input is refused, first failing check wins", () => {
  it("accepts the test home's split shift", () => {
    expect(validateSplitShift(testHome)).toEqual({ ok: true });
  });
  it.each([
    ["7:00", "12:00", "16:30", "20:00", "time_format"],
    ["07:00", "12:00", "16:30", "24:00", "time_format"],
    ["07:00", "07:00", "16:30", "20:00", "zero_length"],
    ["07:00", "12:00", "22:00", "02:00", "block_crosses_midnight"],
    ["16:30", "20:00", "07:00", "12:00", "block_order"],
    ["07:00", "12:00", "11:00", "15:00", "block_order"],
    ["07:00", "12:00", "12:00", "16:00", "no_pause"],
  ])("%s–%s + %s–%s => %s", (a, b, c, d, reason) => {
    expect(validateSplitShift(t(a, b, c, d))).toEqual({ ok: false, reason });
  });
  it("names the first failing check when several fail (time_format before block_order)", () => {
    expect(validateSplitShift(t("25:00", "12:00", "06:00", "07:00"))).toEqual({ ok: false, reason: "time_format" });
  });
});

describe("HD-3s S2: the pause is not working time", () => {
  it("07:00–12:00 + 16:30–20:00 = 510 minutes (5 h + 3 h 30)", () => {
    expect(splitWorkMinutes("2027-02-10", testHome)).toBe(510);
  });
  it("is unchanged on both DST days (blocks lie outside 02:00–03:00)", () => {
    expect(splitWorkMinutes("2027-03-28", testHome)).toBe(510);
    expect(splitWorkMinutes("2027-10-31", testHome)).toBe(510);
  });
  it("gives two spans with the pause between them", () => {
    const [a, b] = splitShiftSpans("2027-02-10", testHome);
    expect((b.start - a.end) / 60_000).toBe(270);
  });
});

describe("HD-3s S3: one split shift is one working day", () => {
  it("touches only its work date", () => {
    expect(splitWorkDays("2027-02-10", testHome)).toEqual(["2027-02-10"]);
  });
});

describe("HD-3s S4: rest starts after the second block; never between the two blocks", () => {
  it("20:00 → next day 07:00 is 11 h", () => {
    const split = splitShiftSpans("2027-02-10", testHome);
    // Early shift 07:00–15:30 on 11.02.2027 (CET = UTC+1).
    const nextEarly = [{ start: Date.UTC(2027, 1, 11, 6, 0), end: Date.UTC(2027, 1, 11, 14, 30) }];
    expect(restMinutesBetween(split, nextEarly)).toBe(660);
  });
  it("20:00 → next day 06:30 is 10 h 30 (below a home's 11 h the draft blocks it with «rest»)", () => {
    const split = splitShiftSpans("2027-02-10", testHome);
    const next = [{ start: Date.UTC(2027, 1, 11, 5, 30), end: Date.UTC(2027, 1, 11, 14, 0) }];
    expect(restMinutesBetween(split, next)).toBe(630);
  });
  it("the pause of 4 h 30 is not a rest gap (a split shift alone is never a rest violation)", () => {
    const [a, b] = splitShiftSpans("2027-02-10", testHome);
    expect(restMinutesBetween([a, b], [])).toBe(Number.POSITIVE_INFINITY);
  });
});

describe("HD-3s S5: daily target is a hint, never a block", () => {
  it("42 h / 5 = 504 min; 510 worked => +6 min hint", () => {
    expect(dailyTargetHint(510, 42)).toEqual({ targetMinutes: 504, diffMinutes: 6 });
  });
  it("39.5 h (founder's example of a Basel hospital) / 5 = 474 min => +36 min hint", () => {
    expect(dailyTargetHint(510, 39.5)).toEqual({ targetMinutes: 474, diffMinutes: 36 });
  });
  it("no hint when equal", () => {
    expect(dailyTargetHint(504, 42)).toBeNull();
  });
  it("no weekly target entered => no hint, nothing invented", () => {
    expect(dailyTargetHint(510, null)).toBeNull();
  });
});

describe("HD-3s R-j (Art. 10 Abs. 3 ArG, [A] p. 4): the working day including the pause lies within 14 h", () => {
  it("07:00–12:00 + 16:30–20:00 spans 13 h (780 min), allowed", () => {
    expect(daySpanMinutes("2027-02-10", testHome)).toBe(780);
  });
  it("06:00–11:00 + 16:00–20:30 spans 14 h 30 (870 min), above 14 h", () => {
    expect(daySpanMinutes("2027-02-10", t("06:00", "11:00", "16:00", "20:30"))).toBe(870);
  });
});

// --- evaluateShift: all rules in their fixed order (draft §5) --------------------------------------------------------------
import {
  DEFAULT_LIMITS,
  evaluateShift, modelAllows, requiredPauseMinutes, validateLimits, type Candidate, type ShiftDef } from "@/features/home-plan/split";

const SPLIT: ShiftDef = { cls: "split", blocks: [{ starts_at: "07:00", ends_at: "12:00" }, { starts_at: "16:30", ends_at: "20:00" }] };
const EARLY: ShiftDef = { cls: "early", blocks: [{ starts_at: "07:00", ends_at: "15:30" }] };
const LATE: ShiftDef = { cls: "late", blocks: [{ starts_at: "14:30", ends_at: "23:00" }] };
const NIGHT: ShiftDef = { cls: "night", blocks: [{ starts_at: "22:30", ends_at: "07:15" }] };
const LIMITS = { ...DEFAULT_LIMITS, weeklyTargetHours: 42 };
const base = (over: Partial<Candidate> = {}): Candidate => ({
  person: { pensum_pct: 100, shift_model: "any", absences: [] },
  existing: [],
  date: "2027-02-10",
  def: SPLIT,
  limits: LIMITS,
  ...over,
});

describe("HD-3s evaluateShift: invalid input is refused before any rule", () => {
  it("a broken split shift => invalid_shift", () => {
    expect(evaluateShift(base({ def: { cls: "split", blocks: [{ starts_at: "12:00", ends_at: "16:00" }, { starts_at: "07:00", ends_at: "11:00" }] } }))).toEqual({ result: "invalid_shift", reason: "block_order" });
  });
  it("three blocks => block_count", () => {
    expect(evaluateShift(base({ def: { cls: "split", blocks: [...SPLIT.blocks, { starts_at: "21:00", ends_at: "22:00" }] } }))).toEqual({ result: "invalid_shift", reason: "block_count" });
  });
  it.each([
    [{ minRestHours: 0 }, "min_rest_hours"],
    [{ minRestHours: 10.5 }, "min_rest_hours"],
    [{ maxConsecutiveDays: 15 }, "max_consecutive_days"],
    [{ weeklyTargetHours: 0 }, "weekly_target_hours"],
    [{ maxWeeklyHours: Number.NaN }, "max_weekly_hours"],
    [{ maxDaySpanHours: 25 }, "max_day_span_hours"],
    [{ nightMaxWorkHours: 10, nightMaxSpanHours: 9 }, "night_limits"],
    [{ workDaysPerWeek: 0 }, "work_days_per_week"],
    [{ weeklyTargetHours: null }, "pensum_reference_missing"],
  ])("limits %o => %s (fail closed)", (over, reason) => {
    expect(validateLimits({ ...LIMITS, ...over })).toEqual({ ok: false, reason });
    expect(evaluateShift(base({ limits: { ...LIMITS, ...over } }))).toEqual({ result: "invalid_limits", reason });
  });
});

describe("HD-3s evaluateShift: each rule, and the first failing rule wins", () => {
  it("the test home's split shift is ok: 510 worked minutes, one hint: daily target +6 min (no block exceeds 5.5 h, so no pause hint)", () => {
    const r = evaluateShift(base());
    expect(r).toEqual({ result: "ok", workMinutes: 510, hints: [{ kind: "daily_target", targetMinutes: 504, diffMinutes: 6 }], mark: "Arbeitszeitgesetz nicht abschliessend geprüft" });
  });
  it("R-b before everything: no Pensum => pensum_missing even if also absent", () => {
    expect(evaluateShift(base({ person: { pensum_pct: null, shift_model: "early_only", absences: [{ starts_on: "2027-02-10", ends_on: "2027-02-10" }] } }))).toMatchObject({ reason: "pensum_missing" });
  });
  it("R-c (founder 00:20): a split shift for «any» and «no_night», never for early/late/night only", () => {
    expect(modelAllows("any", "split")).toBe(true);
    expect(modelAllows("no_night", "split")).toBe(true);
    for (const m of ["early_only", "late_only", "night_only"] as const) expect(modelAllows(m, "split")).toBe(false);
    expect(evaluateShift(base({ person: { pensum_pct: 100, shift_model: "no_night", absences: [] } }))).toMatchObject({ result: "ok" });
    expect(evaluateShift(base({ person: { pensum_pct: 100, shift_model: "late_only", absences: [] } }))).toMatchObject({ reason: "shift_model" });
  });
  it("S5 (founder 00:20): weekly target ÷ the home's working days per week (field, default 5)", () => {
    expect(dailyTargetHint(474, 39.5)).toBeNull();
    expect(dailyTargetHint(510, 42, 6)).toEqual({ targetMinutes: 420, diffMinutes: 90 });
  });
  it("R-d: absence on the work date", () => {
    expect(evaluateShift(base({ person: { pensum_pct: 100, shift_model: "any", absences: [{ starts_on: "2027-02-10", ends_on: "2027-02-12" }] } }))).toMatchObject({ reason: "absent" });
  });
  it("R-e / K3: a shift inside the pause is busy, not rest", () => {
    const inPause: ShiftDef = { cls: null, blocks: [{ starts_at: "12:30", ends_at: "16:00" }] };
    expect(evaluateShift(base({ existing: [{ date: "2027-02-10", def: inPause }] }))).toMatchObject({ reason: "busy" });
  });
  it("R-j: 06:00–11:00 + 16:00–20:30 spans 14 h 30 > 14 h => day_span", () => {
    const long: ShiftDef = { cls: "split", blocks: [{ starts_at: "06:00", ends_at: "11:00" }, { starts_at: "16:00", ends_at: "20:30" }] };
    expect(evaluateShift(base({ def: long }))).toMatchObject({ reason: "day_span" });
  });
  it("R-f: rest starts after block 2: split 20:00 → early 06:30 next day (10 h 30) => rest; → 07:00 (11 h) ok", () => {
    const early0630: ShiftDef = { cls: "early", blocks: [{ starts_at: "06:30", ends_at: "15:00" }] };
    expect(evaluateShift(base({ existing: [{ date: "2027-02-11", def: early0630 }] }))).toMatchObject({ reason: "rest" });
    expect(evaluateShift(base({ existing: [{ date: "2027-02-11", def: EARLY }] }))).toMatchObject({ result: "ok" });
  });
  it("R-f: late 14:30–23:00 the day before => only 8 h rest before block 1 => rest", () => {
    expect(evaluateShift(base({ existing: [{ date: "2027-02-09", def: LATE }] }))).toMatchObject({ reason: "rest" });
  });
  it("R-g: a split shift counts as one day; 6 days before it => the 7th is consecutive", () => {
    const six = [4, 5, 6, 7, 8, 9].map((d) => ({ date: `2027-02-0${d}`, def: EARLY }));
    expect(evaluateShift(base({ existing: six.slice(1), limits: { ...LIMITS, weeklyTargetHours: 80, maxWeeklyHours: 80 } }))).toMatchObject({ result: "ok" });
    expect(evaluateShift(base({ existing: six, limits: { ...LIMITS, weeklyTargetHours: 80, maxWeeklyHours: 80 } }))).toMatchObject({ reason: "consecutive" });
  });
  it("R-k: the test home's night 22:30–07:15 (8 h 45) is ok; 21:00–07:00 (10 h) => night", () => {
    expect(evaluateShift(base({ def: NIGHT }))).toMatchObject({ result: "ok" });
    expect(evaluateShift(base({ def: { cls: "night", blocks: [{ starts_at: "21:00", ends_at: "07:00" }] } }))).toMatchObject({ reason: "night" });
  });
  it("R-h: 50 % of 42 h = 1260 min; two earlier early shifts (1020) + split (510) => pensum_full", () => {
    const week = [{ date: "2027-02-08", def: EARLY }, { date: "2027-02-12", def: EARLY }];
    expect(evaluateShift(base({ person: { pensum_pct: 50, shift_model: "any", absences: [] }, existing: week }))).toMatchObject({ reason: "pensum_full" });
  });
  it("R-i / K8: with a weekly target of 60 h, the 50 h law cap binds after the Pensum cap", () => {
    const week = [8, 9].map((d) => ({ date: `2027-02-0${d}`, def: EARLY })).concat([11, 12, 13].map((d) => ({ date: `2027-02-${d}`, def: EARLY })));
    // 5 × 510 = 2550 + 510 = 3060 > 3000 (50 h) but ≤ 3600 (100 % of 60 h)
    expect(evaluateShift(base({ existing: week, limits: { ...LIMITS, weeklyTargetHours: 60 } }))).toMatchObject({ reason: "weekly_max" });
  });
  it("same input in any order => the same result (deterministic)", () => {
    const ex = [{ date: "2027-02-11", def: EARLY }, { date: "2027-02-08", def: LATE }];
    expect(evaluateShift(base({ existing: ex }))).toEqual(evaluateShift(base({ existing: [...ex].reverse() })));
  });
});

describe("HD-3s S6 pause (Art. 15 ArG)", () => {
  it.each([[330, 0], [331, 15], [421, 30], [541, 60]])("%i min => %i min pause", (w, p) => {
    expect(requiredPauseMinutes(w)).toBe(p);
  });
});
