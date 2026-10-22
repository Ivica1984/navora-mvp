"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { signOut } from "@/features/auth/actions";
import { completeVisit, departVisit, pauseVisit, resumeVisit, startVisit } from "@/features/visits/commands";
import { getVisitStatusLabel } from "@/features/visits/types";
import {
  FIELD_ACTION_LABEL,
  fieldActions,
  formatDayLabel,
  formatTime,
  summarizeDay,
  type FieldAction,
} from "@/features/field/rules";
import {
  EVENT_LABEL,
  computeVisitTimes,
  formatMinutes,
  parseEvents,
  zurichDate,
  zurichLocalToIso,
  zurichTime,
  type VisitEvent,
} from "@/features/field/time";
import { correctVisitTime, recordObservation } from "@/features/field/commands";
import { formatMinutesByCategory } from "@/features/team/rules";
import type { FieldNote, FieldVisit } from "@/features/field/types";
import type { FieldReport } from "@/features/field/report";
import ReportSection from "./report-section";
import QualitySection from "./quality-section";
import VisitLifecycle from "./visit-lifecycle";
import type { VisitStatusNote } from "@/features/lifecycle/queries";
import type { FieldQuality, QualityEventType } from "@/features/quality/queries";

type Props = {
  day: string;
  isToday: boolean;
  previousDay: string;
  nextDay: string;
  visits: FieldVisit[];
  notes: FieldNote[];
  reports: FieldReport[];
  quality: FieldQuality[];
  qualityTypes: QualityEventType[];
  statusNotes: VisitStatusNote[];
};

const COMMANDS: Record<FieldAction, typeof startVisit> = {
  depart: departVisit,
  start: startVisit,
  pause: pauseVisit,
  resume: resumeVisit,
  complete: completeVisit,
};

// Observations are possible from departure on (migration 0009 enforces the same).
const OBSERVABLE = new Set(["on_the_way", "started", "paused", "completed"]);

const STATUS_CLASS: Record<string, string> = {
  planned: "bg-amber-100 text-amber-900",
  started: "bg-blue-100 text-blue-900",
  on_the_way: "bg-blue-100 text-blue-900",
  paused: "bg-blue-100 text-blue-900",
  completed: "bg-emerald-100 text-emerald-900",
  cancelled: "bg-rose-100 text-rose-900",
  no_show: "bg-rose-100 text-rose-900",
};

export default function FieldClient({ day, isToday, previousDay, nextDay, visits, notes, reports, quality, qualityTypes, statusNotes }: Props) {
  const summary = summarizeDay(visits);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="sticky top-0 z-10 bg-emerald-950 px-4 pb-4 pt-3 text-white shadow-md">
        <div className="mx-auto flex max-w-xl items-center justify-between gap-3">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">NAVORA · Mein Tag</p>
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold text-emerald-100 underline underline-offset-4">
            Teamanfragen
          </Link>
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
                <VisitCard
                  visit={visit}
                  notes={notes.filter((n) => n.visit_id === visit.visit_id)}
                  report={reports.find((r) => r.visit_id === visit.visit_id) ?? null}
                  quality={quality.filter((q) => q.visit_id === visit.visit_id)}
                  qualityTypes={qualityTypes}
                  statusNotes={statusNotes.filter((n) => n.visit_id === visit.visit_id)}
                />
              </li>
            ))}
          </ol>
        )}

        <p className="mt-6 text-xs leading-relaxed text-emerald-900/60">
          Du siehst die Einsätze deiner Teams. Zeiten entstehen aus deinen Statuswechseln und lassen sich mit Begründung korrigieren. Beobachtungen sieht nur dein Team; Übergaben erscheinen bei den nächsten Einsätzen derselben Person. Nach dem Einsatz entsteht der Bericht aus diesen Angaben; die ausführende Person unterschreibt ihn.
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

function VisitCard({
  visit,
  notes,
  report,
  quality,
  qualityTypes,
  statusNotes,
}: {
  visit: FieldVisit;
  notes: FieldNote[];
  report: FieldReport | null;
  quality: FieldQuality[];
  qualityTypes: QualityEventType[];
  statusNotes: VisitStatusNote[];
}) {
  const router = useRouter();
  const [pending, setPending] = useState<FieldAction | null>(null);
  const [error, setError] = useState<string | null>(null);

  const actions = fieldActions(visit.status);
  const start = formatTime(visit.time_start);
  const end = formatTime(visit.time_end);
  const time = start ? (end ? `${start} – ${end}` : `ab ${start}`) : "Zeit offen";
  const place = [visit.address, [visit.plz, visit.ort].filter(Boolean).join(" ")].filter(Boolean).join(", ");
  const services = visit.services_provided?.length ? visit.services_provided.join(", ") : null;
  const needs = visit.care_needs?.length ? visit.care_needs.join(", ") : null;
  const events = parseEvents(visit.events);
  const times = events.length > 0 ? computeVisitTimes(events) : null;

  async function run(action: FieldAction) {
    setPending(action);
    setError(null);
    // One idempotency key per tap: a retried request is applied at most once (T10).
    const result = await COMMANDS[action]({ visitId: visit.visit_id, idempotencyKey: crypto.randomUUID() });
    setPending(null);
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
        {(visit.planned_minutes_a !== null || visit.planned_minutes_b !== null || visit.planned_minutes_c !== null) && (
          <Row
            label="Geplant"
            value={`${visit.is_needs_assessment ? "Bedarfsabklärung · " : ""}${formatMinutesByCategory({
              a: visit.planned_minutes_a,
              b: visit.planned_minutes_b,
              c: visit.planned_minutes_c,
            })}`}
          />
        )}
        {visit.care_goals && visit.care_goals.length > 0 && (
          <Row label="Pflegeziele" value={visit.care_goals.join(" · ")} />
        )}
        <Row
          label="Verantwortlich"
          value={visit.responsible_me ? "du" : visit.responsible_set ? "Teammitglied" : "noch niemand – im Team klären"}
          muted={!visit.responsible_set}
        />
      </dl>

      <Handover notes={notes.filter((n) => n.kind === "handover")} />

      {times && (
        <section aria-label="Erfasste Zeit" className="mt-3 grid grid-cols-3 gap-2 rounded-xl bg-stone-50 p-2 text-center text-sm">
          <TimeCell label="Anfahrt" value={formatMinutes(times.travelMinutes)} />
          <TimeCell label="Pflege" value={formatMinutes(times.careMinutes)} />
          <TimeCell label="Pause" value={formatMinutes(times.pauseMinutes)} />
          {times.inconsistent && (
            <p className="col-span-3 text-xs font-semibold text-amber-800">
              Zeitfolge unstimmig – bitte im Team prüfen.
            </p>
          )}
        </section>
      )}

      {events.length > 0 && <Timeline events={events} />}

      <Observations
        visitId={visit.visit_id}
        canRecord={OBSERVABLE.has(visit.status ?? "")}
        notes={notes.filter((n) => n.kind === "observation")}
      />

      <ReportSection visitId={visit.visit_id} visitStatus={visit.status} report={report} />

      <QualitySection visitId={visit.visit_id} items={quality} types={qualityTypes} />

      <VisitLifecycle visitId={visit.visit_id} status={visit.status} notes={statusNotes} />

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-semibold text-rose-800">
          {error}
        </p>
      )}

      {actions.length > 0 && (
        <div className={`mt-4 grid gap-2 ${actions.length > 1 ? "grid-cols-[2fr_1fr]" : ""}`}>
          {actions.map((action, index) => (
            <button
              key={action}
              type="button"
              onClick={() => run(action)}
              disabled={pending !== null}
              className={`min-h-12 rounded-xl text-base font-bold disabled:opacity-60 ${
                index === 0
                  ? action === "complete"
                    ? "bg-blue-800 text-white active:bg-blue-900"
                    : "bg-emerald-800 text-white active:bg-emerald-900"
                  : "border-2 border-emerald-800 bg-white text-emerald-900 active:bg-emerald-50"
              }`}
            >
              {pending === action ? "Wird gespeichert …" : FIELD_ACTION_LABEL[action]}
            </button>
          ))}
        </div>
      )}
    </article>
  );
}

function formatDateTime(iso: string) {
  return new Intl.DateTimeFormat("de-CH", {
    timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).format(new Date(iso));
}

function Handover({ notes }: { notes: FieldNote[] }) {
  if (notes.length === 0) return null;
  return (
    <section aria-label="Übergabe" className="mt-3 rounded-xl border-l-4 border-amber-500 bg-amber-50 p-3 text-sm">
      <h3 className="font-bold text-amber-900">Übergabe aus dem Team</h3>
      <ul className="mt-1 grid gap-2">
        {notes.map((note) => (
          <li key={note.id}>
            <p className="whitespace-pre-wrap">{note.content}</p>
            <p className="text-xs text-amber-900/70">
              {formatDateTime(note.recorded_at)} · {note.own ? "von dir" : "aus dem Team"}
              {note.edited ? " · geändert" : ""}
            </p>
          </li>
        ))}
      </ul>
    </section>
  );
}

function Observations({ visitId, canRecord, notes }: { visitId: string; canRecord: boolean; notes: FieldNote[] }) {
  if (!canRecord && notes.length === 0) return null;
  return (
    <section aria-label="Beobachtungen" className="mt-3 grid gap-2 text-sm">
      <h3 className="font-bold">Beobachtungen</h3>
      {notes.length > 0 && (
        <ul className="grid gap-2">
          {notes.map((note) => (
            <li key={note.id}>
              <ObservationEntry visitId={visitId} note={note} />
            </li>
          ))}
        </ul>
      )}
      {canRecord && <ObservationForm visitId={visitId} supersedesId={null} />}
    </section>
  );
}

function ObservationEntry({ visitId, note }: { visitId: string; note: FieldNote }) {
  const [editing, setEditing] = useState(false);
  if (editing) {
    return (
      <ObservationForm
        visitId={visitId}
        supersedesId={note.id}
        initialContent={note.content}
        initialHandover={note.for_handover}
        onDone={() => setEditing(false)}
      />
    );
  }
  return (
    <div className="rounded-lg bg-stone-50 p-2">
      <p className="whitespace-pre-wrap">{note.content}</p>
      <div className="mt-1 flex items-center justify-between gap-2">
        <p className="text-xs text-emerald-900/60">
          {formatDateTime(note.recorded_at)} · {note.own ? "von dir" : "aus dem Team"}
          {note.edited ? " · geändert" : ""}
          {note.for_handover ? " · Übergabe" : ""}
        </p>
        {note.own && (
          <button type="button" onClick={() => setEditing(true)} className="min-h-11 shrink-0 px-2 font-semibold underline underline-offset-4">
            Ändern
          </button>
        )}
      </div>
    </div>
  );
}

function ObservationForm({
  visitId,
  supersedesId,
  initialContent = "",
  initialHandover = false,
  onDone,
}: {
  visitId: string;
  supersedesId: string | null;
  initialContent?: string;
  initialHandover?: boolean;
  onDone?: () => void;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formKey, setFormKey] = useState(0);

  async function save(form: FormData) {
    setPending(true);
    setError(null);
    const result = await recordObservation({
      visitId,
      content: String(form.get("content") ?? ""),
      forHandover: form.get("handover") === "on",
      supersedesId,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setFormKey((k) => k + 1); // clears the form for the next observation
    onDone?.();
    router.refresh();
  }

  const label = supersedesId ? "Beobachtung ändern" : "Neue Beobachtung";
  return (
    <form key={formKey} action={save} className="grid gap-2 rounded-lg border border-stone-200 p-2">
      <label className="grid gap-1">
        <span className="text-xs font-semibold">{label}</span>
        <textarea
          name="content"
          required
          maxLength={2000}
          rows={3}
          defaultValue={initialContent}
          className="rounded-lg border border-stone-300 bg-white p-2"
        />
      </label>
      <label className="flex min-h-11 items-center gap-2">
        <input name="handover" type="checkbox" defaultChecked={initialHandover} className="size-5" />
        <span>Für die Übergabe markieren</span>
      </label>
      {error && (
        <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">
          {error}
        </p>
      )}
      <div className={`grid gap-2 ${onDone ? "grid-cols-2" : ""}`}>
        <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
          {pending ? "Wird gespeichert …" : supersedesId ? "Änderung speichern" : "Beobachtung speichern"}
        </button>
        {onDone && (
          <button type="button" onClick={onDone} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
            Abbrechen
          </button>
        )}
      </div>
      <p className="text-xs text-emerald-900/60">
        Gespeichert wird mit deinem Zugang und der Uhrzeit. Änderungen werden als neue Fassung abgelegt; nur dein Team sieht Beobachtungen.
      </p>
    </form>
  );
}

function Timeline({ events }: { events: VisitEvent[] }) {
  return (
    <details className="mt-2 rounded-xl border border-stone-200 p-2 text-sm">
      <summary className="min-h-11 cursor-pointer content-center px-1 font-semibold text-emerald-900">
        Zeiten ansehen und korrigieren
      </summary>
      <ol className="mt-1 grid gap-2" aria-label="Zeitverlauf">
        {events.map((event, index) => (
          <li key={event.id ?? index}>
            <TimelineEntry event={event} />
          </li>
        ))}
      </ol>
      <p className="mt-2 text-xs text-emerald-900/60">
        Korrekturen werden mit Begründung gespeichert; die ursprünglich erfasste Zeit bleibt sichtbar.
      </p>
    </details>
  );
}

function TimelineEntry({ event }: { event: VisitEvent }) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const label = EVENT_LABEL[event.type] ?? event.type;

  async function save(form: FormData) {
    if (!event.id) return;
    const time = String(form.get("time") ?? "");
    const reason = String(form.get("reason") ?? "");
    const correctedAt = zurichLocalToIso(zurichDate(event.recorded_at ?? event.at), time);
    if (!correctedAt) {
      setError("Bitte eine gültige Uhrzeit angeben.");
      return;
    }
    setPending(true);
    setError(null);
    const result = await correctVisitTime({
      eventId: event.id,
      correctedAt,
      reason,
      idempotencyKey: crypto.randomUUID(),
    });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setEditing(false);
    router.refresh();
  }

  return (
    <div className="rounded-lg bg-stone-50 p-2" aria-label={`${label} ${zurichTime(event.at)}`}>
      <div className="flex items-center justify-between gap-2">
        <p>
          <span className="font-semibold">{label}</span>{" "}
          <span className="tabular-nums">{zurichTime(event.at)}</span>
          {event.corrected && event.recorded_at && (
            <span className="block text-xs text-amber-800">
              korrigiert · erfasst {zurichTime(event.recorded_at)}
              {event.reason ? ` · ${event.reason}` : ""}
            </span>
          )}
        </p>
        {!editing && event.id && (
          <button
            type="button"
            onClick={() => setEditing(true)}
            className="min-h-11 shrink-0 rounded-lg px-3 font-semibold text-emerald-900 underline underline-offset-4"
          >
            Korrigieren
          </button>
        )}
      </div>
      {editing && (
        <form action={save} className="mt-2 grid gap-2">
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Richtige Uhrzeit</span>
            <input
              name="time"
              type="time"
              required
              defaultValue={zurichTime(event.at)}
              className="min-h-11 rounded-lg border border-stone-300 bg-white px-3"
            />
          </label>
          <label className="grid gap-1">
            <span className="text-xs font-semibold">Begründung</span>
            <textarea
              name="reason"
              required
              minLength={5}
              maxLength={500}
              rows={2}
              className="rounded-lg border border-stone-300 bg-white p-2"
            />
          </label>
          {error && (
            <p role="alert" data-testid="command-error" className="rounded-lg border border-rose-300 bg-rose-50 p-2 font-semibold text-rose-800">
              {error}
            </p>
          )}
          <div className="grid grid-cols-2 gap-2">
            <button type="submit" disabled={pending} className="min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60">
              {pending ? "Wird gespeichert …" : "Korrektur speichern"}
            </button>
            <button type="button" onClick={() => { setEditing(false); setError(null); }} className="min-h-11 rounded-lg border border-stone-300 font-semibold">
              Abbrechen
            </button>
          </div>
        </form>
      )}
    </div>
  );
}

function TimeCell({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="font-bold tabular-nums">{value}</p>
      <p className="text-xs text-emerald-900/60">{label}</p>
    </div>
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
