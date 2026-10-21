import { supabase } from "@/lib/supabase";
import type { TeamRow } from "./types";

export async function getTeams(): Promise<TeamRow[]> {
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
    console.error("Error loading teams:", error);
    throw new Error("Teams konnten nicht geladen werden.");
  }

  return data ?? [];
}
