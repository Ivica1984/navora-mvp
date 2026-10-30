"use server";

// ASM1 (migration 0100, ADR-123): record an assessment, supersede one with a reason, confirm as the named nurse.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { ASSESSMENT_REASONS, isValidReference } from "./rules";

const minutes = z.number().int().min(0).max(99999).nullable();
const period = z.string().trim().max(60).nullable();
const recordSchema = z
  .object({
    caseId: z.uuid(),
    assessmentDate: z.iso.date(),
    instrumentId: z.uuid(),
    assessorId: z.uuid(),
    documentRef: z.string().trim().max(64).nullable(),
    minutesA: minutes,
    periodA: period,
    minutesB: minutes,
    periodB: period,
    minutesC: minutes,
    periodC: period,
    supersedesId: z.uuid().nullable(),
    reason: z.string().trim().max(500).nullable(),
    idempotencyKey: z.uuid(),
  })
  // The database decides; these refinements only give the same answer before the round trip.
  .refine((d) => d.documentRef === null || d.documentRef === "" || isValidReference(d.documentRef), { message: "reference_invalid" })
  .refine((d) => (d.minutesA === null) === !d.periodA && (d.minutesB === null) === !d.periodB && (d.minutesC === null) === !d.periodC, {
    message: "period_required",
  })
  .refine((d) => (d.minutesA === null && d.minutesB === null && d.minutesC === null) || !!d.documentRef, { message: "reference_required" })
  .refine((d) => d.supersedesId === null || (d.reason !== null && d.reason.length >= 10), { message: "reason_required" });

const confirmSchema = z.object({ recordId: z.uuid(), idempotencyKey: z.uuid() });

const FAILED = "Bedarfsabklärung konnte nicht gespeichert werden.";

function result(op: string, data: unknown, error: { code?: string } | null): CommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: FAILED };
  }
  const res = (data ?? {}) as { result?: string; reason?: string };
  if (res.result === "ok" || res.result === "duplicate") {
    revalidatePath("/team");
    return { ok: true };
  }
  if (res.result === "rejected") return { ok: false, error: ASSESSMENT_REASONS[res.reason ?? ""] ?? FAILED };
  return { ok: false, error: FAILED };
}

export async function recordAssessment(input: unknown): Promise<CommandResult> {
  const parsed = recordSchema.safeParse(input);
  if (!parsed.success) {
    const code = parsed.error.issues.find((i) => i.message in ASSESSMENT_REASONS)?.message;
    return { ok: false, error: code ? ASSESSMENT_REASONS[code] : "Bitte Datum, Instrument und abklärende Pflegefachperson angeben." };
  }
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_assessment", {
    p_case_id: d.caseId,
    p_assessment_date: d.assessmentDate,
    p_instrument_id: d.instrumentId,
    p_assessor_id: d.assessorId,
    // Generated RPC types mark every argument as required; null = not given.
    p_document_ref: (d.documentRef || null) as string,
    p_minutes_a: d.minutesA as number,
    p_period_a: (d.periodA || null) as string,
    p_minutes_b: d.minutesB as number,
    p_period_b: (d.periodB || null) as string,
    p_minutes_c: d.minutesC as number,
    p_period_c: (d.periodC || null) as string,
    p_supersedes_id: d.supersedesId as string,
    p_reason: (d.reason || null) as string,
    p_idempotency_key: d.idempotencyKey,
  });
  return result("record_assessment", data, error);
}

export async function confirmAssessment(input: unknown): Promise<CommandResult> {
  const parsed = confirmSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: FAILED };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("confirm_assessment", {
    p_record_id: parsed.data.recordId,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  return result("confirm_assessment", data, error);
}
