import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  COUNTERSIGN_HEADING, FOLLOWUP_HEADING, RETURNED_HEADING, RETURNED_INSTRUCTION,
  countersignLabel, followupLabel, returnedInstructionLine, returnedLabel,
} from "@/features/field/todo";

// UX1-27 (b) (`cra` CGR-80, ADR-106) and UX1-30 (`uxa` UXR-20, `cra` 05:30, ADR-107): every link in the "Zu erledigen"
// row reads like the heading of the section it jumps to. The e2e (tests/e2e/ux1.spec.ts, field.spec.ts) check the
// rendered texts; this test pins the source so the two cannot drift.
const FIELD = readFileSync("src/app/(protected)/field/field-client.tsx", "utf8");
const REPORT = readFileSync("src/features/field/report.ts", "utf8");

/** The JSX of one section, from its opening tag to the matching </section>. */
function section(id: string): string {
  const start = FIELD.indexOf(`id="${id}"`);
  expect(start, id).toBeGreaterThan(0);
  const open = FIELD.lastIndexOf("<section", start);
  return FIELD.slice(open, FIELD.indexOf("</section>", start));
}

const LINKS = [
  { id: "entscheid-offen", constant: "FOLLOWUP_HEADING", label: "followupLabel", count: "openFollowups.length" },
  { id: "zurueckgegeben", constant: "RETURNED_HEADING", label: "returnedLabel", count: "returned.length" },
  { id: "gegenzeichnung", constant: "COUNTERSIGN_HEADING", label: "countersignLabel", count: "countersign.length" },
];

describe("UX1-27 / UX1-30: each 'Zu erledigen' link carries its section heading's name", () => {
  it("the headings keep their words", () => {
    expect(FOLLOWUP_HEADING).toBe("Nicht abgeschlossen: Entscheid offen");
    expect(RETURNED_HEADING).toBe("Zurückgegeben");
    expect(COUNTERSIGN_HEADING).toBe("Zur Gegenzeichnung");
  });

  it("link text equals the section heading for a seeded count, for all three links", () => {
    for (const n of [1, 3]) {
      expect(followupLabel(n)).toBe(`Nicht abgeschlossen: Entscheid offen (${n})`);
      expect(returnedLabel(n)).toBe(`Zurückgegeben (${n})`);
      expect(countersignLabel(n)).toBe(`Zur Gegenzeichnung (${n})`);
    }
  });

  for (const l of LINKS) {
    it(`#${l.id}: the link, the section label and the section h2 use ${l.constant}`, () => {
      const link = FIELD.match(new RegExp(`<a href="#${l.id}"[^>]*>([^<]*)</a>`));
      expect(link?.[1]).toBe(`{${l.label}(${l.count})}`);
      const s = section(l.id);
      expect(s).toMatch(new RegExp(`^<section aria-label=\\{${l.constant}\\} `));
      expect(s).toMatch(new RegExp(`<h2 className="[^"]*">\\{${l.label}\\(${l.count.replace(".", "\\.")}\\)\\}</h2>`));
    });
  }

  it("no second wording of a link or heading is left", () => {
    expect(FIELD).not.toMatch(/>Entscheid offen \(/);
    expect(FIELD).not.toMatch(/>Zurückgegeben \(/);
    expect(FIELD).not.toMatch(/>Zur Gegenzeichnung \(/);
    expect(FIELD).not.toContain("Zurückgegeben: bitte korrigieren und neu unterschreiben (");
  });
});

describe("UX1-30 cra conditions (05:30): the instruction moved into the returned-reports section", () => {
  it("(2) one constant, equal to the existing wording; rendered in sentence case only", () => {
    expect(RETURNED_INSTRUCTION).toBe("bitte korrigieren und neu unterschreiben");
    expect(returnedInstructionLine()).toBe("Bitte korrigieren und neu unterschreiben");
    expect(returnedInstructionLine().toLowerCase()).toBe(RETURNED_INSTRUCTION);
  });

  it("(1) always rendered inside returned-reports, after its h2 and before the first item, never collapsed", () => {
    const s = section("zurueckgegeben");
    const h2 = s.indexOf("</h2>");
    const line = s.indexOf('<p data-testid="returned-instruction"');
    const list = s.indexOf("<ul");
    expect(h2).toBeGreaterThan(0);
    expect(line).toBeGreaterThan(h2);
    expect(list).toBeGreaterThan(line);
    // Directly after the h2, unconditional (no `&&`, no ternary), with its text from the constant.
    expect(s.slice(h2, line)).toMatch(/^<\/h2>\s*$/);
    const tag = s.slice(line, s.indexOf("</p>", line));
    expect(tag).toContain("{returnedInstructionLine()}");
    expect(tag).not.toMatch(/hidden|sr-only|<details|collapse|aria-hidden/);
    expect(s).not.toMatch(/<details|aria-expanded/);
  });

  it("(3) the returner's name, the reason on each item and the visit-card label stay unchanged", () => {
    const s = section("zurueckgegeben");
    expect(s).toContain('{r.returned_by_name ? `${r.returned_by_name}: ` : ""}{r.reason}');
    expect(REPORT).toContain("label: `Zurückgegeben: bitte korrigieren und neu unterschreiben${version}`,");
    expect(REPORT).toContain("label: `Zurückgegeben – wartet auf neue Unterschrift${version}`,");
  });
});
