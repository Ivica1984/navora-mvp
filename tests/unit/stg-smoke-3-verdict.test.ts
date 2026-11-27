import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { countFailed, deployChanged, verdict } from "../../scripts/staging-smoke-verdict.mjs";

// STG-SMOKE-3 (b) (brief docs/agents/briefs/STG-SMOKE-3.md): one rerun of the failed click paths only when Render
// demonstrably switched commits during a red run. Basis: 3 of 3 red staging-smoke runs since 26.11. were a deploy
// switch during the run (eng 7208819340). The rerun path itself is proven only by this matrix (brief: name it so).

const before = "1aeb5459f0c3d2e1b4a5968778695a4b3c2d1e0f";
const after = "de0d10f5a1b2c3d4e5f60718293a4b5c6d7e8f90";

describe("verdict: full decision matrix", () => {
  it("green: first run green, no rerun", () => {
    const v = verdict({ paths: "success", rerun: "", before, after: before, failed: 0 });
    expect(v).toMatchObject({ green: true, rerun: false });
    // a green first run during a deploy switch is still a plain green (nothing to repeat)
    expect(verdict({ paths: "success", rerun: "skipped", before, after, failed: 0 }).green).toBe(true);
  });
  it("red without a change stays red, and no rerun is attempted", () => {
    const v = verdict({ paths: "failure", rerun: "skipped", before, after: before, failed: 2 });
    expect(v).toMatchObject({ green: false, rerun: false });
    expect(v.message).toMatch(/no proven deploy change/);
  });
  it("red with a change and a green rerun → green with the rerun line", () => {
    const v = verdict({ paths: "failure", rerun: "success", before, after, failed: 3 });
    expect(v).toMatchObject({ green: true, rerun: true });
    expect(v.message).toBe(`green after one rerun of 3 failed paths; deploy \`${before}\` → \`${after}\`; rerun against \`${after}\``);
  });
  it("red with a change and a red rerun → red", () => {
    const v = verdict({ paths: "failure", rerun: "failure", before, after, failed: 1 });
    expect(v).toMatchObject({ green: false, rerun: true });
  });
  it("an empty before or after value → red, even with a green rerun", () => {
    for (const [b, a] of [["", after], [before, ""], ["", ""]]) {
      expect(verdict({ paths: "failure", rerun: "success", before: b, after: a, failed: 1 }).green).toBe(false);
      expect(verdict({ paths: "failure", rerun: "skipped", before: b, after: a, failed: 1 }).green).toBe(false);
    }
  });
  it("a rerun attempted without a change → red (green or red rerun)", () => {
    for (const rerun of ["success", "failure"]) {
      const v = verdict({ paths: "failure", rerun, before, after: before, failed: 1 });
      expect(v.green).toBe(false);
      expect(v.message).toMatch(/without a proven deploy change/);
    }
  });
});

describe("verdict: fail closed on everything else", () => {
  it("a rerun after a green first run is red", () => {
    expect(verdict({ paths: "success", rerun: "success", before, after, failed: 0 }).green).toBe(false);
  });
  it("paths that did not run (skipped, empty, unknown) are red", () => {
    for (const paths of ["skipped", "", "neutral"]) expect(verdict({ paths, rerun: "", before, after: before }).green).toBe(false);
  });
  it("a change but no rerun (skipped or cancelled rerun) is red", () => {
    expect(verdict({ paths: "failure", rerun: "skipped", before, after, failed: 2 }).green).toBe(false);
    expect(verdict({ paths: "failure", rerun: "cancelled", before, after, failed: 2 }).green).toBe(false);
    expect(verdict({ paths: "cancelled", rerun: "", before, after, failed: 2 }).green).toBe(false);
  });
  it("a green rerun with an unknown or empty failed set is red (the rerun was not of the failed paths)", () => {
    for (const failed of [null, 0, "", "x", -1, 1.5]) expect(verdict({ paths: "failure", rerun: "success", before, after, failed }).green).toBe(false);
  });
  it("a malformed commit value is no proven change", () => {
    expect(deployChanged("unknown", after)).toBe(false);
    expect(deployChanged(before, "<html>")).toBe(false);
    expect(deployChanged(before, before)).toBe(false);
    expect(deployChanged(before, after)).toBe(true);
    expect(verdict({ paths: "failure", rerun: "success", before: "unknown", after, failed: 1 }).green).toBe(false);
  });
});

describe("countFailed (Playwright .last-run.json)", () => {
  it("counts failed and not-run tests, the set --last-failed reruns", () => {
    expect(countFailed(JSON.stringify({ status: "failed", failedTests: ["a", "b", "c"] }))).toBe(3);
    expect(countFailed({ status: "passed", failedTests: [] })).toBe(0);
  });
  it("gives null for a missing or malformed file", () => {
    expect(countFailed("not json")).toBeNull();
    expect(countFailed(JSON.stringify({ status: "failed" }))).toBeNull();
    expect(countFailed(undefined)).toBeNull();
  });
});

describe("workflow and config catalogue (permission and negative tests)", () => {
  const wf = readFileSync(join(__dirname, "../../.github/workflows/staging-smoke.yml"), "utf8");
  const config = readFileSync(join(__dirname, "../../playwright.staging-smoke.config.ts"), "utf8");
  const smoke = wf.slice(wf.indexOf("  smoke:"), wf.indexOf("  notify:"));
  const notify = wf.slice(wf.indexOf("  notify:"));
  const step = (name: string) => {
    const at = smoke.indexOf(`- name: ${name}`);
    expect(at).toBeGreaterThan(0);
    const next = smoke.indexOf("\n      - ", at + 1);
    return smoke.slice(at, next < 0 ? undefined : next);
  };

  it("keeps retries: 0 in the Playwright config and adds no retries anywhere", () => {
    expect(config).toMatch(/\n\s+retries: 0,/);
    expect(wf).not.toMatch(/--retries/);
  });
  it("the first run has an id, continue-on-error, and its outcome reaches the verdict", () => {
    const paths = step("Click paths on navora-staging");
    expect(paths).toContain("id: paths");
    expect(paths).toContain("continue-on-error: true");
    expect(paths).toContain("run: npx playwright test --config playwright.staging-smoke.config.ts\n");
    expect(step("Staging smoke verdict")).toContain("PATHS_OUTCOME: ${{ steps.paths.outcome }}");
  });
  it("writes SERVED_BEFORE before and SERVED_AFTER after the first run", () => {
    expect(smoke.indexOf('echo "SERVED_BEFORE=')).toBeLessThan(smoke.indexOf("id: paths"));
    const afterStep = step("App commit Render serves after the click paths");
    expect(afterStep).toContain('echo "SERVED_AFTER=${after}" >> "$GITHUB_ENV"');
    expect(afterStep).toContain("if: always()");
    expect(smoke.indexOf("id: paths")).toBeLessThan(smoke.indexOf('echo "SERVED_AFTER='));
  });
  it("has exactly one rerun step, bound to red paths and a proven deploy change", () => {
    expect(wf.match(/--last-failed/g)).toHaveLength(1);
    expect(wf.match(/npx playwright test/g)).toHaveLength(2);
    const rerun = step("Rerun the failed click paths once (Render switched commits during the run)");
    expect(rerun).toContain("--last-failed");
    const cond = rerun.match(/\n\s+if: (.*)\n/)?.[1] ?? "";
    expect(cond).toContain("steps.paths.outcome == 'failure'");
    expect(cond).toContain("env.SERVED_BEFORE != ''");
    expect(cond).toContain("env.SERVED_AFTER != ''");
    expect(cond).toContain("env.SERVED_BEFORE != env.SERVED_AFTER");
    expect(cond).not.toMatch(/always\(\)|failure\(\)|\|\|/);
    // the rerun comes after SERVED_AFTER is written, and before the verdict
    expect(smoke.indexOf('echo "SERVED_AFTER=')).toBeLessThan(smoke.indexOf("--last-failed"));
    expect(smoke.indexOf("--last-failed")).toBeLessThan(smoke.indexOf("- name: Staging smoke verdict"));
  });
  it("the verdict decides the job: runs always, is the last step, and has no continue-on-error", () => {
    const v = step("Staging smoke verdict");
    expect(v).toContain("if: always()");
    expect(v).toContain("run: node scripts/staging-smoke-verdict.mjs");
    expect(v).not.toContain("continue-on-error");
    expect(v).toContain("RERUN_OUTCOME: ${{ steps.rerun.outcome }}");
    expect(smoke.lastIndexOf("      - name: ")).toBe(smoke.indexOf("      - name: Staging smoke verdict"));
    expect(smoke.match(/continue-on-error: true/g)).toHaveLength(2); // the first run and the one rerun only
  });
  it("leaves the guards unchanged: timeout 90, the reviewed-code guard, no write access, notify on every red", () => {
    expect(smoke).toContain("timeout-minutes: 90");
    expect(smoke).toContain("git merge-base --is-ancestor");
    expect(smoke).not.toMatch(/: write/);
    expect(notify).toContain("needs: [scope, smoke]");
    expect(notify).toContain("if: failure()");
    expect(notify).not.toMatch(/secrets\./);
  });
});
