// HD-3s (probe branch `probe/hd3s-split-shift-red`, not merged): the rules of a shift with one or two blocks
// (Früh-, Spät-, Nachtdienst = one block; geteilter Dienst = two blocks) as a pure function. No Next, Supabase, clock or
// randomness; fixed, checkable rules only, no AI model. Rules, order, limits and conflicts:
// docs/engineering/probes/HD-3s_RULES_DRAFT.md §1–§5.
//
// Founder rules (#1712 7145634673, live 2026-11-24/25): the pause between the blocks is not working time, only the
// minutes actually worked count; rest starts after the end of the second block; a split shift is one working day; the
// daily target is a hint, never a block. Legal values (ArG/ArGV, sources [A] [B] [C] in the draft) are parameters of the
// home with the mark «Arbeitszeitgesetz nicht abschliessend geprüft»; `lca` checks them before real data.
//
// Integration into the HD-3a draft (`draft.ts`) and the database check is PLANNED after HD-3a (founder order:
// HD-3a → HD-3s → HD-3b); until then this module is the executable specification.

export const WORKING_TIME_LAW_MARK = "Arbeitszeitgesetz nicht abschliessend geprüft";

export type Block = { starts_at: string; ends_at: string };
export type SplitShiftTimes = { block1: Block; block2: Block };
export type Span = { start: number; end: number };
export type ShiftClass = "early" | "late" | "night" | "split";
export type ShiftModel = "any" | "early_only" | "late_only" | "night_only" | "no_night";

const MIN = 60_000;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const hm = (t: string): number => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

// --- V: shape of a shift ------------------------------------------------------------------------------------------------

export type SplitInvalid = "time_format" | "zero_length" | "block_crosses_midnight" | "block_order" | "no_pause";
export type ShiftInvalid = SplitInvalid | "block_count";

/** V1–V5 for a split shift, in fixed order; the first failing check is the reason (deterministic). */
export function validateSplitShift(t: SplitShiftTimes): { ok: true } | { ok: false; reason: SplitInvalid } {
  const times = [t.block1.starts_at, t.block1.ends_at, t.block2.starts_at, t.block2.ends_at];
  if (!times.every((x) => TIME.test(x))) return { ok: false, reason: "time_format" };
  const [s1, e1, s2, e2] = times.map(hm);
  if (s1 === e1 || s2 === e2) return { ok: false, reason: "zero_length" };
  if (e1 < s1 || e2 < s2) return { ok: false, reason: "block_crosses_midnight" };
  if (s2 < e1) return { ok: false, reason: "block_order" };
  if (s2 === e1) return { ok: false, reason: "no_pause" };
  return { ok: true };
}

/** One block (may cross midnight, as HD-3a) or two blocks (a split shift, V1–V5). */
export function validateBlocks(blocks: ReadonlyArray<Block>): { ok: true } | { ok: false; reason: ShiftInvalid } {
  if (blocks.length === 2) return validateSplitShift({ block1: blocks[0], block2: blocks[1] });
  if (blocks.length !== 1) return { ok: false, reason: "block_count" };
  const b = blocks[0];
  if (!TIME.test(b.starts_at) || !TIME.test(b.ends_at)) return { ok: false, reason: "time_format" };
  if (b.starts_at === b.ends_at) return { ok: false, reason: "zero_length" };
  return { ok: true };
}

// --- Time (Europe/Zurich, the readings of `private.at_zurich` / `private.at_zurich_end`, as HD-3a `draft.ts`) ---------

const wallFmt = new Intl.DateTimeFormat("en-US", {
  timeZone: "Europe/Zurich", hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
});
function zurichWall(instant: number): number {
  const p = Object.fromEntries(wallFmt.formatToParts(new Date(instant)).map((x) => [x.type, x.value]));
  return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute);
}
/** Start: ambiguous => the earlier instant; end: ambiguous => the later instant; non-existent => CET in both. */
function zurichInstant(wall: number, end: boolean): number {
  const cet = wall - 60 * MIN;
  const cest = wall - 120 * MIN;
  const cetOk = zurichWall(cet) === wall;
  const cestOk = zurichWall(cest) === wall;
  if (end) return cetOk || !cestOk ? cet : cest;
  return cestOk ? cest : cet;
}
const dayWall = (date: string): number => Date.UTC(+date.slice(0, 4), +date.slice(5, 7) - 1, +date.slice(8, 10));

export function addDays(date: string, n: number): string {
  return new Date(dayWall(date) + n * 1440 * MIN).toISOString().slice(0, 10);
}
/** Monday of the ISO week. */
export function weekStart(date: string): string {
  const dow = (new Date(dayWall(date)).getUTCDay() + 6) % 7;
  return addDays(date, -dow);
}

function blockSpan(date: string, b: Block): Span {
  const s = hm(b.starts_at);
  const e = hm(b.ends_at);
  const base = dayWall(date);
  return {
    start: zurichInstant(base + s * MIN, false),
    end: zurichInstant(base + (e > s ? 0 : 1440) * MIN + e * MIN, true),
  };
}

export function shiftSpans(date: string, blocks: ReadonlyArray<Block>): Span[] {
  return blocks.map((b) => blockSpan(date, b));
}

/** S1: the two blocks of a split shift as instants. */
export function splitShiftSpans(date: string, t: SplitShiftTimes): [Span, Span] {
  return [blockSpan(date, t.block1), blockSpan(date, t.block2)];
}

const worked = (spans: ReadonlyArray<Span>): number => spans.reduce((m, s) => m + (s.end - s.start) / MIN, 0);

/** S2: working minutes = the blocks only; the pause is not working time. */
export function splitWorkMinutes(date: string, t: SplitShiftTimes): number {
  return worked(splitShiftSpans(date, t));
}

/** S3: a split shift is one working day, its work_date (no block crosses midnight, V3). */
export function splitWorkDays(date: string, _t: SplitShiftTimes): string[] {
  return [date];
}

/** Calendar days a shift touches (absence check), as `private.institution_shift_days`. */
export function shiftDays(date: string, blocks: ReadonlyArray<Block>): string[] {
  const last = blocks[blocks.length - 1];
  const e = hm(last.ends_at);
  return blocks.length === 1 && e <= hm(last.starts_at) && e !== 0 ? [date, addDays(date, 1)] : [date];
}

/** R-j: minutes from the start of the first block to the end of the last, pauses included. */
export function daySpanMinutes(date: string, t: SplitShiftTimes): number {
  const [a, b] = splitShiftSpans(date, t);
  return (b.end - a.start) / MIN;
}
const spanOf = (spans: ReadonlyArray<Span>): number => (spans[spans.length - 1].end - spans[0].start) / MIN;

/**
 * S4: rest between two DIFFERENT shifts, in minutes, from the end of the earlier one's last block to the start of the
 * later one's first block. Never between the blocks of one split shift (K1). No shift on one side => +Infinity.
 */
export function restMinutesBetween(earlier: ReadonlyArray<Span>, later: ReadonlyArray<Span>): number {
  if (earlier.length === 0 || later.length === 0) return Number.POSITIVE_INFINITY;
  return (Math.min(...later.map((s) => s.start)) - Math.max(...earlier.map((s) => s.end))) / MIN;
}

/** S5: hint when the worked minutes differ from weekly target ÷ working days per week. No target => no hint. */
export function dailyTargetHint(
  workMinutes: number,
  weeklyTargetHours: number | null,
  workDaysPerWeek = 5,
): null | { targetMinutes: number; diffMinutes: number } {
  if (weeklyTargetHours === null || !(weeklyTargetHours > 0) || !(workDaysPerWeek > 0)) return null;
  const targetMinutes = Math.round((weeklyTargetHours * 60) / workDaysPerWeek);
  const diffMinutes = workMinutes - targetMinutes;
  return diffMinutes === 0 ? null : { targetMinutes, diffMinutes };
}

/** S6 (Art. 15 ArG, [A] p. 6): minimum pause for a stretch of work: > 5.5 h 15 min, > 7 h 30 min, > 9 h 60 min. */
export function requiredPauseMinutes(workMinutes: number): number {
  if (workMinutes > 540) return 60;
  if (workMinutes > 420) return 30;
  if (workMinutes > 330) return 15;
  return 0;
}

/** R-k: does a span touch the local night 23:00–06:00 (Art. 17a ArG, [A] p. 5)? */
function touchesNight(span: Span): boolean {
  for (let t = span.start; t < span.end; t += 15 * MIN) {
    const h = new Date(zurichWall(t)).getUTCHours();
    if (h >= 23 || h < 6) return true;
  }
  return false;
}

// --- Limits: parameters of the home, checked before any rule (invalid input => no evaluation, fail closed) ------------

export type Limits = {
  minRestHours: number; // R-f, founder 11 (FE-119)
  maxConsecutiveDays: number; // R-g, founder 6 (FE-119; Art. 21 ArGV 1)
  weeklyTargetHours: number | null; // R-h 100 % Pensum (FE-123 Q1); null => no draft
  maxWeeklyHours: number; // R-i, Art. 9 ArG 50 («Beispielwert», BGAP draft 45)
  maxDaySpanHours: number; // R-j, Art. 10 Abs. 3 ArG 14
  nightMaxWorkHours: number; // R-k, Art. 17a ArG 9
  nightMaxSpanHours: number; // R-k, Art. 17a ArG 10
  workDaysPerWeek: number; // S5, 5 (`eng` reading, OPEN)
};
export const DEFAULT_LIMITS: Limits = {
  minRestHours: 11,
  maxConsecutiveDays: 6,
  weeklyTargetHours: null,
  maxWeeklyHours: 50,
  maxDaySpanHours: 14,
  nightMaxWorkHours: 9,
  nightMaxSpanHours: 10,
  workDaysPerWeek: 5,
};

export type LimitInvalid =
  | "min_rest_hours"
  | "max_consecutive_days"
  | "weekly_target_hours"
  | "max_weekly_hours"
  | "max_day_span_hours"
  | "night_limits"
  | "work_days_per_week"
  | "pensum_reference_missing";

const inRange = (v: number, lo: number, hi: number) => Number.isFinite(v) && v >= lo && v <= hi;

/** Ranges as the HD-3a database commands (input checks, not legal rules); first failing field wins. */
export function validateLimits(l: Limits): { ok: true } | { ok: false; reason: LimitInvalid } {
  if (!Number.isInteger(l.minRestHours) || !inRange(l.minRestHours, 1, 24)) return { ok: false, reason: "min_rest_hours" };
  if (!Number.isInteger(l.maxConsecutiveDays) || !inRange(l.maxConsecutiveDays, 1, 14)) return { ok: false, reason: "max_consecutive_days" };
  if (l.weeklyTargetHours !== null && !inRange(l.weeklyTargetHours, 1, 80)) return { ok: false, reason: "weekly_target_hours" };
  if (!inRange(l.maxWeeklyHours, 1, 80)) return { ok: false, reason: "max_weekly_hours" };
  if (!inRange(l.maxDaySpanHours, 1, 24)) return { ok: false, reason: "max_day_span_hours" };
  if (!inRange(l.nightMaxWorkHours, 1, 24) || !inRange(l.nightMaxSpanHours, l.nightMaxWorkHours, 24)) return { ok: false, reason: "night_limits" };
  if (!inRange(l.workDaysPerWeek, 1, 7)) return { ok: false, reason: "work_days_per_week" };
  if (l.weeklyTargetHours === null) return { ok: false, reason: "pensum_reference_missing" };
  return { ok: true };
}

// --- The rule check for one person and one candidate shift --------------------------------------------------------------

export type ShiftDef = { blocks: ReadonlyArray<Block>; cls: ShiftClass | null };
export type PlannedShift = { date: string; def: ShiftDef };
export type Candidate = {
  person: { pensum_pct: number | null; shift_model: ShiftModel; absences: ReadonlyArray<{ starts_on: string; ends_on: string }> };
  existing: ReadonlyArray<PlannedShift>;
  date: string;
  def: ShiftDef;
  limits: Limits;
};

/** Hard rules in the fixed order of the draft §5; the first one that fails is the reason. */
export const RULE_ORDER = [
  "pensum_missing", // R-b
  "shift_model", // R-c
  "absent", // R-d
  "busy", // R-e (also a shift inside the pause of a split shift, K3)
  "day_span", // R-j
  "rest", // R-f
  "consecutive", // R-g
  "night", // R-k
  "pensum_full", // R-h
  "weekly_max", // R-i (K8: both caps apply, the first failing one is named)
] as const;
export type RuleBreach = (typeof RULE_ORDER)[number];
export type Hint = { kind: "daily_target"; targetMinutes: number; diffMinutes: number } | { kind: "pause"; block: number; minutes: number };

export type Evaluation =
  | { result: "invalid_shift"; reason: ShiftInvalid }
  | { result: "invalid_limits"; reason: LimitInvalid }
  | { result: "blocked"; reason: RuleBreach; mark: typeof WORKING_TIME_LAW_MARK }
  | { result: "ok"; workMinutes: number; hints: Hint[]; mark: typeof WORKING_TIME_LAW_MARK };

/** R-c: `any` takes every class (also none); a split shift only `any` until the founder decides (OPEN, fail closed). */
export function modelAllows(model: ShiftModel, cls: ShiftClass | null): boolean {
  if (model === "any") return true;
  if (cls === null || cls === "split") return false;
  if (model === "no_night") return cls === "early" || cls === "late";
  return model === `${cls}_only`;
}

export function evaluateShift(c: Candidate): Evaluation {
  const shape = validateBlocks(c.def.blocks);
  if (!shape.ok) return { result: "invalid_shift", reason: shape.reason };
  const lim = validateLimits(c.limits);
  if (!lim.ok) return { result: "invalid_limits", reason: lim.reason };
  for (const e of c.existing) {
    const s = validateBlocks(e.def.blocks);
    if (!s.ok) return { result: "invalid_shift", reason: s.reason };
  }
  const l = c.limits;
  const mark = WORKING_TIME_LAW_MARK;
  const blocked = (reason: RuleBreach): Evaluation => ({ result: "blocked", reason, mark });

  // R-b, R-c, R-d
  if (c.person.pensum_pct === null) return blocked("pensum_missing");
  if (!modelAllows(c.person.shift_model, c.def.cls)) return blocked("shift_model");
  const days = shiftDays(c.date, c.def.blocks);
  if (c.person.absences.some((a) => days.some((d) => a.starts_on <= d && a.ends_on >= d))) return blocked("absent");

  const spans = shiftSpans(c.date, c.def.blocks);
  const others = c.existing.map((e) => ({ date: e.date, spans: shiftSpans(e.date, e.def.blocks) }));

  // R-e: a block overlaps, or another shift lies between our first start and last end (inside the pause), or vice versa.
  const first = spans[0].start;
  const last = spans[spans.length - 1].end;
  for (const o of others) {
    const oFirst = o.spans[0].start;
    const oLast = o.spans[o.spans.length - 1].end;
    if (oFirst < last && first < oLast) return blocked("busy");
  }
  // R-j
  if (spanOf(spans) > l.maxDaySpanHours * 60) return blocked("day_span");
  // R-f (S4)
  for (const o of others) {
    const gap = o.spans[o.spans.length - 1].end <= first ? restMinutesBetween(o.spans, spans) : restMinutesBetween(spans, o.spans);
    if (gap < l.minRestHours * 60) return blocked("rest");
  }
  // R-g (S3: one working day per shift, its work_date)
  const dates = new Set(c.existing.map((e) => e.date));
  let run = 1;
  for (let d = addDays(c.date, -1); dates.has(d); d = addDays(d, -1)) run++;
  for (let d = addDays(c.date, 1); dates.has(d); d = addDays(d, 1)) run++;
  if (!dates.has(c.date) && run > l.maxConsecutiveDays) return blocked("consecutive");
  // R-k: a shift touching 23:00–06:00: work ≤ nightMaxWorkHours within ≤ nightMaxSpanHours (pauses included).
  const work = worked(spans);
  if (spans.some(touchesNight) && (work > l.nightMaxWorkHours * 60 || spanOf(spans) > l.nightMaxSpanHours * 60)) return blocked("night");
  // R-h, R-i: worked minutes in the ISO week of the work_date.
  const ws = weekStart(c.date);
  const used = others.filter((o) => weekStart(o.date) === ws).reduce((m, o) => m + worked(o.spans), 0);
  const pensumCap = Math.floor(((c.person.pensum_pct ?? 0) * (l.weeklyTargetHours ?? 0) * 60) / 100);
  if (used + work > pensumCap) return blocked("pensum_full");
  if (used + work > l.maxWeeklyHours * 60) return blocked("weekly_max");

  // Hints (never a block): S5 daily target for a split shift, S6 pause per block.
  const hints: Hint[] = [];
  if (c.def.blocks.length === 2) {
    const h = dailyTargetHint(work, l.weeklyTargetHours, l.workDaysPerWeek);
    if (h) hints.push({ kind: "daily_target", ...h });
  }
  spans.forEach((s, i) => {
    const need = requiredPauseMinutes((s.end - s.start) / MIN);
    if (need > 0 && c.def.blocks.length === 2) hints.push({ kind: "pause", block: i + 1, minutes: need });
  });
  return { result: "ok", workMinutes: work, hints, mark };
}
