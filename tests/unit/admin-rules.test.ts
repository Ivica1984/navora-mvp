import { describe, expect, it } from "vitest";
import { ADMIN_MESSAGES, allowedPriorities, changedLabel, checkRuleInput, isValidEmail, readRemovalResult, releasedNotice } from "@/features/admin/rules";

// ADM1: client-side mirror of the safe ranges in private.exception_rule_range (migration 0025).
describe("admin rules (ADM1)", () => {
  const p1Safety = { default_priority: "P1", default_amount: 24, default_escalate: null, max_amount: 24, max_escalate: null };
  const p2 = { default_priority: "P2", default_amount: 24, default_escalate: null, max_amount: 48, max_escalate: null };
  const serious = { default_priority: "P2", default_amount: null, default_escalate: 4, max_amount: null, max_escalate: 4 };

  it("never offers a priority below the platform default", () => {
    expect(allowedPriorities("P1")).toEqual(["P1"]);
    expect(allowedPriorities("P2")).toEqual(["P1", "P2"]);
    expect(allowedPriorities("P3")).toEqual(["P1", "P2", "P3"]);
  });

  it("keeps safety alerts no later than the default", () => {
    expect(checkRuleInput(p1Safety, "P1", 12, null)).toBeNull();
    expect(checkRuleInput(p1Safety, "P1", 48, null)).toContain("0 und 24");
    expect(checkRuleInput(p1Safety, "P2", 24, null)).not.toBeNull();
  });

  it("allows other thresholds up to twice the default", () => {
    expect(checkRuleInput(p2, "P2", 48, null)).toBeNull();
    expect(checkRuleInput(p2, "P2", 49, null)).not.toBeNull();
    expect(checkRuleInput(p2, "P2", 1.5, null)).not.toBeNull();
  });

  it("escalation never later; no escalation where the default has none", () => {
    expect(checkRuleInput(serious, "P2", null, 2)).toBeNull();
    expect(checkRuleInput(serious, "P2", null, 8)).toContain("Eskalation");
    expect(checkRuleInput(p2, "P2", 24, 4)).not.toBeNull();
  });

  it("labels who changed a setting and when", () => {
    expect(changedLabel(true, null, null)).toBe("Standard");
    expect(changedLabel(false, "Anna", "2026-10-22T12:05:00Z")).toMatch(/^geändert von Anna am /);
  });

  it("checks e-mail shape", () => {
    expect(isValidEmail("a@b.ch")).toBe(true);
    expect(isValidEmail("kein-email")).toBe(false);
  });
});

// ADM1 changes: removing a member releases her future planned visits (migration 0036).
describe("member removal releases visits (ADM1 changes)", () => {
  it("reads the command result and the number released", () => {
    expect(readRemovalResult({ result: "ok", released: 3 })).toEqual({ code: "ok", released: 3 });
    expect(readRemovalResult({ result: "duplicate" })).toEqual({ code: "duplicate", released: 0 });
    expect(readRemovalResult({ result: "has_cases" })).toEqual({ code: "has_cases", released: 0 });
    expect(readRemovalResult({ result: "has_visit_in_progress" })).toEqual({ code: "has_visit_in_progress", released: 0 });
    expect(readRemovalResult({ result: "ok", released: -1 })).toEqual({ code: "ok", released: 0 });
    expect(readRemovalResult(null)).toEqual({ code: "failed", released: 0 });
    expect(readRemovalResult("ok")).toEqual({ code: "failed", released: 0 });
  });

  it("explains a refusal while a visit is in progress (CGR-10)", () => {
    expect(ADMIN_MESSAGES.has_visit_in_progress).toMatch(/Einsatz/);
  });

  it("explains a refusal while a report she owes is missing or unsigned (CGR-18)", () => {
    expect(readRemovalResult({ result: "has_unsigned_reports" })).toEqual({ code: "has_unsigned_reports", released: 0 });
    expect(ADMIN_MESSAGES.has_unsigned_reports).toMatch(/Bericht/);
    expect(ADMIN_MESSAGES.has_unsigned_reports).toMatch(/unterschreiben/);
  });

  it("says how many visits are now open in the team", () => {
    expect(releasedNotice(3)).toBe("Entfernt. 3 Einsätze sind jetzt offen im Team.");
    expect(releasedNotice(1)).toBe("Entfernt. 1 Einsatz ist jetzt offen im Team.");
    expect(releasedNotice(0)).toBe("Entfernt. Keine geplanten Einsätze betroffen.");
  });
});
