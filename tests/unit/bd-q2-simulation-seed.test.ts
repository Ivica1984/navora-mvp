import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * BD / Q-BD-2 (brief docs/agents/briefs/BD.md amendment 2026-11-11 05:39; `cra` CGR-177; ADR-180): one synthetic
 * simulation organisation in the seed, so the BD run can reach the QUAL1 matrix with login accounts. This guard reads
 * files only; pgTAP 124 proves the same on the database after `supabase db reset`.
 *   (a) the organisation is labelled synthetic, its evidence is written by the fixture path only (no recorded_by, no
 *       self_confirmed row, verified only);
 *   (b) exactly one organisation in the seed is a simulation; migration 0124 guards the flag against every app role and
 *       command; pgTAP 124 asserts it;
 *   (c) Testorganisation A is not a simulation (its insert names no `simulation` column);
 *   pgTAP 002 counts the seeded sign-in accounts, so it must follow the seed.
 */
const SEED = readFileSync("supabase/seed.sql", "utf8");
const MIGRATION = readFileSync("supabase/migrations/20261021000124_bd_q2_simulation_flag_guard.sql", "utf8");
const PGTAP = readFileSync("supabase/tests/database/124_bd_q2_simulation_seed.test.sql", "utf8");
const PGTAP_002 = readFileSync("supabase/tests/database/002_auth_seed.test.sql", "utf8");

const SIM_ORG = "00000000-0000-4000-b000-000000000019";
const SIM_TEAM = "00000000-0000-4000-a000-0000000001b9";
const noComments = (sql: string) => sql.replace(/--[^\n]*/g, "");

/** Every `insert into public.organizations (...) values (...)` statement of the seed, without comments. */
function orgInserts(sql: string): string[] {
  return [...noComments(sql).matchAll(/insert\s+into\s+public\.organizations\s*\([^;]*;/gi)].map((m) => m[0]);
}

describe("BD Q-BD-2 seed simulation organisation (CGR-177)", () => {
  it("Q2-1 (b): exactly one seeded organisation is a simulation, and it is the Basel organisation", () => {
    const withFlag = orgInserts(SEED).filter((s) => /\bsimulation\b/i.test(s));
    expect(withFlag).toHaveLength(1);
    expect(withFlag[0]).toContain(SIM_ORG);
    expect(withFlag[0]).toMatch(/,\s*true\s*\)/);
    expect(noComments(SEED)).not.toMatch(/update\s+public\.organizations/i);
  });

  it("Q2-2 (a): the organisation is labelled synthetic in its name", () => {
    const stmt = orgInserts(SEED).find((s) => s.includes(SIM_ORG)) ?? "";
    expect(stmt).toMatch(/synthetisch/i);
    expect(stmt).toMatch(/Simulation/);
  });

  it("Q2-3 (c): Testorganisation A is seeded without the simulation flag", () => {
    const a = orgInserts(SEED).find((s) => s.includes("00000000-0000-4000-b000-000000000011")) ?? "";
    expect(a).toContain("Testorganisation A");
    expect(a).not.toMatch(/simulation/i);
  });

  it("Q2-4: the simulation team lies in the synthetic region Basel-Stadt (Q-BD-3)", () => {
    const team = noComments(SEED).split("\n").find((l) => l.includes(SIM_TEAM) && /'Basel-Stadt'/.test(l));
    expect(team).toBeDefined();
  });

  it("Q2-5 (a): evidence is written only for the simulation organisation, verified, without recorded_by", () => {
    const stmts = [...noComments(SEED).matchAll(/insert\s+into\s+public\.member_qualification_evidence[^;]*;/gi)].map((m) => m[0]);
    expect(stmts.length).toBeGreaterThan(0);
    for (const s of stmts) {
      expect(s).toContain(SIM_ORG);
      expect(s).not.toMatch(/recorded_by|self_confirmed/);
      expect(s).toMatch(/'verified'/);
    }
  });

  it("Q2-6: pgTAP 002 counts every seeded sign-in account (one bcrypt password each)", () => {
    const signIn = (SEED.match(/extensions\.crypt\(/g) ?? []).length;
    const counts = [...PGTAP_002.matchAll(/^\s*(\d+),\s*$/gm)].map((m) => Number(m[1]));
    expect(counts).toEqual([signIn, 0, signIn]);
  });

  it("Q2-7 (b): migration 0124 guards organizations.simulation against app roles and commands, idempotently", () => {
    const sql = noComments(MIGRATION);
    expect(sql).toMatch(/create or replace function private\.organizations_simulation_guard\(\)/);
    expect(sql).toMatch(/set search_path = ''/);
    expect(sql).toMatch(/auth\.uid\(\)/);
    expect(sql).toMatch(/current_setting\('navora\.command', true\)/);
    expect(sql).toMatch(/'authenticated', 'anon', 'service_role'/);
    expect(sql).toMatch(/errcode = '42501'/);
    expect(sql).toMatch(/drop trigger if exists organizations_simulation_guard on public\.organizations/);
    expect(sql).toMatch(/before insert or update of simulation on public\.organizations/);
    expect(sql).toMatch(/revoke all on function private\.organizations_simulation_guard\(\) from public, anon, authenticated/);
    expect(sql).not.toMatch(/\bgrant\b/i);
  });

  it("Q2-8: pgTAP 124 keeps every CGR-177 assertion", () => {
    for (const label of [
      "CGR-177 (b): exactly one simulation organisation",
      "CGR-177 (b): authenticated may not update organizations",
      "CGR-177 (b): service_role may not set organizations.simulation",
      "CGR-177 (b): no command may set organizations.simulation",
      "CGR-177 (a): every evidence row of the simulation organisation is a synthetic fixture",
      "CGR-177 (c): Testorganisation A is not a simulation",
      "CGR-177: a care assistant is refused on a KLV-B visit",
      "CGR-177: a registered nurse is not refused on a KLV-B visit",
    ]) {
      expect(PGTAP).toContain(label);
    }
  });
});
