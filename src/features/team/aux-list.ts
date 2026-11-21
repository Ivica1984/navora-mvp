// PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 2026-11-21 20:39 (1)-(3), CGR-272, CGR-273).
// An auxiliary hint list that cannot be loaded never takes down the page it sits on, and is never dropped silently:
// the page keeps its day view and commands and shows one notice line where the list would be. Pure; no I/O.
// Safety lists (field_safety_alerts and any list `cra` names) are NOT auxiliary lists: they stay fail-hard (CGR-273).

/** Working wording from the brief (2); final wording at the `uxa` gate, content check by `cra`. */
export const VISIT_ALERTS_UNAVAILABLE_NOTICE = "Hinweise zu Einsätzen konnten nicht geladen werden.";

/** The only lists that may degrade (fail closed: an unknown list is not degradable). Mirrors migration 0165. */
export const DEGRADABLE_LISTS = ["team_visit_alerts"] as const;
export type DegradableList = (typeof DEGRADABLE_LISTS)[number];

/** A loaded list, or the fact that it could not be loaded. `unavailable` rows are always empty, never a partial list. */
export type AuxList<T> = { rows: T[]; unavailable: boolean };

export function loaded<T>(rows: T[] | null | undefined): AuxList<T> {
  return { rows: rows ?? [], unavailable: false };
}

export function unavailable<T>(): AuxList<T> {
  return { rows: [], unavailable: true };
}

/** CGR-272: the notice is shown on every render while the load fails, and only then. */
export function showsUnavailableNotice(list: AuxList<unknown>): boolean {
  return list.unavailable;
}
