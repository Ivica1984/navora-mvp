/**
 * QUAL1 part 1 (brief docs/agents/briefs/QUAL1.md, ADR-163, migration 0120): words for `private.qual_check` rows.
 * The four CR-183 values are internal result codes (QUAL1-17 as amended 2026-11-07 04:45), never screen text. Reasons
 * follow the brief's S1-S8 and matrix v0.2 §7; QUAL1-21 (4), ADR-166: they name the activity in words (`label_de` of
 * `qual_activities`, matrix v0.2) and dates, never a code and never a client datum. Every rule behind them is PROPOSED
 * (simulation organisations only). Unknown values fail closed: they read "ungeklärt" and allow nothing.
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
  /** The activity in words (`qual_activities.label_de`); the reader joins it. Without it the text stays neutral. */
  activity_label?: string | null;
  result: QualResult;
  label: string;
  /** null for a colleague (CGR-152: the evidence reason is the member's and the administrators' only). */
  reason: string | null;
  matrix_version: string;
  rule_status: string | null;
  delegation_until: string | null;
};

import { QUAL_PROVISIONAL_HEADER, QUAL_PROVISIONAL_WORDING } from "./refusals";

/** QUAL1-14, QUAL1-21 (4): one provisional wording on every screen. */
export const SIMULATION_BANNER = `Simulation · synthetische Daten · ${QUAL_PROVISIONAL_HEADER}`;

export type QualLabel = "geeignet" | "geeignet mit Delegation" | "nicht geeignet" | "ungeklärt";

/** The CR-183 result code (internal; QUAL1-21 (3): never shown as a verdict on a person). */
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

/** ": Ausbildung" etc.; empty when the reason is withheld (CGR-152) or unknown. */
function requirementSuffix(reason: string | null): string {
  const word = reason ? REQUIREMENT_WORDS[reason.split(":")[0]] : undefined;
  return word ? `: ${word}` : "";
}

function swissDate(isoDate: string | null): string {
  if (!isoDate || !/^\d{4}-\d{2}-\d{2}/.test(isoDate)) return "unbekannt";
  const [y, m, d] = isoDate.slice(0, 10).split("-");
  return `${d}.${m}.${y}`;
}

/** The activity in words, or a neutral phrase; never the matrix code (QUAL1-21 (4)). */
function activityWords(row: QualCheckRow): string {
  const label = row.activity_label?.trim();
  return label ? label : "eine Tätigkeit dieses Einsatzes";
}

export function qualReason(row: QualCheckRow): string {
  const act = activityWords(row);
  switch (row.result) {
    case "allowed_own":
      return "eigener Kompetenzbereich";
    case "allowed_delegated":
      return `Delegation gültig bis ${swissDate(row.delegation_until)}`;
    case "not_allowed":
      return `nicht im Kompetenzbereich erfasst: ${act}`;
    case "unresolved":
      // The open question number (e.g. a K-n code) stays in the register; the text names only the activity.
      return `${QUAL_PROVISIONAL_WORDING} noch offen: ${act}`;
    case "evidence_missing":
      return `Nachweis fehlt${requirementSuffix(row.reason)}`;
    case "evidence_expired":
      return `Voraussetzung abgelaufen${requirementSuffix(row.reason)}`;
    case "evidence_contradictory":
      return "Nachweise widersprüchlich";
    case "delegation_missing":
      return `Delegation fehlt: ${act}`;
    case "delegation_expired":
      return `Delegation abgelaufen am ${swissDate(row.delegation_until)}: ${act}`;
    case "delegation_review_needed":
      return `Delegation: Überprüfung nötig (${act})`;
    default:
      return `${QUAL_PROVISIONAL_WORDING} noch offen: ${act}`;
  }
}
