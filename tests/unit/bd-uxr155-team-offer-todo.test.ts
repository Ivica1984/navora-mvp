import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { TEAM_OFFERS_ANCHOR, TEAM_OFFERS_HEADING, openTeamOfferCount, teamOffersHref, teamOffersLabel } from "@/features/field/todo";

// BD / UXR-155 (ADR-179): a referral offered to her team shows up where the nurse starts (/field), as one neutral
// "Zu erledigen" link with the count that leads to the offers on /team. The decision stays on /team (team autonomy);
// the link names no client and no request (data minimisation, J2). tests/e2e/journey.spec.ts checks the rendered row.
const FIELD = readFileSync("src/app/(protected)/field/field-client.tsx", "utf8");
const FIELD_PAGE = readFileSync("src/app/(protected)/field/page.tsx", "utf8");
const TEAM = readFileSync("src/app/(protected)/team/team-client.tsx", "utf8");
const FIELD_QUERIES = readFileSync("src/features/field/queries.ts", "utf8");

/** The JSX of the team-offer link in the "Zu erledigen" row. */
function offerLink(): string {
  const at = FIELD.indexOf('data-testid="todo-team-offers"');
  expect(at, "todo-team-offers link").toBeGreaterThan(0);
  return FIELD.slice(FIELD.lastIndexOf("<a", at), FIELD.indexOf("</a>", at));
}

describe("UXR-155: open offers for her teams are counted as /team shows them", () => {
  it("counts the offers her teams have not declined, one per request and team", () => {
    expect(openTeamOfferCount([])).toBe(0);
    expect(openTeamOfferCount([{ my_team_declined: false }, { my_team_declined: true }, { my_team_declined: false }])).toBe(2);
    expect(openTeamOfferCount([{ my_team_declined: true }])).toBe(0);
  });

  it("the link text is the /team section heading with the count", () => {
    expect(TEAM_OFFERS_HEADING).toBe("Anfragen an dein Team");
    expect(teamOffersLabel(1)).toBe("Anfragen an dein Team (1)");
    expect(teamOffersLabel(4)).toBe("Anfragen an dein Team (4)");
  });

  it("the link leads to the offers section on /team", () => {
    expect(TEAM_OFFERS_ANCHOR).toBe("anfragen");
    expect(teamOffersHref()).toBe("/team#anfragen");
  });
});

describe("UXR-155: the /field row and the /team section use the same words", () => {
  it("/team: the offers heading carries the anchor and the constant", () => {
    expect(TEAM).toMatch(/<h2 id=\{TEAM_OFFERS_ANCHOR\} className="[^"]*">\{TEAM_OFFERS_HEADING\}<\/h2>/);
    expect(TEAM).not.toContain(">Anfragen an dein Team<");
  });

  it("/field: shown only from one open offer, neutral, with the count and nothing else", () => {
    const link = offerLink();
    expect(FIELD).toMatch(/\{openTeamOffers > 0 && \(\s*(\/\*[\s\S]*?\*\/\s*)?<a/);
    expect(link).toContain("href={teamOffersHref()}");
    expect(link).toContain('data-tone="info"');
    expect(link).toContain("{teamOffersLabel(openTeamOffers)}");
    // No urgency colour: the urgency stays on the offer card.
    expect(link).not.toMatch(/amber|red-|rose-|orange/);
    // The row itself appears when this is the only open item.
    expect(FIELD).toMatch(/\(openFollowups\.length > 0 \|\| [^)]*openTeamOffers > 0[^)]*\) && \(/);
  });

  it("/field receives a number only: no request title, region or client field reaches the client component", () => {
    expect(FIELD_PAGE).toContain("openTeamOffers={openTeamOffers}");
    expect(FIELD).toMatch(/openTeamOffers\?: number;/);
    expect(FIELD).not.toMatch(/request_title|TeamOffer\b/);
  });

  it("the count reads the same database path as /team (public.team_offers), and a failure hides only the link", () => {
    const fn = FIELD_QUERIES.slice(FIELD_QUERIES.indexOf("export async function getOpenTeamOfferCount"));
    expect(fn).toContain('supabase.rpc("team_offers")');
    expect(fn).toContain("openTeamOfferCount(");
    expect(fn).toMatch(/if \(error\) \{\s*logEvent\("error", "field\.team_offers_load_failed"/);
    expect(fn.slice(0, fn.indexOf("\n}\n"))).toContain("return 0;");
  });
});
