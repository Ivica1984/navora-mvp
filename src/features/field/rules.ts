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

/**
 * VIS1-3 (wording fixed in the brief): shown once under the day heading of a day after today, styled `info`.
 * VIS1-3e (2) (po 2026-10-28 22:15, UXR-33): count-aware; one visit keeps the VIS1-3 wording, several get the PO's
 * plural wording (`cra` reads it in VIS1-7). Closes ADR-111 deviation 2.
 */
export function futureDayNote(day: string, count = 1): string {
  if (count > 1) {
    return `Diese Einsätze sind für den ${formatShortDate(day)} geplant. Machst du einen davon heute, verschiebe ihn zuerst mit «Heute machen».`;
  }
  return `Der Einsatz ist für den ${formatShortDate(day)} geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.`;
}

/** VIS1-3b: the move at the door. */
export const MOVE_TO_TODAY_LABEL = "Heute machen";
export const MOVE_TO_TODAY_CONFIRM = "Auf heute verschieben";
export const MOVE_TO_TODAY_HINT =
  "Der Einsatz wird auf heute verschoben und im Verlauf festgehalten. Gestartet wird er danach mit «Einsatz starten».";

/** VIS1-3e (1): the one status line after a successful move on /field. */
export const MOVED_TO_TODAY_STATUS = "Einsatz auf heute verschoben";

/**
 * VIS1-3d (UXR-31): a move whose responsible member is absent at the new time releases the visit (ABS1-C4). The same
 * fixed text as on /team; one behaviour per command.
 */
export const RELEASED_ON_MOVE = "Die verantwortliche Person ist zur neuen Zeit abwesend. Der Einsatz ist jetzt offen im Team.";

const LAST_MINUTE_OF_DAY = 23 * 60 + 59;

/** Minutes since midnight of an "HH:MM" or "HH:MM:SS" time; null when absent or malformed. */
export function minutesOf(time: string | null): number | null {
  const m = /^(\d{2}):(\d{2})/.exec(time ?? "");
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  return h < 24 && min < 60 ? h * 60 + min : null;
}

function hhmmOf(minutes: number): string {
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
}

/** The wall-clock minute of the day in Europe/Zurich (DAY-1), for the prefill of VIS1-3c. */
export function zurichMinutesNow(now: Date = new Date()): number {
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .formatToParts(now);
  const h = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const m = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  return h * 60 + m;
}

/**
 * VIS1-3c (po 2026-10-28 22:15 from `uxa` UXR-30): the times the "Heute machen" confirmation prefills. Start = the next
 * full 5 minutes after now (Zurich: 14:02 → 14:05, 14:05 → 14:10); end = start + the card's planned duration. If the
 * start or the end would fall after 23:59 today, both stay empty (and required): no visit is prefilled across
 * midnight. A card without a valid planned duration gets the start only. Both fields stay editable. No signal, threshold
 * or permission depends on this; it only keeps the usual move at the door from being overdue the moment it is saved.
 */
export function prefillMoveTimes(nowMinutes: number, timeStart: string | null, timeEnd: string | null): { start: string; end: string } {
  const start = (Math.floor(nowMinutes / 5) + 1) * 5;
  if (start > LAST_MINUTE_OF_DAY) return { start: "", end: "" };
  const s = minutesOf(timeStart);
  const e = minutesOf(timeEnd);
  const duration = s !== null && e !== null && e > s ? e - s : null;
  if (duration === null) return { start: hhmmOf(start), end: "" };
  const end = start + duration;
  if (end > LAST_MINUTE_OF_DAY) return { start: "", end: "" };
  return { start: hhmmOf(start), end: hhmmOf(end) };
}

/**
 * VIS1-8 (po 2026-10-28 22:00 from `cra` CGR-89): the fact the confirmation states about the date the visit leaves.
 * `hasOther` is the server's yes/no (`visit_move_leaves_other_visit`, migration 0090): true also when the other visit
 * belongs to a team she cannot read, so the sentence never says "kein Einsatz" then; no detail of it is shown. Null
 * (no answer, e.g. not a team member, or the read failed) shows no sentence rather than a guess.
 */
export function moveLeavesNote(plannedDay: string, hasOther: boolean | null): string | null {
  if (hasOther === null) return null;
  return hasOther
    ? `Am ${formatShortDate(plannedDay)} ist danach noch ein Einsatz bei dieser Person geplant.`
    : `Am ${formatShortDate(plannedDay)} ist danach kein Einsatz bei dieser Person geplant.`;
}

/**
 * VIS1-3d / VIS1-3e: after a move on /field the page opens today's view with `?verschoben=<visit>` (and `offen=1` when
 * the move released the visit, `hinweise=<flags>` for the planning flags). Display only: a crafted link can at most show
 * a notice; it changes nothing. Unknown flags and a malformed id are dropped.
 */
export type MovedNotice = { visitId: string; released: boolean; flags: string[] };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseMovedNotice(
  verschoben: string | string[] | undefined,
  offen: string | string[] | undefined,
  hinweise: string | string[] | undefined,
  knownFlags: ReadonlyArray<string>,
): MovedNotice | null {
  const id = Array.isArray(verschoben) ? verschoben[0] : verschoben;
  if (!id || !UUID_RE.test(id)) return null;
  const open = Array.isArray(offen) ? offen[0] : offen;
  const raw = Array.isArray(hinweise) ? hinweise[0] : hinweise;
  const flags = (raw ?? "").split(",").filter((f) => knownFlags.includes(f));
  return { visitId: id.toLowerCase(), released: open === "1", flags: [...new Set(flags)] };
}

/** The /field link after a move (inverse of parseMovedNotice). */
export function movedNoticeHref(visitId: string, released: boolean, flags: ReadonlyArray<string>): string {
  const params = new URLSearchParams({ verschoben: visitId });
  if (released) params.set("offen", "1");
  if (flags.length > 0) params.set("hinweise", flags.join(","));
  return `/field?${params.toString()}`;
}

/** The query parameters that carry a move's result (VIS1-3d / VIS1-3e). */
export const MOVED_NOTICE_PARAMS = ["verschoben", "offen", "hinweise"] as const;

/**
 * VIS1-3g (UXR-35, ADR-112 addendum): the notice belongs to the move that produced it. Once today's view has shown it,
 * the page drops these parameters from the address (history.replaceState), so a reload, a later refresh (e.g. after
 * "Einsatz starten") or a copied link no longer shows it. Returns the search string without them ("" when empty);
 * every other parameter is kept in order.
 */
export function withoutMovedNotice(search: string): string {
  const params = new URLSearchParams(search);
  for (const key of MOVED_NOTICE_PARAMS) params.delete(key);
  const rest = params.toString();
  return rest ? `?${rest}` : "";
}

/**
 * VIS1-10 (po 2026-10-29 02:15, amended 03:10 and 04:10 from `uxa` UXR-39; ADR-116): the database refused "Heute machen"
 * with `day_changed` because the date she was shown is no longer its today (page left open across midnight). The
 * confirmation stays open with the new date as a fact, tone `info`, focus on it. Wording fixed by the PO; `cra` reads it
 * in the VIS1-7 gate. e.g. "Inzwischen ist Donnerstag, 29.10.2026. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige
 * noch einmal."
 */
export function dayChangedNote(day: string): string {
  const [y, m, d] = day.split("-").map(Number);
  const weekday = new Intl.DateTimeFormat("de-CH", { timeZone: "UTC", weekday: "long" }).format(new Date(Date.UTC(y, m - 1, d)));
  return `Inzwischen ist ${weekday}, ${formatShortDate(day)}. Die Zeiten sind neu gesetzt. Prüfe sie und bestätige noch einmal.`;
}

/**
 * VIS1-10 fallback (brief wording, po 02:15): where the confirmation can no longer be shown, e.g. the visit is no longer
 * dated after the new today, so "Heute machen" does not apply to it any more.
 */
export const DAY_CHANGED_RELOAD = "Inzwischen ist ein neuer Tag. Lade die Seite neu, dann siehst du die Einsätze von heute.";

/**
 * VIS1-10: what the confirmation does after `day_changed`. `today` is the database's date from the refusal; the visit
 * keeps its date. Offered again only while the visit is still dated after that today and both dates are real dates;
 * otherwise the reload sentence. Display only: the database decides again on the next confirm.
 */
export function afterDayChanged(today: unknown, visitDate: unknown): { kind: "confirm_again"; today: string } | { kind: "reload" } {
  const real = (d: unknown): d is string => typeof d === "string" && d !== "" && parseDayParam(d, "") === d;
  if (!real(today) || !real(visitDate)) return { kind: "reload" };
  return visitDate > today ? { kind: "confirm_again", today } : { kind: "reload" };
}

/** VIS1-3f (UXR-34): the id of the release notice, the moved card's accessible description. */
export const MOVED_RELEASED_NOTICE_ID = "verschoben-offen-hinweis";

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
