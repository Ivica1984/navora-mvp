// CGR-139 (`cra` 2026-11-06 01:30, PS-124) / `uxa` UXR-102 (#884), ADR-152: one label for every member picker that
// sets the responsible member of a visit and for the member headings next to it. Pure TypeScript (ADR-002).
//
// Label form confirmed by `cra` (CGR-139 remedy, the CGR-108 form of the handover):
//   * the member's display name;
//   * "<Name> (du)" for the caller, "Ich (du)" when she has no name;
//   * otherwise "Teammitglied <n> (ohne Namen)", <n> being her position in the team ordered by user id: the same number
//     as the handover (`private.member_code`, migration 0033) and /team (`memberLabel`, from `team_cases` members).
// When the position is not known the label says so without a number; a number is never guessed.

import { QUALIFICATION_LABEL } from "./rules";

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

export type RosterMember = { user_id: string; me: boolean; name?: string | null; qualification?: string | null };

/**
 * UXR-113 (ADR-154): the options of a picker over ONE team's `team_cases` members (every membership ordered by user id),
 * as the /team "Neuer Einsatz" → "Verantwortlich" picker needs them: `pickerMemberLabel` with the member's /team
 * position, then " – <Qualifikation>" when one is recorded. A repeated id is listed once, at its first place.
 */
export function teamPickerOptions(roster: readonly RosterMember[]): { value: string; label: string }[] {
  const numbers = memberNumbers(roster);
  const seen = new Set<string>();
  const out: { value: string; label: string }[] = [];
  for (const m of roster) {
    if (seen.has(m.user_id)) continue;
    seen.add(m.user_id);
    const base = pickerMemberLabel({ name: m.name, me: m.me, no: numbers.get(m.user_id) ?? null });
    const q = m.qualification ? ` – ${QUALIFICATION_LABEL[m.qualification] ?? m.qualification}` : "";
    out.push({ value: m.user_id, label: base + q });
  }
  return out;
}
