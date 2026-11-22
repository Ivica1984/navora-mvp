import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decide, pickBase } from "../../scripts/staging-smoke-scope.mjs";

// STG-SMOKE-1 (AI1 PO package contract 2026-11-22 item 0): the post-merge smoke scope is measured against the last
// commit whose click paths ran green (fail open), and `staging-version` waits for the `ci` `staging` job.
// Reproduces PERF1: code merge 448e9c4 (its pending smoke replaced by the concurrency group), then docs-only merge
// 4310526 whose diff against ^1 is docs only → the click paths were skipped and the code merge was never smoked.

type Run = { id: number; head_sha: string; head_branch: string; event: string; conclusion: string | null };
type Job = { name: string; conclusion: string | null };

// History (oldest → newest): 5fc77ec (green smoke) → 448e9c4 (code, smoke cancelled) → 4310526 (docs only).
const order = ["5fc77ec", "448e9c4", "4310526"];
const isAncestor = (a: string, d: string) => order.indexOf(a) >= 0 && order.indexOf(a) <= order.indexOf(d);
const run = (id: number, head_sha: string, over: Partial<Run> = {}): Run => ({
  id,
  head_sha,
  head_branch: "recovery/main",
  event: "push",
  conclusion: "success",
  ...over,
});
const clicked = (c: string | null): Job[] => [
  { name: "staging smoke scope (docs-only merges skip)", conclusion: "success" },
  { name: "staging smoke (founder click paths 1 and 2)", conclusion: c },
  { name: "report a red staging smoke", conclusion: "skipped" },
];

describe("pickBase (positive)", () => {
  it("PERF1 case: the base of 4310526 is 5fc77ec, so the code of 448e9c4 is in the diff and the paths run", () => {
    const runs = [run(44994828040, "5fc77ec")];
    const b = pickBase(runs, () => clicked("success"), isAncestor, "4310526");
    expect(b).toMatchObject({ base: "5fc77ec", runId: 44994828040 });
    // the files between 5fc77ec and 4310526 include the PERF1 migrations → run
    expect(decide("push", "refs/heads/recovery/main", ["docs/a.md", "supabase/migrations/20261021000164_x.sql"]).run).toBe(true);
  });
  it("counts a green manual run on a staging-smoke/** branch (same paths, commit on recovery/main)", () => {
    const runs = [run(2, "448e9c4", { head_branch: "staging-smoke/perf1-448e9c4" }), run(1, "5fc77ec")];
    expect(pickBase(runs, () => clicked("success"), isAncestor, "4310526").base).toBe("448e9c4");
  });
  it("then a docs-only merge after a green smoke still skips (STAB1-F2 kept)", () => {
    expect(decide("push", "refs/heads/recovery/main", ["docs/agents/journal/x.md"]).run).toBe(false);
  });
});

describe("pickBase (negative: never a base that was not clicked green)", () => {
  it("skips a run whose click-path job was skipped (a docs-only merge) and takes the older green one", () => {
    const runs = [run(3, "448e9c4"), run(1, "5fc77ec")];
    const jobs = (id: number) => (id === 3 ? clicked("skipped") : clicked("success"));
    expect(pickBase(runs, jobs, isAncestor, "4310526").base).toBe("5fc77ec");
  });
  it("skips a cancelled or red click-path job, a failed run, a pull-request run and a foreign branch", () => {
    const runs = [
      run(9, "448e9c4", { conclusion: "failure" }),
      run(8, "448e9c4", { event: "workflow_dispatch" }),
      run(7, "448e9c4", { head_branch: "feature/x" }),
      run(6, "448e9c4"),
    ];
    expect(pickBase(runs, () => clicked("cancelled"), isAncestor, "4310526").base).toBeNull();
  });
  it("skips a green run on a commit that is not an ancestor, and the commit itself", () => {
    const runs = [run(5, "deadbee"), run(4, "4310526")];
    expect(pickBase(runs, () => clicked("success"), isAncestor, "4310526").base).toBeNull();
  });
  it("fails open: unreadable jobs or no runs give no base, and no base means an empty diff → run", () => {
    expect(pickBase([run(1, "5fc77ec")], () => null, isAncestor, "4310526").base).toBeNull();
    expect(pickBase([], () => clicked("success"), isAncestor, "4310526").base).toBeNull();
    const throwing = () => {
      throw new Error("not fetched");
    };
    expect(pickBase([run(1, "5fc77ec")], () => clicked("success"), throwing, "4310526").base).toBeNull();
    expect(decide("push", "refs/heads/recovery/main", []).run).toBe(true);
  });
});

describe("workflow wiring (permission test)", () => {
  const smoke = readFileSync(join(__dirname, "../../.github/workflows/staging-smoke.yml"), "utf8");
  const scope = smoke.slice(smoke.indexOf("  scope:"), smoke.indexOf("  smoke:"));
  const version = readFileSync(join(__dirname, "../../.github/workflows/staging-version.yml"), "utf8");
  it("scope job: full history, actions read only, no secret, no write", () => {
    expect(scope).toContain("fetch-depth: 0");
    expect(scope).toMatch(/actions: read/);
    expect(scope).not.toMatch(/: write/);
    expect(scope).not.toMatch(/secrets\./);
  });
  it("staging-version waits for the ci staging job before it reads the versions, only after a merge", () => {
    const wait = version.indexOf("node scripts/staging-smoke-after-merge.mjs --ci-only");
    expect(wait).toBeGreaterThan(0);
    expect(wait).toBeLessThan(version.indexOf("Read the app version"));
    expect(version.slice(version.lastIndexOf("- name: After a merge", wait), wait)).toContain("if: github.event_name == 'push'");
    expect(version).not.toMatch(/: write/);
  });
});
