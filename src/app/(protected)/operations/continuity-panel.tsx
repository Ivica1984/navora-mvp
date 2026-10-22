import { formatContinuity } from "@/features/team/rules";
import type { ContinuityRow } from "@/features/team/queries";

/** J6: continuity per client this month (read only). Per client, never per nurse — no ranking. */
export default function ContinuityPanel({ rows }: { rows: ContinuityRow[] }) {
  return (
    <section aria-label="Kontinuität" className="grid gap-2 rounded-xl border border-stone-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold">Kontinuität diesen Monat</h2>
      <p className="text-sm text-stone-500">Pro Klient:in: verschiedene Pflegende und Anteil der Bezugspflege. Keine Bewertung einzelner Personen.</p>
      {rows.length === 0 ? (
        <p className="text-sm text-stone-500">Keine laufenden Fälle.</p>
      ) : (
        <ul className="grid gap-1 text-sm">
          {rows.map((r) => (
            <li key={r.case_id} data-testid="continuity-row">
              <span className="font-semibold">{r.client_label ?? "Klient:in"}</span> · {r.team_name}
              {!r.primary_set && <span className="ml-1 font-semibold text-amber-800">· Bezugspflege fehlt</span>}
              <span className="block text-xs text-stone-600">{formatContinuity(r)}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
