import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// UX1-17 (ADR-105, UXR-2): no text colour with an opacity below 80 % under src/app/(protected), src/app/(auth) and
// src/components. Secondary text uses the one class `text-secondary` (globals.css). Documented exceptions for
// non-text decoration: none today.
const ROOTS = ["src/app/(protected)", "src/app/(auth)", "src/components"];
const LOW_OPACITY_TEXT = /text-[a-z]+-\d{3}\/(10|20|30|40|50|60|70)\b/g;

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return files(path);
    return /\.(tsx|ts)$/.test(name) ? [path] : [];
  });
}

describe("UX1-17: secondary text is readable", () => {
  it("no text colour below 80 % opacity in the scanned folders", () => {
    const hits = ROOTS.flatMap(files).flatMap((file) =>
      (readFileSync(file, "utf8").match(LOW_OPACITY_TEXT) ?? []).map((m) => `${file}: ${m}`),
    );
    expect(hits).toEqual([]);
  });

  it("the secondary-text class exists and uses stone-700 (DESIGN_SYSTEM.md §7 interim value)", () => {
    const css = readFileSync("src/app/globals.css", "utf8");
    expect(css).toMatch(/@utility text-secondary\s*\{\s*color:\s*var\(--color-stone-700\);/);
  });

  it("UX1-19 (ii): :root declares color-scheme light and no dark override exists", () => {
    const css = readFileSync("src/app/globals.css", "utf8");
    expect(css).toMatch(/:root\s*\{[^}]*color-scheme:\s*light;/);
    expect(css).not.toMatch(/prefers-color-scheme:\s*dark/);
  });
});

// UX1-16: /login addresses every user. Code comments are not user-facing and are stripped before the scan.
const LOGIN_DIR = "src/app/(auth)/login";
const LOGIN_FORBIDDEN = ["Admin / Coach", "Attention Center", "Operations-Lage", "Teams Übersicht", "Navora"];

function withoutComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:])\/\/.*$/gm, "$1");
}

describe("UX1-16: one sign-in page for every role", () => {
  for (const file of files(LOGIN_DIR)) {
    it(`${file} has no role-specific or old product wording`, () => {
      const text = withoutComments(readFileSync(file, "utf8"));
      for (const word of LOGIN_FORBIDDEN) expect(text, word).not.toContain(word);
    });
  }

  it("the page heading is the same for every role", () => {
    const text = readFileSync(join(LOGIN_DIR, "page.tsx"), "utf8");
    expect(text).toContain("Bei NAVORA anmelden");
  });
});
