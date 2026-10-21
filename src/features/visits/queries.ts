import { supabase } from "@/lib/supabase";
import type { CareVisitRow } from "./types";

export async function getCareVisits(): Promise<CareVisitRow[]> {
  const { data, error } = await supabase
    .from("care_visits")
    .select(
      `
      id,
      case_id,
      visit_date,
      time_start,
      time_end,
      team_member_name,
      services_provided,
      notes,
      billable,
      status,
      created_at
      `
    )
    .order("visit_date", { ascending: true });

  if (error) {
    console.error("Error loading care visits:", error);
    throw new Error("Einsätze konnten nicht geladen werden.");
  }

  return data ?? [];
}
