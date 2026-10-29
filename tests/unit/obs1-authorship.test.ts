import { describe, expect, it } from "vitest";
import {
  AUTHOR_NOT_STORED_TEXT,
  AUTHOR_WITHOUT_NAME_TEXT,
  QUALIFICATION_NOT_RECORDED_TEXT,
  observationAuthor,
  showsQualificationMarker,
  snapshotAuthor,
} from "@/features/field/authorship";
import { entryAuthorLabel, entryQualificationMissing } from "@/features/handover/rules";

// OBS1 (ADR-118, migration 0095): display of the author and the OBS1-1 marker. Synthetic names only.
describe("OBS1 observation author on the visit card and in the handover (OBS1-2)", () => {
  it("names a colleague by her display name, the reader herself as 'von dir'", () => {
    expect(observationAuthor({ own: false, author_name: "Kandidatin Olga Test" })).toBe("Kandidatin Olga Test");
    expect(observationAuthor({ own: true, author_name: "Kandidatin Olga Test" })).toBe("von dir");
  });
  it("never guesses a name for a member without one", () => {
    expect(observationAuthor({ own: false, author_name: null })).toBe(AUTHOR_WITHOUT_NAME_TEXT);
    expect(observationAuthor({ own: false, author_name: "  " })).toBe(AUTHOR_WITHOUT_NAME_TEXT);
  });
  it("shows the marker only when it was recorded as missing", () => {
    expect(showsQualificationMarker(true)).toBe(true);
    expect(showsQualificationMarker(false)).toBe(false);
    expect(showsQualificationMarker(null)).toBe(false);
    expect(showsQualificationMarker(undefined)).toBe(false);
  });
  it("the marker text is neutral: no code, no judgement, no alarm word", () => {
    expect(QUALIFICATION_NOT_RECORDED_TEXT).not.toMatch(/qualification_missing|unqualifiziert|Warnung|Achtung|Fehler|ungültig|!/i);
  });
  it("HAND1 names the author of an observation, keeps codes for other entries", () => {
    const detail = { content: "x", author_name: "Kandidatin Olga Test", author_qualification_missing: true };
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail })).toBe("Kandidatin Olga Test");
    expect(entryAuthorLabel({ kind: "observation", author: "me", detail })).toBe("Ich");
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail: { content: "x" } })).toBe("Teammitglied 4");
    expect(entryAuthorLabel({ kind: "care_plan_added", author: "member:4", detail })).toBe("Teammitglied 4");
    expect(entryQualificationMissing({ kind: "observation", detail })).toBe(true);
    expect(entryQualificationMissing({ kind: "observation", detail: { author_qualification_missing: false } })).toBe(false);
    expect(entryQualificationMissing({ kind: "care_plan_added", detail })).toBe(false);
  });
});

describe("OBS1 report snapshot author (OBS1-3)", () => {
  const base = { content: "Synthetisch", recorded_at: "2026-10-29T08:00:00Z" };
  it("a version stored after OBS1 names the author and carries the marker", () => {
    expect(snapshotAuthor({ ...base, author_id: "u1", author_name: "Kandidatin Olga Test", author_qualification_missing: true }))
      .toEqual({ stored: true, text: "Kandidatin Olga Test", marker: true });
    expect(snapshotAuthor({ ...base, author_id: "u2", author_name: "Pflegefachfrau Paula Test", author_qualification_missing: false }))
      .toEqual({ stored: true, text: "Pflegefachfrau Paula Test", marker: false });
    expect(snapshotAuthor({ ...base, author_id: "u3", author_name: null, author_qualification_missing: null }))
      .toEqual({ stored: true, text: AUTHOR_WITHOUT_NAME_TEXT, marker: false });
  });
  it("a version signed before OBS1 says so in one neutral line, never a guessed name", () => {
    expect(snapshotAuthor({ ...base, handover: false, edited: false })).toEqual({ stored: false, text: AUTHOR_NOT_STORED_TEXT, marker: false });
  });
});
