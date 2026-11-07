import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseTable, bare } from "../../scripts/agents-coordination/parse.mjs";

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
    // Append a row after the last row of the priority queue, whatever its length (the PO re-ranks freely).
    const dir = mkdtempSync(join(tmpdir(), "agents-"));
    cpSync(REAL, dir, { recursive: true });
    const path = join(dir, "NEXT_CAPABILITY.md");
    const lines = readFileSync(path, "utf8").split("\n");
    const head = lines.findIndex((l) => l.trim() === "## Priority queue");
    let last = head;
    for (let i = head + 1; i < lines.length && !lines[i].startsWith("## "); i++) if (lines[i].startsWith("|")) last = i;
    const rank = lines.slice(head, last + 1).filter((l) => /^\| \d+ \|/.test(l)).length + 1;
    lines.splice(last + 1, 0, `| ${rank} | X9 | New thing | approved | – | test |`);
    writeFileSync(path, lines.join("\n"));
    const r = run(dir);
    expect(r.code).toBe(1);
    expect(r.out).toContain("X9 has no row in IMPLEMENTATION_STATUS.md");
  });

  it("blocked work must name an open decision", () => {
    // Blocked-by is the 8th column; set it on the first item row, whatever it holds today.
    const r = withEdit("IMPLEMENTATION_STATUS.md", /^(\| (?!ID )[A-Z][A-Za-z0-9-]* \|(?:[^|\n]*\|){6})[^|\n]*\|/m, "$1 D-404 |");
    expect(r.out).toContain("blocked by D-404, which is not an open decision");
  });

  it("legal decisions cannot be owned by engineering", () => {
    const r = withEdit("OPEN_DECISIONS.md", "| D-4 | legal | legal |", "| D-4 | eng | legal |");
    expect(r.out).toContain("legal decisions cannot be owned by eng");
  });

  it("states are validated", () => {
    const r = withEdit("IMPLEMENTATION_STATUS.md", /^(\| J1 \| po \| )[a-z-]+ \|/m, "$1done |");
    expect(r.out).toContain('State "done" must be one of');
  });

  it("ranks follow the row order", () => {
    // COORD-3: take the queue's second row, whatever item the PO ranked there, and give it a wrong rank.
    const queue = readFileSync(join(REAL, "NEXT_CAPABILITY.md"), "utf8");
    const second = queue.match(/^\| 2 \| [A-Za-z0-9-]+ \|/m)?.[0];
    expect(second, "the priority queue needs at least two rows").toBeTruthy();
    const r = withEdit("NEXT_CAPABILITY.md", second as string, (second as string).replace("| 2 |", "| 97 |"));
    expect(r.out).toContain("rank 97 should be 2");
  });

  describe("decision package index (COORD5)", () => {
    // A copy of the real layer whose INDEX is rebuilt from the copy's own Open decisions (status not-started),
    // so the tests do not depend on how the PO has filled the real INDEX today. `edit` then adds one defect.
    function withIndex(edit: (rows: { id: string; owner: string }[]) => { rows: string[]; files?: Record<string, string | null> }) {
      const dir = mkdtempSync(join(tmpdir(), "agents-"));
      cpSync(REAL, dir, { recursive: true });
      const open = (parseTable(readFileSync(join(dir, "OPEN_DECISIONS.md"), "utf8"), "Open") as Record<string, string>[])
        .map((r) => ({ id: bare(r.ID), owner: bare(r.Owner) }));
      const { rows, files = {} } = edit(open);
      writeFileSync(join(dir, "decisions", "INDEX.md"), [
        "# Decision packages: index and order", "", "Prose.", "",
        "| Order | Tier | ID | Row owner | Question (short) | Blocks | CGR | Inputs | Preliminary route | Package status |",
        "|---|---|---|---|---|---|---|---|---|---|", ...rows, "", "**Not a decision row.**", "",
      ].join("\n"));
      for (const [f, text] of Object.entries(files)) {
        if (text === null) rmSync(join(dir, "decisions", f), { force: true });
        else writeFileSync(join(dir, "decisions", f), text);
      }
      return run(dir);
    }
    const row = (id: string, owner: string, cell = "not-started") => `| 1 | 4 | ${id} | ${owner} | q | – | – | E | r | ${cell} |`;
    const human = (o: { owner: string }) => ["owner", "legal", "clinical"].includes(o.owner);

    it("a rebuilt, complete INDEX is valid", () => {
      expect(withIndex((open) => ({ rows: open.map((d) => row(d.id, d.owner)) })).code).toBe(0);
    });

    it("every open decision owned by owner, legal or clinical needs an INDEX row", () => {
      const r = withIndex((open) => {
        const missing = open.find(human)!;
        return { rows: open.filter((d) => d !== missing).map((d) => row(d.id, d.owner)) };
      });
      expect(r.code).toBe(1);
      expect(r.out).toMatch(/is open but has no INDEX row/);
    });

    it("the package status must be one of the DECISION_PACKAGES.md values", () => {
      const r = withIndex((open) => ({ rows: open.map((d, i) => row(d.id, d.owner, i === 0 ? "[ready](X.md)" : "not-started")) }));
      expect(r.code).toBe(1);
      expect(r.out).toContain('package status "ready" must be one of');
    });

    it("awaiting-approval and po-decided need the package file", () => {
      for (const status of ["awaiting-approval: clinical", "po-decided"]) {
        const r = withIndex((open) => {
          const d = open.find(human)!;
          return { rows: open.map((x) => row(x.id, x.owner, x === d ? `[${status}](${d.id}.md)` : "not-started")), files: { [`${d.id}.md`]: null } };
        });
        expect(r.code).toBe(1);
        expect(r.out).toContain(`requires decisions/`);
      }
    });

    it("an INDEX ID that is neither open nor decided is reported", () => {
      const r = withIndex((open) => ({ rows: [...open.map((d) => row(d.id, d.owner)), row("D-404", "owner")] }));
      expect(r.code).toBe(1);
      expect(r.out).toContain("D-404 is neither in Open nor in Decided");
    });

    it("negative: po-decided while still in Open is a warning, not an error", () => {
      const r = withIndex((open) => {
        const d = open.find(human)!;
        return { rows: open.map((x) => row(x.id, x.owner, x === d ? `[po-decided](${d.id}.md) (2026-10-24)` : "not-started")), files: { [`${d.id}.md`]: "# package\n" } };
      });
      expect(r.code).toBe(0);
      expect(r.out).toMatch(/package is po-decided but the row is still in Open/);
    });
  });
});
