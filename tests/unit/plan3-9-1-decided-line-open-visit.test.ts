import { describe, expect, it } from "vitest";
import { lineDecisionText, lineStillOpenText, type DayPlanLine } from "@/features/planning/day-plan-view";

/**
 * PLAN3-9 (1) (ADR-156, `cra` CGR-138, PO note 2026-11-06 06:30): a decided day-plan line never reads as a covered
 * visit. `day_plan` returns `visit_has_responsible` (yes/no, migration 0115); the screen says "Noch offen" (the
 * existing `/visits` wording) for a decided line whose visit has nobody, and the decided "kein Vorschlag" no longer
 * ends in "bestätigt". Synthetic values only.
 */
function line(over: Partial<DayPlanLine>): Pick<DayPlanLine, "decision" | "visit_has_responsible"> {
  return { decision: "open", visit_has_responsible: false, ...over };
}

describe("PLAN3-9 (1) a decided line whose visit has nobody says so", () => {
  it("shows 'Noch offen' after a rejection, a decided 'kein Vorschlag' or any other decision while the visit has nobody", () => {
    for (const decision of ["rejected", "not_found", "confirmed", "corrected", "unknown_code"]) {
      expect(lineStillOpenText(line({ decision, visit_has_responsible: false }))).toBe("Noch offen");
    }
  });

  it("says nothing once the visit has a responsible member", () => {
    for (const decision of ["rejected", "not_found", "confirmed", "corrected"]) {
      expect(lineStillOpenText(line({ decision, visit_has_responsible: true }))).toBeNull();
    }
  });

  it("says nothing on an open line (it is still being decided; the decision controls are there)", () => {
    expect(lineStillOpenText(line({ decision: "open", visit_has_responsible: false }))).toBeNull();
    expect(lineStillOpenText(line({ decision: "open", visit_has_responsible: true }))).toBeNull();
  });

  it("treats a missing yes/no as 'nobody' (never as covered)", () => {
    expect(lineStillOpenText(line({ decision: "rejected", visit_has_responsible: null as unknown as boolean }))).toBe(
      "Noch offen",
    );
  });
});

describe("PLAN3-9 (1) the decided 'kein Vorschlag' does not read as a confirmed visit", () => {
  it("does not end in 'bestätigt'", () => {
    const t = lineDecisionText("not_found");
    expect(t).not.toBeNull();
    expect(t!.endsWith("bestätigt")).toBe(false);
    expect(t).toBe("„kein Vorschlag“, entschieden");
  });

  it("keeps the other decision texts", () => {
    expect(lineDecisionText("open")).toBeNull();
    expect(lineDecisionText("confirmed")).toBe("bestätigt");
    expect(lineDecisionText("corrected")).toBe("geändert und bestätigt");
    expect(lineDecisionText("rejected")).toBe("abgelehnt");
  });
});
