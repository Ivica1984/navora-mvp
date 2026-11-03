import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { AUTHOR_WITHOUT_NAME_TEXT, observationAuthor } from "@/features/field/authorship";
import { entryAuthorLabel } from "@/features/handover/rules";
import { getVisitResponsibleLabel, RESPONSIBLE_LABEL, RESPONSIBLE_NOBODY_TEXT } from "@/features/visits/types";

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

  it("a handover observation whose author has no name shows the constant, not a member code", () => {
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail: { content: "x" } })).toBe(AUTHOR_WITHOUT_NAME_TEXT);
    expect(entryAuthorLabel({ kind: "observation", author: "member:4", detail: { content: "x", author_name: "  " } })).toBe(
      AUTHOR_WITHOUT_NAME_TEXT
    );
  });

  it("other handover entry kinds keep their labels", () => {
    expect(entryAuthorLabel({ kind: "care_plan_added", author: "member:4", detail: { content: "x" } })).toBe("Teammitglied 4");
    expect(entryAuthorLabel({ kind: "observation", author: "me", detail: { content: "x" } })).toBe("Ich");
    expect(entryAuthorLabel({ kind: "observation", author: "system", detail: {} })).toBe("Automatisch");
  });
});

describe("UX2-29: 'Verantwortlich' and 'noch niemand' on /visits and /field", () => {
  it("the /visits label helper says 'noch niemand' when nobody is responsible", () => {
    expect(RESPONSIBLE_LABEL).toBe("Verantwortlich");
    expect(RESPONSIBLE_NOBODY_TEXT).toBe("noch niemand");
    expect(getVisitResponsibleLabel({ responsible_user_id: null, responsible_name: null })).toBe("noch niemand");
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
});
