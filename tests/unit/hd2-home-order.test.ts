// HD-2 (brief HD.md §3, §3a): the words of a cell's external order. The database decides the state
// (institution_plan → private.order_client_state); these tests pin the words and the honesty rules.
import { describe, expect, it } from "vitest";
import {
  canPrepareOrder, canWithdrawOrder, cellStatusText, messageText, orderLine, ordersPerDay, tagList, type CellOrder, type Plan, type PlanCell,
} from "@/features/home-plan/rules";

const sent = (cover_state: string, cover_detail: string | null = null): CellOrder => ({
  gap_order_id: "g", state: "sent", order_id: "o", grade: "nurse_hf_fh", grade_fixed: true, starts_at: null,
  cover_state, cover_detail, latest_cover_at: null,
});
const cell = (over: Partial<PlanCell> = {}): PlanCell => ({
  date: "2026-11-19", station_id: "s", shift_type_id: "t", required_total: 1, required_grade: "nurse_hf_fh",
  required_grade_count: 1, example: true, assigned: [], present: 0, grade_present: 0, missing: 1, status: "gap",
  external_covered: 0, order: null, ...over,
});
const plan = (role: "lead" | "planner" | "viewer", can_order: boolean, cells: PlanCell[] = []): Plan => ({
  institution: { id: "i", display_name: "Testheim", simulation: true, role, can_order, order_postcode: null },
  from: "2026-11-16", to: "2026-11-22", stations: [], shift_types: [], staff: [], absences: [], cells,
});

describe("HD-2 order line (§3 words)", () => {
  it("E, A, T, G, K and N each have their own words", () => {
    expect(orderLine({ ...sent("open"), state: "prepared", order_id: null }).headline).toBe("Auftrag vorbereitet, nicht gesendet");
    expect(orderLine(sent("open")).headline).toBe("Angebot versandt · noch nicht gedeckt");
    expect(orderLine(sent("open", "awaiting_acknowledgement")).headline).toBe("Team hat übernommen · Person bestätigt noch");
    expect(orderLine(sent("covered")).headline).toBe("Gedeckt · Person bestätigt, geprüft für HF");
    expect(orderLine(sent("not_covered", "no_team_free"))).toMatchObject({ code: "K", headline: "Nicht gedeckt", detail: "Kein passendes Team ist frei." });
    expect(orderLine(sent("no_longer_covered")).headline).toBe("Nicht mehr gedeckt · Angebot läuft wieder");
    expect(orderLine(sent("no_longer_covered", "no_offer_open")).headline).toBe("Nicht mehr gedeckt · kein Angebot offen");
  });

  it("only `covered` ever reads «Gedeckt»; T says it does not count yet", () => {
    for (const [s, d] of [["open", null], ["open", "awaiting_acknowledgement"], ["open", "take_fell_away"], ["open", "take_fell_away_no_offer"],
      ["not_covered", "started"], ["not_covered", "cover_time_reached"], ["no_longer_covered", null], ["no_longer_covered", "no_offer_open"],
      ["something", null]] as const) {
      expect(orderLine(sent(s, d)).headline).not.toMatch(/^Gedeckt/);
    }
    expect(orderLine(sent("open", "awaiting_acknowledgement")).detail).toBe("Zählt noch nicht als besetzt.");
  });

  it("FE-110 (b): «läuft wieder» / «wieder an alle» never without a real release", () => {
    for (const l of [orderLine(sent("no_longer_covered", "no_offer_open")), orderLine(sent("open", "take_fell_away_no_offer"))]) {
      expect(JSON.stringify(l)).not.toMatch(/läuft wieder|wieder an alle/);
    }
  });

  it("K and N name the next action of the home; no person and no cause", () => {
    for (const l of [orderLine(sent("not_covered", "started")), orderLine(sent("no_longer_covered")), orderLine(sent("no_longer_covered", "no_offer_open"))]) {
      expect(l.next).toBe("Nächste Handlung: eine zulässige eigene Person einteilen oder den Auftrag zurückziehen.");
      expect(JSON.stringify(l)).not.toMatch(/abwesend|krank|Nachweis|Vertrag/);
    }
  });
});

describe("HD-2 cell rules", () => {
  it("«Externen Auftrag vorbereiten» only on a gap without an order, for a planner who may order", () => {
    expect(canPrepareOrder(plan("lead", true), cell())).toBe(true);
    expect(canPrepareOrder(plan("planner", true), cell())).toBe(true);
    expect(canPrepareOrder(plan("viewer", true), cell())).toBe(false);
    expect(canPrepareOrder(plan("lead", false), cell())).toBe(false);
    expect(canPrepareOrder(plan("lead", true), cell({ status: "ok" }))).toBe(false);
    expect(canPrepareOrder(plan("lead", true), cell({ order: sent("open") }))).toBe(false);
  });

  it("a covered external person is named as such in the count", () => {
    expect(cellStatusText(cell({ status: "ok", external_covered: 1, missing: 0 }))).toBe("0 + 1 extern von 1 · besetzt");
    expect(cellStatusText(cell())).toBe("0 von 1 · Lücke: 1 fehlt, 1 HF fehlt");
  });

  it("the month row lists the order letters per day", () => {
    const p = plan("lead", true, [cell({ order: sent("covered") }), cell({ shift_type_id: "u", order: sent("no_longer_covered") })]);
    expect(ordersPerDay(p).get("2026-11-19")).toEqual(["G", "N"]);
  });

  it("tag lists keep only the known code shape", () => {
    expect(tagList("A1,A2, B3H,x;drop,A1")).toEqual(["A1", "A2", "B3H"]);
    expect(tagList(undefined)).toEqual([]);
  });
});

describe("HD-2 slice 5: «Auftrag zurückziehen» (HD.md §3 rows A, K, N)", () => {
  it("offered for A, K and N of a sent order, to a planner who may order", () => {
    for (const o of [sent("open"), sent("open", "take_fell_away"), sent("open", "take_fell_away_no_offer"),
      sent("not_covered", "no_team_free"), sent("not_covered", "cover_time_reached"), sent("no_longer_covered"),
      sent("no_longer_covered", "no_offer_open")]) {
      expect(canWithdrawOrder(plan("planner", true), o)).toBe(true);
      expect(canWithdrawOrder(plan("lead", true), o)).toBe(true);
    }
  });

  it("never for G (confirmed person), T (awaiting confirmation) or a draft", () => {
    expect(canWithdrawOrder(plan("planner", true), sent("covered"))).toBe(false);
    expect(canWithdrawOrder(plan("planner", true), sent("open", "awaiting_acknowledgement"))).toBe(false);
    expect(canWithdrawOrder(plan("planner", true), { ...sent("open"), state: "prepared", order_id: null })).toBe(false);
  });

  it("never for a viewer or a planner who may not order", () => {
    expect(canWithdrawOrder(plan("viewer", true), sent("not_covered"))).toBe(false);
    expect(canWithdrawOrder(plan("planner", false), sent("not_covered"))).toBe(false);
  });

  it("the answer never claims an offer runs again", () => {
    expect(messageText("order_withdrawn")).toEqual({ kind: "ok", text: "Auftrag zurückgezogen. Kein Team erhält das Angebot mehr; die Lücke bleibt." });
    for (const c of ["not_sent", "already_withdrawn", "order_started", "covered", "awaiting_acknowledgement", "visit_under_way"]) {
      const m = messageText(c);
      expect(m?.kind).toBe("error");
      expect(m?.text).not.toMatch(/läuft wieder|wieder an alle/);
    }
  });
});
