import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  LOOKBACK_EXPLANATION,
  NOT_OPEN_TEXT,
  NO_OTHER_MEMBER_TEXT,
  RECORD_ACTIONS,
  RECORD_ACTION_DONE,
  bulkResultText,
  lookbackCountsText,
  minReachedText,
  notOpenDatedText,
  recordBackLink,
} from "@/features/ai/labels";

// AIG1-C1 / AIG1-C2 / AIG1-C3 (ADR-130): texts of the look-back list, the record page and the confirm screen, as adopted
// by the PO 2026-10-31 00:10 CET from `uxa` 23:55. The rules stay in the database (0104).
const root = process.cwd();
const lookbackPage = readFileSync(
  join(root, "src/app/(protected)/operations/assistenten/rueckblick/[stopId]/page.tsx"),
  "utf8",
);
const recordActions = readFileSync(join(root, "src/app/(protected)/visits/[visitId]/lookback-actions.tsx"), "utf8");

describe("AIG1-C1 (2)/(3): a line of a visit no longer open", () => {
  it("is labelled as a fact of the Einsatz, with its date where the line carries none", () => {
    expect(NOT_OPEN_TEXT).toBe("Einsatz nicht mehr offen");
    expect(notOpenDatedText("2026-10-29")).toBe("Einsatz vom 29.10.2026 nicht mehr offen");
    expect(notOpenDatedText(null)).toBe("Einsatz nicht mehr offen");
  });

  it("is counted apart, and both counts are always shown side by side", () => {
    expect(lookbackCountsText(2, 1)).toBe("Werte: 2 offen · 1 nicht mehr offen");
    expect(lookbackCountsText(0, 3)).toBe("Werte: 0 offen · 3 nicht mehr offen");
    expect(lookbackCountsText(4, 0)).toBe("Werte: 4 offen · 0 nicht mehr offen");
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
    expect(lookbackPage).not.toMatch(/<button|<form|<input|<select/);
  });

  it("success says the value left the list", () => {
    expect(RECORD_ACTION_DONE.confirmed).toBe("Erneut bestätigt. Der Wert ist nicht mehr auf der Liste.");
    expect(RECORD_ACTION_DONE.corrected).toBe("Geändert und bestätigt. Der Wert ist nicht mehr auf der Liste.");
  });
});

describe("AIG1-C3", () => {
  const home = { href: "/field", label: "Mein Tag" };
  const stop = "00000000-0000-4000-a000-0000000006f1";

  it("(1) the record page returns to where the reader came from, from the link, never inferred", () => {
    expect(recordBackLink("rueckblick", stop, home)).toEqual({
      href: `/operations/assistenten/rueckblick/${stop}`,
      label: "Zurück zur Liste",
    });
    expect(recordBackLink("vorschlaege", null, home)).toEqual({ href: "/team/vorschlaege", label: "Zurück zu den Vorschlägen" });
    expect(recordBackLink(null, null, home)).toEqual(home);
    // A malformed stop id never becomes a link.
    expect(recordBackLink("rueckblick", "../../admin", home)).toEqual(home);
  });

  it("(2) the bulk result names both counts", () => {
    expect(bulkResultText(2, 1)).toBe("2 Werte bestätigt, 1 nicht übernommen.");
    expect(bulkResultText(3, 0)).toBe("3 Werte bestätigt.");
    expect(bulkResultText(1, 0)).toBe("1 Wert bestätigt.");
  });

  it("(4) null minimum flag and (5) unavailable 'Ändern'", () => {
    expect(minReachedText(null)).toBe("Noch kein Fenster abgeschlossen");
    expect(NO_OTHER_MEMBER_TEXT).toBe("Kein anderes Teammitglied wählbar.");
  });
});
