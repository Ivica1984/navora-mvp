import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  approvalRecordErrors,
  approvalRecordMissing,
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

// COND1-10 = DOOR1-16 (CGR-68, interim part; ADR-097): an APPROVED register row names an approval record
// clinical/approvals/CR-nnn.md with the approver's role, the G-1 reference and the date. Synthetic rows and records only.
const HEADER = [
  "## Rules",
  "",
  "| ID | Rule (as implemented) | Where | Cited source | Set by | Decision | Status | Architect note |",
  "|---|---|---|---|---|---|---|---|",
];
const RECORD = ["# CR-900 approval (synthetic)", "", "- **Approver role:** Clinical Owner (synthetic)",
  "- **G-1 reference:** G-1 (synthetic)", "- **Date:** 2027-01-01"].join("\n");
const register = (note: string) =>
  [...HEADER, "| CR-001 | synthetic rule | 0000 | – | eng | – | UNVALIDATED | |",
   `| CR-900 | synthetic approved rule | 0000 | – | clinical | D-99 | APPROVED | ${note} |`].join("\n");

describe("DOOR1-16 approval record for an APPROVED register row", () => {
  it("an APPROVED row without a record fails", () => {
    expect(approvalRecordErrors(register("synthetic"), () => null)[0]).toContain("CR-900 is APPROVED but names no approval record");
    expect(approvalRecordErrors(register("[record](approvals/CR-900.md)"), () => null)[0]).toContain("approvals/CR-900.md: missing");
  });

  it("with a complete record it passes", () => {
    expect(approvalRecordErrors(register("[record](approvals/CR-900.md)"), (p) => (p === "approvals/CR-900.md" ? RECORD : null))).toEqual([]);
  });

  it("a record without role, G-1 reference or date fails, naming what is missing", () => {
    expect(approvalRecordMissing(RECORD)).toEqual([]);
    expect(approvalRecordMissing("- Approver role: Clinical Owner\n- G-1 reference: pending\n- Date: 1.1.2027"))
      .toEqual(["G-1 reference", "Date (YYYY-MM-DD)"]);
    expect(approvalRecordMissing("")).toEqual(["Approver role", "G-1 reference", "Date (YYYY-MM-DD)"]);
    const errors = approvalRecordErrors(register("approvals/CR-900.md"), () => "- Date: 2027-01-01");
    expect(errors).toEqual(["clinical/approvals/CR-900.md: names no Approver role, no G-1 reference (DOOR1-16)"]);
  });

  it("rows that are not APPROVED need no record", () => {
    expect(approvalRecordErrors([...HEADER, "| CR-001 | synthetic rule | 0000 | – | eng | – | PROVISIONAL | |"].join("\n"), () => null)).toEqual([]);
    expect(approvalRecordErrors(null, () => null)).toEqual([]);
  });

  it("today's register (no APPROVED row) passes, and agents-check fails on an APPROVED row without a record", () => {
    const real = readFileSync(join(process.cwd(), "docs", "agents", "clinical", "CLINICAL_RULE_REGISTER.md"), "utf8");
    expect([...registerStatus(real).values()]).not.toContain("APPROVED");
    expect(approvalRecordErrors(real, () => null)).toEqual([]);

    const script = join(process.cwd(), "scripts", "agents-check.mjs");
    const dir = mkdtempSync(join(tmpdir(), "clin-"));
    writeFileSync(join(dir, "CLINICAL_RULE_REGISTER.md"), register("[record](approvals/CR-900.md)"));
    let code = 0;
    let out = "";
    try {
      execFileSync(process.execPath, [script], { env: { ...process.env, CLINICAL_DIR: dir }, encoding: "utf8", stdio: "pipe" });
    } catch (e) {
      const err = e as { status: number; stderr: string };
      code = err.status;
      out = err.stderr;
    }
    expect(code).toBe(1);
    expect(out).toContain("clinical/approvals/CR-900.md: missing; CR-900 is APPROVED (DOOR1-16)");
    mkdirSync(join(dir, "approvals"));
    writeFileSync(join(dir, "approvals", "CR-900.md"), RECORD);
    expect(execFileSync(process.execPath, [script], { env: { ...process.env, CLINICAL_DIR: dir }, encoding: "utf8" })).toContain("agents: ok");
  });
});
