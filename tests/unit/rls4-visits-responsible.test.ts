import { describe, expect, it } from "vitest";
import { getVisitResponsibleLabel } from "@/features/visits/types";

// RLS4-6 (ADR-122): /visits names the responsible member from responsible_user_id, never the legacy
// free-text team_member_name. Synthetic ids and names only.
describe("getVisitResponsibleLabel (RLS4-6)", () => {
  it("shows the responsible member's display name", () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-1", responsible_name: "Pflegekraft Team C" })).toBe(
      "Pflegekraft Team C"
    );
  });

  it('shows "Noch offen" when nobody is responsible', () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null })).toBe("Noch offen");
  });

  it('shows "Teammitglied" when the responsible member has no display name', () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-2", responsible_name: null })).toBe("Teammitglied");
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-2", responsible_name: "  " })).toBe("Teammitglied");
  });

  it("never shows a name without a responsible member", () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: "Synthetische Pflegende" })).toBe("Noch offen");
  });
});
