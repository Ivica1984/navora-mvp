import { describe, expect, it } from "vitest";
import {
  CANCEL_REASONS, CLOSE_REASONS, FOLLOWUP_DECISIONS, FOLLOWUP_NOTICE, INTERRUPT_NOTICE, INTERRUPT_REASONS, NO_SHOW_NOTICE, NO_SHOW_OUTCOMES, PAUSE_REASONS, REASON_LABEL,
  canEndNotCompleted, followupOf, needsFollowup, reasonError,
} from "@/features/lifecycle/rules";

describe("C1 lifecycle rules", () => {
  it("reason lists follow the PO brief", () => {
    expect([...PAUSE_REASONS]).toEqual(["hospital_stay", "rehabilitation", "client_absence", "other"]);
    expect([...CLOSE_REASONS]).toEqual(["goal_reached", "moved_inpatient", "moved_away", "declined", "died", "other"]);
    expect([...CANCEL_REASONS]).toEqual(["client_cancelled", "client_in_hospital", "team_cancelled", "other"]);
    expect([...NO_SHOW_OUTCOMES]).toEqual(["client_reached", "emergency_contact_informed", "emergency_services_called", "other"]);
  });

  it("every reason has a label", () => {
    for (const r of [...PAUSE_REASONS, ...CLOSE_REASONS, ...CANCEL_REASONS, ...NO_SHOW_OUTCOMES, ...INTERRUPT_REASONS, ...FOLLOWUP_DECISIONS, "case_closed"]) {
      expect(REASON_LABEL[r]).toBeTruthy();
    }
  });

  it("a reason is required; 'other' needs a note", () => {
    expect(reasonError("", "", PAUSE_REASONS)).toMatch(/Grund/);
    expect(reasonError("died", "", PAUSE_REASONS)).toMatch(/Grund/);
    expect(reasonError("other", "x", PAUSE_REASONS)).toMatch(/beschreiben/);
    expect(reasonError("hospital_stay", "", PAUSE_REASONS)).toBeNull();
  });

  it("CSR1 / CGR-20: a started or paused visit can end as not completed, with the reasons of the CSR1 criterion", () => {
    expect([...INTERRUPT_REASONS]).toEqual(["client_transferred", "client_declined", "nurse_unavailable", "started_by_mistake", "other"]);
    expect(canEndNotCompleted("started")).toBe(true);
    expect(canEndNotCompleted("paused")).toBe(true);
    for (const s of ["planned", "on_the_way", "completed", "cancelled", "no_show", "interrupted", null]) {
      expect(canEndNotCompleted(s)).toBe(false);
    }
    expect(reasonError("other", "", INTERRUPT_REASONS)).toMatch(/beschreiben/);
    expect(reasonError("client_cancelled", "", INTERRUPT_REASONS)).toMatch(/Grund/);
    expect(INTERRUPT_NOTICE).toContain("D-31");
  });

  it("CSR1 / CGR-25: an interrupted visit waits for a follow-up decision from the short list", () => {
    expect([...FOLLOWUP_DECISIONS]).toEqual(["follow_up_planned", "no_longer_needed", "other"]);
    expect(REASON_LABEL.follow_up_planned).toBe("Folgeeinsatz geplant");
    expect(REASON_LABEL.no_longer_needed).toBe("Nicht mehr nötig");
    expect(reasonError("", "", FOLLOWUP_DECISIONS)).toMatch(/Grund/);
    expect(reasonError("other", " ", FOLLOWUP_DECISIONS)).toMatch(/beschreiben/);
    expect(reasonError("client_transferred", "", FOLLOWUP_DECISIONS)).toMatch(/Grund/);
    expect(reasonError("no_longer_needed", "", FOLLOWUP_DECISIONS)).toBeNull();
    const interrupted = { kind: "interrupted" };
    const decided = { kind: "interruption_followup" };
    expect(needsFollowup("interrupted", [interrupted])).toBe(true);
    expect(needsFollowup("interrupted", [interrupted, decided])).toBe(false);
    expect(needsFollowup("completed", [])).toBe(false);
    expect(followupOf([interrupted, decided])).toBe(decided);
    expect(FOLLOWUP_NOTICE).toContain("D-31");
    expect(FOLLOWUP_NOTICE).toContain("die App plant nichts");
  });

  it("the no-show notice gives no clinical instructions and points to D-19", () => {
    expect(NO_SHOW_NOTICE).toContain("D-19");
  });
});
