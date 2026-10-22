"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { acceptCover } from "@/features/cover/commands";
import type { CoverOffer, MyCover } from "@/features/cover/queries";
import { offerMinutes } from "@/features/cover/rules";
import { formatDayLabel, formatTime } from "@/features/field/rules";
import { QUALIFICATION_LABEL } from "@/features/team/rules";

/**
 * COVER1 on /field: visits a neighbouring team could not cover, offered without client identity,
 * and the covers this nurse accepted. Running an accepted cover in the app waits for D-3.
 */
export default function CoverSection({ offers, mine }: { offers: CoverOffer[]; mine: MyCover[] }) {
  const router = useRouter();
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  if (offers.length === 0 && mine.length === 0) return null;

  async function accept(visitId: string) {
    setPending(visitId);
    setError(null);
    const result = await acceptCover({ visitId, idempotencyKey: crypto.randomUUID() });
    setPending(null);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  const slot = (date: string, start: string | null, end: string | null) =>
    `${formatDayLabel(date)} · ${formatTime(start) ?? "Zeit offen"}${end ? `–${formatTime(end)}` : ""}`;

  return (
    <section aria-label="Übernahmen im Netzwerk" data-testid="cover" className="mb-4 grid gap-2 rounded-2xl border-l-4 border-violet-600 bg-violet-50 p-3 text-sm">
      {offers.length > 0 && (
        <>
          <h2 className="font-bold text-violet-900">Ein Nachbarteam braucht Unterstützung ({offers.length})</h2>
          <ul className="grid gap-2" aria-label="Übernahme-Angebote">
            {offers.map((o) => (
              <li key={o.visit_id} className="grid gap-1 rounded-xl bg-white p-2">
                <p className="font-semibold">{slot(o.visit_date, o.time_start, o.time_end)}</p>
                <p>{o.area ?? "Ort offen"} · Team {o.team_name} · {o.services?.join(", ") ?? "–"} · {offerMinutes(o.minutes_a, o.minutes_b, o.minutes_c)}</p>
                {o.required_qualification && <p className="text-xs">nur {QUALIFICATION_LABEL[o.required_qualification]}</p>}
                <button type="button" disabled={pending !== null} onClick={() => accept(o.visit_id)}
                  className="min-h-11 rounded-lg bg-violet-800 font-bold text-white disabled:opacity-60">
                  {pending === o.visit_id ? "Wird gespeichert …" : "Einsatz übernehmen"}
                </button>
              </li>
            ))}
          </ul>
          <p className="text-xs text-violet-900/80">Name und Adresse siehst du erst nach der Übernahme. Wer zuerst übernimmt, hat den Einsatz.</p>
        </>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {mine.length > 0 && (
        <>
          <h2 className="font-bold text-violet-900">Von dir übernommen</h2>
          <ul className="grid gap-1" aria-label="Meine Übernahmen">
            {mine.map((m) => (
              <li key={m.visit_id}>
                {slot(m.visit_date, m.time_start, m.time_end)} · {m.area ?? "Ort offen"} · Team {m.team_name} · {offerMinutes(m.minutes_a, m.minutes_b, m.minutes_c)}
              </li>
            ))}
          </ul>
          <p className="text-xs text-violet-900/80">
            Die Einsatzdetails für Teamfremde schaltet NAVORA frei, sobald der Entscheid zum Datenzugriff (D-3) gefallen ist. Bis dahin stimmt sich das Team des Falls mit dir ab.
          </p>
        </>
      )}
    </section>
  );
}
