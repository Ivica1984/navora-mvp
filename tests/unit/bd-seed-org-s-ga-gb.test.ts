import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * BD seed completion for Testorganisation S (PO 2026-11-11 10:39, BD brief amendment 10:39; ADR-182). This guard reads
 * files only; pgTAP 125 proves the same on the database after `supabase db reset`.
 *   (G-a) org S gets the same synthetic ASM1 instrument list as Testorganisation A (fixture only, no record);
 *   (G-b) `plan3_day_proposal` is seeded on for org S as for Testorganisation H; only org H and org S have it on;
 *         the team's own switch (PLAN3-10) is not seeded; org S gets no administrator.
 * Fixture only: the seed change adds no grant, policy, function or migration.
 */
const SEED = readFileSync("supabase/seed.sql", "utf8");
const PGTAP = readFileSync("supabase/tests/database/125_bd_seed_org_s_asm1_day_proposal.test.sql", "utf8");

const ORG_A = "00000000-0000-4000-b000-000000000011";
const ORG_H = "00000000-0000-4000-b000-000000000018";
const ORG_S = "00000000-0000-4000-b000-000000000019";
const noComments = (sql: string) => sql.replace(/--[^\n]*/g, "");
const statements = (re: RegExp) => [...noComments(SEED).matchAll(re)].map((m) => m[0]);

type Instrument = { org: string; name: string; version: string; from: string; to: string; mark: string; by: string };

/** Every row of every `insert into public.assessment_instruments ... values` statement of the seed. */
function instruments(): Instrument[] {
  const rows: Instrument[] = [];
  for (const s of statements(/insert\s+into\s+public\.assessment_instruments\s*\([^;]*;/gi)) {
    const re =
      /\(\s*'[0-9a-f-]{36}',\s*'([0-9a-f-]{36})',\s*'([^']+)',\s*'([^']+)',\s*date\s*'([0-9-]+)',\s*(null|date\s*'[0-9-]+'),\s*(true|false),\s*'([0-9a-f-]{36})'\s*\)/gi;
    for (const m of s.matchAll(re)) {
      rows.push({ org: m[1], name: m[2], version: m[3], from: m[4], to: m[5].replace(/\s+/g, " "), mark: m[6], by: m[7] });
    }
  }
  return rows;
}

const key = (i: Instrument) => [i.name, i.version, i.from, i.to, i.mark].join("|");

describe("BD seed Testorganisation S: ASM1 instrument (G-a) and day proposal (G-b)", () => {
  it("GA-1: org S has exactly org A's instrument entries (name, version, validity, mark)", () => {
    const all = instruments();
    const a = all.filter((i) => i.org === ORG_A).map(key).sort();
    const s = all.filter((i) => i.org === ORG_S).map(key).sort();
    expect(a.length).toBeGreaterThan(0);
    expect(s).toEqual(a);
  });

  it("GA-2: org S entries are attributed to a seeded member of org S, and no assessment record is seeded", () => {
    const sAuthors = new Set(instruments().filter((i) => i.org === ORG_S).map((i) => i.by));
    const sMembers = statements(/insert\s+into\s+public\.organization_memberships[^;]*;/gi)
      .flatMap((s) => [...s.matchAll(new RegExp(`'${ORG_S}',\\s*'([0-9a-f-]{36})'`, "g"))].map((m) => m[1]));
    expect(sAuthors.size).toBeGreaterThan(0);
    for (const by of sAuthors) expect(sMembers).toContain(by);
    expect(noComments(SEED)).not.toMatch(/insert\s+into\s+public\.assessment_records/i);
  });

  it("GB-1: only org H and org S have plan3_day_proposal seeded on", () => {
    const on = statements(/insert\s+into\s+public\.ai_agent_settings[^;]*;/gi)
      .filter((s) => /d\.key\s*=\s*'plan3_day_proposal'/.test(s) && /,\s*'on',/.test(s))
      .map((s) => s.match(/select\s+'([0-9a-f-]{36})'/i)?.[1]);
    expect(on.sort()).toEqual([ORG_H, ORG_S].sort());
  });

  it("GB-2: the team's own switch is not seeded and org S gets no administrator", () => {
    expect(noComments(SEED)).not.toMatch(/insert\s+into\s+public\.team_day_proposal_settings/i);
    const adminInS = statements(/insert\s+into\s+public\.organization_memberships[^;]*;/gi)
      .some((s) => new RegExp(`'${ORG_S}',\\s*'[0-9a-f-]{36}',\\s*'admin'`).test(s));
    expect(adminInS).toBe(false);
  });

  it("GX-1: the seed change is fixture only (no grant, policy, function or organisation update in the seed)", () => {
    const sql = noComments(SEED);
    expect(sql).not.toMatch(/\bgrant\s+/i);
    expect(sql).not.toMatch(/create\s+(or\s+replace\s+)?(policy|function)/i);
    expect(sql).not.toMatch(/update\s+public\.organizations/i);
  });

  it("GX-2: pgTAP 125 keeps the PO's acceptance assertions", () => {
    for (const label of [
      "(G-a): Testorganisation S has exactly the instrument entries of Testorganisation A",
      "(G-a): no assessment record is seeded for org S",
      "(G-b): only Testorganisation H and Testorganisation S have plan3_day_proposal on",
      "(G-b): org S has no administrator",
      "(G-b): a member of Testteam Basel switches the day proposal on for her team",
    ]) {
      expect(PGTAP).toContain(label);
    }
  });
});
