import { describe, expect, it } from "vitest";
import {
  combineMemberBusy,
  memberBusyNote,
  memberTakeWindowText,
  MEMBER_OVERLAP_SELF_TEXT,
  MEMBER_TAKE_WINDOW_SELF_TEXT,
} from "@/features/visits/member-overlap-rules";

/**
 * HD-3s-F2-F1-F1 criterion 4 (`uxa` UXR-302, ADR-230, migration 0192): when the chosen time lies in the window of the
 * chosen person's live take (pause included), the pre-save note states the coming refusal instead of the PLAN3-16
 * information sentence. Wording PROPOSED (`cra`, `uxa` confirm). Synthetic labels only; fixed, checkable rule, no AI.
 */
describe("combineMemberBusy", () => {
  it("reads a take window only when the overlap read said yes", () => {
    expect(combineMemberBusy(true, true)).toBe("take_window");
    expect(combineMemberBusy(true, false)).toBe(true);
    expect(combineMemberBusy(false, true)).toBe(false);
    expect(combineMemberBusy(null, true)).toBeNull();
  });
  it("anything but true from the take read keeps the information answer", () => {
    for (const v of [null, undefined, "true", 1, {}]) expect(combineMemberBusy(true, v)).toBe(true);
  });
});

describe("memberBusyNote", () => {
  const colleague = { label: "Synth A", me: false };
  it("states the refusal for a colleague's take window, naming nothing about the take", () => {
    const note = memberBusyNote("take_window", colleague);
    expect(note).toEqual({ kind: "take_window", text: memberTakeWindowText("Synth A") });
    expect(note?.text).toBe(
      "Synth A hat zu dieser Zeit eine laufende geteilte Übernahme. Die Pause zwischen den Blöcken gilt als belegt. So wird nicht gespeichert.",
    );
    expect(note?.text).not.toContain("in diesem oder einem anderen Team");
  });
  it("speaks to herself when she is the chosen person", () => {
    expect(memberBusyNote("take_window", { label: "Ich", me: true })).toEqual({ kind: "take_window", text: MEMBER_TAKE_WINDOW_SELF_TEXT });
  });
  it("keeps the PLAN3-16 information sentence for another visit", () => {
    expect(memberBusyNote(true, { label: "Ich", me: true })).toEqual({ kind: "overlap", text: MEMBER_OVERLAP_SELF_TEXT });
    expect(memberBusyNote(true, colleague)?.kind).toBe("overlap");
  });
  it("no overlap, no answer, no member or an empty label: no note", () => {
    expect(memberBusyNote(false, colleague)).toBeNull();
    expect(memberBusyNote(null, colleague)).toBeNull();
    expect(memberBusyNote("take_window", null)).toBeNull();
    expect(memberBusyNote("take_window", { label: "  ", me: false })).toBeNull();
  });
});
