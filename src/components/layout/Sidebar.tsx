import Link from "next/link";
import { signOut } from "@/features/auth/actions";
import { demoPagesEnabled } from "@/lib/flags";

type SidebarProps = {
  active:
    | "operations"
    | "partners"
    | "teams"
    | "matching"
    | "visits"
    | "field"
    | "quality"
    | "analytics";
};

const allNavItems = [
  {
    key: "operations",
    label: "Operations Board",
    href: "/operations",
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
    key: "matching",
    label: "Matching-Übersicht",
    href: "/matching",
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
] as const;

const DEMO_PAGE_KEYS: ReadonlyArray<string> = ["partners", "matching"];

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

        <div
          style={{
            background:
              active === "analytics"
                ? "rgba(255,255,255,0.14)"
                : "rgba(255,255,255,0.06)",
            padding: "14px 16px",
            borderRadius: "16px",
            fontWeight: active === "analytics" ? 700 : 400,
          }}
        >
          KPI / Analytics
        </div>
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
