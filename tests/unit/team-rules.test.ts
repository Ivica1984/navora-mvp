import { describe, expect, it } from "vitest";
import { formatMinutesByCategory, minutesFromForm, sortVisitAlerts, visitAlertHandling } from "@/features/team/rules";

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

describe("CSR1 team visit alerts (CGR-04)", () => {
  it("orders P1 first, then the oldest, unknown priorities last, without mutating the input", () => {
    const input = [
      { id: "p2-old", priority: "P2", since: "2026-10-23T05:00:00Z", taken: false },
      { id: "x", priority: "X", since: "2026-10-23T01:00:00Z", taken: false },
      { id: "p1-new", priority: "P1", since: "2026-10-23T06:00:00Z", taken: false },
      { id: "p1-old", priority: "P1", since: "2026-10-23T04:00:00Z", taken: true },
      { id: "p2-new", priority: "P2", since: "2026-10-23T06:30:00Z", taken: false },
    ];
    expect(sortVisitAlerts(input).map((a) => a.id)).toEqual(["p1-old", "p1-new", "p2-old", "p2-new", "x"]);
    expect(input[0].id).toBe("p2-old");
  });

  it("says whether Operations took the alert over", () => {
    expect(visitAlertHandling(true)).toContain("kümmert sich");
    expect(visitAlertHandling(false)).toContain("noch nicht übernommen");
  });
});
