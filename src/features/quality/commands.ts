"use server";

// QG1: record a quality event, review/close it, set and lift a quality hold (migration 0020).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { SEVERITIES, qualityRejectionMessage } from "./rules";

const key = z.uuid();
const INVALID = "Bitte die Eingaben prüfen (Begründung bzw. Notiz mindestens 3 Zeichen).";
const FAILED = "Konnte nicht gespeichert werden.";

function done(): CommandResult {
  revalidatePath("/field");
  revalidatePath("/operations");
  return { ok: true };
}

const recordSchema = z.object({
  visitId: z.uuid(),
  typeCode: z.string().min(2).max(40),
  severity: z.enum(SEVERITIES),
  note: z.string().trim().max(2000),
  idempotencyKey: key,
});

export async function recordQualityEvent(input: unknown): Promise<CommandResult> {
  const parsed = recordSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_quality_event", {
    p_visit_id: parsed.data.visitId,
    p_type_code: parsed.data.typeCode,
    p_severity: parsed.data.severity,
    p_occurred_at: new Date().toISOString(),
    p_note: parsed.data.note,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "record_quality_event", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? INVALID : FAILED };
  }
  const result = data as { result?: string; reason?: string } | null;
  if (result?.result === "ok" || result?.result === "duplicate") return done();
  return { ok: false, error: qualityRejectionMessage(result?.reason) };
}

const statusSchema = z
  .object({ eventId: z.uuid(), status: z.enum(["in_review", "closed"]), note: z.string().trim().max(1000), idempotencyKey: key })
  .refine((d) => d.status !== "closed" || d.note.length >= 3, { message: "note" });

export async function setQualityEventStatus(input: unknown): Promise<CommandResult> {
  const parsed = statusSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_quality_event_status", {
    p_event_id: parsed.data.eventId,
    p_status: parsed.data.status,
    p_note: parsed.data.note,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_quality_event_status", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? INVALID : FAILED };
  }
  if (data === "ok" || data === "duplicate") return done();
  return { ok: false, error: "Nicht gespeichert: Das Ereignis ist bereits geschlossen oder nicht für dich sichtbar." };
}

const holdSchema = z.object({ visitId: z.uuid(), reason: z.string().trim().min(3).max(500), idempotencyKey: key });

export async function setQualityHold(input: unknown): Promise<CommandResult> {
  const parsed = holdSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_quality_hold", {
    p_visit_id: parsed.data.visitId,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_quality_hold", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? INVALID : FAILED };
  }
  if (data === "ok" || data === "duplicate") return done();
  if (data === "already_held") return { ok: false, error: "Für diesen Einsatz besteht bereits ein Qualitäts-Stopp." };
  return { ok: false, error: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team." };
}

const liftSchema = z.object({ holdId: z.uuid(), reason: z.string().trim().min(3).max(500), idempotencyKey: key });

export async function liftQualityHold(input: unknown): Promise<CommandResult> {
  const parsed = liftSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("lift_quality_hold", {
    p_hold_id: parsed.data.holdId,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "lift_quality_hold", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? INVALID : FAILED };
  }
  if (data === "ok" || data === "duplicate") return done();
  return { ok: false, error: "Nicht gespeichert: Aufheben dürfen nur Coach oder Admin (vorläufig, D-16)." };
}
