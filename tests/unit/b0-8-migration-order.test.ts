import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { MIGRATION_NAME, checkMigrationOrder } from "../../scripts/migration-order.mjs";

// B0-8 (ADR-177, PRODUCT_BLOCKS.md §4): migrations must run in the same order on an empty database
// (`supabase db reset`: every file in version order) and on an existing one (only the files it has not applied yet,
// appended after the ones it has). That holds exactly when a change only appends: every migration it adds has a
// version above the highest one already on the base, and no migration on the base is removed, renamed or edited.
// A late-merged low number (0106 merged after 0122, PO merge #815) is reported.

const SCRIPT = join(process.cwd(), "scripts/migration-order.mjs");
const WORKFLOW = readFileSync(join(process.cwd(), ".github/workflows/ci.yml"), "utf8");

const m = (n: number, slug = "x") => `202610210001${String(n).padStart(2, "0")}_${slug}.sql`;
const f = (name: string, content = name) => ({ name, content });

describe("B0-8 checkMigrationOrder (pure)", () => {
  it("B0-8-1: a change that appends a higher version passes", () => {
    const base = [f(m(20)), f(m(21))];
    const r = checkMigrationOrder({ base, head: [...base, f(m(22))] });
    expect(r.ok).toBe(true);
    expect(r.errors).toEqual([]);
    expect(r.added).toEqual([m(22)]);
  });

  it("B0-8-2: no migration change at all passes", () => {
    const base = [f(m(20)), f(m(21))];
    expect(checkMigrationOrder({ base, head: base }).ok).toBe(true);
  });

  it("B0-8-3: a late-merged low number is reported with the base's highest version (0106 after 0122)", () => {
    const base = [f("20261021000105_a.sql"), f("20261021000122_b.sql")];
    const r = checkMigrationOrder({ base, head: [...base, f("20261021000106_late.sql")] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/20261021000106_late\.sql.*20261021000122/);
  });

  it("B0-8-4: a version equal to the base's highest is reported", () => {
    const base = [f(m(21, "a"))];
    const r = checkMigrationOrder({ base, head: [...base, f(m(21, "b"))] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/duplicate version 20261021000121/);
  });

  it("B0-8-5: two added files with the same version are reported", () => {
    const base = [f(m(20))];
    const r = checkMigrationOrder({ base, head: [...base, f(m(22, "a")), f(m(22, "b"))] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/duplicate version 20261021000122/);
  });

  it("B0-8-6: removing a migration that is on the base is reported", () => {
    const base = [f(m(20)), f(m(21))];
    const r = checkMigrationOrder({ base, head: [f(m(20))] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/20261021000121_x\.sql: on the base but removed or renamed/);
  });

  it("B0-8-7: renaming a migration on the base is reported (removed plus added)", () => {
    const base = [f(m(20)), f(m(21))];
    const r = checkMigrationOrder({ base, head: [f(m(20)), f(m(23, "renamed"), m(21))] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/20261021000121_x\.sql: on the base but removed or renamed/);
  });

  it("B0-8-8: editing a migration that is on the base is reported (an existing database never runs it again)", () => {
    const base = [f(m(20)), f(m(21), "create table a ();")];
    const r = checkMigrationOrder({ base, head: [f(m(20)), f(m(21), "create table b ();")] });
    expect(r.ok).toBe(false);
    expect(r.errors.join("\n")).toMatch(/20261021000121_x\.sql: changed after it reached the base/);
  });

  it.each(["0123_short.sql", "20261021000123-dash.sql", "20261021000123_Upper.sql", "20261021000123_x.txt", "20261021000123.sql"])(
    "B0-8-9: a file name the CLI would not read as <14-digit version>_<name>.sql is reported: %s",
    (name) => {
      const base = [f(m(20))];
      const r = checkMigrationOrder({ base, head: [...base, f(name)] });
      expect(r.ok).toBe(false);
      expect(r.errors.join("\n")).toContain(name);
    },
  );

  it("B0-8-10: an empty base (first migration) passes and the order is ascending", () => {
    const r = checkMigrationOrder({ base: [], head: [f(m(2)), f(m(1))] });
    expect(r.ok).toBe(true);
    expect(r.added).toEqual([m(1), m(2)]);
  });

  it("the name pattern is <14 digits>_<lowercase slug>.sql", () => {
    expect(MIGRATION_NAME.test("20261021000122_qual1_3_plan2_series_asks_the_check.sql")).toBe(true);
    expect(MIGRATION_NAME.test("2026102100012_x.sql")).toBe(false);
  });
});

describe("B0-8 the repository's migrations", () => {
  it("every file in supabase/migrations has a valid name and a unique version", () => {
    const names = readdirSync(join(process.cwd(), "supabase/migrations"));
    expect(names.length).toBeGreaterThan(0);
    const bad = names.filter((n) => !MIGRATION_NAME.test(n));
    expect(bad).toEqual([]);
    const versions = names.map((n) => n.slice(0, 14));
    expect(new Set(versions).size).toBe(versions.length);
  });
});

function git(cwd: string, ...args: string[]) {
  return execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function repoWith(files: Record<string, string>) {
  const dir = mkdtempSync(join(tmpdir(), "b0-8-"));
  git(dir, "init", "-q", "-b", "main");
  git(dir, "config", "user.email", "ci@example.invalid");
  git(dir, "config", "user.name", "ci");
  mkdirSync(join(dir, "supabase/migrations"), { recursive: true });
  for (const [n, c] of Object.entries(files)) writeFileSync(join(dir, "supabase/migrations", n), c);
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "-m", "base");
  return dir;
}

function run(dir: string, ...args: string[]) {
  return spawnSync("node", [SCRIPT, ...args], { cwd: dir, encoding: "utf8", env: { ...process.env, MIGRATION_BASE_REF: "HEAD^1" } });
}

describe("B0-8 CLI against a real git history", () => {
  it("passes when the head commit appends a higher version", () => {
    const dir = repoWith({ [m(20)]: "a", [m(21)]: "b" });
    try {
      writeFileSync(join(dir, "supabase/migrations", m(22)), "c");
      git(dir, "add", "-A");
      git(dir, "commit", "-q", "-m", "append");
      const r = run(dir);
      expect(r.status).toBe(0);
      expect(r.stdout).toMatch(/migration-order.*ok/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("fails with an error annotation when the head commit inserts a lower version", () => {
    const dir = repoWith({ [m(20)]: "a", [m(22)]: "b" });
    try {
      writeFileSync(join(dir, "supabase/migrations", m(21, "late")), "c");
      git(dir, "add", "-A");
      git(dir, "commit", "-q", "-m", "late");
      const r = run(dir);
      expect(r.status).toBe(1);
      expect(r.stdout).toMatch(/::error title=migration-order::.*20261021000121_late\.sql/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("fails closed when the base revision does not resolve", () => {
    const dir = repoWith({ [m(20)]: "a" });
    try {
      const r = run(dir); // only one commit: HEAD^1 does not exist
      expect(r.status).toBe(1);
      expect(r.stdout).toMatch(/::error title=migration-order::.*base/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("--history lists every first-parent step that inserted a lower version, and exits 0", () => {
    const dir = repoWith({ [m(20)]: "a", [m(22)]: "b" });
    try {
      writeFileSync(join(dir, "supabase/migrations", m(21, "late")), "c");
      git(dir, "add", "-A");
      git(dir, "commit", "-q", "-m", "late");
      const r = spawnSync("node", [SCRIPT, "--history", "HEAD"], { cwd: dir, encoding: "utf8" });
      expect(r.status).toBe(0);
      expect(r.stdout).toMatch(/20261021000121_late\.sql.*20261021000122/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("B0-8 wiring in CI", () => {
  it("the app job runs the migration-order check against the merge commit's base parent", () => {
    const app = WORKFLOW.slice(WORKFLOW.indexOf("\n  app:"), WORKFLOW.indexOf("\n  db:"));
    expect(app).toContain("scripts/ci-step.sh migration-order node scripts/migration-order.mjs");
    expect(app).toMatch(/MIGRATION_BASE_REF: HEAD\^1/);
    expect(app).toMatch(/fetch-depth: 0/);
  });
});
