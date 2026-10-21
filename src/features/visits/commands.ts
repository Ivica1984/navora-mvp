"use server";

// Visit commands (T8). Replaces direct browser UPDATEs. Each transition only
// applies if the visit is still in the expected source state, so a double click
// or a stale page cannot move a visit twice.
// Authorisation is enforced by RLS since T9: only members of the visit's team
// can update it (policy team_members_update_visits).
// NOT YET (T10): visit_events + audit_events, idempotency key, DB function.

import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/auth/session";
import { visitIdSchema, type CommandResult } from "./command-schemas";

const INVALID = "Ungültige Eingabe.";

async function transitionVisit(
  input: unknown,
  from: string,
  update: Record<string, unknown>,
  failure: string
): Promise<CommandResult> {
  const parsed = visitIdSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: INVALID };

  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("care_visits")
    .update(update)
    .eq("id", parsed.data.visitId)
    .eq("status", from)
    .select("id");

  if (error) {
    console.error("Visit transition failed:", error.code);
    return { ok: false, error: failure };
  }
  if (!data?.length) {
    // RLS hides rows the user may not change, so "0 rows" means either the
    // status changed meanwhile or the user is not in the visit's team.
    return {
      ok: false,
      error:
        "Einsatz nicht geändert: Der Status hat sich inzwischen geändert, oder du gehörst nicht zum zuständigen Team.",
    };
  }

  revalidatePath("/visits");
  revalidatePath("/operations");
  return { ok: true };
}

export async function startVisit(input: unknown): Promise<CommandResult> {
  return transitionVisit(
    input,
    "planned",
    { status: "started" },
    "Einsatz konnte nicht gestartet werden."
  );
}

export async function completeVisit(input: unknown): Promise<CommandResult> {
  return transitionVisit(
    input,
    "started",
    // LEGACY (SR-09): billable is still set on completion, exactly as before.
    // DOMAIN_RULES require validated time, approved documentation and tariff
    // rules first. Removal is scheduled in T10 together with billing facts;
    // T8 deliberately keeps behaviour unchanged.
    { status: "completed", billable: true },
    "Einsatz konnte nicht abgeschlossen werden."
  );
}
