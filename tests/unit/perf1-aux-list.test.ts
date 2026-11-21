import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { DEGRADABLE_LISTS, VISIT_ALERTS_UNAVAILABLE_NOTICE, loaded, showsUnavailableNotice, unavailable } from "@/features/team/aux-list";

// PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 20:39 (2), (3); CGR-272, CGR-273).
describe("PERF1 auxiliary hint list", () => {
  it("a loaded list shows no notice, also when it is empty", () => {
    expect(showsUnavailableNotice(loaded([]))).toBe(false);
    expect(showsUnavailableNotice(loaded(null))).toBe(false);
    expect(loaded(null).rows).toEqual([]);
  });

  it("a failed list is never an empty list without the notice (CGR-272)", () => {
    const l = unavailable<{ id: string }>();
    expect(l.rows).toEqual([]);
    expect(showsUnavailableNotice(l)).toBe(true);
  });

  it("uses the brief's working wording", () => {
    expect(VISIT_ALERTS_UNAVAILABLE_NOTICE).toBe("Hinweise zu Einsätzen konnten nicht geladen werden.");
  });

  it("only team_visit_alerts degrades; the safety list stays fail-hard (CGR-273)", () => {
    expect([...DEGRADABLE_LISTS]).toEqual(["team_visit_alerts"]);
    const field = readFileSync("src/features/field/queries.ts", "utf8");
    const safety = field.slice(field.indexOf("export async function getSafetyAlerts"));
    expect(safety.slice(0, safety.indexOf("\n}\n"))).toMatch(/throw new Error/);
    const migration = readFileSync("supabase/migrations/20261021000165_perf1_aux_list_failures.sql", "utf8");
    expect(migration).toContain("check (list_key in ('team_visit_alerts'))");
    expect(migration).toContain("p_list not in ('team_visit_alerts')");
  });

  it("the failed load is logged and counted, and the count never throws (queries.ts)", () => {
    const q = readFileSync("src/features/team/queries.ts", "utf8");
    const fn = q.slice(q.indexOf("export async function getTeamVisitAlerts"));
    expect(fn).toContain('"team.visit_alerts_unavailable"');
    expect(fn).toContain('rpc("record_aux_list_failure", { p_list: "team_visit_alerts" })');
    expect(fn).not.toMatch(/throw /);
  });
});
