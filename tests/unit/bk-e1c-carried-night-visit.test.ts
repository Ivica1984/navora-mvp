import { describe, expect, it } from "vitest";
import { carriedLine, carriedVisits, withCarriedCaseRows, withCarriedRows } from "@/features/field/carried";
import { orderFieldVisits, pickNextVisit, type NextVisitLike } from "@/features/field/rules";

// BK-e1c (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, CGR-257, UXR-248; ADR-203 amendment
// BK-e1c). The night visit of the day before, still running on day 2, is the first card of «Heute»; its day-1 rows
// (notes, report, quality …) come with it, no other visit's rows. Synthetic ids only.

type V = NextVisitLike & { case_id: string | null };
const visit = (id: string, status: string, time_start: string, extra: Partial<V> = {}): V => ({
  visit_id: id,
  case_id: `case-${id}`,
  status,
  time_start,
  responsible_me: true,
  suspended: false,
  ...extra,
});

describe("order of «Heute» with a carried night visit (C1, UXR-248)", () => {
  it("the carried running night visit is first, before an earlier running visit of day 2", () => {
    const day2Running = visit("d2", "started", "06:00:00");
    const carried = visit("n1", "started", "22:00:00", { carried_from_previous_day: true });
    expect(pickNextVisit([day2Running, carried])?.visit_id).toBe("n1");
    const ordered = orderFieldVisits([day2Running, carried]);
    expect(ordered.next?.visit_id).toBe("n1");
    expect(ordered.rest.map((v) => v.visit_id)).toEqual(["d2"]);
  });

  it("a carried paused visit counts as running and is first too", () => {
    const planned = visit("d2", "planned", "05:00:00");
    const carried = visit("n2", "paused", "22:30:00", { carried_from_previous_day: true });
    expect(pickNextVisit([planned, carried])?.visit_id).toBe("n2");
  });

  it("a carried visit completed today is not «Als Nächstes» (nothing left to start)", () => {
    const planned = visit("d2", "planned", "08:00:00");
    const done = visit("n9", "completed", "22:00:00", { carried_from_previous_day: true });
    expect(pickNextVisit([done, planned])?.visit_id).toBe("d2");
  });

  it("without a carried visit the order is unchanged (regression)", () => {
    const a = visit("a", "planned", "09:00:00");
    const b = visit("b", "started", "10:00:00");
    expect(pickNextVisit([a, b])?.visit_id).toBe("b");
    expect(pickNextVisit([a, visit("c", "planned", "07:00:00")])?.visit_id).toBe("c");
  });

  it("her own visits still come before the team's: a colleague's carried visit does not jump her own", () => {
    const mine = visit("m", "planned", "08:00:00");
    const colleagues = visit("n1", "started", "22:00:00", { carried_from_previous_day: true, responsible_me: false });
    expect(pickNextVisit([mine, colleagues])?.visit_id).toBe("m");
  });
});

describe("day-1 rows of a carried card", () => {
  const carried = new Set(["n1"]);
  it("adds the day-1 rows of the carried visit only", () => {
    const day2 = [{ visit_id: "d2", n: 1 }];
    const day1 = [{ visit_id: "n1", n: 2 }, { visit_id: "other", n: 3 }, { visit_id: null, n: 4 }];
    expect(withCarriedRows(day2, day1, carried)).toEqual([{ visit_id: "d2", n: 1 }, { visit_id: "n1", n: 2 }]);
  });
  it("nothing carried: the day's rows unchanged", () => {
    expect(withCarriedRows([{ visit_id: "d2" }], [{ visit_id: "n1" }], new Set())).toEqual([{ visit_id: "d2" }]);
  });
  it("a case history is never shown twice", () => {
    const day2 = [{ case_id: "c1", n: 1 }];
    const day1 = [{ case_id: "c1", n: 2 }, { case_id: "c2", n: 3 }, { case_id: "c3", n: 4 }];
    expect(withCarriedCaseRows(day2, day1, new Set(["c1", "c2"]))).toEqual([{ case_id: "c1", n: 1 }, { case_id: "c2", n: 3 }]);
  });
  it("carriedVisits picks the flagged ones", () => {
    const list = [visit("a", "planned", "08:00:00"), visit("n1", "started", "22:00:00", { carried_from_previous_day: true })];
    expect(carriedVisits(list).map((v) => v.visit_id)).toEqual(["n1"]);
  });
});

describe("line on a carried card (copy PROPOSED, uxa)", () => {
  it("running: «Läuft seit gestern 22:00»", () => {
    expect(carriedLine(true, "started", "22:00:00")).toBe("Läuft seit gestern 22:00");
    expect(carriedLine(true, "paused", "22:30:00")).toBe("Läuft seit gestern 22:30");
  });
  it("completed today: «Begonnen gestern 22:00»", () => {
    expect(carriedLine(true, "completed", "22:00:00")).toBe("Begonnen gestern 22:00");
  });
  it("not carried: no line", () => {
    expect(carriedLine(false, "started", "22:00:00")).toBeNull();
    expect(carriedLine(undefined, "started", "22:00:00")).toBeNull();
  });
});
