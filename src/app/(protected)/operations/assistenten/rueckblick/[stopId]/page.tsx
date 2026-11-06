import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { PageFrame } from "@/components/layout/PageFrame";
import { getStopLookback, getStopMeasures } from "@/features/ai/queries";
import {
  LOOKBACK_EXPLANATION,
  NOT_OPEN_TEXT,
  fieldLabel,
  formatDate,
  lookbackCountsText,
  stopMeasureCells,
  supersededText,
} from "@/features/ai/labels";

// AIG1-12 / -13 / -14 (ADR-129): after a stop, the records that hold a value of that agent confirmed unchanged in the
// stop window. Its own line layout: record (case reference, visit date), field and, where it applies, "überholt am
// <Datum>". No person name, no "bestätigt von", no outcome, no person filter or sort (AIG1-14); agent_stop_lookback
// returns no such column. Each line has one action: it opens its record. The list writes nothing; whether, by whom and
// by when a value is re-checked is the Clinical Owner's (D-17, UNKNOWN). AIG1-C1 (ADR-130): a line of a visit no longer
// open stays, labelled "Einsatz nicht mehr offen" (the line shows its date), and is counted apart ("Werte: <n> offen · <m>
// nicht mehr offen"); the explanation names only the record page's actions (AIG1-C2 (c)). AIG1-C3 (1): each line passes
// its origin to the record page, which links back here. Wording adopted by the PO 2026-10-31 00:10 from `uxa`.
// PLAN3-13 (ADR-150): after the list (uxa UXR-115), the look-back measure per team (agent_stop_measures, 0112): counts of lines only,
// never per person, no target; cards below 640 px, a table above; a failed read says so instead of showing zeros.
export default async function LookbackPage({ params }: { params: Promise<{ stopId: string }> }) {
  await connection();
  const { stopId } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(stopId)) notFound();
  const [lines, measures] = await Promise.all([getStopLookback(stopId), getStopMeasures(stopId)]);
  const open = lines.filter((l) => !l.superseded && !l.not_open).length;
  const notOpen = lines.filter((l) => l.not_open).length;
  return (
    <PageFrame className="bg-stone-50 text-emerald-950">
      <main className="grid min-w-0 gap-4 p-4 md:p-6">
        <Link href="/operations" className="text-sm font-semibold underline underline-offset-4">
          Zurück zu den Ausnahmen
        </Link>
        <header>
          <h1 className="text-2xl font-bold">Unverändert bestätigte Werte</h1>
          <p className="text-sm text-secondary" data-testid="lookback-explanation">
            {LOOKBACK_EXPLANATION}
          </p>
          <p className="mt-1 text-sm font-semibold" data-testid="lookback-open-count">
            {lookbackCountsText(open, notOpen)}
          </p>
        </header>
        {lines.length === 0 ? (
          <p data-testid="lookback-empty" className="rounded-lg border border-dashed border-stone-300 p-4 text-center text-secondary">
            Keine Werte auf der Liste.
          </p>
        ) : (
          <ul aria-label="Betroffene Werte" data-testid="lookback-list" className="grid gap-2">
            {lines.map((l) => (
              <li key={`${l.entity_type}:${l.entity_id}:${l.field}`}>
                <Link
                  href={`/visits/${l.entity_id}?von=rueckblick&stopp=${stopId}`}
                  data-testid="lookback-line"
                  className="grid gap-0.5 rounded-lg border border-stone-200 bg-white p-3 text-sm hover:border-emerald-700"
                >
                  <span className="font-semibold">
                    {l.case_ref ?? "Fall"} · Einsatz {l.visit_date ? formatDate(l.visit_date) : "–"}
                  </span>
                  <span>
                    {fieldLabel(l.field)} · {l.team_name}
                  </span>
                  {l.superseded && (
                    <span data-testid="lookback-superseded" className="text-xs font-semibold">
                      {supersededText(l.superseded_at)}
                    </span>
                  )}
                  {l.not_open && (
                    <span data-testid="lookback-not-open" className="text-xs font-semibold">
                      {NOT_OPEN_TEXT}
                    </span>
                  )}
                </Link>
              </li>
            ))}
          </ul>
        )}
        <section aria-labelledby="stop-measures-title" data-testid="stop-measures" className="grid gap-2">
          <h2 id="stop-measures-title" className="text-lg font-semibold">
            Rückblick in Zahlen
          </h2>
          {measures === null ? (
            <p data-testid="stop-measures-error" className="text-sm">
              Die Zahlen konnten nicht geladen werden.
            </p>
          ) : measures.length === 0 ? (
            <p className="text-sm text-secondary">Keine Zahlen für dieses Team.</p>
          ) : (
            <>
              {/* UXR-115: below 640 px one card per team (label: value), no sideways scroll. */}
              <ul aria-label="Rückblick in Zahlen pro Team" className="grid gap-2 sm:hidden">
                {measures.map((m) => (
                  <li key={m.team_id} data-testid="stop-measure-card" className="rounded-lg border border-stone-200 bg-white p-3 text-sm">
                    <h3 className="font-semibold">{m.team_name}</h3>
                    <dl className="mt-1 grid grid-cols-[1fr_auto] gap-x-3 gap-y-1">
                      {stopMeasureCells(m).map((c) => (
                        <div key={c.key} className="contents">
                          <dt className="text-secondary">{c.label}</dt>
                          <dd className="text-right font-semibold" data-testid={`stop-measure-card-${c.key}`}>
                            {c.value}
                          </dd>
                        </div>
                      ))}
                    </dl>
                  </li>
                ))}
              </ul>
              <div
                role="region"
                aria-label="Tabelle Rückblick in Zahlen"
                tabIndex={0}
                className="hidden overflow-x-auto rounded-xl border border-stone-200 bg-white sm:block"
              >
                <table aria-label="Rückblick in Zahlen pro Team" className="w-full text-left text-sm">
                  <thead className="bg-stone-100 text-xs">
                    <tr>
                      <th className="sticky left-0 bg-stone-100 p-2">Team</th>
                      {stopMeasureCells(measures[0]).map((c) => (
                        <th key={c.key} className="p-2">
                          {c.label}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {measures.map((m) => (
                      <tr key={m.team_id} data-testid="stop-measure-row" className="border-t border-stone-200 align-top">
                        <th scope="row" className="sticky left-0 bg-white p-2 font-semibold">
                          {m.team_name}
                        </th>
                        {stopMeasureCells(m).map((c) => (
                          <td key={c.key} className="p-2" data-testid={`stop-measure-${c.key}`}>
                            {c.value}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </section>
      </main>
    </PageFrame>
  );
}
