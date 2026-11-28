// HD-3a FE-128 (founder 2026-11-25 «Die Eingabe gehört noch ins HD-3a.»; brief HD.md §5b, PO amendment 10:39): the
// home enters its own planning inputs on /heim through the existing commands (`institution_set_planning_limits`,
// `institution_set_shift_class`, `institution_set_staff_planning`). This module only reads the form fields and words
// the choices; the database checks the role and the ranges again and audits every change. NAVORA proposes no value:
// a field without a value stays «nicht eingetragen» (the draft then fails closed). Fixed rules, no AI.
import { SHIFT_CLASSES, SHIFT_MODELS, type ShiftClass, type ShiftModel } from "./draft";

/** The value the form sends for «nicht eingetragen» (an explicit choice, never an empty field; R-6-3). */
export const NOT_ENTERED = "nicht_eingetragen";

export const SHIFT_MODEL_LABEL: Record<ShiftModel, string> = {
  any: "alle Dienste",
  early_only: "nur Frühdienst",
  late_only: "nur Spätdienst",
  night_only: "nur Nachtdienst",
  no_night: "kein Nachtdienst",
};
export const shiftModelLabel = (m: string | null | undefined): string =>
  SHIFT_MODELS.includes(m as ShiftModel) ? SHIFT_MODEL_LABEL[m as ShiftModel] : "unbekannt";

export const SHIFT_CLASS_LABEL: Record<ShiftClass, string> = { early: "Früh", late: "Spät", night: "Nacht", split: "Geteilt" };
/** HD-3s: the classes the class form offers for a one-block type; `split` comes only with two blocks (0182). */
export const SELECTABLE_SHIFT_CLASSES: ReadonlyArray<ShiftClass> = SHIFT_CLASSES.filter((c) => c !== "split");
export const shiftClassLabel = (c: string | null | undefined): string =>
  SHIFT_CLASSES.includes(c as ShiftClass) ? SHIFT_CLASS_LABEL[c as ShiftClass] : "keine Klasse";

/** The form value of a shift class choice: a class or `none` («keine Klasse» = NULL in the database). */
export const NO_CLASS = "none";

/** Shown next to every limit field (FE-119, FE-123): the value is the home's, not checked against the law. */
export const LIMIT_MARK = "Wert des Heims · Arbeitszeitgesetz nicht abschliessend geprüft";

export type FieldError =
  | "rest_not_whole"
  | "days_not_whole"
  | "weekly_not_number"
  | "pensum_not_whole"
  | "pensum_choice_missing"
  | "weekly_choice_missing"
  | "pensum_conflict"
  | "weekly_conflict"
  | "shift_model_unknown"
  | "shift_class_unknown";

/** A whole number written by a person ("11", " 6 "); "11,5", "11.5", "1e1", "" are refused (no rounding). */
export function parseWhole(v: string | null): number | null {
  if (v === null) return null;
  const s = v.trim();
  return /^\d{1,3}$/.test(s) ? Number(s) : null;
}

/** Hours with a decimal comma or point ("42", "42,5", "42.5"; at most two decimals). Anything else is refused. */
export function parseHours(v: string | null): number | null {
  if (v === null) return null;
  const s = v.trim();
  if (!/^\d{1,3}([.,]\d{1,2})?$/.test(s)) return null;
  return Number(s.replace(",", "."));
}

const field = (f: FormData, k: string): string | null => {
  const v = f.get(k);
  return typeof v === "string" ? v : null;
};

/**
 * A value that may be «nicht eingetragen» (R-6-3, T-2). A typed number is a value; «nicht eingetragen» with an empty
 * field is NULL; «nicht eingetragen» next to a typed number is refused as a contradiction; an empty field without
 * «nicht eingetragen» is refused. So neither a cleared field nor a forgotten radio button ever writes NULL silently.
 */
function choose(
  choice: string | null, text: string | null, parseValue: (v: string | null) => number | null, name: "weekly" | "pensum",
): { ok: true; value: number | null } | { ok: false; error: FieldError } {
  const typed = text !== null && text.trim() !== "";
  if (choice === NOT_ENTERED) return typed ? { ok: false, error: `${name}_conflict` } : { ok: true, value: null };
  if (!typed) return { ok: false, error: choice === "wert" ? (name === "weekly" ? "weekly_not_number" : "pensum_not_whole") : `${name}_choice_missing` };
  const v = parseValue(text);
  if (v === null) return { ok: false, error: name === "weekly" ? "weekly_not_number" : "pensum_not_whole" };
  return { ok: true, value: v };
}

export type LimitsInput = { minRestHours: number; maxConsecutiveDays: number; weeklyTargetHours: number | null };

/**
 * The home limits form. Rest and days in a row are required whole numbers (the draft needs them); the weekly target is
 * a number or the explicit choice «nicht eingetragen» (see `choose`). The ranges are checked by the database
 * (`limits_not_valid`, `weekly_target_hours_not_valid`), not here.
 */
export function readLimitsForm(f: FormData): { ok: true; value: LimitsInput } | { ok: false; error: FieldError } {
  const rest = parseWhole(field(f, "rest"));
  if (rest === null) return { ok: false, error: "rest_not_whole" };
  const days = parseWhole(field(f, "days"));
  if (days === null) return { ok: false, error: "days_not_whole" };
  const w = choose(field(f, "weekly_choice"), field(f, "weekly"), parseHours, "weekly");
  if (!w.ok) return w;
  return { ok: true, value: { minRestHours: rest, maxConsecutiveDays: days, weeklyTargetHours: w.value } };
}

export type StaffPlanningInput = { pensumPct: number | null; shiftModel: ShiftModel };

/** The person form: Pensum as a whole percent or the explicit choice «nicht eingetragen», and a known shift model. */
export function readStaffPlanningForm(f: FormData): { ok: true; value: StaffPlanningInput } | { ok: false; error: FieldError } {
  const model = field(f, "model");
  if (!SHIFT_MODELS.includes(model as ShiftModel)) return { ok: false, error: "shift_model_unknown" };
  const p = choose(field(f, "pensum_choice"), field(f, "pensum"), parseWhole, "pensum");
  if (!p.ok) return p;
  return { ok: true, value: { pensumPct: p.value, shiftModel: model as ShiftModel } };
}

/** The shift class form: a class or «keine Klasse». */
export function readShiftClassForm(f: FormData): { ok: true; value: ShiftClass | null } | { ok: false; error: FieldError } {
  const v = field(f, "class");
  if (v === NO_CLASS) return { ok: true, value: null };
  if (SELECTABLE_SHIFT_CLASSES.includes(v as ShiftClass)) return { ok: true, value: v as ShiftClass };
  return { ok: false, error: "shift_class_unknown" };
}

/**
 * R-6-2 (b) (HD-3a-F1, migration 0188): the form carries the values it showed (`was_*`); the command sends them as
 * `p_expected` and the database compares them under the row lock it takes for the write. A different value means
 * somebody else changed it in between: nothing is written (`changed_meanwhile`), the page shows the current values.
 * A missing or unreadable `was_*` sends nothing (fail closed).
 */
export const shownValue = (v: number | string | null | undefined): string => (v === null || v === undefined ? NOT_ENTERED : String(v));

/** A shown number back from the form: «nicht eingetragen» → null; anything but a plain decimal → not readable. */
export function shownNumber(shown: string | null): { ok: true; value: number | null } | { ok: false } {
  if (shown === NOT_ENTERED) return { ok: true, value: null };
  if (shown === null || !/^\d{1,6}(\.\d{1,6})?$/.test(shown)) return { ok: false };
  return { ok: true, value: Number(shown) };
}

/** A shown text back from the form: «nicht eingetragen» → null only where the column may be empty. */
function shownText(shown: string | null, nullable: boolean): { ok: true; value: string | null } | { ok: false } {
  if (shown === null || shown === "") return { ok: false };
  if (shown === NOT_ENTERED) return nullable ? { ok: true, value: null } : { ok: false };
  return { ok: true, value: shown };
}

export type ExpectedLimits = { min_rest_hours: number; max_consecutive_days: number; weekly_target_hours: number | null };
/** `p_expected` of `institution_set_planning_limits`; null when a shown value is missing (nothing is sent). */
export function expectedLimits(f: FormData): ExpectedLimits | null {
  const rest = shownNumber(field(f, "was_rest"));
  const days = shownNumber(field(f, "was_days"));
  const weekly = shownNumber(field(f, "was_weekly"));
  if (!rest.ok || !days.ok || !weekly.ok || rest.value === null || days.value === null) return null;
  return { min_rest_hours: rest.value, max_consecutive_days: days.value, weekly_target_hours: weekly.value };
}

export type ExpectedStaffPlanning = { pensum_pct: number | null; shift_model: string };
/** `p_expected` of `institution_set_staff_planning`. */
export function expectedStaffPlanning(f: FormData): ExpectedStaffPlanning | null {
  const pensum = shownNumber(field(f, "was_pensum"));
  const model = shownText(field(f, "was_model"), false);
  if (!pensum.ok || !model.ok || model.value === null) return null;
  return { pensum_pct: pensum.value, shift_model: model.value };
}

export type ExpectedShiftClass = { shift_class: string | null };
/** `p_expected` of `institution_set_shift_class` («keine Klasse» shown = null). */
export function expectedShiftClass(f: FormData): ExpectedShiftClass | null {
  const c = shownText(field(f, "was_class"), true);
  return c.ok ? { shift_class: c.value } : null;
}

// --- HD-3a-F3: monthly target (founder FE-135 option A, migration 0189) ------------------------------------------------
/** The explicit choice «kein Monatssoll» / «keine Schwelle» (deletes the value; never a cleared field). */
export const NO_VALUE = "kein";

export type MonthTargetError =
  | "target_not_number"
  | "target_choice_missing"
  | "target_conflict"
  | "month_not_valid"
  | "threshold_not_number"
  | "threshold_choice_missing"
  | "threshold_conflict";

/** Hours of a month (up to 744 h = 31 days) with a decimal comma or point, at most two decimals; «-5», «1e2», «» refused. */
export function parseMonthHours(v: string | null): number | null {
  if (v === null) return null;
  const s = v.trim();
  if (!/^\d{1,4}([.,]\d{1,2})?$/.test(s)) return null;
  return Number(s.replace(",", "."));
}

/** Hours to the stored working minutes (the database's unit for R-m and R-h): 120,5 h -> 7230 min. */
export const hoursToMinutes = (h: number): number => Math.round(h * 60);

/** Minutes as hours for the screen, Swiss style with a decimal comma and at most two decimals: 7230 -> «120,5 h». */
export function minutesAsHours(m: number): string {
  const h = Math.round((m / 60) * 100) / 100;
  return `${String(h).replace(".", ",")} h`;
}

/** The calendar month a form names, as its first day (YYYY-MM-01, a real date); anything else is not readable. */
export function readMonth(v: string | null): string | null {
  if (v === null || !/^\d{4}-(0[1-9]|1[0-2])-01$/.test(v)) return null;
  return v;
}

function chooseHours(
  choice: string | null, text: string | null, err: { number: MonthTargetError; missing: MonthTargetError; conflict: MonthTargetError },
): { ok: true; value: number | null } | { ok: false; error: MonthTargetError } {
  const typed = text !== null && text.trim() !== "";
  if (choice === NO_VALUE) return typed ? { ok: false, error: err.conflict } : { ok: true, value: null };
  if (!typed) return { ok: false, error: choice === "wert" ? err.number : err.missing };
  const h = parseMonthHours(text);
  return h === null ? { ok: false, error: err.number } : { ok: true, value: h };
}

export type MonthTargetInput = { month: string; targetMinutes: number | null };
/**
 * The monthly target form of one person: the month (hidden), and hours or the explicit choice «kein Monatssoll» (T-2:
 * a negative or unreadable value is refused with a visible text; 0 and more than 744 h are refused by the database).
 */
export function readMonthTargetForm(f: FormData): { ok: true; value: MonthTargetInput } | { ok: false; error: MonthTargetError } {
  const month = readMonth(field(f, "month"));
  if (month === null) return { ok: false, error: "month_not_valid" };
  const h = chooseHours(field(f, "target_choice"), field(f, "target"),
    { number: "target_not_number", missing: "target_choice_missing", conflict: "target_conflict" });
  if (!h.ok) return h;
  return { ok: true, value: { month, targetMinutes: h.value === null ? null : hoursToMinutes(h.value) } };
}

/** `p_expected` of `institution_set_monthly_target`: the minutes the form showed («kein Monatssoll» = null). */
export function expectedMonthTarget(f: FormData): { target_minutes: number | null } | null {
  const shown = shownNumber(field(f, "was_target"));
  return shown.ok ? { target_minutes: shown.value } : null;
}

/** The threshold form of the home: hours or the explicit choice «keine Schwelle» (every deviation is shown). */
export function readThresholdForm(f: FormData): { ok: true; value: number | null } | { ok: false; error: MonthTargetError } {
  return chooseHours(field(f, "threshold_choice"), field(f, "threshold"),
    { number: "threshold_not_number", missing: "threshold_choice_missing", conflict: "threshold_conflict" });
}

/** `p_expected` of `institution_set_monthly_target_threshold`. */
export function expectedThreshold(f: FormData): { monthly_target_deviation_hours: number | null } | null {
  const shown = shownNumber(field(f, "was_threshold"));
  return shown.ok ? { monthly_target_deviation_hours: shown.value } : null;
}
