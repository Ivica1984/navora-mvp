import { describe, expect, it } from "vitest";
import { afterCompleteHref, carriedLine, carriedVisitIds, withCarriedRows } from "@/features/field/carried";
import { fieldActionsOn, orderFieldVisits, pickNextVisit } from "@/features/field/rules";

// BK-e1c (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, UXR-248, CGR-257; ADR-203 (22)).
// Display rules of the running night visit carried to the next day by `field_visits` (migration 0149). Synthetic data.

const v = (id: string, over: Partial<{ status: string; time_start: string; responsible_me: boolean; carried_from_previous_day: boolean }> = {}) => ({
  visit_id: id,
  status: "planned",
  time_start: "06:00:00",
  responsible_me: true,
  suspended: false,
  carried_from_previous_day: false,
  ...over,
});

describe("C1: the carried night visit comes first on day 2", () => {
  it("before a running visit of day 2 and before an earlier planned one", () => {
    const visits = [v("d2-early", { time_start: "05:00:00" }), v("d2-running", { status: "started", time_start: "07:00:00" }),
      v("night", { status: "started", time_start: "22:00:00", carried_from_previous_day: true })];
    expect(pickNextVisit(visits)?.visit_id).toBe("night");
    expect(orderFieldVisits(visits).next?.visit_id).toBe("night");
  });

  it("a paused carried visit counts as running", () => {
    const visits = [v("d2", { time_start: "05:00:00" }), v("night", { status: "paused", time_start: "22:00:00", carried_from_previous_day: true })];
    expect(pickNextVisit(visits)?.visit_id).toBe("night");
  });

  it("without a carried visit the order is unchanged (UX1-6)", () => {
    const visits = [v("a", { time_start: "08:00:00" }), v("b", { status: "started", time_start: "09:00:00" })];
    expect(pickNextVisit(visits)?.visit_id).toBe("b");
  });

  it("«Einsatz abschliessen» and «Pause» stay on the card: a visit dated the day before is not after today (VIS1)", () => {
    expect(fieldActionsOn("started", "2026-11-21", "2026-11-22")).toEqual(["complete", "pause"]);
  });
});

describe("C1: the line on the carried card (copy PROPOSED, uxa)", () => {
  it("started on its own day: «Läuft seit gestern 22:00»", () => {
    expect(carriedLine([{ type: "started", at: "2026-11-21T22:00:00+01:00" }], "2026-11-21", "22:00:00")).toBe("Läuft seit gestern 22:00");
  });
  it("started after midnight: the time only", () => {
    expect(carriedLine([{ type: "started", at: "2026-11-22T00:30:00+01:00" }], "2026-11-21", "22:00:00")).toBe("Läuft seit 00:30");
  });
  it("no recorded start: the planned start", () => {
    expect(carriedLine([], "2026-11-21", "22:00:00")).toBe("Läuft seit gestern 22:00");
  });
});

describe("C1: the carried visit keeps its own rows from the previous day", () => {
  const carried = carriedVisitIds([{ visit_id: "night", carried_from_previous_day: true }, { visit_id: "d2", carried_from_previous_day: false }]);
  const key = (r: { visit_id: string | null }) => r.visit_id;

  it("only carried visits are read as carried", () => {
    expect([...carried]).toEqual(["night"]);
  });
  it("adds the carried visit's rows of the previous day, never other visits of that day", () => {
    const merged = withCarriedRows([{ visit_id: "d2", n: 1 }], [{ visit_id: "night", n: 2 }, { visit_id: "night", n: 3 }, { visit_id: "day1-other", n: 4 }], carried, key);
    expect(merged.map((r) => r.n)).toEqual([1, 2, 3]);
  });
  it("never duplicates rows already present for that visit", () => {
    const merged = withCarriedRows([{ visit_id: "night", n: 1 }], [{ visit_id: "night", n: 2 }], carried, key);
    expect(merged.map((r) => r.n)).toEqual([1]);
  });
  it("no carried visit: the day's rows unchanged", () => {
    expect(withCarriedRows([{ visit_id: "a" }], [{ visit_id: "night" }], new Set(), key)).toEqual([{ visit_id: "a" }]);
  });
});

describe("after completing a carried visit (PROPOSED, uxa)", () => {
  it("goes to the visit's own day, where it and its report draft stay", () => {
    expect(afterCompleteHref({ carried_from_previous_day: true, visit_date: "2026-11-21" })).toBe("/field?datum=2026-11-21");
  });
  it("a visit of the day itself stays on the page", () => {
    expect(afterCompleteHref({ carried_from_previous_day: false, visit_date: "2026-11-22" })).toBeNull();
  });
});
