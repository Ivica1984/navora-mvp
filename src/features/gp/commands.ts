"use server";

// ORD0-1/2 (migration 0061, ADR-075): the team records that the treating doctor was informed; the task closes.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { GP_CHANNELS, GP_MESSAGES } from "./rules";

const schema = z.object({
  caseId: z.uuid(),
  informedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  channel: z.enum(GP_CHANNELS),
  idempotencyKey: z.uuid(),
});

export async function recordGpInformed(input: unknown): Promise<CommandResult> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { ok: false, error: GP_MESSAGES.invalid };
  const d = parsed.data;
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("record_gp_informed", {
    p_case_id: d.caseId,
    p_informed_on: d.informedOn,
    p_channel: d.channel,
    p_idempotency_key: d.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "record_gp_informed", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? GP_MESSAGES.invalid : GP_MESSAGES.failed };
  }
  const out = (data ?? {}) as { result?: string; reason?: string };
  if (out.result === "ok" || out.result === "duplicate" || out.result === "unchanged") {
    revalidatePath("/team");
    revalidatePath("/field");
    return { ok: true };
  }
  return { ok: false, error: GP_MESSAGES[out.reason ?? ""] ?? GP_MESSAGES.failed };
}
