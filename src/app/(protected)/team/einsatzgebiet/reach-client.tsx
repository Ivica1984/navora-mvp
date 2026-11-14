"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { setTeamReach } from "@/features/reach/commands";
import type { PostcodeOption, TeamReach } from "@/features/reach/queries";
import { REACH_NEW_ORDERS_ONLY_TEXT, parseDistanceKm, parsePostcodes, reachProblemsByField } from "@/features/reach/rules";
import { formatDate } from "@/features/ai/labels";
import { ErrorText } from "../error-text";

const button = "min-h-11 rounded-lg px-3 text-sm font-semibold disabled:opacity-60";

/**
 * BK-b1s (a)–(d): one form per own team. The ticked postcodes and the maximum distance go to `set_team_reach` as they
 * are; every refusal comes from the database and is shown at its field (b). The line under the button says that a
 * change applies to new orders only (d).
 */
export default function ReachClient({ teams, postcodes }: { teams: TeamReach[]; postcodes: PostcodeOption[] }) {
  if (teams.length === 0) {
    return (
      <p data-testid="reach-empty" className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
        Kein eigenes Team. Das Einsatzgebiet stellt ein Mitglied des Teams ein.
      </p>
    );
  }
  return (
    <>
      {teams.map((t) => (
        <ReachForm key={t.team_id} team={t} postcodes={postcodes} />
      ))}
    </>
  );
}

function ReachForm({ team, postcodes }: { team: TeamReach; postcodes: PostcodeOption[] }) {
  const router = useRouter();
  const [ticked, setTicked] = useState<string[]>(team.postcodes ?? []);
  const [distance, setDistance] = useState<string>(team.max_distance_km == null ? "" : String(team.max_distance_km));
  const [pending, setPending] = useState(false);
  const [saved, setSaved] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [problems, setProblems] = useState<{ postcodes: string[]; distance: string[] }>({ postcodes: [], distance: [] });
  const pcId = `reach-pc-${team.team_id}`;
  const kmId = `reach-km-${team.team_id}`;

  function toggle(pc: string, on: boolean) {
    setTicked((cur) => (on ? [...cur, pc] : cur.filter((x) => x !== pc)));
  }

  async function save() {
    setPending(true);
    setSaved(null);
    setError(null);
    setProblems({ postcodes: [], distance: [] });
    const r = await setTeamReach({
      teamId: team.team_id,
      postcodes: parsePostcodes(ticked),
      maxDistanceKm: parseDistanceKm(distance),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (r.ok) {
      setSaved(r.changed ? "Gespeichert." : "Keine Änderung.");
      router.refresh();
    } else if ("problems" in r) {
      setProblems(reachProblemsByField(r.problems));
    } else {
      setError(r.error);
    }
  }

  return (
    <section
      aria-label={`Einsatzgebiet ${team.team_name}`}
      data-testid="reach-form"
      className="rounded-2xl border border-emerald-900/10 bg-white p-4 shadow-sm"
    >
      <h2 className="text-lg font-bold">{team.team_name}</h2>
      {team.team_status !== "active" ? (
        <p data-testid="reach-not-active" className="mt-1 text-sm text-stone-700">
          Das Team ist noch im Aufbau und erhält noch keine Aufträge.
        </p>
      ) : null}
      <p data-testid="reach-changed-at" className="mt-1 text-sm text-stone-700">
        {team.reach_changed_at ? `Zuletzt geändert am ${formatDate(team.reach_changed_at)}.` : "Noch nicht eingestellt."}
      </p>
      <fieldset className="mt-3" aria-describedby={problems.postcodes.length ? `${pcId}-err` : undefined}>
        <legend className="text-sm font-semibold">PLZ des Einsatzgebiets</legend>
        <ul className="mt-1 grid grid-cols-1 gap-1 sm:grid-cols-2">
          {postcodes.map((p) => (
            <li key={p.postcode}>
              <label className="flex min-h-11 items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  className="h-5 w-5"
                  checked={ticked.includes(p.postcode)}
                  onChange={(e) => toggle(p.postcode, e.target.checked)}
                />
                {p.postcode} {p.place_name}
              </label>
            </li>
          ))}
        </ul>
        {problems.postcodes.length ? (
          <div id={`${pcId}-err`} data-testid="reach-postcodes-error">
            <ErrorText message={problems.postcodes.join(" ")} testId="reach-postcodes-error-text" />
          </div>
        ) : null}
      </fieldset>
      <div className="mt-3">
        <label htmlFor={kmId} className="text-sm font-semibold">
          Höchstdistanz in km
        </label>
        <input
          id={kmId}
          inputMode="decimal"
          value={distance}
          onChange={(e) => setDistance(e.target.value)}
          aria-invalid={problems.distance.length > 0}
          aria-describedby={problems.distance.length ? `${kmId}-err` : undefined}
          className="mt-1 block min-h-11 w-32 rounded-lg border border-stone-400 px-2 text-base"
        />
        {problems.distance.length ? (
          <div id={`${kmId}-err`} data-testid="reach-distance-error">
            <ErrorText message={problems.distance.join(" ")} testId="reach-distance-error-text" />
          </div>
        ) : null}
      </div>
      <button
        type="button"
        onClick={save}
        disabled={pending}
        className={`${button} mt-4 bg-emerald-800 text-white`}
      >
        Einsatzgebiet speichern
      </button>
      <p data-testid="reach-new-orders-only" className="mt-2 text-sm text-stone-700">
        {REACH_NEW_ORDERS_ONLY_TEXT}
      </p>
      {saved ? (
        <p role="status" data-testid="reach-saved" className="mt-2 text-sm font-semibold text-emerald-900">
          {saved}
        </p>
      ) : null}
      <ErrorText message={error} testId="reach-error" />
    </section>
  );
}
