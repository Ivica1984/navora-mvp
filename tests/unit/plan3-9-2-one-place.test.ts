import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  DAY_PLAN_AGENT_KEY,
  dayPlanRowHref,
  dayPlanRowText,
  splitDayPlanSuggestions,
} from "@/features/ai/day-plan-rows";

/**
 * PLAN3-9 (2) (ADR-160, `uxa` UXR-103 adopted by the PO note 2026-11-06 06:30): one place decides a day-plan line.
 * `/team/vorschlaege` lists each open day plan as one row ("Tagesvorschlag <Wochentag, Datum>: <n> offen", link to that
 * day) without a per-line "Bestätigen"; the header count is unchanged. The day of a line comes from the database
 * (`open_day_plan_lines`, migration 0117: `day_plan_lines.plan_date`), never from the visit date. Synthetic values only.
 */
const root = process.cwd();
const client = readFileSync(join(root, "src/app/(protected)/team/vorschlaege/suggestions-client.tsx"), "utf8");
const queries = readFileSync(join(root, "src/features/ai/queries.ts"), "utf8");

const TODAY = "2026-11-06";
type S = { suggestion_id: string; agent_key: string };
const s = (id: string, agent_key = DAY_PLAN_AGENT_KEY): S => ({ suggestion_id: id, agent_key });

describe("PLAN3-9 (2) splitting the open proposals of one team", () => {
  it("takes every open day-plan line out of the per-line list and counts it under its day plan's date", () => {
    const out = splitDayPlanSuggestions(
      [s("a"), s("b"), s("c"), s("x", "aig1_test_agent"), s("d")],
      [
        { suggestion_id: "a", plan_date: "2026-11-07" },
        { suggestion_id: "b", plan_date: "2026-11-07" },
        { suggestion_id: "c", plan_date: "2026-11-09" },
        { suggestion_id: "d", plan_date: "2026-11-07" },
      ],
      TODAY,
    );
    expect(out.perLine.map((x) => x.suggestion_id)).toEqual(["x"]);
    expect(out.days).toEqual([
      { plan_date: "2026-11-07", open: 3 },
      { plan_date: "2026-11-09", open: 1 },
    ]);
    expect(out.unread).toBe(0);
  });

  it("orders the day rows by date, whatever order the lines come in", () => {
    const out = splitDayPlanSuggestions(
      [s("a"), s("b")],
      [
        { suggestion_id: "a", plan_date: "2026-11-12" },
        { suggestion_id: "b", plan_date: "2026-11-08" },
      ],
      TODAY,
    );
    expect(out.days.map((d) => d.plan_date)).toEqual(["2026-11-08", "2026-11-12"]);
  });

  it("uses the day plan's date, not the visit date: a line is counted under the day it was proposed for", () => {
    // The reader is the only source of the day; nothing in the suggestion row is used to place it.
    const out = splitDayPlanSuggestions([{ ...s("a"), visit_date: "2026-11-10" } as S], [{ suggestion_id: "a", plan_date: "2026-11-07" }], TODAY);
    expect(out.days).toEqual([{ plan_date: "2026-11-07", open: 1 }]);
  });

  it("keeps a line of a day plan before today on its own line: the day page opens today to 14 days ahead only (deviation 1)", () => {
    const out = splitDayPlanSuggestions([s("a"), s("b")], [
      { suggestion_id: "a", plan_date: "2026-11-05" },
      { suggestion_id: "b", plan_date: TODAY },
    ], TODAY);
    expect(out.perLine.map((x) => x.suggestion_id)).toEqual(["a"]);
    expect(out.days).toEqual([{ plan_date: TODAY, open: 1 }]);
  });

  it("never lists a day-plan line per line when the day read failed: it is counted as unread instead (fail closed)", () => {
    const out = splitDayPlanSuggestions([s("a"), s("b"), s("x", "aig1_test_agent")], null, TODAY);
    expect(out.perLine.map((x) => x.suggestion_id)).toEqual(["x"]);
    expect(out.days).toEqual([]);
    expect(out.unread).toBe(2);
  });

  it("counts a day-plan line the reader did not return as unread, never as a per-line proposal", () => {
    const out = splitDayPlanSuggestions([s("a"), s("b")], [{ suggestion_id: "a", plan_date: "2026-11-07" }], TODAY);
    expect(out.perLine).toEqual([]);
    expect(out.days).toEqual([{ plan_date: "2026-11-07", open: 1 }]);
    expect(out.unread).toBe(1);
  });

  it("ignores a reader row whose line is not open in the list (the list is the open proposals; counts follow it)", () => {
    const out = splitDayPlanSuggestions([s("a")], [
      { suggestion_id: "a", plan_date: "2026-11-07" },
      { suggestion_id: "gone", plan_date: "2026-11-07" },
    ], TODAY);
    expect(out.days).toEqual([{ plan_date: "2026-11-07", open: 1 }]);
  });

  it("changes nothing for proposals of other agents", () => {
    const list = [s("x", "aig1_test_agent"), s("y", "aig1_test_agent")];
    const out = splitDayPlanSuggestions(list, [], TODAY);
    expect(out.perLine).toEqual(list);
    expect(out.days).toEqual([]);
    expect(out.unread).toBe(0);
  });
});

describe("PLAN3-9 (2) the day row", () => {
  it("reads 'Tagesvorschlag <Wochentag, Datum>: <n> offen'", () => {
    expect(dayPlanRowText("2026-11-07", 5)).toBe("Tagesvorschlag Samstag, 07.11.2026: 5 offen");
    expect(dayPlanRowText("2026-11-09", 1)).toBe("Tagesvorschlag Montag, 09.11.2026: 1 offen");
  });

  it("names no person and no client", () => {
    expect(dayPlanRowText("2026-11-07", 3)).not.toMatch(/Pflege|Klient|\(du\)/);
  });

  it("links to that team and day on /team/tagesplan (the page's own parameters)", () => {
    expect(dayPlanRowHref("00000000-0000-4000-a000-0000000001a1", "2026-11-07")).toBe(
      "/team/tagesplan?team=00000000-0000-4000-a000-0000000001a1&datum=2026-11-07",
    );
  });
});

describe("PLAN3-9 (2) the confirm screen wiring", () => {
  it("splits the list before rendering lines and renders the day rows with their own test id", () => {
    expect(client).toContain("splitDayPlanSuggestions(");
    expect(client).toContain('data-testid="day-plan-row"');
    expect(client).toContain("dayPlanRowText(");
  });

  it("reads the day of each line through the new reader, per team, as the caller", () => {
    expect(queries).toContain('rpc("open_day_plan_lines"');
  });
});
