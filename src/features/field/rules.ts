// Field tool rules (F1) — pure TypeScript (ADR-002): no React, Next or Supabase imports.

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const ZONE = "Europe/Zurich";

/** Today's calendar date in Switzerland as YYYY-MM-DD (the server may run in UTC). */
export function todayInZurich(now: Date = new Date()): string {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Accepts only a real calendar date in YYYY-MM-DD; anything else falls back to `fallback`. */
export function parseDayParam(value: unknown, fallback: string): string {
  if (typeof value !== "string" || !ISO_DATE.test(value)) return fallback;
  const [y, m, d] = value.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const valid =
    date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
  return valid ? value : fallback;
}

/** Shifts a YYYY-MM-DD date by whole days (calendar arithmetic, no time zone involved). */
export function shiftDay(day: string, delta: number): string {
  const [y, m, d] = day.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d + delta));
  return date.toISOString().slice(0, 10);
}

/** e.g. "Mittwoch, 21. Oktober 2026" */
export function formatDayLabel(day: string): string {
  const [y, m, d] = day.split("-").map(Number);
  return new Intl.DateTimeFormat("de-CH", {
    timeZone: "UTC",
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(Date.UTC(y, m - 1, d)));
}

/** "08:00:00" → "08:00" */
export function formatTime(value: string | null): string | null {
  return value ? value.slice(0, 5) : null;
}

export type FieldAction = "depart" | "start" | "pause" | "resume" | "complete";

/**
 * Actions the field tool offers for a status, primary action first. Mirrors the
 * transitions the database allows (migration 0007, ADR-023):
 *   planned → on_the_way → started ↔ paused → completed, plus planned → started.
 * assigned/accepted wait for owner decision D-6. cancel, no-show and the not-completed end (CSR1 / CGR-20)
 * are reason commands on the card (visit-lifecycle.tsx), not field actions.
 * The database is the authority; this only decides which buttons to show.
 */
export function fieldActions(status: string | null): FieldAction[] {
  switch (status) {
    case "planned":
      return ["depart", "start"];
    case "on_the_way":
      return ["start"];
    case "started":
      return ["complete", "pause"];
    case "paused":
      return ["resume"];
    default:
      return [];
  }
}

/**
 * VIS1 (ADR-111, `cra` CGR-87): field actions happen on the visit's day. A visit dated after today (Europe/Zurich,
 * DAY-1) shows no field action; the database refuses them with `not_today` (migration 0089). Today and earlier days
 * keep `fieldActions` unchanged (VIS1-6). ISO dates compare as strings.
 */
export function isAfterToday(visitDate: string | null, today: string): boolean {
  return visitDate !== null && visitDate > today;
}

export function fieldActionsOn(status: string | null, visitDate: string | null, today: string): FieldAction[] {
  return isAfterToday(visitDate, today) ? [] : fieldActions(status);
}

/** VIS1-3b: a planned, not suspended visit dated after today can be moved to today at the door (existing J3 move). */
export function canMoveToToday(status: string | null, suspended: boolean | null, visitDate: string | null, today: string): boolean {
  return status === "planned" && suspended !== true && isAfterToday(visitDate, today);
}

/** "2026-10-29" → "29.10.2026" (calendar date, no time zone involved). */
export function formatShortDate(day: string): string {
  const [y, m, d] = day.split("-");
  return `${d}.${m}.${y}`;
}

/** VIS1-3 (wording fixed in the brief): shown once under the day heading of a day after today, styled `info`. */
export function futureDayNote(day: string): string {
  return `Der Einsatz ist für den ${formatShortDate(day)} geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.`;
}

/** VIS1-3b: the move at the door. */
export const MOVE_TO_TODAY_LABEL = "Heute machen";
export const MOVE_TO_TODAY_CONFIRM = "Auf heute verschieben";
export const MOVE_TO_TODAY_HINT =
  "Der Einsatz wird auf heute verschoben und im Verlauf festgehalten. Gestartet wird er danach mit «Einsatz starten».";

export const FIELD_ACTION_LABEL: Record<FieldAction, string> = {
  depart: "Losfahren",
  start: "Einsatz starten",
  pause: "Pause",
  resume: "Fortsetzen",
  complete: "Einsatz abschliessen",
};

export type FieldVisitLike = { status: string | null };

export function summarizeDay(visits: ReadonlyArray<FieldVisitLike>) {
  let open = 0;
  let running = 0;
  let done = 0;
  for (const v of visits) {
    if (v.status === "completed") done += 1;
    else if (v.status === "started" || v.status === "on_the_way" || v.status === "paused") running += 1;
    // CSR1 / CGR-20: a visit ended as not completed is neither open nor done.
    else if (v.status !== "cancelled" && v.status !== "no_show" && v.status !== "interrupted") open += 1;
  }
  return { total: visits.length, open, running, done };
}

// UX1 part (c) (ADR-104): the order of /field and the consequence lines of the "Mehr" menu. Display only: which
// visits exist, who may act and what a command does stay with the database.

export type NextVisitLike = {
  visit_id: string;
  status: string | null;
  time_start: string | null;
  responsible_me: boolean | null;
  suspended: boolean | null;
};

const RUNNING = new Set(["on_the_way", "started", "paused"]);
const STARTABLE = new Set(["planned", ...RUNNING]);

/**
 * UX1-6: the visit shown first ("Als Nächstes"). Only visits she can still act on count (planned or running, not
 * suspended by a case pause). Her own (responsible: du) come before the team's; within them a running visit comes
 * first, then the earliest start; a visit without a start time comes last. No candidate: null (the list stays in time
 * order). This picks what is shown first; it assigns nothing.
 */
export function pickNextVisit<T extends NextVisitLike>(visits: ReadonlyArray<T>): T | null {
  const open = visits.filter((v) => STARTABLE.has(v.status ?? "") && !v.suspended);
  const mine = open.filter((v) => v.responsible_me === true);
  const pool = mine.length > 0 ? mine : open;
  if (pool.length === 0) return null;
  const running = pool.find((v) => RUNNING.has(v.status ?? ""));
  if (running) return running;
  return [...pool].sort((a, b) => timeKey(a.time_start).localeCompare(timeKey(b.time_start)))[0];
}

function timeKey(time: string | null): string {
  return time ?? "99:99";
}

/** UX1-6: the next visit first, every other visit of the day after it in the order the database returned. */
export function orderFieldVisits<T extends NextVisitLike>(visits: ReadonlyArray<T>): { next: T | null; rest: T[] } {
  const next = pickNextVisit(visits);
  return { next, rest: visits.filter((v) => v !== next) };
}

export type TakeableLike = { visit_date: string; time_start: string | null; may_take: boolean | null };

/**
 * UX1-6a: while "Offen im Team" is collapsed, its header shows the earliest visit of today she may take, so taking it
 * stays one tap (ABS1/COVER1 "one tap, first wins"). Other days and visits she may not take stay in the list.
 */
export function earliestTakeableToday<T extends TakeableLike>(open: ReadonlyArray<T>, today: string): T | null {
  const candidates = open.filter((o) => o.visit_date === today && o.may_take === true);
  if (candidates.length === 0) return null;
  return [...candidates].sort((a, b) => timeKey(a.time_start).localeCompare(timeKey(b.time_start)))[0];
}

/**
 * UX1-8: the one sentence the second step of "Mehr" shows before the existing command runs. Wording for `cra` review
 * (UX1-12 clinical gate). The cancellation sentence states what `cancel_visit` does (status `cancelled`, migration
 * 0024/0054); it does not release the visit to the team (deviation from the brief's example, ADR-104).
 */
export const CANCEL_CONSEQUENCE = "Der Einsatz wird mit dem gewählten Grund als abgesagt gespeichert und findet nicht statt.";
/** UX1-8: the hold's consequence; the hold's meaning (HOLD_MEANING, CGR-13) stays next to it, unchanged. */
export const HOLD_CONSEQUENCE = "Dieser Einsatz wird nicht abgerechnet, bis Coach oder Admin die Sperre mit Begründung aufheben.";
