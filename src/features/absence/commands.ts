"use server";

// ABS1 (migration 0046): record, withdraw or shorten an absence; take an open visit of the team (one tap, first
// wins). The database checks team membership, qualification and overlap; no reason exists to send.

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { ABSENCE_MESSAGES, TAKE_MESSAGES, resultOf } from "./rules";

const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const time = z.string().regex(/^\d{2}:\d{2}$/);

const recordSchema = z.object({
  teamId: z.uuid(),
  userId: z.uuid().nullable(),
  from: day.nullable(),
  until: day.nullable(),
  fromTime: time.nullable(),
  untilTime: time.nullable(),
  idempotencyKey: z.uuid(),
});

function done(): CommandResult {
  revalidatePath("/field");
  revalidatePath("/team");
  return { ok: true };
}

export async function recordAbsence(input: unknown): Promise<CommandResult> {
  const p = recordSchema.safeParse(input);
  if (!p.success) return { ok: false, error: ABSENCE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  // The generated RPC type marks every argument as required; null means "default" (herself, today, whole day).
  const { data, error } = await supabase.rpc("record_absence", {
    p_team_id: p.data.teamId,
    p_user_id: p.data.userId as string,
    p_from: p.data.from as string,
    p_until: p.data.until as string,
    p_from_time: p.data.fromTime as string,
    p_until_time: p.data.untilTime as string,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "record_absence", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? ABSENCE_MESSAGES.invalid : ABSENCE_MESSAGES.failed };
  }
  const r = resultOf(data);
  if (r === "ok" || r === "duplicate") return done();
  return { ok: false, error: ABSENCE_MESSAGES[r] ?? ABSENCE_MESSAGES.failed };
}

const changeSchema = z.object({
  absenceId: z.uuid(),
  withdraw: z.boolean(),
  until: day.nullable(),
  untilTime: time.nullable(),
  idempotencyKey: z.uuid(),
});

export async function changeAbsence(input: unknown): Promise<CommandResult> {
  const p = changeSchema.safeParse(input);
  if (!p.success || (!p.data.withdraw && !p.data.until)) return { ok: false, error: ABSENCE_MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("change_absence", {
    p_absence_id: p.data.absenceId,
    p_withdraw: p.data.withdraw,
    p_until: p.data.until as string,
    p_until_time: p.data.untilTime as string,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "change_absence", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? ABSENCE_MESSAGES.invalid : ABSENCE_MESSAGES.failed };
  }
  const r = resultOf(data);
  if (r === "ok" || r === "duplicate") return done();
  return { ok: false, error: ABSENCE_MESSAGES[r] ?? ABSENCE_MESSAGES.failed };
}

export async function takeOpenVisit(input: unknown): Promise<CommandResult> {
  const p = z.object({ visitId: z.uuid(), idempotencyKey: z.uuid() }).safeParse(input);
  if (!p.success) return { ok: false, error: TAKE_MESSAGES.failed };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("take_open_visit", { p_visit_id: p.data.visitId, p_idempotency_key: p.data.idempotencyKey });
  if (error) {
    logEvent("warn", "command.failed", { op: "take_open_visit", ...errorFields(error) });
    return { ok: false, error: TAKE_MESSAGES.failed };
  }
  const r = resultOf(data);
  if (r === "ok" || r === "duplicate") return done();
  return { ok: false, error: TAKE_MESSAGES[r] ?? TAKE_MESSAGES.failed };
}
