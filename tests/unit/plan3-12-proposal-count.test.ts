import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { countOpenSuggestions, suggestionsLink } from "@/features/ai/labels";

// PLAN3-12 (ADR-148, `uxa` UXR-68): the entry to `/team/vorschlaege` on `/team` shows how many proposals wait.
// Count only: no client name, no person, no colour above `info`, no deadline word (H-20). Counted from the rows the
// member already reads (`open_suggestions` per team); no new read.
const root = process.cwd();
const teamClient = readFileSync(join(root, "src/app/(protected)/team/team-client.tsx"), "utf8");
const teamPage = readFileSync(join(root, "src/app/(protected)/team/page.tsx"), "utf8");
const queries = readFileSync(join(root, "src/features/ai/queries.ts"), "utf8");

describe("PLAN3-12 link text", () => {
  it("reads 'Vorschläge (<n>)' with the aria-label '<n> offene Vorschläge' when at least one proposal is open", () => {
    expect(suggestionsLink(5)).toEqual({ text: "Vorschläge (5)", ariaLabel: "5 offene Vorschläge" });
    expect(suggestionsLink(4)).toEqual({ text: "Vorschläge (4)", ariaLabel: "4 offene Vorschläge" });
    expect(suggestionsLink(1)).toEqual({ text: "Vorschläge (1)", ariaLabel: "1 offene Vorschläge" });
  });

  it("reads plain 'Vorschläge' without an aria-label at 0", () => {
    expect(suggestionsLink(0)).toEqual({ text: "Vorschläge", ariaLabel: undefined });
  });

  it("reads plain 'Vorschläge' when the count is unknown (failed read): a missing count is never shown as a number", () => {
    expect(suggestionsLink(null)).toEqual({ text: "Vorschläge", ariaLabel: undefined });
    expect(suggestionsLink(Number.NaN)).toEqual({ text: "Vorschläge", ariaLabel: undefined });
    expect(suggestionsLink(-1)).toEqual({ text: "Vorschläge", ariaLabel: undefined });
  });

  it("carries no deadline word, no urgency word and no name (H-20)", () => {
    for (const n of [0, 1, 7, 120]) {
      const { text, ariaLabel } = suggestionsLink(n);
      const all = `${text} ${ariaLabel ?? ""}`;
      expect(all).not.toMatch(/heute|bis|frist|dringend|sofort|jetzt|überfällig|!/i);
      expect(all).toMatch(/^Vorschläge( \(\d+\))?( \d+ offene Vorschläge)? ?$/);
    }
  });
});

describe("PLAN3-12 count", () => {
  it("sums the open proposals of every team the member reads", () => {
    expect(countOpenSuggestions([3, 2])).toBe(5);
    expect(countOpenSuggestions([0])).toBe(0);
    expect(countOpenSuggestions([])).toBe(0);
  });

  it("is unknown (null) when any team's read failed, never a partial number", () => {
    expect(countOpenSuggestions([3, null])).toBeNull();
    expect(countOpenSuggestions([null])).toBeNull();
  });
});

describe("PLAN3-12 wiring", () => {
  it("the /team link uses the count text and its aria-label, with no colour above info", () => {
    const link = teamClient.slice(teamClient.indexOf('href="/team/vorschlaege"') - 40, teamClient.indexOf('href="/team/vorschlaege"') + 400);
    expect(teamClient).toContain("suggestionsLink(openSuggestions)");
    expect(link).toContain("aria-label={suggestionsEntry.ariaLabel}");
    expect(link).toContain("{suggestionsEntry.text}");
    expect(link).not.toMatch(/red-|amber-|orange-|rose-|yellow-/);
  });

  it("the count comes from open_suggestions through the member's own teams (no new read, no new RPC)", () => {
    const fn = queries.slice(queries.indexOf("export async function getOpenSuggestionCount"));
    expect(fn).toContain('rpc("open_suggestions"');
    expect(fn.slice(0, fn.indexOf("\n}\n"))).not.toMatch(/\.from\(/);
    expect(teamPage).toContain("getOpenSuggestionCount");
  });
});
