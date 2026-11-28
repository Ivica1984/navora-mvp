// PROBE HD-PEN-HAND-F1 (brief docs/agents/briefs/HD-PEN-HAND-F1.md; UXR-315 to UXR-318). RED BY DESIGN, DO NOT MERGE.
// Each test names one fault of «Stunden nicht prüfbar» on `recovery/main` 1638ba2c. The package PR replaces this file
// with the real positive, negative and permission tests (unit + e2e 390/1440 px); the probe only proves the faults exist.
// No database, no migration: the faults are text and navigation (brief «Rules and their input class»: no new rule).
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { hoursUnknownCountText, hoursUnknownNext, ruleText, ruleWarning, type Plan } from "@/features/home-plan/rules";

const PAGE = readFileSync("src/app/(protected)/heim/page.tsx", "utf8");
/** The source of one top-level function component of the page, up to the next top-level declaration. */
function component(name: string): string {
  const start = PAGE.indexOf(`function ${name}(`);
  expect(start, `${name} not found in heim/page.tsx`).toBeGreaterThan(-1);
  const rest = PAGE.slice(start + 1);
  const end = rest.search(/\n(?:function |const |export )/);
  return PAGE.slice(start, end < 0 ? undefined : start + 1 + end);
}

const STAFF = "00000000-0000-4000-a000-000000000001";
/** Pensum entered, no monthly target, no Wochensoll of the home: the cause is the home's value, not the person's. */
const weeklyMissing = {
  staff: [{ id: STAFF, display_name: "Ada Test", active: true, pensum_pct: 80 }],
  month_targets: [],
  institution: { weekly_target_hours: null },
} as unknown as Pick<Plan, "staff" | "month_targets" | "institution">;

describe("PROBE HD-PEN-HAND-F1 (red until the package lands)", () => {
  it("UXR-315: the count line names the range it counts (week or month), not a bare total", () => {
    // Today the function only gets counts; the page shows «2 Dienste ohne Stundenprüfung» above a week and a month.
    expect(hoursUnknownCountText({ shifts: 2, confirmed: 0 })).toMatch(/in dieser Woche|im [A-ZÄÖÜ][a-zäöü]+ \d{4}/);
  });

  it("UXR-316: the cause is known without a new query, yet the count-line link ignores it", () => {
    // Open question 2 of the brief: the plan answer already holds everything `hoursUnknownNext` needs.
    const gap = hoursUnknownNext(weeklyMissing, STAFF, "2026-12-02");
    expect(gap?.actions.map((a) => a.kind)).toEqual(["month_target", "weekly_target"]);
    // Fault: the line always links to the person's Pensum field (`#heim-staff-planning`), never asks for the cause.
    expect(component("HoursUnknownLine")).toContain("hoursUnknownNext(");
  });

  it("UXR-317: the stored-shift mark has one colon, not «Regel: Stunden nicht prüfbar: …»", () => {
    const mark = ruleWarning({ rules: ["hours_unknown"], override_rules: null }) ?? "";
    expect(mark.split(":").length - 1).toBeLessThanOrEqual(1);
  });

  it("UXR-317: the rule line and the reason do not both state the missing values", () => {
    const gap = hoursUnknownNext(weeklyMissing, STAFF, "2026-12-02");
    const said = (s: string) => /eingetragen/.test(s);
    expect(said(ruleText("hours_unknown")) && said(gap?.reason ?? "")).toBe(false);
  });

  it("UXR-318: the warning box says first that nothing is assigned yet", () => {
    expect(component("RuleWarning")).toContain("Noch nicht eingeteilt.");
  });

  it("UXR-318: a link from the box does not silently drop the pending assignment", () => {
    // The personHref / limitsHref given to RuleWarning are built by `href()`, which never carries `warnung`; the box
    // has no sentence saying the shift must be assigned again afterwards. One of the two must hold.
    const call = PAGE.slice(PAGE.indexOf("<RuleWarning "), PAGE.indexOf("/>", PAGE.indexOf("<RuleWarning ")));
    const carries = /warnung/.test(call);
    const says = /neu einteilen|erneut einteilen/.test(component("RuleWarning"));
    expect(carries || says).toBe(true);
  });

  it("UXR-318: the working-time sentence appears only when rest or consecutive days are affected", () => {
    const box = component("RuleWarning");
    const i = box.indexOf("Ruhezeit und Arbeitstage in Folge");
    expect(i).toBeGreaterThan(-1);
    // Today it is a plain <p> shown for every rule, «Stunden nicht prüfbar» alone included.
    expect(box.slice(Math.max(0, i - 200), i)).toMatch(/"rest"|"consecutive"/);
  });
});
