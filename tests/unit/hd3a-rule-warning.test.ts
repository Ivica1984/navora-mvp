// HD-3a slice 2c (FE-123 Q3): a hand assignment against a planning rule is a warning. These tests pin the words and
// the URL round trip of the pending warning; the database decides the rules (pgTAP 173).
import { describe, expect, it } from "vitest";
import {
  PLANNING_RULES,
  messageText,
  monthCode,
  parseRules,
  parseWarning,
  ruleWarning,
  withMessage,
  withWarning,
  type PersonDay,
} from "@/features/home-plan/rules";

const ID = "00000000-0000-4000-a000-000000000001";

describe("HD-3a rule warning", () => {
  it("keeps the database order of the rules and drops unknown words", () => {
    expect([...PLANNING_RULES]).toEqual(["shift_model", "rest", "consecutive", "pensum_full"]);
    expect(parseRules("pensum_full,rest,absent,x")).toEqual(["rest", "pensum_full"]);
    expect(parseRules(null)).toEqual([]);
  });

  it("carries the pending assignment in the URL and reads it back; malformed input is ignored", () => {
    const w = { staff: ID, station: ID, shift: ID, date: "2026-12-02", rules: ["shift_model", "rest"] as const };
    const url = withMessage(withWarning("/heim?ansicht=woche&datum=2026-12-02", { ...w, rules: [...w.rules] }), "rule_warning");
    const q = new URL(url, "http://x").searchParams;
    expect(q.get("meldung")).toBe("rule_warning");
    expect(parseWarning(q.get("warnung"))).toEqual({ ...w, rules: ["shift_model", "rest"] });
    expect(parseWarning(`${ID}~${ID}~${ID}~2026-12-02~`)).toBeNull();
    expect(parseWarning(`x~${ID}~${ID}~2026-12-02~rest`)).toBeNull();
    expect(parseWarning(`${ID}~${ID}~${ID}~2026-02-30~rest`)).toBeNull();
    expect(parseWarning(`${ID}~${ID}~${ID}~2026-12-02~rest~more`)).toBeNull();
  });

  it("drops the pending warning with any other message (after confirming or cancelling)", () => {
    const url = withMessage(`/heim?ansicht=woche&warnung=${ID}~${ID}~${ID}~2026-12-02~rest`, "assigned_with_warning");
    expect(new URL(url, "http://x").searchParams.get("warnung")).toBeNull();
    expect(messageText("rule_warning")?.kind).toBe("error");
    expect(messageText("assigned_with_warning")?.kind).toBe("ok");
  });

  it("words the warning of a stored shift; «von Hand bestätigt» only when every current rule was confirmed", () => {
    expect(ruleWarning({ rules: [], override_rules: null })).toBeNull();
    expect(ruleWarning({})).toBeNull();
    expect(ruleWarning({ rules: ["rest"], override_rules: ["rest"] })).toBe("Regel: Ruhezeit zu kurz (von Hand bestätigt)");
    expect(ruleWarning({ rules: ["shift_model", "rest"], override_rules: ["rest"] })).toBe(
      "Regel: Schichtmodell der Person passt nicht zu dieser Dienstart, Ruhezeit zu kurz",
    );
  });

  it("marks a shift with a warning in the month grid with «!»", () => {
    const day = (warning: string | null, counts = true, absent = false): PersonDay => ({
      date: "2026-12-02",
      absent,
      shifts: [{ assignment_id: "a", code: "S", label: "Spät", time: "14:30–23:00", station: "R", counts, warning }],
    });
    expect(monthCode(day(null))).toBe("S");
    expect(monthCode(day("Regel: Ruhezeit zu kurz"))).toBe("S!");
    expect(monthCode(day(null, false))).toBe("(S)");
    expect(monthCode(day("x", true, true))).toBe("A (S!)");
  });
});
