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
 * moment of correction the departure and the start are set, per visit. Care time = start → completion ≥ the planned
 * minutes, so the billable minutes are not scaled below the planned ones and no minimum applies.
 */
export const CORRECTION_BACK = {
  assessment: { departed: 55, started: 50 },
  care: { departed: 40, started: 35 },
} as const;

/** Bounds of the run window in minutes of the Zurich day. */
const EARLIEST_RUN_MINUTE = 75; // 01:15: the earliest correction (55 min back) stays after 00:00 with 20 min margin
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
