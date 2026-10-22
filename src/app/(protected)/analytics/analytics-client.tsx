import Link from "next/link";
import Sidebar from "@/components/layout/Sidebar";
import type { KpiRow } from "@/features/analytics/queries";
import { KPI, KPI_ORDER, formatKpi } from "@/features/analytics/rules";

function shiftMonth(month: string, by: number): string {
  const [y, m] = month.split("-").map(Number);
  const d = new Date(Date.UTC(y, m - 1 + by, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function monthLabel(month: string): string {
  return new Intl.DateTimeFormat("de-CH", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(`${month}T00:00:00Z`));
}

/** AN1: one table per scope (organisation, then each team). Every figure shows its definition and source. */
export default function AnalyticsClient({ rows, month }: { rows: KpiRow[]; month: string }) {
  const scopes = new Map<string, { title: string; rows: KpiRow[] }>();
  for (const r of rows) {
    const key = r.team_id ?? `org:${r.organization_id}`;
    const title = r.team_id ? `Team ${r.team_name ?? ""}` : "Ganze Organisation";
    if (!scopes.has(key)) scopes.set(key, { title, rows: [] });
    scopes.get(key)!.rows.push(r);
  }
  const ordered = [...scopes.entries()].sort(([a], [b]) => (a.startsWith("org:") ? -1 : b.startsWith("org:") ? 1 : a.localeCompare(b)));

  return (
    <div style={{ minHeight: "100vh", display: "grid", gridTemplateColumns: "280px 1fr", background: "#f4f7f4", color: "#153328" }}>
      <Sidebar active="analytics" />
      <main className="grid content-start gap-6 p-8">
        <header className="grid gap-2">
          <p className="text-xs uppercase tracking-widest text-stone-500">Pilot-Wirkung</p>
          <h2 className="text-2xl font-bold">Kennzahlen {monthLabel(month)}</h2>
          <p className="text-sm text-stone-600">
            Nur Summen pro Team und Organisation, nie pro Pflegeperson, ohne Klient:innen-Daten. Zahlen aus weniger als 5 Fällen sind als «zu wenig Daten» markiert.
          </p>
          <nav aria-label="Monat wechseln" className="flex gap-3 text-sm font-semibold">
            <Link className="underline" href={`/analytics?monat=${shiftMonth(month, -1)}`}>← Vormonat</Link>
            <Link className="underline" href={`/analytics?monat=${shiftMonth(month, 1)}`}>Folgemonat →</Link>
          </nav>
        </header>
        {ordered.length === 0 && (
          <p data-testid="no-kpis" className="rounded-xl border border-stone-300 bg-white p-4">Für dich gibt es keine Kennzahlen.</p>
        )}
        {ordered.map(([key, scope]) => (
          <section key={key} aria-label={scope.title} className="grid gap-2 rounded-2xl border border-stone-200 bg-white p-5">
            <h3 className="text-lg font-bold">{scope.title}</h3>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs uppercase text-stone-500">
                  <th className="py-1">Kennzahl</th><th>Wert</th><th>Basis</th><th>Zeitraum</th><th>Definition · Quelle</th>
                </tr>
              </thead>
              <tbody>
                {KPI_ORDER.filter((k) => scope.rows.some((r) => r.kpi === k)).map((k) => {
                  const r = scope.rows.find((x) => x.kpi === k)!;
                  const def = KPI[k];
                  return (
                    <tr key={k} data-kpi={k} className="border-t border-stone-100 align-top">
                      <td className="py-2 pr-3 font-semibold">{def.label}</td>
                      <td className="py-2 pr-3 tabular-nums" data-testid={`kpi-${k}`}>
                        {formatKpi(k, r.value)}
                        {r.too_few && <span className="ml-1 rounded bg-amber-100 px-1 text-xs text-amber-900">zu wenig Daten</span>}
                        {def.reference && <span className="block text-xs text-stone-500">{def.reference}</span>}
                      </td>
                      <td className="py-2 pr-3 tabular-nums text-stone-600">{r.base ?? "–"}</td>
                      <td className="py-2 pr-3 text-xs text-stone-600" data-testid={`period-${k}`}>{k === "open_p1_exceptions" ? "Stand jetzt" : monthLabel(month)}</td>
                      <td className="py-2 text-xs text-stone-600">
                        {def.definition} <span className="italic">Quelle: {def.source}.</span>
                        {r.note && <span className="block text-amber-900">{r.note}</span>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </section>
        ))}
      </main>
    </div>
  );
}
