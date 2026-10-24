"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { acceptCover, withdrawCover } from "@/features/cover/commands";
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
          <p className="text-xs text-violet-900/80">
            Wer zuerst übernimmt, hat den Einsatz. Name, Adresse und Pflegeplan zeigt NAVORA erst, wenn der Zugriff für Übernahmen geklärt ist (D-3);
            bis dahin klärt das Team des Falls die Details mit dir.
          </p>
        </>
      )}
      {error && <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">{error}</p>}
      {mine.length > 0 && (
        <>
          <h2 className="font-bold text-violet-900">Von dir übernommen</h2>
          <ul className="grid gap-1" aria-label="Meine Übernahmen">
            {mine.map((m) => (
              <li key={m.visit_id} className="grid gap-1">
                <span>{slot(m.visit_date, m.time_start, m.time_end)} · {m.area ?? "Ort offen"} · Team {m.team_name} · {offerMinutes(m.minutes_a, m.minutes_b, m.minutes_c)}</span>
                <form aria-label="Übernahme zurückgeben" className="flex flex-wrap gap-2" onSubmit={(e) => {
                  e.preventDefault();
                  const reason = String(new FormData(e.currentTarget).get("reason") ?? "").trim();
                  if (reason.length < 3) return setError("Bitte einen Grund angeben.");
                  void (async () => {
                    setPending(m.visit_id);
                    setError(null);
                    const result = await withdrawCover({ visitId: m.visit_id, reason, idempotencyKey: crypto.randomUUID() });
                    setPending(null);
                    if (!result.ok) setError(result.error);
                    router.refresh();
                  })();
                }}>
                  <input name="reason" required minLength={3} maxLength={300} placeholder="Grund" aria-label="Grund für die Rückgabe"
                    className="min-h-11 flex-1 rounded-lg border border-stone-300 bg-white px-2" />
                  <button type="submit" disabled={pending !== null} className="min-h-11 rounded-lg border border-violet-800 px-3 font-semibold">Zurückgeben</button>
                </form>
              </li>
            ))}
          </ul>
          <p className="text-xs text-violet-900/80">
            Der Einsatz bleibt beim Team des Falls als «ohne Verantwortliche» markiert, bis du ihn in NAVORA durchführen kannst (D-3). Das Team stimmt sich mit dir ab.
          </p>
        </>
      )}
    </section>
  );
}
