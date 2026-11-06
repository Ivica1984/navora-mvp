// CGR-139 (`cra` 2026-11-06 01:30, PS-124) / `uxa` UXR-102 (#884), ADR-152: one label for every member picker that
// sets the responsible member of a visit and for the member headings next to it. Pure TypeScript (ADR-002).
//
// Label form confirmed by `cra` (CGR-139 remedy, the CGR-108 form of the handover):
//   * the member's display name;
//   * "<Name> (du)" for the caller, "Ich (du)" when she has no name;
//   * otherwise "Teammitglied <n> (ohne Namen)", <n> being her position in the team ordered by user id: the same number
//     as the handover (`private.member_code`, migration 0033) and /team (`memberLabel`, from `team_cases` members).
// When the position is not known the label says so without a number; a number is never guessed.

export const MEMBER_WITHOUT_NUMBER_TEXT = "Teammitglied (ohne Namen)";

export type PickerMember = { name?: string | null; me?: boolean; no?: number | null };

export function pickerMemberLabel(m: PickerMember): string {
  const named = typeof m.name === "string" ? m.name.trim() : "";
  if (m.me) return named ? `${named} (du)` : "Ich (du)";
  if (named) return named;
  const no = m.no;
  if (typeof no === "number" && Number.isInteger(no) && no > 0) return `Teammitglied ${no} (ohne Namen)`;
  return MEMBER_WITHOUT_NUMBER_TEXT;
}

/**
 * The team position of each member, from 1, in the order given. Pass the `team_cases` members of ONE team: every
 * membership of the team ordered by user id, as `private.member_code` numbers them. A repeated id keeps its first place.
 */
export function memberNumbers(roster: readonly { user_id: string }[]): Map<string, number> {
  const out = new Map<string, number>();
  for (const m of roster) if (!out.has(m.user_id)) out.set(m.user_id, out.size + 1);
  return out;
}
