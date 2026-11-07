import { describe, expect, it } from "vitest";
import {
  STEP_FIGURES,
  STEP_SPAN_MEASURES,
  TARGET_WORDS,
  buildStepScopes,
  formatStep,
  type StepSourceRow,
} from "@/features/analytics/step-spans";

// AN3 (brief docs/agents/briefs/AN3.md, ADR-144): "Wo die Nicht-Pflegezeit hingeht". Pure rules, written before the code.

const ORG = "00000000-0000-4000-b000-000000000012";
const TEAM = "00000000-0000-4000-a000-000000000101";

function row(over: Partial<StepSourceRow> & { key: string }): StepSourceRow {
  return { organization_id: ORG, team_id: TEAM, team_name: "Bern West", value: 1, base: 10, too_few: false, note: null, ...over };
}

describe("AN3 figures", () => {
  it("AN3-1: names (a) to (e) once each, in the brief's order, after the care share and travel (AN3-2)", () => {
    expect(STEP_FIGURES.map((f) => f.key)).toEqual([
      "direct_care_share",
      "travel_share_in_visits",
      "report_final_minutes",
      "countersign_latency_hours",
      "report_returned_share",
      "time_correction_share",
      "referral_to_case_ready_hours",
      "inform_gp_done_hours",
      "inform_gp_open_at_month_end",
      "inform_gp_open_age_days",
      "proposal_decided_hours",
      "proposals_corrected",
      "proposals_rejected",
      "proposals_expired_undecided",
    ]);
    expect(new Set(STEP_FIGURES.map((f) => f.key)).size).toBe(STEP_FIGURES.length);
  });

  it("AN3-1 (a), (b) and the care share are reused from AN1/AN2, never recomputed by AN3", () => {
    const source = Object.fromEntries(STEP_FIGURES.map((f) => [f.key, f.from]));
    expect(source.direct_care_share).toBe("kpi");
    expect(source.report_final_minutes).toBe("kpi");
    expect(source.time_correction_share).toBe("kpi");
    expect(source.countersign_latency_hours).toBe("hypothesis");
    expect(source.report_returned_share).toBe("hypothesis");
    // only the new figures come from the AN3 read
    expect(STEP_FIGURES.filter((f) => f.from === "span").map((f) => f.key).sort()).toEqual([...STEP_SPAN_MEASURES].sort());
  });

  it("AN3-2: travel is labelled as travel within visits only", () => {
    const travel = STEP_FIGURES.find((f) => f.key === "travel_share_in_visits")!;
    expect(travel.label).toMatch(/im Einsatz/);
    expect(travel.definition).toMatch(/Rückweg/);
    expect(travel.definition).toMatch(/nicht gemessen/);
  });

  it("AN3-5: the countersign span stands beside the returned share and time corrections of the same team", () => {
    const keys = STEP_FIGURES.map((f) => f.key);
    const i = keys.indexOf("countersign_latency_hours");
    expect(keys.slice(i, i + 3)).toEqual(["countersign_latency_hours", "report_returned_share", "time_correction_share"]);
  });

  it("CGR-112: the decision span (e) stands beside the changed, rejected and expired counts", () => {
    const keys = STEP_FIGURES.map((f) => f.key);
    const i = keys.indexOf("proposal_decided_hours");
    expect(keys.slice(i, i + 4)).toEqual(["proposal_decided_hours", "proposals_corrected", "proposals_rejected", "proposals_expired_undecided"]);
    expect(STEP_FIGURES[i].definition).toMatch(/kein Richtwert/);
  });

  it("AN3-5: no figure carries a reference value, and no label or note uses a target word", () => {
    expect(TARGET_WORDS).toEqual(["Ziel", "Soll", "besser", "zu langsam"]);
    for (const f of STEP_FIGURES) {
      expect(f).not.toHaveProperty("reference");
      const text = `${f.label} ${f.definition} ${f.source}`.toLowerCase();
      for (const w of TARGET_WORDS) expect(text, `${f.key} contains "${w}"`).not.toContain(w.toLowerCase());
    }
  });

  it("AN3-3: no figure is per person", () => {
    for (const f of STEP_FIGURES) expect(`${f.label} ${f.definition}`).not.toMatch(/pro Person|pro Pflegende[rn]?\b|pro Mitglied/);
  });
});

describe("AN3 formatting", () => {
  it("formats hours, minutes, days, shares and counts in de-CH", () => {
    expect(formatStep("Std.", 4.5)).toBe("4.5 Std.");
    expect(formatStep("Min.", 12)).toBe("12 Min.");
    expect(formatStep("Tage", "2.25")).toBe("2.3 Tage");
    expect(formatStep("%", 37.5)).toBe("37.5 %");
    expect(formatStep("", 3)).toBe("3");
    expect(formatStep("Std.", null)).toBe("–");
    expect(formatStep("Std.", "x")).toBe("–");
  });
});

describe("AN3 scopes", () => {
  it("builds one scope per team and the organisation first, taking each figure from its own source", () => {
    const scopes = buildStepScopes(
      [row({ key: "direct_care_share", value: 61 }), row({ key: "direct_care_share", team_id: null, team_name: null, value: 58 })],
      [row({ key: "countersign_latency_hours", value: 5 })],
      [row({ key: "referral_to_case_ready_hours", value: 26 })],
    );
    expect(scopes.map((s) => s.title)).toEqual(["Ganze Organisation", "Team Bern West"]);
    const team = scopes[1];
    expect(team.figures.map((f) => f.key)).toEqual(STEP_FIGURES.map((f) => f.key));
    expect(team.figures.find((f) => f.key === "direct_care_share")!.value).toBe(61);
    expect(team.figures.find((f) => f.key === "countersign_latency_hours")!.value).toBe(5);
    expect(team.figures.find((f) => f.key === "referral_to_case_ready_hours")!.value).toBe(26);
    // a figure without a source row shows no value, never 0
    expect(team.figures.find((f) => f.key === "inform_gp_done_hours")!.value).toBeNull();
    expect(scopes[0].figures.find((f) => f.key === "direct_care_share")!.value).toBe(58);
  });

  it("AN3-4: keeps 'zu wenig Daten' and a hidden value (suppression is the database's, never undone here)", () => {
    const scopes = buildStepScopes(
      [],
      [],
      [
        row({ key: "proposal_decided_hours", value: 3, base: 4, too_few: true }),
        row({ key: "travel_share_in_visits", value: null, base: null, too_few: true, note: "Zu wenig Personen" }),
      ],
    );
    const f = scopes[0].figures;
    expect(f.find((x) => x.key === "proposal_decided_hours")).toMatchObject({ value: 3, base: 4, tooFew: true });
    expect(f.find((x) => x.key === "travel_share_in_visits")).toMatchObject({ value: null, base: null, note: "Zu wenig Personen" });
  });

  it("ignores rows of figures AN3 does not show", () => {
    const scopes = buildStepScopes([row({ key: "billable_per_care_minute" })], [row({ key: "coordinator_ends" })], []);
    expect(scopes).toHaveLength(1);
    expect(scopes[0].figures.every((f) => f.value === null)).toBe(true);
  });
});
