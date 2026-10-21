import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// The official agent collaboration layer (docs/agents/) is validated by scripts/agents-check.mjs.
// These tests run the validator against a copy of the real files with one defect each.
const SCRIPT = join(process.cwd(), "scripts", "agents-check.mjs");
const REAL = join(process.cwd(), "docs", "agents");

function run(dir: string) {
  try {
    return { code: 0, out: execFileSync(process.execPath, [SCRIPT], { env: { ...process.env, AGENTS_DIR: dir }, encoding: "utf8", stdio: "pipe" }) };
  } catch (e) {
    const err = e as { status: number; stderr: string };
    return { code: err.status, out: err.stderr };
  }
}

function withEdit(file: string, from: string | RegExp, to: string) {
  const dir = mkdtempSync(join(tmpdir(), "agents-"));
  cpSync(REAL, dir, { recursive: true });
  const path = join(dir, file);
  const text = readFileSync(path, "utf8");
  const next = text.replace(from, to);
  expect(next, `fixture edit did not apply to ${file}`).not.toBe(text);
  writeFileSync(path, next);
  return run(dir);
}

describe("agent collaboration layer (docs/agents)", () => {
  it("the committed files are valid", () => {
    expect(run(REAL).code).toBe(0);
  });

  it("every PO priority must be acknowledged by engineering", () => {
    const r = withEdit("NEXT_CAPABILITY.md", /(\| 4 \| J3 .*\n)/, "$1| 5 | X9 | New thing | approved | – | test |\n");
    expect(r.code).toBe(1);
    expect(r.out).toContain("X9 has no row in IMPLEMENTATION_STATUS.md");
  });

  it("blocked work must name an open decision", () => {
    const r = withEdit("IMPLEMENTATION_STATUS.md", "| COORD-1 | – |", "| D-404 | – |");
    expect(r.out).toContain("blocked by D-404, which is not an open decision");
  });

  it("legal decisions cannot be owned by engineering", () => {
    const r = withEdit("OPEN_DECISIONS.md", "| D-4 | legal | legal |", "| D-4 | eng | legal |");
    expect(r.out).toContain("legal decisions cannot be owned by eng");
  });

  it("states are validated", () => {
    const r = withEdit("IMPLEMENTATION_STATUS.md", "| J1 | po | delivered |", "| J1 | po | done |");
    expect(r.out).toContain('State "done" must be one of');
  });

  it("ranks follow the row order", () => {
    const r = withEdit("NEXT_CAPABILITY.md", "| 2 | J1 |", "| 7 | J1 |");
    expect(r.out).toContain("rank 7 should be 2");
  });
});
