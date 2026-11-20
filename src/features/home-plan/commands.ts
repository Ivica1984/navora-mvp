"use server";

// HD-1 / HD-2: the home's plan commands. Every one is a database function that checks the role in this home again,
// locks the person and refuses an absent, double-booked or overlapping assignment. The form returns to the same view
// with a message code (no client script needed; works on a phone).
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { HOME_PLAN_PATH, safeReturnPath, withMessage } from "./rules";

const uuid = z.uuid();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const time = z.string().regex(/^\d{2}:\d{2}$/);
const grade = z.enum(["ags_eba", "fage_efz", "nurse_hf_fh"]);

type Result = { result?: string; problems?: string[] };

async function run(op: string, args: Record<string, unknown>, done: string, back: string): Promise<never> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc(op as never, args as never);
  let code = done;
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    code = "failed";
  } else {
    const r = (data ?? {}) as Result;
    if (r.result === "rejected") code = "rejected";
    else if (r.result !== "ok") code = r.problems?.[0] ?? "failed";
  }
  revalidatePath(HOME_PLAN_PATH);
  redirect(withMessage(back, code));
}

const str = (f: FormData, k: string) => {
  const v = f.get(k);
  return typeof v === "string" && v.trim() !== "" ? v.trim() : null;
};

function parse<T>(schema: z.ZodType<T>, value: unknown, back: string): T {
  const p = schema.safeParse(value);
  if (!p.success) redirect(withMessage(back, "input_not_valid"));
  return p.data;
}

export async function assignStaff(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, station: uuid, shift: uuid, date, staff: uuid }), {
    institution: str(form, "institution"), station: str(form, "station"), shift: str(form, "shift"),
    date: str(form, "date"), staff: str(form, "staff"),
  }, back);
  await run("institution_assign_staff", {
    p_institution_id: v.institution, p_station_id: v.station, p_shift_type_id: v.shift, p_work_date: v.date, p_staff_id: v.staff,
  }, "assigned", back);
}

export async function unassignStaff(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const id = parse(uuid, str(form, "assignment"), back);
  await run("institution_unassign_staff", { p_assignment_id: id }, "unassigned", back);
}

export async function recordAbsence(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, staff: uuid, from: date, to: date }), {
    institution: str(form, "institution"), staff: str(form, "staff"), from: str(form, "from"), to: str(form, "to") ?? str(form, "from"),
  }, back);
  await run("institution_record_absence", {
    p_institution_id: v.institution, p_staff_id: v.staff, p_starts_on: v.from, p_ends_on: v.to,
  }, "absence", back);
}

export async function removeAbsence(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const id = parse(uuid, str(form, "absence"), back);
  await run("institution_remove_absence", { p_absence_id: id }, "absence_removed", back);
}

export async function addStaff(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, name: z.string().min(2).max(80), grade, station: uuid.nullable() }), {
    institution: str(form, "institution"), name: str(form, "name"), grade: str(form, "grade"), station: str(form, "station"),
  }, back);
  await run("institution_add_staff", {
    p_institution_id: v.institution, p_display_name: v.name, p_grade: v.grade, p_home_station_id: v.station,
  }, "staff_added", back);
}

export async function setStaffActive(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ staff: uuid, active: z.enum(["true", "false"]) }), {
    staff: str(form, "staff"), active: str(form, "active"),
  }, back);
  await run("institution_set_staff_active", { p_staff_id: v.staff, p_active: v.active === "true" }, "staff_changed", back);
}

export async function addStation(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, name: z.string().min(1).max(60) }), {
    institution: str(form, "institution"), name: str(form, "name"),
  }, back);
  await run("institution_add_station", { p_institution_id: v.institution, p_name: v.name }, "station_added", back);
}

export async function setShiftType(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, code: z.string().min(1).max(12), label: z.string().min(1).max(40), starts: time, ends: time }), {
    institution: str(form, "institution"), code: str(form, "code"), label: str(form, "label"), starts: str(form, "starts"), ends: str(form, "ends"),
  }, back);
  await run("institution_set_shift_type", {
    p_institution_id: v.institution, p_code: v.code, p_label: v.label, p_starts_at: v.starts, p_ends_at: v.ends,
  }, "shift_saved", back);
}

export async function setStaffingRule(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({
    institution: uuid, station: uuid, shift: uuid,
    total: z.coerce.number().int().min(0).max(50),
    grade: grade.nullable(),
    gradeCount: z.coerce.number().int().min(0).max(50),
  }), {
    institution: str(form, "institution"), station: str(form, "station"), shift: str(form, "shift"),
    total: str(form, "total"), grade: str(form, "grade"), gradeCount: str(form, "gradeCount") ?? "0",
  }, back);
  await run("institution_set_staffing_rule", {
    p_institution_id: v.institution, p_station_id: v.station, p_shift_type_id: v.shift, p_required_total: v.total,
    p_required_grade: v.gradeCount > 0 ? v.grade : null, p_required_grade_count: v.grade ? v.gradeCount : 0,
  }, "rule_saved", back);
}

export async function loadExample(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, week: date }), { institution: str(form, "institution"), week: str(form, "week") }, back);
  await run("institution_load_example", { p_institution_id: v.institution, p_week_start: v.week }, "example", back);
}
