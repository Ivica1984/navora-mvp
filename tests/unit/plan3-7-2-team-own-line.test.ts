import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { PLAN_TEAM_LINE_ERROR, planTeamMeasureCells, planTeamOwnLine, SUPPRESSED_TEXT, type PlanTeamMeasure } from "@/features/ai/labels";

// PLAN3-7 (2) (po 2026-11-06 06:30, `aia` AUT-52); ADR-155. The team holds the PLAN3-10 switch, so it sees its own
// day-plan measures under that switch on /team/tagesplan: one information line from the same reader
// (`plan3_team_measures`) and the same suppression as Operations. No new read, no target, no other team, no person.
// Written before the code (eng run 2026-11-06 06:15).
const root = process.cwd();
const page = readFileSync(join(root, "src/app/(protected)/team/tagesplan/page.tsx"), "utf8");
const client = readFileSync(join(root, "src/app/(protected)/team/tagesplan/day-plan-client.tsx"), "utf8");

const row: PlanTeamMeasure = {
  team_id: "t1",
  team_name: "Testteam G",
  month: "2026-11-01",
  enabled_since: "2026-11-03",
  day_plans: 4,
  lines: 20,
  decided_lines: 16,
  confirmed_unchanged_share: 75,
  corrected_share: 19,
  rejected_share: 6,
  confirm_actions_per_plan: 1.5,
  minutes_to_last_decision_median: 12.5,
  no_proposal: 3,
  no_proposal_share: 15,
  no_proposal_not_active: 0,
  no_proposal_needs_rn: 1,
  no_proposal_absent: 0,
  no_proposal_overlap: 2,
  proposal_suppressed: false,
  continuity_before_share: 40,
  continuity_before_base: 10,
  continuity_after_share: 60,
  continuity_after_base: 15,
  continuity_suppressed: false,
};

describe("PLAN3-7 (2): the team's own line", () => {
  it("reads the brief's line: day plans, share confirmed unchanged, share without a proposal", () => {
    expect(planTeamOwnLine(row)).toBe("Diesen Monat: 4 Tagesvorschläge · 75 % unverändert bestätigt · 15 % ohne Vorschlag");
  });

  it("uses the singular for one day plan", () => {
    expect(planTeamOwnLine({ ...row, day_plans: 1 })).toBe(
      "Diesen Monat: 1 Tagesvorschlag · 75 % unverändert bestätigt · 15 % ohne Vorschlag",
    );
  });

  it("reads a missing share as '–', never 0", () => {
    expect(planTeamOwnLine({ ...row, confirmed_unchanged_share: null, decided_lines: 0 })).toBe(
      "Diesen Monat: 4 Tagesvorschläge · – unverändert bestätigt · 15 % ohne Vorschlag",
    );
  });

  it("with fewer than three confirmers keeps the count and hides the shares as Operations does (AIG1-7)", () => {
    const text = planTeamOwnLine({ ...row, proposal_suppressed: true, confirmed_unchanged_share: null, no_proposal_share: null });
    expect(text).toBe(`Diesen Monat: 4 Tagesvorschläge · Anteile ${SUPPRESSED_TEXT}`);
    expect(text).not.toContain("%");
  });

  it("says 'noch kein Tagesvorschlag' without a row or with no day plan, never a 0 % share", () => {
    expect(planTeamOwnLine(undefined)).toBe("Diesen Monat: noch kein Tagesvorschlag");
    expect(planTeamOwnLine({ ...row, day_plans: 0, lines: 0 })).toBe("Diesen Monat: noch kein Tagesvorschlag");
  });

  it("names no team, no person, no target and no comparison", () => {
    for (const t of [planTeamOwnLine(row), planTeamOwnLine({ ...row, proposal_suppressed: true })]) {
      expect(t).not.toContain(row.team_name);
      expect(t).not.toMatch(/Ziel|Durchschnitt|andere Teams|Rang|besser|schlechter/);
    }
  });

  it("has a read-failure text that is not a zero", () => {
    expect(PLAN_TEAM_LINE_ERROR).toBe("Die Zahlen dieses Monats konnten nicht geladen werden.");
    expect(PLAN_TEAM_LINE_ERROR).not.toMatch(/\d/);
  });

  it("the month's cells on the team page are the Operations cells for the same row", () => {
    expect(planTeamMeasureCells(row).map((c) => c.key)).toEqual([
      "day_plans",
      "confirmed_unchanged",
      "corrected",
      "rejected",
      "actions",
      "minutes",
      "no_proposal",
      "continuity",
    ]);
  });
});

describe("PLAN3-7 (2): no new read, the selected team's row only", () => {
  it("the page reads the measures through the existing reader for the current Zurich month", () => {
    expect(page).toContain("getPlanTeamMeasures(monthParam(undefined))");
    expect(page).not.toContain('rpc("');
  });

  it("the page passes on only the selected team's row, found by its id", () => {
    expect(page).toMatch(/\.find\(\(m\) => m\.team_id === selected\.team_id\)/);
  });

  it("the client shows the line under the switch with its own test id and the cells in a disclosure", () => {
    expect(client).toContain('data-testid="day-plan-measures"');
    expect(client).toContain('data-testid="day-plan-measures-cells"');
    expect(client).toContain("planTeamOwnLine(");
    expect(client).toContain("planTeamMeasureCells(");
  });
});
