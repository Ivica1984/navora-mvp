import { describe, expect, it } from "vitest";
import {
  NOT_FOUND_TEXT,
  bulkConfirmLabel,
  fieldLabel,
  formatDate,
  formatShare,
  minReachedText,
  provenanceLine,
  proposedByText,
  refusalText,
  stateLabel,
  stopReasonText,
  supersededText,
  windowText,
} from "@/features/ai/labels";

// AIG1 part (b) (ADR-129): the texts of the proposal screens. The rules stay in the database (0097, 0103).
describe("AIG1-3 / AIG1-4: proposed values and their provenance", () => {
  it("names the agent on every proposed value and shows a missing value only as 'nicht gefunden'", () => {
    expect(proposedByText("Testassistent Bezugspflege")).toBe("vorgeschlagen von Testassistent Bezugspflege");
    expect(NOT_FOUND_TEXT).toBe("nicht gefunden");
    expect(fieldLabel("responsible_user_id")).toBe("Zuständig");
  });

  it("writes 'vorgeschlagen von <Agent> / bestätigt von <Name> am <Datum>'", () => {
    const base = { agent_name: "Testassistent Bezugspflege", not_found: false, confirmer_name: "Pflegekraft Team E" };
    expect(provenanceLine({ ...base, status: "bestätigt", confirmed_at: "2026-10-30" })).toBe(
      "vorgeschlagen von Testassistent Bezugspflege / bestätigt von Pflegekraft Team E am 30.10.2026",
    );
    expect(provenanceLine({ ...base, status: "geändert", confirmed_at: "2026-10-30" })).toBe(
      "vorgeschlagen von Testassistent Bezugspflege / geändert und bestätigt von Pflegekraft Team E am 30.10.2026",
    );
    expect(provenanceLine({ ...base, status: "abgelehnt", confirmed_at: "2026-10-30" })).toContain("abgelehnt von Pflegekraft Team E");
    expect(provenanceLine({ ...base, status: "offen", confirmer_name: null, confirmed_at: null })).toBe(
      "vorgeschlagen von Testassistent Bezugspflege / noch nicht bestätigt",
    );
  });

  it("a confirmed 'nicht gefunden' never turns into an empty value", () => {
    const line = provenanceLine({
      agent_name: "A",
      status: "nicht gefunden",
      not_found: true,
      confirmer_name: "B",
      confirmed_at: "2026-10-30",
    });
    expect(line).toBe("vorgeschlagen von A: nicht gefunden / bestätigt von B am 30.10.2026");
    expect(line).not.toMatch(/keine|: \//);
  });

  it("formats an instant in Europe/Zurich", () => {
    // 23:30 UTC on 30 October is 00:30 on 31 October in Zurich (CET).
    expect(formatDate("2026-10-30T23:30:00Z")).toBe("31.10.2026");
  });
});

describe("AIG1-5 / CGR-78 (b): the ticked list", () => {
  it("the confirm button names its count", () => {
    expect(bulkConfirmLabel(0)).toBe("0 angekreuzte Werte bestätigen");
    expect(bulkConfirmLabel(1)).toBe("1 angekreuzten Wert bestätigen");
    expect(bulkConfirmLabel(3)).toBe("3 angekreuzte Werte bestätigen");
  });

  it("a value the consuming command refuses stays open with its reason (AIG1-15)", () => {
    expect(refusalText("not_qualified")).toContain("Qualifikation");
    expect(refusalText("outside_contract")).toContain("Vertrag");
    expect(refusalText("absent")).toContain("abwesend");
    expect(refusalText("unexpected")).toBe("Nicht übernommen.");
  });
});

describe("AIG1-10 / AIG1-16: the health list", () => {
  it("shows state, reason, the written threshold and whether the minimum was reached", () => {
    expect(stateLabel("stopped")).toBe("gestoppt");
    expect(stopReasonText("threshold")).toContain("Schwelle");
    expect(stopReasonText("version_changed")).toContain("Version");
    expect(formatShare(33.33)).toMatch(/^33[.,]33 %$/);
    expect(formatShare(20)).toBe("20 %");
    expect(formatShare(null)).toBe("–");
    expect(windowText(7)).toBe("7 Tage");
    expect(minReachedText(true)).toBe("Mindestzahl im letzten Fenster erreicht: ja");
    expect(minReachedText(false)).toBe("Mindestzahl im letzten Fenster erreicht: nein");
    expect(minReachedText(null)).toContain("noch kein abgeschlossenes Fenster");
  });
});

describe("AIG1-13 (b) / AIG1-14: the look-back line", () => {
  it("labels a superseded value with its date and names no person", () => {
    expect(supersededText("2026-10-30")).toBe("überholt am 30.10.2026");
    expect(supersededText(null)).toBe("überholt");
  });
});
