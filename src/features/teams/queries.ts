import "server-only";

import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";
import type { TeamRow } from "./types";

export async function getTeams(): Promise<TeamRow[]> {
  // Runs as the signed-in user (RLS sees auth.uid()); redirects to /login otherwise.
  const { supabase } = await requireUser();

  const { data, error } = await supabase
    .from("teams")
    .select(
      `
      id,
      name,
      region,
      care_focus,
      status,
      open_slots,
      utilization,
      lead_name,
      next_step,
      created_at,
      priority,
      coach_name
      `
    )
    .order("created_at", { ascending: true });

  if (error) {
    logEvent("error", "teams.load_failed", errorFields(error));
    throw new Error("Teams konnten nicht geladen werden.");
  }

  return data ?? [];
}
