import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { DOCS_ONLY_PREFIXES, classify } from "../../scripts/ci-scope.mjs";

// CI2 (ADR-167): on a pull request that changes only files under docs/, the heavy jobs db, e2e and ui-screenshots
// keep their names and succeed only after verifying the diff; every other change, and every push, runs them in full.

const SCRIPT = join(process.cwd(), "scripts/ci-scope.mjs");
const WORKFLOW = readFileSync(join(process.cwd(), ".github/workflows/ci.yml"), "utf8");

describe("CI2 classify (pure)", () => {
  it("the docs-only path list is exactly docs/", () => {
    expect(DOCS_ONLY_PREFIXES).toEqual(["docs/"]);
  });

  it("CI2-2: a pull request that changes only docs/ files takes the verified fast path", () => {
    const r = classify({ event: "pull_request", files: ["docs/agents/JOURNAL.md", "docs/product/PRODUCT_BLOCKS.md"] });
    expect(r.full).toBe(false);
    expect(r.reason).toMatch(/2 files.*docs\//);
  });

  it.each([
    "src/app/page.tsx",
    "supabase/migrations/0200_x.sql",
    "tests/unit/x.test.ts",
    "tests/e2e/x.spec.ts",
    "scripts/agents-check.mjs",
    ".github/workflows/ci.yml",
    "package.json",
    "package-lock.json",
    "README.md",
    "ARCHITECTURE.md",
    "playwright.config.ts",
  ])("CI2-3: docs plus %s runs every full job", (path) => {
    const r = classify({ event: "pull_request", files: ["docs/agents/JOURNAL.md", path] });
    expect(r.full).toBe(true);
    expect(r.reason).toContain(path);
  });

  it("CI2-5: every push (recovery/main, main) runs in full, even for docs only", () => {
    expect(classify({ event: "push", files: ["docs/agents/JOURNAL.md"] }).full).toBe(true);
  });

  it("fails closed: an empty or unknown diff runs in full", () => {
    expect(classify({ event: "pull_request", files: [] }).full).toBe(true);
    expect(classify({ event: "pull_request", files: undefined }).full).toBe(true);
    expect(classify({ event: "workflow_dispatch", files: ["docs/a.md"] }).full).toBe(true);
  });

  it("a path that only looks like docs/ is not docs (prefix match on the whole first segment)", () => {
    for (const p of ["docs", "docsx/a.md", "./docs/a.md", "docs/../src/a.ts", "src/docs/a.md", " docs/a.md"]) {
      expect(classify({ event: "pull_request", files: [p] }).full).toBe(true);
    }
  });
});

// The CLI against a real git repository: a merge commit like the one actions/checkout makes for pull_request.
function repo(): string {
  const dir = mkdtempSync(join(tmpdir(), "ci2-"));
  const git = (...a: string[]) => execFileSync("git", ["-C", dir, ...a], { encoding: "utf8" });
  git("init", "-q", "-b", "base");
  git("config", "user.email", "ci2@navora.test");
  git("config", "user.name", "ci2");
  writeFileSync(join(dir, "a.txt"), "a");
  git("add", ".");
  git("commit", "-qm", "base");
  return dir;
}

function prMerge(dir: string, files: Record<string, string>, renameFrom?: string): void {
  const git = (...a: string[]) => execFileSync("git", ["-C", dir, ...a], { encoding: "utf8" });
  git("checkout", "-qb", "pr");
  for (const p of Object.keys(files)) execFileSync("mkdir", ["-p", join(dir, p, "..")]);
  if (renameFrom) git("mv", renameFrom, Object.keys(files)[0]);
  for (const [p, c] of Object.entries(files)) writeFileSync(join(dir, p), c);
  git("add", "-A");
  git("commit", "-qm", "pr");
  git("checkout", "-q", "base");
  git("merge", "-q", "--no-ff", "-m", "merge", "pr");
}

function cli(dir: string, event: string): { out: string; output: string; code: number } {
  const outFile = join(mkdtempSync(join(tmpdir(), "ci2-out-")), "out");
  writeFileSync(outFile, "");
  try {
    const out = execFileSync("node", [SCRIPT], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, CI_EVENT: event, GITHUB_OUTPUT: outFile },
    });
    return { out, output: readFileSync(outFile, "utf8"), code: 0 };
  } catch (e) {
    const err = e as { stdout?: string; status?: number };
    return { out: err.stdout ?? "", output: readFileSync(outFile, "utf8"), code: err.status ?? 1 };
  }
}

describe("CI2 ci-scope.mjs (CLI)", () => {
  it("docs-only merge commit: full=false and a notice", () => {
    const d = repo();
    prMerge(d, { "docs/x.md": "x" });
    const r = cli(d, "pull_request");
    expect(r.code).toBe(0);
    expect(r.output).toContain("full=false");
    expect(r.out).toContain("::notice title=ci-scope::");
  });

  it("docs plus one src file: full=true", () => {
    const d = repo();
    prMerge(d, { "docs/x.md": "x", "src/y.ts": "y" });
    const r = cli(d, "pull_request");
    expect(r.code).toBe(0);
    expect(r.output).toContain("full=true");
  });

  it("a rename out of src/ into docs/ counts the old path too (no-renames): full=true", () => {
    const d = repo();
    execFileSync("mkdir", ["-p", join(d, "src")]);
    writeFileSync(join(d, "src/z.ts"), "z");
    execFileSync("git", ["-C", d, "add", "."]);
    execFileSync("git", ["-C", d, "commit", "-qm", "src"]);
    prMerge(d, { "docs/z.ts": "z" }, "src/z.ts");
    expect(cli(d, "pull_request").output).toContain("full=true");
  });

  it("push: full=true without looking at the diff", () => {
    const d = repo();
    expect(cli(d, "push").output).toContain("full=true");
  });

  it("no GITHUB_OUTPUT: fails (otherwise every gated step would be skipped unchecked)", () => {
    const d = repo();
    prMerge(d, { "docs/x.md": "x" });
    const env = { ...process.env, CI_EVENT: "pull_request" };
    delete env.GITHUB_OUTPUT;
    expect(() => execFileSync("node", [SCRIPT], { cwd: d, env, stdio: "pipe" })).toThrow();
  });

  it("pull_request but HEAD is not a merge commit: fails (no silent fast path)", () => {
    const d = repo();
    const r = cli(d, "pull_request");
    expect(r.code).not.toBe(0);
    expect(r.output).not.toContain("full=false");
  });
});

// The workflow wiring: names unchanged, push stays full, every heavy step is gated, app untouched.
function jobBlock(id: string): string {
  const start = WORKFLOW.indexOf(`\n  ${id}:\n`);
  expect(start, `job ${id}`).toBeGreaterThan(-1);
  const rest = WORKFLOW.slice(start + 1);
  const next = rest.slice(1).search(/\n {2}[a-z][a-z0-9-]*:\n/);
  return next === -1 ? rest : rest.slice(0, next + 1);
}

function steps(block: string): string[] {
  return block.split(/\n {6}- /).slice(1);
}

describe("CI2 ci.yml wiring", () => {
  it("CI2-2: the four required check names are unchanged", () => {
    for (const n of [
      "name: app (lint · typecheck · unit · audit · build)",
      "name: db (migrations · seed · pgTAP)",
      "name: e2e (auth · protected routes · Playwright)",
      "name: ui-screenshots (390 · 1440 · every role)",
    ]) {
      expect(WORKFLOW).toContain(n);
    }
  });

  it("CI2-5: triggers unchanged: every pull request, every push to main and recovery/main, no paths filter", () => {
    expect(WORKFLOW).toMatch(/\non:\n {2}pull_request:\n {2}push:\n {4}branches: \[main, recovery\/main\]\n/);
    expect(WORKFLOW).not.toMatch(/\n\s+paths(-ignore)?:/);
  });

  it("B0-1 / CI2-5: superseded pull-request runs are cancelled, push runs (merge commits) never", () => {
    const m = /\nconcurrency:\n((?: {2}.*\n)+)/.exec(WORKFLOW);
    expect(m).not.toBe(null);
    const block = (m as RegExpExecArray)[1];
    expect(block).toContain("  group: ci-${{ github.event_name == 'pull_request' && github.ref || github.sha }}\n");
    expect(block).toContain("  cancel-in-progress: ${{ github.event_name == 'pull_request' }}\n");
  });

  it("no job is skipped as a whole (a skipped job would report success unchecked)", () => {
    for (const id of ["app", "db", "e2e", "ui-screenshots"]) {
      const head = jobBlock(id).split("\n    steps:")[0];
      expect(head, id).not.toMatch(/\n {4}if:/);
    }
  });

  it("CI2-4: the app job (agents-check, lint, typecheck, unit, audit, build) has no scope gate", () => {
    const app = jobBlock("app");
    expect(app).toContain("node scripts/agents-check.mjs");
    expect(app).not.toContain("steps.scope");
  });

  it.each(["db", "e2e", "ui-screenshots"])("%s: checkout, then the scope step, then every step gated on full", (id) => {
    const s = steps(jobBlock(id));
    expect(s[0]).toMatch(/^uses: actions\/checkout@/);
    expect(s[1]).toMatch(/^name: CI2 scope/);
    expect(s[1]).toContain("id: scope");
    expect(s[1]).toContain("node scripts/ci-scope.mjs");
    expect(s[1]).not.toMatch(/\n\s+if:/);
    for (const step of s.slice(2)) {
      const ifLine = /\n\s+if: (.*)/.exec(step)?.[1] ?? "";
      const gated =
        ifLine.includes("steps.scope.outputs.full == 'true'") ||
        // db: the detect step is gated, every later db step needs its output
        (id === "db" && ifLine.includes("steps.detect.outputs.present == 'true'")) ||
        // ui-screenshots: the UI scope step is gated, every later step needs its output
        (id === "ui-screenshots" && ifLine.includes("steps.ui.outputs.run == 'true'"));
      expect(gated, `${id} step not gated: ${step.split("\n")[0]}`).toBe(true);
    }
  });

  it("db: the detect step itself is gated on full", () => {
    const detect = steps(jobBlock("db")).find((s) => s.startsWith("name: Detect Supabase project"));
    expect(detect).toContain("if: steps.scope.outputs.full == 'true'");
  });

  it("ui-screenshots: the UI scope step is gated on full", () => {
    const ui = steps(jobBlock("ui-screenshots")).find((s) => s.includes("id: ui"));
    expect(ui).toContain("if: steps.scope.outputs.full == 'true'");
  });
});
