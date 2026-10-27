"use client";

import Link from "next/link";
import type { CSSProperties, ReactNode } from "react";
import { signOut } from "@/features/auth/actions";
import { demoPagesEnabled } from "@/lib/flags";
import { navItemsFor } from "@/lib/auth/nav";
import { useNavAccess } from "./nav-access";

type SidebarProps = {
  /** The page the person is on. /teams and /visits (first MVP) are no longer menu items (UX1-4) but still pass it. */
  active:
    | "operations"
    | "partners"
    | "teams"
    | "visits"
    | "field"
    | "work"
    | "intake"
    | "analytics"
    | "admin"
    | "settings";
};

/** UX1-3 (ADR-103): only the items whose page admits the caller, in menu order. */
function useMenuItems() {
  return navItemsFor(useNavAccess(), demoPagesEnabled);
}

function SignOutButton() {
  return (
    <form action={signOut}>
      <button
        type="submit"
        style={{
          width: "100%",
          background: "transparent",
          color: "white",
          border: "1px solid rgba(255,255,255,0.3)",
          borderRadius: "999px",
          padding: "10px 14px",
          cursor: "pointer",
          font: "inherit",
        }}
      >
        Abmelden
      </button>
    </form>
  );
}

function MenuLinks({ active }: SidebarProps) {
  const items = useMenuItems();
  return (
    <nav aria-label="Hauptmenü" data-testid="main-menu" style={{ display: "grid", gap: "10px", marginTop: "10px" }}>
      {items.map((item) => {
        const isActive = item.key === active;
        return (
          <Link
            key={item.key}
            href={item.href}
            aria-current={isActive ? "page" : undefined}
            style={{
              background: isActive ? "rgba(255,255,255,0.14)" : "rgba(255,255,255,0.06)",
              padding: "14px 16px",
              borderRadius: "16px",
              fontWeight: isActive ? 700 : 400,
              color: "white",
              textDecoration: "none",
              display: "block",
            }}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}

export default function Sidebar({ active }: SidebarProps) {
  return (
    <aside
      style={{
        background: "#16392d",
        color: "white",
        padding: "24px",
        display: "flex",
        flexDirection: "column",
        gap: "18px",
        minHeight: "100vh",
      }}
    >
      <div>
        <p
          style={{
            fontSize: "12px",
            textTransform: "uppercase",
            letterSpacing: "0.08em",
            color: "rgba(255,255,255,0.7)",
            marginBottom: "8px",
          }}
        >
          Swiss Care OS
        </p>
        <h1 style={{ margin: 0, fontSize: "28px" }}>Navora</h1>
      </div>

      <MenuLinks active={active} />

      <div
        style={{
          marginTop: "auto",
          background: "rgba(255,255,255,0.08)",
          borderRadius: "18px",
          padding: "16px",
        }}
      >
        <p
          style={{
            margin: 0,
            color: "rgba(255,255,255,0.72)",
            fontSize: "12px",
          }}
        >
          Pilot Schweiz
        </p>
        <h3 style={{ margin: "8px 0 0", fontSize: "20px" }}>
          Navora MVP
        </h3>
      </div>

      <SignOutButton />
    </aside>
  );
}

/**
 * UX1-1 (ADR-103): below 768 px the side column collapses into a bar at the top of the page: the menu (closed by
 * default) and "Abmelden", so the content keeps the full width. From 768 px the side column is shown as before.
 */
export function MobileMenu({ active }: SidebarProps) {
  return (
    <div
      data-testid="mobile-menu-bar"
      className="grid gap-2 md:hidden"
      style={{ background: "#16392d", color: "white", padding: "8px 16px" }}
    >
      <div className="flex items-center justify-between gap-3">
        <span className="font-bold">Navora</span>
        <SignOutButton />
      </div>
      <details data-testid="mobile-menu">
        <summary className="flex min-h-11 cursor-pointer items-center font-bold">Menü</summary>
        <div style={{ paddingBottom: "8px" }}>
          <MenuLinks active={active} />
        </div>
      </details>
    </div>
  );
}

/**
 * UX1-1: the page frame of the pages with the side column. One column below 768 px (menu on top), `280px 1fr` from
 * 768 px (the /intake pattern). `min-w-0` lets the content column shrink instead of widening the page.
 */
export function AppFrame({ active, className, style, children }: SidebarProps & {
  className?: string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  return (
    <div className={`grid min-h-screen md:grid-cols-[280px_1fr] ${className ?? ""}`} style={style}>
      <div className="hidden md:block">
        <Sidebar active={active} />
      </div>
      <div className="min-w-0">
        <MobileMenu active={active} />
        {children}
      </div>
    </div>
  );
}
