import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * RLS4-C1 (po 2026-10-30 06:10, `cra` CGR-101; ADR-122 addendum): the runbook check in OWNER_RUNBOOK.md §5c and the
 * query pgTAP 105 asserts on the synthetic seed are the same text, so the tested check is the one a person runs.
 */
const BEGIN = "-- RLS4-C1 check begin";
const END = "-- RLS4-C1 check end";

function checkText(path: string): string {
  const source = readFileSync(path, "utf8");
  const from = source.indexOf(BEGIN);
  const to = source.indexOf(END);
  expect(from, `${path} has the begin marker`).toBeGreaterThanOrEqual(0);
  expect(to, `${path} has the end marker after it`).toBeGreaterThan(from);
  return source.slice(from + BEGIN.length, to).replace(/\s+/g, " ").trim();
}

describe("RLS4-C1 runbook check", () => {
  const runbook = checkText("docs/engineering/OWNER_RUNBOOK.md");
  const pgtap = checkText("supabase/tests/database/105_rls4_c1_legacy_name_check.test.sql");

  it("is identical in the runbook and in pgTAP 105", () => {
    expect(runbook).toBe(pgtap);
  });

  it("counts (never lists) non-cancelled visits of today or later with a legacy name and no responsible member", () => {
    expect(runbook).toMatch(/^select count\(\*\)::int as unmapped from public\.care_visits v where /);
    for (const part of [
      "v.status <> 'cancelled'",
      "v.visit_date >= (private.at_zurich(private.now()))::date",
      "v.team_member_name is not null",
      "v.responsible_user_id is null",
    ]) expect(runbook).toContain(part);
    expect(runbook).not.toMatch(/team_member_name\s*,|group by|update|delete|insert/i);
  });

  it("the runbook never edits, blanks or drops team_member_name", () => {
    const section = readFileSync("docs/engineering/OWNER_RUNBOOK.md", "utf8").split("## 5c.")[1]?.split("\n## ")[0] ?? "";
    const sql = [...section.matchAll(/```sql\n([\s\S]*?)```/g)].map((m) => m[1]).join("\n");
    expect(sql).not.toMatch(/set\s+team_member_name|team_member_name\s*=\s*(null|'')|drop\s+column/i);
    expect(sql).toContain("set local navora.command = 'rls4_c1_legacy_mapping'");
  });
});
