import { describe, expect, it } from "vitest";
import {
  CLIENT_ORDER_PATH,
  GRADE_OPTIONS,
  ORDER_PROBLEM_CODES,
  coverStateText,
  homePathFor,
  orderProblemText,
  radiusLine,
  resolveOrderDate,
  shiftLabelLine,
} from "@/features/orders/rules";

/**
 * BK-a (brief docs/agents/briefs/BK.md; ADR-194). Written before `src/features/orders/rules.ts` (red first, task
 * rule 3). pgTAP 135 proves the database side (one row, 540 minutes, no write before confirm, no default); this file
 * guards the form side: the date words (AUT-120), the problem texts, the summary lines (UXR-197) and the landing page.
 * Dates are fixed (no clock read): 2026-11-15 is a Sunday, 2026-11-18 a Wednesday.
 */
describe("BK-a relative date (AUT-120)", () => {
  it("on a Sunday, «Sonntag» admits today and next Sunday: two candidates, no date filled", () => {
    expect(resolveOrderDate("Sonntag", "2026-11-15")).toEqual({
      kind: "relative_date_ambiguous",
      candidates: ["2026-11-15", "2026-11-22"],
    });
  });

  it("on a Wednesday, «Sonntag» is exactly one date", () => {
    expect(resolveOrderDate("Sonntag", "2026-11-18")).toEqual({ kind: "date", date: "2026-11-22" });
    expect(resolveOrderDate("  sonntag ", "2026-11-18")).toEqual({ kind: "date", date: "2026-11-22" });
  });

  it("«heute», «morgen», «übermorgen» and a written date are one date each", () => {
    expect(resolveOrderDate("heute", "2026-11-18")).toEqual({ kind: "date", date: "2026-11-18" });
    expect(resolveOrderDate("morgen", "2026-11-30")).toEqual({ kind: "date", date: "2026-12-01" });
    expect(resolveOrderDate("übermorgen", "2026-12-31")).toEqual({ kind: "date", date: "2027-01-02" });
    expect(resolveOrderDate("22.11.2026", "2026-11-18")).toEqual({ kind: "date", date: "2026-11-22" });
    expect(resolveOrderDate("2026-11-22", "2026-11-18")).toEqual({ kind: "date", date: "2026-11-22" });
  });

  it("nothing is guessed: unknown words, an impossible date and an empty field give no date (BK-1b)", () => {
    expect(resolveOrderDate("bald", "2026-11-18")).toEqual({ kind: "unknown" });
    expect(resolveOrderDate("31.02.2026", "2026-11-18")).toEqual({ kind: "unknown" });
    expect(resolveOrderDate("", "2026-11-18")).toEqual({ kind: "empty" });
  });
});

describe("BK-a texts", () => {
  it("every database problem code has a German text without a code or `_` (UXR-196)", () => {
    for (const code of ORDER_PROBLEM_CODES) {
      const text = orderProblemText(code);
      expect(text.length).toBeGreaterThan(5);
      expect(text).not.toContain("_");
    }
    expect(orderProblemText("something_new")).not.toContain("_");
  });

  it("offers the three levels of the form, with the matrix grade codes behind them", () => {
    expect(GRADE_OPTIONS.map((g) => g.label)).toEqual(["AGS", "FaGe", "HF"]);
    expect(GRADE_OPTIONS.map((g) => g.value)).toEqual(["ags_eba", "fage_efz", "nurse_hf_fh"]);
  });

  it("UXR-197: a matching label reads «… · aus Ihrem Dienstplan»; no label gives no line", () => {
    expect(shiftLabelLine("Nacht")).toBe("Nacht · aus Ihrem Dienstplan");
    expect(shiftLabelLine(null)).toBeNull();
    expect(shiftLabelLine("")).toBeNull();
  });

  it("UXR-197: an empty radius reads «Distanz: keine Vorgabe»", () => {
    expect(radiusLine(null)).toBe("Distanz: keine Vorgabe");
    expect(radiusLine(5)).toBe("Distanz: höchstens 5 km");
    expect(radiusLine(2.5)).toBe("Distanz: höchstens 2,5 km");
  });

  it("BK-6: a confirmed order without cover says so in words", () => {
    expect(coverStateText("not_covered")).toBe("noch nicht gedeckt");
    expect(coverStateText("anything")).toBe("noch nicht gedeckt");
  });
});

describe("BK-a landing (ADR-192 (6))", () => {
  it("a client without organisation role lands on /order", () => {
    expect(CLIENT_ORDER_PATH).toBe("/order");
    expect(homePathFor([], true)).toBe("/order");
  });

  it("everybody else keeps today's landing page", () => {
    expect(homePathFor([], false)).toBe("/operations");
    expect(homePathFor(["nurse"], false)).toBe("/field");
    expect(homePathFor(["operations"], false)).toBe("/operations");
  });
});
