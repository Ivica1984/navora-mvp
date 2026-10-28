import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { FOLLOWUP_HEADING, followupLabel } from "@/features/field/todo";

// UX1-27 (b) (`cra` CGR-80, ADR-106): the "Zu erledigen" link to the open decisions reads like the section's own
// heading, "Nicht abgeschlossen: Entscheid offen (n)". The e2e (tests/e2e/ux1.spec.ts) checks the rendered texts.
const FIELD = readFileSync("src/app/(protected)/field/field-client.tsx", "utf8");

describe("UX1-27: the follow-up link keeps the section heading", () => {
  it("the heading keeps the words that say why a decision is open", () => {
    expect(FOLLOWUP_HEADING).toBe("Nicht abgeschlossen: Entscheid offen");
    expect(followupLabel(2)).toBe("Nicht abgeschlossen: Entscheid offen (2)");
  });

  it("the link, the section label and the section heading all use the one constant", () => {
    const link = FIELD.match(/<a href="#entscheid-offen"[^>]*>([^<]*)<\/a>/);
    expect(link?.[1]).toBe("{followupLabel(openFollowups.length)}");
    expect(FIELD).toMatch(/<section aria-label=\{FOLLOWUP_HEADING\} id="entscheid-offen"/);
    expect(FIELD).toMatch(/<h2 className="[^"]*">\{followupLabel\(openFollowups\.length\)\}<\/h2>/);
    // No second, shorter wording of the link.
    expect(FIELD).not.toMatch(/>Entscheid offen \(/);
  });
});
