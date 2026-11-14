import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { REACH_DISTANCE_RULE_TEXT, REACH_HELP_TEXT } from "@/features/reach/rules";

// UXR-209 (uxa 2026-11-14 11:48, placed by PO amendment 12:39 (2)) and lca D-44 B-5 (PO amendment 12:39 (3)).
// Written before the code (red first: REACH_DISTANCE_RULE_TEXT did not exist). Words: `uxa`, verbatim.
// Facts behind the words (no new rule): migration 0130 `private.screen_order_reach` measures
// `min(d.distance_km)` over the team's service postcodes and compares it with
// `least(t.max_distance_km, o.radius_km)` (the team maximum when the client set no limit).

const ROOT = join(__dirname, "..", "..");
const read = (p: string) => readFileSync(join(ROOT, p), "utf8");

describe("UXR-209: the reach screen says how postcodes and km work together", () => {
  it("uses the uxa words verbatim", () => {
    expect(REACH_DISTANCE_RULE_TEXT).toBe(
      "NAVORA misst von der nächsten gewählten PLZ bis zum Einsatzort. Gibt der Auftraggeber eine kleinere Distanz an, gilt seine.",
    );
  });

  it("matches the database rule it describes (nearest postcode, smaller limit)", () => {
    const sql = read("supabase/migrations/20261021000130_bk_b1_reach_distance_filter.sql");
    expect(sql).toContain("select min(d.distance_km) from public.team_service_postcodes s");
    expect(sql).toContain("least(t.max_distance_km, o.radius_km)");
  });

  it("is the accessible description of the distance field, next to any error", () => {
    const tsx = read("src/app/(protected)/team/einsatzgebiet/reach-client.tsx");
    expect(tsx).toContain("REACH_DISTANCE_RULE_TEXT");
    expect(tsx).toMatch(/id=\{`\$\{kmId\}-rule`\}/);
    expect(tsx).toMatch(/aria-describedby=\{[^}]*`\$\{kmId\}-rule/);
  });
});

describe("lca D-44 B-5 (G-4 (c)): the area is the team's working area, not a home address", () => {
  it("keeps the lca help line", () => {
    expect(REACH_HELP_TEXT).toBe("PLZ, von der aus euer Team Aufträge annimmt. Nicht eure Wohnadresse.");
  });

  it("attaches the help line to the postcode field itself (the field says so)", () => {
    const tsx = read("src/app/(protected)/team/einsatzgebiet/reach-client.tsx");
    expect(tsx).toContain("REACH_HELP_TEXT");
    expect(tsx).toMatch(/id=\{`\$\{pcId\}-help`\}/);
    expect(tsx).toMatch(/<fieldset[^>]*aria-describedby=\{[^}]*`\$\{pcId\}-help/);
  });
});
