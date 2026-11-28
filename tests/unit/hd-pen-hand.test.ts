// HD-PEN-HAND (brief docs/agents/briefs/HD-PEN-HAND.md, ENG-PH1; ADR-232; migration 0190): «Stunden nicht prüfbar».
// The database decides the rule (pgTAP 188); these tests pin that the app knows the code, words it, carries it through
// the confirmation URL, marks stored shifts and never shows an unknown code as «undefined».
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  PLANNING_RULES,
  isPlanningRule,
  parseRules,
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
});
