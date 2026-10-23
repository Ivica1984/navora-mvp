import { describe, expect, it } from "vitest";
import { CLOSES_WITH_CAUSE, CLOSES_WITH_FOLLOWUP, canClose, countByPriority, formatAge, handlerLabel, parseComments } from "@/features/operations/exceptions";

const NOW = Date.parse("2026-10-21T20:00:00Z");

describe("OPS1 exception helpers", () => {
  it("formats age in the past and the future (an uncovered visit lies ahead)", () => {
    expect(formatAge("2026-10-21T19:45:00Z", NOW)).toBe("seit 15 min");
    expect(formatAge("2026-10-21T14:00:00Z", NOW)).toBe("seit 6 h");
    expect(formatAge("2026-10-18T20:00:00Z", NOW)).toBe("seit 3 T");
    expect(formatAge("2026-10-21T23:00:00Z", NOW)).toBe("in 3 h");
  });

  it("counts by priority and ignores unknown values", () => {
    const base = { since: "", taken: false, taken_by_me: false };
    expect(countByPriority([{ ...base, priority: "P1" }, { ...base, priority: "P3" }, { ...base, priority: "P3" }, { ...base, priority: "X" }]))
      .toEqual({ P1: 1, P2: 0, P3: 2 });
  });

  it("shows who handles an exception", () => {
    expect(handlerLabel({ priority: "P1", since: "", taken: false, taken_by_me: false })).toBe("offen – niemand übernommen");
    expect(handlerLabel({ priority: "P1", since: "", taken: true, taken_by_me: true })).toBe("von dir übernommen");
    expect(handlerLabel({ priority: "P1", since: "", taken: true, taken_by_me: false })).toBe("von Operations übernommen");
    expect(handlerLabel({ priority: "P1", since: "", taken: true, taken_by_me: false, owner_name: "Olga Ops" })).toBe("von Olga Ops übernommen");
  });

  it("offers a close only when the database says the exception is closable (CSR1 / CGR-06)", () => {
    expect(canClose({ closable: true })).toBe(true);
    expect(canClose({ closable: false })).toBe(false);
    expect(canClose({ closable: null })).toBe(false);
    expect(canClose({})).toBe(false);
  });

  it("explains a not-closable exception without calling every one a safety exception (CGR-06, CGR-22)", () => {
    expect(CLOSES_WITH_CAUSE).toContain("schliesst automatisch");
    expect(CLOSES_WITH_CAUSE).toContain("jemand zuständig");
    expect(CLOSES_WITH_CAUSE).not.toMatch(/^Sicherheitsausnahme/);
    // CSR1 / CGR-25: an interrupted visit names the decision that ends it.
    expect(CLOSES_WITH_FOLLOWUP).toContain("Kein Schliessen von Hand");
    expect(CLOSES_WITH_FOLLOWUP).toContain("Folgeeinsatz geplant");
  });

  it("parses comments defensively", () => {
    expect(parseComments([{ text: "a", at: "2026-10-21T20:00:00Z", mine: true }, { text: 1 }, null])).toHaveLength(1);
    expect(parseComments("x")).toEqual([]);
  });
});
