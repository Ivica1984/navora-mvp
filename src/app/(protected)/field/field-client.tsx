"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { completeVisit, departVisit, pauseVisit, resumeVisit, startVisit } from "@/features/visits/commands";
import { moveVisitToToday } from "@/features/team/commands";
import { getMoveLeavesFact } from "@/features/field/commands";
import OverlapNote, { useOverlapNote } from "@/components/visits/OverlapNote";
import { cardAccessibleName, overlapAfterSave, overlapNote, overlapParam, sameSlotInfo, sameSlotPositions, type OverlapFact } from "@/features/visits/overlap-rules";
import { PLAN_FLAG_LABEL } from "@/features/team/rules";
import { getVisitStatusLabel } from "@/features/visits/types";
import {
  FIELD_ACTION_LABEL,
  MOVE_TO_TODAY_CONFIRM,
  MOVE_TO_TODAY_HINT,
  MOVE_TO_TODAY_LABEL,
  MOVED_TO_TODAY_STATUS,
  RELEASED_ON_MOVE,
  type MovedNotice,
  canMoveToToday,
  DAY_CHANGED_RELOAD,
  afterDayChanged,
  dayChangedNote,
  moveLeavesNote,
  movedNoticeHref,
  withoutMovedNotice,
  MOVED_RELEASED_NOTICE_ID,
  prefillMoveTimes,
  zurichMinutesNow,
  fieldActionsOn,
  formatDayLabel,
  formatShortDate,
  futureDayNote,
  isAfterToday,
  todayInZurich,
  formatTime,
  orderFieldVisits,
  summarizeDay,
  type FieldAction,
} from "@/features/field/rules";
import { HeaderMenu } from "@/components/layout/Sidebar";
import { PAGE_LABEL } from "@/lib/auth/nav";
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
import { QUALIFICATION_NOT_RECORDED_TEXT, observationAuthor, showsQualificationMarker } from "@/features/field/authorship";
import { actionsForMember } from "@/features/field/qualification";
import { QUALIFICATION_MISSING_MESSAGE } from "@/lib/commands/result";
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
import { COUNTERSIGN_HEADING, FOLLOWUP_HEADING, RETURNED_HEADING, countersignLabel, followupLabel, returnedInstructionLine, returnedLabel } from "@/features/field/todo";

type Props = {
  day: string;
  isToday: boolean;
  /** Today in Europe/Zurich (DAY-1); VIS1: a day after it shows no field action. */
  today?: string;
  /** VIS1-3d / VIS1-3e: the result of a "Heute machen" move, shown once above the moved card. */
  moved?: MovedNotice | null;
  /** VIS2-5 (2): the overlap the server found at that move and the confirmation did not show (display only). */
  movedOverlap?: OverlapFact;
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
  /** UX2-22 (ADR-124): teams in which her own qualification is not yet recorded (ADM2-6); her own rows only. */
  unqualifiedTeams?: string[];
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
  // UX1-23 (UXR-16): a visit status is a label, not a safety signal, so never the P1 colour.
  cancelled: "bg-stone-200 text-stone-800",
  no_show: "bg-stone-200 text-stone-800",
  interrupted: "bg-amber-100 text-amber-900",
};

export default function FieldClient({ day, isToday, today: todayProp, previousDay, nextDay, visits, notes, reports, quality, qualityTypes, statusNotes, countersign, returned = [], cover, sinceLast, openFollowups = [], absence, signals = [], doorNotes = [], safetyAlerts = [], alertHistory = [], teamOpenReports = [], focusAt = null, moved = null, movedOverlap = null, unqualifiedTeams = [] }: Props) {
  const summary = summarizeDay(visits);
  const ordered = orderFieldVisits(visits);
  // VIS2-3: cards of the same client whose times overlap get a distinguishing line and accessible name.
  const sameSlot = sameSlotPositions(visits);
  const sinceLastByVisit = groupSinceLast(sinceLast);
  // VIS1 (ADR-111): the page passes today (Europe/Zurich); without it the view is today's.
  const today = todayProp ?? (isToday ? day : todayInZurich());
  const futureDay = isAfterToday(day, today);
  // VIS1-3d / VIS1-3e (ADR-112): the visit just moved to today, if any.
  const movedId = moved?.visitId ?? null;
  const movedOverlapText = moved ? overlapNote(day, movedOverlap ?? null, today) : null;
  // VIS1-3g (UXR-35): shown once. The notice stays on this render; the address loses the move's parameters at once,
  // so a reload or the refresh after the next action (e.g. "Einsatz starten") no longer shows it. The `moved` row and
  // /team stay the lasting record.
  useEffect(() => {
    if (!movedId) return;
    const { pathname, search, hash } = window.location;
    const rest = withoutMovedNotice(search);
    if (rest !== search) window.history.replaceState(null, "", `${pathname}${rest}${hash}`);
  }, [movedId]);

  return (
    <div className="min-h-screen bg-stone-100 text-emerald-950">
      <header className="sticky top-0 z-10 bg-emerald-950 px-4 pb-4 pt-3 text-white shadow-md">
        <div className="mx-auto flex max-w-xl flex-wrap items-center justify-between gap-x-2 gap-y-1">
          <p className="text-xs font-semibold uppercase tracking-widest text-emerald-200">{PAGE_LABEL.field}</p>
          <Link href="/team" className="ml-auto flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold text-emerald-100 underline underline-offset-4">
            {PAGE_LABEL.team}
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
        {unqualifiedTeams.length > 0 && (
          // UX2-22 (uxa UXR-45, cra 13:40: hide; ADR-124): once, at the top under the safety signals, in `info`; the
          // ADM2-16 refusal sentence unchanged. Her cards then offer no depart, start, resume or completion control.
          <p data-testid="qualification-missing-note" data-tone="info" className="mb-4 rounded-xl border border-stone-300 bg-stone-50 p-3 text-sm text-stone-700">
            {QUALIFICATION_MISSING_MESSAGE}
          </p>
        )}
        {/* VIS1-3 / VIS1-3a (UXR-29): once per future day, under the day heading, `info` (a planned day is the normal
            state, not a warning); the cards then show no field action, only the move of VIS1-3b. */}
        {futureDay && visits.length > 0 && (
          <p data-testid="future-day-note" data-tone="info" className="mb-4 rounded-xl border border-stone-300 bg-stone-50 p-3 text-sm text-stone-700">
            {futureDayNote(day, visits.length)}
          </p>
        )}
        {/* VIS1-3d / VIS1-3e: when the moved visit is not among her cards of this day, the notice stands above the list. */}
        {moved && !visits.some((v) => v.visit_id === movedId) && <MovedNoticeBlock moved={moved} overlapText={movedOverlapText} />}
        {(openFollowups.length > 0 || returned.length > 0 || countersign.length > 0) && (
          // UX1-6 (ADR-104): the open decisions and reports sit below her visits; one line at the top keeps them in sight.
          // UX1-27 (CGR-80, ADR-106): inside the first viewport, above the next visit; the follow-up link carries the
          // section's own heading.
          <nav aria-label="Zu erledigen" data-testid="todo-links" className="mb-4 flex flex-wrap gap-2 text-sm font-semibold">
            {openFollowups.length > 0 && (
              <a href="#entscheid-offen" className="flex min-h-11 items-center rounded-lg border border-amber-600 bg-white px-3 text-amber-900">{followupLabel(openFollowups.length)}</a>
            )}
            {returned.length > 0 && (
              <a href="#zurueckgegeben" className="flex min-h-11 items-center rounded-lg border border-amber-500 bg-white px-3 text-amber-900">{returnedLabel(returned.length)}</a>
            )}
            {countersign.length > 0 && (
              <a href="#gegenzeichnung" className="flex min-h-11 items-center rounded-lg border border-blue-600 bg-white px-3 text-blue-900">{countersignLabel(countersign.length)}</a>
            )}
          </nav>
        )}
        {visits.length === 0 ? (
          <p className="mb-4 rounded-2xl border border-dashed border-emerald-900/20 bg-white/70 p-6 text-center text-secondary">
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
                {moved && movedId === visit.visit_id && <MovedNoticeBlock moved={moved} overlapText={movedOverlapText} />}
                <VisitCard
                  visit={visit}
                  today={today}
                  focusOnMount={movedId === visit.visit_id}
                  describedBy={moved?.released && movedId === visit.visit_id ? MOVED_RELEASED_NOTICE_ID : undefined}
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
                  sameSlot={sameSlot.get(visit.visit_id)}
                  unqualifiedTeams={unqualifiedTeams}
                />
              </li>
            ))}
          </ol>
        )}
        {openFollowups.length > 0 && (
          // CSR1 / CGR-25: an interrupted visit keeps a signal until a person decides about the care still due.
          <section aria-label={FOLLOWUP_HEADING} id="entscheid-offen" data-testid="followup-queue" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-amber-600 bg-amber-50 p-3 text-sm">
            <h2 className="font-bold text-amber-900">{followupLabel(openFollowups.length)}</h2>
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
          // UX1-30 (uxa UXR-20, cra 05:30, ADR-107): heading = link text; the instruction is the section's first line,
          // always rendered, after the h2 and before the first item, never collapsed.
          <section aria-label={RETURNED_HEADING} id="zurueckgegeben" data-testid="returned-reports" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-amber-500 bg-amber-50 p-3 text-sm">
            <h2 className="font-bold text-amber-900">{returnedLabel(returned.length)}</h2>
            <p data-testid="returned-instruction" className="mt-1 font-semibold text-amber-900">{returnedInstructionLine()}</p>
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
          <section aria-label={COUNTERSIGN_HEADING} id="gegenzeichnung" data-testid="countersign-queue" className="mb-4 scroll-mt-56 rounded-2xl border-l-4 border-blue-600 bg-blue-50 p-3 text-sm">
            <h2 className="font-bold text-blue-900">{countersignLabel(countersign.length)}</h2>
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
        {absence && <OpenVisitsSection open={absence.open} today={absence.today} unqualifiedTeams={unqualifiedTeams} />}

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
        <p className="mt-6 text-xs leading-relaxed text-secondary">
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
      <p className="text-xs font-semibold uppercase tracking-wide text-secondary">{label}</p>
    </div>
  );
}

function VisitCard({
  visit,
  today,
  focusOnMount = false,
  describedBy,
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
  sameSlot,
  unqualifiedTeams = [],
}: {
  focusAt?: string | null;
  /** UX2-22 (ADR-124): no depart, start, resume or completion control on a visit of a team where hers is missing. */
  unqualifiedTeams?: string[];
  /** VIS2-3: position among this client's cards at an overlapping time, if any. */
  sameSlot?: { index: number; total: number };
  visit: FieldVisit;
  today: string;
  focusOnMount?: boolean;
  /** VIS1-3f (UXR-34): the release notice above the moved card, heard where focus lands (VIS1-3e). */
  describedBy?: string;
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
  // VIS1-3: a visit dated after today shows no field action (the database refuses them, migration 0089).
  const afterToday = isAfterToday(visit.visit_date, today);
  // UX2-22 (ADR-124): no control the database refuses her for a missing qualification (ADM2-16, 0094).
  const actions = visit.suspended ? [] : actionsForMember(fieldActionsOn(visit.status, visit.visit_date, today), visit.team_id, unqualifiedTeams);
  const canMove = canMoveToToday(visit.status, visit.suspended, visit.visit_date, today);
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
  // VIS1-3e (1): after "Heute machen" focus lands on the moved card (once, on mount).
  const articleRef = useRef<HTMLElement>(null);
  useEffect(() => {
    if (focusOnMount) articleRef.current?.focus();
  }, [focusOnMount]);

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
      ref={articleRef}
      tabIndex={focusOnMount ? -1 : undefined}
      data-testid={focusOnMount ? "moved-visit" : undefined}
      aria-describedby={describedBy}
      id={focused ? "einsatz-korrektur" : undefined}
      aria-label={cardAccessibleName(time, visit.client_name ?? "Klient:in", sameSlot)}
      className="scroll-mt-4 rounded-2xl bg-white p-4 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-lg font-bold tabular-nums">{time}</p>
          <h2 className="text-base font-semibold">{visit.client_name ?? "Klient:in ohne Namen"}</h2>
          {sameSlot && (
            // VIS2-3 (ADR-121): tells two cards of one client at one time apart; a fact, `info`, nothing refused.
            <p data-testid="same-slot-line" data-tone="info" className="mt-1 text-sm text-stone-700">
              {sameSlotInfo(sameSlot, visit.responsible_me ? "du" : visit.responsible_set ? "Teammitglied" : "noch niemand")}
            </p>
          )}
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
        visitId={visit.visit_id} status={visit.status} notes={statusNotes} afterToday={afterToday}
        cancelRequested={moreAction === "cancel"} onCancelClosed={() => setMoreAction(null)}
      />

      {error && (
        <p role="alert" data-testid="command-error" className="mt-3 rounded-lg border border-amber-800 bg-amber-50 p-3 text-sm font-semibold text-stone-900">
          {error}
        </p>
      )}

      {canMove && <MoveToToday visit={visit} today={today} />}

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
                  className="min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-left font-semibold">
                  {/* UXR-16: neutral outline (rose is the P1 colour family); the consequence sentence carries the weight. */}
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
        <p data-testid="facts-locked" className="text-xs text-secondary">
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
      {/* OBS1-1/-4: a recorded fact in `info` tone; the observation is never hidden or reordered by it. */}
      {showsQualificationMarker(note.author_qualification_missing) && (
        <p data-testid="observation-qualification-marker" className="mt-1 text-xs text-stone-700">{QUALIFICATION_NOT_RECORDED_TEXT}</p>
      )}
      <div className="mt-1 flex items-center justify-between gap-2">
        <p className="text-xs text-secondary">
          {formatDateTime(note.recorded_at)} · <span data-testid="observation-author">{observationAuthor(note)}</span>
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
        <p role="alert" data-testid="command-error" className="rounded-lg border border-amber-800 bg-amber-50 p-2 font-semibold text-stone-900">
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
      <p className="text-xs text-secondary">
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
      <p className="mt-2 text-xs text-secondary">
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
            <p role="alert" data-testid="command-error" className="rounded-lg border border-amber-800 bg-amber-50 p-2 font-semibold text-stone-900">
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
      <p className="text-xs text-secondary">{label}</p>
    </div>
  );
}

function Row({ label, value, muted = false, testId }: { label: string; value: string; muted?: boolean; testId?: string }) {
  return (
    <div className="grid grid-cols-[7.5rem_1fr] gap-2">
      <dt className="text-secondary">{label}</dt>
      <dd data-testid={testId} className={muted ? "text-secondary italic" : ""}>{value}</dd>
    </div>
  );
}

/**
 * VIS1-3b (po 2026-10-28 20:15 from `aia` AUT-16; ADR-111): "Heute machen" on a card dated after today. One
 * confirmation: today's date (Europe/Zurich), times (editable) and an empty, required reason (J3 rule, 3-300
 * characters). It calls the existing `reschedule_visit` with all its checks (ABS1-C4, ABS1-C5, CGR-35, audit, `moved`
 * row); no new command, no new permission. The move never starts the visit: afterwards she is on today's view, where
 * "Einsatz starten" is its own tap.
 * Follow-up (ADR-112): VIS1-3c prefills the next full 5 minutes after now and the card's duration (empty across
 * midnight); VIS1-8 states whether the client still has a visit on the planned date (server yes/no); VIS1-3e moves
 * focus into the form and back; VIS1-3d hands the release and the planning flags to today's view.
 * VIS1-10 (ADR-116, `cra` CGR-91): the confirm sends the date she was shown; `move_visit_to_today` moves the visit to
 * the database's today only when that is the shown date. After `day_changed` (page left open across midnight) the form
 * stays open: the new date as a fact at its top (focus on it), the times re-derived by VIS1-3c for the new now, the
 * typed reason kept, the VIS1-8 line unchanged; nothing is stored until she confirms again. Where the visit is no
 * longer dated after the new today, the reload sentence instead.
 */
function MoveToToday({ visit, today }: { visit: FieldVisit; today: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [times, setTimes] = useState<{ start: string; end: string }>({ start: "", end: "" });
  // VIS2-1: the slot as she types it (the inputs stay uncontrolled); read by the overlap sentence.
  const [typed, setTyped] = useState<{ start: string; end: string }>({ start: "", end: "" });
  // VIS1-10: the date shown as "Heute" (the render's today until the database names another one), the sentence after
  // `day_changed`, the reload fallback, and a counter that re-mounts the time inputs with the re-derived values.
  const [shownDay, setShownDay] = useState(today);
  const [dayNote, setDayNote] = useState<string | null>(null);
  const [reload, setReload] = useState(false);
  const [timesEpoch, setTimesEpoch] = useState(0);
  const [reasonText, setReasonText] = useState("");
  const dayNoteRef = useRef<HTMLParagraphElement>(null);
  // VIS2-1 / VIS2-5 (1): the overlap for the times in the form, re-read as they change and when the form is offered again.
  const overlap = useOverlapNote(null, visit.visit_id, { date: shownDay, start: typed.start, end: typed.end }, shownDay, open);
  // VIS1-8: undefined while the answer is loading, null when there is none (no sentence then).
  const [leaves, setLeaves] = useState<boolean | null | undefined>(undefined);
  const openRef = useRef<HTMLButtonElement>(null);
  const startRef = useRef<HTMLInputElement>(null);
  const returnFocus = useRef(false);

  // VIS1-3e (1): focus into the form ("Von") on open; back to "Heute machen" after "Abbrechen".
  useEffect(() => {
    if (open) startRef.current?.focus();
    else if (returnFocus.current) {
      returnFocus.current = false;
      openRef.current?.focus();
    }
  }, [open]);

  // VIS1-10: the new date is announced where she is looking (focus on the sentence, tabIndex -1).
  useEffect(() => {
    if (dayNote || reload) dayNoteRef.current?.focus();
  }, [dayNote, reload, timesEpoch]);

  function openForm() {
    // VIS1-3c: computed when she opens the form, from the Zurich wall clock.
    const prefill = prefillMoveTimes(zurichMinutesNow(), visit.time_start, visit.time_end);
    setTimes(prefill);
    setTyped(prefill);
    setLeaves(undefined);
    setError(null);
    setDayNote(null);
    setReload(false);
    setReasonText("");
    setTimesEpoch((n) => n + 1);
    setOpen(true);
    void getMoveLeavesFact(visit.visit_id).then(setLeaves, () => setLeaves(null));
  }

  function cancel() {
    returnFocus.current = true;
    setOpen(false);
    setError(null);
  }

  async function submit(form: FormData) {
    setPending(true);
    setError(null);
    const result = await moveVisitToToday({
      visitId: visit.visit_id,
      // VIS1-10: the date shown as "Heute" in this form; the database moves to its today only if it is this one.
      date: String(form.get("shown") ?? shownDay),
      start: String(form.get("start") ?? ""),
      end: String(form.get("end") ?? ""),
      reason: String(form.get("reason") ?? ""),
      idempotencyKey: crypto.randomUUID(),
      overlapShown: overlap.shown,
    });
    setPending(false);
    if (!result.ok && "dayChanged" in result) {
      const next = afterDayChanged(result.today, result.visitDate);
      if (next.kind === "reload") {
        setDayNote(null);
        setReload(true);
        return;
      }
      // Nothing was stored. The form shows the database's today, times re-derived for the new now, the reason kept.
      setShownDay(next.today);
      const prefill = prefillMoveTimes(zurichMinutesNow(), visit.time_start, visit.time_end);
      setTimes(prefill);
      setTyped(prefill);
      setTimesEpoch((n) => n + 1);
      setDayNote(dayChangedNote(next.today));
      return;
    }
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setOpen(false);
    // VIS1-3d / VIS1-3e: today's view shows "Einsatz auf heute verschoben", the release and the flags above the card.
    // VIS1-3g: no router.refresh() here. The push loads today's dynamic view fresh; a queued refresh would run after
    // the notice's parameters left the address and drop the notice before it was seen.
    // VIS2-5 (2): an overlap the server found that the form did not show travels to the moved card's notice.
    const missed = overlapParam(overlapAfterSave(overlap.shown, result.overlap));
    const href = movedNoticeHref(visit.visit_id, result.released, result.flags);
    router.push(missed ? `${href}&${new URLSearchParams({ ueberschneidung: missed }).toString()}` : href);
  }

  if (!open) {
    return (
      <button
        ref={openRef}
        type="button"
        data-testid="move-to-today"
        onClick={openForm}
        className="mt-4 min-h-11 w-full rounded-xl border border-stone-300 bg-white px-3 text-base font-semibold text-emerald-950"
      >
        {MOVE_TO_TODAY_LABEL}
      </button>
    );
  }

  const leavesNote = leaves === undefined ? null : moveLeavesNote(visit.visit_date, leaves);

  if (reload) {
    // VIS1-10 fallback: the confirmation no longer applies to this visit; nothing was stored.
    return (
      <div className="mt-4 grid gap-2 rounded-xl border border-stone-300 bg-stone-50 p-3 text-sm">
        <p ref={dayNoteRef} tabIndex={-1} role="status" data-testid="move-day-changed" data-tone="info" className="rounded-lg border border-stone-300 bg-white p-2 text-stone-700">
          {DAY_CHANGED_RELOAD}
        </p>
        <Link href="/field" className="flex min-h-11 items-center justify-center rounded-xl border border-stone-300 bg-white px-3 font-semibold text-emerald-950">
          Einsätze von heute
        </Link>
      </div>
    );
  }

  return (
    <form
      action={submit}
      onChange={(e) => {
        const f = new FormData(e.currentTarget);
        setTyped({ start: String(f.get("start") ?? ""), end: String(f.get("end") ?? "") });
      }}
      aria-label="Einsatz auf heute verschieben"
      data-testid="move-to-today-form"
      className="mt-4 grid gap-3 rounded-xl border border-stone-300 bg-stone-50 p-3 text-sm"
    >
      {dayNote && (
        // VIS1-10 (UXR-39): the new date as a fact, at the top of the open form, tone `info`, focus on it.
        <p ref={dayNoteRef} tabIndex={-1} role="status" data-testid="move-day-changed" data-tone="info" className="rounded-lg border border-stone-300 bg-white p-2 font-semibold text-stone-700">
          {dayNote}
        </p>
      )}
      {/* VIS1-10: the date shown as "Heute"; re-mounted with the database's today after `day_changed`. */}
      <input key={`shown-${timesEpoch}`} type="hidden" name="shown" defaultValue={shownDay} />
      <p>
        Heute, <span data-testid="move-to-today-date">{formatShortDate(shownDay)}</span> (geplant war der {formatShortDate(visit.visit_date)}).
      </p>
      {leavesNote && (
        // VIS1-8: a fact from the plan, `info`; no block, no extra tap. Never "kein Einsatz" while another team's visit
        // exists that day (the server counts it without showing it).
        <p data-testid="move-leaves-note" data-tone="info" className="rounded-lg border border-stone-300 bg-white p-2 text-stone-700">
          {leavesNote}
        </p>
      )}
      <div className="grid grid-cols-2 gap-2">
        <label className="grid min-w-0 gap-1 font-semibold">
          Von
          <input key={`start-${timesEpoch}`} ref={startRef} name="start" type="time" required defaultValue={times.start}
            className="min-h-11 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-2 text-base font-normal" />
        </label>
        <label className="grid min-w-0 gap-1 font-semibold">
          Bis
          <input key={`end-${timesEpoch}`} name="end" type="time" required defaultValue={times.end}
            className="min-h-11 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-2 text-base font-normal" />
        </label>
      </div>
      {/* VIS2-1 / VIS2-2 / VIS2-5: below "Von"/"Bis", tied to the confirm button; a fact, `info`, never a block. */}
      <OverlapNote id={`overlap-today-${visit.visit_id}`} note={overlap.note} answered={overlap.answered} />
      <label className="grid gap-1 font-semibold">
        Grund der Verschiebung
        {/* VIS1-10: controlled, so the typed reason survives React's form reset after a refused confirm. */}
        <textarea name="reason" required minLength={3} maxLength={300} rows={2} value={reasonText}
          onChange={(e) => setReasonText(e.target.value)}
          className="w-full min-w-0 rounded-lg border border-stone-300 bg-white p-2 text-base font-normal" />
      </label>
      <p className="text-secondary">{MOVE_TO_TODAY_HINT}</p>
      {error && (
        <p role="alert" data-testid="move-to-today-error" className="rounded-lg border border-amber-800 bg-amber-50 p-3 font-semibold text-stone-900">
          {error}
        </p>
      )}
      <div className="grid grid-cols-[2fr_1fr] gap-2">
        <button type="submit" disabled={pending} aria-describedby={overlap.note ? `overlap-today-${visit.visit_id}` : undefined}
          className="min-h-11 rounded-xl bg-emerald-800 font-bold text-white disabled:opacity-60">
          {pending ? "Wird gespeichert …" : MOVE_TO_TODAY_CONFIRM}
        </button>
        <button type="button" onClick={cancel} className="min-h-11 rounded-xl border border-stone-300 font-semibold">
          Abbrechen
        </button>
      </div>
    </form>
  );
}

/**
 * VIS1-3e (1) and VIS1-3d (ADR-112): above the moved card on today's view, one status line "Einsatz auf heute
 * verschoben"; when the move released the visit (ABS1-C4: the responsible member is absent at the new time), the same
 * fixed text as /team, tone `attention`; returned planning flags as on /team. Position and tone: `cra` in VIS1-7.
 */
function MovedNoticeBlock({ moved, overlapText }: { moved: MovedNotice; overlapText: string | null }) {
  return (
    <div className="mb-2 grid gap-1">
      <p role="status" data-testid="moved-to-today" className="text-sm font-semibold text-emerald-900">
        {MOVED_TO_TODAY_STATUS}
      </p>
      {overlapText && (
        // VIS2-5 (2): the server found an overlap the confirmation did not show; the move went through.
        <p data-testid="overlap-after-save" data-tone="info" className="rounded-lg border border-stone-300 bg-white p-2 text-sm text-stone-700">
          {overlapText}
        </p>
      )}
      {moved.released && (
        <p id={MOVED_RELEASED_NOTICE_ID} role="status" data-testid="moved-released" data-tone="attention" className="rounded-xl border border-amber-800 bg-amber-50 p-3 text-sm font-semibold text-amber-900">
          {RELEASED_ON_MOVE}
        </p>
      )}
      {moved.flags.length > 0 && (
        <ul aria-label="Hinweise" data-testid="moved-flags" className="grid gap-0.5 text-xs font-semibold text-amber-800">
          {moved.flags.map((f) => (
            <li key={f}>⚠ {PLAN_FLAG_LABEL[f] ?? f}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
