import type { HypothesisRow, KpiRow, StepSpanRow } from "@/features/analytics/queries";
import { buildStepScopes, formatStep, type StepSourceRow } from "@/features/analytics/step-spans";

/**
 * AN3: "Wo die Nicht-Pflegezeit hingeht". One group per scope (organisation, then each team): the care share and the
 * travel within visits first, then each administrative step with its median, base and period. Facts only: no target,
 * colour scale or ranking (AN3-5). Cards stack, so 390 px fits. role="group" keeps the AN1 region names unique.
 */
export default function StepSpans({ kpis, hypotheses, spans, periodLabel }: {
  kpis: KpiRow[];
  hypotheses: HypothesisRow[];
  spans: StepSpanRow[];
  periodLabel: string;
}) {
  const fromKpi: StepSourceRow[] = kpis.map((r) => ({ ...r, key: r.kpi }));
  // AN2 rows: a suppressed row shows no value (the database already returns null); `note` explains it.
  const fromHyp: StepSourceRow[] = hypotheses.filter((r) => r.detail === null).map((r) => ({ ...r, key: r.measure }));
  const fromSpan: StepSourceRow[] = spans.map((r) => ({ ...r, key: r.measure }));
  const scopes = buildStepScopes(fromKpi, fromHyp, fromSpan);

  return (
    <section aria-label="Wo die Nicht-Pflegezeit hingeht" data-testid="step-spans" className="grid min-w-0 gap-3">
      <header className="grid gap-1">
        <h2 className="text-xl font-bold">Wo die Nicht-Pflegezeit hingeht</h2>
        <p className="text-sm text-stone-600">
          Wie lange jeder Schritt dauert, den NAVORA schon mit Zeitpunkten erfasst: Median pro Team und Monat, mit Basis. Keine
          neue Erfassung, nie pro Pflegeperson, kein Richtwert. Weniger als 5 Fälle: «zu wenig Daten».
        </p>
      </header>
      {scopes.length === 0 && (
        <p data-testid="no-step-spans" className="rounded-xl border border-stone-300 bg-white p-4">Für dich gibt es keine Schrittzeiten.</p>
      )}
      {scopes.map((scope) => (
        <div key={scope.key} role="group" aria-label={`Schritte: ${scope.title}`} data-scope={scope.key.startsWith("org:") ? "org" : "team"}
             className="grid min-w-0 gap-2 rounded-2xl border border-stone-200 bg-white p-4">
          <h3 className="text-lg font-bold">{scope.title}</h3>
          <ul className="grid gap-2">
            {scope.figures.map((f) => (
              <li key={f.key} data-step={f.key} className="grid min-w-0 gap-0.5 rounded-lg bg-stone-50 px-3 py-2 text-sm">
                <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                  <span className="font-medium break-words">{f.label}</span>
                  <span className="tabular-nums font-semibold" data-testid="step-value">
                    {formatStep(f.unit, f.value)}
                    {f.tooFew && (
                      <span className="ml-1 rounded bg-amber-100 px-1 text-xs font-normal text-amber-900">zu wenig Daten</span>
                    )}
                  </span>
                </div>
                <p className="text-xs text-stone-600">
                  <span data-testid="step-base">Basis {f.base ?? "–"}</span> · <span data-testid="step-period">{periodLabel}</span>
                </p>
                <p className="text-xs text-stone-600 break-words">
                  {f.definition} <span className="italic">Quelle: {f.source}.</span>
                </p>
                {f.note && <p className="text-xs text-amber-900 break-words" data-testid="step-note">{f.note}</p>}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </section>
  );
}
