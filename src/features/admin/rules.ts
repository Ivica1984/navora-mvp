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
  // SIG1 (0060): the untaken-signal threshold is in minutes.
  minutes: "Minuten",
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
  // CGR-18 (migration 0037): also when she performs a colleague's visit of this team.
  has_visit_in_progress: "Sie ist gerade unterwegs zu einem Einsatz oder mitten in einem Einsatz dieses Teams. Erst abschliessen lassen, dann entfernen.",
  // CGR-18 (migration 0037): only she can write and sign the report of a visit she carried out, and only as a member.
  has_unsigned_reports: "Sie hat Einsätze in diesem Team durchgeführt, deren Bericht fehlt oder noch nicht unterschrieben ist. Nur sie kann ihn schreiben und unterschreiben. Erst unterschreiben lassen, dann entfernen.",
  name_taken: "Ein Team mit diesem Namen gibt es bereits.",
  wrong_state: "Nicht mehr im passenden Zustand.",
  out_of_range: "Ausserhalb des sicheren Bereichs.",
};

/**
 * The safe range of an exception rule as the database enforces it (private.exception_rule_range, migration 0059,
 * CGR-39). `amount_direction` says how the threshold works: `look_ahead` (a window ahead of an event: a larger amount
 * means an EARLIER signal) or `delay` (time after an event: a larger amount means a LATER signal). Either way an
 * override never makes a signal later than the platform default.
 */
export type RuleRange = {
  default_priority: string;
  default_amount: number | null;
  default_escalate: number | null;
  min_amount: number | null;
  max_amount: number | null;
  max_escalate: number | null;
  amount_direction: string | null;
  unit?: string | null;
};

const RANK: Record<string, number> = { P1: 1, P2: 2, P3: 3 };

/** Priorities an administrator may choose: never below the platform default. */
export function allowedPriorities(defaultPriority: string): string[] {
  const max = RANK[defaultPriority] ?? 3;
  return PRIORITIES.filter((p) => RANK[p] <= max);
}

/** Shown on every rule: "Sicherheitsausnahmen melden sich nie später als der Standard" stays the general rule. */
export const RULES_INTRO =
  "Sichere Bereiche: Die Priorität bleibt mindestens beim Standard. Sicherheitsausnahmen melden sich nie später als der Standard: " +
  "keine Schwelle und keine Eskalation darf eine Meldung später machen.";

/** Which way is stricter for this rule, e.g. "Früher melden = mehr Stunden Vorlauf". */
export function stricterHint(direction: string | null, unit: string | null | undefined): string | null {
  const u = UNIT_LABEL[unit ?? ""] ?? unit ?? "";
  if (direction === "look_ahead") return `Früher melden = mehr ${u} Vorlauf (weniger als der Standard ist nicht möglich).`;
  if (direction === "delay") return `Früher melden = weniger ${u} Wartezeit (mehr als der Standard ist nicht möglich).`;
  return null;
}

/** Client-side mirror of the database check; the database stays the authority. */
export function checkRuleInput(range: RuleRange, priority: string, amount: number | null, escalate: number | null): string | null {
  if (!allowedPriorities(range.default_priority).includes(priority)) return "Die Priorität darf nicht unter dem Standard liegen.";
  if ((range.default_amount === null) !== (amount === null)) return ADMIN_MESSAGES.invalid;
  const min = range.min_amount ?? 0;
  const max = range.max_amount ?? 0;
  if (amount !== null && (!Number.isInteger(amount) || amount < min || amount > max)) {
    const hint = stricterHint(range.amount_direction, range.unit);
    return `Schwelle zwischen ${min} und ${max}${hint ? `. ${hint}` : "."} Sicherheitsausnahmen melden sich nie später als der Standard.`;
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
