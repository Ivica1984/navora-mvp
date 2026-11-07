import { describe, expect, it } from "vitest";
import {
  memberOverlapAfterSave,
  memberOverlapNote,
  parseMemberOverlap,
  MEMBER_OVERLAP_SELF_TEXT,
} from "@/features/visits/member-overlap-rules";

/**
 * PLAN3-16 (`cra` CGR-137, `aia` 20:20, wording `uxa` 2026-11-06 07:50 PROPOSED, ADR-161): a hand assignment states,
 * as information, that the member already has a visit at that time in this or another team. yes/no only: the sentence
 * names no other team, client or time; it never refuses and adds no confirmation. Synthetic labels only.
 */
describe("parseMemberOverlap", () => {
  it("reads only a boolean; anything else is no answer", () => {
    expect(parseMemberOverlap(true)).toBe(true);
    expect(parseMemberOverlap(false)).toBe(false);
    for (const v of [null, undefined, "true", 1, {}, [], { overlap: true }]) expect(parseMemberOverlap(v)).toBeNull();
  });
});

describe("memberOverlapNote", () => {
  it("names the member by her picker label (pickerMemberLabel, no qualification suffix)", () => {
    expect(memberOverlapNote(true, { label: "Synth A", me: false })).toBe(
      "Synth A hat zu dieser Zeit schon einen Einsatz, in diesem oder einem anderen Team.",
    );
    expect(memberOverlapNote(true, { label: "Teammitglied 2 (ohne Namen)", me: false })).toBe(
      "Teammitglied 2 (ohne Namen) hat zu dieser Zeit schon einen Einsatz, in diesem oder einem anderen Team.",
    );
  });

  it("speaks to herself when she is the member", () => {
    expect(memberOverlapNote(true, { label: "Synth A (du)", me: true })).toBe(MEMBER_OVERLAP_SELF_TEXT);
    expect(MEMBER_OVERLAP_SELF_TEXT).toBe("Du hast zu dieser Zeit schon einen Einsatz, in diesem oder einem anderen Team.");
  });

  it("says nothing without an overlap, without an answer or without a member", () => {
    expect(memberOverlapNote(false, { label: "Synth A", me: false })).toBeNull();
    expect(memberOverlapNote(null, { label: "Synth A", me: false })).toBeNull();
    expect(memberOverlapNote(true, null)).toBeNull();
    expect(memberOverlapNote(true, { label: "  ", me: false })).toBeNull();
  });

  it("never reads as a refusal or asks for a confirmation, and names no time or team", () => {
    const texts = [memberOverlapNote(true, { label: "Synth A", me: false }), MEMBER_OVERLAP_SELF_TEXT];
    for (const t of texts) {
      expect(t).not.toMatch(/nicht|trotzdem|bestätig|Grund|\d{1,2}:\d{2}|Team [A-Z]/);
    }
  });
});

describe("memberOverlapAfterSave", () => {
  it("states the server's fact only when the form did not show it", () => {
    expect(memberOverlapAfterSave(false, true)).toBe(true);
    expect(memberOverlapAfterSave(true, true)).toBe(false);
    expect(memberOverlapAfterSave(false, false)).toBe(false);
    expect(memberOverlapAfterSave(false, null)).toBe(false);
  });
});
