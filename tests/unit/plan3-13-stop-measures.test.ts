import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { daysToZeroText, leadTimeText, stopMeasureCells } from "@/features/ai/labels";

// PLAN3-13 (ADR-150, brief PLAN3 note 2026-10-31 02:25 and AUT-31 02:55): per stop and team, never per person, the
// look-back measure the PO decides P-39 and P-40 on. Counts of lines only; no person, outcome or confirmer column
// (AIG1-11); read through the existing AIG1 look-back scope (coordinators every team, a member her own teams).
const root = process.cwd();
const migration = readFileSync(join(root, "supabase/migrations/20261021000112_plan3_13_stop_measures.sql"), "utf8");
const page = readFileSync(join(root, "src/app/(protected)/operations/assistenten/rueckblick/[stopId]/page.tsx"), "utf8");

const row = {
  team_id: "t1",
  team_name: "Testteam F",
  lines_at_stop: 4,
  left_by_recheck: 0,
  superseded: 1,
  not_open_at_stop: 0,
  became_not_open: 1,
  open_now: 2,
  days_to_zero_open: null as number | null,
  proposals_in_window: 6,
  lead_time_median_hours: 120.5 as number | null,
};

describe("PLAN3-13 cells", () => {
  it("lists the six look-back counts and the lead time in a fixed order", () => {
    expect(stopMeasureCells(row)).toEqual([
      { key: "lines_at_stop", label: "Werte beim Stopp", value: "4" },
      { key: "left_by_recheck", label: "Erneut bestätigt oder geändert", value: "0" },
      { key: "superseded", label: "Überholt", value: "1" },
      { key: "not_open_at_stop", label: "Beim Stopp nicht mehr offen", value: "0" },
      { key: "became_not_open", label: "Seither nicht mehr offen", value: "1" },
      { key: "days_to_zero_open", label: "Tage bis 0 offen", value: "noch 2 offen" },
      { key: "lead_time", label: "Vorlauf Vorschlag bis Einsatz (Median)", value: "120.5 Std. · 6 Vorschläge" },
    ]);
  });

  it("names days until 0 offen only once nothing is open", () => {
    expect(daysToZeroText(0, 0)).toBe("am Tag des Stopps");
    expect(daysToZeroText(1, 0)).toBe("1 Tag");
    expect(daysToZeroText(3, 0)).toBe("3 Tage");
    expect(daysToZeroText(null, 1)).toBe("noch 1 offen");
    expect(daysToZeroText(5, 2)).toBe("noch 2 offen");
  });

  it("never shows a missing lead time as zero", () => {
    expect(leadTimeText(null, 0)).toBe("–");
    expect(leadTimeText(0, 3)).toBe("0 Std. · 3 Vorschläge");
    expect(leadTimeText(2, 1)).toBe("2 Std. · 1 Vorschlag");
  });
});

describe("PLAN3-13 migration and page", () => {
  it("adds one read-only function with no person, outcome or confirmer column", () => {
    expect(migration).toMatch(/create or replace function public\.agent_stop_measures\(p_stop_id uuid\)/);
    expect(migration).not.toMatch(/\b(insert|update|delete)\s+(into|public\.|from)/i);
    const returns = migration.match(/function public\.agent_stop_measures\(p_stop_id uuid\)\s*returns table \(([^)]*)\)/)?.[1] ?? "";
    expect(returns).toContain("lines_at_stop");
    expect(returns).not.toMatch(/confirm|outcome|user|person|member|actor|nurse|_by\b/);
  });

  it("keeps the AIG1 look-back scope (coordinator or the line's own team) and LEAVE1-3", () => {
    expect(migration).toMatch(/private\.is_coordinator\(st\.organization_id\) or private\.is_team_member\(l\.team_id\)/);
    expect(migration).toMatch(/not private\.access_ended/);
  });

  it("shows the measure on the stop's look-back page without a person column", () => {
    expect(page).toContain("getStopMeasures");
    expect(page).toContain('data-testid="stop-measures"');
    const section = page.slice(page.indexOf('data-testid="stop-measures"'), page.indexOf("</section>"));
    expect(section).toContain("stopMeasureCells");
    expect(section).not.toMatch(/bestätigt von|confirmed_by|display_name|member_name/);
  });
});
