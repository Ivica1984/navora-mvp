import { describe, expect, it } from "vitest";
import { ADDRESS_MISSING, STREET_MISSING, TAKE_STREET_NOT_SENT, placeLine } from "@/features/field/place";
import { TAKE_HEADING, visitHeading } from "@/features/field/heading";

// BK-e1b / UXR-237, UXR-239 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 05:39; `cra` 05:26 confirmed the
// words for the simulation only; ADR-203 (11)). Written before the code (red first, FE-071 (2)). Presentation only.

describe("placeLine with the take flag (UXR-237)", () => {
  it("take visit without a street: names the simulation limit, not an action the team cannot take", () => {
    expect(placeLine(null, "4052", "Basel", true)).toEqual({
      text: "4052 Basel · Strasse fehlt – wird in der Simulation nicht übermittelt",
      missing: true,
    });
    expect(TAKE_STREET_NOT_SENT).toBe("Strasse fehlt – wird in der Simulation nicht übermittelt");
  });

  it("take visit with a postcode only", () => {
    expect(placeLine("", "4052", null, true)).toEqual({
      text: "4052 · Strasse fehlt – wird in der Simulation nicht übermittelt",
      missing: true,
    });
  });

  it("without the take flag the BK-e1a line stays (UXR-190)", () => {
    expect(placeLine(null, "4052", "Basel", false)).toEqual({ text: `4052 Basel · ${STREET_MISSING}`, missing: true });
    expect(placeLine(null, "4052", "Basel")).toEqual({ text: `4052 Basel · ${STREET_MISSING}`, missing: true });
  });

  it("a take visit with a street reads as a full address", () => {
    expect(placeLine("Musterweg 1", "4052", "Basel", true)).toEqual({ text: "Musterweg 1, 4052 Basel", missing: false });
  });

  it("nothing recorded: «Adresse fehlt – im Team klären» with or without the flag", () => {
    expect(placeLine(null, null, null, true)).toEqual({ text: ADDRESS_MISSING, missing: true });
    expect(placeLine(null, null, null, false)).toEqual({ text: ADDRESS_MISSING, missing: true });
  });
});

describe("visitHeading (UXR-239)", () => {
  it("take visit: «Übernommene Schicht», never «ohne Namen»", () => {
    expect(TAKE_HEADING).toBe("Übernommene Schicht");
    expect(visitHeading(null, true)).toBe("Übernommene Schicht");
    expect(visitHeading(undefined, true)).not.toMatch(/ohne Namen/);
  });

  it("take visit: no client identifier is shown (UNKNOWN which one, `lca`, CGR-243)", () => {
    expect(visitHeading("Synthetische Person", true)).toBe("Übernommene Schicht");
  });

  it("other visits: the client name, or «Klient:in ohne Namen» (unchanged)", () => {
    expect(visitHeading("Synthetische Person", false)).toBe("Synthetische Person");
    expect(visitHeading(null, false)).toBe("Klient:in ohne Namen");
    expect(visitHeading(null, null)).toBe("Klient:in ohne Namen");
  });
});
