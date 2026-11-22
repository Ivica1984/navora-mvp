#!/usr/bin/env node
// STAB1-F2 (PERF1 scope (4)): a merge into recovery/main that changes only documentation starts no staging click paths.
// The app and the database on navora-staging are unchanged by such a merge, so a smoke would only repeat the previous
// one and add load and orders to staging. Every other push, and every manual start, runs the smoke (fail open to RUN:
// any doubt, an unreadable diff or an empty file list, runs it).
//
// STG-SMOKE-1 (AI1 contract item 0, 2026-11-22): the diff is taken against the newest commit of recovery/main whose
// click paths last ran green (job «staging smoke …» conclusion success, on a recovery/main push or a
// `staging-smoke/**` push), not against `^1`. Reason: the `staging-smoke` concurrency group replaces a pending run by
// a newer one, so the run of a code merge (448e9c4) was cancelled and the next run (docs-only merge 4310526) skipped
// the click paths: the code merge was never smoked automatically. With the base «last green smoke» a skipped or
// cancelled code merge is carried into the next run. No green base found, or anything unreadable → run.
//   node scripts/staging-smoke-scope.mjs <event> <ref> <sha>   → prints run=true|false (for $GITHUB_OUTPUT)
import { execFileSync } from "node:child_process";

/** Documentation only: under docs/, or a Markdown file anywhere. Code, tests, workflows, migrations are never docs. */
export function isDocsOnly(files) {
  if (!Array.isArray(files) || files.length === 0) return false;
  return files.every((f) => typeof f === "string" && f.length > 0 && (f.startsWith("docs/") || f.endsWith(".md")));
}

export function decide(event, ref, files) {
  if (event !== "push" || ref !== "refs/heads/recovery/main") return { run: true, why: "not a merge into recovery/main" };
  if (isDocsOnly(files)) return { run: false, why: `docs-only since the last green smoke (${files.length} file(s)): no click paths` };
  return { run: true, why: "since the last green smoke, code, tests, workflows or migrations changed (or the base is unknown)" };
}

/** The job of a staging-smoke run that clicks the paths (the scope and notify jobs never count). */
const SMOKE_JOB = (name) => typeof name === "string" && name.startsWith("staging smoke (");

/**
 * Pick the base commit: the newest successful staging-smoke run whose click-path job really ran green and whose
 * commit is an ancestor of `sha` (and not `sha` itself). Runs on `staging-smoke/**` count: they click the same paths
 * on a commit of recovery/main. A run whose click-path job was skipped (docs-only), cancelled or red never counts.
 * @param {Array<{id:number,head_sha:string,head_branch:string,event:string,conclusion:string|null}>} runs newest first
 * @param {(runId:number)=>Array<{name:string,conclusion:string|null}>|null} jobsOf jobs of a run, null if unreadable
 * @param {(ancestor:string, descendant:string)=>boolean} isAncestor
 * @param {string} sha the commit this run checks
 * @returns {{base:string|null, runId?:number, why:string}}
 */
export function pickBase(runs, jobsOf, isAncestor, sha) {
  for (const r of runs ?? []) {
    if (!r || r.conclusion !== "success" || r.event !== "push" || !r.head_sha || r.head_sha === sha) continue;
    if (r.head_branch !== "recovery/main" && !String(r.head_branch ?? "").startsWith("staging-smoke/")) continue;
    let ancestor = false;
    try {
      ancestor = isAncestor(r.head_sha, sha);
    } catch {
      ancestor = false;
    }
    if (!ancestor) continue;
    const jobs = jobsOf(r.id);
    if (!jobs) return { base: null, why: `jobs of run ${r.id} unreadable` }; // doubt → no base → run
    if (jobs.some((j) => SMOKE_JOB(j.name) && j.conclusion === "success")) {
      return { base: r.head_sha, runId: r.id, why: `last green smoke: run ${r.id} on ${r.head_sha}` };
    }
  }
  return { base: null, why: "no green smoke on an ancestor found" };
}

function main([event, ref, sha]) {
  let files = [];
  let baseWhy = "";
  if (event === "push" && ref === "refs/heads/recovery/main") {
    try {
      const repo = process.env.GITHUB_REPOSITORY;
      if (!repo) throw new Error("GITHUB_REPOSITORY missing");
      const gh = (path) => JSON.parse(execFileSync("gh", ["api", path], { encoding: "utf8" }));
      const runs = [];
      for (let page = 1; page <= 3; page++) {
        const got = gh(`repos/${repo}/actions/workflows/staging-smoke.yml/runs?status=success&per_page=50&page=${page}`).workflow_runs ?? [];
        runs.push(...got);
        if (got.length < 50) break;
      }
      runs.sort((a, b) => b.id - a.id);
      const isAncestor = (a, d) => {
        try {
          execFileSync("git", ["merge-base", "--is-ancestor", a, d], { stdio: "ignore" });
          return true;
        } catch {
          return false;
        }
      };
      const jobsOf = (id) => {
        try {
          return gh(`repos/${repo}/actions/runs/${id}/jobs?per_page=50`).jobs ?? null;
        } catch {
          return null;
        }
      };
      const b = pickBase(runs, jobsOf, isAncestor, sha);
      baseWhy = b.why;
      if (b.base) {
        files = execFileSync("git", ["diff", "--name-only", b.base, sha], { encoding: "utf8" }).split("\n").filter(Boolean);
      }
    } catch (e) {
      baseWhy = `base unreadable (${e instanceof Error ? e.message.split("\n")[0] : "error"})`;
      files = []; // unreadable → run
    }
  }
  const d = decide(event, ref, files);
  console.error(`staging-smoke scope: run=${d.run} (${d.why})${baseWhy ? `; ${baseWhy}` : ""}`);
  process.stdout.write(`run=${d.run}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
