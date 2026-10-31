// AIG1 part (b) (ADR-129): pure texts and formatting for the proposal screens. No Next or Supabase imports; unit-tested
// (tests/unit/aig1-labels.test.ts). The database decides every rule (migrations 0097, 0103); this only words its answers.
// No clinical rule, threshold or default lives here: the threshold values are read from `agent_health`.

/** AIG1-4: a field the agent did not find is shown as exactly this, never empty, "keine" or a default. */
export const NOT_FOUND_TEXT = "nicht gefunden";

/** Field names as the screen shows them (only fields with a consuming command; ADR-120). */
const FIELD_LABEL: Record<string, string> = {
  responsible_user_id: "Zuständig",
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
  if (von === "vorschlaege") return { href: "/team/vorschlaege", label: "Zurück zu den Vorschlägen" };
  return home;
}

/** AIG1-C2 (a): the record page's line for a listed value (Engineering's wording, open for `uxa`). */
export const RECORD_LOOKBACK_TEXT = "Dieser Wert steht auf der Rückblick-Liste eines gestoppten Assistenten.";
