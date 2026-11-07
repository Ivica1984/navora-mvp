import { describe, expect, it } from "vitest";
import {
  MOVED_TO_TODAY_STATUS,
  RELEASED_ON_MOVE,
  futureDayNote,
  minutesOf,
  moveLeavesNote,
  movedNoticeHref,
  parseMovedNotice,
  withoutMovedNotice,
  prefillMoveTimes,
  zurichMinutesNow,
} from "@/features/field/rules";
import { PLAN_FLAG_LABEL } from "@/features/team/rules";

// VIS1 follow-up (ADR-112; PO brief VIS1-3c, VIS1-3d, VIS1-3e, VIS1-8). Pure display rules; the database decides.
const at = (hh: number, mm: number) => hh * 60 + mm;

describe("VIS1-3c: the prefilled times are never in the past", () => {
  it("start = the next full 5 minutes after now (brief examples)", () => {
    expect(prefillMoveTimes(at(14, 2), "08:00:00", "08:30:00").start).toBe("14:05");
    expect(prefillMoveTimes(at(14, 5), "08:00:00", "08:30:00").start).toBe("14:10");
    expect(prefillMoveTimes(at(23, 57), "08:00:00", "08:30:00")).toEqual({ start: "", end: "" });
  });

  it("end = start + the card's planned duration", () => {
    expect(prefillMoveTimes(at(14, 2), "08:00:00", "08:30:00")).toEqual({ start: "14:05", end: "14:35" });
    expect(prefillMoveTimes(at(9, 59), "18:00", "19:15")).toEqual({ start: "10:00", end: "11:15" });
  });

  it("both empty when the start or the end would fall after 23:59 (no prefill across midnight)", () => {
    expect(prefillMoveTimes(at(23, 54), "08:00", "08:30")).toEqual({ start: "", end: "" });   // 23:55 + 30 min
    expect(prefillMoveTimes(at(23, 25), "08:00", "08:30")).toEqual({ start: "", end: "" });   // 23:30 + 30 min = 24:00
    expect(prefillMoveTimes(at(23, 24), "08:00", "08:30")).toEqual({ start: "23:25", end: "23:55" });
    expect(prefillMoveTimes(at(23, 55), "08:00", "08:30")).toEqual({ start: "", end: "" });   // start would be 24:00
  });

  it("a card without a valid planned duration gets the start only (end stays empty and required)", () => {
    expect(prefillMoveTimes(at(14, 2), null, null)).toEqual({ start: "14:05", end: "" });
    expect(prefillMoveTimes(at(14, 2), "09:00", "08:00")).toEqual({ start: "14:05", end: "" });
  });

  it("the start is always after now", () => {
    for (let m = 0; m < at(23, 55); m += 7) {
      const { start } = prefillMoveTimes(m, "08:00", "08:05");
      if (start) expect(minutesOf(start)!).toBeGreaterThan(m);
    }
  });

  it("now is the Zurich wall clock, also across the clock change", () => {
    expect(zurichMinutesNow(new Date("2026-10-28T13:02:30Z"))).toBe(at(14, 2));     // CET (UTC+1)
    expect(zurichMinutesNow(new Date("2026-07-01T12:02:00Z"))).toBe(at(14, 2));     // CEST (UTC+2)
    expect(zurichMinutesNow(new Date("2026-10-28T22:59:00Z"))).toBe(at(23, 59));
  });
});

describe("VIS1-3e (2): the future-day line is count-aware", () => {
  it("one visit keeps the VIS1-3 wording", () => {
    expect(futureDayNote("2026-11-04", 1)).toBe(
      "Der Einsatz ist für den 04.11.2026 geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.",
    );
    expect(futureDayNote("2026-11-04")).toBe(futureDayNote("2026-11-04", 1));
  });

  it("several visits get the PO's plural wording", () => {
    expect(futureDayNote("2026-11-04", 3)).toBe(
      "Diese Einsätze sind für den 04.11.2026 geplant. Machst du einen davon heute, verschiebe ihn zuerst mit «Heute machen».",
    );
  });
});

describe("VIS1-8: what the move leaves behind", () => {
  it("none: the client has no other visit that day", () => {
    expect(moveLeavesNote("2026-10-29", false)).toBe("Am 29.10.2026 ist danach kein Einsatz bei dieser Person geplant.");
  });

  it("own team or another team's visit: the server answers true, the sentence says 'noch ein Einsatz', no detail", () => {
    const own = moveLeavesNote("2026-10-29", true);
    expect(own).toBe("Am 29.10.2026 ist danach noch ein Einsatz bei dieser Person geplant.");
    // The other team's visit reaches the client only as the same yes; the sentence names no time, team or person.
    expect(own).not.toMatch(/\d{2}:\d{2}|Team|von /);
  });

  it("no answer: no sentence, never a guessed 'kein Einsatz'", () => {
    expect(moveLeavesNote("2026-10-29", null)).toBeNull();
  });
});

describe("VIS1-3d / VIS1-3e: the move's result on today's view", () => {
  const flags = Object.keys(PLAN_FLAG_LABEL);
  const id = "00000000-0000-4000-a090-000000000021";

  it("the link carries the visit, the release and the flags, and parses back", () => {
    const href = movedNoticeHref(id, true, ["uncovered", "not_primary"]);
    expect(href).toBe(`/field?verschoben=${id}&offen=1&hinweise=uncovered%2Cnot_primary`);
    const q = new URLSearchParams(href.split("?")[1]);
    expect(parseMovedNotice(q.get("verschoben") ?? undefined, q.get("offen") ?? undefined, q.get("hinweise") ?? undefined, flags))
      .toEqual({ visitId: id, released: true, flags: ["uncovered", "not_primary"] });
    expect(movedNoticeHref(id, false, [])).toBe(`/field?verschoben=${id}`);
  });

  it("a malformed id shows nothing; unknown flags are dropped", () => {
    expect(parseMovedNotice("x", "1", "uncovered", flags)).toBeNull();
    expect(parseMovedNotice(undefined, "1", "uncovered", flags)).toBeNull();
    expect(parseMovedNotice(id, undefined, "uncovered,<script>,uncovered", flags)).toEqual({ visitId: id, released: false, flags: ["uncovered"] });
  });

  it("the released text is the /team text, word for word", () => {
    expect(RELEASED_ON_MOVE).toBe("Die verantwortliche Person ist zur neuen Zeit abwesend. Der Einsatz ist jetzt offen im Team.");
    expect(MOVED_TO_TODAY_STATUS).toBe("Einsatz auf heute verschoben");
  });
});

describe("VIS1-3g: the move's notice is shown once (not kept in the address)", () => {
  const id = "00000000-0000-4000-a090-000000000021";

  it("drops the move's parameters and keeps every other one in order", () => {
    expect(withoutMovedNotice(`?verschoben=${id}&offen=1&hinweise=uncovered`)).toBe("");
    expect(withoutMovedNotice(`?verschoben=${id}`)).toBe("");
    expect(withoutMovedNotice(`?datum=2026-10-29&verschoben=${id}&von=push`)).toBe("?datum=2026-10-29&von=push");
    expect(withoutMovedNotice("")).toBe("");
    expect(withoutMovedNotice("?datum=2026-10-29")).toBe("?datum=2026-10-29");
  });

  it("the link a move produces leaves nothing behind once stripped", () => {
    const href = movedNoticeHref(id, true, ["uncovered"]);
    expect(withoutMovedNotice(href.slice(href.indexOf("?")))).toBe("");
  });
});
