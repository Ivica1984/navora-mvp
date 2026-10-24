import { describe, expect, it } from "vitest";
import {
  DECLINE_REASONS,
  DECLINE_REASON_LABEL,
  ESCALATION_REASON_LABEL,
  declineError,
  formatResponseDue,
  formatWeeklyHours,
} from "@/features/team/rules";

const NOW = Date.parse("2026-10-22T08:00:00Z");

describe("J2 decline reasons", () => {
  it("v1 list from the PO brief, each with a label", () => {
    expect([...DECLINE_REASONS]).toEqual(["capacity", "qualification", "distance", "other"]);
    for (const code of DECLINE_REASONS) expect(DECLINE_REASON_LABEL[code]).toBeTruthy();
  });

  it("a decline needs a code; 'other' needs a short text", () => {
    expect(declineError("", "")).toMatch(/Grund/);
    expect(declineError("weather", "")).toMatch(/Grund/);
    expect(declineError("other", " x ")).toMatch(/beschreiben/);
    expect(declineError("other", "Urlaub im Team")).toBeNull();
    expect(declineError("capacity", "")).toBeNull();
  });
});

describe("J2 offer facts", () => {
  it("expected hours are shown as stated, never guessed", () => {
    expect(formatWeeklyHours(6)).toBe("6 h/Woche");
    expect(formatWeeklyHours(3.5)).toBe("3.5 h/Woche");
    expect(formatWeeklyHours(null)).toBe("nicht erfasst");
  });

  it("response time: not configured, remaining, expired", () => {
    expect(formatResponseDue(null, NOW)).toBe("Antwortfrist nicht festgelegt");
    expect(formatResponseDue("2026-10-22T08:45:00Z", NOW)).toBe("Antwort in 45 min");
    expect(formatResponseDue("2026-10-22T12:00:00Z", NOW)).toBe("Antwort in 4 h");
    expect(formatResponseDue("2026-10-22T07:59:00Z", NOW)).toBe("Antwortfrist abgelaufen");
  });
});

describe("J2 escalation labels", () => {
  it("every escalation reason has a label (OPS1 derives the exceptions in the database)", () => {
    for (const r of ["no_eligible_team", "all_declined", "deadline_passed", "deadline_not_configured"]) {
      expect(ESCALATION_REASON_LABEL[r]).toBeTruthy();
    }
  });
});
