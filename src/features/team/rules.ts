// Team planning rules (J3) — pure TypeScript (ADR-002).

/** Flags returned by the database for a planned visit (migration 0014). */
export const PLAN_FLAG_LABEL: Record<string, string> = {
  order_expired: "nach Ablauf der Verordnung",
  reassessment_due: "nach Überprüfungsdatum des Pflegeplans – Neubeurteilung",
  uncovered: "niemand verantwortlich (nächste 24 h)",
};


export type Minutes = { a: number; b: number; c: number };

/** Planned minutes per category from form inputs; empty → 0. Never only a total (PO brief J3). */
export function minutesFromForm(get: (name: string) => string): Minutes {
  const n = (k: string) => {
    const v = Number.parseInt(get(k), 10);
    return Number.isFinite(v) && v > 0 ? v : 0;
  };
  return { a: n("minutes_a"), b: n("minutes_b"), c: n("minutes_c") };
}

export function formatMinutesByCategory(m: { a?: number | null; b?: number | null; c?: number | null }): string {
  const parts = (["a", "b", "c"] as const)
    .filter((k) => (m[k] ?? 0) > 0)
    .map((k) => `${k.toUpperCase()} ${m[k]} min`);
  return parts.length ? parts.join(" · ") : "keine Minuten erfasst";
}

export const QUALIFICATION_LABEL: Record<string, string> = {
  registered_nurse: "Pflegefachperson",
  care_assistant: "Pflegeassistenz",
};

// J2 changes (PO brief): decline reasons v1 — mirror of the database check (migration 0017).
export const DECLINE_REASONS = ["capacity", "qualification", "distance", "other"] as const;
export type DeclineReason = (typeof DECLINE_REASONS)[number];

export const DECLINE_REASON_LABEL: Record<DeclineReason, string> = {
  capacity: "Keine Kapazität",
  qualification: "Qualifikation fehlt",
  distance: "Zu weit weg",
  other: "Anderer Grund",
};

/** Client-side check before sending a decline; the database checks the same. Returns an error or null. */
export function declineError(code: string, text: string): string | null {
  if (!(DECLINE_REASONS as readonly string[]).includes(code)) return "Bitte einen Grund auswählen.";
  if (code === "other" && text.trim().length < 3) return "Bei «Anderer Grund» bitte kurz beschreiben (mind. 3 Zeichen).";
  return null;
}

/** "6 h/Woche" or a clear placeholder; never a guess. */
export function formatWeeklyHours(hours: number | null | undefined): string {
  if (hours === null || hours === undefined) return "nicht erfasst";
  return `${Number.isInteger(hours) ? hours : hours.toFixed(1)} h/Woche`;
}

/** Remaining response time for an offer; null deadline = not configured (Q8). */
export function formatResponseDue(dueIso: string | null | undefined, now = Date.now()): string {
  if (!dueIso) return "Antwortfrist nicht festgelegt";
  const minutes = Math.round((Date.parse(dueIso) - now) / 60_000);
  if (minutes <= 0) return "Antwortfrist abgelaufen";
  if (minutes < 120) return `Antwort in ${minutes} min`;
  return `Antwort in ${Math.round(minutes / 60)} h`;
}

export const ESCALATION_REASON_LABEL: Record<string, string> = {
  no_eligible_team: "Kein geeignetes Team (Region, aktiv, Qualifikation)",
  all_declined: "Alle geeigneten Teams haben abgelehnt",
  deadline_passed: "Antwortfrist abgelaufen",
  deadline_not_configured: "Antwortfrist nicht konfiguriert (Q8)",
};
