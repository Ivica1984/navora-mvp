import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { REPEAT_JOBS, WINDOW_START, WINDOW_VERDICT, jobBlock } from "../../scripts/ci-repeat.mjs";
import { WINDOW, report, verdict, zurich } from "../../scripts/ci-repeat-window.mjs";

// ADR-198 (PO hypothesis H-BK-00:39): a ci-repeat run labels itself acceptance evidence or not by its Zurich start and
// end time, because the e2e acceptance specs skip themselves at night (ADR-113) and a skipped test is not a verifying
// run (FE-071 (4)). Label only: the verdict never fails a job and changes no test.

const ROOT = process.cwd();
const SCRIPT = join(ROOT, "scripts/ci-repeat-window.mjs");
const REPEAT = readFileSync(join(ROOT, ".github/workflows/ci-repeat.yml"), "utf8");

describe("ADR-198 Zurich clock", () => {
  it("reads the Zurich wall clock in winter (CET) and summer (CEST)", () => {
    expect(zurich(new Date("2026-11-17T00:11:00Z"))).toEqual({ day: "2026-11-17", hm: "01:11" });
    expect(zurich(new Date("2026-07-01T00:25:00Z"))).toEqual({ day: "2026-07-01", hm: "02:25" });
    expect(zurich(new Date("2026-11-16T23:30:00Z"))).toEqual({ day: "2026-11-17", hm: "00:30" });
  });

  it("refuses an invalid date (fail closed)", () => {
    expect(() => zurich(new Date("not a date"))).toThrow(/invalid/);
  });
});

describe("ADR-198 window verdict", () => {
  it("the window is 02:20 to 22:20 Zurich", () => {
    expect(WINDOW).toEqual({ from: "02:20", until: "22:20" });
  });

  it("the night repeat 43977104731 (start 00:11 Zurich) is outside: started before 02:20", () => {
    const v = verdict("2026-11-16T23:11:00Z", "2026-11-16T23:21:00Z");
    expect(v.inside).toBe(false);
    expect(v.reason).toBe("started before 02:20 Zurich");
    expect(v.start).toBe("2026-11-17 00:11");
  });

  it("02:19 is outside, 02:20 is inside (start boundary)", () => {
    expect(verdict("2026-11-17T01:19:00Z", "2026-11-17T01:35:00Z").inside).toBe(false);
    expect(verdict("2026-11-17T01:20:00Z", "2026-11-17T01:35:00Z")).toMatchObject({ inside: true, reason: "" });
  });

  it("an end at 22:19 is inside, at 22:20 outside (end boundary)", () => {
    expect(verdict("2026-11-17T20:00:00Z", "2026-11-17T21:19:00Z").inside).toBe(true);
    const late = verdict("2026-11-17T20:00:00Z", "2026-11-17T21:20:00Z");
    expect(late).toMatchObject({ inside: false, reason: "ended at or after 22:20 Zurich" });
  });

  it("a run that crosses midnight Zurich is outside", () => {
    const v = verdict("2026-11-17T20:00:00Z", "2026-11-17T23:05:00Z");
    expect(v).toMatchObject({ inside: false, reason: "the run crossed midnight Europe/Zurich" });
  });

  it("summer time: 02:25 CEST start is inside, 02:15 CEST is outside", () => {
    expect(verdict("2026-07-01T00:25:00Z", "2026-07-01T00:40:00Z").inside).toBe(true);
    expect(verdict("2026-07-01T00:15:00Z", "2026-07-01T00:40:00Z").inside).toBe(false);
  });

  it("the spring DST day: 01:30 UTC is 03:30 CEST, inside", () => {
    expect(verdict("2027-03-28T01:30:00Z", "2027-03-28T01:45:00Z")).toMatchObject({ inside: true, start: "2027-03-28 03:30" });
  });

  it("a missing or invalid start counts as outside (fail closed)", () => {
    for (const s of [undefined, "", "garbage"]) {
      expect(verdict(s, "2026-11-17T10:00:00Z")).toMatchObject({ inside: false, reason: "start time unknown" });
    }
  });
});

describe("ADR-198 report text", () => {
  it("outside: a warning annotation and a summary that says NOT acceptance evidence", () => {
    const r = report(verdict("2026-11-16T23:11:00Z", "2026-11-16T23:21:00Z"));
    expect(r.annotation.startsWith("::warning title=ci-repeat window::NOT acceptance evidence")).toBe(true);
    expect(r.summary).toContain("NOT acceptance evidence");
    expect(r.summary).toContain("FE-071 (4)");
  });

  it("inside: a notice that still requires reading the skip counts, never a pass claim", () => {
    const r = report(verdict("2026-11-17T09:00:00Z", "2026-11-17T09:12:00Z"));
    expect(r.annotation.startsWith("::notice title=ci-repeat window::Inside")).toBe(true);
    expect(r.summary).not.toContain("NOT acceptance evidence");
    expect(r.summary).toContain("0 skipped");
    expect(r.summary).not.toMatch(/\bpassed\b|10\/10/);
  });
});

describe("ADR-198 CLI (never fails the run)", () => {
  function cli(mode: string, env: Record<string, string>) {
    return execFileSync("node", [SCRIPT, mode], { encoding: "utf8", env: { ...process.env, ...env } });
  }

  it("start writes started=<ISO> to GITHUB_OUTPUT", () => {
    const dir = mkdtempSync(join(tmpdir(), "repeat-window-"));
    const out = join(dir, "out");
    writeFileSync(out, "");
    const log = cli("start", { REPEAT_WINDOW_NOW: "2026-11-17T09:00:00.000Z", GITHUB_OUTPUT: out });
    expect(readFileSync(out, "utf8")).toBe("started=2026-11-17T09:00:00.000Z\n");
    expect(log).toContain("2026-11-17 10:00 Europe/Zurich");
  });

  it("verdict outside the window exits 0 and writes the warning and the summary", () => {
    const dir = mkdtempSync(join(tmpdir(), "repeat-window-"));
    const summary = join(dir, "summary");
    writeFileSync(summary, "");
    const log = cli("verdict", {
      REPEAT_STARTED: "2026-11-16T23:11:00Z",
      REPEAT_WINDOW_NOW: "2026-11-16T23:21:00Z",
      GITHUB_STEP_SUMMARY: summary,
    });
    expect(log).toContain("::warning title=ci-repeat window::NOT acceptance evidence");
    expect(readFileSync(summary, "utf8")).toContain("### ci-repeat window: NOT acceptance evidence");
  });

  it("verdict with no recorded start exits 0 and says outside", () => {
    const log = cli("verdict", { REPEAT_STARTED: "", REPEAT_WINDOW_NOW: "2026-11-17T09:00:00Z", GITHUB_STEP_SUMMARY: "" });
    expect(log).toContain("start time unknown");
  });

  it("an unknown mode is a usage error (exit 2), not a silent pass", () => {
    expect(() => execFileSync("node", [SCRIPT, "bogus"], { stdio: "pipe" })).toThrow();
  });
});

describe("ADR-198 wiring in ci-repeat.yml", () => {
  it("every repeated attempt waits for window-start, so none starts before the recorded time", () => {
    for (const id of REPEAT_JOBS) expect(jobBlock(REPEAT, id)).toContain(`\n    needs: [${WINDOW_START}]\n`);
  });

  it("the verdict job runs after all attempts, also after a failure", () => {
    const block = jobBlock(REPEAT, WINDOW_VERDICT);
    expect(block).toContain(`    needs: [${WINDOW_START}, ${REPEAT_JOBS.join(", ")}]\n`);
    expect(block).toContain("    if: always()\n");
    expect(block).toContain("REPEAT_STARTED: ${{ needs.window-start.outputs.started }}");
    expect(block).toContain("run: node scripts/ci-repeat-window.mjs verdict\n");
  });

  it("window-start exposes the start as a job output", () => {
    const block = jobBlock(REPEAT, WINDOW_START);
    expect(block).toContain("      started: ${{ steps.start.outputs.started }}\n");
    expect(block).toContain("run: node scripts/ci-repeat-window.mjs start\n");
  });

  it("the window jobs neither fail nor skip a test (label only, ADR-198)", () => {
    const src = readFileSync(SCRIPT, "utf8");
    expect(src).not.toContain("process.exit(1)");
    for (const id of [WINDOW_START, WINDOW_VERDICT]) {
      const block = jobBlock(REPEAT, id);
      expect(block).not.toMatch(/continue-on-error|exit 1|skip/);
    }
  });
});
