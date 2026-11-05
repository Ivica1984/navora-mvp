import { describe, expect, it } from "vitest";
import { NAV_ITEMS, NO_ACCESS, PAGE_LABEL, menuItemsFor, type NavAccess } from "@/lib/auth/nav";
import { MORE_LABEL, TAB_KEYS, TAB_LABEL, activeNavKey, homeTabFor, shellItemsFor, tabLabel } from "@/lib/auth/shell";
import { HOME_PATH, homePathForRoles } from "@/lib/auth/paths";

// UX2-1 (ADR-131): one shell for every protected route. On a phone a tab bar Heute (/field), Team (/team),
// Arbeitstag (/work) and "Mehr" (every other page the role may open, /settings among them); on a desktop a sidebar
// with the same items. Items per role come from the UX1-3 route → roles map (`NAV_ITEMS`), the one source.

const hrefs = (items: ReadonlyArray<{ href: string }>) => items.map((i) => i.href);

describe("UX2-1: tab bar and Mehr come from the one route → roles map", () => {
  it("/team is an item of the map, checked like /field (own team membership)", () => {
    const team = NAV_ITEMS.find((i) => i.key === "team");
    expect(team?.href).toBe("/team");
    expect(team?.label).toBe(PAGE_LABEL.team);
    expect(team?.check).toEqual({ kind: "team_member" });
  });

  it("the tab labels are the brief's words, in the brief's order", () => {
    expect(TAB_KEYS).toEqual(["field", "team", "work"]);
    expect(TAB_LABEL).toEqual({ field: "Heute", team: "Team", work: "Arbeitstag" });
    expect(MORE_LABEL).toBe("Mehr");
  });

  it("a nurse in a team: Heute, Team, Arbeitstag as tabs; figures and settings under Mehr", () => {
    const { tabs, more } = shellItemsFor({ roles: ["nurse"], inTeam: true });
    expect(hrefs(tabs)).toEqual(["/field", "/team", "/work"]);
    expect(hrefs(more)).toEqual(["/analytics", "/settings"]);
  });


  it("an administrator in a team: three tabs, administration under Mehr", () => {
    const { tabs, more } = shellItemsFor({ roles: ["admin"], inTeam: true });
    expect(hrefs(tabs)).toEqual(["/field", "/team", "/work"]);
    expect(hrefs(more)).toEqual(["/operations", "/intake", "/analytics", "/settings", "/admin"]);
  });

  it("tabs and Mehr together are exactly the menu (no item lost, none added, none twice)", () => {
    for (const access of [
      { roles: ["nurse"], inTeam: true },
      { roles: ["nurse"], inTeam: false },
      { roles: ["coach"], inTeam: false },
      { roles: ["operations"], inTeam: true },
      { roles: ["admin"], inTeam: false },
      { roles: ["guest"], inTeam: false },
      NO_ACCESS,
    ] satisfies NavAccess[]) {
      for (const demo of [false, true]) {
        const { tabs, more } = shellItemsFor(access, demo);
        expect([...hrefs(tabs), ...hrefs(more)].sort()).toEqual(hrefs(menuItemsFor(access, demo)).sort());
      }
    }
  });

  it("cra UX1-20 kept: a failed membership read leaves no tab and only Meine Einstellungen under Mehr", () => {
    const { tabs, more } = shellItemsFor(NO_ACCESS);
    expect(tabs).toEqual([]);
    expect(hrefs(more)).toEqual(["/settings"]);
  });

  it("Mehr always holds Meine Einstellungen (the nurse's way to the push opt-in, UX1-2)", () => {
    for (const access of [{ roles: ["nurse"], inTeam: true }, NO_ACCESS, { roles: ["admin"], inTeam: true }]) {
      expect(hrefs(shellItemsFor(access).more)).toContain("/settings");
    }
  });
});

// UX2-31 (1) (uxa UXR-75, ADR-131 deviation 3 decided, po 2026-11-03 06:30): for a role whose home is /operations and
// who is in no team (coordinator, coach, administrator without a team membership) the first tab is "Ausnahmen", then up
// to two of field, team, work she may open, then "Mehr". A team member's tabs are unchanged.
describe("UX2-31 (1): the role's home is its first tab", () => {
  it("operations without a team: Ausnahmen first, then Arbeitstag; the rest under Mehr in menu order", () => {
    const { tabs, more } = shellItemsFor({ roles: ["operations"], inTeam: false });
    expect(hrefs(tabs)).toEqual(["/operations", "/work"]);
    expect(tabs.map(tabLabel)).toEqual(["Ausnahmen", "Arbeitstag"]);
    expect(hrefs(more)).toEqual(["/intake", "/analytics", "/settings"]);
  });

  it("a coach without a team: Ausnahmen first, then Arbeitstag", () => {
    const { tabs, more } = shellItemsFor({ roles: ["coach"], inTeam: false });
    expect(hrefs(tabs)).toEqual(["/operations", "/work"]);
    expect(hrefs(more)).toEqual(["/analytics", "/settings"]);
  });

  it("an administrator without a team: Ausnahmen first, then Arbeitstag; administration under Mehr", () => {
    const { tabs, more } = shellItemsFor({ roles: ["admin"], inTeam: false });
    expect(hrefs(tabs)).toEqual(["/operations", "/work"]);
    expect(hrefs(more)).toEqual(["/intake", "/analytics", "/settings", "/admin"]);
  });

  it("the home tab is the home path the sign-in lands on (homePathForRoles), never a page she may not open", () => {
    for (const roles of [["operations"], ["coach"], ["admin"], ["admin", "nurse"]]) {
      const access = { roles, inTeam: false };
      expect(homePathForRoles(roles)).toBe(HOME_PATH);
      expect(homeTabFor(access)?.href).toBe(HOME_PATH);
      expect(hrefs(shellItemsFor(access).tabs)[0]).toBe(HOME_PATH);
    }
  });

  it("a team member's tabs are unchanged, whatever her role", () => {
    for (const roles of [["nurse"], ["operations"], ["coach"], ["admin"]]) {
      expect(homeTabFor({ roles, inTeam: true }), roles.join()).toBeNull();
      expect(hrefs(shellItemsFor({ roles, inTeam: true }).tabs), roles.join()).toEqual(["/field", "/team", "/work"]);
    }
  });

  it("no home tab when the role may not open /operations or the read failed (no tab added, fail closed)", () => {
    expect(homeTabFor({ roles: ["nurse"], inTeam: false })).toBeNull();
    expect(homeTabFor({ roles: ["guest"], inTeam: false })).toBeNull();
    expect(homeTabFor(NO_ACCESS)).toBeNull();
    expect(hrefs(shellItemsFor({ roles: ["guest"], inTeam: false }).tabs)).toEqual(["/work"]);
    expect(hrefs(shellItemsFor({ roles: ["nurse"], inTeam: false }).tabs)).toEqual(["/work"]);
  });

  it("at most three tabs plus Mehr for every role (four columns at 390 px)", () => {
    for (const roles of [["nurse"], ["operations"], ["coach"], ["admin"], ["admin", "operations", "coach"], ["guest"], []]) {
      for (const inTeam of [false, true]) {
        for (const demo of [false, true]) {
          expect(shellItemsFor({ roles, inTeam }, demo).tabs.length).toBeLessThanOrEqual(3);
        }
      }
    }
  });
});

describe("UX2-1 / UX2-8: the active item (aria-current) follows the route", () => {
  it("a route and its sub-routes mark their item", () => {
    expect(activeNavKey("/field")).toBe("field");
    expect(activeNavKey("/team")).toBe("team");
    expect(activeNavKey("/team/vorschlaege")).toBe("team");
    expect(activeNavKey("/operations/assistenten/rueckblick/abc")).toBe("operations");
    expect(activeNavKey("/settings")).toBe("settings");
  });

  it("a route that only shares a prefix marks nothing (/teams is not /team)", () => {
    expect(activeNavKey("/teams")).toBeNull();
    expect(activeNavKey("/visits")).toBeNull();
    expect(activeNavKey("/fieldwork")).toBeNull();
    expect(activeNavKey("/")).toBeNull();
  });
});
