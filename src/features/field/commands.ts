"use server";

// F3: time corrections (migration 0008). The database checks team membership,
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
