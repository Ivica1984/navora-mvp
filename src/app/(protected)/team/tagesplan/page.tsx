import Link from "next/link";
import { connection } from "next/server";
import { PAGE_LABEL } from "@/lib/auth/nav";
import { todayInZurich } from "@/features/field/rules";
import { getDayPlan, getDayPlanState, getDayPlanTeams } from "@/features/planning/day-plan-queries";
import { dayPlanDateBounds, isDayPlanDate } from "@/features/planning/day-plan-view";
import { getPlanTeamMeasures } from "@/features/ai/queries";
import { monthParam } from "@/features/ai/labels";
import DayPlanClient from "./day-plan-client";

// PLAN3 part (b) (ADR-147): the team's day-plan proposal (PLAN3-1, -3, -4, -9, -10, -14; 390 px first). The team asks
// for a day, sees per member who would take which open visit and why, and confirms line by line or by a list it ticked.
// Nothing reaches a visit without a team member's confirmation (AIG1, migrations 0097, 0109, 0110).
export default async function DayPlanPage({ searchParams }: PageProps<"/team/tagesplan">) {
  // Care data is never prerendered or cached (ADR-010, SR-05).
  await connection();
  const { team, datum } = await searchParams;
  const today = todayInZurich();
  const bounds = dayPlanDateBounds(today);
  const teams = await getDayPlanTeams();
  const selected = teams.find((t) => t.team_id === team) ?? teams[0] ?? null;
  const date = typeof datum === "string" && isDayPlanDate(datum, today) ? datum : null;
  const [state, plan, measures] = await Promise.all([
    selected ? getDayPlanState(selected.team_id) : Promise.resolve(null),
    selected && date ? getDayPlan(selected.team_id, date) : Promise.resolve(null),
    // PLAN3-7 (2) (ADR-155): the same reader as Operations, current Zurich month; null when the read failed.
    selected ? getPlanTeamMeasures(monthParam(undefined)) : Promise.resolve(null),
  ]);
  // Only the selected team's row reaches the client (a coordinator's read also returns other teams).
  const ownMeasure = selected && measures ? (measures.find((m) => m.team_id === selected.team_id) ?? null) : null;
  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-1">
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold underline underline-offset-4">
            {PAGE_LABEL.team}
          </Link>
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Tagesvorschlag</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Der Assistent schlägt vor, wer welchen offenen Einsatz übernimmt. Zugeteilt wird nur, was eine Person aus dem Team bestätigt.
        </p>
      </header>
      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        {selected ? (
          <DayPlanClient
            key={`${selected.team_id}:${date ?? ""}`}
            teams={teams.map((t) => ({ team_id: t.team_id, team_name: t.team_name }))}
            team={selected}
            state={state}
            date={date}
            bounds={bounds}
            lines={plan?.lines ?? []}
            load={plan?.load ?? []}
            measure={ownMeasure}
            measureFailed={measures === null}
          />
        ) : (
          <p data-testid="day-plan-no-team" className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
            Du bist in keinem Team mit laufenden Klientinnen und Klienten.
          </p>
        )}
      </main>
    </div>
  );
}
