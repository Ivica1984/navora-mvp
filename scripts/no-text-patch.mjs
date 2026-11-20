#!/usr/bin/env node
// STAB-1 (founder 2026-11-20, issue #1587: «SO ETWAS WIRD BEI NAVORA NIE WIEDER AKZEPTIERT»): no migration after the
// cutoff may change a function by text replacement. Red when a migration with a version above CUTOFF reads a live
// definition (pg_get_functiondef) or calls a *_patch helper. Functions change only as whole files
// (supabase/schema/functions, scripts/fn-source.mjs). Historical migrations up to the cutoff are never edited.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

export const CUTOFF = "20261021000153"; // highest migration on recovery/main when the rule was set (2026-11-20)
const DIR = "supabase/migrations";
const FORBIDDEN = [/pg_get_functiondef\s*\(/i, /\b\w*_patch\s*\(/i, /\breplace\s*\(\s*def\b/i];

export function findTextPatches(files) {
  const problems = [];
  for (const { name, content } of files) {
    const v = /^(\d{14})_/.exec(name)?.[1];
    if (!v || v <= CUTOFF) continue;
    for (const re of FORBIDDEN) if (re.test(content)) problems.push(`${name}: text patch (${re.source}); re-create the whole function from supabase/schema/functions instead`);
  }
  return problems;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const files = readdirSync(DIR).filter((f) => f.endsWith(".sql")).map((name) => ({ name, content: readFileSync(join(DIR, name), "utf8") }));
  const problems = findTextPatches(files);
  problems.forEach((p) => console.error(`::error title=no text patch (STAB-1)::${p}`));
  if (problems.length === 0) console.log(`no-text-patch: no migration after ${CUTOFF} patches a function by text`);
  process.exit(problems.length ? 1 : 0);
}
