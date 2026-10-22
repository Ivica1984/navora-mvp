// ADM1 pilot administration — pure helpers and labels (ADR-042). No Next or Supabase imports.

export const ROLES = ["admin", "coach", "operations", "nurse"] as const;
export type Role = (typeof ROLES)[number];

export const ROLE_LABEL: Record<string, string> = {
  admin: "Administration",
  coach: "Coach",
  operations: "Operations",
  nurse: "Pflege",
};

export const QUALIFICATIONS = ["registered_nurse", "care_assistant"] as const;

export const REFERRAL_TYPES = ["hospital_discharge", "nursing_home", "private", "other"] as const;
export const REFERRAL_TYPE_LABEL: Record<string, string> = {
  hospital_discharge: "Spitalaustritt",
  nursing_home: "Pflegeheim",
  private: "Privat",
  other: "Andere",
};

export const DEADLINE_UNITS = ["working_hours", "working_days"] as const;
export const UNIT_LABEL: Record<string, string> = {
  working_hours: "Arbeitsstunden",
  working_days: "Arbeitstage",
  hours: "Stunden",
  days: "Tage",
};

export const PRIORITIES = ["P1", "P2", "P3"] as const;

/** Messages for the command results of migration 0025. */
export const ADMIN_MESSAGES: Record<string, string> = {
  invalid: "Bitte die Angaben prüfen.",
  failed: "Die Änderung konnte nicht gespeichert werden.",
  rejected: "Nur die Administration dieser Organisation darf das.",
  unchanged: "Keine Änderung.",
  already_member: "Diese Person ist bereits Mitglied.",
  already_invited: "Für diese E-Mail gibt es schon eine offene Einladung.",
  last_admin: "Die letzte Administratorin bzw. der letzte Administrator kann die Rolle nicht abgeben.",
  has_cases: "Es gibt noch offene Fälle (oder Bezugspflege). Zuerst übergeben.",
  // CGR-10 (migration 0036): never removed while on the way to, in, or pausing a visit of this team.
  has_visit_in_progress: "Sie ist gerade unterwegs zu einem Einsatz oder mitten in einem Einsatz dieses Teams. Erst abschliessen lassen, dann entfernen.",
  name_taken: "Ein Team mit diesem Namen gibt es bereits.",
  wrong_state: "Nicht mehr im passenden Zustand.",
  out_of_range: "Ausserhalb des sicheren Bereichs.",
};

/** The safe range of an exception rule as the database enforces it (private.exception_rule_range). */
export type RuleRange = {
  default_priority: string;
  default_amount: number | null;
  default_escalate: number | null;
  max_amount: number | null;
  max_escalate: number | null;
};

const RANK: Record<string, number> = { P1: 1, P2: 2, P3: 3 };

/** Priorities an administrator may choose: never below the platform default. */
export function allowedPriorities(defaultPriority: string): string[] {
  const max = RANK[defaultPriority] ?? 3;
  return PRIORITIES.filter((p) => RANK[p] <= max);
}

/** Client-side mirror of the database check; the database stays the authority. */
export function checkRuleInput(range: RuleRange, priority: string, amount: number | null, escalate: number | null): string | null {
  if (!allowedPriorities(range.default_priority).includes(priority)) return "Die Priorität darf nicht unter dem Standard liegen.";
  if ((range.default_amount === null) !== (amount === null)) return ADMIN_MESSAGES.invalid;
  if (amount !== null && (!Number.isInteger(amount) || amount < 0 || amount > (range.max_amount ?? 0))) {
    return `Schwelle zwischen 0 und ${range.max_amount}.`;
  }
  if (range.default_escalate === null ? escalate !== null : escalate === null || !Number.isInteger(escalate) || escalate < 0 || escalate > (range.max_escalate ?? 0)) {
    return range.default_escalate === null ? ADMIN_MESSAGES.invalid : `Eskalation zwischen 0 und ${range.max_escalate} Stunden.`;
  }
  return null;
}

/** "geändert von Anna am 22.10.2026, 14:05" or "Standard". */
export function changedLabel(isDefault: boolean, by: string | null, at: string | null): string {
  if (isDefault || !at) return "Standard";
  const when = new Intl.DateTimeFormat("de-CH", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Zurich" }).format(new Date(at));
  return `geändert${by ? ` von ${by}` : ""} am ${when}`;
}

export function isValidEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim()) && value.trim().length <= 254;
}

/**
 * ADM1 changes: result of `remove_team_member` (migration 0036), jsonb {result, released}.
 * Returns the command code and the number of visits released to the team (0 when unknown).
 */
export function readRemovalResult(data: unknown): { code: string; released: number } {
  if (data && typeof data === "object" && "result" in data) {
    const d = data as { result?: unknown; released?: unknown };
    const released = typeof d.released === "number" && Number.isInteger(d.released) && d.released > 0 ? d.released : 0;
    return { code: String(d.result), released };
  }
  return { code: "failed", released: 0 };
}

/** "3 Einsätze sind jetzt offen im Team." — shown after a removal released her future visits. */
export function releasedNotice(released: number): string {
  if (released <= 0) return "Entfernt. Keine geplanten Einsätze betroffen.";
  if (released === 1) return "Entfernt. 1 Einsatz ist jetzt offen im Team.";
  return `Entfernt. ${released} Einsätze sind jetzt offen im Team.`;
}
