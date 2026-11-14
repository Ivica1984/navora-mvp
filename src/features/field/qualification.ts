// UX2-22 (uxa UXR-45, cra 13:40 PR #666: hide; uxa 16:10: one line; ADR-124): no field action she cannot perform.
// Pure module (unit-tested). The server refusal (ADM2-16, migration 0094, `qualification_missing`) stays the guard;
// this only stops the screen offering a control the database always refuses her.

import type { FieldAction } from "./rules";

/** One of her own `team_memberships` rows (RLS read_own_team_membership; no new read scope). */
export type OwnMembership = { team_id: string; qualification: string | null };

/**
 * Text of "Offen im Team" for a member without a recorded qualification (uxa 16:10, taken in by po 16:24).
 * No client name, time, toggle or "Übernehmen" beside it.
 */
export const OPEN_VISITS_UNQUALIFIED_TEXT = "Offene Einsätze übernehmen Teammitglieder mit erfasster Qualifikation.";

/**
 * The commands ADM2-16 refuses without a recorded qualification: depart, start, resume and complete (0094
 * `visit_qualification_refusal`). Pause is not refused by the database (0094 "unchanged: pause"), so it stays.
 */
const REFUSED_WITHOUT_QUALIFICATION: ReadonlySet<FieldAction> = new Set(["depart", "start", "resume", "complete"]);

/** Teams in which her own membership row has no qualification (the ADM2-6 state before set_member_qualification). */
export function teamsWithoutQualification(rows: readonly OwnMembership[]): string[] {
  return [...new Set(rows.filter((r) => r.qualification === null).map((r) => r.team_id))].sort();
}

/**
 * The field actions a card offers her. A visit of a team where her qualification is missing loses every action the
 * database refuses her (hide, `cra` 13:40). A visit of another team (e.g. one she covers) is left to the server, which
 * checks the cover team (0094 `actor_may_perform_visit`).
 */
export function actionsForMember(actions: readonly FieldAction[], visitTeamId: string | null, unqualified: readonly string[]): FieldAction[] {
  if (!visitTeamId || !unqualified.includes(visitTeamId)) return [...actions];
  return actions.filter((a) => !REFUSED_WITHOUT_QUALIFICATION.has(a));
}

/**
 * "Offen im Team" split for her: visits of teams where her qualification is recorded stay as built; visits of teams
 * where it is missing are withheld, and the section then shows only the one line (`withheld > 0` and nothing left).
 */
export function splitOpenVisits<T extends { team_id: string | null }>(open: readonly T[], unqualified: readonly string[]): { shown: T[]; withheld: number } {
  const shown = open.filter((o) => !o.team_id || !unqualified.includes(o.team_id));
  return { shown, withheld: open.length - shown.length };
}
