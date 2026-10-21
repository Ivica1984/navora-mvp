"use server";

// Team commands (T8). Replaces direct browser UPDATEs: input is validated and
// the write runs server-side as the signed-in user.
// Authorisation is enforced by RLS since T9: only organisation roles admin and
// coach may update teams (policy coaches_update_teams); columns are limited to
// priority and coach_name by column privileges.
// NOT YET (T10): audit_events, idempotency key, DB function.

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/auth/session";
import {
  assignTeamCoachSchema,
  setTeamPrioritySchema,
  type CommandResult,
} from "./command-schemas";

const INVALID = "Ungültige Eingabe.";
const FAILED =
  "Änderung nicht gespeichert: fehlende Berechtigung (nur Admin/Coach) oder Team nicht gefunden.";

export async function setTeamPriority(input: unknown): Promise<CommandResult> {
  const parsed = setTeamPrioritySchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };

  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("teams")
    .update({ priority: parsed.data.priority })
    .eq("id", parsed.data.teamId)
    .select("id");

  if (error || !data?.length) {
    if (error) console.error("setTeamPriority failed:", error.code);
    return { ok: false, error: FAILED };
  }

  revalidatePath("/teams");
  revalidatePath("/operations");
  return { ok: true };
}

export async function assignTeamCoach(input: unknown): Promise<CommandResult> {
  const parsed = assignTeamCoachSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };

  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("teams")
    .update({ coach_name: parsed.data.coachName })
    .eq("id", parsed.data.teamId)
    .select("id");

  if (error || !data?.length) {
    if (error) console.error("assignTeamCoach failed:", error.code);
    return { ok: false, error: FAILED };
  }

  revalidatePath("/teams");
  revalidatePath("/operations");
  return { ok: true };
}
