import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { continuityText, monthParam, noProposalText, planTeamMeasureCells } from "@/features/ai/labels";

// PLAN3-7 (ADR-151, brief PLAN3-7 as amended 2026-10-30 03:10, `aia` AUT-1 / AUT-25): per team and Zurich month, never
// per person, how the day-plan assistant is used. Written before the code (eng run 2026-11-06 01:10).
const root = process.cwd();
const migration = readFileSync(join(root, "supabase/migrations/20261021000113_plan3_7_team_measures.sql"), "utf8");
const page = readFileSync(join(root, "src/app/(protected)/operations/assistenten/tagesvorschlag/page.tsx"), "utf8");

const row = {
  team_id: "t1",
  team_name: "Testteam G",
  month: "2026-11-01",
  enabled_since: "2026-11-03" as string | null,
  day_plans: 4,
  lines: 20,
  decided_lines: 16 as number | null,
  confirmed_unchanged_share: 75 as number | null,
  corrected_share: 18.8 as number | null,
  confirm_actions_per_plan: 1.5 as number | null,
  minutes_to_last_decision_median: 12.5 as number | null,
  no_proposal: 3 as number | null,
  no_proposal_share: 15 as number | null,
  no_proposal_not_active: 0 as number | null,
  no_proposal_needs_rn: 1 as number | null,
  no_proposal_absent: 0 as number | null,
  no_proposal_overlap: 2 as number | null,
  proposal_suppressed: false,
  continuity_before_share: 40 as number | null,
  continuity_before_base: 10,
  continuity_after_share: 60 as number | null,
  continuity_after_base: 15,
  continuity_suppressed: false,
};

describe("PLAN3-7 cells", () => {
  it("lists the team measures in a fixed order", () => {
    expect(planTeamMeasureCells(row)).toEqual([
      { key: "day_plans", label: "Tagesvorschläge", value: "4 · 20 Zeilen" },
      { key: "confirmed_unchanged", label: "Unverändert bestätigt", value: "75 % · 16 entschieden" },
      { key: "corrected", label: "Geändert (Gegenmass)", value: "18.8 %" },
      { key: "actions", label: "Bestätigungen pro Tagesvorschlag", value: "1.5" },
      { key: "minutes", label: "Minuten bis zur letzten Entscheidung (Median)", value: "12.5 Min." },
      { key: "no_proposal", label: "Kein Vorschlag", value: "15 % · 3 Zeilen (Nicht verfügbar 0 · Pflegefachperson nötig 1 · Abwesend 0 · Überschneidung 2)" },
      { key: "continuity", label: "Einsätze durch Bezugs- oder Stellvertretungsperson", value: "vorher 40 % (10) · seit Einschalten 60 % (15)" },
    ]);
  });

  it("hides every confirmed share of a small team (AIG1-7) but keeps the plan count", () => {
    const cells = planTeamMeasureCells({
      ...row,
      proposal_suppressed: true,
      decided_lines: null,
      confirmed_unchanged_share: null,
      corrected_share: null,
      confirm_actions_per_plan: null,
      minutes_to_last_decision_median: null,
      no_proposal: null,
      no_proposal_share: null,
      no_proposal_not_active: null,
      no_proposal_needs_rn: null,
      no_proposal_absent: null,
      no_proposal_overlap: null,
    });
    expect(cells[0].value).toBe("4 · 20 Zeilen");
    for (const c of cells.slice(1, 6)) expect(c.value).toBe("nicht ausgewiesen (weniger als 3 Personen)");
  });

  it("never shows a missing value as zero", () => {
    expect(noProposalText(null, null, null)).toBe("–");
    expect(continuityText(null, 0, null, 0, false, null)).toBe("nie eingeschaltet · – (0)");
    expect(continuityText(40, 10, null, 0, false, null)).toBe("nie eingeschaltet · 40 % (10)");
    expect(continuityText(null, 0, 50, 4, false, "2026-11-01")).toBe("vorher – (0) · seit Einschalten 50 % (4)");
    expect(continuityText(40, 10, 60, 15, true, "2026-11-03")).toBe("nicht ausgewiesen (weniger als 3 Personen)");
  });

  it("reads the month from ?monat=YYYY-MM and falls back to the current month", () => {
    expect(monthParam("2026-10", new Date("2026-11-06T00:10:00Z"))).toBe("2026-10-01");
    expect(monthParam("2026-13", new Date("2026-11-06T00:10:00Z"))).toBe("2026-11-01");
    expect(monthParam(undefined, new Date("2026-11-30T23:30:00Z"))).toBe("2026-12-01"); // Zurich: 1 December 00:30
  });
});

describe("PLAN3-7 migration and page", () => {
  it("adds one read-only function with no person, confirmer or outcome column", () => {
    expect(migration).toMatch(/create or replace function public\.plan3_team_measures\(p_month date\)/);
    expect(migration).not.toMatch(/\b(insert|update|delete)\s+(into|public\.|from)/i);
    const returns = migration.match(/function public\.plan3_team_measures\(p_month date\)\s*returns table \(([^)]*)\)/)?.[1] ?? "";
    expect(returns).toContain("corrected_share");
    expect(returns).toContain("continuity_after_share");
    expect(returns).not.toMatch(/confirmer|confirmed_by|outcome|user|person|member|actor|nurse_id|_by\b/);
  });

  it("keeps the AIG1-7 scope, LEAVE1-3 and the three-person suppression", () => {
    expect(migration).toMatch(/private\.is_team_member\(t\.id\) or private\.is_coordinator\(t\.organization_id\)/);
    expect(migration).toMatch(/not private\.access_ended/);
    expect(migration).toMatch(/count\(distinct [a-z.]*confirmed_by\)[^<]*< 3/);
    expect(migration).toMatch(/private\.pilot_team_people/);
  });

  it("shows the measure per team on the Operations page without a person column", () => {
    expect(page).toContain("getPlanTeamMeasures");
    expect(page).toContain('data-testid="plan-team-measures"');
    expect(page).toContain("planTeamMeasureCells");
    expect(page).not.toMatch(/bestätigt von|confirmed_by|display_name|member_name/);
  });
});
