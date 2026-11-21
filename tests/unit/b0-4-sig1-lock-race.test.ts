import { readFileSync, statSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { stripSig1Lock } from "../../scripts/db-flaky/b0-4-strip-sig1-lock.mjs";

/**
 * B0-4 (PRODUCT_BLOCKS.md §4), issue #919, ADR-175. pgTAP 080 failed 17/58 once on `f5f5e09` (tests 6-9 "have" empty:
 * no delivery rows), while the second run on the same commit passed. #922 (ADR-162) gave 080 (and eight more files)
 * the SIG1 evaluation lock of org A at its start, because `private.evaluate_signals` skips (returns 0, writes nothing)
 * when another session holds that lock, as the pg_cron job `navora-sig1-signals` does during its run.
 *
 * B0-4 asks for the race to be **reproduced**: a second session holds the SIG1 lock during the evaluation; red on the
 * state before #922, green on today's; 062, 078 and 080 also under a forced scheduler run.
 * `scripts/db-flaky/b0-4-sig1-lock-race.sh` does that in real sessions. "The state before #922" is today's file with
 * exactly the #922 block removed (`b0-4-strip-sig1-lock.mjs`), so the only difference between red and green is the
 * remedy. This guard is written before the script. It reads files only; no product function, rule or assertion changes.
 */
const DB_TESTS = "supabase/tests/database";
const F080 = `${DB_TESTS}/080_cond1_leave1_door1_conditions.test.sql`;
const F062 = `${DB_TESTS}/062_sig1_safety_signal_delivery.test.sql`;
const F078 = `${DB_TESTS}/078_leave1_14_claims_lapse.test.sql`;
const SCRIPT = "scripts/db-flaky/b0-4-sig1-lock-race.sh";
const read = (p: string) => readFileSync(p, "utf8");

type Stripped = { sql: string; removedLocks: number; removedAssertions: number; plan: { from: number; to: number } };
const strip = (sql: string): Stripped => stripSig1Lock(sql);

/** Lines that are SQL, not comments or blank. */
const code = (sql: string) => sql.split("\n").filter((l) => l.trim() !== "" && !l.trim().startsWith("--"));

/** The text of one job of ci.yml (`  <id>:` up to the next job), as in ci2-scope.test.ts. */
function job(text: string, id: string): string {
  const start = text.indexOf(`\n  ${id}:\n`);
  expect(start, `job ${id} in ci.yml`).toBeGreaterThan(-1);
  const rest = text.slice(start + 1);
  const next = rest.slice(1).search(/\n {2}[a-z][a-z0-9-]*:\n/);
  return next === -1 ? rest : rest.slice(0, next + 1);
}

describe("B0-4: 080 without the #922 block (the state before #922)", () => {
  const today = read(F080);
  const before = strip(today);

  it("removes exactly one lock call and the one CGR-110 lock assertion, and lowers the plan by one (59 -> 58, as on f5f5e09)", () => {
    expect(before.removedLocks).toBe(1);
    expect(before.removedAssertions).toBe(1);
    expect(before.plan).toEqual({ from: 59, to: 58 });
    expect(before.sql).toContain("select plan(58);");
    expect(before.sql).not.toContain("select plan(59);");
  });

  it("leaves no SIG1 lock call or lock assertion in the SQL (comments may still name it)", () => {
    expect(code(before.sql).filter((l) => l.includes("navora.sig1"))).toEqual([]);
    expect(before.sql).not.toContain("'CGR-110: this file holds");
  });

  it("changes nothing else: every other line of today's file is kept, in order", () => {
    const removed = today.split("\n").filter((l) => !before.sql.split("\n").includes(l));
    // Only the plan line, the lock line and the assertion's lines go.
    expect(removed.some((l) => l === "select plan(59);")).toBe(true);
    expect(removed.filter((l) => l.startsWith("select pg_advisory_xact_lock(")).length).toBe(1);
    expect(removed.length).toBeLessThanOrEqual(1 + 1 + 6);
    const kept = today.split("\n").filter((l) => before.sql.split("\n").includes(l) || l === "select plan(59);");
    const keptWithoutPlan = kept.filter((l) => l !== "select plan(59);");
    const strippedWithoutPlan = before.sql.split("\n").filter((l) => l !== "select plan(58);");
    expect(strippedWithoutPlan).toEqual(keptWithoutPlan);
  });

  it("still has the pinned clock and the evaluations the #919 failure read (tests 6-9 deliver nothing when skipped)", () => {
    expect(before.sql).toContain("set_config('navora.test_now'");
    expect(code(before.sql).some((l) => l.includes("private.evaluate_signals("))).toBe(true);
  });
});

describe("B0-4: the strip function fails closed", () => {
  it("throws on a file without the lock block, so the 'before' run can never silently equal today's file", () => {
    expect(() => strip("begin;\nselect plan(3);\nselect ok(true);\nrollback;\n")).toThrow(/no SIG1 lock/);
  });

  it("throws when the lock assertion does not follow the lock call", () => {
    const sql = [
      "begin;",
      "select plan(2);",
      "select pg_advisory_xact_lock(hashtext('navora.sig1'), hashtext('00000000-0000-4000-b000-000000000011'));",
      "select ok(true);",
      "rollback;",
    ].join("\n");
    expect(() => strip(sql)).toThrow(/assertion/);
  });

  it("throws on a file with no or two plan lines", () => {
    const lock = "select pg_advisory_xact_lock(hashtext('navora.sig1'), hashtext('00000000-0000-4000-b000-000000000011'));";
    const assertion = [
      "select is((select count(*)::int from pg_locks",
      "           where locktype = 'advisory'),",
      "  1, 'CGR-110: this file holds the SIG1 evaluation lock of org A, so no concurrent evaluator takes it');",
    ];
    expect(() => strip(["begin;", lock, ...assertion, "rollback;"].join("\n"))).toThrow(/plan/);
    expect(() => strip(["begin;", "select plan(2);", "select plan(2);", lock, ...assertion].join("\n"))).toThrow(/plan/);
  });

  it("handles 062's two locks (org A and org B) under one assertion", () => {
    const s = strip(read(F062));
    expect(s.removedLocks).toBe(2);
    expect(s.removedAssertions).toBe(1);
    expect(s.plan.to).toBe(s.plan.from - 1);
    expect(code(s.sql).filter((l) => l.includes("navora.sig1"))).toEqual([]);
  });

  it("handles 078 the same way as 080", () => {
    const s = strip(read(F078));
    expect(s.removedLocks).toBe(1);
    expect(s.removedAssertions).toBe(1);
    expect(s.plan.to).toBe(s.plan.from - 1);
  });
});

describe("B0-4: today's files keep the #922 remedy (the 'green' side)", () => {
  for (const f of [F062, F078, F080]) {
    it(`${f.split("/").pop()} takes the waiting lock (not the try form) before its first evaluation`, () => {
      const lines = code(read(f));
      const lock = lines.findIndex((l) => l.startsWith("select pg_advisory_xact_lock(hashtext('navora.sig1')"));
      const firstEval = lines.findIndex((l) => /private\.evaluate_(all_)?signals\(/.test(l));
      expect(lock).toBeGreaterThan(-1);
      expect(firstEval).toBeGreaterThan(lock);
      expect(lines.some((l) => l.includes("pg_try_advisory_xact_lock(hashtext('navora.sig1')"))).toBe(false);
    });
  }

  it("the evaluator still skips instead of waiting (0060), which is what makes the race possible", () => {
    const m = read("supabase/migrations/20261021000060_sig1_safety_signal_delivery.sql");
    expect(m).toContain("if not pg_try_advisory_xact_lock(hashtext('navora.sig1'), hashtext(p_org::text)) then return 0; end if;");
    expect(m).toContain("'navora-sig1-signals', '* * * * *', 'select private.evaluate_all_signals()'");
  });
});

describe("B0-4: the reproduction script", () => {
  const sh = read(SCRIPT);

  it("exists and is executable", () => {
    expect(statSync(SCRIPT).mode & 0o111).not.toBe(0);
    expect(sh.startsWith("#!/usr/bin/env bash\n")).toBe(true);
    expect(sh).toContain("set -euo pipefail");
  });

  it("builds the 'before' file from today's 080 with the strip module (one source of truth, no stored copy)", () => {
    expect(sh).toContain(`F080="${F080}"`);
    expect(sh).toContain("node scripts/db-flaky/b0-4-strip-sig1-lock.mjs");
  });

  it("holds org A's SIG1 lock in a second real session and ends it by its application name", () => {
    expect(sh).toContain("ORG_A=00000000-0000-4000-b000-000000000011");
    expect(sh).toMatch(/pg_advisory_lock\(hashtext\('navora\.sig1'\), hashtext\('\$ORG_A'\)\)/);
    expect(sh).toContain("PGAPPNAME=b0-4-holder");
    expect(sh).toMatch(/pg_terminate_backend\(pid\)[\s\S]*application_name = 'b0-4-holder'/);
  });

  it("requires the #919 signature on the 'before' side: red, with tests 6 to 9 among the failures", () => {
    expect(sh).toMatch(/for t in 6 7 8 9/);
    expect(sh).toContain("not ok - before #922: 080 stayed green while another session held the lock (race not reproduced)");
  });

  it("requires today's 080 to wait for the lock (not skip) and then pass in full", () => {
    expect(sh).toContain("not ok - today: 080 did not wait for the lock");
    expect(sh).toContain("not ok - today: 080 is not green after the lock was released");
  });

  it("runs 062, 078 and 080 under a forced scheduler run (the pg_cron job's own command, committed, repeatedly)", () => {
    expect(sh).toContain("select private.evaluate_all_signals();");
    for (const f of [F062, F078, F080]) expect(sh).toContain((f.split("/").pop() ?? "-").replace(".test.sql", ""));
    expect(sh).toContain("not ok - forced scheduler run:");
  });

  it("writes nothing it keeps: every pgTAP file rolls back; only the forced scheduler runs commit, as pg_cron does", () => {
    for (const f of [F062, F078, F080]) expect(code(read(f)).slice(-1)[0]).toBe("rollback;");
  });

  it("fails closed and ends with the collected status", () => {
    expect(sh).toMatch(/exit "\$status"\s*$/);
  });
});

describe("B0-4: CI wiring", () => {
  const db = job(read(".github/workflows/ci.yml"), "db");

  it("runs on every full db job, after the clock is unpinned (the files pin their own clock)", () => {
    const step = db.indexOf("scripts/ci-step.sh b0-4-sig1-lock-race scripts/db-flaky/b0-4-sig1-lock-race.sh");
    expect(step).toBeGreaterThan(-1);
    expect(step).toBeGreaterThan(db.indexOf("- name: Unpin the database clock"));
    const name = db.lastIndexOf("- name:", step);
    const header = db.slice(name, step);
    expect(header).toContain("if: steps.detect.outputs.present == 'true'\n");
    expect(header).not.toMatch(/github\.head_ref|startsWith/);
  });
});
