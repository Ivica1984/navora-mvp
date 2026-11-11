import { describe, expect, it } from "vitest";
import {
  ASSESSMENT_MINUTES,
  CARE_MINUTES,
  CORRECTION_BACK,
  INTERNAL_CODE,
  durchgangSlots,
  hhmm,
  minutesBack,
  zurichDay,
  zurichMinuteOfDay,
  zurichWall,
} from "../e2e/support/durchgang-time";

// BD-2 (ADR-181): the time helpers of tests/e2e/durchgang-ambulant.spec.ts. Written before the spec.
// 2026-11-11 is in CET (UTC+1): 09:10 UTC is 10:10 in Zurich.
const at = (iso: string) => Date.parse(iso);

describe("Zurich day and wall time", () => {
  it("reads the Zurich calendar day, not the UTC day", () => {
    expect(zurichDay(at("2026-11-11T23:30:00Z"))).toBe("2026-11-12");
    expect(zurichDay(at("2026-11-11T22:59:00Z"))).toBe("2026-11-11");
    expect(zurichDay(at("2026-11-11T10:00:00Z"), 1)).toBe("2026-11-12");
    expect(zurichDay(at("2026-12-31T12:00:00Z"), 1)).toBe("2027-01-01");
  });
  it("formats Swiss wall time in 24 h and the minute of the day", () => {
    expect(zurichWall(at("2026-11-11T09:10:00Z"))).toBe("10:10");
    expect(zurichWall(at("2026-07-01T09:10:00Z"))).toBe("11:10"); // CEST
    expect(zurichMinuteOfDay(at("2026-11-11T09:10:00Z"))).toBe(610);
  });
  it("hhmm pads and refuses out-of-range minutes", () => {
    expect(hhmm(0)).toBe("00:00");
    expect(hhmm(605)).toBe("10:05");
    expect(hhmm(1439)).toBe("23:59");
    expect(() => hhmm(1440)).toThrow(RangeError);
    expect(() => hhmm(-1)).toThrow(RangeError);
    expect(() => hhmm(1.5)).toThrow(RangeError);
  });
});

describe("durchgangSlots", () => {
  it("plans the assessment at the next full five minutes plus five, the care visit 15 minutes after it, both today", () => {
    expect(durchgangSlots(at("2026-11-11T09:10:00Z"))).toEqual({
      assessment: { from: "10:20", to: "11:05" },
      care: { from: "11:20", to: "11:50" },
    });
    expect(durchgangSlots(at("2026-11-11T09:12:30Z"))).toEqual({
      assessment: { from: "10:20", to: "11:05" },
      care: { from: "11:20", to: "11:50" },
    });
  });
  it("keeps the planned durations of the synthetic run", () => {
    const s = durchgangSlots(at("2026-11-11T13:00:00Z"))!;
    const m = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3));
    expect(m(s.assessment.to) - m(s.assessment.from)).toBe(ASSESSMENT_MINUTES);
    expect(m(s.care.to) - m(s.care.from)).toBe(CARE_MINUTES);
    expect(m(s.assessment.from)).toBeGreaterThan(14 * 60);
  });
  it("is null when the care visit would end after 23:40 or a correction would land on the previous day", () => {
    expect(durchgangSlots(at("2026-11-11T21:05:00Z"))).toBeNull(); // 22:05 Zurich → care would end 23:45
    expect(durchgangSlots(at("2026-11-11T21:00:00Z"))?.care.to).toBe("23:40"); // 22:00 Zurich
    expect(durchgangSlots(at("2026-11-11T00:10:00Z"))).toBeNull(); // 01:10 Zurich
    expect(durchgangSlots(at("2026-11-11T00:15:00Z"))).not.toBeNull(); // 01:15
  });
});

describe("F3 corrections of the run (Q-BD-1 option (A))", () => {
  it("keep departure before start and give care time at least the planned minutes", () => {
    for (const [visit, planned] of [["assessment", ASSESSMENT_MINUTES], ["care", CARE_MINUTES]] as const) {
      const back = CORRECTION_BACK[visit];
      expect(back.departed).toBeGreaterThan(back.started);
      expect(back.started).toBeGreaterThanOrEqual(planned);
    }
  });
  it("minutesBack types the Swiss wall time N minutes earlier", () => {
    expect(minutesBack(at("2026-11-11T09:10:00Z"), 55)).toBe("09:15");
  });
});

describe("INTERNAL_CODE (uxa G-6)", () => {
  it("matches internal codes and not ordinary words", () => {
    for (const s of ["D-18", "siehe CR-029", "CGR-176 (1)", "SIG-2"]) expect(s).toMatch(INTERNAL_CODE);
    for (const s of ["Basel-Stadt", "A 45 min", "KVG", "Testlauf: simulierte Einsatzdauer", "CHF 12.00", "BD-2"]) {
      expect(s).not.toMatch(INTERNAL_CODE);
    }
  });
});
