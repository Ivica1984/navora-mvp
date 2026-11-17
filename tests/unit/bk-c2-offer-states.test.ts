import { describe, expect, it } from "vitest";
import {
  ACK_FINAL_LINE,
  CANNOT_STEP,
  DECLINE_STEP,
  NOBODY_LINE,
  TAKE_FOOTER,
  clientCoverLines,
  firstName,
  shortName,
  teamOfferView,
  zurichDayTime,
  zurichTime,
  type TeamOrderOfferRow,
} from "@/features/orders/offer-rules";

// BK-c2 screens (brief docs/agents/briefs/BK.md 04:39 (3), (4); 05:39 (3); 08:39 (2)–(4); 09:39 (2) (d); ADR-200).
// Written before the code (red first). Words: BK5_OFFER_TEMPLATE.md §2–§4 and UX_REVIEW.md 07:52 (PROPOSED, `uxa`);
// the PO placed them for the simulation. Synthetic names only.

const ME = "00000000-0000-4000-a000-000000000001";
const COLLEAGUE = "00000000-0000-4000-a000-000000000002";
const NAMES = new Map([
  [ME, "Anna Muster"],
  [COLLEAGUE, "Beat Beispiel"],
]);

// 2026-11-21 is a Saturday; 06:00Z = 07:00 Zurich (CET).
const STARTS = "2026-11-21T06:00:00Z";
const LATEST = "2026-11-21T02:00:00Z";

function row(over: Partial<TeamOrderOfferRow> = {}): TeamOrderOfferRow {
  return {
    order_id: "o1",
    team_id: "t1",
    sentence: "Schichtauftrag · HF · Sa 21.11.2026 07:00 – Sa 21.11.2026 15:30 (8.5 Std.) · 4102 Binningen",
    starts_at: STARTS,
    ends_at: "2026-11-21T14:30:00Z",
    duration_minutes: 510,
    postcode: "4102",
    place_name: "Binningen",
    grade: "nurse_hf_fh",
    activity_tags: [],
    required_tags: [],
    distance_km: 3,
    limit_km: 10,
    offer_state: "open",
    taken_member_id: null,
    taken_by: null,
    taken_at: null,
    acknowledged_at: null,
    latest_cover_at: LATEST,
    caller_free: true,
    release_kind: null,
    released_member_id: null,
    ...over,
  };
}

describe("names and times", () => {
  it("shortens a display name to «Vorname N.» and never invents one", () => {
    expect(shortName("Anna Muster")).toBe("Anna M.");
    expect(shortName("Pflegekraft Assistenz Basel S")).toBe("Pflegekraft A.");
    expect(shortName("Anna")).toBe("Anna");
    expect(shortName(null)).toBe("Ein Teammitglied");
    expect(firstName("Beat Beispiel")).toBe("Beat");
    expect(firstName(undefined)).toBe("das Teammitglied");
  });

  it("writes Zurich day and time, never UTC", () => {
    expect(zurichDayTime(STARTS)).toBe("Sa 21.11., 07:00");
    expect(zurichTime("2026-11-20T13:31:00Z")).toBe("14:31");
    // Summer time: 2026-07-04 05:00Z = 07:00 Zurich (CEST).
    expect(zurichDayTime("2026-07-04T05:00:00Z")).toBe("Sa 04.07., 07:00");
  });
});

describe("team side (template §3, UXR-221, CGR-230, UXR-222, AUT-132, CGR-234 (d))", () => {
  it("an open offer: neutral broadcast line, the caller first and pre-selected when she is free", () => {
    const v = teamOfferView(row(), ME, NAMES, [
      { user_id: ME, is_caller: true },
      { user_id: COLLEAGUE, is_caller: false },
    ]);
    expect(v.kind).toBe("offer");
    if (v.kind !== "offer") return;
    expect(v.tag).toBe("Neues Angebot");
    expect(v.broadcast).toBe("Alle passenden Teams sehen dieses Angebot.");
    expect(v.candidates).toEqual([
      { userId: ME, label: "Ich (Anna)" },
      { userId: COLLEAGUE, label: "Beat B." },
    ]);
    expect(v.preselected).toBe(ME);
    expect(v.callerNotFree).toBeNull();
    expect(v.releaseLine).toBeNull();
  });

  it("an open offer the caller cannot take herself: one neutral line, never the reason, no «Ich» row", () => {
    const v = teamOfferView(row({ caller_free: false }), ME, NAMES, [{ user_id: COLLEAGUE, is_caller: false }]);
    if (v.kind !== "offer") throw new Error(v.kind);
    expect(v.callerNotFree).toBe("Du selbst kannst diese Schicht nicht übernehmen.");
    expect(v.candidates.map((c) => c.label)).toEqual(["Beat B."]);
    expect(v.preselected).toBeNull();
    expect(JSON.stringify(v)).not.toMatch(/Abwesen|Nachweis|Stunden|step|Stufe \d/i);
  });

  it("taken, the caller named herself: «Übernommen», no action", () => {
    const v = teamOfferView(row({ offer_state: "taken_by_us", taken_member_id: ME, taken_by: ME, taken_at: "2026-11-20T13:31:00Z", acknowledged_at: "2026-11-20T13:31:00Z" }), ME, NAMES, []);
    expect(v).toMatchObject({ kind: "taken", tag: "Übernommen", lines: ["Ihr habt diese Schicht übernommen. Es geht: Anna M."], actions: false });
  });

  it("taken, a colleague named, not yet acknowledged: the team sees who, by whom, until when (a fact, no countdown)", () => {
    const v = teamOfferView(row({ offer_state: "taken_by_us", taken_member_id: COLLEAGUE, taken_by: ME, taken_at: "2026-11-20T13:31:00Z" }), ME, NAMES, []);
    expect(v).toMatchObject({
      kind: "taken",
      tag: "Übernommen",
      lines: [
        "Es geht: Beat B. · Bestätigung ausstehend",
        "Übernommen von Anna M. um 14:31.",
        "Bestätigt Beat nicht bis Sa 21.11., 03:00, gilt die Übernahme nicht mehr.",
      ],
      actions: false,
    });
  });

  it("the named colleague's own card: «Für dich eingeteilt» with «Bestätigen» and «Ich kann nicht»", () => {
    const v = teamOfferView(row({ offer_state: "taken_by_us", taken_member_id: COLLEAGUE, taken_by: ME, taken_at: "2026-11-20T13:31:00Z" }), COLLEAGUE, NAMES, []);
    expect(v).toMatchObject({
      kind: "taken",
      tag: "Für dich eingeteilt",
      lines: ["Anna M. hat diese Schicht für euer Team übernommen und dich eingeteilt.", "Bitte bis Sa 21.11., 03:00 bestätigen."],
      actions: true,
      mine: true,
    });
  });

  it("acknowledged: the team reads «bestätigt um», her own card says she is assigned; no action", () => {
    const r = row({ offer_state: "taken_by_us", taken_member_id: COLLEAGUE, taken_by: ME, taken_at: "2026-11-20T13:31:00Z", acknowledged_at: "2026-11-20T14:02:00Z" });
    expect(teamOfferView(r, ME, NAMES, [])).toMatchObject({ lines: ["Es geht: Beat B. · bestätigt um 15:02"], actions: false });
    expect(teamOfferView(r, COLLEAGUE, NAMES, [])).toMatchObject({ lines: ["Du bist für diese Schicht eingeteilt."], actions: false, mine: true });
  });

  it("after «Ich kann nicht» the team sees the release and may choose again while the offer is still with it", () => {
    const v = teamOfferView(row({ release_kind: "member_cannot", released_member_id: COLLEAGUE }), ME, NAMES, [{ user_id: ME, is_caller: true }]);
    if (v.kind !== "offer") throw new Error(v.kind);
    expect(v.releaseLine).toBe("Nicht mehr übernommen: Beat B. kann diese Schicht nicht übernehmen.");
    expect(v.chooseLabel).toBe("Andere Person wählen");
  });

  it("UXR-226: nobody in the team can take: one line, no «Du selbst …», no primary button; «Ablehnen» stays", () => {
    const v = teamOfferView(row({ caller_free: false }), ME, NAMES, []);
    if (v.kind !== "offer") throw new Error(v.kind);
    expect(v.nobodyLine).toBe("Niemand in eurem Team kann diese Schicht zurzeit übernehmen.");
    expect(NOBODY_LINE).toBe(v.nobodyLine);
    expect(v.callerNotFree).toBeNull();
    expect(v.chooseLabel).toBeNull();
    expect(v.candidates).toEqual([]);
    expect(JSON.stringify(v)).not.toMatch(/Person wählen|Du selbst|erfüllt niemand/);
  });

  it("UXR-226 negative: with a candidate there is no «Niemand …» line and the primary stays", () => {
    const v = teamOfferView(row(), ME, NAMES, [{ user_id: ME, is_caller: true }]);
    if (v.kind !== "offer") throw new Error(v.kind);
    expect(v.nobodyLine).toBeNull();
    expect(v.chooseLabel).toBe("Person wählen");
  });

  it("UXR-224: the confirm steps carry one consequence sentence each; «Bestätigen» says it is final", () => {
    expect(CANNOT_STEP).toEqual({
      sentence: "Du gibst diese Schicht frei. Sie geht sofort an alle passenden Teams; du kannst sie danach nicht mehr übernehmen.",
      action: "Freigeben",
      back: "Zurück",
    });
    expect(DECLINE_STEP).toEqual({ sentence: "Euer Team sieht dieses Angebot danach nicht mehr.", action: "Ablehnen", back: "Zurück" });
    expect(ACK_FINAL_LINE).toBe("Mit dem Bestätigen bist du fest eingeteilt.");
  });

  it("UXR-228: the footer says when the client reads «Gedeckt»", () => {
    expect(TAKE_FOOTER).toBe(
      "Beim Übernehmen prüft NAVORA alle Bedingungen für die gewählte Person erneut. ‹Gedeckt› sieht der Auftraggeber, wenn diese Person geprüft ist und, falls ihr jemand anderen wählt, bestätigt hat.",
    );
  });

  it("a release with no new offer for the team: the line only, no action (CGR-234 (d))", () => {
    expect(teamOfferView(row({ offer_state: "released", release_kind: "not_acknowledged", released_member_id: COLLEAGUE }), ME, NAMES, [])).toEqual({
      kind: "released",
      line: "Die Übernahme gilt nicht mehr: Beat B. hat nicht bis 03:00 bestätigt.",
    });
    expect(teamOfferView(row({ offer_state: "released", release_kind: "no_longer_eligible", released_member_id: COLLEAGUE }), ME, NAMES, [])).toEqual({
      kind: "released",
      line: "Nicht mehr gedeckt: Beat B. erfüllt die Bedingungen für diese Schicht nicht mehr.",
    });
  });

  it("never words a countdown, a cascade, exclusivity or another team", () => {
    const views = [
      teamOfferView(row(), ME, NAMES, [{ user_id: ME, is_caller: true }]),
      teamOfferView(row({ offer_state: "taken_by_us", taken_member_id: COLLEAGUE, taken_by: ME, taken_at: "2026-11-20T13:31:00Z" }), ME, NAMES, []),
    ];
    for (const v of views) expect(JSON.stringify(v)).not.toMatch(/exklusiv|Kaskade|zuerst|als Nächstes|Vermittlung|Provision|noch \d+ (Std|Min)/i);
  });
});

describe("client side (template §4, F-1, UXR-223, CGR-226 (a))", () => {
  const base = { starts_at: STARTS, latest_cover_at: LATEST, covered_team_name: null, taken_at: null, grade: "fage_efz" };

  it("open: not covered yet, offered to all matching teams at once", () => {
    expect(clientCoverLines({ ...base, cover_state: "open", cover_detail: null })).toEqual({
      headline: "Noch nicht gedeckt · Beginn Sa 21.11., 07:00",
      detail: "Angebot an alle passenden Teams gleichzeitig.",
    });
  });

  it("UXR-223: before the acknowledgement the client never reads «Gedeckt»", () => {
    const l = clientCoverLines({ ...base, cover_state: "open", cover_detail: "awaiting_acknowledgement" });
    expect(l.headline).toBe("Noch nicht gedeckt · Beginn Sa 21.11., 07:00");
    expect(l.detail).toBe("Ein Team hat übernommen; die eingeteilte Person bestätigt noch.");
    expect(l.headline).not.toMatch(/^Gedeckt/);
  });

  it("covered: the ordered level, never the person's grade or «Pflegekraft»", () => {
    expect(clientCoverLines({ ...base, cover_state: "covered", cover_detail: null, covered_team_name: "Testteam Basel", taken_at: "2026-11-20T13:31:00Z" })).toEqual({
      headline: "Gedeckt · Person benannt, geprüft für FaGe",
      detail: "Team Testteam Basel · übernommen um 14:31",
    });
  });

  it("F-1: one neutral zero state; the client never reads which of the two causes", () => {
    const l = clientCoverLines({ ...base, cover_state: "not_covered", cover_detail: "no_team_free" });
    expect(l).toEqual({ headline: "Nicht gedeckt · Beginn Sa 21.11., 07:00", detail: "Kein passendes Team ist frei." });
    // Operations details never reach this function through client_orders(); if one did, it is not worded apart.
    for (const d of ["no_team_eligible", "all_declined"]) {
      expect(clientCoverLines({ ...base, cover_state: "not_covered", cover_detail: d })).toEqual(l);
    }
    expect(JSON.stringify(l)).not.toMatch(/abgelehnt|erfüllt kein Team|von \d|\d+ Teams?/);
  });

  it("coverage time reached, shift started, a named person dropped out", () => {
    expect(clientCoverLines({ ...base, cover_state: "not_covered", cover_detail: "cover_time_reached" })).toEqual({
      headline: "Nicht gedeckt · Beginn Sa 21.11., 07:00",
      detail: "Bis jetzt hat kein Team diese Schicht übernommen.",
    });
    expect(clientCoverLines({ ...base, cover_state: "not_covered", cover_detail: "started" })).toEqual({
      headline: "Nicht gedeckt · Die Schicht hat um 07:00 begonnen.",
      detail: null,
    });
    // UXR-225 (b) with `lca` F-2 (PO 12:39 (2)): after «Gedeckt» was shown, the detail names no person and no cause.
    expect(clientCoverLines({ ...base, cover_state: "no_longer_covered", cover_detail: null })).toEqual({
      headline: "Nicht mehr gedeckt · Beginn Sa 21.11., 07:00",
      detail: "Die Übernahme gilt nicht mehr. Das Angebot geht wieder an alle passenden Teams.",
    });
  });

  it("UXR-225 (a): a take that fell away before «Gedeckt» was ever shown reads «Noch nicht gedeckt», never «Nicht mehr gedeckt»", () => {
    const l = clientCoverLines({ ...base, cover_state: "open", cover_detail: "take_fell_away" });
    expect(l).toEqual({
      headline: "Noch nicht gedeckt · Beginn Sa 21.11., 07:00",
      detail: "Die eingeteilte Person kann nicht. Das Angebot geht wieder an alle passenden Teams.",
    });
    expect(JSON.stringify(l)).not.toMatch(/Nicht mehr gedeckt/);
  });

  it("`lca` F-2 negative: «Nicht mehr gedeckt» never carries a person or a cause", () => {
    const l = clientCoverLines({ ...base, cover_state: "no_longer_covered", cover_detail: null });
    expect(JSON.stringify(l)).not.toMatch(/Person kann nicht|Person|abwesend|krank|Nachweis|erfüllt/);
  });

  it("an unknown state is never shown as covered", () => {
    expect(clientCoverLines({ ...base, cover_state: "something", cover_detail: null }).headline).toBe("Noch nicht gedeckt · Beginn Sa 21.11., 07:00");
  });
});

describe("command answers on the team card", () => {
  it("words a lost race neutrally and never names a step or a reason about a person", async () => {
    const { offerCommandText, ALREADY_TAKEN_TEXT } = await import("@/features/orders/offer-rules");
    expect(offerCommandText("already_taken")).toBe(ALREADY_TAKEN_TEXT);
    for (const r of ["member_not_eligible", "not_offered", "order_started", "not_named", "self_named", "already_acknowledged", "no_live_take", undefined]) {
      expect(offerCommandText(r)).not.toMatch(/step|Stufe|Abwesen|Nachweis|Team [A-Z]/);
    }
  });
});
