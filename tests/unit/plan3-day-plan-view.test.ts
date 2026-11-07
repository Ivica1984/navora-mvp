import { describe, expect, it } from "vitest";
import {
  dayPlanDateBounds,
  groupDayPlan,
  isDayPlanDate,
  lineDecisionText,
  lineFlags,
  loadText,
  minuteCategoryText,
  tickableLineIds,
  type DayPlanLine,
  type DayPlanLoadRow,
} from "@/features/planning/day-plan-view";

/**
 * PLAN3 part (b) (ADR-147): the screen model of the day-plan proposal on /team/tagesplan. The database decides every
 * limit, reason and decision (0109, 0110); this module only groups and words what `day_plan` and `day_plan_load` return.
 * Synthetic values only.
 */
const A = "00000000-0000-4000-a000-0000000009e1";
const B = "00000000-0000-4000-a000-0000000009e2";

function line(over: Partial<DayPlanLine>): DayPlanLine {
  return {
    suggestion_id: "s",
    proposal_id: "p",
    proposed_at: "2026-11-05T10:00:00Z",
    visit_id: "v",
    case_id: "c",
    time_start: "08:00:00",
    time_end: "08:30:00",
    minutes_a: 30,
    minutes_b: 0,
    minutes_c: 0,
    is_needs_assessment: false,
    member_id: A,
    member_name: "Synth A",
    reason: "primary_nurse",
    known_visits: 0,
    not_found_reason: null as unknown as string,
    changes_assignment: false,
    not_continuity: false,
    decision: "open",
    bulk_allowed: true,
    visit_has_responsible: false,
    ...over,
  };
}

const load: DayPlanLoadRow[] = [
  { member_id: A, member_name: "Synth A", minutes_now: 60, minutes_with_proposal: 120, other_team_visits: false },
  { member_id: B, member_name: "Synth B", minutes_now: 0, minutes_with_proposal: 30, other_team_visits: true },
];

describe("PLAN3-9 list per member", () => {
  it("groups proposed lines under their member in the load order, 'kein Vorschlag' apart", () => {
    const g = groupDayPlan(
      [
        line({ suggestion_id: "1", member_id: B, member_name: "Synth B", time_start: "09:00:00" }),
        line({ suggestion_id: "2", member_id: A }),
        line({ suggestion_id: "3", member_id: null as unknown as string, member_name: null as unknown as string, not_found_reason: "absent", bulk_allowed: false }),
      ],
      load,
    );
    expect(g.members.map((m) => m.member_id)).toEqual([A, B]);
    expect(g.members[0].lines.map((l) => l.suggestion_id)).toEqual(["2"]);
    expect(g.members[1].lines.map((l) => l.suggestion_id)).toEqual(["1"]);
    expect(g.withoutProposal.map((l) => l.suggestion_id)).toEqual(["3"]);
  });

  it("keeps every member of the load, also one without a proposed line (PLAN3-4: load visible)", () => {
    const g = groupDayPlan([line({ suggestion_id: "1", member_id: A })], load);
    expect(g.members).toHaveLength(2);
    expect(g.members[1].lines).toEqual([]);
    expect(g.members[1].otherTeams).toBe(true);
  });

  it("adds a proposed member the load does not list, after the listed ones, so no line is lost", () => {
    const g = groupDayPlan([line({ suggestion_id: "1", member_id: "x", member_name: "Synth X" })], load);
    expect(g.members.map((m) => m.member_id)).toEqual([A, B, "x"]);
    expect(g.members[2].minutesNow).toBeNull();
  });
});

describe("PLAN3-9 ticked list (CGR-78 (b))", () => {
  it("only open, bulk-eligible lines with a member can be ticked; none is ticked by default", () => {
    const ids = tickableLineIds([
      line({ suggestion_id: "1" }),
      line({ suggestion_id: "2", decision: "confirmed", bulk_allowed: false }),
      line({ suggestion_id: "3", member_id: null as unknown as string, bulk_allowed: false }),
      line({ suggestion_id: "4", bulk_allowed: false }),
    ]);
    expect(ids).toEqual(["1"]);
  });
});

describe("PLAN3-9 line texts", () => {
  it("names the minute categories the visit carries", () => {
    expect(minuteCategoryText(line({ minutes_a: 30 }))).toBe("A 30 min");
    expect(minuteCategoryText(line({ minutes_a: 15, minutes_b: 20, minutes_c: 0 }))).toBe("A 15 min · B 20 min");
    expect(minuteCategoryText(line({ minutes_a: 0, minutes_b: 0, minutes_c: 0 }))).toBe("ohne geplante Minuten");
    expect(minuteCategoryText(line({ is_needs_assessment: true }))).toContain("Bedarfsabklärung");
  });

  it("shows 'ändert bisherige Zuteilung' and 'nicht Bezugspflege/Stellvertretung' only where they apply", () => {
    expect(lineFlags(line({}))).toEqual([]);
    expect(lineFlags(line({ changes_assignment: true, not_continuity: true }))).toEqual([
      "ändert bisherige Zuteilung",
      "nicht Bezugspflege/Stellvertretung",
    ]);
  });

  it("words a decided line, never with the confirmer's name", () => {
    expect(lineDecisionText("open")).toBeNull();
    expect(lineDecisionText("confirmed")).toBe("bestätigt");
    expect(lineDecisionText("corrected")).toBe("geändert und bestätigt");
    expect(lineDecisionText("rejected")).toBe("abgelehnt");
    expect(lineDecisionText("not_found")).toBe("„kein Vorschlag“, entschieden"); // PLAN3-9 (1), ADR-156
    expect(lineDecisionText("unknown_code")).toBe("entschieden");
  });
});

describe("PLAN3-4 load before and after, no maximum", () => {
  it("states this team's minutes now and with the proposal (UXR-98: the scope is said)", () => {
    expect(loadText(60, 120)).toBe("60 → 120 Minuten in eurem Team");
    expect(loadText(0, 0)).toBe("0 Minuten in eurem Team");
    expect(loadText(null, null)).toBeNull();
  });

  it("never judges a load", () => {
    expect(loadText(600, 900)).not.toMatch(/zu viel|über|Maximum|Grenze/i);
  });
});

describe("PLAN3-1 date range: today to 14 days ahead (Europe/Zurich)", () => {
  it("bounds", () => {
    expect(dayPlanDateBounds("2026-11-05")).toEqual({ min: "2026-11-05", max: "2026-11-19" });
    expect(dayPlanDateBounds("2026-12-25")).toEqual({ min: "2026-12-25", max: "2027-01-08" });
  });

  it("accepts only a valid ISO date inside the bounds", () => {
    expect(isDayPlanDate("2026-11-05", "2026-11-05")).toBe(true);
    expect(isDayPlanDate("2026-11-19", "2026-11-05")).toBe(true);
    expect(isDayPlanDate("2026-11-20", "2026-11-05")).toBe(false);
    expect(isDayPlanDate("2026-11-04", "2026-11-05")).toBe(false);
    expect(isDayPlanDate("2026-02-30", "2026-02-01")).toBe(false);
    expect(isDayPlanDate("morgen", "2026-11-05")).toBe(false);
  });
});
