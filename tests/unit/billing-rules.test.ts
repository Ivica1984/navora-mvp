import { describe, expect, it } from "vitest";
import { NOT_BILLABLE_LABEL, REFERENCE_NOT_VALIDATED, formatChf, monthStart, notBillableText, parseNotBillable } from "@/features/billing/rules";

describe("J5 billing preview helpers", () => {
  it("labels every non-billable reason the database returns", () => {
    for (const r of ["quality_hold", "report_not_final", "not_generated", "b_without_valid_order", "no_insurer",
      "below_minimum", "no_planned_minutes", "no_measured_time", "order_validity_missing", "order_expired", "payer_not_modelled",
      "order_recorded_after_visit"]) {
      expect(NOT_BILLABLE_LABEL[r]).toBeTruthy();
    }
    expect(notBillableText(["no_insurer", "below_minimum"])).toBe("Krankenversicherer fehlt, unter der Mindestdauer");
    expect(notBillableText([])).toBe("Grund unbekannt");
    expect(notBillableText(["order_expired", "payer_not_modelled"])).toBe("Verordnung abgelaufen, Kostenträger nicht abgebildet (nur KVG)");
    expect(notBillableText(["order_validity_missing", "order_recorded_after_visit"]))
      .toBe("Verordnung ohne Enddatum, Verordnung erst nach dem Besuchstag erfasst");
  });

  it("names unvalidated reference data and its open decisions (CGR-08)", () => {
    expect(REFERENCE_NOT_VALIDATED).toContain("nicht validiert");
    expect(REFERENCE_NOT_VALIDATED).toMatch(/D-11.*D-18/);
  });

  it("formats Swiss francs and leaves unknown amounts blank", () => {
    expect(formatChf(38.78)).toMatch(/38\.78/);
    expect(formatChf(null)).toBe("–");
  });

  it("parses the not-billable list defensively and finds the month start", () => {
    expect(parseNotBillable([{ visit_id: "v", date: "2026-10-22", client: null, reasons: [] }, null, { x: 1 }])).toHaveLength(1);
    expect(parseNotBillable("x")).toEqual([]);
    expect(monthStart("2026-10-22")).toBe("2026-10-01");
  });
});
