import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * Owner directive 2026-11-03 (#824, ADR-141, migration 0107): no assistant may propose a billing value or change a
 * safety signal's priority. The classifier `private.aig1_prohibited_target` names the tables; pgTAP 108 checks the
 * register and the AIG1 functions against the same set. This file keeps the three in step: every billing or
 * safety-signal table any migration creates is covered by the classifier, and pgTAP 108's write check names the same
 * explicit tables.
 */
const MIGRATIONS = "supabase/migrations";
const MIGRATION = `${MIGRATIONS}/20261021000107_aig1_prohibited_targets.sql`;
const PGTAP = "supabase/tests/database/108_ai_prohibited_targets.test.sql";

const migration = readFileSync(MIGRATION, "utf8");
const pgtap = readFileSync(PGTAP, "utf8");

function classifierBody(): string {
  const from = migration.indexOf("create or replace function private.aig1_prohibited_target(");
  const to = migration.indexOf("$$;", from);
  expect(from, "0107 defines the classifier").toBeGreaterThanOrEqual(0);
  return migration.slice(from, to);
}

/** The explicit table names the classifier lists, and whether it covers the signal_* prefix. */
function classifierTables(): { names: Set<string>; signalPrefix: boolean } {
  const body = classifierBody();
  const names = new Set<string>();
  for (const m of body.matchAll(/'([a-z_]+)'/g)) {
    if (m[1] !== "billing" && m[1] !== "safety_signal") names.add(m[1]);
  }
  return { names, signalPrefix: /like 'signal\\_%'/.test(body) };
}

function covered(table: string): boolean {
  const { names, signalPrefix } = classifierTables();
  return names.has(table) || (signalPrefix && table.startsWith("signal_"));
}

function createdTables(): string[] {
  const tables = new Set<string>();
  for (const file of readdirSync(MIGRATIONS).filter((f) => f.endsWith(".sql"))) {
    const sql = readFileSync(`${MIGRATIONS}/${file}`, "utf8");
    for (const m of sql.matchAll(/create table (?:if not exists )?public\.([a-z_]+)/gi)) tables.add(m[1].toLowerCase());
  }
  return [...tables];
}

describe("AI prohibited targets (#824)", () => {
  it("lists the billing and safety-signal-priority tables", () => {
    const { names, signalPrefix } = classifierTables();
    for (const t of [
      "billable_facts",
      "billing_rules",
      "tariff_rates",
      "quality_holds",
      "safety_signals",
      "exception_rules",
      "exception_rule_overrides",
    ]) {
      expect(names.has(t), `${t} is in the classifier`).toBe(true);
    }
    expect(signalPrefix, "every signal_* table is covered").toBe(true);
  });

  it("does not list the one field the register holds (the visit's responsible member)", () => {
    expect(covered("care_visits")).toBe(false);
  });

  it("covers every billing, tariff or signal table any migration creates", () => {
    const relevant = createdTables().filter((t) =>
      /^(billable_|billing_|tariff_|safety_signal|signal_|exception_rule)/.test(t),
    );
    expect(relevant.length).toBeGreaterThan(5);
    for (const t of relevant) expect(covered(t), `${t} is covered by private.aig1_prohibited_target`).toBe(true);
  });

  it("checks the AIG1 functions against the same tables in pgTAP 108", () => {
    const m = pgtap.match(/public\\\.\(([a-z_|+\[\]-]+)\)\\M/);
    expect(m, "pgTAP 108 has the write check").not.toBeNull();
    const listed = new Set(m![1].split("|"));
    const { names } = classifierTables();
    for (const t of names) expect(listed.has(t), `${t} is in the pgTAP 108 write check`).toBe(true);
    expect(listed.has("signal_[a-z_]+"), "the pgTAP 108 write check covers signal_*").toBe(true);
  });

  it("refuses with 42501 and adds no grant", () => {
    expect(migration).toMatch(/using errcode = '42501'/);
    expect(migration).not.toMatch(/^\s*grant\s/im);
    expect(migration).toMatch(/revoke all on function private\.aig1_prohibited_target\(text, text\) from public, anon, authenticated/);
  });
});
