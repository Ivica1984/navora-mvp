import { describe, expect, it } from "vitest";
import { bulkResultText, refusalText } from "@/features/ai/labels";
import { lineNotFoundText } from "@/features/planning/day-plan-labels";
import {
  groupDayPlan,
  lineDecisionText,
  lineStillOpenText,
  tickableLineIds,
  type DayPlanLine,
} from "@/features/planning/day-plan-view";

/**
 * CGR-75 (5) (`cra`, PLAN3 acceptance condition, ADR-158): "a proposal that cannot staff a visit says so and leaves it
 * to the existing uncovered-visit path, never drops it"; a ticked list whose line is refused at confirm keeps the
 * reason on that line and the visit open. The database decides every reason (0109/0110/0115); these cases pin how the
 * screen model carries them. They are the pure-function half of the e2e in `plan3.spec` (390 px). Synthetic values only.
 */
const RN = "00000000-0000-4000-a000-0000000009e2";

function line(over: Partial<DayPlanLine>): DayPlanLine {
  return {
    suggestion_id: "s",
    proposal_id: "p",
    proposed_at: "2026-11-06T09:00:00Z",
    visit_id: "v",
    case_id: "c",
    time_start: "14:00:00",
    time_end: "14:30:00",
    minutes_a: 0,
    minutes_b: 30,
    minutes_c: 0,
    is_needs_assessment: false,
    member_id: RN,
    member_name: "Synth RN",
    reason: "primary_nurse",
    known_visits: 0,
    not_found_reason: null as unknown as string,
    changes_assignment: false,
    not_continuity: false,
    decision: "open",
    bulk_allowed: true,
    visit_has_responsible: false,
    ...over,
  };
}

const unstaffable = () =>
  line({
    suggestion_id: "nf",
    member_id: null as unknown as string,
    member_name: null as unknown as string,
    reason: null as unknown as string,
    not_found_reason: "overlap",
  });

describe("CGR-75 (5) an unstaffable visit is shown, not dropped", () => {
  it("keeps a line without a member in 'Ohne Vorschlag' (no member block, nothing lost)", () => {
    const g = groupDayPlan([line({ suggestion_id: "a" }), unstaffable()], []);
    expect(g.withoutProposal.map((l) => l.suggestion_id)).toEqual(["nf"]);
    expect(g.members.flatMap((m) => m.lines.map((l) => l.suggestion_id))).toEqual(["a"]);
  });

  it("says 'kein Vorschlag' with the limit the closest member failed", () => {
    expect(lineNotFoundText("overlap")).toBe(
      "kein Vorschlag: die passenden Mitglieder haben zu dieser Zeit schon einen Einsatz",
    );
    for (const code of ["not_active", "needs_rn", "absent", "overlap", "unknown_code"]) {
      expect(lineNotFoundText(code).startsWith("kein Vorschlag")).toBe(true);
    }
  });

  it("offers no tick box for it, so it is never confirmed in a ticked list", () => {
    expect(tickableLineIds([line({ suggestion_id: "a" }), unstaffable()])).toEqual(["a"]);
  });

  it("once decided, says so without reading as covered: '„kein Vorschlag“, entschieden' and 'Noch offen'", () => {
    const decided = { ...unstaffable(), decision: "not_found" };
    expect(lineDecisionText(decided.decision)).toBe("„kein Vorschlag“, entschieden");
    expect(lineDecisionText(decided.decision)?.endsWith("bestätigt")).toBe(false);
    expect(lineStillOpenText(decided)).toBe("Noch offen");
  });
});

describe("CGR-75 (5) a ticked list with a line refused at confirm", () => {
  it("counts the refused line apart in the result", () => {
    expect(bulkResultText(1, 1)).toBe("1 Wert bestätigt, 1 nicht übernommen.");
    expect(bulkResultText(2, 0)).toBe("2 Werte bestätigt.");
  });

  it("words the confirm-time overlap refusal for the line it belongs to", () => {
    expect(refusalText("overlap")).toBe("Nicht übernommen: Diese Person hat zu dieser Zeit schon einen Einsatz.");
  });

  it("leaves the refused line open and tickable again (no decision text, no 'Noch offen' while it is open)", () => {
    const refused = line({ suggestion_id: "r", decision: "open" });
    expect(lineDecisionText(refused.decision)).toBeNull();
    expect(lineStillOpenText(refused)).toBeNull();
    expect(tickableLineIds([refused])).toEqual(["r"]);
  });
});
