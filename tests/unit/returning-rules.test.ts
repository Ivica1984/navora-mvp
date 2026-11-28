import { describe, expect, it } from "vitest";
import { linkEffect, linkableLabel, returnReferralFacts, returningOfferText, reviewTaskLabel } from "@/features/returning/rules";

// RET1: labels only; linking, eligibility and the first-refusal window live in the database (migration 0034, pgTAP 034).
describe("returning client rules (RET1)", () => {
  it("describes a linkable case for the intake role", () => {
    expect(linkableLabel({ case_id: "c", client_name: "Testfall 08", lifecycle: "paused", team_name: "Testteam Nord",
      since: "2026-10-19T10:00:00Z", reason_code: "hospital_stay" }))
      .toBe("Testfall 08 · pausiert seit 19.10.2026 (Spitalaufenthalt) · Testteam Nord");
    expect(linkableLabel({ case_id: "c", client_name: null, lifecycle: "closed", team_name: null, since: null, reason_code: null }))
      .toBe("Fall ohne Namen · abgeschlossen · ohne Team");
  });

  it("says what the link does before it is confirmed", () => {
    expect(linkEffect("paused")).toContain("keine neue Teamsuche");
    expect(linkEffect("closed")).toContain("Das frühere Team erhält die Anfrage zuerst");
  });

  it("names the review task with the pause reason", () => {
    expect(reviewTaskLabel("hospital_stay")).toBe("Situation nach Spitalaufenthalt verändert: entscheiden, ob der Pflegeplan überprüft wird");
    expect(reviewTaskLabel(null)).toContain("nach der Pause");
  });

  it("labels the offer for the previous team, with its window", () => {
    expect(returningOfferText("2026-10-22T15:35:00Z")).toBe("Rückkehrende Klient:in: euer Team hat sie betreut. Vorrang für euer Team bis 22.10., 17:35.");
    expect(returningOfferText(null)).toBe("Rückkehrende Klient:in: euer Team hat sie betreut.");
  });

  // COND2-4 (migration 0088, ADR-102): the returning referral's level with its source and the referrer's date.
  it("shows the returning referral's level with its source and the referrer's date while the review is open", () => {
    expect(returnReferralFacts({ urgency: "hoch", return_urgency_source: "referrer_stated", return_referrer_requested_start: "2026-11-02" }))
      .toEqual({ urgencyLine: "Dringlichkeit: hoch (vom Zuweiser angegeben)", referrerStart: "2026-11-02" });
    expect(returnReferralFacts({ urgency: "niedrig", return_urgency_source: "unknown", return_referrer_requested_start: null }))
      .toEqual({ urgencyLine: "Dringlichkeit: niedrig (Quelle nicht erfasst)", referrerStart: null });
  });

  it("shows nothing once the review task is closed (the database returns no source)", () => {
    expect(returnReferralFacts({ urgency: "hoch", return_urgency_source: null, return_referrer_requested_start: null })).toBeNull();
  });
});
