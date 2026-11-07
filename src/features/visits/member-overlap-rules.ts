// PLAN3-16 (ADR-161; PO brief docs/agents/briefs/PLAN3.md PLAN3-16; `cra` CGR-137; `aia` 20:20 condition). Display
// rules only: whether the member a visit is given to already has a visit at that time, in any team, is decided by the
// database (`member_slot_overlap` before saving, `member_overlap` on the command result; migration 0118, pgTAP 119).
// yes/no only: the sentence names no other team, client or time. Information: it never refuses, delays or asks for a
// confirmation, and adds no reason field.

/** The server's answer: true or false; null when there is none (no member, not allowed, incomplete slot, read failed). */
export type MemberOverlapFact = boolean | null;

/** Parses the RPC result (or a command result's `member_overlap`) defensively; anything but a boolean is no answer. */
export function parseMemberOverlap(data: unknown): MemberOverlapFact {
  return typeof data === "boolean" ? data : null;
}

/** Wording `uxa` 2026-11-06 07:50 (PROPOSED; `cra` and `lca` to confirm), for herself. */
export const MEMBER_OVERLAP_SELF_TEXT = "Du hast zu dieser Zeit schon einen Einsatz, in diesem oder einem anderen Team.";

/**
 * The one `info` line under "Verantwortlich". `member.label` is `pickerMemberLabel` (PLAN3-17, without the
 * qualification suffix); `me` when she is the member. No overlap, no answer or no member: no sentence.
 */
export function memberOverlapNote(fact: MemberOverlapFact, member: { label: string; me: boolean } | null): string | null {
  if (fact !== true || !member) return null;
  if (member.me) return MEMBER_OVERLAP_SELF_TEXT;
  const label = member.label.trim();
  if (!label) return null;
  return `${label} hat zu dieser Zeit schon einen Einsatz, in diesem oder einem anderen Team.`;
}

/** After the save: the server's fact is stated only when the form did not show it (VIS2-5 pattern). */
export function memberOverlapAfterSave(shown: boolean, server: MemberOverlapFact): boolean {
  return !shown && server === true;
}
