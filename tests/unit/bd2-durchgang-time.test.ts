import { describe, expect, it } from "vitest";
import {
  ASSESSMENT_MINUTES,
  CARE_MINUTES,
  CORRECTION_BACK,
  INTERNAL_CODE,
  correctedSpan,
  durchgangSlots,
  effectiveEventTimes,
  hhmm,
  sequenceViolations,
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
    // CGR-180 (1): the assessment's departure is corrected 120 minutes back; 20 minutes margin to midnight → 02:20.
    expect(durchgangSlots(at("2026-11-11T01:15:00Z"))).toBeNull(); // 02:15 Zurich
    expect(durchgangSlots(at("2026-11-11T01:20:00Z"))).not.toBeNull(); // 02:20
  });
});

describe("F3 corrections of the run (Q-BD-1 option (A))", () => {
  it("keep departure before start before completion and give care time at least the planned minutes", () => {
    for (const [visit, planned] of [["assessment", ASSESSMENT_MINUTES], ["care", CARE_MINUTES]] as const) {
      const back: { departed: number; started: number; completed?: number } = CORRECTION_BACK[visit];
      const completed = back.completed ?? 0;
      expect(back.departed).toBeGreaterThan(back.started);
      expect(back.started).toBeGreaterThan(completed);
      expect(back.started - completed).toBeGreaterThanOrEqual(planned);
    }
  });
  it("minutesBack types the Swiss wall time N minutes earlier", () => {
    expect(minutesBack(at("2026-11-11T09:10:00Z"), 55)).toBe("09:15");
  });
});

// CGR-180 (1) (`cra` 13:30): the effective times of the run must form a possible care sequence: the care visit starts
// at or after the assessment's completion, and the same nurse's two visits do not overlap.
describe("CGR-180 (1): the corrected times form a possible sequence", () => {
  const T = at("2026-11-11T09:10:00Z");
  const min = 60_000;

  it("correctedSpan sets each event N minutes before the moment of correction; an uncorrected completion stays at it", () => {
    expect(correctedSpan(T, { departed: 40, started: 35 })).toEqual({ departed: T - 40 * min, started: T - 35 * min, completed: T });
    expect(correctedSpan(T, { departed: 120, started: 115, completed: 65 }))
      .toEqual({ departed: T - 120 * min, started: T - 115 * min, completed: T - 65 * min });
  });

  it("holds for the run's corrections whenever the care visit is corrected after the assessment (any gap ≥ 0)", () => {
    for (const gapMin of [0, 1, 3, 10, 30, 120]) {
      const a = correctedSpan(T, CORRECTION_BACK.assessment);
      const c = correctedSpan(T + gapMin * min, CORRECTION_BACK.care);
      expect(sequenceViolations(a, c), `gap ${gapMin} min`).toEqual([]);
    }
  });

  it("names the two faults of the old corrections (55/50 and 40/35, completion uncorrected): CGR-180 regression", () => {
    const a = correctedSpan(T, { departed: 55, started: 50 });
    const c = correctedSpan(T + 3 * min, { departed: 40, started: 35 });
    expect(sequenceViolations(a, c)).toEqual(["care_starts_before_assessment_completed", "visits_overlap"]);
  });

  it("allows a care visit that departs exactly at the assessment's completion, and refuses one a minute earlier", () => {
    const a = { departed: T - 60 * min, started: T - 55 * min, completed: T - 10 * min };
    expect(sequenceViolations(a, { departed: T - 10 * min, started: T - 5 * min, completed: T })).toEqual([]);
    expect(sequenceViolations(a, { departed: T - 11 * min, started: T - 5 * min, completed: T })).toEqual(["visits_overlap"]);
  });

  it("effectiveEventTimes takes the newest correction per event (as private.effective_event_time), else the recorded time", () => {
    const events = [
      { id: 1, event_type: "departed", occurred_at: "2026-11-11T09:00:00Z" },
      { id: 2, event_type: "started", occurred_at: "2026-11-11T09:01:00Z" },
      { id: 3, event_type: "completed", occurred_at: "2026-11-11T09:02:00Z" },
    ];
    const corrections = [
      { id: 10, event_id: 1, corrected_at: "2026-11-11T07:00:00Z", created_at: "2026-11-11T09:03:00Z" },
      { id: 11, event_id: 1, corrected_at: "2026-11-11T07:30:00Z", created_at: "2026-11-11T09:04:00Z" },
      { id: 12, event_id: 2, corrected_at: "2026-11-11T07:40:00Z", created_at: "2026-11-11T09:04:00Z" },
      { id: 13, event_id: 2, corrected_at: "2026-11-11T07:35:00Z", created_at: "2026-11-11T09:04:00Z" }, // same time: higher id wins
    ];
    expect(effectiveEventTimes(events, corrections)).toEqual({
      departed: at("2026-11-11T07:30:00Z"),
      started: at("2026-11-11T07:35:00Z"),
      completed: at("2026-11-11T09:02:00Z"),
    });
  });

  it("effectiveEventTimes refuses a timeline without departure, start or completion", () => {
    expect(() => effectiveEventTimes([{ id: 1, event_type: "departed", occurred_at: "2026-11-11T09:00:00Z" }], []))
      .toThrow(/started/);
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
