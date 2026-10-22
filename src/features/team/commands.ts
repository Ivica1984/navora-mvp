"use server";

// J2: team decision on an offered matching request (migration 0011).
// J3: team planning of visits (migration 0012).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { DECLINE_REASONS } from "./rules";

const decisionSchema = z.object({
  requestId: z.uuid(),
  teamId: z.uuid(),
  decision: z.enum(["accept", "decline"]),
  reason: z.string().trim().max(500),
  reasonCode: z.enum(DECLINE_REASONS).nullable(),
  idempotencyKey: z.uuid(),
}).refine((d) => (d.decision === "decline") === (d.reasonCode !== null), { message: "reason code" })
  .refine((d) => d.reasonCode !== "other" || d.reason.length >= 3, { message: "other needs text" });

const MESSAGES: Record<string, string> = {
  invalid: "Ungültige Eingabe. Eine Ablehnung braucht einen Grund; bei «Anderer Grund» eine kurze Beschreibung.",
  rejected: "Nicht gespeichert: Dein Team hat bereits entschieden, oder die Anfrage ist nicht für dein Team.",
  taken: "Ein anderes Team hat diesen Fall bereits übernommen.",
  not_qualified: "Dieser Fall braucht eine Pflegefachperson im Team (Bedarfsabklärung oder Kategorie B).",
  failed: "Entscheid konnte nicht gespeichert werden.",
};

export async function decideMatchingRequest(input: unknown): Promise<CommandResult> {
  const parsed = decisionSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: MESSAGES.invalid };
  const d = parsed.data;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("decide_matching_request", {
    p_request_id: d.requestId,
    p_team_id: d.teamId,
    p_decision: d.decision,
    p_reason: d.reason,
    p_idempotency_key: d.idempotencyKey,
    // The generated RPC type marks every argument as required; null = acceptance.
    p_reason_code: d.reasonCode as string,
  });

  if (error) {
    logEvent("warn", "command.failed", { op: "decide_matching_request", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/team");
    revalidatePath("/field");
    revalidatePath("/operations");
    return { ok: true };
  }
  return { ok: false, error: MESSAGES[String(data)] ?? MESSAGES.failed };
}

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const slot = {
  date: z.iso.date(),
  start: z.string().regex(TIME),
  end: z.string().regex(TIME),
};
const minutes = z.number().int().min(0).max(600);
const planSchema = z.object({
  caseId: z.uuid(),
  ...slot,
  minutesA: minutes,
  minutesB: minutes,
  minutesC: minutes,
  needsAssessment: z.boolean(),
  responsibleUserId: z.uuid().nullable(),
  idempotencyKey: z.uuid(),
});
const reason = z.string().trim().min(3).max(300);
const rescheduleSchema = z.object({ visitId: z.uuid(), ...slot, reason, idempotencyKey: z.uuid() });
const removeSchema = z.object({ visitId: z.uuid(), reason, idempotencyKey: z.uuid() });
const carePlanSchema = z.object({
  caseId: z.uuid(),
  service: z.string().trim().min(2).max(120),
  category: z.enum(["A", "B", "C"]),
  minutes: z.number().int().min(1).max(600),
  frequency: z.string().trim().min(1).max(60),
  reviewDate: z.iso.date(),
  goal: z.string().trim().max(300),
  idempotencyKey: z.uuid(),
});
const retireSchema = z.object({ itemId: z.uuid(), reason, idempotencyKey: z.uuid() });

/** Why the database refused a plan (migration 0014). German, shown inline. */
const PLAN_REASONS: Record<string, string> = {
  not_team_member: "Nur Mitglieder des zuständigen Teams planen Einsätze.",
  assessment_first: "Zuerst den Abklärungsbesuch (Bedarfsabklärung, Kategorie A) planen und durchführen.",
  assessment_already_planned: "Ein Abklärungsbesuch ist bereits geplant.",
  assessment_category_a_only: "Der Abklärungsbesuch umfasst nur Kategorie A.",
  order_required: "Kategorie B braucht eine vorliegende ärztliche Verordnung im Fall.",
  rn_required: "Kategorie B und Bedarfsabklärung nur durch eine Pflegefachperson (HF/FH).",
  responsible_not_in_team: "Die verantwortliche Person gehört nicht zum Team.",
  minutes_exceed_window: "Die geplanten Minuten sind länger als das Zeitfenster.",
  not_removable: "Nur geplante Einsätze ohne Dokumentation können entfernt werden.",
};

export type PlanResult = { ok: true; flags: string[] } | { ok: false; error: string };

function planResult(op: string, data: unknown, error: { code?: string } | null): PlanResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return {
      ok: false,
      error: error.code === "22023" ? "Bitte Datum (ab gestern), Zeiten, Minuten pro Kategorie und – bei Änderungen – einen Grund angeben." : "Planung konnte nicht gespeichert werden.",
    };
  }
  const res = (data ?? {}) as { result?: string; reason?: string; flags?: unknown };
  if (res.result === "rejected") return { ok: false, error: PLAN_REASONS[res.reason ?? ""] ?? "Nicht gespeichert." };
  if (res.result !== "ok" && res.result !== "duplicate") return { ok: false, error: "Planung konnte nicht gespeichert werden." };
  revalidatePath("/team");
  revalidatePath("/field");
  revalidatePath("/visits");
  revalidatePath("/operations");
  return { ok: true, flags: Array.isArray(res.flags) ? res.flags.filter((f): f is string => typeof f === "string") : [] };
}

export async function planVisit(input: unknown): Promise<PlanResult> {
  const parsed = planSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte Datum, Zeiten und Minuten pro Kategorie angeben." };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("plan_visit", {
    p_case_id: d.caseId,
    p_visit_date: d.date,
    p_time_start: d.start,
    p_time_end: d.end,
    p_minutes_a: d.minutesA,
    p_minutes_b: d.minutesB,
    p_minutes_c: d.minutesC,
    p_needs_assessment: d.needsAssessment,
    // Generated RPC types mark every argument as required; null = team without a responsible member.
    p_responsible_user_id: d.responsibleUserId as string,
    p_idempotency_key: d.idempotencyKey,
  });
  return planResult("plan_visit", data, error);
}

export async function rescheduleVisit(input: unknown): Promise<PlanResult> {
  const parsed = rescheduleSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte Datum, Zeiten und einen Grund (mind. 3 Zeichen) angeben." };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("reschedule_visit", {
    p_visit_id: d.visitId,
    p_visit_date: d.date,
    p_time_start: d.start,
    p_time_end: d.end,
    p_reason: d.reason,
    p_idempotency_key: d.idempotencyKey,
  });
  return planResult("reschedule_visit", data, error);
}

export async function removePlannedVisit(input: unknown): Promise<PlanResult> {
  const parsed = removeSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte einen Grund (mind. 3 Zeichen) angeben." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("remove_planned_visit", {
    p_visit_id: parsed.data.visitId,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  return planResult("remove_planned_visit", data, error);
}

function textResult(op: string, data: unknown, error: { code?: string } | null): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? "Bitte Leistung, Kategorie A/B/C, Minuten, Häufigkeit und ein Überprüfungsdatum ab heute angeben." : "Speichern fehlgeschlagen." };
  }
  if (data === "rejected") return { ok: false, error: "Nur Mitglieder des zuständigen Teams pflegen den Pflegeplan." };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: "Speichern fehlgeschlagen." };
  revalidatePath("/team");
  return { ok: true };
}

export async function addCarePlanItem(input: unknown): Promise<CommandResult> {
  const parsed = carePlanSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte Leistung, Kategorie A/B/C, Minuten, Häufigkeit und Überprüfungsdatum angeben." };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("add_care_plan_item", {
    p_case_id: d.caseId,
    p_service: d.service,
    p_category: d.category,
    p_planned_minutes: d.minutes,
    p_frequency: d.frequency,
    p_review_date: d.reviewDate,
    // empty goal = none (the database stores NULL)
    p_goal: d.goal,
    p_idempotency_key: d.idempotencyKey,
  });
  return textResult("add_care_plan_item", data, error);
}

export async function retireCarePlanItem(input: unknown): Promise<CommandResult> {
  const parsed = retireSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Bitte einen Grund (mind. 3 Zeichen) angeben." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("retire_care_plan_item", {
    p_item_id: parsed.data.itemId,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  return textResult("retire_care_plan_item", data, error);
}

// J6: primary nurse and deputy per case (migration 0021). Changing needs a reason (F0 rule).
const primarySchema = z.object({
  caseId: z.uuid(),
  primaryId: z.uuid(),
  deputyId: z.uuid().nullable(),
  reason: z.string().trim().max(300),
  idempotencyKey: z.uuid(),
});

const PRIMARY_MESSAGES: Record<string, string> = {
  invalid: "Bitte Bezugspflegende wählen; die Stellvertretung muss eine andere Person sein. Ein Wechsel braucht eine Begründung (mind. 3 Zeichen).",
  not_in_team: "Bezugspflege und Stellvertretung müssen zum zuständigen Team gehören.",
  rejected: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team.",
  failed: "Konnte nicht gespeichert werden.",
};

export async function setPrimaryNurse(input: unknown): Promise<CommandResult> {
  const parsed = primarySchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: PRIMARY_MESSAGES.invalid };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_primary_nurse", {
    p_case_id: d.caseId,
    p_primary: d.primaryId,
    // The generated RPC type marks every argument as required; null = no deputy / no reason.
    p_deputy: d.deputyId as string,
    p_reason: d.reason,
    p_idempotency_key: d.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_primary_nurse", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? PRIMARY_MESSAGES.invalid : PRIMARY_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate" || data === "unchanged") {
    revalidatePath("/team");
    revalidatePath("/operations");
    return { ok: true };
  }
  return { ok: false, error: PRIMARY_MESSAGES[String(data)] ?? PRIMARY_MESSAGES.failed };
}

// RET1: the team closes the non-blocking review task after a resumed pause (public.complete_case_task, migration 0034).
const taskSchema = z.object({ caseId: z.uuid(), kind: z.literal("review_after_pause"), idempotencyKey: z.uuid() });

export async function completeCaseTask(input: unknown): Promise<CommandResult> {
  const parsed = taskSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Ungültige Aufgabe." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("complete_case_task", {
    p_case_id: parsed.data.caseId,
    p_kind: parsed.data.kind,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "complete_case_task", ...errorFields(error) });
    return { ok: false, error: "Konnte nicht gespeichert werden." };
  }
  if (data === "ok" || data === "duplicate" || data === "unchanged") {
    revalidatePath("/team");
    return { ok: true };
  }
  return { ok: false, error: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team." };
}
