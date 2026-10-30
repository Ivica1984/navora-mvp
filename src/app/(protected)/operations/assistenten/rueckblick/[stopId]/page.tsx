import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { AppFrame } from "@/components/layout/Sidebar";
import { getStopLookback } from "@/features/ai/queries";
import { fieldLabel, formatDate, supersededText } from "@/features/ai/labels";

// AIG1-12 / -13 / -14 (ADR-129): after a stop, the records that hold a value of that agent confirmed unchanged in the
// stop window. Its own line layout: record (case reference, visit date), field and, where it applies, "überholt am
// <Datum>". No person name, no "bestätigt von", no outcome, no person filter or sort (AIG1-14); agent_stop_lookback
// returns no such column. Each line has one action: it opens its record. The list writes nothing; whether, by whom and
// by when a value is re-checked is the Clinical Owner's (D-17, UNKNOWN).
export default async function LookbackPage({ params }: { params: Promise<{ stopId: string }> }) {
  await connection();
  const { stopId } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(stopId)) notFound();
  const lines = await getStopLookback(stopId);
  const open = lines.filter((l) => !l.superseded).length;
  return (
    <AppFrame active="operations" className="bg-stone-50 text-emerald-950">
      <main className="grid min-w-0 gap-4 p-4 md:p-6">
        <Link href="/operations" className="text-sm font-semibold underline underline-offset-4">
          Zurück zu den Ausnahmen
        </Link>
        <header>
          <h1 className="text-2xl font-bold">Unverändert bestätigte Werte</h1>
          <p className="text-sm text-secondary">
            Werte des gestoppten Assistenten, die im Stoppfenster unverändert bestätigt wurden. Ob, von wem und bis wann sie
            nachgeprüft werden, ist offen (klinische Verantwortung). Ein Wert verlässt die Liste, sobald er im Einsatz erneut
            bestätigt oder geändert wird.
          </p>
          <p className="mt-1 text-sm font-semibold" data-testid="lookback-open-count">
            {open === 1 ? "1 offen" : `${open} offen`}
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
                  href={`/visits/${l.entity_id}`}
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
                </Link>
              </li>
            ))}
          </ul>
        )}
      </main>
    </AppFrame>
  );
}
