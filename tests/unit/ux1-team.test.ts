import { describe, expect, it } from "vitest";
import { CLEARANCE_SUMMARY, CLEARANCE_TEXT, PROVISIONAL_NOTE, SIGNAL_POINTER, alertRepeatsSignal } from "@/features/team/rules";
import { REACH_GAP_TEXT, allReachable } from "@/features/push/rules";

// UX1 part (g) (ADR-109): UX1-22 (`cra` C-1) and UX1-24 (`cra` C-3) on /team. Synthetic rows only.

const alert = (over: Partial<{ visit_id: string; exception_type: string; flags: string[]; taken: boolean }> = {}) => ({
  visit_id: "v1", exception_type: "visit_overdue", flags: [] as string[], taken: false, ...over,
});
const signal = (visit_id = "v1", signal_kind = "visit_overdue") => ({ visit_id, signal_kind });

describe("UX1-22: an entry shrinks to one pointer line only when it repeats an open signal card", () => {
  it("same visit, same situation, no flags, not taken, no own action: pointer", () => {
    expect(alertRepeatsSignal(alert(), [signal()])).toBe(true);
    expect(alertRepeatsSignal(alert({ exception_type: "visit_stuck" }), [signal("v1", "visit_stuck")])).toBe(true);
  });

  it("no open card for that visit, or a card for another situation: full entry", () => {
    expect(alertRepeatsSignal(alert(), [])).toBe(false);
    expect(alertRepeatsSignal(alert(), [signal("v2")])).toBe(false);
    expect(alertRepeatsSignal(alert(), [signal("v1", "visit_stuck")])).toBe(false);
  });

  it("an entry with flags (CGR-32) keeps them: full entry", () => {
    expect(alertRepeatsSignal(alert({ flags: ["responsible_absent"] }), [signal()])).toBe(false);
  });

  it("an entry Operations has taken carries a handling state the card lacks: full entry", () => {
    expect(alertRepeatsSignal(alert({ taken: true }), [signal()])).toBe(false);
  });

  it("visit_interrupted carries its own action (the follow-up form, CGR-25): always full", () => {
    expect(alertRepeatsSignal(alert({ exception_type: "visit_interrupted" }), [signal("v1", "visit_interrupted")])).toBe(false);
  });

  it("missing flags are treated as none", () => {
    expect(alertRepeatsSignal({ visit_id: "v1", exception_type: "visit_overdue", flags: null, taken: false }, [signal()])).toBe(true);
  });

  it("the texts: pointer and summary as in the brief; the clearance paragraph is the former one, word for word", () => {
    expect(SIGNAL_POINTER).toBe("Steht oben als Sicherheitssignal");
    expect(CLEARANCE_SUMMARY).toBe("Wann erledigt sich das?");
    expect(PROVISIONAL_NOTE).toBe("Schwellen und Regeln provisorisch (klinische Entscheidungen offen).");
    expect(`${CLEARANCE_TEXT} ${PROVISIONAL_NOTE}`).toBe(
      "Erledigt sich, sobald der Einsatz weitergeht, abgesagt oder als «nicht angetroffen» erfasst ist; ein nicht abgeschlossener Einsatz, sobald jemand über die noch fällige Pflege entschieden hat; eine offene Berichtskorrektur, sobald sie unterschrieben und, falls nötig, gegengezeichnet ist; eine Verordnung ohne Enddatum, sobald ein Enddatum erfasst ist. Schwellen und Regeln provisorisch (klinische Entscheidungen offen).",
    );
  });
});

describe("UX1-24: team push reachability", () => {
  it("the gap text is `cra` C-3's wording", () => {
    expect(REACH_GAP_TEXT).toBe("Nicht alle erhalten Sicherheitssignale ausserhalb der App");
  });

  it("all reachable only when every listed member is active; none listed is not 'all'", () => {
    expect(allReachable([{ active: true }, { active: true }])).toBe(true);
    expect(allReachable([{ active: true }, { active: false }])).toBe(false);
    expect(allReachable([{ active: false }, { active: false }])).toBe(false);
    expect(allReachable([])).toBe(false);
  });
});
