#!/usr/bin/env node
// CI2 (ADR-167): decides whether the heavy CI jobs (db, e2e, ui-screenshots) run in full or take the verified fast path.
// Deterministic path rule, no AI (brief CI2). Fail-closed: anything other than a pull request whose merge commit
// changes only files under docs/ runs in full; an error exits non-zero so the job fails instead of passing unchecked.
//
// CLI: CI_EVENT=<github.event_name> node scripts/ci-scope.mjs   (writes full=true|false to $GITHUB_OUTPUT)
// On pull_request, actions/checkout checks out the merge commit refs/pull/<n>/merge: HEAD^1 is the base, so
// `git diff HEAD^1 HEAD` is exactly what the PR changes on top of the base (needs fetch-depth >= 2).
import { execFileSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

/** The only paths a fast-path pull request may touch (ADR-167). */
export const DOCS_ONLY_PREFIXES = Object.freeze(["docs/"]);

function isDocsOnlyPath(p) {
  if (typeof p !== "string" || p !== p.trim()) return false;
  if (p.split("/").some((seg) => seg === ".." || seg === "." || seg === "")) return false;
  return DOCS_ONLY_PREFIXES.some((prefix) => p.startsWith(prefix) && p.length > prefix.length);
}

/**
 * @param {{ event: string, files?: string[] }} input
 * @returns {{ full: boolean, reason: string }}
 */
export function classify({ event, files }) {
  if (event !== "pull_request") return { full: true, reason: `event ${event}: always full` };
  if (!Array.isArray(files) || files.length === 0) return { full: true, reason: "no changed files found: full (fail-closed)" };
  const outside = files.filter((f) => !isDocsOnlyPath(f));
  if (outside.length > 0) {
    const shown = outside.slice(0, 5).join(", ") + (outside.length > 5 ? `, … (${outside.length} in all)` : "");
    return { full: true, reason: `changes outside ${DOCS_ONLY_PREFIXES.join(" ")}: ${shown}` };
  }
  return { full: false, reason: `${files.length} files, all under ${DOCS_ONLY_PREFIXES.join(" ")}: verified docs-only` };
}

function git(...args) {
  return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function main() {
  const event = process.env.CI_EVENT ?? "";
  let files;
  if (event === "pull_request") {
    // The fast path is only allowed on the merge commit actions/checkout makes; anything else is an error.
    const parents = git("rev-list", "--parents", "-n", "1", "HEAD").trim().split(/\s+/).slice(1);
    if (parents.length !== 2) {
      console.log(`::error title=ci-scope::HEAD is not a pull-request merge commit (${parents.length} parents); refusing to decide`);
      process.exit(1);
    }
    files = git("diff", "--no-renames", "--name-only", "HEAD^1", "HEAD").split("\n").filter(Boolean);
  }
  const { full, reason } = classify({ event, files });
  const out = process.env.GITHUB_OUTPUT;
  if (!out) {
    // Without the output every gated step would be skipped and the job would pass unchecked.
    console.log("::error title=ci-scope::GITHUB_OUTPUT is not set; refusing to decide");
    process.exit(1);
  }
  appendFileSync(out, `full=${full}\n`);
  console.log(`::notice title=ci-scope::full=${full}: ${reason}`);
  if (!full) console.log("::notice title=ci-scope::docs-only pull request: this job verified the diff and skips its heavy steps (ADR-167)");
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) main();
