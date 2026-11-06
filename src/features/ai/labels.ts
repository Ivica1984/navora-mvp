// AIG1 part (b) (ADR-129): pure texts and formatting for the proposal screens. No Next or Supabase imports; unit-tested
// (tests/unit/aig1-labels.test.ts). The database decides every rule (migrations 0097, 0103); this only words its answers.
// No clinical rule, threshold or default lives here: the threshold values are read from `agent_health`.

import { RESPONSIBLE_LABEL } from "@/features/visits/types";

/** AIG1-4: a field the agent did not find is shown as exactly this, never empty, "keine" or a default. */
export const NOT_FOUND_TEXT = "nicht gefunden";

/** Field names as the screen shows them (only fields with a consuming command; ADR-120). */
const FIELD_LABEL: Record<string, string> = {
  // UXR-79 with UX2-29: the responsible member reads "Verantwortlich" here too (`RESPONSIBLE_LABEL`).
  responsible_user_id: RESPONSIBLE_LABEL,
};

export function fieldLabel(field: string): string {
  return FIELD_LABEL[field] ?? field;
}

/** AIG1-3: the proposing agent, on every proposed value. */
export function proposedByText(agentName: string): string {
  return `vorgeschlagen von ${agentName}`;
}

/** "30.10.2026" in Europe/Zurich (for an instant) or as written (for a date). */
export function formatDate(value: string): string {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [y, m, d] = value.split("-");
    return `${d}.${m}.${y}`;
  }
  return new Intl.DateTimeFormat("de-CH", {
    timeZone: "Europe/Zurich",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(new Date(value));
}

export const hhmm = (t: string | null | undefined): string => (t ? t.slice(0, 5) : "–");

/** AIG1-5 / CGR-78 (b): the bulk button names its count. */
export function bulkConfirmLabel(count: number): string {
  return count === 1 ? "1 angekreuzten Wert bestätigen" : `${count} angekreuzte Werte bestätigen`;
}

/** One row of `value_provenance` (AIG1-3, AIG1-11 (2a)). */
export type Provenance = {
  agent_name: string;
  status: string;
  not_found: boolean;
  confirmer_name: string | null;
  confirmed_at: string | null;
};

/**
 * AIG1-3: "vorgeschlagen von <Agent> / bestätigt von <Name> am <Datum>" for one value. A changed value is hers
 * ("geändert"); a rejection names who rejected it; an undecided value says so. The confirmer is shown only when the
 * database returned one (value_provenance: team members of the record).
 */
export function provenanceLine(p: Provenance): string {
  const proposed = p.not_found ? `${proposedByText(p.agent_name)}: ${NOT_FOUND_TEXT}` : proposedByText(p.agent_name);
  if (!p.confirmed_at || p.status === "offen") return `${proposed} / noch nicht bestätigt`;
  const who = p.confirmer_name ?? "Teammitglied";
  const when = formatDate(p.confirmed_at);
  switch (p.status) {
    case "abgelehnt":
      return `${proposed} / abgelehnt von ${who} am ${when}`;
    case "geändert":
      return `${proposed} / geändert und bestätigt von ${who} am ${when}`;
    default:
      return `${proposed} / bestätigt von ${who} am ${when}`;
  }
}

/** Reasons the consuming command (J3) returns for one value; the value stays open (PLAN3-9, AIG1-15). */
export const REFUSAL_TEXT: Record<string, string> = {
  not_qualified: "Nicht übernommen: Diese Person darf den Einsatz nicht durchführen (Mitgliedschaft oder Qualifikation).",
  outside_contract: "Nicht übernommen: Der Einsatz liegt ausserhalb ihres Vertrags.",
  absent: "Nicht übernommen: Diese Person ist zu dieser Zeit abwesend gemeldet.",
  already_taken: "Nicht übernommen: Der Einsatz hat inzwischen jemand anderes.",
  not_open: "Nicht übernommen: Der Einsatz ist nicht mehr offen.",
  // PLAN3-14 (ADR-146): a day-plan line whose member has an overlapping visit by now, in any team.
  overlap: "Nicht übernommen: Diese Person hat zu dieser Zeit schon einen Einsatz.",
  // PLAN3-15 (ADR-157, 0116): the line was closed by a fresh request for the same day (Engineering text, open for `uxa`).
  replaced: "Nicht übernommen: Für diesen Tag wurde neu vorgeschlagen. Diese Zeile gilt nicht mehr.",
};

export function refusalText(reason: string | null | undefined): string {
  return (reason && REFUSAL_TEXT[reason]) ?? "Nicht übernommen.";
}

// --- AIG1-10 / AIG1-16: the health list -------------------------------------------------------------------------------

export const STATE_LABEL: Record<string, string> = { on: "eingeschaltet", off: "ausgeschaltet", stopped: "gestoppt" };

export function stateLabel(state: string): string {
  return STATE_LABEL[state] ?? state;
}

export function stopReasonText(reason: string | null | undefined): string {
  if (reason === "threshold") return "Korrekturanteil über der Schwelle im abgeschlossenen Fenster";
  if (reason === "version_changed") return "Version, Anbieter oder Region geändert ohne erneutes Einschalten";
  return "–";
}

/** "33,33 %" (Swiss German decimal comma) or "–" when there is no value. */
export function formatShare(share: number | null | undefined): string {
  if (share === null || share === undefined) return "–";
  return `${Number(share).toLocaleString("de-CH", { maximumFractionDigits: 2 })} %`;
}

/** AIG1-16 (2), wording `uxa`'s: whether the last closed window reached the written minimum. */
export function minReachedText(flag: boolean | null | undefined): string {
  // AIG1-C3 wording (PO 2026-10-31 00:10, `uxa` 23:55).
  if (flag === null || flag === undefined) return "Noch kein Fenster abgeschlossen";
  return `Mindestzahl im letzten Fenster erreicht: ${flag ? "ja" : "nein"}`;
}

export function windowText(days: number | null | undefined): string {
  if (!days) return "–";
  return days === 1 ? "1 Tag" : `${days} Tage`;
}

// --- AIG1-12 / -13 / -14: the look-back list (no person, no outcome) -------------------------------------------------

/** AIG1-13 (b) / AIG1-14: a listed value the record no longer holds. */
export function supersededText(at: string | null | undefined): string {
  return at ? `überholt am ${formatDate(at)}` : "überholt";
}

// --- AIG1-C1 / AIG1-C2 / AIG1-C3 (ADR-130): visits no longer open, the record page's re-check actions, back links --------
// Wording adopted by the PO 2026-10-31 00:10 CET from `uxa` 23:55 (`briefs/AIG1.md`).

/** AIG1-C1 (2): a listed value of a visit no longer open, as a fact of the visit (the line already shows its date). */
export const NOT_OPEN_TEXT = "Einsatz nicht mehr offen";

/** AIG1-C1 (2): the same fact where the line carries no date. */
export function notOpenDatedText(visitDate: string | null | undefined): string {
  return visitDate ? `Einsatz vom ${formatDate(visitDate)} nicht mehr offen` : NOT_OPEN_TEXT;
}

/** AIG1-C1 (3): both counts, always side by side, the second also at 0. */
export function lookbackCountsText(open: number, notOpen: number): string {
  return `Werte: ${open} offen · ${notOpen} nicht mehr offen`;
}

/** AIG1-C2 (a): the two one-by-one actions the record page offers for a listed value of a visit still open. */
export const RECORD_ACTIONS = { reconfirm: "Erneut bestätigen", change: "Ändern" } as const;

/** AIG1-C2 (a): the one status line after a successful action. */
export const RECORD_ACTION_DONE = {
  confirmed: "Erneut bestätigt. Der Wert ist nicht mehr auf der Liste.",
  corrected: "Geändert und bestätigt. Der Wert ist nicht mehr auf der Liste.",
} as const;

/**
 * AIG1-C2 (c): the look-back page names only actions the product offers: a value leaves the list through the record
 * page's "Erneut bestätigen" or "Ändern", by a member of the visit's team.
 */
export const LOOKBACK_EXPLANATION =
  "Werte des gestoppten Assistenten, die im Stoppfenster unverändert bestätigt wurden. Ob, von wem und bis wann sie " +
  "nachgeprüft werden müssen, ist noch nicht festgelegt. Ein Wert verlässt die Liste, sobald jemand aus dem Team des " +
  "Einsatzes ihn dort erneut bestätigt oder ändert.";

/** AIG1-C3 (5) / UXR-71: why "Ändern" is unavailable. */
export const NO_OTHER_MEMBER_TEXT = "Kein anderes Teammitglied wählbar.";

/** AIG1-C3 (2) / UXR-66: the result of a ticked confirm names both counts. */
export function bulkResultText(confirmed: number, refused: number): string {
  const done = confirmed === 1 ? "1 Wert bestätigt" : `${confirmed} Werte bestätigt`;
  return refused > 0 ? `${done}, ${refused} nicht übernommen.` : `${done}.`;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * AIG1-C3 (1) / UXR-67: where the record page's back link leads. The origin comes from the link that opened the page
 * (`?von=rueckblick&stopp=<id>` or `?von=vorschlaege`), never from a person; otherwise the role's home.
 */
export function recordBackLink(
  von: string | null | undefined,
  stopId: string | null | undefined,
  home: { href: string; label: string },
): { href: string; label: string } {
  if (von === "rueckblick" && stopId && UUID.test(stopId)) {
    return { href: `/operations/assistenten/rueckblick/${stopId}`, label: "Zurück zur Liste" };
  }
  // PLAN3-11 (ADR-149): opened from the team's own look-back list on `/team`.
  if (von === "team-rueckblick" && stopId && UUID.test(stopId)) {
    return { href: `/team/rueckblick/${stopId}`, label: "Zurück zur Liste" };
  }
  if (von === "vorschlaege") return { href: "/team/vorschlaege", label: "Zurück zu den Vorschlägen" };
  return home;
}

/** AIG1-C2 (a): the record page's line for a listed value (Engineering's wording, open for `uxa`). */
export const RECORD_LOOKBACK_TEXT = "Dieser Wert steht auf der Rückblick-Liste eines gestoppten Assistenten.";

/**
 * PLAN3-12 (ADR-148, `uxa` UXR-68): the entry to `/team/vorschlaege` on `/team`. "Vorschläge (<n>)" with the aria-label
 * "<n> offene Vorschläge" when at least one proposal is open; plain "Vorschläge" at 0 and when the count is unknown (a
 * failed read is never shown as a number). Count only: no name, no deadline word, no colour above `info` (H-20).
 */
export function suggestionsLink(count: number | null): { text: string; ariaLabel: string | undefined } {
  if (count === null || !Number.isInteger(count) || count <= 0) return { text: "Vorschläge", ariaLabel: undefined };
  return { text: `Vorschläge (${count})`, ariaLabel: `${count} offene Vorschläge` };
}

/** PLAN3-12: the sum over the member's teams; unknown (null) as soon as one team's read failed, never a partial sum. */
export function countOpenSuggestions(perTeam: (number | null)[]): number | null {
  let sum = 0;
  for (const n of perTeam) {
    if (n === null) return null;
    sum += n;
  }
  return sum;
}

/**
 * PLAN3-11 (ADR-149): one row of `public.team_lookback_stops()`: a stop of an agent with at least one open look-back line
 * of one of the caller's own teams. Counts only; no person, outcome or confirmer (AIG1-11, AIG1-14).
 */
export type TeamLookbackStop = {
  stop_id: string;
  agent_name: string;
  team_name: string;
  open_count: number;
  not_open_count: number;
};

/**
 * PLAN3-11: the entry on `/team` ("<Agent> gestoppt · Werte: <n> offen · <m> nicht mehr offen", AIG1-C1 count wording)
 * and its one link. No entry at "0 offen" (AIG1-C5 (d)). Link text is Engineering's, open for `uxa`.
 */
export function teamLookbackEntry(s: TeamLookbackStop): { text: string; href: string; linkText: string } | null {
  if (!UUID.test(s.stop_id) || !Number.isInteger(s.open_count) || s.open_count <= 0) return null;
  return {
    text: `${s.agent_name} gestoppt · ${lookbackCountsText(s.open_count, s.not_open_count)}`,
    href: `/team/rueckblick/${s.stop_id}`,
    linkText: "Werte prüfen",
  };
}

/**
 * PLAN3-11: the stop's look-back lines narrowed to the caller's own teams (AIG1-12 (iii)): a coordinator who is also a
 * team member sees on `/team` only her teams' lines; the full list stays on Operations. Never widens; keeps the order.
 */
export function linesOfTeams<T extends { team_id: string }>(lines: T[], teamIds: string[]): T[] {
  const ids = new Set(teamIds);
  return lines.filter((l) => ids.has(l.team_id));
}

/**
 * PLAN3-13 (ADR-150): one row of `public.agent_stop_measures(stop)`: the look-back measure of one team for one stop.
 * Counts of lines only; no person, outcome or confirmer (AIG1-11). A usefulness measure, never a stop criterion.
 */
export type StopMeasure = {
  team_id: string;
  team_name: string;
  lines_at_stop: number;
  left_by_recheck: number;
  superseded: number;
  not_open_at_stop: number;
  became_not_open: number;
  open_now: number;
  days_to_zero_open: number | null;
  proposals_in_window: number;
  lead_time_median_hours: number | null;
};

/** PLAN3-13: "Tage bis 0 offen" only once nothing is open; while lines are open, how many. */
export function daysToZeroText(days: number | null, openNow: number): string {
  if (openNow > 0 || days === null) return `noch ${openNow} offen`;
  if (days === 0) return "am Tag des Stopps";
  return days === 1 ? "1 Tag" : `${days} Tage`;
}

/** PLAN3-13 (AUT-31): the median lead time from proposal to visit; a missing value is "–", never 0. */
export function leadTimeText(hours: number | null, proposals: number): string {
  if (hours === null || hours === undefined) return "–";
  return `${hours} Std. · ${proposals} ${proposals === 1 ? "Vorschlag" : "Vorschläge"}`;
}

/** PLAN3-13: the cells of one team's measure in a fixed order (labels are Engineering's, open for `uxa`). */
export function stopMeasureCells(m: StopMeasure): { key: string; label: string; value: string }[] {
  return [
    { key: "lines_at_stop", label: "Werte beim Stopp", value: String(m.lines_at_stop) },
    { key: "left_by_recheck", label: "Erneut bestätigt oder geändert", value: String(m.left_by_recheck) },
    { key: "superseded", label: "Überholt", value: String(m.superseded) },
    { key: "not_open_at_stop", label: "Beim Stopp nicht mehr offen", value: String(m.not_open_at_stop) },
    { key: "became_not_open", label: "Seither nicht mehr offen", value: String(m.became_not_open) },
    { key: "days_to_zero_open", label: "Tage bis 0 offen", value: daysToZeroText(m.days_to_zero_open, m.open_now) },
    {
      key: "lead_time",
      label: "Vorlauf Vorschlag bis Einsatz (Median)",
      value: leadTimeText(m.lead_time_median_hours, m.proposals_in_window),
    },
  ];
}

/**
 * PLAN3-7 (ADR-151): one team's day-plan measures for one Zurich month, as `plan3_team_measures` (migration 0113, 0114)
 * returns them. Shares in percent. No person, outcome or confirmer column; a suppressed value is null (AIG1-7, AN1).
 */
export type PlanTeamMeasure = {
  team_id: string;
  team_name: string;
  month: string;
  enabled_since: string | null;
  day_plans: number;
  lines: number;
  decided_lines: number | null;
  confirmed_unchanged_share: number | null;
  corrected_share: number | null;
  /** CGR-140 (migration 0114, ADR-153): rejected ÷ decided; with the two shares above it adds up to 100 %. */
  rejected_share: number | null;
  confirm_actions_per_plan: number | null;
  minutes_to_last_decision_median: number | null;
  no_proposal: number | null;
  no_proposal_share: number | null;
  no_proposal_not_active: number | null;
  no_proposal_needs_rn: number | null;
  no_proposal_absent: number | null;
  no_proposal_overlap: number | null;
  proposal_suppressed: boolean;
  continuity_before_share: number | null;
  continuity_before_base: number;
  continuity_after_share: number | null;
  continuity_after_base: number;
  continuity_suppressed: boolean;
  /** PLAN3-15 (0116, ADR-157): requests that closed earlier undecided lines, and the lines closed. Not decisions. */
  requests_closing?: number;
  lines_closed?: number;
};

/** PLAN3-7: the text for a value hidden by the three-person rule (AIG1-7 confirmers, AN1 performers). */
export const SUPPRESSED_TEXT = "nicht ausgewiesen (weniger als 3 Personen)";

const num = (v: number): string => Number(v).toLocaleString("de-CH", { maximumFractionDigits: 1 });

/** PLAN3-7 (AUT-25): "kein Vorschlag" share and count with the four PLAN3-2 limits; a missing value is "–". */
export function noProposalText(
  share: number | null,
  count: number | null,
  byReason: { not_active: number | null; needs_rn: number | null; absent: number | null; overlap: number | null } | null,
): string {
  if (share === null || count === null) return "–";
  const r = byReason;
  const split = r
    ? ` (Nicht verfügbar ${r.not_active ?? 0} · Pflegefachperson nötig ${r.needs_rn ?? 0} · Abwesend ${r.absent ?? 0} · Überschneidung ${r.overlap ?? 0})`
    : "";
  return `${formatShare(share)} · ${count} ${count === 1 ? "Zeile" : "Zeilen"}${split}`;
}

/** PLAN3-7 (AN2 style): continuity before and since the team's switch-on date; missing shares are "–", never 0. */
export function continuityText(
  before: number | null,
  beforeBase: number,
  after: number | null,
  afterBase: number,
  suppressed: boolean,
  enabledSince: string | null,
): string {
  if (suppressed) return SUPPRESSED_TEXT;
  if (!enabledSince) return `nie eingeschaltet · ${formatShare(before)} (${beforeBase})`;
  return `vorher ${formatShare(before)} (${beforeBase}) · seit Einschalten ${formatShare(after)} (${afterBase})`;
}

/**
 * PLAN3-15 (ADR-157): requests that closed earlier undecided lines, apart from the three shares (a closed line is not a
 * decision). A count of the team's requests, not of a confirmer, so the three-person rule does not hide it, as the
 * day-plan count. Wording Engineering's, open for `uxa`. No cell for a row without the 0116 columns.
 */
function replacedCell(m: PlanTeamMeasure): { key: string; label: string; value: string }[] {
  if (m.requests_closing === undefined || m.lines_closed === undefined) return [];
  const r = m.requests_closing;
  const l = m.lines_closed;
  const value = r === 0 && l === 0 ? "keine" : `${r} ${r === 1 ? "Anfrage" : "Anfragen"} · ${l} ${l === 1 ? "Zeile" : "Zeilen"} ersetzt`;
  return [{ key: "replaced", label: "Neu angefragt (frühere offene Zeilen ersetzt)", value }];
}

/** PLAN3-7: the cells of one team's month in a fixed order (labels are Engineering's, open for `uxa`). */
export function planTeamMeasureCells(m: PlanTeamMeasure): { key: string; label: string; value: string }[] {
  const hidden = m.proposal_suppressed;
  const or = (v: string): string => (hidden ? SUPPRESSED_TEXT : v);
  return [
    { key: "day_plans", label: "Tagesvorschläge", value: `${m.day_plans} · ${m.lines} ${m.lines === 1 ? "Zeile" : "Zeilen"}` },
    {
      key: "confirmed_unchanged",
      label: "Unverändert bestätigt",
      value: or(m.confirmed_unchanged_share === null ? "–" : `${formatShare(m.confirmed_unchanged_share)} · ${m.decided_lines ?? 0} entschieden`),
    },
    { key: "corrected", label: "Geändert (Gegenmass)", value: or(formatShare(m.corrected_share)) },
    { key: "rejected", label: "Abgelehnt", value: or(formatShare(m.rejected_share)) }, // CGR-140 (ADR-153)
    ...replacedCell(m),
    {
      key: "actions",
      label: "Bestätigungen pro Tagesvorschlag",
      value: or(m.confirm_actions_per_plan === null ? "–" : num(m.confirm_actions_per_plan)),
    },
    {
      key: "minutes",
      label: "Minuten bis zur letzten Entscheidung (Median)",
      value: or(m.minutes_to_last_decision_median === null ? "–" : `${num(m.minutes_to_last_decision_median)} Min.`),
    },
    {
      key: "no_proposal",
      label: "Kein Vorschlag",
      value: or(
        noProposalText(m.no_proposal_share, m.no_proposal, {
          not_active: m.no_proposal_not_active,
          needs_rn: m.no_proposal_needs_rn,
          absent: m.no_proposal_absent,
          overlap: m.no_proposal_overlap,
        }),
      ),
    },
    {
      key: "continuity",
      label: "Einsätze durch Bezugs- oder Stellvertretungsperson",
      value: continuityText(
        m.continuity_before_share,
        m.continuity_before_base,
        m.continuity_after_share,
        m.continuity_after_base,
        m.continuity_suppressed,
        m.enabled_since,
      ),
    },
  ];
}

/** PLAN3-7 (2) (ADR-155): a failed read of the team's own measures says so; it never reads as zero. */
export const PLAN_TEAM_LINE_ERROR = "Die Zahlen dieses Monats konnten nicht geladen werden.";

/**
 * PLAN3-7 (2) (po 2026-11-06 06:30, `aia` AUT-52; ADR-155): the team's own line under its PLAN3-10 switch on
 * `/team/tagesplan`, from the same row Operations reads. Wording of the brief; open for `uxa`. No target, no other
 * team, no person. With fewer than three confirmers in the month (AIG1-7) the count stays and the shares are hidden.
 * No row, or no day plan in the month: "noch kein Tagesvorschlag", never a 0 % share.
 */
export function planTeamOwnLine(m: PlanTeamMeasure | null | undefined): string {
  if (!m || m.day_plans <= 0) return "Diesen Monat: noch kein Tagesvorschlag";
  const plans = `${m.day_plans} ${m.day_plans === 1 ? "Tagesvorschlag" : "Tagesvorschläge"}`;
  if (m.proposal_suppressed) return `Diesen Monat: ${plans} · Anteile ${SUPPRESSED_TEXT}`;
  return `Diesen Monat: ${plans} · ${formatShare(m.confirmed_unchanged_share)} unverändert bestätigt · ${formatShare(m.no_proposal_share)} ohne Vorschlag`;
}

/** PLAN3-7: `?monat=YYYY-MM` as the first day of that month; otherwise the current Europe/Zurich month. */
export function monthParam(raw: string | undefined, now: Date = new Date()): string {
  if (raw && /^\d{4}-(0[1-9]|1[0-2])$/.test(raw)) return `${raw}-01`;
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Zurich", year: "numeric", month: "2-digit" }).formatToParts(now);
  const y = parts.find((p) => p.type === "year")?.value;
  const mo = parts.find((p) => p.type === "month")?.value;
  return `${y}-${mo}-01`;
}
