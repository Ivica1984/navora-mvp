"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { signOut } from "@/features/auth/actions";
import { completeVisit, startVisit } from "@/features/visits/commands";
import { getVisitStatusLabel } from "@/features/visits/types";
import {
  formatDayLabel,
  formatTime,
  nextFieldAction,
  summarizeDay,
} from "@/features/field/rules";
import type { FieldVisit } from "@/features/field/types";

type Props = {
  day: string;
  isToday: boolean;
  previousDay: string;
  nextDay: string;
  visits: FieldVisit[];
};

const STATUS_CLASS: Record<string, string> = {
  planned: "bg-amber-100 text-amber-900",
  started: "bg-blue-100 text-blue-900",
  on_the_way: "bg-blue-100 text-blue-900",
  paused: "bg-blue-100 text-blue-900",
  completed: "bg-emerald-100 text-emerald-900",
  cancelled: "bg-rose-100 text-rose-900",
  no_show: "bg-rose-100 text-rose-900",
};

export default function FieldClient({ day, isToday, previousDay, nextDay, visits }: Props) {
  const summary = summarizeDay(visits);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="sticky top-0 z-10 bg-emerald-950 px-4 pb-4 pt-3 text-white shadow-md">
        <div className="mx-auto flex max-w-xl items-center justify-between gap-3">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">NAVORA · Mein Tag</p>
          <form action={signOut}>
            <button type="submit" className="min-h-11 rounded-lg px-3 text-sm font-semibold text-emerald-100 underline-offset-4 hover:underline">
              Abmelden
            </button>
          </form>
        </div>
        <div className="mx-auto mt-1 max-w-xl">
          <h1 className="text-xl font-bold leading-tight">{isToday ? "Heute" : formatDayLabel(day)}</h1>
          {isToday && <p className="text-sm text-emerald-100">{formatDayLabel(day)}</p>}
          <nav aria-label="Tag wechseln" className="mt-3 grid grid-cols-3 gap-2 text-sm font-semibold">
            <Link href={`/field?datum=${previousDay}`} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">
              ← Vortag
            </Link>
            <Link href="/field" aria-current={isToday ? "date" : undefined} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">
              Heute
            </Link>
            <Link href={`/field?datum=${nextDay}`} className="flex min-h-11 items-center justify-center rounded-lg bg-emerald-900">
              Folgetag →
            </Link>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-xl px-4 py-4">
        <section className="mb-4 grid grid-cols-3 gap-2 text-center" aria-label="Tagesübersicht">
          <Stat label="Offen" value={summary.open} />
          <Stat label="Laufend" value={summary.running} />
          <Stat label="Erledigt" value={summary.done} />
        </section>

        {visits.length === 0 ? (
          <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center text-emerald-900/70">
            Keine Einsätze deiner Teams an diesem Tag.
          </p>
        ) : (
          <ol className="grid gap-3" aria-label="Einsätze">
            {visits.map((visit) => (
              <li key={visit.visit_id}>
                <VisitCard visit={visit} />
              </li>
            ))}
          </ol>
        )}

        <p className="mt-6 text-xs leading-relaxed text-emerald-900/60">
          Du siehst die Einsätze deiner Teams. Zeiterfassung, Beobachtungen und Bericht folgen in den nächsten Ausbaustufen.
        </p>
      </main>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl bg-white p-3 shadow-sm">
      <p className="text-2xl font-bold">{value}</p>
      <p className="text-xs font-semibold uppercase tracking-wide text-emerald-900/60">{label}</p>
    </div>
  );
}

function VisitCard({ visit }: { visit: FieldVisit }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const action = nextFieldAction(visit.status);
  const start = formatTime(visit.time_start);
  const end = formatTime(visit.time_end);
  const time = start ? (end ? `${start} – ${end}` : `ab ${start}`) : "Zeit offen";
  const place = [visit.address, [visit.plz, visit.ort].filter(Boolean).join(" ")].filter(Boolean).join(", ");
  const services = visit.services_provided?.length ? visit.services_provided.join(", ") : null;
  const needs = visit.care_needs?.length ? visit.care_needs.join(", ") : null;

  async function run() {
    if (!action) return;
    setPending(true);
    setError(null);
    // One idempotency key per tap: a retried request is applied at most once (T10).
    const command = action === "start" ? startVisit : completeVisit;
    const result = await command({ visitId: visit.visit_id, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  return (
    <article
      aria-label={`Einsatz ${time}, ${visit.client_name ?? "Klient:in"}`}
      className="rounded-2xl bg-white p-4 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-lg font-bold tabular-nums">{time}</p>
          <h2 className="text-base font-semibold">{visit.client_name ?? "Klient:in ohne Namen"}</h2>
        </div>
        <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${STATUS_CLASS[visit.status ?? ""] ?? "bg-stone-200 text-stone-800"}`}>
          {getVisitStatusLabel(visit.status)}
        </span>
      </div>

      <dl className="mt-3 grid gap-1 text-sm">
        <Row label="Ort" value={place || "Adresse fehlt – im Team klären"} muted={!place} />
        <Row label="Leistungen" value={services ?? "Noch nicht erfasst"} muted={!services} />
        {needs && <Row label="Pflegebedarf" value={needs} />}
        <Row label="Team" value={visit.team_name} />
      </dl>

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}

      {action && (
        <button
          type="button"
          onClick={run}
          disabled={pending}
          className={`mt-4 min-h-12 w-full rounded-xl text-base font-bold text-white disabled:opacity-60 ${
            action === "start" ? "bg-emerald-800 active:bg-emerald-900" : "bg-blue-800 active:bg-blue-900"
          }`}
        >
          {pending ? "Wird gespeichert …" : action === "start" ? "Einsatz starten" : "Einsatz abschliessen"}
        </button>
      )}
    </article>
  );
}

function Row({ label, value, muted = false }: { label: string; value: string; muted?: boolean }) {
  return (
    <div className="grid grid-cols-[7.5rem_1fr] gap-2">
      <dt className="text-emerald-900/60">{label}</dt>
      <dd className={muted ? "text-emerald-900/50 italic" : ""}>{value}</dd>
    </div>
  );
}
