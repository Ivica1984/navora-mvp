import { execFileSync, spawnSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  addedLines, freezeFindings, frozenMarkerErrors, JOURNAL_ERROR_FROM, journalEntries, rowLines,
} from "../../scripts/agents-coordination/freeze.mjs";

// COORD6 (ADR-110): frozen packages stay frozen. Synthetic coordination texts only (no care data).

const HEADER = "| Order | Tier | ID | Row owner | Question (short) | Blocks | CGR | Inputs | Preliminary route | Package status |\n|---|---|---|---|---|---|---|---|---|---|";
const idxRow = (id: string, cell: string) => `| 1 | 4 | ${id} | owner | q | – | – | E | r | ${cell} |`;
const index = (...rows: string[]) => `# Decision packages\n\nProse.\n\n${HEADER}\n${rows.join("\n")}\n\n**Not a decision row.**\n`;
const FROZEN = "[awaiting-approval: owner](D-90.md) · frozen since 2026-10-27 14:45 (ask)";
const decisions = (open: string[], decided: string[] = []) => `# Open decisions

## Open

| ID | Owner | Kind | Question | Recommendation | Blocks | Opened |
|---|---|---|---|---|---|---|
${open.join("\n")}

## Decided

| ID | Owner | Answer | Date |
|---|---|---|---|
${decided.join("\n")}
`;
const openRow = (id: string, q = "question") => `| ${id} | owner | product | ${q} | rec | – | 2026-10-24 |`;
const journal = (...entries: string[]) => `# Agent journal\n\nNewest first.\n\n---\n\n${entries.join("\n\n---\n\n")}\n`;
const entry = (heading: string, body: string) => `## ${heading}\n\n- ${body}`;
const PKG = "# D-90 package\n\n## Owner approval required?\n\nYes.\n";
const BEFORE = new Date("2026-11-01T10:00:00Z");

function base(over: Partial<{ index: string; decisions: string; journal: string; packages: Record<string, string | null> }> = {}) {
  return {
    index: index(idxRow("D-90", FROZEN), idxRow("D-91", "[inputs-requested](D-91.md) (open)")),
    decisions: decisions([openRow("D-90"), openRow("D-91")]),
    journal: journal(entry("2026-10-28 10:00 CET · po (Product Owner)", "D-90 no new evidence (old entry, kept).")),
    packages: { "D-90": PKG },
    ...over,
  };
}

describe("COORD6-1 marking", () => {
  it("an awaiting-approval row without the marker is an error, with it ok", () => {
    const text = index(
      idxRow("D-90", FROZEN),
      idxRow("D-92", "[**awaiting-approval: clinical**](D-92.md) (2026-10-24; no marker)"),
      idxRow("D-93", "[po-decided](D-93.md) (not frozen, no marker needed)"),
    );
    const errors = frozenMarkerErrors(text);
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain("D-92");
    expect(errors[0]).toContain("frozen since YYYY-MM-DD HH:MM");
  });

  it("the marker must follow the status link directly", () => {
    const errors = frozenMarkerErrors(index(idxRow("D-90", "[awaiting-approval: owner](D-90.md) (ask) · frozen since 2026-10-27 14:45")));
    expect(errors).toHaveLength(1);
  });
});

describe("COORD6-2 unfreeze line in the package file", () => {
  it("(a) a changed frozen package without the line → error naming the ID", () => {
    const b = base();
    const h = { ...b, packages: { "D-90": `${PKG}\nAddendum: re-checked.\n` } };
    const { errors } = freezeFindings({ base: b, head: h, now: BEFORE });
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain("decisions/D-90.md: D-90 is frozen");
  });

  it("(b) with an added Unfreeze line → ok", () => {
    const b = base();
    const h = { ...b, packages: { "D-90": `${PKG}\nUnfreeze: 3 CGR-86\n\nAddendum.\n` } };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });

  it("an Unfreeze line already on the base does not unfreeze a new change", () => {
    const b = base({ packages: { "D-90": `${PKG}\nUnfreeze: 1 owner answered\n` } });
    const h = { ...b, packages: { "D-90": `${PKG}\nUnfreeze: 1 owner answered\nMore.\n` } };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toHaveLength(1);
  });

  it("a malformed line (trigger 6, no reference) does not count", () => {
    const b = base();
    for (const line of ["Unfreeze: 6 x", "Unfreeze: 3", "unfreeze: 3 CGR-86", "**Unfreeze:** 3 CGR-86"]) {
      const h = { ...b, packages: { "D-90": `${PKG}\n${line}\n` } };
      expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors, line).toHaveLength(1);
    }
  });

  it("(c) a package that is not awaiting-approval on the base → ok without the line", () => {
    const b = base({ packages: { "D-90": PKG, "D-91": "draft" } });
    const h = { ...b, packages: { "D-90": PKG, "D-91": "draft, extended" } };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });

  it("(d) a package newly escalated in the same diff → ok", () => {
    const b = base();
    const h = {
      ...b,
      index: index(idxRow("D-90", FROZEN), idxRow("D-91", "[awaiting-approval: owner](D-91.md) · frozen since 2026-10-28 15:30 (ask)")),
      packages: { "D-90": PKG, "D-91": "complete package" },
    };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });
});

describe("COORD6-3 rows", () => {
  it("INDEX row changed without the reference → error; with it → ok", () => {
    const b = base();
    const bad = { ...b, index: index(idxRow("D-90", `${FROZEN}; re-checked`), idxRow("D-91", "[inputs-requested](D-91.md) (open)")) };
    const r1 = freezeFindings({ base: b, head: bad, now: BEFORE });
    expect(r1.errors).toHaveLength(1);
    expect(r1.errors[0]).toMatch(/^decisions\/INDEX\.md: D-90/);
    const good = { ...b, index: index(idxRow("D-90", `${FROZEN}; Unfreeze: 2 D-11 answered`), idxRow("D-91", "[inputs-requested](D-91.md) (open)")) };
    expect(freezeFindings({ base: b, head: good, now: BEFORE }).errors).toEqual([]);
  });

  it("OPEN_DECISIONS.md Open row changed without the reference → error; with it → ok", () => {
    const b = base();
    const bad = { ...b, decisions: decisions([openRow("D-90", "question, reworded"), openRow("D-91")]) };
    const r1 = freezeFindings({ base: b, head: bad, now: BEFORE });
    expect(r1.errors).toHaveLength(1);
    expect(r1.errors[0]).toMatch(/^OPEN_DECISIONS\.md \(Open\): D-90/);
    const good = { ...b, decisions: decisions([openRow("D-90", "Unfreeze: 5 csa issue #593. question, reworded"), openRow("D-91")]) };
    expect(freezeFindings({ base: b, head: good, now: BEFORE }).errors).toEqual([]);
  });

  it("an Unfreeze line in the package file in the same diff satisfies the rows", () => {
    const b = base();
    const h = {
      ...b,
      decisions: decisions([openRow("D-90", "question, reworded"), openRow("D-91")]),
      index: index(idxRow("D-90", `${FROZEN}; changed`), idxRow("D-91", "[inputs-requested](D-91.md) (open)")),
      packages: { "D-90": `${PKG}\nUnfreeze: 4 PR #612 changes the Engineering impact\n` },
    };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });

  it("negative: rows of packages that are not frozen change freely", () => {
    const b = base();
    const h = { ...b, decisions: decisions([openRow("D-90"), openRow("D-91", "changed")]) };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });
});

describe("COORD6-4 journal", () => {
  const added = (body: string) => {
    const b = base();
    return { b, h: { ...b, journal: b.journal.replace("---\n\n", `---\n\n${entry("2026-10-28 16:00 CET · lca", body)}\n\n---\n\n`) } };
  };

  it("an added 'no new evidence' entry naming a frozen package warns before 2026-11-04 00:00 Europe/Zurich", () => {
    const { b, h } = added("D-90: No New Evidence since 14:56.");
    const r = freezeFindings({ base: b, head: h, now: new Date("2026-11-03T22:59:59Z") });
    expect(r.errors).toEqual([]);
    expect(r.warnings).toHaveLength(1);
    expect(r.warnings[0]).toContain("D-90");
  });

  it("... and is an error from then on", () => {
    const { b, h } = added("D-90: no new evidence.");
    const r = freezeFindings({ base: b, head: h, now: JOURNAL_ERROR_FROM });
    expect(r.warnings).toEqual([]);
    expect(r.errors).toHaveLength(1);
  });

  it("negative: old entries, other packages, and ID prefixes are not matched", () => {
    const now = JOURNAL_ERROR_FROM;
    // the base already holds an old D-90 "no new evidence" entry: unchanged, so nothing
    expect(freezeFindings({ base: base(), head: base(), now })).toEqual({ errors: [], warnings: [] });
    for (const body of ["D-91 no new evidence (not frozen).", "D-901 no new evidence.", "D-90 re-checked: trigger 3 CGR-86 (evidence)."]) {
      const { b, h } = added(body);
      expect(freezeFindings({ base: b, head: h, now }), body).toEqual({ errors: [], warnings: [] });
    }
  });
});

describe("COORD6-6 moving a package out of awaiting-approval", () => {
  it("to decided with an Unfreeze line → ok (trigger 1, the person answered)", () => {
    const b = base();
    const h = {
      ...b,
      index: index(idxRow("D-90", "[decided](D-90.md) (owner 2026-10-29: A)"), idxRow("D-91", "[inputs-requested](D-91.md) (open)")),
      decisions: decisions([openRow("D-91")], ["| D-90 | owner | A | 2026-10-29 |"]),
      packages: { "D-90": `${PKG}\nUnfreeze: 1 owner answered 2026-10-29 (issue #700)\n\n## Decision\n\nA.\n` },
    };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toEqual([]);
  });

  it("to decided without any Unfreeze line → errors for the package and both rows", () => {
    const b = base();
    const h = {
      ...b,
      index: index(idxRow("D-90", "[decided](D-90.md) (owner 2026-10-29: A)"), idxRow("D-91", "[inputs-requested](D-91.md) (open)")),
      decisions: decisions([openRow("D-91")], ["| D-90 | owner | A | 2026-10-29 |"]),
      packages: { "D-90": `${PKG}\n## Decision\n\nA.\n` },
    };
    expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors).toHaveLength(3);
  });

  it("for po-decided and inputs-requested, a reference in the rows alone is enough when the file is unchanged", () => {
    for (const status of ["po-decided", "inputs-requested"]) {
      const b = base();
      const h = {
        ...b,
        index: index(idxRow("D-90", `[${status}](D-90.md) (Unfreeze: 5 lca asked)`), idxRow("D-91", "[inputs-requested](D-91.md) (open)")),
        decisions: decisions([openRow("D-90", "Unfreeze: 5 lca asked. q"), openRow("D-91")]),
      };
      expect(freezeFindings({ base: b, head: h, now: BEFORE }).errors, status).toEqual([]);
    }
  });
});

describe("helpers", () => {
  it("rowLines, addedLines, journalEntries", () => {
    expect(rowLines(decisions([openRow("D-90")]), "Open").get("D-90")).toBe(openRow("D-90"));
    expect(rowLines(decisions([], ["| D-9 | owner | A | d |"]), "Open").size).toBe(0);
    expect(addedLines("a\nb\na", "a\nb\na\na\nc")).toEqual(["a", "c"]);
    expect(journalEntries(journal(entry("h1", "x"), entry("h2", "y"))).map((e) => e.heading)).toEqual(["## h1", "## h2"]);
  });
});

// COORD6-2 to -5 end to end: scripts/agents-check.mjs against a git repository holding a copy of the real layer.
describe("agents-check with a base revision (git)", () => {
  const SCRIPT = join(process.cwd(), "scripts", "agents-check.mjs");
  const REAL = join(process.cwd(), "docs", "agents");
  const git = (dir: string, ...args: string[]) =>
    execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, encoding: "utf8", stdio: "pipe" });
  // stdout and stderr together: the COORD6-5 skip warning goes to stderr.
  function run(env: Record<string, string>) {
    const r = spawnSync(process.execPath, [SCRIPT], { env: { ...process.env, ...env }, encoding: "utf8" });
    return { code: r.status, out: `${r.stdout}${r.stderr}` };
  }
  function repo() {
    const root = mkdtempSync(join(tmpdir(), "coord6-"));
    const dir = join(root, "docs", "agents");
    cpSync(REAL, dir, { recursive: true });
    git(root, "init", "-q");
    git(root, "add", "-A");
    git(root, "commit", "-q", "-m", "base");
    return { root, dir, rev: git(root, "rev-parse", "HEAD").trim() };
  }
  const frozenId = () => {
    const m = readFileSync(join(REAL, "decisions", "INDEX.md"), "utf8").match(/^\|[^|\n]*\|[^|\n]*\| ([A-Z]+-\d+) \|.*\[\**awaiting-approval: [a-z]+\**\]\(/m);
    expect(m, "the real INDEX needs one awaiting-approval row").toBeTruthy();
    return (m as RegExpMatchArray)[1];
  };

  it("an unchanged layer passes; a frozen package changed without Unfreeze fails, with it passes", () => {
    const { dir, rev } = repo();
    const env = { AGENTS_DIR: dir, AGENTS_BASE_REF: rev, AGENTS_NOW: "2026-11-01T10:00:00Z" };
    expect(run(env).code).toBe(0);
    const id = frozenId();
    const file = join(dir, "decisions", `${id}.md`);
    const text = readFileSync(file, "utf8");
    writeFileSync(file, `${text}\nAddendum without trigger.\n`);
    const bad = run(env);
    expect(bad.code).toBe(1);
    expect(bad.out).toContain(`decisions/${id}.md: ${id} is frozen`);
    writeFileSync(file, `${text}\nUnfreeze: 3 CGR-999 (synthetic test)\n`);
    expect(run(env).code).toBe(0);
  });

  it("COORD6-5: an unresolvable base skips checks 2 to 4 with one warning; check 1 still runs", () => {
    const { dir } = repo();
    const id = frozenId();
    const file = join(dir, "decisions", `${id}.md`);
    writeFileSync(file, `${readFileSync(file, "utf8")}\nAddendum without trigger.\n`);
    const r = run({ AGENTS_DIR: dir, AGENTS_BASE_REF: "origin/no-such-branch" });
    expect(r.code).toBe(0);
    expect(r.out.match(/COORD6 freeze checks \(2 to 4\) skipped/g)).toHaveLength(1);
    const idx = join(dir, "decisions", "INDEX.md");
    writeFileSync(idx, readFileSync(idx, "utf8").replace(/\) · frozen since \d{4}-\d{2}-\d{2} \d{2}:\d{2}/, ")"));
    const r1 = run({ AGENTS_DIR: dir, AGENTS_BASE_REF: "origin/no-such-branch" });
    expect(r1.code).toBe(1);
    expect(r1.out).toContain("COORD6-1");
  });

  it("COORD6-5: a folder outside git skips with a warning", () => {
    const dir = mkdtempSync(join(tmpdir(), "coord6-nogit-"));
    cpSync(REAL, dir, { recursive: true });
    const r = run({ AGENTS_DIR: dir });
    expect(r.code).toBe(0);
    expect(r.out).toContain("COORD6 freeze checks (2 to 4) skipped");
  });
});
