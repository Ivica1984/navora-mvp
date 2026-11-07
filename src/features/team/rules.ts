// Team planning rules (J3) — pure TypeScript (ADR-002).

import { memberNumbers, pickerMemberLabel } from "./member-label";
import { QUALIFICATION_LABEL } from "./qualification";

/** Flags returned by the database for a planned visit (migration 0014). */
export const PLAN_FLAG_LABEL: Record<string, string> = {
  order_expired: "nach Ablauf der Verordnung",
  reassessment_due: "nach Überprüfungsdatum des Pflegeplans – Neubeurteilung",
  uncovered: "niemand verantwortlich (nächste 24 h)",
  not_primary: "weder Bezugspflegende noch Stellvertretung (Kontinuität)",
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

export { QUALIFICATION_LABEL } from "./qualification";

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
  deadline_not_configured: "Keine Antwortfrist für diese Zuweisungsart",
};

// J6 (PO brief): continuity. PLAN3-17 (2) (`uxa` UXR-114, ADR-159): the name part is `pickerMemberLabel`, the one
// label of every visit-assigning picker (CGR-139): the display name (ADM1, never guessed), "<Name> (du)" / "Ich (du)"
// for the caller, otherwise "Teammitglied <n> (ohne Namen)" with <n> the member's /team position (`memberNumbers`).
// Kept here: "nicht bestimmt" (nobody), "nicht mehr im Team" (not in the list) and the qualification suffix.
export function memberLabel(
  members: readonly { user_id: string; me: boolean; qualification?: string | null; name?: string | null }[],
  userId: string | null | undefined,
): string {
  if (!userId) return "nicht bestimmt";
  const m = members.find((x) => x.user_id === userId);
  if (!m) return "nicht mehr im Team";
  const name = pickerMemberLabel({ name: m.name, me: m.me, no: memberNumbers(members).get(userId) ?? null });
  return m.qualification ? `${name} – ${QUALIFICATION_LABEL[m.qualification] ?? m.qualification}` : name;
}

/** "3 Pflegende · 67 % durch Bezugspflege" — per client, never per person. */
export function formatContinuity(row: { visits: number; distinct_nurses: number; primary_share_pct: number | null }): string {
  if (row.visits === 0) return "diesen Monat noch keine abgeschlossenen Einsätze";
  const share = row.primary_share_pct === null ? "Bezugspflege nicht bestimmt" : `${row.primary_share_pct} % durch Bezugspflege`;
  return `${row.visits} Einsätze · ${row.distinct_nurses} verschiedene Pflegende · ${share}`;
}

// CSR1 / CGR-04 (migration 0038): overdue and stuck visits of the team. Thresholds are PROVISIONAL (D-28).
export type VisitAlertLike = { priority: string; since: string; taken: boolean };

const ALERT_RANK: Record<string, number> = { P1: 1, P2: 2, P3: 3 };

/** P1 first, then the oldest; unknown priorities last. Does not mutate the input. */
export function sortVisitAlerts<T extends VisitAlertLike>(alerts: T[]): T[] {
  return [...alerts].sort(
    (a, b) => (ALERT_RANK[a.priority] ?? 9) - (ALERT_RANK[b.priority] ?? 9) || Date.parse(a.since) - Date.parse(b.since),
  );
}

/** Whether Operations already took the alert over; the team still resolves it by acting on the visit. */
export function visitAlertHandling(taken: boolean): string {
  return taken ? "Operations ist informiert und kümmert sich mit" : "Operations sieht es auch, noch nicht übernommen";
}

/**
 * UX1-22 (`uxa` UXR-4; `cra` C-1 "confirm with change"; ADR-109): texts of the "Einsätze mit Handlungsbedarf" list.
 * The clearance explanation is the former single paragraph, word for word, split before its last sentence; the last
 * sentence stays visible (C-1), the rest goes behind "Wann erledigt sich das?".
 */
export const SIGNAL_POINTER = "Steht oben als Sicherheitssignal";
export const CLEARANCE_SUMMARY = "Wann erledigt sich das?";
export const CLEARANCE_TEXT =
  "Erledigt sich, sobald der Einsatz weitergeht, abgesagt oder als «nicht angetroffen» erfasst ist; ein nicht abgeschlossener Einsatz, sobald jemand über die noch fällige Pflege entschieden hat; eine offene Berichtskorrektur, sobald sie unterschrieben und, falls nötig, gegengezeichnet ist; eine Verordnung ohne Enddatum, sobald ein Enddatum erfasst ist.";
export const PROVISIONAL_NOTE = "Schwellen und Regeln provisorisch (klinische Entscheidungen offen).";

/** Alert types whose list entry carries its own action, so they are always shown in full (C-1). */
const ALERTS_WITH_OWN_ACTION: ReadonlySet<string> = new Set(["visit_interrupted"]);

export type PointerAlert = { visit_id: string; exception_type: string; flags?: readonly string[] | null; taken: boolean };
export type PointerSignal = { visit_id: string; signal_kind: string };

/**
 * UX1-22 / C-1: whether a list entry only repeats a P1 signal card shown above it, and may shrink to one pointer line.
 * True only when all hold, otherwise the entry stays in full (fail-safe):
 * - an OPEN signal card (`openSignals`: the banner's open cards, not taken ones) is for the same visit and the same
 *   situation (`signal_kind` equals `exception_type`);
 * - the entry has no flags (e.g. CGR-32 "Zuständige Person abwesend gemeldet");
 * - Operations has not taken it (`taken` is a handling state the card lacks);
 * - the entry carries no action of its own (`visit_interrupted`: the follow-up decision form).
 */
export function alertRepeatsSignal(alert: PointerAlert, openSignals: readonly PointerSignal[]): boolean {
  if (ALERTS_WITH_OWN_ACTION.has(alert.exception_type)) return false;
  if ((alert.flags ?? []).length > 0) return false;
  if (alert.taken) return false;
  return openSignals.some((s) => s.visit_id === alert.visit_id && s.signal_kind === alert.exception_type);
}

/**
 * UX2-16 (`uxa` UXR-28; `cra` 2026-10-28 17:30 answer 3; ADR-133): the "Einsätze mit Handlungsbedarf" frame follows what
 * the list shows. Red while at least one P1 entry is shown in full; amber while the list has any entry otherwise
 * (pointer lines to a red card above, P2 entries, or an unknown priority); never neutral while an entry is listed.
 * `null` for an empty list (the section is not rendered, as before). P1/P2 stay PROVISIONAL (D-28); no rule changes.
 */
export type VisitAlertFrame = "red" | "amber";

export function visitAlertFrame(
  alerts: readonly (PointerAlert & { priority: string })[],
  openSignals: readonly PointerSignal[],
): VisitAlertFrame | null {
  if (alerts.length === 0) return null;
  return alerts.some((a) => a.priority === "P1" && !alertRepeatsSignal(a, openSignals)) ? "red" : "amber";
}

/** Frame classes per state: red keeps the P1 tokens it had; amber is the non-P1 attention colour (as UX1-24). */
export const VISIT_ALERT_FRAME_CLASS: Record<VisitAlertFrame, string> = {
  red: "border-rose-300 bg-rose-50",
  amber: "border-amber-500 bg-amber-50",
};
