"use server";

// J2: team decision on an offered matching request (migration 0011).

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
