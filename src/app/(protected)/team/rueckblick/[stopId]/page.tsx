import Link from "next/link";
import { notFound } from "next/navigation";
import { connection } from "next/server";
import { getStopLookback, getTeamLookbackStops } from "@/features/ai/queries";
import { LOOKBACK_EXPLANATION, NOT_OPEN_TEXT, fieldLabel, formatDate, linesOfTeams, lookbackCountsText, supersededText } from "@/features/ai/labels";

// PLAN3-11 (ADR-149): the look-back lines of one stop, as the team sees them where it plans. Same reader and line layout
// as the Operations list (AIG1-12/-13/-14, AIG1-C1): record (case reference, visit date), field, team and, where it
// applies, "überholt am <Datum>" or "Einsatz nicht mehr offen". Narrowed to the caller's own teams on this stop
// (`team_lookback_stops`, migration 0111), so a coordinator who is also a team member sees only her teams' lines here;
// Operations keeps the full list. No person name, no confirming person, no outcome, no person filter or sort. Each line opens its
// record, which links back here and offers the AIG1-C2 actions to the record's team. Writes nothing.
export default async function TeamLookbackPage({ params }: { params: Promise<{ stopId: string }> }) {
  await connection();
  const { stopId } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(stopId)) notFound();
  const [allLines, stops] = await Promise.all([getStopLookback(stopId), getTeamLookbackStops()]);
  const teamIds = (stops ?? []).filter((s) => s.stop_id === stopId).map((s) => s.team_id);
  const lines = linesOfTeams(allLines, teamIds);
  const open = lines.filter((l) => !l.superseded && !l.not_open).length;
  const notOpen = lines.filter((l) => l.not_open).length;
  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <main className="mx-auto grid max-w-xl min-w-0 gap-4 px-4 py-4">
        <Link href="/team" className="flex min-h-11 items-center text-sm font-semibold underline underline-offset-4">
          Zurück zum Team
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
            Keine offenen Werte eures Teams auf der Liste.
          </p>
        ) : (
          <ul aria-label="Betroffene Werte" data-testid="lookback-list" className="grid gap-2">
            {lines.map((l) => (
              <li key={`${l.entity_type}:${l.entity_id}:${l.field}`}>
                <Link
                  href={`/visits/${l.entity_id}?von=team-rueckblick&stopp=${stopId}`}
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
      </main>
    </div>
  );
}
