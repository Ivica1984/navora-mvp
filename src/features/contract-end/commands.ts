"use server";

// ADM2-11 (migration 0092, ADR-115): the administrator records or changes a contract end date. The database checks the
// administrator, the switch, the date and idempotency, releases her later visits and audits; this action only validates
// shape.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { CONTRACT_END_MESSAGES } from "./rules";

export type ContractEndResult =
  | { ok: true; released: Record<string, number>; accessEndsOn: string | null }
  | { ok: false; error: string };

/** "Vertragsende erfassen": a date (YYYY-MM-DD) or null to remove it. Never returns a count of her days. */
export async function setMemberContractEnd(input: unknown): Promise<ContractEndResult> {
  const p = z.object({
    userId: z.uuid(), endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(), idempotencyKey: z.uuid(),
  }).safeParse(input);
  if (!p.success) return { ok: false, error: CONTRACT_END_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_member_contract_end", {
    p_user_id: p.data.userId, p_end_date: p.data.endDate as string, p_idempotency_key: p.data.idempotencyKey });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_member_contract_end", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? CONTRACT_END_MESSAGES.invalid : CONTRACT_END_MESSAGES.failed };
  }
  const v = (data ?? {}) as { result?: string; released?: Record<string, number>; access_ends_on?: string | null };
  if (v.result === "ok" || v.result === "duplicate" || v.result === "unchanged") {
    revalidatePath("/admin");
    revalidatePath("/team");
    return { ok: true, released: v.released ?? {}, accessEndsOn: v.access_ends_on ?? null };
  }
  return { ok: false, error: CONTRACT_END_MESSAGES[String(v.result)] ?? CONTRACT_END_MESSAGES.failed };
}
