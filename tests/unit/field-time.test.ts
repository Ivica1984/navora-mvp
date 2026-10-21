import { describe, expect, it } from "vitest";
import {
  computeVisitTimes,
  formatMinutes,
  parseEvents,
  zurichDate,
  zurichLocalToIso,
  zurichTime,
} from "@/features/field/time";

const t = (hhmm: string) => `2026-10-21T${hhmm}:00Z`;

describe("visit times from events (F2)", () => {
  it("separates travel, care and pause", () => {
    const times = computeVisitTimes([
      { type: "departed", at: t("08:00") },
      { type: "started", at: t("08:20") },
      { type: "paused", at: t("08:50") },
      { type: "resumed", at: t("09:00") },
      { type: "completed", at: t("09:15") },
    ]);
    expect(times).toEqual({ travelMinutes: 20, careMinutes: 45, pauseMinutes: 10, inconsistent: false });
  });

  it("counts up to now while travelling, caring or paused", () => {
    const now = new Date(t("08:30"));
    expect(computeVisitTimes([{ type: "departed", at: t("08:00") }], now).travelMinutes).toBe(30);
    expect(computeVisitTimes([{ type: "started", at: t("08:10") }], now)).toMatchObject({ careMinutes: 20, travelMinutes: null });
    expect(
      computeVisitTimes([{ type: "started", at: t("08:00") }, { type: "paused", at: t("08:20") }], now)
    ).toMatchObject({ careMinutes: 20, pauseMinutes: 10 });
  });

  it("without departure there is no travel time (not zero)", () => {
    expect(computeVisitTimes([{ type: "started", at: t("08:00") }, { type: "completed", at: t("08:30") }]))
      .toMatchObject({ travelMinutes: null, careMinutes: 30, pauseMinutes: null });
  });

  it("no events → nothing known", () => {
    expect(computeVisitTimes([])).toEqual({ travelMinutes: null, careMinutes: null, pauseMinutes: null, inconsistent: false });
  });

  it("flags out-of-order timelines and never returns negative minutes", () => {
    const times = computeVisitTimes([
      { type: "started", at: t("09:00") },
      { type: "completed", at: t("08:00") },
    ]);
    expect(times.inconsistent).toBe(true);
    expect(times.careMinutes).toBe(0);
  });

  it("parses only well-formed events", () => {
    expect(parseEvents(null)).toEqual([]);
    expect(parseEvents([{ type: "started", at: t("08:00") }, { type: 1 }, { type: "x", at: "nope" }]))
      .toEqual([{ type: "started", at: t("08:00") }]);
  });

  it("formats minutes", () => {
    expect(formatMinutes(null)).toBe("–");
    expect(formatMinutes(45)).toBe("45 min");
    expect(formatMinutes(60)).toBe("1 h");
    expect(formatMinutes(95)).toBe("1 h 35 min");
  });
});


describe("Swiss wall-clock time for corrections (F3)", () => {
  it("converts summer and winter times to UTC", () => {
    expect(zurichLocalToIso("2026-10-21", "08:30")).toBe("2026-10-21T06:30:00.000Z"); // CEST +2
    expect(zurichLocalToIso("2026-12-01", "08:30")).toBe("2026-12-01T07:30:00.000Z"); // CET +1
  });

  it("round-trips through zurichTime/zurichDate", () => {
    const iso = zurichLocalToIso("2026-10-21", "23:45")!;
    expect(zurichTime(iso)).toBe("23:45");
    expect(zurichDate(iso)).toBe("2026-10-21");
  });

  it("handles the DST change days", () => {
    expect(zurichLocalToIso("2026-10-25", "12:00")).toBe("2026-10-25T11:00:00.000Z"); // after fall-back
    expect(zurichLocalToIso("2026-03-29", "12:00")).toBe("2026-03-29T10:00:00.000Z"); // after spring-forward
  });

  it("rejects malformed input", () => {
    expect(zurichLocalToIso("2026-10-21", "24:00")).toBeNull();
    expect(zurichLocalToIso("21.10.2026", "08:00")).toBeNull();
    expect(zurichLocalToIso("2026-10-21", "8:00")).toBeNull();
  });

  it("keeps correction provenance when parsing events", () => {
    const raw = [{ id: 7, type: "departed", at: "2026-10-21T06:00:00Z", recorded_at: "2026-10-21T06:20:00Z", corrected: true, reason: "vergessen" }];
    expect(parseEvents(raw)[0]).toMatchObject({ id: 7, corrected: true, reason: "vergessen" });
  });
});
