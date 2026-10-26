import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  clinicalCategoryErrors,
  clinicalCategoryInserts,
  registerStatus,
} from "../../scripts/agents-coordination/clinical-categories.mjs";

// DOOR1-14 (CGR-61, migration 0080, ADR-093): a migration that inserts a clinical safety-alert category needs an
// APPROVED Clinical Rule Register row in approval_ref. Synthetic SQL and register rows only.
const REGISTER = [
  "## Rules",
  "",
  "| ID | Rule (as implemented) | Where | Cited source | Set by | Decision | Status | Architect note |",
  "|---|---|---|---|---|---|---|---|",
  "| CR-001 | synthetic rule | 0000 | – | eng | – | UNVALIDATED | |",
  "| CR-900 | synthetic approved rule | 0000 | – | clinical | D-99 | APPROVED | synthetic |",
].join("\n");

const insert = (cls: string, ref: string | null) =>
  `insert into public.safety_alert_categories (code, version, label, class, active_from, source${ref === null ? "" : ", approval_ref"})\n` +
  `values ('syn_cat', 1, 'Synthetisch, mit Komma', '${cls}', date '2027-01-01', 'Quelle (it''s synthetic)'${ref === null ? "" : `, '${ref}'`})\n` +
  "on conflict (code, version) do nothing;";

describe("DOOR1-14 clinical category check", () => {
  it("reads the register status by ID", () => {
    expect(registerStatus(REGISTER).get("CR-001")).toBe("UNVALIDATED");
    expect(registerStatus(REGISTER).get("CR-900")).toBe("APPROVED");
  });

  it("finds clinical inserts with their approval reference, and ignores organisational ones", () => {
    expect(clinicalCategoryInserts(insert("clinical", "CR-900"))).toEqual([{ code: "syn_cat", approvalRef: "CR-900", parsed: true }]);
    expect(clinicalCategoryInserts(insert("organisational", null))).toEqual([]);
    expect(clinicalCategoryInserts("-- a comment: insert into safety_alert_categories 'clinical';\nselect 1;")).toEqual([]);
  });

  it("accepts an APPROVED register row", () => {
    expect(clinicalCategoryErrors([{ name: "0999.sql", sql: insert("clinical", "CR-900") }], REGISTER)).toEqual([]);
  });

  it.each([
    ["D-17", "must name a register row CR-nnn"],
    ["pending", "must name a register row CR-nnn"],
    ["#396", "must name a register row CR-nnn"],
    ["CR-001", 'CR-001 is "UNVALIDATED", needs APPROVED'],
    ["CR-404", "CR-404 is not in the register"],
  ])("refuses approval_ref %s", (ref, message) => {
    const errors = clinicalCategoryErrors([{ name: "0999.sql", sql: insert("clinical", ref) }], REGISTER);
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain(message);
  });

  it("refuses a clinical insert without approval_ref and an unreadable one (fail closed)", () => {
    expect(clinicalCategoryErrors([{ name: "a.sql", sql: insert("clinical", null) }], REGISTER)[0]).toContain("CR-nnn");
    const select = "insert into public.safety_alert_categories select * from x where class = 'clinical';";
    expect(clinicalCategoryErrors([{ name: "b.sql", sql: select }], REGISTER)[0]).toContain("could not be read");
  });

  it("an organisational row needs no reference", () => {
    expect(clinicalCategoryErrors([{ name: "c.sql", sql: insert("organisational", null) }], REGISTER)).toEqual([]);
  });

  it("agents-check fails on such a migration and passes on the repository's migrations", () => {
    const script = join(process.cwd(), "scripts", "agents-check.mjs");
    const dir = mkdtempSync(join(tmpdir(), "mig-"));
    writeFileSync(join(dir, "0999_syn.sql"), insert("clinical", "D-17"));
    let code = 0;
    let out = "";
    try {
      execFileSync(process.execPath, [script], { env: { ...process.env, MIGRATIONS_DIR: dir }, encoding: "utf8", stdio: "pipe" });
    } catch (e) {
      const err = e as { status: number; stderr: string };
      code = err.status;
      out = err.stderr;
    }
    expect(code).toBe(1);
    expect(out).toContain("0999_syn.sql: clinical safety-alert category syn_cat");
    expect(execFileSync(process.execPath, [script], { encoding: "utf8" })).toContain("agents: ok");
  });
});
