import { describe, expect, it } from "vitest";
import { ADDRESS_MISSING, STREET_MISSING, placeLine } from "@/features/field/place";

// BK-e1 / UXR-190 (#1232, `cra` CGR-212): the «Ort» row of the /field visit card must not look complete when the street
// is missing. Brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 02:39 criterion 1; ADR-202 (1).
// Written before the code (red first, FE-071 (2)). Presentation only: no rule about whether such a visit may be planned.

describe("placeLine (UXR-190)", () => {
  it("street, postcode and place: the full address, no hint", () => {
    expect(placeLine("Musterweg 1", "4052", "Basel")).toEqual({ text: "Musterweg 1, 4052 Basel", missing: false });
  });

  it("postcode and place without a street: «4052 Basel · Strasse fehlt – im Team klären», marked as missing", () => {
    expect(placeLine(null, "4052", "Basel")).toEqual({ text: "4052 Basel · Strasse fehlt – im Team klären", missing: true });
    expect(STREET_MISSING).toBe("Strasse fehlt – im Team klären");
  });

  it("nothing recorded: «Adresse fehlt – im Team klären» (unchanged)", () => {
    expect(placeLine(null, null, null)).toEqual({ text: "Adresse fehlt – im Team klären", missing: true });
    expect(ADDRESS_MISSING).toBe("Adresse fehlt – im Team klären");
  });

  it("a postcode alone (the seed shape since B1.1-1c) still says the street is missing", () => {
    expect(placeLine(null, "4052", null)).toEqual({ text: "4052 · Strasse fehlt – im Team klären", missing: true });
  });

  it("blank strings count as empty (no «Ort 4052» that looks complete)", () => {
    expect(placeLine("  ", "4052", "Basel")).toEqual({ text: "4052 Basel · Strasse fehlt – im Team klären", missing: true });
    expect(placeLine("", "", "")).toEqual({ text: "Adresse fehlt – im Team klären", missing: true });
  });

  it("a street without postcode stays as recorded (unchanged when the street exists)", () => {
    expect(placeLine("Musterweg 1", null, null)).toEqual({ text: "Musterweg 1", missing: false });
  });
});
