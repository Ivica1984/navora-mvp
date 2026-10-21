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
 * assigned/accepted/cancelled/no_show wait for owner decision D-6.
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
    else if (v.status !== "cancelled" && v.status !== "no_show") open += 1;
  }
  return { total: visits.length, open, running, done };
}
