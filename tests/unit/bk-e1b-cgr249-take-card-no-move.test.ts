import { describe, expect, it } from "vitest";
import { canMoveToToday } from "@/features/field/rules";
import { LIFECYCLE_MESSAGES } from "@/features/lifecycle/rules";
import { TAKE_CANNOT_GO_LINE } from "@/features/field/more-actions";

// BK-e1b / CGR-249 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 07:39 (1); `cra` 07:27; ADR-203 (14)).
// While a take is live no person command moves its visit: the /field take card offers no «Heute machen». The database
// refuses the move as well (`move_visit_to_today`, `reschedule_visit` → `take_visit`, migration 0142, pgTAP 148 §12).
// Written before the code (red first, FE-071 (2)).

const TODAY = "2026-11-16";

describe("«Heute machen» on the /field card (CGR-249)", () => {
  it("a planned visit after today that is not from a take keeps «Heute machen» (VIS1-3b unchanged)", () => {
    expect(canMoveToToday("planned", false, "2026-11-20", TODAY)).toBe(true);
    expect(canMoveToToday("planned", false, "2026-11-20", TODAY, false)).toBe(true);
  });

  it("a take visit never offers «Heute machen», whatever its date", () => {
    expect(canMoveToToday("planned", false, "2026-11-20", TODAY, true)).toBe(false);
    expect(canMoveToToday("planned", null, "2026-11-21", TODAY, true)).toBe(false);
  });

  it("the server refusal `take_visit` of a move reads as the take line, not as a generic failure", () => {
    expect(LIFECYCLE_MESSAGES.take_visit).toBe(TAKE_CANNOT_GO_LINE);
  });
});
