import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  REACH_NEW_ORDERS_ONLY_TEXT,
  REACH_PATH,
  REACH_PROBLEM_CODES,
  parseDistanceKm,
  parsePostcodes,
  reachProblemsByField,
  reachProblemText,
} from "@/features/reach/rules";

// BK-b1s (PO amendment 2026-11-14 10:39 (3), AUT-117 (c); ADR-195 addendum 11:10): the team's own reach screen
// «Unser Einsatzgebiet». Written before the code (red first: the module did not exist). Words PROPOSED for `uxa`.

const ROOT = join(__dirname, "..", "..");

describe("BK-b1s: the reach screen's rules", () => {
  it("lives under the team's page", () => {
    expect(REACH_PATH).toBe("/team/einsatzgebiet");
  });

  it("knows exactly the three refusals of set_team_reach (migration 0130)", () => {
    expect(REACH_PROBLEM_CODES).toEqual(["missing_service_postcode", "postcode_not_in_list", "max_distance_not_positive"]);
  });

  it("(b) shows each refusal at its own field", () => {
    expect(reachProblemsByField(["missing_service_postcode", "max_distance_not_positive"])).toEqual({
      postcodes: [reachProblemText("missing_service_postcode")],
      distance: [reachProblemText("max_distance_not_positive")],
    });
    expect(reachProblemsByField(["postcode_not_in_list"])).toEqual({
      postcodes: [reachProblemText("postcode_not_in_list")],
      distance: [],
    });
  });

  it("words every refusal and never guesses an unknown code", () => {
    for (const code of REACH_PROBLEM_CODES) expect(reachProblemText(code)).toMatch(/\S/);
    expect(reachProblemText("missing_service_postcode")).toBe("Bitte mindestens eine PLZ wählen.");
    expect(reachProblemText("postcode_not_in_list")).toBe("Diese PLZ ist nicht in der Liste.");
    expect(reachProblemText("max_distance_not_positive")).toBe("Bitte eine Distanz grösser als 0 km eingeben.");
    expect(reachProblemText("something_else")).toBe("Nicht gespeichert. Bitte die Angaben prüfen.");
    expect(reachProblemsByField(["something_else"]).postcodes).toEqual(["Nicht gespeichert. Bitte die Angaben prüfen."]);
  });

  it("(d) says that a change applies to new orders only", () => {
    expect(REACH_NEW_ORDERS_ONLY_TEXT).toBe(
      "Eine Änderung gilt für neue Aufträge. Aufträge, die schon geprüft wurden, bleiben, wie sie sind.",
    );
  });

  it("reads a distance with a comma or a dot; empty or text is null (the database refuses, not the form)", () => {
    expect(parseDistanceKm("10")).toBe(10);
    expect(parseDistanceKm(" 7,5 ")).toBe(7.5);
    expect(parseDistanceKm("7.5")).toBe(7.5);
    expect(parseDistanceKm("0")).toBe(0);
    expect(parseDistanceKm("-3")).toBe(-3);
    expect(parseDistanceKm("")).toBeNull();
    expect(parseDistanceKm("zehn")).toBeNull();
    expect(parseDistanceKm("1e3")).toBeNull();
  });

  it("keeps the ticked postcodes once each, sorted", () => {
    expect(parsePostcodes(["4057", "4051", "4057", " ", ""])).toEqual(["4051", "4057"]);
  });

  it("(a) writes only through set_team_reach and reads only through my_team_reach (no table read in the app)", () => {
    const commands = readFileSync(join(ROOT, "src/features/reach/commands.ts"), "utf8");
    const queries = readFileSync(join(ROOT, "src/features/reach/queries.ts"), "utf8");
    expect(commands).toContain('rpc("set_team_reach"');
    expect(queries).toContain('rpc("my_team_reach"');
    for (const src of [commands, queries]) {
      expect(src).not.toMatch(/\.from\("(teams|team_service_postcodes)"\)/);
    }
  });
});
