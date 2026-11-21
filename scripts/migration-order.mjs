#!/usr/bin/env node
// B0-8 (ADR-177): migrations run in the same order on an empty and on an existing database.
//
// An empty database (`supabase db reset`) applies every file in supabase/migrations in version order. An existing
// database applies only the versions it has not recorded yet, after the ones it has. Both orders are the same exactly
// when a change only appends: every added migration has a version above the highest version on the base, and no
// migration on the base is removed, renamed or edited. Deterministic rule, no AI; fail-closed (an unresolvable base
// is an error, never a pass).
//
// CLI:
//   MIGRATION_BASE_REF=<rev> node scripts/migration-order.mjs   check HEAD against <rev> (default origin/recovery/main)
//                                                              CI: HEAD^1, the base parent of the pull-request merge
//                                                              commit, or the previous tip on a push
//   node scripts/migration-order.mjs --history [<rev>]          list every first-parent step of <rev> (default HEAD)
//                                                              that broke the rule; informational, exits 0
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

export const MIGRATIONS_DIR = "supabase/migrations";
/** <14-digit version>_<lowercase slug>.sql; the version is what the Supabase CLI records per applied file. */
export const MIGRATION_NAME = /^(\d{14})_([a-z0-9_]+)\.sql$/;

/**
 * @param {{ base: {name: string, content: string}[], head: {name: string, content: string}[] }} input
 * @returns {{ ok: boolean, errors: string[], added: string[], baseMax: string | null }}
 */
export function checkMigrationOrder({ base, head }) {
  const errors = [];
  const baseByName = new Map(base.map((x) => [x.name, x.content]));
  const headByName = new Map(head.map((x) => [x.name, x.content]));

  for (const { name } of head) {
    if (!MIGRATION_NAME.test(name)) errors.push(`${name}: not <14-digit version>_<lowercase name>.sql`);
  }

  const versionsOf = (list) => {
    const seen = new Map();
    for (const { name } of list) {
      const mm = MIGRATION_NAME.exec(name);
      if (!mm) continue;
      seen.set(mm[1], [...(seen.get(mm[1]) ?? []), name]);
    }
    return seen;
  };
  for (const [v, names] of versionsOf(head)) {
    if (names.length > 1) errors.push(`duplicate version ${v}: ${names.sort().join(", ")}`);
  }

  const baseVersions = [...versionsOf(base).keys()].sort();
  const baseMax = baseVersions.length ? baseVersions[baseVersions.length - 1] : null;

  for (const [name, content] of baseByName) {
    if (!headByName.has(name)) {
      errors.push(`${name}: on the base but removed or renamed (an existing database has already applied it)`);
    } else if (headByName.get(name) !== content) {
      errors.push(`${name}: changed after it reached the base (an existing database will not run it again; add a new migration instead)`);
    }
  }

  const added = head
    .map((x) => x.name)
    .filter((n) => !baseByName.has(n))
    .sort();
  for (const name of added) {
    const mm = MIGRATION_NAME.exec(name);
    if (!mm || baseMax === null) continue;
    if (mm[1] <= baseMax) {
      errors.push(
        `${name}: version ${mm[1]} is not above the base's highest version ${baseMax}; an empty database would run it before ${baseMax}, an existing one after it (renumber it above ${baseMax})`,
      );
    }
  }

  return { ok: errors.length === 0, errors, added, baseMax };
}

function git(...args) {
  return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 256 * 1024 * 1024 });
}

/** The migrations of one revision with their blob ids (a changed blob id is a changed file). */
function migrationsAt(rev) {
  const out = git("ls-tree", rev, `${MIGRATIONS_DIR}/`);
  return out
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [meta, path] = line.split("\t");
      return { name: path.slice(MIGRATIONS_DIR.length + 1), content: meta.split(/\s+/)[2] };
    });
}

function resolve(rev) {
  try {
    return git("rev-parse", "--verify", "-q", `${rev}^{commit}`).trim();
  } catch {
    return null;
  }
}

function history(rev) {
  const commits = git("rev-list", "--first-parent", "--reverse", rev).split("\n").filter(Boolean);
  let found = 0;
  for (const c of commits) {
    const parent = resolve(`${c}^1`);
    if (!parent) continue;
    const r = checkMigrationOrder({ base: migrationsAt(parent), head: migrationsAt(c) });
    if (r.ok) continue;
    found += 1;
    const subject = git("log", "-1", "--format=%h %cs %s", c).trim();
    for (const e of r.errors) console.log(`${subject}\n  ${e}`);
  }
  console.log(`migration-order history: ${commits.length} first-parent commits, ${found} with a finding (informational)`);
}

function main() {
  const args = process.argv.slice(2);
  if (args[0] === "--history") {
    history(args[1] ?? "HEAD");
    return;
  }
  const baseRef = process.env.MIGRATION_BASE_REF || "origin/recovery/main";
  const base = resolve(baseRef);
  if (!base) {
    console.log(`::error title=migration-order::base revision ${baseRef} does not resolve; refusing to decide (fetch more history)`);
    process.exit(1);
  }
  const r = checkMigrationOrder({ base: migrationsAt(base), head: migrationsAt("HEAD") });
  if (!r.ok) {
    for (const e of r.errors) console.log(`::error title=migration-order::${e}`);
    console.log(`migration-order: ${r.errors.length} finding(s) against ${baseRef} (${base.slice(0, 7)})`);
    process.exit(1);
  }
  console.log(
    `migration-order ok against ${baseRef} (${base.slice(0, 7)}): highest base version ${r.baseMax ?? "none"}; added ${r.added.length ? r.added.join(", ") : "none"}`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) main();
