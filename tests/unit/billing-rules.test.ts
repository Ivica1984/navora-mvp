import { describe, expect, it } from "vitest";
import { NOT_BILLABLE_LABEL, formatChf, monthStart, notBillableText, parseNotBillable } from "@/features/billing/rules";

describe("J5 billing preview helpers", () => {
  it("labels every non-billable reason the database returns", () => {
    for (const r of ["quality_hold", "report_not_final", "not_generated", "b_without_valid_order", "no_insurer",
      "below_minimum", "no_planned_minutes", "no_measured_time"]) {
      expect(NOT_BILLABLE_LABEL[r]).toBeTruthy();
    }
    expect(notBillableText(["no_insurer", "below_minimum"])).toBe("Krankenversicherer fehlt, unter der Mindestdauer");
    expect(notBillableText([])).toBe("Grund unbekannt");
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
