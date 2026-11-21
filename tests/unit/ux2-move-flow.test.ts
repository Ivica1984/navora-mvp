import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  DAY_CHANGED_RELOAD,
  MOVED_FLAGS_LIST_ID,
  MOVED_RELEASED_NOTICE_ID,
  MOVE_TODAY_LINK_LABEL,
  movedCardDescribedBy,
} from "@/features/field/rules";

// UX2 part 5 (ADR-134; brief UX2-18 to UX2-21, `uxa` UXR-36, -37, -40, -41). Display rules on the /field move flow
// only: the database (`move_visit_to_today`, 0093) still decides every move.

describe("UX2-20: the reload fallback points at its link", () => {
  it("is the PO's wording and names the link label it sits beside", () => {
    expect(DAY_CHANGED_RELOAD).toBe("Inzwischen ist ein neuer Tag. Tippe auf «Einsätze von heute».");
    expect(MOVE_TODAY_LINK_LABEL).toBe("Einsätze von heute");
    expect(DAY_CHANGED_RELOAD).toContain(`«${MOVE_TODAY_LINK_LABEL}»`);
  });

  it("asks for no manual reload and carries no internal code", () => {
    expect(DAY_CHANGED_RELOAD).not.toMatch(/neu laden|Lade die Seite/i);
    expect(DAY_CHANGED_RELOAD).not.toMatch(/day_changed|_/);
  });
});

describe("UX2-19: the moved card is described by its notices", () => {
  it("names nothing when the move neither released the visit nor returned a flag", () => {
    expect(movedCardDescribedBy({ released: false, flags: [] })).toBeUndefined();
  });

  it("names the release notice alone (VIS1-3f unchanged)", () => {
    expect(movedCardDescribedBy({ released: true, flags: [] })).toBe(MOVED_RELEASED_NOTICE_ID);
  });

  it("names the flags list when the move returned a flag", () => {
    expect(movedCardDescribedBy({ released: false, flags: ["uncovered"] })).toBe(MOVED_FLAGS_LIST_ID);
  });

  it("names both, release notice first, when both exist", () => {
    expect(movedCardDescribedBy({ released: true, flags: ["uncovered", "not_primary"] })).toBe(
      `${MOVED_RELEASED_NOTICE_ID} ${MOVED_FLAGS_LIST_ID}`,
    );
  });

  it("uses distinct ids that are valid idref tokens", () => {
    expect(MOVED_FLAGS_LIST_ID).not.toBe(MOVED_RELEASED_NOTICE_ID);
    expect(MOVED_FLAGS_LIST_ID).toMatch(/^[a-z][a-z-]*$/);
  });
});

// Source guards on the presentation (the repository has no component renderer; e2e `ux2-move-flow.spec.ts` covers
// the rendered page).
const FIELD = readFileSync("src/app/(protected)/field/field-client.tsx", "utf8");

function block(startMarker: string, endMarker: string): string {
  const start = FIELD.indexOf(startMarker);
  const end = FIELD.indexOf(endMarker, start);
  expect(start, startMarker).toBeGreaterThan(-1);
  expect(end, endMarker).toBeGreaterThan(start);
  return FIELD.slice(start, end);
}

describe("UX2-21: a focused sentence is not also a live region", () => {
  it("the day-changed sentences (focus target) carry no role=status and no aria-live", () => {
    const tags = FIELD.match(/<p ref=\{dayNoteRef\}[^>]*>/g) ?? [];
    expect(tags.length).toBe(2);
    for (const tag of tags) {
      expect(tag).not.toMatch(/role="status"/);
      expect(tag).not.toMatch(/aria-live/);
      expect(tag).toMatch(/tabIndex=\{-1\}/);
    }
  });
});

describe("UX2-19: the flags list is text-sm and carries its id", () => {
  it("renders the list with MOVED_FLAGS_LIST_ID at text-sm, wording from PLAN_FLAG_LABEL", () => {
    const notice = block("function MovedNoticeBlock", "\n}\n");
    expect(notice).toMatch(/id=\{MOVED_FLAGS_LIST_ID\}/);
    expect(notice).toMatch(/data-testid="moved-flags"[^>]*text-sm/);
    expect(notice).not.toMatch(/data-testid="moved-flags"[^>]*text-xs/);
    expect(notice).toMatch(/PLAN_FLAG_LABEL\[f\]/);
    // A name on the referenced list would replace the flags in the card's description (CI run 41572248453).
    expect(notice).not.toMatch(/<ul[^>]*aria-label[^>]*data-testid="moved-flags"|data-testid="moved-flags"[^>]*aria-label/);
  });

  it("the moved card's description comes from movedCardDescribedBy", () => {
    expect(FIELD).toMatch(/describedBy=\{moved && movedId === visit\.visit_id \? movedCardDescribedBy\(moved\) : undefined\}/);
  });
});

describe("UX2-18: the VIS1-8 line has its place from the first render", () => {
  it("the leaves slot is rendered while the answer loads, so Von and Bis do not move", () => {
    const form = block("function MoveToToday", "\n}\n");
    expect(form).toMatch(/data-testid="move-leaves-slot"/);
    // The slot is not conditional on the answer: both wordings are stacked invisibly to reserve the taller one, and
    // the visible sentence appears inside it.
    expect(form).not.toMatch(/&&\s*\(\s*<div data-testid="move-leaves-slot"/);
    expect(form.indexOf('data-testid="move-leaves-note"')).toBeGreaterThan(form.indexOf('data-testid="move-leaves-slot"'));
    expect(form).toMatch(/aria-hidden="true" className="invisible col-start-1 row-start-1/);
    expect(form).toMatch(/\[true, false\]\.map\(\(other\) =>/);
    expect(form).toMatch(/moveLeavesNote\(visit\.visit_date, other\)/);
  });
});
