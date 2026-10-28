import { readFileSync } from "node:fs";
import { join, sep } from "node:path";
import ts from "typescript";
import { describe, expect, it } from "vitest";
import { NAV_ITEMS, PAGE_LABEL } from "@/lib/auth/nav";
import { TEAM_PANEL_HEADING } from "@/features/operations/labels";
import { sourceFiles, userFacingStrings } from "./support/user-facing-strings";

// UX1 part (d), ADR-108. The user-facing strings are read from the syntax tree of every source file under the scanned
// folders (tests/unit/support/user-facing-strings.ts); code comments are not user-facing and are exempt. A decision or
// item code the reviewers need stays in the element's `data-ref` attribute (not shown to the reader).
const ROOTS = ["src/app/(protected)", "src/app/(auth)", "src/components"];
const EXTRA = ["src/lib/auth/nav.ts"]; // UXR-12: the menu labels
const FILES = [...ROOTS.flatMap(sourceFiles), ...EXTRA];
const STRINGS = FILES.flatMap(userFacingStrings);
const where = (s: { file: string; line: number; text: string }) => `${s.file}:${s.line}: ${s.text}`;

describe("UX1-11: no internal codes in user-facing text", () => {
  const CODE = /\b(D-\d+|SIG\d+(-\d+)?|F\d(–F\d|-F\d)?|PLAN\d|WORK\d|CGR-\d+|COND\d|IPA\d)\b/;

  it("the scan reads the pages (guard against an empty scan)", () => {
    expect(FILES.length).toBeGreaterThan(40);
    expect(STRINGS.some((s) => s.text.includes("Ich kann nicht arbeiten"))).toBe(true);
  });

  it("no decision, signal or item code outside a data-ref attribute", () => {
    expect(STRINGS.filter((s) => CODE.test(s.text)).map(where)).toEqual([]);
  });

  it("the codes that were shown stay available to reviewers as data-ref (UX1-12: meaning kept, code moved)", () => {
    const refs: Array<[string, string]> = [
      ["src/app/(protected)/field/cover-section.tsx", 'data-ref="D-3"'],
      ["src/app/(protected)/admin/admin-client.tsx", 'data-ref="D-26"'],
      ["src/app/(protected)/admin/outside-section.tsx", 'data-ref="SIG1-8"'],
      ["src/app/(protected)/team/team-client.tsx", 'data-ref="D-22"'],
      ["src/app/(protected)/team/team-client.tsx", 'data-ref="D-15"'],
      ["src/components/billing/billing-preview.tsx", '"D-11"'],
    ];
    for (const [file, ref] of refs) expect(readFileSync(file, "utf8"), `${file} ${ref}`).toContain(ref);
  });
});

describe("UX1-13: one product name, German labels", () => {
  it('no "Navora", "Swiss Care OS", "MVP", "Board", "Analytics", "Control Tower", "Drilldown" or "KPI" in user-facing text', () => {
    const FORBIDDEN = /Navora|Swiss Care OS|MVP|Board|Analytics|Control Tower|Drilldown|KPI/;
    expect(STRINGS.filter((s) => FORBIDDEN.test(s.text)).map(where)).toEqual([]);
  });

  it("no second name for a page survives (old labels and the NAVORA prefix of the day pages)", () => {
    const OLD = /Mein Tag \(mobil\)|NAVORA · |Teamanfragen|Teamzahlen|Operations Board|Zuweisungen aufnehmen|Pilotbetrieb verwalten|Pilot-Wirkung|Pilot Schweiz/;
    expect(STRINGS.filter((s) => OLD.test(s.text)).map(where)).toEqual([]);
  });
});

// One label per page: the menu item, the page's name and every header link to it from another page use PAGE_LABEL.
const PAGE_FILE: Record<keyof typeof PAGE_LABEL, string> = {
  operations: "src/app/(protected)/operations/operations-client.tsx",
  intake: "src/app/(protected)/intake/page.tsx",
  partners: "src/app/(protected)/partners/page.tsx",
  field: "src/app/(protected)/field/field-client.tsx",
  work: "src/app/(protected)/work/work-client.tsx",
  analytics: "src/app/(protected)/analytics/analytics-client.tsx",
  settings: "src/app/(protected)/settings/settings-client.tsx",
  admin: "src/app/(protected)/admin/admin-client.tsx",
  team: "src/app/(protected)/team/team-client.tsx",
};

// Inline action links inside a sentence or a call to action name the action, not the page (ADR-108):
// "Zum Team" is part of the CGR-32 notice confirmed by `cra` (kept word for word); the WORK1 link asks her to confirm.
const ACTION_LINKS = new Set([
  "src/app/(protected)/field/absence-section.tsx|Zum Team",
  "src/app/(protected)/field/field-client.tsx|Arbeitstag ansehen und bestätigen",
]);

type LinkUse = { file: string; route: string; text: string; usesLabel: string | null };

function tree(file: string): ts.SourceFile {
  return ts.createSourceFile(file, readFileSync(file, "utf8"), ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
}

function hrefPath(element: ts.JsxOpeningElement): string | null {
  for (const attr of element.attributes.properties) {
    if (!ts.isJsxAttribute(attr) || attr.name.getText() !== "href" || !attr.initializer) continue;
    const init = attr.initializer;
    if (ts.isStringLiteral(init)) return init.text;
    if (ts.isJsxExpression(init) && init.expression) {
      const e = init.expression;
      if (ts.isStringLiteral(e) || ts.isNoSubstitutionTemplateLiteral(e)) return e.text;
      if (ts.isTemplateExpression(e)) return e.head.text;
    }
  }
  return null;
}

function linkUses(file: string): LinkUse[] {
  const out: LinkUse[] = [];
  const visit = (node: ts.Node) => {
    if (ts.isJsxElement(node) && ["Link", "a"].includes(node.openingElement.tagName.getText())) {
      const href = hrefPath(node.openingElement);
      if (href?.startsWith("/")) {
        const children = node.children.filter((c) => !(ts.isJsxText(c) && !c.text.trim()));
        const only = children.length === 1 ? children[0] : null;
        const label = only && ts.isJsxExpression(only) && only.expression && ts.isPropertyAccessExpression(only.expression)
          && only.expression.expression.getText() === "PAGE_LABEL" ? only.expression.name.getText() : null;
        out.push({ file, route: href.split(/[?#]/)[0], text: node.children.map((c) => c.getText()).join("").replace(/\s+/g, " ").trim(), usesLabel: label });
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(tree(file));
  return out;
}

describe("UX1-13 / UXR-12: each page has one label", () => {
  it("the menu labels are PAGE_LABEL, one per page, all different", () => {
    for (const item of NAV_ITEMS) expect(item.label, item.key).toBe(PAGE_LABEL[item.key]);
    const labels = Object.values(PAGE_LABEL);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it("each page names itself with its label (heading, or the line above the date on the day pages)", () => {
    for (const [key, file] of Object.entries(PAGE_FILE)) {
      expect(readFileSync(file, "utf8"), `${file} uses PAGE_LABEL.${key}`).toMatch(new RegExp(`\\{PAGE_LABEL\\.${key}\\}`));
    }
  });

  it("every link to a labelled page from another page uses its label (except named inline action links)", () => {
    const routeKey = new Map(Object.keys(PAGE_LABEL).map((key) => [`/${key}`, key]));
    const wrong = FILES.filter((f) => f.endsWith(".tsx")).flatMap(linkUses).filter((use) => {
      const key = routeKey.get(use.route);
      if (!key) return false;
      if (use.file.includes(join("(protected)", key) + sep)) return false; // the page's own day/month navigation
      if (ACTION_LINKS.has(`${use.file}|${use.text}`)) return false;
      return use.usesLabel !== key;
    });
    expect(wrong.map((w) => `${w.file}: ${w.route} "${w.text}"`)).toEqual([]);
  });
});

// UX1-32 (`uxa` UXR-22, UXR-23; ADR-108 addendum). An eyebrow is a text-only element (literal text, no link, button or
// component inside) placed directly before a page's h1 in the same parent. The shell (side column, header row with
// links and menu) is not text-only, so it is not an eyebrow; the day pages' label line sits in the header row, not
// next to their date h1.
const PROTECTED_TSX = sourceFiles("src/app/(protected)").filter((f) => f.endsWith(".tsx"));

function hasLiteralText(node: ts.Node): boolean {
  if (ts.isJsxText(node) && node.text.trim()) return true;
  return node.getChildren().some(hasLiteralText);
}

function isTextOnly(node: ts.JsxChild): boolean {
  if (!ts.isJsxElement(node)) return false;
  let interactive = false;
  const visit = (n: ts.Node) => {
    if (ts.isJsxOpeningElement(n) || ts.isJsxSelfClosingElement(n)) {
      const tag = n.tagName.getText();
      if (/^[A-Z]/.test(tag) || ["a", "button", "input", "select", "form"].includes(tag)) interactive = true;
    }
    ts.forEachChild(n, visit);
  };
  node.children.forEach(visit);
  return !interactive && hasLiteralText(node);
}

function eyebrows(file: string): { headings: number; found: string[] } {
  const found: string[] = [];
  let headings = 0;
  const visit = (node: ts.Node) => {
    if (ts.isJsxElement(node) && node.openingElement.tagName.getText() === "h1") {
      headings += 1;
      const parent = node.parent;
      if (ts.isJsxElement(parent) || ts.isJsxFragment(parent)) {
        const siblings = parent.children.filter((c) => !(ts.isJsxText(c) && !c.text.trim()));
        for (const before of siblings.slice(0, siblings.indexOf(node))) {
          if (isTextOnly(before)) found.push(`${file}: "${before.getText().replace(/\s+/g, " ").slice(0, 80)}"`);
        }
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(tree(file));
  return { headings, found };
}

describe("UX1-32: one name per page", () => {
  it("(a) no protected page renders an eyebrow line above its h1", () => {
    const results = PROTECTED_TSX.map(eyebrows);
    expect(results.reduce((n, r) => n + r.headings, 0)).toBeGreaterThanOrEqual(7); // guard against an empty scan
    expect(results.flatMap((r) => r.found)).toEqual([]);
  });

  it("(a) the eyebrow detector catches the removed /partners line (self-test on a synthetic source)", () => {
    const src = `export default () => (<section><p style={{}}>Partner</p><h1>{PAGE_LABEL.partners}</h1></section>);`;
    const node = ts.createSourceFile("x.tsx", src, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
    let hit = false;
    const visit = (n: ts.Node) => {
      if (ts.isJsxElement(n) && n.openingElement.tagName.getText() === "h1" && ts.isJsxElement(n.parent)) {
        const sibs = n.parent.children.filter((c) => !(ts.isJsxText(c) && !c.text.trim()));
        hit = sibs.slice(0, sibs.indexOf(n)).some(isTextOnly);
      }
      ts.forEachChild(n, visit);
    };
    visit(node);
    expect(hit).toBe(true);
  });

  it('(b) the /operations team panel is headed "Details zum Pflegeteam" from one constant, in both states', () => {
    expect(TEAM_PANEL_HEADING).toBe("Details zum Pflegeteam");
    const ops = readFileSync("src/app/(protected)/operations/operations-client.tsx", "utf8");
    expect(ops.match(/<h2 style=\{sectionTitle\}>\{TEAM_PANEL_HEADING\}<\/h2>/g)?.length).toBe(2);
    expect(STRINGS.filter((s) => s.text.includes("Pflegeteam Detail")).map(where)).toEqual([]);
  });
});
