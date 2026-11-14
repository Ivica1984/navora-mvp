// BK-a, UXR-202 (PO amendment 2026-11-14 01:39 (3), on `cra`'s review position 01:35; brief `docs/agents/briefs/BK.md`):
// «Dringlichkeit fehlt» must look different from every stored level (outlined badge, dark text, the words), it is not
// red (red stays for safety signals, UX1-23), and the list keeps arrival order (no invented priority).
// Written before the change to `src/features/intake/rules.ts` (red first: a missing urgency shared the grey of «niedrig»).
import { describe, expect, it } from "vitest";
import {
  URGENCIES,
  URGENCY_BADGE_CLASS,
  URGENCY_MISSING_BADGE_CLASS,
  intakeRowsWithUrgencyCheck,
  urgencyBadgeClass,
  urgencyBadgeText,
} from "@/features/intake/rules";

describe("UXR-202: the «Dringlichkeit fehlt» badge", () => {
  it("differs from the class of every stored level", () => {
    for (const missing of [null, undefined, ""]) {
      for (const level of URGENCIES) {
        expect(urgencyBadgeClass(missing), `${String(missing)} vs ${level}`).not.toBe(URGENCY_BADGE_CLASS[level]);
      }
      expect(urgencyBadgeClass(missing)).toBe(URGENCY_MISSING_BADGE_CLASS);
    }
  });

  it("is outlined with dark text and names the gap in words", () => {
    expect(URGENCY_MISSING_BADGE_CLASS).toMatch(/\bring-1\b/);
    expect(URGENCY_MISSING_BADGE_CLASS).toMatch(/\btext-stone-900\b/);
    expect(urgencyBadgeText(null)).toBe("Dringlichkeit fehlt");
  });

  it("is never red (UX1-23: red only for safety signals)", () => {
    expect(URGENCY_MISSING_BADGE_CLASS).not.toMatch(/\b(rose|red)-/);
  });

  it("keeps the list in arrival order (no invented priority)", () => {
    const rows = [
      { id: "1", urgency: "niedrig" },
      { id: "2", urgency: null },
      { id: "3", urgency: "hoch" },
    ];
    expect(intakeRowsWithUrgencyCheck(rows).rows.map((r) => r.id)).toEqual(["1", "2", "3"]);
  });
});
