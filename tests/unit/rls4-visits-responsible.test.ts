import { describe, expect, it } from "vitest";
import { getVisitResponsibleLabel } from "@/features/visits/types";

// RLS4-6 (ADR-122): /visits names the responsible member from responsible_user_id, never the legacy
// free-text team_member_name. Synthetic ids and names only.
// UX2-29 amended (CGR-109): the empty text depends on whether the visit is still open, so every case names an open
// visit of `TODAY` (planned) unless it says otherwise; the closed-visit cases live in ux2-wording.test.ts.
const TODAY = "2026-11-03";
const OPEN = { visit_date: TODAY, status: "planned" } as const;

describe("getVisitResponsibleLabel (RLS4-6)", () => {
  it("shows the responsible member's display name", () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-1", responsible_name: "Pflegekraft Team C", ...OPEN }, TODAY)).toBe(
      "Pflegekraft Team C"
    );
  });

  it('shows "noch niemand" when nobody is responsible on a visit still open (UX2-29)', () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, ...OPEN }, TODAY)).toBe("noch niemand");
  });

  it('shows "Teammitglied" when the responsible member has no display name', () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-2", responsible_name: null, ...OPEN }, TODAY)).toBe("Teammitglied");
    expect(getVisitResponsibleLabel({ responsible_user_id: "u-synthetic-2", responsible_name: "  ", ...OPEN }, TODAY)).toBe("Teammitglied");
  });

  it("never shows a name without a responsible member, open or not", () => {
    expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: "Synthetische Pflegende", ...OPEN }, TODAY)).toBe("noch niemand");
    expect(
      getVisitResponsibleLabel(
        { responsible_user_id: null, responsible_name: "Synthetische Pflegende", visit_date: "2026-11-02", status: "completed" },
        TODAY
      )
    ).toBe("nicht erfasst");
  });
});
