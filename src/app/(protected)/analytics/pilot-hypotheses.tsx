import type { HypothesisRow } from "@/features/analytics/queries";
import {
  DETAIL_MEASURES,
  HYPOTHESIS_GROUPS,
  MEASURE,
  PERIOD_NOTE,
  formatMeasure,
  measureLabel,
  orderGroupRows,
} from "@/features/analytics/hypotheses";

/**
 * AN2: "Pilot-Hypothesen". One block per scope (organisation, then each team), one card per hypothesis, one line per
 * measure with value, base and period. Never per nurse; suppressed rows say why. Cards stack, so 390 px fits.
 */
export default function PilotHypotheses({ rows, periodLabel }: { rows: HypothesisRow[]; periodLabel: string }) {
  const scopes = new Map<string, { title: string; rows: HypothesisRow[] }>();
  for (const r of rows) {
    const key = r.team_id ?? `org:${r.organization_id}`;
    const title = r.team_id ? `Team ${r.team_name ?? ""}` : "Ganze Organisation";
    if (!scopes.has(key)) scopes.set(key, { title, rows: [] });
    scopes.get(key)!.rows.push(r);
  }
  const ordered = [...scopes.entries()].sort(([a], [b]) => (a.startsWith("org:") ? -1 : b.startsWith("org:") ? 1 : a.localeCompare(b)));

  return (
    <section aria-label="Pilot-Hypothesen" data-testid="pilot-hypotheses" className="grid min-w-0 gap-3">
      <header className="grid gap-1">
        <h2 className="text-xl font-bold">Pilot-Hypothesen</h2>
        <p className="text-sm text-stone-600">
          Aus Ereignissen berechnet, ohne Strichlisten. Nur Team und Organisation, nie pro Pflegeperson. {PERIOD_NOTE} Weniger als 5 Fälle: «zu wenig Daten».
        </p>
      </header>
      {ordered.length === 0 && (
        <p data-testid="no-hypotheses" className="rounded-xl border border-stone-300 bg-white p-4">Für dich gibt es keine Pilot-Hypothesen.</p>
      )}
      {ordered.map(([key, scope]) => (
        // role="group", not a region: the AN1 regions keep their names ("Ganze Organisation", "Team …") unique.
        <div key={key} role="group" aria-label={`Hypothesen: ${scope.title}`} data-scope={key.startsWith("org:") ? "org" : "team"}
             className="grid min-w-0 gap-3 rounded-2xl border border-stone-200 bg-white p-4">
          <h3 className="text-lg font-bold">{scope.title}</h3>
          {HYPOTHESIS_GROUPS.map((g) => {
            const groupRows = orderGroupRows(g, scope.rows);
            if (groupRows.length === 0) return null;
            return (
              <article key={g.no} data-hypothesis={g.no} className="grid min-w-0 gap-2 border-t border-stone-100 pt-3">
                <p className="font-semibold break-words">H{g.no} · {g.hypothesis}</p>
                <p className="text-xs text-secondary break-words">Prüft: «{g.challenge}» (Challenge-Tabelle) · Quelle: {g.source}</p>
                <ul className="grid gap-2">
                  {groupRows.map((r, i) => (
                    <li
                      key={`${r.measure}:${r.detail ?? ""}`}
                      data-measure={r.measure}
                      data-detail={r.detail ?? undefined}
                      className="grid min-w-0 gap-0.5 rounded-lg bg-stone-50 px-3 py-2 text-sm"
                    >
                      <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                        <span className="font-medium break-words">{measureLabel(r.measure, r.detail)}</span>
                        <span className="tabular-nums font-semibold" data-testid="hyp-value">
                          {r.suppressed ? "zu wenig Personen" : formatMeasure(r.measure, r.value)}
                          {!r.suppressed && r.too_few && (
                            <span className="ml-1 rounded bg-amber-100 px-1 text-xs font-normal text-amber-900">zu wenig Daten</span>
                          )}
                        </span>
                      </div>
                      <p className="text-xs text-stone-600">
                        <span data-testid="hyp-base">Basis {r.base ?? "–"}</span> · <span data-testid="hyp-period">{periodLabel}</span>
                      </p>
                      {/* rows with a fixed code (reasons, endings) explain their measure once, on its first row */}
                      {(r.measure === "absence_past_visit_end"
                        ? i === 0 || groupRows[i - 1].measure !== r.measure
                        : !DETAIL_MEASURES.has(r.measure)) && (
                        <p className="text-xs text-stone-600 break-words">{MEASURE[r.measure]?.definition}</p>
                      )}
                      {r.note && <p className="text-xs text-amber-900 break-words" data-testid="hyp-note">{r.note}</p>}
                    </li>
                  ))}
                </ul>
              </article>
            );
          })}
        </div>
      ))}
    </section>
  );
}
