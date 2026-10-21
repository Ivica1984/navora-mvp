"use server";

// F3: time corrections (migration 0008). F4: observations (migration 0009). The database checks team membership,
// reason, "not in the future" and timeline order; corrections are append-only.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";

const correctionSchema = z.object({
  eventId: z.number().int().positive(),
  correctedAt: z.iso.datetime(),
  reason: z.string().trim().min(5).max(500),
  idempotencyKey: z.uuid(),
});

const MESSAGES = {
  invalid: "Bitte eine gültige Uhrzeit und eine Begründung (mind. 5 Zeichen) angeben.",
  future: "Die korrigierte Zeit darf nicht in der Zukunft liegen.",
  order: "Die korrigierte Zeit passt nicht in die Reihenfolge des Einsatzes (z. B. Ende vor Start).",
  rejected: "Nicht gespeichert: Du gehörst nicht zum zuständigen Team.",
  failed: "Korrektur konnte nicht gespeichert werden.",
};

export async function correctVisitTime(input: unknown): Promise<CommandResult> {
  const parsed = correctionSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: MESSAGES.invalid };

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("correct_visit_time", {
    p_event_id: parsed.data.eventId,
    p_corrected_at: parsed.data.correctedAt,
    p_reason: parsed.data.reason,
    p_idempotency_key: parsed.data.idempotencyKey,
  });

  if (error) {
    logEvent("warn", "command.failed", { op: "correct_visit_time", ...errorFields(error) });
    if (error.code === "23514") return { ok: false, error: MESSAGES.order };
    if (error.code === "22023") {
      return { ok: false, error: new Date(parsed.data.correctedAt) > new Date() ? MESSAGES.future : MESSAGES.invalid };
    }
    return { ok: false, error: MESSAGES.failed };
  }
  if (data === "rejected") return { ok: false, error: MESSAGES.rejected };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: MESSAGES.failed };

  revalidatePath("/field");
  return { ok: true };
}

const observationSchema = z.object({
  visitId: z.uuid(),
  content: z.string().trim().min(1).max(2000),
  forHandover: z.boolean(),
  supersedesId: z.uuid().nullable(),
  idempotencyKey: z.uuid(),
});

const OBSERVATION_MESSAGES = {
  invalid: "Bitte eine Beobachtung eingeben (höchstens 2000 Zeichen).",
  rejected:
    "Nicht gespeichert: Beobachtungen sind erst ab Abfahrt möglich, nur im zuständigen Team, und nur die neueste Fassung kann geändert werden.",
  failed: "Beobachtung konnte nicht gespeichert werden.",
};

export async function recordObservation(input: unknown): Promise<CommandResult> {
  const parsed = observationSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: OBSERVATION_MESSAGES.invalid };

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_observation", {
    p_visit_id: parsed.data.visitId,
    p_content: parsed.data.content,
    p_for_handover: parsed.data.forHandover,
    // The generated RPC type marks every argument as required; null means "new observation".
    p_supersedes_id: parsed.data.supersedesId as string,
    p_idempotency_key: parsed.data.idempotencyKey,
  });

  if (error) {
    logEvent("warn", "command.failed", { op: "record_observation", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? OBSERVATION_MESSAGES.invalid : OBSERVATION_MESSAGES.failed };
  }
  if (data === "rejected") return { ok: false, error: OBSERVATION_MESSAGES.rejected };
  if (data !== "ok" && data !== "duplicate") return { ok: false, error: OBSERVATION_MESSAGES.failed };

  revalidatePath("/field");
  return { ok: true };
}
