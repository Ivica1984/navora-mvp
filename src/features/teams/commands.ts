"use server";

// Team commands. Since T10 each one calls a Postgres command function
// (migration …0004): RLS decides who may change what (T9: admin/coach), the
// idempotency key makes retries safe, and an audit trigger records the change.

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/auth/session";
import { toCommandResult } from "@/lib/commands/result";
import {
  assignTeamCoachSchema,
  setTeamPrioritySchema,
  type CommandResult,
} from "./command-schemas";

const INVALID: CommandResult = { ok: false, error: "Ungültige Eingabe." };
const MESSAGES = {
  rejected:
    "Änderung nicht gespeichert: fehlende Berechtigung (nur Admin/Coach) oder Team nicht gefunden.",
  failed: "Änderung konnte nicht gespeichert werden.",
};

function done(result: CommandResult): CommandResult {
  if (result.ok) {
    revalidatePath("/teams");
    revalidatePath("/operations");
  }
  return result;
}

export async function setTeamPriority(input: unknown): Promise<CommandResult> {
  const parsed = setTeamPrioritySchema.safeParse(input);
  if (!parsed.success) return INVALID;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("set_team_priority", {
    p_team_id: parsed.data.teamId,
    p_priority: parsed.data.priority,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) console.error("set_team_priority failed:", error.code);

  return done(toCommandResult(data, error, MESSAGES));
}

export async function assignTeamCoach(input: unknown): Promise<CommandResult> {
  const parsed = assignTeamCoachSchema.safeParse(input);
  if (!parsed.success) return INVALID;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("assign_team_coach", {
    p_team_id: parsed.data.teamId,
    p_coach_name: parsed.data.coachName,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) console.error("assign_team_coach failed:", error.code);

  return done(toCommandResult(data, error, MESSAGES));
}
