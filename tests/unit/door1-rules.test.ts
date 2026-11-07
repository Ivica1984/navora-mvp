// DOOR1 part (a) (migration 0072, ADR-085): display rules for the door facts and the card notes.
import { describe, expect, it } from "vitest";
import {
  DISCLOSURE_BASES, DISCLOSURE_BASIS_LABEL, atDoorText, basisText, doorNoteText, outcomeError, outcomeNeedsBasis,
} from "@/features/lifecycle/rules";

describe("DOOR1-5 an der Tür", () => {
  it("shows ja, nein, and nicht erfasst for rows recorded before the fact existed", () => {
    expect(atDoorText(true)).toBe("an der Tür: ja");
    expect(atDoorText(false)).toBe("an der Tür: nein");
    expect(atDoorText(null)).toBe("an der Tür: nicht erfasst");
    expect(atDoorText(undefined)).toBe("an der Tür: nicht erfasst");
  });
});

describe("DOOR1-6 basis of Notfallkontakt informiert", () => {
  it("mirrors the database list", () => {
    expect([...DISCLOSURE_BASES]).toEqual(["recorded_consent", "emergency", "other"]);
    for (const b of DISCLOSURE_BASES) expect(DISCLOSURE_BASIS_LABEL[b]).toBeTruthy();
  });

  it("only emergency_contact_informed takes a basis", () => {
    expect(outcomeNeedsBasis("emergency_contact_informed")).toBe(true);
    for (const o of ["client_reached", "emergency_services_called", "other"]) expect(outcomeNeedsBasis(o)).toBe(false);
  });

  it("refuses emergency_contact_informed without a basis, and an outcome without a note", () => {
    expect(outcomeError("emergency_contact_informed", "Synthetisch: Tochter", null)).toMatch(/Grundlage/);
    expect(outcomeError("emergency_contact_informed", "Synthetisch: Tochter", "guess")).toMatch(/Grundlage/);
    expect(outcomeError("emergency_contact_informed", "Synthetisch: Tochter", "emergency")).toBeNull();
    expect(outcomeError("client_reached", "x", null)).toMatch(/mind\. 3 Zeichen/);
    expect(outcomeError("", "Synthetisch", null)).toMatch(/Ergebnis wählen/);
    expect(outcomeError("client_reached", "Synthetisch: erreicht", null)).toBeNull();
  });

  it("shows the basis with the outcome, and nicht erfasst on rows recorded before it", () => {
    expect(basisText("emergency_contact_informed", "recorded_consent")).toBe("Grundlage: erfasste Einwilligung");
    expect(basisText("emergency_contact_informed", "emergency")).toBe("Grundlage: Notfall");
    expect(basisText("emergency_contact_informed", "other")).toBe("Grundlage: andere");
    expect(basisText("emergency_contact_informed", null)).toBe("Grundlage: nicht erfasst");
    expect(basisText("client_reached", "emergency")).toBeNull();
  });
});

describe("DOOR1-1 notes on the card", () => {
  it("never shows a blank note", () => {
    expect(doorNoteText("Synthetisch: Schlüssel beim Nachbarn")).toBe("Synthetisch: Schlüssel beim Nachbarn");
    expect(doorNoteText("   ")).toBe("nicht erfasst");
    expect(doorNoteText(null)).toBe("nicht erfasst");
    expect(doorNoteText(undefined)).toBe("nicht erfasst");
  });
});
