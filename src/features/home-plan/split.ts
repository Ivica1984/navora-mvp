// HD-3s «geteilter Dienst» (brief docs/agents/briefs/HD-3s.md; founder FE-127 (3); rules draft
// docs/engineering/probes/HD-3s_RULES_DRAFT.md §1–§3). Pure functions, no Next, Supabase, clock or randomness. Fixed,
// checkable rules only; no AI model.
//
// A split shift has two blocks on one day. It is stored like the database stores it (migration 0182): starts_at = start
// of block 1, ends_at = end of block 2, block1_ends_at and block2_starts_at mark the pause. So the whole working day is
// starts_at..ends_at, and the HD-3a readings of overlap (K3: a shift in the pause is busy), rest (after block 2, never
// between the blocks, K1) and days in a row (one work date) stay as they are. Only the working minutes leave the pause
// out (founder point 1, `private.institution_shift_minutes`).
//
// Out of scope (brief): R-i 50 h, R-j 14 h span, R-k night rule, S6 pause hint (no founder value; `lca` in this
// package's gate; follow-up HD-3s-F1). The probe's evaluator for those stays on the probe branch.

export type Block = { starts_at: string; ends_at: string };
export type SplitShiftTimes = { block1: Block; block2: Block };

/** V1–V5 in this order; the same codes as `private.institution_split_problem` and the check constraints of 0182. */
export const SPLIT_PROBLEMS = ["time_format", "zero_length", "block_crosses_midnight", "block_order", "no_pause"] as const;
export type SplitProblem = (typeof SPLIT_PROBLEMS)[number];

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const hm = (t: string): number => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

/** V1–V5; the first failing check is the reason (deterministic). NAVORA sets no minimum or maximum pause. */
export function validateSplitShift(t: SplitShiftTimes): { ok: true } | { ok: false; reason: SplitProblem } {
  const times = [t.block1.starts_at, t.block1.ends_at, t.block2.starts_at, t.block2.ends_at];
  if (!times.every((x) => typeof x === "string" && TIME.test(x))) return { ok: false, reason: "time_format" };
  const [s1, e1, s2, e2] = times.map(hm);
  if (s1 === e1 || s2 === e2) return { ok: false, reason: "zero_length" };
  if (e1 < s1 || e2 < s2) return { ok: false, reason: "block_crosses_midnight" };
  if (s2 < e1) return { ok: false, reason: "block_order" };
  if (s2 === e1) return { ok: false, reason: "no_pause" };
  return { ok: true };
}

const PROBLEM_TEXT: Record<SplitProblem, string> = {
  time_format: "Bitte jede Zeit als HH:MM eingeben (00:00 bis 23:59).",
  zero_length: "Ein Block muss länger als 0 Minuten sein.",
  block_crosses_midnight: "Ein Block darf nicht über Mitternacht gehen.",
  block_order: "Block 2 muss nach dem Ende von Block 1 beginnen.",
  no_pause: "Zwischen Block 1 und Block 2 braucht es eine Pause.",
};
export const splitProblemText = (p: SplitProblem): string => PROBLEM_TEXT[p];
export function isSplitProblem(v: unknown): v is SplitProblem {
  return typeof v === "string" && (SPLIT_PROBLEMS as ReadonlyArray<string>).includes(v);
}

/** A shift type as the plan returns it, with or without the two block fields. */
export type BlockFields = {
  starts_at: string;
  ends_at: string;
  shift_class?: string | null;
  block1_ends_at?: string | null;
  block2_starts_at?: string | null;
};

export function isSplit(t: BlockFields): boolean {
  return t.shift_class === "split" && !!t.block1_ends_at && !!t.block2_starts_at;
}

/** The blocks of a shift type: one block, or the two blocks of a split shift. */
export function blocksOf(t: BlockFields): Block[] {
  if (!isSplit(t)) return [{ starts_at: t.starts_at, ends_at: t.ends_at }];
  return [
    { starts_at: t.starts_at, ends_at: t.block1_ends_at as string },
    { starts_at: t.block2_starts_at as string, ends_at: t.ends_at },
  ];
}

/** «07:00–11:30 und 16:00–20:00» or «07:00–15:30». */
export function shiftTimesText(t: BlockFields): string {
  return blocksOf(t)
    .map((b) => `${b.starts_at}–${b.ends_at}`)
    .join(" und ");
}

/**
 * S5 (founder FE-127 (3)): the daily target = weekly target hours ÷ working days per week of the home. A hint only,
 * never a block («Zählen, nicht erzwingen»). No weekly target, or no valid number of days => no hint.
 */
export function dailyTargetHint(
  workMinutes: number,
  weeklyTargetHours: number | null | undefined,
  workDaysPerWeek: number | null | undefined,
): null | { targetMinutes: number; diffMinutes: number } {
  const h = weeklyTargetHours === null || weeklyTargetHours === undefined ? NaN : Number(weeklyTargetHours);
  const d = workDaysPerWeek === null || workDaysPerWeek === undefined ? NaN : Number(workDaysPerWeek);
  if (!(h > 0) || !Number.isInteger(d) || d < 1 || d > 7) return null;
  const targetMinutes = Math.round((h * 60) / d);
  const diffMinutes = workMinutes - targetMinutes;
  return diffMinutes === 0 ? null : { targetMinutes, diffMinutes };
}

const hours = (m: number): string => {
  const a = Math.abs(m);
  const h = Math.floor(a / 60);
  const min = a % 60;
  if (h === 0) return `${min} min`;
  return min === 0 ? `${h} h` : `${h} h ${String(min).padStart(2, "0")}`;
};
export const minutesText = hours;

/** «Arbeitszeit 8 h 30 (ohne Pause); Soll pro Tag 8 h 24: 6 min mehr. Hinweis, keine Sperre.» */
export function dailyTargetText(workMinutes: number, hint: { targetMinutes: number; diffMinutes: number }): string {
  const diff = hint.diffMinutes > 0 ? `${hours(hint.diffMinutes)} mehr` : `${hours(hint.diffMinutes)} weniger`;
  return `Arbeitszeit ${hours(workMinutes)} (ohne Pause); Soll pro Tag ${hours(hint.targetMinutes)}: ${diff}. Hinweis, keine Sperre.`;
}
