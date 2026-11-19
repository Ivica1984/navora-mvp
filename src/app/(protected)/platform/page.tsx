import { connection } from "next/server";
import { getPlatformPage } from "@/features/platform/queries";
import { platformTotals } from "@/features/platform/rules";
import { PAGE_LABEL } from "@/lib/auth/nav";

// PLATFORM1 (ADR-213): the NAVORA operator cockpit. Counts only (Blueprint V3.2 §2.4 «NAVORA-Betrieb»): no person, no
// address, no care content, no money (FE-078). Synthetic data only (Phase A).
export default async function PlatformPage() {
  await connection();
  const data = await getPlatformPage();
  if (!data.operator) {
    return (
      <main className="mx-auto grid max-w-2xl gap-4 p-4">
        <h1 className="text-2xl font-bold">{PAGE_LABEL.platform}</h1>
        <p data-testid="platform-no-access">Diese Seite ist nur für den NAVORA-Betrieb.</p>
      </main>
    );
  }
  const t = platformTotals(data.rows);
  const tiles = [
    { key: "organizations", label: "Organisationen", value: t.organizations },
    { key: "teams", label: "Teams", value: t.teams },
    { key: "members", label: "Mitglieder", value: t.members },
    { key: "client_accounts", label: "Auftraggeber (Heime)", value: t.client_accounts },
    { key: "orders_upcoming", label: "Kommende Aufträge", value: t.orders_upcoming },
    { key: "orders_not_covered", label: "Nicht gedeckt", value: t.orders_not_covered },
  ];
  return (
    <main className="mx-auto grid w-full max-w-5xl min-w-0 gap-6 p-4">
      <header className="grid gap-1">
        <h1 className="text-2xl font-bold">{PAGE_LABEL.platform}</h1>
        <p className="text-sm text-secondary">Nur Zählwerte · keine Pflegeinhalte, keine Adressen, keine Beträge · synthetische Daten</p>
      </header>
      <section aria-label="Übersicht" className="grid grid-cols-2 gap-3 md:grid-cols-3">
        {tiles.map((tile) => (
          <div key={tile.key} data-testid={`platform-total-${tile.key}`}
            className="rounded-lg border border-stone-200 bg-white p-3">
            <p className="text-sm text-secondary">{tile.label}</p>
            <p className="text-2xl font-bold">{tile.value}</p>
          </div>
        ))}
      </section>
      <section aria-label="Organisationen" className="grid min-w-0 gap-2">
        <h2 className="text-lg font-bold">Organisationen ({data.rows.length})</h2>
        <div className="overflow-x-auto">
          <table data-testid="platform-orgs" className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-stone-300">
                <th scope="col" className="p-2">Organisation</th>
                <th scope="col" className="p-2 text-right">Teams</th>
                <th scope="col" className="p-2 text-right">Mitglieder</th>
                <th scope="col" className="p-2 text-right">Heime</th>
                <th scope="col" className="p-2 text-right">Kommend</th>
                <th scope="col" className="p-2 text-right">Gedeckt</th>
                <th scope="col" className="p-2 text-right">Wartet</th>
                <th scope="col" className="p-2 text-right">Nicht gedeckt</th>
              </tr>
            </thead>
            <tbody>
              {data.rows.map((r) => (
                <tr key={r.organization_id} className="border-b border-stone-200">
                  <th scope="row" className="p-2 font-semibold">
                    {r.organization_name}
                    {r.simulation && <span className="text-secondary block text-xs font-normal">Simulation</span>}
                  </th>
                  <td className="p-2 text-right">{r.teams}</td>
                  <td className="p-2 text-right">{r.members}</td>
                  <td className="p-2 text-right">{r.client_accounts}</td>
                  <td className="p-2 text-right">{r.orders_upcoming}</td>
                  <td className="p-2 text-right">{r.orders_covered}</td>
                  <td className="p-2 text-right">{r.orders_waiting}</td>
                  <td className={`p-2 text-right ${r.orders_not_covered > 0 ? "font-bold text-red-800" : ""}`}>
                    {r.orders_not_covered}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <p className="text-sm text-secondary">
        Noch nicht gebaut: Abo-Gebühren der Teams (FEE1), B2B-Lizenzen, Teamgesundheit. NAVORA nimmt keine Kommission
        und kein Geld aus Pflegeerlösen (FE-078).
      </p>
    </main>
  );
}
