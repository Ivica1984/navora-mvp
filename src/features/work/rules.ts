// WORK1 (migration 0079, ADR-092): the nurse's working day, proposed from her own visit events, confirmed by her and
// exported by her. Pure module (labels, time conversion, payload, CSV), unit-tested. The database decides everything
// again (only she reads her day, the two questions, versions, audit).

const ZONE = "Europe/Zurich";

/** WORK1-8: the fixed information text. A changed text needs a new version (and the database constant in 0079). */
export const NOTICE_VERSION = "work1-notice-v1";
export const NOTICE_TITLE = "Information zu deinem Arbeitstag";
export const NOTICE_PARAGRAPHS: readonly string[] = [
  "NAVORA speichert, wann ein Einsatz beginnt, unterbrochen und abgeschlossen wird und wann du losfährst. Die Mitglieder deines Teams sehen diese Statuszeiten der Einsätze, damit ihr die Pflege koordinieren könnt.",
  "Aus deinen eigenen Statuszeiten schlägt NAVORA dir deinen Arbeitstag vor. Diesen Vorschlag, deine Bestätigung, frühere Fassungen und deine Notizen siehst nur du. Niemand sonst im Team, in der Koordination oder in der Administration sieht sie.",
  "Du ergänzt Beginn und Ende des Arbeitstags, Pausen von 30 Minuten oder mehr und Arbeit ausserhalb der Einsätze und bestätigst den Tag. Den bestätigten Monat exportierst du selbst als Datei und gibst ihn deiner Arbeitgeberin. NAVORA schickt nichts automatisch.",
  "Dein Team sieht pro Monat nur einen Anteil für das ganze Team (direkte Pflegezeit an bestätigter Arbeitszeit), nie Zahlen einer einzelnen Person und erst ab drei Personen.",
  "NAVORA prüft keine Pausen-, Ruhe- oder Höchstarbeitszeiten.",
];
/** Shown with the text: it is a draft for the employer (go-live gate G-19), not the employer's adopted information. */
export const NOTICE_DRAFT_HINT = "Entwurf für die Arbeitgeberin (Testbetrieb mit synthetischen Daten).";

export const VISIT_KINDS = ["travel", "care", "visit_pause"] as const;
export const OUTSIDE_KINDS = ["team_meeting", "training", "administration", "on_call", "call_out_travel", "other"] as const;
export const REASON_CODES = ["segment_missing", "time_wrong", "break_missing", "other"] as const;
export type VisitKind = (typeof VISIT_KINDS)[number];
export type OutsideKind = (typeof OUTSIDE_KINDS)[number];
export type ReasonCode = (typeof REASON_CODES)[number];

export const KIND_LABEL: Record<string, string> = {
  travel: "Weg zum Einsatz",
  care: "Pflege im Einsatz",
  visit_pause: "Unterbruch im Einsatz",
  report_signed: "Bericht signiert",
  break: "Pause (30 Min. oder mehr)",
  team_meeting: "Teamsitzung",
  training: "Weiterbildung",
  administration: "Administration",
  on_call: "Pikett-Einsatz ohne Besuch",
  call_out_travel: "Weg eines Pikett-Einsatzes",
  other: "Andere Arbeit",
  day: "Arbeitstag",
};

export const REASON_LABEL: Record<ReasonCode, string> = {
  segment_missing: "Abschnitt fehlte",
  time_wrong: "Zeit falsch",
  break_missing: "Pause fehlte",
  other: "Anderes",
};

export const CONFIRM_MESSAGES: Record<string, string> = {
  ok: "Arbeitstag bestätigt.",
  duplicate: "Arbeitstag bestätigt.",
  questions_open: "Bitte beide Fragen beantworten und Beginn und Ende eintragen.",
  future: "Ein künftiger Tag kann nicht bestätigt werden.",
  invalid: "Bitte die Zeiten prüfen.",
  rejected: "Nicht möglich.",
  failed: "Bestätigen fehlgeschlagen.",
};

export const INVALID_FIELD: Record<string, string> = {
  day: "Beginn und Ende prüfen: Beginn am gewählten Tag, Ende danach, höchstens 24 Stunden.",
  segments: "Ein Einsatzabschnitt hat kein gültiges Ende.",
  breaks: "Eine Pause hat keine gültige Zeit.",
  breaks_overlap: "Zwei Pausen überschneiden sich.",
  outside_work: "Eine Arbeit ausserhalb der Einsätze hat keine gültige Zeit.",
  outside_day: "Ein Eintrag liegt ausserhalb von Beginn und Ende des Arbeitstags.",
  reason_code: "Für eine Korrektur einen Grund wählen.",
  note: "Die Notiz hat höchstens 200 Zeichen.",
};

const TIME = /^([01]\d|2[0-3]):([0-5]\d)$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

function zurichParts(at: Date): { date: string; time: string; offsetMinutes: number } {
  const f = new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONE, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
    second: "2-digit", hourCycle: "h23",
  });
  const p = Object.fromEntries(f.formatToParts(at).map((x) => [x.type, x.value]));
  const asUtc = Date.UTC(Number(p.year), Number(p.month) - 1, Number(p.day), Number(p.hour), Number(p.minute), Number(p.second));
  return {
    date: `${p.year}-${p.month}-${p.day}`,
    time: `${p.hour}:${p.minute}`,
    offsetMinutes: Math.round((asUtc - Math.floor(at.getTime() / 1000) * 1000) / 60000),
  };
}

function offsetText(minutes: number): string {
  const sign = minutes < 0 ? "-" : "+";
  const m = Math.abs(minutes);
  return `${sign}${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}

/**
 * Zurich local date and time ("HH:MM") → ISO instant with its offset. Same rule as the database (DST1, ADR-081):
 * the repeated autumn hour reads as the earlier instant (CEST); a time in the spring gap reads in standard time (CET).
 * Null for malformed input.
 */
export function zurichInstant(date: string, time: string): string | null {
  if (!DATE.test(date) || !TIME.test(time)) return null;
  for (const off of ["+02:00", "+01:00"]) {
    const iso = `${date}T${time}:00${off}`;
    const at = new Date(iso);
    if (Number.isNaN(at.getTime())) return null;
    const p = zurichParts(at);
    if (p.date === date && p.time === time) return iso;
  }
  return `${date}T${time}:00+01:00`;
}

/** Instant → "YYYY-MM-DD" Zurich calendar date. */
export function zurichDate(iso: string): string {
  return zurichParts(new Date(iso)).date;
}

/** Instant → "HH:MM" Zurich wall clock. */
export function zurichTime(iso: string): string {
  return zurichParts(new Date(iso)).time;
}

/** Instant → Zurich local date-time with its UTC offset, e.g. "2026-10-25T02:30:00+01:00" (WORK1-4). */
export function zurichLocalWithOffset(iso: string): string {
  const at = new Date(iso);
  const p = zurichParts(at);
  const sec = String(at.getUTCSeconds()).padStart(2, "0");
  return `${p.date}T${p.time}:${sec}${offsetText(p.offsetMinutes)}`;
}

/** Elapsed minutes between two instants (real length, also across a clock change), one decimal. */
export function elapsedMinutes(startIso: string, endIso: string): number {
  return Math.round((new Date(endIso).getTime() - new Date(startIso).getTime()) / 6000) / 10;
}

/** The day after a date (the end of a night shift may fall on it). */
export function nextDate(date: string): string {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);
}

/** End time on the same day, or the next day when it is not after the start ("22:00" → "06:00"). */
export function endInstant(date: string, startTime: string, endTime: string): string | null {
  if (!TIME.test(startTime) || !TIME.test(endTime)) return null;
  return endTime > startTime ? zurichInstant(date, endTime) : zurichInstant(nextDate(date), endTime);
}

/** WORK1-C4 (0081): `corrected` = the start or end came from an F3-corrected visit event (effective time). */
export type ProposalRow = {
  seq: number; visit_no: number | null; kind: string; starts_at: string; ends_at: string | null; corrected?: boolean;
};
/** The times a visit segment had when the form opened (proposal or confirmed version), to see whether she changed it. */
export type SegmentOrigin = { start: string | null; end: string | null; corrected: boolean };
export type Interval = { start: string; end: string };
export type OutsideEntry = Interval & { kind: OutsideKind };
/** "none" is an explicit answer; null is "not answered yet". Nothing is pre-answered (WORK1-2). */
export type Answer<T> = "none" | T[] | null;

export type DayDraft = {
  date: string;
  dayStart: string; // "HH:MM" or ""
  dayEnd: string;
  segments: Array<{ kind: VisitKind; start: string | null; end: string | null; origin?: SegmentOrigin }>;
  breaks: Answer<{ start: string; end: string }>; // HH:MM pairs
  outside: Answer<{ kind: OutsideKind; start: string; end: string }>;
  reason?: ReasonCode | null;
  note?: string;
};

/** Which questions are still open (both must be answered, start and end entered). */
export function openQuestions(d: Pick<DayDraft, "dayStart" | "dayEnd" | "breaks" | "outside">): string[] {
  const open: string[] = [];
  if (!TIME.test(d.dayStart)) open.push("day_start");
  if (!TIME.test(d.dayEnd)) open.push("day_end");
  if (d.breaks === null || (Array.isArray(d.breaks) && d.breaks.length === 0)) open.push("breaks");
  if (d.outside === null || (Array.isArray(d.outside) && d.outside.length === 0)) open.push("outside_work");
  return open;
}

/** Visit segments of the proposal she can confirm (the report sign time is a point, not a segment). */
export function proposalSegments(rows: ProposalRow[]): DayDraft["segments"] {
  return rows
    .filter((r): r is ProposalRow & { kind: VisitKind } => (VISIT_KINDS as readonly string[]).includes(r.kind))
    .map((r) => ({
      kind: r.kind, start: r.starts_at, end: r.ends_at,
      origin: { start: r.starts_at, end: r.ends_at, corrected: Boolean(r.corrected) },
    }));
}

/**
 * WORK1-C4 (b): the hint when she changes the start or end of a segment that came from a visit. Her confirmation is
 * still stored as she entered it; the working day never writes the visit's times (no write-back, 0081).
 */
export const VISIT_TIME_HINT =
  "Die Zeit im Einsatz bleibt unverändert. Korrigieren Sie sie im Einsatz, damit Bericht und Abrechnung stimmen.";
export const VISIT_TIME_LINK = "Zeit im Einsatz korrigieren";
export const CORRECTED_MARK = "im Einsatz korrigiert";

function sameInstant(a: string | null, b: string | null): boolean {
  if (a === null || b === null) return a === b;
  return Math.abs(new Date(a).getTime() - new Date(b).getTime()) < 1000;
}

/** True when a visit segment's start or end differs from the time it had when the form opened. */
export function visitSegmentChanged(seg: { start: string | null; end: string | null; origin?: SegmentOrigin }): boolean {
  if (!seg.origin) return false;
  return !sameInstant(seg.start, seg.origin.start) || !sameInstant(seg.end, seg.origin.end);
}

/**
 * Link to the visit's time correction (F3) on /field: the Zurich day of the segment and its original start instant;
 * /field opens the time line of the visit that has an event at that instant. No visit identifier is needed (the
 * proposal carries none, WORK1-1). Without a start, the day of the working day.
 */
export function visitCorrectionHref(origin: SegmentOrigin | undefined, day: string): string {
  const at = origin?.start ?? origin?.end ?? null;
  if (!at) return `/field?datum=${day}`;
  return `/field?datum=${zurichDate(at)}&zeit=${encodeURIComponent(new Date(at).toISOString())}#einsatz-korrektur`;
}

function hhmmInterval(date: string, dayStartTime: string, start: string, end: string): Interval | null {
  // A clock time before the day's start belongs to the next calendar day (night shift).
  const place = (t: string) => (t >= dayStartTime ? zurichInstant(date, t) : zurichInstant(nextDate(date), t));
  const s = place(start);
  const e = place(end);
  return s && e ? { start: s, end: e } : null;
}

/** Builds the confirm payload (instants with offset). Unanswered questions stay absent; the database refuses them. */
export function buildPayload(d: DayDraft): Record<string, unknown> {
  const payload: Record<string, unknown> = {};
  if (TIME.test(d.dayStart)) payload.day_start = zurichInstant(d.date, d.dayStart);
  if (TIME.test(d.dayStart) && TIME.test(d.dayEnd)) payload.day_end = endInstant(d.date, d.dayStart, d.dayEnd);
  payload.segments = d.segments.map((s) => ({ kind: s.kind, start: s.start, end: s.end }));
  if (d.breaks === "none") payload.breaks = "none";
  else if (Array.isArray(d.breaks) && d.breaks.length > 0)
    payload.breaks = d.breaks.map((b) => hhmmInterval(d.date, d.dayStart, b.start, b.end) ?? { start: null, end: null });
  if (d.outside === "none") payload.outside_work = "none";
  else if (Array.isArray(d.outside) && d.outside.length > 0)
    payload.outside_work = d.outside.map((o) => ({ kind: o.kind, ...(hhmmInterval(d.date, d.dayStart, o.start, o.end) ?? { start: null, end: null }) }));
  if (d.reason) payload.reason_code = d.reason;
  if (d.note && d.note.trim()) payload.note = d.note.trim();
  return payload;
}

export type ConfirmedEntry = { kind: string; start: string; end: string; minutes: number };
export type ExportDay = {
  date: string;
  version: number;
  confirmed_at: string;
  day_start: string;
  day_end: string;
  breaks_answer: "none" | "listed";
  outside_answer: "none" | "listed";
  paid_minutes: number;
  entries: ConfirmedEntry[];
};
export type MonthExport = { month: string; days: ExportDay[]; unconfirmed: string[] };

function csvCell(v: string | number): string {
  const s = String(v);
  return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/**
 * WORK1-4: the CSV for her employer. Columns: date, segment kind, start, end (local time with UTC offset), elapsed
 * minutes, version, confirmed at. No client, case, address, visit identifier or note. Unconfirmed days are listed by
 * date in the header as "nicht bestätigt", never filled. Semicolon-separated (Swiss spreadsheet default), UTF-8.
 */
export function buildCsv(e: MonthExport): string {
  const lines: string[] = [];
  lines.push(`# NAVORA Arbeitszeit ${e.month} (von der Pflegenden bestätigt und exportiert)`);
  lines.push(`# nicht bestätigt: ${e.unconfirmed.length > 0 ? e.unconfirmed.join(", ") : "keine"}`);
  lines.push(["datum", "art", "beginn", "ende", "minuten", "fassung", "bestaetigt_am"].join(";"));
  for (const d of [...e.days].sort((a, b) => a.date.localeCompare(b.date))) {
    const tail = [d.version, zurichLocalWithOffset(d.confirmed_at)];
    const row = (kind: string, start: string, end: string, minutes: number | string) =>
      lines.push([d.date, kind, start, end, minutes, ...tail].map(csvCell).join(";"));
    row(KIND_LABEL.day, zurichLocalWithOffset(d.day_start), zurichLocalWithOffset(d.day_end), elapsedMinutes(d.day_start, d.day_end));
    if (d.breaks_answer === "none") row("Pause (30 Min. oder mehr): keine", "", "", "");
    if (d.outside_answer === "none") row("Arbeit ausserhalb der Einsätze: keine", "", "", "");
    for (const x of [...d.entries].sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())) {
      row(KIND_LABEL[x.kind] ?? x.kind, zurichLocalWithOffset(x.start), zurichLocalWithOffset(x.end), x.minutes);
    }
    row("Bezahlte Arbeitszeit (Tag ohne Pausen)", "", "", d.paid_minutes);
  }
  return lines.join("\r\n") + "\r\n";
}

/** "2026-10" from a YYYY-MM-DD date. */
export function monthOf(date: string): string {
  return date.slice(0, 7);
}
