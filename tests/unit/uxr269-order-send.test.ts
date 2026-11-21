// UXR-269 (#1656): «Senden» on the home's review screen sends exactly what the boxes show. The server compares the
// submitted boxes with the snapshot of the last «Prüfen» (`sameOrderChoice`) and sends nothing when they differ; the
// line next to «Senden» is built from the same checked values (`orderSendSummary`). Fixed rules, no AI.
import { describe, expect, it } from "vitest";
import { messageText, orderSendSummary, sameOrderChoice, type OrderChoice } from "@/features/home-plan/rules";

const checked: OrderChoice = { postcode: "4102", grade: "nurse_hf_fh", tags: ["A1", "C1"] };

describe("UXR-269 sameOrderChoice (shown boxes vs. checked snapshot)", () => {
  it("is true for the same values, in any order and with repeats", () => {
    expect(sameOrderChoice({ ...checked }, checked)).toBe(true);
    expect(sameOrderChoice({ ...checked, tags: ["C1", "A1"] }, checked)).toBe(true);
    expect(sameOrderChoice({ ...checked, tags: ["C1", "A1", "C1"] }, checked)).toBe(true);
  });

  it("is false when an activity was ticked or unticked after «Prüfen»", () => {
    expect(sameOrderChoice({ ...checked, tags: ["C1"] }, checked)).toBe(false);
    expect(sameOrderChoice({ ...checked, tags: ["A1", "C1", "C2"] }, checked)).toBe(false);
    expect(sameOrderChoice({ ...checked, tags: ["A2", "C1"] }, checked)).toBe(false);
    expect(sameOrderChoice({ ...checked, tags: [] }, checked)).toBe(false);
  });

  it("is false when the postcode or the grade changed", () => {
    expect(sameOrderChoice({ ...checked, postcode: "4051" }, checked)).toBe(false);
    expect(sameOrderChoice({ ...checked, grade: "fage_efz" }, checked)).toBe(false);
    expect(sameOrderChoice({ ...checked, postcode: null }, checked)).toBe(false);
  });

  it("fails closed without a snapshot (a hand-made send without «Prüfen»)", () => {
    expect(sameOrderChoice(checked, { postcode: null, grade: null, tags: [] })).toBe(false);
  });
});

describe("UXR-269 orderSendSummary (the line next to «Senden»)", () => {
  const activities = [{ code: "A1", label_de: "Vitalzeichen" }, { code: "C1", label_de: "Grundpflege" }];

  it("names grade, day and time, postcode and place and every activity by code and name", () => {
    expect(orderSendSummary({
      grade: "nurse_hf_fh", day: "Do 26.11.", time: "07:00–15:30", postcode: "4102", place: "Binningen",
      tags: ["A1", "C1"], activities,
    })).toBe("Wird gesendet: HF · Do 26.11. 07:00–15:30 · 4102 Binningen · Tätigkeiten: A1 · Vitalzeichen, C1 · Grundpflege");
  });

  it("keeps an activity without a name as its code and drops no activity", () => {
    const s = orderSendSummary({
      grade: "fage_efz", day: "Fr 27.11.", time: "15:00–23:30", postcode: "4051", place: null, tags: ["C1", "X9"], activities,
    });
    expect(s).toBe("Wird gesendet: FaGe · Fr 27.11. 15:00–23:30 · 4051 · Tätigkeiten: C1 · Grundpflege, X9");
  });
});

describe("UXR-269 notice", () => {
  it("says that nothing was sent and asks to check again", () => {
    const m = messageText("order_changed_recheck");
    expect(m?.kind).toBe("error");
    expect(m?.text).toContain("Es wurde nichts gesendet");
    expect(m?.text).toContain("erneut prüfen");
  });
});
