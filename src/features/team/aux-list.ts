// PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 2026-11-21 20:39 (1)-(3), CGR-272, CGR-273).
// An auxiliary hint list that cannot be loaded never takes down the page it sits on, and is never dropped silently:
// the page keeps its day view and commands and shows one notice line where the list would be. Pure; no I/O.
// Safety lists (field_safety_alerts and any list `cra` names) are NOT auxiliary lists: they stay fail-hard (CGR-273).

/** Headline from the brief (2); final wording at the `uxa` gate, content check by `cra`. */
export const VISIT_ALERTS_UNAVAILABLE_NOTICE = "Hinweise zu Einsätzen konnten nicht geladen werden.";
/** UXR-276 (`uxa` early review 2026-11-22 01:30, wording verbatim): what may be missing. */
export const VISIT_ALERTS_UNAVAILABLE_MISSING =
  "Es können offene Punkte fehlen, z. B. nicht erfolgte Einsätze oder Folgeentscheide nach einem Abbruch.";
/** CGR-277 (`cra` pre-gate 2026-11-22 01:30): point to the safety signals and the team. `eng` wording, an instruction,
 *  not a promise that the signals hold every missing entry (not every degraded type is a signal); `uxa`/`cra` gate. */
export const VISIT_ALERTS_UNAVAILABLE_NEXT = "Achte auf die Sicherheitssignale und frag im Zweifel im Team nach.";
/** UXR-276: the one action to read again (DESIGN_SYSTEM §1). */
export const VISIT_ALERTS_RELOAD_LABEL = "Erneut laden";

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
