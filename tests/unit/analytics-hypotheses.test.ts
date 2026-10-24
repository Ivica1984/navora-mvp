import { describe, expect, it } from "vitest";
import {
  BELOW_MINIMUM_NOTE,
  HYPOTHESIS_GROUPS,
  MEASURE,
  formatMeasure,
  measureLabel,
  orderGroupRows,
} from "@/features/analytics/hypotheses";

// AN2 part 2 (migration 0057, ADR-070): every measure the database returns has a label, a definition and a group.
const DB_MEASURES = [
  "coordinator_ends", "correction_versions_per_100", "correction_minutes_after_signature", "correction_unchanged_share",
  "correction_open_signals", "correction_open_hours", "correction_open_withdrawn_share", "correction_open_signed_share",
  "not_billable_facts", "not_billable_reason", "not_billable_days_to_billable", "visits_many_pauses", "visits_open_past_p1",
  "hold_lift_hours", "holds_still_open", "late_report_facts_share", "basis_changed_per_100",
];

describe("pilot hypotheses (AN2)", () => {
  it("defines every measure of the read model once, in exactly one hypothesis group", () => {
    const grouped = HYPOTHESIS_GROUPS.flatMap((g) => g.measures);
    expect(new Set(grouped).size).toBe(grouped.length);
    expect([...grouped].sort()).toEqual([...DB_MEASURES].sort());
    for (const m of DB_MEASURES) {
      expect(MEASURE[m]?.label, m).toBeTruthy();
      expect(MEASURE[m]?.definition, m).toBeTruthy();
    }
  });

  it("names its hypothesis, the challenge row it tests and the source for each group, by the brief's number", () => {
    expect(HYPOTHESIS_GROUPS.map((g) => g.no)).toEqual([3, 5, 6, 7, 9, 11, 12]);
    for (const g of HYPOTHESIS_GROUPS) {
      expect(g.hypothesis, String(g.no)).toBeTruthy();
      expect(g.challenge, String(g.no)).toBeTruthy();
      expect(g.source, String(g.no)).toBeTruthy();
    }
  });

  it("AN2-M7: the not-billable total says it leaves out the minimum-duration reason; the note names D-18", () => {
    expect(MEASURE.not_billable_facts.definition).toContain("Nicht enthalten: Fakten, deren einziger Grund die Mindestdauer ist");
    expect(BELOW_MINIMUM_NOTE).toBe("Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten.");
    expect(measureLabel("not_billable_reason", "below_minimum")).toBe("Grund: unter der Mindestdauer");
    expect(measureLabel("not_billable_reason", "no_insurer")).toBe("Grund: Krankenversicherer fehlt");
    expect(measureLabel("not_billable_reason", "none")).toBe("Grund: ohne Angabe");
  });

  it("puts the below_minimum row first among the reasons", () => {
    const g = HYPOTHESIS_GROUPS.find((x) => x.no === 7)!;
    const rows = [
      { measure: "not_billable_reason", detail: "no_insurer" },
      { measure: "not_billable_days_to_billable", detail: null },
      { measure: "not_billable_reason", detail: "below_minimum" },
      { measure: "not_billable_facts", detail: null },
    ];
    expect(orderGroupRows(g, rows).map((r) => r.detail ?? r.measure)).toEqual([
      "not_billable_facts", "below_minimum", "no_insurer", "not_billable_days_to_billable",
    ]);
  });

  it("formats values with their unit and never invents a figure", () => {
    expect(formatMeasure("correction_versions_per_100", 80)).toBe("80 pro 100");
    expect(formatMeasure("correction_minutes_after_signature", "25")).toBe("25 Min.");
    expect(formatMeasure("correction_unchanged_share", "50.0")).toBe("50 %");
    expect(formatMeasure("hold_lift_hours", 7.5)).toMatch(/^7[.,]5 Std\.$/);
    expect(formatMeasure("coordinator_ends", 2)).toBe("2");
    expect(formatMeasure("coordinator_ends", null)).toBe("–");
  });
});
