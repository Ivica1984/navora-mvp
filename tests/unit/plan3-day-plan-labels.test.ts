import { describe, expect, it } from "vitest";
import {
  DAY_PLAN_REASONS,
  DAY_PLAN_NOT_FOUND,
  confirmButtonLabel,
  dayPlanRefusalText,
  lineReasonText,
  lineNotFoundText,
  otherTeamVisitsLine,
  switchedOnLine,
} from "@/features/planning/day-plan-labels";
import { refusalText } from "@/features/ai/labels";

/**
 * PLAN3 (ADR-145): the texts the day-plan proposal shows. The database returns codes only
 * (`day_plan.reason`, `day_plan.not_found_reason`, `propose_day_plan` refusal reasons); every code
 * the migration can return must have a text, and the brief's wordings are used where it gives them.
 */
describe("PLAN3-3 reasons", () => {
  it("covers every reason code of day_plan_lines (0109 check constraint)", () => {
    expect(Object.keys(DAY_PLAN_REASONS).sort()).toEqual(
      ["deputy", "free_capacity", "knows_client", "primary_nurse"],
    );
  });

  it("uses the brief's wording", () => {
    expect(lineReasonText("primary_nurse", null)).toBe("Bezugspflegende");
    expect(lineReasonText("deputy", null)).toBe("Stellvertretung");
    expect(lineReasonText("free_capacity", 0)).toBe("freie Kapazität");
  });

  it("names the number of visits for a member who knows the client", () => {
    expect(lineReasonText("knows_client", 3)).toBe("kennt die Klientin (3 Besuche)");
    expect(lineReasonText("knows_client", 1)).toBe("kennt die Klientin (1 Besuch)");
  });

  it("never invents a reason for an unknown code", () => {
    expect(lineReasonText("something_else", 2)).toBeNull();
  });
});

describe("PLAN3-1 kein Vorschlag", () => {
  it("covers every limit code of day_plan_lines (0109 check constraint)", () => {
    expect(Object.keys(DAY_PLAN_NOT_FOUND).sort()).toEqual(["absent", "needs_rn", "not_active", "overlap"]);
  });

  it("starts with 'kein Vorschlag' and names the limit", () => {
    for (const code of Object.keys(DAY_PLAN_NOT_FOUND)) {
      expect(lineNotFoundText(code)).toMatch(/^kein Vorschlag: /);
    }
    expect(lineNotFoundText("needs_rn")).toContain("Pflegefachperson");
  });

  it("falls back to plain 'kein Vorschlag' for an unknown code", () => {
    expect(lineNotFoundText("x")).toBe("kein Vorschlag");
  });
});

describe("PLAN3-6 / PLAN3-10 refusals", () => {
  it("shows 'Vorschlag zurzeit nicht verfügbar' when the agent is off or stopped", () => {
    expect(dayPlanRefusalText("agent_off")).toBe("Vorschlag zurzeit nicht verfügbar");
    expect(dayPlanRefusalText("agent_stopped")).toBe("Vorschlag zurzeit nicht verfügbar");
  });

  it("has a text for every refusal propose_day_plan returns", () => {
    for (const code of ["team_off", "date_out_of_range", "open_proposal", "nothing_open"]) {
      expect(dayPlanRefusalText(code)).not.toBe("");
    }
    expect(dayPlanRefusalText("date_out_of_range")).toContain("14 Tage");
  });

  it("uses no word of pressure or judgement (H-20, PLAN3-4)", () => {
    const all = [
      ...Object.values(DAY_PLAN_REASONS),
      ...Object.values(DAY_PLAN_NOT_FOUND),
      ...["agent_off", "team_off", "date_out_of_range", "open_proposal", "nothing_open"].map(dayPlanRefusalText),
    ].join(" ");
    expect(all).not.toMatch(/sofort|dringend|überlastet|zu viel|Frist|Maximum/i);
  });
});

describe("PLAN3-9 confirm button and PLAN3-10 switch line", () => {
  it("names its count", () => {
    expect(confirmButtonLabel(3)).toBe("3 Zuteilungen bestätigen");
    expect(confirmButtonLabel(1)).toBe("1 Zuteilung bestätigen");
  });

  it("is never a bulk label without a count", () => {
    expect(() => confirmButtonLabel(0)).toThrow();
  });

  it("shows the switch date without a name", () => {
    expect(switchedOnLine("2026-11-05")).toBe("Tagesvorschlag eingeschaltet am 05.11.2026");
    expect(switchedOnLine(null)).toBeNull();
  });
});

describe("PLAN3-14: visits in other teams (cra CGR-136, ADR-146)", () => {
  it("a line refused at confirm for an overlap names the reason, the value stays open", () => {
    expect(refusalText("overlap")).toContain("schon einen Einsatz");
    expect(refusalText("overlap")).not.toBe(refusalText("unexpected"));
  });

  it("the day-load line says only that other-team visits exist: no count, no client, no time", () => {
    expect(otherTeamVisitsLine(true)).toBe("weitere Einsätze in anderen Teams");
    expect(otherTeamVisitsLine(false)).toBeNull();
    expect(otherTeamVisitsLine(null)).toBeNull();
    expect(otherTeamVisitsLine(true)).not.toMatch(/\d/);
  });

  it("uses no word of pressure or judgement (H-20)", () => {
    expect(`${refusalText("overlap")} ${otherTeamVisitsLine(true)}`).not.toMatch(
      /sofort|dringend|überlastet|zu viel|Frist|Maximum/i,
    );
  });
});
