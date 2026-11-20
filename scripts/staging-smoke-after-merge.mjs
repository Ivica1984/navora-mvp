#!/usr/bin/env node
// STAB1 scope (e) (brief docs/agents/briefs/STAB1.md, founder FE-099 (2), ADR-222 point 7): after every push to
// recovery/main, `staging-smoke` must click the proven paths on navora-staging — but only once that commit is really
// there. Two preconditions, both read only from the GitHub API and the public /api/version endpoint:
//   1. the `ci` push run on the merge commit has finished and its `staging` job (migrations → navora-staging) is green;
//   2. Render serves that commit or a later commit of recovery/main.
// The decisions are pure functions (unit test tests/unit/stab1-staging-smoke-after-merge.test.ts); `main()` polls.
// No secret is read here: the GitHub token is the job's own read token, /api/version is public.

/**
 * Decide from the `ci` runs on one commit whether the smoke may start.
 * @param {Array<{id:number,name:string,head_branch:string,event:string,status:string,conclusion:string|null}>} runs
 * @param {(runId:number)=>Array<{name:string,status:string,conclusion:string|null}>|null} jobsOf jobs of a run (or null if not read yet)
 * @returns {{state:'wait'|'go'|'fail', reason:string, runId?:number}}
 */
export function decideCi(runs, jobsOf) {
  const ci = (runs ?? [])
    .filter((r) => r.name === "ci" && r.event === "push" && r.head_branch === "recovery/main")
    .sort((a, b) => b.id - a.id)[0];
  if (!ci) return { state: "wait", reason: "no ci push run for this commit yet" };
  if (ci.status !== "completed") return { state: "wait", reason: `ci run ${ci.id} is ${ci.status}`, runId: ci.id };
  const jobs = jobsOf(ci.id);
  if (!jobs) return { state: "wait", reason: `jobs of ci run ${ci.id} not read yet`, runId: ci.id };
  const staging = jobs.find((j) => j.name.startsWith("staging"));
  if (!staging) return { state: "fail", reason: `ci run ${ci.id} has no staging job`, runId: ci.id };
  if (staging.conclusion !== "success") {
    return {
      state: "fail",
      reason: `ci run ${ci.id}: staging job ${staging.conclusion ?? staging.status}; migrations may not be on navora-staging`,
      runId: ci.id,
    };
  }
  return { state: "go", reason: `ci run ${ci.id}: staging job success`, runId: ci.id };
}

/**
 * Decide whether the commit Render serves is the merge commit or a later one.
 * @param {string} want merge commit
 * @param {string} served commit from /api/version (may be empty)
 * @param {(ancestor:string, descendant:string)=>boolean} isAncestor git merge-base --is-ancestor
 * @returns {{state:'wait'|'go', reason:string}}
 */
export function decideServed(want, served, isAncestor) {
  if (!served) return { state: "wait", reason: "/api/version gave no commit (deploy running or instance asleep)" };
  if (served === want) return { state: "go", reason: `Render serves ${served}` };
  let later = false;
  try {
    later = isAncestor(want, served);
  } catch {
    later = false; // served commit not fetched yet, or not on recovery/main: not good enough
  }
  if (later) return { state: "go", reason: `Render serves ${served}, a later commit that contains ${want}` };
  return { state: "wait", reason: `Render still serves ${served}, not ${want}` };
}

async function main() {
  const { execFileSync } = await import("node:child_process");
  const repo = process.env.GITHUB_REPOSITORY;
  const want = process.env.GITHUB_SHA;
  const appUrl = process.env.APP_URL ?? "https://navora-staging.onrender.com";
  const ciMinutes = Number(process.env.WAIT_CI_MINUTES ?? 50);
  const renderMinutes = Number(process.env.WAIT_RENDER_MINUTES ?? 20);
  if (!repo || !want) throw new Error("GITHUB_REPOSITORY and GITHUB_SHA are required");
  const gh = (path) => JSON.parse(execFileSync("gh", ["api", path], { encoding: "utf8" }));
  const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));

  let ci = { state: "wait", reason: "not read" };
  for (let t = 0; t < ciMinutes * 60; t += 60) {
    const runs = gh(`repos/${repo}/actions/runs?head_sha=${want}&event=push&per_page=50`).workflow_runs;
    ci = decideCi(runs, (id) => gh(`repos/${repo}/actions/runs/${id}/jobs?per_page=50`).jobs);
    console.log(`ci: ${ci.state} (${ci.reason})`);
    if (ci.state !== "wait") break;
    await sleep(60);
  }
  if (ci.state !== "go") {
    console.log(`::error title=staging-smoke precondition::${ci.state === "wait" ? `after ${ciMinutes} min: ` : ""}${ci.reason}; the smoke was not started`);
    process.exit(1);
  }

  const isAncestor = (a, d) => {
    execFileSync("git", ["fetch", "--no-tags", "-q", "origin", "recovery/main"]);
    try {
      execFileSync("git", ["merge-base", "--is-ancestor", a, d]);
      return true;
    } catch {
      return false;
    }
  };
  let served = { state: "wait", reason: "not read" };
  for (let t = 0; t < renderMinutes * 60; t += 30) {
    let commit = "";
    try {
      const res = await fetch(`${appUrl}/api/version`, { signal: AbortSignal.timeout(20_000) });
      if (res.ok) commit = String((await res.json()).commit ?? "");
    } catch {
      commit = "";
    }
    served = decideServed(want, commit, isAncestor);
    console.log(`render: ${served.state} (${served.reason})`);
    if (served.state === "go") break;
    await sleep(30);
  }
  if (served.state !== "go") {
    console.log(`::error title=staging-smoke precondition::after ${renderMinutes} min: ${served.reason}; the smoke was not started`);
    process.exit(1);
  }
  console.log(`::notice title=staging-smoke::${ci.reason}; ${served.reason}; starting the click paths`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => {
    console.log(`::error title=staging-smoke precondition::${e.message}`);
    process.exit(1);
  });
}
