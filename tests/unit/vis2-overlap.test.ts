import { describe, expect, it } from "vitest";
import {
  cardAccessibleName, cardInterval, overlapAfterSave, overlapNote, overlapParam, parseOverlapFact, parseOverlapParam,
  sameSlotInfo, sameSlotLine, sameSlotPositions, type CardLike,
} from "@/features/visits/overlap-rules";
import { MOVED_NOTICE_PARAMS, withoutMovedNotice } from "@/features/field/rules";

// VIS2 (ADR-121; PO brief VIS2 with VIS2-5; `cra` CGR-97; wording `uxa` 23:55). Display rules only: the database
// (`client_visit_overlap` and the commands' `overlap`, migration 0098, pgTAP 098) decides whether the client has another
// visit at an overlapping time and what the caller may see of it.

const READABLE = { overlap: true, timeStart: "09:00", timeEnd: "09:30" };
const HIDDEN = { overlap: true, timeStart: null, timeEnd: null };

describe("VIS2-1 / VIS2-2: the sentence before saving", () => {
  it("names the weekday, the date and the times of a visit she can read", () => {
    expect(overlapNote("2026-11-03", READABLE, "2026-10-30")).toBe(
      "Bei dieser Person ist am Dienstag, 03.11.2026 von 09:00 bis 09:30 bereits ein Einsatz geplant.",
    );
  });

  it("says 'heute' for today's date", () => {
    expect(overlapNote("2026-10-30", READABLE, "2026-10-30")).toBe(
      "Bei dieser Person ist heute von 09:00 bis 09:30 bereits ein Einsatz geplant.",
    );
  });

  it("names no time, team, member or service for a visit she cannot read, and never 'kein Einsatz'", () => {
    const text = overlapNote("2026-11-03", HIDDEN, "2026-10-30");
    expect(text).toBe(
      "Bei dieser Person ist am Dienstag, 03.11.2026 zu einer Zeit, die sich mit diesem Einsatz überschneidet, bereits ein Einsatz geplant.",
    );
    expect(text).not.toMatch(/kein|Team|\d{2}:\d{2}/);
  });

  it("shows nothing without an overlap or without an answer", () => {
    expect(overlapNote("2026-11-03", { overlap: false, timeStart: null, timeEnd: null }, "2026-10-30")).toBeNull();
    expect(overlapNote("2026-11-03", null, "2026-10-30")).toBeNull();
    expect(overlapNote("", READABLE, "2026-10-30")).toBeNull();
  });

  it("carries no internal code and asks for nothing (no reason, no second confirmation)", () => {
    const text = overlapNote("2026-11-03", READABLE, "2026-10-30") ?? "";
    expect(text).not.toMatch(/_|overlap|bestätig|Grund/i);
  });

  it("parses the server answer defensively", () => {
    expect(parseOverlapFact({ overlap: true, time_start: "09:00", time_end: "09:30" })).toEqual(READABLE);
    expect(parseOverlapFact({ overlap: true, time_start: null, time_end: null })).toEqual(HIDDEN);
    expect(parseOverlapFact({ overlap: false, time_start: "09:00", time_end: "09:30" })).toEqual({ overlap: false, timeStart: null, timeEnd: null });
    expect(parseOverlapFact({ overlap: true, time_start: "9 Uhr", time_end: "09:30" })).toEqual(HIDDEN);
    expect(parseOverlapFact({ overlap: true, time_start: "09:00" })).toEqual(HIDDEN);
    expect(parseOverlapFact(null)).toBeNull();
    expect(parseOverlapFact({ overlap: "yes" })).toBeNull();
  });
});

describe("VIS2-5 (2): the server's check after the save", () => {
  it("is shown only when the form did not show an overlap the server found", () => {
    expect(overlapAfterSave(false, READABLE)).toEqual(READABLE);
    expect(overlapAfterSave(true, READABLE)).toBeNull();
    expect(overlapAfterSave(false, { overlap: false, timeStart: null, timeEnd: null })).toBeNull();
    expect(overlapAfterSave(false, null)).toBeNull();
  });

  it("travels to today's view as a display-only parameter and back", () => {
    expect(overlapParam(READABLE)).toBe("09:00-09:30");
    expect(overlapParam(HIDDEN)).toBe("1");
    expect(overlapParam(null)).toBeNull();
    expect(parseOverlapParam("09:00-09:30")).toEqual(READABLE);
    expect(parseOverlapParam("1")).toEqual(HIDDEN);
    expect(parseOverlapParam("25:00-09:30")).toBeNull();
    expect(parseOverlapParam("<script>")).toBeNull();
    expect(parseOverlapParam(undefined)).toBeNull();
  });

  it("is dropped from the address with the other move parameters (VIS1-3g)", () => {
    expect(MOVED_NOTICE_PARAMS).toContain("ueberschneidung");
    expect(withoutMovedNotice("?verschoben=x&ueberschneidung=09:00-09:30&datum=2026-10-30")).toBe("?datum=2026-10-30");
  });
});

const card = (id: string, start: string | null, end: string | null, extra: Partial<CardLike> = {}): CardLike => ({
  visit_id: id, case_id: "case-1", visit_date: "2026-11-03", time_start: start, time_end: end,
  planned_minutes_a: 30, planned_minutes_b: 0, planned_minutes_c: 0, status: "planned", ...extra,
});

describe("VIS2-3: two cards of one client at one time can be told apart", () => {
  it("numbers overlapping cards of the same client and leaves others alone", () => {
    const pos = sameSlotPositions([
      card("b", "22:40:00", "23:10:00"),
      card("a", "22:40:00", "23:10:00"),
      card("c", "08:00:00", "08:30:00"),
      card("d", "22:40:00", "23:10:00", { case_id: "case-2" }),
    ]);
    expect(pos.get("a")).toEqual({ index: 1, total: 2 });
    expect(pos.get("b")).toEqual({ index: 2, total: 2 });
    expect(pos.has("c")).toBe(false);
    expect(pos.has("d")).toBe(false);
  });

  it("uses half-open intervals (touching visits are not grouped) and skips cancelled visits", () => {
    const pos = sameSlotPositions([
      card("a", "09:00:00", "09:30:00"),
      card("b", "09:30:00", "10:00:00"),
      card("c", "09:10:00", "09:20:00", { status: "cancelled" }),
    ]);
    expect(pos.size).toBe(0);
  });

  it("reads a visit without an end as start + planned minutes (as the database)", () => {
    expect(cardInterval(card("a", "09:00:00", null))).toEqual([540, 570]);
    expect(cardInterval(card("a", null, null))).toEqual([0, 1440]);
    expect(cardInterval(card("a", "23:30:00", "00:15:00"))).toEqual([1410, 1440]);
    expect(sameSlotPositions([card("a", "09:00:00", null), card("b", "09:20:00", "09:50:00")]).size).toBe(2);
  });

  it("gives the two cards different accessible names (`uxa` wording) and an unchanged name otherwise", () => {
    const pos = sameSlotPositions([card("a", "22:40:00", "23:10:00"), card("b", "22:40:00", "23:10:00")]);
    const a = cardAccessibleName("22:40 – 23:10", "Testfall 08", pos.get("a"));
    const b = cardAccessibleName("22:40 – 23:10", "Testfall 08", pos.get("b"));
    expect(a).not.toBe(b);
    expect(a).toBe("Einsatz 22:40 – 23:10, Testfall 08, 1 von 2 zu dieser Zeit");
    expect(cardAccessibleName("08:00 – 08:30", "Testfall 08", undefined)).toBe("Einsatz 08:00 – 08:30, Testfall 08");
    expect(sameSlotLine({ index: 2, total: 2 })).toBe("2 von 2 zu dieser Zeit");
    expect(sameSlotInfo({ index: 2, total: 2 }, "du")).toBe("2 von 2 zu dieser Zeit · Verantwortlich: du");
  });
});
