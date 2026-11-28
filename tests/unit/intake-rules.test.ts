import { describe, expect, it } from "vitest";
import {
  CANTONS,
  URGENCY_SOURCES,
  factsFromForm,
  intakeOrganization,
  parseMissing,
  parseServices,
  urgencySourceLabel,
  urgencyWithSource,
} from "@/features/intake/rules";

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


describe("intake facts (J1, PO brief)", () => {
  it("has all 26 cantons", () => {
    expect(CANTONS).toHaveLength(26);
    expect(new Set(CANTONS).size).toBe(26);
  });

  it("leaves empty inputs out so an update never blanks a recorded fact", () => {
    const form: Record<string, string> = {
      residence_municipality: " Bern ", residence_canton: "BE", insurer_name: "", insurance_type: "KVG",
      gp_named: "yes", other_providers_active: "", requested_start: "2026-10-23",
    };
    expect(factsFromForm((k) => form[k] ?? "")).toEqual({
      residence_municipality: "Bern", residence_canton: "BE", insurance_type: "KVG", gp_named: true, requested_start: "2026-10-23",
    });
    expect(factsFromForm((k) => (k === "other_providers_active" ? "no" : ""))).toEqual({ other_providers_active: false });
  });

  it("J2: expected hours per week as a number (comma accepted), empty or invalid left out", () => {
    expect(factsFromForm((k) => (k === "expected_hours_per_week" ? "6,5" : ""))).toEqual({ expected_hours_per_week: 6.5 });
    expect(factsFromForm((k) => (k === "expected_hours_per_week" ? "abc" : ""))).toEqual({});
    expect(factsFromForm((k) => (k === "expected_hours_per_week" ? "0" : ""))).toEqual({});
  });

  it("parses the readiness list defensively", () => {
    expect(parseMissing([{ item: "insurer", reason: "Krankenversicherer fehlt" }, { item: 1 }, null])).toEqual([
      { item: "insurer", reason: "Krankenversicherer fehlt" },
    ]);
    expect(parseMissing(undefined)).toEqual([]);
  });

  it("IPA1-7: only the two recorded sources can be chosen; anything else reads as not recorded", () => {
    expect(URGENCY_SOURCES).toEqual(["referrer_stated", "intake_assessed"]);
    expect(urgencySourceLabel("referrer_stated")).toBe("vom Zuweiser angegeben");
    expect(urgencySourceLabel("intake_assessed")).toBe("bei der Aufnahme eingeschätzt");
    for (const other of ["unknown", "", null, undefined, "x"]) {
      expect(urgencySourceLabel(other)).toBe("Quelle nicht erfasst");
    }
    expect(urgencyWithSource("hoch", "referrer_stated")).toBe("Dringlichkeit: hoch (vom Zuweiser angegeben)");
    expect(urgencyWithSource("mittel", "unknown")).toBe("Dringlichkeit: mittel (Quelle nicht erfasst)");
  });
});
