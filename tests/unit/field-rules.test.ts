import { describe, expect, it } from "vitest";
import {
  formatDayLabel,
  formatTime,
  fieldActions,
  parseDayParam,
  shiftDay,
  summarizeDay,
  todayInZurich,
} from "@/features/field/rules";

describe("field rules (F1)", () => {
  it("uses the Swiss calendar day, not the server's UTC day", () => {
    // 23:30 UTC on 21 Oct = 01:30 on 22 Oct in Zurich (CEST, UTC+2)
    expect(todayInZurich(new Date("2026-10-21T23:30:00Z"))).toBe("2026-10-22");
    expect(todayInZurich(new Date("2026-10-21T10:00:00Z"))).toBe("2026-10-21");
    // winter time (CET, UTC+1)
    expect(todayInZurich(new Date("2026-12-31T23:30:00Z"))).toBe("2027-01-01");
  });

  it("accepts only real YYYY-MM-DD dates from the URL", () => {
    const fallback = "2026-10-21";
    expect(parseDayParam("2026-10-20", fallback)).toBe("2026-10-20");
    expect(parseDayParam("2026-02-30", fallback)).toBe(fallback);
    expect(parseDayParam("2026-10-20T00:00", fallback)).toBe(fallback);
    expect(parseDayParam("'; drop table", fallback)).toBe(fallback);
    expect(parseDayParam(["2026-10-20"], fallback)).toBe(fallback);
    expect(parseDayParam(undefined, fallback)).toBe(fallback);
  });

  it("shifts days across month, year and DST boundaries", () => {
    expect(shiftDay("2026-10-31", 1)).toBe("2026-11-01");
    expect(shiftDay("2026-01-01", -1)).toBe("2025-12-31");
    expect(shiftDay("2026-10-25", 1)).toBe("2026-10-26"); // DST ends in CH
    expect(shiftDay("2024-02-28", 1)).toBe("2024-02-29");
  });

  it("formats a German day label and short times", () => {
    expect(formatDayLabel("2026-10-21")).toBe("Mittwoch, 21. Oktober 2026");
    expect(formatTime("08:00:00")).toBe("08:00");
    expect(formatTime(null)).toBeNull();
  });

  it("offers only the transitions the database allows (primary action first)", () => {
    expect(fieldActions("planned")).toEqual(["depart", "start"]);
    expect(fieldActions("on_the_way")).toEqual(["start"]);
    expect(fieldActions("started")).toEqual(["complete", "pause"]);
    expect(fieldActions("paused")).toEqual(["resume"]);
    for (const s of ["completed", "cancelled", "no_show", "assigned", "accepted", null]) {
      expect(fieldActions(s)).toEqual([]);
    }
  });

  it("summarises the day", () => {
    expect(
      summarizeDay([
        { status: "planned" },
        { status: "started" },
        { status: "completed" },
        { status: "cancelled" },
        { status: "on_the_way" },
      ])
    ).toEqual({ total: 5, open: 1, running: 2, done: 1 });
  });
});
