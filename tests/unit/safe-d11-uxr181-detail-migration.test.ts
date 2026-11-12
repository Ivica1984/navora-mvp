import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * SAFE-D11 follow-up, UXR-181 (brief docs/agents/briefs/SAFE-D11.md §PO 20:39 (2) and §PO 21:39; ADR-185): the detail of
 * `case_not_ready` and `case_reopened_no_team` is the stored reason of each missing readiness item, joined by «; »,
 * never the item code. This guard reads files only; pgTAP 019 and 130 and e2e `safe-d11.spec.ts` prove the behaviour.
 */
const PATH = "supabase/migrations/20261021000126_safe_d11_uxr181_exception_detail_reason.sql";
const noComments = (sql: string) => sql.replace(/--[^\n]*/g, "");

describe("SAFE-D11 follow-up migration 0126 (UXR-181)", () => {
  const sql = existsSync(PATH) ? readFileSync(PATH, "utf8") : "";
  const code = noComments(sql);

  it("exists", () => {
    expect(existsSync(PATH)).toBe(true);
  });

  it("patches only private.derived_exceptions: both item-code details become the stored reason, joined by «; »", () => {
    expect(code).toContain("'private.derived_exceptions(uuid)'");
    // the find: the item code, exactly twice (case_not_ready, case_reopened_no_team)
    expect(code).toContain("string_agg(m ->> ''item'', '', '')");
    expect(code).toMatch(/'2'\]/);
    // the replacement: the stored reason, in readiness order
    expect(code).toContain("string_agg(m.value ->> ''reason'', ''; '' order by m.ord)");
    expect(code).toContain("jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord)");
  });

  it("changes no grant, policy, column, wording or visibility", () => {
    expect(code).not.toMatch(/create\s+policy|alter\s+table|grant\s+(select|insert|update|delete|execute)/i);
    expect(code).not.toMatch(/exception_rules/i);
    expect(code).not.toMatch(/operations_exceptions|team_visit_alerts|exception_closes_with_cause/i);
    expect(code).not.toMatch(/insert\s+into|update\s+public\./i);
    // the reason texts stay where they are (private.case_readiness, 0013), word for word
    expect(code).not.toMatch(/case_readiness\(p_case_id/i);
  });

  it("keeps derived_exceptions closed to the API roles", () => {
    expect(code).toMatch(/revoke all on function private\.derived_exceptions\(uuid\) from public, anon, authenticated;/);
  });
});
