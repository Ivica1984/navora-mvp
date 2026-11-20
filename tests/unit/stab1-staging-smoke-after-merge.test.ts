import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { decideCi, decideServed } from "../../scripts/staging-smoke-after-merge.mjs";

// STAB1 scope (e), ADR-222 point 7: after a merge into recovery/main the staging smoke starts only when the `ci`
// staging job has put the migrations on navora-staging and Render serves the merge commit (or a later one). It never
// starts on a red or missing staging job, and never reports green for a commit that is not on staging.

type Run = { id: number; name: string; head_branch: string; event: string; status: string; conclusion: string | null };
type Job = { name: string; status: string; conclusion: string | null };

const run = (over: Partial<Run> = {}): Run => ({
  id: 100,
  name: "ci",
  head_branch: "recovery/main",
  event: "push",
  status: "completed",
  conclusion: "success",
  ...over,
});
const jobs = (staging: string | null): Job[] => [
  { name: "app (lint · typecheck · unit · audit · build)", status: "completed", conclusion: "success" },
  ...(staging === null ? [] : [{ name: "staging (migrations → navora-staging)", status: "completed", conclusion: staging }]),
];

describe("decideCi (positive)", () => {
  it("goes when the ci push run finished and its staging job is green", () => {
    expect(decideCi([run()], () => jobs("success"))).toMatchObject({ state: "go", runId: 100 });
  });
  it("uses the newest ci push run on recovery/main and ignores other workflows and pull-request runs", () => {
    const runs = [
      run({ id: 90, conclusion: "failure" }),
      run({ id: 101 }),
      run({ id: 102, name: "codeql" }),
      run({ id: 103, event: "pull_request" }),
    ];
    const seen: number[] = [];
    const d = decideCi(runs, (id) => (seen.push(id), jobs("success")));
    expect(d).toMatchObject({ state: "go", runId: 101 });
    expect(seen).toEqual([101]);
  });
});

describe("decideCi (negative: never start on a commit that may not be on staging)", () => {
  it("waits while there is no run or the run is not finished", () => {
    expect(decideCi([], () => null).state).toBe("wait");
    expect(decideCi([run({ status: "in_progress", conclusion: null })], () => jobs("success")).state).toBe("wait");
  });
  it("fails when the staging job is red, skipped, cancelled or missing", () => {
    for (const c of ["failure", "skipped", "cancelled"]) {
      expect(decideCi([run({ conclusion: "failure" })], () => jobs(c)).state).toBe("fail");
    }
    expect(decideCi([run()], () => jobs(null))).toMatchObject({ state: "fail", reason: expect.stringContaining("no staging job") });
  });
});

describe("decideServed", () => {
  const want = "a".repeat(40);
  it("goes when Render serves the merge commit or a later commit that contains it", () => {
    expect(decideServed(want, want, () => false).state).toBe("go");
    expect(decideServed(want, "b".repeat(40), (a, d) => a === want && d === "b".repeat(40)).state).toBe("go");
  });
  it("waits on an older commit, an empty answer or an unknown commit (never go by error)", () => {
    expect(decideServed(want, "", () => true).state).toBe("wait");
    expect(decideServed(want, "c".repeat(40), () => false).state).toBe("wait");
    expect(
      decideServed(want, "d".repeat(40), () => {
        throw new Error("unknown commit");
      }).state,
    ).toBe("wait");
  });
});

describe("staging-smoke workflow wiring (permission test)", () => {
  const wf = readFileSync(join(__dirname, "../../.github/workflows/staging-smoke.yml"), "utf8");
  const smoke = wf.slice(wf.indexOf("  smoke:"), wf.indexOf("  notify:"));
  const notify = wf.slice(wf.indexOf("  notify:"));
  it("runs on every push to recovery/main and still on staging-smoke/** branches", () => {
    expect(wf).toMatch(/branches: \['staging-smoke\/\*\*', recovery\/main\]/);
  });
  it("waits for the preconditions before the click paths, only after a merge", () => {
    const wait = smoke.indexOf("node scripts/staging-smoke-after-merge.mjs");
    expect(wait).toBeGreaterThan(0);
    expect(wait).toBeLessThan(smoke.indexOf("npx playwright test --config playwright.staging-smoke.config.ts"));
    expect(smoke).toContain("if: github.event_name == 'push' && github.ref == 'refs/heads/recovery/main'");
  });
  it("gives the job with the demo passwords no write access, and the writing job no password", () => {
    expect(smoke).not.toMatch(/: write/);
    expect(notify).toMatch(/issues: write/);
    expect(notify).not.toMatch(/secrets\./);
    expect(notify).toContain("if: failure()");
  });
});
