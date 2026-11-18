import { describe, expect, it } from "vitest";
import { TAKE_CANNOT_GO_LINE, fieldMoreItems, showTakeCannotGoLine } from "@/features/field/more-actions";
import { LIFECYCLE_MESSAGES } from "@/features/lifecycle/rules";

// BK-e1b / CGR-248, UXR-241 (#1428) and UXR-240 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 06:39 (2), (3);
// `cra` 06:27 confirmed the line for the simulation only; ADR-203 (13)). Written before the code (red first, FE-071 (2)).
// The database refuses the cancellation of a take visit as well (pgTAP 148 §11); this is the card side.

describe("«Mehr» items on the /field card (CGR-248, UXR-240)", () => {
  it("a visit that is not from a take keeps «Einsatz absagen» and the billing hold (UX1-8 unchanged)", () => {
    expect(fieldMoreItems({ status: "planned", fromTake: false, takeEnded: false, holdOpen: false })).toEqual(["cancel", "hold"]);
    expect(fieldMoreItems({ status: "on_the_way", fromTake: false, takeEnded: false, holdOpen: false })).toEqual(["cancel", "hold"]);
    expect(fieldMoreItems({ status: "in_progress", fromTake: false, takeEnded: false, holdOpen: false })).toEqual(["hold"]);
    expect(fieldMoreItems({ status: "planned", fromTake: false, takeEnded: false, holdOpen: true })).toEqual(["cancel"]);
  });

  it("CGR-248: a take visit never offers «Einsatz absagen», planned or on the way", () => {
    expect(fieldMoreItems({ status: "planned", fromTake: true, takeEnded: false, holdOpen: false })).toEqual(["hold"]);
    expect(fieldMoreItems({ status: "on_the_way", fromTake: true, takeEnded: false, holdOpen: false })).toEqual(["hold"]);
    expect(fieldMoreItems({ status: "planned", fromTake: true, takeEnded: false, holdOpen: true })).toEqual([]);
  });

  it("UXR-240: an ended take card offers no action at all (no «Mehr», no billing hold)", () => {
    expect(fieldMoreItems({ status: "cancelled", fromTake: true, takeEnded: true, holdOpen: false })).toEqual([]);
  });
});

describe("the line instead of «Einsatz absagen» on a take card (CGR-248 / UXR-241)", () => {
  it("uses the words confirmed by `cra` for the simulation", () => {
    expect(TAKE_CANNOT_GO_LINE).toBe(
      "Kannst du nicht? Melde dich sofort bei deinem Team. Die Schicht bleibt bei dir, bis sie geklärt ist.",
    );
  });

  it("shows on a live take visit before its start (planned or on the way)", () => {
    expect(showTakeCannotGoLine({ status: "planned", fromTake: true, takeEnded: false })).toBe(true);
    expect(showTakeCannotGoLine({ status: "on_the_way", fromTake: true, takeEnded: false })).toBe(true);
  });

  it("never on another visit, an ended take card or once the visit has started", () => {
    expect(showTakeCannotGoLine({ status: "planned", fromTake: false, takeEnded: false })).toBe(false);
    expect(showTakeCannotGoLine({ status: "cancelled", fromTake: true, takeEnded: true })).toBe(false);
    expect(showTakeCannotGoLine({ status: "in_progress", fromTake: true, takeEnded: false })).toBe(false);
  });

  it("the server refusal `take_visit` reads as the same line, not as a generic failure", () => {
    expect(LIFECYCLE_MESSAGES.take_visit).toBe(TAKE_CANNOT_GO_LINE);
  });
});
