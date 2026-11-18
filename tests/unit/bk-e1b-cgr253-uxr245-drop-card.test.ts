import { describe, expect, it } from "vitest";
import {
  TAKE_DROP_NAMED_LINE,
  TAKE_DROP_TEAM_LINE,
  TAKE_MESSAGES,
  signalHref,
  signalNextStep,
  signalTakeable,
  splitSignals,
} from "@/features/signals/rules";

// BK-e1b / CGR-253 / UXR-245 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 11:39 (1), choice (b); #1445;
// `cra` 11:26, `uxa` 10:48; ADR-203 (18)). A `take_member_dropped` signal has no «Ich übernehme» for any recipient: a
// tap would neither move the visit nor stop the step to Operations. The card shows the next step per recipient instead
// (words PROPOSED by `uxa`, `cra` confirms for the simulation). The database refuses the take as well
// (`take_signal` → `kind_not_takeable`, migration 0146, pgTAP 148 §10 and §13 (b)).
// UXR-246 (11:39 (2)): a colleague's card links to /team, never to a /field day where she does not see the visit.
// Written before the code (red first, FE-071 (2)).

const base = { visit_date: "2026-11-23", taken_by_me: false, taken_by_name: null, taken_awaits_rn: false };
const named = { ...base, signal_kind: "take_member_dropped", reason: "responsible" };
const colleague = { ...base, signal_kind: "take_member_dropped", reason: "team" };
const operations = { ...base, signal_kind: "take_member_dropped", reason: "operations_fallback" };

describe("take_member_dropped card: no take button (CGR-253 (b))", () => {
  it("is not takeable for the named member, a colleague or Operations", () => {
    expect(signalTakeable(named)).toBe(false);
    expect(signalTakeable(colleague)).toBe(false);
    expect(signalTakeable(operations)).toBe(false);
  });

  it("every other kind keeps «Ich übernehme» (SIG1-4 unchanged)", () => {
    for (const kind of ["visit_overdue", "visit_stuck", "visit_uncovered", "visit_interrupted", "no_show"]) {
      expect(signalTakeable({ signal_kind: kind })).toBe(true);
    }
  });

  it("stays in the open list for every recipient, since nobody can take it", () => {
    const { open, taken } = splitSignals([named, colleague]);
    expect(open).toHaveLength(2);
    expect(taken).toHaveLength(0);
  });

  it("the server refusal kind_not_takeable reads as a stated reason, not as a generic failure", () => {
    expect(TAKE_MESSAGES.kind_not_takeable).toBeTruthy();
    expect(TAKE_MESSAGES.kind_not_takeable).not.toBe(TAKE_MESSAGES.failed);
  });
});

describe("take_member_dropped card: the next step per recipient (CGR-253 (b), UXR-245)", () => {
  it("the named member reads that the shift stays hers and her team is informed (`uxa` 10:48)", () => {
    expect(TAKE_DROP_NAMED_LINE).toBe(
      "Diese übernommene Schicht ist dir zugeteilt, du bist aber nicht mehr eingeplant. Dein Team ist informiert. " +
        "Die Schicht bleibt bei dir, bis sie geklärt ist.",
    );
    expect(signalNextStep(named)).toBe(TAKE_DROP_NAMED_LINE);
  });

  it("a colleague reads the next step to settle it in the team", () => {
    expect(TAKE_DROP_TEAM_LINE).toBe("Bitte sofort im Team klären, wer hingeht.");
    expect(signalNextStep(colleague)).toBe(TAKE_DROP_TEAM_LINE);
  });

  it("no line for Operations (no words decided) and none for any other kind", () => {
    expect(signalNextStep(operations)).toBeNull();
    expect(signalNextStep({ signal_kind: "no_show", reason: "responsible" })).toBeNull();
    expect(signalNextStep({ signal_kind: "visit_overdue", reason: "team" })).toBeNull();
  });
});

describe("take_member_dropped card: the link (UXR-246 link part)", () => {
  it("a colleague's card links to /team, not to a /field day without the visit", () => {
    expect(signalHref(colleague)).toBe("/team");
  });

  it("the named member's card keeps the /field day where her take visit is", () => {
    expect(signalHref(named)).toBe("/field?datum=2026-11-23");
  });

  it("every other kind keeps the /field day (SIG1 unchanged)", () => {
    expect(signalHref({ visit_date: "2026-10-24", signal_kind: "visit_overdue", reason: "team" })).toBe("/field?datum=2026-10-24");
    expect(signalHref({ visit_date: "2026-10-24" })).toBe("/field?datum=2026-10-24");
  });
});
