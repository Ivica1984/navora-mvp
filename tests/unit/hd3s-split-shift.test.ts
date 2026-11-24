// HD-3s PROBE (red by design until HD-3s is built after HD-3a): the founder's split shift rules of 2026-11-24 ca. 23:10
// (#1712 7145634673) as executable acceptance criteria. Rules and conflict resolution:
// docs/engineering/probes/HD-3s_RULES_DRAFT.md. Synthetic example times of the test home («Beispielwert des Heims»).
import { describe, expect, it } from "vitest";
import {
  dailyTargetHint,
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
