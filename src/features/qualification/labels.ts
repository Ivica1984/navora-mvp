/**
 * QUAL1 part 1 (brief docs/agents/briefs/QUAL1.md, ADR-163, migration 0120): words for `private.qual_check` rows.
 * The four labels are CR-183's. Reasons follow the brief's S1-S8 and matrix v0.2 §7; they name activity codes and
 * dates only, never a client datum. Every rule behind them is PROPOSED (simulation organisations only).
 * Unknown values fail closed: they read "ungeklärt" and allow nothing.
 */

export const QUAL_RESULTS = [
  "allowed_own",
  "allowed_delegated",
  "not_allowed",
  "unresolved",
  "evidence_missing",
  "evidence_expired",
  "evidence_contradictory",
  "delegation_missing",
  "delegation_expired",
  "delegation_review_needed",
] as const;

export type QualResult = (typeof QUAL_RESULTS)[number];

export type QualCheckRow = {
  activity_code: string | null;
  result: QualResult;
  label: string;
  reason: string;
  matrix_version: string;
  rule_status: string | null;
  delegation_until: string | null;
};

export const SIMULATION_BANNER = "Simulation · synthetische Daten · Regeln PROPOSED";

export type QualLabel = "geeignet" | "geeignet mit Delegation" | "nicht geeignet" | "ungeklärt";

export function qualLabel(result: QualResult): QualLabel {
  switch (result) {
    case "allowed_own":
      return "geeignet";
    case "allowed_delegated":
      return "geeignet mit Delegation";
    case "not_allowed":
      return "nicht geeignet";
    default:
      return "ungeklärt";
  }
}

/** CR-183: only `geeignet` and `geeignet mit Delegation` allow the member to be responsible. */
export function allowsResponsibility(result: QualResult): boolean {
  return result === "allowed_own" || result === "allowed_delegated";
}

const REQUIREMENT_WORDS: Record<string, string> = {
  grade: "Ausbildung",
  practice_licence: "Berufsausübungsbewilligung",
  experience_2y: "Berufserfahrung (2 Jahre)",
  experience_psych_2y: "Psychiatrische Berufserfahrung (2 Jahre)",
  instruction_record: "Instruktion",
};

function requirementWord(reason: string): string {
  const key = reason.split(":")[0];
  return REQUIREMENT_WORDS[key] ?? "Nachweis";
}

function swissDate(isoDate: string | null): string {
  if (!isoDate || !/^\d{4}-\d{2}-\d{2}/.test(isoDate)) return "unbekannt";
  const [y, m, d] = isoDate.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
}

export function qualReason(row: QualCheckRow): string {
  const act = row.activity_code ?? "–";
  switch (row.result) {
    case "allowed_own":
      return "eigener Kompetenzbereich";
    case "allowed_delegated":
      return `Delegation gültig bis ${swissDate(row.delegation_until)}`;
    case "not_allowed":
      return `${act} nicht im Kompetenzbereich`;
    case "unresolved": {
      const open = row.reason.startsWith("cell:?:") ? row.reason.slice("cell:?:".length) : null;
      return `Regel ungeklärt (${act}, PROPOSED ?${open ? `, ${open}` : ""})`;
    }
    case "evidence_missing":
      return `Nachweis fehlt: ${requirementWord(row.reason)}`;
    case "evidence_expired":
      return `Voraussetzung abgelaufen: ${requirementWord(row.reason)}`;
    case "evidence_contradictory":
      return "Nachweise widersprüchlich";
    case "delegation_missing":
      return `Delegation fehlt (${act})`;
    case "delegation_expired":
      return `Delegation ${act} abgelaufen am ${swissDate(row.delegation_until)}`;
    case "delegation_review_needed":
      return `Delegation ${act}: Überprüfung nötig`;
    default:
      return "Regel ungeklärt";
  }
}
