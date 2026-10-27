import Link from "next/link";
import { signOut } from "@/features/auth/actions";
import { demoPagesEnabled } from "@/lib/flags";

type SidebarProps = {
  active:
    | "operations"
    | "partners"
    | "teams"
    | "visits"
    | "field"
    | "work"
    | "intake"
    | "quality"
    | "analytics"
    | "admin"
    | "settings";
};

const allNavItems = [
  {
    key: "operations",
    label: "Operations Board",
    href: "/operations",
  },
  {
    key: "intake",
    label: "Aufnahme",
    href: "/intake",
  },
  {
    key: "partners",
    label: "Partneranfragen",
    href: "/partners",
  },
  {
    key: "teams",
    label: "Teams Übersicht",
    href: "/teams",
  },
  {
    key: "visits",
    label: "Einsätze",
    href: "/visits",
  },
  {
    key: "field",
    label: "Mein Tag (mobil)",
    href: "/field",
  },
  {
    // WORK1: the person's own working day (only she reads it).
    key: "work",
    label: "Mein Arbeitstag",
    href: "/work",
  },
  {
    // SIG2-1: the member's own settings (delivery outside the app).
    key: "settings",
    label: "Meine Einstellungen",
    href: "/settings",
  },
  {
    // ADM1: shown to everybody; the page and the database admit administrators only.
    key: "admin",
    label: "Administration",
    href: "/admin",
  },
] as const;

// IPA1-4: the /matching demo and its team-request scorer were removed (ADR-099).
const DEMO_PAGE_KEYS: ReadonlyArray<string> = ["partners"];

const navItems = allNavItems.filter(
  (item) => demoPagesEnabled || !DEMO_PAGE_KEYS.includes(item.key)
);

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

      <nav style={{ display: "grid", gap: "10px", marginTop: "10px" }}>
        {navItems.map((item) => {
          const isActive = item.key === active;

          return (
            <Link
              key={item.key}
              href={item.href}
              style={{
                background: isActive
                  ? "rgba(255,255,255,0.14)"
                  : "rgba(255,255,255,0.06)",
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

        <div
          style={{
            background:
              active === "quality"
                ? "rgba(255,255,255,0.14)"
                : "rgba(255,255,255,0.06)",
            padding: "14px 16px",
            borderRadius: "16px",
            fontWeight: active === "quality" ? 700 : 400,
          }}
        >
          Qualitätsmanagement
        </div>

        <Link
          href="/analytics"
          style={{
            background:
              active === "analytics"
                ? "rgba(255,255,255,0.14)"
                : "rgba(255,255,255,0.06)",
            padding: "14px 16px",
            borderRadius: "16px",
            fontWeight: active === "analytics" ? 700 : 400,
            color: "white",
            textDecoration: "none",
            display: "block",
          }}
        >
          KPI / Analytics
        </Link>
      </nav>

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
    </aside>
  );
}
