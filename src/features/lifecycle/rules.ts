// C1 — case and visit lifecycle: reason lists and labels (mirror the database checks, migration 0024).

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

/** Client-side check; the database checks the same. "other" needs a short note. */
export function reasonError(code: string, note: string, allowed: readonly string[]): string | null {
  if (!allowed.includes(code)) return "Bitte einen Grund wählen.";
  if (code === "other" && note.trim().length < 3) return "Bei «Anderer Grund» bitte kurz beschreiben (mind. 3 Zeichen).";
  return null;
}

export const LIFECYCLE_MESSAGES: Record<string, string> = {
  rejected: "Nicht gespeichert: fehlende Berechtigung (zuständiges Team bzw. Operations).",
  wrong_state: "Nicht möglich im aktuellen Zustand (z. B. bereits pausiert, abgesagt oder begonnen).",
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
