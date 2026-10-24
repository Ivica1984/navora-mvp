"use server";

// C1: pause/resume/close/reopen a case; cancel a visit; record a no-show and its outcome (migration 0024).
// CSR1 / CGR-20: end a started or paused visit as not completed, with a reason (migration 0042).
// CSR1 / CGR-25: record the follow-up decision after such an end (migration 0045).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { CANCEL_REASONS, CLOSE_REASONS, FOLLOWUP_DECISIONS, INTERRUPT_REASONS, LIFECYCLE_MESSAGES, NO_SHOW_OUTCOMES, PAUSE_REASONS } from "./rules";

const key = z.uuid();
const note = z.string().trim().max(1000);

type RpcResult = { data: unknown; error: { code?: string } | null };

function interpret(op: string, { data, error }: RpcResult): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? LIFECYCLE_MESSAGES.invalid : LIFECYCLE_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/team");
    revalidatePath("/field");
    revalidatePath("/operations");
    return { ok: true };
  }
  return { ok: false, error: LIFECYCLE_MESSAGES[String(data)] ?? LIFECYCLE_MESSAGES.failed };
}

export async function pauseCase(input: unknown): Promise<CommandResult> {
  const p = z.object({ caseId: z.uuid(), reasonCode: z.enum(PAUSE_REASONS), note, expectedEnd: z.iso.date().nullable(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("pause_case", await supabase.rpc("pause_case", { p_case_id: p.data.caseId, p_reason_code: p.data.reasonCode, p_reason: (p.data.note || null) as string,
    p_expected_end: p.data.expectedEnd as string, p_idempotency_key: p.data.idempotencyKey }));
}

export async function resumeCase(input: unknown): Promise<CommandResult> {
  const p = z.object({ caseId: z.uuid(), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("resume_case", await supabase.rpc("resume_case", { p_case_id: p.data.caseId, p_idempotency_key: p.data.idempotencyKey }));
}

export async function closeCase(input: unknown): Promise<CommandResult> {
  const p = z.object({ caseId: z.uuid(), reasonCode: z.enum(CLOSE_REASONS), note, idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("close_case", await supabase.rpc("close_case", { p_case_id: p.data.caseId, p_reason_code: p.data.reasonCode, p_reason: (p.data.note || null) as string,
    p_idempotency_key: p.data.idempotencyKey }));
}

export async function reopenCase(input: unknown): Promise<CommandResult> {
  const p = z.object({ caseId: z.uuid(), reason: z.string().trim().min(3).max(500), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("reopen_case", await supabase.rpc("reopen_case", { p_case_id: p.data.caseId, p_reason: p.data.reason, p_idempotency_key: p.data.idempotencyKey }));
}

export async function cancelVisit(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), reasonCode: z.enum(CANCEL_REASONS), note, idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("cancel_visit", await supabase.rpc("cancel_visit", { p_visit_id: p.data.visitId, p_reason_code: p.data.reasonCode, p_reason: (p.data.note || null) as string,
    p_idempotency_key: p.data.idempotencyKey }));
}

export async function recordNoShow(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), note: z.string().trim().min(3).max(1000), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("record_no_show", await supabase.rpc("record_no_show", { p_visit_id: p.data.visitId, p_reason: p.data.note, p_idempotency_key: p.data.idempotencyKey }));
}

export async function recordNoShowOutcome(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), outcome: z.enum(NO_SHOW_OUTCOMES), note: z.string().trim().min(3).max(1000), idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("record_no_show_outcome", await supabase.rpc("record_no_show_outcome", { p_visit_id: p.data.visitId, p_outcome: p.data.outcome, p_reason: p.data.note,
    p_idempotency_key: p.data.idempotencyKey }));
}

export async function endVisitNotCompleted(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), reasonCode: z.enum(INTERRUPT_REASONS), note, idempotencyKey: key }).safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("end_visit_not_completed", await supabase.rpc("end_visit_not_completed", { p_visit_id: p.data.visitId, p_reason_code: p.data.reasonCode,
    p_reason: (p.data.note || null) as string, p_idempotency_key: p.data.idempotencyKey }));
}

export async function recordInterruptionFollowup(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), decision: z.enum(FOLLOWUP_DECISIONS), note, idempotencyKey: key })
    .refine((d) => d.decision !== "other" || d.note.length >= 3, { message: "note" })
    .safeParse(input);
  if (!p.success) return { ok: false, error: LIFECYCLE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  return interpret("record_interruption_followup", await supabase.rpc("record_interruption_followup", { p_visit_id: p.data.visitId,
    p_decision: p.data.decision, p_note: (p.data.note || null) as string, p_idempotency_key: p.data.idempotencyKey }));
}
