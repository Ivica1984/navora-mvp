// SIG1 (migration 0060, ADR-074): fixed texts and pure helpers for P1 safety signals on /field, /team and OPS1.
// Pure module (no "use server"), unit-tested in tests/unit/signals-rules.test.ts.

/** The brief's fixed text per kind (SIG1-3). Never configurable; no client name, no free text. */
export const SIGNAL_TEXT: Record<string, string> = {
  visit_overdue: "Einsatz überfällig",
  visit_stuck: "Einsatz hängt",
  visit_uncovered: "Einsatz ohne Zuständige",
  visit_interrupted: "Einsatz abgebrochen",
  no_show: "Klientin öffnet nicht",
};

/** Polling interval: a new P1 shows within 60 s (SIG1-3); the server throttles evaluation to once per 15 s. */
export const SIGNAL_POLL_MS = 30_000;

export const TAKE_MESSAGES: Record<string, string> = {
  not_recipient: "Dieses Signal ist nicht an dich gerichtet.",
  signal_ended: "Die Ursache ist behoben, das Signal ist beendet.",
  failed: "Konnte nicht gespeichert werden. Bitte nochmals versuchen.",
  invalid: "Ungültige Eingabe.",
};

export type SignalRow = {
  signal_id: string;
  signal_kind: string;
  visit_id: string;
  visit_date: string;
  time_start: string | null;
  team_name: string;
  reason: string;
  delivered_at: string;
  taken_by_me: boolean;
  taken_by_name: string | null;
  taken_at: string | null;
  /** SIG2-5: nobody received it outside the app, so Operations got it at once. */
  outside_none?: boolean | null;
  /** SIG1-C1 (0063): qualification of the person shown as taker (`registered_nurse`, `care_assistant`, or none). */
  taken_by_qualification?: string | null;
  /** SIG1-C1: taken, but by nobody whose take stops the step to Operations (a no-show or broken-off visit). */
  taken_awaits_rn?: boolean | null;
  /** SIG2-C1 (1) (0068): a watched period of the organisation runs now (no watched hours recorded → false). */
  watched_now?: boolean | null;
  /**
   * FUP1-2 (0071, CGR-58): the step to Operations reaches Operations outside the app: once made, it follows the
   * Operations delivery; before, it is judged at the instant the step is due. Decides the banner text when present.
   */
  operations_outside_app?: boolean | null;
  /**
   * LEAVE1-14 (0078, CGR-62): the only take is by a person whose access has ended. It stops nothing and reads as
   * untaken: no name, time or qualification; the banner shows TAKE_ENDED.
   */
  taker_access_ended?: boolean | null;
};

/** LEAVE1-14: fixed text for a take whose taker's access has ended (no reason code, LEAVE1-8). */
export const TAKE_ENDED = "Übernahme beendet – Zugang beendet";

export function signalText(kind: string): string {
  return SIGNAL_TEXT[kind] ?? "Sicherheitssignal";
}

/** "24.10. 07:00 · Testteam Nord" — date and planned start of the visit, and the owning team. */
export function signalWhen(row: Pick<SignalRow, "visit_date" | "time_start" | "team_name">): string {
  const [, m, d] = row.visit_date.split("-");
  const time = row.time_start ? ` ${row.time_start.slice(0, 5)}` : "";
  return `${d}.${m}.${time} · ${row.team_name}`;
}

/** Link to the visit's day in the field tool. */
export function signalHref(row: Pick<SignalRow, "visit_date">): string {
  return `/field?datum=${row.visit_date}`;
}

/**
 * SIG1-4: untaken signals at the top; taken ones leave the top list and show who took them.
 * SIG1-C1: a signal taken only by someone whose take does not stop the step to Operations (a care assistant's take of a
 * no-show or broken-off visit) stays at the top for everyone who has not taken it, so a registered nurse can take it.
 * LEAVE1-14: a take by a person whose access has ended stays at the top too (it stops nothing).
 */
export function splitSignals<T extends Pick<SignalRow, "taken_by_name" | "taken_by_me" | "taken_awaits_rn"> & { taker_access_ended?: boolean | null }>(
  rows: T[],
): { open: T[]; taken: T[] } {
  const open: T[] = [];
  const taken: T[] = [];
  for (const r of rows) {
    const isTaken = !r.taker_access_ended && (r.taken_by_me || (Boolean(r.taken_by_name) && !r.taken_awaits_rn));
    (isTaken ? taken : open).push(r);
  }
  return { open, taken };
}

/** Fixed qualification labels (D-5 pilot model). */
export const QUALIFICATION_LABEL: Record<string, string> = {
  registered_nurse: "Pflegefachperson",
  care_assistant: "Pflegehilfe",
};

/** SIG1-C1 (a): the step to Operations follows, and a watched period runs (Operations is told outside the app too). */
export const OPERATIONS_FOLLOWS = "Meldung an Operations folgt";
/** SIG2-C1 (1) (CGR-48): no watched period runs, so the step to Operations stays in the app (SIG2-12). */
export const OPERATIONS_APP_ONLY = "Operations nur in der App: ausserhalb der überwachten Zeit";

/**
 * Does the banner promise the message to Operations? FUP1-2 (0071): the reader's `operations_outside_app` decides
 * whenever the row carries the field (the step follows its delivery, or the instant it is due); only a row without the
 * field (a reader older than 0071) falls back to `watched_now` (SIG2-C1 (1)). Only `true` promises; null never does.
 */
export function operationsFollows(row: Pick<SignalRow, "watched_now" | "operations_outside_app">): boolean {
  if (row.operations_outside_app !== undefined) return row.operations_outside_app === true;
  return row.watched_now === true;
}

/**
 * "übernommen von Anna (Pflegehilfe), Meldung an Operations folgt" (SIG1-C1 (a)) when the step reaches Operations
 * outside the app; otherwise "…, Operations nur in der App: ausserhalb der überwachten Zeit" (SIG2-C1 (1), FUP1-2).
 * A missing flag never promises the message to Operations.
 */
export function takenText(
  row: Pick<SignalRow, "taken_by_me" | "taken_by_name" | "taken_by_qualification" | "taken_awaits_rn" | "watched_now" | "operations_outside_app">
    & { taker_access_ended?: boolean | null },
): string {
  if (row.taker_access_ended) return TAKE_ENDED;
  const base = row.taken_by_me ? "von dir übernommen" : `übernommen von ${row.taken_by_name ?? "Teammitglied"}`;
  if (!row.taken_awaits_rn) return base;
  const label = row.taken_by_qualification ? QUALIFICATION_LABEL[row.taken_by_qualification] : undefined;
  return `${label ? `${base} (${label})` : base}, ${operationsFollows(row) ? OPERATIONS_FOLLOWS : OPERATIONS_APP_ONLY}`;
}

/** SIG2-C1 (2) (0068, ADR-082): a planned visit of the next 7 days outside the organisation's watched periods. */
export type OutsideWatchedVisit = {
  visit_id: string;
  organization_id: string;
  team_id: string;
  team_name: string;
  visit_date: string;
  time_start: string | null;
  time_end: string | null;
};

export const OUTSIDE_WATCHED_LABEL = "Geplante Einsätze ausserhalb der überwachten Zeiten";
export const OUTSIDE_WATCHED_EMPTY = "Keine geplanten Einsätze ausserhalb der überwachten Zeiten in den nächsten 7 Tagen.";
/** Why the list exists (SIG1-8 stays a go-live condition until the list is empty for the pilot plan). */
export const OUTSIDE_WATCHED_NOTE =
  "Heute und die nächsten 6 Tage. Ausserhalb der überwachten Zeiten erhält Operations Signale nur in der App. " +
  "Bedingung SIG1-8: solche Einsätze sind im Pilot nicht geplant, oder jemand beobachtet die Signale in dieser Zeit.";

/** "Mo 26.10. 21:00–21:30 · Testteam Nord"; without a planned start: "ohne Zeit". */
export function outsideWatchedLine(row: Pick<OutsideWatchedVisit, "visit_date" | "time_start" | "time_end" | "team_name">): string {
  const [y, m, d] = row.visit_date.split("-").map(Number);
  const weekday = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
  const dd = String(d).padStart(2, "0");
  const mm = String(m).padStart(2, "0");
  const start = row.time_start ? row.time_start.slice(0, 5) : null;
  const end = row.time_end ? row.time_end.slice(0, 5) : null;
  const time = start ? (end ? `${start}–${end}` : start) : "ohne Zeit";
  return `${weekday} ${dd}.${mm}. ${time} · ${row.team_name}`;
}

/** Why the person received it (Operations rows say so). */
export function reasonText(reason: string, outsideNone = false): string | null {
  if (reason === "operations_fallback") return "an Operations: niemand im Team im Dienst";
  // SIG2-5: "kein Empfänger ausserhalb der App" → Operations at once, without waiting for the untaken threshold.
  if (reason === "untaken" && outsideNone) return "an Operations: kein Empfänger ausserhalb der App";
  if (reason === "untaken") return "an Operations: nicht rechtzeitig übernommen";
  return null;
}

export function takeOutcome(data: unknown): { result: string; reason?: string } {
  if (data && typeof data === "object" && "result" in data) {
    const d = data as { result: unknown; reason?: unknown };
    return { result: String(d.result), reason: d.reason == null ? undefined : String(d.reason) };
  }
  return { result: "failed" };
}

/** SIG2-11 (0064, ADR-078): the scheduled evaluator's last run per organisation (Operations and administrators only). */
export type EvaluatorHealth = { organization_id: string; last_run_at: string | null; running: boolean };

export const EVALUATOR_DOWN = "Signalprüfung läuft nicht";
export const EVALUATOR_RUNNING = "Signalprüfung läuft";

/** The organisations whose scheduled evaluator has not run for more than 5 minutes (decided by the database). */
export function evaluatorDown(rows: EvaluatorHealth[]): EvaluatorHealth[] {
  return rows.filter((r) => !r.running);
}

/** One line per organisation for the warning; the time is Europe/Zurich wall time. */
export function evaluatorDownText(row: EvaluatorHealth): string {
  if (!row.last_run_at) return `${EVALUATOR_DOWN}: kein geplanter Lauf erfasst.`;
  const at = new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", dateStyle: "short", timeStyle: "short" })
    .format(new Date(row.last_run_at));
  return `${EVALUATOR_DOWN}: letzter geplanter Lauf ${at}.`;
}

/** What it means for the team (SIG2-11 (2)): no outside channel is shown as active, signals need an open page. */
export const EVALUATOR_DOWN_CONSEQUENCE =
  "Signale erscheinen nur, solange eine NAVORA-Seite geöffnet ist; ausserhalb der App wird keine Benachrichtigung als aktiv angezeigt. " +
  "Bitte die Administration bzw. den Betrieb der Plattform informieren.";
