"use server";

// Visit commands. Since T10 each one calls a Postgres command function
// (migration …0004): RLS limits changes to the visit's team (T9), a trigger
// enforces planned → started → completed, the idempotency key makes retries
// safe, and an audit trigger records the change. Completing a visit no longer
// sets `billable` (SR-09): billing facts come later from validated data.

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/auth/session";
import { toCommandResult } from "@/lib/commands/result";
import { visitCommandSchema, type CommandResult } from "./command-schemas";

const INVALID: CommandResult = { ok: false, error: "Ungültige Eingabe." };
const REJECTED =
  "Einsatz nicht geändert: Der Status hat sich inzwischen geändert, oder du gehörst nicht zum zuständigen Team.";

async function runVisitCommand(
  fn: "start_visit" | "complete_visit",
  input: unknown,
  failed: string
): Promise<CommandResult> {
  const parsed = visitCommandSchema.safeParse(input);
  if (!parsed.success) return INVALID;

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc(fn, {
    p_visit_id: parsed.data.visitId,
    p_idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) console.error(`${fn} failed:`, error.code);

  const result = toCommandResult(data, error, { rejected: REJECTED, failed });
  if (result.ok) {
    revalidatePath("/visits");
    revalidatePath("/operations");
  }
  return result;
}

export async function startVisit(input: unknown): Promise<CommandResult> {
  return runVisitCommand("start_visit", input, "Einsatz konnte nicht gestartet werden.");
}

export async function completeVisit(input: unknown): Promise<CommandResult> {
  return runVisitCommand("complete_visit", input, "Einsatz konnte nicht abgeschlossen werden.");
}
