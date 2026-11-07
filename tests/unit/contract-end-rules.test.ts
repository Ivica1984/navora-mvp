import { describe, expect, it } from "vitest";
import {
  CONTRACT_END_MESSAGES, accessStartsText, caseRefLabel, caseReference, continuityAnchorId, contractEndLine, contractEndNotice, currentContracts, dayAfter,
  dayLabel, leaverHeadline, myContractEndText, readHandover, readMyContractEnd, readSuccessorItems, successorLine,
  successorTitle, withContractEnds, zurichDay,
} from "@/features/contract-end/rules";
import { parseAccessState } from "@/features/auth/access-state";
import { ACCESS_REASON_LABEL, lastEventAtByUser } from "@/features/admin/rules";
import { TAKE_MESSAGES } from "@/features/absence/rules";

// ADM2 part (b) (migration 0092, ADR-115): pure helpers. The database decides the window, the access end and the readers.

describe("dates", () => {
  it("labels and the day after (month and year ends)", () => {
    expect(dayLabel("2026-11-08")).toBe("08.11.2026");
    expect(dayLabel(null)).toBe("");
    expect(dayAfter("2026-10-31")).toBe("2026-11-01");
    expect(dayAfter("2026-12-31")).toBe("2027-01-01");
    expect(dayAfter("2028-02-28")).toBe("2028-02-29");
  });

  it("the Zurich day of an instant, across the clock change", () => {
    expect(zurichDay("2026-10-24T21:59:00Z")).toBe("2026-10-24"); // 23:59 CEST
    expect(zurichDay("2026-10-24T22:00:00Z")).toBe("2026-10-25"); // 00:00 CEST
    expect(zurichDay("2026-10-25T22:59:00Z")).toBe("2026-10-25"); // 23:59 CET
    expect(zurichDay("2026-10-25T23:00:00Z")).toBe("2026-10-26"); // 00:00 CET
  });
});

describe("currentContracts (the newest row is current)", () => {
  it("keeps the newest row per person and drops malformed dates", () => {
    const c = currentContracts([
      { user_id: "a", start_date: "2026-01-01", end_date: null, seq: 1 },
      { user_id: "a", start_date: "2026-01-01", end_date: "2026-11-30", seq: 3 },
      { user_id: "a", start_date: "2026-01-01", end_date: "2026-12-31", seq: 2 },
      { user_id: "b", start_date: null, end_date: "bad", seq: 1 },
    ]);
    expect(c.a).toEqual({ startDate: "2026-01-01", endDate: "2026-11-30" });
    expect(c.b).toEqual({ startDate: null, endDate: null });
  });
});

describe("administrator texts (ADM2-11, ADM2-13)", () => {
  it("before and after the end", () => {
    expect(contractEndLine({ startDate: null, endDate: "2026-11-30" }, "2026-10-29"))
      .toBe("Vertragsende 30.11.2026 · Zugang endet am 01.12.2026 ohne weiteren Schritt.");
    expect(contractEndLine({ startDate: null, endDate: "2026-10-27" }, "2026-10-29"))
      .toBe("Vertrag endete am 27.10.2026; Zugang beendet seit 28.10.2026 (Vertragsende).");
    expect(contractEndLine({ startDate: null, endDate: null }, "2026-10-29")).toBeNull();
    expect(contractEndLine(undefined, "2026-10-29")).toBeNull();
  });

  it("the release notice sums the teams and never carries a count of her days", () => {
    expect(contractEndNotice({ t1: 2, t2: 1 }, "2026-12-01"))
      .toBe("Vertragsende gespeichert. Ihr Zugang endet am 01.12.2026. 3 geplante Einsätze nach dem Vertragsende sind jetzt offen im Team.");
    expect(contractEndNotice({}, "2026-12-01")).toBe("Vertragsende gespeichert. Ihr Zugang endet am 01.12.2026.");
    expect(contractEndNotice({ t1: 1 }, null)).toContain("1 geplanter Einsatz nach dem Vertragsende ist jetzt offen im Team.");
  });

  it("every database result has a message; the take and plan codes are worded", () => {
    for (const code of ["rejected", "self", "admission_off", "in_past", "access_ended", "no_contract", "last_admin", "has_planned_visits"]) {
      expect(CONTRACT_END_MESSAGES[code]).toBeTruthy();
    }
    expect(TAKE_MESSAGES.outside_contract).toBe("Dieser Einsatz liegt nach deinem Vertragsende.");
    expect(ACCESS_REASON_LABEL.contract_end).toBe("Vertragsende");
  });

  it("shows an access her contract end ended, until an event on or after that day (restore)", () => {
    const contracts = { a: { startDate: null, endDate: "2026-10-27" }, b: { startDate: null, endDate: "2026-10-27" },
                        c: { startDate: null, endDate: "2026-10-29" } };
    const open = { ended: false, endedAt: null, reasonCode: null };
    const access = withContractEnds({ a: open, b: open }, contracts,
      { b: "2026-10-27T23:30:00Z" /* 00:30 on the 28th: a restore after the end */ }, "2026-10-29");
    expect(access.a).toEqual({ ended: true, endedAt: "2026-10-28", reasonCode: "contract_end" });
    expect(access.b).toEqual(open);
    expect(access.c).toBeUndefined(); // ends today: access ends tomorrow
    expect(lastEventAtByUser([
      { user_id: "x", kind: "ended", reason_code: "employment_ended", created_at: "2026-10-01T10:00:00Z", seq: 1 },
      { user_id: "x", kind: "restored", reason_code: "ended_in_error", created_at: "2026-10-02T10:00:00Z", seq: 2 },
    ])).toEqual({ x: "2026-10-02T10:00:00Z" });
  });
});

describe("handover list (ADM2-12, ADM2-15 a)", () => {
  it("reads the database list defensively", () => {
    const rows = readHandover([
      { user_id: "u", member_name: "Pflegekraft Bald", end_date: "2026-11-08", access_ends_on: "2026-11-09", teams: ["Testteam C"],
        cases: [{ case_id: "c", case_ref: "000261", team: "Testteam C", role: "deputy" }],
        visits: [{ case_ref: "000261", visit_date: "2026-11-01", team: "Testteam C", role: "responsible" }] },
      { user_id: "bad" },
      "x",
    ]);
    expect(rows).toHaveLength(1);
    expect(leaverHeadline(rows[0])).toBe("Pflegekraft Bald: Vertragsende 08.11.2026, Zugang endet am 09.11.2026");
    expect(caseRefLabel(rows[0].cases[0].case_ref)).toBe("Fall-Ref. 000261");
    expect(readHandover(null)).toEqual([]);
  });
});

describe("successor items (ADM2-15 b)", () => {
  it("names the step and the former colleague, never the client", () => {
    const [i] = readSuccessorItems([{ case_id: "c", case_ref: "000261", team_id: "t", team: "Testteam C", role: "primary",
                                      member_name: "Pflegekraft Vertragsende", access_ended_on: "2026-10-28" }, { role: "x" }]);
    expect(successorTitle("primary")).toBe("Bezugspflege neu bestimmen");
    expect(successorTitle("deputy")).toBe("Stellvertretung neu bestimmen");
    expect(successorLine(i)).toBe(
      "Fall-Ref. 000261 · Testteam C: Pflegekraft Vertragsende (Bezugspflege) hat keinen Zugang mehr seit 28.10.2026. Das Team bestimmt, wer übernimmt.");
    expect(readSuccessorItems("x")).toEqual([]);
  });
});

describe("her own notice (ADM2-14 a) and the start date (ADM2-6)", () => {
  it("reads and words the end", () => {
    const c = readMyContractEnd({ end_date: "2026-11-12", access_ends_on: "2026-11-13" });
    expect(c).toEqual({ end_date: "2026-11-12", access_ends_on: "2026-11-13" });
    expect(myContractEndText(c!)).toBe(
      "Dein Vertrag endet am 12.11.2026. Ab 13.11.2026 hast du keinen Zugang mehr zu NAVORA. Exportiere vorher deine bestätigten Arbeitstage.");
    expect(readMyContractEnd(null)).toBeNull();
    expect(readMyContractEnd({ end_date: "x" })).toBeNull();
  });

  it("the access screen names the start date before the contract starts", () => {
    expect(parseAccessState({ ended: true, ended_at: null, starts_on: "2026-11-02" }))
      .toEqual({ ended: true, endedAt: null, startsOn: "2026-11-02" });
    expect(parseAccessState({ ended: false, ended_at: null, starts_on: null })).toEqual({ ended: false, endedAt: null });
    expect(accessStartsText("2026-11-02")).toBe("Ihr Zugang beginnt am 02.11.2026, mit Ihrem Vertragsbeginn.");
  });
});

describe("ADM2-15 (c): the card's case reference equals private.case_reference (pgTAP 092 pins the same ids)", () => {
  it("takes the last six hex digits of the id, upper case", () => {
    expect(caseReference("00000000-0000-4000-a000-000000000261")).toBe("000261");
    expect(caseReference("3f2504e0-4f89-11d3-9a0c-0305e82c3301")).toBe("2C3301");
    expect(caseRefLabel(caseReference("3f2504e0-4f89-11d3-9a0c-0305e82c3301"))).toBe("Fall-Ref. 2C3301");
  });
  it("anchors the case card's Kontinuität section by case id", () => {
    expect(continuityAnchorId("00000000-0000-4000-a000-000000000261")).toBe("kontinuitaet-00000000-0000-4000-a000-000000000261");
  });
});
