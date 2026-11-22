#!/usr/bin/env node
// STAB1-F2 (PERF1 scope (4)): a merge into recovery/main that changes only documentation starts no staging click paths.
// The app and the database on navora-staging are unchanged by such a merge, so a smoke would only repeat the previous
// one and add load and orders to staging. Every other push, and every manual start, runs the smoke (fail open to RUN:
// any doubt, an unreadable diff or an empty file list, runs it).
//   node scripts/staging-smoke-scope.mjs <event> <ref> <sha>   → prints run=true|false (for $GITHUB_OUTPUT)
import { execFileSync } from "node:child_process";

/** Documentation only: under docs/, or a Markdown file anywhere. Code, tests, workflows, migrations are never docs. */
export function isDocsOnly(files) {
  if (!Array.isArray(files) || files.length === 0) return false;
  return files.every((f) => typeof f === "string" && f.length > 0 && (f.startsWith("docs/") || f.endsWith(".md")));
}

export function decide(event, ref, files) {
  if (event !== "push" || ref !== "refs/heads/recovery/main") return { run: true, why: "not a merge into recovery/main" };
  if (isDocsOnly(files)) return { run: false, why: `docs-only merge (${files.length} file(s)): no click paths` };
  return { run: true, why: "the merge changes code, tests, workflows or migrations" };
}

function main([event, ref, sha]) {
  let files = [];
  if (event === "push" && ref === "refs/heads/recovery/main") {
    try {
      // A merge commit: what it brings into recovery/main is the diff against its first parent.
      files = execFileSync("git", ["diff", "--name-only", `${sha}^1`, sha], { encoding: "utf8" }).split("\n").filter(Boolean);
    } catch {
      files = []; // unreadable → run
    }
  }
  const d = decide(event, ref, files);
  console.error(`staging-smoke scope: run=${d.run} (${d.why})`);
  process.stdout.write(`run=${d.run}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
