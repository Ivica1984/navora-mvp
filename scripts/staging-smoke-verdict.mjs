#!/usr/bin/env node
// STG-SMOKE-3 (b) (brief docs/agents/briefs/STG-SMOKE-3.md, PO 2026-11-27 06:39): the verdict of the staging click
// paths. Since 26.11. every red `staging-smoke` run was of one class: Render switched to a newer commit while the
// paths ran (mostly a docs-only merge), and a person had to restart and explain it. The workflow now runs the paths
// with `continue-on-error`, records the commit Render serves before (SERVED_BEFORE) and after (SERVED_AFTER), and runs
// exactly one `--last-failed` rerun only when the paths were red AND both values are known AND they differ. This script
// decides the job (fixed decision table, no heuristics):
//   green  ⇐ (i) the first run is green and no rerun ran, or
//              (ii) a deploy change is proven, the first run named ≥ 1 failed path and the one rerun is green
//                   (then a ::warning and a summary line: «green after one rerun of N failed paths; deploy …»);
//   red    ⇐ everything else: red without a change, a red rerun, an empty before/after value, a rerun that ran
//              without a proven change, an unknown outcome (fail closed).
// N is the size of Playwright's own `--last-failed` set from the first run (`.last-run.json`: failed tests plus the
// tests a serial group did not run after a failure), read before the rerun overwrites it.
//   node scripts/staging-smoke-verdict.mjs count   → prints N (or nothing when unreadable)
//   node scripts/staging-smoke-verdict.mjs         → env PATHS_OUTCOME, RERUN_OUTCOME, SERVED_BEFORE, SERVED_AFTER,
//                                                     FAILED_PATHS; exits 1 on red
import { appendFileSync, readFileSync } from "node:fs";

export const LAST_RUN = "test-results/staging-smoke/.last-run.json";
const SHA = /^[0-9a-f]{7,40}$/;

/** Number of tests Playwright would rerun with --last-failed, or null when the file is missing or malformed. */
export function countFailed(json) {
  try {
    const info = typeof json === "string" ? JSON.parse(json) : json;
    return Array.isArray(info?.failedTests) ? info.failedTests.length : null;
  } catch {
    return null;
  }
}

/** A proven deploy change: both commits read from /api/version, well-formed, and different. */
export function deployChanged(before, after) {
  return SHA.test(before ?? "") && SHA.test(after ?? "") && before !== after;
}

const ran = (outcome) => outcome === "success" || outcome === "failure" || outcome === "cancelled";

/**
 * @param {{ paths: string, rerun?: string, before?: string, after?: string, failed?: number | string | null }} input
 *   paths/rerun are GitHub step outcomes (`success`, `failure`, `cancelled`, `skipped`, or empty when not run).
 * @returns {{ green: boolean, rerun: boolean, message: string }}
 */
export function verdict({ paths, rerun = "", before = "", after = "", failed = null }) {
  const b = before || "unknown";
  const a = after || "unknown";
  const rerunRan = ran(rerun);
  const changed = deployChanged(before, after);
  if (paths === "success") {
    if (rerunRan) return { green: false, rerun: true, message: `red: a rerun ran although the click paths were green (deploy ${b} → ${a})` };
    return { green: true, rerun: false, message: `green: click paths green on the first run (deploy ${b} → ${a})` };
  }
  if (paths !== "failure" && paths !== "cancelled") {
    return { green: false, rerun: rerunRan, message: `red: the click paths did not run (outcome «${paths || "none"}»)` };
  }
  if (!changed) {
    if (rerunRan) return { green: false, rerun: true, message: `red: a rerun ran without a proven deploy change (deploy ${b} → ${a})` };
    return { green: false, rerun: false, message: `red: click paths red with no proven deploy change (deploy ${b} → ${a}); no rerun` };
  }
  const n = Number(failed);
  if (!Number.isInteger(n) || n < 1) {
    return { green: false, rerun: rerunRan, message: `red: deploy ${b} → ${a} changed, but the failed paths of the first run are unknown; no valid rerun` };
  }
  if (rerun === "success") {
    return { green: true, rerun: true, message: `green after one rerun of ${n} failed paths; deploy \`${b}\` → \`${a}\`; rerun against \`${a}\`` };
  }
  if (rerunRan) return { green: false, rerun: true, message: `red: the one rerun of ${n} failed paths against \`${a}\` was red too (deploy \`${b}\` → \`${a}\`)` };
  return { green: false, rerun: false, message: `red: deploy ${b} → ${a} changed, but the rerun did not run` };
}

function main(args) {
  if (args[0] === "count") {
    let n = null;
    try {
      n = countFailed(readFileSync(LAST_RUN, "utf8"));
    } catch {
      n = null;
    }
    process.stdout.write(n === null ? "" : String(n));
    return;
  }
  const e = process.env;
  const v = verdict({
    paths: e.PATHS_OUTCOME ?? "",
    rerun: e.RERUN_OUTCOME ?? "",
    before: e.SERVED_BEFORE ?? "",
    after: e.SERVED_AFTER ?? "",
    failed: e.FAILED_PATHS === "" || e.FAILED_PATHS === undefined ? null : e.FAILED_PATHS,
  });
  const level = !v.green ? "error" : v.rerun ? "warning" : "notice";
  console.log(`::${level} title=staging-smoke verdict::${v.message}`);
  if (e.GITHUB_STEP_SUMMARY) {
    try {
      appendFileSync(e.GITHUB_STEP_SUMMARY, `### staging-smoke verdict\n\n${v.message}\n`);
    } catch {
      // the summary is a convenience; the log line above carries the verdict
    }
  }
  process.exitCode = v.green ? 0 : 1;
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
