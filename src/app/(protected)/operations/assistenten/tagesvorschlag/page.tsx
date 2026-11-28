import Link from "next/link";
import { connection } from "next/server";
import { PageFrame } from "@/components/layout/PageFrame";
import { getPlanTeamMeasures } from "@/features/ai/queries";
import { monthParam, planTeamMeasureCells } from "@/features/ai/labels";

// PLAN3-7 (ADR-151): how teams use the day-plan assistant ("Tagesvorschlag"), per team and Zurich month, never per
// person. plan3_team_measures (0113) returns counts and shares only; a share of a team with fewer than three confirmers
// (AIG1-7) or performers (AN1) in the month comes back null and reads "nicht ausgewiesen". No target, no ranking, no
// stop criterion (ADR-120 deviation 4). A failed read says so instead of showing zeros.
export default async function PlanTeamMeasuresPage({ searchParams }: { searchParams: Promise<{ monat?: string }> }) {
  await connection();
  const { monat } = await searchParams;
  const month = monthParam(monat);
  const rows = await getPlanTeamMeasures(month);
  return (
    <PageFrame className="bg-stone-50 text-emerald-950">
      <main className="grid min-w-0 gap-4 p-4 md:p-6">
        <Link href="/operations/assistenten" className="text-sm font-semibold underline underline-offset-4">
          Zurück zu den Assistenten
        </Link>
        <header>
          <h1 className="text-2xl font-bold">Tagesvorschlag in Zahlen</h1>
          <p className="text-sm text-secondary">
            Pro Team und Monat ({month.slice(0, 7)}), nie pro Person. Werte eines Teams mit weniger als drei Personen im Monat
            werden nicht ausgewiesen.
          </p>
          <form className="mt-2 flex items-end gap-2 text-sm">
            <label className="grid gap-1">
              Monat
              <input type="month" name="monat" defaultValue={month.slice(0, 7)} className="min-h-11 rounded border border-stone-300 px-2" />
            </label>
            <button type="submit" className="min-h-11 rounded border border-stone-300 bg-white px-3 font-semibold">
              Anzeigen
            </button>
          </form>
        </header>
        <section aria-labelledby="plan-team-measures-title" data-testid="plan-team-measures" className="grid gap-2">
          <h2 id="plan-team-measures-title" className="text-lg font-semibold">
            Pro Team
          </h2>
          {rows === null ? (
            <p data-testid="plan-team-measures-error" className="text-sm">
              Die Zahlen konnten nicht geladen werden.
            </p>
          ) : rows.length === 0 ? (
            <p data-testid="plan-team-measures-empty" className="text-sm text-secondary">
              Keine Tagesvorschläge und keine erfassten Einsätze in diesem Monat.
            </p>
          ) : (
            <div className="overflow-x-auto rounded-xl border border-stone-200 bg-white">
              <table aria-label="Tagesvorschlag in Zahlen pro Team" className="w-full text-left text-sm">
                <thead className="bg-stone-100 text-xs uppercase tracking-wide">
                  <tr>
                    <th className="p-2">Team</th>
                    {planTeamMeasureCells(rows[0]).map((c) => (
                      <th key={c.key} className="p-2">
                        {c.label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {rows.map((m) => (
                    <tr key={m.team_id} data-testid="plan-team-measure-row" className="border-t border-stone-200 align-top">
                      <th scope="row" className="p-2 font-semibold">
                        {m.team_name}
                        {m.enabled_since && (
                          <span className="block text-xs font-normal text-secondary">eingeschaltet am {m.enabled_since.split("-").reverse().join(".")}</span>
                        )}
                      </th>
                      {planTeamMeasureCells(m).map((c) => (
                        <td key={c.key} className="p-2" data-testid={`plan-team-measure-${c.key}`}>
                          {c.value}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </main>
    </PageFrame>
  );
}
