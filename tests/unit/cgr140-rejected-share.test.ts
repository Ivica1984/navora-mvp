import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { planTeamMeasureCells } from "@/features/ai/labels";

// CGR-140 (`cra` 2026-11-06 01:30, advisory S3; `aia` review 32 supports option (a)); ADR-153. PLAN3-7 counted a
// rejected line as decided but in neither share. Option (a): a third share "Abgelehnt" (rejected ÷ decided), so
// unchanged + corrected + rejected add up to the decided lines. Written before the code (eng run 2026-11-06 03:10).
const root = process.cwd();
const migration = readFileSync(join(root, "supabase/migrations/20261021000114_cgr140_plan3_rejected_share.sql"), "utf8");
const pgtap = readFileSync(join(root, "supabase/tests/database/114_plan3_7_team_measures.test.sql"), "utf8");

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

describe("CGR-140: the rejected share", () => {
  it("shows \"Abgelehnt\" right after the correction share", () => {
    const cells = planTeamMeasureCells(row);
    const keys = cells.map((c) => c.key);
    expect(keys.slice(1, 4)).toEqual(["confirmed_unchanged", "corrected", "rejected"]);
    expect(cells.find((c) => c.key === "rejected")).toEqual({ key: "rejected", label: "Abgelehnt", value: "6.3 %" });
  });

  it("reads a missing rejected share as \"–\", never 0, and hides it for a small team", () => {
    expect(planTeamMeasureCells({ ...row, rejected_share: null }).find((c) => c.key === "rejected")?.value).toBe("–");
    const hidden = planTeamMeasureCells({ ...row, proposal_suppressed: true, rejected_share: null });
    expect(hidden.find((c) => c.key === "rejected")?.value).toBe("nicht ausgewiesen (weniger als 3 Personen)");
  });

  it("redefines plan3_team_measures with rejected_share, keeping scope, suppression and no person column", () => {
    expect(migration).toMatch(/drop function if exists public\.plan3_team_measures\(date\)/);
    expect(migration).toMatch(/create function public\.plan3_team_measures\(p_month date\)/);
    const returns = migration.match(/function public\.plan3_team_measures\(p_month date\)\s*returns table \(([^)]*)\)/)?.[1] ?? "";
    expect(returns).toMatch(/corrected_share numeric,\s*rejected_share numeric/);
    expect(returns).not.toMatch(/confirmer|confirmed_by|outcome|user|person|member|actor|nurse_id|_by\b/);
    expect(migration).toMatch(/l\.outcome = 'rejected'/);
    expect(migration).toMatch(/private\.is_team_member\(t\.id\) or private\.is_coordinator\(t\.organization_id\)/);
    expect(migration).toMatch(/not private\.access_ended/);
    expect(migration).toMatch(/count\(distinct [a-z.]*confirmed_by\)[^<]*< 3/);
    expect(migration).toMatch(/revoke all on function public\.plan3_team_measures\(date\) from public, anon/);
    expect(migration).toMatch(/grant execute on function public\.plan3_team_measures\(date\) to authenticated/);
    expect(migration).not.toMatch(/\b(insert|update|delete)\s+(into|public\.|from)/i);
    // the 0113 header said "corrected or rejected" for corrected_share; the corrected header must not repeat it
    expect(migration).not.toMatch(/corrected_share[^\n]*corrected or rejected/);
  });

  it("has a pgTAP case with a rejected line where the three shares add up to 100 %", () => {
    expect(pgtap).toMatch(/'rejected'/);
    expect(pgtap).toMatch(/rejected_share/);
    expect(pgtap).toMatch(/CGR-140/);
  });
});
