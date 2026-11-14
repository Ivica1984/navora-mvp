import { describe, expect, it } from "vitest";
import { COVER_MESSAGES, offerMinutes } from "@/features/cover/rules";

// COVER1: the offer shows only what is needed to decide (migration 0028).
describe("cover rules (COVER1)", () => {
  it("shows minutes per category and leaves empty categories out", () => {
    expect(offerMinutes(30, 0, null)).toBe("A 30 min");
    expect(offerMinutes(30, 20, 10)).toBe("A 30 · B 20 · C 10 min");
    expect(offerMinutes(null, null, null)).toBe("–");
  });

  it("explains every refusal of the database", () => {
    for (const code of ["taken", "rejected", "failed", "invalid"]) expect(COVER_MESSAGES[code]).toBeTruthy();
  });
});
