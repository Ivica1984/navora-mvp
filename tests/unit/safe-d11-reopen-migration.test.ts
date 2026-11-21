import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * SAFE-D11 (brief docs/agents/briefs/SAFE-D11.md; ADR-184): a reopened case without a team gets a new admissible team
 * search (R1) or a visible Operations exception (R2), never neither, and nothing assigns a team (R5). This guard reads
 * files only; pgTAP 129 and 130 prove the behaviour on the database after `supabase db reset`.
 */
const PATH = "supabase/migrations/20261021000125_safe_d11_reopened_case_search_or_exception.sql";
const noComments = (sql: string) => sql.replace(/--[^\n]*/g, "");

describe("SAFE-D11 migration 0125", () => {
  it("exists, with the pgTAP files that prove it", () => {
    expect(existsSync(PATH)).toBe(true);
    expect(existsSync("supabase/tests/database/129_d11_reopened_case_team_search.test.sql")).toBe(true);
    expect(existsSync("supabase/tests/database/130_safe_d11_reopen_exception.test.sql")).toBe(true);
  });

  const sql = existsSync(PATH) ? readFileSync(PATH, "utf8") : "";
  const code = noComments(sql);

  it("R5: never sets assigned_team_id and grants or widens nothing", () => {
    expect(code).not.toMatch(/assigned_team_id\s*=(?!\s*p_|=)/i);
    expect(code).not.toMatch(/\bset\s+assigned_team_id\b/i);
    expect(code).not.toMatch(/create\s+policy|alter\s+table|grant\s+(select|insert|update|delete)/i);
  });

  it("R1: reopen goes through the first-search path (open_matching_if_ready), only for a case without a team", () => {
    // both are patches of the current definitions, so the first-search insert (private.now(), RET1, 0086) is kept as is
    expect(code).toContain("select private.safe_d11_patch('private.open_matching_if_ready(uuid)'");
    expect(code).toContain("select private.safe_d11_patch('public.reopen_case(uuid, text, uuid)'");
    expect(sql).toContain("|| E'  if c.assigned_team_id is null then\\n'\n  || E'    perform private.open_matching_if_ready(c.id);\\n'");
    expect(sql).toContain("m.status <> ''withdrawn''");
    // no function is replaced wholesale, and no body reads now() directly (ADR-081)
    expect(code).not.toMatch(/create\s+or\s+replace\s+function\s+(public|private)\.(open_matching_if_ready|reopen_case)/i);
    expect(code.replace(/private\.now\(\)/g, "")).not.toMatch(/\bnow\(\)/);
    // the withdrawn rows are never updated (history)
    expect(code).not.toMatch(/update\s+public\.matching_requests/i);
  });

  it("R2/R4: two P2 exception types with the brief's label and next step, closing only with their cause", () => {
    expect(code).toContain(
      "('case_reopened_no_team', 'P2', null, null, null, 'Wiedereröffneter Fall ohne Team',\n" +
        "   'Fehlende Angaben ergänzen; die Teamsuche öffnet sich dann selbst. Nie automatisch zuweisen.')",
    );
    expect(code).toContain("('case_reopened_team_inactive', 'P2'");
    expect(code).toMatch(/on conflict \(exception_type\) do nothing/);
    for (const fn of ["private.derived_exceptions(uuid)", "private.exception_closes_with_cause(uuid, text)", "public.operations_exceptions()"]) {
      expect(code).toContain(`select private.safe_d11_patch('${fn}'`);
    }
    expect(code).toMatch(/drop function private\.safe_d11_patch\(text, text\[\], text\);\s*$/);
  });
});
