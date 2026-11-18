// BK-e1c (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1; R3b, CGR-257, UXR-248; ADR-203 amendment
// BK-e1c). A night visit of the day before that is still running (or was completed today) is on today's /field
// (public.field_visits, migration 0149, flag `carried_from_previous_day`). The day's other readers (notes, report,
// quality, status notes, door notes, «Seit dem letzten Einsatz», alert history) are dated by the visit; for a carried
// card the page reads them for the day before as well and keeps only the rows of the carried visits. Display only.

export type CarriedLike = { visit_id: string; case_id: string | null; carried_from_previous_day?: boolean | null };

/** The carried visits of the day, in list order. */
export function carriedVisits<T extends CarriedLike>(visits: ReadonlyArray<T>): T[] {
  return visits.filter((v) => v.carried_from_previous_day === true);
}

/** The day's rows plus, from the day before, the rows of the carried visits only (never another visit's rows). */
export function withCarriedRows<R extends { visit_id: string | null }>(
  day: ReadonlyArray<R>,
  previousDay: ReadonlyArray<R>,
  carriedIds: ReadonlySet<string>,
): R[] {
  if (carriedIds.size === 0) return [...day];
  const present = new Set(day.map((r) => r.visit_id));
  return [...day, ...previousDay.filter((r) => r.visit_id !== null && carriedIds.has(r.visit_id) && !present.has(r.visit_id))];
}

/**
 * Per-case rows (the access-arrangement history): from the day before, only for cases of carried visits that have no
 * row on this day already, so a case never shows its history twice.
 */
export function withCarriedCaseRows<R extends { case_id: string | null }>(
  day: ReadonlyArray<R>,
  previousDay: ReadonlyArray<R>,
  carriedCaseIds: ReadonlySet<string>,
): R[] {
  if (carriedCaseIds.size === 0) return [...day];
  const present = new Set(day.map((r) => r.case_id));
  return [...day, ...previousDay.filter((r) => r.case_id !== null && carriedCaseIds.has(r.case_id) && !present.has(r.case_id))];
}

/**
 * The line on a carried card (copy PROPOSED, `uxa` decides the exact wording; UXR-248). A running visit: «Läuft seit
 * gestern 22:00». Completed today: «Begonnen gestern 22:00». The line does not change after the planned end (PROPOSED,
 * `uxa` review question 4). No line for a visit that is not carried.
 */
export function carriedLine(carried: boolean | null | undefined, status: string | null, timeStart: string | null): string | null {
  if (carried !== true) return null;
  const hhmm = timeStart ? timeStart.slice(0, 5) : null;
  if (status === "completed") return hhmm ? `Begonnen gestern ${hhmm}` : "Begonnen gestern";
  return hhmm ? `Läuft seit gestern ${hhmm}` : "Läuft seit gestern";
}
