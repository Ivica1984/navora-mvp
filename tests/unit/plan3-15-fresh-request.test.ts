import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { planTeamMeasureCells, refusalText } from "@/features/ai/labels";
import { DAY_PLAN_REFUSAL_CODES, dayPlanRefusalText } from "@/features/planning/day-plan-labels";

// PLAN3-15 (po 2026-11-06 06:30 in PO PR #893, `aia` AUT-51, `cra` 15:00 conditions; ADR-157, migration 0116): a fresh
// request for the same team and day closes the earlier undecided lines with an outcome of their own and writes the new
// lines; the `open_proposal` refusal is gone. Written before the code (eng run 2026-11-06 08:15).
const root = process.cwd();
const read = (p: string) => readFileSync(join(root, p), "utf8");
const migration = read("supabase/migrations/20261021000116_plan3_15_fresh_request_closes_lines.sql");
const pgtap = read("supabase/tests/database/116_plan3_15_fresh_request.test.sql");
const client = read("src/app/(protected)/team/tagesplan/day-plan-client.tsx");

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
  rejected_share: 6.3 as number | null,
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

describe("PLAN3-15: no refusal for an earlier undecided proposal", () => {
  it("propose_day_plan no longer returns open_proposal, so the app has no text and no redirect for it", () => {
    expect(DAY_PLAN_REFUSAL_CODES).not.toContain("open_proposal");
    expect(DAY_PLAN_REFUSAL_CODES).toEqual(["agent_off", "agent_stopped", "team_off", "date_out_of_range", "nothing_open"]);
    expect(dayPlanRefusalText("open_proposal")).toBe("Vorschlag zurzeit nicht verfügbar");
    expect(client).not.toContain("open_proposal");
  });

  it("a closed line confirmed from an old screen is refused with its own text, never 'bestätigt'", () => {
    expect(refusalText("replaced")).toBe("Nicht übernommen: Für diesen Tag wurde neu vorgeschlagen. Diese Zeile gilt nicht mehr.");
    expect(refusalText("replaced")).not.toMatch(/bestätigt/);
  });
});

describe("PLAN3-15 / PLAN3-7: closing is counted apart from the three decision shares", () => {
  it("shows requests that closed earlier lines and the lines closed, after the shares", () => {
    const cells = planTeamMeasureCells({ ...row, requests_closing: 2, lines_closed: 5 });
    const keys = cells.map((c) => c.key);
    expect(keys.indexOf("replaced")).toBeGreaterThan(keys.indexOf("rejected"));
    expect(cells.find((c) => c.key === "replaced")).toEqual({
      key: "replaced",
      label: "Neu angefragt (frühere offene Zeilen ersetzt)",
      value: "2 Anfragen · 5 Zeilen ersetzt",
    });
  });

  it("uses the singular and says 'keine' for none; counts stay visible under the three-person rule (not a decision)", () => {
    expect(planTeamMeasureCells({ ...row, requests_closing: 1, lines_closed: 1 }).find((c) => c.key === "replaced")?.value)
      .toBe("1 Anfrage · 1 Zeile ersetzt");
    expect(planTeamMeasureCells({ ...row, requests_closing: 0, lines_closed: 0 }).find((c) => c.key === "replaced")?.value)
      .toBe("keine");
    expect(
      planTeamMeasureCells({ ...row, proposal_suppressed: true, requests_closing: 2, lines_closed: 3 }).find((c) => c.key === "replaced")
        ?.value,
    ).toBe("2 Anfragen · 3 Zeilen ersetzt");
  });

  it("leaves the shares untouched: a closed line is not decided (unchanged + corrected + rejected = 100 %)", () => {
    const cells = planTeamMeasureCells({ ...row, requests_closing: 2, lines_closed: 5 });
    expect(cells.find((c) => c.key === "confirmed_unchanged")?.value).toContain("16 entschieden");
  });

  it("a row from before 0116 (no closing columns) shows no extra cell", () => {
    expect(planTeamMeasureCells(row).map((c) => c.key)).not.toContain("replaced");
  });
});

describe("PLAN3-15: the migration and its pgTAP file", () => {
  it("records the closing outcome in an append-only, audited table with RLS and no grant to app roles", () => {
    expect(migration).toMatch(/create table if not exists public\.day_plan_line_closures/);
    expect(migration).toMatch(/alter table public\.day_plan_line_closures enable row level security/);
    expect(migration).toMatch(/revoke all on public\.day_plan_line_closures from public, anon, authenticated/);
    expect(migration).toMatch(/private\.aig1_append_only\(\)/);
    expect(migration).toMatch(/private\.write_audit_event\(/);
  });

  it("removes the open_proposal refusal and closes only undecided lines of still-open visits", () => {
    const fn = migration.slice(migration.indexOf("create or replace function public.propose_day_plan"));
    expect(fn.slice(0, fn.indexOf("$$;"))).not.toContain("'open_proposal'");
    expect(migration).toMatch(/insert into public\.day_plan_line_closures/);
  });

  it("covers the brief's pgTAP scenario", () => {
    for (const s of ["overlap", "open_suggestions", "day_plan_line_closures", "replaced", "unchanged"]) {
      expect(pgtap).toContain(s);
    }
  });
});
