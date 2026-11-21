import { describe, expect, it } from "vitest";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";

/**
 * IPA1-5 (ADR-099): no UI string in src/ presents an organisational fact as a client risk,
 * as monitoring, or as a health statement. Comments are not UI strings and are skipped.
 * IPA1-4 (ADR-099): the /matching demo and its client-side team-request scorer are gone.
 */

const ROOT = process.cwd();
const SRC = join(ROOT, "src");

/** Words that must not appear in a UI string (D-34 wording rule; IPA1 brief). */
const FORBIDDEN = /Risiko|Überwachung|überwacht|Gesundheitszustand|Diagnose/i;

/**
 * Allowed occurrences: `file` relative to the repository root, `phrase` the exact text that may
 * contain a forbidden word. Empty today. "Rettungsdienst alarmiert" and "Sicherheitssignal" stay
 * allowed by the brief and contain none of the words. Each entry must still match (no stale entries).
 */
const ALLOW: ReadonlyArray<{ file: string; phrase: string; reason: string }> = [];

function sourceFiles(dir: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) sourceFiles(path, out);
    else if (/\.(tsx?|jsx?|mjs)$/.test(entry.name)) out.push(path);
  }
  return out;
}

/** Removes comments but keeps line numbers: block comments become blank lines. */
function stripComments(source: string): string[] {
  const noBlocks = source.replace(/\/\*[\s\S]*?\*\//g, (block) => block.replace(/[^\n]/g, ""));
  return noBlocks.split("\n").map((line) => {
    if (/^\s*\/\//.test(line)) return "";
    // A trailing comment needs whitespace before "//" (keeps "https://…" in strings).
    return line.replace(/\s\/\/\s.*$/, "");
  });
}

function findForbidden(file: string, source: string): { line: number; text: string }[] {
  const hits: { line: number; text: string }[] = [];
  stripComments(source).forEach((line, i) => {
    if (!FORBIDDEN.test(line)) return;
    const allowed = ALLOW.some((a) => a.file === file && line.includes(a.phrase));
    if (!allowed) hits.push({ line: i + 1, text: line.trim() });
  });
  return hits;
}

describe("IPA1-5 wording check", () => {
  it("finds each forbidden word in a string and ignores comments", () => {
    for (const word of ["Risiko", "Top Risiko-Fälle", "Überwachung", "überwachte Zeit", "Gesundheitszustand", "Diagnose"]) {
      expect(findForbidden("x.tsx", `const t = "${word}";`)).toHaveLength(1);
    }
    expect(findForbidden("x.tsx", "<h2>Keine Risikofälle.</h2>")).toHaveLength(1);
    expect(findForbidden("x.tsx", "// Top Risiko-Fälle was removed\n/* überwacht */\nconst a = 1; // Risiko")).toHaveLength(0);
    expect(findForbidden("x.tsx", 'const ok = "Rettungsdienst alarmiert · Sicherheitssignal · besetzte Zeiten";')).toHaveLength(0);
  });

  it("keeps line numbers after a block comment", () => {
    expect(findForbidden("x.tsx", '/*\n a\n*/\nconst t = "Risiko";')).toEqual([{ line: 4, text: 'const t = "Risiko";' }]);
  });

  it("no UI string in src/ uses a forbidden word outside the allow-list", () => {
    const hits: string[] = [];
    for (const path of sourceFiles(SRC)) {
      const file = relative(ROOT, path);
      for (const hit of findForbidden(file, readFileSync(path, "utf8"))) hits.push(`${file}:${hit.line}: ${hit.text}`);
    }
    expect(hits).toEqual([]);
  });

  it("every allow-list entry still matches a file", () => {
    for (const entry of ALLOW) {
      expect(readFileSync(join(ROOT, entry.file), "utf8")).toContain(entry.phrase);
    }
  });
});

describe("IPA1-4 /matching demo scorer removed", () => {
  it("the route does not exist", () => {
    expect(existsSync(join(SRC, "app", "(protected)", "matching"))).toBe(false);
    expect(existsSync(join(SRC, "app", "matching"))).toBe(false);
  });

  it("no source file carries the scorer or links to the route", () => {
    const hits: string[] = [];
    for (const path of sourceFiles(SRC)) {
      const source = readFileSync(path, "utf8");
      if (/calculateMatchScore|getMatchSignals|teamFit|["'`]\/matching["'`]/.test(source)) hits.push(relative(ROOT, path));
    }
    expect(hits).toEqual([]);
  });
});
