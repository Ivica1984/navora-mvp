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

describe("continuity (J6)", () => {
  // Imported lazily to keep this file's existing imports untouched.
  it("labels members without names and never guesses", async () => {
    const { memberLabel } = await import("@/features/team/rules");
    const members = [
      { user_id: "a", me: true, qualification: "registered_nurse" },
      { user_id: "b", me: false, qualification: "care_assistant" },
    ];
    expect(memberLabel(members, "a")).toBe("Ich – Pflegefachperson");
    expect(memberLabel(members, "b")).toBe("Teammitglied 2 – Pflegeassistenz");
    expect(memberLabel(members, null)).toBe("nicht bestimmt");
    expect(memberLabel(members, "x")).toBe("nicht mehr im Team");
  });

  it("uses the display name once one is set (ADM1)", async () => {
    const { memberLabel } = await import("@/features/team/rules");
    const members = [
      { user_id: "a", me: true, qualification: "registered_nurse", name: "Anna Muster" },
      { user_id: "b", me: false, qualification: "care_assistant", name: "Ben Beispiel" },
      { user_id: "c", me: false, qualification: null, name: "  " },
    ];
    expect(memberLabel(members, "a")).toBe("Ich (Anna Muster) – Pflegefachperson");
    expect(memberLabel(members, "b")).toBe("Ben Beispiel – Pflegeassistenz");
    expect(memberLabel(members, "c")).toBe("Teammitglied 3");
  });

  it("formats the monthly measure per client, never per person", async () => {
    const { formatContinuity, PLAN_FLAG_LABEL } = await import("@/features/team/rules");
    expect(formatContinuity({ visits: 0, distinct_nurses: 0, primary_share_pct: null })).toContain("noch keine");
    expect(formatContinuity({ visits: 6, distinct_nurses: 3, primary_share_pct: 67 })).toBe("6 Einsätze · 3 verschiedene Pflegende · 67 % durch Bezugspflege");
    expect(formatContinuity({ visits: 2, distinct_nurses: 1, primary_share_pct: null })).toContain("Bezugspflege nicht bestimmt");
    expect(PLAN_FLAG_LABEL.not_primary).toBeTruthy();
  });
});
