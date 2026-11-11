// BD-2 (ADR-181): time helpers for the continuous e2e run (tests/e2e/durchgang-ambulant.spec.ts). Pure TypeScript, no
// Playwright import, unit-tested in tests/unit/bd2-durchgang-time.test.ts. The seed, the app and the run share one
// Europe/Zurich calendar day (ADR-068, ADR-113); CI's clock runs in UTC.

/** A Europe/Zurich calendar day as yyyy-mm-dd, `offset` days from the day of `nowMs`. */
export function zurichDay(nowMs: number = Date.now(), offset = 0): string {
  const [y, m, d] = new Date(nowMs).toLocaleDateString("sv-SE", { timeZone: "Europe/Zurich" }).split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10);
}

/** Swiss wall-clock time "HH:MM" (24 h) of an instant. */
export function zurichWall(ms: number): string {
  return new Intl.DateTimeFormat("de-CH", { timeZone: "Europe/Zurich", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .format(new Date(ms));
}

/** Minutes since Zurich midnight of an instant. */
export function zurichMinuteOfDay(ms: number): number {
  const [h, m] = zurichWall(ms).split(":").map(Number);
  return h * 60 + m;
}

/** "HH:MM" of a minute of the day (0 ≤ min < 1440). */
export function hhmm(min: number): string {
  if (!Number.isInteger(min) || min < 0 || min >= 24 * 60) throw new RangeError(`minute of day out of range: ${min}`);
  return `${String(Math.floor(min / 60)).padStart(2, "0")}:${String(min % 60).padStart(2, "0")}`;
}

export type Slot = { from: string; to: string };
export type DurchgangSlots = { assessment: Slot; care: Slot };

/** Planned minutes of the two visits of the run (synthetic test values, no care rule): assessment A 45, care visit C 30. */
export const ASSESSMENT_MINUTES = 45;
export const CARE_MINUTES = 30;

/**
 * F3 corrections of the run (Q-BD-1 option (A), reason «Testlauf: simulierte Einsatzdauer»): how many minutes before the
 * moment of correction each event is set, per visit; `completed` absent = the recorded completion stays. Care time =
 * start → completion ≥ the planned minutes, so the billable minutes are not scaled below the planned ones and no minimum
 * applies.
 *
 * CGR-180 (1) (`cra` 13:30): the effective times must form a possible care sequence. The care visit is corrected a few
 * minutes after the assessment, so the assessment's completion is also set back (65 min) and lies before the care
 * visit's corrected departure (40 min back from a later moment): the care visit starts after the needs assessment ended
 * and the nurse's two visits do not overlap. Synthetic test values, no care rule.
 */
export const CORRECTION_BACK = {
  assessment: { departed: 120, started: 115, completed: 65 },
  care: { departed: 40, started: 35 },
} as const;

export type CorrectionBack = { departed: number; started: number; completed?: number };

/** Effective times (ms) of one visit: departure, start, completion. */
export type VisitSpan = { departed: number; started: number; completed: number };

/** The effective span of a visit corrected at `correctedAtMs` with `back` (the completion is taken as that moment). */
export function correctedSpan(correctedAtMs: number, back: CorrectionBack): VisitSpan {
  const at = (minutes: number) => correctedAtMs - minutes * 60_000;
  return { departed: at(back.departed), started: at(back.started), completed: at(back.completed ?? 0) };
}

export type SequenceViolation = "care_starts_before_assessment_completed" | "visits_overlap";

/**
 * CGR-180 (1): faults of the sequence assessment → care visit of the same nurse and client, in effective time.
 * A visit occupies the nurse from departure to completion; touching ends (departure = completion) do not overlap.
 */
export function sequenceViolations(assessment: VisitSpan, care: VisitSpan): SequenceViolation[] {
  const faults: SequenceViolation[] = [];
  if (care.started < assessment.completed) faults.push("care_starts_before_assessment_completed");
  if (care.departed < assessment.completed && assessment.departed < care.completed) faults.push("visits_overlap");
  return faults;
}

type EventRow = { id: number; event_type: string; occurred_at: string };
type CorrectionRow = { id: number; event_id: number; corrected_at: string; created_at: string };

/**
 * Effective departure, start and completion of one visit, as `private.effective_event_time` (0008) computes them: the
 * newest correction of the event (created_at, then id), else the recorded time. Throws when one of the three is missing.
 */
export function effectiveEventTimes(events: EventRow[], corrections: CorrectionRow[]): VisitSpan {
  const effective = (type: "departed" | "started" | "completed"): number => {
    const event = events.find((e) => e.event_type === type);
    if (!event) throw new Error(`the visit has no ${type} event`);
    const newest = corrections
      .filter((c) => c.event_id === event.id)
      .sort((x, y) => Date.parse(y.created_at) - Date.parse(x.created_at) || y.id - x.id)[0];
    return Date.parse(newest ? newest.corrected_at : event.occurred_at);
  };
  return { departed: effective("departed"), started: effective("started"), completed: effective("completed") };
}

/** Bounds of the run window in minutes of the Zurich day. */
const EARLIEST_RUN_MINUTE = 140; // 02:20: the earliest correction (120 min back) stays after 00:00 with 20 min margin
const LAST_SLOT_END_MINUTE = 23 * 60 + 40; // 23:40: the care visit ends before midnight, 20 min before the day guard

/**
 * The two slots of the run, both today and in the future: the assessment starts at the next full five minutes plus five,
 * the care visit 15 minutes after the assessment's end. `null` when the run would cross midnight or a correction would
 * land on the previous day (the spec then names the reason; ci-e2e-day-guard.sh keeps CI runs away from midnight).
 */
export function durchgangSlots(nowMs: number = Date.now()): DurchgangSlots | null {
  const now = zurichMinuteOfDay(nowMs);
  if (now < EARLIEST_RUN_MINUTE) return null;
  const aFrom = Math.ceil((now + 1) / 5) * 5 + 5;
  const aTo = aFrom + ASSESSMENT_MINUTES;
  const cFrom = aTo + 15;
  const cTo = cFrom + CARE_MINUTES;
  if (cTo > LAST_SLOT_END_MINUTE) return null;
  return { assessment: { from: hhmm(aFrom), to: hhmm(aTo) }, care: { from: hhmm(cFrom), to: hhmm(cTo) } };
}

/** The wall time to type for "N minutes before `nowMs`" in a correction. */
export function minutesBack(nowMs: number, minutes: number): string {
  return zurichWall(nowMs - minutes * 60_000);
}

/** Internal codes that no text of the run may show (`uxa` G-6): D-, CR-, CGR-, SIG- followed by a number. */
export const INTERNAL_CODE = /\b(?:D|CR|CGR|SIG)-\d+/;
