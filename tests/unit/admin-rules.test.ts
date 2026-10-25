import { describe, expect, it } from "vitest";
import {
  ACCESS_END_REASONS, ACCESS_REASON_LABEL, ACCESS_RESTORE_REASONS, ADMIN_MESSAGES, accessEndedNotice, accessStateByUser, allowedPriorities,
  changedLabel, checkRuleInput, countOpenReports, isValidEmail, openReportsText, readAccessEndResult, readRemovalResult, releasedNotice,
  RULES_INTRO, stricterHint,
} from "@/features/admin/rules";

// ADM1: client-side mirror of the safe ranges in private.exception_rule_range (migration 0059, CGR-39).
describe("admin rules (ADM1)", () => {
  // look-ahead (a window ahead of the visit): the 24 h hospital-discharge rule may grow to 96 h, never shrink.
  const hospital = { default_priority: "P1", default_amount: 24, default_escalate: null, min_amount: 24, max_amount: 96,
    max_escalate: null, amount_direction: "look_ahead", unit: "hours" };
  // delay (time after the visit ended): the 24 h report rule may shrink to 0, never grow.
  const report = { default_priority: "P3", default_amount: 24, default_escalate: null, min_amount: 0, max_amount: 24,
    max_escalate: null, amount_direction: "delay", unit: "hours" };
  const serious = { default_priority: "P2", default_amount: null, default_escalate: 4, min_amount: null, max_amount: null,
    max_escalate: 4, amount_direction: null };

  it("never offers a priority below the platform default", () => {
    expect(allowedPriorities("P1")).toEqual(["P1"]);
    expect(allowedPriorities("P2")).toEqual(["P1", "P2"]);
    expect(allowedPriorities("P3")).toEqual(["P1", "P2", "P3"]);
  });

  it("a look-ahead rule refuses a lower value: it would signal later (CGR-39)", () => {
    expect(checkRuleInput(hospital, "P1", 12, null)).toContain("Früher melden = mehr Stunden Vorlauf");
    expect(checkRuleInput(hospital, "P1", 12, null)).toContain("Sicherheitsausnahmen melden sich nie später als der Standard");
    expect(checkRuleInput(hospital, "P1", 0, null)).toContain("zwischen 24 und 96");
    expect(checkRuleInput(hospital, "P1", 48, null)).toBeNull();
    expect(checkRuleInput(hospital, "P1", 96, null)).toBeNull();
    expect(checkRuleInput(hospital, "P1", 97, null)).not.toBeNull();
    expect(checkRuleInput(hospital, "P2", 24, null)).not.toBeNull();
  });

  it("a delay rule refuses a higher value: it would signal later", () => {
    expect(checkRuleInput(report, "P3", 48, null)).toContain("Früher melden = weniger Stunden Wartezeit");
    expect(checkRuleInput(report, "P3", 12, null)).toBeNull();
    expect(checkRuleInput(report, "P3", 0, null)).toBeNull();
    expect(checkRuleInput(report, "P3", 1.5, null)).not.toBeNull();
  });

  it("says per rule which way is stricter, and the general rule stays", () => {
    expect(stricterHint("look_ahead", "days")).toBe("Früher melden = mehr Tage Vorlauf (weniger als der Standard ist nicht möglich).");
    expect(stricterHint("delay", "hours")).toBe("Früher melden = weniger Stunden Wartezeit (mehr als der Standard ist nicht möglich).");
    expect(stricterHint(null, null)).toBeNull();
    expect(RULES_INTRO).toContain("Sicherheitsausnahmen melden sich nie später als der Standard");
  });

  it("escalation never later; no escalation where the default has none", () => {
    expect(checkRuleInput(serious, "P2", null, 2)).toBeNull();
    expect(checkRuleInput(serious, "P2", null, 8)).toContain("Eskalation");
    expect(checkRuleInput(report, "P3", 24, 4)).not.toBeNull();
  });

  it("labels who changed a setting and when", () => {
    expect(changedLabel(true, null, null)).toBe("Standard");
    expect(changedLabel(false, "Anna", "2026-10-22T12:05:00Z")).toMatch(/^geändert von Anna am /);
  });

  it("checks e-mail shape", () => {
    expect(isValidEmail("a@b.ch")).toBe(true);
    expect(isValidEmail("kein-email")).toBe(false);
  });
});

// ADM1 changes: removing a member releases her future planned visits (migration 0036).
describe("member removal releases visits (ADM1 changes)", () => {
  it("reads the command result and the number released", () => {
    expect(readRemovalResult({ result: "ok", released: 3 })).toEqual({ code: "ok", released: 3 });
    expect(readRemovalResult({ result: "duplicate" })).toEqual({ code: "duplicate", released: 0 });
    expect(readRemovalResult({ result: "has_cases" })).toEqual({ code: "has_cases", released: 0 });
    expect(readRemovalResult({ result: "has_visit_in_progress" })).toEqual({ code: "has_visit_in_progress", released: 0 });
    expect(readRemovalResult({ result: "ok", released: -1 })).toEqual({ code: "ok", released: 0 });
    expect(readRemovalResult(null)).toEqual({ code: "failed", released: 0 });
    expect(readRemovalResult("ok")).toEqual({ code: "failed", released: 0 });
  });

  it("explains a refusal while a visit is in progress (CGR-10)", () => {
    expect(ADMIN_MESSAGES.has_visit_in_progress).toMatch(/Einsatz/);
  });

  it("explains a refusal while a report she owes is missing or unsigned (CGR-18)", () => {
    expect(readRemovalResult({ result: "has_unsigned_reports" })).toEqual({ code: "has_unsigned_reports", released: 0 });
    expect(ADMIN_MESSAGES.has_unsigned_reports).toMatch(/Bericht/);
    expect(ADMIN_MESSAGES.has_unsigned_reports).toMatch(/unterschreiben/);
  });

  it("says how many visits are now open in the team", () => {
    expect(releasedNotice(3)).toBe("Entfernt. 3 Einsätze sind jetzt offen im Team.");
    expect(releasedNotice(1)).toBe("Entfernt. 1 Einsatz ist jetzt offen im Team.");
    expect(releasedNotice(0)).toBe("Entfernt. Keine geplanten Einsätze betroffen.");
  });
});

describe("LEAVE1 (migrations 0074, 0075): access end and the open-work list", () => {
  it("reads the end_member_access result with her open reports by kind", () => {
    expect(readAccessEndResult({ result: "ok", push_subscriptions_removed: 1, open_reports: { unsigned: 1, correction_draft: 0, returned: 2 } }))
      .toEqual({ code: "ok", openReports: { unsigned: 1, correction_draft: 0, returned: 2 } });
    expect(readAccessEndResult({ result: "has_cases" })).toEqual({ code: "has_cases", openReports: null });
    expect(readAccessEndResult(null)).toEqual({ code: "failed", openReports: null });
    expect(readAccessEndResult({ result: "ok", open_reports: { unsigned: -1, returned: "x" } }).openReports)
      .toEqual({ unsigned: 0, correction_draft: 0, returned: 0 });
  });

  it("counts and describes open reports by kind", () => {
    const counts = countOpenReports([{ kind: "unsigned" }, { kind: "unsigned" }, { kind: "returned" }, { kind: "other" }]);
    expect(counts).toEqual({ unsigned: 2, correction_draft: 0, returned: 1 });
    expect(openReportsText(counts)).toBe("2 nicht unterschrieben · 1 zurückgegeben, offen");
    expect(openReportsText(countOpenReports([]))).toBe("keine offenen Berichte");
    expect(accessEndedNotice(counts)).toContain("Offen bleiben: 2 nicht unterschrieben");
    expect(accessEndedNotice({ unsigned: 0, correction_draft: 0, returned: 0 })).toBe("Zugang beendet. Keine offenen Berichte.");
  });

  it("takes the newest access event per person as her state", () => {
    const state = accessStateByUser([
      { user_id: "a", kind: "ended", reason_code: "employment_ended", created_at: "2026-10-20T08:00:00Z", seq: 1 },
      { user_id: "a", kind: "restored", reason_code: "ended_in_error", created_at: "2026-10-21T08:00:00Z", seq: 2 },
      { user_id: "b", kind: "ended", reason_code: "access_withdrawn", created_at: "2026-10-22T08:00:00Z", seq: 3 },
    ]);
    expect(state.a).toEqual({ ended: false, endedAt: null, reasonCode: null });
    expect(state.b).toEqual({ ended: true, endedAt: "2026-10-22T08:00:00Z", reasonCode: "access_withdrawn" });
  });

  it("labels every reason code and has messages for the refusals", () => {
    for (const code of [...ACCESS_END_REASONS, ...ACCESS_RESTORE_REASONS]) expect(ACCESS_REASON_LABEL[code]).toBeTruthy();
    for (const code of ["self", "has_cases", "has_visit_in_progress", "has_planned_visits", "rejected", "unchanged"]) {
      expect(ADMIN_MESSAGES[code]).toBeTruthy();
    }
  });
});
