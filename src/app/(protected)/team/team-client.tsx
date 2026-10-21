"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { decideMatchingRequest } from "@/features/team/commands";
import type { TeamOffer } from "@/features/team/queries";

const URGENCY_CLASS: Record<string, string> = {
  hoch: "bg-rose-100 text-rose-900",
  mittel: "bg-amber-100 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

function hoursSince(iso: string) {
  return Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 3_600_000));
}

export default function TeamClient({ offers }: { offers: TeamOffer[] }) {
  const open = offers.filter((o) => !o.my_team_declined);
  const declined = offers.filter((o) => o.my_team_declined);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="bg-emerald-950 px-4 pb-4 pt-3 text-white">
        <div className="mx-auto flex max-w-xl items-center justify-between">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">NAVORA · Team</p>
          <Link href="/field" className="flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold underline underline-offset-4">
            Mein Tag
          </Link>
        </div>
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Anfragen an dein Team</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Ihr entscheidet selbst, welche Klientinnen und Klienten ihr übernehmt. Der erste Zusage-Entscheid eines Teams gilt.
        </p>
      </header>

      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        {open.length === 0 && (
          <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
            Keine offenen Anfragen für deine Teams.
          </p>
        )}
        <ul className="grid gap-3" aria-label="Offene Anfragen">
          {open.map((offer) => (
            <li key={`${offer.matching_request_id}-${offer.team_id}`}>
              <OfferCard offer={offer} />
            </li>
          ))}
        </ul>

        {declined.length > 0 && (
          <section aria-label="Abgelehnt" className="mt-4 grid gap-2">
            <h2 className="text-sm font-bold uppercase tracking-wide text-emerald-900/60">Von deinem Team abgelehnt</h2>
            {declined.map((o) => (
              <p key={`${o.matching_request_id}-${o.team_id}`} className="rounded-xl bg-white/60 p-3 text-sm">
                {o.request_title} · {o.region}
              </p>
            ))}
          </section>
        )}

        <p className="mt-4 text-xs leading-relaxed text-emerald-900/60">
          Angeboten werden Anfragen aus der Region deines aktiven Teams. Kompetenzen, Qualifikationen, Kapazität und
          Sicherheitsvorbehalte werden noch nicht automatisch geprüft – bitte im Team beurteilen. Namen und Kontaktdaten
          sind erst nach der Zusage sichtbar.
        </p>
      </main>
    </div>
  );
}

function OfferCard({ offer }: { offer: TeamOffer }) {
  const router = useRouter();
  const [pending, setPending] = useState<"accept" | "decline" | null>(null);
  const [declining, setDeclining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reason, setReason] = useState("");

  async function decide(decision: "accept" | "decline") {
    setPending(decision);
    setError(null);
    const result = await decideMatchingRequest({
      requestId: offer.matching_request_id,
      teamId: offer.team_id,
      decision,
      reason: decision === "decline" ? reason : "",
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(null);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  return (
    <article aria-label={`Anfrage ${offer.request_title}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="font-bold">{offer.request_title}</h2>
          <p className="text-sm text-emerald-900/70">
            {offer.region} · für {offer.team_name} · seit {hoursSince(offer.created_at)} h offen
          </p>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${URGENCY_CLASS[offer.urgency] ?? "bg-stone-200"}`}>
          {offer.urgency}
        </span>
      </div>
      <p className="mt-2 text-sm">
        Leistungen: {offer.required_services?.length ? offer.required_services.join(", ") : "nicht angegeben"}
      </p>
      <ul className="mt-2 grid gap-0.5 text-xs" aria-label="Prüfkriterien">
        <li>✓ Aktives Team · ✓ Region</li>
        <li className="text-amber-800">○ Kompetenz, Qualifikation, Kapazität, Sicherheitsvorbehalte: nicht automatisch geprüft</li>
      </ul>

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}

      {!declining ? (
        <div className="mt-4 grid grid-cols-[2fr_1fr] gap-2">
          <button
            type="button"
            onClick={() => decide("accept")}
            disabled={pending !== null}
            className="min-h-12 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60"
          >
            {pending === "accept" ? "Wird gespeichert …" : "Fall übernehmen"}
          </button>
          <button
            type="button"
            onClick={() => setDeclining(true)}
            disabled={pending !== null}
            className="min-h-12 rounded-xl border-2 border-emerald-800 font-bold text-emerald-900"
          >
            Ablehnen
          </button>
        </div>
      ) : (
        <div className="mt-3 grid gap-2">
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Grund (optional, für das Team und den Coach)</span>
            <input
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={500}
              className="min-h-11 rounded-lg border border-stone-300 bg-white px-3"
            />
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => decide("decline")}
              disabled={pending !== null}
              className="min-h-11 rounded-xl bg-stone-700 font-bold text-white disabled:opacity-60"
            >
              {pending === "decline" ? "Wird gespeichert …" : "Ablehnung speichern"}
            </button>
            <button type="button" onClick={() => setDeclining(false)} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </div>
      )}
    </article>
  );
}
