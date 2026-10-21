"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { decideMatchingRequest, planVisit, removePlannedVisit, rescheduleVisit } from "@/features/team/commands";
import type { TeamCase, TeamOffer } from "@/features/team/queries";
import { formatDayLabel, shiftDay, todayInZurich } from "@/features/field/rules";
import { getVisitStatusLabel } from "@/features/visits/types";

const URGENCY_CLASS: Record<string, string> = {
  hoch: "bg-rose-100 text-rose-900",
  mittel: "bg-amber-100 text-amber-900",
  niedrig: "bg-stone-200 text-stone-800",
};

function hoursSince(iso: string) {
  return Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 3_600_000));
}

export default function TeamClient({ offers, cases }: { offers: TeamOffer[]; cases: TeamCase[] }) {
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
        <h1 className="mx-auto mt-1 max-w-xl text-xl font-bold">Dein Team</h1>
        <p className="mx-auto max-w-xl text-sm text-emerald-100">
          Ihr entscheidet selbst, welche Klientinnen und Klienten ihr übernehmt. Der erste Zusage-Entscheid eines Teams gilt.
        </p>
      </header>

      <main className="mx-auto grid max-w-xl gap-3 px-4 py-4">
        <h2 className="text-lg font-bold">Anfragen an dein Team</h2>
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

        <section aria-label="Unsere Klientinnen und Klienten" className="mt-6 grid gap-3">
          <h2 className="text-lg font-bold">Unsere Klientinnen und Klienten</h2>
          {cases.length === 0 && (
            <p className="rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center">
              Dein Team betreut noch keine Fälle.
            </p>
          )}
          <ul className="grid gap-3">
            {cases.map((c) => (
              <li key={`${c.case_id}-${c.team_id}`}>
                <CaseCard teamCase={c} />
              </li>
            ))}
          </ul>
        </section>

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

type Upcoming = { visit_id: string; date: string; start: string | null; end: string | null; status: string | null };

function parseUpcoming(raw: unknown): Upcoming[] {
  return Array.isArray(raw)
    ? raw.filter((v): v is Upcoming => typeof v === "object" && v !== null && typeof (v as Upcoming).visit_id === "string")
    : [];
}

const hhmm = (t: string | null) => (t ? t.slice(0, 5) : "–");

function SlotFields({ date, start, end }: { date: string; start: string; end: string }) {
  const field = "min-h-11 rounded-lg border border-stone-300 bg-white px-2";
  return (
    <div className="grid grid-cols-3 gap-2">
      <label className="grid gap-1 text-xs font-semibold">
        Datum
        <input name="date" type="date" required defaultValue={date} className={field} />
      </label>
      <label className="grid gap-1 text-xs font-semibold">
        Von
        <input name="start" type="time" required defaultValue={start} className={field} />
      </label>
      <label className="grid gap-1 text-xs font-semibold">
        Bis
        <input name="end" type="time" required defaultValue={end} className={field} />
      </label>
    </div>
  );
}

function CaseCard({ teamCase }: { teamCase: TeamCase }) {
  const router = useRouter();
  const [planning, setPlanning] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const upcoming = parseUpcoming(teamCase.upcoming);
  const needs = teamCase.care_needs ?? [];

  async function plan(form: FormData) {
    setPending(true);
    setError(null);
    const result = await planVisit({
      caseId: teamCase.case_id,
      date: String(form.get("date") ?? ""),
      start: String(form.get("start") ?? ""),
      end: String(form.get("end") ?? ""),
      services: needs,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setPlanning(false);
    router.refresh();
  }

  return (
    <article aria-label={`Fall ${teamCase.client_name ?? ""}`} className="rounded-2xl bg-white p-4 shadow-sm">
      <h3 className="font-bold">{teamCase.client_name ?? "Klient:in"}</h3>
      <p className="text-sm text-emerald-900/70">
        {teamCase.region} · {teamCase.team_name}
        {needs.length > 0 ? ` · ${needs.join(", ")}` : ""}
      </p>

      <h4 className="mt-3 text-xs font-bold uppercase tracking-wide text-emerald-900/60">Geplante Einsätze</h4>
      {upcoming.length === 0 ? (
        <p className="text-sm italic text-emerald-900/60">Noch keine Einsätze geplant.</p>
      ) : (
        <ul className="mt-1 grid gap-2" aria-label="Geplante Einsätze">
          {upcoming.map((v) => (
            <li key={v.visit_id}>
              <PlannedVisit visit={v} />
            </li>
          ))}
        </ul>
      )}

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}

      {!planning ? (
        <button type="button" onClick={() => setPlanning(true)} className="mt-3 min-h-11 w-full rounded-xl border-2 border-emerald-800 font-bold text-emerald-900">
          Einsatz planen
        </button>
      ) : (
        <form action={plan} aria-label="Einsatz planen" className="mt-3 grid gap-2 rounded-xl bg-stone-50 p-3">
          <SlotFields date={shiftDay(todayInZurich(), 1)} start="08:00" end="08:45" />
          <p className="text-xs text-emerald-900/60">
            Leistungen: {needs.length ? needs.join(", ") : "noch nicht erfasst"} · der Einsatz gehört dem Team.
          </p>
          <div className="grid grid-cols-[2fr_1fr] gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Einsatz speichern"}
            </button>
            <button type="button" onClick={() => { setPlanning(false); setError(null); }} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </article>
  );
}

function PlannedVisit({ visit }: { visit: Upcoming }) {
  const router = useRouter();
  const [moving, setMoving] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const isPlanned = visit.status === "planned";

  async function move(form: FormData) {
    setPending(true);
    setError(null);
    const result = await rescheduleVisit({
      visitId: visit.visit_id,
      date: String(form.get("date") ?? ""),
      start: String(form.get("start") ?? ""),
      end: String(form.get("end") ?? ""),
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setMoving(false);
    router.refresh();
  }

  async function remove() {
    setPending(true);
    setError(null);
    const result = await removePlannedVisit({ visitId: visit.visit_id, idempotencyKey: crypto.randomUUID() });
    setPending(false);
    if (!result.ok) setError(result.error);
    router.refresh();
  }

  return (
    <div className="rounded-lg bg-stone-50 p-2 text-sm">
      <div className="flex items-center justify-between gap-2">
        <p>
          <span className="font-semibold">{formatDayLabel(visit.date)}</span>{" "}
          <span className="tabular-nums">
            {hhmm(visit.start)}–{hhmm(visit.end)}
          </span>{" "}
          <span className="text-emerald-900/60">· {getVisitStatusLabel(visit.status)}</span>
        </p>
        {isPlanned && !moving && (
          <div className="flex shrink-0 gap-1">
            <button type="button" onClick={() => setMoving(true)} className="min-h-11 px-2 font-semibold underline underline-offset-4">
              Verschieben
            </button>
            <button type="button" onClick={remove} disabled={pending} className="min-h-11 px-2 font-semibold text-rose-800 underline underline-offset-4">
              Entfernen
            </button>
          </div>
        )}
      </div>
      {moving && (
        <form action={move} className="mt-2 grid gap-2">
          <SlotFields date={visit.date} start={hhmm(visit.start)} end={hhmm(visit.end)} />
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              Verschieben
            </button>
            <button type="button" onClick={() => setMoving(false)} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
      {error && (
        <p role="alert" data-testid="command-error" className="mt-2 rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
    </div>
  );
}
