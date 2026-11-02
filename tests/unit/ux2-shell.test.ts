import { describe, expect, it } from "vitest";
import { NAV_ITEMS, NO_ACCESS, PAGE_LABEL, menuItemsFor, type NavAccess } from "@/lib/auth/nav";
import { MORE_LABEL, TAB_KEYS, TAB_LABEL, activeNavKey, shellItemsFor } from "@/lib/auth/shell";

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

  it("operations without a team: only Arbeitstag as a tab; her pages under Mehr in menu order", () => {
    const { tabs, more } = shellItemsFor({ roles: ["operations"], inTeam: false });
    expect(hrefs(tabs)).toEqual(["/work"]);
    expect(hrefs(more)).toEqual(["/operations", "/intake", "/analytics", "/settings"]);
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
