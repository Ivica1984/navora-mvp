"use server";

// PLAN2: structured frequency, plan now, series on/off (migration 0025). The database checks the team,
// applies the J3 rules and logs every generated visit with the reason "care plan".

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { PLANNING_MESSAGES, REASON_LABEL } from "./rules";

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const key = z.uuid();

export type PlanningResult = { ok: true; notes: string[]; created?: number } | { ok: false; error: string };

function fromJson(op: string, data: unknown, error: { code?: string } | null): PlanningResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? PLANNING_MESSAGES.invalid : PLANNING_MESSAGES.failed };
  }
  const r = (data ?? {}) as { result?: string; reasons?: string[]; created?: number };
  if (r.result === "ok" || r.result === "duplicate" || r.result === "skipped") {
    revalidatePath("/team");
    return { ok: true, notes: (r.reasons ?? []).map((x) => REASON_LABEL[x] ?? x), created: r.created };
  }
  return { ok: false, error: PLANNING_MESSAGES[r.result ?? ""] ?? PLANNING_MESSAGES.failed };
}

export async function setCarePlanSchedule(input: unknown): Promise<PlanningResult> {
  const p = z.object({
    itemId: z.uuid(),
    period: z.enum(["day", "week"]).nullable(),
    times: z.number().int().min(1).max(7).nullable(),
    weekdays: z.array(z.number().int().min(1).max(7)).max(7).nullable(),
    windowStart: z.string().regex(TIME).nullable(),
    windowEnd: z.string().regex(TIME).nullable(),
    idempotencyKey: key,
  }).safeParse(input);
  if (!p.success) return { ok: false, error: PLANNING_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_care_plan_schedule", {
    p_item_id: p.data.itemId, p_times: p.data.times as number, p_period: p.data.period as string,
    p_weekdays: (p.data.weekdays && p.data.weekdays.length > 0 ? p.data.weekdays : null) as number[],
    p_window_start: p.data.windowStart as string, p_window_end: p.data.windowEnd as string, p_idempotency_key: p.data.idempotencyKey,
  });
  return fromJson("set_care_plan_schedule", data, error);
}

export async function planFromCarePlan(input: unknown): Promise<PlanningResult> {
  const p = z.object({ caseId: z.uuid(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: PLANNING_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("plan_from_care_plan", { p_case_id: p.data.caseId, p_idempotency_key: p.data.idempotencyKey });
  return fromJson("plan_from_care_plan", data, error);
}

export async function setAutoPlanning(input: unknown): Promise<CommandResult> {
  const p = z.object({ caseId: z.uuid(), enabled: z.boolean(), reason: z.string().trim().min(3).max(300), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: PLANNING_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_auto_planning", {
    p_case_id: p.data.caseId, p_enabled: p.data.enabled, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_auto_planning", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? PLANNING_MESSAGES.invalid : PLANNING_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/team");
    return { ok: true };
  }
  return { ok: false, error: PLANNING_MESSAGES[String(data)] ?? PLANNING_MESSAGES.failed };
}
