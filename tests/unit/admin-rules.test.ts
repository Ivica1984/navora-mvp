import { describe, expect, it } from "vitest";
import { allowedPriorities, changedLabel, checkRuleInput, isValidEmail } from "@/features/admin/rules";

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
