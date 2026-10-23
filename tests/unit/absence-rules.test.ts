import { describe, expect, it } from "vitest";
import { ABSENCE_MESSAGES, TAKE_MESSAGES, absenceMemberLabel, formatAbsencePeriod, knownByLabel, resultOf } from "@/features/absence/rules";
import { entryLines } from "@/features/handover/rules";

// ABS1: labels only; the database records, releases, scopes and decides (migration 0046, pgTAP 046).
describe("absence rules (ABS1)", () => {
  it("shows a whole-day absence as days (the end is exclusive)", () => {
    // 2026-10-24 00:00 Zurich (CEST, UTC+2) to 2026-10-25 00:00 Zurich: one day.
    expect(formatAbsencePeriod("2026-10-23T22:00:00Z", "2026-10-24T22:00:00Z")).toBe("Sa., 24.10.");
    // Two days, across the switch to winter time (25.10., UTC+1 afterwards).
    expect(formatAbsencePeriod("2026-10-23T22:00:00Z", "2026-10-25T23:00:00Z")).toBe("Sa., 24.10. – So., 25.10.");
  });

  it("shows times when the absence does not cover whole days", () => {
    expect(formatAbsencePeriod("2026-10-24T06:00:00Z", "2026-10-24T10:00:00Z")).toBe("Sa., 24.10. 08:00 – Sa., 24.10. 12:00");
  });

  it("labels who is absent and who knows the client, never a reason", () => {
    expect(absenceMemberLabel("me")).toBe("Du");
    expect(absenceMemberLabel("Test Pflege")).toBe("Test Pflege");
    expect(knownByLabel(null)).toBeNull();
    expect(knownByLabel("me")).toBe("Du kennst die Klientin");
    expect(knownByLabel("Test Pflege")).toBe("Test Pflege kennt die Klientin");
  });

  it("maps every command result to a message", () => {
    expect(resultOf({ result: "overlaps", absence_id: "x" })).toBe("overlaps");
    expect(resultOf("ok")).toBe("failed");
    for (const code of ["overlaps", "in_past", "not_shorter", "already_ended", "rejected"]) expect(ABSENCE_MESSAGES[code]).toBeTruthy();
    for (const code of ["already_taken", "not_qualified", "absent", "not_open", "rejected"]) expect(TAKE_MESSAGES[code]).toBeTruthy();
    expect(TAKE_MESSAGES.already_taken).toContain("Bereits übernommen");
  });

  it("HAND1 shows a released visit as the fact only", () => {
    expect(entryLines("visit_released", { before: { date: "2026-10-24", start: "09:00:00", end: "09:30:00" }, after: {}, reason: null }))
      .toEqual(["Einsatz 24.10.2026 09:00–09:30 wieder offen im Team"]);
  });
});
