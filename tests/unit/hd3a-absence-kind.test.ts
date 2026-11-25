// HD-3a (FE-119, FE-120; migration 0171): the four neutral absence kinds on screen. The database refuses every other
// value (pgTAP 171); this checks that the screen offers exactly the four and never a sickness kind.
import { describe, expect, it } from "vitest";
import { ABSENCE_KINDS, absenceKindLabel, messageText } from "@/features/home-plan/rules";

describe("HD-3a absence kinds", () => {
  it("offers exactly Ferien, Weiterbildung, Kompensation, Abwesend", () => {
    expect(ABSENCE_KINDS.map(absenceKindLabel)).toEqual(["Ferien", "Weiterbildung", "Kompensation", "Abwesend"]);
  });
  it("has no sickness kind", () => {
    expect(ABSENCE_KINDS.map(absenceKindLabel).some((l) => /krank/i.test(l))).toBe(false);
    expect((ABSENCE_KINDS as readonly string[]).includes("sickness")).toBe(false);
  });
  it("words a refused kind", () => {
    expect(messageText("kind_not_valid")).toEqual({ kind: "error", text: expect.stringContaining("Kompensation") });
  });
});
