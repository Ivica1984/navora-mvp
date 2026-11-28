// HD-3a slice 4 (brief HD.md §5b «Planungslauf: ein Button in Woche und Monat»; ADR-224 rev. 2): pure glue between
// `institution_plan` and the solver for the screen «Plan vorschlagen». No Next or Supabase imports, unit-tested
// (tests/unit/hd3a-draft-screen.test.ts). The database decides every row on «übernehmen» (`institution_apply_draft`);
// this module only reads the plan into the solver input and orders the result for display. Fixed rules, no AI.
import {
  SHIFT_CLASSES,
  SHIFT_MODELS,
  buildDraft,
  draftContextRange,
  fullTimeMinutes,
  type DraftGap,
  type DraftInput,
  type DraftMonthTarget,
  type DraftResult,
  type DraftRow,
  type DraftShiftType,
  type DraftStaff,
  type DraftWish,
  type ShiftClass,
  type ShiftModel,
} from "./draft";
import { addDays, cellKey, monthEnd, monthStart, weekStart, type MonthTarget, type Plan } from "./rules";
import { validateSplitShift } from "./split";

/** The two periods the screen offers; «übernehmen» refuses more than 31 days (migration 0177). */
export type DraftPeriod = "woche" | "monat";

export function draftPeriodRange(period: DraftPeriod, date: string): { from: string; to: string } {
  if (period === "woche") {
    const from = weekStart(date);
    return { from, to: addDays(from, 6) };
  }
  return { from: monthStart(date), to: monthEnd(date) };
}

/** `institution_plan` reads at most 42 days per call (`p_to - p_from <= 41`). */
export const PLAN_READ_MAX_DAYS = 42;

/** The calls that cover [from, to] in consecutive, non-overlapping pieces of at most 42 days. */
export function planReadChunks(from: string, to: string): Array<{ from: string; to: string }> {
  const out: Array<{ from: string; to: string }> = [];
  for (let a = from; a <= to; a = addDays(a, PLAN_READ_MAX_DAYS)) {
    const b = addDays(a, PLAN_READ_MAX_DAYS - 1);
    out.push({ from: a, to: b < to ? b : to });
  }
  return out;
}

/** The planning inputs `institution_plan` returns since migrations 0171-0174 (all optional in the older `Plan` type). */
type PlanInputs = {
  institution: Plan["institution"] & {
    min_rest_hours?: number | null;
    max_consecutive_days?: number | null;
    weekly_target_hours?: number | null;
  };
  shift_types: Array<Plan["shift_types"][number] & { shift_class?: string | null }>;
  staff: Array<Plan["staff"][number] & { pensum_pct?: number | null; shift_model?: string | null }>;
  wishes?: Array<{ staff_id: string; weekday: number; kind: string; shift_type_id: string | null }>;
  /** HD-3a-F3 (migration 0189): per person and month of the read range; absent in an older answer. */
  month_targets?: MonthTargetRow[];
};
/** One `month_targets` entry of `institution_plan` (T-1: every number is the database's). */
export type MonthTargetRow = MonthTarget;
export type DraftPlan = Omit<Plan, "institution" | "shift_types" | "staff"> & PlanInputs;

const isClass = (v: unknown): v is ShiftClass => SHIFT_CLASSES.includes(v as ShiftClass);
const isModel = (v: unknown): v is ShiftModel => SHIFT_MODELS.includes(v as ShiftModel);

export type DraftLimitsRead =
  | { ok: true; minRestHours: number; maxConsecutiveDays: number; weeklyTargetHours: number | null }
  | { ok: false };

/** The home's limits. A missing rest or days-in-a-row value fails closed (no draft), never a default of NAVORA. */
export function readLimits(plan: DraftPlan): DraftLimitsRead {
  const i = plan.institution;
  const rest = i.min_rest_hours;
  const days = i.max_consecutive_days;
  if (typeof rest !== "number" || !(rest > 0) || typeof days !== "number" || !(days > 0)) return { ok: false };
  const weekly = typeof i.weekly_target_hours === "number" ? i.weekly_target_hours : null;
  return { ok: true, minRestHours: rest, maxConsecutiveDays: days, weeklyTargetHours: weekly };
}

/** The dates the solver must see for a period, from the home's own days-in-a-row limit. */
export function contextRangeFor(plan: DraftPlan, from: string, to: string): { from: string; to: string } | null {
  const l = readLimits(plan);
  return l.ok ? draftContextRange(from, to, { maxConsecutiveDays: l.maxConsecutiveDays }) : null;
}

/**
 * Several `institution_plan` reads of one home (consecutive ranges) as one plan: the master data of the first read,
 * the cells of all reads (each cell once), the absences of all reads (each absence once).
 */
export function mergePlans(parts: ReadonlyArray<DraftPlan>): DraftPlan | null {
  if (parts.length === 0) return null;
  const first = parts[0];
  const cells = new Map<string, DraftPlan["cells"][number]>();
  const absences = new Map<string, DraftPlan["absences"][number]>();
  const targets = new Map<string, MonthTargetRow>();
  for (const p of parts) {
    for (const c of p.cells) cells.set(cellKey(c.date, c.station_id, c.shift_type_id), c);
    for (const a of p.absences) absences.set(a.id, a);
    // A month touched by two reads is the same database row (whole-month sums), so either copy is the same.
    for (const m of p.month_targets ?? []) targets.set(`${m.staff_id}|${m.month}`, m);
  }
  const froms = parts.map((p) => p.from).sort();
  const tos = parts.map((p) => p.to).sort();
  return {
    ...first, from: froms[0], to: tos[tos.length - 1], cells: [...cells.values()], absences: [...absences.values()],
    ...(parts.some((p) => p.month_targets) ? { month_targets: [...targets.values()] } : {}),
  };
}

/**
 * The plan the solver needs for [from, to], through `read` (one `institution_plan` call per range). The screen passes
 * its server read (`getDraftPlan`); the CGR-284 (b) equivalence test passes a signed-in client of the local stack, so
 * both go through this one path. Null when any read fails: no draft from part of the plan.
 */
export async function readDraftPlan(
  read: (from: string, to: string) => Promise<DraftPlan | null>,
  from: string,
  to: string,
): Promise<DraftPlan | null> {
  const period = await read(from, to);
  if (!period) return null;
  const range = contextRangeFor(period, from, to);
  if (!range) return period;
  const parts: DraftPlan[] = [];
  for (const c of planReadChunks(range.from, range.to)) {
    const p = await read(c.from, c.to);
    if (!p) return null;
    parts.push(p);
  }
  return mergePlans(parts);
}

/**
 * The solver input for [from, to] from a plan that covers at least `contextRangeFor(plan, from, to)`. `null` (no draft)
 * when the home's limits are missing or a value is outside what the database allows (an app older or newer than the
 * schema): the draft fails closed and never guesses a shift class or model.
 */
export function draftInputFromPlan(plan: DraftPlan, from: string, to: string): DraftInput | null {
  const l = readLimits(plan);
  if (!l.ok) return null;
  if (plan.shift_types.some((t) => t.shift_class != null && !isClass(t.shift_class))) return null;
  // HD-3s (fail closed): a split type must carry two valid blocks, and blocks only on a split type; else no draft.
  if (plan.shift_types.some((t) => (t.shift_class === "split") !== (t.block1_ends_at != null || t.block2_starts_at != null))) return null;
  if (plan.shift_types.some((t) => t.shift_class === "split" && !validateSplitShift({
    block1: { starts_at: t.starts_at, ends_at: String(t.block1_ends_at) },
    block2: { starts_at: String(t.block2_starts_at), ends_at: t.ends_at },
  }).ok)) return null;
  if (plan.staff.some((s) => !isModel(s.shift_model))) return null;
  const shiftTypes: DraftShiftType[] = plan.shift_types.map((t) => ({
    id: t.id, code: t.code, label: t.label, starts_at: t.starts_at, ends_at: t.ends_at,
    shift_class: isClass(t.shift_class) ? t.shift_class : null,
    block1_ends_at: t.block1_ends_at ?? null, block2_starts_at: t.block2_starts_at ?? null,
  }));
  const staff: DraftStaff[] = plan.staff.map((s) => ({
    id: s.id, display_name: s.display_name, grade: s.grade, home_station_id: s.home_station_id, active: s.active,
    pensum_pct: typeof s.pensum_pct === "number" ? s.pensum_pct : null,
    shift_model: s.shift_model as ShiftModel,
  }));
  const wishes: DraftWish[] = (plan.wishes ?? [])
    .filter((w) => (w.kind === "work" || w.kind === "off") && Number.isInteger(w.weekday) && w.weekday >= 1 && w.weekday <= 7)
    .map((w) => ({ staff_id: w.staff_id, weekday: w.weekday, kind: w.kind as DraftWish["kind"], shift_type_id: w.shift_type_id }));
  // HD-3a-F3 R-m: only entries with a valid target (whole positive minutes); a malformed entry fails closed (no draft).
  const rows = plan.month_targets ?? [];
  if (rows.some((m) => m.target_minutes !== null && !(Number.isInteger(m.target_minutes) && m.target_minutes > 0
      && Number.isInteger(m.planned_minutes) && m.planned_minutes >= 0 && /^\d{4}-\d{2}-01$/.test(m.month)))) return null;
  const monthTargets: DraftMonthTarget[] = rows
    .filter((m) => m.target_minutes !== null)
    .map((m) => ({ staff_id: m.staff_id, month: m.month, target_minutes: m.target_minutes as number, planned_minutes: m.planned_minutes }));
  return {
    from, to, shiftTypes, staff, absences: plan.absences, cells: plan.cells, wishes, monthTargets,
    limits: { minRestHours: l.minRestHours, maxConsecutiveDays: l.maxConsecutiveDays, fullTimeMinutesPerWeek: fullTimeMinutes(l.weeklyTargetHours) },
  };
}

/** Rows in the order the screen shows and sends them (T-1 «übernommen = gezeigt»: the form carries exactly these). */
export function sortRows(rows: ReadonlyArray<DraftRow>, plan: Pick<Plan, "stations" | "shift_types" | "staff">): DraftRow[] {
  const st = new Map(plan.stations.map((s, i) => [s.id, i]));
  const ty = new Map(plan.shift_types.map((t, i) => [t.id, i]));
  const name = new Map(plan.staff.map((s) => [s.id, s.display_name]));
  return [...rows].sort(
    (a, b) =>
      (a.date < b.date ? -1 : a.date > b.date ? 1 : 0) ||
      (st.get(a.station_id) ?? 0) - (st.get(b.station_id) ?? 0) ||
      (ty.get(a.shift_type_id) ?? 0) - (ty.get(b.shift_type_id) ?? 0) ||
      (name.get(a.staff_id) ?? "").localeCompare(name.get(b.staff_id) ?? "", "de") ||
      (a.staff_id < b.staff_id ? -1 : 1),
  );
}

/** Gaps in the same order as the rows (date, station, shift type). */
export function sortGaps(gaps: ReadonlyArray<DraftGap>, plan: Pick<Plan, "stations" | "shift_types">): DraftGap[] {
  const st = new Map(plan.stations.map((s, i) => [s.id, i]));
  const ty = new Map(plan.shift_types.map((t, i) => [t.id, i]));
  return [...gaps].sort(
    (a, b) =>
      (a.date < b.date ? -1 : a.date > b.date ? 1 : 0) ||
      (st.get(a.station_id) ?? 0) - (st.get(b.station_id) ?? 0) ||
      (ty.get(a.shift_type_id) ?? 0) - (ty.get(b.shift_type_id) ?? 0),
  );
}

/** The rows as the form value: the four keys only, nothing else (`institution_apply_draft` refuses other keys). */
export function rowsFormValue(rows: ReadonlyArray<DraftRow>): string {
  return JSON.stringify(rows.map((r) => ({ date: r.date, station_id: r.station_id, shift_type_id: r.shift_type_id, staff_id: r.staff_id })));
}

/** The answer of `institution_apply_draft` as a message code and counts for the plan view. */
export type ApplyOutcome = { code: string; applied: number; refused: number };
export function applyOutcome(data: unknown): ApplyOutcome {
  const r = (data ?? {}) as { result?: string; problems?: unknown; applied?: unknown; refused?: unknown };
  const n = (v: unknown) => (typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : 0);
  const refused = Array.isArray(r.refused) ? r.refused.length : 0;
  if (r.result === "ok") return { code: refused > 0 ? "draft_applied_partly" : "draft_applied", applied: n(r.applied), refused };
  if (r.result === "already_applied") return { code: "draft_already_applied", applied: n(r.applied), refused };
  if (r.result === "rejected") return { code: "rejected", applied: 0, refused: 0 };
  const first = Array.isArray(r.problems) && typeof r.problems[0] === "string" ? r.problems[0] : "failed";
  return { code: first, applied: 0, refused: 0 };
}

/** The draft with its measured duration on this server (M1, brief HD.md §5b «Ziel < 2 s»; reported, not a gate). */
export function timedDraft(input: DraftInput): { result: DraftResult; ms: number } {
  const started = performance.now();
  const result = buildDraft(input);
  return { result, ms: Math.max(1, Math.round(performance.now() - started)) };
}
