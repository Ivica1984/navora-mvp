import { describe, expect, it } from "vitest";
import { intakeOrganization, parseServices } from "@/features/intake/rules";

describe("intake rules (J1)", () => {
  it("only admin/operations memberships may do intake", () => {
    expect(intakeOrganization([{ organization_id: "a", role: "nurse" }, { organization_id: "b", role: "operations" }])).toBe("b");
    expect(intakeOrganization([{ organization_id: "a", role: "admin" }])).toBe("a");
    expect(intakeOrganization([{ organization_id: "a", role: "coach" }])).toBeNull();
    expect(intakeOrganization([])).toBeNull();
  });

  it("parses services from free text", () => {
    expect(parseServices("Grundpflege, Wundversorgung ,,\nGrundpflege; Begleitung")).toEqual([
      "Grundpflege",
      "Wundversorgung",
      "Begleitung",
    ]);
    expect(parseServices("")).toEqual([]);
    expect(parseServices("x".repeat(81))).toEqual([]);
  });
});
