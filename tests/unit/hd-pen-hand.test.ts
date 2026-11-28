// HD-PEN-HAND (brief docs/agents/briefs/HD-PEN-HAND.md, ENG-PH1; ADR-232; migration 0190): «Stunden nicht prüfbar».
// The database decides the rule (pgTAP 188); these tests pin that the app knows the code, words it, carries it through
// the confirmation URL, marks stored shifts and never shows an unknown code as «undefined».
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  PLANNING_RULES,
  hoursUnknownCount,
  hoursUnknownCountText,
  hoursUnknownNext,
  isPlanningRule,
  parseRules,
  pensumMissingText,
  withoutPensumAndTarget,
  parseWarning,
  ruleText,
  ruleWarning,
  withKnownRules,
  withWarning,
  type Plan,
} from "@/features/home-plan/rules";

const ID = "00000000-0000-4000-a000-000000000001";

describe("HD-PEN-HAND hours_unknown", () => {
  it("is a known planning rule, last in the database order, with its own text", () => {
    expect(PLANNING_RULES.at(-1)).toBe("hours_unknown");
    expect(isPlanningRule("hours_unknown")).toBe(true);
    expect(parseRules("hours_unknown,shift_model")).toEqual(["shift_model", "hours_unknown"]);
    expect(ruleText("hours_unknown")).toMatch(/^Stunden nicht prüfbar/);
  });

  it("round-trips through the pending warning URL, so the lead can confirm it", () => {
    const url = withWarning("/heim?ansicht=woche", { staff: ID, station: ID, shift: ID, date: "2026-12-02", rules: ["hours_unknown"] });
    const w = parseWarning(new URL(url, "http://x").searchParams.get("warnung"));
    expect(w?.rules).toEqual(["hours_unknown"]);
  });

  it("marks a stored shift; «von Hand bestätigt» only when confirmed (backlog shifts stay unconfirmed)", () => {
    expect(ruleWarning({ rules: ["hours_unknown"], override_rules: ["hours_unknown"] })).toBe(
      `Regel: ${ruleText("hours_unknown")} (von Hand bestätigt)`,
    );
    expect(ruleWarning({ rules: ["hours_unknown"], override_rules: null })).toBe(`Regel: ${ruleText("hours_unknown")}`);
    // Pensum entered since: the code is gone from `rules`, a stale confirmation shows nothing.
    expect(ruleWarning({ rules: [], override_rules: ["hours_unknown"] })).toBeNull();
  });

  it("filters rule codes this app does not know from the plan answer (never «undefined»)", () => {
    const plan = {
      cells: [
        {
          assigned: [
            { assignment_id: "a", rules: ["future_rule", "rest"], override_rules: ["future_rule"] },
            { assignment_id: "b", rules: ["hours_unknown"], override_rules: null },
            { assignment_id: "c" },
          ],
        },
      ],
    } as unknown as Plan;
    const out = withKnownRules(plan);
    expect(out.cells[0].assigned.map((a) => [a.rules, a.override_rules])).toEqual([
      [["rest"], []],
      [["hours_unknown"], null],
      [[], null],
    ]);
    expect(ruleWarning(out.cells[0].assigned[0])).toBe("Regel: Ruhezeit zu kurz");
    expect(ruleWarning(out.cells[0].assigned[0])).not.toContain("undefined");
    // The input is not changed.
    expect((plan.cells[0].assigned[0].rules as string[])[0]).toBe("future_rule");
  });

  it("parity: the app knows exactly the codes the canonical rule source can return", () => {
    // STAB-1 canonical file = the definition the database holds (fn-source check in CI).
    const sql = readFileSync("supabase/schema/functions/private.institution_rule_breaches.sql", "utf8");
    const codes = [...sql.matchAll(/breaches := breaches \|\| '([a-z_]+)'::text/g)].map((m) => m[1]);
    // month_target_full and pensum_full are alternatives in one slot (file order differs from the list order).
    expect([...codes].sort()).toEqual([...PLANNING_RULES].sort());
    expect(codes.at(-1)).toBe("hours_unknown");
  });

  const base = {
    institution: { id: "h", display_name: "H", simulation: true, role: "lead" as const, weekly_target_hours: 42 },
    staff: [
      { id: "p", display_name: "Pia", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: null },
      { id: "q", display_name: "Quinn", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: 80 },
    ],
    month_targets: [] as Plan["month_targets"],
  };

  it("next action: names what is missing; the lead gets all links, Monatssoll and Wochensoll are marked lead-only", () => {
    const n = hoursUnknownNext(base, "p", "2027-03-10");
    expect(n?.reason).toBe("Für März 2027 ist kein Monatssoll und kein Pensum eingetragen.");
    expect(n?.actions.map((a) => [a.kind, a.lead_only])).toEqual([["pensum", false], ["month_target", true]]);
    const noWeekly = { ...base, institution: { ...base.institution, weekly_target_hours: null } };
    expect(hoursUnknownNext(noWeekly, "q", "2027-03-10")?.actions.map((a) => a.kind)).toEqual(["month_target", "weekly_target"]);
    expect(hoursUnknownNext(noWeekly, "p", "2027-03-10")?.reason).toContain("kein Pensum und kein Wochensoll des Heims");
    // Negative: hours checkable → no next action; a target for the month → none either (R-m checks).
    expect(hoursUnknownNext(base, "q", "2027-03-10")).toBeNull();
    const withTarget = { ...base, month_targets: [{ staff_id: "p", month: "2027-03-01", target_minutes: 600, planned_minutes: 0,
      remaining_minutes: 600, comparison_minutes: null, deviates: null }] };
    expect(hoursUnknownNext(withTarget, "p", "2027-03-10")).toBeNull();
    expect(hoursUnknownNext(withTarget, "p", "2027-04-01")).not.toBeNull();
  });

  it("count line: counts each stored shift once, confirmed ones too, and names the first person; none → zero", () => {
    const a = (id: string, staff: string, name: string, rules: string[], ov: string[] | null) =>
      ({ assignment_id: id, staff_id: staff, display_name: name, grade: "fage_efz", absent: false, inactive: false, rules, override_rules: ov });
    const plan = { cells: [
      { date: "2027-03-11", assigned: [a("1", "p", "Pia", ["hours_unknown"], ["hours_unknown"])] },
      { date: "2027-03-10", assigned: [a("2", "z", "Zoe", ["hours_unknown"], null), a("3", "q", "Quinn", ["rest"], null)] },
      { date: "2027-03-10", assigned: [a("2", "z", "Zoe", ["hours_unknown"], null), a("4", "b", "Ben", ["hours_unknown"], null)] },
    ] } as unknown as Plan;
    const n = hoursUnknownCount(plan);
    expect(n).toEqual({ shifts: 3, confirmed: 1, first: { staff_id: "b", date: "2027-03-10" } });
    // HD-PEN-HAND-F1 UXR-315: the line names the range it counts (see tests/unit/hd-pen-hand-f1.test.ts).
    expect(hoursUnknownCountText(n, "woche", "2027-03-08")).toBe("3 Dienste ohne Stundenprüfung in dieser Woche (davon 1 von Hand bestätigt)");
    expect(hoursUnknownCountText({ shifts: 1, confirmed: 0 }, "woche", "2027-03-08")).toBe("1 Dienst ohne Stundenprüfung in dieser Woche");
    expect(hoursUnknownCount({ cells: [{ date: "2027-03-10", assigned: [a("3", "q", "Quinn", ["rest"], null)] }] } as unknown as Plan))
      .toEqual({ shifts: 0, confirmed: 0, first: null });
  });

  it("UXR-310: refusal text and staff mark speak of Pensum and Monatssoll", () => {
    expect(pensumMissingText({ name: "Pia", shifts: 1 })).toBe(
      "Pia: 1 Dienst nicht übernommen, weil weder Pensum noch Monatssoll eingetragen ist. "
      + "Bitte bei der Person das Pensum oder das Monatssoll eintragen und neu vorschlagen.");
    expect(withoutPensumAndTarget(base, "p")).toBe(true);
    expect(withoutPensumAndTarget(base, "q")).toBe(false);
    expect(withoutPensumAndTarget({ ...base, month_targets: [{ staff_id: "p", month: "2027-03-01", target_minutes: 600,
      planned_minutes: 0, remaining_minutes: 600, comparison_minutes: null, deviates: null }] }, "p")).toBe(false);
  });
});
