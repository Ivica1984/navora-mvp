import { describe, expect, it } from "vitest";
import { formatMinutesByCategory, minutesFromForm } from "@/features/team/rules";

describe("team planning rules (J3)", () => {
  it("reads minutes per category; empty or invalid → 0", () => {
    const form: Record<string, string> = { minutes_a: "", minutes_b: "15", minutes_c: "-3" };
    expect(minutesFromForm((k) => form[k] ?? "")).toEqual({ a: 0, b: 15, c: 0 });
  });

  it("formats only categories with minutes", () => {
    expect(formatMinutesByCategory({ a: 0, b: 15, c: 30 })).toBe("B 15 min · C 30 min");
    expect(formatMinutesByCategory({ a: null, b: null, c: null })).toBe("keine Minuten erfasst");
  });
});
