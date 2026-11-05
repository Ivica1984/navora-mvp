import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { linesOfTeams, recordBackLink, teamLookbackEntry } from "@/features/ai/labels";

// PLAN3-11 (ADR-149, brief PLAN3-11 as amended by AIG1-C5 (d)): after a stop, the team finds the look-back lines of its
// own records on `/team`. One entry per stop and team with at least one open line ("<n> offen · <m> nicht mehr offen"),
// one link to the list narrowed to the member's own teams, each line opening its record. No confirmer, no outcome, no
// person filter or sort (AIG1-12, AIG1-14); no new read.
const root = process.cwd();
const migration = readFileSync(join(root, "supabase/migrations/20261021000111_plan3_11_team_lookback.sql"), "utf8");
const teamClient = readFileSync(join(root, "src/app/(protected)/team/team-client.tsx"), "utf8");
const listPage = readFileSync(join(root, "src/app/(protected)/team/rueckblick/[stopId]/page.tsx"), "utf8");

const STOP = "0b1c2d3e-4f50-4a61-8b72-9c8d7e6f5a40";

describe("PLAN3-11 entry on /team", () => {
  it("names the agent and both counts in the AIG1-C1 wording", () => {
    expect(teamLookbackEntry({ stop_id: STOP, agent_name: "Tagesvorschlag", team_name: "Nord", open_count: 2, not_open_count: 1 })).toEqual({
      text: "Tagesvorschlag gestoppt · Werte: 2 offen · 1 nicht mehr offen",
      href: `/team/rueckblick/${STOP}`,
      linkText: "Werte ansehen",
    });
  });

  it("gives no entry at 0 offen (AIG1-C5 (d)) or for a stop id that is not a uuid", () => {
    expect(teamLookbackEntry({ stop_id: STOP, agent_name: "A", team_name: "Nord", open_count: 0, not_open_count: 3 })).toBeNull();
    expect(teamLookbackEntry({ stop_id: "x/../y", agent_name: "A", team_name: "Nord", open_count: 1, not_open_count: 0 })).toBeNull();
  });
});

describe("PLAN3-11 list narrowed to the member's own teams", () => {
  const lines = [
    { team_id: "t1", entity_id: "v1" },
    { team_id: "t2", entity_id: "v2" },
    { team_id: "t1", entity_id: "v3" },
  ];
  it("keeps only the lines of the given teams, in the reader's order (no own sort)", () => {
    expect(linesOfTeams(lines, ["t1"]).map((l) => l.entity_id)).toEqual(["v1", "v3"]);
  });
  it("keeps nothing when the member has no team on this stop (never widened)", () => {
    expect(linesOfTeams(lines, [])).toEqual([]);
  });
});

describe("PLAN3-11 back link from the record page", () => {
  it("leads back to the team's list when the record was opened from it", () => {
    expect(recordBackLink("team-rueckblick", STOP, { href: "/field", label: "Zurück" })).toEqual({
      href: `/team/rueckblick/${STOP}`,
      label: "Zurück zur Liste",
    });
  });
  it("keeps the Operations list and the home link unchanged", () => {
    expect(recordBackLink("rueckblick", STOP, { href: "/field", label: "Zurück" }).href).toBe(`/operations/assistenten/rueckblick/${STOP}`);
    expect(recordBackLink("team-rueckblick", "nope", { href: "/field", label: "Zurück" })).toEqual({ href: "/field", label: "Zurück" });
  });
});

describe("PLAN3-11 guards in the code", () => {
  it("the stop reader answers team members only and has no person or outcome column", () => {
    expect(migration).toMatch(/create or replace function public\.team_lookback_stops\(\)/);
    expect(migration).toMatch(/private\.is_team_member\(l\.team_id\)/);
    expect(migration).not.toMatch(/is_coordinator/);
    const returns = migration.match(/returns table \(([^)]*)\)/)?.[1] ?? "";
    expect(returns).not.toMatch(/confirm|outcome|user|person|member|actor|nurse/);
  });
  it("/team renders the entry and the list page opens each record with the team origin, without a confirmer", () => {
    expect(teamClient).toMatch(/team-lookback-entry/);
    expect(listPage).toMatch(/von=team-rueckblick&stopp=/);
    expect(listPage).toMatch(/linesOfTeams\(/);
    expect(listPage).not.toMatch(/bestätigt von|confirmed_by|confirmer/i);
  });
});
