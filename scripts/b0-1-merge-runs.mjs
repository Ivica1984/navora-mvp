#!/usr/bin/env node
// B0-1 (ADR-178): every merge commit on recovery/main is tested completely, and a red test is reported red.
//
// Reads `ci` runs and their jobs from the GitHub API and classifies each run deterministically (no AI):
//   green       every required job succeeded and every core test step in it ran and succeeded
//   red         the tests ran and a job failed (the failing job and step are named); a red run is a complete run
//               (a failed job whose every error annotation is titled `infrastructure:` stopped before the first test,
//               ADR-174; it counts as not run, the same rule as B0-2, and makes the run incomplete)
//   incomplete  the run or a required job was cancelled, skipped or timed out, or a job or a core test step is
//               missing or was skipped in a job that reports success (e.g. a docs-only skip on a push)
//   pending     the run has not finished
// A merge commit is covered when at least one `ci` push run on it is green or red. A merge commit with no `ci` push
// run (missing) or only incomplete runs is a B0-1 failure. Fail-closed: an API error is an error, never a pass.
//
// CLI (read-only; GITHUB_TOKEN is used when set, the repository is public):
//   node scripts/b0-1-merge-runs.mjs --since <rev> [--until <rev>]   first-parent commits of <until> (default
//                                                                     origin/recovery/main) after <rev>; exit 0 when
//                                                                     every one is covered, 1 when one is missing or
//                                                                     incomplete, 2 when only pending ones remain
//   node scripts/b0-1-merge-runs.mjs --pr <n>                          the newest `ci` pull_request run of PR <n>
//                                                                     (run on the merge commit refs/pull/<n>/merge);
//                                                                     prints the verdict; exit 0 when red (negative
//                                                                     case shown), 1 otherwise
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

/** The four jobs of .github/workflows/ci.yml, keyed by the first word of their display name. */
export const REQUIRED_JOBS = ["app", "db", "e2e", "ui-screenshots"];

/** Steps that are the tests themselves; a green job without them did not test the commit. ui-screenshots may skip
 *  its capture by design when no screen changed, so it has none. */
export const CORE_STEPS = {
  app: ["Lint", "Typecheck", "Unit tests", "Build"],
  db: ["Apply migrations from scratch", "Seed", "Database tests"],
  e2e: ["Playwright"],
  "ui-screenshots": [],
};

const NOT_RUN = new Set(["cancelled", "skipped", "timed_out", "stale", "startup_failure", "neutral", "action_required"]);

/** @param {string} name */
export function jobKey(name) {
  const first = String(name).split(" ")[0];
  return REQUIRED_JOBS.includes(first) ? first : null;
}

/**
 * @param {{ run: {status: string, conclusion: string | null}, jobs: {id?: number, name: string, status?: string, conclusion: string | null, steps?: {name: string, conclusion: string | null}[]}[], annotationsByJobId?: Record<string, {annotation_level: string, title: string}[]> }} input
 * @returns {{ verdict: "green" | "red" | "incomplete" | "pending", reasons: string[], failed: string[] }}
 */
export function classifyRun({ run, jobs, annotationsByJobId = {} }) {
  if (run.status !== "completed") return { verdict: "pending", reasons: [`run ${run.status}`], failed: [] };
  const reasons = [];
  const failed = [];
  if (NOT_RUN.has(String(run.conclusion))) reasons.push(`run ${run.conclusion}`);

  for (const key of REQUIRED_JOBS) {
    const job = jobs.find((j) => jobKey(j.name) === key);
    if (!job) {
      reasons.push(`job ${key} missing`);
      continue;
    }
    const steps = job.steps ?? [];
    if (job.conclusion === "success") {
      for (const core of CORE_STEPS[key]) {
        const s = steps.find((x) => x.name === core);
        if (!s) reasons.push(`${key}: core step "${core}" missing`);
        else if (s.conclusion !== "success") reasons.push(`${key}: core step "${core}" ${s.conclusion}`);
      }
    } else if (job.conclusion === "failure") {
      const errors = (annotationsByJobId[job.id] ?? []).filter((a) => a.annotation_level === "failure");
      if (errors.length && errors.every((a) => String(a.title).startsWith("infrastructure:"))) {
        reasons.push(...errors.map((a) => `${key}: ${a.title}`));
        continue;
      }
      const bad = steps.filter((x) => x.conclusion === "failure").map((x) => `${key}: ${x.name}`);
      failed.push(...(bad.length ? bad : [`${key}: (no step named)`]));
    } else {
      reasons.push(`${key}: job ${job.conclusion ?? job.status ?? "unknown"}`);
    }
  }

  if (reasons.length) return { verdict: "incomplete", reasons, failed };
  if (failed.length) return { verdict: "red", reasons, failed };
  return { verdict: "green", reasons, failed };
}

/**
 * @param {{ commits: string[], runs: {id: number, name: string, event: string, head_sha: string, status: string, conclusion: string | null}[], jobsByRunId: Record<string, any[]>, annotationsByJobId?: Record<string, any[]> }} input
 */
export function evaluateMergeCommits({ commits, runs, jobsByRunId, annotationsByJobId = {} }) {
  const out = commits.map((sha) => {
    const mine = runs
      .filter((r) => r.head_sha === sha && r.name === "ci" && r.event === "push")
      .sort((a, b) => a.id - b.id)
      .map((r) => ({ id: r.id, ...classifyRun({ run: r, jobs: jobsByRunId[r.id] ?? [], annotationsByJobId }) }));
    let verdict = "missing";
    if (mine.some((r) => r.verdict === "red")) verdict = "red";
    else if (mine.some((r) => r.verdict === "green")) verdict = "green";
    else if (mine.some((r) => r.verdict === "pending")) verdict = "pending";
    else if (mine.length) verdict = "incomplete";
    return { sha, verdict, runs: mine };
  });
  const bad = out.filter((c) => c.verdict === "missing" || c.verdict === "incomplete");
  return { ok: bad.length === 0 && !out.some((c) => c.verdict === "pending"), pending: out.some((c) => c.verdict === "pending"), failed: bad.length > 0, commits: out };
}

// ---------------------------------------------------------------- CLI

const REPO = process.env.GITHUB_REPOSITORY || "Ivica1984/navora-mvp";
const API = `https://api.github.com/repos/${REPO}`;

async function api(path) {
  const headers = { Accept: "application/vnd.github+json", "Content-Type": "application/json" };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const res = await fetch(`${API}${path}`, { headers });
  if (!res.ok) throw new Error(`GET ${path}: HTTP ${res.status}`);
  return res.json();
}

async function jobsOf(runId, annotationsByJobId) {
  const d = await api(`/actions/runs/${runId}/jobs?per_page=100`);
  for (const j of d.jobs.filter((x) => x.conclusion === "failure")) {
    annotationsByJobId[j.id] = await api(`/check-runs/${j.id}/annotations?per_page=100`);
  }
  return d.jobs;
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i > 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const pr = arg("--pr");
  if (pr) {
    const p = await api(`/pulls/${pr}`);
    const d = await api(`/actions/runs?event=pull_request&head_sha=${p.head.sha}&per_page=20`);
    const ciRuns = d.workflow_runs.filter((r) => r.name === "ci").sort((a, b) => b.id - a.id);
    if (!ciRuns.length) throw new Error(`PR #${pr}: no ci pull_request run on head ${p.head.sha}`);
    const r = ciRuns[0];
    const annotationsByJobId = {};
    const jobs = await jobsOf(r.id, annotationsByJobId);
    const c = classifyRun({ run: r, jobs, annotationsByJobId });
    console.log(JSON.stringify({ pr: Number(pr), head: p.head.sha, merge_commit_sha: p.merge_commit_sha, run: r.id, ...c }, null, 2));
    process.exit(c.verdict === "red" ? 0 : 1);
  }

  const since = arg("--since");
  if (!since) throw new Error("usage: --since <rev> [--until <rev>] | --pr <n>");
  const until = arg("--until") || "origin/recovery/main";
  const commits = execFileSync("git", ["rev-list", "--first-parent", "--reverse", `${since}..${until}`], { encoding: "utf8" })
    .split("\n")
    .filter(Boolean);
  const runs = [];
  const jobsByRunId = {};
  const annotationsByJobId = {};
  for (const sha of commits) {
    const d = await api(`/actions/runs?event=push&head_sha=${sha}&per_page=20`);
    for (const r of d.workflow_runs.filter((x) => x.name === "ci")) {
      runs.push(r);
      if (r.status === "completed") jobsByRunId[r.id] = await jobsOf(r.id, annotationsByJobId);
    }
  }
  const res = evaluateMergeCommits({ commits, runs, jobsByRunId, annotationsByJobId });
  for (const c of res.commits) {
    const detail = c.runs.map((r) => `${r.id}:${r.verdict}${r.reasons.length ? ` (${r.reasons.join("; ")})` : ""}${r.failed.length ? ` [${r.failed.join("; ")}]` : ""}`).join(", ");
    console.log(`${c.sha.slice(0, 7)} ${c.verdict.padEnd(10)} ${detail || "no ci push run"}`);
  }
  console.log(`b0-1: ${res.commits.length} merge commits; ${res.ok ? "every one covered" : res.failed ? "NOT every one covered" : "pending runs remain"}`);
  process.exit(res.ok ? 0 : res.failed ? 1 : 2);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  main().catch((e) => {
    console.error(`b0-1: ${e.message}`);
    process.exit(1);
  });
}
