import { describe, expect, it } from "vitest";
import {
  FACTS_LOCKED_HINT,
  REPORT_REJECTION_MESSAGE,
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

  it("a final report is never editable or signable, only correctable as a new version", () => {
    const view = reportView("completed", report({ status: "final", i_signed: true }));
    expect(view).toMatchObject({ tone: "final", actions: ["correct"] });
    expect(view?.actions).not.toContain("edit");
    expect(view?.actions).not.toContain("sign");
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
    ]) {
      expect(REPORT_REJECTION_MESSAGE[reason]).toBeTruthy();
    }
  });

  it("asks her to check the reloaded facts when they changed before signing (CGR-02)", () => {
    expect(reportRejectionMessage("facts_changed")).toContain("geändert");
    expect(reportRejectionMessage("facts_changed")).toContain("erneut unterschreiben");
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

  it("names the correction path in the hint", () => {
    expect(FACTS_LOCKED_HINT).toContain("Bericht korrigieren");
  });
});
