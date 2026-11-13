import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import * as rules from "@/features/regions/rules";

/**
 * B1.1-1b (ADR-187; brief B1.1 §PO 08:39 point 1). Written before the code (task rule 3):
 *  - CGR-202 (b) (cra 05:29, wording uxa 07:52): when teams carry the value, the confirming sentence also says that
 *    those teams can then be offered the open team searches of the new region («können»: eligibility at read time,
 *    0017:358-374); no team name in the sentence.
 *  - CGR-201 safety net (PO 06:39 point 2, texts uxa 07:52): a value already mapped whose rows still carry the old text
 *    is shown with «Bereits «…» zugeordnet. Seither neu mit dem alten Wert:» and the region as text, no select.
 *  - UXR-187 (uxa 07:52, low): the `role="status"` container is mounted, empty, before the act; after success focus
 *    moves to the section heading (tabIndex -1), never to the live region (UXR-41).
 */
type Counts = { teams: number; cases: number; referrals: number; open_searches: number };
type Extra = {
  mapRegionConfirmSentence: (from: string, to: string, row: Counts) => string;
  mappedRegionNote: (to: string) => string;
  mappedRegionLabel: (to: string) => string;
};
const m = rules as unknown as Partial<Extra>;
const row = (teams: number, cases: number, referrals: number, open_searches: number): Counts => ({ teams, cases, referrals, open_searches });

describe("CGR-202 (b): the team side of «Zuordnen»", () => {
  it("one team: names that the team can then be offered the new region's open searches", () => {
    const s = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(1, 0, 0, 0));
    expect(s).toContain(
      "Das Team mit «Bern West» gehört danach zu «Basel-Stadt»; ihm können dann offene Teamsuchen aus «Basel-Stadt» angeboten werden.",
    );
  });

  it("several teams: plural with the count", () => {
    const s = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(2, 3, 0, 1));
    expect(s).toContain(
      "Die 2 Teams mit «Bern West» gehören danach zu «Basel-Stadt»; ihnen können dann offene Teamsuchen aus «Basel-Stadt» angeboten werden.",
    );
  });

  it("stands after the search sentence and before the undo sentence", () => {
    const s = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(2, 3, 0, 1));
    const search = s.indexOf("Offene Teamsuchen können danach");
    const team = s.indexOf("Die 2 Teams mit");
    const undo = s.indexOf("nicht rückgängig");
    expect(search).toBeGreaterThan(-1);
    expect(team).toBeGreaterThan(search);
    expect(undo).toBeGreaterThan(team);
  });

  it("is left out when no team carries the value", () => {
    const s = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(0, 2, 1, 0));
    expect(s).not.toContain("Team mit");
    expect(s).not.toContain("Teams mit");
    expect(s).not.toContain("angeboten");
  });
});

describe("CGR-201 safety net: a mapped value with rows still on the old text", () => {
  it("says the value is already mapped and what follows is new since then", () => {
    expect(m.mappedRegionNote!("Basel-Stadt")).toBe("Bereits «Basel-Stadt» zugeordnet. Seither neu mit dem alten Wert:");
  });

  it("shows the region as text instead of a choice", () => {
    expect(m.mappedRegionLabel!("Basel-Stadt")).toBe("Region: Basel-Stadt");
  });

  it("the panel offers no select for such a row and still confirms before the command", () => {
    const src = readFileSync("src/app/(protected)/operations/unmapped-regions-panel.tsx", "utf8");
    expect(src).toMatch(/mappedRegionNote\(/);
    expect(src).toMatch(/mappedRegionLabel\(/);
    expect(src).toMatch(/mapped_region_id/);
  });
});

describe("UXR-187: live region and focus", () => {
  const src = readFileSync("src/app/(protected)/operations/unmapped-regions-panel.tsx", "utf8");

  it("mounts the status container unconditionally (not behind done.length)", () => {
    expect(src).toMatch(/<div role="status" data-testid="region-mapped"/);
    expect(src).not.toMatch(/done\.length > 0 && \(\s*<div role="status"/);
  });

  it("moves focus to the heading after success, never to the live region", () => {
    expect(src).toMatch(/<h2[^>]*tabIndex=\{-1\}/);
    expect(src).toMatch(/headingRef\.current\?\.focus\(\)/);
    expect(src).not.toMatch(/<div role="status"[^>]*tabIndex/);
  });
});
