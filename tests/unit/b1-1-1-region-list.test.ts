import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * B1.1-1 (a, Δ1) region list (brief docs/agents/briefs/B1.1.md; ADR-186). Written before the code (red first, task
 * rule 3): `src/features/regions/rules.ts` and the select fields do not exist on `recovery/main` `0ea663a`.
 * pgTAP 132 proves the database write path; this file guards the form side and the texts.
 */
const RULES = "src/features/regions/rules.ts";
// A computed path keeps typecheck and the other unit files green while the module is missing (red first).
type Rules = {
  regionOptions: (rows: { id: string; name: string; sort_order: number; active: boolean }[]) => { value: string; label: string }[];
  isListedRegion: (value: string, list: readonly string[]) => boolean;
  mapRegionResultText: (result: string) => string;
  REGION_NOT_IN_LIST_MESSAGE: string;
  UNMAPPED_REGIONS_HEADING: string;
};
const load = async (): Promise<Rules | null> =>
  existsSync(RULES) ? ((await import(/* @vite-ignore */ ["..", "..", RULES.replace(/\.ts$/, "")].join("/"))) as Rules) : null;

describe("B1.1-1 region list (form side)", () => {
  it("has a rules module", () => {
    expect(existsSync(RULES)).toBe(true);
  });

  it("offers only active list entries, in list order, never a free-text option", async () => {
    const m = await load();
    expect(m).not.toBeNull();
    const rows = [
      { id: "b", name: "Basel-Landschaft", sort_order: 2, active: true },
      { id: "x", name: "Alt", sort_order: 3, active: false },
      { id: "a", name: "Basel-Stadt", sort_order: 1, active: true },
    ];
    expect(m!.regionOptions(rows)).toEqual([
      { value: "Basel-Stadt", label: "Basel-Stadt" },
      { value: "Basel-Landschaft", label: "Basel-Landschaft" },
    ]);
  });

  it("accepts a list name exactly and refuses everything else (no silent correction)", async () => {
    const m = await load();
    const list = ["Basel-Stadt", "Basel-Landschaft"];
    expect(m!.isListedRegion("Basel-Stadt", list)).toBe(true);
    for (const v of ["Basel Stadt", "basel-stadt", " Basel-Stadt", "Bern West", "", "Basel Pilot"]) {
      expect(m!.isListedRegion(v, list)).toBe(false);
    }
  });

  it("names the refusal in plain words and the mapping heading as the brief says", async () => {
    const m = await load();
    expect(m!.REGION_NOT_IN_LIST_MESSAGE).toBe("Bitte eine Region aus der Liste wählen.");
    expect(m!.UNMAPPED_REGIONS_HEADING).toBe("Region nicht zugeordnet");
  });

  it("maps every mapping result to a German message and never shows a code", async () => {
    const m = await load();
    for (const r of ["ok", "duplicate", "already_mapped", "not_found", "rejected"]) {
      const text = m!.mapRegionResultText(r);
      expect(text.length).toBeGreaterThan(5);
      expect(text).not.toMatch(/_/);
    }
  });

  it("the intake and team forms use a select for the region, never a free-text input", () => {
    for (const file of ["src/app/(protected)/intake/intake-client.tsx", "src/app/(protected)/admin/admin-client.tsx"]) {
      const src = readFileSync(file, "utf8");
      expect(src, file).not.toMatch(/<input[^>]*name="region"/);
      expect(src, file).toMatch(/<select[^>]*name="region"/);
    }
  });
});
