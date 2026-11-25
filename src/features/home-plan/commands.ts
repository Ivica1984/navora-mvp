"use server";

// HD-1 / HD-2: the home's plan commands. Every one is a database function that checks the role in this home again,
// locks the person and refuses an absent, double-booked or overlapping assignment. The form returns to the same view
// with a message code (no client script needed; works on a phone).
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { zurichToday } from "@/features/orders/queries";
import { applyOutcome } from "./draft-screen";
import { readLimitsForm, readShiftClassForm, readStaffPlanningForm, sameAsShown } from "./planning-inputs";
import { getPlan } from "./queries";
import { ABSENCE_KINDS, HOME_PLAN_PATH, isPlanningRule, parseRules, safeReturnPath, sameOrderChoice, withAffected, withDraftCounts, withMessage, withWarning } from "./rules";

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

const raw = (f: FormData, k: string) => {
  const v = f.get(k);
  return typeof v === "string" ? v : null;
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
  // HD-3a Q3 (FE-123): the confirmed planning rules, only from the confirmation form (known words only). The database
  // reads the rules again under its locks and saves only when every current rule is confirmed.
  const confirm = parseRules(str(form, "confirm"));
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("institution_assign_staff", {
    p_institution_id: v.institution, p_station_id: v.station, p_shift_type_id: v.shift, p_work_date: v.date, p_staff_id: v.staff,
    ...(confirm.length > 0 ? { p_confirm_rules: confirm } : {}),
  });
  let code = confirm.length > 0 ? "assigned_with_warning" : "assigned";
  let target = back;
  if (error) {
    logEvent("warn", "command.failed", { op: "institution_assign_staff", ...errorFields(error) });
    code = "failed";
  } else {
    const r = (data ?? {}) as Result & { rules?: unknown };
    if (r.result === "warning") {
      const rules = Array.isArray(r.rules) ? r.rules.filter(isPlanningRule) : [];
      code = "rule_warning";
      target = withWarning(back, { staff: v.staff, station: v.station, shift: v.shift, date: v.date, rules });
    } else if (r.result === "rejected") code = "rejected";
    else if (r.result !== "ok") code = r.problems?.[0] ?? "failed";
  }
  revalidatePath(HOME_PLAN_PATH);
  redirect(withMessage(target, code));
}

export async function unassignStaff(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const id = parse(uuid, str(form, "assignment"), back);
  await run("institution_unassign_staff", { p_assignment_id: id }, "unassigned", back);
}

export async function recordAbsence(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, staff: uuid, from: date, to: date, kind: z.enum(ABSENCE_KINDS) }), {
    institution: str(form, "institution"), staff: str(form, "staff"), from: str(form, "from"), to: str(form, "to") ?? str(form, "from"),
    kind: str(form, "kind") ?? "absent",
  }, back);
  await run("institution_record_absence", {
    p_institution_id: v.institution, p_staff_id: v.staff, p_starts_on: v.from, p_ends_on: v.to, p_kind: v.kind,
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

// --- HD-2: gap → external order (migration 0162). The order itself is made by confirm_client_order in the database
// (no second order path); these actions only pass the home's choices and return to the plan with a message code.
type GapResult = Result & { gap_order_id?: string; order_id?: string; prefill?: { activity_tags?: string[] } };

async function rpc(op: string, args: Record<string, unknown>): Promise<GapResult | null> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc(op as never, args as never);
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return null;
  }
  return (data ?? {}) as GapResult;
}

function codeOf(r: GapResult | null, done: string): string {
  if (!r) return "failed";
  if (r.result === "ok") return done;
  if (r.result === "rejected") return "rejected";
  if (r.result === "already_sent" || r.result === "duplicate") return "duplicate";
  return r.problems?.[0] ?? "failed";
}

function reviewPath(back: string, gapOrderId: string, date: string, extra: Record<string, string> = {}): string {
  const url = new URL(back, "http://x");
  url.searchParams.set("ansicht", "auftrag");
  url.searchParams.set("datum", date);
  url.searchParams.set("entwurf", gapOrderId);
  for (const [k, v] of Object.entries(extra)) if (v) url.searchParams.set(k, v);
  return safeReturnPath(`${url.pathname}${url.search}`);
}

export async function prepareGapOrder(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, station: uuid, shift: uuid, date }), {
    institution: str(form, "institution"), station: str(form, "station"), shift: str(form, "shift"), date: str(form, "date"),
  }, back);
  const r = await rpc("institution_prepare_gap_order", {
    p_institution_id: v.institution, p_station_id: v.station, p_shift_type_id: v.shift, p_work_date: v.date,
  });
  revalidatePath(HOME_PLAN_PATH);
  if (r?.result === "ok" && r.gap_order_id) {
    redirect(withMessage(reviewPath(back, r.gap_order_id, v.date, { tags: (r.prefill?.activity_tags ?? []).join(",") }), "order_prepared"));
  }
  redirect(withMessage(back, codeOf(r, "order_prepared")));
}

const tagSchema = z.array(z.string().regex(/^[A-Z][A-Z0-9]{0,5}$/)).max(30);

const tagsOf = (form: FormData, k: string) => form.getAll(k).filter((t): t is string => typeof t === "string");

// UXR-269: «Prüfen» and «Senden» are two buttons of one form, so both read the boxes exactly as they are shown.
// «Prüfen» only returns to the review screen with the shown values (the page runs the preview, writes nothing).
export async function checkGapOrder(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({
    gap: uuid, date, postcode: z.string().regex(/^\d{4}$/).nullable(), grade: grade.nullable(), tags: tagSchema, req: tagSchema,
  }), {
    gap: str(form, "gap"), date: str(form, "date"), postcode: str(form, "postcode"), grade: str(form, "grade"),
    tags: tagsOf(form, "tag"), req: tagsOf(form, "req"),
  }, back);
  redirect(reviewPath(back, v.gap, v.date, {
    tags: v.tags.join(","), req: v.req.join(","), postcode: v.postcode ?? "", grade: v.grade ?? "", geprueft: "1",
  }));
}

export async function sendGapOrder(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({
    gap: uuid, date, postcode: z.string().regex(/^\d{4}$/).nullable(), grade: grade.nullable(), tags: tagSchema, req: tagSchema,
    key: uuid,
    checkedPostcode: z.string().regex(/^\d{4}$/).nullable(), checkedGrade: grade.nullable(), checkedTags: tagSchema,
  }), {
    gap: str(form, "gap"), date: str(form, "date"), postcode: str(form, "postcode"), grade: str(form, "grade"),
    tags: tagsOf(form, "tag"), req: tagsOf(form, "req"), key: str(form, "key"),
    checkedPostcode: str(form, "checked_postcode"), checkedGrade: str(form, "checked_grade"), checkedTags: tagsOf(form, "checked_tag"),
  }, back);
  const kept = { tags: v.tags.join(","), req: v.req.join(","), postcode: v.postcode ?? "", grade: v.grade ?? "", geprueft: "1" };
  // UXR-269: send only what the screen showed when it was checked. A change after «Prüfen» (or a missing snapshot)
  // sends nothing and checks the shown values again (fail closed; the database re-checks every rule on send anyway).
  if (!sameOrderChoice(
    { postcode: v.postcode, grade: v.grade, tags: v.tags },
    { postcode: v.checkedPostcode, grade: v.checkedGrade, tags: v.checkedTags },
  )) {
    redirect(withMessage(reviewPath(back, v.gap, v.date, kept), "order_changed_recheck"));
  }
  const r = await rpc("institution_send_gap_order", {
    p_gap_order_id: v.gap, p_postcode: v.postcode, p_grade: v.grade, p_activity_tags: v.tags, p_required_tags: v.req,
    p_radius_km: null, p_idempotency_key: v.key,
  });
  revalidatePath(HOME_PLAN_PATH);
  revalidatePath("/order");
  const code = codeOf(r, "order_sent");
  if (code === "order_sent" || code === "duplicate") {
    const week = new URL(back, "http://x");
    week.searchParams.set("ansicht", "woche");
    week.searchParams.delete("entwurf");
    week.searchParams.delete("tags");
    redirect(withMessage(safeReturnPath(`${week.pathname}${week.search}`), code));
  }
  // Refused: back to the review screen with the home's (checked) choices kept.
  redirect(withMessage(reviewPath(back, v.gap, v.date, kept), code));
}

export async function discardGapOrder(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const gap = parse(uuid, str(form, "gap"), back);
  const r = await rpc("institution_discard_gap_order", { p_gap_order_id: gap });
  revalidatePath(HOME_PLAN_PATH);
  const week = new URL(back, "http://x");
  week.searchParams.set("ansicht", "woche");
  week.searchParams.delete("entwurf");
  week.searchParams.delete("tags");
  redirect(withMessage(safeReturnPath(`${week.pathname}${week.search}`), codeOf(r, "order_discarded")));
}

// HD-2 slice 5: «Auftrag zurückziehen» (A, K, N). The database decides (state, start, cover, visit under way) and
// releases a live take; the page only words the answer.
export async function withdrawGapOrder(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const gap = parse(uuid, str(form, "gap"), back);
  const r = await rpc("institution_withdraw_gap_order", { p_gap_order_id: gap });
  revalidatePath(HOME_PLAN_PATH);
  revalidatePath("/order");
  const code = r?.result === "already_withdrawn" ? "already_withdrawn" : codeOf(r, "order_withdrawn");
  redirect(withMessage(back, code));
}

// HD-3a slice 4: «Entwurf übernehmen». The form carries exactly the rows the screen showed (T-1) and one apply id per
// shown draft (a double click or a retry is answered «already_applied», nothing is written twice). The database checks
// every row again under its locks and refuses what no longer fits (partial take-over); refused rows stay gaps.
const draftRow = z.strictObject({ date, station_id: uuid, shift_type_id: uuid, staff_id: uuid });

export async function applyDraft(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  let rows: unknown = null;
  try {
    rows = JSON.parse(str(form, "rows") ?? "null");
  } catch {
    rows = null;
  }
  const v = parse(z.object({ institution: uuid, apply: uuid, rows: z.array(draftRow).min(1).max(2000) }), {
    institution: str(form, "institution"), apply: str(form, "apply"), rows,
  }, back);
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("institution_apply_draft", {
    p_institution_id: v.institution, p_apply_id: v.apply, p_rows: v.rows,
  });
  let target: string;
  if (error) {
    logEvent("warn", "command.failed", { op: "institution_apply_draft", ...errorFields(error) });
    target = withMessage(back, "failed");
  } else {
    const o = applyOutcome(data);
    logEvent("info", "draft.applied", { op: "institution_apply_draft", code: o.code, count: o.applied });
    target = withDraftCounts(withMessage(back, o.code), o.applied, o.refused);
  }
  revalidatePath(HOME_PLAN_PATH);
  redirect(target);
}

// HD-3a FE-128 (brief HD.md §5b, PO amendment 2026-11-25 10:39): the planning inputs of the home, through the existing
// commands. Each form carries the values it showed (`was_*`, R-6-2 option (a)); a fresh `institution_plan` read must
// still hold them, else nothing is written and the page shows the current values. The commands check the role
// (limits and class: lead only; Pensum and model: lead and planner), LEAVE1-3 and the ranges, and audit old and new.
async function currentPlan(institution: string) {
  const today = zurichToday();
  return getPlan(institution, today, today);
}

export async function setPlanningLimits(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const institution = parse(uuid, str(form, "institution"), back);
  const read = readLimitsForm(form);
  if (!read.ok) redirect(withMessage(back, read.error));
  const now = await currentPlan(institution);
  if (!now) redirect(withMessage(back, "failed"));
  const i = now.institution;
  if (!sameAsShown(raw(form, "was_rest"), i.min_rest_hours) || !sameAsShown(raw(form, "was_days"), i.max_consecutive_days)
      || !sameAsShown(raw(form, "was_weekly"), i.weekly_target_hours)) {
    redirect(withMessage(back, "changed_meanwhile"));
  }
  await run("institution_set_planning_limits", {
    p_institution_id: institution, p_min_rest_hours: read.value.minRestHours, p_max_consecutive_days: read.value.maxConsecutiveDays,
    p_weekly_target_hours: read.value.weeklyTargetHours,
  }, "limits_saved", back);
}

export async function setStaffPlanning(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, staff: uuid }), { institution: str(form, "institution"), staff: str(form, "staff") }, back);
  const read = readStaffPlanningForm(form);
  if (!read.ok) redirect(withMessage(back, read.error));
  const now = await currentPlan(v.institution);
  const p = now?.staff.find((s) => s.id === v.staff);
  if (!now) redirect(withMessage(back, "failed"));
  if (!p) redirect(withMessage(back, "not_found"));
  if (!sameAsShown(raw(form, "was_pensum"), p.pensum_pct) || !sameAsShown(raw(form, "was_model"), p.shift_model)) {
    redirect(withMessage(back, "changed_meanwhile"));
  }
  await run("institution_set_staff_planning", {
    p_staff_id: v.staff, p_pensum_pct: read.value.pensumPct, p_shift_model: read.value.shiftModel,
  }, "staff_planning_saved", back);
}

export async function setShiftClass(form: FormData) {
  const back = safeReturnPath(form.get("back"));
  const v = parse(z.object({ institution: uuid, shift: uuid }), { institution: str(form, "institution"), shift: str(form, "shift") }, back);
  const read = readShiftClassForm(form);
  if (!read.ok) redirect(withMessage(back, read.error));
  const now = await currentPlan(v.institution);
  const t = now?.shift_types.find((x) => x.id === v.shift);
  if (!now) redirect(withMessage(back, "failed"));
  if (!t) redirect(withMessage(back, "not_found"));
  if (!sameAsShown(raw(form, "was_class"), t.shift_class)) redirect(withMessage(back, "changed_meanwhile"));
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("institution_set_shift_class", { p_shift_type_id: v.shift, p_shift_class: read.value as string });
  let code = "shift_class_saved";
  let target = back;
  if (error) {
    logEvent("warn", "command.failed", { op: "institution_set_shift_class", ...errorFields(error) });
    code = "failed";
  } else {
    const r = (data ?? {}) as Result & { affected_assignments?: unknown };
    if (r.result === "rejected") code = "rejected";
    else if (r.result !== "ok") code = r.problems?.[0] ?? "failed";
    else target = withAffected(back, typeof r.affected_assignments === "number" ? r.affected_assignments : 0);
  }
  revalidatePath(HOME_PLAN_PATH);
  redirect(withMessage(target, code));
}
