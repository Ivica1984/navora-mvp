import { describe, expect, it } from "vitest";
import { REPORT_REJECTION_MESSAGE, reportRejectionMessage, reportView, type FieldReport } from "@/features/field/report";

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
    // ADM1 (migration 0029): names of signer and countersigner; null without a profile
    signed_by_name: null as unknown as string,
    countersigned_by_name: null as unknown as string,
    ...overrides,
  };
}

describe("reportView (F6)", () => {
  it("shows nothing before the visit is completed", () => {
    for (const status of ["planned", "on_the_way", "started", "paused", null]) {
      expect(reportView(status, null)).toBeNull();
    }
  });

  it("a completed visit without a report offers to create the draft", () => {
    expect(reportView("completed", null)).toMatchObject({ label: "Bericht fehlt", actions: ["create"] });
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
      "not_awaiting_countersignature", "rn_required", "own_report", "not_final", "not_latest",
    ]) {
      expect(REPORT_REJECTION_MESSAGE[reason]).toBeTruthy();
    }
  });

  it("falls back to a generic message", () => {
    expect(reportRejectionMessage("something_else")).toBe("Bericht konnte nicht gespeichert werden.");
    expect(reportRejectionMessage(undefined)).toBe("Bericht konnte nicht gespeichert werden.");
  });
});
