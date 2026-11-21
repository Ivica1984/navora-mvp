#!/usr/bin/env node
// B0-4 (PRODUCT_BLOCKS.md §4, issue #919, ADR-175): "the state before #922" of a pgTAP file is today's file with exactly
// the CGR-110 block removed: the waiting SIG1 lock call(s) right after plan(), the one assertion that the file holds
// them, and one from the plan count. Nothing else changes, so red (before) and green (today) differ only by the remedy.
// Fails closed: a file without that block, or with an unexpected shape, throws instead of returning today's file.
//
// Usage as a CLI: node scripts/db-flaky/b0-4-strip-sig1-lock.mjs <file.sql>   (prints the stripped SQL to stdout)
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const LOCK = /^select pg_advisory_xact_lock\(hashtext\('navora\.sig1'\), hashtext\('[0-9a-f-]{36}'\)\);$/;
const PLAN = /^select plan\((\d+)\);$/;
const ASSERT_START = /^select is\(\(select count\(\*\)::int from pg_locks\s*$/;
const ASSERT_END = /'CGR-110: this file holds [^']*'\);$/;

/**
 * @param {string} sql today's pgTAP file
 * @returns {{ sql: string, removedLocks: number, removedAssertions: number, plan: { from: number, to: number } }}
 */
export function stripSig1Lock(sql) {
  const lines = sql.split("\n");

  const plans = lines.map((l, i) => [l, i]).filter(([l]) => PLAN.test(l));
  if (plans.length !== 1) throw new Error(`expected exactly one plan line, found ${plans.length}`);
  const [planLine, planIndex] = plans[0];
  const from = Number(PLAN.exec(planLine)[1]);

  const locks = lines.map((l, i) => [l, i]).filter(([l]) => LOCK.test(l)).map(([, i]) => i);
  if (locks.length === 0) throw new Error("no SIG1 lock call (CGR-110 block) found");
  for (let k = 1; k < locks.length; k++) {
    if (locks[k] !== locks[k - 1] + 1) throw new Error("the SIG1 lock calls are not one consecutive block");
  }

  const start = locks[locks.length - 1] + 1;
  if (!ASSERT_START.test(lines[start] ?? "")) throw new Error("the CGR-110 lock assertion does not follow the lock call");
  let end = -1;
  for (let i = start; i < Math.min(lines.length, start + 8); i++) {
    if (ASSERT_END.test(lines[i])) { end = i; break; }
  }
  if (end === -1) throw new Error("the CGR-110 lock assertion has no end line within 8 lines");

  const drop = new Set([...locks]);
  for (let i = start; i <= end; i++) drop.add(i);
  const out = lines.map((l, i) => (i === planIndex ? `select plan(${from - 1});` : l)).filter((_, i) => !drop.has(i));

  const leftover = out.filter((l) => !l.trim().startsWith("--") && l.includes("navora.sig1"));
  if (leftover.length) throw new Error(`SIG1 lock text left after stripping: ${leftover[0]}`);

  return { sql: out.join("\n"), removedLocks: locks.length, removedAssertions: 1, plan: { from, to: from - 1 } };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const file = process.argv[2];
  if (!file) { console.error("usage: b0-4-strip-sig1-lock.mjs <file.sql>"); process.exit(2); }
  process.stdout.write(stripSig1Lock(readFileSync(file, "utf8")).sql);
}
