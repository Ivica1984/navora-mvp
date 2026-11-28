// HD-PEN-HAND-F1 (brief docs/agents/briefs/HD-PEN-HAND-F1.md; UXR-315 to UXR-318): «Stunden nicht prüfbar» says its
// range, its cause and its consequence. No new rule, no migration: the database decides `hours_unknown` (pgTAP 188);
// these tests pin the text and navigation the app builds from the plan answer. Replaces the red probe of #1880.
import { describe, expect, it } from "vitest";
import {
  WARNING_RETURN_CODES,
  hoursUnknownCountText,
  hoursUnknownFirstNote,
  hoursUnknownNext,
  hoursUnknownSteps,
  keepsWarning,
  parseWarning,
  ruleText,
  ruleWarning,
  showsWorkingTimeNote,
  warningReturned,
  withMessage,
  withWarning,
  type Plan,
} from "@/features/home-plan/rules";

const ID = "00000000-0000-4000-a000-000000000001";
const base = {
  institution: { id: "h", display_name: "H", simulation: true, role: "lead" as const, weekly_target_hours: 42 },
  staff: [
    { id: "p", display_name: "Pia", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: null },
    { id: "q", display_name: "Quinn", grade: "fage_efz", home_station_id: null, active: true, pensum_pct: 80 },
  ],
  month_targets: [] as Plan["month_targets"],
} as unknown as Pick<Plan, "staff" | "month_targets" | "institution">;
const noWeekly = { ...base, institution: { ...base.institution, weekly_target_hours: null } } as typeof base;

describe("HD-PEN-HAND-F1 UXR-315: the count line names its range", () => {
  it("week and month (positive)", () => {
    expect(hoursUnknownCountText({ shifts: 2, confirmed: 0 }, "woche", "2026-11-30")).toBe("2 Dienste ohne Stundenprüfung in dieser Woche");
    expect(hoursUnknownCountText({ shifts: 1, confirmed: 1 }, "monat", "2026-12-01"))
      .toBe("1 Dienst ohne Stundenprüfung im Dezember 2026 (davon 1 von Hand bestätigt)");
    expect(hoursUnknownCountText({ shifts: 3, confirmed: 0 }, "monat", "2027-03-01")).toBe("3 Dienste ohne Stundenprüfung im März 2027");
  });
  it("never reads as a home-wide total (negative)", () => {
    for (const t of [hoursUnknownCountText({ shifts: 2, confirmed: 0 }, "woche", "2026-11-30"),
      hoursUnknownCountText({ shifts: 2, confirmed: 0 }, "monat", "2026-12-01")]) {
      expect(t).toMatch(/ (in dieser Woche|im [A-ZÄÖÜ][a-zäöü]+ \d{4})( \(|$)/);
      expect(t).not.toMatch(/insgesamt|im Heim/);
    }
  });
});

describe("HD-PEN-HAND-F1 UXR-316: the count line's step comes from the same cause as the warning", () => {
  it("Pensum missing: link to that person, for the lead and the planner", () => {
    expect(hoursUnknownSteps(base, { staff_id: "p", date: "2027-03-10" }, true))
      .toEqual([{ kind: "person", staff_id: "p", date: "2027-03-10", label: "Pensum von Pia eintragen" }]);
    expect(hoursUnknownSteps(base, { staff_id: "p", date: "2027-03-10" }, false).map((s) => s.kind)).toEqual(["person"]);
  });
  it("Wochensoll missing: the lead gets «Wochensoll eintragen», never the person's Pensum field", () => {
    const steps = hoursUnknownSteps(noWeekly, { staff_id: "q", date: "2027-03-10" }, true);
    expect(steps).toEqual([{ kind: "weekly_target", label: "Wochensoll eintragen" }]);
    // The cause is the same one the warning box names.
    expect(hoursUnknownNext(noWeekly, "q", "2027-03-10")?.actions.map((a) => a.kind)).toContain("weekly_target");
  });
  it("Wochensoll missing, planner (permission): no settings link, the sentence who enters it", () => {
    const steps = hoursUnknownSteps(noWeekly, { staff_id: "q", date: "2027-03-10" }, false);
    expect(steps).toEqual([{ kind: "ask_lead", text: "Das Wochensoll des Heims fehlt; es trägt die Heimleitung ein." }]);
    expect(steps.some((s) => s.kind === "weekly_target")).toBe(false);
  });
  it("both missing: the home's Wochensoll first, then the person's Pensum", () => {
    expect(hoursUnknownSteps(noWeekly, { staff_id: "p", date: "2027-03-10" }, true).map((s) => s.kind)).toEqual(["weekly_target", "person"]);
    expect(hoursUnknownSteps(noWeekly, { staff_id: "p", date: "2027-03-10" }, false).map((s) => s.kind)).toEqual(["ask_lead", "person"]);
  });
  it("fallback: the mirror finds no gap although the row is flagged → the person, never nothing", () => {
    // Quinn has Pensum and the home a Wochensoll: `hoursUnknownNext` is null; the database still decides.
    expect(hoursUnknownSteps(base, { staff_id: "q", date: "2027-03-10" }, true))
      .toEqual([{ kind: "person", staff_id: "q", date: "2027-03-10", label: "Quinn ansehen" }]);
    expect(hoursUnknownSteps(base, { staff_id: "gone", date: "2027-03-10" }, true)[0]).toMatchObject({ kind: "person", label: "erste Person ansehen" });
  });
  it("the note says the link is the first of n, only when there are several", () => {
    expect(hoursUnknownFirstNote(1)).toBeNull();
    expect(hoursUnknownFirstNote(4)).toBe("Der Link öffnet den ersten von 4 Diensten.");
  });
});

describe("HD-PEN-HAND-F1 UXR-317: the gap is said once", () => {
  it("the rule is a label; the mark has one colon", () => {
    expect(ruleText("hours_unknown")).toBe("Stunden nicht prüfbar");
    expect(ruleWarning({ rules: ["hours_unknown"], override_rules: null })).toBe("Regel: Stunden nicht prüfbar");
    expect(ruleWarning({ rules: ["hours_unknown"], override_rules: ["hours_unknown"] })).toBe("Regel: Stunden nicht prüfbar (von Hand bestätigt)");
    for (const m of [ruleWarning({ rules: ["hours_unknown"], override_rules: null }), ruleWarning({ rules: ["rest", "hours_unknown"], override_rules: null })]) {
      expect((m ?? "").split(":").length - 1).toBe(1);
    }
  });
  it("only the reason names the missing values", () => {
    const reason = hoursUnknownNext(base, "p", "2027-03-10")?.reason ?? "";
    expect(reason).toBe("Für März 2027 ist kein Monatssoll und kein Pensum eingetragen.");
    expect(ruleText("hours_unknown")).not.toMatch(/Pensum|Monatssoll|Wochensoll|eingetragen/);
  });
});

describe("HD-PEN-HAND-F1 UXR-318: a link from the box keeps the pending assignment; nothing is confirmed after a return", () => {
  const pending = withWarning(`/heim?ansicht=personal&person=${ID}`, { staff: ID, station: ID, shift: ID, date: "2026-12-02", rules: ["hours_unknown"] });
  const warnung = (url: string) => new URL(url, "http://x").searchParams.get("warnung");

  it("the saves reached from the box keep `warnung` and mark the return", () => {
    expect([...WARNING_RETURN_CODES]).toEqual(["staff_planning_saved", "monthly_target_saved", "limits_saved"]);
    for (const code of WARNING_RETURN_CODES) {
      const url = withMessage(pending, code);
      expect(parseWarning(warnung(url))?.rules).toEqual(["hours_unknown"]);
      expect(warningReturned(code)).toBe(true);
    }
  });
  it("a fresh database warning keeps it, but is not a return (so it offers the confirmation again, no loop)", () => {
    expect(keepsWarning("rule_warning")).toBe(true);
    expect(warningReturned("rule_warning")).toBe(false);
    expect(warningReturned(undefined)).toBe(false);
  });
  it("assigned, an error or any other message drops it (negative)", () => {
    for (const code of ["assigned", "assigned_with_warning", "failed", "changed_meanwhile", "rejected", "absence_saved", "input_not_valid"]) {
      expect(warnung(withMessage(pending, code))).toBeNull();
      expect(warningReturned(code)).toBe(false);
    }
  });
  it("the working-time sentence only for rest and days in a row", () => {
    expect(showsWorkingTimeNote(["hours_unknown"])).toBe(false);
    expect(showsWorkingTimeNote(["shift_model", "pensum_full"])).toBe(false);
    expect(showsWorkingTimeNote(["rest"])).toBe(true);
    expect(showsWorkingTimeNote(["consecutive", "hours_unknown"])).toBe(true);
  });
});
