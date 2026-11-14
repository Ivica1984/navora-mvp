import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  REQUIRED_JOBS,
  classifyRun,
  evaluateMergeCommits,
  jobKey,
} from "../../scripts/b0-1-merge-runs.mjs";

// B0-1 (ADR-178, PRODUCT_BLOCKS.md §4): every merge commit on recovery/main gets a complete `ci` run, and a
// deliberately red test is reported red on the merge commit. The checker reads runs and jobs from the GitHub API and
// classifies each run deterministically: green, red (the tests ran and reported a failure), incomplete (cancelled,
// a job or a core test step missing or skipped) or pending. A merge commit without a complete run is a B0-1 failure.

type Step = { name: string; conclusion: string | null };
type Job = { id: number; name: string; status: string; conclusion: string | null; steps: Step[] };

const ok = (name: string): Step => ({ name, conclusion: "success" });
const STEPS: Record<string, string[]> = {
  app: ["Lint", "Typecheck", "Unit tests", "Build"],
  db: ["Apply migrations from scratch", "Seed", "Database tests"],
  e2e: ["Playwright"],
  "ui-screenshots": [],
};
const JOB_NAMES: Record<string, string> = {
  app: "app (lint · typecheck · unit · audit · build)",
  db: "db (migrations · seed · pgTAP)",
  e2e: "e2e (auth · protected routes · Playwright)",
  "ui-screenshots": "ui-screenshots (390 · 1440 · every role)",
};
const greenJob = (key: string, id = 1): Job => ({
  id,
  name: JOB_NAMES[key],
  status: "completed",
  conclusion: "success",
  steps: [ok("Set up job"), ...STEPS[key].map(ok), ok("Complete job")],
});
const greenJobs = (): Job[] => REQUIRED_JOBS.map((k: string, i: number) => greenJob(k, i + 1));
const run = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 100,
  name: "ci",
  event: "push",
  head_sha: "a".repeat(40),
  status: "completed",
  conclusion: "success",
  ...over,
});

describe("B0-1 classifyRun (pure)", () => {
  it("B0-1-1: four green jobs with every core step green is green", () => {
    const r = classifyRun({ run: run(), jobs: greenJobs() });
    expect(r.verdict).toBe("green");
    expect(r.reasons).toEqual([]);
  });

  it("B0-1-2: the job keys are the four CI jobs", () => {
    expect([...REQUIRED_JOBS].sort()).toEqual(["app", "db", "e2e", "ui-screenshots"]);
    expect(jobKey(JOB_NAMES.db)).toBe("db");
    expect(jobKey("something else")).toBeNull();
  });

  it("B0-1-3: a cancelled run is incomplete, never green or red", () => {
    const r = classifyRun({ run: run({ conclusion: "cancelled" }), jobs: greenJobs() });
    expect(r.verdict).toBe("incomplete");
    expect(r.reasons.join("\n")).toMatch(/run cancelled/);
  });

  it("B0-1-4: a run still in progress is pending", () => {
    expect(classifyRun({ run: run({ status: "in_progress", conclusion: null }), jobs: [] }).verdict).toBe("pending");
  });

  it("B0-1-5: a failing unit step is red and names the job and the step", () => {
    const jobs = greenJobs();
    jobs[0] = { ...jobs[0], conclusion: "failure", steps: [ok("Lint"), ok("Typecheck"), { name: "Unit tests", conclusion: "failure" }, ok("Build")] };
    const r = classifyRun({ run: run({ conclusion: "failure" }), jobs });
    expect(r.verdict).toBe("red");
    expect(r.failed).toEqual(["app: Unit tests"]);
  });

  it("B0-1-6: a red db job whose later steps were skipped after the failure is still red", () => {
    const jobs = greenJobs();
    jobs[1] = {
      ...jobs[1],
      conclusion: "failure",
      steps: [{ name: "Apply migrations from scratch", conclusion: "failure" }, { name: "Seed", conclusion: "skipped" }, { name: "Database tests", conclusion: "skipped" }],
    };
    const r = classifyRun({ run: run({ conclusion: "failure" }), jobs });
    expect(r.verdict).toBe("red");
    expect(r.failed).toEqual(["db: Apply migrations from scratch"]);
  });

  it("B0-1-7: a green job whose core test step was skipped is incomplete (e.g. a docs-only skip on a push)", () => {
    const jobs = greenJobs();
    jobs[1] = { ...jobs[1], steps: [ok("Apply migrations from scratch"), ok("Seed"), { name: "Database tests", conclusion: "skipped" }] };
    const r = classifyRun({ run: run(), jobs });
    expect(r.verdict).toBe("incomplete");
    expect(r.reasons.join("\n")).toMatch(/db: core step "Database tests" skipped/);
  });

  it("B0-1-8: a missing job or a missing core step is incomplete", () => {
    const noE2e = greenJobs().filter((j) => jobKey(j.name) !== "e2e");
    expect(classifyRun({ run: run(), jobs: noE2e }).reasons.join("\n")).toMatch(/job e2e missing/);
    const jobs = greenJobs();
    jobs[0] = { ...jobs[0], steps: [ok("Lint"), ok("Typecheck"), ok("Build")] };
    const r = classifyRun({ run: run(), jobs });
    expect(r.verdict).toBe("incomplete");
    expect(r.reasons.join("\n")).toMatch(/app: core step "Unit tests" missing/);
  });

  it("B0-1-9: a cancelled job inside a failed run is incomplete, not red", () => {
    const jobs = greenJobs();
    jobs[0] = { ...jobs[0], conclusion: "failure", steps: [{ name: "Lint", conclusion: "failure" }] };
    jobs[2] = { ...jobs[2], conclusion: "cancelled" };
    const r = classifyRun({ run: run({ conclusion: "failure" }), jobs });
    expect(r.verdict).toBe("incomplete");
    expect(r.reasons.join("\n")).toMatch(/e2e: job cancelled/);
  });

  it("B0-1-10: ui-screenshots may skip its capture when no screen changed (no core step)", () => {
    const jobs = greenJobs();
    jobs[3] = { ...jobs[3], steps: [ok("Does this change touch the UI?"), { name: "Capture", conclusion: "skipped" }] };
    expect(classifyRun({ run: run(), jobs }).verdict).toBe("green");
  });

  it("B0-1-11: a timed-out run is incomplete", () => {
    expect(classifyRun({ run: run({ conclusion: "timed_out" }), jobs: greenJobs() }).verdict).toBe("incomplete");
  });

  // Same count rule as B0-2 (PO 2026-11-10 12:39, ADR-174): a failure labelled `infrastructure:` stopped before the
  // first test, so the job did not test the commit: incomplete, neither green nor a test failure.
  const infraRed = (titles: string[]) => {
    const jobs = greenJobs();
    jobs[2] = { ...jobs[2], id: 77, conclusion: "failure", steps: [{ name: "Start local Supabase (applies migrations + synthetic seed)", conclusion: "failure" }] };
    const annotationsByJobId = { 77: titles.map((title) => ({ annotation_level: "failure", title })) };
    return classifyRun({ run: run({ conclusion: "failure" }), jobs, annotationsByJobId });
  };

  it("B0-1-19: a red job whose every error annotation is `infrastructure:` is incomplete, not red", () => {
    const r = infraRed(["infrastructure: runner port in use (54322)"]);
    expect(r.verdict).toBe("incomplete");
    expect(r.reasons.join("\n")).toMatch(/e2e: infrastructure: runner port in use/);
  });

  it("B0-1-20: a red job with any other error annotation stays red", () => {
    const r = infraRed(["infrastructure: registry limit", "supabase-start failed (exit 1)"]);
    expect(r.verdict).toBe("red");
    expect(r.failed).toEqual(["e2e: Start local Supabase (applies migrations + synthetic seed)"]);
  });
});

describe("B0-1 evaluateMergeCommits (pure)", () => {
  const sha = (c: string) => c.repeat(40);

  it("B0-1-12: every merge commit with a complete run passes; red counts as tested", () => {
    const runs = [run({ id: 1, head_sha: sha("a") }), run({ id: 2, head_sha: sha("b"), conclusion: "failure" })];
    const redJobs = greenJobs();
    redJobs[0] = { ...redJobs[0], conclusion: "failure", steps: [{ name: "Unit tests", conclusion: "failure" }] };
    const r = evaluateMergeCommits({ commits: [sha("a"), sha("b")], runs, jobsByRunId: { 1: greenJobs(), 2: redJobs } });
    expect(r.ok).toBe(true);
    expect(r.commits.map((c: { verdict: string }) => c.verdict)).toEqual(["green", "red"]);
  });

  it("B0-1-13: a merge commit without a ci push run is missing and fails", () => {
    const r = evaluateMergeCommits({ commits: [sha("c")], runs: [], jobsByRunId: {} });
    expect(r.ok).toBe(false);
    expect(r.commits[0].verdict).toBe("missing");
  });

  it("B0-1-14: only `ci` push runs count (a pull_request or another workflow run does not cover the merge commit)", () => {
    const runs = [run({ id: 3, head_sha: sha("d"), event: "pull_request" }), run({ id: 4, head_sha: sha("d"), name: "agents-coordination" })];
    const r = evaluateMergeCommits({ commits: [sha("d")], runs, jobsByRunId: { 3: greenJobs(), 4: greenJobs() } });
    expect(r.commits[0].verdict).toBe("missing");
  });

  it("B0-1-15: a cancelled run next to a complete run on the same commit is covered (the complete one decides)", () => {
    const runs = [run({ id: 5, head_sha: sha("e"), conclusion: "cancelled" }), run({ id: 6, head_sha: sha("e") })];
    const r = evaluateMergeCommits({ commits: [sha("e")], runs, jobsByRunId: { 5: greenJobs(), 6: greenJobs() } });
    expect(r.ok).toBe(true);
    expect(r.commits[0].verdict).toBe("green");
    expect(r.commits[0].runs.map((x: { verdict: string }) => x.verdict)).toEqual(["incomplete", "green"]);
  });

  it("B0-1-16: only a cancelled run fails the commit; a pending run is reported as pending", () => {
    const runs = [run({ id: 7, head_sha: sha("f"), conclusion: "cancelled" }), run({ id: 8, head_sha: sha("1"), status: "queued", conclusion: null })];
    const r = evaluateMergeCommits({ commits: [sha("f"), sha("1")], runs, jobsByRunId: { 7: greenJobs(), 8: [] } });
    expect(r.ok).toBe(false);
    expect(r.commits.map((c: { verdict: string }) => c.verdict)).toEqual(["incomplete", "pending"]);
    expect(r.pending).toBe(true);
  });
});

describe("B0-1 wiring", () => {
  const WORKFLOW = readFileSync(join(process.cwd(), ".github/workflows/ci.yml"), "utf8");

  it("B0-1-17: push runs on recovery/main get a group per commit and are never cancelled (configuration part, #980)", () => {
    expect(WORKFLOW).toMatch(/push:\s*\n\s*branches: \[main, recovery\/main\]/);
    expect(WORKFLOW).toContain("group: ci-${{ github.event_name == 'pull_request' && github.ref || github.sha }}");
    expect(WORKFLOW).toContain("cancel-in-progress: ${{ github.event_name == 'pull_request' }}");
  });

  it("B0-1-18: the core steps the checker requires exist in ci.yml under these names", () => {
    for (const step of ["Lint", "Typecheck", "Unit tests", "Build", "Apply migrations from scratch", "Seed", "Database tests", "Playwright"]) {
      expect(WORKFLOW).toMatch(new RegExp(`- name: ${step.replace(/[()]/g, "\\$&")}\\s*\\n`));
    }
  });
});
