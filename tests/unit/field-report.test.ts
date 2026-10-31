import { describe, expect, it } from "vitest";
import {
  FACTS_LOCKED_HINT,
  RETURNED_LOCKED_HINT,
  REPORT_REJECTION_MESSAGE,
  countersignItemNote,
  returnConfirmation,
  reportRejectionMessage,
  reportView,
  visitFactsLocked,
  type FieldReport,
} from "@/features/field/report";

function report(overrides: Partial<FieldReport>): FieldReport {
  return {
    visit_id: "v1",
    report_id: "r1",
    version: 1,
    status: "draft",
    summary: null as unknown as string,
    snapshot: {},
    correction_reason: null as unknown as string,
    countersign_required: false,
    signed_at: null as unknown as string,
    countersigned_at: null as unknown as string,
    i_am_performer: true,
    i_signed: false,
    i_can_countersign: false,
    // ADM1 (migration 0035): names of signer and countersigner; null without a profile
    signed_by_name: null as unknown as string,
    countersigned_by_name: null as unknown as string,
    // CSR1 / CGR-02 (migration 0041): hash of the snapshot shown; sign_report carries it back
    snapshot_hash: "h1",
    // F6R (migration 0065): the return; reason, time, returner and returned version only for performer and team RNs
    returned: false,
    return_reason: null as unknown as string,
    returned_at: null as unknown as string,
    returned_by_name: null as unknown as string,
    returned_snapshot: null,
    i_can_return: false,
    // LEAVE1 (migration 0075): returned while the performer was unavailable; her access ended
    performer_unavailable: false,
    performer_access_ended: false,
    ...overrides,
  };
}

describe("reportView (F6)", () => {
  it("shows nothing before the visit is completed, nor for a visit ended as not completed (CGR-20)", () => {
    for (const status of ["planned", "on_the_way", "started", "paused", "interrupted", null]) {
      expect(reportView(status, null)).toBeNull();
    }
  });

  it("a completed visit without a report offers to create the draft", () => {
    expect(reportView("completed", null)).toMatchObject({ label: "Bericht nicht automatisch erstellt", actions: ["create"] });
    expect(reportView("completed", null)?.hint).toContain("kein Entwurf");
  });

  it("only the performer edits and signs a draft", () => {
    expect(reportView("completed", report({}))?.actions).toEqual(["edit", "sign"]);
    const other = reportView("completed", report({ i_am_performer: false }));
    expect(other?.actions).toEqual([]);
    expect(other?.hint).toContain("durchgeführt");
  });

  it("a signed report awaiting countersignature offers it only to an eligible registered nurse", () => {
    const signed = { status: "signed", countersign_required: true, i_am_performer: false };
    expect(reportView("completed", report({ ...signed, i_can_countersign: true }))?.actions).toEqual(["countersign"]);
    expect(reportView("completed", report({ ...signed, i_can_countersign: false }))?.actions).toEqual([]);
    expect(reportView("completed", report({ ...signed, i_am_performer: true }))?.hint).toContain("Pflegefachperson");
  });

  it("F6R-8: next to Gegenzeichnen a registered nurse may return the report, when the database allows it", () => {
    const signed = { status: "signed", countersign_required: true, i_am_performer: false, i_can_countersign: true };
    expect(reportView("completed", report({ ...signed, i_can_return: true }))?.actions).toEqual(["countersign", "return"]);
    expect(reportView("completed", report({ ...signed, i_can_return: false }))?.actions).toEqual(["countersign"]);
    expect(reportView("completed", report({ ...signed, i_can_countersign: false, i_can_return: true }))?.actions).toEqual([]);
  });

  it("F6R-5: a returned draft asks the performer to correct and sign again; nobody else acts on it", () => {
    const mine = reportView("completed", report({ version: 2, returned: true }));
    expect(mine).toMatchObject({ label: "Zurückgegeben: bitte korrigieren und neu unterschreiben (Fassung 2)", actions: ["edit", "sign"] });
    expect(mine?.actions).not.toContain("withdraw");
    const other = reportView("completed", report({ version: 2, returned: true, i_am_performer: false }));
    expect(other?.actions).toEqual([]);
    expect(other?.label).toContain("Zurückgegeben");
  });

  it("F6R-8: the confirmation names who gets the report back and when it becomes valid", () => {
    expect(returnConfirmation("Anna Test")).toBe(
      "Der Bericht geht an Anna Test zurück und wird erst nach erneuter Unterschrift und deiner Gegenzeichnung gültig.",
    );
    expect(returnConfirmation(null)).toContain("an die ausführende Person zurück");
  });

  it("a final report is never editable or signable, only correctable as a new version", () => {
    const view = reportView("completed", report({ status: "final", i_signed: true }));
    expect(view).toMatchObject({ tone: "final", actions: ["correct"] });
    expect(view?.actions).not.toContain("edit");
    expect(view?.actions).not.toContain("sign");
  });

  it("offers the performer to withdraw a correction draft, never a first draft (CGR-24-W)", () => {
    expect(reportView("completed", report({ version: 2, correction_reason: "Synthetisch" }))?.actions).toEqual(["edit", "sign", "withdraw"]);
    expect(reportView("completed", report({ version: 1 }))?.actions).not.toContain("withdraw");
    expect(reportView("completed", report({ version: 2, correction_reason: "Synthetisch", i_am_performer: false }))?.actions).toEqual([]);
    expect(reportView("completed", report({ version: 2, status: "signed", correction_reason: "Synthetisch" }))?.actions).not.toContain("withdraw");
  });

  it("labels later versions", () => {
    expect(reportView("completed", report({ version: 2 }))?.label).toBe("Entwurf (Fassung 2)");
  });

  it("an unknown status offers no action", () => {
    expect(reportView("completed", report({ status: "archived" }))?.actions).toEqual([]);
  });
});

describe("report rejection messages", () => {
  it("covers every reason code the migration returns", () => {
    for (const reason of [
      "not_team_member", "visit_not_completed", "no_performer", "draft_exists", "not_draft", "not_performer",
      "not_awaiting_countersignature", "rn_required", "own_report", "not_final", "not_latest", "facts_changed",
      "performer_not_in_team", "not_correction", "draft_has_changes", "awaiting_countersignature",
      "reason_too_short", "returned_report",
    ]) {
      expect(REPORT_REJECTION_MESSAGE[reason]).toBeTruthy();
    }
  });

  it("asks her to check the reloaded facts when they changed before signing (CGR-02)", () => {
    expect(reportRejectionMessage("facts_changed")).toContain("geändert");
    expect(reportRejectionMessage("facts_changed")).toContain("erneut unterschreiben");
  });

  it("explains a refused correction when the performer left the team, and that the final report stays (CGR-19)", () => {
    expect(reportRejectionMessage("performer_not_in_team")).toContain("nicht mehr zum Team");
    expect(reportRejectionMessage("performer_not_in_team")).toContain("bleibt gültig");
  });

  it("says why a correction draft with changes cannot be withdrawn (CGR-24-W)", () => {
    expect(reportRejectionMessage("draft_has_changes")).toContain("unterschrieben werden");
    expect(reportRejectionMessage("awaiting_countersignature")).toContain("Gegenzeichnung");
  });

  it("falls back to a generic message", () => {
    expect(reportRejectionMessage("something_else")).toBe("Bericht konnte nicht gespeichert werden.");
    expect(reportRejectionMessage(undefined)).toBe("Bericht konnte nicht gespeichert werden.");
  });
});

describe("visitFactsLocked (CSR1 / CGR-03, migration 0040)", () => {
  it("is open without a report and while the latest version is a draft (first draft or correction draft)", () => {
    expect(visitFactsLocked(null)).toBe(false);
    expect(visitFactsLocked(report({ status: "draft" }))).toBe(false);
    expect(visitFactsLocked(report({ status: "draft", version: 2 }))).toBe(false);
  });

  it("is locked once the latest version is signed or final", () => {
    expect(visitFactsLocked(report({ status: "signed", countersign_required: true }))).toBe(true);
    expect(visitFactsLocked(report({ status: "final" }))).toBe(true);
  });

  it("F6R-3: a returned draft is open only for its performer", () => {
    expect(visitFactsLocked(report({ status: "draft", version: 2, returned: true, i_am_performer: true }))).toBe(false);
    expect(visitFactsLocked(report({ status: "draft", version: 2, returned: true, i_am_performer: false }))).toBe(true);
    expect(visitFactsLocked({ status: "draft" })).toBe(false);
    expect(RETURNED_LOCKED_HINT).toContain("durchgeführt");
  });

  it("names the correction path in the hint", () => {
    expect(FACTS_LOCKED_HINT).toContain("Bericht korrigieren");
  });
});

describe("LEAVE1 (migration 0075): a performer who is no longer available", () => {
  it("LEAVE1-11: a version returned while its performer was unavailable offers nothing and is never final", () => {
    const view = reportView("completed", report({ status: "signed", countersign_required: true, i_am_performer: false,
      returned: true, performer_unavailable: true, i_can_countersign: false, i_can_return: false }));
    expect(view?.label).toBe("Zurückgegeben – Autorin nicht mehr verfügbar");
    expect(view?.actions).toEqual([]);
    expect(view?.hint).toContain("nicht verrechnet");
  });

  it("LEAVE1-5: her open draft names the access end to the team, never a reason", () => {
    const view = reportView("completed", report({ status: "draft", i_am_performer: false, performer_access_ended: true }));
    expect(view?.actions).toEqual([]);
    expect(view?.hint).toContain("Zugang beendet");
    const returned = reportView("completed", report({ status: "draft", version: 2, returned: true, i_am_performer: false,
      performer_access_ended: true }));
    expect(returned?.hint).toContain("Zugang beendet");
  });

  it("a signed report of a leaver still offers countersignature and return to a registered nurse", () => {
    const view = reportView("completed", report({ status: "signed", countersign_required: true, i_am_performer: false,
      i_can_countersign: true, i_can_return: true, performer_access_ended: true }));
    expect(view?.actions).toEqual(["countersign", "return"]);
  });

  it("the return confirmation says that no draft opens when her access ended", () => {
    expect(returnConfirmation("Anna Test", true)).toContain("nicht verrechnet");
    expect(returnConfirmation("Anna Test", true)).not.toContain("Anna Test");
  });

  it("has messages for the new refusals", () => {
    expect(reportRejectionMessage("performer_unavailable")).toContain("Zugang");
    expect(reportRejectionMessage("returned_performer_unavailable")).toContain("nicht abgeschlossen");
  });
});

describe("countersignItemNote (F6R-5, LEAVE1-5, LEAVE1-11)", () => {
  it("adds nothing to a report awaiting countersignature of a colleague with open access", () => {
    expect(countersignItemNote({ kind: "awaiting_countersignature", performer_name: "Anna Test", performer_access_ended: null })).toBeNull();
  });

  it("names a return to its performer, and the state when she was unavailable", () => {
    expect(countersignItemNote({ kind: "returned", performer_name: "Anna Test", performer_access_ended: null })).toBe("zurückgegeben an Anna Test");
    expect(countersignItemNote({ kind: "returned_performer_unavailable", performer_name: "Anna Test", performer_access_ended: "2026-10-25" }))
      .toBe("Zurückgegeben – Autorin nicht mehr verfügbar · Zugang beendet (25.10.2026)");
  });

  it("marks the open work of a member whose access ended with the date only", () => {
    expect(countersignItemNote({ kind: "unsigned", performer_name: "Anna Test", performer_access_ended: "2026-10-25" }))
      .toBe("nicht unterschrieben · Zugang beendet (25.10.2026)");
    expect(countersignItemNote({ kind: "correction_draft", performer_name: null, performer_access_ended: "2026-10-25" }))
      .toBe("Korrektur nicht unterschrieben · Zugang beendet (25.10.2026)");
  });

  it("falls back to the F6R flag when no kind is present", () => {
    expect(countersignItemNote({ returned: true, performer_name: null })).toBe("zurückgegeben");
  });
});
