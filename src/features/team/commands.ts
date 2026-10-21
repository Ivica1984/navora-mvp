"use server";

// J2: team decision on an offered matching request (migration 0011).
// J3: team planning of visits (migration 0012).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";

const decisionSchema = z.object({
  requestId: z.uuid(),
  teamId: z.uuid(),
  decision: z.enum(["accept", "decline"]),
  reason: z.string().trim().max(500),
  idempotencyKey: z.uuid(),
});

const MESSAGES: Record<string, string> = {
  invalid: "Ungültige Eingabe.",
  rejected: "Nicht gespeichert: Dein Team hat bereits entschieden, oder die Anfrage ist nicht für dein Team.",
  taken: "Ein anderes Team hat diesen Fall bereits übernommen.",
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
const planSchema = z.object({ caseId: z.uuid(), ...slot, services: z.array(z.string().trim().min(1).max(80)).max(20), idempotencyKey: z.uuid() });
const rescheduleSchema = z.object({ visitId: z.uuid(), ...slot, idempotencyKey: z.uuid() });
const removeSchema = z.object({ visitId: z.uuid(), idempotencyKey: z.uuid() });

const PLAN_MESSAGES = {
  invalid: "Bitte Datum (ab gestern) und eine Endzeit nach der Startzeit angeben.",
  rejected: "Nicht gespeichert: nur Mitglieder des zuständigen Teams planen, und nur geplante Einsätze ohne Dokumentation können verschoben oder entfernt werden.",
  failed: "Planung konnte nicht gespeichert werden.",
};

function planResult(op: string, data: unknown, error: { code?: string } | null): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? PLAN_MESSAGES.invalid : PLAN_MESSAGES.failed };
  }
  if (data === "rejected") return { ok: false, error: PLAN_MESSAGES.rejected };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: PLAN_MESSAGES.failed };
  revalidatePath("/team");
  revalidatePath("/field");
  revalidatePath("/visits");
  return { ok: true };
}

export async function planVisit(input: unknown): Promise<CommandResult> {
  const parsed = planSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: PLAN_MESSAGES.invalid };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("plan_visit", {
    p_case_id: d.caseId,
    p_visit_date: d.date,
    p_time_start: d.start,
    p_time_end: d.end,
    p_services: d.services,
    p_idempotency_key: d.idempotencyKey,
  });
  return planResult("plan_visit", data, error);
}

export async function rescheduleVisit(input: unknown): Promise<CommandResult> {
  const parsed = rescheduleSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: PLAN_MESSAGES.invalid };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("reschedule_visit", {
    p_visit_id: d.visitId,
    p_visit_date: d.date,
    p_time_start: d.start,
    p_time_end: d.end,
    p_idempotency_key: d.idempotencyKey,
  });
  return planResult("reschedule_visit", data, error);
}

export async function removePlannedVisit(input: unknown): Promise<CommandResult> {
  const parsed = removeSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: PLAN_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("remove_planned_visit", {
    p_visit_id: parsed.data.visitId,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  return planResult("remove_planned_visit", data, error);
}
