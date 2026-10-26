import { describe, expect, it } from "vitest";
import {
  NOTICE_PARAGRAPHS, NOTICE_VERSION, buildCsv, buildPayload, elapsedMinutes, endInstant, openQuestions,
  proposalSegments, zurichInstant, zurichLocalWithOffset, type MonthExport,
} from "@/features/work/rules";

// WORK1 (migration 0079, ADR-092): pure rules of the working-day proposal, confirmation payload and CSV export.

describe("Zurich local time ↔ instant (same rule as the database, DST1)", () => {
  it("summer and winter offsets", () => {
    expect(zurichInstant("2026-10-22", "07:00")).toBe("2026-10-22T07:00:00+02:00");
    expect(zurichInstant("2026-12-01", "07:00")).toBe("2026-12-01T07:00:00+01:00");
  });
  it("the repeated autumn hour reads as the earlier instant; the spring gap in standard time", () => {
    expect(zurichInstant("2026-10-25", "02:30")).toBe("2026-10-25T02:30:00+02:00");
    expect(zurichInstant("2026-03-29", "02:30")).toBe("2026-03-29T02:30:00+01:00");
  });
  it("refuses malformed input", () => {
    expect(zurichInstant("2026-10-22", "7:00")).toBeNull();
    expect(zurichInstant("22.10.2026", "07:00")).toBeNull();
  });
  it("an end before the start lies on the next day (night shift)", () => {
    expect(endInstant("2026-10-22", "22:00", "06:00")).toBe("2026-10-23T06:00:00+02:00");
  });
  it("local time with UTC offset, on both sides of the clock change (WORK1-4)", () => {
    expect(zurichLocalWithOffset("2026-10-25T00:30:00Z")).toBe("2026-10-25T02:30:00+02:00");
    expect(zurichLocalWithOffset("2026-10-25T01:30:00Z")).toBe("2026-10-25T02:30:00+01:00");
  });
  it("elapsed minutes are real minutes, also across the repeated hour (WORK1-3)", () => {
    expect(elapsedMinutes("2026-10-25T02:30:00+02:00", "2026-10-25T02:30:00+01:00")).toBe(60);
  });
});

describe("the day is never complete by default (WORK1-2)", () => {
  const base = { dayStart: "06:45", dayEnd: "16:00", breaks: "none" as const, outside: "none" as const };
  it("both questions and start and end must be answered", () => {
    expect(openQuestions(base)).toEqual([]);
    expect(openQuestions({ ...base, breaks: null })).toEqual(["breaks"]);
    expect(openQuestions({ ...base, outside: [] })).toEqual(["outside_work"]);
    expect(openQuestions({ ...base, dayStart: "", dayEnd: "" })).toEqual(["day_start", "day_end"]);
  });
  it("an unanswered question stays absent from the payload, so the database refuses it (questions_open)", () => {
    const p = buildPayload({ date: "2026-10-22", ...base, breaks: null, segments: [] });
    expect(p).not.toHaveProperty("breaks");
    expect(p.outside_work).toBe("none");
  });
  it("'keine' is an explicit answer and lists become instants with offset", () => {
    const p = buildPayload({
      date: "2026-10-22", ...base, segments: [],
      breaks: [{ start: "12:00", end: "12:30" }],
      outside: [{ kind: "administration", start: "16:30", end: "17:00" }],
    });
    expect(p.breaks).toEqual([{ start: "2026-10-22T12:00:00+02:00", end: "2026-10-22T12:30:00+02:00" }]);
    expect(p.outside_work).toEqual([{ kind: "administration", start: "2026-10-22T16:30:00+02:00", end: "2026-10-22T17:00:00+02:00" }]);
    expect(p.day_start).toBe("2026-10-22T06:45:00+02:00");
  });
  it("the report sign time is a point, never a segment to confirm; open ends stay open", () => {
    expect(proposalSegments([
      { seq: 1, visit_no: 1, kind: "care", starts_at: "2026-10-22T05:15:00Z", ends_at: null },
      { seq: 2, visit_no: null, kind: "report_signed", starts_at: "2026-10-22T06:00:00Z", ends_at: "2026-10-22T06:00:00Z" },
    ])).toEqual([{ kind: "care", start: "2026-10-22T05:15:00Z", end: null }]);
  });
});

describe("CSV export (WORK1-4)", () => {
  const e: MonthExport = {
    month: "2026-10",
    unconfirmed: ["2026-10-23"],
    days: [{
      date: "2026-10-25", version: 2, confirmed_at: "2026-10-26T11:00:00Z",
      day_start: "2026-10-25T00:00:00Z", day_end: "2026-10-25T02:30:00Z", breaks_answer: "none", outside_answer: "listed",
      paid_minutes: 150,
      entries: [
        { kind: "care", start: "2026-10-25T00:30:00Z", end: "2026-10-25T01:30:00Z", minutes: 60 },
        { kind: "administration", start: "2026-10-25T02:00:00Z", end: "2026-10-25T02:30:00Z", minutes: 30 },
      ],
    }],
  };
  const csv = buildCsv(e);
  const lines = csv.trimEnd().split("\r\n");
  it("lists unconfirmed days by date in the header, never filled", () => {
    expect(lines[1]).toBe("# nicht bestätigt: 2026-10-23");
    expect(csv).not.toContain("2026-10-23;");
  });
  it("has the columns date, kind, start, end (local with offset), minutes, version, confirmed at", () => {
    expect(lines[2]).toBe("datum;art;beginn;ende;minuten;fassung;bestaetigt_am");
    expect(lines).toContain("2026-10-25;Pflege im Einsatz;2026-10-25T02:30:00+02:00;2026-10-25T02:30:00+01:00;60;2;2026-10-26T12:00:00+01:00");
    expect(lines).toContain("2026-10-25;Arbeitstag;2026-10-25T02:00:00+02:00;2026-10-25T03:30:00+01:00;150;2;2026-10-26T12:00:00+01:00");
    expect(lines).toContain("2026-10-25;Pause (30 Min. oder mehr): keine;;;;2;2026-10-26T12:00:00+01:00");
  });
  it("carries no note, client, case or visit identifier", () => {
    expect(csv).not.toMatch(/note|notiz|visit|case|klient/i);
  });
});

describe("information text (WORK1-8)", () => {
  it("names both uses: team coordination and her own proposal", () => {
    const text = NOTICE_PARAGRAPHS.join(" ");
    expect(text).toContain("damit ihr die Pflege koordinieren könnt");
    expect(text).toContain("siehst nur du");
    expect(NOTICE_VERSION).toBe("work1-notice-v1");
  });
});
