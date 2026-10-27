// UX1-3 (ADR-103): which menu item a signed-in person sees. Pure TypeScript, no Next or Supabase imports, unit-tested.
//
// The menu is not an access boundary. The page's own server-side check (the database function or RLS policy that
// returns its data) stays the boundary and is unchanged; this table only mirrors it so that nobody meets an item that
// refuses her. tests/unit/nav-access.test.ts reads each predicate's role list from the newest migration that defines
// it and fails when this table drifts from the database.

/** What the menu needs to know about the caller: her organisation roles and whether she belongs to a team. */
export type NavAccess = {
  /** `organization_memberships.role` of every own membership (RLS: own rows only). */
  roles: ReadonlyArray<string>;
  /** At least one own `team_memberships` row (the team-scoped pages read nothing for anybody else). */
  inTeam: boolean;
};

/** The database predicates the page checks use (supabase/migrations, `private.*`). */
export type PageCheck =
  | { kind: "role"; predicate: "is_org_admin" | "is_intake_role" | "is_coordinator"; roles: ReadonlyArray<string> }
  | { kind: "team_member" }
  | { kind: "team_member_or_role"; predicate: "is_coordinator"; roles: ReadonlyArray<string> }
  | { kind: "member" };

/** private.is_org_admin (0035). */
export const ADMIN_ROLES: ReadonlyArray<string> = ["admin"];
/** private.is_intake_role (0013); the same list as INTAKE_ROLES in features/intake/rules.ts. */
export const INTAKE_PAGE_ROLES: ReadonlyArray<string> = ["admin", "operations"];
/** private.is_coordinator (0015). */
export const COORDINATOR_ROLES: ReadonlyArray<string> = ["admin", "coach", "operations"];

export type NavKey =
  | "operations"
  | "intake"
  | "partners"
  | "field"
  | "work"
  | "analytics"
  | "settings"
  | "admin";

export type NavItem = {
  key: NavKey;
  label: string;
  href: string;
  /** The page's server-side check, as the database applies it. */
  check: PageCheck;
  /** Where the check lives (for reviewers; not shown). */
  source: string;
  /** Static demo page, shown only with the demo flag (ADR-006). */
  demo?: true;
};

// Labels are unchanged here; plain-word labels are UX1 part (d) (UX1-11 to UX1-13, `cra` string gate).
// UX1-4: "Qualitätsmanagement" had no target and is removed (open quality holds are on /operations, serious events in
// the OPS1 exceptions there); the first-MVP pages /teams and /visits are no longer in the menu (routes stay until UX2).
export const NAV_ITEMS: ReadonlyArray<NavItem> = [
  {
    key: "operations",
    label: "Operations Board",
    href: "/operations",
    check: { kind: "role", predicate: "is_coordinator", roles: COORDINATOR_ROLES },
    source: "public.operations_exceptions: private.is_coordinator",
  },
  {
    key: "intake",
    label: "Aufnahme",
    href: "/intake",
    check: { kind: "role", predicate: "is_intake_role", roles: INTAKE_PAGE_ROLES },
    source: "getIntakeData: intakeOrganization (INTAKE_ROLES); partner_requests policies: private.is_intake_role",
  },
  {
    key: "partners",
    label: "Partneranfragen",
    href: "/partners",
    check: { kind: "role", predicate: "is_intake_role", roles: INTAKE_PAGE_ROLES },
    source: "static demo page (ADR-006), shown to the intake roles only",
    demo: true,
  },
  {
    key: "field",
    label: "Mein Tag (mobil)",
    href: "/field",
    check: { kind: "team_member" },
    source: "public.field_visits: own team_memberships",
  },
  {
    // WORK1: the person's own working day (only she reads it); the database admits every member to her own day.
    key: "work",
    label: "Mein Arbeitstag",
    href: "/work",
    check: { kind: "member" },
    source: "public.my_working_time_notice / public.my_working_day: own rows",
  },
  {
    key: "analytics",
    label: "KPI / Analytics",
    href: "/analytics",
    check: { kind: "team_member_or_role", predicate: "is_coordinator", roles: COORDINATOR_ROLES },
    source: "public.pilot_kpis: private.is_coordinator or private.is_team_member",
  },
  {
    // SIG2-1: the member's own settings (delivery outside the app).
    key: "settings",
    label: "Meine Einstellungen",
    href: "/settings",
    check: { kind: "member" },
    source: "public.my_push_state: own rows",
  },
  {
    key: "admin",
    label: "Administration",
    href: "/admin",
    check: { kind: "role", predicate: "is_org_admin", roles: ADMIN_ROLES },
    source: "getAdminData: own admin membership; public.admin_members: private.is_org_admin",
  },
];

const hasAny = (roles: ReadonlyArray<string>, allowed: ReadonlyArray<string>) => roles.some((r) => allowed.includes(r));

/** Whether the page's own check admits the caller (the menu mirror of it; the page itself decides). */
export function admits(check: PageCheck, access: NavAccess): boolean {
  switch (check.kind) {
    case "role":
      return hasAny(access.roles, check.roles);
    case "team_member":
      return access.inTeam;
    case "team_member_or_role":
      return access.inTeam || hasAny(access.roles, check.roles);
    case "member":
      return access.roles.length > 0;
  }
}

/** The items this person may open, in menu order. A demo item only with the demo flag. */
export function navItemsFor(access: NavAccess, demoPages = false): NavItem[] {
  return NAV_ITEMS.filter((item) => (demoPages || !item.demo) && admits(item.check, access));
}

/** Nobody signed in, or memberships could not be read: no item (fail closed). */
export const NO_ACCESS: NavAccess = { roles: [], inTeam: false };

/**
 * `cra` 2026-10-27 17:35 (UX1-20, UXR-10; ADR-104 addendum): "Meine Einstellungen" is the nurse's only route to the
 * SIG2 push opt-in for P1 signals outside the app, so it must not disappear when the membership read fails and the
 * menu fails closed. /settings reads only the caller's own rows (`public.my_push_state`) and admits any signed-in
 * person, so showing the link without the read widens no access. Every other item stays fail-closed.
 */
export const SETTINGS_ITEM: NavItem = (() => {
  const item = NAV_ITEMS.find((candidate) => candidate.key === "settings");
  if (!item) throw new Error("nav: the settings item is missing from NAV_ITEMS");
  return item;
})();

/** The menu as shown: `navItemsFor`, plus "Meine Einstellungen" when the role table left it out (e.g. a failed read). */
export function menuItemsFor(access: NavAccess, demoPages = false): NavItem[] {
  const items = navItemsFor(access, demoPages);
  return items.some((item) => item.key === "settings") ? items : [...items, SETTINGS_ITEM];
}
