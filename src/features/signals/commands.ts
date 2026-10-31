"use server";

// SIG1 (migration 0060): poll the caller's open P1 safety signals and take one ("Ich übernehme").
// The database decides who is a recipient; the poll also runs the (throttled) server evaluation.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import { kickDispatch } from "@/features/push/dispatch";
import { TAKE_MESSAGES, takeOutcome, type SignalRow } from "./rules";

export async function pollSignals(): Promise<{ ok: true; rows: SignalRow[] } | { ok: false }> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("my_signals");
  if (error) {
    logEvent("warn", "signals.poll_failed", errorFields(error));
    return { ok: false };
  }
  // SIG2: the poll has just evaluated; hand new outside deliveries to the sender at once (the scheduler is primary).
  kickDispatch();
  return { ok: true, rows: (data ?? []) as SignalRow[] };
}

const takeSchema = z.object({ signalId: z.uuid(), idempotencyKey: z.uuid() });

export async function takeSignal(input: unknown): Promise<{ ok: true } | { ok: false; error: string }> {
  const p = takeSchema.safeParse(input);
  if (!p.success) return { ok: false, error: TAKE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("take_signal", {
    p_signal_id: p.data.signalId,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "take_signal", ...errorFields(error) });
    return { ok: false, error: TAKE_MESSAGES.failed };
  }
  const r = takeOutcome(data);
  // A second tap (also by a colleague) is `duplicate`: the signal is taken, which is what she wanted.
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/field");
    revalidatePath("/team");
    return { ok: true };
  }
  return { ok: false, error: TAKE_MESSAGES[r.reason ?? ""] ?? TAKE_MESSAGES.failed };
}
