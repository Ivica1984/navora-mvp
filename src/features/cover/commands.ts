"use server";

// COVER1: accept a visit offered by a neighbouring team (migration 0028). First acceptance wins.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { COVER_MESSAGES } from "./rules";

export async function acceptCover(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), idempotencyKey: z.uuid() }).safeParse(input);
  if (!p.success) return { ok: false, error: COVER_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("accept_cover", { p_visit_id: p.data.visitId, p_idempotency_key: p.data.idempotencyKey });
  if (error) {
    logEvent("warn", "command.failed", { op: "accept_cover", ...errorFields(error) });
    return { ok: false, error: COVER_MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate") {
    revalidatePath("/field");
    revalidatePath("/team");
    return { ok: true };
  }
  return { ok: false, error: COVER_MESSAGES[String(data)] ?? COVER_MESSAGES.failed };
}
