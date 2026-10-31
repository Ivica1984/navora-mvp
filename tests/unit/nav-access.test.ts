import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  ADMIN_ROLES,
  COORDINATOR_ROLES,
  INTAKE_PAGE_ROLES,
  NAV_ITEMS,
  admits,
  navItemsFor,
  menuItemsFor,
  NO_ACCESS,
  type NavAccess,
} from "@/lib/auth/nav";
import { INTAKE_ROLES } from "@/features/intake/rules";

// UX1-3 (ADR-103): the menu mirrors each page's server-side check. These tests read the checks from the migrations
// (the newest definition wins, as when the migrations are applied in order), so the menu cannot drift from them.
const MIGRATIONS = join(process.cwd(), "supabase", "migrations");
const migrationFiles = readdirSync(MIGRATIONS).filter((f) => f.endsWith(".sql")).sort();

/** Body of the newest `create [or replace] function <name>(` in the migrations, up to its closing `$$;`. */
function newestDefinition(name: string): string {
  const head = new RegExp(`create\\s+(or\\s+replace\\s+)?function\\s+${name.replace(".", "\\.")}\\s*\\(`, "i");
  let found: string | null = null;
  for (const file of migrationFiles) {
    const sql = readFileSync(join(MIGRATIONS, file), "utf8");
    let rest = sql;
    let m: RegExpExecArray | null;
    while ((m = head.exec(rest)) !== null) {
      const from = rest.slice(m.index);
      const end = from.indexOf("$$;", from.indexOf("$$") + 2);
      found = end > 0 ? from.slice(0, end + 3) : from;
      rest = from.slice(m[0].length);
    }
  }
  if (!found) throw new Error(`${name} is not defined in supabase/migrations`);
  return found;
}

/** The role list a `private.has_org_role(org, array[...])` predicate passes. */
function predicateRoles(name: string): string[] {
  const body = newestDefinition(`private.${name}`);
  const m = /has_org_role\s*\([^,]+,\s*array\s*\[([^\]]*)\]/i.exec(body);
  if (!m) throw new Error(`private.${name} does not call has_org_role with a role array`);
  return [...m[1].matchAll(/'([a-z_]+)'/g)].map((x) => x[1]).sort();
}

const sorted = (xs: ReadonlyArray<string>) => [...xs].sort();

describe("menu role lists = the database predicates (UX1-3, no drift)", () => {
  it("is_org_admin, is_intake_role and is_coordinator list the same roles as the menu", () => {
    expect(sorted(ADMIN_ROLES)).toEqual(predicateRoles("is_org_admin"));
    expect(sorted(INTAKE_PAGE_ROLES)).toEqual(predicateRoles("is_intake_role"));
    expect(sorted(COORDINATOR_ROLES)).toEqual(predicateRoles("is_coordinator"));
    // /intake decides in the app with INTAKE_ROLES before any read (getIntakeData).
    expect(sorted(INTAKE_PAGE_ROLES)).toEqual(sorted(INTAKE_ROLES));
  });

  it("every role item names the predicate whose role list it carries", () => {
    const lists: Record<string, ReadonlyArray<string>> = {
      is_org_admin: ADMIN_ROLES,
      is_intake_role: INTAKE_PAGE_ROLES,
      is_coordinator: COORDINATOR_ROLES,
    };
    for (const item of NAV_ITEMS) {
      if (item.check.kind === "role" || item.check.kind === "team_member_or_role") {
        expect(item.check.roles, item.href).toEqual(lists[item.check.predicate]);
      }
    }
  });

  it("the functions behind each page still use the predicate the menu assumes", () => {
    // /operations: OPS1 exceptions for the coordination roles.
    expect(newestDefinition("public.operations_exceptions")).toMatch(/private\.is_coordinator\(/);
    // /admin: the member list for administrators.
    expect(newestDefinition("public.admin_members")).toMatch(/private\.is_org_admin\(/);
    // /analytics: coordination roles or members of the team.
    const kpis = newestDefinition("public.pilot_kpis");
    expect(kpis).toMatch(/private\.is_coordinator\(/);
    expect(kpis).toMatch(/private\.is_team_member\(/);
    // /field: visits of the caller's own teams.
    expect(newestDefinition("public.field_visits")).toMatch(/team_memberships/);
  });

  it("covers exactly the menu routes (no item without a target, no first-MVP page)", () => {
    expect(NAV_ITEMS.map((i) => i.href).sort()).toEqual(
      ["/admin", "/analytics", "/field", "/intake", "/operations", "/partners", "/settings", "/work"].sort(),
    );
    // UX1-4: /teams and /visits (first MVP) are not menu items; "Qualitätsmanagement" (no target) is gone.
    expect(NAV_ITEMS.some((i) => i.href === "/teams" || i.href === "/visits")).toBe(false);
    expect(NAV_ITEMS.some((i) => i.label === "Qualitätsmanagement")).toBe(false);
    for (const item of NAV_ITEMS) expect(item.href).toMatch(/^\/[a-z]+$/);
  });
});

describe("items per role (seed people, UX1-3)", () => {
  const hrefs = (access: NavAccess, demo = false) => navItemsFor(access, demo).map((i) => i.href);

  it("a nurse in a team: her day, her working day, figures and settings; no coordination page", () => {
    expect(hrefs({ roles: ["nurse"], inTeam: true })).toEqual(["/field", "/work", "/analytics", "/settings"]);
  });

  it("a coach without a team: operations, figures, working day, settings", () => {
    expect(hrefs({ roles: ["coach"], inTeam: false })).toEqual(["/operations", "/work", "/analytics", "/settings"]);
  });

  it("operations: operations, intake, figures, working day, settings; no administration", () => {
    expect(hrefs({ roles: ["operations"], inTeam: false })).toEqual([
      "/operations", "/intake", "/work", "/analytics", "/settings",
    ]);
  });

  it("an administrator: everything but the team-only day view", () => {
    expect(hrefs({ roles: ["admin"], inTeam: false })).toEqual([
      "/operations", "/intake", "/work", "/analytics", "/settings", "/admin",
    ]);
  });

  it("a nurse without a team sees no /field and no figures", () => {
    expect(hrefs({ roles: ["nurse"], inTeam: false })).toEqual(["/work", "/settings"]);
  });

  it("the demo page only with the demo flag, and only for the intake roles", () => {
    expect(hrefs({ roles: ["operations"], inTeam: false }, true)).toContain("/partners");
    expect(hrefs({ roles: ["nurse"], inTeam: true }, true)).not.toContain("/partners");
    expect(hrefs({ roles: ["admin"], inTeam: false }, false)).not.toContain("/partners");
  });

  it("fails closed: no memberships (or an unreadable membership) → no item", () => {
    expect(hrefs(NO_ACCESS)).toEqual([]);
    expect(admits({ kind: "member" }, NO_ACCESS)).toBe(false);
  });

  it("an unknown role admits nothing beyond membership", () => {
    expect(hrefs({ roles: ["guest"], inTeam: false })).toEqual(["/work", "/settings"]);
  });

  it("cra 2026-10-27 (UX1-20): a failed membership read keeps only \"Meine Einstellungen\" in the menu", () => {
    expect(menuItemsFor(NO_ACCESS).map((i) => i.href)).toEqual(["/settings"]);
    expect(menuItemsFor(NO_ACCESS, true).map((i) => i.href)).toEqual(["/settings"]);
  });

  it("menuItemsFor equals navItemsFor whenever the role table already admits settings (no duplicate)", () => {
    for (const access of [
      { roles: ["nurse"], inTeam: true },
      { roles: ["coach"], inTeam: false },
      { roles: ["operations"], inTeam: false },
      { roles: ["admin"], inTeam: true },
      { roles: ["guest"], inTeam: false },
    ] satisfies NavAccess[]) {
      expect(menuItemsFor(access)).toEqual(navItemsFor(access));
    }
  });
});
