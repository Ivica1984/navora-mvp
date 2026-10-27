"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { completeVisit, departVisit, pauseVisit, resumeVisit, startVisit } from "@/features/visits/commands";
import { getVisitStatusLabel } from "@/features/visits/types";
import {
  FIELD_ACTION_LABEL,
  fieldActions,
  formatDayLabel,
  formatTime,
  orderFieldVisits,
  summarizeDay,
  type FieldAction,
} from "@/features/field/rules";
import { HeaderMenu } from "@/components/layout/Sidebar";
import {
  EVENT_LABEL,
  computeVisitTimes,
  formatMinutes,
  hasEventAt,
  parseEvents,
  zurichDate,
  zurichLocalToIso,
  zurichTime,
  type VisitEvent,
} from "@/features/field/time";
import { correctVisitTime, recordObservation } from "@/features/field/commands";
import { formatMinutesByCategory } from "@/features/team/rules";
import type { FieldNote, FieldVisit } from "@/features/field/types";
import { FACTS_LOCKED_HINT, RETURNED_LOCKED_HINT, countersignItemNote, visitFactsLocked, type FieldReport } from "@/features/field/report";
import ReportSection from "./report-section";
import { openReportsText } from "@/features/admin/rules";
import { REASON_LABEL as LIFECYCLE_REASON_LABEL, doorNoteText } from "@/features/lifecycle/rules";
import { ACCESS_CATEGORY } from "@/features/door/rules";
import { createReportDraft } from "@/features/field/report-commands";
import type { CountersignItem, DoorNote, ReturnedItem, SafetyAlert, SafetyAlertHistoryEntry, TeamOpenReport } from "@/features/field/queries";
import { AccessRow, SafetyAlertRow } from "@/components/door/SafetyAlertForm";
import type { CoverOffer, MyCover } from "@/features/cover/queries";
import CoverSection from "./cover-section";
import { AbsenceControl, AbsenceList, OpenVisitsSection } from "./absence-section";
import type { OpenVisit, TeamAbsence, TeamColleague } from "@/features/absence/queries";
import SinceLastSection from "./since-last-section";
import { groupSinceLast, type SinceLast } from "@/features/handover/rules";
import type { SinceLastRowDb } from "@/features/field/queries";
import QualitySection from "./quality-section";
import VisitLifecycle from "./visit-lifecycle";
import InterruptionFollowupForm from "@/components/lifecycle/InterruptionFollowupForm";
import type { VisitStatusNote } from "@/features/lifecycle/queries";
import type { FieldQuality, QualityEventType } from "@/features/quality/queries";
import type { TeamVisitAlert } from "@/features/team/queries";
import SignalBanner from "@/components/signals/SignalBanner";
import type { SignalRow } from "@/features/signals/rules";

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
  countersign: CountersignItem[];
  /** F6R-5: her reports a registered nurse returned, any date, until she signs again. */
  returned?: ReturnedItem[];
  cover: { offers: CoverOffer[]; mine: MyCover[] };
  sinceLast: SinceLastRowDb[];
  /** DOOR1-1 (migration 0072): access and language notes per visit. */
  doorNotes?: DoorNote[];
  /** DOOR1-3/-4 (migration 0073): latest safety-alert value per active category and visit. */
  safetyAlerts?: SafetyAlert[];
  /** DOOR1-13 (migration 0080): the access arrangement's history, the intake note as its earliest entry. */
  alertHistory?: SafetyAlertHistoryEntry[];
  /** CSR1 / CGR-25: visits of her teams ended as not completed that still wait for a follow-up decision. */
  openFollowups?: TeamVisitAlert[];
  /** ABS1: absences of her teams, "Offen im Team", and the members she can record an absence for. */
  absence?: { today: string; absences: TeamAbsence[]; open: OpenVisit[]; colleagues: TeamColleague[] };
  /** SIG1: her open P1 safety signals at the top, refreshed without a reload. */
  signals?: SignalRow[];
  /** LEAVE1-12 (1): registered nurses only: team members with open reports (counts by kind, access-end date). */
  teamOpenReports?: TeamOpenReport[];
  /** WORK1-C4 (b): opened from /work to correct a visit time: the instant of one of the visit's events. */
  focusAt?: string | null;
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
  interrupted: "bg-amber-100 text-amber-900",
};

export default function FieldClient({ day, isToday, previousDay, nextDay, visits, notes, reports, quality, qualityTypes, statusNotes, countersign, returned = [], cover, sinceLast, openFollowups = [], absence, signals = [], doorNotes = [], safetyAlerts = [], alertHistory = [], teamOpenReports = [], focusAt = null }: Props) {
  const summary = summarizeDay(visits);
  const ordered = orderFieldVisits(visits);
  const sinceLastByVisit = groupSinceLast(sinceLast);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="sticky top-0 z-10 bg-emerald-950 px-4 pb-4 pt-3 text-white shadow-md">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-x-2 gap-y-1">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">NAVORA · Mein Tag</p>
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold text-emerald-100 underline underline-offset-4">
            Teamanfragen
          </Link>
          {/* UX1-20: the role's menu with "Meine Einstellungen" (SIG2 push opt-in) and, last, "Abmelden" (UXR-11). */}
          <HeaderMenu active="field" />
        </div>
        <div className="mx-auto mt-1 max-w-xl">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-xl font-bold leading-tight">{isToday ? "Heute" : formatDayLabel(day)}</h1>
              {isToday && <p className="text-sm text-emerald-100">{formatDayLabel(day)}</p>}
            </div>
            {/* UX1-6a / ABS1: "Ich kann nicht arbeiten" stays in the first viewport, two taps from the top. */}
            {absence && <AbsenceControl today={absence.today} colleagues={absence.colleagues} />}
          </div>
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
        {/* UX1-6 order (ADR-104): (1) SIG1 safety signals, unchanged and above everything; (2) her next visit; (3) her
            other visits; then open decisions and reports; (4) "Offen im Team", collapsed; (5) workday link and counters. */}
        <SignalBanner initial={signals} />
        {(openFollowups.length > 0 || returned.length > 0 || countersign.length > 0) && (
          // UX1-6 (ADR-104): the open decisions and reports sit below her visits; one line at the top keeps them in sight.
          <nav aria-label="Zu erledigen" data-testid="todo-links" className="mb-4 flex flex-wrap gap-2 text-sm font-semibold">
            {openFollowups.length > 0 && (
              <a href="#entscheid-offen" className="flex min-h-11 items-center rounded-lg border border-amber-600 bg-white px-3 text-amber-900">Entscheid offen ({openFollowups.length})</a>
            )}
            {returned.length > 0 && (
              <a href="#zurueckgegeben" className="flex min-h-11 items-center rounded-lg border border-amber-500 bg-white px-3 text-amber-900">Zurückgegeben ({returned.length})</a>
            )}
            {countersign.length > 0 && (
              <a href="#gegenzeichnung" className="flex min-h-11 items-center rounded-lg border border-blue-600 bg-white px-3 text-blue-900">Zur Gegenzeichnung ({countersign.length})</a>
            )}
          </nav>
        )}
        {visits.length === 0 ? (
          <p className="mb-4 rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center text-emerald-900/70">
            Keine Einsätze deiner Teams an diesem Tag.
          </p>
        ) : (
          // UX1-6: (2) her next visit, (3) her other visits of the day; one list, so the day keeps one "Einsätze" region.
          <ol className="mb-4 grid gap-3" aria-label="Einsätze">
            {[...(ordered.next ? [ordered.next] : []), ...ordered.rest].map((visit) => (
              <li key={visit.visit_id} data-testid={visit === ordered.next ? "next-visit" : undefined}>
                {visit === ordered.next && (
                  <p data-testid="next-visit-label" className="mb-1 text-xs font-bold uppercase tracking-wide text-emerald-900">
                    {isToday ? "Als Nächstes" : "Erster offener Einsatz"}
                  </p>
                )}
                {visit === ordered.rest[0] && ordered.next && (
                  <p className="mb-1 mt-2 text-xs font-bold uppercase tracking-wide text-emerald-900">Weitere Einsätze</p>
                )}
                <VisitCard
                  visit={visit}
                  notes={notes.filter((n) => n.visit_id === visit.visit_id)}
                  report={reports.find((r) => r.visit_id === visit.visit_id) ?? null}
                  quality={quality.filter((q) => q.visit_id === visit.visit_id)}
                  qualityTypes={qualityTypes}
                  statusNotes={statusNotes.filter((n) => n.visit_id === visit.visit_id)}
                  sinceLast={sinceLastByVisit.get(visit.visit_id)}
                  door={doorNotes.find((d) => d.visit_id === visit.visit_id)}
                  alerts={safetyAlerts.filter((a) => a.visit_id === visit.visit_id)}
                  history={alertHistory.filter((h) => h.case_id === visit.case_id)}
                  focusAt={focusAt}
                />
              </li>
            ))}
          </ol>
        )}
        {openFollowups.length > 0 && (
          // CSR1 / CGR-25: an interrupted visit keeps a signal until a person decides about the care still due.
          <section aria-label="Nicht abgeschlossen: Entscheid offen" id="entscheid-offen" data-testid="followup-queue" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-amber-600 bg-amber-50 p-3 text-sm">
            <h2 className="font-bold text-amber-900">Nicht abgeschlossen: Entscheid offen ({openFollowups.length})</h2>
            <ul className="mt-1 grid gap-2">
              {openFollowups.map((a) => (
                <li key={a.exception_key} data-testid="followup-item" className="grid gap-1 rounded-xl bg-white p-2">
                  <p>{a.client_name ?? "Klient:in"} · {a.detail} · {a.team_name}</p>
                  <InterruptionFollowupForm visitId={a.visit_id} />
                </li>
              ))}
            </ul>
          </section>
        )}
        {returned.length > 0 && (
          // F6R-5: a returned report is never stranded: it stays on her day until she signs again (UX1-6: below her visits,
          // linked from the "Zu erledigen" line at the top).
          <section aria-label="Zurückgegeben" id="zurueckgegeben" data-testid="returned-reports" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-amber-500 bg-amber-50 p-3 text-sm">
            <h2 className="font-bold text-amber-900">Zurückgegeben: bitte korrigieren und neu unterschreiben ({returned.length})</h2>
            <ul className="mt-1 grid gap-2">
              {returned.map((r) => (
                <li key={r.report_id}>
                  <Link href={`/field?datum=${r.visit_date}`} className="underline underline-offset-2">
                    {formatDayLabel(r.visit_date)} · {formatTime(r.time_start) ?? "Zeit offen"} · {r.client_name ?? "Klient:in"} · {r.team_name}
                  </Link>
                  <p className="whitespace-pre-wrap text-xs text-amber-900/80">
                    {r.returned_by_name ? `${r.returned_by_name}: ` : ""}{r.reason}
                  </p>
                </li>
              ))}
            </ul>
          </section>
        )}
        {countersign.length > 0 && (
          // F7: the countersignature request reaches the team at the moment of signing.
          <section aria-label="Zur Gegenzeichnung" id="gegenzeichnung" data-testid="countersign-queue" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-blue-600 bg-blue-50 p-3 text-sm">
            <h2 className="font-bold text-blue-900">Zur Gegenzeichnung ({countersign.length})</h2>
            <ul className="mt-1 grid gap-1">
              {countersign.map((c) => {
                // F6R-5: returned to its performer; LEAVE1-5 / LEAVE1-11 (migration 0075): the open work of a
                // member whose access ended, with "Zugang beendet" (date only, never a reason).
                const note = countersignItemNote(c);
                return (
                  <li key={`${c.visit_id}:${c.report_id ?? "none"}:${c.kind}`} data-testid="countersign-item">
                    <Link href={`/field?datum=${c.visit_date}`} className="underline underline-offset-2">
                      {formatDayLabel(c.visit_date)} · {formatTime(c.time_start) ?? "Zeit offen"} · {c.client_name ?? "Klient:in"} · {c.team_name}
                    </Link>
                    {note && <span className="text-xs font-semibold text-amber-800">{" "}· {note}</span>}
                  </li>
                );
              })}
            </ul>
          </section>
        )}
        {absence && <OpenVisitsSection open={absence.open} today={absence.today} />}

        <CoverSection offers={cover.offers} mine={cover.mine} />
        {teamOpenReports.length > 0 && (
          // LEAVE1-12 (1): open reports of team members, visible before (and after) an access end. Counts only.
          <section aria-label="Offene Berichte im Team" data-testid="team-open-reports" className="mb-4 rounded-2xl border-l-4 border-stone-500 bg-white p-3 text-sm">
            <h2 className="font-bold">Offene Berichte im Team</h2>
            <ul className="mt-1 grid gap-1">
              {teamOpenReports.map((m) => (
                <li key={`${m.user_id}:${m.team_name}`}>
                  {m.member_name ?? "Teammitglied"} · {m.team_name} · {openReportsText({ unsigned: m.unsigned, correction_draft: m.correction_draft, returned: m.returned })}
                  {m.access_ended_on && <span className="text-xs font-semibold text-amber-800"> · Zugang beendet</span>}
                </li>
              ))}
            </ul>
          </section>
        )}
        {absence && <AbsenceList today={absence.today} absences={absence.absences} />}

        {/* WORK1: her own working day for this date (only she reads it). In the page, not the header: phone width. */}
        <Link href={`/work?datum=${day}`} className="mb-2 flex min-h-11 items-center justify-center rounded-lg border border-emerald-800 bg-white px-3 text-sm font-semibold text-emerald-900">
          Arbeitstag ansehen und bestätigen
        </Link>
        <section className="mb-4 grid grid-cols-3 gap-2 text-center" aria-label="Tagesübersicht">
          <Stat label="Offen" value={summary.open} />
          <Stat label="Laufend" value={summary.running} />
          <Stat label="Erledigt" value={summary.done} />
        </section>
        <p className="mt-6 text-xs leading-relaxed text-emerald-900/60">
          Du siehst die Einsätze deiner Teams. Zeiten entstehen aus deinen Statuswechseln und lassen sich mit Begründung korrigieren. Beobachtungen sieht nur dein Team; Vor jedem Einsatz siehst du, was seit deinem letzten Einsatz bei dieser Person erfasst wurde. Nach dem Einsatz entsteht der Bericht aus diesen Angaben; die ausführende Person unterschreibt ihn.
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
  sinceLast,
  door,
  alerts,
  history,
  focusAt = null,
}: {
  focusAt?: string | null;
  visit: FieldVisit;
  notes: FieldNote[];
  report: FieldReport | null;
  quality: FieldQuality[];
  qualityTypes: QualityEventType[];
  statusNotes: VisitStatusNote[];
  sinceLast: SinceLast | undefined;
  door: DoorNote | undefined;
  alerts: SafetyAlert[];
  history: SafetyAlertHistoryEntry[];
}) {
  const router = useRouter();
  const [pending, setPending] = useState<FieldAction | null>(null);
  const [error, setError] = useState<string | null>(null);
  // UX1-8: the card's "Mehr" menu (first tap) and the action chosen in it (second tap opens its form with the consequence).
  const [moreOpen, setMoreOpen] = useState(false);
  const [moreAction, setMoreAction] = useState<"cancel" | "hold" | null>(null);
  const canCancel = visit.status === "planned" || visit.status === "on_the_way";
  const canHold = !quality.some((q) => q.kind === "hold" && q.status === "open");
  const moreItems = [canCancel && "cancel", canHold && "hold"].filter(Boolean) as ("cancel" | "hold")[];

  // C1: a visit suspended by a case pause cannot be started; no buttons, a clear marker instead.
  const actions = visit.suspended ? [] : fieldActions(visit.status);
  const start = formatTime(visit.time_start);
  const end = formatTime(visit.time_end);
  const time = start ? (end ? `${start} – ${end}` : `ab ${start}`) : "Zeit offen";
  const place = [visit.address, [visit.plz, visit.ort].filter(Boolean).join(" ")].filter(Boolean).join(", ");
  const services = visit.services_provided?.length ? visit.services_provided.join(", ") : null;
  const needs = visit.care_needs?.length ? visit.care_needs.join(", ") : null;
  const events = parseEvents(visit.events);
  const times = events.length > 0 ? computeVisitTimes(events) : null;
  // WORK1-C4 (b): /work links here with the instant of one of this visit's events; its time line opens.
  const focused = hasEventAt(events, focusAt);
  // CSR1 / CGR-03: signed means fixed; changes only through a report correction version.
  const locked = visitFactsLocked(report);
  // F6R-3: a returned report is open for its performer only; everyone else sees why the facts are fixed.
  const lockedHint = report?.status === "draft" && report.returned ? RETURNED_LOCKED_HINT : FACTS_LOCKED_HINT;

  async function run(action: FieldAction) {
    setPending(action);
    setError(null);
    // One idempotency key per tap: a retried request is applied at most once (T10).
    const result = await COMMANDS[action]({ visitId: visit.visit_id, idempotencyKey: crypto.randomUUID() });
    // F7: completing opens the report draft at once (built from the visit data). If the database refuses
    // the draft (e.g. no recorded start), the F6 "create" step stays available on the card.
    let draftError: string | null = null;
    if (result.ok && action === "complete") {
      const draft = await createReportDraft({ visitId: visit.visit_id, summary: null, idempotencyKey: crypto.randomUUID() });
      if (!draft.ok) draftError = `Einsatz abgeschlossen, aber der Bericht konnte nicht automatisch entstehen: ${draft.error}`;
    }
    setPending(null);
    if (!result.ok) setError(result.error);
    else if (draftError) setError(draftError);
    router.refresh();
  }

  return (
    <article
      id={focused ? "einsatz-korrektur" : undefined}
      aria-label={`Einsatz ${time}, ${visit.client_name ?? "Klient:in"}`}
      className="scroll-mt-4 rounded-2xl bg-white p-4 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-lg font-bold tabular-nums">{time}</p>
          <h2 className="text-base font-semibold">{visit.client_name ?? "Klient:in ohne Namen"}</h2>
        </div>
        <span data-testid="visit-status" className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${visit.suspended ? "bg-amber-100 text-amber-900" : STATUS_CLASS[visit.status ?? ""] ?? "bg-stone-200 text-stone-800"}`}>
          {visit.suspended ? `pausiert${visit.pause_reason ? ` · ${LIFECYCLE_REASON_LABEL[visit.pause_reason] ?? ""}` : ""}` : getVisitStatusLabel(visit.status)}
        </span>
      </div>

      <dl className="mt-3 grid gap-1 text-sm">
        <Row label="Ort" value={place || "Adresse fehlt – im Team klären"} muted={!place} />
        {/* DOOR1-1 (migration 0072): what the nurse needs at the door, recorded at intake; never blank. The access line
            is the one "Zugang" row below (DOOR1-13, 0080). */}
        {visit.case_id && (
          <Row label="Sprache" value={doorNoteText(door?.language_notes)} muted={!door?.language_notes} testId="door-language" />
        )}
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

      {/* DOOR1-4 (migration 0073): safety-alert values, "nicht erfasst" when none; display only (DOOR1-8). DOOR1-13 (0080):
          the access arrangement and the intake note are one "Zugang" line. */}
      {visit.case_id && (
        <section aria-label="Sicherheitshinweise" data-testid="safety-alerts" className="mt-3 grid gap-2">
          <AccessRow
            caseId={visit.case_id}
            category={(() => {
              const a = alerts.find((x) => x.category_code === ACCESS_CATEGORY);
              return a ? { code: a.category_code, label: a.category_label, help_text: a.help_text, refuses_codes: a.refuses_codes } : null;
            })()}
            current={alerts.find((x) => x.category_code === ACCESS_CATEGORY && x.value) ?? null}
            intakeNote={door?.access_notes ?? null}
            intakeOn={door?.intake_on ?? null}
            history={history}
          />
          {alerts.filter((a) => a.category_code !== ACCESS_CATEGORY).map((a) => (
            <SafetyAlertRow
              key={a.category_code}
              caseId={visit.case_id as string}
              category={{ code: a.category_code, label: a.category_label, help_text: a.help_text, refuses_codes: a.refuses_codes }}
              current={a.value ? a : null}
            />
          ))}
        </section>
      )}

      <SinceLastSection block={sinceLast} visitStatus={visit.status} />

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

      {events.length > 0 && <Timeline events={events} locked={locked} lockedHint={lockedHint} open={focused} />}

      <Observations
        visitId={visit.visit_id}
        canRecord={OBSERVABLE.has(visit.status ?? "")}
        locked={locked}
        lockedHint={lockedHint}
        notes={notes.filter((n) => n.kind === "observation")}
      />

      <ReportSection visitId={visit.visit_id} visitStatus={visit.status} report={report} />

      <QualitySection
        visitId={visit.visit_id} items={quality} types={qualityTypes}
        holdRequested={moreAction === "hold"} onHoldClosed={() => setMoreAction(null)}
      />

      <VisitLifecycle
        visitId={visit.visit_id} status={visit.status} notes={statusNotes}
        cancelRequested={moreAction === "cancel"} onCancelClosed={() => setMoreAction(null)}
      />

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

      {/* UX1-8 (ADR-104): actions with billing or planning consequences need two taps: "Mehr", then the action, whose
          form states the consequence in one sentence before the existing command runs. Commands, audit and refusals are
          unchanged; who may run them is decided by the database as before. */}
      {moreItems.length > 0 && (
        <div className="mt-3 grid gap-2 text-sm">
          <button
            type="button"
            aria-expanded={moreOpen}
            aria-controls={`mehr-${visit.visit_id}`}
            data-testid="visit-more"
            onClick={() => setMoreOpen((x) => !x)}
            className="min-h-11 justify-self-end rounded-lg border border-stone-400 bg-white px-4 font-semibold"
          >
            Mehr
          </button>
          {moreOpen && (
            <div id={`mehr-${visit.visit_id}`} role="group" aria-label="Weitere Aktionen" className="grid gap-2 rounded-xl border border-stone-200 p-2">
              {moreItems.includes("cancel") && (
                <button type="button" onClick={() => { setMoreAction("cancel"); setMoreOpen(false); }}
                  className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-left font-semibold">
                  Einsatz absagen
                </button>
              )}
              {moreItems.includes("hold") && (
                <button type="button" onClick={() => { setMoreAction("hold"); setMoreOpen(false); }}
                  className="min-h-11 rounded-lg border border-rose-400 bg-white px-3 text-left font-semibold text-rose-900">
                  Abrechnungssperre setzen
                </button>
              )}
            </div>
          )}
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

function Observations({
  visitId,
  canRecord,
  locked,
  lockedHint = FACTS_LOCKED_HINT,
  notes,
}: {
  visitId: string;
  canRecord: boolean;
  locked: boolean;
  lockedHint?: string;
  notes: FieldNote[];
}) {
  if (!canRecord && notes.length === 0) return null;
  return (
    <section aria-label="Beobachtungen" className="mt-3 grid gap-2 text-sm">
      <h3 className="font-bold">Beobachtungen</h3>
      {notes.length > 0 && (
        <ul className="grid gap-2">
          {notes.map((note) => (
            <li key={note.id}>
              <ObservationEntry visitId={visitId} note={note} locked={locked} />
            </li>
          ))}
        </ul>
      )}
      {canRecord && !locked && <ObservationForm visitId={visitId} supersedesId={null} />}
      {canRecord && locked && (
        <p data-testid="facts-locked" className="text-xs text-emerald-900/70">
          {lockedHint}
        </p>
      )}
    </section>
  );
}

function ObservationEntry({ visitId, note, locked }: { visitId: string; note: FieldNote; locked: boolean }) {
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
        {/* CGR-01: only the author changes her observation; a colleague adds her own. */}
        {note.own && !locked && (
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
        {/* UX1-7: the always-open "Neue Beobachtung" form is an outline button, so the card keeps one filled button (its
            status action); the opened "Beobachtung ändern" form keeps its filled submit. */}
        <button type="submit" disabled={pending} className={onDone
          ? "min-h-11 rounded-lg bg-emerald-800 font-bold text-white disabled:opacity-60"
          : "min-h-11 rounded-lg border-2 border-emerald-800 bg-white font-bold text-emerald-900 disabled:opacity-60"}>
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

function Timeline({ events, locked, lockedHint = FACTS_LOCKED_HINT, open = false }: { events: VisitEvent[]; locked: boolean; lockedHint?: string; open?: boolean }) {
  return (
    <details open={open || undefined} className="mt-2 rounded-xl border border-stone-200 p-2 text-sm">
      <summary className="min-h-11 cursor-pointer content-center px-1 font-semibold text-emerald-900">
        {locked ? "Zeiten ansehen" : "Zeiten ansehen und korrigieren"}
      </summary>
      <ol className="mt-1 grid gap-2" aria-label="Zeitverlauf">
        {events.map((event, index) => (
          <li key={event.id ?? index}>
            <TimelineEntry event={event} locked={locked} />
          </li>
        ))}
      </ol>
      <p className="mt-2 text-xs text-emerald-900/60">
        {locked ? lockedHint : "Korrekturen werden mit Begründung gespeichert; die ursprünglich erfasste Zeit bleibt sichtbar."}
      </p>
    </details>
  );
}

function TimelineEntry({ event, locked }: { event: VisitEvent; locked: boolean }) {
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
        {!editing && !locked && event.id && (
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

function Row({ label, value, muted = false, testId }: { label: string; value: string; muted?: boolean; testId?: string }) {
  return (
    <div className="grid grid-cols-[7.5rem_1fr] gap-2">
      <dt className="text-emerald-900/60">{label}</dt>
      <dd data-testid={testId} className={muted ? "text-emerald-900/50 italic" : ""}>{value}</dd>
    </div>
  );
}
