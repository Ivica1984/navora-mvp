import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * CGR-110 remainder (#919, ADR-162; first part #399, ADR-137). `private.evaluate_signals` starts with
 * `pg_try_advisory_xact_lock(hashtext('navora.sig1'), hashtext(org))` and returns 0 without evaluating when another
 * session holds that lock (0060: "skip instead of waiting"). The local stack's pg_cron job `navora-sig1-signals` runs
 * `evaluate_all_signals` every minute and holds each organisation's lock until its run ends; it cannot see a test
 * file's uncommitted fixtures. A pgTAP file whose evaluation meets such a run therefore reads "no signal, no delivery"
 * (062 tests 47/50 on #395 and #800; 064 on 2026-11-05; 080 tests 6-9 on `f5f5e09`, #919).
 *
 * This guard keeps every pgTAP file that calls the evaluator independent of the scheduler: before its first
 * evaluation it takes (waiting, never the try form) the SIG1 lock of every organisation it evaluates, and asserts
 * with `pg_locks` that it holds it. It checks the test files only; no product function, rule or assertion changes.
 */
const DIR = "supabase/tests/database";
const ORG = /'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'/;

/** SQL without `--` comments (the files put no `--` inside string literals on evaluator lines). */
function code(sql: string): string {
  return sql
    .split("\n")
    .map((line) => {
      const at = line.indexOf("--");
      return at >= 0 ? line.slice(0, at) : line;
    })
    .join("\n");
}

type EvaluatorFile = {
  file: string;
  sql: string;
  /** Organisations passed to `private.evaluate_signals(<literal>, …)`. */
  orgs: Set<string>;
  /** Calls of `evaluate_signals` whose first argument is not a literal organisation id. */
  nonLiteral: number;
  /** Whether the file calls `private.evaluate_all_signals()` (outside a quoted string). */
  callsAll: boolean;
  /** Offset of the first evaluator call (or the definition of a helper that contains one). */
  firstCall: number;
};

function evaluatorFiles(): EvaluatorFile[] {
  const out: EvaluatorFile[] = [];
  for (const file of readdirSync(DIR).filter((f) => f.endsWith(".sql")).sort()) {
    const sql = code(readFileSync(`${DIR}/${file}`, "utf8"));
    const orgs = new Set<string>();
    let nonLiteral = 0;
    let firstCall = Number.POSITIVE_INFINITY;
    // A quoted signature (has_function_privilege('authenticated', 'private.evaluate_signals(uuid, boolean)', …)) is no call.
    for (const m of sql.matchAll(/(?<!')private\.evaluate_signals\(([^)]*)/g)) {
      firstCall = Math.min(firstCall, m.index ?? 0);
      const org = ORG.exec(m[1].split(",")[0]);
      if (org) orgs.add(org[1]);
      else nonLiteral += 1;
    }
    let callsAll = false;
    for (const m of sql.matchAll(/(?<!')private\.evaluate_all_signals\(\)(?!')/g)) {
      callsAll = true;
      firstCall = Math.min(firstCall, m.index ?? 0);
    }
    if (orgs.size > 0 || nonLiteral > 0 || callsAll) out.push({ file, sql, orgs, nonLiteral, callsAll, firstCall });
  }
  return out;
}

function lockAt(sql: string, org: string): number {
  return sql.indexOf(`pg_advisory_xact_lock(hashtext('navora.sig1'), hashtext('${org}'))`);
}

describe("CGR-110 (#919): every pgTAP file that calls the SIG1 evaluator owns the lock of what it evaluates", () => {
  const files = evaluatorFiles();

  it("finds the evaluator files (the guard is never vacuous)", () => {
    const names = files.map((f) => f.file.slice(0, 3));
    for (const n of ["062", "064", "065", "067", "068", "069", "078", "080", "090", "099"]) {
      expect(names, `pgTAP ${n} calls the evaluator`).toContain(n);
    }
  });

  it.each(evaluatorFiles().map((f) => [f.file, f] as const))(
    "%s takes the SIG1 lock of every organisation it evaluates before its first evaluation",
    (_name, f) => {
      expect(f.nonLiteral, `${f.file}: evaluate_signals is called with a literal organisation id`).toBe(0);
      if (f.callsAll) expect(f.orgs.size, `${f.file}: evaluate_all_signals is called with an organisation lock held`).toBeGreaterThan(0);
      for (const org of f.orgs) {
        const at = lockAt(f.sql, org);
        expect(at, `${f.file}: takes pg_advisory_xact_lock for ${org}`).toBeGreaterThanOrEqual(0);
        expect(at, `${f.file}: the lock for ${org} comes before the first evaluation`).toBeLessThan(f.firstCall);
      }
    },
  );

  it.each(evaluatorFiles().map((f) => [f.file, f] as const))(
    "%s waits for the lock (never the try form) and asserts it holds it",
    (_name, f) => {
      expect(f.sql, `${f.file}: no try-lock on navora.sig1 in a test`).not.toMatch(/pg_try_advisory_xact_lock\(hashtext\('navora\.sig1'\)/);
      expect(f.sql, `${f.file}: reads pg_locks`).toMatch(/from pg_locks/);
      const assertion = f.sql.indexOf("'CGR-110: this file holds the SIG1 evaluation lock");
      expect(assertion, `${f.file}: names the CGR-110 lock assertion`).toBeGreaterThanOrEqual(0);
      expect(assertion, `${f.file}: asserts the lock before the first evaluation`).toBeLessThan(f.firstCall);
    },
  );
});
