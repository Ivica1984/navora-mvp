import { describe, expect, it } from "vitest";
import { CANCEL_REASONS, CLOSE_REASONS, NO_SHOW_NOTICE, NO_SHOW_OUTCOMES, PAUSE_REASONS, REASON_LABEL, reasonError } from "@/features/lifecycle/rules";

describe("C1 lifecycle rules", () => {
  it("reason lists follow the PO brief", () => {
    expect([...PAUSE_REASONS]).toEqual(["hospital_stay", "rehabilitation", "client_absence", "other"]);
    expect([...CLOSE_REASONS]).toEqual(["goal_reached", "moved_inpatient", "moved_away", "declined", "died", "other"]);
    expect([...CANCEL_REASONS]).toEqual(["client_cancelled", "client_in_hospital", "team_cancelled", "other"]);
    expect([...NO_SHOW_OUTCOMES]).toEqual(["client_reached", "emergency_contact_informed", "emergency_services_called", "other"]);
  });

  it("every reason has a label", () => {
    for (const r of [...PAUSE_REASONS, ...CLOSE_REASONS, ...CANCEL_REASONS, ...NO_SHOW_OUTCOMES, "case_closed"]) {
      expect(REASON_LABEL[r]).toBeTruthy();
    }
  });

  it("a reason is required; 'other' needs a note", () => {
    expect(reasonError("", "", PAUSE_REASONS)).toMatch(/Grund/);
    expect(reasonError("died", "", PAUSE_REASONS)).toMatch(/Grund/);
    expect(reasonError("other", "x", PAUSE_REASONS)).toMatch(/beschreiben/);
    expect(reasonError("hospital_stay", "", PAUSE_REASONS)).toBeNull();
  });

  it("the no-show notice gives no clinical instructions and points to D-19", () => {
    expect(NO_SHOW_NOTICE).toContain("D-19");
  });
});
