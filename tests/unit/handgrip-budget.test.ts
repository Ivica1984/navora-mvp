import { describe, expect, it } from "vitest";
import baseline from "../e2e/handgrip-baseline.json";
import {
  HANDGRIP_ROLES,
  HANDGRIP_TARGET,
  judgeHandgrips,
  parseBaseline,
  handgripReport,
  type HandgripRole,
} from "../e2e/support/handgrip-budget";

// ADR-208 (founder decision 2026-11-19, live session: «muss zwingend eingeführt werden»; mode «Sperrklinke»):
// the handgrips per order are measured on the BK path and held by a ratchet. More handgrips than the baseline fail;
// fewer also fail until the baseline is lowered in the same PR, so the limit only ever goes down. The target is the
// Blueprint V3.2 §6.3 sentence (1 client, 1 team, 3 carer after the shift); it is reported, never weakened.
describe("handgrip ratchet (ADR-208)", () => {
  it("holds the Blueprint §6.3 targets exactly", () => {
    expect(HANDGRIP_TARGET).toEqual({ auftraggeber: 1, team: 1, pflege_nach_schicht: 3 });
    expect(HANDGRIP_ROLES).toEqual(["auftraggeber", "team", "pflege_nach_schicht"]);
  });

  it("passes when the measured count equals the baseline and names the gap to the target", () => {
    const verdict = judgeHandgrips("auftraggeber", 8, 8);
    expect(verdict).toEqual({ role: "auftraggeber", measured: 8, baseline: 8, target: 1, gap: 7, outcome: "held" });
  });

  it("fails when a step needs more handgrips than the baseline", () => {
    const verdict = judgeHandgrips("team", 3, 2);
    expect(verdict.outcome).toBe("over_baseline");
    expect(verdict.gap).toBe(2);
  });

  it("fails on an improvement until the baseline is lowered in the same PR (the limit only goes down)", () => {
    const verdict = judgeHandgrips("auftraggeber", 6, 8);
    expect(verdict.outcome).toBe("lower_baseline");
  });

  it("reports a count at or below the target with gap 0, never a negative gap", () => {
    expect(judgeHandgrips("team", 1, 1)).toMatchObject({ gap: 0, outcome: "held" });
    expect(judgeHandgrips("pflege_nach_schicht", 2, 2)).toMatchObject({ gap: 0, outcome: "held" });
  });

  it("rejects counts that are not whole numbers of zero or more", () => {
    expect(() => judgeHandgrips("team", -1, 2)).toThrow();
    expect(() => judgeHandgrips("team", 1.5, 2)).toThrow();
    expect(() => judgeHandgrips("team", 1, Number.NaN)).toThrow();
  });

  it("parses the committed baseline file: known roles only, whole numbers, no role without a target", () => {
    const parsed = parseBaseline(baseline);
    for (const role of Object.keys(parsed) as HandgripRole[]) {
      expect(HANDGRIP_ROLES).toContain(role);
      expect(Number.isInteger(parsed[role])).toBe(true);
      expect(parsed[role]).toBeGreaterThanOrEqual(0);
    }
    expect(() => parseBaseline({ auftraggeber: 8, disponent: 2 })).toThrow(/unknown role/);
    expect(() => parseBaseline({ auftraggeber: "8" })).toThrow();
    expect(() => parseBaseline([])).toThrow();
  });

  it("writes a German report line per role with measured, limit, target and gap", () => {
    const text = handgripReport([judgeHandgrips("auftraggeber", 8, 8), judgeHandgrips("team", 2, 2)]);
    expect(text).toContain("| Auftraggeber | 8 | 8 | 1 | 7 | gehalten |");
    expect(text).toContain("| Team | 2 | 2 | 1 | 1 | gehalten |");
    expect(judgeHandgrips("team", 3, 2).message).toMatch(/mehr Handgriffe als die Basislinie/);
    expect(judgeHandgrips("team", 1, 2).message).toMatch(/Basislinie .* auf 1 senken/);
  });
});
