// DOOR1 part (b) (migration 0073, ADR-086): display and input rules for the safety-alert values.
// Pure module: no "use server", so the rules are unit-tested (tests/unit/door1-alerts.test.ts).
// Display only: no value ranks, routes, escalates or blocks anything (DOOR1-8). No clinical category exists (D-17 part 3).

/** The three values, in the order the form offers them: "unbekannt" first (DOOR1-4, `cra` 22:26). */
export const ALERT_VALUES = ["unbekannt", "nein", "ja"] as const;
export type AlertValue = (typeof ALERT_VALUES)[number];

/** Same list as the database (0073 check constraint). */
export const ALERT_SOURCES = ["referral", "client", "relative", "doctor", "team"] as const;
export type AlertSource = (typeof ALERT_SOURCES)[number];

export const ALERT_SOURCE_LABEL: Record<AlertSource, string> = {
  referral: "Zuweisung",
  client: "Klient:in",
  relative: "Angehörige",
  doctor: "Ärztin/Arzt",
  team: "Team",
};

export const ALERT_NOTE_MAX = 300;
export const NOT_RECORDED = "nicht erfasst";
export const CODE_REFUSED = "Bitte keinen Code erfassen";
/**
 * COND1-9 = DOOR1-15 (PO 2026-10-26 14:30, CGR-66): the help text under "Zugang zur Wohnung" at intake, the same text as
 * the DOOR1-4 note (category access_arrangement version 2, migration 0084). The code guard stays: a phone number or a
 * postal code (four digits or more in a row) is refused like a code.
 */
export const ACCESS_HELP_TEXT = "Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code";

/**
 * DOOR1-4 guard: four or more digits in a row, also with single spaces, dots, commas, colons, slashes or dashes between
 * them ("4711", "47 11", "4-7-1-1"). Same pattern as private.looks_like_code (0073), which checks again on the server.
 */
const CODE_PATTERN = /[0-9](?:[ .,:/-]?[0-9]){3}/;

export function looksLikeCode(note: string | null | undefined): boolean {
  return note ? CODE_PATTERN.test(note) : false;
}

/** The input error for a value, or null. Mirrors the command (0073): "ja" needs a note; at most 300; no code. */
export function alertValueError(value: string, note: string | null | undefined, refusesCodes: boolean): string | null {
  const text = note?.trim() ?? "";
  if (!(ALERT_VALUES as readonly string[]).includes(value)) return "Bitte ja, nein oder unbekannt wählen.";
  if (value === "ja" && text.length === 0) return "Bei «ja» bitte festhalten, wo und wer den Schlüssel hat.";
  if (text.length > ALERT_NOTE_MAX) return `Höchstens ${ALERT_NOTE_MAX} Zeichen.`;
  if (refusesCodes && looksLikeCode(text)) return CODE_REFUSED;
  return null;
}

/** Visual class of a value: "unbekannt" stands out and never looks like "nein" (DOOR1-4). */
export function alertValueTone(value: string | null | undefined): "unknown" | "no" | "yes" | "none" {
  if (value === "unbekannt") return "unknown";
  if (value === "nein") return "no";
  if (value === "ja") return "yes";
  return "none";
}

/** The value as shown: the value itself, or "nicht erfasst" when no value was ever recorded. */
export function alertValueText(value: string | null | undefined): string {
  return value && (ALERT_VALUES as readonly string[]).includes(value) ? value : NOT_RECORDED;
}

export function alertSourceText(source: string | null | undefined): string | null {
  if (!source) return null;
  return `Quelle: ${ALERT_SOURCE_LABEL[source as AlertSource] ?? source}`;
}

const ACTOR_LABEL: Record<string, string> = { me: "von dir", team: "Team", coordination: "Koordination", former: "ehemaliges Mitglied" };

/** "Pflegefachperson A · 25.10.2026 08:10 · Quelle: Angehörige" (who, when, source; DOOR1-4). */
export function alertMetaLine(row: {
  actor_kind: string | null;
  actor_name: string | null;
  recorded_at: string | null;
  source: string | null;
}): string | null {
  if (!row.recorded_at) return null;
  const who = row.actor_kind === "me" ? ACTOR_LABEL.me : row.actor_name ?? ACTOR_LABEL[row.actor_kind ?? ""] ?? "unbekannt";
  const when = new Intl.DateTimeFormat("de-CH", {
    timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).format(new Date(row.recorded_at));
  return [who, when, alertSourceText(row.source)].filter(Boolean).join(" · ");
}

/** HAND1 line of a new value (DOOR1-7): "Schlüssel- und Zugangsregelung: ja · Quelle: Angehörige · <note>". */
export function alertHandoverLines(detail: Record<string, unknown>): string[] {
  const str = (v: unknown) => (typeof v === "string" && v.length > 0 ? v : null);
  const label = str(detail.label) ?? "Sicherheitshinweis";
  return [
    `${label}: ${alertValueText(str(detail.value))}`,
    alertSourceText(str(detail.source)),
    str(detail.note),
  ].filter((l): l is string => Boolean(l));
}

// DOOR1-13 (migration 0080, ADR-093): one "Zugang" line on the card, never two competing records of the same thing.
export const ACCESS_CATEGORY = "access_arrangement";
export const FROM_INTAKE = "aus der Aufnahme";

const dayFormat = new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric" });

/** "25.10.2026" from a date ("2026-10-25") or an instant. */
export function formatDay(value: string): string {
  const date = /^\d{4}-\d{2}-\d{2}$/.test(value) ? new Date(`${value}T12:00:00Z`) : new Date(value);
  return dayFormat.format(date);
}

export type AccessLine =
  | { kind: "value"; value: string; note: string | null; meta: string | null }
  | { kind: "intake"; note: string; meta: string }
  | { kind: "none"; text: typeof NOT_RECORDED };

/**
 * The one "Zugang" line. A recorded access-arrangement value wins (latest value, who, when, source); without one, the
 * intake note "aus der Aufnahme" with the case's intake date; neither: "nicht erfasst".
 */
export function accessLine(input: {
  intakeNote: string | null | undefined;
  intakeOn: string | null | undefined;
  current: { value: string | null; note: string | null; source: string | null; recorded_at: string | null; actor_kind: string | null; actor_name: string | null } | null | undefined;
}): AccessLine {
  const current = input.current;
  if (current?.value) {
    return { kind: "value", value: alertValueText(current.value), note: current.note?.trim() || null, meta: alertMetaLine(current) };
  }
  const note = input.intakeNote?.trim();
  if (note) return { kind: "intake", note, meta: [FROM_INTAKE, input.intakeOn ? formatDay(input.intakeOn) : null].filter(Boolean).join(" · ") };
  return { kind: "none", text: NOT_RECORDED };
}

export type AccessHistoryLine = { value: string | null; note: string | null; meta: string };

/**
 * The history of the access arrangement, newest first; the intake note is its earliest entry (source referral). Shown
 * only once a value exists: before that the intake note is the line itself.
 */
export function accessHistory(
  entries: readonly { value: string | null; note: string | null; source: string | null; recorded_at: string | null; actor_kind: string | null; actor_name: string | null; from_intake: boolean | null }[],
): AccessHistoryLine[] {
  if (!entries.some((e) => !e.from_intake)) return [];
  const values = entries.filter((e) => !e.from_intake);
  const intake = entries.filter((e) => e.from_intake);
  return [
    ...values.map((e) => ({ value: alertValueText(e.value), note: e.note, meta: alertMetaLine(e) ?? "" })),
    ...intake.map((e) => ({
      value: null,
      note: e.note,
      meta: [FROM_INTAKE, e.recorded_at ? formatDay(e.recorded_at) : null, alertSourceText("referral")].filter(Boolean).join(" · "),
    })),
  ];
}
