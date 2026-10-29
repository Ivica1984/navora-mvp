// ADM2 part (a): the team admits its colleagues (migration 0091, ADR-114). Pure helpers and labels, no Next or
// Supabase imports. The database decides every rule (consent count, objection, lapse); these helpers only read and
// word its result.

export const PENSUM_BANDS = ["20-40", "40-60", "60-80", "80-100"] as const;
export type PensumBand = (typeof PENSUM_BANDS)[number];

export const CLAIMED_QUALIFICATIONS = ["registered_nurse", "care_assistant"] as const;

/** ADM2-3: the fixed objection codes (no free text). */
export const OBJECTION_REASONS = ["team_full", "availability_mismatch", "qualification_mix", "wants_to_meet_first"] as const;
export type ObjectionReason = (typeof OBJECTION_REASONS)[number];

export const OBJECTION_LABEL: Record<ObjectionReason, string> = {
  team_full: "Team ist voll",
  availability_mismatch: "Verfügbarkeit passt nicht",
  qualification_mix: "Qualifikationsmix passt nicht",
  wants_to_meet_first: "Möchte sie zuerst kennenlernen",
};

export const DECISIONS = ["consent", "objection", "withdraw_objection", "withdraw_proposal"] as const;
export type Decision = (typeof DECISIONS)[number];

/** Messages for the command results of migration 0091. */
export const ADMISSION_MESSAGES: Record<string, string> = {
  invalid: "Bitte die Angaben prüfen.",
  failed: "Die Änderung konnte nicht gespeichert werden.",
  rejected: "Das dürfen nur aktive Mitglieder dieses Teams.",
  admission_off: "Die Aufnahme durch das Team ist in deiner Organisation nicht eingeschaltet.",
  own_proposal: "Deinem eigenen Vorschlag stimmst du nicht selbst zu.",
  not_proposer: "Nur wer vorgeschlagen hat, kann den Vorschlag zurückziehen.",
  no_objection: "Du hast keinen Einwand erhoben.",
  closed: "Über diesen Vorschlag ist schon entschieden.",
  unchanged: "Keine Änderung.",
  not_admitted: "Der Vorschlag ist (noch) nicht vom Team aufgenommen.",
  unknown_user: "Dieses Konto gibt es nicht. Bitte zuerst das Konto anlegen.",
  already_member: "Sie ist schon Mitglied dieses Teams.",
  access_ended: "Der Zugang dieser Person ist beendet.",
};

export const ADMIN_ADMISSION_REJECTED = "Nur die Administration dieser Organisation darf das.";

export type Outcome = "admitted" | "withdrawn" | "lapsed" | "contract_recorded";

export const OUTCOME_LABEL: Record<string, string> = {
  open: "offen",
  admitted: "vom Team aufgenommen",
  withdrawn: "zurückgezogen",
  lapsed: "verfallen",
  contract_recorded: "Vertrag erfasst",
};

export type TeamProposal = {
  proposal_id: string;
  created_at: string;
  lapses_at: string;
  proposed_by_me: boolean;
  proposer_name: string | null;
  display_name: string;
  claimed_qualification: string;
  pensum_band: string;
  outcome: Outcome | null;
  consents: number;
  needed: number;
  objections: number;
  objection_reasons: ObjectionReason[];
  my_stance: "consent" | "objection" | "objection_withdrawn" | null;
  my_reason: ObjectionReason | null;
};

export type TeamAdmissions = {
  enabled: boolean;
  consents_needed: number;
  lapse_days: number;
  proposals: TeamProposal[];
};

export type AdminProposal = {
  proposal_id: string;
  team_id: string;
  team: string;
  created_at: string;
  outcome: "open" | Outcome;
  outcome_at: string | null;
  display_name: string | null;
  claimed_qualification: string | null;
  pensum_band: string | null;
};

export type AdminAdmissions = { enabled: boolean; proposals: AdminProposal[] };

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

/** Reads `team_admissions(team)`; null when the caller may not read it (the database returns null). */
export function readTeamAdmissions(raw: unknown): TeamAdmissions | null {
  if (!isObj(raw)) return null;
  const proposals = Array.isArray(raw.proposals) ? (raw.proposals.filter(isObj) as unknown as TeamProposal[]) : [];
  return {
    enabled: raw.enabled === true,
    consents_needed: typeof raw.consents_needed === "number" ? raw.consents_needed : 2,
    lapse_days: typeof raw.lapse_days === "number" ? raw.lapse_days : 14,
    proposals,
  };
}

/** Reads `admin_team_admissions(org)`; null for a non-administrator. */
export function readAdminAdmissions(raw: unknown): AdminAdmissions | null {
  if (!isObj(raw)) return null;
  const proposals = Array.isArray(raw.proposals) ? (raw.proposals.filter(isObj) as unknown as AdminProposal[]) : [];
  return { enabled: raw.enabled === true, proposals };
}

/** "1 von 2 Zustimmungen" — the count the database computed (other active members only). */
export function consentLine(p: Pick<TeamProposal, "consents" | "needed">): string {
  return `${p.consents} von ${p.needed} Zustimmung${p.needed === 1 ? "" : "en"}`;
}

/** What the reader can do on an open proposal; the database refuses everything else anyway. */
export function availableDecisions(p: Pick<TeamProposal, "outcome" | "proposed_by_me" | "my_stance">): Decision[] {
  if (p.outcome !== null) return [];
  if (p.proposed_by_me) return ["withdraw_proposal"];
  if (p.my_stance === "objection") return ["withdraw_objection"];
  if (p.my_stance === "consent") return ["objection"];
  return ["consent", "objection"];
}

/** Admitted proposals wait for the administrator's "Vertrag erfasst". */
export function awaitingContract(rows: AdminProposal[]): AdminProposal[] {
  return rows.filter((r) => r.outcome === "admitted");
}

/** A Zurich calendar date (YYYY-MM-DD) for an instant, for "verfällt am". */
export function zurichDate(iso: string): string {
  const parts = new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", day: "2-digit", month: "2-digit", year: "numeric" })
    .formatToParts(new Date(iso));
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("day")}.${get("month")}.${get("year")}`;
}
