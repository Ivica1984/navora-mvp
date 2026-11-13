import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import * as rules from "@/features/regions/rules";

/**
 * B1.1-1 (Δ1, ADR-186 amendment 04:30), uxa UXR-184 (high) and UXR-185 (low) on PR #1164. Written before the code
 * (task rule 3): «Zuordnen» rewrites every team, case, referral and open search of a value in one tap, so it needs an
 * in-place confirming step whose sentence is built from the row counts and claims no more than the database does:
 * a mapping cannot be undone on this screen (map_legacy_region has no reverse, a second call is `already_mapped`) and
 * an open search that moves to the new region can then be offered to that region's active teams
 * (private.request_offered_to_team compares t.region = m.region at read time, 0017:358-374).
 */
type Counts = { teams: number; cases: number; referrals: number; open_searches: number };
type Extra = {
  regionCountLine: (row: Counts) => string;
  mapRegionConfirmSentence: (from: string, to: string, row: Counts) => string;
  mapRegionDoneText: (from: string, to: string) => string;
  MAP_REGION_CONFIRM_LABEL: string;
};
const m = rules as unknown as Partial<Extra>;

const row = (teams: number, cases: number, referrals: number, open_searches: number): Counts => ({ teams, cases, referrals, open_searches });

describe("B1.1-1 «Region nicht zugeordnet»: count line (UXR-185)", () => {
  it("names open searches first, then referrals, cases, teams; leaves out zero counts", () => {
    expect(typeof m.regionCountLine).toBe("function");
    expect(m.regionCountLine!(row(2, 3, 0, 1))).toBe("1 offene Teamsuche · 3 Fälle · 2 Teams");
    expect(m.regionCountLine!(row(0, 0, 4, 2))).toBe("2 offene Teamsuchen · 4 Anfragen");
  });

  it("uses singular and plural", () => {
    expect(m.regionCountLine!(row(1, 1, 1, 1))).toBe("1 offene Teamsuche · 1 Anfrage · 1 Fall · 1 Team");
    expect(m.regionCountLine!(row(2, 2, 2, 2))).toBe("2 offene Teamsuchen · 2 Anfragen · 2 Fälle · 2 Teams");
  });

  it("says plainly when nothing uses the value any more", () => {
    expect(m.regionCountLine!(row(0, 0, 0, 0))).toBe("Zurzeit von keinem Eintrag verwendet.");
  });
});

describe("B1.1-1 «Zuordnen»: confirming step (UXR-184)", () => {
  it("states what changes, from the counts, and that it cannot be undone here", () => {
    expect(typeof m.mapRegionConfirmSentence).toBe("function");
    const s = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(2, 3, 0, 1));
    expect(s).toContain("«Bern West»");
    expect(s).toContain("«Basel-Stadt»");
    expect(s).toContain("1 offenen Teamsuche");
    expect(s).toContain("3 Fällen");
    expect(s).toContain("2 Teams");
    expect(s).not.toContain("Anfrage");
    expect(s).toContain("nicht rückgängig");
  });

  it("names the effect on open searches only when there is one, and claims no more than «können»", () => {
    const withSearch = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(1, 0, 0, 2));
    expect(withSearch).toContain("können danach Teams in «Basel-Stadt» angeboten werden");
    const without = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(1, 1, 1, 0));
    // B1.1-1b (ADR-187): the team side (CGR-202 (b)) now says «angeboten» for the team; the search sentence stays absent.
    expect(without).not.toContain("Offene Teamsuchen können danach");
    expect(without).not.toContain("Teams in «Basel-Stadt» angeboten");
    const noTeamNoSearch = m.mapRegionConfirmSentence!("Bern West", "Basel-Stadt", row(0, 1, 1, 0));
    expect(noTeamNoSearch).not.toContain("angeboten");
  });

  it("uses singular and plural in the dative", () => {
    const one = m.mapRegionConfirmSentence!("A", "B", row(1, 1, 1, 1));
    expect(one).toContain("1 offenen Teamsuche, 1 Anfrage, 1 Fall und 1 Team");
    const many = m.mapRegionConfirmSentence!("A", "B", row(2, 2, 2, 2));
    expect(many).toContain("2 offenen Teamsuchen, 2 Anfragen, 2 Fällen und 2 Teams");
  });

  it("keeps a result line that names both values", () => {
    expect(m.mapRegionDoneText!("Bern West", "Basel-Stadt")).toBe("Region zugeordnet: Bern West → Basel-Stadt");
    expect(m.MAP_REGION_CONFIRM_LABEL).toBe("Zuordnen");
  });

  it("the panel runs the command only from the confirming step and keeps the result line", () => {
    const src = readFileSync("src/app/(protected)/operations/unmapped-regions-panel.tsx", "utf8");
    expect(src).toMatch(/import ConfirmStep from "@\/app\/\(protected\)\/admin\/confirm-step"/);
    expect(src).toMatch(/mapRegionConfirmSentence\(/);
    expect(src).toMatch(/mapRegionDoneText\(/);
    expect(src).toMatch(/role="status"/);
    // The form submit only opens the step; the command is called in the step's onConfirm.
    const submit = src.slice(src.indexOf("onSubmit"), src.indexOf("onSubmit") + 400);
    expect(submit).not.toMatch(/mapLegacyRegion\(/);
  });
});
