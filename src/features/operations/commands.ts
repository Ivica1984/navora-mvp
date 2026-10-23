"use server";

// OPS1: take over, comment, close (reason required) — audited in exception_events (migration 0019).
// Safety exceptions (P1 or escalating to P1) are not closed by hand: `cause_persists` (CSR1 / CGR-06, migration 0039).
// Nor is an uncovered visit (`visit_uncovered`) while nobody is responsible (CSR1 / CGR-22, migration 0044).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";

const schema = z
  .object({
    key: z.string().min(3).max(200),
    kind: z.enum(["take", "comment", "close"]),
    text: z.string().trim().max(1000),
    idempotencyKey: z.uuid(),
  })
  .refine((d) => d.kind === "take" || d.text.length >= 3, { message: "text" });

const MESSAGES = {
  invalid: "Bitte einen Text eingeben (mind. 3 Zeichen). Schliessen braucht eine Begründung.",
  rejected: "Nicht gespeichert: Die Ausnahme ist bereits geschlossen oder nicht mehr aktuell.",
  // CSR1 / CGR-06 (migration 0039) and CGR-22 (0044): it closes only when its cause is resolved.
  cause_persists:
    "Nicht geschlossen: Diese Ausnahme schliesst erst, wenn die Ursache behoben ist (bei einem unbesetzten Einsatz: jemand ist zuständig oder der Einsatz ist abgesagt). Übernehmen und Notizen sind möglich.",
  failed: "Konnte nicht gespeichert werden.",
};

export async function handleException(input: unknown): Promise<CommandResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { ok: false, error: MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("handle_exception", {
    p_key: parsed.data.key,
    p_kind: parsed.data.kind,
    p_text: parsed.data.text,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "handle_exception", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/operations");
    return { ok: true };
  }
  if (data === "cause_persists") return { ok: false, error: MESSAGES.cause_persists };
  return { ok: false, error: data === "rejected" ? MESSAGES.rejected : MESSAGES.failed };
}
