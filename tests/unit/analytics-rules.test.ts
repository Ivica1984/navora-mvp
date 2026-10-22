import { describe, expect, it } from "vitest";
import { KPI, KPI_ORDER, formatKpi } from "@/features/analytics/rules";

// AN1: every KPI the database returns has a definition and a source on the page.
describe("analytics rules (AN1)", () => {
  it("defines every KPI with a label, definition and source", () => {
    for (const key of KPI_ORDER) {
      expect(KPI[key]?.label, key).toBeTruthy();
      expect(KPI[key]?.definition, key).toBeTruthy();
      expect(KPI[key]?.source, key).toBeTruthy();
    }
  });

  it("formats values with their unit and never invents a figure", () => {
    expect(formatKpi("direct_care_share", 75)).toBe("75 %");
    expect(formatKpi("direct_care_share", "62.5")).toMatch(/^62[.,]5 %$/);
    expect(formatKpi("referral_to_first_visit_days", 2.25)).toMatch(/^2[.,][23] Tage$/);
    expect(formatKpi("distinct_nurses_per_client", 1.5)).toMatch(/^1[.,]5$/);
    expect(formatKpi("p1_median_close_hours", null)).toBe("–");
  });
});
