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
 * R-6-2 option (a): the form carries the values it showed (`was_*`); the server compares them with a fresh read before
 * it writes. A different value means somebody else changed it in between: nothing is written, the person reloads.
 * A short window between the read and the write remains (named in the ready report; option (b) is a follow-up).
 */
export const shownValue = (v: number | string | null | undefined): string => (v === null || v === undefined ? NOT_ENTERED : String(v));

export function sameAsShown(shown: string | null, current: number | string | null | undefined): boolean {
  if (shown === null) return false;
  return shown === shownValue(current);
}
