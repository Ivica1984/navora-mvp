/**
 * PLAN3 (ADR-145): texts of the day-plan proposal. The database returns codes only
 * (`day_plan.reason`, `day_plan.not_found_reason`, `propose_day_plan` refusal reasons).
 * Wording of the reasons, "Vorschlag zurzeit nicht verfügbar", the confirm button and the switch line:
 * brief PLAN3-3, -6, -9, -10. The "kein Vorschlag" limits and the other refusals are Engineering's
 * texts, open for `uxa`.
 */

import { QUAL_NO_PROPOSAL_TEXT } from "@/features/qualification/refusals";

export const DAY_PLAN_REASONS: Readonly<Record<string, string>> = {
  primary_nurse: "Bezugspflegende",
  deputy: "Stellvertretung",
  knows_client: "kennt Klient:in", // UXR-101 (PO 2026-11-06 06:30): no gendered client noun
  free_capacity: "freie Kapazität",
};

export const DAY_PLAN_NOT_FOUND: Readonly<Record<string, string>> = {
  not_active: "kein Vorschlag: kein aktives Teammitglied verfügbar",
  needs_rn: QUAL_NO_PROPOSAL_TEXT.needs_rn, // QUAL1-21 (1): the RN rule has one text (ADR-166)
  absent: "kein Vorschlag: die passenden Mitglieder sind abwesend",
  overlap: "kein Vorschlag: die passenden Mitglieder haben zu dieser Zeit schon einen Einsatz",
};

const UNAVAILABLE = "Vorschlag zurzeit nicht verfügbar";

const REFUSALS: Readonly<Record<string, string>> = {
  agent_off: UNAVAILABLE,
  agent_stopped: UNAVAILABLE,
  team_off: "Der Tagesvorschlag ist für euer Team ausgeschaltet.",
  date_out_of_range: "Ein Vorschlag ist nur für heute und die nächsten 14 Tage möglich.", // UXR-100
  nothing_open: "An diesem Tag ist kein Einsatz offen.",
};

/**
 * The refusal codes `propose_day_plan` returns (0109). PLAN3-15 (0116, ADR-157): `open_proposal` is gone; a fresh
 * request closes the earlier undecided lines instead.
 */
export const DAY_PLAN_REFUSAL_CODES: readonly string[] = Object.keys(REFUSALS);

/** The stated reason of a proposed line, or null for a code the database does not return. */
export function lineReasonText(reason: string, knownVisits: number | null): string | null {
  const text = DAY_PLAN_REASONS[reason];
  if (!text) return null;
  if (reason !== "knows_client") return text;
  const n = knownVisits ?? 0;
  return `${text} (${n} ${n === 1 ? "Besuch" : "Besuche"})`;
}

/** "kein Vorschlag" with the limit the closest member failed. */
export function lineNotFoundText(code: string): string {
  return DAY_PLAN_NOT_FOUND[code] ?? "kein Vorschlag";
}

/** The text for a refused `propose_day_plan` call. */
export function dayPlanRefusalText(reason: string): string {
  return REFUSALS[reason] ?? UNAVAILABLE;
}

/** PLAN3-9: the confirm button names its count; there is no bulk label without one. */
export function confirmButtonLabel(count: number): string {
  if (!Number.isInteger(count) || count < 1) {
    throw new Error("a ticked list of at least one line is required");
  }
  return `${count} ${count === 1 ? "Zuteilung" : "Zuteilungen"} bestätigen`;
}

/** PLAN3-10: "Tagesvorschlag eingeschaltet am <Datum>" from an ISO date, never with a name. */
export function switchedOnLine(isoDate: string | null): string | null {
  if (!isoDate) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(isoDate);
  if (!m) return null;
  return `Tagesvorschlag eingeschaltet am ${m[3]}.${m[2]}.${m[1]}`;
}

/**
 * PLAN3-14 (ADR-146, `cra` CGR-136): on the day-load line of a member who also has visits that day in
 * another team (cover or a second membership). Only that they exist: no count, no client, no time.
 * Wording `uxa` UXR-98 (1) (2026-11-05 19:50): the minutes on the same line count this team only, so the fact says
 * that it is not counted there.
 */
export function otherTeamVisitsLine(hasOtherTeamVisits: boolean | null): string | null {
  return hasOtherTeamVisits === true ? "Dazu Einsätze in anderen Teams, hier nicht mitgezählt." : null;
}
