// DOOR1 part (b) (migration 0073, ADR-086): the safety-alert value rules (code guard, form order, display).
import { describe, expect, it } from "vitest";
import {
  ALERT_SOURCES, ALERT_SOURCE_LABEL, ALERT_VALUES, CODE_REFUSED, alertHandoverLines, alertMetaLine, alertValueError,
  alertValueText, alertValueTone, looksLikeCode,
} from "@/features/door/rules";
import { ENTRY_TITLE, entryLines } from "@/features/handover/rules";

describe("DOOR1-4 code guard", () => {
  it("refuses four or more digits in a row, also with single separators (same pattern as private.looks_like_code)", () => {
    for (const note of ["Code 4711", "Safe 47 11", "4-7-1-1", "Tür 12.34", "4711 0815", "Schlüsselsafe:12345", "1/2/3/4", "12,34"]) {
      expect(looksLikeCode(note), note).toBe(true);
    }
  });

  it("lets house numbers, floors and short numbers pass", () => {
    for (const note of ["Schlüssel bei Nachbarin Nr. 12, 2. Stock", "Haus 3a", "Briefkasten links", "", "123", "12 3"]) {
      expect(looksLikeCode(note), note).toBe(false);
    }
    expect(looksLikeCode(null)).toBe(false);
    expect(looksLikeCode(undefined)).toBe(false);
  });

  it("refuses a code with the fixed text, only for a category that refuses codes", () => {
    expect(alertValueError("ja", "Synthetisch: Safe 4711 beim Eingang", true)).toBe(CODE_REFUSED);
    expect(CODE_REFUSED).toBe("Bitte keinen Code erfassen");
    expect(alertValueError("ja", "Synthetisch: Safe 4711 beim Eingang", false)).toBeNull();
    expect(alertValueError("nein", "früher 4-7-1-1", true)).toBe(CODE_REFUSED);
  });
});

describe("DOOR1-3 values", () => {
  it("mirrors the database lists", () => {
    expect([...ALERT_VALUES]).toEqual(["unbekannt", "nein", "ja"]);
    expect([...ALERT_SOURCES]).toEqual(["referral", "client", "relative", "doctor", "team"]);
    for (const s of ALERT_SOURCES) expect(ALERT_SOURCE_LABEL[s]).toBeTruthy();
  });

  it('"ja" needs the note, the note has at most 300 characters, the value is one of three', () => {
    expect(alertValueError("ja", "  ", true)).toMatch(/Schlüssel/);
    expect(alertValueError("ja", "Synthetisch: bei der Nachbarin links", true)).toBeNull();
    expect(alertValueError("unbekannt", "", true)).toBeNull();
    expect(alertValueError("nein", "x".repeat(301), true)).toMatch(/300/);
    expect(alertValueError("vielleicht", "", true)).toMatch(/ja, nein oder unbekannt/);
  });
});

describe("DOOR1-4 display", () => {
  it('offers "unbekannt" first and shows it distinct from "nein"', () => {
    expect(ALERT_VALUES[0]).toBe("unbekannt");
    expect(alertValueTone("unbekannt")).toBe("unknown");
    expect(alertValueTone("nein")).toBe("no");
    expect(alertValueTone("unbekannt")).not.toBe(alertValueTone("nein"));
    expect(alertValueTone("ja")).toBe("yes");
  });

  it('shows "nicht erfasst" when no value was recorded, never blank', () => {
    expect(alertValueText(null)).toBe("nicht erfasst");
    expect(alertValueText("")).toBe("nicht erfasst");
    expect(alertValueText(undefined)).toBe("nicht erfasst");
    expect(alertValueText("unbekannt")).toBe("unbekannt");
  });

  it("shows who, when (Europe/Zurich) and source", () => {
    const line = alertMetaLine({ actor_kind: "team", actor_name: "Synthetische Pflegefachperson", recorded_at: "2026-10-25T07:10:00Z", source: "relative" });
    expect(line).toBe("Synthetische Pflegefachperson · 25.10.2026, 08:10 · Quelle: Angehörige");
    expect(alertMetaLine({ actor_kind: "me", actor_name: null, recorded_at: "2026-10-25T07:10:00Z", source: "team" })).toMatch(/^von dir · .* · Quelle: Team$/);
    expect(alertMetaLine({ actor_kind: null, actor_name: null, recorded_at: null, source: null })).toBeNull();
  });
});

describe("DOOR1-7 HAND1", () => {
  it("names the entry and shows category, value, source and note", () => {
    expect(ENTRY_TITLE.safety_alert).toBe("Sicherheitshinweis erfasst");
    const detail = { label: "Schlüssel- und Zugangsregelung", value: "ja", source: "relative", note: "Synthetisch: bei der Nachbarin" };
    expect(alertHandoverLines(detail)).toEqual(["Schlüssel- und Zugangsregelung: ja", "Quelle: Angehörige", "Synthetisch: bei der Nachbarin"]);
    expect(entryLines("safety_alert", detail)).toEqual(alertHandoverLines(detail));
    expect(entryLines("safety_alert", { label: "Schlüssel- und Zugangsregelung", value: "unbekannt", source: "team", note: null }))
      .toEqual(["Schlüssel- und Zugangsregelung: unbekannt", "Quelle: Team"]);
  });
});
