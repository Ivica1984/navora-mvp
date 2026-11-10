import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * B0-7 (PRODUCT_BLOCKS.md §4, ADR-176): database privileges. pgTAP 123 checks the catalogue after ALL migrations:
 * no table without RLS, no `anon` grant, every SECURITY DEFINER function with `search_path = ''` and EXECUTE revoked
 * from PUBLIC. This guard reads files only. It keeps the catalogue test complete:
 *   1. every schema a migration creates is in the schema list pgTAP 123 checks (a new schema cannot escape the test);
 *   2. each of the B0-7 assertions is still in the file (a weakening PR turns this red, merge gate condition 7);
 *   3. the checks read the catalogue (pg_class, pg_proc, pg_default_acl), not a hand-kept list of objects.
 */
const MIGRATIONS = "supabase/migrations";
const TEST = "supabase/tests/database/123_b0_7_catalogue_privileges.test.sql";
const read = (p: string) => readFileSync(p, "utf8");

/** Schemas created by a migration (`create schema [if not exists] <name>`), lower case. */
export function schemasCreated(sql: string): string[] {
  const out = new Set<string>();
  const re = /create\s+schema\s+(?:if\s+not\s+exists\s+)?("?)([a-z_][a-z0-9_]*)\1/gi;
  for (const m of sql.replace(/--[^\n]*/g, "").matchAll(re)) out.add(m[2].toLowerCase());
  return [...out];
}

/** The schema list of pgTAP 123: the line `-- B0-7 covered schemas: a, b`. */
export function coveredSchemas(testSql: string): string[] {
  const m = testSql.match(/^-- B0-7 covered schemas: (.+)$/m);
  return m ? m[1].split(",").map((s) => s.trim().toLowerCase()).filter(Boolean) : [];
}

describe("B0-7 catalogue test helpers", () => {
  it("finds created schemas, with and without IF NOT EXISTS, and ignores comments", () => {
    expect(schemasCreated("create schema if not exists private;\n-- create schema ghost;\nCREATE SCHEMA \"Two\";").sort())
      .toEqual(["private", "two"]);
  });
  it("reads the covered-schema line", () => {
    expect(coveredSchemas("begin;\n-- B0-7 covered schemas: public, private\n")).toEqual(["public", "private"]);
    expect(coveredSchemas("begin;\n")).toEqual([]);
  });
});

describe("B0-7: pgTAP 123 covers every migration schema and every criterion", () => {
  const test = read(TEST);
  const covered = coveredSchemas(test);

  it("the test declares public and private as covered schemas", () => {
    expect(covered).toEqual(expect.arrayContaining(["public", "private"]));
  });

  it("every schema a migration creates (except the Supabase extensions schema) is covered", () => {
    const created = new Set<string>();
    for (const f of readdirSync(MIGRATIONS).filter((f) => f.endsWith(".sql"))) {
      for (const s of schemasCreated(read(`${MIGRATIONS}/${f}`))) created.add(s);
    }
    created.delete("extensions");
    expect([...created].filter((s) => !covered.includes(s))).toEqual([]);
  });

  it("the SQL schema array matches the declared list", () => {
    const arr = `array[${covered.map((s) => `'${s}'`).join(", ")}]`;
    expect(test).toContain(arr);
  });

  it.each([
    ["B0-7-1", "relrowsecurity"],
    ["B0-7-2", "aclexplode(c.relacl)"],
    ["B0-7-3", "aclexplode(p.proacl)"],
    ["B0-7-4", "has_schema_privilege('anon'"],
    ["B0-7-5", "pg_default_acl"],
    ["B0-7-6", "search_path=\"\""],
    ["B0-7-7", "acldefault('f', p.proowner)"],
  ])("assertion %s is present and reads the catalogue (%s)", (tag, needle) => {
    const block = test.split(`'${tag}:`)[0].split(/\nselect /).pop() ?? "";
    expect(test).toContain(`'${tag}:`);
    expect(block).toContain(needle);
  });

  it("runs as one transaction with a fixed plan and rolls back", () => {
    expect(test).toMatch(/^begin;/m);
    expect(test).toMatch(/select plan\(\d+\);/);
    expect(test.trimEnd().endsWith("rollback;")).toBe(true);
  });
});
