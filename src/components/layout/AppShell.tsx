"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import { signOut } from "@/features/auth/actions";
import { demoPagesEnabled } from "@/lib/flags";
import { menuItemsFor, type NavItem, type NavKey } from "@/lib/auth/nav";
import { MORE_LABEL, activeNavKey, shellItemsFor, tabLabel } from "@/lib/auth/shell";
import { useNavAccess } from "./nav-access";

// UX2-1 (ADR-131): one shell around every protected route, rendered once by src/app/(protected)/layout.tsx.
// Phone (< 768 px): a tab bar at the bottom, Heute (/field), Team (/team), Arbeitstag (/work) and "Mehr" (every other
// page the role may open, "Meine Einstellungen" among them, then "Abmelden"). Desktop (≥ 768 px): a sidebar with the
// same items. The items come from the UX1-3 route → roles map only (lib/auth/shell.ts); the shell is not an access
// boundary, every page keeps its own server-side check. Only one of the two navigations is displayed at a time, so
// assistive technology meets one "Hauptmenü".

const FOCUS = "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2";

/** Columns of the tab bar: the tabs she may open plus "Mehr" (one to four). */
const TAB_COLUMNS: Record<number, string> = { 1: "grid-cols-1", 2: "grid-cols-2", 3: "grid-cols-3", 4: "grid-cols-4" };

function SignOutButton({ tone }: { tone: "dark" | "light" }) {
  const look =
    tone === "dark"
      ? "border-white/40 text-white focus-visible:outline-white"
      : "border-stone-400 text-emerald-950 focus-visible:outline-emerald-700";
  return (
    <form action={signOut}>
      <button type="submit" className={`min-h-11 w-full rounded-lg border px-4 text-sm font-semibold ${look} ${FOCUS}`}>
        Abmelden
      </button>
    </form>
  );
}

function Sidebar({ items, active }: { items: NavItem[]; active: NavKey | null }) {
  return (
    <aside
      data-testid="shell-sidebar"
      aria-label="NAVORA"
      className="sticky top-0 hidden h-screen flex-col gap-6 overflow-y-auto bg-emerald-950 p-6 text-white md:flex"
    >
      {/* UX2-12 (part): the product name is text, never a heading; each page's own label is its heading. */}
      <p className="text-2xl font-bold tracking-wide">NAVORA</p>
      <nav aria-label="Hauptmenü" data-testid="main-menu">
        <ul className="grid gap-2">
          {items.map((item) => {
            const current = item.key === active;
            return (
              <li key={item.key}>
                <Link
                  href={item.href}
                  aria-current={current ? "page" : undefined}
                  className={`flex min-h-11 items-center rounded-xl px-4 text-base focus-visible:outline-white ${FOCUS} ${
                    current ? "bg-white/15 font-bold" : "bg-white/5 hover:bg-white/10"
                  }`}
                >
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
      <div className="mt-auto">
        <SignOutButton tone="dark" />
      </div>
    </aside>
  );
}

function TabBar({ tabs, more, active }: { tabs: NavItem[]; more: NavItem[]; active: NavKey | null }) {
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const barRef = useRef<HTMLElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const moreActive = more.some((item) => item.key === active);

  // The open "Mehr" list closes on Escape (focus back on "Mehr"), on a tap outside the bar and when an item is chosen
  // (the UX1-26 behaviour of the interim header menu, kept); a new route remounts the bar (AppShell keys it by route).
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      setOpen(false);
      buttonRef.current?.focus();
    };
    const onDown = (e: PointerEvent) => {
      if (e.target instanceof Node && !barRef.current?.contains(e.target)) setOpen(false);
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onDown);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onDown);
    };
  }, [open]);

  const tabClass = (current: boolean) =>
    `flex min-h-14 w-full flex-col items-center justify-center border-t-4 px-1 text-sm focus-visible:outline-emerald-700 ${FOCUS} ${
      current ? "border-emerald-800 font-bold text-emerald-950" : "border-transparent text-stone-700"
    }`;

  return (
    <nav
      ref={barRef}
      aria-label="Hauptmenü"
      data-testid="tab-bar"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-stone-300 bg-white pb-[env(safe-area-inset-bottom)] md:hidden"
    >
      <ul className={`grid ${TAB_COLUMNS[tabs.length + 1]}`}>
        {tabs.map((item) => {
          const current = item.key === active;
          return (
            <li key={item.key}>
              <Link href={item.href} aria-current={current ? "page" : undefined} className={tabClass(current)}>
                {tabLabel(item)}
              </Link>
            </li>
          );
        })}
        <li>
          <button
            ref={buttonRef}
            type="button"
            aria-expanded={open}
            aria-controls={open ? panelId : undefined}
            data-testid="tab-more-button"
            onClick={() => setOpen((o) => !o)}
            className={tabClass(open || moreActive)}
          >
            {MORE_LABEL}
          </button>
        </li>
      </ul>
      {/* After the tabs in the DOM, so Tab from "Mehr" reaches the list's first item; shown above the bar. */}
      {open && (
        <div
          id={panelId}
          data-testid="tab-more"
          className="absolute inset-x-0 bottom-full max-h-[70vh] overflow-y-auto border-t border-stone-300 bg-white p-3 shadow-lg"
          onClick={(e) => {
            if (e.target instanceof Element && e.target.closest("a")) setOpen(false);
          }}
        >
          <ul className="grid gap-2">
            {more.map((item) => {
              const current = item.key === active;
              return (
                <li key={item.key}>
                  <Link
                    href={item.href}
                    aria-current={current ? "page" : undefined}
                    className={`flex min-h-11 items-center rounded-lg px-4 text-base text-emerald-950 focus-visible:outline-emerald-700 ${FOCUS} ${
                      current ? "bg-emerald-50 font-bold" : "bg-stone-50"
                    }`}
                  >
                    {item.label}
                  </Link>
                </li>
              );
            })}
          </ul>
          {/* UX1-20 / UXR-11 (kept): "Abmelden" is the last item of the menu, not the bar's most prominent control. */}
          <div className="mt-3">
            <SignOutButton tone="light" />
          </div>
        </div>
      )}
    </nav>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const access = useNavAccess();
  const pathname = usePathname() ?? "";
  const items = menuItemsFor(access, demoPagesEnabled);
  const { tabs, more } = shellItemsFor(access, demoPagesEnabled);
  const active = activeNavKey(pathname);
  return (
    <div data-testid="app-shell" className="min-h-screen md:grid md:grid-cols-[280px_minmax(0,1fr)]">
      <Sidebar items={items} active={active} />
      {/* Room for the fixed tab bar below 768 px, so it never covers the end of a page. */}
      <div className="min-w-0 pb-[calc(3.5rem+env(safe-area-inset-bottom))] md:pb-0">{children}</div>
      <TabBar key={pathname} tabs={tabs} more={more} active={active} />
    </div>
  );
}
