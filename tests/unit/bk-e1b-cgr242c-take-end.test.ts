import { describe, expect, it } from "vitest";
import { TAKE_ENDED_STATUS, takeEndedText } from "@/features/field/take-end";
import { offerCommandText } from "@/features/orders/offer-rules";

// BK-e1b / CGR-242 (c) (`cra` 04:27; words `uxa` 03:50, UX_REVIEW.md; PO 04:39): the released member's /field card of a
// take visit ended before the start. It stays on her day, says in text that it is no longer hers and why, and never
// reads as a cancellation by the client («abgesagt», «storniert»). Codes from care_visits.system_end_reason (0139).
// Written before the code (red first, FE-071 (2)).

const TAIL = "Das Angebot geht wieder an alle passenden Teams.";

describe("takeEndedText (CGR-242 (c))", () => {
  it("status line «Nicht mehr deine Schicht»", () => {
    expect(TAKE_ENDED_STATUS).toBe("Nicht mehr deine Schicht");
  });

  it("her own absence", () => {
    expect(takeEndedText("take_released_absence")).toBe(
      `Die Übernahme gilt nicht mehr: du hast für diese Zeit eine Abwesenheit erfasst. ${TAIL}`,
    );
  });

  it("another visit or take of hers at the same time", () => {
    expect(takeEndedText("take_released_busy")).toBe(
      `Die Übernahme gilt nicht mehr: du hast zur gleichen Zeit einen anderen Einsatz. ${TAIL}`,
    );
  });

  it("membership ended", () => {
    expect(takeEndedText("take_released_left_team")).toBe(
      `Die Übernahme gilt nicht mehr: du bist nicht mehr in diesem Team. ${TAIL}`,
    );
  });

  it("any other code: no reason clause", () => {
    expect(takeEndedText("take_released")).toBe(`Die Übernahme gilt nicht mehr. ${TAIL}`);
    expect(takeEndedText("something_new")).toBe(`Die Übernahme gilt nicht mehr. ${TAIL}`);
  });

  it("not a system end: nothing", () => {
    expect(takeEndedText(null)).toBeNull();
    expect(takeEndedText(undefined)).toBeNull();
    expect(takeEndedText("")).toBeNull();
  });

  it("never reads as a cancellation", () => {
    for (const code of ["take_released", "take_released_absence", "take_released_busy", "take_released_left_team"]) {
      const text = `${TAKE_ENDED_STATUS} ${takeEndedText(code)}`.toLowerCase();
      expect(text).not.toContain("abgesagt");
      expect(text).not.toContain("storniert");
    }
  });
});

describe("offerCommandText (CGR-244)", () => {
  it("«Ich kann nicht» refused while her visit is under way: a visible reason, never silent", () => {
    expect(offerCommandText("visit_under_way")).toBe(
      "Du bist für diese Schicht schon unterwegs. Die Übernahme bleibt bestehen; bitte im Team klären.",
    );
  });
});
