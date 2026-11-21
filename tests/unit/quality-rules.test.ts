import { describe, expect, it } from "vitest";
import { EVENT_STATUS_LABEL, HOLD_MEANING, NO_TYPES_NOTICE, SEVERITIES, SEVERITY_LABEL, isSerious, qualityRejectionMessage } from "@/features/quality/rules";

describe("QG1 quality rules", () => {
  it("severity uses the four existing values, each labelled", () => {
    expect([...SEVERITIES]).toEqual(["low", "medium", "high", "critical"]);
    for (const s of SEVERITIES) expect(SEVERITY_LABEL[s]).toBeTruthy();
  });

  it("serious = high or critical (same as OPS1 and the database)", () => {
    expect(isSerious("high")).toBe(true);
    expect(isSerious("critical")).toBe(true);
    expect(isSerious("medium")).toBe(false);
    expect(isSerious(null)).toBe(false);
  });

  it("labels every status", () => {
    for (const s of ["open", "in_review", "closed"]) expect(EVENT_STATUS_LABEL[s]).toBeTruthy();
  });

  it("explains the missing clinical list instead of inventing types", () => {
    expect(NO_TYPES_NOTICE).toContain("D-16");
  });

  it("maps rejections, with a generic fallback", () => {
    expect(qualityRejectionMessage("type_not_approved")).toContain("klinisch");
    expect(qualityRejectionMessage("x")).toBe("Qualitätsereignis konnte nicht gespeichert werden.");
  });

  it("CSR1 / CGR-13: a hold is a billing hold and gives no care instruction", () => {
    expect(HOLD_MEANING).toContain("nur die Abrechnung");
    expect(HOLD_MEANING).not.toMatch(/Stopp/);
    expect(NO_TYPES_NOTICE).toContain("Abrechnungssperre");
  });
});
