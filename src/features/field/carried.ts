// BK-e1c (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, UXR-248, CGR-257; ADR-203 (22)).
// A running night visit of the previous day is listed on the carer's next day by `public.field_visits` (migration 0149,
// `carried_from_previous_day`). Display only: which visits exist and what a command may do stay with the database.
import { zurichDate, zurichTime, type VisitEvent } from "./time";

export type CarriedLike = { visit_id: string; carried_from_previous_day?: boolean | null };

/** The ids of the visits the database carried over from the previous day. */
export function carriedVisitIds(visits: ReadonlyArray<CarriedLike>): Set<string> {
  return new Set(visits.filter((v) => v.carried_from_previous_day === true).map((v) => v.visit_id));
}

/**
 * The per-day companion rows (notes, report, quality, status notes, door facts, since-last) of a carried visit are
 * dated by its own day, so the page reads them from the previous day too and keeps only the carried visits' rows.
 * Rows already present for a key (a visit, or a case for the alert history) are never duplicated.
 */
export function withCarriedRows<T>(
  current: ReadonlyArray<T>,
  previous: ReadonlyArray<T>,
  carried: ReadonlySet<string>,
  key: (row: T) => string | null,
): T[] {
  if (carried.size === 0) return [...current];
  const present = new Set(current.map(key));
  return [
    ...current,
    ...previous.filter((r) => {
      const k = key(r);
      return k !== null && carried.has(k) && !present.has(k);
    }),
  ];
}

/**
 * The line on a carried card (copy PROPOSED by `uxa`, UXR-248): since when the visit runs. The recorded start is used
 * when there is one; started on the visit's own day reads «gestern», started after midnight reads the time only.
 * Without a recorded start (a paused visit always has one) the planned start is used.
 */
export function carriedLine(events: ReadonlyArray<VisitEvent>, visitDate: string, timeStart: string | null): string {
  const started = events.find((e) => e.type === "started");
  if (started) {
    const time = zurichTime(started.at);
    return zurichDate(started.at) === visitDate ? `Läuft seit gestern ${time}` : `Läuft seit ${time}`;
  }
  return timeStart ? `Läuft seit gestern ${timeStart.slice(0, 5)}` : "Läuft seit gestern";
}

/**
 * After «Einsatz abschliessen» on a carried card the visit is no longer running, so day 2 no longer lists it; the
 * carer is taken to the visit's own day, where it and its report draft stay (PROPOSED, `uxa`). Null: stay.
 */
export function afterCompleteHref(visit: { carried_from_previous_day?: boolean | null; visit_date: string }): string | null {
  return visit.carried_from_previous_day === true ? `/field?datum=${visit.visit_date}` : null;
}
