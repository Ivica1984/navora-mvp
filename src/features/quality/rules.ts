// QG1 — quality events and holds: pure helpers (ADR-002). Rules live in the database (migration 0020).

export const SEVERITIES = ["low", "medium", "high", "critical"] as const;
export type Severity = (typeof SEVERITIES)[number];

export const SEVERITY_LABEL: Record<Severity, string> = {
  low: "gering",
  medium: "mittel",
  high: "hoch",
  critical: "kritisch",
};

export const EVENT_STATUS_LABEL: Record<string, string> = {
  open: "offen",
  in_review: "in Prüfung",
  closed: "geschlossen",
};

/** Serious = high or critical (same rule as OPS1 and the database). */
export function isSerious(severity: string | null | undefined): boolean {
  return severity === "high" || severity === "critical";
}

export const QUALITY_REJECTION_MESSAGE: Record<string, string> = {
  not_team_member: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team.",
  type_not_approved: "Dieser Ereignistyp ist nicht klinisch freigegeben.",
};

export function qualityRejectionMessage(reason: unknown): string {
  return (typeof reason === "string" && QUALITY_REJECTION_MESSAGE[reason]) || "Qualitätsereignis konnte nicht gespeichert werden.";
}

/** Shown while the clinical list (D-16) is not yet approved. */
export const NO_TYPES_NOTICE =
  "Die Liste der Qualitätsereignisse wird klinisch festgelegt (D-16). Bis dahin: Beobachtung erfassen und bei Bedarf eine Abrechnungssperre setzen.";

/**
 * CSR1 / CGR-13 (QG1, until `clinical` answers D-16): a quality hold is shown as "Abrechnungssperre" (billing hold).
 * It blocks billing of the visit only; NAVORA gives no care instruction with it.
 */
export const HOLD_MEANING = "Gesperrt ist nur die Abrechnung; ob und wie gepflegt wird, regelt die Sperre nicht.";
