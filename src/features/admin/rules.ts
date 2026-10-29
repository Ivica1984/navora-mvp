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
  // LEAVE1 (migrations 0074, 0075): ending and restoring a person's access.
  self: "Den eigenen Zugang kann man nicht beenden.",
  // LEAVE1-13 (migration 0076): only a planned visit she covers for another team still refuses; her own are released.
  has_planned_visits: "Sie vertritt ab heute bei einem geplanten Einsatz eines anderen Teams. Zuerst die Vertretung beenden, dann den Zugang beenden.",
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

// LEAVE1 (migrations 0074, 0075) -----------------------------------------------------------------------------------------

/** Reason codes of end_member_access / restore_member_access (no free text). */
export const ACCESS_END_REASONS = ["employment_ended", "access_withdrawn"] as const;
export const ACCESS_RESTORE_REASONS = ["employment_resumed", "ended_in_error"] as const;
export const ACCESS_REASON_LABEL: Record<string, string> = {
  employment_ended: "Anstellung beendet",
  access_withdrawn: "Zugang entzogen",
  employment_resumed: "Anstellung wieder aufgenommen",
  ended_in_error: "Irrtümlich beendet",
  // ADM2-13 (0092): ended by the recorded contract end, without a command (no row in the access record).
  contract_end: "Vertragsende",
};

/** LEAVE1-12: open report kinds (private.open_reports_of, migration 0075). */
export const OPEN_REPORT_KINDS = ["unsigned", "correction_draft", "returned"] as const;
export const OPEN_REPORT_LABEL: Record<string, string> = {
  unsigned: "nicht unterschrieben",
  correction_draft: "Korrektur nicht unterschrieben",
  returned: "zurückgegeben, offen",
};
export type OpenReportCounts = Record<(typeof OPEN_REPORT_KINDS)[number], number>;

const count = (v: unknown): number => (typeof v === "number" && Number.isInteger(v) && v > 0 ? v : 0);

/** WORK1-C3 (c), migration 0083: the label of the administrator's count (lca term c, wording of the PO brief). */
export const UNEXPORTED_DAYS_LABEL = "Bestätigte Tage, die sie noch nicht exportiert hat";

/** "Bestätigte Tage, die sie noch nicht exportiert hat: 2", or null when no count is available. */
export function unexportedDaysText(n: number | null | undefined): string | null {
  return typeof n === "number" && Number.isInteger(n) && n >= 0 ? `${UNEXPORTED_DAYS_LABEL}: ${n}` : null;
}

/** COND1-5a: the count as a non-negative integer, else null. */
export function readUnexportedCount(v: unknown): number | null {
  return typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : null;
}

/**
 * COND2-1 (migration 0087, ADR-101): the prepare_member_access_end result. The count is read only on `ok` (an
 * administrator of her organisation, her access still open); every other code carries none.
 */
export function readPreparedEndCount(data: unknown): number | null {
  if (!data || typeof data !== "object") return null;
  const d = data as { result?: unknown; unexported_days?: unknown };
  return d.result === "ok" ? readUnexportedCount(d.unexported_days) : null;
}

/** G-19 item (4): before an access end, ask her to export first (nothing is exported on her behalf). */
export function unexportedEndPrompt(n: number | null | undefined): string | null {
  if (typeof n !== "number" || !Number.isInteger(n) || n <= 0) return null;
  const days = n === 1 ? "1 bestätigten Tag" : `${n} bestätigte Tage`;
  return `Sie hat ${days} noch nicht exportiert. Bitten Sie sie, diese vorher selbst zu exportieren; nach dem Ende kann sie es nicht mehr.`;
}

/**
 * The end_member_access result: its code and, on success, her open reports by kind (LEAVE1-12 (2)), the number of
 * planned visits released to their teams (LEAVE1-13; the command returns them per team, summed here) and the number of
 * open safety signals she had taken (LEAVE1-14 (3), migration 0078; they now read as untaken). WORK1-C3 (a), migration
 * 0083: her confirmed days not yet exported (null when the result carries none).
 */
export function readAccessEndResult(data: unknown): {
  code: string; openReports: OpenReportCounts | null; released: number; takenSignals: number; unexportedDays: number | null;
} {
  if (!data || typeof data !== "object" || !("result" in data)) {
    return { code: "failed", openReports: null, released: 0, takenSignals: 0, unexportedDays: null };
  }
  const d = data as { result?: unknown; open_reports?: unknown; released?: unknown; taken_signals?: unknown; unexported_days?: unknown };
  let openReports: OpenReportCounts | null = null;
  if (d.open_reports && typeof d.open_reports === "object") {
    const o = d.open_reports as Record<string, unknown>;
    openReports = { unsigned: count(o.unsigned), correction_draft: count(o.correction_draft), returned: count(o.returned) };
  }
  const released = d.released && typeof d.released === "object"
    ? Object.values(d.released as Record<string, unknown>).reduce<number>((sum, v) => sum + count(v), 0)
    : 0;
  const unexportedDays = typeof d.unexported_days === "number" && Number.isInteger(d.unexported_days) && d.unexported_days >= 0
    ? d.unexported_days : null;
  return { code: String(d.result), openReports, released, takenSignals: count(d.taken_signals), unexportedDays };
}

/** Counts open reports by kind from list rows (member_open_reports). */
export function countOpenReports(rows: { kind: string }[]): OpenReportCounts {
  const counts: OpenReportCounts = { unsigned: 0, correction_draft: 0, returned: 0 };
  for (const r of rows) if (r.kind in counts) counts[r.kind as keyof OpenReportCounts] += 1;
  return counts;
}

/** "2 nicht unterschrieben · 1 zurückgegeben, offen", or the empty text. */
export function openReportsText(counts: OpenReportCounts | null): string {
  if (!counts) return "";
  const parts = OPEN_REPORT_KINDS.filter((k) => counts[k] > 0).map((k) => `${counts[k]} ${OPEN_REPORT_LABEL[k]}`);
  return parts.length > 0 ? parts.join(" · ") : "keine offenen Berichte";
}

/**
 * After an end: her planned visits now open in the team (LEAVE1-13), the safety signals she had taken that are open
 * again for the team (LEAVE1-14) and what stays open for the team (the command is never refused by open reports,
 * LEAVE1-2).
 */
export function accessEndedNotice(counts: OpenReportCounts | null, released = 0, takenSignals = 0, unexportedDays: number | null = null): string {
  const visits = released <= 0 ? "" : released === 1
    ? " 1 geplanter Einsatz ist jetzt offen im Team."
    : ` ${released} geplante Einsätze sind jetzt offen im Team.`;
  const signals = takenSignals <= 0 ? "" : takenSignals === 1
    ? " 1 übernommenes Sicherheitssignal ist wieder offen im Team."
    : ` ${takenSignals} übernommene Sicherheitssignale sind wieder offen im Team.`;
  const open = counts ? OPEN_REPORT_KINDS.reduce((sum, k) => sum + counts[k], 0) : 0;
  // WORK1-C3 (a): only when there are some; the administrator alone receives this result.
  const days = unexportedDays && unexportedDays > 0 ? ` ${unexportedDaysText(unexportedDays)}.` : "";
  if (open === 0) return `Zugang beendet.${visits}${signals} Keine offenen Berichte.${days}`;
  return `Zugang beendet.${visits}${signals} Offen bleiben: ${openReportsText(counts)}. Das Team sieht sie mit «Zugang beendet»; sie werden nicht verrechnet.${days}`;
}

export type AccessEvent = { user_id: string; kind: string; reason_code: string; created_at: string; seq: number };
export type AccessState = { ended: boolean; endedAt: string | null; reasonCode: string | null };

/** ADM2-13 (0092): the time of each person's newest access event. */
export function lastEventAtByUser(events: AccessEvent[]): Record<string, string> {
  const latest: Record<string, AccessEvent> = {};
  for (const e of events) if (!latest[e.user_id] || e.seq > latest[e.user_id].seq) latest[e.user_id] = e;
  return Object.fromEntries(Object.entries(latest).map(([u, e]) => [u, e.created_at]));
}

/** Current state per person = her newest access event (0074). */
export function accessStateByUser(events: AccessEvent[]): Record<string, AccessState> {
  const latest: Record<string, AccessEvent> = {};
  for (const e of events) if (!latest[e.user_id] || e.seq > latest[e.user_id].seq) latest[e.user_id] = e;
  const out: Record<string, AccessState> = {};
  for (const [user, e] of Object.entries(latest)) {
    out[user] = e.kind === "ended"
      ? { ended: true, endedAt: e.created_at, reasonCode: e.reason_code }
      : { ended: false, endedAt: null, reasonCode: null };
  }
  return out;
}
