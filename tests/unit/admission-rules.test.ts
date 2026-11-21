import { describe, expect, it } from "vitest";
import {
  OBJECTION_LABEL, OBJECTION_REASONS, PENSUM_BANDS, availableDecisions, awaitingContract, consentLine, readAdminAdmissions,
  readTeamAdmissions, zurichDate, type AdminProposal,
} from "@/features/admission/rules";

// ADM2 part (a) (migration 0091, ADR-114): the UI only reads and words the database's result.
describe("admission rules", () => {
  it("offers exactly the brief's Pensum bands and objection codes (no free text)", () => {
    expect([...PENSUM_BANDS]).toEqual(["20-40", "40-60", "60-80", "80-100"]);
    expect([...OBJECTION_REASONS]).toEqual(["team_full", "availability_mismatch", "qualification_mix", "wants_to_meet_first"]);
    for (const r of OBJECTION_REASONS) expect(OBJECTION_LABEL[r]).toBeTruthy();
  });

  it("reads null (no access) as null and keeps only object rows", () => {
    expect(readTeamAdmissions(null)).toBeNull();
    expect(readAdminAdmissions("x")).toBeNull();
    const t = readTeamAdmissions({ enabled: true, consents_needed: 2, lapse_days: 14, proposals: [{ proposal_id: "a" }, 3, null] });
    expect(t?.enabled).toBe(true);
    expect(t?.proposals).toHaveLength(1);
  });

  it("words the consent count the database computed", () => {
    expect(consentLine({ consents: 1, needed: 2 })).toBe("1 von 2 Zustimmungen");
    expect(consentLine({ consents: 0, needed: 1 })).toBe("0 von 1 Zustimmung");
  });

  it("offers the decisions the database accepts on an open proposal", () => {
    expect(availableDecisions({ outcome: null, proposed_by_me: true, my_stance: null })).toEqual(["withdraw_proposal"]);
    expect(availableDecisions({ outcome: null, proposed_by_me: false, my_stance: null })).toEqual(["consent", "objection"]);
    expect(availableDecisions({ outcome: null, proposed_by_me: false, my_stance: "objection" })).toEqual(["withdraw_objection"]);
    expect(availableDecisions({ outcome: null, proposed_by_me: false, my_stance: "consent" })).toEqual(["objection"]);
    expect(availableDecisions({ outcome: null, proposed_by_me: false, my_stance: "objection_withdrawn" })).toEqual(["consent", "objection"]);
    expect(availableDecisions({ outcome: "admitted", proposed_by_me: false, my_stance: null })).toEqual([]);
  });

  it("lists only admitted proposals for 'Vertrag erfassen'", () => {
    const row = (outcome: AdminProposal["outcome"]): AdminProposal => ({
      proposal_id: outcome, team_id: "t", team: "Team", created_at: "2026-10-29T09:00:00Z", outcome, outcome_at: null,
      display_name: null, claimed_qualification: null, pensum_band: null,
    });
    expect(awaitingContract([row("open"), row("admitted"), row("lapsed"), row("contract_recorded")]).map((r) => r.outcome))
      .toEqual(["admitted"]);
  });

  it("shows the Zurich calendar date of an instant", () => {
    expect(zurichDate("2026-11-03T23:30:00Z")).toBe("04.11.2026");
    expect(zurichDate("2026-07-01T21:59:00Z")).toBe("01.07.2026");
  });
});
