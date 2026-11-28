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

// UX2-26 (ADR-136, `aia` AUT-21, `uxa` 16:10): the qualification in the same sitting as the contract. The offer calls
// the EXISTING set_member_qualification (0018, patched 0046); nothing here adds a rule, a read scope or a field. The
// membership without qualification is the existing fact ADM2-6 creates (team_memberships.qualification is null), read
// from admin_members.

export const QUALIFICATION_OFFER_TITLE = "Qualifikation festlegen";
export const QUALIFICATION_REASON_LABEL = "Begründung (3–300 Zeichen)";
export const MISSING_QUALIFICATION_HEADING = "Vertrag erfasst, Qualifikation fehlt";

/** The qualifications the administrator may set, in one fixed order: it takes no claim, so the claimed one is never
 * ordered first or marked. */
const OFFER_ORDER = ["registered_nurse", "care_assistant"] as const;
export function qualificationOfferOptions(): string[] {
  return [...OFFER_ORDER];
}

/** The reason rule of set_member_qualification (3-300 characters after trimming). */
export function validQualificationReason(reason: string): boolean {
  const n = reason.trim().length;
  return n >= 3 && n <= 300;
}

export type MissingQualification = { userId: string; email: string; displayName: string; teamId: string; team: string };

type MemberLike = { user_id: string; email: string; display_name: string | null; teams: unknown };
const teamRows = (teams: unknown): { team_id: string; team: string; qualification: string | null }[] =>
  Array.isArray(teams) ? teams.filter(isObj).map((t) => ({
    team_id: String(t.team_id ?? ""), team: String(t.team ?? ""), qualification: typeof t.qualification === "string" ? t.qualification : null,
  })) : [];

/** One entry per member and team whose membership has no qualification yet (input order kept). */
export function membersWithoutQualification(members: MemberLike[]): MissingQualification[] {
  return members.flatMap((m) => teamRows(m.teams)
    .filter((t) => t.qualification === null && t.team_id !== "")
    .map((t) => ({ userId: m.user_id, email: m.email, displayName: m.display_name ?? "", teamId: t.team_id, team: t.team })));
}

/** The member the administrator just recorded: the e-mail she typed and the proposal's team. */
export function findRecordedMember(rows: MissingQualification[], email: string, teamId: string): MissingQualification | null {
  const e = email.trim().toLowerCase();
  if (e === "") return null;
  return rows.find((r) => r.teamId === teamId && r.email.trim().toLowerCase() === e) ?? null;
}
