import "server-only";

import { requireUser } from "@/lib/auth/session";
import type { CareVisitRow } from "./types";
import { errorFields, logEvent } from "@/lib/log";

export async function getCareVisits(): Promise<CareVisitRow[]> {
  // Runs as the signed-in user (RLS sees auth.uid()); redirects to /login otherwise.
  const { supabase } = await requireUser();

  // RLS4-6 (ADR-122): the responsible member comes from responsible_user_id; team_member_name is not read.
  const { data, error } = await supabase
    .from("care_visits")
    .select(
      `
      id,
      case_id,
      visit_date,
      time_start,
      time_end,
      responsible_user_id,
      services_provided,
      notes,
      billable,
      status,
      created_at
      `
    )
    .order("visit_date", { ascending: true });

  if (error) {
    logEvent("error", "visits.load_failed", errorFields(error));
    throw new Error("Einsätze konnten nicht geladen werden.");
  }

  const rows = data ?? [];
  const ids = [...new Set(rows.map((v) => v.responsible_user_id).filter((id): id is string => Boolean(id)))];
  const names = new Map<string, string>();
  if (ids.length > 0) {
    // One display name per responsible member (member_profiles: readable within the organisation).
    const { data: profiles, error: profileError } = await supabase
      .from("member_profiles")
      .select("user_id, display_name")
      .in("user_id", ids);
    if (profileError) {
      logEvent("error", "visits.responsible_names_failed", errorFields(profileError));
    }
    for (const p of profiles ?? []) {
      if (p.display_name) names.set(p.user_id, p.display_name);
    }
  }

  return rows.map((v) => ({
    ...v,
    responsible_name: v.responsible_user_id ? (names.get(v.responsible_user_id) ?? null) : null,
  }));
}
