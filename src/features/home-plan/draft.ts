// HD-3a slice 2 (ADR-224 rev. 2, brief HD.md §5b): «Optimierung (feste Regeln)». A deterministic, constructive plan
// draft as a pure function: no Next, Supabase, clock or randomness. Fixed, checkable rules only; no AI model.
//
// The draft is a proposal. It never writes; the home lead takes it over with one command that re-checks every row in
// the database (slice 3, `institution_apply_draft`). After that, the screen shows only what `institution_plan` returns
// (CGR-284 (a)). `predicted` below is the solver's own reading of the cell rule, for the equivalence test CGR-284 (b).
//
// Hard rules (every one is a parameter or a value of the home, none is invented by NAVORA):
//   R-a active person only (HD-1 R1)            R-e no overlap with any other shift of the person (HD-1)
//   R-b Pensum entered (NULL = never planned)    R-f rest between two shifts >= min_rest_hours (founder, FE-119)
//   R-c shift model allows the shift class      R-g <= max_consecutive_days working days in a row (founder, FE-119)
//   R-d no absence day touched (HD-1 R3)        R-h shift minutes per ISO week <= Pensum x full-time reference
// Rest time and days in a row carry the mark «Arbeitszeitgesetz nicht abschliessend geprüft» (`lca` before real data).
//
// Wishes (FE-125, slice 2d; rule catalogue HD_RULE_CATALOGUE.md W-1, W-2, §4) are an ORDER among permitted persons only:
//   W-1 `work` weekday + shift type: such a person is picked first for that cell (still after every hard rule).
//   W-2 `off` weekday: such a person is picked last, only when nobody else is permitted (minimum staffing wins).
// A wish never makes a person permitted. Every wish not met in the period is listed with its reason.
//
// Founder answers (FE-123, brief HD.md §5b PO amendment 19:39), taken as inputs of the home, never invented here:
//   Q1 100 % Pensum = the home's «Sollstunden pro Woche» (`institutions.weekly_target_hours`, test home 42 h, marked
//      «Beispielwert des Heims»); not entered => the draft refuses to run (fail closed, `pensum_reference_missing`).
//   Q2 each shift type has the class `early`, `late` or `night` chosen by the home, or none; there is no day class.
//      A restricted shift model is never placed on an unclassified type (only `any` may take it).
//
// Time follows the database exactly: a shift starts at work_date + starts_at and ends on the same day when ends_at >
// starts_at, else on the next day (`private.institution_shift_span`); local Zurich time is turned into an instant like
// `private.at_zurich` (start; ambiguous => the earlier instant) and `private.at_zurich_end` (end; ambiguous => the later
// instant); a non-existent local time is read as CET in both. Absence days follow `private.institution_shift_days`.

import { addDays, weekStart, type Absence, type PlanCell, type ShiftType, type Staff } from "./rules";

export const DRAFT_MARK = "Optimierung (feste Regeln)";
export const WORKING_TIME_LAW_MARK = "Arbeitszeitgesetz nicht abschliessend geprüft";

export const SHIFT_CLASSES = ["early", "late", "night"] as const;
export type ShiftClass = (typeof SHIFT_CLASSES)[number];
export const SHIFT_MODELS = ["any", "early_only", "late_only", "night_only", "no_night"] as const;
export type ShiftModel = (typeof SHIFT_MODELS)[number];

/** Which shift classes a shift model allows. `any` also allows an unclassified type; every other model does not (Q2). */
const MODEL_ALLOWS: Record<Exclude<ShiftModel, "any">, ReadonlyArray<ShiftClass>> = {
  early_only: ["early"],
  late_only: ["late"],
  night_only: ["night"],
  no_night: ["early", "late"],
};

export function modelAllows(model: ShiftModel, cls: ShiftClass | null): boolean {
  if (model === "any") return true;
  return cls !== null && MODEL_ALLOWS[model].includes(cls);
}

/** The home's «Sollstunden pro Woche» as minutes; null, non-finite or <= 0 => null (no draft, fail closed). */
export function fullTimeMinutes(weeklyTargetHours: number | null | undefined): number | null {
  if (weeklyTargetHours === null || weeklyTargetHours === undefined) return null;
  const h = Number(weeklyTargetHours);
  return Number.isFinite(h) && h > 0 ? Math.round(h * 60) : null;
}

export type DraftShiftType = ShiftType & { shift_class: ShiftClass | null };
export type DraftStaff = Staff & { pensum_pct: number | null; shift_model: ShiftModel };
export type DraftLimits = {
  minRestHours: number;
  maxConsecutiveDays: number;
  /** Q1 (FE-123): minutes of shift time per ISO week at 100 % Pensum (`fullTimeMinutes(weekly_target_hours)`). */
  fullTimeMinutesPerWeek: number | null;
};
/** A wish of the home for one person (`institution_staff_wishes`): ISO weekday 1 = Monday ... 7 = Sunday. */
export type DraftWish = { staff_id: string; weekday: number; kind: "work" | "off"; shift_type_id: string | null };
export type DraftInput = {
  /** Dates the draft may fill (inclusive). Cells outside count only through their existing assignments. */
  from: string;
  to: string;
  shiftTypes: ReadonlyArray<DraftShiftType>;
  staff: ReadonlyArray<DraftStaff>;
  absences: ReadonlyArray<Absence>;
  /** `institution_plan` cells over at least `draftContextRange(from, to, limits)`. */
  cells: ReadonlyArray<PlanCell>;
  limits: DraftLimits;
  /** W-1 and W-2 (FE-125); absent = no wishes. */
  wishes?: ReadonlyArray<DraftWish>;
};

export type DraftRow = { date: string; station_id: string; shift_type_id: string; staff_id: string };
export type BlockReason =
  | "pensum_missing"
  | "shift_model"
  | "absent"
  | "busy"
  | "rest"
  | "consecutive"
  | "pensum_full";
export const BLOCK_ORDER: ReadonlyArray<BlockReason> = [
  "pensum_missing",
  "shift_model",
  "absent",
  "busy",
  "rest",
  "consecutive",
  "pensum_full",
];
export type DraftGap = {
  date: string;
  station_id: string;
  shift_type_id: string;
  /** `external_order`: the cell has an active external order (HD-2); the draft leaves it to that order. */
  kind: "unfilled" | "external_order";
  missing_total: number;
  missing_grade: number;
  grade: string | null;
  /** Persons of the pool (the missing grade, else every grade) who are active, and why each one cannot take the shift. */
  pool_active: number;
  blocked: Record<BlockReason, number>;
};
/**
 * A wish not met on one date of the period. `reason`: a hard rule that blocks the person (work wish), `no_open_place`
 * (permitted, but every place of that shift was already filled), `needed_for_staffing` (off wish: the draft needed the
 * person for the minimum staffing) or `existing_assignment` (off wish: an assignment the home made already).
 */
export type UnmetWish = {
  staff_id: string;
  date: string;
  kind: DraftWish["kind"];
  shift_type_id: string | null;
  reason: BlockReason | "no_open_place" | "needed_for_staffing" | "existing_assignment";
};
export type WishSummary = { total: number; met: number; unmet: UnmetWish[] };
export type PredictedCell = { date: string; station_id: string; shift_type_id: string; status: "ok" | "gap" };
export type DraftResult =
  | { result: "pensum_reference_missing" }
  | { result: "ok"; rows: DraftRow[]; gaps: DraftGap[]; predicted: PredictedCell[]; wishes: WishSummary };

// --- Time ---------------------------------------------------------------------------------------------------------------
const MIN = 60_000;
const wallFmt = new Intl.DateTimeFormat("en-US", {
  timeZone: "Europe/Zurich",
  hourCycle: "h23",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});
function zurichWall(instant: number): number {
  const p = Object.fromEntries(wallFmt.formatToParts(new Date(instant)).map((x) => [x.type, x.value]));
  return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute);
}
/** Local Zurich wall time (as UTC-shaped milliseconds) to an instant; `end` picks the later reading of an ambiguous time. */
function zurichInstant(wall: number, end: boolean): number {
  const cet = wall - 60 * MIN;
  const cest = wall - 120 * MIN;
  const cetOk = zurichWall(cet) === wall;
  const cestOk = zurichWall(cest) === wall;
  if (end) return cetOk || !cestOk ? cet : cest;
  return cestOk ? cest : cet;
}
const hm = (t: string): number => {
  const [h, m] = t.split(":");
  return Number(h) * 60 + Number(m);
};
const dayWall = (date: string): number => Date.UTC(+date.slice(0, 4), +date.slice(5, 7) - 1, +date.slice(8, 10));

export type Span = { start: number; end: number };
const spanCache = new Map<string, Span>();
export function shiftSpan(date: string, starts: string, ends: string): Span {
  const key = `${date}|${starts}|${ends}`;
  const hit = spanCache.get(key);
  if (hit) return hit;
  const s = hm(starts);
  const e = hm(ends);
  const base = dayWall(date);
  const span = {
    start: zurichInstant(base + s * MIN, false),
    end: zurichInstant(base + (e > s ? 0 : 24 * 60) * MIN + e * MIN, true),
  };
  spanCache.set(key, span);
  return span;
}
/** ISO weekday of a date string: 1 = Monday ... 7 = Sunday. */
export function isoWeekday(date: string): number {
  const d = new Date(dayWall(date)).getUTCDay();
  return d === 0 ? 7 : d;
}

/** Calendar days a shift touches, as `private.institution_shift_days` (inclusive range). */
export function shiftDays(date: string, starts: string, ends: string): { first: string; last: string } {
  const e = hm(ends);
  return { first: date, last: e <= hm(starts) && e !== 0 ? addDays(date, 1) : date };
}

/** The dates whose assignments the draft must see: whole ISO weeks (Pensum) and the runs before and after. */
export function draftContextRange(from: string, to: string, limits: Pick<DraftLimits, "maxConsecutiveDays">): {
  from: string;
  to: string;
} {
  const pad = Math.max(limits.maxConsecutiveDays, 2);
  const a = addDays(from, -pad);
  const b = addDays(to, pad);
  const wf = weekStart(from);
  const wt = addDays(weekStart(to), 6);
  return { from: a < wf ? a : wf, to: b > wt ? b : wt };
}

// --- Model ----------------------------------------------------------------------------------------------------------------
type Shift = { date: string; week: string; typeId: string; span: Span; minutes: number; proposed: boolean };
type Person = DraftStaff & { shifts: Shift[]; dates: Map<string, number>; minutesInPeriod: number };

const cmp = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);

function blockFor(p: Person, date: string, t: DraftShiftType, input: DraftInput, absent: Map<string, Absence[]>): BlockReason | null {
  const { limits } = input;
  if (p.pensum_pct === null) return "pensum_missing";
  if (!modelAllows(p.shift_model, t.shift_class)) return "shift_model";
  const days = shiftDays(date, t.starts_at, t.ends_at);
  if ((absent.get(p.id) ?? []).some((a) => a.starts_on <= days.last && a.ends_on >= days.first)) return "absent";
  const span = shiftSpan(date, t.starts_at, t.ends_at);
  const rest = limits.minRestHours * 60 * MIN;
  let rested = true;
  for (const s of p.shifts) {
    if (s.span.start < span.end && span.start < s.span.end) return "busy";
    const gap = s.span.end <= span.start ? span.start - s.span.end : s.span.start - span.end;
    if (gap < rest) rested = false;
  }
  if (!rested) return "rest";
  // A second shift on a day already worked does not lengthen the run.
  let run = 1;
  for (let d = addDays(date, -1); p.dates.has(d); d = addDays(d, -1)) run++;
  for (let d = addDays(date, 1); p.dates.has(d); d = addDays(d, 1)) run++;
  if (run > limits.maxConsecutiveDays) return "consecutive";
  const ws = weekStart(date);
  let used = 0;
  for (const s of p.shifts) if (s.week === ws) used += s.minutes;
  const minutes = (span.end - span.start) / MIN;
  const cap = Math.floor(((p.pensum_pct ?? 0) * (limits.fullTimeMinutesPerWeek ?? 0)) / 100);
  if (used + minutes > cap) return "pensum_full";
  return null;
}

function emptyBlocked(): Record<BlockReason, number> {
  return Object.fromEntries(BLOCK_ORDER.map((r) => [r, 0])) as Record<BlockReason, number>;
}

/**
 * The draft. Same input (in any order) => the same output. Existing assignments are never moved or removed; they count
 * towards every rule, also outside the period. Cells are filled in order of scarcity (fewest eligible persons first,
 * then date, start time, station, type); within a cell the missing grade first, then any grade; among eligible persons
 * the one with the fewest planned minutes per Pensum point in the period, then the lowest id.
 */
export function buildDraft(input: DraftInput): DraftResult {
  const { limits } = input;
  if (limits.fullTimeMinutesPerWeek === null || !(limits.fullTimeMinutesPerWeek > 0)) {
    return { result: "pensum_reference_missing" };
  }
  const types = new Map(input.shiftTypes.map((t) => [t.id, t]));
  const absent = new Map<string, Absence[]>();
  for (const a of input.absences) absent.set(a.staff_id, [...(absent.get(a.staff_id) ?? []), a]);

  const persons = new Map<string, Person>();
  for (const s of [...input.staff].sort((a, b) => cmp(a.id, b.id))) {
    persons.set(s.id, { ...s, shifts: [], dates: new Map(), minutesInPeriod: 0 });
  }
  const inPeriod = (d: string) => d >= input.from && d <= input.to;
  // Wishes as two lookups (input order does not matter): `${staff}|${weekday}|${type}` and `${staff}|${weekday}`.
  const wishWork = new Set<string>();
  const wishOff = new Set<string>();
  for (const w of input.wishes ?? []) {
    if (!persons.has(w.staff_id) || !(w.weekday >= 1 && w.weekday <= 7)) continue;
    if (w.kind === "work" && w.shift_type_id) wishWork.add(`${w.staff_id}|${w.weekday}|${w.shift_type_id}`);
    else if (w.kind === "off") wishOff.add(`${w.staff_id}|${w.weekday}`);
  }
  // 0 = wishes this weekday with this shift type, 1 = no wish, 2 = wishes this weekday off (W-2 wins over W-1).
  const wishTier = (p: Person, date: string, typeId: string): number => {
    const wd = isoWeekday(date);
    if (wishOff.has(`${p.id}|${wd}`)) return 2;
    return wishWork.has(`${p.id}|${wd}|${typeId}`) ? 0 : 1;
  };
  const addShift = (p: Person, date: string, t: DraftShiftType, proposed: boolean) => {
    const span = shiftSpan(date, t.starts_at, t.ends_at);
    const minutes = (span.end - span.start) / MIN;
    p.shifts.push({ date, week: weekStart(date), typeId: t.id, span, minutes, proposed });
    p.dates.set(date, (p.dates.get(date) ?? 0) + 1);
    if (inPeriod(date)) p.minutesInPeriod += minutes;
  };
  // Existing assignments, of every person and every cell the caller read (also absent or inactive ones: the database
  // checks overlap against all of them).
  const seen = new Set<string>();
  for (const c of input.cells) {
    const t = types.get(c.shift_type_id);
    if (!t) continue;
    for (const a of c.assigned) {
      const p = persons.get(a.staff_id);
      if (!p || seen.has(a.assignment_id)) continue;
      seen.add(a.assignment_id);
      addShift(p, c.date, t, false);
    }
  }

  type Need = { cell: PlanCell; t: DraftShiftType; total: number; grade: number; addedGrade: number; addedAny: number };
  const needs: Need[] = [];
  const gaps: DraftGap[] = [];
  const predicted: PredictedCell[] = [];
  const canonical = [...input.cells]
    .filter((c) => inPeriod(c.date) && types.has(c.shift_type_id))
    .sort((a, b) => cmp(a.date, b.date) || cmp(a.station_id, b.station_id) || cmp(a.shift_type_id, b.shift_type_id));
  for (const c of canonical) {
    if (c.required_total === null) continue;
    const ext = c.order?.cover_state === "covered" ? 1 : 0;
    const extGrade = ext && c.order?.grade === c.required_grade ? 1 : 0;
    const total = Math.max(c.required_total - c.present - ext, 0);
    const grade = c.required_grade ? Math.max(c.required_grade_count - c.grade_present - extGrade, 0) : 0;
    if (total === 0 && grade === 0) continue;
    const t = types.get(c.shift_type_id)!;
    if (c.order) {
      gaps.push(gapOf(c, "external_order", total, grade, 0, emptyBlocked()));
      continue;
    }
    needs.push({ cell: c, t, total, grade, addedGrade: 0, addedAny: 0 });
  }
  const eligibleAtStart = new Map<Need, number>();
  for (const n of needs) {
    let k = 0;
    for (const p of persons.values()) {
      if (!p.active) continue;
      if (n.grade > 0 && p.grade !== n.cell.required_grade) continue;
      if (blockFor(p, n.cell.date, n.t, input, absent) === null) k++;
    }
    eligibleAtStart.set(n, k);
  }
  needs.sort(
    (a, b) =>
      eligibleAtStart.get(a)! - eligibleAtStart.get(b)! ||
      cmp(a.cell.date, b.cell.date) ||
      cmp(a.t.starts_at, b.t.starts_at) ||
      cmp(a.cell.station_id, b.cell.station_id) ||
      cmp(a.t.id, b.t.id),
  );

  const rows: DraftRow[] = [];
  const pick = (n: Need, grade: string | null): Person | null => {
    // Hard rules first (a wish never makes a person permitted), then the wish tier, then the load, then the lowest id.
    let best: Person | null = null;
    let bestTier = Infinity;
    let bestLoad = Infinity;
    for (const p of persons.values()) {
      if (!p.active || (grade !== null && p.grade !== grade)) continue;
      if (blockFor(p, n.cell.date, n.t, input, absent) !== null) continue;
      const tier = wishTier(p, n.cell.date, n.t.id);
      const load = p.minutesInPeriod / (p.pensum_pct as number);
      if (tier < bestTier || (tier === bestTier && load < bestLoad)) {
        best = p;
        bestTier = tier;
        bestLoad = load;
      }
    }
    return best;
  };
  for (const n of needs) {
    const place = (p: Person) => {
      addShift(p, n.cell.date, n.t, true);
      rows.push({ date: n.cell.date, station_id: n.cell.station_id, shift_type_id: n.t.id, staff_id: p.id });
      if (p.grade === n.cell.required_grade) n.addedGrade++;
      n.addedAny++;
    };
    while (n.addedGrade < n.grade) {
      const p = pick(n, n.cell.required_grade);
      if (!p) break;
      place(p);
    }
    while (n.addedAny < n.total) {
      const p = pick(n, null);
      if (!p) break;
      place(p);
    }
  }
  for (const n of needs) {
    const missingGrade = Math.max(n.grade - n.addedGrade, 0);
    const missingTotal = Math.max(n.total - n.addedAny, 0);
    if (missingGrade === 0 && missingTotal === 0) continue;
    const pool = missingGrade > 0 ? n.cell.required_grade : null;
    const blocked = emptyBlocked();
    let active = 0;
    for (const p of persons.values()) {
      if (!p.active || (pool !== null && p.grade !== pool)) continue;
      active++;
      const r = blockFor(p, n.cell.date, n.t, input, absent);
      if (r) blocked[r]++;
    }
    gaps.push(gapOf(n.cell, "unfilled", missingTotal, missingGrade, active, blocked));
  }
  // CGR-284 (b): the solver's reading of the database cell rule after its own rows.
  const added = new Map<string, { any: number; grade: number }>();
  for (const n of needs) added.set(cellId(n.cell), { any: n.addedAny, grade: n.addedGrade });
  for (const c of canonical) {
    if (c.required_total === null) continue;
    const a = added.get(cellId(c)) ?? { any: 0, grade: 0 };
    const ext = c.order?.cover_state === "covered" ? 1 : 0;
    const extGrade = ext && c.order?.grade === c.required_grade ? 1 : 0;
    const ok =
      c.present + a.any + ext >= c.required_total && c.grade_present + a.grade + extGrade >= c.required_grade_count;
    predicted.push({ date: c.date, station_id: c.station_id, shift_type_id: c.shift_type_id, status: ok ? "ok" : "gap" });
  }
  gaps.sort((a, b) => cmp(a.date, b.date) || cmp(a.station_id, b.station_id) || cmp(a.shift_type_id, b.shift_type_id));
  // Every wish on every date of the period, met or not (inactive persons are not planned and are left out).
  const wishes: WishSummary = { total: 0, met: 0, unmet: [] };
  const periodDates: string[] = [];
  for (let d = input.from; d <= input.to; d = addDays(d, 1)) periodDates.push(d);
  const sortedWishes = [...(input.wishes ?? [])].sort(
    (a, b) => cmp(a.staff_id, b.staff_id) || a.weekday - b.weekday || cmp(a.kind, b.kind) || cmp(a.shift_type_id ?? "", b.shift_type_id ?? ""),
  );
  const counted = new Set<string>();
  for (const w of sortedWishes) {
    const p = persons.get(w.staff_id);
    if (!p || !p.active) continue;
    const t = w.shift_type_id ? types.get(w.shift_type_id) : undefined;
    if (w.kind === "work" && !t) continue;
    // W-2 wins over W-1 on the same weekday (the command refuses the pair; this keeps the solver total).
    if (w.kind === "work" && wishOff.has(`${p.id}|${w.weekday}`)) continue;
    const key = `${p.id}|${w.weekday}|${w.kind}|${t?.id ?? ""}`;
    if (counted.has(key)) continue;
    counted.add(key);
    for (const date of periodDates) {
      if (isoWeekday(date) !== w.weekday) continue;
      wishes.total++;
      if (w.kind === "work") {
        if (p.shifts.some((s) => s.date === date && s.typeId === t!.id)) {
          wishes.met++;
          continue;
        }
        const r = blockFor(p, date, t!, input, absent);
        wishes.unmet.push({ staff_id: p.id, date, kind: "work", shift_type_id: t!.id, reason: r ?? "no_open_place" });
      } else {
        // A day off by work date (as R-g counts days): no shift whose work date is that day.
        const that = p.shifts.filter((s) => s.date === date);
        if (that.length === 0) {
          wishes.met++;
          continue;
        }
        const reason = that.some((s) => s.proposed) ? "needed_for_staffing" : "existing_assignment";
        wishes.unmet.push({ staff_id: p.id, date, kind: "off", shift_type_id: null, reason });
      }
    }
  }
  wishes.unmet.sort((a, b) => cmp(a.date, b.date) || cmp(a.staff_id, b.staff_id) || cmp(a.kind, b.kind));
  rows.sort(
    (a, b) =>
      cmp(a.date, b.date) || cmp(a.station_id, b.station_id) || cmp(a.shift_type_id, b.shift_type_id) || cmp(a.staff_id, b.staff_id),
  );
  return { result: "ok", rows, gaps, predicted, wishes };
}

const cellId = (c: Pick<PlanCell, "date" | "station_id" | "shift_type_id">) => `${c.date}|${c.station_id}|${c.shift_type_id}`;

function gapOf(
  c: PlanCell,
  kind: DraftGap["kind"],
  missingTotal: number,
  missingGrade: number,
  poolActive: number,
  blocked: Record<BlockReason, number>,
): DraftGap {
  return {
    date: c.date,
    station_id: c.station_id,
    shift_type_id: c.shift_type_id,
    kind,
    missing_total: missingTotal,
    missing_grade: missingGrade,
    grade: missingGrade > 0 ? c.required_grade : null,
    pool_active: poolActive,
    blocked,
  };
}

// --- Independent check ------------------------------------------------------------------------------------------------
export type Violation = { staff_id: string; date: string; rule: "unknown_staff" | "inactive" | BlockReason | "overlap" | "outside_period" };

/**
 * Checks proposed rows against every hard rule, written independently of `buildDraft` (whole-person view: all shifts
 * sorted, every pair, every week, every run). Only violations that involve at least one proposed row are reported; an
 * existing manual assignment is the home's (Q3). The contract asks for 0 on every draft.
 */
export function verifyDraft(input: DraftInput, rows: ReadonlyArray<DraftRow>): Violation[] {
  const out: Violation[] = [];
  const types = new Map(input.shiftTypes.map((t) => [t.id, t]));
  const staff = new Map(input.staff.map((s) => [s.id, s]));
  const fullTime = input.limits.fullTimeMinutesPerWeek ?? 0;
  type S = { date: string; span: Span; proposed: boolean };
  const by = new Map<string, S[]>();
  const push = (id: string, s: S) => by.set(id, [...(by.get(id) ?? []), s]);
  const ids = new Set<string>();
  for (const c of input.cells) {
    const t = types.get(c.shift_type_id);
    if (!t) continue;
    for (const a of c.assigned) {
      if (ids.has(a.assignment_id)) continue;
      ids.add(a.assignment_id);
      push(a.staff_id, { date: c.date, span: shiftSpan(c.date, t.starts_at, t.ends_at), proposed: false });
    }
  }
  for (const r of rows) {
    const p = staff.get(r.staff_id);
    const t = types.get(r.shift_type_id);
    if (!p || !t) {
      out.push({ staff_id: r.staff_id, date: r.date, rule: "unknown_staff" });
      continue;
    }
    if (r.date < input.from || r.date > input.to) out.push({ staff_id: p.id, date: r.date, rule: "outside_period" });
    if (!p.active) out.push({ staff_id: p.id, date: r.date, rule: "inactive" });
    if (p.pensum_pct === null) out.push({ staff_id: p.id, date: r.date, rule: "pensum_missing" });
    if (!modelAllows(p.shift_model, t.shift_class)) out.push({ staff_id: p.id, date: r.date, rule: "shift_model" });
    const d = shiftDays(r.date, t.starts_at, t.ends_at);
    for (const a of input.absences) {
      if (a.staff_id === p.id && a.starts_on <= d.last && a.ends_on >= d.first) {
        out.push({ staff_id: p.id, date: r.date, rule: "absent" });
        break;
      }
    }
    push(p.id, { date: r.date, span: shiftSpan(r.date, t.starts_at, t.ends_at), proposed: true });
  }
  const rest = input.limits.minRestHours * 60 * MIN;
  for (const [id, list] of by) {
    if (!list.some((s) => s.proposed)) continue;
    const p = staff.get(id);
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        if (!a.proposed && !b.proposed) continue;
        const date = a.proposed ? a.date : b.date;
        if (a.span.start < b.span.end && b.span.start < a.span.end) out.push({ staff_id: id, date, rule: "overlap" });
        else if (Math.max(b.span.start - a.span.end, a.span.start - b.span.end) < rest) out.push({ staff_id: id, date, rule: "rest" });
      }
    }
    const weeks = new Map<string, { minutes: number; proposed: boolean }>();
    for (const s of list) {
      const w = weekStart(s.date);
      const v = weeks.get(w) ?? { minutes: 0, proposed: false };
      v.minutes += (s.span.end - s.span.start) / MIN;
      v.proposed ||= s.proposed;
      weeks.set(w, v);
    }
    const cap = Math.floor(((p?.pensum_pct ?? 0) * fullTime) / 100);
    for (const [w, v] of weeks) if (v.proposed && v.minutes > cap) out.push({ staff_id: id, date: w, rule: "pensum_full" });
    const dates = [...new Set(list.map((s) => s.date))].sort();
    const proposedDates = new Set(list.filter((s) => s.proposed).map((s) => s.date));
    let runStart = 0;
    for (let i = 1; i <= dates.length; i++) {
      if (i < dates.length && dates[i] === addDays(dates[i - 1], 1)) continue;
      const run = dates.slice(runStart, i);
      if (run.length > input.limits.maxConsecutiveDays && run.some((x) => proposedDates.has(x))) {
        out.push({ staff_id: id, date: run[0], rule: "consecutive" });
      }
      runStart = i;
    }
  }
  return out;
}

// --- Words --------------------------------------------------------------------------------------------------------------
const BLOCK_LABEL: Record<BlockReason, string> = {
  pensum_missing: "ohne Pensum",
  shift_model: "Schichtmodell passt nicht",
  absent: "abwesend",
  busy: "bereits im Dienst",
  rest: "Ruhezeit zu kurz",
  consecutive: "zu viele Tage in Folge",
  pensum_full: "Pensum ausgeschöpft",
};

/**
 * The reason of a remaining gap, from plan data only (no absence reason exists): «1 × HF fehlt – 3 aktiv: 2 abwesend,
 * 1 bereits im Dienst». `gradeLabel` words the exact grade code (CGR-284 (c): no substitution between grades).
 */
export function gapReasonText(g: DraftGap, gradeLabel: (code: string | null) => string): string {
  if (g.kind === "external_order") return "Externer Auftrag aktiv – der Entwurf plant diese Lücke nicht.";
  const head =
    g.missing_grade > 0
      ? `${g.missing_grade} × ${gradeLabel(g.grade)} fehlt`
      : `${g.missing_total} ${g.missing_total === 1 ? "Person fehlt" : "Personen fehlen"}`;
  const parts = BLOCK_ORDER.filter((r) => g.blocked[r] > 0).map((r) => `${g.blocked[r]} ${BLOCK_LABEL[r]}`);
  if (g.pool_active === 0) return `${head} – keine aktive Person${g.missing_grade > 0 ? ` mit ${gradeLabel(g.grade)}` : ""}`;
  return `${head} – ${g.pool_active} aktiv${parts.length ? `: ${parts.join(", ")}` : ""}`;
}

const WISH_REASON_LABEL: Record<Exclude<UnmetWish["reason"], BlockReason>, string> = {
  no_open_place: "kein offener Platz in diesem Dienst",
  needed_for_staffing: "für die Mindestbesetzung gebraucht",
  existing_assignment: "bereits von Hand eingeteilt",
};

/** Why a wish is not met, from plan data only: «Wunsch Mo Frühdienst nicht erfüllt – Ruhezeit zu kurz». */
export function unmetWishReasonText(w: UnmetWish): string {
  return w.reason in BLOCK_LABEL ? BLOCK_LABEL[w.reason as BlockReason] : WISH_REASON_LABEL[w.reason as keyof typeof WISH_REASON_LABEL];
}
