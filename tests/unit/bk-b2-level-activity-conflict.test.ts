import { describe, expect, it } from "vitest";
import {
  ORDER_PROBLEM_CODES,
  levelActivityConflictText,
  orderProblemField,
  orderProblemText,
} from "@/features/orders/rules";

// BK-b2 (brief docs/agents/briefs/BK.md, PO amendment 2026-11-13 21:39 (4); `cra` CGR-216 (a); draft ADR-196).
// Written before the code (red first: `levelActivityConflictText` and the code `level_activity_conflict` do not exist
// on the BK-b1 head f3b2a5c). The database (pgTAP 138) refuses the order; this module only words the code, at the
// activities field, and names every activity the database returned (CGR-205 (a): shown to the client before
// confirmation, never resolved silently). Words PROPOSED for `uxa`.

const LABELS: Record<string, string> = {
  B2: "Venöse und kapillare Blutentnahme",
  B3: "Medikamente richten und verabreichen",
};

describe("CGR-216: level against activity, worded for the client", () => {
  it("is a known preview code and belongs to the activities field", () => {
    expect(ORDER_PROBLEM_CODES).toContain("level_activity_conflict");
    expect(orderProblemField("level_activity_conflict")).toBe("tags");
  });

  it("has a general text when the activities are not known", () => {
    expect(orderProblemText("level_activity_conflict")).toBe(
      "Mindestens eine gewählte Tätigkeit passt nicht zur gewählten Stufe.",
    );
  });

  it("names the level and each activity the database returned, in its order", () => {
    expect(levelActivityConflictText("ags_eba", ["B2", "B3"], LABELS)).toBe(
      "Für AGS ist diese Auswahl nicht möglich: Venöse und kapillare Blutentnahme, Medikamente richten und verabreichen. " +
        "Bitte eine andere Stufe wählen oder die Tätigkeit entfernen.",
    );
  });

  it("never drops an activity it has no label for: the code is shown instead", () => {
    expect(levelActivityConflictText("fage_efz", ["B3H"], LABELS)).toBe(
      "Für FaGe ist diese Auswahl nicht möglich: B3H. Bitte eine andere Stufe wählen oder die Tätigkeit entfernen.",
    );
  });

  it("falls back to the general text for an empty list or an unknown level (nothing is guessed)", () => {
    expect(levelActivityConflictText("ags_eba", [], LABELS)).toBe(orderProblemText("level_activity_conflict"));
    expect(levelActivityConflictText("xx", ["B2"], LABELS)).toBe(orderProblemText("level_activity_conflict"));
  });
});
