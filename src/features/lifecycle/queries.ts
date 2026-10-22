import "server-only";

import type { Database } from "@/lib/supabase/database.types";
import { requireUser } from "@/lib/auth/session";
import { errorFields, logEvent } from "@/lib/log";

export type CaseLifecycle = Database["public"]["Functions"]["team_case_lifecycle"]["Returns"][number];
export type VisitStatusNote = Database["public"]["Functions"]["field_visit_status_notes"]["Returns"][number];

/** C1: lifecycle of the caller's teams' cases, including paused and closed ones (migration 0024). */
export async function getCaseLifecycle(): Promise<CaseLifecycle[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("team_case_lifecycle");
  if (error) {
    logEvent("error", "lifecycle.load_failed", errorFields(error));
    throw new Error("Fallstatus konnte nicht geladen werden.");
  }
  return data ?? [];
}

/** C1: reasons and no-show outcomes for the day's visits (team only). */
export async function getVisitStatusNotes(day: string): Promise<VisitStatusNote[]> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("field_visit_status_notes", { p_date: day });
  if (error) {
    logEvent("error", "lifecycle.notes_load_failed", errorFields(error));
    throw new Error("Absagen konnten nicht geladen werden.");
  }
  return data ?? [];
}
