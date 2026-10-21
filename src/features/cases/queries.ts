import { supabase } from "@/lib/supabase";
import type { CaseRow } from "./types";

export async function getCases(): Promise<CaseRow[]> {
  const { data, error } = await supabase
    .from("cases")
    .select(
      `
      id,
      created_at,
      name,
      region,
      status,
      bedarf,
      urgency,
      time_info,
      first_name,
      last_name,
      date_of_birth,
      gender,
      address,
      plz,
      ort,
      phone,
      emergency_contact_name,
      emergency_contact_phone,
      mobility_status,
      cognitive_status,
      diagnosis_tags,
      care_needs,
      care_level,
      referral_source,
      insurance_provider,
      start_date,
      next_step,
      notes,
      assigned_team
      `
    )
    .order("created_at", { ascending: false });

  if (error) {
    console.error("Error loading cases:", error);
    throw new Error("Cases konnten nicht geladen werden.");
  }

  return data ?? [];
}

export async function getCasesWithVisits(): Promise<(CaseRow & { care_visits: { id: string; status: string | null }[] })[]> {
  const { data, error } = await supabase
    .from("cases")
    .select(
      `
      id,
      created_at,
      name,
      region,
      status,
      bedarf,
      urgency,
      time_info,
      first_name,
      last_name,
      date_of_birth,
      gender,
      address,
      plz,
      ort,
      phone,
      emergency_contact_name,
      emergency_contact_phone,
      mobility_status,
      cognitive_status,
      diagnosis_tags,
      care_needs,
      care_level,
      referral_source,
      insurance_provider,
      start_date,
      next_step,
      notes,
      assigned_team,
      assigned_team_id,
      teams (
        id,
        name,
        region,
        status,
        open_slots,
        utilization
      ),
      care_visits (
        id,
        status,
        visit_date,
        time_start,
        time_end,
        team_member_name,
        services_provided,
        notes
      )
      `
    )
    .order("created_at", { ascending: false });

  if (error) {
    console.error("Error loading cases with visits:", error);
    throw new Error("Cases mit Einsätzen konnten nicht geladen werden.");
  }

  return data ?? [];
}
