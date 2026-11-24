// HD-3s PROBE (unmerged branch `probe/hd3s-split-shift-red`, FE-099 WORKING MODE 7): the interface of the split shift
// («geteilter Dienst») rules, deliberately NOT implemented. Every function throws, so the tests in
// tests/unit/hd3s-split-shift.test.ts are red. The implementation follows after HD-3a (founder order 2026-11-24 ca. 23:00:
// HD-3a → HD-3s → HD-3b), on the HD-3a draft model (`draft.ts`), and replaces this file.
// Rules: docs/engineering/probes/HD-3s_RULES_DRAFT.md. Fixed, checkable rules only; no AI model.

export type Block = { starts_at: string; ends_at: string };
export type SplitShiftTimes = { block1: Block; block2: Block };
export type Span = { start: number; end: number };

export type SplitInvalid = "time_format" | "zero_length" | "block_crosses_midnight" | "block_order" | "no_pause";

/** V1–V5 in fixed order; the first failing check is the reason (deterministic). */
export function validateSplitShift(_t: SplitShiftTimes): { ok: true } | { ok: false; reason: SplitInvalid } {
  throw new Error("HD-3s not implemented (probe)");
}

/** S1: the two blocks as instants (Europe/Zurich, same rules as `private.at_zurich` / `at_zurich_end`). */
export function splitShiftSpans(_date: string, _t: SplitShiftTimes): [Span, Span] {
  throw new Error("HD-3s not implemented (probe)");
}

/** S2 (founder 23:10 (1)): working minutes = both blocks, the pause is not working time. */
export function splitWorkMinutes(_date: string, _t: SplitShiftTimes): number {
  throw new Error("HD-3s not implemented (probe)");
}

/** S3 (founder 23:10 (3) «Zählen, nicht erzwingen»): a split shift is one working day, its work_date. */
export function splitWorkDays(_date: string, _t: SplitShiftTimes): string[] {
  throw new Error("HD-3s not implemented (probe)");
}

/**
 * S4 (founder 23:10 (2)): rest between two DIFFERENT shifts, in minutes, from the end of the earlier one's last block to
 * the start of the later one's first block. Never applied between the two blocks of one split shift (conflict K1).
 */
export function restMinutesBetween(_earlier: ReadonlyArray<Span>, _later: ReadonlyArray<Span>): number {
  throw new Error("HD-3s not implemented (probe)");
}

/**
 * S5: hint (never a block) when the working minutes differ from the home's daily target. The daily target is the home's
 * weekly target hours divided by `workDaysPerWeek` (default 5 = `eng` reading, OPEN for the founder). No weekly target
 * entered => no hint (nothing invented).
 */
export function dailyTargetHint(
  _workMinutes: number,
  _weeklyTargetHours: number | null,
  _workDaysPerWeek?: number,
): null | { targetMinutes: number; diffMinutes: number } {
  throw new Error("HD-3s not implemented (probe)");
}
