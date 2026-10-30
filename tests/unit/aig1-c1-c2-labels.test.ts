import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  LOOKBACK_EXPLANATION,
  RECORD_ACTIONS,
  lookbackCountsText,
  notOpenText,
} from "@/features/ai/labels";

// AIG1-C1 / AIG1-C2 (ADR-130): texts of the look-back list and the record page. The rules stay in the database (0104).
const root = process.cwd();
const lookbackPage = readFileSync(
  join(root, "src/app/(protected)/operations/assistenten/rueckblick/[stopId]/page.tsx"),
  "utf8",
);
const recordActions = readFileSync(join(root, "src/app/(protected)/visits/[visitId]/lookback-actions.tsx"), "utf8");

describe("AIG1-C1 (2): a line of a visit no longer open", () => {
  it("is labelled as a fact of the visit, with its date", () => {
    expect(notOpenText("2026-10-29")).toBe("Besuch nicht mehr offen (Einsatz vom 29.10.2026)");
    expect(notOpenText(null)).toBe("Besuch nicht mehr offen");
  });

  it("is counted apart, and both counts are always shown side by side", () => {
    expect(lookbackCountsText(2, 1)).toBe("2 offen · 1 nicht mehr offen");
    expect(lookbackCountsText(0, 3)).toBe("0 offen · 3 nicht mehr offen");
    expect(lookbackCountsText(4, 0)).toBe("4 offen · 0 nicht mehr offen");
  });
});

describe("AIG1-C2 (c): the look-back page names only actions the product offers", () => {
  // Each action the explanation mentions, mapped to the control that offers it on the record page.
  const mentioned: Record<string, string> = {
    "erneut bestätigt": RECORD_ACTIONS.reconfirm,
    "ändert": RECORD_ACTIONS.change,
  };

  it("mentions re-confirming and changing, which the record page offers as one-by-one controls", () => {
    for (const [phrase, control] of Object.entries(mentioned)) {
      expect(LOOKBACK_EXPLANATION).toContain(phrase);
      expect(control.length).toBeGreaterThan(0);
    }
    expect(recordActions).toContain("RECORD_ACTIONS.reconfirm");
    expect(recordActions).toContain("RECORD_ACTIONS.change");
    expect(RECORD_ACTIONS).toEqual({ reconfirm: "Erneut bestätigen", change: "Ändern" });
  });

  it("names no action that neither page offers", () => {
    for (const word of ["erledigt", "abhaken", "abgehakt", "ablehnen", "abgelehnt", "entfernen", "löschen", "ankreuzen", "alle bestätigen", "Neustart"]) {
      expect(LOOKBACK_EXPLANATION.toLowerCase()).not.toContain(word.toLowerCase());
    }
  });

  it("the look-back page renders that explanation and has no control of its own", () => {
    expect(lookbackPage).toContain("{LOOKBACK_EXPLANATION}");
    expect(lookbackPage).not.toContain("Ein Wert verlässt die Liste, sobald er im Einsatz erneut");
    expect(lookbackPage).not.toMatch(/<button|<form|<input|<select/);
  });
});
