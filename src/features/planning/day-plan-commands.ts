"use server";

// PLAN3 part (b) (ADR-147): the two commands of /team/tagesplan. The database decides (0109, 0110): who may switch the
// team's "Tagesvorschlag" (an active member of that team only, audited, actor in the audit row only) and who may ask,
// for which day, with which refusal. Confirming lines goes through the AIG1 commands unchanged (features/ai/commands).

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/auth/session";
import type { CommandResult } from "@/lib/commands/result";
import { errorFields, logEvent } from "@/lib/log";
import { dayPlanRefusalText } from "./day-plan-labels";

const MESSAGES = {
  invalid: "Ungültige Eingabe.",
  rejected: "Nicht gespeichert: Das geht nur in deinem eigenen Team.",
  failed: "Konnte nicht gespeichert werden.",
};

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export async function setTeamDayProposal(input: unknown): Promise<CommandResult> {
  const p = z.object({ teamId: z.uuid(), on: z.boolean(), idempotencyKey: z.uuid() }).safeParse(input);
  if (!p.success) return { ok: false, error: MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_team_day_proposal", {
    p_team_id: p.data.teamId,
    p_on: p.data.on,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "set_team_day_proposal", ...errorFields(error) });
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  if (data === "ok" || data === "duplicate" || data === "unchanged") {
    revalidatePath("/team/tagesplan");
    return { ok: true };
  }
  return { ok: false, error: data === "rejected" ? MESSAGES.rejected : MESSAGES.failed };
}

export type ProposeResult =
  | { ok: true; lines: number; notFound: number }
  | { ok: false; error: string; reason?: string };

export async function proposeDayPlan(input: unknown): Promise<ProposeResult> {
  const p = z
    .object({ teamId: z.uuid(), date: z.string().regex(ISO_DATE), includeAssigned: z.boolean(), idempotencyKey: z.uuid() })
    .safeParse(input);
  if (!p.success) return { ok: false, error: MESSAGES.invalid };
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("propose_day_plan", {
    p_team_id: p.data.teamId,
    p_date: p.data.date,
    p_include_assigned: p.data.includeAssigned,
    p_idempotency_key: p.data.idempotencyKey,
  });
  if (error) {
    logEvent("warn", "command.failed", { op: "propose_day_plan", ...errorFields(error) });
    if (error.code === "42501") return { ok: false, error: MESSAGES.rejected };
    return { ok: false, error: error.code === "22023" ? MESSAGES.invalid : MESSAGES.failed };
  }
  const r = data && typeof data === "object" && !Array.isArray(data) ? (data as Record<string, unknown>) : {};
  if (r.result === "ok" || r.result === "duplicate") {
    revalidatePath("/team/tagesplan");
    revalidatePath("/team/vorschlaege");
    return { ok: true, lines: Number(r.lines ?? 0), notFound: Number(r.not_found ?? 0) };
  }
  if (r.result === "nothing_open") return { ok: false, error: dayPlanRefusalText("nothing_open"), reason: "nothing_open" };
  if (r.result === "refused") {
    const reason = typeof r.reason === "string" ? r.reason : "";
    return { ok: false, error: dayPlanRefusalText(reason), reason };
  }
  return { ok: false, error: r.result === "rejected" ? MESSAGES.rejected : MESSAGES.failed };
}
