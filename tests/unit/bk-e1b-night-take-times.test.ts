import { describe, expect, it } from "vitest";
import { computeVisitTimes, type VisitEvent } from "@/features/field/time";
import { fieldActionsOn } from "@/features/field/rules";

// BK-e1b / criterion 4, «F1–F4 sums for the 22:00–07:00 visit» (brief docs/agents/briefs/BK.md §PO amendments
// 2026-11-18 06:39 (6) … 14:39; CGR-200, CGR-206 (a); ADR-203 (7), (21)). The visit written from a night take is one
// visit dated on the start day (pgTAP 148 §6). Its F1–F4 times come from event instants (timestamptz), so the sums must
// not depend on the calendar day. Synthetic instants (Europe/Zurich, CET, no clock change: that night is BK-g).
// Regression guard: no code changed for it; it was green on its first run (stated in ADR-203 (21), not claimed red).

const night: VisitEvent[] = [
  { type: "departed", at: "2026-11-21T21:40:00+01:00" },
  { type: "started", at: "2026-11-21T22:00:00+01:00" },
  { type: "paused", at: "2026-11-22T01:00:00+01:00" },
  { type: "resumed", at: "2026-11-22T01:30:00+01:00" },
  { type: "completed", at: "2026-11-22T07:00:00+01:00" },
];

describe("F2 times of a 22:00–07:00 take visit (criterion 4)", () => {
  it("travel, care and pause across midnight: 20 / 510 / 30 minutes, consistent", () => {
    const t = computeVisitTimes(night, new Date("2026-11-22T08:00:00+01:00"));
    expect(t).toEqual({ travelMinutes: 20, careMinutes: 510, pauseMinutes: 30, inconsistent: false });
    // care + pause = the 9 h of the order slot (22:00–07:00)
    expect((t.careMinutes ?? 0) + (t.pauseMinutes ?? 0)).toBe(540);
  });

  it("without a pause the care time is the full 9 h", () => {
    const t = computeVisitTimes([night[1], night[4]], new Date("2026-11-22T08:00:00+01:00"));
    expect(t.careMinutes).toBe(540);
    expect(t.inconsistent).toBe(false);
  });

  it("still running at 03:00 the next day: counts from 22:00, never negative", () => {
    const t = computeVisitTimes(night.slice(0, 2), new Date("2026-11-22T03:00:00+01:00"));
    expect(t.careMinutes).toBe(300);
    expect(t.inconsistent).toBe(false);
  });

  it("the end the next morning is still offered on the visit's own day card (VIS1-3: only a later date refuses)", () => {
    // Visit dated 2026-11-21, today 2026-11-22 at 07:00: «Abschliessen» stays available.
    expect(fieldActionsOn("started", "2026-11-21", "2026-11-22")).toEqual(["complete", "pause"]);
    expect(fieldActionsOn("paused", "2026-11-21", "2026-11-22")).toEqual(["resume"]);
  });
});
