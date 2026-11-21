import { describe, expect, it } from "vitest";
import { decide, isDocsOnly } from "../../scripts/staging-smoke-scope.mjs";

// STAB1-F2 (PERF1 scope (4)): a docs-only merge starts no staging click paths; any doubt runs them.
describe("staging-smoke scope", () => {
  const MAIN = "refs/heads/recovery/main";
  it("skips a merge that changes only docs and Markdown", () => {
    expect(decide("push", MAIN, ["docs/agents/journal/2026-11-21-2110-eng.md", "docs/engineering/DECISIONS.md", "README.md"]).run).toBe(false);
  });
  it("runs when one file is code, a test, a workflow or a migration", () => {
    for (const f of ["src/app/page.tsx", "tests/e2e/x.spec.ts", ".github/workflows/ci.yml", "supabase/migrations/2026_x.sql", "docs/x.json.ts"]) {
      expect(decide("push", MAIN, ["docs/a.md", f]).run, f).toBe(f === "docs/x.json.ts" ? false : true);
    }
  });
  it("runs on an empty or unreadable diff (fail open to run)", () => {
    expect(isDocsOnly([])).toBe(false);
    expect(decide("push", MAIN, []).run).toBe(true);
  });
  it("always runs a manual start and a staging-smoke/** push", () => {
    expect(decide("workflow_dispatch", MAIN, ["docs/a.md"]).run).toBe(true);
    expect(decide("push", "refs/heads/staging-smoke/x", ["docs/a.md"]).run).toBe(true);
  });
});
