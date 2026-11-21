import { readdirSync, readFileSync, statSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * B0-3 part 2 (PRODUCT_BLOCKS.md §4), issue #603, ADR-170. pgTAP 079 test 44 (WORK1-5 catalogue: a fingerprint of
 * everything five seed roles read, taken before and after w1's actions) failed intermittently until #761 (ADR-126)
 * put the file at REPEATABLE READ. The failure class is a commit by another session landing between the two
 * catalogues: at READ COMMITTED each statement sees it. The local stack's scheduled evaluator
 * (`private.evaluate_all_signals()`, pg_cron job `navora-sig1-signals`) is such a writer: it upserts
 * `private.signal_scheduler_runs.ran_at = now()`, which `public.signal_evaluator_health()` shows to Operations and
 * administrators (the recorded `admin` shape).
 *
 * `scripts/db-flaky/b0-3-079-snapshot.sh` reproduces that race deterministically in two real sessions (a forced
 * evaluator run committed between the catalogues): red at READ COMMITTED, green at REPEATABLE READ. This guard keeps
 * the reproduction wired into CI and keeps every before/after catalogue file at REPEATABLE READ. It reads files only;
 * no product function, rule or assertion changes.
 */
const DB_TESTS = "supabase/tests/database";
const SCRIPT = "scripts/db-flaky/b0-3-079-snapshot.sh";
const read = (p: string) => readFileSync(p, "utf8");

/** First SQL statement of a file, ignoring `--` comment lines and blank lines. */
function firstStatement(sql: string): string {
  const line = sql.split("\n").find((l) => l.trim() !== "" && !l.trim().startsWith("--"));
  return (line ?? "").trim().toLowerCase();
}

/** The text of one job of ci.yml (`  <id>:` up to the next job), as in ci2-scope.test.ts. */
function job(text: string, id: string): string {
  const start = text.indexOf(`\n  ${id}:\n`);
  expect(start, `job ${id} in ci.yml`).toBeGreaterThan(-1);
  const rest = text.slice(start + 1);
  const next = rest.slice(1).search(/\n {2}[a-z][a-z0-9-]*:\n/);
  return next === -1 ? rest : rest.slice(0, next + 1);
}

describe("B0-3 part 2: pgTAP 079 snapshot race (issue #603)", () => {
  it("079 starts its transaction at REPEATABLE READ (the ADR-126 fix stays in place)", () => {
    expect(firstStatement(read(`${DB_TESTS}/079_work1_working_day.test.sql`))).toBe("begin isolation level repeatable read;");
  });

  it("every pgTAP file that compares a before/after catalogue fingerprint runs at REPEATABLE READ", () => {
    const files = readdirSync(DB_TESTS).filter((f) => f.endsWith(".sql"));
    const catalogue = files.filter((f) => /pg_temp\.fingerprint\s*\(/.test(read(`${DB_TESTS}/${f}`)));
    expect(catalogue).toContain("079_work1_working_day.test.sql");
    const wrong = catalogue.filter((f) => firstStatement(read(`${DB_TESTS}/${f}`)) !== "begin isolation level repeatable read;");
    expect(wrong).toEqual([]);
  });

  describe("the reproduction script", () => {
    const sh = read(SCRIPT);

    it("exists and is executable", () => {
      expect(statSync(SCRIPT).mode & 0o111).not.toBe(0);
      expect(sh.startsWith("#!/usr/bin/env bash\n")).toBe(true);
      expect(sh).toContain("set -euo pipefail");
    });

    it("takes the catalogue function from 079 itself (one source of truth, no copy that can drift)", () => {
      expect(sh).toContain('FILE="supabase/tests/database/079_work1_working_day.test.sql"');
      expect(sh).toMatch(/awk '[^']*pg_temp\\\.fingerprint\\\(/);
    });

    it("runs both isolation levels", () => {
      expect(sh).toMatch(/race "read committed"/);
      expect(sh).toMatch(/race "repeatable read"/);
    });

    it("forces the scheduler's own command between the catalogues, in a second session that commits", () => {
      const cron = read("supabase/migrations/20261021000060_sig1_safety_signal_delivery.sql");
      expect(cron).toContain("'navora-sig1-signals', '* * * * *', 'select private.evaluate_all_signals()'");
      expect(sh).toContain("select private.evaluate_all_signals();");
      expect(sh).toMatch(/pg_advisory_lock\(\$GATE\)/);
      expect(sh).toMatch(/pg_advisory_xact_lock\(\$GATE\)/);
    });

    it("fails closed: red if READ COMMITTED shows no difference (race not reproduced) or REPEATABLE READ shows one", () => {
      expect(sh).toContain("not ok - READ COMMITTED: no difference after a committed evaluator run");
      expect(sh).toContain("not ok - REPEATABLE READ: the catalogue changed");
      expect(sh).toMatch(/exit "\$status"\s*$/);
    });

    it("writes no fixture: the catalogue sessions roll back", () => {
      expect(sh.match(/^rollback;$/gm)?.length ?? 0).toBeGreaterThanOrEqual(1);
      expect(sh).not.toMatch(/^commit;$/m);
    });
  });

  it("the db job of ci.yml runs it on every run, after the pgTAP suite", () => {
    const db = job(read(".github/workflows/ci.yml"), "db");
    const at = db.indexOf("scripts/db-flaky/b0-3-079-snapshot.sh");
    expect(at).toBeGreaterThan(db.indexOf("supabase test db"));
    const step = db.slice(db.lastIndexOf("- name:", at), at);
    expect(step).not.toMatch(/head_ref|startsWith/);
    expect(step).toContain("steps.detect.outputs.present == 'true'");
  });
});
