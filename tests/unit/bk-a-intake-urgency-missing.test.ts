// BK-a, CGR-215 (d) (PO amendment 2026-11-13 21:39, brief `docs/agents/briefs/BK.md`): the Operations intake list never
// drops a row silently because its urgency is empty. The row stays, shows «Dringlichkeit fehlt», and the load logs an
// error event. Written before the change to `src/features/intake/rules.ts` (red first: `URGENCY_MISSING_LABEL` and
// `intakeRowsWithUrgencyCheck` did not exist, and `urgencyWithSource` took no null).
import { describe, expect, it } from "vitest";
import {
  URGENCY_MISSING_LABEL,
  intakeRowsWithUrgencyCheck,
  urgencyBadgeClass,
  urgencyBadgeText,
  urgencyWithSource,
} from "@/features/intake/rules";

describe("intake list: missing urgency (CGR-215 (d))", () => {
  it("names the gap in words, never an empty badge", () => {
    expect(URGENCY_MISSING_LABEL).toBe("Dringlichkeit fehlt");
    expect(urgencyBadgeText(null)).toBe("Dringlichkeit fehlt");
    expect(urgencyBadgeText("")).toBe("Dringlichkeit fehlt");
    expect(urgencyBadgeText("hoch")).toBe("hoch");
    expect(urgencyWithSource(null, "referrer_stated")).toBe("Dringlichkeit fehlt");
    expect(urgencyWithSource("mittel", "intake_assessed")).toBe("Dringlichkeit: mittel (bei der Aufnahme eingeschätzt)");
    expect(typeof urgencyBadgeClass(null)).toBe("string");
    expect(urgencyBadgeClass(null).length).toBeGreaterThan(0);
  });

  it("keeps every row, in order, and counts the ones without urgency", () => {
    const rows = [
      { id: "a", urgency: "hoch" },
      { id: "b", urgency: null },
      { id: "c", urgency: "niedrig" },
      { id: "d", urgency: "" },
    ];
    const { rows: kept, missingUrgency } = intakeRowsWithUrgencyCheck(rows);
    expect(kept.map((r) => r.id)).toEqual(["a", "b", "c", "d"]);
    expect(kept).toHaveLength(rows.length);
    expect(missingUrgency).toEqual(["b", "d"]);
  });

  it("reports nothing missing when every row has an urgency", () => {
    expect(intakeRowsWithUrgencyCheck([{ id: "a", urgency: "mittel" }]).missingUrgency).toEqual([]);
    expect(intakeRowsWithUrgencyCheck([]).rows).toEqual([]);
  });
});
