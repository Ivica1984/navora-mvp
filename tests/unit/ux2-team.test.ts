import { describe, expect, it } from "vitest";
import { VISIT_ALERT_FRAME_CLASS, visitAlertFrame } from "@/features/team/rules";

// UX2 part 4 (ADR-133): UX2-16 (`uxa` UXR-28; `cra` 17:30 answer 3) on /team. Synthetic rows only.
// The "Einsätze mit Handlungsbedarf" frame follows what the list shows: red while a P1 entry is shown in full; amber
// while the list has any entry (pointers to a red card above, or only P2 entries); empty list as today (no frame).

type A = { visit_id: string; exception_type: string; priority: string; flags: string[]; taken: boolean };
const alert = (over: Partial<A> = {}): A => ({
  visit_id: "v1", exception_type: "visit_overdue", priority: "P1", flags: [], taken: false, ...over,
});
const signal = (visit_id = "v1", signal_kind = "visit_overdue") => ({ visit_id, signal_kind });

describe("UX2-16: frame of the visit alert list per mix", () => {
  it("P1 entry in full: red", () => {
    expect(visitAlertFrame([alert()], [])).toBe("red");
  });

  it("only pointers to an open signal card above: amber", () => {
    expect(visitAlertFrame([alert()], [signal()])).toBe("amber");
    expect(visitAlertFrame([alert(), alert({ visit_id: "v2" })], [signal(), signal("v2")])).toBe("amber");
  });

  it("only P2 entries: amber", () => {
    expect(visitAlertFrame([alert({ priority: "P2" })], [])).toBe("amber");
    expect(visitAlertFrame([alert({ priority: "P2", exception_type: "visit_stuck" }), alert({ priority: "P2", visit_id: "v2" })], [])).toBe("amber");
  });

  it("empty list: unchanged (no frame, the section is not rendered)", () => {
    expect(visitAlertFrame([], [])).toBeNull();
    expect(visitAlertFrame([], [signal()])).toBeNull();
  });

  it("pointers plus one P1 shown in full (e.g. taken, flagged or with its own action): red", () => {
    expect(visitAlertFrame([alert(), alert({ visit_id: "v2", taken: true })], [signal(), signal("v2")])).toBe("red");
    expect(visitAlertFrame([alert({ flags: ["responsible_absent"] })], [signal()])).toBe("red");
    expect(visitAlertFrame([alert({ exception_type: "visit_interrupted" })], [signal("v1", "visit_interrupted")])).toBe("red");
  });

  it("P2 plus a P1 pointer: amber; P2 plus a P1 in full: red", () => {
    expect(visitAlertFrame([alert(), alert({ visit_id: "v2", priority: "P2" })], [signal()])).toBe("amber");
    expect(visitAlertFrame([alert(), alert({ visit_id: "v2", priority: "P2" })], [])).toBe("red");
  });

  it("an unknown priority is never neutral while listed: amber", () => {
    expect(visitAlertFrame([alert({ priority: "P3" })], [])).toBe("amber");
  });

  it("frame classes: red uses the P1 tokens, amber never the P1 colour, neither is neutral", () => {
    expect(VISIT_ALERT_FRAME_CLASS.red).toMatch(/border-rose-/);
    expect(VISIT_ALERT_FRAME_CLASS.amber).toMatch(/border-amber-/);
    expect(VISIT_ALERT_FRAME_CLASS.amber).not.toMatch(/rose-/);
    for (const cls of Object.values(VISIT_ALERT_FRAME_CLASS)) expect(cls).not.toMatch(/stone-|white/);
  });
});
