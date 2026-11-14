import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// #635 (ADR-113): the e2e run-day guard. Clock replaced through E2E_GUARD_NOW; no sleeping (E2E_GUARD_DRY_RUN).
const SCRIPT = join(process.cwd(), "scripts/ci-e2e-day-guard.sh");

function run(mode: "wait" | "check", isoUtc: string, file: string, margin?: number): string {
  return execFileSync("bash", [SCRIPT, mode], {
    encoding: "utf8",
    env: {
      ...process.env,
      E2E_GUARD_NOW: String(Math.floor(Date.parse(isoUtc) / 1000)),
      E2E_GUARD_DRY_RUN: "1",
      E2E_DAY_FILE: file,
      ...(margin === undefined ? {} : { E2E_DAY_MARGIN_MIN: String(margin) }),
    },
  });
}

function waitSeconds(out: string): number {
  const m = /^WAIT (\d+)$/m.exec(out);
  if (!m) throw new Error(`no WAIT line in: ${out}`);
  return Number(m[1]);
}

const tmp = () => join(mkdtempSync(join(tmpdir(), "e2e-day-")), "day");

describe("ci-e2e-day-guard wait", () => {
  it("waits until 30 s after midnight Europe/Zurich when less than 20 min are left (CET)", () => {
    const f = tmp();
    const out = run("wait", "2026-10-28T22:50:00Z", f); // 23:50 CET
    expect(waitSeconds(out)).toBe(10 * 60 + 30);
    expect(out).toContain("e2e run day (Europe/Zurich): 2026-10-29");
  });

  it("uses the Zurich clock in summer time (CEST, UTC+2)", () => {
    const out = run("wait", "2026-06-30T21:45:00Z", tmp()); // 23:45 CEST
    expect(waitSeconds(out)).toBe(15 * 60 + 30);
    expect(out).toContain("2026-07-01");
  });

  it("does not wait with 20 min or more left, nor just after midnight", () => {
    expect(waitSeconds(run("wait", "2026-10-28T22:40:00Z", tmp()))).toBe(0); // 23:40 CET
    expect(waitSeconds(run("wait", "2026-10-28T23:00:30Z", tmp()))).toBe(0); // 00:00:30 CET
    expect(waitSeconds(run("wait", "2026-10-28T13:00:00Z", tmp()))).toBe(0); // 14:00 CET
  });

  it("the margin is configurable", () => {
    expect(waitSeconds(run("wait", "2026-10-28T22:25:00Z", tmp(), 40))).toBe(35 * 60 + 30); // 23:25 CET, 40 min
  });
});

describe("ci-e2e-day-guard check", () => {
  it("flags a run whose Zurich day changed and stays quiet otherwise", () => {
    const f = tmp();
    writeFileSync(f, "2026-10-28\n");
    expect(run("check", "2026-10-28T23:05:00Z", f)).toContain("CHANGED"); // 00:05 CET on the 29th
    expect(run("check", "2026-10-28T22:05:00Z", f)).not.toContain("CHANGED"); // 23:05 CET on the 28th
  });

  it("says nothing to compare when no day was recorded", () => {
    expect(run("check", "2026-10-28T23:05:00Z", join(tmp(), "missing"))).toContain("nothing to compare");
  });
});
