import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { ATTEMPTS_DEFAULT, ATTEMPTS_SHORT, REPEAT_JOBS, jobBlock, render } from "../../scripts/ci-repeat.mjs";

// B0-2 (docs/product/PRODUCT_BLOCKS.md §4, ADR-168): a repeat check runs db and e2e N times on one commit, with the very
// same steps as ci.yml, so "10 of 10 green" on a named commit is evidence and every failed attempt is named.

const ROOT = process.cwd();
const CI = readFileSync(join(ROOT, ".github/workflows/ci.yml"), "utf8");
const REPEAT_PATH = join(ROOT, ".github/workflows/ci-repeat.yml");
const REPEAT = readFileSync(REPEAT_PATH, "utf8");
const SCRIPT = join(ROOT, "scripts/ci-repeat.mjs");

function stepsOf(block: string): string {
  return block.split("\n    steps:\n")[1] ?? "";
}

describe("B0-2 ci-repeat.yml is generated from ci.yml (no drift)", () => {
  it("the committed file is exactly what the generator renders from today's ci.yml", () => {
    expect(REPEAT).toBe(render(CI));
  });

  it("the --check CLI passes on the committed files", () => {
    expect(() => execFileSync("node", [SCRIPT, "--check"], { cwd: ROOT, stdio: "pipe" })).not.toThrow();
  });

  it("a changed db step in ci.yml makes the committed copy stale (the check would fail)", () => {
    const changed = CI.replace("supabase db reset --no-seed", "supabase db reset --no-seed --debug");
    expect(changed).not.toBe(CI);
    expect(render(changed)).not.toBe(REPEAT);
  });

  it.each(REPEAT_JOBS)("the %s steps are byte-identical to ci.yml (apart from the per-attempt artifact name)", (id) => {
    const original = stepsOf(jobBlock(CI, id));
    const copy = stepsOf(jobBlock(REPEAT, id)).replace(/(name: playwright-report)-\$\{\{ matrix\.attempt \}\}/g, "$1");
    expect(original.length).toBeGreaterThan(500);
    expect(copy).toBe(original);
  });
});

describe("B0-2 ci-repeat.yml wiring", () => {
  it("runs only on a push to a repeat/ branch: never on a pull request, never on main or recovery/main", () => {
    expect(REPEAT).toMatch(/\non:\n {2}push:\n {4}branches: \['repeat\/\*\*'\]\n\n/);
    expect(REPEAT).not.toMatch(/\n {2}pull_request/);
    expect(REPEAT).not.toMatch(/branches: \[[^\]]*recovery\/main/);
  });

  it("does not reuse the four required check names (a repeat run can never stand in for a required check)", () => {
    for (const n of [
      "name: app (lint · typecheck · unit · audit · build)",
      "name: db (migrations · seed · pgTAP)",
      "name: e2e (auth · protected routes · Playwright)",
      "name: ui-screenshots (390 · 1440 · every role)",
    ]) {
      expect(REPEAT).not.toContain(`    ${n}\n`);
    }
    expect(REPEAT).toContain("    name: db repeat ${{ matrix.attempt }} (migrations · seed · pgTAP)\n");
    expect(REPEAT).toContain("    name: e2e repeat ${{ matrix.attempt }} (auth · protected routes · Playwright)\n");
  });

  it("every attempt runs to the end (fail-fast off) and a repeat run is never cancelled", () => {
    for (const id of REPEAT_JOBS) {
      expect(jobBlock(REPEAT, id)).toContain("    strategy:\n      fail-fast: false\n");
    }
    expect(REPEAT).toContain("\nconcurrency:\n  group: ci-repeat-${{ github.sha }}-${{ github.ref }}\n  cancel-in-progress: false\n");
  });

  it("10 attempts by default; repeat/2/… runs 2 (a cheap probe of the mechanism)", () => {
    expect(ATTEMPTS_DEFAULT).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(ATTEMPTS_SHORT).toEqual([1, 2]);
    const line =
      "        attempt: ${{ fromJSON(startsWith(github.ref, 'refs/heads/repeat/2/') && '[1,2]' || '[1,2,3,4,5,6,7,8,9,10]') }}\n";
    for (const id of REPEAT_JOBS) expect(jobBlock(REPEAT, id)).toContain(line);
  });

  it("artifacts are unique per attempt (upload-artifact@v4 refuses duplicate names)", () => {
    expect(REPEAT).not.toMatch(/name: playwright-report\n/);
    expect(REPEAT).toContain("name: playwright-report-${{ matrix.attempt }}\n");
  });

  it("only db and e2e are repeated; app and ui-screenshots are not part of it", () => {
    expect(REPEAT_JOBS).toEqual(["db", "e2e"]);
    expect(REPEAT).not.toMatch(/\n {2}app:\n/);
    expect(REPEAT).not.toMatch(/\n {2}ui-screenshots:\n/);
  });

  it("read-only token and the same top-level env as ci.yml", () => {
    expect(REPEAT).toContain("\npermissions:\n  contents: read\n");
    expect(REPEAT).toContain('\nenv:\n  NEXT_TELEMETRY_DISABLED: "1"\n');
  });

  it("ci.yml itself is untouched by B0-2 (CI2 wiring tests keep holding)", () => {
    expect(CI).toMatch(/\non:\n {2}pull_request:\n {2}push:\n {4}branches: \[main, recovery\/main\]\n/);
    expect(CI).not.toContain("matrix.attempt");
  });
});

describe("B0-2 generator fails closed", () => {
  it("throws when a repeated job is missing from ci.yml", () => {
    expect(() => render(CI.replace("\n  e2e:\n", "\n  e2e-renamed:\n"))).toThrow(/e2e/);
  });

  it("throws when a job's name line is not where it expects it", () => {
    expect(() => render(CI.replace("    name: db (migrations · seed · pgTAP)\n", ""))).toThrow(/db/);
  });

  it("throws when ci.yml already uses a strategy or matrix for a repeated job", () => {
    const withMatrix = CI.replace(
      "    name: db (migrations · seed · pgTAP)\n",
      "    name: db (migrations · seed · pgTAP)\n    strategy:\n      matrix:\n        x: [1]\n",
    );
    expect(() => render(withMatrix)).toThrow(/strategy/);
  });
});
