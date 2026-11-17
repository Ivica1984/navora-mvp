import { describe, expect, it } from "vitest";
import { REASON_PREFIX, REASON_WORDS, reasonLine, teamOfferView, type TeamOrderOfferRow } from "@/features/orders/offer-rules";

// BK-c3 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-17 17:39; ADR-201). Written before the code (red first).
// Words: UX_REVIEW.md «Words for BK-c3» (`uxa`, PROPOSED) with UXR-233 (`member_free` only as the sole clause; no
// clause for `within_reach`). The database returns codes only (`team_order_offers().reasons`); this maps them.

function row(over: Partial<TeamOrderOfferRow> = {}): TeamOrderOfferRow {
  return {
    order_id: "o1",
    team_id: "t1",
    sentence: "Schichtauftrag · FaGe · Di 24.11.2026 08:00 – Di 24.11.2026 12:00 (4 Std.) · 4102 Binningen",
    starts_at: "2026-11-24T07:00:00Z",
    ends_at: "2026-11-24T11:00:00Z",
    duration_minutes: 240,
    postcode: "4102",
    place_name: "Binningen",
    grade: "fage_efz",
    activity_tags: [],
    required_tags: [],
    distance_km: 3,
    limit_km: 10,
    offer_state: "open",
    taken_member_id: null,
    taken_by: null,
    taken_at: null,
    acknowledged_at: null,
    latest_cover_at: "2026-11-24T03:00:00Z",
    caller_free: true,
    release_kind: null,
    released_member_id: null,
    reasons: [],
    ...over,
  };
}

describe("reason line (BK-c3)", () => {
  it("maps the codes word for word (uxa «Words for BK-c3»)", () => {
    expect(REASON_PREFIX).toBe("Empfohlen für euch: ");
    expect(REASON_WORDS).toEqual({
      knows_client: "ihr wart schon hier im Einsatz",
      member_free: "jemand von euch ist frei",
    });
  });

  it("shows «ihr wart schon hier im Einsatz» and drops member_free when another clause is there (UXR-233)", () => {
    expect(reasonLine(["member_free", "knows_client"])).toBe("Empfohlen für euch: ihr wart schon hier im Einsatz");
  });

  it("shows member_free only when it is the sole clause (UXR-233)", () => {
    expect(reasonLine(["member_free"])).toBe("Empfohlen für euch: jemand von euch ist frei");
  });

  it("shows no line without member_free, also not with knows_client alone (CGR-238 (c), UXR-234, PO 19:39)", () => {
    expect(reasonLine(["knows_client"])).toBeNull();
    expect(reasonLine(["knows_client", "rank_1"])).toBeNull();
  });

  it("shows no line on a card where nobody of the team can go (UXR-234, CGR-238 (c))", () => {
    const nobodyBoth = teamOfferView(row({ reasons: ["member_free", "knows_client"] }), "me", new Map(), []);
    expect(nobodyBoth.kind).toBe("offer");
    if (nobodyBoth.kind === "offer") {
      expect(nobodyBoth.nobodyLine).not.toBeNull();
      expect(nobodyBoth.reasonLine).toBeNull();
    }
    const nobodyKnows = teamOfferView(row({ reasons: ["knows_client"] }), "me", new Map(), []);
    if (nobodyKnows.kind === "offer") expect(nobodyKnows.reasonLine).toBeNull();
    const nobodyFree = teamOfferView(row({ reasons: ["member_free"] }), "me", new Map(), []);
    if (nobodyFree.kind === "offer") expect(nobodyFree.reasonLine).toBeNull();
  });

  it("shows nothing for no clause, an unknown code, or a code that explains nothing (K-2)", () => {
    expect(reasonLine([])).toBeNull();
    expect(reasonLine(null)).toBeNull();
    expect(reasonLine(undefined)).toBeNull();
    expect(reasonLine(["rank_1"])).toBeNull();
    expect(reasonLine(["within_reach"])).toBeNull();
    expect(reasonLine(["holds_all_tags"])).toBeNull();
    expect(reasonLine(["language"])).toBeNull();
    expect(reasonLine(["score", "member_free"])).toBe("Empfohlen für euch: jemand von euch ist frei");
  });

  it("never carries a number, a rank, a percentage or another team", () => {
    for (const codes of [["member_free"], ["member_free", "knows_client"]]) {
      const line = reasonLine(codes) ?? "";
      expect(line).not.toMatch(/\d|%|Rang|Platz|Punkte|Teams?\b|zuerst|besser/);
    }
  });

  it("puts the line on an open offer card only", () => {
    const open = teamOfferView(row({ reasons: ["member_free", "knows_client"] }), "me", new Map(), [{ user_id: "me", is_caller: true }]);
    expect(open.kind).toBe("offer");
    if (open.kind === "offer") expect(open.reasonLine).toBe("Empfohlen für euch: ihr wart schon hier im Einsatz");

    const none = teamOfferView(row({ reasons: [] }), "me", new Map(), [{ user_id: "me", is_caller: true }]);
    if (none.kind === "offer") expect(none.reasonLine).toBeNull();

    const missing = teamOfferView(row({ reasons: undefined }), "me", new Map(), [{ user_id: "me", is_caller: true }]);
    if (missing.kind === "offer") expect(missing.reasonLine).toBeNull();

    const taken = teamOfferView(
      row({ offer_state: "taken_by_us", taken_member_id: "me", taken_by: "me", acknowledged_at: "2026-11-21T11:00:00Z", reasons: ["knows_client"] }),
      "me",
      new Map(),
      [],
    );
    expect(taken.kind).toBe("taken");
    expect(JSON.stringify(taken)).not.toContain("Empfohlen");
  });
});
