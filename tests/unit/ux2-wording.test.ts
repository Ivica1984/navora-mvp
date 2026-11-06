import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { AUTHOR_WITHOUT_NAME_TEXT, observationAuthor } from "@/features/field/authorship";
import { fieldLabel } from "@/features/ai/labels";
import { authorLabel, entryAuthorLabel } from "@/features/handover/rules";
import {
  getVisitResponsibleLabel,
  isVisitStillOpen,
  RESPONSIBLE_LABEL,
  RESPONSIBLE_NOBODY_TEXT,
  RESPONSIBLE_NOT_RECORDED_TEXT,
  RESPONSIBLE_PICK_TEXT,
} from "@/features/visits/types";

// UX2 part 3 (ADR-132): UX2-27 (one author, one label) and UX2-29 (one word per concept for the responsible member).
// Display only; synthetic names. Written before the code change.

describe("UX2-27: an observation's author reads the same on the card, in the report facts and in the handover", () => {
  it("a colleague with a name reads 'von <Name>' on the visit card, as in the report facts", () => {
    expect(observationAuthor({ own: false, author_name: "Synthetische Kollegin X" })).toBe("von Synthetische Kollegin X");
    expect(observationAuthor({ own: false, author_name: "  Synthetische Kollegin X " })).toBe("von Synthetische Kollegin X");
  });

  it("her own observation still reads 'von dir'; a colleague without a name keeps the constant", () => {
    expect(observationAuthor({ own: true, author_name: "Synthetische Kollegin X" })).toBe("von dir");
    expect(observationAuthor({ own: false, author_name: null })).toBe(AUTHOR_WITHOUT_NAME_TEXT);
  });

  // UX2-27 as amended po 2026-11-03 06:30 (cra CGR-108): this replaces the earlier "constant, not a member code" test.
  it("a handover observation whose author has no name keeps her member number: 'Teammitglied <n> (ohne Namen)'", () => {
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail: { content: "x" } })).toBe("Teammitglied 4 (ohne Namen)");
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail: { content: "x", author_name: "  " } })).toBe(
      "Teammitglied 4 (ohne Namen)"
    );
  });

  it("two observations by two different unnamed members in one handover carry two different labels", () => {
    const a = entryAuthorLabel({ kind: "observation", author: "member:2", detail: { content: "x" } });
    const b = entryAuthorLabel({ kind: "observation", author: "member:5", detail: { content: "y" } });
    expect(a).not.toBe(b);
  });

  // The handover has no report entry kind (ENTRY_TITLE); her other entries (a moved visit, a care-plan change) carry
  // authorLabel's member number, so the test uses those (deviation recorded in ADR-132 addendum).
  it("an unnamed member's observation and her other entries in the same handover carry the same member number", () => {
    const number = (label: string) => /^Teammitglied (\d+)\b/.exec(label)?.[1];
    const observation = entryAuthorLabel({ kind: "observation", author: "member:3", detail: { content: "x" } });
    const moved = entryAuthorLabel({ kind: "visit_moved", author: "member:3", detail: {} });
    const plan = entryAuthorLabel({ kind: "care_plan_added", author: "member:3", detail: { content: "x" } });
    expect(moved).toBe(authorLabel("member:3"));
    expect(number(observation)).toBe("3");
    expect(number(observation)).toBe(number(moved));
    expect(number(observation)).toBe(number(plan));
  });

  it("the visit card meta line keeps AUTHOR_WITHOUT_NAME_TEXT for an unnamed colleague", () => {
    expect(observationAuthor({ own: false, author_name: "" })).toBe(AUTHOR_WITHOUT_NAME_TEXT);
  });

  it("other handover entry kinds keep their labels", () => {
    expect(entryAuthorLabel({ kind: "care_plan_added", author: "member:4", detail: { content: "x" } })).toBe("Teammitglied 4");
    expect(entryAuthorLabel({ kind: "observation", author: "me", detail: { content: "x" } })).toBe("Ich");
    expect(entryAuthorLabel({ kind: "observation", author: "system", detail: {} })).toBe("Automatisch");
  });
});

describe("UX2-29: 'Verantwortlich' and 'noch niemand' on /visits and /field", () => {
  const TODAY = "2026-11-03";

  it("the /visits label helper says 'noch niemand' when nobody is responsible on a visit still open", () => {
    expect(RESPONSIBLE_LABEL).toBe("Verantwortlich");
    expect(RESPONSIBLE_NOBODY_TEXT).toBe("noch niemand");
    for (const status of ["planned", "on_the_way", "started", "paused"]) {
      expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, visit_date: TODAY, status }, TODAY)).toBe(
        "noch niemand"
      );
    }
    expect(
      getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, visit_date: "2026-11-04", status: "planned" }, TODAY)
    ).toBe("noch niemand");
  });

  // UX2-29 as amended po 2026-11-03 06:30 (cra CGR-109, G-25 (c)): a visit no longer open claims no absence.
  it("a past visit with an empty responsible member reads 'nicht erfasst', never 'noch niemand'", () => {
    expect(RESPONSIBLE_NOT_RECORDED_TEXT).toBe("nicht erfasst");
    expect(
      getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, visit_date: "2026-11-02", status: "completed" }, TODAY)
    ).toBe("nicht erfasst");
    // dated before today, even if its status was never moved on
    expect(
      getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, visit_date: "2026-11-02", status: "planned" }, TODAY)
    ).toBe("nicht erfasst");
  });

  it("a visit of today or later with a status other than planned, on_the_way, started, paused reads 'nicht erfasst'", () => {
    for (const status of ["completed", "cancelled", "no_show", "interrupted", "assigned", "accepted"]) {
      expect(isVisitStillOpen({ visit_date: TODAY, status }, TODAY)).toBe(false);
      expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null, visit_date: TODAY, status }, TODAY)).toBe(
        "nicht erfasst"
      );
    }
  });

  it("a recorded responsible member is named whatever the date or status", () => {
    expect(
      getVisitResponsibleLabel(
        { responsible_user_id: "u1", responsible_name: "Synthetische Pflegekraft", visit_date: "2026-11-02", status: "completed" },
        TODAY
      )
    ).toBe("Synthetische Pflegekraft");
    expect(getVisitResponsibleLabel({ responsible_user_id: "u1", responsible_name: null, visit_date: TODAY, status: "planned" }, TODAY)).toBe(
      "Teammitglied"
    );
  });

  // UXR-79 with UX2-29: one label for the responsible member, one placeholder for both pickers.
  it("fieldLabel('responsible_user_id') is RESPONSIBLE_LABEL; the picker placeholder is 'Verantwortliche Person wählen'", () => {
    expect(fieldLabel("responsible_user_id")).toBe(RESPONSIBLE_LABEL);
    expect(RESPONSIBLE_PICK_TEXT).toBe("Verantwortliche Person wählen");
  });

  const ROOT = join(__dirname, "..", "..", "src", "app", "(protected)");
  function files(dir: string): string[] {
    return readdirSync(dir).flatMap((name) => {
      const path = join(dir, name);
      if (statSync(path).isDirectory()) return files(path);
      return /\.(tsx?|jsx?)$/.test(name) && !/\.backup\.|\.before-/.test(name) ? [path] : [];
    });
  }
  const screens = [...files(join(ROOT, "visits")), ...files(join(ROOT, "field"))];

  it("finds the screen files", () => {
    expect(screens.length).toBeGreaterThan(2);
  });

  it("no /visits or /field screen labels the responsible member 'Pflegekraft:' or 'Zuständig', or says 'Noch offen'", () => {
    const hits: string[] = [];
    for (const file of screens) {
      readFileSync(file, "utf8")
        .split("\n")
        .forEach((line, i) => {
          if (/Pflegekraft:|label="Pflegekraft"|"Noch offen"|Noch offen<|fieldLabel\("responsible_user_id"\)/.test(line)) hits.push(`${file}:${i + 1}`);
        });
    }
    expect(hits).toEqual([]);
  });

  it("both responsible-member pickers use RESPONSIBLE_PICK_TEXT, no bare 'Person wählen'", () => {
    const pickers = [
      join(ROOT, "team", "vorschlaege", "suggestions-client.tsx"),
      join(ROOT, "visits", "[visitId]", "lookback-actions.tsx"),
    ];
    for (const file of pickers) {
      const text = readFileSync(file, "utf8");
      expect(text).toContain("RESPONSIBLE_PICK_TEXT");
      expect(text).not.toMatch(/>\s*Person wählen\s*</);
    }
  });
});
