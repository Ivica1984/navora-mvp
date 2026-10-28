// C1 — case and visit lifecycle: reason lists and labels (mirror the database checks, migration 0024).

import { ROLE_LABEL } from "@/features/admin/rules";
import { QUALIFICATION_LABEL } from "@/features/team/rules";

export const PAUSE_REASONS = ["hospital_stay", "rehabilitation", "client_absence", "other"] as const;
export const CLOSE_REASONS = ["goal_reached", "moved_inpatient", "moved_away", "declined", "died", "other"] as const;
export const CANCEL_REASONS = ["client_cancelled", "client_in_hospital", "team_cancelled", "other"] as const;
export const NO_SHOW_OUTCOMES = ["client_reached", "emergency_contact_informed", "emergency_services_called", "other"] as const;
/** CSR1 / CGR-20 (migration 0042): why a started or paused visit ended without completion. */
export const INTERRUPT_REASONS = ["client_transferred", "client_declined", "nurse_unavailable", "started_by_mistake", "other"] as const;
/** CSR1 / CGR-25 (migration 0045): the follow-up decision after a not-completed end ("other" needs a note). */
export const FOLLOWUP_DECISIONS = ["follow_up_planned", "no_longer_needed", "other"] as const;

/** Visit states from which a visit can be ended as not completed (the database checks the same). */
export function canEndNotCompleted(status: string | null): boolean {
  return status === "started" || status === "paused";
}

export const REASON_LABEL: Record<string, string> = {
  hospital_stay: "Spitalaufenthalt",
  rehabilitation: "Rehabilitation",
  client_absence: "Ferien / Abwesenheit der Klient:in",
  goal_reached: "Pflegeziel erreicht",
  moved_inpatient: "Eintritt stationäre Pflege",
  moved_away: "Umzug",
  declined: "Klient:in lehnt weitere Pflege ab",
  died: "Klient:in verstorben",
  client_cancelled: "Abgesagt durch Klient:in",
  client_in_hospital: "Klient:in im Spital",
  team_cancelled: "Abgesagt durch das Team",
  case_closed: "Fall abgeschlossen",
  client_reached: "Klient:in erreicht",
  emergency_contact_informed: "Notfallkontakt informiert",
  emergency_services_called: "Rettungsdienst alarmiert",
  client_transferred: "Klient:in verlegt bzw. ins Spital gebracht",
  client_declined: "Klient:in lehnt die Fortsetzung ab",
  nurse_unavailable: "Pflegeperson abberufen oder unwohl",
  started_by_mistake: "Irrtümlich gestartet",
  follow_up_planned: "Folgeeinsatz geplant",
  no_longer_needed: "Nicht mehr nötig",
  other: "Anderer Grund",
};

/**
 * CSR1 / CGR-34 (migration 0054): stored by the server on the cancellation of a past planned visit whose responsible
 * member was recorded absent at its time (CGR-32). Fixed text; NAVORA stores no reason for an absence.
 */
export const RESPONSIBLE_ABSENT_NOTE = "nicht durchgeführt: zuständige Person abwesend gemeldet";

/** The cancellation as one line: "Abgesagt (<reason>)", the note, and the CGR-34 fact when stored. */
export function cancellationText(reasonCode: string | null, note: string | null, responsibleAbsent: boolean | null | undefined): string {
  const reason = REASON_LABEL[reasonCode ?? ""] ?? reasonCode ?? "ohne Grund";
  let text = `Abgesagt (${reason})`;
  if (note) text += ` – ${note}`;
  if (responsibleAbsent === true) text += ` · ${RESPONSIBLE_ABSENT_NOTE}`;
  return text;
}

/** Client-side check; the database checks the same. "other" needs a short note. */
export function reasonError(code: string, note: string, allowed: readonly string[]): string | null {
  if (!allowed.includes(code)) return "Bitte einen Grund wählen.";
  if (code === "other" && note.trim().length < 3) return "Bei «Anderer Grund» bitte kurz beschreiben (mind. 3 Zeichen).";
  return null;
}

export const LIFECYCLE_MESSAGES: Record<string, string> = {
  rejected: "Nicht gespeichert: fehlende Berechtigung (zuständiges Team bzw. Operations).",
  wrong_state: "Nicht möglich im aktuellen Zustand (z. B. bereits pausiert, abgesagt oder begonnen).",
  // VIS1 (migration 0089): no-show and "not completed" refuse a visit dated after today.
  not_today: "Dieser Einsatz ist für einen späteren Tag geplant. Wenn du ihn heute machst, verschiebe ihn zuerst auf heute.",
  already_decided: "Schon entschieden: Eine Kollegin oder Operations hat den Entscheid bereits erfasst.",
  invalid: "Bitte die Eingaben prüfen (Grund wählen; Begründung bzw. Notiz mindestens 3 Zeichen).",
  failed: "Konnte nicht gespeichert werden.",
};

/** CSR1 / CGR-20: shown with the not-completed end until the clinical rule (D-31) exists. */
export const INTERRUPT_NOTICE =
  "Hält fest, dass die Pflege abgebrochen wurde – nicht, dass sie erbracht wurde: keine Abrechnung, kein Bericht, nicht als abgeschlossen gezählt. Dokumentation und Abrechnung legt die klinische Leitung fest (D-31); bis dahin gilt diese provisorische Regel.";

/** Shown with the no-show workflow until the clinical on-site protocol (D-19) exists. */
export const NO_SHOW_NOTICE =
  "Die App erfasst und eskaliert an Operations (P1). Das Vorgehen vor Ort legt die klinische Leitung fest (D-19) – bis dahin gelten eure Teamregeln.";

/** CSR1 / CGR-25: shown with the follow-up decision until the clinical rule (D-31) exists. */
export const FOLLOWUP_NOTICE =
  "Hält fest, wie es mit der noch fälligen Pflege weitergeht. «Folgeeinsatz geplant» ist eure Aussage; die App plant nichts. Was ein Folgeentscheid enthalten muss, legt die klinische Leitung fest (D-31); bis dahin gilt diese provisorische Regel.";

/** CSR1 / CGR-25: the follow-up decision of an interrupted visit, if any (one per visit, the database checks the same). */
export function followupOf<T extends { kind: string }>(notes: readonly T[]): T | undefined {
  return notes.find((n) => n.kind === "interruption_followup");
}

/** CSR1 / CGR-25: an interrupted visit without a follow-up decision still waits for a person. */
export function needsFollowup(status: string | null, notes: readonly { kind: string }[]): boolean {
  return status === "interrupted" && !followupOf(notes);
}

/** CSR1 / CGR-26 (migration 0047): who recorded a status note, as the database labels it (never a user id). */
export type NoteActor = {
  actor_kind: string | null;
  actor_name: string | null;
  actor_qualification: string | null;
  actor_role: string | null;
};

/** "Ich", "Anna – Pflegeassistenz", "Teammitglied – Pflegefachperson", "Operations", "nicht mehr im Team". */
export function recordedByLabel(a: NoteActor): string {
  const name = a.actor_name?.trim() || null;
  switch (a.actor_kind) {
    case "me":
      return "Ich";
    case "team": {
      const who = name ?? "Teammitglied";
      const qualification = a.actor_qualification ? QUALIFICATION_LABEL[a.actor_qualification] ?? a.actor_qualification : null;
      return qualification ? `${who} – ${qualification}` : who;
    }
    case "coordination": {
      const role = a.actor_role ? ROLE_LABEL[a.actor_role] ?? a.actor_role : "Koordination";
      return name ? `${name} (${role})` : role;
    }
    case "former":
      return "nicht mehr im Team";
    default:
      return "unbekannt";
  }
}

/** CSR1 / CGR-26: an end recorded by someone other than the reader is shown prominently. */
export function recordedBySomeoneElse(a: NoteActor): boolean {
  return a.actor_kind !== "me";
}

// DOOR1 (migration 0072): two recorded facts of a no-show. Display and record only: neither raises a signal, ranks or
// blocks anything (DOOR1-8). Rows recorded before 0072 carry neither and read "nicht erfasst".

/** DOOR1-6: the basis of a disclosure to an emergency contact (mirrors the database check). */
export const DISCLOSURE_BASES = ["recorded_consent", "emergency", "other"] as const;
export type DisclosureBasis = (typeof DISCLOSURE_BASES)[number];

export const DISCLOSURE_BASIS_LABEL: Record<DisclosureBasis, string> = {
  recorded_consent: "erfasste Einwilligung",
  emergency: "Notfall",
  other: "andere",
};

/** DOOR1-6: only "Notfallkontakt informiert" takes a basis, and then it is required. */
export function outcomeNeedsBasis(outcome: string): boolean {
  return outcome === "emergency_contact_informed";
}

/** Client-side check of an outcome; the database checks the same (22023). */
export function outcomeError(outcome: string, note: string, basis: string | null): string | null {
  if (!(NO_SHOW_OUTCOMES as readonly string[]).includes(outcome)) return "Bitte ein Ergebnis wählen.";
  if (note.trim().length < 3) return "Bitte das Ergebnis kurz beschreiben (mind. 3 Zeichen).";
  if (outcomeNeedsBasis(outcome)) {
    // With "andere" the (required) note says which basis.
    if (!basis || !(DISCLOSURE_BASES as readonly string[]).includes(basis)) return "Bitte die Grundlage wählen (erfasste Einwilligung, Notfall oder andere).";
  } else if (basis) {
    return "Eine Grundlage gibt es nur bei «Notfallkontakt informiert».";
  }
  return null;
}

/** DOOR1-5: "an der Tür: ja / nein / nicht erfasst". */
export function atDoorText(atDoor: boolean | null | undefined): string {
  return `an der Tür: ${atDoor === true ? "ja" : atDoor === false ? "nein" : "nicht erfasst"}`;
}

/** DOOR1-6: "Grundlage: …" for "Notfallkontakt informiert"; null for every other outcome. */
export function basisText(outcome: string | null | undefined, basis: string | null | undefined): string | null {
  if (outcome !== "emergency_contact_informed") return null;
  const label = basis && basis in DISCLOSURE_BASIS_LABEL ? DISCLOSURE_BASIS_LABEL[basis as DisclosureBasis] : "nicht erfasst";
  return `Grundlage: ${label}`;
}

/** DOOR1-1: a note that was not recorded is shown as "nicht erfasst", never blank. */
export function doorNoteText(note: string | null | undefined): string {
  const t = note?.trim();
  return t ? t : "nicht erfasst";
}
