import "server-only";

import { requireUser } from "@/lib/auth/session";
import type { CaseRow } from "./types";

export async function getCases(): Promise<CaseRow[]> {
  // Runs as the signed-in user (RLS sees auth.uid()); redirects to /login otherwise.
  const { supabase } = await requireUser();

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
      assigned_team_id
      `
    )
    .order("created_at", { ascending: false });

  if (error) {
    console.error("Error loading cases:", error);
    throw new Error("Cases konnten nicht geladen werden.");
  }

  return data ?? [];
}
