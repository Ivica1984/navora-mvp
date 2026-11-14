// UX2-1 (ADR-131): the items of the one app shell. Pure TypeScript, no Next or Supabase imports, unit-tested
// (tests/unit/ux2-shell.test.ts).
//
// The shell reads the UX1-3 route → roles map (`menuItemsFor` in ./nav) and nothing else, so the phone tab bar, its
// "Mehr" list and the desktop sidebar can never show different items. Like the menu, the shell is not an access
// boundary: every page keeps its own server-side check.

import { NAV_ITEMS, menuItemsFor, type NavAccess, type NavItem, type NavKey } from "./nav";
import { HOME_PATH, homePathForRoles } from "./paths";

/** The tabs of the phone tab bar, in the brief's order (UX2-1). Any other item the role may open is under "Mehr". */
export const TAB_KEYS = ["field", "team", "work"] as const satisfies ReadonlyArray<NavKey>;

type TabKey = (typeof TAB_KEYS)[number];

/**
 * The tab labels as UX2-1 names them. The sidebar and the pages keep PAGE_LABEL (UX1-13); the short tab words exist
 * because four tabs share 390 px. ADR-131 deviation 1 asks `uxa` whether the two should become one.
 */
export const TAB_LABEL = { field: "Heute", team: "Team", work: "Arbeitstag" } as const satisfies Record<TabKey, string>;

/** The fourth tab: the rest of the menu, "Meine Einstellungen" and "Abmelden" among it. */
export const MORE_LABEL = "Mehr";

const isTab = (key: NavKey): key is TabKey => (TAB_KEYS as ReadonlyArray<NavKey>).includes(key);

/** UX2-31 (1): how many of TAB_KEYS follow the home tab, so that home, two tabs and "Mehr" share 390 px. */
const TABS_AFTER_HOME = 2;

/**
 * UX2-31 (1) (`uxa` UXR-75; ADR-131 deviation 3, decided by po 2026-11-03 06:30): the tab of the role's home page when
 * it is not one of TAB_KEYS. A person in no team whose sign-in lands on /operations (`homePathForRoles`: coordinator,
 * coach, administrator without a team membership) gets "Ausnahmen" as her first tab. Only an item her menu already
 * holds can become the home tab (nothing added); a team member keeps Heute, Team, Arbeitstag. Null otherwise.
 */
export function homeTabFor(access: NavAccess, demoPages = false): NavItem | null {
  if (access.inTeam || homePathForRoles(access.roles) !== HOME_PATH) return null;
  return menuItemsFor(access, demoPages).find((item) => item.href === HOME_PATH) ?? null;
}

/**
 * UXR-204 (`uxa` 2026-11-14 03:47; BK amendment 2026-11-14 04:39 (2); ADR-194 addendum 05:20): the client's order page
 * as her one tab. Only when nothing else would be a tab (no home tab, none of TAB_KEYS) and only an item her menu
 * already holds (`client_account` check, fail closed): a client-account member without a role or team never sees a
 * tab bar of "Mehr" alone. Every staff case keeps its tabs; /order stays under "Mehr" there.
 */
function clientTabFrom(items: ReadonlyArray<NavItem>): NavItem | null {
  return items.find((item) => item.key === "order") ?? null;
}

export type ShellItems = {
  /** Tab bar items she may open: the home tab (UX2-31) if any, then TAB_KEYS order, or the client's /order tab alone
   * (UXR-204) when neither applies (zero to three in all). */
  tabs: NavItem[];
  /** Every other menu item she may open, in menu order. Never empty: "Meine Einstellungen" always stays (cra UX1-20). */
  more: NavItem[];
};

/**
 * Splits the menu (UX1-3, with the cra UX1-20 settings rule) into tabs and "Mehr". Nothing added, nothing dropped: an
 * item is either a tab or under "Mehr".
 */
export function shellItemsFor(access: NavAccess, demoPages = false): ShellItems {
  const items = menuItemsFor(access, demoPages);
  const home = homeTabFor(access, demoPages);
  const fixed = TAB_KEYS.flatMap((key) => items.filter((item) => item.key === key));
  const client = home || fixed.length > 0 ? null : clientTabFrom(items);
  const tabs = home ? [home, ...fixed.slice(0, TABS_AFTER_HOME)] : client ? [client] : fixed;
  const inTabs = new Set(tabs.map((item) => item.key));
  const more = items.filter((item) => !inTabs.has(item.key));
  return { tabs, more };
}

/** The tab label of a tab item, the page label otherwise. */
export function tabLabel(item: NavItem): string {
  return isTab(item.key) ? TAB_LABEL[item.key] : item.label;
}

/**
 * The item a route belongs to (for `aria-current`): the route itself or one of its sub-routes. A route that only
 * shares a prefix belongs to nothing (`/teams`, the first-MVP page, is not `/team`).
 */
export function activeNavKey(pathname: string, items: ReadonlyArray<NavItem> = NAV_ITEMS): NavKey | null {
  const hit = items.find((item) => pathname === item.href || pathname.startsWith(`${item.href}/`));
  return hit ? hit.key : null;
}
