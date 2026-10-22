// C1 — case and visit lifecycle: reason lists and labels (mirror the database checks, migration 0024).

export const PAUSE_REASONS = ["hospital_stay", "rehabilitation", "client_absence", "other"] as const;
export const CLOSE_REASONS = ["goal_reached", "moved_inpatient", "moved_away", "declined", "died", "other"] as const;
export const CANCEL_REASONS = ["client_cancelled", "client_in_hospital", "team_cancelled", "other"] as const;
export const NO_SHOW_OUTCOMES = ["client_reached", "emergency_contact_informed", "emergency_services_called", "other"] as const;

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
  invalid: "Bitte die Eingaben prüfen (Grund wählen; Begründung bzw. Notiz mindestens 3 Zeichen).",
  failed: "Konnte nicht gespeichert werden.",
};

/** Shown with the no-show workflow until the clinical on-site protocol (D-19) exists. */
export const NO_SHOW_NOTICE =
  "Die App erfasst und eskaliert an Operations (P1). Das Vorgehen vor Ort legt die klinische Leitung fest (D-19) – bis dahin gelten eure Teamregeln.";
