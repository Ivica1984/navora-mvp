/**
 * QUAL1-21 (brief docs/agents/briefs/QUAL1.md, PO 2026-11-07 04:45; `uxa` UXR-129 to -133; ADR-166): one text per
 * QUAL1 refusal or proposal reason, used on every path (hand assignment, move, take, swap, cover, AIG1 confirm, day plan,
 * PLAN2 series, visit start). Only the subject changes ("<Name>" / "dich" / "die gewählte Person").
 *
 * - No verdict on a person while the rules are PROPOSED: the text says what the visit needs and what is not recorded.
 * - No register, matrix or rule code, no "PROPOSED": the provisional status is one wording, `QUAL_PROVISIONAL_WORDING`.
 * - No reason detail about the member's evidence (CGR-152): the database detail is never shown.
 * - At visit start only what is decided: nothing was written and the visit stays planned. Release on lapse (QUAL1-17
 *   second half) is PLANNED; who confirms a lapsed evidence is UNKNOWN until D-43 and is not named.
 *
 * Words PROPOSED (`uxa`); `cra` to confirm "Pflegefachperson" and the phrasing before any screen ships.
 * Pure module (unit-tested in tests/unit/qual1-21-one-text.test.ts).
 */

export const QUAL_PROVISIONAL_WORDING = "vorläufige Regel";
export const QUAL_PROVISIONAL_HEADER = "Regel vorläufig, nicht fachlich freigegeben";

export const QUAL_REASON_CODES = [
  "qualification_not_allowed", // 0121 backstop (42501)
  "qualification_lapsed", // 0121 start check (42501)
  "needs_rn", // J3 RN rule (CR-007/CR-009), PLAN3 proposal reason
  "evidence_missing",
  "rule_unresolved",
  "delegation_missing",
  "not_member",
  "not_qualified", // J3 consumer refusal in the AIG1 confirm (membership or qualification)
] as const;

export type QualReasonCode = (typeof QUAL_REASON_CODES)[number];

export type QualSubject = { kind: "self" } | { kind: "member"; name: string } | { kind: "chosen" };

/** Where the refusal is shown: an assignment write, the visit start, her own take/cover, a ticked AIG1 value. */
export type QualContext = "save" | "start" | "take" | "confirm";

/** The subject after "für" (accusative). An empty name falls back to the neutral subject. */
function subjectWords(subject: QualSubject): string {
  if (subject.kind === "self") return "dich";
  if (subject.kind === "member" && subject.name.trim() !== "") return subject.name.trim();
  return "die gewählte Person";
}

/** "für X" at the start of a sentence reads "Für X". */
const REASON_TEMPLATES: Readonly<Record<QualReasonCode, (s: string) => string>> = {
  qualification_not_allowed: (s) =>
    `Für ${s} ist für mindestens eine Tätigkeit dieses Einsatzes nicht alles erfasst, was die ${QUAL_PROVISIONAL_WORDING} verlangt.`,
  qualification_lapsed: (s) =>
    `Zum Start ist für ${s} für mindestens eine Tätigkeit dieses Einsatzes nicht mehr alles erfasst, was die ${QUAL_PROVISIONAL_WORDING} verlangt (Nachweis oder Delegation).`,
  needs_rn: (s) => `Dieser Einsatz verlangt eine Pflegefachperson; für ${s} ist das nicht erfasst.`,
  evidence_missing: (s) => `Für ${s} ist ein Nachweis nicht erfasst, den die ${QUAL_PROVISIONAL_WORDING} für diesen Einsatz verlangt.`,
  rule_unresolved: (s) =>
    `Für eine Tätigkeit dieses Einsatzes ist die ${QUAL_PROVISIONAL_WORDING} noch offen; deshalb ist für ${s} nichts als erfüllt erfasst.`,
  delegation_missing: (s) => `Für ${s} ist keine gültige Delegation für eine Tätigkeit dieses Einsatzes erfasst.`,
  not_member: (s) => `Für ${s} ist keine Mitgliedschaft in diesem Team erfasst.`,
  not_qualified: (s) => `Für ${s} ist nicht erfasst, was dieser Einsatz verlangt (Teammitgliedschaft oder Qualifikation).`,
};

/** Fail closed: an unknown reason claims nothing about the person. */
const UNKNOWN_TEMPLATE = (s: string) => `Für ${s} ist nicht erfasst, was dieser Einsatz verlangt.`;

/** The one sentence for a QUAL1 reason; only the subject differs between paths. */
export function qualReasonText(reason: QualReasonCode, subject: QualSubject): string {
  const template = (REASON_TEMPLATES as Record<string, ((s: string) => string) | undefined>)[reason] ?? UNKNOWN_TEMPLATE;
  return template(subjectWords(subject));
}

const PREFIX: Readonly<Record<QualContext, string>> = {
  save: "Nicht gespeichert: ",
  start: "Nicht begonnen: ",
  take: "Nicht übernommen: ",
  confirm: "Nicht übernommen: ",
};

/** The next step, only what is decided (QUAL1-21 (5)); none in the AIG1 list, whose value simply stays open. */
const NEXT_STEP: Readonly<Record<QualContext, string>> = {
  save: " Bitte eine andere Person wählen oder den Einsatz offen im Team lassen.",
  start: " Der Einsatz bleibt geplant; bitte im Team klären, wer übernimmt.",
  take: " Eine andere Person aus dem Team kann ihn übernehmen.",
  confirm: "",
};

/** A command's refusal text: what happened, the reason sentence, the decided next step. */
export function qualRefusalText(reason: QualReasonCode, subject: QualSubject, context: QualContext): string {
  return `${PREFIX[context]}${qualReasonText(reason, subject)}${NEXT_STEP[context]}`;
}

/** Day-plan "no proposal" lines (PLAN3): the team, not a person, is the subject. */
export const QUAL_NO_PROPOSAL_TEXT = {
  needs_rn: "kein Vorschlag: keine Pflegefachperson verfügbar",
} as const satisfies Partial<Record<QualReasonCode, string>>;
