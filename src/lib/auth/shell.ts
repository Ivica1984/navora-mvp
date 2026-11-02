// UX2-1 (ADR-131): the items of the one app shell. Pure TypeScript, no Next or Supabase imports, unit-tested
// (tests/unit/ux2-shell.test.ts).
//
// The shell reads the UX1-3 route → roles map (`menuItemsFor` in ./nav) and nothing else, so the phone tab bar, its
// "Mehr" list and the desktop sidebar can never show different items. Like the menu, the shell is not an access
// boundary: every page keeps its own server-side check.

import { NAV_ITEMS, menuItemsFor, type NavAccess, type NavItem, type NavKey } from "./nav";

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

export type ShellItems = {
  /** Tab bar items she may open, in TAB_KEYS order (zero to three). */
  tabs: NavItem[];
  /** Every other menu item she may open, in menu order. Never empty: "Meine Einstellungen" always stays (cra UX1-20). */
  more: NavItem[];
};

/** Splits the menu (UX1-3, with the cra UX1-20 settings rule) into tabs and "Mehr". Nothing added, nothing dropped. */
export function shellItemsFor(access: NavAccess, demoPages = false): ShellItems {
  const items = menuItemsFor(access, demoPages);
  const tabs = TAB_KEYS.flatMap((key) => items.filter((item) => item.key === key));
  const more = items.filter((item) => !isTab(item.key));
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
