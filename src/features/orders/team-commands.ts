"use server";

// BK-c2 (ADR-199, ADR-200): the four team commands on a shift-order offer. The database checks membership, the round,
// the person (`order_member_step`, CGR-204 (b)) and the named person; it refuses everybody else (BK-5n, FE-039).
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { ALREADY_TAKEN_TEXT, DECLINED_TEXT, offerCommandText } from "./offer-rules";

export type OfferCommandResult = { ok: true; status?: string } | { ok: false; error: string; status?: string };

const TEAM_PATH = "/team";
const ORDER_PATH = "/order";

type Answer = { result?: string; reason?: string };

function answer(op: string, data: unknown, error: { message: string } | null): OfferCommandResult {
  if (error) {
    logEvent("warn", "command.failed", { op, ...errorFields(error) });
    return { ok: false, error: "Das hat nicht geklappt. Bitte nochmals versuchen." };
  }
  const r = (data ?? {}) as Answer;
  revalidatePath(TEAM_PATH);
  revalidatePath(ORDER_PATH);
  if (r.result === "ok" || r.result === "duplicate") return { ok: true };
  // A lost race is a neutral state, not an error colour (template §3).
  if (r.reason === "already_taken") return { ok: false, error: "", status: ALREADY_TAKEN_TEXT };
  if (r.reason === "already_declined") return { ok: false, error: "", status: DECLINED_TEXT };
  return { ok: false, error: offerCommandText(r.reason) };
}

const takeInput = z.object({ orderId: z.uuid(), teamId: z.uuid(), memberId: z.uuid(), idempotencyKey: z.uuid() });
export async function takeShiftOrder(input: unknown): Promise<OfferCommandResult> {
  const p = takeInput.safeParse(input);
  if (!p.success) return { ok: false, error: "Bitte eine Person wählen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("take_order", {
    p_order_id: p.data.orderId,
    p_team_id: p.data.teamId,
    p_member_id: p.data.memberId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  return answer("take_order", data, error);
}

const declineInput = z.object({ orderId: z.uuid(), teamId: z.uuid(), idempotencyKey: z.uuid() });
export async function declineShiftOrder(input: unknown): Promise<OfferCommandResult> {
  const p = declineInput.safeParse(input);
  if (!p.success) return { ok: false, error: "Das hat nicht geklappt. Bitte nochmals versuchen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("decline_order", {
    p_order_id: p.data.orderId,
    p_team_id: p.data.teamId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  const r = answer("decline_order", data, error);
  return r.ok ? { ok: true, status: DECLINED_TEXT } : r;
}

const namedInput = z.object({ orderId: z.uuid(), idempotencyKey: z.uuid() });
export async function acknowledgeShiftTake(input: unknown): Promise<OfferCommandResult> {
  const p = namedInput.safeParse(input);
  if (!p.success) return { ok: false, error: "Das hat nicht geklappt. Bitte nochmals versuchen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("acknowledge_take", { p_order_id: p.data.orderId, p_idempotency_key: p.data.idempotencyKey });
  return answer("acknowledge_take", data, error);
}

export async function releaseNamedShiftTake(input: unknown): Promise<OfferCommandResult> {
  const p = namedInput.safeParse(input);
  if (!p.success) return { ok: false, error: "Das hat nicht geklappt. Bitte nochmals versuchen." };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("release_named_take", { p_order_id: p.data.orderId, p_idempotency_key: p.data.idempotencyKey });
  return answer("release_named_take", data, error);
}
